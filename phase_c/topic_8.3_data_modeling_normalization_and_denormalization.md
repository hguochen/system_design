# 8.3 Data Modeling — Normalization and Denormalization

> **Topic:** Topic 8 — Database Fundamentals
> **Phase:** C — Data Storage Branch
> **Depth Tier:** 🥇 T1 (Core) — budget ~1.75h
> **Prereqs:** 8.1 (SQL vs. NoSQL), 8.2 (OLTP vs. OLAP)
> **Date studied:** 2026-07-31

---

## 0. 🧭 The Question This Answers

8.1 asked which *engine* to use and 8.2 asked which *workload shape* you're serving. This subtopic asks the question that sits underneath both: once you've picked a store, **where does each individual fact physically live?** Normalization says a fact lives in exactly one place, so it can never disagree with itself. Denormalization says a fact lives in every place that reads it, so no read has to reassemble it. Both are correct — they just move cost between writes and reads, and the entire craft is knowing which direction to push for a given access pattern.

The central tension is that correctness and read performance pull in opposite directions here. Every duplicated copy of a fact is a read you made faster and a way your data can now become internally inconsistent. There is no schema that is simply "good" — there is only a schema that is correctly biased toward the workload it serves.

**The question:** *Should this fact live in exactly one place, or in every place that reads it — and if it's duplicated, who owns the truth?*

> **→ Next:** Before we can answer that, we need to know what actually goes wrong when a fact lives in more than one place. What breaks?

---

## 1. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*
>
> ⏭️ **First time through this topic?** Skip to §2 and come back here for revision.

```
§ 1  WHY IT EXISTS
Store the same fact in two places and the two copies will eventually disagree.
Not "might" — will, because updates are concurrent, partial, and fallible. A
customer changes their address; one row gets the new value, another doesn't,
and now the database contains two contradictory answers to one question with
no way to tell which is right. These are the update, insert, and delete
anomalies Codd identified in 1970. Normalization eliminates them structurally
rather than procedurally: if a fact physically exists in exactly one place, no
amount of buggy application code or interleaved concurrency can make two copies
disagree, because there is no second copy. The cost is that answering a
question now requires reassembling it from several tables via joins — and
joins are exactly what stops working when you shard.

§ 2  WHAT IT IS
NORMALIZATION   Decomposing tables so every non-key attribute depends on
                the key, the whole key, and nothing but the key.
  1NF  Atomic values. No repeating groups, no comma-separated lists in a cell.
  2NF  1NF + no partial dependency. Every non-key attribute depends on the
       WHOLE composite key, not just part of it.
  3NF  2NF + no transitive dependency. Non-key attributes don't depend on
       other non-key attributes. (zip → city belongs in its own table.)
  BCNF Stricter 3NF; rarely the deciding factor in an interview.
DENORMALIZATION Deliberately reintroducing duplication — copied columns,
                embedded documents, precomputed aggregates, materialized
                views — to remove joins from the read path. It is a
                performance decision, not a mistake, and it is only correct
                when you also name the sync mechanism.

§ 3  THE MECHANISM
NORMALIZED READ   The answer is scattered across N tables. Every query pays
                  N-1 joins: index lookup per table, then a nested-loop or
                  hash join to stitch rows together. Cheap on one machine
                  with warm indexes. Expensive the moment those tables live
                  on different shards — a local join becomes a network
                  scatter-gather (see 7.7).
DENORMALIZED READ One fetch by key returns the whole answer. No join, no
                  fan-out, predictable p99 — this is why single-table design
                  exists in DynamoDB and why timelines are precomputed.
THE TRADE         You did not delete the work. You moved it from read time
                  to write time. One write now touches every copy, and the
                  copies are only consistent if that fan-out is atomic
                  (transaction) or eventually reconciled (async + repair).
THE INVARIANT     Every duplicated fact needs a named SOURCE OF TRUTH and a
                  named SYNC MECHANISM. A design that duplicates without
                  naming both is incomplete, and interviewers probe exactly
                  there.

§ 4  USE / AVOID
NORMALIZE when: writes are frequent and must be correct; the entity is shared
  by many readers; the access pattern isn't known yet; the data is the system
  of record (money, inventory, identity, permissions).
DENORMALIZE when: the read:write ratio is heavily read-skewed; the join is on
  the hot path and measurably dominates latency; the data is immutable or
  slow-changing; the store cannot join at all (DynamoDB, Cassandra); the read
  crosses shard boundaries.
AVOID normalizing to 3NF-and-beyond as a reflex in a NoSQL design — it
  produces a schema the engine physically cannot serve, because there is no
  join operator to reassemble it.
AVOID denormalizing a fast-changing, widely-shared fact — the fan-out cost
  and drift risk grow with the number of copies, and one entity update
  becomes an unbounded write amplification.

§ 5  DENORMALIZATION PATTERNS (name these, don't just say "denormalize")
COPIED COLUMN      Duplicate a hot attribute onto the child row.
                   orders.customer_name alongside orders.customer_id.
EMBEDDED DOCUMENT  Nest the child inside the parent record. Order + line
                   items as one document. Bounded children only.
PRECOMPUTED COUNTER Store the aggregate, don't COUNT() it.
                   post.comment_count. Watch for the hot-row problem.
MATERIALIZED VIEW  Engine-maintained precomputed join/aggregate. Postgres
                   MATERIALIZED VIEW, or a DynamoDB GSI as a read model.
FAN-OUT-ON-WRITE   Write the result into every reader's own row at write
                   time. Twitter-style timelines (see 24.1).

§ 6  NUMBERS TO ANCHOR THE DISCUSSION
Rule of thumb: normalize until it hurts, denormalize until it works.
A same-shard indexed join is typically sub-millisecond; the argument for
  denormalizing is rarely about one join, it's about JOIN DEPTH (5+ tables)
  or CROSS-SHARD joins, which turn into network scatter-gather.
Read:write ratio is the deciding signal. ~100:1 or higher read-skew is
  where denormalization usually pays; near 1:1 it usually doesn't.
Write amplification = number of copies. Denormalizing a field onto 10M rows
  means one logical update becomes 10M physical writes — that's a backfill
  job, not an UPDATE statement.
Bounded-children rule: embed only if the child collection has a known ceiling
  (order → line items, yes; user → posts, no).

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "Walk me through your schema for this"            → state your normal form
                                                       AND your denorm choices
→ "This page does a 6-table join on every load"     → denormalize the read path
→ "How do you keep those two copies in sync?"       → source of truth + sync
                                                       mechanism, by name
→ "We're moving this table to DynamoDB"             → access-pattern-first
                                                       modeling, not 3NF
GOTCHA: Denormalizing without naming (a) which copy is the source of truth and
  (b) the mechanism that keeps the others converged — transaction, CDC stream,
  async job with a reconciliation/repair pass — is the single most common
  depth failure here. Saying "we'd denormalize for speed" and stopping reads
  as if duplication were free. It never is; you have traded a correctness
  guarantee for a latency win, and the interviewer wants to hear you say so.
```

