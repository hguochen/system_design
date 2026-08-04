# 8.5 Query Patterns and Optimization

> **Topic:** Topic 8 — Database Fundamentals
> **Phase:** C — Data Storage Branch
> **Depth Tier:** 🥈 T2 (Depth) — budget ~1h
> **Prereqs:** 8.4 (Indexing — B-tree, LSM-tree, Composite Indexes), 8.1 (SQL vs. NoSQL)
> **Date studied:** _____

> 🥈 **T2 means:** this is a follow-up probe, not a core design decision. You need
> to explain it confidently and name its trade-off — you do not need to design
> a system around it from scratch.

---

## 0. 🧭 The Question This Answers

8.4 settled which index structures to build for the queries on your hot path. This subtopic asks the question that decides whether that investment actually pays off: given the right index exists, how do you know your query is using it — and what specific things about how a query is *written*, not how the table is indexed, silently stop that from happening? A perfectly indexed table can still run a full scan on every request because of one function wrapped around a column, or grind to a crawl on page 400 because of how pagination was written.

The tension is that the query planner is a cost-based optimizer placing a bet from statistics, not a guarantee of the fastest plan. You cannot reason about query speed by staring at the schema — you have to read the plan the engine actually chose, compare it to what you expected, and know which specific patterns in the SQL itself defeat an otherwise-correct index.

**The question:** *Given the right indexes exist, how do you verify — and shape — a query so the planner can actually use them?*

> **→ Next:** Before learning to read a plan, what happens when nobody reads one at all — what silently goes wrong?

---

## 1. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds.*
>
> ⏭️ **First time through?** Skip to §2 and come back here for revision.

```
§ 1  WHY IT EXISTS
An index only helps if the planner can prove, from the query's own text,
that it narrows the search — and several everyday ways of writing SQL
make that proof impossible even when the perfect index already exists.
Wrapping an indexed column in a function, comparing across a type
mismatch, or asking for every column when only three are needed all
silently fall back to a scan or a partial win. The planner does not
warn you; it just picks the best plan it can prove, which after 8.4's
work is often still a scan. Reading the actual plan is the only way
to know which case you're in.

§ 2  WHAT IT IS
QUERY PLAN      The concrete sequence of access paths (scan, index
                scan, join algorithm, sort) the engine will execute,
                chosen by comparing ESTIMATED cost across the options.
SARGABLE        Search ARGument ABLE — a predicate written so the
                planner can seek directly on an index, rather than
                reading every row and testing it. "Sargable" is a
                property of the predicate's TEXT, not the schema.
EXPLAIN         Shows the chosen plan and its ESTIMATED cost/rows —
                a prediction, made before execution.
EXPLAIN ANALYZE Actually runs the query and adds ACTUAL rows/timing
                next to the estimate. The gap between the two is the
                single most useful number in query tuning.
KEYSET          Seeking past the last-seen key with a WHERE clause,
PAGINATION      instead of counting past N rows with OFFSET.

§ 3  THE MECHANISM
COST ESTIMATION  For each candidate plan the planner estimates cost
                 from table/column statistics — row counts, distinct
                 values, a value histogram — updated by ANALYZE
                 (autovacuum runs it, but lags after bulk loads and
                 large deletes).
PLAN SELECTION   Lowest estimated total cost wins. This is a BET: if
                 statistics are stale or the value you pass in is
                 unusually common, the estimate is wrong and the
                 chosen plan is wrong, even though nothing about the
                 SQL or the indexes changed.
NO MID-QUERY     Once chosen, the plan runs to completion. If actual
REPLAN           rows diverge wildly from the estimate mid-execution,
                 the engine does not notice and switch plans.
SARGABILITY      The planner can only use an index's sort order to
CHECK            SEEK if the predicate is a direct comparison on the
                 raw column. A function call, an implicit cast, or a
                 leading wildcard hides the column from the index,
                 forcing a scan even with a perfect index present.

§ 4  USE / AVOID
READ THE PLAN when: a query is slow, before touching the schema —
  most "we need an index" conversations are actually "we need to
  read EXPLAIN ANALYZE" conversations.
REWRITE THE PREDICATE when: EXPLAIN shows a scan on an indexed
  column — check for a wrapped function, an implicit cast, a leading
  wildcard, or an OR across unindexed columns first.
SWITCH TO KEYSET PAGINATION when: users page deep into a large,
  frequently-inserted result set (feeds, search results, exports).
AVOID trusting the schema alone — an index existing tells you
  nothing about whether any query actually uses it; only the plan
  does.

§ 5  SARGABILITY RULES (what silently defeats a seek)
WRAPPED COLUMN     WHERE lower(email) = ?    → scan. Fix: expression
                   index on lower(email), or store normalized.
IMPLICIT CAST      WHERE varchar_col = 123   → scan. The engine may
                   cast the COLUMN, not the literal, discarding its
                   own index.
LEADING WILDCARD   WHERE name LIKE '%foo'    → scan. A trailing
                   wildcard ('foo%') can still seek; a leading one
                   cannot, because sort order is on the first char.
OR ACROSS COLUMNS  WHERE a = ? OR b = ?      → often a scan unless
                   the engine chooses a bitmap OR of two separate
                   index scans — verify in the plan, don't assume.
OFFSET AT DEPTH    OFFSET 100000 LIMIT 20    → the engine still
                   walks and discards 100,000 rows first. Cost
                   grows linearly with page depth regardless of
                   indexing.

§ 6  NUMBERS TO ANCHOR THE DISCUSSION
EXPLAIN vs EXPLAIN ANALYZE: estimated-vs-actual row count off by
  more than ~10x is the rule-of-thumb trigger to suspect stale
  statistics or a skewed value, not a schema problem.
OFFSET pagination cost is O(offset + limit) — page 1 and page 5,000
  read a near-identical number of rows before the LIMIT kicks in.
KEYSET pagination cost is O(log n) — a single index seek, flat
  regardless of how deep the page is.
SELECT * on a covering index silently defeats the cover: the index
  contains the WHERE/ORDER BY columns, but the engine still fetches
  the row for every column not present in the index.

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "This query got slow as the table grew"     → EXPLAIN ANALYZE
                                                  first, not a new
                                                  index
→ "The index exists but isn't being used"     → check sargability:
                                                  wrapped column,
                                                  cast, wildcard
→ "How do you paginate a 50M-row feed?"        → keyset, not OFFSET
→ "p50 is fine but p99 spikes under load"      → skewed-value /
                                                  stale-stats bet
                                                  gone wrong
GOTCHA: Reaching for "add an index" as the first move, before
  reading a plan. Half of query-tuning interview problems are
  solved by discovering the right index already exists and the
  query just isn't sargable — proposing a redundant index instead
  reads as pattern-matching, not diagnosis.
```

