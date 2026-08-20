# 15.1 Replication — Why and How

> **Topic:** Topic 15 — Distributed Storage Systems
> **Phase:** E — Reliability Branch
> **Depth Tier:** 🥇 T1 (Core) — budget ~3h
> **Prereqs:** 3.6 (Share-Nothing Architecture), 7.1 (Horizontal Partitioning vs. Vertical Partitioning)
> **Date studied:** 2026-08-20

---

## 0. 🧭 The Question This Answers

3.6 established the share-nothing shape: independent nodes, no shared disk, no shared state between them. 7.1 established that data gets split across those nodes into partitions so no single machine has to hold everything. Neither of those decisions says anything about what happens to *one* partition's data once it lands on *one* node — and by default, it lands on exactly one. That single copy is fast to write and trivial to reason about, precisely because there's only one of it.

That simplicity is also the whole problem. A single copy of anything ties the data's entire fate to one piece of hardware: one disk that can fail, one machine that can crash, one rack that can lose power, one availability zone that can go dark. None of those events are exotic — they are the ordinary, expected behavior of commodity infrastructure at scale. The question replication exists to answer isn't "should data ever be copied" — it's precise enough to be a real engineering decision.

**The question:** *How many independent copies of a piece of data do you need, where do those copies have to live relative to each other, and how does a write actually reach all of them — so that losing any single node neither destroys the data nor takes it offline?*

> **→ Next:** Before the fix, what exactly goes wrong with a single copy — and how bad is it, concretely?

---

## 1. 🎯 Interview Quick Reference Card

> *Not a summary — a live-recall tool, built for retrieval speed under interview pressure. If you need the reasoning behind anything here, that's what §2 (cheatsheet) and the rest of the doc are for.*

**The checklist — walk this on the whiteboard, in order:**

1. Name the two independent risks a single copy carries, unprompted: **durability** (the node's disk fails → data is permanently gone) and **availability** (the node crashes or is partitioned away → data is temporarily unreachable, but not lost).
2. State the definition: replication = keeping **N independent copies** (replicas) of the same data on different nodes, kept in sync by propagating every write to all of them.
3. Name the two propagation mechanisms unprompted: **synchronous** (wait for replica(s) to acknowledge before returning success — safer, slower) and **asynchronous** (return immediately, replicate in the background — faster, riskier). Say that 15.5 is the deep dive on this trade-off.
4. Say why placement matters, not just count: N copies are only independently safe if they don't share a **failure domain** — same rack, same power feed, or same AZ can let one event take out several "independent" copies together.
5. Give a number, not a vibe: **N=3 is the common default**, justified by "tolerates one node/domain failure" — always tie N to a stated failure-tolerance requirement.
6. Name what replication does **not** give you, unprompted: it doesn't decide which copy is authoritative or how a read should choose (that's leader/follower, 15.2, or quorum, 15.3), and it is not a substitute for backups — it propagates a bad write just as faithfully as a good one.
7. Price it unprompted: N copies cost **N× the storage** and **N−1× the write fan-out** for every single write — replication is a deliberate trade of resources for durability and availability, not a free upgrade.

**Trigger → action:**

| Interviewer says | You do |
|---|---|
| "Why do you need more than one copy of this data?" | Name both risks explicitly: durability (disk failure → permanent loss) and availability (node crash → temporary outage) |
| "What's your replication factor, and why that number?" | Give N tied to a stated failure-tolerance requirement — e.g. "N=3, to survive one node or one rack going down" |
| "How do the copies actually stay in sync?" | Name synchronous vs. asynchronous propagation as the two mechanisms, and that this doc assumes a write path that reaches all N |
| "Does replication protect you if someone deletes the wrong row?" | No — say so directly: replication propagates every write, including mistakes and corruption, to every copy just as faithfully. That's what backups (20.x) are for |
| "Isn't that the same as sharding?" | No — orthogonal. Sharding splits *different* data across nodes for scale; replication copies the *same* data for durability. Most systems do both — N replicas per shard |

**Fast disambiguation — the pairs that get confused live:**

| Pair | The distinction |
|---|---|
| **Replication vs. Sharding/Partitioning (7.1)** | Replication = multiple copies of the *same* data, for durability/availability. Partitioning = splitting *different* data across nodes, for scale. Orthogonal — usually combined, N replicas per shard. |
| **Replication vs. Backup** | Replication propagates *every* write — including a bad one — to all copies almost immediately. A backup is a deliberately delayed, point-in-time, restorable snapshot (20.x) that protects against exactly the class of mistake replication can't. |
| **Durability vs. Availability** (the two things replication buys) | Durability = the data is not permanently lost. Availability = the data is currently reachable. A down replica under sync propagation can block write *availability* without any data being *lost*; losing all N copies at once is a durability loss with no fix. |
| **Replication factor (N) vs. quorum (R/W, 15.3)** | N is how many copies exist — this doc's question. R and W are how many of those N copies must participate in a *given* read or write — a separate tuning question that assumes N is already fixed. |

**High-yield anchors:**

