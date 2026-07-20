# 7.7 Cross-Shard Queries and Distributed Joins

> **Topic:** Topic 7 — Data Partitioning / Sharding
> **Phase:** B — Scalability Branch
> **Date studied:** 2026-07-19

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

Once data is spread across N shards, any query that can't be answered from a single shard becomes a distributed problem. If the query includes the **partition key**, a router sends it to exactly one shard — cheap and fast. If it doesn't (filter by a non-key column, join two tables sharded on different keys, aggregate globally), the system must **fan out to many or all shards, wait for the slowest, and merge** the results. That fan-out is where sharded systems get slow, expensive, and operationally painful. This subtopic is about recognizing which queries are single-shard vs cross-shard, and the small menu of techniques used to make the expensive ones acceptable: scatter-gather, denormalization, co-partitioning, broadcast/replicated tables, global secondary indexes, and offloading to a separate read/analytics store.

### 🎯 What to Focus On

**1. Single-shard vs cross-shard is decided by the partition key.** The single most important habit: for every important query, ask "does this query carry the shard key?" If yes → one shard. If no → scatter-gather. Your shard-key choice *is* your query-performance design.

**2. Scatter-gather and tail-latency amplification.** A query fanned out to N shards completes only when the **slowest** shard responds. This converts your average latency into your worst-case latency, and it gets worse as N grows. Know why, and know the throughput cost (1 logical query → N physical queries).

**3. The distributed-join toolkit.** Three canonical strategies: **broadcast/replicated** (small table copied to every shard), **co-located/co-partitioned** (both tables sharded on the join key), and **shuffle/repartition** (move rows over the network to align keys). Know when each applies and their costs.

**4. Denormalization and read models.** The most common production answer is to avoid the cross-shard join entirely — pre-join at write time, duplicate data, or maintain a separately-sharded materialized view (CQRS). You trade write amplification and storage for single-shard reads.

**5. Aggregations aren't all mergeable.** SUM/COUNT/MIN/MAX merge cleanly from partial results. AVG works via SUM/COUNT. But **COUNT(DISTINCT), median/percentiles, and top-K are not trivially mergeable** — you need approximation (HyperLogLog, t-digest) or a second pass.

---

## 1. 🎯 Goal of This Subtopic

After studying this, you should be able to:

