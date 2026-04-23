# 2.2 PACELC — Extending CAP with Latency

**Topic:** Topic 2 — System Design Core Principles & Scalability Fundamentals
**Phase:** A — Core First Principles
**Date studied:** 2026-04-22
* * *


## 1. 🎯 Goal of This Subtopic

> *Why are you studying this? What should you be able to do after this session?*


* Be able to explain why CAP theorem is incomplete and what real gap PACELC fills in — specifically the latency dimension that CAP ignores entirely.
* Be able to classify a real system using PACELC notation (e.g., "Cassandra is PA/EL") and explain *what that choice means* for its behavior under both partitions and normal operation.
* Be able to use PACELC as a design tool during an interview trade-off discussion, articulating why a system prioritizes latency vs. consistency in steady state — not just during failure.

* * *


## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*


- [x] Can explain PACELC from scratch in under 60 seconds — what each letter stands for and what question the model answers that CAP cannot.
- [x] Can classify DynamoDB, Cassandra, Spanner, and MongoDB using PACELC notation and justify each classification with a specific behavioral example.
- [x] Can explain why the Else (E) branch of PACELC is often more commercially important than the Partition (P) branch.
- [x] Can articulate the latency/consistency trade-off in the Else branch with a concrete scenario (e.g., a write to a multi-node cluster requiring synchronous replication before acknowledging).
- [x] Can draw the PACELC decision tree from memory and annotate it with at least two real systems per quadrant.

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

* * *


## 3. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*


```
ONE-LINER
  PACELC extends CAP by adding the unavoidable latency vs. consistency
  trade-off that exists even when there is no network partition —
  because replication always takes non-zero time.

KEY PROPERTIES / RULES
  P branch (Partition): Same as CAP — choose Availability or Consistency.
    PA = stay up and serve stale data.
    PC = reject or block until consistent.
  EL (Else Latency): Normal ops — async replication, low latency, eventual consistency.
  EC (Else Consistency): Normal ops — wait for replica ack before responding, higher latency.
  Most "AP" CAP systems are PA/EL — sacrifice consistency twice (partition + normal ops).
  PC/EC systems (Spanner, ZooKeeper) are consistency-first in all scenarios.

DECISION RULE
  Use EL when: read-heavy, globally distributed, users tolerate brief staleness
               (e.g., social feeds, shopping carts).
  Use EC when: writes must be immediately visible to all readers and stale reads
               cause real harm (e.g., financial balances, inventory, distributed locks).

NUMBERS / FORMULAS
  Notation:              P[A|C] / E[L|C]   e.g. "PA/EL", "PC/EC"
  Cross-region EC cost:  ~50–150ms per write (speed of light + TCP overhead)
  Cassandra quorum:      N=3, W=2, R=2 → R+W=4 > N=3 → EC-like behavior

GOTCHA TO NEVER FORGET
  Even a perfectly healthy cluster with zero partitions still faces a
  consistency vs. latency trade-off — CAP makes you forget this entirely.

PACELC CLASSIFICATIONS ON POPULAR DBs
- Cassandra - PA/EL(default)
- DynamoDB  - PA/EL(default)
- HBase     - PC/EC
- MongoDB
    - pre-5.0 default - PA/EL
    - 5.0+ default - PC/EC

```


* * *


## 4. 🧠 Core Definition

> *What is it, in one sentence?*

PACELC is a framework proposed by Daniel Abadi (2012) that extends CAP theorem by stating: if there is a **P**artition, a system must choose between **A**vailability and **C**onsistency; **E**lse (during normal operation), it must choose between **L**atency and **C**onsistency — because replication always takes non-zero time, so the trade-off exists even when everything is healthy.

* * *


## 5. 📦 Core Concepts

> *The essential building blocks of this subtopic.*


### The P Branch (Partition Handling)

