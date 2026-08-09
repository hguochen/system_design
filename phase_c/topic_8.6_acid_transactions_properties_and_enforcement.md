# 8.6 ACID Transactions — Properties and Enforcement

> **Topic:** Topic 8 — Database Fundamentals
> **Phase:** C — Data Storage Branch
> **Depth Tier:** 🥇 T1 (Core) — budget ~1.75h
> **Prereqs:** 8.1 (SQL vs. NoSQL), 8.3 (Data modeling — normalization and denormalization)
> **Date studied:** 2026-08-06

---

## 0. 🧭 The Question This Answers

8.1 chose the engine and 8.3 decided where each fact physically lives — and along the way named "transactional fan-out" as the strongest mechanism for keeping duplicated copies in sync. This subtopic asks what that word "transactional" is actually promising. ACID is not one property. It is four independent guarantees — atomicity, consistency, isolation, durability — bundled under one acronym and sold as a single feature, but each one fails in a completely different way, and each one is enforced by a different piece of machinery inside the engine.

The central tension is that every one of the four guarantees costs something specific — a lock held, a log fsynced, a coordinator blocked — and a system that claims "it's transactional" without naming an isolation level, and without saying what happens the moment the transaction crosses a shard boundary, hasn't actually told you what it guarantees.

**The question:** *What exactly breaks — concretely, one failure at a time — when each of the four ACID properties is missing, and what mechanism inside the database is responsible for making sure it isn't?*

> **→ Next:** Before we can name what protects you, we need to see what an unprotected concurrent write path actually does wrong. What breaks?

---

## 1. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*
>
> ⏭️ **First time through this topic?** Skip to §2 and come back here for revision.

```
§ 1  WHY IT EXISTS
Two writes that are supposed to happen together are, to the database, two
unrelated events unless you tell it otherwise. Run "debit A" then "credit B"
as separate statements and any of three things can happen: the process
crashes between them and money vanishes; a concurrent reader sees the
half-done state and reports a balance that was never true; two concurrent
writers each read a stale balance and one silently overwrites the other's
update. None of this is a bug in the storage engine — it's the absence of a
primitive that says "these N writes are one indivisible, isolated, durable
event." That primitive is the transaction, and ACID is the specification of
what it actually guarantees.

§ 2  WHAT IT IS — the four letters, independently
ATOMICITY    All the writes in the transaction commit, or none do. No
             partial application, ever — even across a crash mid-write.
CONSISTENCY  The transaction moves the database from one state that
             satisfies its declared invariants (constraints, foreign keys)
             to another. This is the weakest, most misunderstood letter —
             it's the DB enforcing YOUR rules, not inventing correctness.
ISOLATION    Concurrent transactions cannot observe each other's
             in-flight, uncommitted state. The ideal is SERIALIZABLE: it
             behaves as if every transaction ran alone, one after another,
             even though the engine actually interleaves them.
DURABILITY   Once the client is told "committed," that result survives any
             subsequent crash — power loss one millisecond later must not
             lose it.

§ 3  THE MECHANISM — two subsystems deliver four guarantees
WRITE-AHEAD LOG (WAL)   Every change is appended to a sequential, durable
                        log BEFORE the data page is touched. Atomicity and
                        durability both come from this: on crash, replay
                        the log — redo anything with a commit record, undo
                        anything without one.
CONCURRENCY CONTROL     Delivers isolation. Two families:
  LOCKING (2PL)  acquire a lock per row touched, block or abort on
                 conflict, release at commit. Correct, but writers can
                 block writers and deadlock.
  MVCC           each transaction reads a private snapshot; writers never
                 block readers. Cheap, but the isolation you actually get
                 depends on how conflicts are checked at commit time.
CONSTRAINTS             Delivers consistency — CHECK, FOREIGN KEY, UNIQUE.
                        The engine rejects (aborts) a transaction that
                        would violate one; it does not know your invariant
                        unless you declared it.

§ 4  USE / AVOID
USE a full ACID transaction when: multiple rows or tables must change
  together and a half-done state would corrupt an invariant (money,
  inventory, identity).
USE the weakest isolation level that still prevents the specific anomaly
  you care about — Serializable is correct everywhere but is not free.
AVOID assuming "wrapped in a transaction" says anything without naming the
  isolation level — default isolation differs by engine and each level
  permits different, specific anomalies.
AVOID assuming a transaction spans shards for free — single-node atomicity
  does not cross a partition boundary without an explicit protocol
  (two-phase commit) or an explicit compensating design (saga).

§ 5  ISOLATION LEVELS — named trade-offs, not just names
READ COMMITTED     Never reads uncommitted data. Still allows
                    non-repeatable reads (re-run the same query, get a
                    different answer) and phantom reads.
REPEATABLE READ /
SNAPSHOT            Your transaction sees one consistent snapshot for its
                    whole duration. Prevents non-repeatable reads. Still
                    allows WRITE SKEW — two transactions each read
                    overlapping data, each individually looks valid, the
                    combined effect violates an invariant neither checked.
SERIALIZABLE        Behaves as if transactions ran one at a time. Prevents
                    write skew too. Costs the most — either heavy locking
                    or serialization failures that the client must retry.

§ 6  NUMBERS TO ANCHOR THE DISCUSSION
Durability is only as strong as the fsync. An engine that reports
  "committed" before the log is actually flushed to durable media can lose
  the last stretch of "committed" work on power loss — this is a real,
  documented class of misconfiguration, not a hypothetical.
Two-phase commit costs at least 2 network round trips (prepare, commit) and
  blocks every participant if the coordinator dies after prepare — the
  classic 2PC blocking problem.
Postgres and SQL Server default to READ COMMITTED; MySQL InnoDB defaults to
  REPEATABLE READ. Three major engines, three different default anomaly
  profiles, out of the box.
DynamoDB transactions cap at 25 items / 4MB and cost roughly 2x the
  read/write capacity of the equivalent non-transactional operation.

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "What happens if the DB crashes mid-write?"        → atomicity + WAL redo/undo
→ "How do you stop two requests from double-        → isolation, name the level
   booking / overselling?"                             and the specific anomaly
→ "What isolation level would you use here?"         → never just "a transaction"
→ "This transaction spans two shards"                → single-node ACID doesn't
                                                         cross a partition for free
GOTCHA: Saying "I'd wrap it in a transaction" without naming an isolation
  level is the single most common depth failure here. It says nothing,
  because the default isolation level differs by engine and each level
  permits a distinct, nameable anomaly. The interviewer wants to hear which
  anomaly you're preventing and what it costs to prevent it.
```