---

## 2. 🧠 The Mindmap

> *The picture to hold in your head while you study.*

```
                    ┌──────────────────────────────────┐
                    │   QUERY PATTERNS & OPTIMIZATION   │
                    │  "is the index actually used?"    │
                    └──────────────────┬─────────────────┘
                                       │
       ┌───────────────┬───────────────┼───────────────┬───────────────┐
       ▼               ▼               ▼               ▼               ▼
 READING THE      SARGABILITY      FETCH SHAPE     PAGINATION      STATISTICS
 PLAN
 ├ EXPLAIN        ├ wrapped col    ├ SELECT * vs   ├ OFFSET =      ├ ANALYZE /
 │  (estimate)    │  / function    │  covering      │  O(n) walk    │  autovacuum
 ├ EXPLAIN        ├ implicit cast  ├ correlated     ├ keyset =      ├ histogram,
 │  ANALYZE       ├ leading        │  subquery →    │  O(log n)     │  distinct
 │  (actual)      │  wildcard      │  N+1 shape     │  seek         │  count
 ├ estimated vs   ├ OR across      ├ batching /     ├ stable sort   ├ stale after
 │  actual gap    │  columns       │  joins > loops │  key needed   │  bulk load
 └ no mid-query   └ text property, └ volume, not    └ loses "jump   └ feeds the
   replan           not schema       sargability      to page N"      planner's bet
```

**How to read it:** **reading the plan** is the entry point — everything else is a hypothesis about *why* the plan looks wrong. **Sargability** and **fetch shape** are the two textual failure modes that defeat an index that already exists; **pagination** is fetch shape's most common production instance; and **statistics** are what the planner's bet is made from, so a wrong bet often traces back here rather than to the query text at all.

---

## 3. 🔥 The Problem

8.4 leaves you with the right indexes on the table. It says nothing about whether any given query can actually reach them, and that gap is where a large share of "the database is slow" incidents actually live.