```
N = replication factor (number of independent copies)
Common default: N = 3
Durability risk (single copy): disk failure = permanent data loss
Availability risk (single copy): node crash/partition = temporary outage
Sync propagation: safer, higher write latency
Async propagation: faster, risk of losing the latest write(s) — see 15.5
Replication ≠ Sharding (copies of the same data vs. splits of different data)
Replication ≠ Backup (propagates corruption too — 20.x covers backups)
Cost: N× storage, (N−1)× write fan-out per write
```

**The script — say this close to verbatim:**

> "A single copy of data carries two independent risks: if the node's disk fails, that data is gone permanently — a durability problem — and if the node just crashes or gets partitioned away, the data is temporarily unreachable even though nothing was actually lost — an availability problem. Replication addresses both by keeping N independent copies on different nodes, ideally in different failure domains, and propagating every write to all of them — either synchronously, before acknowledging the write, or asynchronously, in the background. The cost is real: N copies means N times the storage and N minus one times the write fan-out for every single write. And the moment you have more than one copy, you've created a new problem replication doesn't answer by itself — which copy is current, and how a read should choose — which is exactly what leader/follower or quorum reads and writes exist to solve."

> **If pushed on "isn't replication basically a backup?":** "No — replication keeps every copy live and current with every write, including a bad one. If an application bug deletes the wrong row, that deletion propagates to every replica just as faithfully as a correct write would. Backups are deliberately delayed, restorable snapshots that protect against exactly that class of mistake, at the cost of losing whatever changed since the last snapshot. Production systems run both — replication for continuous durability and availability, backups for recovering from logical mistakes replication can't undo."

---

## 2. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*
>
> ⏭️ **First time through this topic?** Skip to §3 and come back here for revision.

```
§ 1  WHY IT EXISTS
A single copy of data on a single node carries two independent risks:
durability (the disk fails, data is gone forever) and availability (the
node crashes or is partitioned away, data is temporarily unreachable).
Replication addresses both by keeping multiple independent copies
instead of trusting any one node.

§ 2  WHAT IT IS
Replica       A copy of the data on a different node — ideally a
              different failure domain — from the other copies.
N             Replication factor: how many independent copies exist.
Propagation   The mechanism that carries a write from wherever it
              first landed out to the other N−1 replicas.

§ 3  THE MECHANISM
WRITE   arrives at an entry point, applied locally, then propagated to
        the other N−1 replicas — synchronously (wait for acks) or
        asynchronously (return immediately, replicate after).
READ    can be served by any replica holding the data — which one to
        trust, and how fresh it must be, is a separate question
        (15.2 leader/follower, or 15.3 quorum).
WHY IT   No single node's failure can take the only copy with it, as
WORKS    long as at least one replica survives whatever hit the others
         — and if the replicas are in independent failure domains,
         their individual (already small) failure risks multiply
         together instead of adding.

§ 4  USE / AVOID
USE replication whenever losing a single node must not mean losing
  data or going fully offline — true for essentially anything that
  matters in production.
USE a higher N when you must tolerate more simultaneous failures, or
  when replicas must span regions to survive a whole-region event.
AVOID treating replication as a substitute for backups: it propagates
  bad writes and corruption just as faithfully as good ones.
AVOID assuming N copies alone tells you which one is current or how
  to read consistently — that's leader/follower (15.2) or quorum
  (15.3), layered on top.

§ 5  SYNC VS. ASYNC (PREVIEW — 15.5 GOES DEEP)
SYNC    Write waits for replica(s) to acknowledge before returning
        success — stronger durability guarantee, higher write latency.
ASYNC   Write returns immediately, replicates in the background —
        lower latency, a real window where an "acknowledged" write
        might exist on fewer than N copies.

§ 6  NUMBERS TO ANCHOR THE DISCUSSION
Common default: N = 3 (tolerates 1 node/domain loss).
Storage cost: N replicas = N× the raw storage for that data.
Write cost: every write fans out to N−1 additional nodes.
Illustrative: 2% annual single-node failure risk → ~0.0008% (1-in-
  125,000) for all 3 independent copies to fail the same year.

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "Why not just one well-provisioned node?" → name both risks:
                                    durability AND availability
→ "What's your replication factor?"         → give N tied to a
                                    stated failure-tolerance target
→ "Is that the same as sharding?"            → no — orthogonal,
                                    copies vs. splits, usually combined
GOTCHA: Treating replication as a complete durability/availability
  solution on its own. It multiplies the number of independent
  failures that would all have to happen together to lose the data —
  it does not protect against replicating a bad write, and it creates
  a new coordination problem (which copy is current) that 15.2/15.3
  exist to solve.
```

---

## 3. 🧠 The Mindmap

> *The picture to hold in your head while you study. Everything below hangs off this.*

```
                                ┌─────────────────────────────────────┐
                                │              REPLICATION               │
                                │  "no single node holds the only        │
                                │   copy of anything that matters"       │
                                └────────────────────┬────────────────────┘
                                                     │
      ┌────────────────────┬────────────────────────┼────────────────────┬────────────────────┐
      ▼                     ▼                        ▼                    ▼                     ▼
 THE TWO RISKS         THE CORE                WHAT IT DOESN'T       WHAT IT COSTS         WHERE IT LEADS
 IT SOLVES              MECHANISM               SOLVE
 ───────────────       ───────────────         ───────────────       ───────────────       ───────────────
 durability:            replica = a copy        bad writes /          N× storage for        15.2 leader/
  disk fails →           on another node         corruption            that data              follower —
  data gone              N = replication         still propagates     N−1× write             who decides
  forever                 factor                 just as faithfully   fan-out per            what's current
 availability:           propagation:            as good writes       write                  15.3 quorum
  node crashes →          sync (wait,            which copy is        coordination            R+W>N — a
  temp outage              safer, slower)         current — a         complexity — the         count-based
  — data isn't             or async (fast,        question            new problem              answer
  lost, just               riskier)               replication         replication             15.4 durability
  unreachable                                     alone doesn't       itself creates            & factor depth
                                                   answer                                       15.5 sync vs.
                                                                                                  async, in depth
                                                                                                 15.6 replication
                                                                                                  lag & anomalies
```

