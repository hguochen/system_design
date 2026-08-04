# 8.4 Indexing — B-tree, LSM-tree, Composite Indexes

> **Topic:** Topic 8 — Database Fundamentals
> **Phase:** C — Data Storage Branch
> **Depth Tier:** 🥇 T1 (Core) — budget ~3h
> **Prereqs:** 8.1 (SQL vs. NoSQL), 8.2 (OLTP vs. OLAP), 8.3 (Normalization & Denormalization)
> **Date studied:** 2026-08-03

---

## 0. 🧭 The Question This Answers

8.3 settled **where a fact lives**. This subtopic asks the question that immediately follows: given that the fact lives somewhere among a hundred million rows, **how does the database find it without reading all of them?** The answer is always the same shape — you build a second, redundant, *ordered* structure whose only job is to narrow the search. That structure is an index, and choosing which ones to build is one of the few database decisions a candidate is asked to make concretely, on a whiteboard, with real column names.

The tension is that an index is not a free accelerator. It is a copy of your data, sorted differently, that must be kept correct on every single write. Every index you add makes some reads dramatically cheaper and makes *all* writes to that table more expensive, permanently. And the two dominant index engines — the B-tree and the LSM-tree — resolve that tension in opposite directions, which is why the same schema can be the right answer on Postgres and the wrong answer on Cassandra.

**The question:** *What is the smallest set of index structures that makes my hot queries fast — and what exactly am I paying for each one on the write path?*

> **→ Next:** Before we can price an index, we need to see what the world looks like without one — and why the obvious fixes don't work. What actually breaks?

---

## 1. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*
>
> ⏭️ **First time through this topic?** Skip to §2 and come back here for revision.

```
§ 1  WHY IT EXISTS
Without an index, answering "find the row where email = X" means reading every
row — O(n), and n grows forever. The obvious fix is to keep the table itself
sorted, but that fails twice: a table can only be physically sorted one way,
and inserting into the middle of a sorted file means rewriting everything
after it. The second obvious fix, an in-memory hash table, gives O(1) point
lookups but cannot answer range or ORDER BY queries at all and must hold the
whole keyspace in RAM. The resolution is to leave the table alone and build a
SEPARATE, ORDERED, DISK-PAGE-SHAPED map from key → row location. Because it is
separate, you can have several of them, sorted different ways. Because it is
ordered, it answers ranges. Because it is page-shaped and shallow, it finds
any row in three or four disk reads no matter how big the table gets.

§ 2  WHAT IT IS
INDEX        A redundant, ordered, auxiliary structure mapping column values
             to row locations, trading write throughput and storage for a
             reduction in the number of rows a query must examine.
SELECTIVITY  The fraction of rows a predicate keeps. An index only pays when
             that fraction is small (roughly under 5–10%); on a low-selectivity
             predicate the planner will correctly ignore your index and scan.
B-TREE       Balanced, sorted, page-oriented tree. Updated IN PLACE. Reads are
             predictable (3–4 page hops); writes are random I/O plus page
             splits. Default in Postgres, InnoDB, Oracle, SQL Server, WiredTiger.
LSM-TREE     Log-structured merge tree. Writes go to an in-memory sorted
             memtable + WAL, flush as immutable SSTables, and are merged by
             background COMPACTION. Writes are sequential and fast; reads may
             touch several levels. Used by RocksDB, LevelDB, Cassandra,
             ScyllaDB, HBase, MyRocks.
COMPOSITE    One index over several columns, sorted by the first, then the
             second within it, and so on. Usable only left-to-right.

§ 3  THE MECHANISM
B-TREE READ   Root page (almost always cached) → binary search inside the
              page → child pointer → repeat. Fanout is in the hundreds, so
              100M rows is ~4 levels; typically 1 physical I/O because the
              upper levels live in the buffer pool.
B-TREE WRITE  Write-ahead log first, then locate the leaf and modify it in
              place. A full leaf SPLITS and the split can propagate upward.
              You rewrite an entire 8–16KB page to change 100 bytes — that is
              write amplification, and it is random I/O.
LSM WRITE     Append to WAL, insert into the in-memory memtable (a sorted
              skip list). When the memtable fills it is frozen and flushed as
              an immutable, sorted SSTable. Purely sequential. Very fast.
LSM READ      Check memtable, then each level newest-first. Each SSTable has a
              BLOOM FILTER that says "definitely not here" cheaply, so most
              levels are skipped without I/O. Bloom filters have false
              positives, never false negatives — and they do NOT help ranges.
COMPACTION    Background merge of overlapping SSTables into fewer, larger,
              non-overlapping ones. It is what keeps read amplification bounded
              and what reclaims space from overwrites and tombstones. It is
              also a background I/O consumer that competes with live traffic.

§ 4  USE / AVOID
INDEX when: the column appears in a WHERE, JOIN, or ORDER BY on a hot path AND
  the predicate is selective; you need a covering index so the query never
  touches the table; you need to enforce uniqueness.
DON'T index when: the table is small enough to scan; the column has few
  distinct values (a boolean, a status with 3 values) so the scan wins anyway;
  the write path is already the bottleneck; nothing queries it.
CHOOSE B-TREE when: mixed read/write OLTP, predictable p99 matters, range
  scans and ORDER BY are common, the working set fits in RAM.
CHOOSE LSM when: write throughput dominates (ingest, time series, event logs,
  counters), the dataset is far larger than RAM, and you can tolerate a
  read path whose tail latency moves with compaction.

§ 5  COMPOSITE INDEX RULES (the part candidates get wrong)
LEFTMOST PREFIX  An index on (a, b, c) serves queries on (a), (a,b), (a,b,c).
                 It does NOT serve a query on (b), (c), or (b,c).
ESR ORDER        Equality columns first, then Sort columns, then Range columns.
                 A range predicate is a STOPPER: once the engine hits a range,
                 no column after it can be used to seek — only to filter rows
                 it already read.
COVERING INDEX   If the index contains every column the query needs, the row
                 itself is never fetched. Postgres calls this an index-only
                 scan; MySQL says "Using index" in EXPLAIN.
ONE COMPOSITE ≠ SEVERAL SINGLES. Three single-column indexes usually cannot be
                 combined as efficiently as one correctly ordered composite.

§ 6  NUMBERS TO ANCHOR THE DISCUSSION
Page size: 8KB Postgres, 16KB InnoDB. Fanout with a small key ≈ 300–500 keys
  per page, so 4 levels covers ~10^9–10^11 rows. Depth is effectively constant.
An index lookup is 3–4 logical page reads and usually 1 physical read — the
  upper levels are cached. Call it sub-millisecond warm.
Selectivity break-even: the planner typically abandons an index somewhere
  around 5–20% of rows returned. Below ~1% the index is a clear win.
Write cost: N secondary indexes turn one INSERT into N+1 structure writes.
  A table with 10 indexes is an 11x write-path multiplier.
LSM write amplification with leveled compaction is roughly 10–30x; the level
  size ratio is typically 10. Bloom filter at ~10 bits/key ≈ 1% false positive.
Index storage is real: a secondary index on a wide table often costs 10–30%
  of the table's size, and they add up.

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "How would you make this query fast?"        → name the composite index and
                                                  its column ORDER, not just
                                                  the columns
→ "What indexes go on this table?"             → derive them from the access
                                                  patterns, ESR order, and say
                                                  what each costs on write
→ "Write throughput degrades as it grows"      → B-tree random I/O + page
                                                  splits + index count → LSM
→ "Ingest 500k events/sec, query by device"    → LSM engine, partition key
                                                  first, time second
GOTCHA: Two failures dominate here. First, listing columns without an ORDER —
  an index on (a,b) and an index on (b,a) are different objects serving
  different queries, and a range predicate stops the seek dead. Second,
  treating indexes as free: they are a write-path tax paid on every insert,
  update, and delete, forever, and "add an index on everything in the WHERE
  clause" is the answer of someone who has never watched p99 write latency
  after a deploy.
```

---

## 2. 🧠 The Mindmap

> *The picture to hold in your head while you study. Everything below hangs off this.*

