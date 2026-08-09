# 8.7 Read vs. Write Optimization

> **Topic:** Topic 8 — Database Fundamentals
> **Phase:** C — Data Storage Branch
> **Depth Tier:** 🥈 T2 (Depth) — budget ~1h
> **Prereqs:** 8.3 (Data Modeling — Normalization/Denormalization), 8.4 (Indexing — B-tree, LSM-tree), 8.2 (OLTP vs. OLAP)
> **Date studied:** _____

> 🥈 **T2 means:** this is a follow-up probe, not a core design decision. You need
> to explain it confidently and name its trade-off — you do not need to design
> a system around it from scratch.

---

## 0. 🧭 The Question This Answers

8.3 showed one specific trade — denormalize and you buy faster reads by paying at write time. 8.4 showed another — an LSM-tree buys fast writes by paying at read time. Both are instances of the same underlying axis, and this subtopic makes that axis explicit: **every storage and schema decision sits on a dial between optimizing the read path and optimizing the write path, and no technique moves that dial for free.**

The tension is that "make the database fast" is not a well-formed goal — fast for which side? A schema, an index, or a storage engine tuned for one side almost always taxes the other, and the craft is knowing your workload's read:write ratio well enough to spend deliberately instead of reflexively reaching for whichever fix fixed the last complaint.

**The question:** *Given a workload's read:write ratio, which specific lever do you pull to speed up the dominant side, and exactly what does it cost the other side?*

> **→ Next:** Before naming the levers, what actually goes wrong when someone optimizes without asking which side is hot?

---

## 1. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds.*
>
> ⏭️ **First time through?** Skip to §2 and come back here for revision.

```
§ 1  WHY IT EXISTS
Every read-side speedup — a denormalized column, a covering index, a cache, a
read replica — adds work or risk to the write path: more copies to keep in
sync, more index entries to maintain per insert, more cache invalidation to
trigger, more replicas to propagate to. Every write-side speedup — an
LSM-tree's sequential append, a write buffer, async replication — defers or
relocates cost onto the read path: more files to merge on a lookup, staler
data, more background compaction competing for I/O. Nothing here is free;
tuning "the database" without naming which side is hot just moves the
bottleneck somewhere less visible.

§ 2  WHAT IT IS
READ:WRITE RATIO   The primary signal. How many reads happen per write for
                   this specific access pattern — not the whole system.
READ-OPTIMIZED     A schema/engine/cache choice that reduces read-time work
LEVER              by doing more work, or accepting more risk, at write time.
WRITE-OPTIMIZED    A schema/engine choice that reduces write-time work by
LEVER              deferring or relocating cost to read time (or to a later,
                   background process).
READ AMPLIFICATION How many underlying reads (pages, SSTables, replicas) one
                   logical read triggers. Rises when writes are optimized.
WRITE AMPLIFICATION How many physical writes one logical write triggers.
                    Rises when reads are optimized (8.3).

§ 3  THE MECHANISM
MEASURE THE RATIO   Per access pattern, not per table. A `users` table can be
                    read-heavy for profile lookups and write-heavy for a
                    presence/last-seen column in the same schema.
PICK THE LEVER      Read-heavy → denormalize (8.3), covering index (8.4),
                    cache, read replica. Write-heavy → LSM-tree (8.4),
                    write buffering/batching, async replication.
PRICE IT            Every lever above has a named cost on the other side —
                    see §4/§6. If you can't name the cost, you haven't
                    finished the analysis, you've just picked a fashionable
                    tool.
SPLIT IF NEEDED     When one schema can't serve both sides well at extreme
                    skew, or the two sides need different consistency
                    guarantees, stop compromising one model — run two
                    (CQRS) and accept a sync lag between them.

§ 4  USE / AVOID
OPTIMIZE FOR READS when: read:write ratio is high (rule of thumb ≥ ~10:1,
  strong case past ~100:1 — same threshold as 8.3's denormalization signal)
  and some staleness or write-side cost is tolerable.
OPTIMIZE FOR WRITES when: the workload is ingestion-shaped — logs, events,
  telemetry, metrics — with high sustained write volume and read patterns
  that are sequential or rare (8.2's OLAP-adjacent shape).
SPLIT WITH CQRS when: both sides are hot AND need different consistency or
  query shapes that no single schema serves well.
AVOID applying a read lever (cache, extra index, denormalized column) to a
  write-dominant path — you've added fixed per-write overhead to fix a
  bottleneck that was never on the read side.
AVOID assuming SQL = read-optimized and NoSQL = write-optimized — the real
  axis is the storage engine's data structure (B-tree vs. LSM-tree, 8.4)
  and the schema (8.3), which correlate with but are not defined by the
  query language.

§ 5  NUMBERS TO ANCHOR THE DISCUSSION
~10:1 read:write is the rough point where a read lever starts paying for
  itself; ~100:1+ is where 8.3's denormalization case gets strong.
LSM-tree writes are O(1) sequential appends to a memtable + commit log;
  B-tree writes are O(log n) random-access page writes that can trigger
  page splits. This is *why* Cassandra/RocksDB choose LSM for high ingest.
Read amplification on an LSM-tree without mitigation: one point read may
  check the memtable plus every un-compacted SSTable — bounded in practice
  by Bloom filters (8.10) and compaction, not eliminated by them.
Async replication lag is typically milliseconds to low seconds; that lag
  is the exact price of scaling reads horizontally via read replicas
  without touching write throughput at all.

§ 6  INTERVIEW TRIGGERS + GOTCHA
→ "This does 50k writes/sec, few reads"         → LSM-tree engine, write
                                                   buffering, defer indexing
→ "This page is read a million times a day,     → denormalize, cache,
   written a few times a day"                     covering index, replica
→ "How do you scale reads without touching       → read replicas, or a
   the write path?"                               separate read model (CQRS)
→ "Why Cassandra over Postgres here?"            → LSM vs. B-tree write
                                                   path, named explicitly
GOTCHA: Naming a lever without naming which side pays for it. "We'd add a
  cache" is not an answer until you've said what the cache does to the
  write path (invalidation) and what happens to reads when it's a write-
  heavy workload the cache barely helps.
```