**How to read it:** The **two risks** branch is the *why* — everything else on this map exists to address durability, availability, or both. The **core mechanism** branch is the *how*, at the level this subtopic covers; propagation's two modes are only previewed here and get their own deep dive in 15.5. **What it doesn't solve** is the honesty check — it draws the boundary of this subtopic so you don't overclaim what raw replication buys you in an interview. **What it costs** is why N is a deliberate trade, never a maximized number. **Where it leads** is this doc's own table of contents for the rest of Topic 15 — every subtopic there exists because this one raised a question it deliberately left open.

> **→ Next:** Made concrete — what exactly breaks with a single copy, and by how much?

---

## 4. 🔥 The Problem

3.6's share-nothing model means every node's storage is genuinely its own — no shared disk array, no shared state to fall back on if one node dies. 7.1's partitioning splits data across those nodes so no single machine holds everything, but says nothing about what protects any *one* partition once it lands on *one* node. By default, it lands on exactly one, and that single copy is fast and simple precisely because there's nothing to keep in sync — there's only one of it.

That simplicity assumed the underlying hardware would mostly stay up, which was a reasonable assumption when "a server" meant one carefully maintained, heavily protected machine. It stopped being reasonable the moment systems moved onto commodity hardware to get horizontal scale (3.7): cheap machines fail routinely — disks wear out, a machine gets rebooted for a kernel patch, a rack loses power, an entire availability zone goes dark for an afternoon. None of that is exotic; it's the ordinary operating condition of a large fleet. A single copy ties the data's entire fate to exactly one piece of that unreliable hardware — when it goes, either temporarily or permanently, so does every guarantee you had about the data.

The instinctive first fix is to hunt for a sturdier single machine: RAID arrays, redundant power supplies, an enterprise-grade SAN instead of local disk. This genuinely lowers the *probability* that any one node fails — but it doesn't remove the *property* that makes a single copy dangerous: however reliable one machine is, it is still exactly one machine, and eventually something takes the whole box down for a reason RAID can't touch — a firmware bug, an operator error, a full power-supply failure, a data-center-level event. Durability against total node loss can't be purchased by making a single node merely less likely to fail; it can only be bought by not depending on a single node at all.

The insight that resolves this: stop trusting any one node to be the sole holder of the data. Keep N independent copies on N different pieces of hardware — ideally different racks, ideally different failure domains entirely — and make every write reach all of them (or enough of them). Losing any one node's disk no longer loses the data. Losing any one node no longer takes it offline. The property a single copy could never have — surviving the loss of the specific hardware holding it — is exactly what N independent copies buys.

**Before / after:**

```
  BEFORE — single copy, single node                AFTER — N=3 independent copies
  ────────────────────────────────                  ────────────────────────────────
   all reads and writes hit ONE node                 writes propagate to 2 more replicas
   ONE disk holds the only copy                      3 different disks each hold a copy

   ✗ disk failure = permanent data loss              ✓ one disk failing loses 0 data —
     (durability gone)                                 2 other copies still hold it
   ✗ node crash/partition = data                     ✓ one node crashing loses 0
     unreachable until it's back                        availability — 2 other nodes
     (availability gone)                                 can still serve it
   ✗ "harden the one node" (RAID,                    ✓ independent copies mean the
     redundant PSU) lowers the odds                      failures that matter are now
     but the node is STILL a single                      correlated only if the copies
     point of total failure                               share a failure domain (§5)
```

**Made concrete — annual failure probability, illustrative single-node AFR of 2%:**

```
  SINGLE COPY                            N = 3 INDEPENDENT COPIES
  (1 node — "independent failure          (3 nodes, different racks/AZs —
   domain" isn't even a question)          failures assumed independent)

  P(data lost this year)                  P(data lost this year)
    = P(that one node fails)                = P(ALL 3 nodes fail in the same year)
    = 2%                                    = 0.02 × 0.02 × 0.02
                                             = 0.0008%   (≈ 1-in-125,000)

  2% annual loss risk is not a             Independence MULTIPLIES the (already
  rounding error — it is a real             small) individual risks together
  design flaw for anything that              instead of adding them. That's WHY
  actually matters.                          replication works, not just THAT it
                                              works — and it's why §5's placement
                                              concept matters as much as N itself.
```

### ✅ Checkpoint

1. A teammate proposes fixing durability by buying one very expensive, highly reliable enterprise server — RAID array, redundant power supplies, the works — instead of running 3 replicas. Using the "naive fix" discussion and the concrete failure-probability example, explain precisely why this doesn't solve the problem the way N independent copies does, and what property of independent copies it's missing.

   > 💡 *If you hesitate, re-read the "naive fix" paragraph and the concrete example's contrast between lowering a single P versus multiplying several independent P's together.*