```
                            ┌──────────────────────────────┐
                            │          INDEXING            │
                            │ "find it without reading all"│
                            └───────────────┬──────────────┘
                                            │
    ┌───────────────┬───────────────┬───────┴───────┬───────────────┬──────────────┐
    ▼               ▼               ▼               ▼               ▼              ▼
 THE PROBLEM     B-TREE          LSM-TREE       COMPOSITE        THE COST      REAL ENGINES
 (why scan       (read-          (write-        (multi-col       (what you
  fails)          optimised)      optimised)     rules)           pay)
 ├ O(n) scan     ├ sorted,       ├ memtable     ├ leftmost      ├ N idx =     ├ Postgres
 │  grows        │  balanced,    │  + WAL       │  prefix       │  N+1 writes │  B-tree heap
 ├ can't sort    │  page-shaped  ├ immutable    ├ ESR order:    ├ page splits ├ InnoDB
 │  a table      ├ fanout 300+   │  SSTables    │  Equality →   │  + frag     │  clustered PK
 │  two ways     │  → 3–4 hops   ├ compaction   │  Sort →       ├ storage     ├ RocksDB /
 ├ hash = no     ├ in-place      │  merges      │  Range        │  10–30%     │  MyRocks LSM
 │  ranges       │  update       ├ bloom filter ├ range is a    ├ write amp   ├ Cassandra
 └ sorted file   ├ random write  │  skips files │  STOPPER      │  B: page    │  SSTables
   = rewrite     │  I/O          └ read amp     ├ covering =    │  L: 10–30x  ├ MongoDB
   on insert     └ predictable     moves with   │  never touch  └ selectivity │  WiredTiger
                   p99             compaction   └  the row        gate        └ DynamoDB GSI
```

**How to read it:** left to right is the argument. **The problem** forces an auxiliary ordered structure; the **B-tree** is the read-optimised answer and the **LSM-tree** is the write-optimised answer to the *same* problem, so they are alternatives, not a hierarchy. **Composite** rules apply to both and are where most interview points are won or lost. **The cost** column is what makes indexing a decision rather than a reflex, and **real engines** are how you check your reasoning against systems that actually shipped.

---

## 3. 🔥 The Problem

Before indexes, finding a row meant looking at every row. A query like `SELECT * FROM users WHERE email = 'ada@x.com'` opens the table file at the beginning and reads forward until it finds a match or hits the end — a **full table scan**, O(n) in the number of rows and, more importantly, O(n) in *disk pages read*. On a 10,000-row table this is invisible; the whole thing is one buffer-pool worth of pages. On a 100-million-row table it is tens of gigabytes of I/O for a query that returns one row, and it gets worse every day the table grows. Worse still, the cost is paid per *concurrent* query, so a scan-driven system doesn't degrade gracefully — it collapses, because every user's scan evicts every other user's cached pages.

The first fix everyone reaches for is to keep the table itself sorted by the column you search on. This fails for two independent reasons, and being able to state both is what separates understanding from recitation. First, **a table has exactly one physical order**. Sort `users` by email and you have made email lookups fast and lookups by `created_at`, `country`, and `id` exactly as slow as before — and real systems query by more than one column. Second, **maintaining sort order on insert is catastrophic**. Inserting a row whose key sorts into the middle of a 40GB file means shifting everything after it; even amortised with gaps and free space, you are rewriting large contiguous regions of the file on a random insert. Sorted storage optimises the read you already had at the cost of the write you do constantly.

The second fix is an in-memory hash table from key to row offset. This is genuinely fast — O(1) point lookups, no tree traversal — and it is a real design (Bitcask uses it). But it fails on three counts that matter for a general-purpose database. It cannot answer **range queries or `ORDER BY`** at all, because a hash destroys ordering by construction; `WHERE created_at > '2026-01-01'` degenerates to a scan again. It requires **the entire keyspace to fit in RAM**, because a hash table with half its buckets on disk is a random-I/O generator. And it gives you nothing for **prefix or partial matching**. Hashing solves point lookups by throwing away the very property — order — that most of the other queries depend on.

The insight that resolved it has two halves. First, **stop trying to reorganise the table and build a separate structure instead**: a small, redundant map from key values to row locations, which you can build several of, each sorted differently, without the table itself having any opinion about order. Second, **shape that structure like the disk**. Disks and SSDs are addressed in blocks — 4KB, 8KB, 16KB — so a binary tree with one key per node is a pathological design that pays a full page read per comparison. Instead, make each node a whole page holding *hundreds* of keys, so a single page read eliminates hundreds of alternatives at once. That is a B-tree, and it is why a lookup in a billion-row table costs three or four page reads instead of thirty.

That resolution held for decades, and then a second problem appeared underneath it. The B-tree's in-place update means every write is a **random** write to a specific page, plus a possible page split, plus rewriting an entire 8–16KB page to change 100 bytes. As write-heavy workloads grew — event ingest, time series, metrics, message logs — that random-write cost, not the read cost, became the ceiling. The LSM-tree answers the same "find it fast" problem while inverting the write path: never modify anything in place, buffer writes in memory, flush them as immutable sorted files, and pay for the resulting mess later, in the background, sequentially. Two structures, one problem, opposite trade-offs — which is exactly why "which index" and "which engine" are the same question asked at different altitudes.

**Before and after:**

```
   BEFORE — full table scan                   AFTER — B-tree index
   ─────────────────────────                  ────────────────────
   users  (100,000,000 rows)                             ┌───────────┐
   ┌──────────────────────────────┐                      │   root    │  ← cached
   │ row 1        read            │                      └─────┬─────┘
   │ row 2        read            │                  ┌─────────┼─────────┐
   │ row 3        read            │                  ▼         ▼         ▼
   │ …            read            │             ┌────────┐ ┌────────┐ ┌────────┐
   │ row 61,204,331  ✓ MATCH      │             │internal│ │internal│ │internal│ ← cached
   │ …            read            │             └────────┘ └───┬────┘ └────────┘
   │ row 100,000,000  read        │                     ┌──────┼──────┐
   └──────────────────────────────┘                     ▼      ▼      ▼
                                                    ┌──────┐┌──────┐┌──────┐
   ✗ O(n) pages read for 1 row                      │ leaf ││ leaf ││ leaf │ ← 1 physical
   ✗ evicts everyone else's cache                   └──────┘└───┬──┘└──────┘   read
   ✗ gets worse every single day                                │
   ✗ concurrency multiplies the damage                          ▼ row pointer
                                                        ✓ 3–4 page reads, ANY table size
                                                        ✓ ordered → ranges + ORDER BY work
                                                        ✗ every write must update it too
```

### ✅ Checkpoint

1. Why can't you get the benefit of an index by simply storing the table itself in sorted order on the search column? Give the two independent reasons — and then explain why an in-memory hash table, which fixes the insert problem, still isn't a general answer.

   > 💡 *Answer out loud before reading on. If you hesitate, re-read the second and third paragraphs — the one-physical-order argument and the ordering-destroyed-by-hashing argument.*

MODEL ANSWER — §3 Checkpoint

WHY NOT JUST SORT THE TABLE? — two independent reasons

1. ONE PHYSICAL ORDER
   A table can be sorted exactly one way. Sort by email and every
   query on created_at, country, or id is back to O(n). Real
   systems query by more than one column — not a corner case.

2. INSERTS REWRITE THE FILE
   A key sorting into the middle means shifting the rows after it.
   Fill factor and free-space gaps AMORTISE this; they do not
   escape it. A random insert still rewrites large contiguous
   regions of the file.

   INDEPENDENT? Yes — #1 is a READ-COVERAGE limit, #2 is a
   WRITE-COST limit. Fixing either leaves the other untouched.
   That independence is the point of the question.

WHY NOT AN IN-MEMORY HASH TABLE? — two counts

1. ORDERING IS DESTROYED BY CONSTRUCTION
   No range queries, no ORDER BY, no prefix or partial matching.
   Hashing solves the point lookup by throwing away the exact
   property most other queries depend on.

