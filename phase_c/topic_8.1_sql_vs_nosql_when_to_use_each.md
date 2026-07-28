# 8.1 SQL vs. NoSQL — When to Use Each

> **Topic:** Topic 8 — Database Fundamentals
> **Phase:** C — Data Storage Branch
> **Date studied:** 2026-07-24

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

This is the first real **storage decision** in a system design interview, and it's the one candidates most often get wrong — not because they pick the "wrong" database, but because they justify it badly. "SQL vs. NoSQL" is a misleading name: the query language is the least important part of the difference. The real axes are the **data model** (relations vs. key-value/document/wide-column/graph), the **schema contract** (enforced on write vs. interpreted on read), the **distribution model** (scale-up-then-shard vs. partition-native), and the **transaction/consistency model** (multi-row ACID vs. single-key atomicity with tunable consistency).

The central tension is this: a relational database is **query-flexible and access-pattern-agnostic** — you model the data once and can ask questions you hadn't thought of yet. A NoSQL store is **access-pattern-specific** — you model the data *around the queries you know you'll run*, and in exchange you get predictable latency and near-linear horizontal scale. Mastering this subtopic means being able to look at a set of entities, relationships, and query patterns and confidently say which model fits, why, and what you're giving up. Modern databases have converged heavily (Postgres has JSONB, DynamoDB has transactions, Spanner has both SQL and horizontal scale), so the mature answer is almost never "NoSQL because scale."

### 🎯 What to Focus On

**1. Model the access patterns before the database.** The decision is driven by *how the data is read and written*, not by how it "looks." Write down the top 3–5 queries by QPS first. If you can't enumerate them, that itself is an argument for relational.

**2. Know the four NoSQL families and what each is actually for.** Key-value (Redis, DynamoDB), document (MongoDB, DynamoDB), wide-column (Cassandra, HBase, Bigtable), graph (Neo4j). "NoSQL" is not one thing — saying "I'd use NoSQL" without naming a family and a product is an instant depth failure.

**3. Schema-on-write vs. schema-on-read is a real trade-off, not a free lunch.** NoSQL doesn't remove the schema; it moves it into your application code and makes every reader responsible for handling every historical shape of the data. Know who pays and when.

**4. Joins and transactions are what you actually give up.** Denormalization, application-side joins, and single-item atomicity are the practical costs. Be able to say exactly which query becomes expensive and what you'd do instead.

**5. "SQL doesn't scale" is false — know the real scaling story.** A single well-tuned Postgres node handles tens of thousands of QPS and terabytes of data. Sharding a relational DB is possible (Vitess, Citus) but bolt-on; NoSQL stores are partition-native from day one. That distinction — *bolt-on vs. built-in* — is the honest version of the scale argument.

---

## 1. 🎯 Goal of This Subtopic

After studying this, you should be able to:

- Given a data model and a set of access patterns, **choose relational or a specific NoSQL family** and justify the choice on schema flexibility, query pattern, consistency needs, and scale — not on buzzwords.
- **Name the four NoSQL families**, give a canonical product for each, and describe the access pattern each is optimized for.
- Explain **what you actually lose** when you leave relational: multi-entity ACID transactions, ad-hoc queries, server-side joins, and referential integrity — and name the workaround for each.
- Explain **schema-on-write vs. schema-on-read** and articulate who pays the cost of a schema change in each model.
- Push back correctly on the claim **"we need NoSQL because we need scale"** by explaining what a single relational node can actually do and what partition-native means.
- Design a **polyglot persistence** answer: which parts of a system go in which store, and why.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can classify a given workload (entities + top queries + scale + consistency needs) as relational or a **named** NoSQL family, and defend it in under 90 seconds
- [ ] Can name all four NoSQL families with a production product and the exact access pattern each is built for
- [ ] Can explain schema-on-write vs. schema-on-read and describe what happens operationally when the shape of the data changes in each
- [ ] Can state precisely what breaks when you denormalize into a document store — and name at least three mitigations (app-side join, transactions/`TransactWriteItems`, CDC-maintained read model)
- [ ] Can rebut "SQL doesn't scale" with concrete numbers and the bolt-on vs. partition-native framing
- [ ] Can describe how modern systems have converged (Postgres JSONB, MongoDB multi-doc ACID, DynamoDB transactions, Spanner/CockroachDB) and why that makes "SQL vs. NoSQL" a false binary

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move on until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] Read **DDIA Chapter 2 (Data Models and Query Languages)** — Kleppmann — the definitive treatment of relational vs. document vs. graph, the object-relational mismatch, and "the great debate"
- [ ] Read the **Amazon DynamoDB Paper (USENIX ATC 2022)** — https://www.usenix.org/conference/atc22/presentation/elhemali — why a partition-native store exists and what it deliberately gives up
- [ ] Read **Alex DeBrie, "The DynamoDB Book" — single-table design chapters** (or his free article https://www.alexdebrie.com/posts/dynamodb-single-table/) — the clearest explanation of modeling around access patterns
- [ ] Read **Sections 4–9** (Cheatsheet → How It Works) of this doc carefully — don't skim
- [ ] Re-read the **Cheatsheet** (§4) and try to recite the decision map from memory

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **Core Definition** and the four NoSQL families from memory, then compare
- [ ] Explain **First Principles** out loud: what did the web-scale companies of 2005–2010 hit that relational couldn't do, and *why*
- [ ] Reconstruct the **decision map** (§4) from memory on paper — every gate, in order
- [ ] Restate each **Trade-off** row in your own words — if you can't explain the cost, you don't own it yet

### Phase 3 — Apply 🔧 💪💪💪💪
*Goal: Connect to real systems and simulate interview scenarios.*

- [ ] Go through **Real-World System Examples** (§10) — verify each claim and add anything missed to **My Notes**
- [ ] Take three systems you already know (URL shortener, Twitter feed, e-commerce checkout) and write the storage choice + justification for each
- [ ] Practice the **Interview Application** (§12) out loud — say the trigger phrases and your response as if live
- [ ] Work through **Common Misconceptions** (§13) — explain *why* each is wrong, not just that it is

### Phase 4 — Validate 🧪 💪💪💪💪💪
*Goal: Confirm you actually own it, not just recognize it.*

- [ ] Answer every **Self-Check Quiz** question (§15) out loud without notes
- [ ] Recite the **Cheatsheet** (§4) from memory — if you can't, re-do Phase 2
- [ ] Tick off items in **What Mastery Looks Like** (§2) — only if you can demonstrate on demand
- [ ] Teach this concept to an imaginary interviewer for 2 minutes without hesitation

---

## 4. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

### 🧠 Concept Mindmap (keep this in your head)

```
                          ┌─────────────────────────┐
                 Flexible │    SQL  vs.  NoSQL      │  Predictable
                 queries ◄┤  (data model, not the   ├► scale
                          │      query language)    │
                          └────────────┬────────────┘
                                       │
     ┌──────────────┬──────────────────┼──────────────────┬─────────────────┐
     ▼              ▼                  ▼                  ▼                 ▼
  RELATIONAL     4 NoSQL          THE 4 AXES          WHAT YOU GIVE      CONVERGENCE
  Postgres/      FAMILIES         ├ Data model         UP LEAVING SQL    (false binary)
  MySQL          ├ Key-value      ├ Schema             ├ Server-side     ├ PG JSONB
  ├ Relations    │  Redis/Dynamo  │  on-write vs         joins           ├ Mongo multi-
  │  + joins     ├ Document       │  on-read           ├ Multi-entity    │  doc ACID
  ├ Schema-      │  Mongo/Dynamo  ├ Distribution        ACID             ├ Dynamo Transact
  │  on-write    ├ Wide-column    │  scale-up+shard    ├ Ad-hoc query    │  WriteItems
  ├ Multi-row    │  Cassandra/    │  vs partition-      flexibility      ├ Spanner /
  │  ACID        │  HBase/Bigtbl  │  native            ├ Referential     │  CockroachDB
  ├ Ad-hoc SQL   └ Graph          └ Consistency          integrity       └ "NewSQL" =
  └ Scale-up,       Neo4j            ACID vs BASE      → fix: denormalize,  SQL + horiz
    shard later     traversals       + tunable            app-join, CDC     scale
```

### 🗺️ SQL vs. NoSQL Decision Map

```
START: You need a primary datastore for these entities + these top queries.
   ▼
Q1. Are the access patterns KNOWN and STABLE (you can list the top 3–5 queries)?
├── NO  ──► RELATIONAL. Ad-hoc/evolving queries need a query planner + joins. ✅
│           (Analytics, internal tools, early-stage products, unclear domain.)
└── YES
    ▼
Q2. Do you need MULTI-ENTITY ACID transactions on the hot path?
    (money movement, inventory decrement + order create, double-entry ledger)
├── YES ──► RELATIONAL (or Spanner/CockroachDB if you also need horizontal scale). ✅
└── NO
    ▼
Q3. Is the dominant read a TRAVERSAL over relationships, N hops deep?
    ("friends of friends", fraud rings, recommendation paths)
├── YES ──► GRAPH DB (Neo4j) — or relational + recursive CTE if depth is bounded.
└── NO
    ▼
Q4. What is the shape of the dominant access?
├── Whole object fetched/written by a single key, blob-like value
│        ──► KEY-VALUE (Redis, DynamoDB, Memcached). Sessions, carts, feature flags.
├── Self-contained nested object, queried by id + a few fields
│        ──► DOCUMENT (MongoDB, DynamoDB, Postgres JSONB). Catalogs, user profiles, CMS.
├── Huge volume of writes, queried by partition key + sorted range within it
│        ──► WIDE-COLUMN (Cassandra, HBase, Bigtable). Time series, events, msg history.
└── Mixed / relational-ish  ──► RELATIONAL, and revisit at real scale.
    ▼
Q5. Does one node still fit? (~single-digit TB, ~10–50k QPS, p99 in budget)
├── YES ──► RELATIONAL, single primary + read replicas. Don't distribute prematurely. ✅
└── NO  ──► Either shard relational (Vitess/Citus — bolt-on) OR use the partition-native
            NoSQL store from Q4. Choose partition-native if the write rate is the problem.
   ⚠️  "We need NoSQL for scale" is only true once you've named the single-node ceiling.
   ⚠️  The default answer in an interview is RELATIONAL unless you can name the reason.
   ⚠️  Polyglot is legitimate: Postgres for orders, Redis for sessions, ES for search.
```

```
§ 1  WHY IT EXISTS
Relational DBs assume all data is co-located on one node, so joins, multi-row
transactions and ad-hoc queries are cheap. That assumption broke for the 2000s
web companies: data outgrew one machine, and sharding a relational DB destroys
exactly the features you paid for (cross-shard joins and transactions). NoSQL
stores were built the other way round: assume partitioning FIRST, then only
offer the operations that can be served from one partition. NoSQL didn't remove
work — it moved joins and schema enforcement into the application.

§ 2  THE FOUR AXES (the real difference — not the query language)
DATA MODEL     relations + joins  ⟷  key-value / document / wide-column / graph
SCHEMA         on-write (DB enforces, migration up-front)
               ⟷ on-read (app enforces, every reader handles every old shape)
DISTRIBUTION   scale up, then bolt on sharding (Vitess/Citus)
               ⟷ partition-native: shard key is part of the data model from day 1
CONSISTENCY    multi-row ACID, strong by default
               ⟷ single-item atomic, tunable/eventual (BASE), quorum-configurable

§ 3  THE FOUR NoSQL FAMILIES  (never say just "NoSQL")
KEY-VALUE    Redis, DynamoDB, Memcached — GET/PUT by key; opaque value.
             Sessions, carts, rate-limit counters, feature flags.
DOCUMENT     MongoDB, DynamoDB, Couchbase, PG JSONB — self-contained nested docs;
             secondary indexes on fields. Catalogs, profiles, CMS, event payloads.
WIDE-COLUMN  Cassandra, HBase, Bigtable — partition key + clustering key, rows
             sorted within a partition; LSM write path. Time series, feeds, logs.
GRAPH        Neo4j, Neptune — nodes + edges; multi-hop traversal is O(hops),
             not O(joins). Social graphs, fraud rings, recommendations.

§ 4  USE / AVOID
Use RELATIONAL when: queries are ad-hoc or will evolve; entities are highly
  related; you need multi-entity ACID; the data fits a node (or a few shards);
  you want the DB — not every future engineer — to enforce the schema.
Use NoSQL when: access patterns are known + stable; the dominant read is by one
  key or one partition; you need partition-native horizontal scale for writes;
  the record is naturally self-contained; per-request latency must be flat at
  any data size.
AVOID NoSQL when you can't enumerate your queries — you'll model the wrong keys
  and be forced into scatter-gather or a full re-model.
AVOID relational-by-default at extreme WRITE volume with a natural partition key.

§ 5  WHAT YOU GIVE UP LEAVING RELATIONAL (and the fix)
Server-side joins   → denormalize / duplicate; or app-side join (watch N+1, §8.8)
Multi-entity ACID   → single-item atomicity; DynamoDB TransactWriteItems (≤100 items),
                      Mongo multi-doc txns; or saga/outbox for cross-service
Ad-hoc queries      → GSIs, or stream (CDC) into Elasticsearch / a warehouse
Referential integ.  → app-enforced; orphaned references become a real bug class
Schema enforcement  → moves into app code + every historical document shape

§ 6  NUMBERS TO ANCHOR THE "SCALE" ARGUMENT
Single Postgres/MySQL node: ~10k–50k simple QPS, single-digit TB comfortably,
  vertical scale into the hundreds of GB RAM. Read replicas multiply READS only.
Writes are the real ceiling — one primary, one write path.
DynamoDB: 400 KB max item; ~3,000 RCU / 1,000 WCU per partition (hot-partition cap).
MongoDB: 16 MB max document. Cassandra: keep partitions under ~100 MB / 100k rows.
Rule of thumb: don't distribute until you've named the number you're exceeding.

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "What database would you use here, and why?"  → access patterns first, then pick
→ "We're expecting 100M users / 1M writes per second" → name the single-node ceiling
→ "The schema will change often"                → document store OR PG JSONB column
→ "This has to be transactionally correct (payments)" → relational / Spanner
GOTCHA: Saying "NoSQL because it scales" without naming a FAMILY, a PRODUCT, the
  ACCESS PATTERN it's modeled for, and WHAT YOU GAVE UP. The interviewer is testing
  whether you know that NoSQL buys scale by REMOVING joins and multi-entity ACID —
  not by being magically faster.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

**Relational (SQL) databases** store data as normalized tables with a schema enforced on write and a query planner that can join and filter arbitrarily, optimizing for query flexibility and multi-row ACID correctness on a single node. **NoSQL databases** are a family of stores (key-value, document, wide-column, graph) that abandon some combination of joins, cross-entity transactions, and enforced schema in order to model data directly around known access patterns and partition natively across many nodes.

---

## 6. 📦 Core Concepts

> *The essential building blocks — the terms and ideas you must have solid before going deeper.*

### The Relational Model & Normalization
Data is decomposed into tables of tuples with typed columns; relationships are expressed by foreign keys, and the query planner reassembles them at read time with joins. Each fact is stored exactly once (normalization), so an update touches one place and there is no possibility of two copies disagreeing. The cost is that answering a real question usually requires touching several tables — cheap when they're on one machine, expensive the moment they're not.

### Schema-on-Write vs. Schema-on-Read
Schema-on-write means the database rejects any row that doesn't match the declared shape; a change requires a migration, but every reader can trust the data. Schema-on-read means the store accepts any document and the *application* interprets it — which is genuinely flexible during rapid iteration, but means production data accumulates every historical shape, and every reader must defensively handle all of them forever. The schema didn't disappear; it moved from one enforced place into N application code paths.

### The Four NoSQL Families
**Key-value** (Redis, DynamoDB): a hash map at scale — `GET`/`PUT` by key, value is opaque. **Document** (MongoDB, DynamoDB, Postgres JSONB): values are structured, nested JSON-like objects; you can index and query on inner fields. **Wide-column** (Cassandra, HBase, Bigtable): rows live inside a partition identified by a partition key and are sorted by a clustering key, making "give me the last N events for entity X" a single sequential read. **Graph** (Neo4j, Neptune): nodes and edges as first-class citizens, where traversing a relationship is a pointer hop rather than a join.

### Access-Pattern-Driven Modeling (Single-Table Design)
In relational modeling you design the data first and the queries follow. In NoSQL you invert it: enumerate the queries, then design keys and item shapes so that every query is a single-partition read. DynamoDB single-table design is the extreme form — multiple entity types share one table, with composite `PK`/`SK` values engineered so that one query returns a whole object graph. The power is flat, predictable latency; the risk is that an unanticipated query has no efficient path and requires a new index or a re-model.

### Denormalization and Duplication
Because there is no server-side join, NoSQL designs deliberately store the same fact in multiple places — the author's display name embedded in every post, the order total copied onto the customer record. Reads become single fetches; writes become fan-outs, and you inherit the job of keeping copies consistent (often via change-data-capture or transactional writes).

### Transaction Scope: ACID vs. BASE (and the convergence)
Relational databases offer ACID across arbitrary rows and tables. Most NoSQL stores originally guaranteed atomicity only within one item/document/partition, and offered **BASE** semantics — basically available, soft state, eventual consistency — often with *tunable* consistency (Cassandra's `ONE`/`QUORUM`/`ALL`, DynamoDB's eventually- vs. strongly-consistent reads). That gap has narrowed sharply: MongoDB has multi-document transactions, DynamoDB has `TransactWriteItems`, and Spanner/CockroachDB offer full distributed ACID SQL. The honest modern framing is *scope and cost of a transaction*, not "has transactions or doesn't."

### Polyglot Persistence
Real systems don't pick one. A single product typically runs Postgres for orders and billing, Redis for sessions and rate limits, Cassandra or a time-series DB for events, Elasticsearch for search, and S3 + a warehouse for analytics. In an interview, proposing the right store *per access pattern* — and naming the sync mechanism between them (CDC, outbox, streaming) — reads as senior; insisting on one database for everything reads as junior.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

The relational model won for thirty years because it solved the right problem: in 1970, storage was expensive and correctness was hard, so storing each fact exactly once and letting a query planner recombine facts on demand was the optimal trade. Every relational feature that we value — joins, ad-hoc SQL, multi-row ACID, foreign keys — silently depends on one assumption: **all the data is reachable from a single machine's address space and a single transaction log**.

That assumption broke around the mid-2000s. Amazon's shopping cart, Google's crawl index, and Facebook's message history simply did not fit on one machine, and the write volume exceeded what one primary could commit. The obvious move — shard the relational database — turns out to destroy the very features you were paying for: a join across shards becomes a network scatter-gather, and a transaction across shards needs two-phase commit, which is slow and blocking. So you end up with a relational database that can't do relational things, plus the operational burden of running one.

NoSQL was the inverted design: **assume partitioning first, then offer only the operations that can be answered from a single partition.** That's why key-value and wide-column stores expose an API built around a partition key — not because engineers dislike SQL, but because any operation spanning partitions has inherently different cost and failure characteristics. The Dynamo paper (2007) and Bigtable paper (2006) are the founding documents of that inversion: they trade query expressiveness and general transactions for linear scalability and predictable single-digit-millisecond latency at any data size.

The deeper principle is that **you cannot get query flexibility, strong multi-entity transactions, and unlimited horizontal scale for free at the same time** — someone pays, either in latency, in operational complexity, or in application-level work. Every database in this space is a different point on that curve. The recent convergence (Spanner, CockroachDB, Postgres JSONB, DynamoDB transactions) doesn't abolish the trade-off; it just moves the cost — Spanner buys distributed ACID with atomic clocks and commit-wait latency, and JSONB buys flexibility by giving up the planner's statistics on those fields.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason fast — especially under interview pressure.*

### Model 1: Warehouse with a Librarian vs. Pre-Packed Boxes
A relational database is a warehouse where items are stored once, in the right aisle, with a very good librarian (the query planner) who can assemble any order you ask for — including orders nobody anticipated. A NoSQL store is a warehouse of **pre-packed boxes**: someone decided in advance what customers would ask for and packed each box to match, so fulfilment is instant and identical every time. Ask for something nobody pre-packed and you must open every box on every shelf (a scatter-gather scan) or repack the warehouse. *Where it breaks down:* secondary indexes and GSIs let you pre-pack a second arrangement after the fact — but you pay for it on every write, and it's usually eventually consistent.

### Model 2: The Schema Never Disappears — It Just Changes Landlords
"Schemaless" doesn't mean there is no schema; it means the schema lives in your application code instead of the database. Under schema-on-write, one migration script pays the cost once, up front, and every reader thereafter can trust the shape. Under schema-on-read, you avoid the migration but every reader, forever, must handle every shape the data has ever had. So the question is never "schema or no schema" — it's "do I want to pay the cost in one migration, or in N defensive code paths?" *Where it breaks down:* for genuinely heterogeneous data (per-tenant custom fields, third-party event payloads), enumerating a fixed schema really is impossible, and schema-on-read is the correct answer, not a dodge.

### Model 3: Follow the Write, Not the Read
When you're stuck, ask where the *writes* go. Relational scales reads well (read replicas are easy) but has one primary, so write throughput is the hard ceiling. Partition-native stores spread writes across partitions by design, so write volume scales with node count. If the workload's pain is "too many reads," the answer is usually caching and replicas, not a new database. If the pain is "too many writes, and they're naturally keyed by entity," that's the genuine NoSQL signal. *Where it breaks down:* it doesn't cover the flexibility axis — a low-volume system with wildly unpredictable queries still wants relational.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step explanation of the internal mechanism.*

**The relational read path (happy path):**
1. Client sends SQL. The parser and planner use table statistics to choose an execution plan — index scan vs. sequential scan, hash join vs. nested-loop join vs. merge join.
2. The executor pulls pages via the buffer pool, applies filters, performs the joins, and materializes the result set.
3. Writes go through the transaction manager: acquire locks (or MVCC snapshots), append to the write-ahead log, `fsync` at commit, then update pages in memory (and later on disk).
4. Because the WAL is a single ordered log on one primary, ACID across arbitrary rows is straightforward — and that same single log is the write-throughput ceiling.
5. Read replicas apply the WAL asynchronously → read scaling is easy, but replicas are stale by the replication lag, which is where read-your-own-writes bugs come from.

**The partition-native NoSQL read path:**
1. Client sends a request that includes a partition key. A request router (DynamoDB's request routers, Cassandra's coordinator node, `mongos`) hashes the partition key to find the owning node(s).
2. That node serves the read locally from its own storage engine — typically an LSM tree (Cassandra, Bigtable, HBase, DynamoDB) optimized for high write throughput, or a B-tree.
3. Because the operation touches one partition, latency is independent of total dataset size — this is the flat p99 that partition-native stores advertise.
4. Writes are appended to a commit log + memtable and flushed to immutable SSTables; replication to N replicas happens with a configurable quorum (`R + W > N` for strong consistency).
5. **Any query without the partition key becomes a scatter-gather across all partitions** — this is where a badly chosen key destroys the performance story (see 7.7).

**Schema evolution in each model:**
- Relational: `ALTER TABLE`. Adding a nullable column is usually instant metadata-only in modern Postgres/MySQL; adding a `NOT NULL` column with a default, changing a type, or adding an index on a large table can require a rewrite or a lock — hence online schema-change tooling (gh-ost, pt-online-schema-change, `CREATE INDEX CONCURRENTLY`).
- Document: write the new shape immediately. Old documents keep the old shape. Readers must handle both, either forever or until a backfill job normalizes them. The migration cost is deferred, not removed.

**Transactions and their scope:**
- Relational: BEGIN → arbitrary reads/writes across tables → COMMIT, with isolation levels from read-committed to serializable.
- DynamoDB: single-item writes are atomic; `TransactWriteItems` gives ACID across up to 100 items (with a cost multiplier and a higher failure rate under contention).
- MongoDB: single-document writes are atomic; multi-document transactions exist since 4.0 but carry meaningful performance cost and are not the intended default pattern.
- Cassandra: no general transactions; lightweight transactions (`IF NOT EXISTS`) use Paxos per partition and are roughly an order of magnitude slower than normal writes.

**Failure / edge cases to know:**
- **Hot partition:** a partition key with skewed traffic saturates one node's throughput cap (DynamoDB ~3,000 RCU / 1,000 WCU per partition) while the rest of the table is idle. Fix: salt the key, or pick a better one (see 7.6).
- **Unanticipated query:** the access pattern you didn't model has no efficient path — you either add a GSI (extra write cost, eventually consistent), do a full table scan, or re-model.
- **Cross-entity consistency:** without multi-entity ACID, a partially applied logical operation (order created, inventory not decremented) is a real state your system can be in. Mitigate with transactional APIs, the outbox pattern, or idempotent sagas with compensation.
- **Replica lag on the relational side:** a write to the primary followed by a read from a replica can miss the write; fix with read-your-writes routing (sticky to primary for a window) — this is the relational analogue of eventual consistency.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How SQL vs. NoSQL Applies | Notes |
|--------|---------------------------|-------|
| **Amazon (orders + cart)** | Cart and session state in **DynamoDB** (key-value, single-key access, must never be slow); orders and financial records in relational systems. The 2007 Dynamo paper was motivated specifically by cart availability during peak. | The canonical "different store per access pattern" example — cite it for polyglot persistence |
| **Instagram** | **PostgreSQL** as the primary store for users, media metadata, and relationships, sharded application-side; **Cassandra** for high-volume feed/activity data; **Redis** for counters and caching | Direct counter-example to "big scale ⇒ no relational" — Instagram runs relational at enormous scale |
| **Netflix** | **Cassandra** as the primary operational store for viewing history and member data — extremely write-heavy, naturally partitioned by member ID, availability over strict consistency | Multi-region active-active is far easier with a partition-native, tunable-consistency store |
| **Discord** | Migrated message history from MongoDB → **Cassandra** → **ScyllaDB**: trillions of messages, dominant query is "give me the last N messages in channel X" — a textbook wide-column partition + clustering key | Great story to cite: the access pattern (range scan inside a partition) *is* the reason for wide-column |
| **Stripe / any payments system** | Relational (Postgres/MySQL) for ledgers and balances — double-entry bookkeeping needs multi-row ACID and referential integrity that you should never hand-roll | The "money moves ⇒ relational (or Spanner)" rule of thumb |
| **Google (internal)** | **Bigtable** (wide-column) for crawl/index-scale data; **Spanner** for globally distributed ACID SQL — F1/AdWords migrated from sharded MySQL to Spanner | Spanner is the proof that the SQL/NoSQL binary is obsolete: SQL + horizontal scale, paid for with TrueTime commit-wait |
| **LinkedIn / social graphs** | Graph traversal ("degrees of connection") served by purpose-built graph infrastructure rather than recursive SQL joins | Multi-hop traversal is the one access pattern where relational degrades non-linearly |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Relational: ad-hoc query flexibility** — the planner answers questions you never anticipated, with joins and aggregations server-side | Query cost is unpredictable; a bad plan or a missing index can degrade non-linearly, and the flexibility is only cheap while data fits few nodes |
| **Relational: multi-row ACID + referential integrity** — the DB, not every future engineer, enforces correctness | Ties you to a single write primary (unless you adopt Spanner/CockroachDB and pay their latency and operational cost) |
| **NoSQL: partition-native horizontal scale** — write throughput and dataset size grow with node count, latency stays flat | Only for queries that carry the partition key; everything else becomes scatter-gather or needs a second index/read model |
| **NoSQL: schema-on-read flexibility** — ship a new field today with no migration | Every reader must handle every historical shape forever; data quality erodes silently, and the migration debt compounds |
| **NoSQL: denormalized single-fetch reads** — one round trip returns a whole object graph | Duplicated facts must be kept in sync on write; you own the consistency problem the DB used to own |
| **NoSQL: predictable per-operation cost** — a single-partition read costs the same at 1 GB and 100 TB | You must know the access patterns *before* you model; an unanticipated query is expensive or impossible without a re-model |
| **Polyglot persistence** — the right store for each access pattern | Operational surface area multiplies: N systems to run, monitor, back up, and keep in sync (CDC/outbox pipelines and their staleness) |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "What database would you use for this, and why?"
- "We expect 100 million users and a million writes per second — does your choice still hold?"
- "The product team says the schema is going to change a lot. Does that change your answer?"
- "This has to be transactionally correct — you can't double-charge a customer."
- "Would you use SQL or NoSQL here?" *(the trap: answering the binary instead of reframing it)*

**What you say / do:**
This lands in the **high-level design / data model** phase, right after requirements. Never answer the binary directly — reframe it first: *"Before I pick, let me state the access patterns."* List the top 3–5 queries with rough QPS, then walk the decision: are the patterns stable, do I need multi-entity ACID, what's the dominant read shape, does one node still fit. Then name a **specific product and family** ("DynamoDB as a key-value store, partitioned on `user_id`"), state the access pattern it's modeled for, and immediately volunteer what you gave up and how you'd cover it. Explicitly consider polyglot: it's usually the correct real-world answer, and proposing Postgres for orders + Redis for sessions + Elasticsearch for search shows you're designing for patterns, not for a brand.

**The trade-off statement (memorize this pattern):**
> "The dominant access pattern here is [read the last N messages in a channel / fetch a cart by user ID], which is a single-partition read at very high write volume — so I'd use [Cassandra / DynamoDB] partitioned on [key]. That buys me flat p99 latency and write throughput that scales with node count. What I give up is server-side joins and multi-entity ACID, so [the join with user profiles becomes a denormalized copy refreshed by CDC / the order-plus-inventory write becomes a TransactWriteItems, or a saga if it spans services]. If instead the requirement had been [ad-hoc analytics / strict financial correctness], I'd have stayed on Postgres, because a single node comfortably handles [X] QPS and we're well under that."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** "SQL doesn't scale, so at high volume you need NoSQL."
  ✅ **Reality:** A single well-tuned Postgres or MySQL node serves tens of thousands of QPS over single-digit terabytes, and Instagram, Shopify, and GitHub run relational at enormous scale. The honest distinction is **bolt-on vs. partition-native**: relational can be sharded (Vitess, Citus), but sharding costs you cross-shard joins and transactions, whereas NoSQL stores are partitioned by design. Name the specific ceiling you're exceeding — usually *write* throughput on the single primary — or your scale argument is hand-waving.

- ❌ **Misconception:** "NoSQL is schemaless, so I don't have to design a schema."
  ✅ **Reality:** The schema moved into your application code. Production data ends up containing every historical shape of every document, and every reader must handle all of them defensively. Worse, in access-pattern-driven stores you must design the *key* schema more carefully than a relational schema — the wrong partition key is far more expensive to fix than a missing index.

- ❌ **Misconception:** "NoSQL is faster than SQL."
  ✅ **Reality:** For an indexed single-row lookup, a relational database is comparably fast. What NoSQL provides is *flat latency as the dataset grows*, achieved by only ever touching one partition. That's a scaling property, not raw speed — and it's bought by removing joins and general transactions, not by superior engineering.

- ❌ **Misconception:** "NoSQL means no transactions and eventual consistency."
  ✅ **Reality:** Out of date. DynamoDB has `TransactWriteItems` and strongly-consistent reads, MongoDB has multi-document ACID transactions, Cassandra has quorum reads/writes with `R + W > N` and lightweight transactions. The right framing is the *scope and cost* of a transaction — cheap within a partition, expensive or bounded across them.

- ❌ **Misconception:** "It's a binary choice — you pick one database for the system."
  ✅ **Reality:** Almost every real system is polyglot: relational for the transactional core, Redis for sessions and counters, wide-column for high-volume events, Elasticsearch for search, object storage plus a warehouse for analytics. The interview-strong answer picks a store per access pattern *and* names how they stay in sync (CDC, outbox, streaming) plus the staleness that introduces.

- ❌ **Misconception:** "Document stores are just relational without the joins, so I'll model the same entities as documents."
  ✅ **Reality:** That's how document databases get misused. Documents should be **aggregates that are read and written as a unit**. If you find yourself doing application-side joins across collections on the hot path, you've built a relational schema without a query planner — you'd have been better off with Postgres (or with a genuinely denormalized document design).

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** **Topic 7 — Partitioning/Sharding** (7.1–7.7). Partition-native NoSQL *is* sharding built into the data model, so everything you know about hash vs. range partitioning, hot partitions, and cross-shard queries applies directly to your choice of partition key here. Also builds on **Topic 2 — CAP/consistency**: BASE, tunable consistency, and quorum (`R + W > N`) are the vocabulary for the consistency axis. And on **Topic 5 — Caching**: a cache in front of a relational DB is often the correct alternative to switching databases entirely.
- **Enables:** the rest of Topic 8 — **8.2 OLTP vs. OLAP** (a third axis: transactional vs. analytical, which cuts across SQL/NoSQL), **8.3 normalization/denormalization** (the modeling technique this decision forces), **8.4 indexing** (B-tree in relational vs. LSM-tree in most NoSQL — the storage-engine reason NoSQL absorbs writes so well), and **8.6 ACID**. It also enables **Topic 9 (object storage)** and **Topic 10 (warehouses)** as the other two members of the polyglot set.
- **Tension with:** **8.6 ACID transactions** — the more you distribute for scale, the more expensive multi-entity ACID becomes; Spanner/CockroachDB pay for it in commit latency. Also in tension with **8.3 normalization** — NoSQL pushes you to denormalize for single-fetch reads, which directly conflicts with the "store each fact once" discipline that keeps data correct. And with **7.7 cross-shard queries** — the flexibility you keep in relational is exactly the flexibility that becomes a scatter-gather once you partition.

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. Name the four NoSQL families, give a production product for each, and state the one access pattern each is optimized for. Then say which one you'd pick for "fetch the last 50 messages in a Discord channel" and why.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit §6 (Four Families) and §4 (Decision Map).*

2. An interviewer says: "We're expecting 500 million users, so obviously we need NoSQL." How do you respond? Be specific about the numbers and the mechanism.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit §13 (first misconception) and §4 §6 (numbers).*

3. You move a `users` + `orders` model from Postgres into DynamoDB. Name three capabilities you just lost, and the concrete workaround for each.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit §4 §5 and §11.*

4. Give a real production system for each of: (a) relational at massive scale, (b) wide-column chosen for a range-within-partition read, (c) key-value chosen for availability on a single-key path. Explain the access pattern that drove each choice.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit §10.*

5. A team chose MongoDB "because the schema will change often." Six months in, the product needs a report joining users, orders, and refunds, filtered on three arbitrary fields. What went wrong, and what are your options now?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit §4 (Q1 gate), §8 Model 1, and §13 (last misconception).*

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **Designing Data-Intensive Applications, Chapter 2 — Data Models and Query Languages** — Kleppmann — relational vs. document vs. graph, the object-relational mismatch, and why the "great debate" is really about data locality
- [ ] **Amazon DynamoDB: A Scalable, Predictably Performant, and Fully Elastic NoSQL Database Service (USENIX ATC 2022)** — https://www.usenix.org/conference/atc22/presentation/elhemali — the modern DynamoDB paper; partition management, hot partitions, and adaptive capacity
- [ ] **Alex DeBrie — "The What, Why, and When of Single-Table Design with DynamoDB"** — https://www.alexdebrie.com/posts/dynamodb-single-table/ — the clearest available explanation of access-pattern-driven modeling
- [ ] **Bigtable: A Distributed Storage System for Structured Data (Google, OSDI 2006)** — https://research.google/pubs/pub27898/ — the origin of the wide-column model
- [ ] **Discord — "How Discord Stores Trillions of Messages"** — https://discord.com/blog/how-discord-stores-trillions-of-messages — a concrete migration story driven entirely by the access pattern
- [ ] **Spanner: Google's Globally-Distributed Database (OSDI 2012)** — https://research.google/pubs/pub39966/ — why the SQL/NoSQL binary collapsed

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*