Buying sturdier hardware only lowers the probability that *that one node* fails
— it moves the 2% in the concrete example down, but it does not change the
fact that there is still exactly one node, and eventually something takes the
whole box down for a reason RAID and redundant power don't touch: a firmware
bug, an operator mistake, a full-facility power event. When that happens,
there is still only one copy, and it's gone. The missing property is
independence: N separate copies in separate failure domains don't just lower
one probability, they multiply several already-small, independent
probabilities together (0.02 × 0.02 × 0.02), which is a fundamentally
different and far larger reduction than making one node modestly more
reliable. A hardened single node is still a single point of total failure; it
has just gotten somewhat less likely to trigger.

> **→ Next:** If the fix is N independent copies, what exactly does that design consist of, and what does it actually take to make it work — not just to have more copies lying around?

---

## 5. 💡 The Core Idea

**Replication is the practice of maintaining N independent copies of the same data on different nodes — ideally in different failure domains — and propagating every write to all of them, so that no single node's failure can either destroy the data or take it fully offline.**

**Visual required:** build-chain diagram.

```
 [REPLICAS &      ──▶ [PROPAGATION —   ──▶ [FAILURE-DOMAIN   ──▶ [THE COST & THE
  REPLICATION           HOW A WRITE          PLACEMENT —           NEW PROBLEM IT
  FACTOR N]              REACHES ALL         WHERE THE N            CREATES]
   because               N COPIES]           COPIES ACTUALLY         because
   §4 showed no           because             LIVE]                   N copies,
   single node             replicas           because                  correctly
   should hold              are only           N only buys              placed and
   the only copy            useful if           independent               kept in sync,
   (§4)                     kept current        failure if                cost real
                                                 they don't                resources and
                                                 share a domain            open a new gap
```

### Replicas & Replication Factor N

Builds directly on §4's insight: no single node should hold the only copy of anything that matters. A **replica** is simply another node holding an independent copy of the same data, and **N** — the replication factor — is how many such copies exist at once. N is not an implementation detail buried in a config file; it's a deliberate, statable design decision that trades resources for fault tolerance, and it's usually the very first number an interviewer expects when you're asked to design a durable storage layer. N=1 means "no replication" — every risk from §4 is fully present.

### Propagation — How a Write Reaches All N Copies

Builds on replicas existing at all: a replica is only useful if it actually stays current, and **propagation** is the mechanism that carries a write from wherever it first landed out to the other N−1 copies. There are exactly two shapes this takes. **Synchronous** propagation waits for some or all of the other replicas to acknowledge the write before telling the client it succeeded — a strong "the write is safe on multiple copies" guarantee, at the cost of higher write latency. **Asynchronous** propagation acknowledges the client immediately and replicates in the background — lower latency, but with a real window where the copy the client was told is "safe" actually sits on fewer than N nodes. This doc only introduces the split; 15.5 is the entire subtopic dedicated to its trade-off math.

### Failure-Domain Placement — Where the N Copies Actually Live

Builds on propagation actually moving data somewhere real: *where* the copies live matters as much as *how many* there are. If all N replicas sit in the same rack, a single power or network event can take all of them out together — and N stops meaning what you think it means, because the copies were never independent to begin with. Genuine independence requires the replicas to not share a **failure domain**: different physical machines at minimum, different racks for real hardware independence, different availability zones or regions if the design must survive a whole-datacenter event. §4's multiplicative math (0.02 × 0.02 × 0.02) only holds if the three failures are actually independent events — placement is what makes that assumption true or false.

### The Cost & the New Problem It Creates

Builds on all three of the above: N replicas, correctly placed and kept in sync, is not free. It costs **N times the storage** for that data, and every single write now fans out to **N−1 additional nodes** instead of touching just one — a real, ongoing operational and infrastructure cost, not a one-time decision. And the moment there is more than one copy, replication creates a brand-new problem it does not answer on its own: with two or more nodes potentially holding the data, *something* has to decide how writes are ordered across them and which copy a read should trust. That coordination question is exactly what 15.2 (a single leader taking every write) and 15.3 (a quorum of nodes agreeing by count) exist to answer — this doc is the "why keep copies," those two are the "how do you keep them coherent."

### ✅ Checkpoint

1. Using only "Replicas & Replication Factor N" and "Propagation," explain why simply raising N — say from 3 to 5 — without also specifying synchronous or asynchronous propagation leaves the durability guarantee undefined.

   > 💡 *If you hesitate, re-read "Propagation" — the sentence about a real window where an acknowledged write can sit on fewer than N copies.*

N alone tells you how many copies are supposed to exist eventually — it says
nothing about whether they're actually caught up at any given instant. If
propagation is asynchronous, a freshly acknowledged write might genuinely
exist on only 1 of the N copies for some window before it reaches the
others, so a node failure during exactly that window can still lose the
write no matter how large N is. The durability guarantee depends on both
numbers together — how many copies exist, and how synchronously they're
kept current — not on N by itself; a large N with fully async propagation
can be less safe in practice than a smaller N with synchronous
acknowledgment from at least one other replica.