2. THE WHOLE KEYSPACE MUST FIT IN RAM
   NOT a full scan when it doesn't — you still know the bucket.
   The failure is that you can't read it EFFICIENTLY: hashing
   scatters keys uniformly BY DESIGN, so there is zero locality
   and every out-of-RAM lookup is an independent random seek.
   Mechanism: a hash table is FLAT — no "top" to keep cached.
   All-or-nothing.
   Contrast: a B-tree is HIERARCHICAL and SHALLOW, so its upper
   levels stay pinned in the buffer pool and you pay ~1 physical
   read at ANY table size. That is the whole design point.

THE ONE-SENTENCE VERSION
  Sorting the table optimises one read at the cost of every write
  and every other query. Hashing optimises the point lookup by
  destroying order and betting the structure fits in RAM.
  The answer is a SEPARATE, ORDERED, SHALLOW, PAGE-SHAPED
  structure — build several, each sorted differently, and none of
  them touch the table.

> **→ Next:** If the answer is a separate ordered structure, what exactly is that structure, and what are the ideas you need in order to reason about it?

---

## 4. 💡 The Core Idea

**An index is a redundant, ordered, auxiliary data structure that maps the values of one or more columns to the locations of the rows containing them — bought with storage and with write throughput on every insert, update, and delete, and worth buying only when it eliminates a large fraction of the rows a hot query would otherwise examine.**

The five ideas below build on each other. Each one only makes sense because of the one before it.

**The build chain:**

```
 [SELECTIVITY] ──▶ [B-TREE] ──▶ [CLUSTERED vs   ──▶ [COMPOSITE +   ──▶ [LSM-TREE]
                                 SECONDARY]          LEFTMOST]
   because an        therefore we      which means      so one index        because that
   index only pays   need an ordered   the index's      can serve many      in-place write
   when it excludes  page-shaped       link to the      predicates — but    is the cost the
   most rows         structure         row matters      only in order       LSM inverts
```

### Selectivity — what an index actually buys

An index does not make a query "fast" in the abstract; it reduces the number of rows the engine must examine, and that reduction is only valuable if it is large. **Selectivity** is the fraction of the table a predicate keeps — `WHERE user_id = 4821` on a table of 50 million orders across 2 million users might keep 0.000005% of rows, while `WHERE is_active = true` might keep 95% of them. For the first, an index turns a 50-million-row scan into a handful of page reads. For the second, the index is actively harmful: following it means a random row fetch for nearly every row in the table, which is *slower* than reading the table sequentially, and a competent query planner will correctly ignore the index you built. The practical break-even is somewhere around 5–20% of rows returned depending on how physically clustered those rows are, and below about 1% an index is an unambiguous win. This is why "index the boolean column" is a red flag in an interview: it is a column with two distinct values and therefore almost no selectivity to offer.

### The B-tree — an ordered map the disk can walk in four hops

Because selectivity is only realisable if the engine can *jump* to the qualifying rows rather than filter its way to them, we need a structure that is both ordered and cheap to descend. The B-tree (in practice the B+tree, where all values live in the leaves and the leaves are linked) achieves this by making every node a **full disk page** holding hundreds of keys with child pointers between them. Searching means reading one page, binary-searching within it in memory, following one pointer, and repeating — so the **fanout**, typically 300–500 for a small key on an 8KB page, is what collapses the tree's depth. Four levels of 400-way fanout addresses 25 billion entries, which is why B-tree depth is effectively constant across every table size you will meet, and why the top one or two levels are permanently resident in the buffer pool. Two properties fall out of the ordering and matter enormously in practice: the leaves are linked in sorted order, so **range scans and `ORDER BY` are nearly free** once you've located the start, and the tree is kept **balanced** on insert, so worst-case and average-case lookups are the same — which is what gives B-tree systems their predictable p99.

### Clustered vs. secondary — where the row actually lives

The B-tree gives you an ordered key; it does not by itself tell you what sits at the leaf, and that detail decides how many I/Os your query really costs. In a **clustered index** the leaf *is* the row: the table is physically stored in primary-key order inside the index, so a PK lookup returns the data with no second fetch. InnoDB works this way, which has a consequence candidates rarely volunteer — an InnoDB **secondary index stores the primary key**, not a physical row pointer, so a secondary lookup is *two* B-tree descents (index → PK, then PK → row), and a fat primary key inflates every secondary index on the table. In a **heap-organised** table like Postgres's, the table is an unordered heap and every index, including the primary key's, stores a pointer (a `ctid`) into it, so every index lookup that needs row data pays one extra random read. The escape hatch in both worlds is a **covering index**: if the index itself contains every column the query needs, the engine never touches the table at all — Postgres calls this an index-only scan, MySQL reports `Using index` — which is often the single largest win available on a hot read path, and it is the reason `INCLUDE` columns exist.

### Composite indexes — one index, several columns, one direction

Once you accept that the leaf-to-row hop is what you want to avoid, the natural move is to put more columns *into* the index — and multi-column indexes come with the rule that generates more interview mistakes than anything else in this subtopic. A composite index on `(a, b, c)` is sorted by `a`, then by `b` within equal `a`, then by `c` within equal `(a, b)`; it is a phone book sorted by last name then first name. That means it serves `WHERE a = ?`, `WHERE a = ? AND b = ?`, and `WHERE a = ? AND b = ? AND c = ?` — the **leftmost prefix** — and it is useless for `WHERE b = ?` alone, exactly as a phone book is useless for finding everyone named "Ada". The second rule is subtler and is the one that separates candidates: a **range predicate is a stopper**. Given `(a, b, c)` and `WHERE a = 1 AND b > 5 AND c = 9`, the engine seeks on `a`, then scans the `b > 5` range, and *cannot* seek on `c` at all — `c` values are only sorted within a fixed `b`, so all it can do is filter rows it has already read. The rule that falls out is **ESR: Equality columns first, then the Sort column, then Range columns**, and stating that ordering rule out loud is worth more in an interview than naming five index types.

**Leftmost prefix and the range stopper — index on `(a, b, c)`:**

```
 Physical key order in the index — sorted by a, then b within a, then c within (a,b)
 ┌─────────────┬─────────────┬─────────────┬─────────────┬─────────────┬─────────────┐
 │ a=1 b=2 c=7 │ a=1 b=2 c=9 │ a=1 b=6 c=3 │ a=1 b=6 c=9 │ a=1 b=8 c=1 │ a=2 b=1 c=4 │
 └─────────────┴─────────────┴─────────────┴─────────────┴─────────────┴─────────────┘
 c is only sorted INSIDE a fixed (a, b). That single fact is the whole rule.

 ✓ SERVED — leftmost prefix              ✗ NOT SERVED — or only partly
 ──────────────────────────              ──────────────────────────────
 WHERE a = ?                             WHERE b = ?          ← no leading a: full scan
 WHERE a = ? AND b = ?                   WHERE c = ?          ← same
 WHERE a = ? AND b = ? AND c = ?         WHERE a = ? AND b > ? AND c = ?
 WHERE a = ? AND b = ? ORDER BY c            RANGE STOPPER: seeks on a, scans the b
                                             range, can only FILTER on c — the index
 seek to the range, then walk the            "is used" and the query is still slow.
 linked leaves                               Fix: reorder to (a, c, b) — E → S → R.
```

### The LSM-tree — the same problem, the write path inverted

Everything above optimises the read; the bill lands on the write, and the LSM-tree is what you build when that bill is the one you cannot pay. A B-tree write is an **in-place** modification: locate the leaf, rewrite the whole 8–16KB page to change 100 bytes, split it if it's full, propagate the split upward, and do all of that as *random* I/O at whatever offset the key happens to live. The LSM-tree refuses to modify anything in place. A write is appended to a WAL and inserted into an in-memory sorted structure (the **memtable**, usually a skip list); when the memtable fills, it is frozen and written out as an immutable, sorted **SSTable** in one sequential pass; and a background **compaction** process periodically merges overlapping SSTables into fewer, larger, non-overlapping ones, discarding superseded values and tombstones as it goes. Writes become sequential and extremely fast; the cost moves to reads, which may have to consult the memtable plus several levels of SSTables — mitigated by a per-SSTable **Bloom filter** that answers "definitely not in this file" for a few bits per key — and to background I/O, since compaction is real work competing with your live traffic. Notice the shape of this: it is 8.3's argument again in a different costume. You did not remove the work; you moved it from the write path to a background process, and the honest version of the trade-off names where it went.

