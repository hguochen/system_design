# 2.5 Consistency vs. Availability — Spectrum of Trade-offs

> **Topic:** Topic 2 — System Design Core Principles & Scalability Fundamentals
> **Phase:** A — Core First Principles
> **Date studied:** 2026-04-27

---

## 1. 🎯 Goal of This Subtopic

> *Why are you studying this? What should you be able to do after this session?*

- Be able to place any system requirement on the **consistency ↔ availability spectrum** and justify the placement with a concrete failure scenario (network partition, replica lag, write conflict).
- Understand why "consistency" and "availability" are not binary — they live on a *spectrum* with at least 5–6 named consistency levels (linearizable, sequential, causal, read-your-writes, monotonic, eventual) and corresponding availability postures.
- Identify when **eventual consistency is the correct choice** over strong consistency, and articulate at least three scenarios where this is true.
- Translate business requirements ("user must see their own posts immediately", "shopping cart must never lose items", "bank transfers must never double-spend") into the right consistency level.
- Walk through a consistency/availability trade-off out loud in a structured way: name the forces, state your assumption, make a choice, explain the cost.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [x] Can name the **6 main consistency levels** in order of strictness and give one real system example for each (linearizable → eventual).
- [x] Can classify any given system requirement (e.g. "user profile update", "view count", "payment ledger") into the right consistency level and justify why.
- [x] Can explain **at least three concrete scenarios where eventual consistency is the right choice** (e.g. social feed timestamps, view counts, DNS) and three where it is wrong (e.g. inventory decrement, bank balance, unique username).
- [x] Can describe the **operational cost** of strong consistency: higher latency, lower throughput, reduced availability under partition, more complex coordination.
- [x] Can explain why "consistency vs. availability" is not the same trade-off as CAP — CAP only kicks in *during* a partition; the spectrum exists *all the time*.
- [x] Can articulate the trade-off statement out loud in under 30 seconds for any given system.

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [x] Read DDIA Chapter 5 ("Replication") — sections on consistency models, read-your-writes, monotonic reads.
- [x] Read DDIA Chapter 9 ("Consistency and Consensus") — sections on linearizability and ordering guarantees.
- [x] Read Jepsen's "Consistency Models" page — https://jepsen.io/consistency
- [x] Read Werner Vogels' "Eventually Consistent" — https://www.allthingsdistributed.com/2008/12/eventually_consistent.html
- [x] Watch "ByteByteGo — Strong vs Eventual Consistency" on YouTube.
- [x] Read through **Sections 5–9** (Core Definition → How It Works) carefully — don't skim
- [x] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [x] Close the doc — write out the **Core Definition** from memory, then compare
- [x] Explain **First Principles** out loud without notes — what problem does this solve and why?
- [x] Reconstruct the **How It Works** mechanics step by step from memory
- [x] Restate each **Trade-off** row in your own words — if you can't explain the cost, you don't own it yet

### Phase 3 — Apply 🔧 💪💪💪💪
*Goal: Connect to real systems and simulate interview scenarios.*

- [x] Go through **Real-World System Examples** (Section 10) — verify each claim independently and add anything missed to **My Notes**
- [x] Practice the **Interview Application** (Section 12) out loud — say the trigger phrases and your response as if in a live interview
- [x] Work through **Common Misconceptions** (Section 13) — for each, make sure you can explain *why* the misconception is wrong, not just that it is
- [x] Trace the **Relationships to Other Concepts** (Section 14) — can you explain each connection without looking?

### Phase 4 — Validate 🧪 💪💪💪💪💪
*Goal: Confirm you actually own it, not just recognize it.*

- [x] Answer every **Self-Check Quiz** question (Section 15) out loud without looking at your notes
- [x] Recite the **Cheatsheet** (Section 4) from memory — if you can't, re-do Phase 2
- [x] Tick off items in **What Mastery Looks Like** (Section 2) — only check a box if you can demonstrate it on demand, not just if it sounds familiar
- [x] Teach this concept out loud to an imaginary interviewer for 2 minutes without hesitation or notes