---

## 2. 🧠 The Mindmap

> *The picture to hold in your head while you study. Everything below hangs off this.*

```
                            ┌──────────────────────────────┐
                            │   ACID = FOUR PROMISES,      │
                            │   ENFORCED BY TWO SUBSYSTEMS │
                            └───────────────┬──────────────┘
                                            │
    ┌───────────────┬───────────────┬───────┴───────┬───────────────┬──────────────┐
    ▼               ▼               ▼               ▼               ▼              ▼
 THE FOUR       WHAT BREAKS     ENFORCEMENT     ISOLATION       THE DECISION   REAL SYSTEMS
 PROPERTIES     (one per        MECHANISMS      LEVELS          (when + cost)
                letter)
 ├ Atomicity    ├ crash mid-    ├ WAL — log     ├ Read          ├ scope of      ├ Postgres —
 │  all-or-     │  write loses  │  before data,  │  Committed —   invariant      │  RC default,
 │  nothing     │  half a txn   │  redo/undo     │  cheapest,     (1 row vs      │  SERIALIZABLE
 ├ Consistency  ├ concurrent    ├ Locking (2PL) │  most          N rows)        │  opt-in
 │  invariants  │  reader sees  │  — block on    │  anomalies    ├ write skew    ├ MySQL InnoDB
 │  hold        │  half-done    │  conflict     ├ Repeatable     tolerable?     │  — RR default,
 ├ Isolation    │  state        ├ MVCC —        │  Read /       ├ shard          next-key locks
 │  no cross-   ├ concurrent    │  snapshot per  │  Snapshot —    boundary?      ├ Spanner —
 │  txn         │  writers      │  txn, no       │  no non-      ├ can you        TrueTime,
 │  visibility  │  overwrite    │  reader/writer │  repeatable    afford         globally
 ├ Durability   │  each other   │  blocking      │  reads         retries?       serializable
 │  survives    └ commit "lost" └ Constraints —  └ Serializable  └ 2PC vs saga   └ DynamoDB —
   a crash        after ack       reject bad        — prevents                    txn, 25 items
                                  state             write skew                     / 4MB cap
```

**How to read it:** the **four properties** are independent promises; §3's **what breaks** shows each one failing on its own; the **enforcement mechanisms** are the two subsystems (log, concurrency control) that actually deliver those promises; **isolation levels** are the named menu of how much of the isolation promise you're buying; **the decision** is which level and which scope you need; and **real systems** show how each engine actually resolved the trade-off.

---

## 3. 🔥 The Problem

Before transactional guarantees existed as an engine primitive, "transfer $100 from A to B" was just two independent statements run back to back: `UPDATE accounts SET balance = balance - 100 WHERE id = A`, then `UPDATE accounts SET balance = balance + 100 WHERE id = B`. It reads like one operation. To the database, it is not one operation — and that gap is exactly where money disappears.

Three concrete, distinct ways it breaks. **Crash between the two statements** (an atomicity gap): the debit commits, the process dies before the credit runs, and $100 has left A and arrived nowhere — the database now violates the most basic invariant a ledger has, that total balance is conserved, and there is no record of what should happen next. **A concurrent reader mid-transfer** (an isolation gap): a second connection runs a balance report between the two statements and sees A already debited but B not yet credited — it reports a number that was never true at any real, consistent point in time, and there is no way for that reader to know it caught the system mid-flight. **Concurrent writers on the same account** (isolation, a different flavor): two transfers out of A run at the same time, each reads the current balance before either writes, each computes its own new balance from that now-stale read, and the second write silently overwrites the first — one deduction is lost entirely, the account is overdrawn, and nothing in the schema recorded that anything went wrong.

The instinctive fix is procedural, and it fails for the same structural reason 8.3's naive fix failed: retry logic, an application-level mutex, "just be careful about statement order" — all of it depends on every future writer, across every service and every deploy, remembering an invariant that lives outside the data. An application mutex protects one process. It says nothing about a second server handling the retried request, and nothing about a crash that happens mid-critical-section, which is a normal event at scale, not an edge case.

The database's answer is to make "these N writes happen as one indivisible, isolated, durable unit" a primitive the storage engine itself enforces — a transaction, bounded by `BEGIN` and `COMMIT` — rather than a convention application code has to honor correctly, forever, under concurrency and partial failure. That's what ACID actually is: four separate, independently-enforced answers to four separate ways a concurrent, crash-prone system corrupts state.

**Before and after:**

```
   BEFORE — two unguarded statements                AFTER — one transaction
   ──────────────────────────────                   ───────────────────────
   UPDATE accounts SET balance =                     BEGIN;
     balance - 100 WHERE id = 'A';                     UPDATE accounts SET balance =
                                                          balance - 100 WHERE id = 'A';
   ⚠ crash here ────────────────┐                       UPDATE accounts SET balance =
                                 │                         balance + 100 WHERE id = 'B';
   UPDATE accounts SET balance =│                     COMMIT;
     balance + 100 WHERE id='B';◄┘  never runs
                                                        ✓ crash before COMMIT → WAL has
   RESULT: $100 left A. Arrived                          no commit record → whole thing
   nowhere. Ledger no longer                              is undone. $100 never left A.
   sums to its prior total.
                                                        ✓ crash after COMMIT → WAL has
   ✗ atomicity violated                                   the commit record → both writes
   ✗ a concurrent reader between                          are redone on recovery. Both
     the two statements sees a                            happened, or neither did.
     balance that was never real
                                                        ✓ no reader sees the half-done
                                                          state — isolation hides the
                                                          in-flight write entirely.
```

### ✅ Checkpoint