### ✅ Checkpoint

1. A query is `WHERE tenant_id = ? AND created_at > ? ORDER BY created_at DESC LIMIT 50`, and a colleague proposes three separate single-column indexes on `tenant_id`, `created_at`, and `status`. Explain precisely why that is worse than one index, state the index you would build with its column order, and explain what the engine can do with each column in it.

   > 💡 *If you hesitate, re-read §4 — the composite indexes block, specifically the leftmost-prefix and range-stopper paragraphs.*

MODEL ANSWER — §4 Checkpoint 1

THE INDEX
  (tenant_id, created_at)      equality first, then sort/range

WHAT THE ENGINE DOES WITH EACH COLUMN
  tenant_id    SEEK. Equality on the leading column — jump
               straight to that tenant's slice of the leaves.
  created_at   SCAN + SORT-SATISFY. Sorted within the tenant, so
               (a) the range is a bounded walk, and
               (b) the ORDER BY is already satisfied: seek to the
                   tenant's upper bound, walk BACKWARDS 50
                   entries. Leaves are doubly-linked.

WHY THREE SINGLE-COLUMN INDEXES LOSE — three separate reasons
  1. ONLY ONE GETS USED. The engine picks tenant_id, narrows to
     that tenant, then FILTERS created_at on every row returned.
     Index-merge / bitmap intersection exists but costs more
     than one correctly ordered composite.
  2. THE SORT SURVIVES. Nothing is ordered by created_at within
     a tenant, so every matching row must be materialised and
     top-N sorted before LIMIT applies. A million rows sorted to
     return 50, versus reading 50 index entries.
  3. 3x WRITE COST. Three structures on every insert, update and
     delete. The composite is one.

THE status INDEX — DROP IT
  The query never references status. An index with no reader is
  pure write-path tax for zero benefit — the easiest point on
  the board, and routinely missed.
  Secondary: status is typically 3–5 distinct values, so even a
  query that DID filter on it is too unselective for the planner
  to bother.

"SHOULD status GO INTO THE COMPOSITE?" — also no, both ways:
  (tenant_id, created_at, status)  the created_at RANGE stops
      the seek — status can only filter, never seek.
  (tenant_id, status, created_at)  now every query MUST supply
      status to reach anything past tenant_id.
  POSITION, not count, is what decides.

2. Explain why the **selectivity** block is what makes the **clustered vs. secondary** block matter, rather than the two being unrelated facts. Why does a heap-organised secondary index lookup make a marginally-selective predicate *worse*, not just no better?

   > 💡 *If you hesitate, re-read the build chain above and trace the "because → therefore → which means" links between blocks one, two, and three.*

MODEL ANSWER — §4 Checkpoint 2

THE COMPARISON THAT MATTERS
  Not secondary vs. clustered. It is INDEX+HOPS vs. FULL SCAN.
  An index is only worth using if it beats ignoring it.

WHY A MARGINAL PREDICATE GETS ACTIVELY WORSE
  Index path  2M index entries, each followed by a hop to a row
              scattered across the file → RANDOM reads.
  Scan path   10M rows read front to back → SEQUENTIAL reads,
              with OS and DB readahead prefetching large chunks.
  Random costs ~20x more per access (2–3 orders of magnitude on
  HDD; 5–20x on SSD, where random also defeats prefetch and
  thrashes the buffer pool).

      index  =  0.20 × 20  =  4.0
      scan   =  1.00 ×  1  =  1.0

  The scan wins by 4x while reading 5x more data. The index is
  HARMFUL, not merely useless. The planner refusing it is the
  planner doing this multiplication correctly.

WHERE THE RULE OF THUMB COMES FROM
      break-even ≈ 1 ÷ random-penalty
  A 20x penalty puts the crossover near 5%. That is the origin
  of "an index pays below ~5–10% selectivity" — arithmetic, not
  folklore.

THE LINK — WHY THESE ARE ONE IDEA, NOT TWO
  The random penalty is NOT a constant. It depends on
  CORRELATION: how closely physical row order matches the
  index's logical order.
    CLUSTERED   correlation = 1.0 BY CONSTRUCTION — the leaf IS
                the row. Fetches are sequential no matter how
                many rows qualify, so selectivity nearly stops
                mattering and low-selectivity ranges stay cheap.
    HEAP +      uncorrelated. Every qualifying row is an
    SECONDARY   independent seek, so cost scales linearly with
                rows returned and selectivity dominates.

  So: clustering sets the random penalty → the penalty sets the
  break-even → the break-even is what selectivity is measured
  against. Selectivity has no meaning without knowing which
  architecture you are in.

  AND (§3 again): one physical order per table means AT MOST ONE
  index can be correlated. Every other index pays the penalty
  forever.

> **→ Next:** You know the structures and the rules. What physically happens inside each one when you read and when you write — and how does each one fail?

---

## 5. ⚙️ How It Actually Works

**The B-tree read path (happy path):**

1. The planner decides an index is worth using, based on the estimated selectivity of the predicate against the column's statistics (histogram, distinct-value count, physical correlation).
2. It reads the **root page** — essentially always already in the buffer pool — and binary-searches within that page's few hundred keys to pick a child pointer.
3. It descends one internal level at a time. Each hop is one page read, and the upper levels are hot, so they are memory hits.
4. It arrives at a **leaf page**, which is typically the only physical I/O in the whole descent.
5. If the index is covering, it returns from the leaf and stops. Otherwise it follows the leaf entry to the row — a second random read in Postgres's heap, or a second B-tree descent on the primary key in InnoDB.
6. For a range or `ORDER BY`, it walks the **linked leaf pages** sequentially from the start point, which is why an index that matches the sort order removes the sort step entirely.

> 🗺️ **Mental model — the tabbed phone book.** A B-tree is a phone book with tabbed dividers: the tabs let you skip to "Ma–Mc" without reading anything before it, and once there the names are in order so a range ("everyone from Ma to Mo") is just reading forward. *Where it breaks down:* a phone book is printed once and never changes, and it is exactly the change that costs. The real B-tree difficulty is inserting a new name into a page that is already full — the split, the propagation upward, and the fragmentation left behind — none of which the phone book image contains.

**The B-tree write path:**

1. The change is written to the **write-ahead log** first, so it survives a crash before it is applied anywhere.
2. The engine descends to the target leaf and modifies it **in place** in the buffer pool; the dirty page is flushed later by a checkpoint.
3. If the leaf is full, it **splits** into two half-full pages and a new separator key is inserted into the parent — which may itself split, cascading upward, in the worst case growing the tree by a level.
4. Every **secondary index** that contains the affected column must be updated too. One `INSERT` into a table with ten indexes is eleven structure modifications.
5. The cost profile: **random** I/O at an arbitrary offset, plus **write amplification** — an entire 8–16KB page rewritten to change a small row, plus the WAL record, plus (in InnoDB) the doublewrite buffer. Page splits also leave pages half-full, so the index physically bloats over time and needs periodic rebuilding.

**The LSM write and read paths:**

1. **Write:** append to the WAL, then insert into the in-memory **memtable** (a sorted skip list). That is the entire foreground cost — one sequential append and one in-memory insert. This is why LSM engines sustain write rates B-trees cannot.
2. **Flush:** when the memtable exceeds its size threshold it is frozen, a new one takes over, and the frozen one is written out as an immutable sorted **SSTable** in a single sequential pass. Nothing is ever updated in place; an overwrite is just a newer entry, and a delete is a **tombstone**.
3. **Compaction:** a background process merges SSTables — in leveled compaction, level *L* is roughly ten times the size of level *L−1* and its files are non-overlapping — discarding superseded values and tombstones and keeping the number of files a read must consult bounded.
4. **Read:** check the memtable first, then each level newest-first, taking the first value found. Before touching a file, consult its **Bloom filter**, which at ~10 bits per key answers "definitely not here" with about a 1% false-positive rate and never a false negative — so most files are skipped without any I/O at all.
5. **Range read:** here the Bloom filter is useless, because it can only answer questions about specific keys. A range scan must open an iterator on every level that could overlap the range and merge them, which is why range-heavy workloads are the weak point of LSM engines.