The P branch is identical to CAP theorem: when a network partition occurs, the system cannot simultaneously guarantee availability (serve every request) and consistency (guarantee every read reflects the latest write). PA systems stay up and serve potentially stale data; PC systems sacrifice availability to maintain correctness. This is the well-known CAP trade-off — PACELC preserves it as-is.


### The E Branch (Else — Normal Operation)

The insight PACELC adds is the **Else branch**: even when no partition exists, replication is not instantaneous. A write to a leader must be propagated to followers, and there is a window during which different nodes see different data. EL systems acknowledge the write as soon as the leader commits it (low latency, eventual consistency). EC systems wait for a quorum or all replicas to confirm before acknowledging (higher latency, strong consistency). The Else branch is often more impactful than the P branch because partitions are rare but replication lag is constant.


### The Latency Cost of Consistency

EC in the Else branch has a concrete, quantifiable latency cost: at minimum, a round-trip to the farthest required replica plus protocol overhead. For a system with replicas in US-East and EU-West, EC adds ~150ms to every write — the speed of light across the Atlantic plus TCP overhead. This makes linearizable global writes expensive by physical law, not by engineering failure. EL systems sidestep this by acknowledging before replication completes, keeping write latency near-zero at the cost of a consistency window.


### Configurable PACELC Classification

Some systems are not statically PA/EL or PC/EC — they let the caller choose per-request. Cassandra's consistency levels (`ONE`, `QUORUM`, `ALL`) let you slide from PA/EL to near-PC/EC on a per-operation basis. DynamoDB similarly offers eventually consistent reads (EL) and strongly consistent reads (EC) as a request parameter. This means the PACELC label for these systems describes their *default* behavior, not their ceiling — and you must know both to reason correctly.

* * *


## 6. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

After CAP theorem became mainstream following Brewer's 2000 keynote and Gilbert & Lynch's 2002 proof, it became the default mental model for distributed system trade-offs. But CAP only asks: "what happens when the network breaks?" It says nothing about normal operation.

This created a blind spot. Systems like Cassandra and DynamoDB were labeled "AP" in their marketing, and engineers understood this as a partition-time behavior — something that only mattered during rare failure events. What was hidden was that these systems also made a specific and consequential choice for their *every-day, normal-operation* behavior: they chose lower latency over consistency via asynchronous replication. That choice meant stale reads, lost updates under concurrent writes, and read-your-own-writes anomalies — all happening during perfectly healthy network conditions, with no partition in sight.

Daniel Abadi published PACELC in 2012 to make this second trade-off explicit. The Else branch forces engineers to ask: "Even when everything is working, what consistency guarantee does this system provide — and what latency am I paying for it?" Without PACELC, this question was invisible. With it, system comparisons become honest.

* * *


## 7. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*


### Model 1: The Two-Question Test

Think of PACELC as two separate questions you must answer when evaluating any distributed database:

1. **"What does it do when the network breaks?"** — PA stays up but serves stale data. PC blocks or rejects.
2. **"What does it do when the network is healthy?"** — EL replies fast with possibly stale data. EC waits for all nodes to confirm before replying.

This model is useful because it gives you a structured interview script: "Let me answer the partition case first, then the steady-state case." It breaks down when you forget that many systems let you tune both answers per request — the classification isn't always static.


### Model 2: The Tollbooth Analogy

Imagine a highway tollbooth connected to a central billing system via a network link. If the link goes down (partition), the tollbooth can either wave everyone through (PA — available but inconsistent) or close the lane (PC — consistent but unavailable). That's the CAP branch. But even when the link is fine, there's a choice: the tollbooth can charge the driver from a local cache and sync later (EL — fast but briefly inconsistent), or wait for the central system to confirm before lifting the gate (EC — correct but slower). Most engineers only think about the "link goes down" scenario — PACELC forces you to think about the second scenario too, which happens on every single transaction.


### Model 3: The Write Latency Budget