---

## 2. 🧠 The Mindmap

> *The picture to hold in your head while you study.*

```
                    ┌────────────────────────────────────┐
                    │   READ vs. WRITE OPTIMIZATION       │
                    │  "which side pays for the speedup?" │
                    └──────────────────┬───────────────────┘
                                       │
     ┌───────────────┬─────────────────┼─────────────────┬───────────────┐
     ▼               ▼                 ▼                 ▼               ▼
 THE SIGNAL      READ-OPTIMIZED   WRITE-OPTIMIZED    THE COST THAT    CQRS —
 (measure         LEVERS           LEVERS             MOVES            THE SPLIT
  first)
 ├ read:write    ├ denormalize    ├ LSM-tree         ├ write          ├ separate
 │  ratio          (8.3)            (8.4)              amplification   read + write
 ├ per access    ├ covering       ├ write buffer /   ├ read           │  models
 │  pattern,       index (8.4)      batching          amplification  ├ sync lag is
 │  not per      ├ cache          ├ async            ├ replication     the price
 │  table          (Topic 5)        replication        lag           ├ used at
 └ staleness     └ read replica   └ defer index      └ nothing is       extreme
   tolerance                        maintenance         eliminated,     skew, not
                                                         only moved      by default
```

**How to read it:** left to right is the argument. You start at **the signal** — measure before you pick anything — then choose from either **read-optimized** or **write-optimized levers** depending on which side is hot; either choice creates **the cost that moves** to the other side; and when that cost gets too large for one schema to absorb on both sides at once, **CQRS** removes the compromise by splitting the model entirely.

---

## 3. 🔥 The Problem

Left unexamined, "optimize the database" collapses into optimizing for whichever side is currently making noise — usually reads, because a slow page load is what a user notices and files a ticket about. So the instinctive move is to add an index for every slow query, denormalize every join that shows up in a profiler, and wrap a cache around anything read twice. Each of these fixes is individually correct in isolation and collectively dangerous, because every one of them adds fixed cost to every write: one more index to update, one more copy to keep in sync, one more cache entry to invalidate. On a read-heavy table this is a good trade. On a write-heavy table — an events table, an activity log, a metrics ingestion path — the same fixes make writes slower without meaningfully helping reads, because reads were never the bottleneck.

The reverse mistake is just as common and less visible: a team picks a write-optimized engine (an LSM-tree store, an append-only log) because "we have a lot of writes," without checking whether reads against that same data are also frequent and latency-sensitive. They then discover that point reads against an LSM-tree must check the in-memory memtable and potentially several on-disk SSTables before compaction has caught up — read amplification they didn't budget for, because the team asked "how do we handle the writes" and never asked "what does this cost our reads."