2. Trace the link between "Failure-Domain Placement" and "The Cost & the New Problem It Creates": a team sets N=3 but places all three replicas in the same rack, reasoning "we're already paying 3× storage, so we've bought our durability." Using both concept blocks, explain what they've actually bought and what they haven't.

   > 💡 *If you hesitate, re-read "Failure-Domain Placement" — the sentence about a single power/network event taking out same-rack replicas together.*

They have genuinely paid the full cost described in "The Cost & the New
Problem It Creates" — 3× the storage and every write fanning out to the
other 2 nodes. But "Failure-Domain Placement" establishes that N only buys
independent-failure protection if the copies don't share a failure domain:
same rack means a single rack-level event (a power feed, a top-of-rack
switch) can take out all three replicas simultaneously, which collapses N=3's
protection back down to effectively N=1 for that specific failure class —
while the team is still paying the full 3× cost for it. They bought the cost
of independence without actually buying the independence itself.

> **→ Next:** You know the shape of the design. What actually happens, step by step, on a real write — and what specifically breaks when a node fails or a network partition hits mid-propagation?

---

## 6. ⚙️ How It Actually Works

**Happy path — a write reaches all N replicas, then a later read, N=3:**

1. A client sends a write for key K to some entry point — which node handles first-contact writes is itself a design choice this doc leaves open; 15.2 covers the common leader-based answer.
2. The entry node applies the write to its own local copy.
3. The entry node propagates the write to the other N−1 replicas over the network, tagged so each replica applies it in the same order the entry node did.
4. Depending on the propagation mode chosen in §5: **synchronous** — the entry node waits for some number of those replicas to acknowledge before telling the client the write succeeded; **asynchronous** — the entry node tells the client success immediately, and propagation continues in the background.
5. Each replica, on receiving the propagated write, applies it to its own local copy, bringing it into sync with the entry node's.
6. A later read can be served by any replica currently holding the data — which one is chosen, and how fresh it's guaranteed to be, depends on the read strategy layered on top of raw replication (15.2 or 15.3).

> 🗺️ **Mental model — replication is a photocopier, not a shared filing cabinet.** A shared filing cabinet has exactly one physical folder; whoever wants "the current version" reaches into the same drawer, so there's never a copy that can fall behind. Replication instead behaves like handing out photocopies to N different offices the instant a document changes — the original office finishes first, and every other office only has the current version once a courier physically delivers its copy, which takes real time and can fail along the way.
> *Where it breaks down:* a delivered photocopy never goes stale until the next edit — but a live replica can also crash or get network-partitioned away entirely, an outcome no photocopy analogy captures. And unlike copies handed out once and then left alone, replicas are continuously being pushed near-simultaneous updates, so at almost any instant some fraction of them may be "copies in transit," not yet fully caught up to the latest version.

**Failure & edge cases:**

- **Losing a replica mid-propagation doesn't lose the write, only that replica's copy of it.** As long as at least one other node (the entry node, or another replica) already has the write, propagating it to a healthy replacement later can still catch that replacement up. The write is only genuinely at risk if the specific node(s) holding it happen to be the *only* ones that received it before all of them fail together.
- **With asynchronous propagation, the entry node failing right after acknowledging a write is exactly the durability gap §5 named.** The client was told "success," but if the entry node's local copy was the only one holding that write when it died, the write is gone despite N being large. (15.5 works out precisely how much risk this is under different configurations.)
- **Two writes to the same key, propagated through different paths (e.g. the entry point failed over mid-write), can arrive at different replicas in different orders, or not at all at some of them.** Plain replication has no built-in mechanism guaranteeing a consistent order across all N copies — that ordering guarantee is exactly what the leader/follower model (15.2) supplies by funneling every write through one place.
- **A network partition can isolate some replicas from the rest entirely.** Isolated replicas keep serving whatever they already had — possibly correct, possibly stale — but stop receiving new writes until the partition heals. That's a live availability/consistency trade-off this doc surfaces but doesn't resolve; 17.x (Consistency Models) formalizes it.
- **Replicating a write is not the same as replicating a *good* write.** If the write itself is a mistake — an application bug deletes the wrong row — replication propagates that mistake to every copy exactly as reliably as it propagates a correct write. This is precisely why replication and backups are not substitutes for each other.

**Mechanism flow, end to end:**

```
① CLIENT WRITE        ② ENTRY NODE          ③ PROPAGATE TO         ④ REPLICAS APPLY —
   arrives at an    ──▶  applies the      ──▶  N−1 OTHER          ──▶  converge to N
   entry point            write locally         REPLICAS                matching copies;
                                                 (sync waits for         a read can now
                                                  acks / async            hit any of them
                                                  doesn't)
```

**Structural diagram — failure-domain placement decides whether N is real:**

```
  SAME RACK (N=3, but NOT independent)          DIFFERENT RACKS/AZs (N=3, independent)

  ┌────────────── RACK 1 ───────────────┐       ┌── RACK 1 ──┐ ┌── RACK 2 ──┐ ┌── RACK 3 ──┐
  │   [Replica A]   [Replica B]         │       │ [Replica A] │ │ [Replica B] │ │ [Replica C] │
  │   [Replica C]                        │       └─────────────┘ └─────────────┘ └─────────────┘
  │   (shared power feed, shared          │
  │    top-of-rack switch)                │
  └────────────────────────────────────────┘

  ✗ a rack power/switch failure can          ✓ a rack-level event only ever takes
    take out A, B, AND C together —            out ONE of the 3 replicas — the
    effective N collapses to 1 for              other two sit on independent
    that failure class, despite N=3             power/network — effective N
    on paper                                     stays 3 for that failure class
```