---

## 2. 🧠 The Mindmap

> *The picture to hold in your head while you study. Everything below hangs off this.*

```
                            ┌──────────────────────────────┐
                            │   NORMALIZATION  ⇄  DENORM   │
                            │  "where does a fact live?"   │
                            └───────────────┬──────────────┘
                                            │
    ┌───────────────┬───────────────┬───────┴───────┬───────────────┬──────────────┐
    ▼               ▼               ▼               ▼               ▼              ▼
 THE RULES      THE ANOMALIES   DENORM         KEEPING COPIES   THE DECISION   REAL SYSTEMS
 (normal        (what breaks)   PATTERNS       HONEST
  forms)
 ├ 1NF atomic   ├ UPDATE        ├ copied col   ├ source of      ├ read:write   ├ Postgres
 │  values      │  one copy     │              │  truth         │  ratio       │  OLTP 3NF
 ├ 2NF whole    │  changes,     ├ embedded     │  (exactly one) ├ join depth   ├ DynamoDB
 │  key         │  other        │  document    ├ sync: txn /    │              │  single-table
 ├ 3NF no       │  doesn't      ├ precomputed  │  CDC / async   ├ cross-shard? ├ Twitter
 │  transitive  ├ INSERT        │  counter     ├ repair pass /  │              │  timelines
 │  deps        │  can't add    ├ materialized │  reconciler    ├ mutability   ├ Reddit
 └ BCNF         │  X without Y  │  view        └ drift is a     │  of the fact │  counters
   (rarely      └ DELETE        └ fan-out-on-    WHEN, not      └ shape of the └ Amazon
    decisive)      lose X by      write          an IF            store           order history
                   removing Y
```

**How to read it:** left to right is the argument. The **rules** exist to prevent the **anomalies**; the anomalies are the price you accept when you adopt a **denorm pattern**; that price is only acceptable if you have a mechanism for **keeping copies honest**; and which way you lean is settled by **the decision** signals, which you can check against how **real systems** actually resolved it.

---

## 3. 🔥 The Problem

Before relational modeling, business data lived in flat files and single wide records — one row per order, carrying the customer's name, address, and phone number right alongside the line items. It reads beautifully. Every query is a single fetch, no joins, no indirection. And it is structurally incapable of staying correct.

Consider a customer with 400 orders, where their address is stored on every order row. The customer moves. You now have 400 rows to update, and three distinct ways to break. **The update anomaly:** the job updates 380 rows and dies, and the database now holds two contradictory addresses for one customer with no marker saying which is current. **The insert anomaly:** you cannot record a new customer at all until they place an order, because the only place an address can be stored is on an order row — the fact has no home of its own. **The delete anomaly:** deleting a customer's last order erases the only copy of their address as collateral damage. In each case the corruption isn't caused by a bug in the storage engine. It's caused by the *shape of the schema* permitting two copies of one fact to exist independently.

The instinctive fix is procedural: be careful in application code. Wrap it in a transaction, write a helper that always updates all copies, add tests. This does not work, and understanding precisely why is what separates a real answer from a rehearsed one. It fails because correctness now depends on every future writer — every service, every migration script, every hotfix, every intern — remembering the invariant, forever. It fails because concurrent writers interleave: two transactions each updating a different subset of the copies can commit in an order that leaves the copies permanently mismatched. And it fails because partial failure is normal, not exceptional — a process dies mid-fan-out and there is nothing in the schema that can detect the resulting split-brain, because both values are equally legal as far as the database is concerned. Procedural correctness is a promise. Structural correctness is a guarantee.

Codd's 1970 insight was to make the guarantee structural. If a fact physically exists in exactly one location, then no sequence of concurrent, partial, or buggy writes can produce two copies that disagree — there *is* no second copy to disagree. Anomalies aren't prevented by discipline; they're rendered impossible by the schema. That's normalization, and it's why 3NF became the default for systems of record.

But the guarantee is not free, and the bill arrives at read time. Once a customer's address lives in one table and their orders in another, answering "show me this order with the shipping address" requires a join. On a single machine with warm indexes, that join is sub-millisecond and nobody notices. Push the same schema onto a sharded cluster — where the customer row and the order rows may live on different physical nodes — and that local join becomes a cross-network scatter-gather with the tail-latency profile of the slowest shard (this is exactly the 7.7 problem). Put five of those joins on a page that loads on every request, and normalization's correctness guarantee is now the thing making your product slow.

So the field arrived at the position it holds today: normalization is the correct **default**, and denormalization is a deliberate, *local*, *justified* retreat from it — trading a correctness guarantee for a latency win, on specific data, for a specific access pattern, with a named mechanism for containing the damage.

**Before and after:**

```
   BEFORE — one wide table                    AFTER — decomposed
   ────────────────────────                   ──────────────────
   orders                                     customers
   ┌────┬─────────┬──────────────┬──────┐     ┌─────┬───────┬─────────────┐
   │ id │ cust    │ address      │ item │     │ id  │ name  │ address     │
   ├────┼─────────┼──────────────┼──────┤     ├─────┼───────┼─────────────┤
   │ 1  │ Ada     │ 12 Oak St    │ pen  │     │ 7   │ Ada   │ 99 Elm Rd   │ ◄─ ONE home.
   │ 2  │ Ada     │ 12 Oak St    │ mug  │     └─────┴───────┴─────────────┘    One update.
   │ 3  │ Ada     │ 99 Elm Rd    │ pad  │◄─┐  orders                           Cannot
   └────┴─────────┴──────────────┴──────┘  │  ┌────┬─────────┬──────┐          disagree.
                                           │  │ id │ cust_id │ item │
   ⚠ Which address is Ada's? The schema  ──┘  ├────┼─────────┼──────┤
     permits both. No way to tell.            │ 1  │    7    │ pen  │
     Update died at row 2 of 3.               │ 2  │    7    │ mug  │
                                              │ 3  │    7    │ pad  │
   ✗ update / insert / delete anomalies       └────┴────┬────┴──────┘
                                                        │
                                              ✓ no anomalies possible
                                              ✗ every read now pays a JOIN
```