1. In the unguarded two-statement version, name the crash point that produces the *worst* outcome — not "the process dies," but a specific line in the sequence — and explain precisely why wrapping each individual `UPDATE` in its own transaction would not fix it, even though each individual statement would then be atomic.

   > 💡 *If you hesitate, re-read the third paragraph of §3 and count how many separate atomic operations the "fix" actually creates.*

MODEL ANSWER — §3 Checkpoint

CRASH POINT
  Between the debit committing and the credit running — after
  "UPDATE ... balance - 100 WHERE id='A'" takes effect, before
  "UPDATE ... balance + 100 WHERE id='B'" executes.

OUTCOME
  $100 left A. Nothing records it should reach B. The ledger's
  invariant (total balance conserved) is violated with no
  correction path.

WHY PER-STATEMENT TRANSACTIONS DON'T FIX IT
  Atomicity only covers the boundary you draw — BEGIN...COMMIT
  around exactly what's inside it. Two separate single-statement
  transactions have two separate boundaries, with a gap between them.

  The crash window doesn't close. It MOVES — from "mid-statement" to
  "mid-transfer, between the two now-atomic pieces." Each UPDATE is
  guaranteed all-or-nothing on its own, but nothing guarantees debit
  and credit happen TOGETHER. A crash in that gap reproduces the
  identical failure: A debited, B never credited.

THE TAKEAWAY
  Atomicity is a property of whatever you put inside BEGIN/COMMIT —
  not a property of "using transactions" in general. Draw the
  boundary around the wrong unit (one statement instead of the whole
  multi-step operation) and you get well-defined atomicity around
  something that was never what needed protecting.

> **→ Next:** If a transaction is the primitive that prevents this, what exactly is each of the four letters promising — and how do the promises build on each other?

---

## 4. 💡 The Core Idea

**A transaction is a unit of work the database guarantees is Atomic — all its writes commit or none do; Consistency-preserving — it moves the database from one state satisfying its declared invariants to another; Isolated — concurrent transactions cannot observe each other's uncommitted, in-flight state; and Durable — once it reports success, that result survives any subsequent crash. Four independent guarantees, enforced by two largely independent subsystems inside the engine.**

The five ideas below build on each other. Each one only makes sense because of the one before it.

**The build chain:**

```
 [ATOMICITY] ──▶ [CONSISTENCY] ──▶ [ISOLATION] ──▶ [DURABILITY] ──▶ [ENFORCEMENT MECHANISM]
   the base          therefore we      but many         and once one       so name the two
   primitive:         can ask if       atomic,           of those          subsystems: WAL
   group writes       the group         consistent        commits          (A+D) and locking/
   into one event     leaves a valid    txns run           cleanly, it       MVCC (I) — no
                       state             concurrently       must survive      single mechanism
                                                              a crash          gives you all four
```

### Atomicity — the base primitive

Everything else in this subtopic assumes you can already treat a group of writes as one event, and atomicity is what makes that assumption true. **All the writes in a transaction commit, or none do — there is no state where some landed and some didn't**, even if the process crashes halfway through. The debit-then-credit transfer from §3 is the canonical example: atomicity is the specific guarantee that closes the "$100 left A and arrived nowhere" failure. Without it, every multi-statement operation is one partial-write bug waiting for the right crash timing.

### Consistency — invariants hold before and after

Once you can group writes atomically, you can ask a second, different question: does this group leave the database in a state that satisfies its rules? That's consistency, and it is the weakest and most misunderstood of the four letters, because the database does not invent your invariants — it only enforces the ones you declare, as `CHECK` constraints, `FOREIGN KEY` constraints, and `UNIQUE` constraints. If a transaction's writes would violate a declared constraint, the engine aborts the whole transaction rather than applying it partially — that abort is consistency in action. What consistency does *not* mean is "my data is correct": an application bug that computes the wrong new balance, but does so within all declared constraints, commits successfully and is fully "consistent" by the database's definition. Consistency is enforcement of stated rules, not a correctness oracle.

### Isolation — concurrent transactions behave as if serial

Atomicity and consistency, as described so far, are properties of a single transaction running alone. Isolation is what happens the instant you allow many such transactions to run concurrently, which every real system does for throughput. The ideal is **serializability**: the observable result is as if every transaction ran one after another, with no overlap, even though the engine actually interleaves their execution for performance. This is where nearly all of the real engineering — and nearly all of the interview depth — actually lives, because "as if serial" is expensive to deliver exactly, and every isolation level weaker than full serializability is a named, specific relaxation that permits a named, specific anomaly. §3's concurrent-reader and concurrent-writer failures are both isolation failures.

### Durability — once committed, survives a crash

Isolation guarantees there's a well-defined instant at which a transaction's effects become visible — the commit. Durability is the promise about what happens to that committed result afterward: once the client has been told "committed," the change survives any subsequent crash, including a power loss one millisecond later. This is a promise about the boundary between volatile memory and durable storage, and it is the one guarantee that can be silently, invisibly broken by a misconfiguration — an engine or a disk that acknowledges a write before it is actually flushed to durable media reports durability it has not actually delivered.

### Enforcement Mechanism — how two subsystems deliver four promises

Naming four independent guarantees only matters if you can also name what actually enforces them, because interviewers probe exactly there. The **write-ahead log (WAL)** delivers atomicity and durability together: every change is appended to a sequential, durable log *before* the corresponding data page is modified, so on crash the engine can replay the log — redoing any transaction that has a commit record, undoing any that doesn't. **Concurrency control** delivers isolation, through one of two families: **locking** (acquire a lock per row touched, block or abort on conflict, release at commit — correct but writers can block writers and deadlock), or **MVCC** (each transaction reads its own private snapshot, so readers never block writers, at the cost of needing an explicit conflict check at commit time). **Constraints**, checked against the transaction's writes before commit, deliver consistency. No single mechanism gives you all four properties — ACID is the sum of at least three separate subsystems working together, which is exactly why it's possible for a system to deliver some of the four and not others.

### ✅ Checkpoint