The insight that resolves both mistakes is the same one 8.3 and 8.4 already demonstrated separately: no technique removes work, it relocates it across the read/write boundary. The only question worth asking before reaching for any lever is which side of *this specific access pattern's* ratio is dominant, because the same table can be read-heavy for one query and write-heavy for another.

### ✅ Checkpoint

1. A team adds a cache in front of a table that receives roughly equal reads and writes, and cache hit rate improves latency in staging. In production the write path gets measurably slower and overall throughput drops. Explain what happened using the read/write relocation framing, not just "caching has overhead."

   > 💡 *If you hesitate, re-read the second paragraph — the reverse mistake — and the closing insight about relocation, not elimination.*

MODEL ANSWER — §3 Checkpoint

MECHANISM (relocation, not elimination)
  Adding a cache doesn't remove work — it moves read-time cost
  (recompute/refetch on every read) to write-time cost (invalidate
  + keep the cache in sync on every write). This is the same
  relocation argument as denormalization (8.3), applied to caching.

WHY IT BACKFIRES SPECIFICALLY HERE (near 1:1 ratio)
  The read win only pays off for the fraction of traffic that's
  reads. The write cost lands on the fraction that's writes. At
  ~50:50, the added per-write invalidation cost is incurred on
  almost as many operations as the ones that got faster — so the
  relocated cost isn't amortized away, it's paid nearly dollar-for-
  dollar against the benefit. At a skewed ratio (say 100:1), that
  same fixed invalidation cost lands on ~1% of operations and is
  easily funded by the win on the other 99%.

THE ROOT CAUSE
  This is exactly the naive reflex §3 opens with: reaching for a
  cache because a value is "read twice," without first checking
  whether the access pattern is actually read-dominant. A read
  lever applied to a workload that isn't read-skewed doesn't fail
  because caching is bad — it fails because the lever was matched
  to the wrong ratio.

ONE-LINE VERSION
  Cost relocates, it doesn't disappear — and at 1:1 there's no
  skew left to absorb it.

> **→ Next:** If cost always relocates rather than disappears, what's the actual menu of levers on each side, and how do they connect to what you already know from 8.3 and 8.4?

---

## 4. 💡 The Core Idea

**Read/write optimization is the practice of identifying which side of a workload's read:write ratio is dominant for a given access pattern, and deliberately choosing a schema, index, cache, or storage-engine technique that relocates cost onto the non-dominant side — because every such technique moves work across the read/write boundary rather than eliminating it.**

**Visual required:** build-chain diagram.

```
 [RATIO IS THE SIGNAL] ──▶ [LEVERS PER SIDE] ──▶ [COST NEVER DISAPPEARS] ──▶ [CQRS SPLITS THE MODEL]
   because you can't        therefore each          so at extreme or           when one schema can't
   choose a lever            lever pushes cost       divergent skew,           absorb both costs,
   without knowing           onto the OTHER          the relocated             stop compromising —
   which side is hot         side, never both        cost has to land          run two models
```

### The Ratio Is the Signal

Everything downstream depends on first measuring, not guessing, the read:write ratio for the *specific access pattern* in question — not the table, not the service, the pattern. A `users` table can be read-heavy for "fetch profile by id" and write-heavy for "update last-seen timestamp" in the same schema, and those two columns deserve different treatment. This is the same discipline 8.2 introduced for classifying a workload as OLTP or OLAP, narrowed down to a single access pattern instead of a whole system.

### Levers Per Side

Once the dominant side is known, the lever choice follows directly. **Read-optimized levers** move cost to write time: denormalization (8.3) copies a fact so a read needs no join; a covering index (8.4) lets a read be satisfied from the index alone; a cache serves repeat reads without touching storage; a read replica adds read capacity that never touches the write path at all. **Write-optimized levers** move cost to read time, or defer it to a background process: an LSM-tree (8.4) turns writes into cheap sequential appends and pays for it later during compaction and at read time; write buffering and batching coalesce many small writes into fewer larger ones; async replication lets a write acknowledge before every replica has it, deferring consistency to a background propagation.

### Cost Never Disappears

Every lever above has a named bill. A cache's bill is invalidation complexity and a miss path that still hits storage. A read replica's bill is replication lag — reads may be stale, and write throughput doesn't improve at all, because every write still funnels through the primary. An LSM-tree's bill is read amplification: a point read may need to check several files before compaction has merged them down. This is the exact same "relocation, not elimination" argument 8.3 built for denormalization, now generalized to every technique on both sides of the dial.