The naive assumption is that once an index exists, every query touching that column is automatically fast. In practice the planner can only use an index's sort order if it can prove — from the literal text of the predicate — that the values it's looking for are a contiguous slice of that order. Wrap the column in a function (`lower(email)`), compare it against a value of a mismatched type, or search for a pattern that starts with a wildcard, and that proof becomes impossible: the planner falls back to reading and testing every row, on a table that has a perfectly good index sitting unused right next to the column.

The instinctive fix, when a query is slow, is to add another index. This frequently doesn't help and sometimes can't help, because the problem was never the absence of an index — it was that the query, as written, hid the column from the one that already exists. Diagnosing which case you're in requires reading what the engine actually decided to do, not guessing from the schema. That structure — a plan, chosen by estimate, checkable after the fact — is what the rest of this subtopic is built around.

### ✅ Checkpoint

1. Why does adding a second index often fail to fix a slow query when the first index already covers the filtered column? Name the mechanism, not just "it's still slow."

   > 💡 *If you hesitate, re-read the paragraph on wrapping / hiding a column from an index.*

> **→ Next:** If the fix isn't always a new index, what's the actual chain of ideas you need to diagnose and shape a query correctly?

---

## 4. 💡 The Core Idea

**Query optimization is the discipline of shaping SQL so the cost-based planner can prove — from the predicate's literal text and the query's fetch shape — that an existing index narrows the work, and of reading the plan it actually chose to verify that proof succeeded.**

**Visual required:** build-chain diagram.

```
 [PLAN IS A BET] ──▶ [SARGABILITY] ──▶ [FETCH SHAPE] ──▶ [KEYSET PAGINATION]
    because the         therefore the       which means a        so the fetch-shape
    planner estimates    predicate's text    sargable query        problem at the
    from statistics,     decides if it       can still drag        page boundary
    not certainty         can even seek       back too much         gets its own fix
```

### The Plan Is a Bet, Not a Guarantee

Every query the planner receives is compiled into several *candidate* plans — scan this table or that index, join with a nested loop or a hash — and each candidate is assigned an estimated cost computed from table statistics: row counts, distinct-value counts, and a histogram of the column's value distribution. The planner picks whichever candidate has the lowest estimated total cost and executes it, without re-checking mid-flight whether the estimate held. `EXPLAIN` shows that choice and its estimate before running anything; `EXPLAIN ANALYZE` actually executes the query and reports the real row counts and timing next to the estimate. The single most useful number in query tuning is the gap between those two — a big divergence means the bet was wrong, usually because statistics are stale or the specific value you searched for is unusually common.

### Sargability — hiding the column from the index

That bet can only be a good one if the predicate is written so the planner can *seek* on an index's sort order in the first place — a property called sargability (search-argument-ability). Wrap an indexed column in a function (`WHERE lower(email) = ?`), compare it against a literal of a mismatched type (forcing an implicit cast the engine applies to the column, not the value), or search for a pattern that begins with a wildcard (`LIKE '%foo'`), and the planner can no longer prove where in the sorted index those values would live — it falls back to reading and testing every row, on a table where the index was built correctly and simply cannot be reached from that SQL. This is the single most common reason "the index exists but isn't used," and it's invisible from the schema; it only shows up in the plan.

### Fetch Shape — sargable but still wasteful

A sargable predicate gets you to the right rows; it says nothing about how much you drag back once you're there. `SELECT *` on a table with a narrow covering index defeats the cover, because the engine has to fetch every column not present in the index for every matching row — the seek was cheap, the fetch wasn't. A correlated subquery re-executed once per outer row is the same shape as issuing N separate queries from application code (the N+1 pattern, 8.8), and usually rewrites cleanly into a single join or a window function. Neither of these is a sargability problem — the index is being used correctly — they're a *volume* problem: pulling back more data, or making more round trips, than the query actually needs.

### Keyset Pagination — fetch shape at the page boundary

The most common production instance of the fetch-shape problem is pagination, and it's worth naming on its own because the fix looks almost nothing like the problem. `OFFSET 100000 LIMIT 20` still requires the engine to walk and discard the first 100,000 matching rows before it can return the next 20 — cost grows linearly with page depth no matter how good the index is, because `OFFSET` is a row-count instruction, not a value to seek on. Keyset pagination replaces it with a `WHERE` clause that seeks directly past the last row the client already saw (`WHERE created_at < :last_seen ORDER BY created_at DESC LIMIT 20`), turning a linear walk into the same O(log n) index seek every other sargable query gets — at the cost of losing the ability to jump to an arbitrary page number, since there's no longer a row count to offset from.

### ✅ Checkpoint