1. A junior engineer says "consistency means the database is correct." Using the CHECK-constraint mechanism from this section, construct a concrete example of a transaction that is fully ACID-consistent by the database's definition, yet produces a *wrong* business result. What does this tell you about what consistency actually guarantees?

   > 💡 *If you hesitate, re-read the Consistency block and its distinction between "satisfies declared constraints" and "is correct."*

MODEL ANSWER — §4 Checkpoint 1

EXAMPLE
  BEGIN;
    UPDATE accounts SET balance = balance - 100 WHERE id = 'A';
    UPDATE accounts SET balance = balance + 80  WHERE id = 'B';
  COMMIT;

WHY IT'S "CONSISTENT" BY THE DATABASE'S DEFINITION
  Both declared constraints still hold after commit — say,
  balance >= 0 on both rows, foreign keys intact, no UNIQUE
  violated. The engine has nothing to check against for
  "debit amount must equal credit amount," because that
  invariant was never declared. It's not a rule the schema knows.

WHY IT'S WRONG
  $20 vanished. The ledger's real invariant — total balance
  conserved across the transfer — is violated, but silently,
  because nobody told the database that invariant exists.

WHAT THIS SAYS ABOUT CONSISTENCY
  Consistency enforces DECLARED rules, not business intent.
  The database is not a correctness oracle — it will happily
  commit a transaction that is internally well-formed and
  externally wrong, because "well-formed" is the only thing
  it was ever told to check. Closing this gap requires an
  explicit constraint or trigger encoding the real invariant
  (e.g., a CHECK or application-level validation comparing
  debit and credit amounts) — the database won't infer it.

2. Explain why atomicity and durability share one mechanism (the WAL) while isolation needs a completely separate one (locking or MVCC). What is different about the *kind* of problem isolation is solving that atomicity/durability are not?

   > 💡 *If you hesitate, re-read the build chain and the Enforcement Mechanism block — atomicity/durability are about a single transaction surviving a crash; isolation is about multiple transactions coexisting.*

MODEL ANSWER — §4 Checkpoint 2

WAL → ATOMICITY + DURABILITY
  Both are about ONE transaction surviving TIME — specifically,
  surviving a crash. Redo what has a commit record, undo what
  doesn't. This is a single-timeline problem: given one transaction's
  history of writes, did it fully happen or fully not happen, and
  does that answer hold after a failure. No other transaction needs
  to be in the picture at all for this problem to exist.

LOCKING/MVCC → ISOLATION
  A completely different axis: multiple transactions coexisting at
  the SAME INSTANT. This problem exists even with zero crashes,
  ever — it's about concurrency, not failure. Two transactions
  running simultaneously need a rule for what each is allowed to see
  and touch of the other's in-flight state.

