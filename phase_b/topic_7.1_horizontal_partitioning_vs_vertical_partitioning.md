# 7.1 Horizontal Partitioning vs. Vertical Partitioning

> **Topic:** Topic 7 — Data Partitioning / Sharding
> **Phase:** B — Scalability Branch
> **Date studied:** 2026-07-12

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

Partitioning is how you split a single logical dataset across multiple physical stores so that no one machine has to hold all the data or serve all the traffic. There are two orthogonal axes to cut along. **Horizontal partitioning (sharding)** splits *rows* — every shard has the identical schema but holds a disjoint subset of the rows (e.g., users A–M on shard 1, N–Z on shard 2). **Vertical partitioning** splits *columns or tables* — each partition holds a different set of attributes for the same entities (e.g., hot profile fields on one store, rarely-read bio/blob fields on another). The two are not competitors; real systems apply both. Mastering this subtopic means being able to look at an access pattern and say precisely which axis to cut along, why, and what it costs you.

### 🎯 What to Focus On

**1. The rows-vs-columns distinction.** The single most important thing: horizontal = same schema, different rows; vertical = same rows (entities), different columns/tables. If you can't state this crisply, everything downstream is fuzzy.

**2. What problem each axis solves.** Horizontal partitioning relieves *volume and throughput* — too many rows, too many QPS for one node. Vertical partitioning relieves *width and access-pattern mismatch* — rows too wide, or hot columns dragged down by cold blob columns. Know which pain each one treats.

**3. The query-locality consequence.** Horizontal partitioning is fine as long as queries hit a single shard by the partition key; it breaks down for cross-shard scatter-gather. Vertical partitioning breaks down when a query needs columns that now live on two different stores — you've turned a single row read into a cross-store join.

**4. When you combine them.** At real scale you vertically split first (separate concerns / tables / services), then horizontally shard the tables that individually outgrow one node. Be able to narrate that progression.

**5. Interview framing.** "How do we scale writes on this table?" → horizontal. "This table has 60 columns but reads only touch 5" or "we're storing a 2MB blob inline" → vertical. Recognize the trigger phrases.

---

## 1. 🎯 Goal of This Subtopic