1. A query uses `WHERE DATE(created_at) = '2026-08-03'` against a table with a B-tree index on `created_at`. Explain precisely why the index isn't used, and state a fix that keeps the predicate sargable.

   > 💡 *If you hesitate, re-read the Sargability paragraph — the wrapped-column rule.*

> **→ Next:** You know the ideas. What physically happens when the planner builds and executes a plan — and where does the bet actually go wrong?

---

## 5. ⚙️ How It Actually Works

**Happy path — reading a plan end to end:**

1. The client sends the SQL text to the planner.
2. The planner enumerates the physically possible access paths for each referenced table (sequential scan, each candidate index, each join algorithm) and estimates the cost of each from current statistics.
3. It picks the single cheapest overall plan — not necessarily the plan a human would guess — and hands it to the executor.
4. `EXPLAIN` alone prints this chosen plan and its estimated cost/row count without running anything.
5. `EXPLAIN ANALYZE` additionally executes the query and annotates each node with the real row count and time, so estimated and actual sit side by side.
6. You read the plan node by node, comparing "Seq Scan" vs. "Index Scan" vs. "Index Only Scan" against what you expected, and comparing estimated vs. actual rows at each node to find where the bet diverged.

> 🗺️ **Mental model — the GPS route estimate.** `EXPLAIN` is the route and ETA a GPS gives you before you drive; `EXPLAIN ANALYZE` is the same route with the actual time you took at each turn stapled on afterward. *Where it breaks down:* a GPS replans mid-drive the moment real traffic diverges from its estimate. The query planner does not — once it commits to a plan, it drives that exact route to the end even if the very first turn reveals the estimate was wrong by three orders of magnitude.

**Failure & edge cases:**

- **Stale statistics.** After a bulk load or large delete, `ANALYZE` hasn't run yet (autovacuum lags), so the planner's row estimates are wrong and it picks a plan sized for a table that no longer exists.
- **Skewed value distribution.** A query parameterized on a column where one value is far more common than the rest (`status = 'pending'` vs. `status = 'archived'`) gets one plan chosen for the "typical" value and applied to every value, so common values perform fine and rare ones (or vice versa) perform badly — this is the p50-fine, p99-bad shape.
- **Index scan chosen but still slow.** An index scan on a low-correlation column still does one random row fetch per matching row (8.4's clustering argument) — "the index is being used" is not the same as "the index is helping."
- **OFFSET pagination silently degrading.** As the dataset grows and users page deeper, latency climbs with no error, no warning, and no change to the query — it looks fine in development with a few hundred rows.

**Estimated vs. actual — reading the divergence:**

```
EXPLAIN ANALYZE  SELECT * FROM orders
                 WHERE customer_id = 42 AND status = 'archived';

 Index Scan using idx_customer_status on orders
   Index Cond: (customer_id = 42 AND status = 'archived')
   Planned rows: 4          ← ESTIMATE, from stored statistics
   Actual rows: 118,402     ← REALITY, for THIS parameter value
   Actual time: 0.03..812.4 ms
                    ▲
                    └── ~29,600x off. Statistics say this value is
                        rare; for this customer it isn't. The plan
                        chosen for "rare" is wrong for "common" —
                        same query, same index, different parameter.
```

**The plan pipeline, end to end:**

```
① SQL text ──▶ ② enumerate access ──▶ ③ estimate cost ──▶ ④ pick cheapest
                paths per table         from statistics        plan
                                                                   │
                                                                   ▼
                                                         ⑤ EXPLAIN (prediction)
                                                                   │
                                                                   ▼
                                                  ⑥ EXPLAIN ANALYZE (execute +
                                                     compare estimated vs actual)
```

### ✅ Checkpoint

1. An `EXPLAIN ANALYZE` shows an Index Scan is being used, and the estimated row count matches the actual almost exactly — yet the query is still slow. What have you not yet ruled out?

   > 💡 *If you hesitate, re-read the "index scan chosen but still slow" failure case, and reconsider what "index is being used" does and doesn't tell you (cross-reference 8.4's clustering argument).*

> **→ Next:** You can diagnose the plan. In a live design or debugging session, what do you actually change — and what does each fix cost?

---

## 6. ⚖️ The Decision — When, and What It Costs