### CQRS Splits the Model Entirely

When a single schema can't serve both a hot read pattern and a hot write pattern well — or when the two need genuinely different consistency guarantees — the escalation is to stop compromising one model and instead maintain two: a write model optimized purely for correct, fast writes, and a separate read model optimized purely for the query shape reads need, kept in sync by the same kind of mechanism (transaction, CDC, async job) 8.3 required you to name for any denormalization. CQRS is not a new idea at this point — it's the read/write dial pushed to its most extreme, aggressive setting.

### ✅ Checkpoint

1. A logging pipeline ingests 80,000 events/sec and is queried only a handful of times a day, for ad hoc debugging. Using the build chain above, explain why choosing an LSM-tree engine is the correct lever, and name the specific cost it creates on the read side.

   > 💡 *If you hesitate, re-read "Levers Per Side" and "Cost Never Disappears."*

> **→ Next:** You know the two lever families and that cost always lands somewhere. What actually happens mechanically when you diagnose a workload and apply the right one?

MODEL ANSWER — §4 Checkpoint

RATIO IS THE SIGNAL
  80,000 writes/sec vs. a handful of reads/day = an extreme
  write-dominant ratio, the opposite end of 8.3's ≥10:1 read-heavy
  threshold. This is squarely the "ingestion-shaped" write-heavy
  case §6 names.

LEVERS PER SIDE — why LSM-tree is correct
  A B-tree write is an in-place, random-access page write —
  O(log n) plus possible page splits. An LSM-tree write is instead:
    1. append to the write-ahead log (durability)
    2. insert into the in-memory memtable (sorted, e.g. skip list)
    3. once the memtable fills, flush it as an immutable, sorted
       SSTable — a sequential disk write, not random access
  Sequential writes sustain far higher throughput than random
  writes, which is exactly what 80k/sec ingestion needs.

COST NEVER DISAPPEARS — the read-side price
  READ AMPLIFICATION: a single logical read may have to check the
  memtable, then potentially several on-disk SSTables, before
  compaction has merged them down. Bloom filters mitigate wasted
  disk seeks for point lookups (skip SSTables that provably don't
  contain the key) but don't eliminate the multi-file check.
  Range queries are the sharpest case: no single Bloom filter
  covers a range, so the read must walk the memtable and every
  relevant SSTable in recency order and merge results — exactly
  the ad hoc debugging query pattern here.

ONE-LINE VERSION
  Sequential-write throughput was bought by making every read
  potentially multi-file — the correct trade for this ratio,
  priced honestly.

---

## 5. ⚙️ How It Actually Works

**Happy path — diagnosing and applying the right lever:**

1. Measure the read:write ratio and the latency/staleness budget for the *specific access pattern* under discussion, not the table or service as a whole.
2. Identify where the dominant operation currently pays its cost — e.g., a read paying join cost, or a write paying random-page-write and index-maintenance cost.
3. Select the lever that matches the dominant side: read-heavy → denormalize / covering index / cache / read replica; write-heavy → LSM-tree engine / write buffering / batching / async replication.
4. Verify the cost actually relocated rather than vanished — confirm write latency or fan-out increased correspondingly, or that replica lag now bounds read freshness. If nothing on the other side got more expensive, you didn't apply a real lever, you found a genuine inefficiency instead (a missing index, a redundant round trip) — a different problem from the one this subtopic addresses.
5. If the ratio is extreme on both sides simultaneously, or the two sides need different consistency guarantees, stop iterating on one schema and consider splitting into a CQRS read model and write model instead.

> 🗺️ **Mental model — a fixed renovation budget.** Optimizing for reads and writes is like renovating a house with a fixed budget: knocking down a wall to enlarge the living room always shrinks another room by the same amount square-footage-wise. There is no renovation that creates space, only one that relocates it to where you need it more. *Where it breaks down:* a few real techniques do reduce total work rather than just relocate it — a Bloom filter (8.10) avoids a wasted disk read on both the read and write side of an LSM-tree — so the "always zero-sum" framing is a strong default, not an absolute law.

**Failure & edge cases:**

