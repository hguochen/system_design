# 15.2 Leader/Follower Model

> **Topic:** Topic 15 — Distributed Storage Systems
> **Phase:** E — Reliability Branch
> **Depth Tier:** 🥇 T1 (Core) — budget ~3h
> **Prereqs:** 15.1 (Replication — Why and How)
> **Date studied:** 2026-08-21

---

## 0. 🧭 The Question This Answers

15.1 established why N independent copies of data exist and how a write reaches all of them — but it deliberately left one question open. The moment more than one copy exists, *something* has to decide the order writes are applied in, and which copy a read should trust as current. Raw replication propagates writes faithfully; it says nothing about arbitrating between two writes that land on different replicas in different orders, or telling a reader which of N copies is "the" answer.

The leader/follower model is the first, and by far the most common, answer to that coordination problem: designate exactly one replica as the sole place writes are accepted, and let every other replica simply apply, in order, whatever that one node did. It's a deliberately narrow design — trading flexibility (any node can take a write) for an unambiguous answer to "which copy is current."

**The question:** *If exactly one replica accepts every write, how does that write actually reach the followers and get served back out to readers — and, critically, what happens to both reads and writes the moment that one replica stops working?*

> **→ Next:** Before the mechanism, what specifically goes wrong if there's no leader at all — no single place writes must go through?

---

## 1. 🎯 Interview Quick Reference Card

> *Not a summary — a live-recall tool, built for retrieval speed under interview pressure. If you need the reasoning behind anything here, that's what §2 (cheatsheet) and the rest of the doc are for.*

**The checklist — walk this on the whiteboard, in order:**