The default is **read the plan before touching the schema**. Four situations decide what to actually change. If `EXPLAIN ANALYZE` shows a sequential scan on a column you expected to be indexed, check the predicate's sargability before assuming the index is missing — a wrapped function, an implicit cast, or a leading wildcard produces the exact same symptom as no index at all. If estimated and actual row counts diverge by an order of magnitude or more, suspect stale statistics (run `ANALYZE`) or a skewed parameter distribution, not the query's structure. If the query is provably sargable and still slow, check its fetch shape: `SELECT *` defeating a covering index, a correlated subquery running once per outer row, or `OFFSET` pagination at depth. Only once all three are ruled out does a new or modified index (8.4) become the right move.

**Decision tree:**

```
                Query is slow — what do you check first?
                                │
                        EXPLAIN ANALYZE it.
                                │
              ┌─────────────────┴──────────────────┐
              ▼                                     ▼
    Seq Scan where you expected              Index Scan is used,
    an index                                  but still slow
              │                                     │
     Is the predicate sargable?           Estimated ≈ actual rows?
     (no wrapped col / cast / wildcard)               │
       ┌──no──┴──yes──┐                  ┌──no────────┴────────yes──┐
       ▼               ▼                  ▼                          ▼
  REWRITE THE      Index truly       ANALYZE the table /      Check fetch shape:
  PREDICATE.       missing — build   suspect a skewed          SELECT *, correlated
  Expression        one (8.4).       parameter — the BET,      subquery, or OFFSET
  index or                           not the query, was        at depth.
  normalized                         wrong.
  storage.
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Keyset pagination: O(log n) at any page depth** — a single index seek, flat cost regardless of how deep the page is | Can't jump to an arbitrary page number; needs a stable, indexed sort key with deterministic tie-breaking |
| **Expression index for a wrapped predicate** (e.g., `lower(email)`) — restores sargability without touching application code | Only serves that exact expression; a different function on the same column needs its own index |
| **Reading `EXPLAIN ANALYZE` before changing the schema** — diagnoses the real cause instead of guessing | Costs a few minutes per query and needs production-representative data — `EXPLAIN` on a dev table with 200 rows tells you very little |
| **Rewriting a correlated subquery as a join or window function** — one query instead of N | Can subtly change result semantics (e.g., row multiplication on a join) and needs re-verification |

### In production

| System | How it applies | The nuance |
|--------|----------------|------------|
| **PostgreSQL** | `EXPLAIN (ANALYZE, BUFFERS)` — `BUFFERS` shows actual page hits, isolating whether time went to CPU or I/O | `auto_explain` can log plans for queries exceeding a threshold in production, without needing to reproduce the slow query by hand |
| **MySQL / InnoDB** | `EXPLAIN ANALYZE` (8.0.18+) adds actual timing; the slow query log flags candidates first | `optimizer_trace` goes further, showing *rejected* plans and why — useful when the chosen plan looks wrong but you can't tell what else was considered |
| **Stripe / GitHub / Shopify APIs** | Cursor-based (keyset) pagination is the default for list endpoints over large, growing collections | The cursor is typically an opaque encoded value, not a raw row ID, specifically so clients can't reconstruct `OFFSET`-style jumping the API is trying to avoid |
| **SQL Server** | Parameter sniffing is named and tunable explicitly: the first execution's parameter shapes the cached plan for all future ones | `OPTION (RECOMPILE)` forces a fresh plan per execution — a direct, named answer to the skewed-value failure case in §5 |

### ✅ Checkpoint

1. A team paginates a public API with `OFFSET`/`LIMIT` and observes p99 latency growing linearly with how many pages a client has already fetched, even though every page returns the same 20 rows. Diagnose it and name the fix, including what the client-facing API contract has to give up.

   > 💡 *If you hesitate, re-read the pagination cost numbers in §1 and the keyset pagination concept block in §4.*

> **→ Next:** Can you defend this under interview pressure — and hold up when the interviewer pushes past the first fix?

---

## 7. 🎯 In the Interview

**When an interviewer asks / says:**
- "This query got slow as the table grew — what would you check?"
- "We have an index on this column but the query is still doing a full scan. Why?"
- "How would you design pagination for an endpoint returning millions of rows?"
- "p50 for this endpoint looks fine, but p99 is terrible under load."

**What you say / do:**
This resurfaces immediately after indexing (8.4) in the schema/data-model phase, and again in the deep dive the moment the interviewer pressure-tests a specific endpoint. Lead with the diagnostic step, not a fix — "I'd pull `EXPLAIN ANALYZE` before touching the schema" — then name the specific pattern you'd look for (sargability, fetch shape, or stale statistics) and only then propose a change.

**The trade-off statement:**
> "I wouldn't add an index without first reading `EXPLAIN ANALYZE` on this query — 'it's slow' could mean the index doesn't exist, or it could mean the predicate isn't sargable and the index we already have can't be reached. If it's a wrapped-column predicate, I'd fix the SQL or add an expression index rather than duplicating the column. And if this is a paginated endpoint, I'd check whether it's using `OFFSET` — because that degrades linearly with page depth regardless of indexing — and switch it to keyset pagination on a stable sort key, at the cost of the client no longer being able to jump to an arbitrary page number."

### ⚠️ Traps

- ❌ **Trap:** "The index exists, so the query should be fast."
  ✅ **Reality:** An index only helps if the predicate is sargable; wrapping the column in a function or comparing across a type mismatch hides it from the index just as completely as if the index didn't exist — the schema tells you nothing, only the plan does.

- ❌ **Trap:** "OFFSET/LIMIT is a fine way to paginate."
  ✅ **Reality:** Cost grows linearly with how deep the page is, because the engine must still walk and discard every prior row. It's invisible in development with a few hundred rows and becomes a production incident specifically once the table and the user base both grow — exactly when it's hardest to change.

- ❌ **Trap:** "The plan shows Index Scan, so performance here is a solved question."
  ✅ **Reality:** "Index is being used" only tells you the seek is cheap; it says nothing about how many rows the query then fetches per match (`SELECT *` defeating a cover) or whether the parameter you passed is wildly more common than the statistics assume.

- ❌ **Trap:** "If it's slow, add another index."
  ✅ **Reality:** The most common outcome in a live debugging exercise is discovering the right index already exists — proposing a new one first reads as pattern-matching rather than diagnosis, and it adds a permanent write-path tax (8.4) for a problem an index was never going to fix.

### ✅ Checkpoint — adversarial stress test

1. Your team ships a fix: an expression index on `lower(email)`, and the slow query is now fast in staging. In production, p99 for the same endpoint doesn't move. `EXPLAIN ANALYZE` in production shows the new index is being used and the estimated row count matches actual almost exactly. Walk me through what else could still be wrong, and how you'd find it without guessing.

   > 💡 *This is the gate. A complete answer covers: fetch shape orthogonal to sargability (`SELECT *` / N+1 / `OFFSET` on the same endpoint), the possibility that staging data doesn't reproduce production's value distribution, and the honest fallback of profiling at the application/network layer (connection pool exhaustion, N calls to this now-fast query, serialization cost) once the query itself is confirmed cheap — because a fast query behind a slow endpoint is a different bug entirely. If you can't answer this cleanly, you are not done.*

---

## 8. 🔗 Connections & Sources

**Builds on:** **8.4 Indexing** — sargability is literally about whether a query's predicate matches the sort order an index provides, so this subtopic is unusable without 8.4's B-tree/composite index model. Also **8.1 SQL vs. NoSQL** — the idea of a cost-based planner choosing between access paths is a SQL-engine concept; most NoSQL stores from 8.1 have no equivalent, and the parallel discipline there is choosing the right partition/sort key up front rather than tuning a query after the fact.

**Enables:** **8.8 N+1 query problem**, which is fetch shape's most common production instance in ORMs — the correlated-subquery pattern named here, seen from the application-code side. Also the keyset pagination pattern reused directly in API design for large list endpoints.

**Tension with:** **8.2 OLTP vs. OLAP** — this subtopic's instinct ("avoid the scan, seek instead") is an OLTP instinct. OLAP engines deliberately scan large fractions of a columnar table because the workload is aggregation, and forcing point-lookup thinking onto an analytical query is itself a mistake there.

### 📚 Further reading

- [ ] **"Use The Index, Luke"** — Markus Winand — https://use-the-index-luke.com/ — the canonical deep reference on sargability and index-based query tuning, works across SQL engines
- [ ] **PostgreSQL docs — "Using EXPLAIN"** — https://www.postgresql.org/docs/current/using-explain.html — official reference for reading plan output and `BUFFERS`
- [ ] **PostgreSQL docs — "Planner Statistics"** — https://www.postgresql.org/docs/current/planner-stats.html — how `ANALYZE` builds the histograms the planner bets on
- [ ] **"Use The Index, Luke" — "Pagination Done the Right Way"** — https://use-the-index-luke.com/no-offset — the OFFSET-vs-keyset argument in depth, with concrete SQL
- [ ] **Slack / Shopify / GitHub Engineering blogs — keyset/cursor pagination** — search each engineering blog for "cursor pagination" — real production cursor design at scale

---

## 9. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