> 🗺️ **Mental model — the stack of dated ledgers.** An LSM-tree is a pile of ledgers, newest on top. Writing is easy: scribble in today's ledger. Reading means checking today's ledger, then yesterday's, and so on until you find the entry — the newest wins. Periodically a clerk rewrites the whole pile into one clean book, dropping every entry that was later corrected or crossed out. *Where it breaks down:* it implies the clerk works in idle time. Compaction runs on the same disks and CPUs as your live traffic, and a compaction backlog is a real, observable production incident — the analogy hides the fact that the cleanup competes with the thing it's cleaning up for.

**Read and write paths compared:**

```
 ① B-TREE READ — descend, few hops, mostly cached
 ┌──────────────┐  ┌───────────────┐  ┌────────────────┐  ┌───────────┐  ┌─────────┐
 │ planner picks│─▶│ root page     │─▶│ internal pages │─▶│ leaf page │─▶│ row     │
 │ index (stats)│  │ (cached)      │  │ (cached)       │  │ 1 phys I/O│  │ fetch   │
 └──────────────┘  └───────────────┘  └────────────────┘  └───────────┘  └─────────┘
 ✓ covering index → stop at the leaf, never fetch the row
 ✓ leaves are linked → range scan and ORDER BY are a sequential walk

 ② B-TREE WRITE — in place, random, amplified
 ┌──────┐  ┌───────────────┐  ┌────────────────┐  ┌──────────────────────────┐
 │ WAL  │─▶│ descend to    │─▶│ modify page    │─▶│ page FULL → SPLIT →      │
 │ first│  │ target leaf   │  │ IN PLACE       │  │ propagate to parent      │
 └──────┘  └───────────────┘  └────────────────┘  └──────────────────────────┘
                    │
                    ▼  … and repeat for EVERY secondary index
           ⚠ 1 INSERT + 10 indexes = 11 structure writes · random I/O
           ⚠ rewrite 8–16KB page to change 100 bytes · splits leave bloat

 ③ LSM WRITE — sequential, then cleaned up later
 ┌──────┐  ┌────────────────┐   flush   ┌──────────────┐   compaction  ┌──────────────┐
 │ WAL  │─▶│ MEMTABLE       │──────────▶│ SSTable  L0  │──────────────▶│ L1 … Ln      │
 │append│  │ sorted skiplist│ immutable │ (immutable)  │  merge, drop  │ ×10 per level│
 └──────┘  └────────────────┘           └──────────────┘  tombstones   └──────────────┘
           ✓ foreground cost = 1 append + 1 in-memory insert
           ⚠ compaction is background I/O COMPETING with live traffic

 ④ LSM READ — newest first, Bloom filters skip the rest
 ┌──────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
 │ memtable │─▶│ L0  [bloom]  │─▶│ L1  [bloom]  │─▶│ Ln  [bloom]  │  first hit wins
 └──────────┘  └──────────────┘  └──────────────┘  └──────────────┘
   ✓ bloom = "definitely not here" for ~10 bits/key, ~1% false positive
   ✗ bloom does NOTHING for RANGE scans — must merge iterators across levels
```

**Failure and edge cases:**

- **The index exists and is not used.** Wrapping the column in a function (`WHERE lower(email) = ?`), a leading-wildcard `LIKE '%foo'`, an implicit type cast, or an `OR` across unindexed columns all defeat the seek. The fix is usually an expression index or a rewritten predicate — but first you have to notice, which means reading `EXPLAIN` rather than assuming (8.5).
- **Stale or skewed statistics.** The planner chooses based on estimated selectivity. After a bulk load, or on a column with a skewed distribution, the estimate can be wrong by orders of magnitude and the planner picks a scan over a perfectly good index — or the reverse.
- **The leftmost-prefix miss.** An index on `(a, b, c)` cannot serve `WHERE b = ?`. Teams commonly have three composites that all start with the same column and none that serves the query they actually run.
- **The range stopper.** Columns after the first range predicate cannot be used for seeking, only for filtering rows already read. This shows up as an index that "is being used" while still reading a million rows.
- **Write amplification from index count.** Every added index taxes every insert, update, and delete on that table, forever. This is the most common cause of "writes got slower and nobody knows why" after a performance-tuning sprint.
- **Right-edge contention on monotonic keys.** An auto-increment or timestamp primary key means every insert targets the same rightmost leaf page, making it a lock and latch hot spot — the same shape as the hot-partition problem in 7.6, one level down. UUIDv7/ULID or hashed prefixes trade some locality for spread.
- **Compaction backlog (LSM).** If ingest outruns compaction, the number of levels a read must consult grows, read latency degrades, and eventually the engine applies **write stalls** to let compaction catch up. Tail latency on an LSM engine is a function of background work, not just query shape.
- **Delete-heavy LSM workloads.** Deletes write tombstones rather than removing data, so a queue-like table can accumulate millions of tombstones that every range scan must read through — the classic Cassandra tombstone incident.
- **Index bloat and rebuild.** Page splits and dead tuples leave B-tree indexes physically larger than their content; Postgres needs `REINDEX`/`pg_repack` occasionally, and building an index on a large live table needs the concurrent/online path or it takes a blocking lock.

**The two structures, side by side:**

```
  B-TREE  (in-place, read-optimised)              LSM-TREE  (out-of-place, write-optimised)
  ────────────────────────────────                ──────────────────────────────────────────
                ┌─────────┐                        WRITE ─┐
                │  root   │  ← cached                     ▼
                └────┬────┘                        ┌───────────────┐   in RAM, sorted
         ┌───────────┼───────────┐                 │   MEMTABLE    │   skip list
         ▼           ▼           ▼                 └───────┬───────┘
    ┌────────┐  ┌────────┐  ┌────────┐                     │ flush (sequential)
    │internal│  │internal│  │internal│ ← cached            ▼
    └───┬────┘  └───┬────┘  └───┬────┘             ┌───────────────────────────┐
        │           │           │                  │ L0  [sst][sst][sst]       │ overlapping
   ┌────┴───┐  ┌────┴───┐  ┌────┴───┐              ├───────────────────────────┤
   ▼        ▼  ▼        ▼  ▼        ▼              │ L1  [ sst ][ sst ]        │ ×10 size
 ┌────┐  ┌────┐┌────┐ ┌────┐┌────┐ ┌────┐          ├───────────────────────────┤ non-overlap
 │leaf│──│leaf│┤leaf│─│leaf││leaf│─│leaf│          │ L2  [   sst   ][   sst  ] │ ×10 size
 └────┘  └────┘└────┘ └────┘└────┘ └────┘          └───────────────────────────┘
   └───── linked, sorted ──────┘                        ▲ compaction merges upward
                                                        │ drops overwrites + tombstones
  fanout 300–500 → depth 3–4 at any size          each SSTable carries a BLOOM FILTER
  RANGE: walk the linked leaves ✓ cheap           RANGE: merge iterators across levels ✗
  WRITE: random, in place, split, amplify ✗       WRITE: append + memtable insert ✓ fast
  p99: predictable                                p99: moves with compaction pressure
```

### ✅ Checkpoint

1. Trace what physically happens when a single row is inserted into a table that has a clustered primary key and four secondary indexes, and the target leaf page of one of those indexes is already full. Name every structure touched and identify the two distinct sources of write amplification.

   > 💡 *If you hesitate, re-read the B-tree write path above, steps 1–5.*

MODEL ANSWER — §5 Checkpoint 1