### ✅ Checkpoint

1. A system propagates writes synchronously but only waits for 1 of the N−1 other replicas to acknowledge (not all of them) before returning success to the client. Using the happy path and the "entry node failing right after acknowledging" edge case, explain whether this is meaningfully different from pure asynchronous replication, and why or why not.

   > 💡 *If you hesitate, re-read step 4 of the happy path and the asynchronous-propagation edge case — count exactly how many nodes have the write before the client is told "success" in each scenario.*

It's meaningfully different, but the gap isn't fully closed. Waiting for at
least 1 replica beyond the entry node means the write is on 2 of the N
copies before the client is told "success" — already an improvement over
pure async, where a client-visible success might exist on only the entry
node's local copy. But it's not a complete fix either: the remaining N−2
replicas are still in exactly the "propagating in the background" state the
async edge case describes, so if the entry node and the one acknowledging
replica are both lost together, the write can still be lost. The risk isn't
eliminated, only reduced in proportion to how many replicas were required to
acknowledge.

2. A network partition splits a 3-replica cluster into two groups: the entry node alone on one side, and the other 2 replicas together on the other side. Using the partition edge case, explain what each side can and cannot do while the partition persists, and why this is described as a trade-off rather than simply a bug.

   > 💡 *If you hesitate, re-read the "network partition can isolate some replicas" edge case — note which side actually receives new writes in this design.*

The entry-node side can keep serving reads from its own local copy — whatever
it already had — but cannot propagate any new writes to the other 2 replicas
until the partition heals; any write accepted during this window exists on
only 1 of the 3 copies, a live durability risk. The 2-replica side can keep
serving reads from its 2 copies, but since writes in this design go through
the entry node, it receives no new writes at all — it can serve
slightly-behind-any-new-write data, but nothing newer. This is a trade-off,
not a bug, because the system chose to keep serving *something* on both
sides of the partition rather than halting entirely; whether that's the
right call, and how to reason about it formally, is exactly what the
consistency/availability trade-off in Topic 17 (CAP) works out in depth.

> **→ Next:** You can run this correctly end to end. In a real design, how do you actually choose N and how it's placed — and what does each choice cost?

---

## 7. ⚖️ The Decision — When, and What It Costs

The baseline — N ≥ 2, placed across independent failure domains — is the correctness floor established by §4/§5; N=1 is simply "no replication," and every risk from §4 is fully present. The real decision is what N should be and how the copies should be placed, and that decision is driven by how much simultaneous failure the data must survive, how expensive losing it actually is, and how much write latency the system can tolerate paying for the guarantee.

**Losing this data outright is acceptable — it's cheap to re-derive from another source.** A cache, a materialized view, or anything with a clean rebuild path can often run with a low N, sometimes even N=1, because losing it is inconvenient, not catastrophic — the recovery plan is "rebuild it," not "restore it."

**Losing this data is not acceptable, and you must survive one node or one failure-domain loss.** This is the canonical case: **N=3**, spread across independent failure domains (different racks at minimum, different AZs for stronger guarantees). It's the default absent a stronger stated requirement, and it's what most systems ship with out of the box.

**You must survive multiple simultaneous failures, or a whole region going down.** Push N higher (5 or more) and spread replicas across regions, not just AZs — this is what multi-region durability designs (37.x) build on, at the cost of real cross-region propagation latency.

**Write latency is the binding constraint, and some durability risk is acceptable to get it.** Lean toward asynchronous propagation even with a solid N — the copies still exist, but the guarantee on the *very latest* write weakens in exchange for speed. This is the choice 15.5 goes deep on.

**Decision tree:**

```
        Is losing this data (not just being briefly unavailable — actually
        gone) acceptable, e.g. because it's cheaply re-derivable from
        another source?
                              │
              ┌──────yes──────┴──────no───────┐
              ▼                                 ▼
   N=1 (no replication) may be           How many simultaneous node/
   fine — rebuild-on-loss is the         failure-domain losses must
   recovery plan.                        you survive?
                                                    │
                                     ┌──────1────────┴────────2+───────┐
                                     ▼                                   ▼
                          N=3, spread across             N=5+, spread across
                          independent failure              multiple regions
                          domains (common default)          (higher tolerance)
                                     │                                   │
                                     └───────────────┬───────────────────┘
                                                       ▼
                                        How much write latency can you
                                        tolerate paying for the guarantee?
                                        sync (safer, slower) vs. async
                                        (faster, riskier) — depth in 15.5
```