### ✅ Checkpoint

1. Why can't you eliminate update anomalies by simply being disciplined in application code — always wrapping the fan-out in a transaction and always using a shared helper function? Give the three distinct reasons this is a promise rather than a guarantee.

   > 💡 *Answer out loud before reading on. If you hesitate, re-read the third paragraph — the difference between procedural and structural correctness.*

MODEL ANSWER — §3 Checkpoint

Why procedural discipline can't eliminate update anomalies:

1. EVERY FUTURE WRITER must remember the invariant — every service,
   migration script, hotfix, intern. Forever. Failure is a WHEN,
   not an IF.

2. CONCURRENT WRITERS INTERLEAVE — two transactions each updating a
   different subset of the copies can commit in an order that leaves
   the copies permanently mismatched.

3. PARTIAL FAILURE IS NORMAL — a process dies mid-fan-out, and the
   schema cannot detect the resulting split-brain because BOTH values
   are equally legal. No constraint says these two must agree, so the
   DB has no basis to reject either. Not a lost write — a lost
   DISTINCTION.

THE ONE-SENTENCE VERSION:
  All three fail because the invariant lives in APPLICATION CODE,
  outside the data — and an invariant outside the data isn't enforced
  by the data. Normalization moves it INSIDE: one fact, one home, no
  second copy to disagree.

  Procedural correctness is a promise. Structural correctness is a
  guarantee.

> **→ Next:** If a fact should have exactly one home, what's the actual rule for deciding where that home is — and what do you call the schema that follows it?

---

## 4. 💡 The Core Idea

**Normalization is the process of decomposing tables until every non-key attribute depends on the key, the whole key, and nothing but the key — so that each fact has exactly one physical home; denormalization is the deliberate reintroduction of duplicate copies of a fact to remove joins from a hot read path, accepting anomaly risk in exchange for read latency.**

The five ideas below build on each other. Each one only makes sense because of the one before it.

**The build chain:**

```
 [ONE HOME PER FACT] ──▶ [NORMAL FORMS] ──▶ [COST MOVES TO READS] ──▶ [DENORM PATTERNS] ──▶ [SYNC OR DRIFT]
     because a copy          therefore we        which means at            so we buy reads         so every copy
     can disagree            need a rule for     scale, joins are          back by copying         needs an owner
     with itself             where "one" is      the bill                  facts again             and a mechanism
```

### One Home Per Fact — the functional dependency

The whole discipline rests on a single relationship: a **functional dependency**, written `A → B`, meaning "given A, B is completely determined." `customer_id → address` says that once you know the customer, the address follows; it is a property of the *business domain*, not of any particular query. The rule that falls out is that B belongs in the table whose key is A, and nowhere else. When `address` appears on an order row, you've stored a customer-determined fact in an order-keyed table, and that mismatch is precisely what creates room for two copies to diverge. Every anomaly in §3 traces back to a functional dependency being stored somewhere other than its own key's table.

### Normal Forms — the rule for finding "one"

Because "put each fact in its own table" is too vague to apply mechanically, the normal forms turn it into a checklist, each one closing a specific loophole the previous one left open. **1NF** demands atomic values: no `"pen,mug,pad"` crammed into one cell and no repeating `item_1, item_2, item_3` columns, because you cannot index, constrain, or independently update a value buried inside another value. **2NF** adds that no non-key attribute may depend on only *part* of a composite key — in an `order_items(order_id, product_id)` table, `product_name` depends on `product_id` alone, so it's duplicated on every line item that sells that product and belongs in `products` instead. **3NF** adds that no non-key attribute may depend on *another non-key attribute*: storing `zip` and `city` together in `customers` is a transitive dependency (`customer_id → zip → city`), so a zip-to-city correction has to be applied in as many rows as use that zip. **BCNF** tightens 3NF for tables with overlapping candidate keys; know the name, but it is almost never the deciding factor in an interview. The practical shorthand — *the key, the whole key, and nothing but the key* — maps exactly onto 1NF, 2NF, 3NF in that order.

### The Cost Moves to Reads

Notice what normalization actually did: it did not remove work, it relocated it. Writes became cheap and safe — one fact, one row, one update, no fan-out, no possibility of divergence — while reads became expensive, because an answer that used to sit in one row is now scattered across several tables and must be reassembled by a join on every single request. On one machine with warm indexes this is a fine trade and usually invisible. It stops being fine in two specific situations, and naming them is what makes your interview answer concrete: when **join depth** grows (a page assembling user → profile → org → plan → entitlements on every load), and when the joined tables live on **different shards**, converting a local index lookup into a cross-network scatter-gather whose latency is set by the slowest node (7.7). Normalization's guarantee is paid for, per read, forever.

### Denormalization Patterns — buying the reads back

Once you see the cost as *relocated* rather than eliminated, denormalization stops looking like a mistake and starts looking like the other direction on the same dial: you move work back to write time by storing a fact in every place that reads it. What matters in an interview is naming the specific pattern rather than waving at "denormalize." A **copied column** duplicates one hot attribute onto the child row (`orders.customer_name` beside `customer_id`) so the common render needs no join. An **embedded document** nests children inside the parent (an order carrying its line items as one document) — correct only when the child collection has a known ceiling. A **precomputed counter** stores `post.comment_count` instead of running `COUNT(*)`, converting an O(n) scan into an O(1) read. A **materialized view** has the engine maintain a precomputed join or aggregate for you (a Postgres `MATERIALIZED VIEW`, or a DynamoDB GSI acting as a purpose-built read model). And **fan-out-on-write** goes furthest, writing the finished result into every reader's own row at write time — the pattern behind precomputed timelines in 24.1.

### Sync or Drift — the part candidates forget

Every one of those patterns creates a second copy of a fact, which reintroduces exactly the anomaly risk §3 spent its whole argument eliminating. The difference between a competent denormalization and a data-corruption incident is that the competent one names two things explicitly. First, the **source of truth**: exactly one copy is authoritative, and every other copy is a derived cache that can be rebuilt from it. Second, the **sync mechanism**: a transaction that updates all copies atomically (correct, but limits you to one shard or one database), a CDC stream that tails the write-ahead log and propagates changes asynchronously (scales, but is eventually consistent), or a background job with a periodic **reconciliation pass** that detects and repairs drift. Drift is not an *if*, it is a *when* — pipelines lag, jobs fail halfway, messages arrive out of order — so a mature design assumes copies will diverge and includes the repair path from the start.