---

## 4. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

```
ONE-LINER
  Consistency and availability live on a SPECTRUM, not a binary —
  the stronger your consistency guarantee, the more availability,
  latency, and throughput you trade away.

KEY PROPERTIES / RULES
  - Consistency levels (strict → loose): Linearizable > Sequential >
    Causal > Read-your-writes > Monotonic > Eventual.
  - Stronger consistency = more coordination = higher latency,
    lower availability (especially under partition), lower throughput.
  - "Eventual" means replicas converge IF writes stop — not "soon."
    There is no SLA on convergence by default.
  - Different *operations* in the same system can sit at different
    points on the spectrum (e.g. payments = strong, view counts = eventual).
  - Consistency choice is a per-operation decision, not a system-wide one.

DECISION RULE
  Use STRONG consistency when: correctness depends on a single source of
    truth (money, inventory, unique IDs, locks, leader election).
  Use EVENTUAL consistency when: stale reads are acceptable, the user
    can tolerate seconds of lag, and you need high availability or low
    latency at scale (feeds, view counts, recommendations, DNS, social).

NUMBERS / FORMULAS
  - Quorum tunability: R + W > N → strong consistency.
                       R + W ≤ N → eventual consistency, lower latency.
  - Strong consistency typically costs ≥ 1 cross-region RTT (~50–200ms)
    on writes; eventual consistency can be < 5ms locally.
  - Linearizability requires consensus (Paxos/Raft) — 2 RTTs in the
    common case, more under failures.

GOTCHA TO NEVER FORGET
  "Eventual consistency" is NOT a single thing — it's the LOOSEST
  level on the spectrum. Most production "eventual" systems offer
  stronger guarantees (read-your-writes, monotonic reads, causal),
  and you should always ask which.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

The **consistency vs. availability trade-off** is the spectrum of guarantees a distributed system can offer about how synchronized its replicas appear to clients — where stronger consistency requires more coordination between replicas (raising latency and reducing availability under failure) and weaker consistency allows replicas to diverge temporarily in exchange for lower latency and higher availability.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*

### Linearizability (Strong Consistency)
The strictest practical consistency model: every operation appears to take effect *atomically at some point between its invocation and response*, and all clients see operations in the same real-time order. Linearizability makes a distributed system appear as if there is a single copy of the data. Once a write completes (acknowledged by quorum), every subsequent read — from any node, anywhere — must return that value. The write appears to take effect at a single atomic instant in real wall-clock time. This requires coordination (consensus or quorum) on every operation, which adds latency and reduces availability under partition. **Example:** Spanner's external consistency, etcd, ZooKeeper. Required for distributed locks, leader election, unique-ID generation. Costs at least one consensus round per write.

Analogy: you deposit $100 at New York. New York doesn't confirm until at least a quorum of branches (e.g. London) acknowledge the write. Once confirmed, any branch you walk into — including Tokyo — returns the updated balance.

### Sequential Consistency
**Sequential** guarantees all clients see operations in *some* total order, but that order may not match real time. Sequential consistency relaxes one thing: the wall clock requirement. Operations still appear to happen in some sequential order that all nodes agree on, and each individual client's operations appear in the order that client issued them - but that order doesn't have to match real time. So if Alice writes X=1 at 10:00:00.000 and Bob reads X at 10:00:00.001, Bob is not guaranteed to see 1. What's guaranteed is that all nodes see the same history, just not necessarily the real-time history. **Example:** Kafka(within a partition)

The practical implication: you can get away without synchronized clocks and global coordination, but you can still get "stale" reads from another client's perspective even though no node disagrees about the ordering.

Analogy: You deposit $100 at New York at 9:00am. London and Tokyo replicate asynchronously — at 9:05am, both Tokyo and London are still showing the old balance. That's fine under sequential consistency. But here's the key: when your deposit finally arrives, it arrives at London AND Tokyo in the same position in their transaction history. If Tokyo's ledger shows: [deposit $200, deposit $100], London's ledger must show the exact same order: [deposit $200, deposit $100] — never [deposit $100, deposit $200]. All branches agree on the same history, just potentially a delayed one.

### Causal Consistency
**Causal** is even weaker than Sequential: It only enforces ordering for operations that are **casually related** - meaning one operation could have influenced the other. If Alice writes X=1 and then Bob reads X=1 and then writes Y=2 (so Y=2 is caused by seeing X=1), then any node that shows Bob's write Y=2 must also show Alice's write X=1. Cause must precede effect. But two concurrent, unrelated writes — say Alice updates her username and Carol updates her bio at the same moment with no dependency between them — can be seen in any order on different replicas. That's fine, because neither caused the other.

Under causal consistency, if two operations are causally related (one could have been influenced by the other), all nodes must observe them in the same cause-before-effect order. For concurrent, unrelated operations, different nodes are free to apply them in different orders — both orderings are valid because neither write caused the other. The cost is much lower than linearizability: you only need to track causal dependencies (via vector clocks or logical timestamps), not coordinate globally on every operation. Useful for chat/social systems where reply-ordering matters but global ordering doesn't.

**Example:** MongoDB causal sessions / Facebook comments

Analogy: 
- you walk into New York branch to deposit $100.
- your wife walks into Tokyo branch and sees your $100 deposit, she withdraws $80.
- your sister walks into London branch and sees $80 withdrawal, so she must also see the $100 deposit

### Read-Your-Writes
**Read-your-writes** ensures a client always sees its own writes (e.g., after editing your profile, the next page load shows the edit even if the cache is stale to others). **Example:** Twitter tweet posts

Analogy: You deposit $100 at New York. Immediately after, you check your balance — the system routes you back to New York (or a replica that has already received your write), so you see the $100 deposit right away. London may still show the old balance. But that's fine, because the guarantee only covers you — other clients asking London will see stale data, but you personally will always be served from a node that has your write.

### Monotonic Reads
*Monotonic reads* ensures a client never sees time go backward (you don't see version v3 then v2). Implemented via session tokens, sticky routing, or write-through caches. **Example:** DynamoDB's with session tracking

### Eventual Consistency
Eventual consistency is the loosest guarantee on the spectrum: if writes stop, all replicas will converge to the same value — but there is no SLA on when, and no guarantee about what a read returns during the convergence window. In practice, convergence typically happens within milliseconds to seconds in well-designed systems. What it does NOT guarantee: two consecutive reads can return different values, two clients can see different values simultaneously, and there is no ordering constraint on unrelated operations. The trade-off is maximum availability, minimum latency, and zero coordination overhead — making it the right choice when brief staleness has no business cost. DNS is the canonical example: a domain record update may take minutes to propagate globally, and that's intentional — availability and scale take priority over instant consistency. **Example:** DNS propagation, S3 (was eventual until 2020, now strongly consistent), Cassandra at default tunable settings, Amazon Cart.

### Tunable Consistency (Quorums)
Systems like Cassandra, DynamoDB, Riak let you choose the consistency level *per operation* by tuning read quorum (R), write quorum (W), and replica count (N). When `R + W > N`, you guarantee read-after-write consistency (any read sees the latest write). When `R + W ≤ N`, you get eventual consistency with better latency. **Why it matters:** You don't pick consistency for the whole system — you pick it per query.

### Availability (in this context)
The probability that a request receives a non-error response within a bounded time. Crucially, this is *separate* from "uptime" — a system that returns stale or rejected data is still "down" in the availability sense. Strong consistency systems often sacrifice availability under partition (CP) by refusing to serve stale reads; eventual consistency systems (AP) keep serving even when replicas disagree.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

The root problem is the **speed of light combined with hardware failure**. In a single-machine database, consistency is "free" — there is one copy, one clock, one truth. The moment you replicate data across machines (for durability, for read scalability, for geographic distribution), you introduce a fundamental tension: to keep replicas in sync, they must coordinate; to coordinate, they must communicate; communication takes time and can fail.

If you demand that all replicas always agree before responding to a client (strong consistency), you pay the round-trip cost on every write *and* you cannot make progress when replicas can't talk (network partition, slow link, dead node) — your system becomes unavailable. If you let replicas respond independently and reconcile later (eventual consistency), you serve writes fast and stay available, but clients can read stale or conflicting data.

The **spectrum** exists because real applications have wildly different tolerances for staleness vs. unavailability. Showing a slightly outdated tweet count is fine; showing a stale bank balance is not. So the field developed *intermediate* models (causal, read-your-writes, monotonic) that give you "just enough" consistency for a specific use case without paying the full coordination cost. The trade-off is unavoidable — physics and probability of failure dictate it — but the *granularity* of choice is what engineering invented.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*

### Model 1: The Sliding Dial
Imagine a single dial on your system, with **strong consistency** on one end and **eventual consistency** on the other. Sliding toward strong: latency goes up, availability goes down, throughput drops, complexity rises. Sliding toward eventual: latency drops, availability rises, throughput climbs, but stale and conflicting reads become possible. The dial is **not binary** — there are many positions (linearizable, sequential, causal, RYW, monotonic, eventual). You can also have *different dials per operation* in the same system.

**Why it works:** It captures that this is a continuous engineering decision, not a flag. **Where it breaks down:** It implies a single tunable axis, but in reality you're juggling several (durability, latency, partition tolerance, conflict resolution policy) — the dial is a useful simplification, not the whole truth.

### Model 2: The Bank vs. Twitter Test
Ask of any feature: *"If a user sees a stale value here, is it embarrassing or catastrophic?"* If catastrophic (double-spending money, selling the last item twice, two users claiming the same username) → strong consistency. If embarrassing or invisible (post count off by 1 for 3 seconds, like count slightly stale, follower list slightly behind) → eventual consistency is fine. Bank = strong. Twitter = eventual (mostly).

**Why it works:** It anchors the decision in *user impact*, not in technology. **Where it breaks down:** Some operations look like Twitter but are secretly Bank — e.g., "follow this user" might allow duplicate writes that bloat your DB; "view count" might affect ad billing and need stronger guarantees than you think. You still have to ask "what's the actual cost of staleness?"

### Model 3: The Whiteboard Lag
Imagine each replica is a person with their own whiteboard, copying state from each other. Strong consistency = everyone must update simultaneously and confirm before any reader can look (slow, blocking, fragile under disconnection). Eventual consistency = each person updates their own board on their own time and reconciles later (fast, available, sometimes wrong). The "consistency level" you pick is essentially: *how out of sync are these whiteboards allowed to be when a reader walks up?*

**Why it works:** Makes replica divergence physical and intuitive. **Where it breaks down:** Real replicas don't just "copy" — they handle conflicting concurrent updates (e.g., two people editing the same cell). The whiteboard model under-represents conflict resolution.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

**The mechanics of a write at different consistency levels (assume 3 replicas, A/B/C):**

**Linearizable write (strong):**
1. Client sends write to leader (or any replica that forwards to leader).
2. Leader proposes the write via a consensus protocol (Raft/Paxos).
3. Leader waits for majority (2 of 3) acknowledgments.
4. Leader commits and replies to client.
5. Subsequent reads — even from followers — must read through leader or use a read index to guarantee they see the latest committed value.
- **Cost:** ≥ 1 consensus round (typically 2 RTTs in the common case). Under partition, the minority side cannot accept writes → reduced availability.

**Quorum-based write (tunable):**
1. Client sends write to coordinator.
2. Coordinator forwards to all N replicas concurrently.
3. Coordinator waits for **W** acknowledgments (configurable: 1, 2, or 3).
4. Replies success once W replicas confirm.
- For reads: coordinator queries **R** replicas, returns most recent value (by timestamp or vector clock).
- **R + W > N** → guaranteed overlap → strong consistency.
- **R + W ≤ N** → may miss recent write → eventual consistency.
- Tunable per-query: same DB can serve `(R=1, W=1)` for view counts and `(R=3, W=3)` for payments.

**Eventual consistency write (async):**
1. Client sends write to any replica.
2. That replica accepts immediately and responds.
3. Replica asynchronously gossips the write to peers (or peers pull it).
4. Conflicts (concurrent writes to same key) resolved via:
   - **Last-write-wins** (timestamp-based — risky with clock skew)
   - **Vector clocks** (track causal history; surface conflicts to app)
   - **CRDTs** (mathematically guaranteed convergent merge)
- **Cost:** Single replica round-trip, very low latency. Reads may return stale data. Conflicts must be reconciled.

**Failure handling:**
- Strong consistency: under partition, side with no majority refuses writes (CP behavior).
- Eventual consistency: every replica keeps accepting, divergence resolved on heal via anti-entropy (Merkle trees, read-repair, hinted handoff).
- **Critical formula:** *Time to convergence after partition heals* = `O(divergence_size / gossip_bandwidth)`. Can be seconds to hours depending on workload.

**Numbers worth remembering:**
- Linearizable write in a regional cluster: ~5–20ms.
- Linearizable write across regions (e.g., Spanner global): ~50–200ms (bound by speed of light).
- Eventual write to nearest replica: ~1–5ms.
- Quorum read with `R=2, N=3`: ~2x latency of single-replica read (waits on slowest of 2).

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| **Google Spanner** | Offers **external consistency** (≈ linearizability) globally using TrueTime + Paxos. Pays cross-region commit latency (~50–150ms) for global strong consistency on every write. | Used for AdWords, Gmail metadata. The TrueTime API (GPS + atomic clocks) is what makes this feasible without unbounded latency. |
| **Amazon DynamoDB** | Offers **two read modes per operation**: eventually consistent (default, half the cost, single-replica read) or strongly consistent (full cost, read through quorum). Writes are quorum-replicated. | Same data store, two consistency levels — chosen at query time. Default eventual to encourage cheap reads. |
| **Apache Cassandra** | **Tunable consistency** via R, W, N parameters per query. Common configurations: `LOCAL_QUORUM` (datacenter-local quorum), `ONE` (single replica, eventual), `ALL` (every replica, strict). | Used by Netflix, Apple, Discord. Designed AP-first; strong consistency is opt-in and expensive. |
| **etcd / ZooKeeper** | Pure linearizable systems via Raft / ZAB. Used for service discovery, distributed locks, leader election — places where stale reads are dangerous. | Sacrifices availability under partition (CP). A 5-node cluster losing 3 nodes goes read-only. |
| **DNS** | **Aggressively eventually consistent** — TTL-bounded staleness measured in minutes to days. Trades freshness for massive read scalability and availability. | Famous example: stale records can persist for hours after a change. Acceptable because most lookups don't need real-time accuracy. |
| **Amazon S3** | Was eventually consistent for years (read-after-write for new keys, eventual for overwrites/deletes). **Switched to strong read-after-write consistency in Dec 2020** at no latency cost — a major engineering achievement. | Shows that the trade-off boundary moves over time as engineering improves. Don't assume yesterday's "eventual" system is still eventual. |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Strong consistency simplifies application logic — no conflict resolution, no stale-data handling, no anti-entropy code paths. | Higher write latency (≥ 1 consensus RTT), reduced availability under partition (minority side refuses writes), and lower max throughput because writes serialize through a leader or quorum. |
| Eventual consistency gives very low latency and very high availability — every replica can serve reads/writes locally. | The application *must* handle stale reads, conflict resolution, and out-of-order events. Bugs from stale data are subtle and may only appear under load or partition. |
| Tunable consistency (per-op choice) lets you spend coordination budget where it matters and save it everywhere else. | Operational complexity: each query author must understand consistency implications. Easy to get wrong silently — e.g., dev defaults to eventual when payment logic needs strong. |
| Session-level guarantees (read-your-writes, monotonic) bridge the gap cheaply — most user-facing surprises (UI stale after own edit) disappear. | Requires routing infrastructure (sticky sessions, session tokens) that may break under load balancer reshuffling, scale-out, or client device changes. |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- *"How do you ensure users see their own posts immediately after publishing?"* → Read-your-writes consistency.
- *"What if two users simultaneously try to buy the last item in stock?"* → Strong consistency / linearizability for the inventory decrement.
- *"How does this system behave during a network partition?"* → CAP + spectrum: which operations stay available, which become unavailable, what staleness do users experience?
- *"Why are you using eventual consistency here? Isn't that risky?"* → Justify with concrete user impact: staleness is invisible / acceptable for this read.
- *"Walk me through how a like count is computed and shown."* → Eventual consistency, with the option to add monotonic reads to avoid backward-going counts.

**What you say / do:**
This concept appears most powerfully in the **deep-dive and trade-off discussion phase** of a design interview — typically after you've sketched the high-level architecture and the interviewer probes correctness or scaling. Bring it up *per operation*, not per system: "For this operation, I'd use X consistency because Y. For that other operation, I'd relax to eventual because Z." Always tie the choice to a *concrete user-facing or business consequence*.

**The trade-off statement (memorize this pattern):**
> "If we choose **strong consistency**, we get **correctness guarantees and simpler application logic**, but we pay **higher write latency, reduced availability under partition, and lower throughput**. For this **payment / inventory / unique-ID** operation, strong consistency is the right call because **a stale read causes double-charging / overselling / duplicates**, and that's a real-money correctness bug that no amount of UX recovery can fix."
>
> "If we choose **eventual consistency**, we get **low latency, high availability, and horizontal scalability**, but we pay **stale reads and conflict resolution complexity**. For this **like count / feed / view tracker** operation, eventual is the right call because **a few seconds of staleness is invisible to users and the volume requires single-replica writes**."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** "Eventual consistency means data converges 'soon' — like within a second."
  ✅ **Reality:** Eventual has *no SLA on convergence*. A partitioned replica may diverge for hours. Most production systems layer a stricter model on top (read-your-writes, monotonic, bounded staleness) and quote convergence times empirically — but that's an implementation choice, not a property of "eventual."

- ❌ **Misconception:** "I have to pick one consistency level for the whole system."
  ✅ **Reality:** You pick consistency *per operation*. A single product (say, a ride-share app) may use linearizable consistency for payments and driver-assignment, causal consistency for chat messages, and eventual consistency for ride history feed — all in the same backend.

- ❌ **Misconception:** "CAP theorem is about consistency vs. availability."
  ✅ **Reality:** CAP is about consistency vs. availability **specifically during a network partition**. The consistency-vs-availability trade-off discussed here exists *all the time*, even when nothing is broken — strong consistency costs latency on every write, not just during partitions. PACELC captures this distinction explicitly.

- ❌ **Misconception:** "Strong consistency is always 'better' — pick it whenever you can afford it."
  ✅ **Reality:** Strong consistency has a *real availability and latency cost* even on the happy path. For most read-heavy, user-facing workloads (feeds, search, analytics), eventual consistency is *the right answer* — not a compromise. Defaulting to strong is a junior anti-pattern.

- ❌ **Misconception:** "Read-your-writes consistency is the same as strong consistency."
  ✅ **Reality:** Read-your-writes is *session-scoped*: a user sees their own writes, but a different user reading the same key might still see stale data. It's much cheaper than linearizability (often implemented with sticky sessions or session tokens) and typically what users actually need from "consistency."

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** **2.1 CAP theorem** (the partition-time trade-off) and **2.2 PACELC** (the latency trade-off in the absence of partitions). Together those give you the theoretical floor; this subtopic is the practical *spectrum* you actually navigate when designing.
- **Enables:** **2.7 Stateless vs. stateful systems** (stateful systems force you to pick a consistency model), **Topic 7 — Database Replication & Sharding** (which makes consistency choices concrete via leader/follower or multi-leader topologies), **Topic 11 — Distributed Consensus** (Raft/Paxos give you linearizability but at a cost), **Topic 28 — Distributed Locking** (requires linearizability), and **Topic 22 — Observability** (consistency choices show up in SLO design).
- **Tension with:** **Latency** (every consistency strengthening adds RTTs), **Availability under partition** (CAP), **Throughput** (coordination serializes), and **Operational simplicity** (mixed-consistency systems are harder to reason about and test). Conversely, eventual consistency is in tension with **Application correctness** — it pushes complexity into the app layer.

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. Name the 6 consistency levels from strictest to loosest, and give one production system that primarily operates at each level.

The six consistency levels from strictest to loosest are linearizability, sequential consistency, causal consistency, read-your-writes, monotonic reads, and eventual consistency.
Linearizability — Google Spanner. Every read reflects the most recent committed write across all global replicas. Spanner achieves this using TrueTime (bounded clock uncertainty) plus a commit wait, making the system appear as a single atomic data store despite being distributed across continents. Used for AdWords billing and Google Pay where double-spending cannot occur.

Sequential consistency — Kafka (within a partition). All consumers of the same partition see messages in the exact same order the producer wrote them. There is no real-time wall-clock guarantee — a lagging consumer might be processing events from 30 seconds ago — but the ordering is identical across all consumers. No node can see message 43 before message 42.

Causal consistency — MongoDB causal sessions. Operations that are causally related are guaranteed to be observed in cause-before-effect order on all nodes. A read that sees a write can only be followed by writes that are logically "after" that read. Concurrent, unrelated operations can be seen in any order. Facebook comment threads operate on the same principle — a reply is always visible after the post it replies to.

Read-Your-Writes — Twitter profile updates. After you post a tweet or update your bio, you immediately see your own change on any subsequent request — even if that request hits a different replica. Other users may still see the old data for a second or two. Implemented via sticky routing or version tokens that force the serving replica to catch up to your last write before responding.

Monotonic reads — paginated content feeds. Once you've seen a feed with 20 posts, a subsequent page load will never show fewer than 20 posts — even if you get routed to a different, slightly lagging replica. Reads only move forward; time never goes backwards for a given client session. Achieved by tracking the last-seen version and refusing to serve from any replica behind that version.

Eventual consistency — DNS. When a domain's A record is updated, that change propagates to resolvers worldwide based on TTL expiry — typically minutes to hours. During propagation, different users resolve the same domain to different IPs. All resolvers will eventually converge, but there is no SLA on when. The trade-off is intentional: DNS handles billions of queries per second globally, and strong consistency at that scale would be physically impossible.

2. A user sees their own newly-posted comment immediately, but their friend on the other side of the world sees it 4 seconds later. What consistency model is this, and what does it *not* guarantee?

This is read-your-writes consistency. It guarantees the client who made the write will always see it on subsequent reads — enforced by routing that client's reads to a replica that has their write, or by version token tracking. It does NOT guarantee other clients see the write immediately (they see it after eventual replication, hence the 4-second lag), it does NOT guarantee ordering of writes from different clients, and critically it does NOT extend to other sessions from the same user — a different device or browser session won't inherit the guarantee unless the version token is explicitly shared.

3. You're designing a system where users can claim a unique handle (like @username). Which consistency level is required, and what specifically goes wrong if you use eventual consistency here?

Unique username registration requires linearizability. The operation is fundamentally "check-then-claim" — read current state, conditionally write — and under eventual consistency, two clients can both read "unclaimed," both write "mine," and both get success from different replicas. The conflict is unresolvable without a loser: unlike shopping carts or counters, username ownership has no commutative merge — you can't say "both users get @gary." Someone loses their handle after the fact. The correct implementation uses atomic CAS (compare-and-set): "claim @gary only if it is currently unclaimed" — executed as a single indivisible operation against a single source of truth.

4. DynamoDB lets you choose "strongly consistent reads" or "eventually consistent reads" per query. Strongly consistent reads cost twice as much. What is happening internally to justify the cost difference?

DynamoDB maintains 3 replicas per partition within a region. Eventually consistent reads hit any replica — fast, but potentially milliseconds stale. Strongly consistent reads must be routed to the leader node specifically, which is the only replica guaranteed to have every committed write. That extra routing step consumes more compute on the leader and adds latency. DynamoDB prices this as 0.5 RCU vs 1 RCU — the 2× cost reflects the leader's additional load, not cross-region work. If the leader is unavailable, strongly consistent reads also fail rather than fall back to a follower, which is the availability cost of the consistency guarantee.

5. Your system normally responds to writes in 5ms. After the team migrates to a linearizable store across two regions, write latency jumps to 120ms. Explain — without using the word "consistency" — exactly what is causing the increase.

So when we say a linearizable system, what we are saying is that this system essentially behaves like a single system, a single source of truth. It will always require, whenever a write happens, a majority write success before a confirmation write is given to the client. In such a case, when the leader has made the write, it must send the write to other replicas and wait for those replicas to confirm before giving the response. This, in itself, takes additional time. In cross-regions, the regions have a longer round-trip time because data travels at about two thirds the speed of light in a fiber optic cable, this in itself takes additional travel time. the travel time here accounts for the big part of jump to 120ms

A linearizable write using a consensus protocol (Raft or Paxos) doesn't complete in a single round trip. It takes two full rounds of message passing:
Round 1 — the leader proposes the write and waits for a quorum of replicas to acknowledge they've received and logged it ("I have it").
Round 2 — the leader commits the write and waits for replicas to acknowledge the commit ("I've applied it").

Only after round 2 does the leader return success to the client. Each round is a full cross-region RTT. At 50–60ms per round trip cross-region, two rounds puts you at 100–120ms — which is exactly what you're seeing. The 5ms baseline was achievable because intra-region consensus only crosses AZs (1–2ms per hop), making two rounds still fast.

This is also why the cost is unavoidable with physics — you cannot optimize your way below the speed of light. If you need cross-region acknowledgment for durability and correctness, you're fundamentally bounded by distance. The only way to get back to 5ms is to relax the cross-region requirement: accept that writes are only acknowledged by in-region replicas, and cross-region replication happens asynchronously — which means you've moved off linearizability.

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **Designing Data-Intensive Applications**, Martin Kleppmann — Chapter 5 (Replication) and Chapter 9 (Consistency and Consensus). The single best resource on this topic.
- [ ] **Jepsen — Consistency Models** — https://jepsen.io/consistency — interactive map of every consistency model with formal definitions and how they relate.
- [ ] **Werner Vogels — "Eventually Consistent"** — https://www.allthingsdistributed.com/2008/12/eventually_consistent.html — Amazon CTO's foundational essay on why eventual consistency is engineering, not compromise.
- [ ] **Peter Bailis — "Highly Available Transactions: Virtues and Limitations"** — VLDB 2014 paper on what consistency you can keep under partition.
- [ ] **Google Spanner paper** (OSDI 2012) and **TrueTime** — how Google made global linearizability practical.
- [ ] **ByteByteGo — "Strong vs Eventual Consistency"** — YouTube, Alex Xu — short visual explainer.

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*