After studying this, you should be able to look at any data model and access pattern and decide whether to partition horizontally, vertically, both, or not at all — and justify it in terms of the specific pressure being relieved (row count / QPS vs. row width / access-pattern mismatch). You should be able to draw each scheme, explain how a read and a write route under each, and name the failure mode each introduces (cross-shard scatter-gather vs. cross-partition joins).

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [x] Can define horizontal and vertical partitioning in one sentence each and state the rows-vs-columns distinction without hesitation
- [x] Can map a given scaling pain (too many rows, too much write QPS, rows too wide, hot+cold columns mixed) to the correct partitioning axis
- [x] Can trace how a single read and a single write route under horizontal partitioning and explain what happens when a query lacks the partition key
- [x] Can explain why vertical partitioning turns some single-row reads into cross-store joins, and when that trade is worth it
- [x] Can describe a realistic progression where a system applies vertical then horizontal partitioning as it grows
- [x] Can distinguish partitioning from replication and explain how the two compose (each shard is itself replicated)

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] Read **"Designing Data-Intensive Applications" Chapter 6 — Partitioning** (Martin Kleppmann) — the definitive treatment; focus on the partitioning/replication interplay
- [ ] Read **ByteByteGo — "Database Sharding Explained"** (https://blog.bytebytego.com/p/database-sharding)
- [ ] Read **AWS — "Vertical vs. Horizontal Partitioning"** guidance in the AWS Prescriptive Guidance / Database patterns docs
- [ ] Read through **Sections 5–9** (Core Definition → How It Works) carefully — don't skim
- [ ] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **Core Definition** of both schemes from memory, then compare
- [ ] Explain **First Principles** out loud without notes — what problem forced partitioning to exist?
- [ ] Reconstruct the **read/write routing** under each scheme step by step from memory
- [ ] Restate each **Trade-off** row in your own words — if you can't explain the cost, you don't own it yet

### Phase 3 — Apply 🔧 💪💪💪💪
*Goal: Connect to real systems and simulate interview scenarios.*

- [ ] Go through **Real-World System Examples** (Section 10) — verify each claim independently and add anything missed to **My Notes**
- [ ] Practice the **Interview Application** (Section 12) out loud — say the trigger phrases and your response as if in a live interview
- [ ] Work through **Common Misconceptions** (Section 13) — for each, make sure you can explain *why* the misconception is wrong, not just that it is
- [ ] Trace the **Relationships to Other Concepts** (Section 14) — can you explain each connection without looking?

### Phase 4 — Validate 🧪 💪💪💪💪💪
*Goal: Confirm you actually own it, not just recognize it.*

- [ ] Answer every **Self-Check Quiz** question (Section 15) out loud without looking at your notes
- [ ] Recite the **Cheatsheet** (Section 4) from memory — if you can't, re-do Phase 2
- [ ] Tick off items in **What Mastery Looks Like** (Section 2) — only check a box if you can demonstrate it on demand, not just if it sounds familiar
- [ ] Teach this concept out loud to an imaginary interviewer for 2 minutes without hesitation or notes

---

## 4. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

### 🗺️ Partitioning Axis Decision Map

```
Is a single node struggling with this dataset?
├── No  ──────────────────────────────────────► Don't partition yet (complexity tax)
└── Yes
    │
    ▼
What is the pressure?
│
├── Too many ROWS / too much write QPS / table > single-node disk
│      │
│      ▼
│   HORIZONTAL PARTITIONING (Sharding)
│   Same schema, disjoint row subsets across N shards.
│   Route by partition key (hash or range).
│   ⚠️ Queries without the partition key → scatter-gather across all shards.
│
└── Rows too WIDE / hot+cold columns mixed / large blobs inline /
    different columns have different access or security needs
       │
       ▼
    VERTICAL PARTITIONING
    Same entities, split columns/tables across stores.
    Hot narrow columns on fast store; cold/wide columns elsewhere.
    ⚠️ A query needing columns from both sides → cross-store join.

BOTH (typical at scale):
    Vertically split into tables/services first →
    then horizontally shard whichever table outgrows one node.
```

```
§ 1  WHY IT EXISTS
One machine has finite disk, RAM, CPU, and IOPS. A dataset or workload that exceeds any
of those must be split across machines — that split is partitioning. Two independent
things can exceed a node: the NUMBER of rows / write throughput (relieved by cutting
rows = horizontal) and the WIDTH of rows or a mismatch between hot and cold columns
(relieved by cutting columns = vertical). Partitioning is the only way to scale a
dataset beyond what the biggest single box can hold; replication (copying) scales
reads and availability but NOT capacity — you still need partitioning for capacity.

§ 2  THE TWO AXES
HORIZONTAL (Sharding):  split by ROW. Every shard = identical schema, disjoint rows.
                        users 1–1M on shard A, 1M–2M on shard B. Relieves volume + QPS.
                        Routing: partition key → hash or range → shard.
VERTICAL:               split by COLUMN / TABLE. Same entities, different attributes
                        per store. Hot fields (name, status) on store X; cold/wide
                        fields (bio, avatar blob, audit log) on store Y. Relieves
                        row width + access-pattern mismatch.
Mnemonic:  Horizontal = more of the SAME rows elsewhere (cut the table sideways).
           Vertical   = different COLUMNS elsewhere (cut the table lengthwise).

§ 3  THE 3 KEY DISTINCTIONS
1. What's replicated vs. what's disjoint: in BOTH schemes the data on each node is
   DISJOINT (no overlap). That's what makes it partitioning, not replication.
   Replication = same data copied; partitioning = different data split.
2. Query locality: horizontal is cheap ONLY if the query carries the partition key
   (single-shard hit). Vertical is cheap ONLY if the query touches columns that all
   live on one partition. Break either assumption and you pay a cross-node cost.
3. What each scales: horizontal scales capacity AND write throughput linearly with
   shard count. Vertical scales by isolating access patterns / hardware per column
   group — it does NOT multiply write throughput of a single hot column set.

§ 4  USE / AVOID
Use HORIZONTAL:   row count or write QPS exceeds one node; you have a good high-
                  cardinality, evenly-distributed partition key; queries are keyed.
Use VERTICAL:     table is very wide; a few hot columns are read constantly while
                  large/cold columns bloat every row; columns differ in access
                  pattern, storage engine fit (blob vs. relational), or security tier.
Use BOTH:         large-scale systems — vertically decompose into services/tables,
                  then horizontally shard the ones that individually outgrow a node.
Avoid partitioning at all: when a single (replicated) node still comfortably fits the
                  data and load. Partitioning adds routing, rebalancing, and cross-
                  partition query complexity — don't pay it early.

§ 5  INTERVIEW TRIGGERS
→ "This table has grown to billions of rows / won't fit on one machine."
→ "Write throughput on this table is saturating the primary."
→ "The row is 60 columns wide but the hot path only reads 4 of them."
→ "We're storing user avatars / documents inline in the same row as the profile."
→ "How would you shard this? What's your partition key?"

§ 6  FTAC
F  "One node can't hold this dataset or serve this write rate, so I need to partition.
   The question is which axis: are we bounded by row count/QPS, or by row width and
   mixed hot/cold access?"
T  "Horizontal sharding scales capacity and write throughput linearly but only if
   queries carry the partition key — otherwise I pay scatter-gather. Vertical splitting
   isolates hot from cold columns but turns cross-column reads into a join."
A  "Assuming most reads are keyed by user_id and the table is uniformly wide, this is
   a volume problem, not a width problem —"
C  "I'd horizontally shard by user_id (hash partitioning) across N shards, each itself
   replicated for availability. Cross-user analytics would go to a separate OLAP store,
   not scatter-gather across shards."

§ 7  NUMBERS & GOTCHA
Rule of thumb:  a single well-tuned RDBMS node comfortably handles ~single-digit TB and
                low-thousands of write QPS before sharding is warranted (varies widely).
Shard count est: shards ≈ ceil(total_data / per_shard_capacity) AND
                 ceil(peak_write_qps / per_shard_write_capacity) — take the max.
Vertical split:  move columns > ~a few KB (blobs, JSON docs) out of the hot row to keep
                 the hot table's rows small and cache-friendly.
GOTCHA: Partitioning is NOT replication and does NOT give you availability by itself.
  Each partition is a single point of failure for its slice of data UNTIL you also
  replicate it. Real designs always layer replication under partitioning. Also: choosing
  a low-cardinality or skewed partition key (e.g., country, boolean) creates hot shards —
  the partition key choice matters more than the sharding mechanism.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

**Horizontal partitioning (sharding)** splits a table by rows — every partition shares the identical schema but stores a disjoint subset of the rows, chosen by a partition key. **Vertical partitioning** splits a table by columns — the same logical entities are divided so that different attributes (columns or sub-tables) live in different stores, typically separating frequently-accessed narrow columns from rarely-accessed wide or bulky ones.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*

### Horizontal Partitioning (Sharding)
Splitting a dataset row-wise: each shard is a full-schema replica of the *structure* but holds only a disjoint slice of the *rows*. A partition key (e.g., `user_id`) plus a strategy (hash or range) decides which shard owns each row. This is the workhorse of scaling — it grows total capacity and write throughput roughly linearly with shard count, because each shard independently absorbs a fraction of the rows and the writes. The catch is routing: a read must know the partition key to go straight to the owning shard; a query without it must fan out to every shard.

### Vertical Partitioning
Splitting a dataset column-wise: the same entity's attributes are divided across stores. A classic example is keeping `user_id, username, status, last_login` (small, hot, read on every request) in one fast table, while `bio, profile_image_blob, preferences_json` (large, cold) live in a separate store. Vertical partitioning shrinks the hot row so more of it fits in cache and each read moves less data. It also lets you match storage engine to data shape — relational store for structured hot fields, blob/object store for the avatar. The cost: any query needing columns from both sides now performs a join across stores.

### Partition Key (Shard Key)
For horizontal partitioning, the column(s) whose value determines a row's home shard. The single most consequential design choice in sharding: it must be high-cardinality and evenly distributed so load spreads uniformly, and it should align with the dominant query pattern so most queries are single-shard. A poor key (low cardinality like `country`, or monotonic like a timestamp) concentrates load on one shard — a hot partition.

### Disjointness (Partitioning vs. Replication)
The defining property of partitioning is that each node holds *different* data with no overlap — as opposed to replication, where each node holds a *copy* of the same data. Partitioning is how you scale *capacity*; replication is how you scale *read throughput* and *availability*. They are orthogonal and almost always combined: you shard for capacity, then replicate each shard for durability and reads.

### Cross-Partition Operations
The failure mode shared by both axes. In horizontal partitioning, a query lacking the partition key (or an aggregate across all users) becomes a **scatter-gather**: query every shard, merge results — slow, and as expensive as your slowest shard. In vertical partitioning, a read needing columns from two partitions becomes a **cross-store join** — you've reintroduced the join you were trying to avoid, now across a network. Good designs keep the common-case query within a single partition.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

A single machine has hard ceilings: finite disk (you can't store more rows than fit), finite RAM (the working set must fit or you thrash), finite CPU/IOPS (only so many writes per second before the disk or lock contention saturates). For a long time you could push those ceilings up by buying a bigger box — vertical *scaling* of hardware. But that curve flattens: the biggest available machine is finite, and its cost grows super-linearly. Eventually a dataset or a write rate simply exceeds what any one node can do.

Partitioning is the answer: split the data across many commodity nodes so the aggregate capacity and throughput scale with the number of nodes. The reason there are *two* axes is that a node can be overwhelmed in two independent ways. It can have *too many rows or too many writes* — a volume/throughput problem, solved by cutting the rows across machines (horizontal). Or its rows can be *too wide*, with a handful of hot columns being read constantly while large cold columns bloat every row and evict useful data from cache — a width/access-mismatch problem, solved by cutting the columns across machines (vertical). Both are forms of "divide the data so no node holds all of it," but they treat different diseases, which is why a mature system uses both.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*

### Model 1: Cutting a Spreadsheet
Picture your data as one giant spreadsheet. **Horizontal partitioning cuts it with horizontal lines** — you tear off blocks of rows and hand each block to a different machine; every block still has all the columns. **Vertical partitioning cuts it with vertical lines** — you slice off groups of columns and put each group on a different machine; every machine still has all the entities but only some of their fields. This model is exact and instantly recallable under pressure. Where it breaks down: it doesn't capture routing or the join cost — it shows the *shape* of the split, not the runtime consequence.

### Model 2: The Library Analogy
A library that outgrows one building can expand two ways. **Horizontal:** open a second, identical building and split the books by call number (A–L here, M–Z there) — same layout, different books; to find a book you must know which building (partition key). **Vertical:** keep the frequently-browsed items (catalog cards, new releases) in the fast front room and move the rarely-touched archives (bound periodicals, microfilm) to a distant annex — same items conceptually, but split by how often they're accessed. A patron who needs both a new release and its archived companion must visit two places (cross-partition read). This works because it captures both the routing (which building) and the join cost (two trips); it breaks down if you push the "same items" mapping too literally.

### Model 3: Volume vs. Width Diagnosis
When you feel scaling pain, ask one diagnostic question: *is the problem how MANY rows, or how WIDE the rows?* "Many" (row count, write QPS, total bytes) → cut horizontally. "Wide" (60 columns, giant blobs inline, hot/cold mixed) → cut vertically. This frame turns an open-ended "how do we scale this?" into a fast, defensible decision. Where it breaks down: at large scale the honest answer is often "both," and the frame is a starting diagnosis, not the final architecture.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

**Horizontal partitioning — read path (single-shard, happy case):**
1. Application issues a query keyed by the partition key, e.g., `SELECT * FROM users WHERE user_id = 12345`.
2. A routing layer (client library, proxy like Vitess/ProxySQL, or coordinator) applies the partition function — hash or range — to `12345` to compute the owning shard.
3. The query is sent to that one shard (and its read replica if reads are offloaded). Result returns directly. Cost ≈ a single-node query.

**Horizontal partitioning — the scatter-gather failure mode:**
1. A query lacks the partition key or aggregates across all rows, e.g., `SELECT COUNT(*) FROM users WHERE status='active'`.
2. The router cannot narrow to one shard, so it fans the query out to **all N shards** in parallel.
3. Each shard computes its partial result; the coordinator merges them. Latency is bounded by the *slowest* shard, and the operation gets more expensive as you add shards. This is why the partition key must align with the dominant query pattern.

**Horizontal partitioning — write path:**
1. Compute the shard from the partition key of the row being written.
2. Write to that shard's primary; the shard's own replication then propagates the write to its replicas.
3. Writes to different keys land on different shards, so aggregate write throughput scales with shard count — the core win.

**Vertical partitioning — read path:**
1. A hot-path read (e.g., render a user's header) touches only the narrow hot table: `SELECT username, status FROM users_core WHERE user_id=12345`. Fast, cache-friendly, small rows.
2. A read needing cold columns (e.g., open the full profile) queries the second store for `bio, avatar` — either a second lookup by `user_id` or an application-level join. This is the cost you accept to keep the hot path lean.

**Vertical partitioning — write path:**
1. Writing hot fields touches only the hot store; writing cold fields touches only the cold store.
2. If a single logical update spans both stores, you now have a multi-store write — either accept eventual consistency between them or coordinate (transaction/saga), which is the price of the split.

**Combining both (typical progression):**
1. Start with one table. As it grows wide or mixes concerns, **vertically split** it into focused tables/services (or move blobs to object storage).
2. As an individual table's row count or write QPS outgrows one node, **horizontally shard** that table by an appropriate partition key.
3. Under every shard, **replicate** for durability and read scaling. The final architecture is: vertically-decomposed tables, each horizontally sharded, each shard replicated.

**Key parameters to reason about:**
- Partition key cardinality and distribution (avoid skew / hot shards).
- Shard count sizing: `shards ≈ max( ceil(total_data / per_shard_capacity), ceil(peak_write_qps / per_shard_write_capacity) )`, with headroom for growth.
- Vertical split threshold: pull columns out of the hot row when they are large (KB-scale blobs/JSON) or cold, so the hot table's rows stay small.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| **Instagram (Postgres)** | Horizontally sharded core data by user ID using a logical-shard scheme (thousands of logical shards mapped onto fewer physical Postgres machines); shard ID encoded into 64-bit IDs | Their well-known ID-generation scheme embeds the shard so routing is a bit-shift; illustrates partition-key-driven routing |
| **Vitess (YouTube / PlanetScale)** | A sharding middleware over MySQL: presents one logical database while horizontally partitioning tables across many MySQL instances, with a query router that resolves single-shard vs. scatter-gather | Productionizes the routing layer and scatter-gather concept; born to scale YouTube's MySQL |
| **Amazon / e-commerce user tables** | Vertical partitioning of a `users` entity: hot account fields (login, status) in a fast transactional store; large/cold fields (order history, preferences, media) in separate stores or services | Classic "split hot narrow from cold wide"; often evolves into separate microservices per column group |
| **Any app storing files/avatars** | Vertical partitioning between a relational row (metadata: `user_id, filename, size`) and an object store (S3/GCS) holding the actual bytes | The blob is moved out of the row entirely — the archetypal vertical split; keeps DB rows small |
| **Cassandra / DynamoDB** | Horizontal partitioning is first-class: the partition key hashes to a token that places rows on nodes; queries efficient only when they specify the partition key, otherwise require a scan/GSI | Makes the "single-shard vs. scatter" trade-off an explicit part of the data-modeling API |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Horizontal: scales total capacity and write throughput ~linearly with shard count | Cross-shard queries (no partition key, or aggregates) become scatter-gather, bounded by the slowest shard |
| Horizontal: each shard is smaller, so per-node indexes, backups, and working sets stay manageable | Requires a routing layer and a well-chosen partition key; a bad key creates hot shards and skew |
| Vertical: shrinks the hot row so more fits in cache and each read moves less data | Reads spanning both partitions become cross-store joins, adding latency and code complexity |
| Vertical: lets you match storage engine to data shape (relational hot fields, blob store for media) | A single logical update spanning partitions loses single-store transactionality (eventual consistency or sagas) |
| Both: partitioning is the only way to hold a dataset larger than the biggest single node | Partitioning alone gives no availability — each partition is a SPOF until separately replicated; operational complexity rises |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "This table won't fit on one machine / has billions of rows — how do you scale it?"
- "Write throughput is saturating the primary database."
- "The row is very wide but the hot path only reads a few columns."
- "You're storing large documents/images inline with the record — is that a problem?"
- "What's your partition key, and what happens to queries that don't use it?"

**What you say / do:**
Diagnose the axis first, out loud: "Is this a volume problem — too many rows or too much write QPS — or a width problem — rows too wide with hot and cold columns mixed?" Then commit: for volume, "I'd horizontally shard by `<key>` so capacity and writes scale with shard count, and I'd pick the key to match the dominant query so most reads are single-shard." For width, "I'd vertically split the hot narrow columns from the cold/bulky ones — moving blobs to object storage — so the hot table stays cache-friendly." Then pre-empt the cost: name scatter-gather (horizontal) or cross-store joins (vertical) before the interviewer does, and note that each shard still needs replication for availability.

**The trade-off statement (memorize this pattern):**
> "Horizontal sharding buys me linear capacity and write scaling, but only if queries carry the partition key — otherwise I pay scatter-gather across all shards. Vertical partitioning buys me a lean, cache-friendly hot path, but any read spanning both column groups becomes a cross-store join. For this system, since reads are almost always keyed by `user_id` and the table is uniformly accessed, this is a volume problem — I'd shard horizontally by `user_id` and push cross-user analytics to a separate OLAP store rather than scatter-gathering."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** Partitioning and replication are the same thing, or partitioning gives you high availability.
  ✅ **Reality:** They are orthogonal. Partitioning splits *different* data across nodes to scale capacity; replication copies the *same* data to scale reads and survive failures. A partition with no replica is a single point of failure for its slice of data. Real designs shard *and* replicate.

- ❌ **Misconception:** "Vertical partitioning" means the same as "vertical scaling."
  ✅ **Reality:** Vertical *scaling* means making one machine bigger (more CPU/RAM). Vertical *partitioning* means splitting a table's columns across stores. Same word, unrelated concepts — mixing them up is a classic interview stumble.

- ❌ **Misconception:** Once you shard horizontally, all queries get faster.
  ✅ **Reality:** Only queries that carry the partition key get faster (single-shard). Queries without it — aggregates, secondary-attribute lookups — get *slower*, because they fan out to every shard and wait on the slowest one. The partition key must match your dominant access pattern or you've hurt the common case.

- ❌ **Misconception:** The sharding *mechanism* (hash vs. range) is the main decision.
  ✅ **Reality:** The *partition key choice* matters more. A low-cardinality or skewed key (country, boolean, monotonic timestamp) creates hot shards regardless of whether you hash or range-partition. Pick a high-cardinality, evenly-distributed key that aligns with queries first; the mechanism is secondary.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** 2.6 Horizontal vs. Vertical Scaling — partitioning is *horizontal scaling applied to data*; and 3.6 Share-Nothing Architecture — sharded nodes owning disjoint data is the canonical share-nothing design that lets partitions scale independently
- **Enables:** 7.2 Hash Partitioning and 7.3 Range Partitioning (the two mechanisms for *how* to assign rows to horizontal shards), 7.4 Consistent Hashing (minimizing reshard cost), 7.6 Hot Partitions (the skew failure mode), and 7.7 Cross-Shard Queries (the scatter-gather problem this subtopic introduces)
- **Tension with:** Joins and transactions / strong consistency — both partitioning axes fragment data that was once co-located, so operations that need multiple partitions (cross-shard joins, multi-store transactions) become expensive or lose ACID guarantees; this is the core tension you manage when you choose to partition

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. Define horizontal and vertical partitioning in one sentence each, and state the single distinguishing property between them.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 5.*
HORIZONTAL: split by ROW — every partition has the identical schema but holds a
disjoint subset of rows, assigned by a partition key.
VERTICAL:   split by COLUMN/TABLE — the same entities are divided so different
attributes live in different stores (hot narrow columns vs. cold wide ones).
DISTINGUISHING PROPERTY: horizontal keeps all columns and splits rows; vertical
keeps all entities and splits columns. Rows vs. columns.

2. A `users` table is 60 columns wide; the hot path reads only 4 of them, but each row also stores a 2MB inline avatar blob that's rarely read. Which partitioning axis applies, and what specifically do you do?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Sections 6 and 8 (Model 3).*
This is a WIDTH problem → VERTICAL partitioning. The 2MB blob bloats every row,
evicting useful data from cache and making every read move megabytes. Move the
avatar to an object store (S3/GCS) keyed by user_id, and split the hot 4 columns
into a narrow users_core table. The hot path now reads small, cache-friendly rows;
the rare full-profile read pays a second lookup / cross-store join.

3. You horizontally shard `users` by `user_id`. A new feature needs `SELECT COUNT(*) FROM users WHERE country='JP'`. What happens, and why is it slow?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 9 (scatter-gather).*
The query has no partition key (it filters by country, not user_id), so the router
cannot target one shard. It fans out to ALL N shards (scatter-gather); each computes
a partial count; the coordinator sums them. It's slow because latency is bounded by
the SLOWEST shard and cost grows with shard count. Fix: serve such analytics from a
separate OLAP store / secondary index by country, not from the sharded OLTP table.

4. Name a real system and describe how it applies one of these axes, including the routing or join consequence.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 10.*
Vitess (over MySQL, from YouTube): horizontally partitions tables across many MySQL
instances behind one logical database. Its query router resolves whether a query is
single-shard (has the partition key → routed to one instance) or requires scatter-
gather (fanned to all shards and merged). This makes the single-shard-vs-scatter
trade-off explicit and operational. (Alternatives: Instagram shards Postgres by
user ID; DynamoDB/Cassandra partition by key hash.)

5. A candidate says "we'll shard the table, which also makes us fault-tolerant since data is spread across nodes." What's wrong, and what's missing?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Sections 6 and 13.*
Wrong: partitioning is NOT replication and provides no availability by itself.
Spreading DIFFERENT data across nodes means each shard is a single point of failure
for its slice — lose a shard, lose that slice entirely. What's missing: REPLICATION
under each shard. The correct design shards for capacity/throughput AND replicates
each shard for durability and read scaling. The two are orthogonal and combined.

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **"Designing Data-Intensive Applications" — Chapter 6, Partitioning** (Martin Kleppmann) — the definitive treatment; focus on partitioning + replication interplay and secondary-index partitioning
- [ ] **ByteByteGo "Database Sharding Explained"** — https://blog.bytebytego.com/p/database-sharding — accessible visual walkthrough of horizontal sharding and routing
- [ ] **Instagram Engineering — "Sharding & IDs at Instagram"** — https://instagram-engineering.com/sharding-ids-at-instagram-1cf5a71e5a5c — real-world horizontal sharding of Postgres with embedded shard IDs
- [ ] **Vitess documentation — "Sharding"** — https://vitess.io/docs/concepts/sharding/ — how a production router handles single-shard vs. scatter-gather queries
- [ ] **AWS Prescriptive Guidance — data partitioning patterns** — search "vertical partitioning" and "horizontal partitioning" in AWS docs for cloud-specific guidance and examples

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

- https://dev.to/somadevtoo/database-sharding-for-system-design-interview-1k6b

MODEL ANSWER — Criterion 1

Horizontal partitioning (sharding): splits a table by ROWS — every
shard has the identical, full schema but holds a disjoint subset of
the rows, assigned by a partition key.

Vertical partitioning: splits a table by COLUMNS — the same entities
(same primary key) are divided so different attributes live in
different stores, typically hot narrow columns separate from cold/
wide ones.

Distinguishing property: horizontal keeps ALL columns and splits the
rows; vertical keeps ALL entities and splits the columns. Rows vs.
columns. (Both preserve disjointness — no data is copied; that's what
makes it partitioning, not replication.)

MODEL ANSWER — Criterion 2

1. HORIZONTAL. Pressure = volume + write throughput (2B rows, writes
   saturating one node). Sharding spreads rows and writes across N
   nodes, scaling aggregate capacity and write QPS ~linearly.

2. VERTICAL. Pressure = row width. A 500KB blob stored inline bloats
   every row on disk and in cache, evicting hot rows and hurting scan/
   cache efficiency even for queries that never read it. Fix: move the
   blob to object storage (S3/GCS), keep a reference; split the 6 hot
   columns into a narrow table. Cost accepted: full-detail reads now
   need a second lookup.

3. VERTICAL. Pressure = hot/cold columns mixed → wide rows slow the hot
   path. Split hot balance fields (narrow, cache-friendly) from the
   cold audit/history column, sharing the same primary key. Cost: any
   op needing both becomes a cross-store read.

MODEL ANSWER — Criterion 3

(a) READ with partition key:
    Routing layer (client lib / proxy / coordinator) applies the
    partition function to user_id=12345 → resolves the owning shard →
    routes the query to that one shard (+ its read replica). ~1 hop,
    ≈ single-node latency.

(b) WRITE with partition key:
    Same routing: partition function → owning shard's primary → write,
    then that shard's own replication propagates to its replicas.
    Different keys map to different shards, so aggregate write
    throughput scales ~linearly with shard count.

(c) QUERY without partition key (e.g. WHERE country='JP'):
    Router can't localize → SCATTER-GATHER: fan the query to ALL N
    shards in parallel, each returns a partial result, coordinator
    merges. Slow because: latency is bounded by the SLOWEST shard,
    it consumes resources on every shard, and it gets worse as shard
    count grows. Hence: keep the dominant query on the partition key.

MODEL ANSWER — Criterion 4

(a) Trigger: any query that needs columns living in BOTH partitions.
    Profile-page render needs name+status (hot store) AND bio+avatar
    (cold store) → two lookups on the same user_id → application joins
    the two slices into one response. That's the cross-store join.

(b) Worth it when the hot path is (i) accessed disproportionately
    (e.g. 9:1 hot:cold) AND/OR (ii) the cold columns are much heavier
    (large blob). Either makes the common read lean and cache-friendly
    while the join is paid only on rare full reads.
    NOT worth it when access is ~even AND columns are similar-sized:
    you pay join overhead on half your traffic for little cache/width
    benefit — better to keep them together.

MODEL ANSWER — Criterion 5

Stage 0: One small table. Fits on one (replicated) node. Don't
         partition — pay no complexity tax.

Stage 1: WIDTH pressure appears first. Hot/cold columns mixed, blobs
         inline → wide rows, slow hot reads, poor cache hit rate
         (little unique data cached). → VERTICAL split: hot narrow
         store, cold store, blobs → object store + reference. Hot path
         now lean and cache-friendly. (Cheap step, no routing.)

Stage 2: VOLUME pressure appears on the hot store. Row count + write
         QPS outgrow one node. → HORIZONTAL shard the hot store by a
         high-cardinality, evenly-distributed key aligned to the
         dominant query. Capacity + writes now scale with shard count.

Why this order: sharding doesn't fix width and vertical doesn't fix
volume. Shard a wide table first and every shard inherits the width
problem. And sharding is the costly step (routing, rebalancing,
cross-shard queries), so defer it until a specific store truly must.
Under everything: replicate each shard.

MODEL ANSWER — Criterion 6

(a) Partitioning: each node holds DIFFERENT, disjoint data (no
    overlap). Replication: each node holds a COPY of the SAME data.

(b) Sharding alone gives NO fault tolerance. Each shard holds data no
    other shard has, so if a shard dies, 100% of requests for that
    slice fail — a partial outage. Fault tolerance requires replicating
    each shard (e.g., 1 primary + 2 replicas) so a node loss is
    survivable.

(c) Both, composed as a grid: N shards × R replicas. Partitioning
    scales capacity + throughput; replication (per shard) delivers HA,
    durability, and read scaling. Every shard is its own replica group.


7.1 HORIZONTAL vs VERTICAL PARTITIONING — CHEAT SHEET

§1 WHY IT EXISTS
One node has finite disk/RAM/CPU/IO; vertical hardware scaling flattens
and cost goes superlinear. Partitioning splits data across nodes so
capacity + throughput scale ~linearly with node count. (Don't partition
until a single replicated node genuinely can't cope — complexity tax.)

§2 THE TWO AXES (what's preserved vs split)
HORIZONTAL (= sharding): split ROWS. Each shard = FULL schema, disjoint
  rows, assigned by a partition key. Relieves VOLUME + write QPS.
VERTICAL: split COLUMNS/tables. Same entities (same PK), attributes
  divided across stores. Relieves ROW WIDTH + hot/cold + datatype mismatch.
Both are DISJOINT (no overlap) → that's partitioning, not replication.

§3 ROUTING (horizontal mechanics)
Read/write WITH key: routing layer applies partition fn → 1 owning shard.
  Different keys → different shards → aggregate writes scale ~linearly.
Query WITHOUT key: SCATTER-GATHER to all shards → merge; bounded by the
  SLOWEST shard, cost grows with shard count. Keep dominant query keyed.

§4 VERTICAL'S COST
Query needing columns from BOTH stores → cross-store join (2 lookups).
Worth it when: hot path is frequent AND/OR cold cols are heavy (big blob).
Not worth it when: access ~even AND columns similar-sized.

§5 ORDER AT SCALE (vertical → then horizontal)
Width pain shows first → vertical split (cheap, no routing).
Then volume pain on the hot store → shard it.
Why this order: sharding doesn't fix width (each shard inherits it) and
  is the costly step (routing/rebalancing/cross-shard) → defer it.

§6 PARTITIONING vs REPLICATION
Partition = DIFFERENT data per node (capacity/throughput).
Replication = SAME data copied (HA/durability/read scaling).
Sharding ALONE = zero fault tolerance; lose a shard = lose that slice.
Compose as a grid: N shards × R replicas; each shard is a replica group.

§7 PARTITION-KEY RULE (the tension)
Want two properties that CONFLICT: even distribution (balance) vs query
  locality (aligns with dominant query). Prioritize locality for the
  dominant query, then engineer away the hotspot (composite key, split).
GOTCHA: high cardinality ≠ even load; a hot value still skews (celebrity).