- Classify any query against a sharded dataset as **single-shard** or **cross-shard** based on whether it carries the partition key.
- Explain **scatter-gather** end to end — the coordinator's role, why latency is governed by the slowest shard, and the throughput multiplier.
- Pick the right **distributed-join strategy** (broadcast, co-located, or shuffle) for a given pair of tables and justify it.
- Propose **denormalization, co-partitioning, global secondary indexes, or a separate read/OLAP store** to eliminate a hot-path cross-shard query, and state the trade-off you're accepting.
- Reason about which **aggregations** merge cleanly across shards and which require approximation.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can look at a query and instantly say whether it's single-shard or a scatter-gather, and explain why
- [ ] Can explain tail-latency amplification: why fanning out to N shards pushes overall latency toward the p99.x of a single shard, and gets worse with N
- [ ] Can name and contrast the three distributed-join strategies (broadcast / co-located / shuffle) and pick one for a given schema
- [ ] Can propose at least three ways to serve a query on a non-partition-key column (global secondary index, denormalized copy, separate search/OLAP store) and state each trade-off
- [ ] Can explain why COUNT(DISTINCT), median, and top-K don't merge like SUM/COUNT, and name an approximation (HLL, t-digest) for each

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move on until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] Read **DDIA Chapter 6 (Partitioning)** — Kleppmann — especially "Partitioning and Secondary Indexes" (local vs global/term-partitioned) and "Request Routing"
- [ ] Read the **Citus documentation on distributed joins and reference tables** (https://docs.citusdata.com/en/stable/develop/reference_sql.html) — co-located joins, reference tables, repartition joins
- [ ] Read **Vitess "Query Serving" / VTGate scatter-gather docs** (https://vitess.io/docs/reference/query-serving/) — how a MySQL-sharded system routes and scatters
- [ ] Read **Sections 4–9** (Cheatsheet → How It Works) of this doc carefully — don't skim
- [ ] Re-read the **Cheatsheet** (Section 4) and try to recite the decision map from memory

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **Core Definition** from memory, then compare
- [ ] Explain **First Principles** out loud: what breaks the moment you shard, and why a single-node join no longer works
- [ ] Reconstruct the **scatter-gather flow** and the **three join strategies** from memory
- [ ] Restate each **Trade-off** row in your own words — if you can't explain the cost, you don't own it yet

### Phase 3 — Apply 🔧 💪💪💪💪
*Goal: Connect to real systems and simulate interview scenarios.*

- [ ] Go through **Real-World System Examples** (Section 10) — verify each claim and add anything missed to **My Notes**
- [ ] Practice the **Interview Application** (Section 12) out loud — say the trigger phrases and your response as if live
- [ ] Work through **Common Misconceptions** (Section 13) — for each, explain *why* it's wrong, not just that it is
- [ ] Trace the **Relationships** (Section 14) — can you explain each connection without looking?

### Phase 4 — Validate 🧪 💪💪💪💪💪
*Goal: Confirm you actually own it, not just recognize it.*

- [ ] Answer every **Self-Check Quiz** question (Section 15) out loud without notes
- [ ] Recite the **Cheatsheet** (Section 4) from memory — if you can't, re-do Phase 2
- [ ] Tick off items in **What Mastery Looks Like** (Section 2) — only if you can demonstrate on demand
- [ ] Teach this concept to an imaginary interviewer for 2 minutes without hesitation

---

## 4. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

### 🧠 Concept Mindmap (keep this in your head)

```
                       ┌───────────────────────┐
              Single   │  CROSS-SHARD QUERIES  │   Cross
              shard ◄──┤   & DISTRIBUTED JOINS ├──► shard
                       └───────────┬───────────┘
                                   │
        ┌───────────────┬──────────┼───────────┬──────────────────┐
        ▼               ▼          ▼           ▼                  ▼
  ROUTING          SCATTER-      DISTRIBUTED   AVOID IT         AGGREGATION
  Has shard key?   GATHER        JOINS         (best answer)    Merge partials
  ├ yes→1 shard    Coordinator   ├ Broadcast   ├ Denormalize    ├ SUM/COUNT/MIN ✓
  └ no →fan-out    fans to all,  │  (small tbl)├ Co-partition   ├ AVG = SUM/COUNT
                   waits slowest,├ Co-located  ├ Global 2nd idx ├ DISTINCT→HLL
                   merges result │  (same key) ├ CQRS read model├ median→t-digest
                   ⚠ tail-lat    └ Shuffle     └ Search/OLAP    └ top-K→approx
                     amplified      (repartition)  store
```

### 🗺️ Cross-Shard Query Decision Map

```
Query hits a sharded table. Does it carry the PARTITION KEY?
├── YES ──────────────────────────────────────────► Single-shard query (cheap) ✅
│                                                    Router → 1 shard → done
└── NO
    │
    ▼
Is it a point/range filter on ONE non-key column you query often?
├── YES ──────────────────────────────► Global Secondary Index (term-partitioned)
│                                        or a denormalized copy sharded by that column
└── NO
    │
    ▼
Is it a JOIN of two tables?
├── YES
│   ├── One table small & static? ─────► BROADCAST / reference table (replicate to all shards)
│   ├── Both shardable on join key? ────► CO-LOCATED join (co-partition, no network shuffle)
│   └── Neither? ───────────────────────► SHUFFLE / repartition join (expensive) — or denormalize
└── NO (ad-hoc filter / global aggregate)
    │
    ▼
Can you tolerate fan-out latency & cost?
├── YES (low QPS, ad-hoc) ─────────────► SCATTER-GATHER via coordinator
└── NO (hot path, high QPS) ───────────► Maintain a separate READ MODEL / OLAP store
                                          (CQRS, materialized view, Elasticsearch, warehouse)
   ⚠️  Scatter-gather latency = SLOWEST shard. Cost = N physical queries per logical query.
   ⚠️  Never let the hot path depend on a fan-out you can design away with the shard key.
```

```
§ 1  WHY IT EXISTS
Sharding buys horizontal scale but breaks the single-node assumption that "all the
data I need is local." A join or a filter on a non-key column can no longer be resolved
by one machine. Cross-shard techniques exist to answer queries whose data lives on
multiple shards — without giving up the scale that sharding bought you.

§ 2  THE ONE QUESTION
For EVERY important query ask: "Does it carry the partition key?"
  YES → router sends it to exactly ONE shard. Fast, cheap, scales linearly.
  NO  → the system must fan out (scatter) to many/all shards and merge (gather).
Your shard-key choice IS your query design. Pick it around the dominant query.

§ 3  SCATTER-GATHER
Coordinator (VTGate / mongos / ES coordinating node) receives the query,
broadcasts to all shards, each executes locally, coordinator merges + sorts + limits.
Latency  = time of the SLOWEST shard (tail-latency amplification).
Throughput = 1 logical query becomes N physical queries → N× load.
Good for: low-QPS, ad-hoc, analytical reads. Bad for: high-QPS hot paths.

§ 4  DISTRIBUTED JOIN — 3 STRATEGIES
BROADCAST / reference: copy a SMALL, slow-changing table to every shard.
    Join runs locally on each shard. Cost: storage × N + write fan-out. (Citus reference table)
CO-LOCATED / co-partition: shard BOTH tables on the join key so matching rows
    live on the same shard. Zero network shuffle. Best option when feasible.
SHUFFLE / repartition: rows are re-hashed on the join key and moved over the
    network so partitions align, then joined. Most expensive; last resort.

§ 5  AVOID THE JOIN (usually the real answer)
Denormalize: pre-join at write time; store data together → single-shard read.
Global secondary index: separate index sharded by the lookup column (extra hop, lag).
CQRS / materialized view: maintain a second copy sharded for the read pattern.
Offload: push cross-cutting queries to search (Elasticsearch) or a warehouse (OLAP).
Trade: write amplification, storage, and duplicate-data consistency for read simplicity.

§ 6  AGGREGATIONS ACROSS SHARDS
Mergeable (partial → combine):  SUM, COUNT, MIN, MAX.  AVG = SUM/COUNT.
NOT trivially mergeable:
  COUNT(DISTINCT) → HyperLogLog (mergeable sketches)
  median / p99     → t-digest / q-digest
  top-K            → per-shard top-K then merge (approximate; can miss true top-K)
GROUP BY: each shard groups locally, coordinator re-groups + re-aggregates.

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "Query by a field that isn't the shard key?"  → global index / denormalize / OLAP
→ "Join orders and users on different shards?"  → co-locate, broadcast, or denormalize
→ "Global leaderboard / analytics across shards?" → materialized read model / OLAP
GOTCHA: Candidates pick a shard key for even data distribution, then discover the
  dominant query filters/joins on a DIFFERENT column → every hot request scatters.
  Choose the shard key around the hot query's access pattern FIRST.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

A **cross-shard query** is any query whose required data spans more than one partition — because it doesn't carry the partition key, joins tables sharded on different keys, or aggregates across the whole dataset — forcing the system to fan out to multiple shards and merge the results, rather than resolving it on a single shard.

---

## 6. 📦 Core Concepts

> *The essential building blocks — the terms and ideas you must have solid before going deeper.*

### Single-Shard vs Cross-Shard Query (Query Routing)
A router/coordinator inspects the query. If it can determine the partition key from the query (e.g., `WHERE user_id = 42` when sharded on `user_id`), it routes to the **one** shard that owns that key — a *targeted* query. If the partition key is absent (`WHERE email = ...`, or a range on a non-key column), the router must send the query to **all** shards — a *scatter* query. This single distinction drives everything else in the topic: performance, cost, and complexity all hinge on whether the query is targeted or scattered.

### Scatter-Gather (Fan-out / Fan-in)
The pattern for answering a query that no single shard can satisfy: a coordinator **scatters** the query to many/all shards, each shard executes locally and returns partial results, and the coordinator **gathers** them — merging, re-sorting, re-aggregating, and applying `LIMIT` globally. The coordinator can only return once every shard it contacted has responded, so latency is governed by the slowest shard. Elasticsearch's query-then-fetch and MongoDB's `mongos` merge are canonical implementations.

### Distributed Join
Joining two tables that are sharded on different keys, so matching rows may live on different shards. Three canonical strategies: **broadcast** (replicate a small table to every shard so the join is local), **co-located** (co-partition both tables on the join key so matching rows are always on the same shard), and **shuffle/repartition** (re-hash and move rows over the network to align partitions, then join). The whole game is minimizing data movement.

### Denormalization & Data Duplication
Rather than join at read time, pre-join or duplicate data at write time so the read touches a single shard. E.g., embed the user's name into each order document, or store a copy of an order under both `user_id` and `merchant_id` shard keys. It converts an expensive distributed read into a cheap targeted read, at the cost of write amplification, extra storage, and the burden of keeping duplicates consistent.

### Global vs Local Secondary Index
A **local (document-partitioned)** secondary index lives on each shard and only indexes that shard's data — so a lookup by the indexed column still scatters to all shards. A **global (term-partitioned)** secondary index is itself sharded by the indexed term, so a lookup is targeted to the shard owning that term — but writes now update an index on a *different* shard, adding a network hop and consistency lag. DynamoDB GSIs and Vitess secondary vindexes are global-style; Cassandra's built-in secondary indexes are local.

### Read Model / CQRS / Materialized View
Maintain a **second, independently-sharded copy** of the data optimized for the query pattern the primary sharding can't serve. Writes update the primary; a stream/ETL keeps the read model in sync. Cross-cutting queries (search, analytics, leaderboards) hit the read model or an OLAP/search engine instead of scattering across the OLTP shards.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

On a single database node, every join, filter, and aggregation is "free" in the topological sense: all the data is co-located, so the query planner can join, sort, and aggregate without crossing a network. Sharding deliberately breaks that. To get horizontal scale — more data and more throughput than one machine can hold — you split the data across nodes by a partition key. The instant you do that, you lose the guarantee that the data a query needs lives together. A query filtering on the shard key still works fine. But a query that joins on a different column, filters on a non-key attribute, or aggregates globally now needs data from machines that don't know about each other.

Cross-shard query techniques exist to bridge that gap: to answer multi-partition questions **without** collapsing back to a single node (which would forfeit the scale) and **without** paying unbounded latency. Every technique in this subtopic is a different point on the trade-off curve between *where the work happens* (read time vs write time), *how much data moves* (broadcast, co-locate, shuffle), and *how fresh the answer is* (synchronous scatter vs eventually-consistent read model). The reason there's no single "right" answer is that the fundamental tension — data locality vs distribution — can't be eliminated, only relocated.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason fast — especially under interview pressure.*

### Model 1: "Ask One Person vs. Ask the Whole Office"
A single-shard query is like asking the one colleague who has the file you need — instant. A cross-shard scatter is like emailing the entire office "does anyone have anything on customer X?" and waiting until the *last, slowest* person replies before you can compile the answer. This captures both costs at once: you've generated N times the work, and your response time is set by the slowest responder, not the average. *Where it breaks down:* real coordinators can early-terminate or query only a subset of shards if the router can prune — it's not always literally everyone.

### Model 2: The Three Ways to Join Two Filing Cabinets in Different Rooms
Two cabinets (tables) in different rooms (shards), and you need matching records. **Broadcast:** photocopy the small cabinet into every room so any room can match locally. **Co-locate:** re-file both cabinets so related records always sit in the same room from now on. **Shuffle:** physically carry folders between rooms until matching ones are together, then match. The costs are obvious in the physical version: photocopying wastes space, re-filing is a one-time reorganization, and carrying folders every query is exhausting. That's exactly the cost profile of the three join strategies.

### Model 3: Move the Work to Write Time
Every cross-shard read problem can be reframed as: "What if I'd done this work when the data was written instead of when it's read?" Denormalization, materialized views, and CQRS read models are all this move — pay once at write time so reads are cheap and single-shard. This works because reads usually vastly outnumber writes, so amortizing the join cost onto the rarer operation is a win. *Where it breaks down:* when writes are frequent and reads are rare, or when the duplicated data must be strongly consistent — then write-time pre-computation becomes the bottleneck and a consistency hazard.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step explanation of the internal mechanism.*

**Query routing (the fork in the road):**
1. A client sends a query to the coordinator/router (VTGate, `mongos`, Citus coordinator, ES coordinating node).
2. The router parses the query and tries to extract the partition key.
3. **Targeted path:** key found → hash/range-map it to the owning shard → forward the query to that one shard → return its result directly. Latency ≈ one shard hop.
4. **Scatter path:** key absent → forward the query to all (or a pruned subset of) shards.

**Scatter-gather (fan-out read):**
1. Coordinator broadcasts the query (or a rewritten per-shard version) to every target shard in parallel.
2. Each shard executes locally against its own data and returns partial results (rows, partial aggregates, or per-shard top-K).
3. Coordinator **gathers**: merges rows, applies global `ORDER BY`, re-runs aggregation over partials, and applies the global `LIMIT`/`OFFSET`.
4. Coordinator returns the merged result. **It cannot return until the slowest contacted shard responds** → tail-latency amplification. If one shard is slow or down, the whole query stalls or partially fails.

**Distributed join — the three strategies in detail:**
- **Broadcast / reference table:** The small table is replicated in full to every shard. The join executes independently on each shard between the local big-table partition and the local full copy of the small table. Correct because every shard has all rows of the small side. Cost: storage overhead × N shards, and every write to the small table must fan out to all shards.
- **Co-located (co-partitioned) join:** Both tables are sharded on the join column with the same function, so a given join key's rows from both tables always land on the same shard. The join is then purely local, no data movement. This is the gold standard — but it only works if you can shard both tables on that key (and you can't co-locate on two different keys at once).
- **Shuffle / repartition join:** When neither side can be co-located, the engine re-partitions one or both tables on the join key on the fly — each shard hashes its rows by the join key and ships them to the shard responsible for that key range — then performs local joins on the aligned data. Correct but network-heavy; used by Citus repartition joins, Spark, and MPP warehouses.

**Aggregation merge:**
- Distributive/algebraic aggregates compute in two passes: each shard computes a partial (`SUM`, `COUNT`, `MIN`, `MAX`, or `SUM`+`COUNT` for `AVG`), and the coordinator combines partials into the final answer.
- Holistic aggregates (`COUNT(DISTINCT)`, `median`, percentiles, exact top-K) cannot be exactly computed from independent per-shard partials in one pass. Systems either (a) approximate with mergeable sketches — HyperLogLog for distinct counts, t-digest/q-digest for percentiles — or (b) route all relevant rows to one place (expensive) for an exact answer.

**Failure / edge cases:**
- A slow or unavailable shard stalls the whole scatter; production systems add per-shard timeouts and may return partial results (ES `_shards.failed`), which sacrifices completeness.
- `LIMIT k` on a scatter must request `k` (or more) from *every* shard and re-limit at the coordinator, because the global top-k can come from any shard — you can't push a small limit blindly.
- Cross-shard **writes** in a transaction need distributed commit (2PC/Paxos), which is slow and blocking — often avoided entirely by co-locating the entities that must change together.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How Cross-Shard Queries / Joins Apply | Notes |
|--------|----------------------------------------|-------|
| **Vitess (YouTube MySQL sharding)** | VTGate routes targeted queries by primary vindex; queries without it become scatter-gather across shards. Secondary vindexes provide global-index-style targeting. Cross-shard joins are supported but limited and discouraged on the hot path. | Vitess deliberately nudges you toward single-shard queries; cross-shard joins can be executed but with cost warnings |
| **Citus (distributed Postgres)** | First-class model: **reference tables** (broadcast/replicated to all nodes), **co-located distributed tables** (shard on the same distribution column for local joins), and **repartition joins** (shuffle) when neither fits | Cleanest vocabulary for the three join strategies — worth citing by name in interviews |
| **MongoDB (sharded)** | `mongos` routes queries containing the shard key to a single shard; queries without it are **scatter-gather** to all shards. `$lookup` (join) across sharded collections is restricted and expensive | Classic advice: include the shard key in your queries or pay the fan-out |
| **Elasticsearch** | Every search fans out to all primary/replica shards of an index (query-then-fetch); the coordinating node merges, re-sorts, and applies size. Aggregations reduce partial results per shard | The canonical scatter-gather engine; often used *as* the cross-cutting read model in front of a sharded OLTP store |
| **DynamoDB** | Queries by partition key are targeted; **Global Secondary Indexes (GSI)** are separately partitioned by the index key to make non-key lookups targeted; `Scan` reads every partition (avoid on hot paths) | GSIs are the textbook global/term-partitioned index; they're eventually consistent with the base table |
| **CockroachDB / Google Spanner** | Distributed SQL planners perform lookup joins, hash joins, and merge joins across ranges, using data locality and index selection to minimize cross-node traffic | Show that "just use distributed SQL" still pays the same physics — the planner is choosing broadcast/co-located/shuffle under the hood |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Scatter-gather** answers any ad-hoc query without pre-planning the shard key around it | Tail-latency amplification (bound by slowest shard) + N× throughput cost; degrades as shard count grows |
| **Denormalization** turns an expensive cross-shard join into a cheap single-shard read | Write amplification, extra storage, and duplicate-data consistency burden (updates must touch every copy) |
| **Broadcast / reference table** makes joins fully local on every shard | Only viable for small, slow-changing tables; storage × N and every write fans out to all shards |
| **Co-located join** eliminates network shuffle entirely — the gold standard | Requires both tables shardable on the join key; you can only co-locate on one key, so it constrains other access patterns |
| **Global secondary index** makes non-key lookups targeted instead of scattered | Extra network hop + index-update consistency lag; the index itself is a second sharded structure to maintain |
| **Separate read model / OLAP store** offloads cross-cutting queries off the OLTP hot path | Data duplication, sync pipeline complexity, and eventual-consistency staleness between primary and read model |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "We shard by `user_id`, but now we need to query by `email` / find all orders in a date range. How?"
- "How do you join orders and users when they live on different shards?"
- "How would you build a global leaderboard / run analytics across all the shards?"
- "What happens to this query as we go from 10 shards to 1,000 shards?"

**What you say / do:**
This appears in the **deep-dive / data-model** phase, right after you've proposed a shard key. Proactively call out: "With this shard key, query A is single-shard, but query B doesn't carry the key, so it would scatter-gather across all shards — that's a problem on the hot path." Then reach for the cheapest fix that fits: co-locate the joined entities if you can, add a global secondary index or denormalized copy for the non-key lookup, and push genuinely cross-cutting queries (search, analytics) to a separate read model or OLAP store. Naming Citus's reference/co-located/repartition vocabulary or DynamoDB GSIs signals depth.

**The trade-off statement (memorize this pattern):**
> "If I keep this as a live cross-shard join via scatter-gather, I get flexibility but pay tail-latency amplification and N× load — unacceptable on a hot path at high QPS. So instead I'll [co-locate these two entities on the join key / denormalize the user fields into the order / maintain a search read model], accepting [a one-time reshard / write amplification and duplicate-data consistency / eventual-consistency staleness] in exchange for cheap single-shard reads on the hot path."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** "A distributed SQL database (Spanner, Cockroach, Citus) means I don't have to worry about cross-shard joins."
  ✅ **Reality:** The planner hides the *syntax*, not the *physics*. Under the hood it still chooses broadcast, co-located, or shuffle, and a badly-designed schema still triggers expensive network shuffles. You must still design the shard key and co-location around your join pattern.

- ❌ **Misconception:** "Scatter-gather latency is roughly the average shard latency."
  ✅ **Reality:** It's the *slowest* shard's latency. Fanning out to N shards effectively samples the tail of the latency distribution N times, so overall latency trends toward a high percentile of a single shard — and it gets worse as N grows (tail-latency amplification).

- ❌ **Misconception:** "A secondary index lets me query the non-shard-key column efficiently."
  ✅ **Reality:** Only a *global (term-partitioned)* index does. A *local* secondary index (e.g., Cassandra's built-in) still requires scatter-gather to every shard, because each shard only indexes its own rows. Know which kind your database gives you.

- ❌ **Misconception:** "All aggregations just merge — sum the sums, done."
  ✅ **Reality:** SUM/COUNT/MIN/MAX and AVG (via SUM/COUNT) merge cleanly. But COUNT(DISTINCT), median/percentiles, and exact top-K do **not** compose from independent per-shard partials — you need approximation (HyperLogLog, t-digest) or a costly second pass to be exact.

- ❌ **Misconception:** "Denormalizing fixes cross-shard reads for free."
  ✅ **Reality:** It moves the cost to write time and creates duplicate data. Now every update must fan out to all copies, and you inherit a consistency problem — the very thing you were trying to avoid, relocated to the write path.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** **7.2 Hash Partitioning** and **7.3 Range Partitioning** — the partition strategy determines which queries are single-shard vs scatter (hash destroys range locality → range queries scatter; range keeps it → point lookups on other columns scatter). Also **7.1 Horizontal vs Vertical Partitioning** — sharding is what creates the cross-shard problem in the first place.
- **Enables:** **CQRS / materialized read models**, **search infrastructure (Topic on search/Elasticsearch)**, and **OLAP/analytics pipelines** — all of which exist largely to serve the cross-cutting queries that a sharded OLTP store can't answer cheaply. Also underpins **API design for paginated/aggregated endpoints** over sharded data.
- **Tension with:** **7.6 Hot Partitions** — the shard key you pick to avoid hot partitions (even distribution) may be exactly the wrong key for your dominant join/filter, forcing scatter-gather; you often can't optimize distribution and query locality with a single key. Also in tension with **distributed transactions / 2PC (Topic 17 consistency)** — cross-shard writes need distributed commit, which co-partitioning tries to avoid.

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. You shard `orders` by `user_id`. Classify each query as single-shard or cross-shard and explain why: (a) `WHERE user_id = 42`, (b) `WHERE order_id = 'abc'`, (c) `WHERE status = 'shipped' AND created_at > ...`.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6 (routing) and Section 9.*

2. Explain tail-latency amplification. Why does fanning a query out to 100 shards make the p99 worse than the p99 of a single shard?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 9 (scatter-gather) and Section 13.*

3. You must join `orders` (sharded by `user_id`) with `products` (a small, rarely-changing catalog). Which distributed-join strategy do you choose and why? What if instead you had to join `orders` with a huge `shipments` table sharded by `shipment_id`?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 9 (three join strategies).*

4. Name a real production system for each of: (a) scatter-gather search, (b) reference/broadcast tables, (c) a global secondary index. Describe how each handles the non-key query.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 10.*

5. Your sharded store must return a global "count of distinct active users today" and the "p99 request latency across all shards." Why can't you just sum per-shard results, and what would you actually do?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 9 (aggregation merge) and Section 13.*

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **Designing Data-Intensive Applications, Chapter 6 (Partitioning)** — Kleppmann — "Partitioning and Secondary Indexes" (local vs global/term-partitioned) and "Request Routing" are the core of this topic
- [ ] **Citus documentation — Distributed Query Execution & Table Co-location** — https://docs.citusdata.com/en/stable/develop/reference_sql.html — reference tables, co-located joins, repartition joins with clear vocabulary
- [ ] **Vitess Query Serving docs** — https://vitess.io/docs/reference/query-serving/ — VTGate routing, scatter-gather, and vindexes in a MySQL-sharded system
- [ ] **MongoDB Sharding — Targeted vs Broadcast Operations** — https://www.mongodb.com/docs/manual/core/sharded-cluster-query-router/ — how `mongos` decides to target one shard vs scatter
- [ ] **"The Tail at Scale" (Dean & Barroso, CACM 2013)** — https://research.google/pubs/pub40801/ — the definitive treatment of tail-latency amplification in fan-out systems

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