### ✅ Checkpoint

1. A table `order_items(order_id, product_id, quantity, product_name, product_category)` has a composite primary key of `(order_id, product_id)`. Which normal form does it violate, exactly which attributes cause the violation, and what concrete anomaly does that permit?

   > 💡 *If you hesitate, re-read §4 — Normal Forms, the 2NF paragraph.*

MODEL ANSWER — §4 Checkpoint 1

TABLE   order_items(order_id, product_id, quantity,
                    product_name, product_category)
PK      (order_id, product_id)  ← composite, so 2NF is in play

VIOLATION   2NF — partial dependency.
OFFENDERS   product_name AND product_category.
            Both are determined by product_id ALONE — half the key.
            (product_id is the DETERMINANT, not the offender.)

WHY quantity IS FINE
  Cover order_id  → product_id alone doesn't determine quantity
  Cover product_id → order_id alone doesn't determine quantity
  Neither half determines it; both together do → whole key → OK.

ANOMALIES PERMITTED (all three)
  UPDATE  rename a product → fan-out across every line item that
          sold it; partial failure leaves two legal names, no way
          to tell which is current
  INSERT  cannot record a product nobody has ordered yet — it has
          no order_id to hang on
  DELETE  removing the last order line for a product erases its
          name and category as collateral damage

FIX
  order_items(order_id, product_id, quantity)
  products(product_id, product_name, product_category)

THE TEST, RESTATED
  2NF is only ever violated when the PK is composite. Cover half
  the key with your thumb — if a non-key column is still fully
  determined by what's left, it's in the wrong table.

2. Explain why the *cost relocation* framing (third block) is what makes the *denormalization patterns* (fourth block) coherent rather than contradictory. Why isn't denormalizing simply undoing normalization?

   > 💡 *If you hesitate, re-read the build chain above and trace the "therefore → which means → so" links.*

MODEL ANSWER — §4 Checkpoint 2

WHY COST RELOCATION MAKES DENORMALIZATION COHERENT

Normalization did not remove work — it MOVED it. Writes became
cheap and safe (one fact, one row, no fan-out); reads became
expensive (reassemble via joins, paid per request, forever).

So there is one dial with two directions, not a right answer and
a wrong answer. Denormalization pushes the dial back toward write
time: store the fact in every place that reads it, so the read is
one fetch and the write pays the fan-out.

WHY IT ISN'T "UNDOING" NORMALIZATION — three reasons

1. SOURCE OF TRUTH SURVIVES
   The normalized copy stays authoritative; every duplicate is
   DERIVED and rebuildable from it. §3's flat table had no
   authoritative copy at all — that's why its divergence was
   unresolvable.

2. THE FAILURE MODE IS DIFFERENT IN KIND
   Unnormalized divergence = CORRUPTION (unrecoverable, both
   values equally legal).
   Denormalized drift    = STALENESS (recoverable, recompute
   from the source of truth).

3. IT'S LOCAL AND PRICED
   You denormalize specific fields on specific hot read paths,
   with a named pattern and a named sync mechanism — not as a
   global schema philosophy. Undoing normalization is a schema
   that never had the guarantee. Denormalizing is a schema that
   has it and spends it, narrowly, on purpose.

THE SOUNDBITE
  Normalization relocates cost to reads. Denormalization
  relocates it back to writes — but keeps the source of truth,
  so what used to be corruption is now only staleness.

> **→ Next:** You know the two directions and why they exist. What physically happens inside the database when you read and write each shape?

---

## 5. ⚙️ How It Actually Works

**The normalized read path (happy path):**

1. The query planner parses the join and picks an order — typically the most selective table first, to shrink the working set before joining anything else.
2. It probes the driving table's index (B-tree) to locate the qualifying rows.
3. For each row, it resolves the foreign key into the next table. With a small outer set it uses a **nested-loop join** (index probe per row); with large sets it builds a **hash join** (hash the smaller side in memory, stream the larger side past it).
4. It repeats per additional table. Latency compounds roughly with join depth, and each step's cost is dominated by whether that table's index and pages are already in the buffer pool.
5. Rows are stitched and projected. On one machine with warm indexes, a 2–3 table join here is routinely sub-millisecond.

> 🗺️ **Mental model — The library catalogue.** A normalized database is a library where the catalogue holds a card per book pointing at a shelf location, and the shelf holds the book. Nothing is written twice, so nothing can contradict itself — but every lookup is two trips, and a question spanning five catalogues is five trips. *Where it breaks down:* it suggests the trips are the only cost. The real killer isn't trip *count*, it's trip *distance* — when the shelves are in different buildings (shards), the same query changes character entirely.

**The denormalized read path (happy path):**

1. The query fetches by primary key or partition key.
2. One page (row store) or one item (document/wide-column store) is returned containing the whole answer — copied columns, embedded children, precomputed aggregates already materialized.
3. No join, no fan-out, no cross-shard coordination. Latency is one I/O and is essentially flat regardless of how many logical entities the answer spans — which is why p99 is so much tighter here, and why it's the default in stores that have no join operator at all.

**Read paths compared — and where the write cost went:**

```
 ① NORMALIZED READ — reassemble on every request
 ┌──────────────┐   ┌──────────────┐   ┌──────────────────┐   ┌────────────────┐   ┌────────┐
 │ query planner│──▶│ B-tree probe │──▶│ nested-loop/hash │──▶│  … join tbl N  │──▶│ answer │
 │ picks order  │   │ driving table│   │   join table 2   │   │ cost ∝ depth   │   └────────┘
 └──────────────┘   └──────────────┘   └──────────────────┘   └────────────────┘
 ⚠ if tables sit on different shards, each join becomes a network scatter-gather (7.7)

 ② DENORMALIZED READ — already assembled
 ┌──────────────────┐   ┌───────────────┐
 │  fetch by key    │──▶│ answer — 1 I/O│   ✓ no join · no fan-out · no cross-shard
 │ PK/partition key │   └───────────────┘   ✓ p99 flat regardless of entity count
 └──────────────────┘

 ③ THE DENORMALIZED WRITE PATH — this is where the cost actually went
                    ┌────────────────────────────────────┐
                    │ transactional fan-out              │  strong · capped at 1 shard/db
 ┌────────────────┐ ├────────────────────────────────────┤
 │ SOURCE OF TRUTH│─┤ CDC / event-driven                 │  scales · seconds of lag
 │ exactly one row│ ├────────────────────────────────────┤
 └────────────────┘ │ async job + reconciler             │  the part people omit
                    └──────────────────┬─────────────────┘
                                       ▼
                          ┌──────────────────────┐      ┌────────────────────────────┐
                          │  copy 1 … copy N     │─────▶│ WRITE AMPLIFICATION        │
                          │  derived, rebuildable│      │  = number of copies        │
                          └──────────────────────┘      │ 1 update on 10M rows =     │
                                                        │ a backfill, not an UPDATE  │
                                                        └────────────────────────────┘
```