In the Else branch, consistency has a concrete time cost: at minimum, a round-trip to the farthest required replica plus protocol overhead. This model is useful because it makes the trade-off quantifiable. You're not choosing between abstract "consistency" and "latency" — you're choosing between a specific millisecond budget and a specific staleness window. In an interview, this lets you say: "Given our SLA of p99 < 50ms write latency, EC with cross-region synchronous replication is not viable — the round-trip alone exceeds our budget. We need EL with compensating read logic."

* * *


## 8. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

**Reading PACELC notation:**
A PACELC classification is written as `P[A|C]/E[L|C]`. The P branch comes first:

* `PA/EL` — stays up during partitions, serves low-latency eventually-consistent reads in normal ops.
* `PC/EC` — rejects requests during partitions, waits for full replication in normal ops before acknowledging.
* `PA/EC` — stays up during partitions (rare case handled with availability), but enforces synchronous replication in normal ops. Rare in practice.

**The Else branch mechanics — EL path:**

1. Client sends a write to the coordinator/leader node.
2. Leader commits the write to its local store.
3. Leader immediately returns success to the client.
4. Replication to followers happens asynchronously in the background.
5. **Window of inconsistency:** Between step 3 and replication completion, a read from any follower returns the old value. Duration: microseconds to seconds depending on replication lag.

**The Else branch mechanics — EC path:**

1. Client sends a write to the coordinator/leader node.
2. Leader sends the write to all required replicas (or a quorum).
3. Leader waits for acknowledgment from all required replicas.
4. Only then does the leader return success to the client.
5. Any subsequent read from any node is guaranteed to see the write. No staleness window exists.
6. **Latency cost:** The write latency is now bounded by the slowest required replica's round-trip time.

**Quorum math — tuning the Else branch:**
Cassandra demonstrates this with configurable consistency levels. With `N` replicas, write quorum `W`, and read quorum `R`:

* If `R + W > N`: every read overlaps with every write by at least one replica → EC-like behavior.
* If `R + W ≤ N`: reads and writes can miss each other → EL behavior.
* Example (N=3): `W=1, R=1` → EL. `W=2, R=2` → EC (4 > 3). `W=3, R=1` → EC but slow writes.

* * *


## 9. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*


### 9.1 PA/EL — Available during partitions, low latency in normal ops

#### Apache Riak

Dynamo-style leaderless architecture — the direct inspiration for Abadi's original PACELC paper. Writes go to any node, replicated async. Conflict resolution uses vector clocks or Riak's CRDT data types. Chose PA/EL explicitly because its target use case (session storage, user preferences) tolerates staleness. Classic example of a system where the PA/EL choice was a conscious product decision, not an oversight.


#### Couchbase(default)

Distributed document store with async intra-cluster replication by default. A write is acknowledged after the active node commits — replicas catch up asynchronously. The result: a node failure between write and replication means data loss for that window. Couchbase calls this "durability level: none" and offers opt-in synchronous replication (durabilityLevel: majority) which shifts the Else branch toward EC.


#### DNS

The canonical real-world PA/EL system that every engineer already uses. When you update an A record, the change propagates through a hierarchy of resolvers with TTLs of minutes to hours. During that window, different clients resolve the same hostname to different IPs. The system stays available (PA) and optimizes for low query latency via local caching (EL). Strong consistency across all resolvers globally would make DNS unusably slow and fragile. Staleness is the explicit design choice.


#### Memcached(distributed)

No replication at all — each key lives on exactly one node. If that node goes down, the key is gone and the cache misses fall through to the database. During normal operation, reads and writes are single-node, sub-millisecond — pure EL. Not typically framed as a PACELC system in textbooks, but it's the extreme end of the EL spectrum: zero consistency overhead, zero replication lag, zero consistency guarantee.


### 9.2 PC/EC — Consistent during partitions, consistent in normal ops

#### Google Spanner