- **Whack-a-mole tuning.** Levers get chosen based on whichever complaint arrived most recently rather than the measured ratio, so a table's optimization ends up serving last month's access pattern instead of today's — and as the ratio drifts (a table that was write-heavy during a migration becomes read-heavy after), nobody revisits the choice.
- **Read replicas mistaken for a write fix.** A team scales out read replicas expecting write throughput to improve; it doesn't, because every write still funnels through the primary. Replicas address read capacity and read latency only.
- **Compaction stalls on LSM-trees.** "Write-optimized" holds only as long as background compaction keeps pace; if foreground write volume outruns compaction, un-merged SSTables pile up, read amplification climbs, and compaction itself starts competing with live traffic for I/O and CPU — the deferred cost from §4 arriving all at once.
- **Caching a workload with no locality.** A cache only helps reads that repeat or cluster; a write-heavy or uniformly-random read pattern gets little hit-rate benefit while still paying full invalidation cost on every write — a read lever applied to a pattern that isn't actually read-dominant.

**The diagnostic pipeline, end to end:**

```
① measure ratio ──▶ ② find where cost      ──▶ ③ pick matching  ──▶ ④ verify cost
   per access         currently sits           lever                relocated
   pattern            (read pays join? write                        (not eliminated)
                       pays index upkeep?)                                │
                                                                          ▼
                                                          ⑤ both sides hot / diverging
                                                             consistency needs?
                                                                          │
                                                                    yes ─┴─ no
                                                                     │        │
                                                                     ▼        ▼
                                                              SPLIT (CQRS)  DONE —
                                                                             single
                                                                             schema
                                                                             holds
```

### ✅ Checkpoint

1. A team ships an LSM-tree-backed store for a high-ingest workload, confirms writes are fast, and calls the optimization complete. Three months later, point-read latency has climbed steadily even though write volume hasn't changed. What did they fail to account for, and what operational factor explains the drift?

   > 💡 *If you hesitate, re-read the "Compaction stalls on LSM-trees" failure case.*

MODEL ANSWER — §5 Checkpoint

WHAT THEY FAILED TO ACCOUNT FOR
  "Write-optimized" isn't a permanent state, it's conditional on
  background compaction keeping pace with foreground writes. The
  team measured write latency, saw it was fast, and declared the
  optimization complete — without checking whether the read-side
  cost this lever defers (§4) was actually being paid down by
  compaction, or just accumulating.

THE OPERATIONAL FACTOR — compaction falling behind
  If sustained write throughput exceeds what compaction can merge,
  un-compacted SSTables accumulate faster than they're consolidated.
  Each new SSTable is one more file a read must check (after the
  memtable and Bloom filters rule out what they can) before it can
  return an answer.

WHY LATENCY CLIMBS WITH CONSTANT WRITE VOLUME
  Write volume didn't change — but the BACKLOG of un-merged
  SSTables did, growing steadily every day compaction stays behind.
  Read amplification is a function of SSTable count, not of current
  write rate, so point-read latency tracks the size of that backlog
  and climbs even though nothing about the write path changed.

THE THROUGH-LINE
  This is the deferred cost from §4 arriving all at once: the bill
  for "cheap writes" was never cancelled, it was postponed to
  compaction — and postponed cost that never gets paid down
  compounds instead of disappearing.

> **→ Next:** You can diagnose and apply a lever. In a live design, which one do you actually pick, and what does each choice cost in production?

---

## 6. ⚖️ The Decision — When, and What It Costs

The default is **measure before choosing** — never assume a workload's shape from its category ("it's an events table, so it must be write-heavy") without checking the actual access patterns against it. Once measured, four situations decide the move. Near a 1:1 ratio with no strong latency pressure on either side, the right answer is usually to do nothing special: a normalized schema on a B-tree engine keeps both sides adequately served, and any lever you'd add costs more than the ratio justifies. A read-heavy pattern (roughly ≥10:1, a strong case past ~100:1) with tolerable staleness calls for denormalization, a covering index, a cache, or a read replica — pick based on whether the bottleneck is join cost, computation cost, or read throughput specifically. A write-heavy, ingestion-shaped pattern calls for an LSM-tree engine, write buffering, or async replication, accepting read amplification and staleness as the price. And when a single access pattern needs to be both hot on reads and hot on writes with genuinely different consistency requirements, no single schema serves both well — that's the signal to split into a CQRS read model and write model rather than keep compromising one.

**Decision tree:**