**The denormalized write path — where the cost actually went:**

1. A write updates the source-of-truth row.
2. It must then propagate to every copy. Three mechanisms, in ascending order of scale and descending order of guarantee:
   - **Transactional fan-out** — update all copies in one ACID transaction. Strong guarantee, but every copy must be reachable in one transaction scope, so this caps you at a single database or shard.
   - **CDC / event-driven** — tail the write-ahead log (Debezium, DynamoDB Streams) and propagate changes downstream. Scales across systems; copies are eventually consistent, typically seconds behind.
   - **Async job + reconciliation** — enqueue the fan-out, and run a periodic sweeper that recomputes derived values from the source of truth and repairs mismatches. The sweeper is the part people omit and the part that saves you.
3. **Write amplification is the number of copies.** Denormalizing a field onto ten million rows means one logical update becomes ten million physical writes — an offline backfill, not an `UPDATE` statement. Say this out loud in an interview; it demonstrates you've thought past the design into the migration.

> 🗺️ **Mental model — Denormalization is a cache you cannot flush.** Every duplicated field is a cache of a fact, so all of Topic 5 applies: it needs an invalidation strategy, it can go stale, and it can serve wrong answers confidently. The one crucial difference is that a cache miss falls back to the source of truth, whereas a stale denormalized column *is* the value the application reads — there is no miss, so nothing self-corrects. *Where it breaks down:* materialized views and GSIs are engine-maintained, so the invalidation is handled for you; the analogy applies fully only to hand-rolled duplication.

**Failure and edge cases:**

- **Drift.** Copies diverge after a partially-failed fan-out or a lagging pipeline. Detectable only if something recomputes from the source of truth and compares — which is why the reconciliation pass is part of the design, not an operational nicety.
- **Unbounded embedded collections.** Embedding works only for bounded children. Embedding a user's posts means the user document grows without limit until it hits the item-size ceiling (400KB in DynamoDB, 16MB in MongoDB) and writes start failing — and every small update rewrites the whole document.
- **Hot rows on precomputed counters.** A single `comment_count` on a viral post becomes a contended row; every commenter serializes on the same lock. Mitigations are sharded counters (N sub-counters summed on read) or buffered increments — this is the 5.7 hot-key problem wearing a schema costume.
- **Backfill and schema evolution.** Adding a denormalized column to an existing large table is an online backfill with throttling and a dual-write window, not a migration you run in a deploy.
- **Over-normalization in a store that can't join.** Applying 3NF to DynamoDB or Cassandra produces a schema the engine physically cannot serve; the application ends up doing N sequential round trips to emulate a join — an N+1 problem (8.8) built directly into the data model.

**The decomposition, structurally:**

```
  UNNORMALIZED                1NF                    2NF                    3NF
  ────────────                ───                    ───                    ───
  orders                      orders                 orders                 orders
  ┌──────────────────┐        ┌────────────────┐     ┌──────────────┐       ┌──────────────┐
  │ id               │        │ id             │     │ id           │       │ id           │
  │ customer         │        │ customer       │     │ customer_id  │       │ customer_id  │
  │ cust_zip         │        │ cust_zip       │     │              │       │              │
  │ cust_city        │        │ cust_city      │     └──────────────┘       └──────────────┘
  │ items            │        │ item  ◄────────┼──┐  order_items            order_items
  │ "pen,mug,pad" ◄──┼──┐     │ qty            │  │  ┌──────────────┐       ┌──────────────┐
  │ prod_name        │  │     │ prod_name      │  │  │ order_id     │       │ order_id     │
  └──────────────────┘  │     │ prod_category  │  │  │ product_id   │       │ product_id   │
                        │     └────────────────┘  │  │ qty          │       │ qty          │
   ✗ non-atomic cell ───┘                         │  └──────────────┘       └──────────────┘
                              ✓ atomic values     │  products               products
                              ✗ prod_name dep. on │  ┌──────────────┐       ┌──────────────┐
                                product_id only ──┘  │ product_id   │       │ product_id   │
                                (partial dep.)       │ name         │       │ name         │
                                                     │ category     │       │ category     │
                                                     └──────────────┘       └──────────────┘
                                                     customers              customers
                                                     ┌──────────────┐       ┌──────────────┐
                                                     │ id           │       │ id           │
                                                     │ name         │       │ name         │
                                                     │ zip          │       │ zip ─────────┼──┐
                                                     │ city  ◄──────┼──┐    └──────────────┘  │
                                                     └──────────────┘  │    zip_codes         │
                                                                       │    ┌──────────────┐  │
                                                     ✗ city dep. on ───┘    │ zip  ◄───────┼──┘
                                                       zip, not on id       │ city         │
                                                       (transitive dep.)    └──────────────┘
                                                                            ✓ 3NF
```

### ✅ Checkpoint

1. Trace what physically happens when a denormalized `orders.customer_name` column is updated because a customer changed their name — from the first write through to the last copy — and name where in that sequence the data can be left permanently inconsistent.

   > 💡 *If you hesitate, re-read the denormalized write path above, steps 1–3.*
MODEL ANSWER — §5 Checkpoint 1

TRACE: customer renames, orders.customer_name is denormalized

1. Write lands on the SOURCE OF TRUTH row (customers).

2. Fan-out to every copy. Mechanism decides the risk:
   TRANSACTIONAL   atomic — all copies commit or all roll back.
                   NO permanent-inconsistency window. Cost: every
                   copy must sit in one transaction scope, so this
                   caps you at one shard / one database.
   CDC / ASYNC     copies converge eventually, seconds behind.
                   THIS is where the window opens.

3. Copies updated. Cost is proportional to that customer's order
   count — NOT a backfill. (Backfill = adding a denormalized
   column onto 10M existing rows; different operation.)