**Trade-offs**

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **More independent copies lower the probability of total data loss and raise availability** during a single node's failure — the multiplicative effect §4 quantified | Storage cost and per-write fan-out grow **linearly with N** — every additional copy is a permanent, ongoing infrastructure cost, not a one-time decision |
| **Placing replicas across failure domains protects against correlated failures** (a rack, an AZ, a region going down together) | Cross-domain — especially cross-region — propagation adds **real network latency** to keeping replicas in sync |
| **Synchronous propagation gives a strong "the write is safe on ≥X copies" guarantee** before the client is told success | Synchronous propagation ties write latency (and sometimes availability) to the **slowest required replica** responding |
| **Replication composes cleanly with partitioning (7.x)** — each shard simply gets its own N replicas | Replication **doesn't decide which copy is authoritative** or how conflicting writes are ordered — that coordination is a separate mechanism (15.2 or 15.3) layered on top |

**In production**

| System | How it applies | The nuance |
|--------|----------------|------------|
| **PostgreSQL streaming replication** | A primary plus N standby replicas, each receiving a continuous stream of write-ahead-log records | `synchronous_commit` is configurable per transaction — async is the common default, but a transaction can opt into waiting for one or more standbys to confirm |
| **MongoDB replica sets** | Default replica set size of 3 members; writes can require acknowledgment from a majority via write concern | `w: "majority"` is the sync-leaning default for durability-sensitive writes; `w: 1` acknowledges after only the primary, trading durability for latency |
| **Amazon S3** | Replicates every object across multiple AZs within a region automatically, by default, with no configuration | Advertises 11 nines of annual durability for exactly the multiplicative-independence reason §4 illustrated; cross-region replication is a separate, optional feature for region-level events |
| **Apache Cassandra / DynamoDB-style stores** | Replication factor is an explicit, per-keyspace/table configuration value, with no single leader coordinating writes | A preview of 16.4's leaderless model — replication factor here is the same N this doc defines, but *how* writes reach all N copies without a leader is answered later |

### ✅ Checkpoint

1. A company stores short-lived session tokens that expire in 15 minutes and can be safely regenerated by asking the user to log in again if they're lost. Using the decision tree and the trade-offs table, propose a replication factor for this data and justify it against both how bad losing it actually is and the cost table's numbers.

   > 💡 *If you hesitate, re-read the decision tree's first branch and the trade-offs table's first row on what extra copies actually buy versus what they cost.*

Given the data is short-lived, cheaply regenerable — worst case, the user just
logs in again — and losing it has genuinely low real-world cost, a low N is
defensible: N=1 (no replication) or a minimal N=2 without cross-region
placement, deliberately declining the storage and write-fan-out cost the
trade-offs table describes. The decision tree's first branch — "is losing
this acceptable, e.g. because it's cheaply re-derivable" — answers yes here,
so the durability that a higher N would buy exceeds what a 15-minute,
trivially-regenerable token actually requires; paying N=3's cost for this
specific data would be over-engineering, not correctness.

> **→ Next:** Can you deliver this cleanly under interview pressure, including when the interviewer pushes on what raw replication doesn't cover?

---

## 8. 🎯 In the Interview

**When an interviewer asks / says:**
- "Walk me through your storage layer's fault tolerance."
- "What happens if a node holding this data goes down?"
- "Why do you need more than one copy of this?"
- "What's your replication factor, and how did you pick it?"

**Where this surfaces — template:**

| Trigger point | What prompts the return to it |
|---|---|
| **1. First appearance** | Right after you name any stateful storage component (a database, a non-derivable cache tier) — the interviewer checks whether you've thought about node failure at all |
| **2. Second appearance** | The moment you say "replicated" or state a replication factor — expect an immediate "why that number" follow-up |
| **3. Third appearance** | If you mention any failure scenario in the design (node crash, region outage), expect a check on whether replication alone actually covers it or you're overclaiming |

**The trade-off statement, broken into a deliverable template — memorize each row, then deliver them in order as one continuous answer:**

| Step | Say this |
|---|---|
| **1. Name the choice** | "I'm keeping N independent copies of this data — replicas — on separate nodes, not just one." |
| **2. Give the mechanism reason** | "That way, no single disk failure or node crash can take the data down with it — as long as one replica survives, the data survives; as long as one node is up, I can still serve it." |
| **3. Price it unprompted** | "The cost is real: N copies means N times the storage, and every write now has to reach N minus one additional nodes — either before I acknowledge it, synchronously, which is safer but slower, or after, asynchronously, which is faster but leaves a small window of risk." |
| **4. Name the switch condition** | "I'd raise N if I need to survive more than one simultaneous failure, or if replicas need to span regions — and I'd push toward synchronous propagation the moment losing even the most recent write becomes unacceptable." |

**A second template — the "isn't this just a backup?" pushback:**

| Step | Say this |
|---|---|
| **1. Name the distinction** | "That's a different mechanism solving a different failure class, and it's worth naming before it's asked." |
| **2. Give the mechanism reason** | "Replication keeps every copy live and current with every write — including a bad one. If an application bug deletes the wrong row, that deletion propagates to every replica exactly as faithfully as a correct write would." |
| **3. Price it unprompted** | "So replication buys me zero protection against logical mistakes — it can't undo a write that was wrong the moment it happened." |
| **4. Name the switch condition** | "For that, I'd pair it with backups — deliberately delayed, restorable snapshots — for continuous durability, backups for recovering from mistakes replication can't." |

**⚠️ Traps**

- ❌ **Trap:** "Replication protects against any kind of data loss, including if someone accidentally deletes or corrupts a record."
  ✅ **Reality:** Replication propagates whatever was written — including a mistake or corruption — to every copy just as faithfully as a good write. That protection comes from backups (20.x), not replication.

