## Q1 — B2B SaaS Invoicing
You're building the billing system for a multi-tenant SaaS product. Each invoice has line items, tax calculations, and payment records that must stay consistent — a partially-applied payment or an invoice with mismatched line-item totals is a compliance problem. Finance also wants to run ad-hoc queries ("total revenue by region last quarter," "which customers are 30+ days overdue") that aren't defined yet. Expected load: a few thousand invoices/day per tenant, low write QPS. What do you pick, and why?

Answer:
ACCESS PATTERNS
1. Fetch invoice + line items by customer, ordered by date → aggregate read, FK-owned entities
2. Atomic payment transfer between customers → multi-entity ACID required
3. Finance ad hoc queries → undefined access patterns, need declarative query surface

DECISION: PostgreSQL (OLTP) + Redshift (OLAP), split by workload

WHY (four axes)
- Schema flexibility: invoice/line-item/payment schema is stable and well-understood →
  schema-on-write costs nothing here; there's no flexibility being sacrificed.
- Query patterns: finance's queries are undefined in advance → SQL gives a declarative
  interface (joins, aggregates, ad hoc predicates) without pre-modeling every query,
  which a KV/document store would force you to do.
- Consistency: payment transfer needs multi-row ACID — debit + credit must commit or
  roll back together. Only a transactional engine gives this without application-level
  compensation logic.
- Scale: low write QPS, single-tenant invoice volume is small → a single well-tuned
  Postgres node comfortably covers this; no scale pressure to justify NoSQL's cost.