WHERE IT BECOMES PERMANENTLY INCONSISTENT
  Any partial failure in the async fan-out — dropped event, dead
  worker, reordered replay — leaves some copies stale.

WHY PERMANENT, NOT MERELY STALE
  A denormalized column has NO MISS PATH.
    Cache:  entry can be ABSENT → absence triggers a fallback read
            to the source → self-heals on the next request.
    Column: value is ALWAYS PRESENT → no fallback is ever triggered
            → the app reads the wrong value confidently, forever.
  Nothing self-corrects. Presence is the hazard.

WHAT YOU MUST BUILD
  A reconciliation sweeper that RECOMPUTES copies from the source
  of truth — never by replaying the stream, because the stream is
  what failed. Sync path and repair path are two different things;
  naming only the sync path is the incomplete answer.

2. A team embeds a user's posts inside the user document because "it makes the profile page one fetch." Name the failure mode this creates, the specific limit it eventually hits, and the rule that would have prevented the choice.

   > 💡 *If you hesitate, re-read the failure cases — unbounded embedded collections.*
MODEL ANSWER — §5 Checkpoint 2

FAILURE MODE
  Unbounded embedded collection. user → posts has no ceiling,
  so the document grows without limit.

WHAT BITES FIRST (before the hard limit)
  WRITE  every update rewrites the ENTIRE document — adding one
         post rewrites all N. Write cost grows with history.
  READ   no pagination inside an embedded array — rendering 10
         posts fetches all of them.

WHAT BITES EVENTUALLY
  Hard item-size ceiling → writes fail outright.
    DynamoDB  400 KB
    MongoDB   16 MB

THE RULE
  Bounded-children rule — embed ONLY when the child collection
  has a known ceiling.
    order → line items    bounded    ✓ embed
    user  → posts         unbounded  ✗ reference

  The ceiling must be a property of the DOMAIN, not a guess.
  "Probably won't get big" is not a bound.

> **→ Next:** You know both mechanisms and how each fails. So in a live design, which do you actually pick — and what exactly are you giving up?

---

## 6. ⚖️ The Decision — When, and What It Costs

The default is normalize. It is the correct starting position because it is the only one that gives a structural correctness guarantee, and because early in a design you usually do not yet know the access patterns well enough to optimize for them — a normalized schema keeps every future query cheap to *write*, even if some are expensive to *run*. You retreat from that default locally, on specific fields, when you can point at a measured read path and name what you're buying.

Four signals decide it. **Read:write ratio** is the strongest: heavily read-skewed data (roughly 100:1 or more) amortizes the write-side fan-out across a huge number of cheap reads, while near-1:1 data pays the fan-out constantly and gains little. **Join depth and shard-crossing** is the second: a two-table same-shard join almost never justifies denormalizing, whereas a five-table join or any cross-shard join on a hot path frequently does. **Mutability** is the third and is the one most often skipped: duplicating an immutable or slow-changing fact (a product's category, an order's shipping address *at time of purchase*) is nearly free of drift risk, while duplicating a volatile, widely-shared fact multiplies both write cost and divergence risk with every copy. Note the subtlety in that example — an order's shipping address is not really a duplicate at all, it's a **point-in-time snapshot**, a genuinely different fact from the customer's current address, and recognizing that distinction is a strong signal in an interview. **Store capability** is the fourth and can be decisive on its own: DynamoDB and Cassandra have no join operator, so access-pattern-first modeling with deliberate duplication isn't an optimization there, it's the only way to model at all (8.1).

**Decision tree:**