THE TEST
  One transaction at a time, crashes still happen → still need the
  WAL (crash-recovery is still a real problem), no longer need
  locking/MVCC (there's nothing concurrent to isolate FROM).
  This is what proves they're solving genuinely different problems,
  not two flavors of the same one.

THE TAKEAWAY
  Atomicity/durability = a transaction vs. time (failure).
  Isolation = a transaction vs. other transactions (concurrency).
  That's why one mechanism (WAL) can't deliver both — they're not
  variations on a theme, they're answers to different questions.

> **→ Next:** You know what each letter promises and which subsystem delivers it. What actually happens, step by step, inside the engine when a transaction runs — and what happens when it crashes mid-flight?

---

## 5. ⚙️ How It Actually Works

**The happy path:**

1. `BEGIN` opens a transaction. The engine assigns it a transaction ID, and — in an MVCC engine — a snapshot of the database as of that instant.
2. Each write inside the transaction is first appended to the **write-ahead log (WAL)**, a sequential, append-only record of the change, *before* the actual data page is modified. Log-before-data is the entire idea; it's why it's called write-*ahead*.
3. Concurrency control decides what the transaction may see and whether it may proceed. Under **locking**, it acquires a lock on each row it touches — shared for reads, exclusive for writes — and blocks or aborts if another transaction holds a conflicting lock. Under **MVCC**, it simply reads from its private snapshot and writes a new row version; it never blocks a reader, and never gets blocked by one.
4. On `COMMIT`, the engine writes a commit record to the WAL and **fsyncs** it to durable storage. This fsync completing is the actual moment "committed" becomes true — not the moment the client's driver call returns, which is a subtlety that matters the instant something goes wrong between those two points.
5. Locks are released (locking engines), or the new row versions become visible to transactions that start afterward (MVCC engines).

> 🗺️ **Mental model — The WAL is a diary you write before you act.** You write down exactly what you're about to do, then you do it. If the house burns down midway, the diary shows precisely how far you got, so on recovery you know exactly what to redo and what to undo — nothing is ambiguous. *Where it breaks down:* a diary is written just before acting and the two are loosely coupled in time. The WAL's ordering is stricter than that — the log record must be durably fsynced *before* the corresponding data page write is considered safe to have happened at all, and a system that skips or delays that fsync for speed (a real, common misconfiguration) has a diary that lies about what it actually recorded.

**Crash recovery, concretely:**

```
 WAL (append-only, in commit order) ──────────────────────────────────────▶ time
 ┌─────────┬─────────┬─────────┬──────────┬─────────┬─────────┬──────────┐
 │ T1 write│ T1 write│ T1      │ T2 write │ T2 write│ T3 write│  ⚡ CRASH │
 │ row A   │ row B   │ COMMIT  │ row C    │ row D   │ row E   │           │
 └─────────┴─────────┴─────────┴──────────┴─────────┴─────────┴──────────┘
      │         │         │          │          │          │
      └─────────┴─────────┘          └──────────┴──────────┘
        T1 has a commit record          T2 and T3 have NO commit record
        → REDO on restart:              → UNDO on restart: as if they
          reapply A, B — T1's            never happened. No commit record
          effects are guaranteed         in the log means the client was
          durable, exactly once          never told "committed" either.

 THE INVARIANT: the log — not the data pages — is the source of truth
 after a crash. A data page can be half-written; the log record for a
 committed transaction cannot be, because it was fsynced before the
 engine told anyone it succeeded.
```

**Isolation, concretely — locking vs. MVCC:**

Two-phase locking (2PL) has a growing phase, where a transaction only acquires locks, and a shrinking phase, where it only releases them, never both — this ordering is what guarantees serializability under locking. It is correct, but it has a direct cost: concurrent writers to the same row block each other, and two transactions that each hold a lock the other needs **deadlock**, detected via a wait-for graph and resolved by aborting one transaction as the "victim." MVCC sidesteps reader/writer blocking entirely — a reader always sees a consistent snapshot and never waits on a writer — but it moves the cost to commit time: the engine must check whether a concurrent transaction wrote something that conflicts with what this transaction read, and if so, abort one of them. That check is exactly where isolation-level differences come from, and it's why MVCC engines can still permit anomalies that pure locking-based serializability would prevent.

> 🗺️ **Mental model — MVCC is a library where every reader gets their own photocopy.** Instead of one shared shelf that a reader and a writer both fight over, each transaction that starts gets a private, consistent photocopy of the book as it existed at that instant. Writers make a new edition without touching anyone's photocopy, so no reader is ever blocked. *Where it breaks down:* photocopies never interact with each other, but real MVCC transactions do — at commit time, the engine must reconcile the new edition against what other transactions have since written, and that reconciliation step is exactly where write skew slips through if the engine only checks for direct row conflicts and not logical ones.

**The row-version chain, structurally:**

```
 Row "inventory:sku-42" — version chain over time
 ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌────────────┐
 │ v1       │────▶│ v2       │────▶│ v3       │────▶│ v4 (latest)│
 │ qty=100  │     │ qty=97   │     │ qty=95   │     │ qty=94     │
 │ committed│     │ committed│     │ committed│     │ committed  │
 │ by T1    │     │ by T5    │     │ by T9    │     │ by T14     │
 └──────────┘     └──────────┘     └──────────┘     └────────────┘
       ▲                 ▲                                  ▲
       │                 │                                  │
  T3's snapshot     T7's snapshot                    T15 reads the
  (began before      (began after T5                 latest committed
   T5 committed —     committed, before               version — v4
   sees v1)           T9 committed — sees v2)

 EACH TRANSACTION reads the newest version that was committed before
 its OWN snapshot began. Older versions are retained only as long as
 some active transaction's snapshot might still need them, then
 vacuumed / garbage-collected.

 ⚠ This is exactly why write skew is possible: T3 and T7 each read a
   DIFFERENT, individually-valid version and neither one ever sees
   the other's write — there is no row-level conflict to detect.
```

**Failure and edge cases:**

- **Deadlock.** Two transactions each hold a lock the other is waiting for. The engine detects the cycle in its wait-for graph and aborts one transaction (the "victim") to break it — the aborted transaction must be retried by the application, which is why retry logic around transactions is normal, not a code smell.
- **Phantom reads.** A range query re-run inside the same transaction returns a different set of rows because a concurrent transaction inserted a new row matching the predicate. Row-level locking doesn't prevent this — you locked the rows that existed, not the ones that didn't yet — which is why preventing it requires range or next-key locking.
- **Write skew under snapshot isolation.** Two transactions each read overlapping data, each makes a decision that is valid against what *they* read, and the combined effect violates an invariant that neither one individually violated. (Classic example: two doctors on call, each independently checks "am I the last one on call" and, seeing a colleague still listed, takes themselves off — both do this concurrently, and the shift ends with nobody on call.) Snapshot isolation, including MVCC as commonly implemented, does **not** prevent this by default; true serializable snapshot isolation (SSI) does, at a real cost in aborted-and-retried transactions.
- **fsync lies.** Some storage layers, drivers, or misconfigured settings acknowledge a write as durable before it is actually flushed to non-volatile media. This silently breaks durability in a way that is invisible until the exact moment a crash exposes it — there is no error, no log line, just data that was reported "committed" and then wasn't there after recovery.
- **Cross-shard atomicity.** A transaction touching rows on two different shards cannot rely on one WAL or one lock table — there isn't one. This is precisely why 8.3 named transactional fan-out as capped "at a single database or shard": single-node atomicity does not extend across a partition boundary without an explicit protocol.

### ✅ Checkpoint

1. Trace exactly what the recovery process does with a transaction that wrote three rows, had its commit record written to the WAL, and then the machine crashed one second later before any of the three data pages were flushed to disk. Is any data lost? Why or why not?

   > 💡 *If you hesitate, re-read the crash-recovery diagram and its invariant statement.*

MODEL ANSWER — §5 Checkpoint 1

RESULT: No data is lost.

WHY
  The engine's rule is: fsync the commit record to durable storage
  BEFORE reporting "committed" to the client — never the reverse.
  So if a commit record for this transaction exists in the WAL after
  the crash, that fsync must have already completed; there's no path
  where the client sees "committed" and the record isn't durably
  logged yet.

WHAT RECOVERY DOES
  Scans the WAL, finds the commit record for this transaction, and
  REDOES it — reapplies the three row writes to the data pages,
  reconstructing exactly the state that would exist if the pages had
  been flushed normally before the crash.

WHY THE UNFLUSHED DATA PAGES DON'T MATTER
  The data pages were never the source of truth — the log was. Their
  being stale or missing entirely after a crash is expected and fine,
  because redo rebuilds them deterministically from what's already
  durable in the log.

2. A team implements "check current stock, then decrement it" using MVCC snapshot isolation, assuming that's strong enough to prevent overselling under concurrent checkouts. Explain precisely why it isn't, using the write-skew definition above, and name the isolation level that would actually prevent it.

   > 💡 *If you hesitate, re-read the write-skew bullet in Failure and edge cases and map "check stock / decrement" onto the two-doctors example.*

MODEL ANSWER — §5 Checkpoint 2

WHY SNAPSHOT ISOLATION ISN'T ENOUGH
  Two checkout transactions each read the stock count from their own
  private snapshot, taken before either commits. Both see stock
  available. Both decrement based on that stale read. Neither ever
  observes the other's write, because MVCC's whole point is that
  readers don't block on writers and don't see concurrent in-flight
  changes. The result: the true count goes negative, or the last
  unit sells twice — an oversell that neither transaction, in
  isolation, did anything "wrong" to cause.

THE FIX
  SERIALIZABLE isolation — the transaction behaves as if it ran
  alone, with no concurrent writes overlapping it. Under true
  Serializable (e.g. Postgres's SSI), the engine detects the
  dependency between the two transactions' read and write sets and
  aborts one of them rather than letting both commit.

  For this specific single-row case, a narrower fix also works:
  SELECT ... FOR UPDATE, an explicit row lock that forces the second
  transaction to block until the first commits, so it reads the
  post-decrement value instead of a stale snapshot.

> **→ Next:** You know both mechanisms and exactly how each fails. So in a live design, which isolation level and which scope do you actually pick — and what are you giving up?

---

## 6. ⚖️ The Decision — When, and What It Costs

The default is not "the strongest isolation level everywhere" — it's the weakest level that still prevents the specific anomaly your workload can't tolerate, on the smallest scope you can keep it on. Full Serializable is correct everywhere, but it is not free: it costs either heavy locking or a real rate of serialization failures that the client must catch and retry, and paying that cost on a read-heavy report that doesn't need it is a needless throughput tax.

Three signals decide it. **Scope of the invariant** is the first and strongest: if the invariant lives on one row (don't oversell this SKU), a targeted lock (`SELECT ... FOR UPDATE`) or a conditional write is usually enough; if it spans multiple rows or tables with a relationship between them (an inventory count and an order total that must stay consistent with each other), you need an isolation level that actually prevents cross-row anomalies, not just per-row ones. **Write-skew tolerance** is the second: if two concurrent transactions could each individually look valid while jointly violating a rule — the two-doctors pattern — Repeatable Read/Snapshot Isolation is not enough, and you need Serializable (or explicit locking that closes the specific gap). **Whether the transaction can stay on one node** is the third and can be decisive on its own: single-node ACID does not cross a shard boundary for free, and the choice there isn't about isolation level at all — it's whether to redesign so the invariant's writes are colocated on one partition (cheap, and the strongly preferred fix), or to pay for two-phase commit (correct, but blocks every participant if the coordinator fails after prepare) or fall back to a saga — an explicit sequence of local transactions with compensating actions — which gives up atomicity for availability and requires the in-between state to be visible and recoverable, not hidden.

**Decision tree:**

```
                 Does the invariant span more than one row/table
                 that must never be observed half-done?
                              │
                 ┌────no──────┴──────yes────┐
                 ▼                          ▼
         READ COMMITTED is           Can this transaction's writes
         usually enough. Add a       stay on ONE shard/partition?
         targeted row lock only              │
         if a specific race         ┌───no───┴───yes──┐
         is identified.             ▼                 ▼
                              Redesign so the    Could two concurrent
                              invariant's data    transactions each look
                              is colocated —      individually valid yet
                              cheapest real       jointly violate the
                              fix. If truly       invariant (write skew)?
                              impossible:                │
                              PAY for 2PC (blocks   ┌─no──┴──yes─┐
                              on coordinator        ▼            ▼
                              failure) or a    REPEATABLE     SERIALIZABLE.
                              SAGA (give up     READ /        Prevents write
                              atomicity, make   SNAPSHOT      skew too. Pay
                              the in-between    is enough.    with locking
                              state visible                   or retries on
                              and recoverable).                serialization
                                                                failure.
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Read Committed: cheapest, highest concurrency** — never blocks on another transaction's uncommitted data | Permits non-repeatable reads and phantoms; a "check then act" pattern can race under concurrent writers |
| **Repeatable Read / Snapshot Isolation: consistent view for the whole transaction** — no non-repeatable reads, readers never block writers under MVCC | Still permits write skew — two transactions can each look individually correct and jointly break an invariant neither checked |
| **Serializable: strongest correctness guarantee** — behaves as if every transaction ran alone, one after another | Highest cost: heavy locking, or serialization failures the client must detect and retry; throughput drops under contention |
| **Two-phase commit: real atomicity across shards** — all participants commit or all abort | Blocks every participant if the coordinator dies after the prepare phase; adds at least 2 network round trips per transaction |
| **Saga: no cross-shard blocking, high availability** — each step is a local transaction | Gives up atomicity entirely; requires explicit compensating actions and leaves a real, visible in-between state |

### In production

| System | How it applies | The nuance |
|--------|----------------|------------|
| **Postgres** | Defaults to Read Committed; Repeatable Read and Serializable are opt-in per transaction (`SET TRANSACTION ISOLATION LEVEL SERIALIZABLE`) | Its Serializable implementation is Serializable Snapshot Isolation (SSI) — it detects the *possibility* of a serialization anomaly and aborts one transaction rather than locking pessimistically, so the client must be ready to retry |
| **MySQL InnoDB** | Defaults to Repeatable Read — stricter than the SQL standard's own definition of that level | InnoDB's Repeatable Read uses next-key locking specifically to also prevent phantom reads, a documented deviation most engineers don't realize is non-standard |
| **Google Spanner** | Offers external consistency — effectively global Serializable — across a globally distributed, sharded database | Achieved via TrueTime, a bounded-uncertainty global clock; the database waits out the clock uncertainty window on commit, trading a few milliseconds of latency for a correctness guarantee most systems can't offer at all |
| **DynamoDB transactions** | `TransactWriteItems` gives all-or-nothing atomicity across up to 25 items / 4MB, within one region | Costs roughly 2x the read/write capacity units of the equivalent non-transactional calls; it is a bounded, priced feature, not an ambient property of the store |
| **Sagas (e.g., order-fulfillment pipelines)** | Used when a business process spans multiple services/databases that can't share one transaction — reserve inventory, charge payment, ship — each a local commit, with a compensating "release inventory" if a later step fails | Not atomic in the ACID sense at all; correctness depends on every step having a working compensating action and the in-between state being observable, not on the database enforcing anything |

### ✅ Checkpoint

1. A ticket-booking system needs "never sell the same seat twice" under a burst of concurrent purchase attempts at on-sale time, where every seat lives in one regional database. Which isolation level (or explicit locking strategy) would you use, which specific anomaly does it close, and what do you do differently if the venue's seats are later sharded across two regional databases?

   > 💡 *If you hesitate, re-read the three signals at the top of §6 and the decision tree.*

MODEL ANSWER — §6 Checkpoint

PART 1 — single regional database
  Lock: SELECT ... FOR UPDATE on the seat's row, inside a
  transaction, at read time. The scenario already tells you the
  race exists (a burst of concurrent purchases at on-sale time), so
  this isn't a "wait and see" case — take the lock upfront.

  Anomaly closed: LOST UPDATE, not write skew. Both buyers target
  the SAME row (one seat), so a row-level lock is sufficient on its
  own — the second transaction blocks until the first commits, then
  sees the seat as sold and fails/retries. (Write skew would need
  Serializable instead, but only applies when the two transactions
  write to DIFFERENT rows — e.g. two different seats jointly
  violating a separate venue-capacity counter neither one's row lock
  would ever touch.)

PART 2 — sharded across two regional databases
  First move: check whether this problem needed to exist at all.
  If seats are sharded sensibly — by venue or region, the natural
  scheme — a given individual seat still lives entirely on one
  shard. "Never sell seat 14B twice" stays a single-shard problem;
  nothing about that specific invariant crossed a boundary. Correct
  sharding design usually means you never needed cross-shard
  atomicity for the per-seat lock at all.

  Where cross-shard coordination IS genuinely needed — e.g. one
  order books two seats that land on different shards — two options,
  with a real cost difference:
    TWO-PHASE COMMIT   correct, atomic across shards, but blocks
                       every participant if the coordinator dies
                       after prepare. A bad fit for a bursty on-sale
                       spike specifically: a stuck coordinator at
                       peak load stalls every reservation waiting
                       on it.
    SAGA               reserve each seat locally, confirm the order,
                       compensate (release) on failure. No blocking,
                       better availability under load — at the cost
                       of a real, visible "reserved but not yet
                       confirmed" window that must be observable and
                       recoverable, not hidden.
  For a high-throughput on-sale burst, the saga is usually the
  better-fitting answer once colocation genuinely isn't possible.

> **→ Next:** You can defend the choice. How does an interviewer actually put pressure on it?

---

## 7. 🎯 In the Interview

**When an interviewer asks / says:**

- "Walk me through what happens if the database crashes right after this write."
- "How do you make sure two concurrent requests don't both book the last seat / oversell the last item?"
- "What isolation level would you use here, and why?"
- "This transaction touches data on two different shards — how do you keep it atomic?"

**What you say / do:**

This lands in the **data model** phase the moment a write touches more than one row or table with an invariant between them — right after you've decided where each fact lives (8.3) — and it resurfaces hard in the **deep dive** the instant the interviewer adds concurrency or a crash to the scenario. Name the isolation level explicitly; "I'd wrap it in a transaction" with no level named answers nothing, because the anomalies each level permits are specific and different. State the mechanism, price the cost unprompted, and name the condition that would change your answer.

**The trade-off statement (memorize this pattern):**

> "For decrementing inventory on checkout, I'd wrap the stock read and the decrement in a single Postgres transaction using `SELECT ... FOR UPDATE` rather than relying on the default Read Committed isolation, because under Read Committed two concurrent checkouts can each read the same stock count before either commits, and both proceed to decrement it — a lost update that oversells the item. `FOR UPDATE` takes a row lock at read time, so the second transaction blocks until the first commits and is forced to read the updated count. I'm trading some serialization on that one inventory row — a very popular item can become a throughput bottleneck at checkout — for the guarantee that we never oversell. If this were a low-stakes counter, like a 'people viewing this' badge where occasional inaccuracy is fine, I wouldn't pay for the lock at all."

**A second trade-off variant — when the interviewer pushes it across shards:**

> "If that inventory row and the order record end up on different shards — say inventory is sharded by warehouse and orders are sharded by customer — I can't get this from a single-node transaction at all; there's no shared WAL or lock table across them. My first move is to try to avoid the problem: keep the invariant's writes colocated on one shard if the data model allows it, since that's the cheap fix. If that's genuinely not possible, I'd use a saga — reserve inventory, then charge payment, then confirm the reservation — with an explicit compensating 'release inventory' step if payment fails. I'm giving up atomicity for availability: there's a real window where inventory is reserved but payment hasn't succeeded, and I'd make that window observable in the order status rather than pretend the operation is instantaneous."

### ⚠️ Traps

- ❌ **Trap:** "I'll just wrap it in a transaction." — and stopping there, with no isolation level named.
  ✅ **Reality:** This says nothing on its own. Default isolation differs by engine — Postgres and SQL Server default to Read Committed, MySQL InnoDB defaults to Repeatable Read — and each level permits a specific, nameable anomaly. A complete answer names the level and the exact anomaly it's closing.

- ❌ **Trap:** "ACID means my data will always be correct."
  ✅ **Reality:** Consistency (the C) only enforces the invariants you declared — `CHECK`, `FOREIGN KEY`, `UNIQUE` constraints. An application bug that computes the wrong value but never trips a declared constraint commits successfully and is fully "consistent" by the database's own definition. The database enforces your rules; it does not invent correctness.

- ❌ **Trap:** "Isolation means concurrent transactions can't affect each other at all."
  ✅ **Reality:** Only Serializable gets close to that. Even snapshot isolation — commonly sold as "the strong one" and the default mental model most candidates reach for — permits write skew: two transactions can each look individually valid against what they read and still jointly violate an invariant neither one checked.

- ❌ **Trap:** "NoSQL means no transactions."
  ✅ **Reality:** Increasingly false — DynamoDB, MongoDB, and Cassandra (lightweight transactions) all offer some transactional scope. The real distinction from a relational engine isn't presence or absence, it's that the scope is usually bounded — a single partition, or a capped item count — rather than open-ended.

### ✅ Checkpoint — adversarial stress test

1. You built the checkout decrement using `SELECT ... FOR UPDATE` on a single Postgres instance and it works. The interviewer says: *"We're sharding this database by product category because write throughput on one instance can't keep up. 'Decrement inventory' and 'record the order' now live on different shards. Walk me through exactly what you lose, how you'd detect a partial failure, and what you'd change in the design so the system can never show an order as confirmed with no inventory actually reserved."*

   > 💡 *A complete answer covers: you lose single-node atomicity across the two writes, since there's no shared WAL or lock table between shards; the real fix is a saga with an explicit intermediate "reserved" state rather than assuming a bare two-phase commit is available or cheap; detection is a reconciliation job that finds reservations past a timeout with no matching confirmed order; and the honest acknowledgment that the design is now eventually consistent, not atomic — the in-between state must be made visible and recoverable, not hidden as if the operation were instantaneous. If you can't answer this cleanly, you are not done.*

> **→ Next:** Can you combine what you've learned across sections, not just recall each one?

MODEL ANSWER — §7 Adversarial Stress Test

WHAT YOU LOSE
  Single-node atomicity across the two writes. There is no shared
  WAL or lock table spanning both shards — "decrement inventory" and
  "record the order" are now two independent local transactions with
  nothing structurally tying their fates together.

THE REAL FIX
  A saga, not a bare two-phase commit. 2PC would technically restore
  atomicity, but at a cost that's worse than the problem it solves:
  if the coordinator dies after both shards have prepared but before
  it sends commit, both shards are stuck holding locks indefinitely,
  waiting on a coordinator that may never return. A saga sidesteps
  this entirely: reserve inventory (local commit on shard 1), then
  confirm the order (local commit on shard 2), with an explicit
  compensating "release inventory" step if the order step fails.
  No cross-shard blocking, ever — at the cost of a real, visible
  in-between state.

DETECTION
  A reconciliation job that finds inventory reservations past a
  timeout with no matching confirmed order (or the reverse — a
  confirmed order with no matching reservation) — not a generic
  "check if the counts agree," but a specific comparison keyed to
  that intermediate "reserved" state.

WHAT CHANGES IN THE DESIGN
  The system is now eventually consistent, not atomic, and the
  design has to say so out loud rather than hide it: an order sits
  in a "reserved, pending confirmation" state until the payment/
  inventory steps both complete, and that state is a real, queryable
  status — not an implementation detail papered over to look
  instantaneous.

---

## 8. 🧪 Mastery Gate

> *Synthesis only. Each question requires combining two or more sections.*

1. **(§3 + §5 + §6)** Using the concurrent checkout / inventory-decrement scenario, explain which of the four ACID properties is actually protecting you from overselling, trace the specific mechanism (locking or MVCC) that enforces it, and state the decision signal that would tell you the cost of that protection isn't worth paying (name a concrete example where it wouldn't be).

2. **(§4 + §6 + 8.3)** 8.3 named "transactional fan-out" as the strongest mechanism for keeping a denormalized copy in sync, but noted it caps you at a single database or shard. Explain exactly which ACID property is what makes that fan-out mechanism safe in the first place, and precisely what happens to that safety guarantee the moment the source row and the copy move onto different shards.

3. **(§5 + §6, applied to a novel system)** Design the write path for a ride-sharing app's driver-matching system, which must never assign the same driver to two concurrent ride requests. Name the isolation mechanism, the isolation level or explicit locking strategy you'd use, the trade-off you're accepting under a surge of simultaneous requests, and what changes if drivers in different cities live on different regional shards.

### Mastery criteria — tick only what you can demonstrate on demand

- [ ] Can state all four ACID properties and give a concrete, distinct example of what breaks when each one alone is violated
- [ ] Can name the engine mechanisms (write-ahead log, locking/MVCC, constraints) that enforce the four properties and say which mechanism enforces which property
- [ ] Can compare Read Committed, Repeatable Read/Snapshot, and Serializable by the specific anomaly each one does and does not prevent
- [ ] Can explain why crossing a shard boundary breaks single-node atomicity and name at least one alternative (two-phase commit or a saga) along with its cost
- [ ] Can choose an isolation level or explicit locking strategy for a novel concurrent-write scenario and justify it against the specific anomaly it prevents

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 9. 🔗 Connections & Sources

**Builds on:** **8.1 SQL vs. NoSQL** — transaction scope is itself a property of the store, and many NoSQL engines restrict transactional guarantees to a single partition rather than offering them unboundedly. Also **8.3 Data modeling**, which named transactional fan-out as the strongest sync mechanism for a denormalized copy without explaining why it's strongest (atomicity) or why it's limited (single-shard scope) — this subtopic is that explanation.

**Enables:** **18.x Consensus / Raft**, which generalizes the single-node write-ahead log into a durability guarantee replicated across multiple nodes, using the same redo-from-log idea at a distributed scale. Also **28.6 Alternatives to locking — idempotency and optimistic concurrency**, which builds directly on the locking-vs-MVCC distinction made here.

**Tension with:** **2.1 CAP theorem** — strong isolation and cross-node atomicity both require coordination, and CAP says you cannot have unconditional coordination available during a network partition. Distributed engines resolve this by either sacrificing some availability to keep strong guarantees (Spanner) or by relaxing isolation/atomicity to keep availability (most eventually-consistent stores, sagas).

### 📚 Further reading

- [ ] **Designing Data-Intensive Applications, Chapter 7 — Transactions** — Kleppmann — the definitive treatment of isolation levels, the anomalies each one permits, and why "ACID" undersells how much variance exists between engines
- [ ] **PostgreSQL Documentation — "Write-Ahead Logging (WAL)"** — https://www.postgresql.org/docs/current/wal-intro.html — how a real engine implements atomicity and durability
- [ ] **PostgreSQL Documentation — "Transaction Isolation"** — https://www.postgresql.org/docs/current/transaction-iso.html — the actual anomaly table per isolation level, with worked examples
- [ ] **"A Critique of ANSI SQL Isolation Levels"** — Berenson, Bernstein, et al. — the paper that formally named write skew and showed the ANSI SQL isolation definitions were incomplete
- [ ] **Google — "Spanner: Google's Globally-Distributed Database"** — the TrueTime paper — external consistency and global serializability at planet scale, and what it costs to get it

---

## 10. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