TRADE-OFF (what's given up)
Postgres doesn't shard natively — if this ever needs to shard, I'm responsible for
picking a shard key (tenant_id/customer_id), building a routing layer, handling
resharding, and avoiding cross-shard ID collisions. That's bolt-on partitioning
(Citus/Vitess) vs. NoSQL's partition-native design. If cross-shard atomicity were ever
needed, it costs a distributed commit protocol round-trip — that's the real latency
tax, not "SQL is inherently slower."

SWITCH CONDITION
I'd move to MongoDB only if BOTH: (a) write volume exceeds single-node Postgres
capacity, AND (b) the payment-atomicity requirement can be satisfied by multi-document
transactions scoped to a single shard (via co-locating a customer's records on one
shard by shard key) — accepting a weaker, partition-scoped guarantee than Postgres's
cross-table ACID in exchange for partition-native horizontal scale. If atomicity must
hold across shards, this switch doesn't work without a distributed transaction
protocol on top, which erodes most of the scale benefit.

## Q2 — Global Chat
A chat app needs to store messages per conversation. Write volume is enormous — tens of millions of messages/sec globally, growing. The only read pattern that matters: "give me the last N messages for conversation_id X, ordered by time." No joins, no ad-hoc queries, users span every region. What's your store?

Answer:
ACCESS PATTERNS
1. 10M+ messages/sec globally → extreme write throughput requirement
2. "last N messages for conversation_id, ordered by time" → single known query shape,
   needs data locality (all of one conversation colocated) + range scan by time
3. No joins, no ad hoc queries → access pattern fully known in advance

DECISION: Cassandra (wide-column). Partition key = conversation_id,
clustering key = timestamp (DESC).

WHY (four axes)
- Query patterns: the one access pattern is known upfront, so the schema can be
  built entirely around it — no ad hoc flexibility to pay for.
- Consistency: no multi-row ACID needed. Tunable consistency — write at
  LOCAL_QUORUM (durability), read at ONE (latency) — replicas converge async.
- Scale: 10M+ msg/sec exceeds any single relational node; Cassandra is
  partition-native from day one vs. bolting sharding onto Postgres.
- CAP/PACELC: AP system — availability and low write latency matter more than
  strict freshness. Cost is staleness (a reader may briefly miss the latest
  message until replicas converge), not incorrect data.

TRADE-OFF
- Queries limited to PK + clustering key; any future non-PK query pattern
  means scatter-gather across all partitions.
- Loss risk comes from replication factor/consistency level, not ACID — write
  at LOCAL_QUORUM to bound it.
- Ordering risk is clock skew on client timestamps across regions (last-write-
  wins conflicts), not arrival order — reads are always clustering-key sorted.
- No cross-partition atomicity — can't atomically write a message and update
  a separate unread-count row.

SWITCH CONDITION
I'd move to NewSQL (Spanner/CockroachDB) if strict linearizable ordering and
zero message loss became hard requirements (e.g., regulatory chat retention)
AND the team can absorb the added write latency and operational cost of a
globally-consistent system — accepting slower writes in exchange for
correctness guarantees Cassandra's tunable consistency can't give.


## Q3 — E-commerce Catalog
Product catalog spans electronics, clothing, and furniture. A laptop has RAM/CPU/screen-size fields; a t-shirt has size/color/material. Merchandising changes attribute sets every few weeks as new product lines launch. Reads are always by product_id or category browse — no cross-category joins. How do you model this?

Answer:
ACCESS PATTERNS
1. Point lookup by product_id
2. Category browse: N items for a given category
3. Attribute SET changes every few weeks as new product lines launch
   (schema volatility, not write frequency)
4. No cross-category joins

DECISION: MongoDB (document). Shard/partition key = product_id,
secondary index = category_id.

WHY (four axes)
- Schema flexibility: this is the dominant driver. New product lines bring new
  attribute sets (RAM/CPU for electronics, size/color for clothing) with no
  advance notice. Schema-on-read lets each document carry its own field set
  with zero migration. The relational alternative — a wide sparse table or
  constant ALTER TABLE per new attribute — is the cost being avoided.
- Query patterns: point lookup by product_id is the dominant, partition-local
  path. Category browse is secondary and accepted to scatter-gather via
  secondary index across shards.
- Consistency: low write volume, occasional replica lag on updates is fine —
  staleness, not correctness, is what's tolerated.
- Data shape: each product is a natural aggregate (all attributes under one
  product_id) — no relational joins needed for a single-product read.

TRADE-OFF
- Schema-on-read pushes shape-handling into every reader — real app-level
  discipline required, or old-shape documents silently break new code.
- Category browse scatter-gathers across shards (accepted since product_id
  lookup, not category browse, is the hot path).
- No ad hoc queries without a supporting index — same full-scan cost any
  NoSQL store pays for unmodeled access patterns.
- Replica lag on writes (bounded by write concern level chosen).

SWITCH CONDITION
I'd move to a relational model once attribute sets across categories
stabilize — at that point schema-on-write's upfront cost (one-time migration)
beats continuously paying the schema-on-read tax at the app layer, and ad hoc
reporting across the now-fixed schema becomes a free bonus of the switch,
not the reason for it.

## Q4 — Multiplayer Leaderboard
A game needs a live leaderboard: top-10 global ranking and "what's my rank" for any of 5 million concurrent players, updated on every match end, sub-millisecond read latency required. Data is ephemeral — losing it in a crash and rebuilding from match logs is acceptable. Pick a store.

Answer:
ACCESS PATTERNS
1. Top-10 global ranking → ZREVRANGE leaderboard 0 9
2. "What's my rank" → ZREVRANK leaderboard user_id (point lookup)
3. Updated on every match end → moderate write volume, ZADD leaderboard score user_id
4. Sub-ms read latency required
5. Data loss on crash acceptable, rebuildable from match logs → durability can be relaxed

DECISION: Redis (key-value / in-memory), single Sorted Set keyed by leaderboard_id,
member = user_id, score = raw score.

WHY (four axes)
- Query patterns: a sorted set is a single structure that natively answers both
  dominant patterns — ZREVRANGE for top-N, ZREVRANK for a specific user's
  position — without a separate index or dual-write to keep in sync.
- Consistency: no ACID requirement; a slightly stale rank between match-end and
  the next read is acceptable, as long as a rank is always returned (AP-leaning).
- Scale/latency: 5M users' worth of (user_id, score) pairs is small enough to
  fit in memory on a single node (or a small Redis Cluster). Because it's
  in-memory, both ZADD and ZREVRANGE are true sub-millisecond operations —
  not achievable on a disk-backed store, and not reliably achievable on
  DynamoDB without adding DAX (which is itself an in-memory layer).
- Data shape: score updates are O(log N), top-K reads are O(log N + K), rank
  lookups are O(log N) — all against the same structure, so there's no risk
  of two representations (a "rank table" and a "score table") drifting apart.

TRADE-OFF
- Single-node memory ceiling — the whole leaderboard must fit in RAM; if the
  entity count grows past one node's memory, you need Redis Cluster and now
  a cross-shard merge to get an exact global top-10 (each shard's local top-10
  isn't guaranteed to contain the true global top-10 unless you know shard
  boundaries relative to score distribution).
- Durability is opt-in and best-effort (RDB snapshot / AOF) — this is only
  acceptable because the scenario explicitly allows rebuilding from match
  logs; if leaderboard state were the source of truth, this would be
  disqualifying.
- No ad hoc queries, no secondary indexes beyond what the sorted set gives you
  — anything outside "by score" access needs a different structure entirely.

SWITCH CONDITION
I'd move away from a single in-memory sorted set if the leaderboard needed to
be the durable source of truth (not reconstructable from logs) or needed
per-segment/filtered leaderboards (e.g., "top 10 in my friends list," "top 10
in my region") at a cardinality that no longer fits cleanly in one structure —
at that point a hybrid (Redis for the hot global leaderboard, a durable store
for segment queries) becomes worth the added complexity.

## Q5 — Social Recommendation Engine
"People you may know" needs mutual-friend and friend-of-friend-of-friend (3-hop) traversal across a graph with hundreds of millions of edges, computed near-real-time as connections change. What's your data model, and what breaks if you tried to do this relationally?

Answer:
ACCESS PATTERNS
1. Bounded 3-hop traversal (friend, friend-of-friend, friend-of-friend-of-friend)
   — not unbounded; a small fixed hop count that's still expensive relationally
2. Near-real-time query freshness — traversal results should reflect a
   connection added moments ago, not necessarily high write throughput
3. Hundreds of millions of edges, continuously changing

DECISION: Neo4j (graph DB). Person = node, friendship = edge.

WHY (four axes)
- Query patterns: native multi-hop traversal is the core requirement — this
  is what the family exists for.
- Consistency: a recommendation reflecting a connection a few seconds late is
  fine — eventual consistency on newly added edges is acceptable, there's no
  correctness invariant at stake.
- Data shape: person-to-person relationships map directly to nodes and edges,
  no impedance mismatch.
- Scale: hundreds of millions of edges likely exceeds a single instance —
  this needs Neo4j clustering (or an alternative), and clustering is where
  the sharding trade-off below bites hardest.

WHAT BREAKS RELATIONALLY
A 3-hop friend query is 3 self-joins on a `friendships` table. The mechanism
that makes this expensive: every hop needs an indexed lookup, and the result
set balloons at each hop by the average node degree (a user with 500 friends
turns hop 2 into up to 250,000 candidate rows before hop 3 even runs). A
native graph DB uses index-free adjacency — each node stores direct pointers
to its neighbors, so a hop is a pointer traversal, roughly O(1) relative to
total graph size, not an indexed join over the whole edge table.

TRADE-OFF
- Sharding a graph DB is hard — edges routinely cross shard boundaries, so
  cross-shard traversal loses the index-free-adjacency advantage entirely.
- Index-free adjacency itself breaks down on supernodes: a user with millions
  of connections makes even native traversal expensive, because the pointer
  fan-out at that one node is what balloons now, not the join.

SWITCH CONDITION
I'd move away from live graph traversal toward a precomputed batch layer
(e.g., Spark GraphX computing candidate recommendations offline, served from
a fast KV/cache) if the workload shifted from bounded point-to-point queries
to full-graph analytics (global ranking, community detection) — or if
supernodes made live traversal latency unpredictable enough that a stale
precomputed answer became preferable to a slow live one.