1. Name the coordination problem 15.1 left open, unprompted: with N copies, something must decide write order and which copy is authoritative.
2. State the definition: exactly one node — the **leader** — accepts all writes for a piece of data; every other node — a **follower** — applies writes streamed from the leader, in order, and can optionally serve reads.
3. Name the two read paths and their trade-off, unprompted: read from the **leader** (always current, doesn't scale) or read from a **follower** (scales read throughput, may be stale — 15.6 is the deep dive on that lag).
4. Say what happens to writes during a leader failure, unprompted: writes are unavailable until failover completes — detect the leader is actually gone, elect the most caught-up follower, promote it, repoint clients and remaining followers.
5. Name failover mechanics at a black-box level: heartbeat-timeout detection past a grace period, election among followers, promotion, repointing. Say 18.2 (Raft) is the concrete mechanism underneath "elect."
6. Name the dangerous failure mode, unprompted: **split-brain** — the old leader comes back (e.g. after a partition heals) without being fenced off, and both it and the newly promoted leader accept writes at once. Say 18.5 is the deep dive, and that fencing (a monotonic generation/epoch number) is the mitigation to gesture at.
7. Price it unprompted: the leader is a hard ceiling on write throughput and a single point of write availability; follower reads carry a real staleness bound. Leader/follower buys unambiguous ordering with zero conflict-resolution machinery, at the cost of funneling every write through one place.

**Trigger → action:**

| Interviewer says | You do |
|---|---|
| "How do you keep your replicas consistent with each other?" | Name single-leader: one node accepts writes, streams them to followers in order |
| "What happens if the leader goes down?" | Detect → elect (most caught-up follower) → promote → repoint. Writes pause during that window; any write acknowledged-but-not-yet-streamed under async propagation can be lost |
| "Can you scale your reads with this model?" | Yes — route reads to followers, independent of leader capacity. Trade-off: a real staleness bound (replication lag, 15.6) |
| "Two nodes both think they're the leader — what happened?" | Split-brain, usually an unfenced old leader returning after a partition. Mitigation: fencing — a generation number followers use to reject a stale leader's writes |
| "Is this the only way to replicate data?" | No — orthogonal choices exist: multi-leader (16.2) and leaderless (16.4), each trading this model's unambiguous ordering for concurrent multi-node writes |

**Fast disambiguation — the pairs that get confused live:**

| Pair | The distinction |
|---|---|
| **Leader/follower vs. Quorum (15.3)** | Leader/follower answers *who accepts writes* — exactly one node. Quorum answers *how many replicas must participate* in a given read or write — a separate, count-based question that can even be layered on top of a leader-based system (e.g. requiring a majority of followers to ack). |
| **Failover vs. Split-brain** | Failover is the intended, safe transition to a new leader once the old one is confirmed gone. Split-brain is the failure mode where two nodes simultaneously believe they're leader — usually because the old one wasn't fenced off before a new one was promoted. |
| **Reading from the leader vs. reading from a follower** | Leader reads are always current — nothing can be more current than where writes land first. Follower reads reflect whatever that follower has applied so far, which can lag by a real, non-zero amount under async propagation. |
| **Leader/follower (15.2) vs. Multi-leader (16.2)** | This model funnels every write through one node for an unambiguous order. Multi-leader lets more than one node accept writes — better for concurrent multi-region writers, at the cost of needing conflict resolution (16.3) this model avoids entirely. |

**High-yield anchors:**

```
Roles: 1 leader, N−1 followers (typical)
Write path: client → leader only, never a follower directly
Read path: leader = current; follower = current minus replication lag
Failover: detect (heartbeat + grace period) → elect (most caught-up
  follower) → promote → repoint
Split-brain: 2 nodes both accept writes → diverging data; fixed by
  fencing (generation/epoch numbers)
Async propagation + leader crash: an acknowledged-but-unpropagated
  write can be lost (15.1/15.5)
Deep dives elsewhere: 18.2 (Raft election mechanism), 18.5 (split-brain
  cause & prevention), 15.6 (replication lag & read anomalies)
```

**The script — say this close to verbatim:**

> "I'm using single-leader replication: exactly one node — the leader — accepts every write for this data, applies it locally, and streams it to the followers in the same order it received it. That gives me one unambiguous write order with zero conflict-resolution machinery, and I can scale reads by routing them to followers. The cost is real: the leader is a hard ceiling on write throughput, and follower reads carry a real staleness bound — a client can read data slightly behind the very latest write. If the leader fails, writes are unavailable for the detection-plus-election window — typically low single-digit seconds with an automated, Raft-based election — and I'd fence the old leader explicitly, with a generation number, so that if it comes back it can't accept writes and create a split-brain."

> **If pushed on "why not just let any node take a write and merge conflicts later?":** "Because without a designated leader, two clients writing to two different replicas at nearly the same time produce two different, unordered histories, and clock-based timestamp reconciliation can't cleanly resolve that — clocks skew across machines, and some writes are genuinely concurrent with no true 'later' one. Leader/follower sidesteps the whole problem: the leader's own receive order *is* the order, no reconciliation required."

---

## 2. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*
>
> ⏭️ **First time through this topic?** Skip to §3 and come back here for revision.

```
§ 1  WHY IT EXISTS
15.1 gives you N independent copies but never says which one accepts a
write first. Accept-anywhere designs let concurrent writes land on
different replicas with no shared way to order them, so replicas can
permanently disagree about the truth. Leader/follower removes the
ambiguity by funneling every write through exactly one node.

§ 2  WHAT IT IS
Leader      The one replica currently authorized to accept writes for
            this data.
Follower    Every other replica in the set — applies the leader's
            write stream in order, and can optionally serve reads.
Failover    The procedure that replaces a dead leader: detect, elect,
            promote, repoint.

§ 3  THE MECHANISM
WRITE    always goes to the current leader — applied locally first,
         then streamed to followers in the leader's own order (15.1's
         propagation, with the entry point now pinned down).
READ     to the leader = always current; to a follower = current as of
         that follower's last applied write — a real staleness bound
         (15.6 quantifies it).
FAILOVER heartbeat timeout suspects the leader → grace period rules
         out "just slow" → most-caught-up follower is elected and
         promoted → old leader must be fenced, or split-brain results.

§ 4  USE / AVOID
USE leader/follower whenever writes need one unambiguous order with
  zero conflict-resolution machinery — the default for most OLTP
  systems.
USE follower reads to scale read throughput when some staleness is
  acceptable.
AVOID assuming follower reads are current — they can lag by a real,
  non-zero amount (15.6).
AVOID assuming electing a new leader alone prevents split-brain — the
  old leader must be explicitly fenced (18.5).

§ 5  FAILOVER SEQUENCE
1. DETECT    heartbeat/health check misses past a grace period
2. ELECT     remaining followers/coordinator pick the most caught-up
             one, to minimize data loss
3. PROMOTE   the chosen follower becomes the new leader
4. REPOINT   clients and remaining followers redirect writes to it
5. FENCE     old leader is blocked from accepting writes if it
             returns — skip this step and you risk split-brain

§ 6  NUMBERS TO ANCHOR THE DISCUSSION
Typical automated election time: low single-digit seconds (MongoDB,
  Raft-based systems).
Writes during election: unavailable — a real, bounded gap, not a
  rounding error.
Async propagation + leader crash: any write acknowledged to the client
  but not yet streamed to a follower can be lost — the same gap
  15.1/15.5 name, now tied to a concrete failure moment.

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "How do replicas stay consistent?"     → one leader accepts writes,
                                  followers replay its order
→ "What happens if the leader dies?"     → detect → elect → promote →
                                  repoint; writes paused meanwhile
→ "Can followers take writes too?"       → no — that's multi-leader
                                  (16.2), a different model
GOTCHA: Assuming electing a new leader is the whole story. If the old
  leader isn't fenced off, it can come back still believing it's in
  charge — two nodes both accepting writes at once (split-brain,
  18.5).
```

---

## 3. 🧠 The Mindmap

> *The picture to hold in your head while you study. Everything below hangs off this.*

```
                              ┌───────────────────────────────────────┐
                              │           LEADER / FOLLOWER              │
                              │  "exactly one node says what order       │
                              │   writes happened in"                    │
                              └─────────────────────┬─────────────────────┘
                                                    │
     ┌────────────────────┬─────────────────────────┼─────────────────────┬────────────────────┐
     ▼                     ▼                         ▼                     ▼                     ▼
THE PROBLEM             THE ROLES               FAILOVER,              WHAT IT COSTS         WHERE IT LEADS
IT SOLVES                & PATHS                 AT A GLANCE             / RISKS
───────────────        ───────────────          ───────────────        ───────────────       ───────────────
accept-anywhere          leader = sole            detect (heartbeat      leader = a write      15.3 quorum —
 designs let              write acceptor           + grace period)        throughput            count-based
 concurrent writes        follower = applies       → elect (most          ceiling               refinement
 land on different        leader's stream in       caught-up wins)       follower reads =       15.6 replication
 replicas with no         order, may serve         → promote →            real staleness         lag & anomalies
 shared order             reads                    repoint                bound                 16.1 single-leader
replicas can              write path: ALL          writes are paused     botched failover         failure modes,
 permanently              writes → leader          for the whole          = split-brain            deeper
 disagree about           only, never a            window                                        18.2 Raft —
 what's true              follower directly                                                        leader election
                          read path: leader =                                                     18.5 split-brain
                           current, follower =                                                     cause & prevention
                           maybe stale
```

**How to read it:** The **problem it solves** branch is the *why* — everything else exists to give writes one unambiguous order. The **roles & paths** branch is the *how*, at this subtopic's level of detail — a fixed write path and a forked read path. **Failover, at a glance** is what happens the instant the mechanism's single point of failure actually fails — the sequence §6 unpacks in full. **What it costs** is the honest ledger: this model buys ordering simplicity by accepting a write ceiling, a staleness bound, and a real risk if failover is done wrong. **Where it leads** is this doc's own table of contents into the rest of the reliability trunk — every subtopic there either refines, deepens, or challenges something this doc introduces.

> **→ Next:** Made concrete — what exactly breaks if any replica can accept a write directly, with no leader at all?

---

## 4. 🔥 The Problem

15.1 solved durability and availability with N independent copies and a propagation mechanism, but it left the actual write *entry point* unspecified — "which node handles first-contact writes is itself a design choice this doc leaves open," as its own §6 put it. Nothing in raw replication says which of the N replicas a client should send a write to first, or which replica a reader should trust.

The naive answer is to let it not matter: any replica accepts writes directly from whichever client happens to talk to it, then propagates that write out to the others, same as any other write. This is **accept-anywhere** replication, and it looks harmless until two clients write concurrently to *different* replicas. Say two users both try to register the username "alice" at nearly the same instant — one write lands on replica 1, the other on replica 2. Both replicas apply their local write immediately and report success, because from each replica's own point of view, its write was the only one it saw. Propagation then has to reconcile two writes to the same key with no shared record of which one actually happened first — because neither replica ever knew about the other write until after committing its own. Different replicas can converge to different final answers, or never converge cleanly at all. This isn't a performance problem; it's a correctness bug — two replicas can permanently disagree about who owns "alice," and a reader querying different replicas can see contradictory histories.

The instinctive fix is to attach a timestamp to every write and let "the newer timestamp wins" resolve any collision during propagation. This looks reasonable until it meets two hard problems. First, clock skew: machine clocks drift and are never perfectly synchronized, so "newer" as measured by two different nodes' clocks doesn't reliably reflect what actually happened first. Second, genuine concurrency: two writes can happen close enough together that there is no true "first" — any resolution rule is picking a winner arbitrarily, not discovering one. For data where quietly discarding one of two valid, concurrent writes is dangerous — a bank balance, an inventory decrement, a username registration — arbitrary resolution is not an acceptable answer, and building real conflict-resolution machinery (last-write-wins with proper logical clocks, vector clocks, CRDTs — Topic 16's territory) is a substantial cost most systems would rather avoid if they don't need concurrent multi-node writes in the first place.

The insight that resolves this without any of that machinery: designate exactly one replica the **leader**. Every write, from any client, anywhere, is funneled to that single node. The leader doesn't need to negotiate an order with anyone — the order writes are applied in is simply the order that one node happened to receive them in. Followers then just replay that same order faithfully. The ordering ambiguity accept-anywhere creates disappears entirely, for the price of concentrating every write on one node.

**Before / after:**

```
  BEFORE — accept-anywhere, no leader              AFTER — leader/follower, one entry point
  ────────────────────────────────                  ────────────────────────────────
   client A writes "alice" → Node 1                  client A's write → LEADER (first)
   client B writes "alice" → Node 2 (same time)       client B's write → LEADER (second)

   ✗ Node 1 and Node 2 each apply their write         ✓ the leader sees A's write, then B's —
     locally, with no shared order between them          a real, unambiguous order exists
   ✗ propagation later has no record of which          ✓ followers replay that exact order,
     "alice" write actually happened first                so every replica ends up agreeing
   ✗ replicas can permanently disagree about           ✓ "who registered alice" has one
     who owns the username                                answer, derived from leader order —
   ✗ "fix" = timestamp reconciliation, which             not a reconciliation guess
     clock skew and true concurrency both break
```

### ✅ Checkpoint

1. Two clients concurrently register the username "alice" against two different replicas in an accept-anywhere design with no leader. Using the naive fix's timestamp-ordering idea and its two stated problems, explain why timestamp-based reconciliation doesn't cleanly resolve this case, and what property the leader/follower model gives you instead that timestamps can't.

   > 💡 *If you hesitate, re-read the "instinctive fix" paragraph's two problems (clock skew, genuine concurrency) and the final paragraph's description of what the leader's receive order actually gives you.*

Timestamp reconciliation fails for two independent reasons: machine clocks drift relative to each other, so a "later" timestamp doesn't reliably reflect what actually happened first across two different nodes; and the two registrations may be genuinely concurrent, meaning there is no true "first" write for any timestamp to correctly identify — the rule would just be picking a winner, not discovering one. Leader/follower avoids needing that judgment call at all: because every write is funneled through one node, the order the leader happened to receive the two writes in *is* the real, unambiguous order — no clock comparison or arbitrary tie-break is required, and every follower replaying that same order converges to the same single answer.

> **→ Next:** If the fix is one leader, what does that design actually consist of — the roles, the write path, the read path, and what happens when the leader itself eventually fails?

---

## 5. 💡 The Core Idea

**Leader/follower (single-leader) replication is a replication topology in which exactly one replica — the leader — accepts all writes for a given piece of data, propagates them in the order it received them to every other replica — the followers — and reads may be served by the leader or by any follower depending on how fresh a client needs the answer to be.**

**Visual required:** build-chain diagram.

```
 [LEADER &        ──▶ [THE WRITE PATH —   ──▶ [THE READ PATH —    ──▶ [FAILOVER — SOMEONE
  FOLLOWERS —           EVERY WRITE            TWO VERY               HAS TO REPLACE
  ROLES, NOT             FUNNELS THROUGH        DIFFERENT               THE LEADER]
  HARDWARE]              ONE NODE]              GUARANTEES]              because
   because                because                 because                 the leader is
   §4 showed no            roles exist              writes always           regular
   single node               only if the              land on the             hardware,
   should decide              write path is             leader first —          subject to
   write order on              well-defined                a read has a           every
   its own (§4)               (roles)                       real choice            failure §4
                                                              of node                named
```

### Leader & Followers — Roles, Not Hardware

Builds directly on §4's insight: exactly one node should decide the order writes are applied in. Every replica in a set is assigned one of two roles: exactly one is the **leader**, and every other node is a **follower**. This is a *role*, not a permanent property of specific hardware — §6 shows the role must move to different physical nodes over the system's lifetime, whenever the current leader dies. While a node holds the follower role, it does not accept client writes directly for that data at all — its job is to apply, in order, whatever the leader streams to it, and it can optionally also serve reads (the Read Path, next). A follower is not a permanently second-class machine; it is simply "not currently the leader," and any follower is a candidate to become leader later.

### The Write Path — Every Write Funnels Through One Node

Builds on roles existing at all: because there is exactly one leader, every write for that data — no matter which client sent it, no matter which node the client happened to talk to first — is routed to the leader. The leader applies the write to its own local copy first, giving it a definite position in that node's write-ahead log, then streams it out to the followers in that same order — this is 15.1's propagation mechanism, now with the entry point pinned down to one specific node. Because every write passes through that single node, the order writes are applied in is simply the order the leader happened to receive them — no cross-replica negotiation is needed to establish an ordering, which is exactly the ambiguity §4 showed accept-anywhere designs cannot cleanly resolve.

### The Read Path — Two Very Different Guarantees

Builds on the write path always landing on the leader first: a read, unlike a write, genuinely has a choice of which node to hit. Reading from the **leader** always returns the most recent write, because nothing in the system can be more current than the node writes land on first. Reading from a **follower** returns whatever that follower has applied so far, which under asynchronous propagation (15.1 §5, 15.5's deep dive) can lag behind the leader by a real, non-zero amount of time — the follower might not yet reflect a write the client itself just made. This is the entire reason follower reads exist as an option: they let read traffic scale horizontally across N−1 extra nodes, at the cost of a staleness bound that 15.6 goes on to quantify and manage in depth.

### Failover — Someone Has to Replace the Leader

Builds on all three of the above: because exactly one node holds the leader role, and that node is ordinary hardware subject to every failure §4 named, the system needs a defined procedure for what happens when it dies. **Failover** is that procedure: detect that the leader is actually gone (not just briefly slow), pick a replacement from among the followers, promote it, and repoint clients and remaining followers at the new leader — the exact sequence §6 unpacks step by step. Until failover completes, writes have nowhere correct to go. Get any step of this wrong — promote too early on a false suspicion, promote a follower that wasn't caught up on the leader's latest writes, or fail to fence the old leader from accepting writes if it returns — and the design can end up with two nodes both believing they're leader at once: the **split-brain** failure that 18.5 covers in depth.

### ✅ Checkpoint

1. A junior engineer argues that since any follower can eventually become leader, calling them "followers" instead of just "replicas" is purely cosmetic — they behave identically to the leader at any given instant. Using the "Leader & Followers" concept, explain precisely what is functionally different about a node's behavior while it holds the follower role, at the same instant a leader exists.

   > 💡 *If you hesitate, re-read the second half of "Leader & Followers" — the sentence stating what a follower does and does not do while holding that role.*

It is not cosmetic. At any instant a leader exists, a node holding the follower role does not accept client writes directly for that data — its only job is to apply, in order, whatever the leader streams to it, and it can optionally serve reads. The leader, by contrast, is the node client writes actually reach and get applied to first. The roles only look symmetric in the abstract ("any of them could be leader eventually"); at any given moment, exactly one of them is doing the write-accepting job and the rest are strictly followers of its output — that asymmetry is the entire mechanism this doc is about, not a naming convenience.

2. Trace the link between the write path and failover: explain why promoting a follower that is behind on replication — one that hasn't yet applied the leader's most recent writes — is a risky choice during failover, using both concepts.

   > 💡 *If you hesitate, re-read "The Write Path" on what makes the leader's order authoritative, and "Failover" on the specific risk named for promoting a follower that wasn't caught up.*

"The Write Path" establishes that the leader's own receive order *is* the system's single source of truth for what happened and in what sequence. If failover promotes a follower that hasn't yet applied the leader's most recent writes, the new leader's log is missing writes the old leader had already accepted — those writes are effectively lost from the system's future state, and any client who was told they succeeded was told something that's no longer true. "Failover" names this directly as a real risk: an under-caught-up promotion doesn't just create a slower node, it silently drops committed history, which is why real systems bias promotion toward whichever follower is furthest along in the log rather than picking one arbitrarily.

> **→ Next:** You know the shape of the design. What actually happens, step by step, on a real write and a real failure — and what specifically breaks during each?

---

## 6. ⚙️ How It Actually Works

**Happy path — a write reaches all N replicas, then a later read, N=3 (1 leader, 2 followers):**

1. A client sends a write for key K to whichever node currently holds the leader role — clients and followers alike must know who the current leader is, itself simple bookkeeping most driver libraries or a routing layer handle transparently.
2. The leader applies the write to its own local copy, giving it a definite position in its write-ahead log.
3. The leader streams the write to both followers, tagged with its log position so each follower applies it in that same order.
4. Depending on propagation mode (15.1 §5): **synchronous** — the leader waits for some number of followers to acknowledge before telling the client the write succeeded; **asynchronous** — the leader tells the client success immediately, and propagation continues in the background.
5. Each follower applies the write to its own local copy in log order, converging toward the leader's state.
6. A later read: hitting the leader returns the current value; hitting a follower returns whatever that follower has applied so far — current, minus however much replication lag exists at that instant.

> 🗺️ **Mental model — a single stenographer mailing carbon copies.** The leader is the one authorized scribe writing the official transcript; followers are recipients who receive a mailed carbon copy of each page, in order, as it's written. Anyone can read a carbon copy, but it's only ever as current as the last page that has actually arrived in the mail.
> *Where it breaks down:* mailed carbon copies never "elect a new scribe" on their own if the scribe stops writing — a desk doesn't get automatically reassigned. Real systems must add detection-and-election machinery on top, which this analogy has no notion of. And unlike physical carbon copies handed out once, if two scribes — the original and a hastily appointed replacement — both believe they hold the pen at the same time, they can write two different, diverging "official" transcripts. A stack of carbon copies has no equivalent of two contradictory master documents both claiming to be authoritative.

**Failure & edge cases:**

- **A follower crashing is far cheaper than a leader crashing.** Writes continue uninterrupted through the leader to the remaining followers; the failed follower simply catches up on rejoining, replaying whatever it missed from the leader's log.
- **A leader that's briefly slow or partitioned, but not actually dead, is the dangerous case for premature failover.** A monitor that declares the leader dead after a single missed heartbeat — with no grace period — risks promoting a new leader while the "dead" one is still alive and might still be accepting writes on its own, which is exactly how split-brain starts. Real systems wait out a grace period specifically to rule this out, at the cost of a slower reaction to a genuinely dead leader.
- **Choosing which follower to promote matters.** The follower furthest along in the log — the most caught-up — is the standard choice, to minimize how many committed writes are lost in the transition (the exact risk named in §5's second checkpoint). When multiple followers are tied, a concrete coordination algorithm has to break the tie; Raft's leader election (18.2) is the mechanism most modern systems actually run.
- **Writes are unavailable for the entire detection-plus-election-plus-promotion window.** This is a real, bounded availability gap for writes specifically — not a rounding error, and distinct from the separate durability question of whether an acknowledged write actually survives.
- **Split-brain is what happens when the old leader isn't fenced off.** If a partition heals and the original leader comes back still believing it's in charge, and nothing stops it from accepting writes, the system now has two nodes both accepting writes simultaneously — old leader and newly promoted leader — and the data can diverge in ways plain replication has no way to reconcile. The fix is **fencing**: a monotonically increasing generation (or epoch) number that followers use to reject writes from any leader whose generation is stale. 18.5 is the full treatment.

**Mechanism flow, end to end:**

```
① CLIENT WRITE       ② LEADER APPLIES      ③ STREAM TO           ④ FOLLOWERS APPLY —
   arrives at the  ──▶  & LOGS locally   ──▶  FOLLOWERS         ──▶  converge toward
   current leader                             (sync waits for         leader's state;
                                                acks / async            reads here =
   [reads here =                               doesn't)                current minus lag
    always current]
```

**Structural diagram — failover as a state machine, fenced vs. unfenced:**

```
  FENCED PATH (safe)                              UNFENCED PATH (unsafe — split-brain)

  STABLE                                          STABLE
   leader serves reads+writes,                     leader serves reads+writes,
   followers stream + optionally serve reads        followers stream + optionally serve reads
        │ heartbeat misses × k                           │ heartbeat misses × k
        ▼                                                ▼
  SUSPECTED  ──(leader responds in time)──▶ STABLE  SUSPECTED  ──(leader responds in time)──▶ STABLE
        │ grace period expires, still silent               │ grace period expires, still silent
        ▼                                                ▼
  ELECTING                                         ELECTING
   writes blocked; most caught-up                   writes blocked; most caught-up
   follower selected                                 follower selected
        │ follower promoted                              │ follower promoted
        ▼                                                ▼
  NEW LEADER (writes resume)                       NEW LEADER (writes resume)
        │                                                │
        │  old leader returns ──▶ generation check       │  old leader returns ──▶ NOT checked
        ▼  fails ──▶ REJECTED, demoted to follower        ▼
  STABLE (safe, one leader)                        SPLIT-BRAIN — both old and new leader
                                                     accept writes at once; data diverges
```

### ✅ Checkpoint

1. A design uses synchronous propagation but requires acknowledgment from only 1 of the 2 followers (not both) before telling the client the write succeeded. Using the happy path's steps 2–4, state exactly how many of the 3 total copies (leader + followers) are guaranteed to hold the write the instant the client is told "success," and explain why that number matters for durability if the leader then crashes.

   > 💡 *If you hesitate, re-read step 2 (leader applies locally) and step 4 (synchronous waits for some number of followers) — count the leader's own copy plus however many followers were required to ack.*

Two of the three copies are guaranteed to hold the write at that instant: the leader's own local copy (applied in step 2, before propagation even starts) plus the one follower whose acknowledgment step 4 required. This matters because if the leader crashes immediately afterward, the write survives on the acknowledging follower and can be promoted forward — durability isn't lost. It's a real improvement over pure async (where only the leader might have it), but it's still not the full N=3: the second follower may not have the write yet, so a scenario where both the leader and the one acknowledging follower are lost together would still lose it.

2. A monitoring system declares the leader dead after a single missed heartbeat, with zero grace period, and immediately promotes a follower. Using the "briefly slow, not actually dead" edge case, explain the concrete risk this specific policy creates if the original leader was only momentarily slow rather than truly gone.

   > 💡 *If you hesitate, re-read the edge case describing why a grace period exists and what happens when a "dead" leader might still be accepting writes on its own.*

If the original leader was only briefly slow — a GC pause, a momentary network blip — it is very likely still alive and may still be accepting client writes on its own for however long it takes it to notice it's been replaced. With zero grace period, the monitoring system promotes a new leader while the old one is still functioning, producing exactly the split-brain precondition: two nodes simultaneously believing they're authorized to accept writes, with no fencing step in this policy to stop the old one. The grace period exists precisely to let a merely-slow leader recover and be ruled out before anything is promoted, trading a slower reaction to genuinely dead leaders for avoiding this false-positive risk.

> **→ Next:** You can run this correctly end to end. In a real design, when is single-leader replication actually the right call, and what does it cost you compared to the alternatives?

---

## 7. ⚖️ The Decision

The baseline: leader/follower is the correctness floor whenever writes need one unambiguous order and you don't want to build conflict-resolution machinery — which describes most OLTP workloads by default. The real decision is less "should I replicate this way at all" and more "does this workload's read/write shape and failure tolerance actually fit the trade-offs this model makes."

**Writes need one unambiguous order, and you don't want to engineer conflict resolution.** This is the canonical case — a relational database, an inventory count, anything where two concurrent writes silently overwriting each other is a real bug, not a shrug. Single-leader gives you that ordering for free, as a structural property of the design, not something you build.

**The workload is read-heavy and some staleness is acceptable.** Route reads to followers and scale read throughput horizontally, independent of the leader's own capacity — the leader stays a write bottleneck, but reads stop being one.

**Write throughput itself is the binding constraint, and a single node genuinely can't keep up.** Leader/follower alone doesn't fix this — the leader is a ceiling by design, adding followers only adds durability and read capacity, never write capacity. The actual fix is partitioning (7.x, each shard gets its own leader) or reconsidering the replication model entirely if writes must originate concurrently from multiple places (16.x).

**Near-zero write downtime during a leader failure is a hard requirement.** Invest in fast, reliable failure detection and automated, consensus-based election (18.2's Raft is the concrete mechanism most systems run) — but accept that some bounded write-unavailability window during detection and election is inherent to this model, not an engineering gap you can fully close.

**Decision tree:**

```
        Do writes need one unambiguous order, with no conflict-
        resolution machinery you're willing to build and maintain?
                              │
              ┌──────yes──────┴──────no───────┐
              ▼                                 ▼
   Single-leader is the right          Concurrent multi-region writers
   baseline. Continue below.           are a hard requirement — look at
                                        multi-leader / leaderless (16.x)
                                        instead; this model isn't a fit.
              │
              ▼
   Is the workload read-heavy, with staleness acceptable
   on at least some of those reads?
                              │
              ┌──────yes──────┴──────no───────┐
              ▼                                 ▼
   Route reads to followers —          Route reads to the leader only —
   scale read capacity                 guarantees freshness, but reads
   independent of the leader.          don't scale past leader capacity.
              │                                 │
              └───────────────┬─────────────────┘
                               ▼
              Is near-zero write downtime on leader
              failure a hard requirement?
                               │
              ┌──────yes──────┴──────no───────┐
              ▼                                 ▼
   Invest in fast detection +          Simpler, slower (even manual)
   automated Raft-based election       failover is acceptable — but the
   (18.2) — a bounded gap still        write-unavailability window
   remains, just a small one.          during it will be longer.
```

**Trade-offs**

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Every write gets one unambiguous, deterministic order** with zero cross-node coordination or conflict-resolution machinery at write time | **The leader is a hard ceiling on write throughput** — adding followers never raises it, only read capacity and durability go up |
| **Reads scale horizontally across N−1 followers**, independent of leader capacity | **Follower reads carry a real staleness bound** (replication lag, 15.6) — a client can read data older than what it itself most recently wrote |
| **Failover gives an automatic recovery path** when the leader dies, keeping the system self-healing rather than requiring a human on call | **The write path has a real, bounded unavailability window** during detection + election + promotion, and a botched failover (unfenced old leader) risks split-brain (18.5) |
| **No conflict-resolution machinery to design, test, or reason about** — LWW, vector clocks, and CRDTs are all Topic 16 problems this model avoids entirely | **All writes must physically route to wherever the leader lives**, which taxes latency for writers far from it — a poor fit for concurrent, low-latency multi-region writes |

**In production**

| System | How it applies | The nuance |
|--------|----------------|------------|
| **PostgreSQL primary/standby** | One primary accepts all writes; standbys apply a streamed write-ahead log and can optionally serve reads | Automated failover isn't built in — tools like Patroni or repmgr add detection and election, often using a consensus store (etcd) to avoid two primaries at once |
| **MySQL source/replica** | One source accepts writes; replicas apply a binlog stream, either asynchronously or via semi-sync plugins | External tooling (Orchestrator, MHA) handles failure detection and promotion; misconfigured failover here is a classic real-world split-brain source |
| **MongoDB replica sets** | Members automatically elect a primary using a Raft-derived protocol; a `priority` setting biases which member is preferred | Election typically completes in a few seconds; a member with `priority: 0` can never become primary — useful for keeping a geographically distant replica read-only |
| **Apache Kafka** | Each partition has its own leader among that partition's replica set — not one leader for the whole cluster | The "in-sync replica set" (ISR) generalizes the followers-must-be-caught-up idea; a cluster controller (itself elected via consensus, KRaft in modern versions) manages elections across every partition |

### ✅ Checkpoint

1. A social app needs a user's follower count updated with a single, unambiguous increment order — two simultaneous follows must never silently overwrite each other into a wrong count — but the workload is read-dominated roughly 1000:1, and a follower count that's a few hundred milliseconds stale is completely acceptable to display. Using the decision tree and the trade-offs table, decide whether single-leader replication fits this workload, and specify how you'd route reads and writes to get the specific benefit this workload needs.

   > 💡 *If you hesitate, re-read the decision tree's first branch (unambiguous order, no conflict resolution) and its second branch (read-heavy, staleness acceptable → route reads to followers).*

Single-leader fits well. The requirement that two simultaneous follows never silently overwrite each other maps directly onto the decision tree's first branch: this data needs one unambiguous write order without building conflict-resolution machinery, which is exactly what routing every increment through the leader gives you for free. The second branch then applies just as cleanly: the workload is heavily read-dominated and explicitly tolerates staleness, so reads should route to followers to get the trade-offs table's read-scaling benefit — the leader stays the sole path for writes (protecting correctness), while the 1000:1 read volume is scaled horizontally across followers instead of bottlenecking on the leader, at the acceptable cost of a few-hundred-millisecond staleness window on the displayed count.

> **→ Next:** Can you deliver this cleanly under interview pressure, including when the interviewer pushes on what happens during a failure?

---

## 8. 🎯 In the Interview

**When an interviewer asks / says:**
- "How do you keep your replicas consistent with each other?"
- "What happens if your primary database goes down?"
- "Can you scale your reads?"
- "Walk me through failover."

**Where this surfaces — template:**

| Trigger point | What prompts the return to it |
|---|---|
| **1. First appearance** | Right after naming a replicated datastore — often immediately following 15.1's "what's your replication factor" question |
| **2. Second appearance** | The moment you say "reads can go to replicas" — expect an immediate staleness follow-up |
| **3. Third appearance** | Any "what if the database goes down" question — expect a check of exactly what's unavailable, for how long, and what could be lost |

**The trade-off statement, broken into a deliverable template — memorize each row, then deliver them in order as one continuous answer:**

| Step | Say this |
|---|---|
| **1. Name the choice** | "I'm using single-leader replication — exactly one node accepts writes for this data, and followers apply the same write stream in order." |
| **2. Mechanism reason** | "That gives every write one unambiguous, deterministic order with no conflict-resolution machinery, and I can scale reads by routing them to followers." |
| **3. Price it unprompted** | "The leader is a hard ceiling on write throughput, and follower reads carry a real staleness bound. If the leader fails, writes are unavailable for the detection-plus-election window — typically low single-digit seconds with an automated election." |
| **4. Switch condition** | "I'd move to multi-leader or leaderless replication the moment I need concurrent, low-latency writes from multiple regions at once — this model forces every write through one place." |

**A second template — the "what actually happens during failover" pushback:**

| Step | Say this |
|---|---|
| **1. Name the distinction** | "Failover has two phases worth separating: detecting the leader is actually gone, and electing plus promoting its replacement." |
| **2. Mechanism reason** | "Detection uses a heartbeat timeout with a grace period, specifically so a leader that's briefly slow isn't mistaken for one that's dead. Election picks the most caught-up follower to minimize data loss, then repoints clients and remaining followers at it." |
| **3. Price it unprompted** | "Writes are unavailable for that whole window — and under asynchronous propagation, any write the old leader had acknowledged but not yet streamed to a follower can be lost." |
| **4. Switch condition** | "I'd explicitly fence the old leader — reject writes from a stale generation number — the moment I need a guarantee against split-brain, rather than assuming it simply stays down." |

**⚠️ Traps**

- ❌ **Trap:** "Followers can also accept writes directly, we just replicate them out afterward."
  ✅ **Reality:** That's multi-leader, not leader/follower. In this model only the leader accepts writes — a follower taking a write directly recreates the exact accept-anywhere ordering problem §4 showed breaks down.

- ❌ **Trap:** "Reads from a follower are just as current as reads from the leader."
  ✅ **Reality:** Follower reads lag by however much replication delay currently exists; only reads from the leader are guaranteed current (§5, §6).

- ❌ **Trap:** "Failover is basically instantaneous, so there's no real availability impact."
  ✅ **Reality:** There's a real, bounded write-unavailability window while the system detects the failure and elects and promotes a replacement (§6) — often low single digits of seconds, sometimes longer.

- ❌ **Trap:** "As long as a new leader gets elected, split-brain can't happen."
  ✅ **Reality:** It can, if the old leader isn't explicitly fenced off. Electing a replacement says nothing about stopping the old leader from still accepting writes if it comes back without being told to step down (§6, 18.5).

> **→ Next:** Can you combine what you've learned across sections, not just recall each one?

---

## 9. 🧪 Mastery Gate

> *Synthesis only. Each question requires combining two or more sections.*

1. **(§5 + §6)** A team's monitoring declares the leader dead after exactly one missed heartbeat with zero grace period, and immediately promotes whichever follower responds first — without checking how caught-up it is. Using the "Failover" concept from §5 and the promotion / split-brain edge cases from §6, name the two independent failure modes this specific policy risks creating, and explain why they are genuinely separate risks rather than the same problem twice.

2. **(§7, applied to a system not mentioned elsewhere in this doc)** A flight-booking service must guarantee that two customers can never both successfully book the last seat on a flight — one unambiguous order, no silent overwrite — while read traffic (customers browsing the seat map) outweighs booking writes by roughly 200:1, and a few hundred milliseconds of staleness on the seat map view is acceptable. Using the decision tree and trade-offs table from §7, decide whether single-leader replication fits this system, and specify exactly which operations should route to the leader and which to followers.

3. **(§4 + §8)** An interviewer asks, "why not just let any node accept writes and merge conflicts later using timestamps?" — the exact concern §4 raised early in this doc. Using §4's two-part argument against timestamp reconciliation and §8's "name the choice, then price it unprompted" delivery structure, give a concise spoken answer that both rejects the naive fix and states what leader/follower buys instead.

### Mastery criteria — tick only what you can demonstrate on demand

- [ ] Can explain leader/follower replication, including exactly what happens to reads and writes during a leader failure
- [ ] Can explain why an accept-anywhere design with no leader creates an ordering problem that timestamps can't cleanly resolve, and what leader/follower gives you instead
- [ ] Can state the difference between reading from the leader and reading from a follower, and name the guarantee each one gives
- [ ] Can walk through the failover sequence (detect → elect → promote → repoint → fence) and state exactly what's unavailable, and at risk, during it
- [ ] Can explain what split-brain is, how an unfenced failover causes it, and name fencing as the mitigation
- [ ] Can judge, given a workload's ordering requirement and read/write ratio, whether single-leader replication is the right fit and how to route its reads and writes

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 10. 🔗 Connections & Sources

**Builds on:** **15.1 Replication — Why and How**, which established N independent copies and the propagation mechanism between them, but explicitly left open "which copy is current, and how does a read choose" — this doc is single-leader replication's answer to exactly that question.

**Enables:** **15.3 Quorum reads and writes**, a complementary, count-based refinement that can layer on top of the pure leader model (e.g. requiring a majority of followers to acknowledge before a write commits). **15.6 Replication lag and read anomalies**, the direct deep dive into the follower-read staleness this doc introduces but doesn't quantify. **16.1 Single-leader replication — recap and failure modes**, which extends this doc's failure-mode treatment further. **18.2 Raft — leader election**, the concrete consensus algorithm behind the black-boxed "elect a new leader" step in §6.

**Tension with:** **16.2 Multi-leader replication**, which relaxes the single-writer constraint this doc establishes as its core simplification — at the direct cost of needing conflict resolution (16.3), the exact machinery this doc's §4 argued single-leader lets you avoid. **18.5 Split-brain — cause and prevention**, the dark failure mode this doc's §6 names but only partially resolves (fencing, at a black-box level) — 18.5 is where the mechanism is actually built out.

### 📚 Further reading

- [ ] **Kleppmann, *Designing Data-Intensive Applications*, Chapter 5 — "Leaders and Followers"** — the specific section of the replication chapter this doc's model comes from, including its treatment of failover risks
- [ ] **The Raft Consensus Algorithm** — https://raft.github.io/ — an interactive visualization of exactly the leader-election mechanism this doc black-boxes into "elect"; useful preview before 18.2
- [ ] **MongoDB docs — Replica Set Elections** — https://www.mongodb.com/docs/manual/core/replica-set-elections/ — a real, production election protocol, including `priority` and how ties are broken
- [ ] **Apache Kafka documentation — Replication** — https://kafka.apache.org/documentation/#replication — per-partition leaders and the in-sync replica set (ISR), a variant worth contrasting with whole-cluster leader/follower

---

## 11. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