```
              What's the read:write ratio for THIS access pattern?
                                │
        ┌───────────near 1:1───┼───read-heavy (≥10:1)───write-heavy (ingest)───┐
        ▼                       │                                              ▼
   NO SPECIAL LEVER.            │                                    LSM-TREE / WRITE
   Normalized schema,           │                                    BUFFERING / ASYNC
   B-tree, done.                │                                    REPLICATION.
                                 ▼                                    Accept read
                    Is staleness tolerable                            amplification.
                    for this read path?
                          │
                ┌────no───┴───yes──┐
                ▼                   ▼
        Denormalize only      DENORMALIZE / CACHE /
        with a strong sync    COVERING INDEX / READ
        (transactional) or    REPLICA. Name the sync
        keep the join —       mechanism (8.3).
        don't fake it with
        a stale cache.
                                     │
                    Both sides ALSO hot with diverging
                    consistency needs on the same data?
                                     │
                              ┌──────┴──────┐
                              ▼             ▼
                            yes            no
                              │             │
                              ▼             ▼
                   SPLIT — CQRS read    Single schema with the
                   model + write        chosen lever is enough.
                   model, synced.
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Denormalization / cache / covering index (read levers)** — reads become single-fetch or in-memory, latency drops and becomes predictable | Write fan-out, cache invalidation complexity, and staleness risk — the exact source-of-truth/sync-mechanism obligation from 8.3 |
| **LSM-tree engine (write lever)** — writes are O(1) sequential appends, sustaining very high ingest throughput | Read amplification — a point read may check the memtable plus multiple SSTables — and background compaction competes with live traffic for I/O |
| **Read replicas** — horizontally scale read throughput without touching the write path at all | Replication lag makes replica reads stale by design, and write throughput is completely unaffected — the wrong lever if writes are the bottleneck |
| **CQRS split models** — each side can be optimized without compromising the other | Two models to build, operate, and keep in sync; the sync lag is now a first-class part of the system's consistency story, not an incidental detail |

### In production

| System | How it applies | The nuance |
|--------|----------------|------------|
| **Cassandra / ScyllaDB** | LSM-tree storage engine purpose-built for high sustained write throughput — sequential commit log + memtable, flushed and compacted in the background | Compaction strategy (size-tiered vs. leveled) is itself a read/write dial: size-tiered favors write throughput with higher read amplification, leveled favors read latency at higher write amplification |
| **PostgreSQL / MySQL (OLTP default)** | B-tree storage engine, read-optimized by default; read replicas added explicitly for horizontal read scaling | Replication lag under heavy write load can push replica reads seconds behind the primary — an explicit trade the application must tolerate or route around |
| **Instagram / Twitter home timelines** | Fan-out-on-write pushes read optimization to its extreme — a timeline read is one fetch, at the cost of writing a single post into millions of follower timelines | This is the same lever family as 8.3's denormalization, applied at social-network scale; celebrity accounts break the pattern and need a hybrid pull-on-read fallback |
| **Kafka** | Append-only log is a pure write-optimized structure; consumers read sequentially rather than doing arbitrary point lookups | Converts the read pattern itself into something cheap (sequential scan from an offset) rather than trying to make arbitrary reads fast against a write-optimized structure |
| **E-commerce search/catalog (CQRS in practice)** | Write model is a normalized order/inventory database; read model is a precomputed, denormalized search index (e.g., Elasticsearch) rebuilt from the write model via a pipeline | The read model can lag the write model by seconds to minutes; a schema change on the write side requires a full reindex/backfill of the read model, not a simple migration |

### ✅ Checkpoint

1. A social app's notification feed is read constantly (every app open) and written to constantly (every like, comment, and follow generates a notification). Both sides are hot, and reads need to reflect writes within a few seconds at most. Would you reach for a single well-tuned schema or split into CQRS? Justify using the decision tree above.

   > 💡 *If you hesitate, re-read the last branch of the decision tree — both sides hot with diverging needs.*

MODEL ANSWER — §6 Checkpoint

RATIO + VOLUME
  Read:write ≈ 1:1, but this isn't the "do nothing" branch of the
  decision tree — that branch assumes no strong latency pressure
  on either side. Here BOTH sides are hot (every app open reads,
  every like/comment/follow writes) and both have real latency
  requirements: reads must reflect writes within a few seconds.

WHY A SINGLE SCHEMA FAILS
  A single schema tuned for fast writes (buffer, batch, defer index
  maintenance) would tax reads; tuned for fast reads (denormalize,
  cache, covering index) it would tax writes. At 1:1 with both
  sides genuinely hot, there's no "less important" side to absorb
  the relocated cost — any single-schema compromise degrades a
  path that matters.

THE DECISION
  Split via CQRS: a write model optimized purely for ingesting
  notifications fast and correctly, and a separate read model
  optimized purely for serving the feed query shape. Sync via CDC
  off the write model — its typical lag (ms to low seconds) fits
  inside the "few seconds at most" freshness requirement, and
  unlike a transaction it doesn't force both models into the same
  database or shard.

THE PRICE, NAMED
  Two models to build and operate, and CDC lag is now a first-class
  part of the consistency story — a like can register on the write
  side microseconds before it's visible in the feed read model.
  That's the accepted cost of not compromising either side.


> **→ Next:** Can you defend this under interview pressure — and hold up when the interviewer pushes on the cost you claimed you'd pay?

---

## 7. 🎯 In the Interview

**When an interviewer asks / says:**
- "This service does 50,000 writes a second and only occasional reads — how would you design the storage layer?"
- "This endpoint is read a million times a day and written to a handful of times — what would you change?"
- "How would you scale reads without touching your write path at all?"
- "Walk me through why you'd pick Cassandra over Postgres for this."

**What you say / do:**
This surfaces in the schema/data-model phase immediately after choosing SQL vs. NoSQL (8.1) and classifying the workload (8.2), and resurfaces hard in the deep dive the moment the interviewer gives you a concrete read or write number. Lead by stating the ratio (measured or explicitly assumed), name which side is dominant, name the specific lever, price it unprompted, and give the condition that would flip your answer.

**The trade-off statement (write-heavy variant):**
> "This write path is doing roughly 50,000 events a second with only occasional ad hoc reads for debugging, so I'd optimize for writes — an LSM-tree-backed store like Cassandra instead of a B-tree engine, because LSM writes are sequential appends to a memtable and commit log rather than in-place random-access page writes, which is what lets it sustain that ingest rate. The cost is read amplification: a point read may have to check the memtable plus several SSTables, mitigated but not eliminated by Bloom filters and compaction, and ad hoc analytical queries against this store will be slow by design. I'd change my answer if the read pattern shifted to needing frequent, low-latency point lookups on recent events — at that point I'd add a read-optimized layer in front rather than fight the storage engine."

**The trade-off statement (read-heavy variant):**
> "If instead this were a product page read 200,000 times a minute per popular item and edited a few times a day, I'd push the other direction: denormalize the category and price fields directly onto the product row, add a covering index for the page's exact filter and sort, and put a cache in front with a TTL matched to how stale the display can tolerably be. The cost lands entirely on the write side — every edit fans out to the copies and invalidates the cache — which is acceptable because writes are rare. I'd change my answer for any field that has to be transactionally exact, like live inventory count; that one I'd read straight from the source instead of the cache, because a stale count there isn't a UX nuisance, it's a correctness bug."

### ⚠️ Traps

- ❌ **Trap:** "We'll just add a cache/index to make it fast" — without first asking whether the workload is read- or write-dominant.
  ✅ **Reality:** Caches and indexes both add fixed cost to every write — invalidation, index maintenance. Applying either to a write-heavy path adds overhead without touching the actual bottleneck, which was never on the read side.

- ❌ **Trap:** "NoSQL is for write-heavy workloads, SQL is for read-heavy ones."
  ✅ **Reality:** The deciding factor is the storage engine's data structure — B-tree vs. LSM-tree (8.4) — and the schema design (8.3), not the query language. Postgres can be tuned write-heavy and Cassandra can serve read-heavy patterns poorly if the wrong engine or model is chosen; SQL-vs-NoSQL correlates with this axis but doesn't define it.

- ❌ **Trap:** "Read replicas will fix our write bottleneck."
  ✅ **Reality:** Replicas scale read throughput horizontally; every write still funnels through the primary. If writes are the actual bottleneck, adding replicas doesn't touch it — a mismatch between the symptom and the lever.

- ❌ **Trap:** "We picked an LSM-tree store, so reads are just as fast as writes now."
  ✅ **Reality:** "Write-optimized" is not "equally fast at everything" — it's an explicit trade. LSM-trees pay for fast writes with read amplification across the memtable and un-compacted SSTables, mitigated by Bloom filters and compaction, never eliminated.

### ✅ Checkpoint — adversarial stress test

1. You've told the interviewer you'd denormalize a hot read field and cache it with a 30-second TTL. They push: *"Your write volume on the source field just increased 50x due to a new feature. Walk me through what breaks first, how you'd detect it, and whether your original lever choice still holds."*

   > 💡 *This is the gate. A complete answer covers: write amplification scaling directly with the new write volume (8.3), the cache's invalidation traffic scaling with it too, the specific signal you'd monitor (write latency on the source table, fan-out queue depth, cache invalidation rate) rather than waiting for a user-visible symptom, and the honest re-evaluation — at 50x the write volume the read:write ratio may have moved enough that the lever you originally chose no longer pays for itself, and you'd need to re-measure rather than assume the original decision still stands. If you can't answer this cleanly, you are not done.*

MODEL ANSWER — §7 Adversarial Stress Test

WHAT BREAKS FIRST
  Not "writes in general" — specifically WRITE AMPLIFICATION. Every
  write to the source field now also fans out to update the
  denormalized copy and invalidates the cache entry. At 50x source
  write volume, that fan-out/invalidation traffic is what scales
  50x and saturates first, ahead of the base write path itself.

DETECTION — a leading signal, not a lagging one
  Don't wait for user-facing write API p99 to spike — that's
  downstream and already too late. Instrument the fan-out path
  directly: put writes to the denormalized copy behind a queue and
  monitor QUEUE DEPTH / lag. A growing backlog is the early warning;
  by the time API p99 moves, the backlog has already been building.

DOES THE ORIGINAL LEVER STILL HOLD?
  Re-measure, don't assume. §3 already proved a read lever (cache/
  denorm) at a near-1:1 ratio doesn't pay for itself — the relocated
  write cost lands on almost as many operations as the ones that
  benefit. If 50x write growth moved this ratio from clearly
  read-dominant toward 1:1, the original choice is now suspect on
  its own terms, not just under new load.
  - If ratio settled near 1:1 AND absolute volume is high on both
    sides: this is now the "both sides hot" condition from §6 —
    stop patching a single schema and split into CQRS instead.
  - If ratio is still meaningfully read-skewed: keep the lever,
    but fix the fan-out bottleneck itself (batch the invalidations,
    or move fan-out fully async off the write's critical path).

THE THROUGH-LINE
  A lever's justification is a function of the ratio at the time
  it was chosen. A 50x shift on one side is exactly the kind of
  event that should trigger re-measuring the ratio, not defending
  the original decision.
---

## 8. 🔗 Connections & Sources

**Builds on:** **8.3 Data Modeling — Normalization and Denormalization**, which supplies the read-side lever (denormalization) and the source-of-truth/sync-mechanism vocabulary this subtopic reuses for every lever, not just that one. Also **8.4 Indexing**, which supplies the write-side lever (LSM-tree vs. B-tree) as a storage-engine-level instance of the same axis, and **8.2 OLTP vs. OLAP**, which established workload classification as the precursor to measuring a ratio at all.

**Enables:** **8.10 Bloom filters**, the concrete mechanism that bounds (without eliminating) the read amplification an LSM-tree creates — the cost named here, mitigated there. Also **Topic 5 Caching**, which is this subtopic's read lever explored in full depth, and **24.1–24.3 Fan-out**, which is the read-optimization lever pushed to social-network extremes.

**Tension with:** **8.6 ACID Transactions** — async replication and CQRS both loosen consistency guarantees in exchange for splitting or relocating read/write cost, directly trading against the atomicity and isolation guarantees 8.6 established as defaults for a system of record.

### 📚 Further reading

- [ ] **Designing Data-Intensive Applications, Chapter 3 — Storage and Retrieval** — Kleppmann — the canonical B-tree vs. LSM-tree comparison and read/write amplification trade-offs this subtopic generalizes
- [ ] **Martin Fowler — "CQRS"** — https://martinfowler.com/bliki/CQRS.html — the read/write dial pushed to its most extreme, architectural form
- [ ] **DataStax — "How is data written?"** — https://docs.datastax.com/en/cassandra-oss/3.0/cassandra/dml/dmlHowDataWritten.html — the Cassandra write path (memtable, commit log, compaction) as a concrete write-optimized mechanism
- [ ] **AWS — "Working with read replicas" (RDS/Aurora)** — https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html — the operational reality of replication lag as the price of read scaling
- [ ] **Discord Engineering — "How Discord Stores Trillions of Messages"** — search Discord's engineering blog — a real migration driven explicitly by a read/write ratio shift (Cassandra to ScyllaDB)

---

## 9. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