STRUCTURES TOUCHED
  1  redo log (WAL)          — sequential, small
  1  clustered index leaf    — the row itself lands here
  3  secondary index leaves  — one (col_value → PK) entry each
  2  split secondary index   — original page + new half
  1  parent of split page    — separator key inserted
  ── 7 data pages × 16KB = 112 KB
  ×2 doublewrite buffer      = 224 KB
  + redo record              ~ a few hundred bytes

  224 KB written for a 200-byte row  →  >1000 : 1

THE TWO SOURCES — they MULTIPLY, they do not add
  1. PAGE GRANULARITY (per structure)
     The minimum unit of I/O is a page. 200 bytes costs 16KB;
     a ~30-byte secondary entry also costs 16KB. ~80–550x on
     its own, and it applies to EVERY structure — including
     the parent page. No exceptions, ever.
  2. STRUCTURE COUNT (how many structures)
     One logical insert becomes N+1 structure writes. Five
     indexes here, seven pages once the split lands.

     ~80x  ×  ~7  ×  2 (doublewrite)  ≈  1000x+

WHERE THE PAGE LIVES BEFORE DISK
  Dirty in the BUFFER POOL, in memory. It is NOT written at
  commit. A background CHECKPOINT flushes it later.
  Durability at commit comes from the redo log, not the data
  page — which is the entire reason a WAL exists: turn an
  expensive random page write into a cheap sequential append,
  and defer the page.

2. An LSM-backed service ingesting sensor readings has healthy p50 read latency but p99 that spikes to seconds several times an hour, and disk utilisation is pinned. Explain the mechanism causing this, why a Bloom filter does not prevent it, and what specifically would look different if the same workload's reads were range scans rather than point lookups.

   > 💡 *If you hesitate, re-read the compaction step and the compaction-backlog failure case — and the sentence about what Bloom filters cannot do.*

MODEL ANSWER — §5 Checkpoint 2

(a) MECHANISM
  Compaction is bursty, I/O-intensive background work reading
  and rewriting GBs of SSTables. During a burst it saturates
  disk bandwidth and foreground reads queue behind it.
  PERIODIC, not gradual — "several times an hour" is the tell.
  p50 SURVIVES because most reads never touch disk (memtable,
  block cache, page cache). Only reads needing physical I/O
  during a burst pay, so the damage is confined to the tail.
  ESCALATION: if ingest outruns compaction persistently, the
  engine applies WRITE STALLS — deliberately throttling clients
  so compaction can catch up.

(b) WHY BLOOM FILTERS DON'T HELP
  They solve READ AMPLIFICATION — which files to skip. The
  problem here is I/O CONTENTION — the disk is busy. A read
  that legitimately needs a file still waits behind compaction.
  Fewer lookups ≠ a less busy disk. Wrong problem.
  MISCONCEPTION TO AVOID: compaction does NOT make SSTables
  unavailable. Inputs stay readable; new outputs are written
  alongside; the engine atomically swaps versions and deletes
  inputs once unreferenced. Readers are never blocked.

(c) IF READS WERE RANGE SCANS
  Bloom filters answer questions about ONE key, so they are
  useless for ranges. Every level that could overlap must be
  opened and its iterator merged.
  The difference in kind: this degrades p50, not just p99. A
  tail problem becomes a median problem.

WHAT YOU'D ACTUALLY DO
  Rate-limit compaction I/O (RocksDB rate limiter); schedule
  major compactions off-peak; reconsider compaction strategy —
  tiered/universal merges less often and less aggressively than
  levelled, trading space and read amp for calmer foreground
  latency; and separate the WAL onto its own device.

> **→ Next:** You know both mechanisms and how each fails. So in a live design, which indexes do you actually create, and which engine family do you pick?

---

## 6. ⚖️ The Decision — When, and What It Costs

The default is **index the access path, not the table**. You do not start from the schema and ask which columns look important; you start from the two or three queries that run on the hot path, write down their `WHERE`, `JOIN`, and `ORDER BY` clauses, and build the smallest set of composite indexes that serves them — then stop. Every index beyond that set is a permanent write-path tax with no reader. The corollary matters just as much: an index that no query uses is strictly worse than no index at all, and most mature systems carry several.

Four signals decide the specifics. **Selectivity** is the gate: if the predicate keeps more than roughly 10–20% of the table, no index will help and the planner will ignore the one you built, so a boolean or a three-value status column is almost never worth indexing alone (though it can be a fine *later* column in a composite). **Column order** is decided by ESR — equality columns first, then the column you sort by, then range columns — because a range predicate stops the engine from seeking on anything after it. **Coverage** is the cheap win people forget: if adding one more column to an index lets the query be answered from the index alone, you have removed a random row fetch per result row, which on a hot path often beats every other optimisation available. And **read:write shape** decides the engine family: a mixed OLTP workload with predictable latency requirements wants a B-tree, while sustained high-volume ingest against a dataset far larger than RAM wants an LSM — and that choice is usually made once, at store selection (8.1), which is why it is worth raising early rather than after you've drawn the schema.

**Decision tree:**