```
                    Is this the system of record?
                    (money, identity, inventory, permissions)
                              │
                 ┌────yes─────┴──────no────┐
                 ▼                         ▼
         NORMALIZE. Correctness    Can the store even join?
         is the requirement.              │
         Denormalize only into      ┌─no──┴──yes──┐
         a separate read model.     ▼             ▼
                             DENORMALIZE.   Is the join on a hot path
                             Model by       AND (depth ≥ 5 OR cross-shard)?
                             access pattern.       │
                             It's the only    ┌─no─┴─yes─┐
                             option.          ▼          ▼
                                          NORMALIZE.  Is the fact slow-changing
                                          The join is  and read:write ≥ ~100:1?
                                          not your          │
                                          problem.     ┌─no─┴─yes─┐
                                                       ▼          ▼
                                                  NORMALIZE.  DENORMALIZE —
                                                  Fan-out     name the pattern,
                                                  cost and    the source of truth,
                                                  drift risk  and the sync mechanism.
                                                  exceed the
                                                  read win.
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Normalization: anomalies become structurally impossible** — one fact, one home, no sequence of concurrent or partial writes can create disagreement | Every read reassembles the answer via joins, paid per request forever; and the schema degrades badly the moment those tables are sharded onto different nodes |
| **Normalization: storage efficiency and cheap writes** — a fact is updated in exactly one place, so no fan-out and no write amplification | Read latency is the least predictable part of the system; p99 is set by join depth and buffer-pool warmth, both of which drift as data grows |
| **Denormalization: flat, predictable single-fetch reads** — no join, no scatter-gather, p99 largely independent of how many entities the answer spans | You have reintroduced the update anomaly by choice; correctness now depends on a sync mechanism that can lag, fail partially, or silently drift |
| **Denormalization: works in stores with no join operator** — the only viable model for DynamoDB, Cassandra, and similar | Write amplification equals the number of copies; a schema change becomes an online backfill with a dual-write window, not a migration |
| **Precomputed aggregates: O(1) instead of O(n)** — `comment_count` beats `COUNT(*)` at any scale | Creates a contended hot row on popular entities, requiring sharded counters or buffered increments (5.7) |

### In production

| System | How it applies | The nuance |
|--------|----------------|------------|
| **Postgres / MySQL as system of record** | Normalized to 3NF for orders, payments, inventory, identity — anywhere a wrong value costs money or trust. Denormalization appears narrowly, as a counter cache or a `MATERIALIZED VIEW` | `MATERIALIZED VIEW` is engine-maintained but **not** auto-refreshed in Postgres — you schedule `REFRESH`, so staleness is your explicit choice, not a default |
| **DynamoDB single-table design** | No join operator, so the model is built access-pattern-first: entities are deliberately duplicated across items and GSIs so every query is a single partition fetch | The design is only possible if you enumerate access patterns *before* modeling; adding an unforeseen pattern later often means a new GSI and a full backfill |
| **Twitter / X home timelines** | Fan-out-on-write: a tweet is copied into each follower's materialized timeline at post time, so reading a timeline is one sequential fetch instead of a join across everyone you follow | Breaks for celebrity accounts, where one post fans out to 100M+ rows — hence the hybrid model that merges precomputed timelines with pull-on-read for high-follower accounts (24.3) |
| **Reddit / Instagram counters** | `comment_count`, `like_count` stored on the parent rather than aggregated at read time | On viral content the counter row becomes a contention hot spot; mitigated with sharded counters or buffered async increments, and the displayed value is often deliberately approximate |
| **Amazon order history** | The shipping address and item price are copied onto the order at purchase time rather than joined from `customers` and `products` | This is a **point-in-time snapshot**, not denormalization — the order must preserve what was true at purchase. Correctness *requires* the copy here; joining live would actively produce the wrong answer |

### ✅ Checkpoint

1. A product catalogue service stores `product.category_name` copied onto every one of 50 million product rows for fast filtering. Categories are renamed roughly twice a year. Is this a good denormalization? Justify using at least three of the four decision signals, and name what you would still need to build.

   > 💡 *If you hesitate, re-read the four signals at the top of §6 and the decision tree.*
MODEL ANSWER — §6 Checkpoint

VERDICT  Yes — a good denormalization.

SIGNALS (3 of 4)
  READ:WRITE RATIO   Extreme. 50M products read continuously;
                     categories written ~2×/year. Orders of
                     magnitude past the ~100:1 threshold.
                     ← THE STRONGEST ARGUMENT. Lead with this.
  MUTABILITY         Categories are near-immutable. Drift risk is
                     tiny because there is almost nothing to drift.
  JOIN / STORE       Weakest here. A single join to a small
                     dimension table is sub-ms on a warm index.
                     Do NOT lead with "it avoids a join" — an
                     interviewer will push back and be right.
                     (Would become decisive if the store had no
                     join operator at all.)

WRITE COST, SCOPED CORRECTLY
  Renaming one category fans out to the rows IN THAT CATEGORY —
  not all 50M. Twice a year, amortizable. But it is a genuine
  online backfill with throttling and a dual-write window, not an
  UPDATE statement.

WHAT YOU MUST STILL BUILD — THE TRIPLE
  1. SOURCE OF TRUTH   categories is authoritative;
                       product.category_name is DERIVED and
                       rebuildable from it.
  2. SYNC MECHANISM    transaction if all copies fit one scope;
                       CDC / async otherwise.
  3. REPAIR PATH       periodic reconciliation sweeper that
                       RECOMPUTES from the source of truth —
                       never by replaying the stream, because the
                       stream is what failed.

THE RULE
  Never say "we'd denormalize" without naming all three.
  Naming only #2 is the most common depth failure on this subtopic.

> **→ Next:** You can defend the choice. How does an interviewer actually put pressure on it?

---

## 7. 🎯 In the Interview

**When an interviewer asks / says:**

- "Walk me through the schema you'd use for this."
- "This page currently does a six-table join on every load — what would you do?"
- "How would you keep those two copies in sync?"
- "We're moving this off Postgres onto DynamoDB. What changes about your data model?"
- "How do you count the likes on a post?"

**What you say / do:**

This lands in the **data model** phase, immediately after you've chosen the store (8.1) and classified the workload (8.2), and it resurfaces in the **deep dive** the moment the interviewer probes a hot read path. Lead with your default and make it explicit — "I'd normalize the system of record to 3NF" — then denormalize *narrowly and out loud*, naming the specific pattern, the field, the read path it serves, and the sync mechanism. The signal you're sending is that duplication is a decision you priced, not a shortcut you took.

**The trade-off statement (memorize this pattern):**

> "I'd keep `customers` and `orders` normalized, since the order table is the system of record and an incorrect address costs a real delivery. But the order list page renders customer name on every row, and that's a join on our hottest read path, so I'd denormalize `customer_name` onto `orders` as a copied column. `customers` stays the source of truth; the copy is maintained by a CDC stream off the customers table with a nightly reconciliation job to repair drift. I'm trading a few seconds of staleness on a display name — which is tolerable — for removing a join from a path that runs on every page load. If instead this were the billing address, I wouldn't denormalize it; I'd snapshot it onto the order at purchase time, because there the historical value is the correct value."

### ⚠️ Traps

- ❌ **Trap:** "We'd denormalize for read performance." — and then stopping there.
  ✅ **Reality:** This is the single most common depth failure on this subtopic. Duplication is not free; you have traded a structural correctness guarantee for latency. A complete answer always names three things: which copy is the **source of truth**, the **sync mechanism** (transaction, CDC, or async job), and the **reconciliation path** for when sync fails. Interviewers ask "how do you keep those in sync?" precisely because most candidates never volunteer it.

- ❌ **Trap:** "Normalization is for SQL; NoSQL means denormalized."
  ✅ **Reality:** Normalization is a property of the *data model*, not of the engine. You can build a fully normalized model in MongoDB with manual reference resolution, and you can heavily denormalize in Postgres with materialized views and copied columns. What actually differs is that document and wide-column stores have no join operator, so a normalized model there forces the *application* to emulate joins with sequential round trips — which is why access-pattern-first modeling dominates in those stores. The reason is capability, not category.

- ❌ **Trap:** "Third normal form is always the right target."
  ✅ **Reality:** 3NF is the right *default* for a system of record, not a universal goal. Two large classes of system correctly sit elsewhere: analytical stores deliberately use denormalized star schemas because their workload is scan-and-aggregate (8.2), and high-scale read paths deliberately precompute. Reciting normal forms as an unconditional target reads as textbook knowledge rather than design judgment.

- ❌ **Trap:** "Storing the shipping address on the order is denormalization."
  ✅ **Reality:** It's a **point-in-time snapshot**, which is a different fact from the customer's current address — the order must preserve what was true at purchase. Here the copy is not a performance optimization at all; joining to the live customer record would actively produce the *wrong* answer on any historical query. Recognizing that some apparent duplication is really temporal versioning is a strong depth signal, and it's the distinction most candidates miss.

- ❌ **Trap:** "Embed the child records — it makes the read one fetch."
  ✅ **Reality:** Only when the child collection is **bounded**. Order → line items is bounded and embeds well. User → posts is unbounded: the document grows until it hits the engine's item-size ceiling (400KB in DynamoDB, 16MB in MongoDB) and writes begin failing outright, and long before that every small update is rewriting the entire document. The bounded-children rule is what separates a correct embed from a time bomb.

### ✅ Checkpoint — adversarial stress test

1. You've denormalized `customer_name` onto `orders` and you're maintaining it with a CDC stream. The interviewer says: *"Your CDC pipeline is down for six hours during a customer-name migration, then recovers and replays events out of order. Some orders now show names that were never current. Walk me through how you detect this, how you repair it, and what you'd have designed differently so this class of bug can't silently persist."*

   > 💡 *This is the gate. A complete answer covers: why last-write-wins on the copy is insufficient when events are reordered, the role of a version or timestamp on the source row, how the reconciliation sweeper recomputes from the source of truth rather than from the stream, and the honest observation that if this data could not tolerate any staleness it should never have been denormalized. If you can't answer this cleanly, you are not done.*

MODEL ANSWER — §7 Adversarial Stress Test

DETECT — two signals, because the hazard is ABSENCE, not error
  BEFORE  Pipeline health: consumer lag against the log + heartbeat.
          Alert on ABSENCE OF PROGRESS, not presence of an error —
          a dead connector emits no error, it just stops. A 6-hour
          outage must page immediately.
  AFTER   Data health: stamp each copy with the source version it
          was derived from (orders.customer_name_synced_version —
          NOT the order's own updated_at, which changes for
          unrelated reasons). Sample continuously for
          copy_version < source_version. Emit drift count as a
          METRIC and alert on it — a sweeper that silently repairs
          40k rows nightly is a broken pipeline nobody knows about.

REPAIR
  Reconciliation sweeper that RECOMPUTES from the source of truth —
  never by replaying the stream, because the stream is what failed.
  Throttled, off-peak, isolated from live traffic.

REDESIGN — so it can't silently persist
  1. MONOTONIC VERSION GUARD. Conditional write: reject any event
     whose version is older than the copy's. Kills "names that were
     never current" outright, and makes the sync path IDEMPOTENT
     and ORDER-INSENSITIVE — replays and duplicates become no-ops.
  2. DRIFT AS A FIRST-CLASS METRIC, not a silent repair.
  3. DON'T DENORMALIZE AT ALL if the field cannot tolerate
     staleness. CDC's floor is seconds, not zero. Cost arguments
     say "not worth it"; the staleness argument says "impossible."

THE THROUGH-LINE
  Denormalized column fails silently — no miss.
  Dead pipeline fails silently — no error.
  Both hazards are the ABSENCE of a signal. Design for absence.

> **→ Next:** Can you combine what you've learned across sections, not just recall each one?

---

## 8. 🧪 Mastery Gate

> *Synthesis only. Each question requires combining two or more sections.*

1. **(§3 + §5 + §6)** A social app stores `follower_count` on the user row. Explain why this is a denormalization, which anomaly class from §3 it reintroduces, the specific failure mode it creates under load from §5, and the decision signals from §6 that nonetheless make it the right call.

2. **(§4 + §7 + 8.1)** A team is porting a 3NF Postgres schema to DynamoDB and plans to keep the table structure identical, resolving foreign keys in application code. Explain what will go wrong, connect it to the N+1 problem (8.8), and describe the modeling process they should follow instead.

3. **(§5 + §6, applied to a novel system)** Design the data model for a hotel booking system's "my reservations" page, which shows the hotel name, room type, nightly rate, and guest name for each booking. Decide for each field whether it is normalized, denormalized, or a point-in-time snapshot — and justify each choice separately. At least one field should fall into each of the three categories.

### Mastery criteria — tick only what you can demonstrate on demand

- [ ] Can state the functional-dependency rule and use it to place any given attribute in the correct table
- [ ] Can identify 1NF, 2NF, and 3NF violations in an unfamiliar schema and name the specific anomaly each one permits
- [ ] Can explain why application-level discipline cannot substitute for structural normalization, giving all three reasons
- [ ] Can name at least four denormalization patterns and the access pattern each one serves
- [ ] Can explain why denormalization is sometimes necessary and state its trade-offs, always naming the source of truth and the sync mechanism
- [ ] Can design a schema for a novel use case with appropriate primary keys, foreign keys, indexes, and justified denormalization
- [ ] Can distinguish a performance denormalization from a point-in-time snapshot and explain why the latter is a correctness requirement

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 9. 🔗 Connections & Sources

**Builds on:** **8.1 SQL vs. NoSQL** — the store's join capability is one of the four decision signals, and it can be decisive on its own, since a store with no join operator forces access-pattern-first modeling regardless of what the data would ideally look like. Also **8.2 OLTP vs. OLAP**, which established that the star schema is a deliberate denormalization justified by scan-shaped workloads.

**Enables:** **8.4 Indexing** — a normalized schema's read cost is largely a question of whether the join columns are properly indexed, so index design is the direct follow-on. Also **8.8 N+1 query problem**, which is what over-normalization looks like in a store that can't join; **7.7 Cross-shard queries**, since shard-crossing joins are the strongest structural argument for denormalizing; and **24.1–24.3 Fan-out**, which is this subtopic's most aggressive pattern applied at social-network scale.

**Tension with:** **8.6 ACID transactions** — transactional fan-out is the strongest sync mechanism but caps you at a single database or shard, so scaling denormalization means giving up the atomicity that made it safe. Also with **Topic 5 Caching**, in a revealing way: a denormalized column is a cache with no miss path, so unlike a real cache it never self-corrects from the source of truth and instead requires an explicit reconciliation pass.

### 📚 Further reading

- [ ] **Designing Data-Intensive Applications, Chapter 2 — Data Models and Query Languages** — Kleppmann — normalization, the document/relational split, and why join support drives modeling
- [ ] **"The Relational Model of Data for Large Shared Data Banks"** — E.F. Codd (1970) — https://www.seas.upenn.edu/~zives/03f/cis550/codd.pdf — the original anomaly argument; skim §1 for the reasoning, not the algebra
- [ ] **AWS — "Single-table design with DynamoDB"** — https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-general-nosql-design.html — access-pattern-first modeling in a store with no joins
- [ ] **Instagram Engineering — "Sharding & IDs at Instagram"** — https://instagram-engineering.com/sharding-ids-at-instagram-1cf5a71e5a5c — a real normalized-then-sharded schema and what shard boundaries did to it
- [ ] **Martin Fowler — "Aggregate" and "CQRS"** — https://martinfowler.com/bliki/CQRS.html — the read-model-vs-write-model framing, which is denormalization taken to its architectural conclusion

---

## 10. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