- ❌ **Trap:** "More replicas is strictly better, so I'll just set N as high as I reasonably can."
  ✅ **Reality:** Every additional replica adds real storage cost and write fan-out with diminishing fault-tolerance return past what your actual failure-tolerance requirement calls for — N should be chosen against a stated number of simultaneous failures to survive, not maximized (§7).

- ❌ **Trap:** "As long as N≥2, my data is safe no matter where the replicas physically live."
  ✅ **Reality:** N only buys independent-failure protection if the replicas don't share a failure domain — same rack, same power feed, or same AZ can let one event take out several "independent" copies at once (§5, §6).

- ❌ **Trap:** "Replication automatically tells me which copy is current, so reads are simple."
  ✅ **Reality:** Replication only gets you multiple copies — it says nothing on its own about which is authoritative or how a read should choose. That coordination is leader/follower (15.2) or quorum (15.3), a separate mechanism layered on top.

> **→ Next:** Can you combine what you've learned across sections, not just recall each one?

---

## 9. 🧪 Mastery Gate

> *Synthesis only. Each question requires combining two or more sections.*

1. **(§5 + §6)** A team advertises "we replicate to 3 nodes for durability" but uses fully asynchronous propagation with no acknowledgment requirement at all — a pure fire-and-forget write. Using the "Propagation" concept from §5 and the asynchronous-propagation edge case from §6, explain precisely what guarantee this configuration does and does not actually provide the instant a client is told a write succeeded.

2. **(§7 + §3, applied to a system not mentioned elsewhere in this doc)** A photo-sharing app's "recently viewed" list for a user is regenerated on the fly from an activity log if it's ever lost, updates constantly, and briefly serving a stale or even empty list is a non-event for the user. Using the decision tree from §7 and the mindmap's "what it costs" vs. "the two risks it solves" branches from §3, argue for the appropriate replication factor for this specific data, and explain why over-replicating it would be a real mistake, not just unnecessary caution.

3. **(§4 + §5)** A company sets N=3 but deploys all three replicas as three virtual machines running on the same physical host — a real, common cloud misconfiguration. Using the concrete failure-probability example from §4 and the "Failure-Domain Placement" concept from §5, explain precisely why this setup has not actually achieved the failure-probability reduction the §4 example promised.

### Mastery criteria — tick only what you can demonstrate on demand

- [ ] Can name the two independent risks a single copy of data carries (durability, availability) with the specific failure each one guards against
- [ ] Can define replication factor N and justify a chosen N against a stated number of simultaneous node/failure-domain losses to survive
- [ ] Can explain why failure-domain placement — not replica count alone — determines whether N independent copies actually fail independently
- [ ] Can state the real costs of replication (N× storage, (N−1)× write fan-out per write) and explain why replication is not a substitute for backups
- [ ] Can explain, at a high level, why replication alone creates a new coordination problem — which copy is current — that leader/follower (15.2) or quorum (15.3) exists to resolve

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 10. 🔗 Connections & Sources

**Builds on:** **3.6 Share-Nothing Architecture**, whose independent-nodes-no-shared-disk model is exactly the property that makes a replica's failure genuinely independent of the others; and **7.1 Horizontal Partitioning vs. Vertical Partitioning**, whose partitions/shards are the actual unit that gets replicated N times in a real sharded-and-replicated system.

**Enables:** **15.2 Leader/follower model**, the first concrete answer to the coordination problem this doc's §5 names — which copy is current. **15.3 Quorum reads and writes**, the second, count-based answer to the same question. **15.4 Durability guarantees and replication factor**, which goes deep on choosing N precisely. **15.5 Synchronous vs. asynchronous replication trade-offs**, the full depth on the propagation split previewed in §5/§6. **15.6 Replication lag and read anomalies**, what asynchronous propagation's "catching up" window actually looks like, and what it costs readers, in practice.

**Tension with:** **Backups (Topic 20)**, which look similar at a glance — both are about "not losing data" — but solve different failure classes and are genuinely easy to conflate, as Trap 1 in §8 flags directly. Replication gives you continuous, near-real-time durability and availability against hardware failure; it cannot undo a logically bad write. Backups give you recovery from exactly that logical-mistake class, at the cost of losing whatever changed since the last snapshot — production systems need both, not one instead of the other.

### 📚 Further reading

- [ ] **Kleppmann, *Designing Data-Intensive Applications*, Chapter 5 (Replication)** — the foundational treatment of why and how systems replicate data, and the source for most of this subtree's vocabulary (leaders, followers, sync/async propagation)
- [ ] **AWS — "Amazon S3 Storage Classes" and durability documentation** — https://aws.amazonaws.com/s3/storage-classes/ — how a hyperscaler reasons about replication factor and failure-domain placement to advertise 11 nines of durability
- [ ] **PostgreSQL docs — Chapter 27, "High Availability, Load Balancing, and Replication"** — https://www.postgresql.org/docs/current/high-availability.html — synchronous vs. asynchronous streaming replication configured in a real, widely-used system
- [ ] **MongoDB docs — Replication** — https://www.mongodb.com/docs/manual/replication/ — replica sets, write concern, and the majority-acknowledgment default in a production leader-based system

---

## 11. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