The gold standard PC/EC system. Uses TrueTime (GPS receivers + atomic clocks in every data center) to bound clock skew to ~7ms globally. Every write waits for the TrueTime uncertainty window to close before committing — this is the EC cost made explicit and quantifiable. During partitions, Spanner uses Paxos-based consensus and will refuse writes that cannot reach quorum. Used by Google for AdWords, Google Play, and F1 (Google's ads database) — workloads where financial correctness justifies the latency cost.


#### Apache ZooKeeper

Purpose-built for distributed coordination: leader election, distributed locks, configuration management. A ZooKeeper node that loses quorum contact with the leader will refuse reads and writes rather than serve stale state. Every write goes through the leader and is committed via ZAB (ZooKeeper Atomic Broadcast) to a majority of nodes before acknowledging. The system is deliberately slow for writes — it's not a general-purpose data store. The PC/EC guarantee is the entire product.


#### etcd

The backing store for Kubernetes cluster state — pod specs, service definitions, ConfigMaps. Uses the Raft consensus algorithm. Every write requires a majority quorum acknowledgment before succeeding. During a network partition, the minority partition stops accepting writes entirely. This is the correct choice: a Kubernetes cluster acting on split-brain etcd state could simultaneously schedule the same pod to conflicting nodes, causing data corruption or duplicate billing. Correctness is non-negotiable.


#### CockroachDB

Distributed SQL database explicitly designed to be PC/EC at global scale — Google Spanner's open-source spiritual successor. Uses multi-version concurrency control (MVCC) and Raft per range. Serializable isolation is the default. Every write is synchronously replicated to a quorum of replicas before the client receives acknowledgment. The latency cost is real and documented — CockroachDB's own benchmarks show significantly higher write latency than PA/EL alternatives like Cassandra. They position this as the right trade-off for financial and transactional workloads.


### 9.3 The interesting middle class

#### Redis Cluster(Default)

PA/EL — Redis prioritizes availability and latency above all else. During a partition, the primary shard continues accepting writes even if it can't reach replicas. Async replication means a primary failure before replication completes loses those writes. Redis explicitly documents this: "Redis is not suitable as your primary data store for data you cannot afford to lose." Used correctly — as a cache layer, session store, or rate limiter — this trade-off is perfectly rational.


#### Redis with WAIT command

Shifts toward EC for specific operations. WAIT numreplicas timeout blocks the client until the specified number of replicas acknowledge the write. Not a global configuration — a per-command opt-in. Same system, same cluster, different PACELC behavior per operation. Mirrors the Cassandra tunable consistency story.
* * *


## 10. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*


>The correct PACELC choice is always downstream of what staleness or unavailability actually costs the user and the business.



### 10.1 Shopping Cart - PA/EL is correct and here’s why

User adds an item to their cart on mobile, then immediately opens the web app. With PA/EL (e.g., DynamoDB default), the web app might not see the item for 50–200ms while replication catches up. The cost: a mildly jarring UX. The alternative — PC/EC — means every cart write waits for cross-region quorum acknowledgment, adding 100–150ms to every "Add to Cart" tap. Amazon famously chose PA/EL for carts and absorbed the staleness. The business math: conversion rate loss from slow add-to-cart clicks far exceeds the cost of brief inconsistency.


### 10.2 Inventory Counter at Checkout - PC/EC is required, and PA/EL will burn you

You have 1 unit of a limited-edition sneaker left. Two users simultaneously hit "Buy Now" from different regions. With PA/EL, both writes succeed on their local nodes before replication — both users get an order confirmation. After healing, you've oversold by 1. Now you must cancel one order, issue an apology, and eat the trust cost. PC/EC forces one write to win and the other to see the updated count before confirming. The latency cost (~100ms extra at checkout) is trivially acceptable compared to the operational nightmare of overselling.


### 10.3 Social Media “Likes” counter - PA/EL is correct, PC/EC is overkill

A post has 1,482 likes. You like it. Someone else in another region sees 1,481 for the next 300ms. Nobody notices, nobody cares, and no business decision depends on this number being exact in real time. Enforcing EC here means every like — potentially millions per second across Instagram-scale traffic — must wait for global quorum acknowledgment. The infrastructure cost and latency hit are enormous for zero user-perceptible benefit. PA/EL is the obvious call. This is the scenario Abadi uses to argue that "AP" systems aren't being reckless — they're being rational.


### 10.4 Bank Account balance - PC/EC, no debate

User has $100. They initiate two wire transfers of $80 each from different devices (or two tabs, or a race condition in your mobile app). With PA/EL: both reads return $100, both writes succeed locally, both replicate. Account is now at -$60. With PC/EC: the second write sees the post-first-write balance of $20, fails the validation, and is rejected. The user gets an error — annoying but correct. The latency cost of EC (waiting for quorum on every balance update) is a non-issue for financial transactions where correctness is a regulatory and legal requirement.


### 10.5 Cassandra with Tunable Consistency - Same System, Different trade-off per operation

This is the most interview-relevant scenario because it shows PACELC isn't just about picking a database — it's about per-operation decisions. A ride-sharing app uses Cassandra for both user profiles and trip pricing:


* **User profile reads** (display name, avatar): ONE consistency. PA/EL. If your name shows as slightly stale for 100ms after you update it, nobody notices.
* **Surge pricing reads** (driver sees fare multiplier): QUORUM consistency. EC in the Else branch. A driver accepting a trip on stale pricing data could be underpaid. The extra 10–20ms round-trip to hit quorum is worth it.

Same cluster, same keyspace — two different PACELC operating points chosen based on what the data means to the business.
* * *


## 11. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**

* "How does your system handle consistency across replicas?"
* "What happens to reads during a network partition?"
* "You said the system is eventually consistent — what does that mean for users in practice?"
* "Walk me through the trade-offs of using DynamoDB / Cassandra here."

**What you say / do:**
During the trade-off deep-dive (after high-level design is set), explicitly classify the chosen data store using PACELC notation: "DynamoDB is PA/EL by default — it stays available during partitions and optimizes for low-latency reads in normal ops, which means users may briefly see stale data after a write. That's acceptable here because we're serving a social activity feed — a few seconds of staleness is invisible to users. To handle read-your-own-writes, I'd route each user's reads to the same node that accepted their write for a short TTL."

**The trade-off statement (memorize this pattern):**
> "If we choose EL — low latency, eventually consistent — we get sub-millisecond write acknowledgment and high read throughput, but we pay with the possibility of briefly stale reads. For this system, that's the right call because user feed reads don't require strict consistency and our SLA demands p99 < 20ms — which EC with synchronous cross-region replication physically cannot achieve."

* * *


## 12. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance does the interviewer is probing for?*


* ❌ **Misconception:** "PACELC and CAP are two separate theories that apply in different situations."

  ✅ **Reality:** PACELC is a strict superset of CAP. The P branch of PACELC *is* the CAP theorem. PACELC simply adds the Else branch that CAP completely ignores. Every CAP classification maps to a PACELC classification, but PACELC is more informative because it also characterizes normal-operation behavior.


* ❌ **Misconception:** "If a system is AP under CAP, it must be EL under PACELC — they always go together."

  ✅ **Reality:** PA/EC is a valid combination. A system can prioritize availability during partitions (PA) while still requiring synchronous replication in normal operation (EC). These are independent design decisions. Conflating them leads to incorrect system classifications.


* ❌ **Misconception:** "The Else branch only matters for globally distributed systems with cross-region replication."

  ✅ **Reality:** Even within a single data center, synchronous replication to 3 nodes adds measurable latency (hundreds of microseconds to low milliseconds). At high QPS with tight p99 SLAs, EL vs. EC is a meaningful choice even for same-region clusters.


* ❌ **Misconception:** "Cassandra is always eventually consistent — it can't provide strong consistency."

  ✅ **Reality:** Cassandra is tunable. At `QUORUM` consistency level with R+W > N, it provides strong consistency in the Else branch. The PA/EL label describes its *default* configuration, not its theoretical maximum. Always distinguish between a system's default behavior and its configurable capability.


* ❌ **Misconception**: "PC/EL systems doesn’t exist"

✅ Reality: Yes — PC/EL is valid. It's the rarest of the four combinations, and it feels counterintuitive at first, which is exactly why interviewers probe it.

**Why it seems contradictory**

At first glance PC/EL reads as: "We care enough about consistency to go unavailable during a partition — but not enough to wait for replication in normal ops." That sounds like a contradiction. It isn't, because the P branch and E branch address different problems entirely.


* **PC** prevents *divergent writes* — two nodes accepting conflicting writes during a partition that are impossible or expensive to reconcile afterward.
* **EL** accepts *replication lag* — a brief window where replicas are behind the primary, but there's only one writer so no conflict is possible.

The insight: **PC is about preventing write conflicts. EL is about read staleness.** You can prevent split-brain (PC) while still serving stale reads from async replicas (EL). They're orthogonal concerns.

**Real-world examples**

**PNUTS (Yahoo!, 2008)**
The clearest textbook example — Abadi explicitly classifies it as PC/EL in his paper. PNUTS routes all writes for a given record to a single designated "record master" regardless of where the write originates. During a partition, clients who can't reach the record master simply cannot write — the system becomes unavailable for writes on that record (PC). No conflicting writes are ever possible. But reads can be served from any local replica using "read-any" consistency, which may return stale data (EL). The tradeoff: zero write conflicts, low-latency local reads, but reduced write availability during failures.

**MySQL/PostgreSQL with async replication + node fencing**
A primary database with async replicas (EL in normal ops — writes acknowledged before replication completes). When a partition is detected, the system uses STONITH ("Shoot The Other Node In The Head") or lease-based fencing to guarantee only one node ever accepts writes — the secondary is forcibly evicted rather than allowed to promote itself and create split-brain (PC). Normal operation is fast and async; failure mode sacrifices availability for correctness.

**Single-master systems with read replicas (general pattern)**
Any architecture where writes are strictly funneled through one primary (preventing conflicting writes = PC) but reads are served from async replicas (tolerating staleness = EL). This includes many traditional RDBMS setups — PostgreSQL streaming replication with `synchronous_commit = off`, MySQL with async binlog replication. The primary refusing to accept writes when it loses quorum contact (via Pacemaker, orchestrator, or similar) is what makes it PC rather than PA.

**Why it's rare**

PC/EL forces you to pay the availability cost of PC without getting the full consistency benefit of EC. Users can still read stale data — you've just guaranteed they can't *write* conflicting data. This is a narrow use case: it makes sense when write conflicts are catastrophically expensive to resolve (PNUTS-style multi-region writes) but read staleness is acceptable. Most systems either want full correctness (PC/EC) or full performance (PA/EL) — the asymmetric guarantee of PC/EL fits a specific niche.

The one-liner for interviews: **PC/EL systems prevent split-brain without paying for synchronous replication — they trade write availability for conflict-free writes, while accepting stale reads as the price of normal-ops speed.**
* * *


## 13. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*


* **Builds on:** 2.1 CAP Theorem — PACELC cannot be understood without first understanding the CAP partition trade-off. The P branch of PACELC is CAP verbatim. You must know why CP vs. AP matters before you can reason about what the Else branch adds on top.
* **Enables:** 2.5 Consistency vs. Availability Trade-offs (the full spectrum from linearizability to eventual consistency); Topic 17 (Consistency Models — where you classify real systems like Cassandra, Spanner, and DynamoDB in depth using the PACELC lens); Topics 15–16 (Distributed Storage and Replication Strategies — where PACELC becomes the evaluation framework for leader/follower and leaderless replication designs).
* **Tension with:** 2.3 Latency vs. Throughput — the latency cost of EC in the Else branch directly caps write throughput. If a write must wait 50ms for all replicas to confirm, your write throughput is physically capped at 20 writes/sec per thread regardless of hardware capacity. EC and high write throughput are in fundamental, unavoidable tension.

* * *


## 14. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*


1. What does each letter in PACELC stand for, and what is the single most important insight PACELC adds over CAP theorem?

P - Partition
A - Availability
C - Consistency
E - Else
L - Latency
C - Consistency

The single most important insight is that CAP only describes what a system sacrifices during a failure — but partitions are rare. Even when the network is perfectly healthy, replication takes non-zero time, so every distributed system must still choose: acknowledge the write immediately and accept a staleness window (EL), or wait for replicas to confirm and accept higher latency (EC). CAP made this invisible. PACELC makes it explicit.

1. A team is building a shopping cart service. Users add items from multiple devices simultaneously. Would you classify this as PA/EL or PC/EC? Justify your choice with a specific consequence of getting it wrong.

Shopping cart is PA/EL. During a partition, the system stays available — a user can keep adding items even if some replicas are unreachable, and the cart merges after healing. In normal ops, writes are acknowledged before replication completes, so a user switching devices might not see their latest item for a few hundred milliseconds.
The consequence of getting it wrong — choosing PC/EC — is that every "Add to Cart" tap blocks on synchronous cross-region replication, adding 100–150ms of latency. At Amazon's scale, that write latency directly kills conversion rate. Amazon's Dynamo paper explicitly called this out: the cost of PC/EC on the cart hot path was measurable in lost revenue. Brief staleness on a cart is invisible to users. A sluggish add-to-cart is not.


1. What is the concrete latency cost of choosing EC in the Else branch for a system with replicas in US-East and EU-West? Why can't this be eliminated by faster hardware or better software?

EC requires the primary to wait for replica acknowledgment before confirming the write to the client. For US-East to EU-West, the signal travels ~70ms one way through transatlantic fiber — near the theoretical maximum for that medium. The round-trip is ~150ms, which becomes the minimum write latency floor for any EC operation spanning those regions. Faster hardware reduces protocol overhead by microseconds — it cannot touch the propagation delay, which is bounded by the speed of light. This is why linearizable global writes are expensive by physical law, not by engineering failure.


1. Classify Cassandra and Google Spanner using PACELC notation. Describe one specific, observable behavioral difference you'd encounter in production as a result of that classification difference.

Cassandra is PA/EL by default. Writes are acknowledged after the coordinator commits locally, with async replication to other nodes. Write latency within a region is typically 1–5ms. Cross-region reads may return stale data during the replication window.
Spanner is PC/EC. Every write waits for TrueTime uncertainty to close (~7ms) plus quorum acknowledgment across replicas. Within a region, write latency is ~5–10ms. Cross-region writes climb to ~100–150ms due to the physical round-trip.
The concrete observable difference: you're running a user profile service. A user updates their email address. With Cassandra, a support agent querying a different region 50ms later may still see the old email — the replication hasn't landed yet. They call the user on the wrong contact. With Spanner, any node queried immediately after the write returns the new email, guaranteed. The Cassandra failure mode is a real production bug class — stale reads causing customer-facing inconsistencies — that Spanner eliminates at the cost of higher write latency.


1. A Cassandra cluster is configured with N=5, W=3, R=3. Is this system behaving as EL or EC in the Else branch? Show your reasoning using quorum math.

W + R > N: 3 + 3 = 6 > 5. This guarantees — not probabilistically, but by the pigeonhole principle — that the read set and write set must overlap by at least one node. That overlapping node has the latest write, so the client will always see the most recent value. This is EC behavior in the Else branch: strong consistency at the cost of requiring 3 of 5 nodes to respond on every read and write operation.

* * *


## 15. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*


- [x] Daniel Abadi — "Consistency Tradeoffs in Modern Distributed Database System Design" (2012) — the original PACELC paper: http://cs-www.cs.yale.edu/homes/dna/papers/abadi-pacelc.pdf
- [ ] *Designing Data-Intensive Applications* by Martin Kleppmann — Chapter 9 (Consistency and Consensus): covers linearizability, replication lag, and the consistency model spectrum that PACELC maps onto.
- [ ] AWS DynamoDB Developer Guide — "Read Consistency" section: concrete documentation of EL vs. EC behavior (eventually consistent vs. strongly consistent reads) in a production PA/EL system.
- [ ] Google Spanner paper (OSDI 2012) — "Spanner: Google's Globally Distributed Database": explains TrueTime and how PC/EC is achieved at global scale: https://static.googleusercontent.com/media/research.google.com/en//archive/spanner-osdi2012.pdf
- [ ] ByteByteGo — "CAP Theorem Simplified" (YouTube, Alex Xu): visual walkthrough of CAP and PACELC with real system classifications.

* * *


## 16. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

* * *


## 17. 🗓️ Study Phases to Achieve Mastery

> *All sections are pre-filled. Your job is not to write — it is to internalize, verify, and prove you own it. Work through each phase in order. Don't move to the next until you can honestly tick every item.*


### Phase 1 — Acquire 📖

*Goal: Read the pre-filled content actively, not passively. Close the doc and reconstruct key ideas from memory.*


- [x] Read **Sections 4, 5, 6** (Core Definition, Core Concepts, First Principles) — then close the doc and explain PACELC out loud in your own words
- [x] Read the original PACELC paper (2012): http://cs-www.cs.yale.edu/homes/dna/papers/abadi-pacelc.pdf — verify the pre-filled content is accurate; correct anything that conflicts
- [ ] Read *Designing Data-Intensive Applications* Chapter 9 (replication lag + linearizability sections) — same drill: correct anything in the doc that doesn't match

### Phase 2 — Consolidate ✍️

*Goal: Compress the pre-filled content into your own mental model. Add personal annotations to Section 16.*


- [x] Read **Section 7** (Mental Models) — does each model click for you? If not, write your own analogy in **Section 16 (My Notes)**
- [x] Read **Section 8** (How It Works) — close the doc and re-explain the EL vs. EC write path mechanics step by step without looking
- [x] Read **Section 10** (Trade-offs) — for each row, ask: "can I think of a concrete scenario where this cost bit someone in production?" Add examples to Section 16 if yes
- [x] Read **Section 3** (Cheatsheet) — memorize it cold; this is your 30-second interview recall card

### Phase 3 — Apply 🔧

*Goal: Stress-test the pre-filled content against real systems. Practice speaking, not reading.*


- [x] Read **Section 9** (Real-World Examples) — look up the DynamoDB and Cassandra consistency docs directly and verify the classifications are correct; annotate any discrepancies in Section 16
- [x] Read **Section 11** (Interview Application) — say the trade-off statement out loud for three different systems: a social feed (PA/EL), a payment ledger (PC/EC), and a shopping cart (PA/EL with read-your-own-writes mitigation)
- [x] Read **Section 12** (Misconceptions) — for each one, ask yourself: "would I have gotten this wrong before reading this file?" Mark the ones that genuinely surprised you in Section 16
- [x] Read **Section 13** (Relationships) — trace the chain: CAP (2.1) → PACELC (2.2) → Consistency Models (Topic 17). Make sure the connections feel logical, not just memorized

### Phase 4 — Validate 🧪

*Goal: Prove you own it — without the doc.*


- [x] Answer all 5 **Self-Check Quiz** questions (Section 14) out loud without looking at any notes — stumble on one → re-read that section only, then retry
- [x] Recite the **Cheatsheet** (Section 3) from memory in under 30 seconds
- [x] Tick off every item in **Section 2** (What Mastery Looks Like) — only check a box if you can demonstrate it on demand right now, not "I think I could"
- [x] Teach PACELC out loud to an imaginary interviewer for 2 minutes without hesitation — cover: what it is, why CAP was insufficient, the Else branch mechanics, and one real system classification with justification