```
                    Does a hot query filter, join, or sort on this column?
                                        │
                       ┌────no──────────┴───────yes───────┐
                       ▼                                  ▼
              DON'T INDEX IT.                 Is the predicate selective?
              An unused index is              (keeps roughly < 10% of rows)
              pure write-path tax                        │
                                              ┌──no──────┴──────yes──┐
                                              ▼                      ▼
                                     DON'T INDEX ALONE.    Do several hot queries share
                                     The scan wins. It may   a leading column?
                                     still earn a place            │
                                     as a LATER column      ┌──no──┴───yes──┐
                                     in a composite.        ▼               ▼
                                                    SINGLE-COLUMN     ONE COMPOSITE in
                                                    or narrow          ESR order:
                                                    composite          Equality → Sort
                                                          │            → Range
                                                          └───────┬───────┘
                                                                  ▼
                                                    Can you add the remaining
                                                    selected columns to make it
                                                    COVERING?
                                                          │
                                                     ┌─no─┴─yes─┐
                                                     ▼          ▼
                                              Accept the    ADD THEM (INCLUDE).
                                              row fetch.    You just deleted a
                                                            random read per row.

                    ─────────────── and, at store-selection time ───────────────

                    Is sustained write throughput the binding constraint,
                    with a dataset far larger than RAM?
                                        │
                      ┌────no───────────┴──────────yes────┐
                      ▼                                   ▼
              B-TREE ENGINE.                       LSM ENGINE.
              Predictable p99, cheap               Sequential writes, high
              ranges, in-place updates.            ingest — accept read
              Postgres, InnoDB, WiredTiger.        amplification and
                                                   compaction-driven p99.
                                                   RocksDB, Cassandra, MyRocks.
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **B-tree: predictable, bounded lookup cost** — 3–4 page hops at any table size, mostly served from the buffer pool, with balanced worst and average cases | Writes are random, in-place, and amplified: an entire 8–16KB page is rewritten to change a small row, page splits cascade upward, and the index physically bloats until it is rebuilt |
| **B-tree: ordering is free** — linked sorted leaves make range scans and `ORDER BY` a sequential walk, and an index matching the sort order removes the sort step entirely | That ordering must be maintained on every write, so high-throughput ingest hits a random-write ceiling that no amount of hardware entirely removes |
| **LSM: sequential writes and very high ingest rates** — foreground cost is one WAL append plus one in-memory insert, and the dataset can far exceed RAM | Reads may consult several levels, and p99 is coupled to background compaction: a compaction backlog degrades read latency and eventually triggers write stalls, which is a class of incident B-trees don't have |
| **LSM: overwrites and deletes are cheap** — no in-place mutation, so an update is just a newer entry | Space amplification until compaction runs, and delete-heavy workloads accumulate tombstones that every range scan must read through; range scans get no help from Bloom filters at all |
| **Covering index: the row is never fetched** — removes one random read per result row, often the single largest available win on a hot read path | The index grows wider, so it costs more storage and more write bandwidth, and it silently stops covering the moment someone adds a column to the `SELECT` list |
| **Composite index: one structure serves several predicates** — fewer indexes to maintain than one per column | Usable only left-to-right, so it serves a specific query shape; a range predicate stops the seek, and column order is a design decision that is expensive to change on a large live table |

### In production

| System | How it applies | The nuance |
|--------|----------------|------------|
| **PostgreSQL** | Heap-organised: the table is unordered and *every* index, including the primary key's, stores a `ctid` pointer into the heap, so a non-covering lookup pays one extra random read | An index-only scan still consults the **visibility map** to confirm the tuple is visible to your snapshot; if the page isn't marked all-visible the heap fetch happens anyway, which is why an index-only scan can quietly stop being index-only after a heavy write burst until `VACUUM` runs |
| **MySQL / InnoDB** | Clustered by primary key — the leaf of the PK index *is* the row — so PK lookups are one descent, but every **secondary index stores the primary key** rather than a row pointer | This makes a secondary lookup two descents, and it makes primary-key width a table-wide cost: a 36-byte UUID PK inflates every secondary index on the table. It is also why a random UUID PK hurts twice — wide keys *and* random insert positions destroying the right-edge locality a monotonic key would have given |
| **RocksDB / LevelDB / MyRocks** | The reference LSM implementations; MyRocks is MySQL with RocksDB underneath, deployed at Facebook specifically to cut write amplification and storage versus InnoDB | Compaction style is a real tuning decision: **leveled** compaction minimises space and read amplification at the cost of write amplification, **universal/tiered** does the reverse. "We use an LSM" is not a complete answer; which compaction and why is the follow-up |
| **Apache Cassandra / ScyllaDB** | LSM by design: memtable → SSTable → compaction, with per-SSTable Bloom filters, and a data model where the partition key and clustering columns *are* the index — you model tables per query | Deletes are tombstones with a `gc_grace_seconds` window before they can be removed, so queue-shaped workloads accumulate tombstones and range reads slow down or trip the tombstone-threshold failure. This is the canonical Cassandra production incident |
| **MongoDB / WiredTiger** | B-tree by default, with an LSM option, and composite indexes that follow exactly the same leftmost-prefix and range-stopper rules as SQL engines | The ESR guidance (Equality, Sort, Range) is written down explicitly in MongoDB's own docs — useful in an interview because it shows the rule is engine-independent, not SQL folklore |
| **DynamoDB** | No query planner and no ad-hoc indexes: you get the partition/sort key plus **GSIs** and **LSIs**, and a query that no key or index serves is a scan you should never run | A GSI is a fully separate, asynchronously-maintained, eventually-consistent copy of the table with its own provisioned throughput — so adding one is a storage and write-cost decision made *before* launch, and adding an unforeseen access pattern later means a new GSI plus a backfill (8.3) |

### ✅ Checkpoint

1. An events table receives 30,000 inserts/sec and serves one hot query: `WHERE tenant_id = ? AND event_type = ? AND ts BETWEEN ? AND ? ORDER BY ts DESC LIMIT 100`, returning about 100 of 8 billion rows. The team wants to add indexes on `tenant_id`, `event_type`, `ts`, and `user_id` "to be safe." State the index you would actually build and its exact column order, justify the order using the range-stopper rule, say which proposed index you would drop and why, and name the engine family you would push for at this write rate.

   > 💡 *If you hesitate, re-read the four signals at the top of §6 and the ESR paragraph in §4.*

> **→ Next:** You can defend the choice. How does an interviewer actually put pressure on it?

---

## 7. 🎯 In the Interview

**When an interviewer asks / says:**

- "This query takes eight seconds. How would you make it fast?"
- "What indexes would you put on this table?"
- "We're ingesting half a million events a second. Which database, and why?"
- "Write latency has been climbing for months and the table has doubled. What's happening?"
- "What's the difference between a B-tree and an LSM-tree, and which engines use each?"

**What you say / do:**

Indexing lands in the **data model** phase, right after the schema (8.3), and it returns in the **deep dive** the moment the interviewer picks one endpoint and asks why it's slow. Do it in a fixed order so it sounds like engineering rather than recall: name the hot query, name its predicate columns and sort, state the composite index **with its column order and the reason for that order**, say whether you can make it covering, and then — unprompted — price it: "that's one more structure written on every insert into a table taking 30k writes/sec." The unprompted cost statement is the signal. Then, if write throughput is the binding constraint, escalate from index design to engine choice and say why an LSM inverts the trade rather than removing it.

**The trade-off statement (memorize this pattern):**

> "The hot query filters on `tenant_id` and `status` by equality, sorts by `created_at`, and ranges over it — so I'd build one composite index on `(tenant_id, status, created_at)`: equality columns first so the engine can seek, then `created_at`, which both satisfies the sort and bounds the range. I would *not* build separate indexes on each column, because three single-column indexes can't be combined as efficiently as one correctly ordered composite and each one taxes every write. If the query only selects `id` and `created_at` I'd make it covering so we never touch the heap — that removes one random read per result row. The price is that every insert now maintains this index too, and with the table at 30k writes/sec that's real: B-tree writes are random, in place, and rewrite a full 8KB page to change 100 bytes. If write throughput became the binding constraint rather than read latency, I'd move this table to an LSM engine — RocksDB or Cassandra — where writes are a WAL append plus a memtable insert. But I'd say clearly that this doesn't make the cost vanish: it moves it to background compaction, so my p99 reads now move with compaction pressure, and range scans lose the Bloom-filter shortcut entirely."

### ⚠️ Traps

- ❌ **Trap:** "Add an index on every column in the `WHERE` clause."
  ✅ **Reality:** Separate single-column indexes are not the same as one composite and usually cannot be combined as efficiently — most engines will pick exactly one, or do a comparatively expensive bitmap/index-merge. The correct answer is *one* composite in ESR order, and it must include the column order and the reasoning behind it. An index list without an order is not an answer to the question that was asked.

- ❌ **Trap:** "Indexes make the database faster."
  ✅ **Reality:** They make *some reads* faster and *all writes* to that table slower, permanently. One `INSERT` on a table with ten indexes is eleven structure modifications, each with its own random I/O and possible page split. And on a low-selectivity predicate an index is not merely useless — following it means a random row fetch for most of the table, which is slower than a sequential scan, which is why the planner refuses to use it. "Faster" without naming which operation is the giveaway.

- ❌ **Trap:** "B-trees are for SQL and LSM-trees are for NoSQL."
  ✅ **Reality:** This is a storage-engine property, not a data-model property, and the counterexamples are load-bearing. MyRocks is MySQL — full SQL, ACID transactions — running on RocksDB's LSM. MongoDB is a document store running WiredTiger's B-tree. TiDB and CockroachDB are distributed SQL databases on LSM storage. What actually correlates is *workload shape*: sustained write-heavy ingest against a dataset larger than RAM pushes you to LSM regardless of query language.

- ❌ **Trap:** "LSM-trees are just faster than B-trees."
  ✅ **Reality:** Faster on the *write* path, and the cost is paid in three places you must name: read amplification (a point read may consult several levels, mitigated but not eliminated by Bloom filters), background compaction competing with live traffic for I/O — which couples your read p99 to background work and can escalate to write stalls — and range scans, which get no help from Bloom filters at all and must merge iterators across levels. B-trees trade lower write throughput for a much more predictable tail.

- ❌ **Trap:** "The order of columns in a composite index doesn't really matter — the engine will figure it out."
  ✅ **Reality:** `(a, b)` and `(b, a)` are different objects serving different queries. Only the **leftmost prefix** is usable, so `(a, b, c)` does nothing for `WHERE b = ?`. And a **range predicate is a stopper**: in `(a, b, c)` with `a = ? AND b > ? AND c = ?`, the engine seeks on `a`, scans the `b` range, and can only *filter* on `c` — so the index "is being used" while still reading far more rows than you think. Reordering to put equality columns before range columns is frequently a 100x change with no schema change at all.

### ✅ Checkpoint — adversarial stress test

1. You have `orders(id, user_id, status, created_at, amount, …)` and the hot query is `WHERE user_id = ? AND status = 'PENDING' AND created_at > ? ORDER BY created_at DESC LIMIT 20`. A teammate added an index on `(user_id, created_at, status)`. The query is still reading hundreds of thousands of rows, and since the deploy, p99 **write** latency on the table has roughly doubled. The interviewer says: *"Explain exactly which columns of that index the engine can seek on and which it can only filter on, give me the index you'd build instead and why, explain the write-latency regression at the level of what physically happens on disk, and then tell me at what point you'd stop tuning indexes and change storage engines — and what you'd be giving up if you did."*

   > 💡 *This is the gate. A complete answer covers: `user_id` seeks, `created_at >` is a range that stops the seek so `status` can only filter rows already read; the correct index is `(user_id, status, created_at)` with equality first, which also satisfies the `ORDER BY` and makes the range a bounded leaf walk; the write regression is one more B-tree maintained per insert, in-place random writes, full-page rewrites and page splits; and the engine switch is justified only when sustained write throughput — not read latency — is the binding constraint, at the price of read amplification, compaction-coupled p99, and worse range scans. If you can't answer this cleanly, you are not done.*

> **→ Next:** Can you combine what you've learned across sections, not just recall each one?

MODEL ANSWER — §7 Adversarial Stress Test

1. SEEK vs FILTER on (user_id, created_at, status)
   user_id      SEEK — equality on the leading column
   created_at   RANGE — bounded walk, and it STOPS the seek
   status       FILTER ONLY, despite having an equality
                predicate. status is sorted only within a fixed
                created_at, so there is nothing to seek into.
                The index "is used" and still reads hundreds of
                thousands of rows.

2. THE CORRECT INDEX
   (user_id, status, created_at)
   Both equality columns first, so both seek. created_at then
   does three jobs at once: bounds the range, satisfies
   ORDER BY created_at DESC (walk linked leaves backwards), and
   bounds LIMIT 20 to ~20 entries examined.   ESR.

3. THE WRITE REGRESSION, PHYSICALLY
   One more B-tree maintained on every insert/update/delete.
   DOUBLING implies ~1 structure before (the clustered PK):
   1 → 2 structures.
   Per write, per structure:
     - descend to the leaf; the key picks the page and keys
       arrive in arbitrary order → RANDOM I/O
     - rewrite a full 8–16KB page to change ~100 bytes
     - if full: SPLIT into two pages, plus a full rewrite of
       the parent, possibly cascading
     - InnoDB writes every data page TWICE (doublewrite)
     - redo record appended; the dirty page sits in the buffer
       pool until a checkpoint flushes it
   RANDOM explains the latency. The rest explains the volume.

4. WHEN TO CHANGE ENGINES — a workload condition
   a. Exhaust index tuning first: drop unused indexes, merge
      redundant ones, fix column order.
   b. Only if AFTER that write latency degrades CONTINUOUSLY as
      the table grows, disk pinned on random I/O, nothing left
      to shed — then throughput is the binding constraint and
      the problem is architectural.
   A one-time step change after a deliberate index addition is
   a PURCHASE, not a ceiling.

   WHAT YOU GIVE UP
     - read amplification across levels
     - p99 coupled to compaction contention; write stalls if
       ingest outruns compaction
     - THE KILLER HERE: this hot query IS a range query. Bloom
       filters answer single-key questions only, so every
       overlapping level must be opened and merged. You would
       degrade the exact query you set out to fix.

   SO THE HONEST RECOMMENDATION FOR THIS TABLE:
   fix the index order, keep the B-tree.

---

## 8. 🧪 Mastery Gate

> *Synthesis only. Each question requires combining two or more sections.*

1. **(§4 + §6 + 8.3)** A covering index and a denormalized copied column both remove work from the read path. Compare them precisely: what each one eliminates, what each costs on the write path, which failure modes each is exposed to, and the specific situation in which you would choose the denormalized column even though a covering index is available.

2. **(§5 + §6 + 7.6)** A table uses an auto-increment integer primary key and takes 50,000 inserts/sec across a B-tree engine. Explain the contention that develops, why it is the same *shape* of problem as a hot partition even though it lives inside one machine, what changing to a random UUID primary key fixes and what it breaks — including what it does to every secondary index in InnoDB — and what you would actually choose.

3. **(§5 + §6, applied to a novel system)** Design the storage and index strategy for a flight-search price-history service: roughly 400,000 price observations per second written continuously, and two read patterns — "the last 30 days of prices for route X on date Y" (hundreds of times per second, latency-sensitive) and "all observations for an analyst's ad-hoc query over any 6-month window" (a few per hour, latency-tolerant). Choose an engine family and justify it, specify the index or key structure for each read pattern including exact column order, and name the one failure mode your design is most exposed to and how you would detect it.

### Mastery criteria — tick only what you can demonstrate on demand

- [ ] Can explain why a full scan fails and why neither a sorted table nor an in-memory hash table is a general replacement for an index
- [ ] Can explain the difference between a B-tree index and an LSM-tree — mechanism, write path, read path, failure modes — and name which storage engines use each
- [ ] Can state the leftmost-prefix rule and the range-stopper rule, and use ESR to derive the correct column order for an unfamiliar query
- [ ] Can explain what a covering index is, what it eliminates, and the engine-specific catch (Postgres visibility map, InnoDB's PK-in-secondary-index)
- [ ] Can price an index on the write path in concrete terms — structures written per insert, page rewrites, page splits, random I/O
- [ ] Can decide, for a given read:write shape and dataset size, whether a B-tree or LSM engine is correct and name exactly what the LSM choice costs
- [ ] Can design the indexes for a novel schema from its access patterns, and name the indexes they would *not* build and why

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 9. 🔗 Connections & Sources

**Builds on:** **8.3 Normalization and Denormalization** — a normalized schema's read cost is almost entirely a question of whether the join columns are indexed, so index design is the direct continuation of schema design, and a covering index is the *non-duplicating* alternative to a denormalized column. Also **8.2 OLTP vs. OLAP**, since selective point-and-range lookups are the OLTP access shape that B-trees serve, while scan-and-aggregate workloads are served by columnar layouts rather than more indexes. And **8.1 SQL vs. NoSQL**, because the engine's index family is often decided at store selection.

**Enables:** **8.5 Query patterns and optimization** — `EXPLAIN` is how you verify every claim in this document against a real planner. **8.7 Read vs. write optimization**, which is this subtopic's trade-off generalised to the whole system. **8.8 N+1 query problem**, where the fix is frequently an index plus a batched query rather than a schema change. **8.6 ACID transactions**, since index structures are where range locks and next-key locks physically live, making index design a concurrency decision too.

**Tension with:** **8.3 denormalization** — both a covering index and a copied column remove work from the read path, but the index keeps a single source of truth and the engine maintains it, while the column adds a copy you must keep in sync; knowing when to reach for which is a genuine judgment call. Also **7.6 Hot partitions** — the locality that makes monotonic keys efficient for B-tree inserts is the same locality that creates right-edge contention and hot shards, so the fixes at the two levels pull against each other.

### 📚 Further reading

- [ ] **Designing Data-Intensive Applications, Chapter 3 — Storage and Retrieval** — Kleppmann — the canonical B-tree vs. LSM comparison, including write amplification and compaction; read this one first
- [ ] **Use The Index, Luke** — Markus Winand — https://use-the-index-luke.com/ — the clearest treatment anywhere of composite index column order, the range-stopper rule, and covering indexes; start with "Anatomy of an Index" and "The Where Clause"
- [ ] **PostgreSQL docs — Indexes / Index-Only Scans** — https://www.postgresql.org/docs/current/indexes-index-only-scans.html — the visibility-map catch that makes index-only scans conditional
- [ ] **RocksDB Wiki — Leveled Compaction** — https://github.com/facebook/rocksdb/wiki/Leveled-Compaction — what compaction actually does, and the write/read/space amplification triangle
- [ ] **MongoDB — "The ESR Rule"** — https://www.mongodb.com/docs/manual/tutorial/equality-sort-range-rule/ — the equality/sort/range ordering rule stated explicitly, and evidence that it is engine-independent

---

## 10. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
