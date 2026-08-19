# 🗝️ Design Problem #3 — Key-Value Store (Dynamo / Cassandra-like)

> **Roadmap coverage map — what you must own to answer this at staff level.**
> Source of truth for tiers and completion: `system_design_study_roadmap.md`
> Generated: 2026-08-19

---

## 🧭 The Framing

This is the **only canonical problem where you build the database instead of using one.**

In #1 and #2 the storage layer was an assumption — *"put the mapping in DynamoDB," "put the
counter in Redis."* Here that assumption **is the deliverable.** Every other problem in the
canonical 20 gets to say "and we store it in a distributed KV store." This one asks what is
inside that box.

Three consequences, and they reshape the entire coverage map:

1. **The whole problem lives below the API line.** `get(k)` / `put(k,v)` / `delete(k)` is the
   entire API. There is no CDN story, no meaningful load-balancer story, no rate limiting.
   Topics 4, 6, 11, 25 — which carried #1 and #2 — nearly vanish. All the weight moves to
   **Phase C and Phase E**: partitioning, replication, consistency, coordination.

2. **It is peer-to-peer, not tiered.** #1 and #2 are stateless-tier + storage-tier. A
   Dynamo-style ring is N identical nodes with no leader. Membership, failure detection and
   repair must all be **decentralized** — and that is precisely where the roadmap has holes.

3. **It is the tunable-consistency problem.** N/R/W is the one place in the canonical 20
   where CAP stops being a slogan and becomes three integers you actually choose. This is
   also the only problem where **PACELC beats CAP** as the framing tool, because the
   interesting branch is the *else* branch — no partition, still trading latency for
   consistency on every single request.

If you prepare one thing for this problem, prepare **the read path when a replica is stale
or missing**: quorum → read repair → hinted handoff → Merkle-tree anti-entropy. That chain
*is* the interview.

**Legend:** ✅ complete · 🥇 T1 Core · 🥈 T2 Depth · 🥉 T3 Awareness

---

## 🥇 Tier A — The Spine

| Topic | Subtopics | Why it's load-bearing here |
|---|---|---|
| **1** Estimation ✅ | 1.6, 1.9, 1.10, 1.11, 1.14, 1.15 | **1.11 replication overhead is the one that bites** — RF=3 means 100 TB of data is 300 TB of disk *and* 3× the write bandwidth the client sent. Almost nobody prices this. **1.9 server count is derived from disk + RAM here, not QPS** |
| **2** Core Principles ✅ | 2.1, **2.2**, 2.5, 2.6, 2.7, 2.10 | **2.2 PACELC is finally load-bearing, not decorative.** CAP only speaks during a partition; the R/W dial is a *latency vs. consistency* choice you pay for on every normal request. That's the E/L branch |
| **3** Stateless ✅ | 3.6 | Share-nothing is the only Topic 3 idea that survives — each node owns its partitions' disk. There is no stateless tier in this design, which is worth saying out loud |
| **4** Load Balancing ✅ | **4.3** | **Contrast, not reuse.** 4.3 is centralized health checking by an external prober. A KV ring has no prober — liveness is gossiped between peers. Knowing *why the LB model doesn't transfer* is the point |
| **5** Caching ✅ | 5.4, **5.7** | 5.4 eviction if the store is memory-first (Redis-shaped). **5.7 hot key survives intact** — a hot key on a ring concentrates all traffic on one replica set of 3 nodes, and consistent hashing does nothing about it |
| **7** Sharding ✅ | 7.2, **7.4**, 7.5, 7.6, **7.7** | **7.4 consistent hashing + virtual nodes is the single most reusable asset you already own** — it is the partitioner. 7.5 is the node join/leave story. **7.7 is a negative result: KV stores refuse cross-shard joins by design.** The API is deliberately impoverished so partitioning stays trivial |
| **8** DB Fundamentals | 8.1 ✅ · **8.4** ✅ · 8.6 ✅ · 8.7 ✅ · **8.10** 🥈 | **8.4 *is* the storage engine.** memtable → SSTable → compaction → tombstone is what runs inside each node, and you already own it — this is the biggest free win in the problem. **8.10 Bloom filter is the per-SSTable read filter**; without it a single read touches every SSTable on disk. 8.6: the honest answer is you *give up* multi-key ACID — be ready to say why that's the price of the partitioning model |
| **11** API Design | 11.1 ✅ | Small but real. The design decision is what you **refuse** to offer: no range scan, no secondary index, no join. Every one of those would break the partitioner |
| **15** Distributed Storage | **15.1, 15.2, 15.3, 15.5, 15.6** 🥇 · **15.4** 🥈 | **The densest topic in this problem — all six subtopics are Tier A.** **15.3 R+W>N is the centerpiece of the entire design.** 15.4 durability / replication factor closes the loop with 1.11. 15.2 leader/follower is the *contrast* case you reject |
| **16** Replication | **16.3, 16.5** 🥇 · **16.4, 16.6** 🥈 | **16.4 leaderless / Dynamo-style is literally this problem's architecture** — it is under-tiered at 🥈 for this problem. **16.3 conflict resolution (LWW vs. vector clocks vs. CRDTs) is the guaranteed follow-up** to "two clients wrote the same key concurrently" |
| **17** Consistency | **17.1, 17.4, 17.5, 17.6** 🥇 · **17.3, 17.7** 🥈 | **Six of seven subtopics are Tier A** — only 17.2 drops out. **17.7 PACELC applied is where you justify the R/W numbers you picked**, and it is the difference between "eventually consistent" as a claim and as a design |
| **18** Consensus | **18.2, 18.5, 18.6** 🥇 · **18.1** 🥈 | **18.6 "when consensus is NOT needed" is the staff fork of the whole problem.** Dynamo avoids consensus (leaderless, AP); etcd/Spanner embrace it (Raft, CP). Naming that fork and picking a side with a reason is the answer. 18.5 split-brain is exactly what sloppy quorum flirts with |
| **19** Fault Tolerance | **19.1, 19.2, 19.4** 🥇 · **19.5, 19.7** 🥈 | 19.5 active-active *is* the replica model. **19.7 timeouts are subtler than usual** — a coordinator waiting for the R-th response is bounded by your slowest replica, so one sick node sets your p99 unless you hedge |
| **20** Backup & Recovery | **20.1, 20.6** 🥇 · **20.3** 🥈 | **20.3 is mis-shelved for this problem — WAL replay is not backup here, it's the crash-recovery path.** An unflushed memtable is pure RAM; the commit log is the *only* thing standing between a power loss and data loss. A Tier B topic doing Tier A work |
| **22** Observability | **22.5, 22.6** 🥇 · **22.3** 🥈 | Split coordinator latency from replica latency or you can't tell a slow disk from a slow network. **Hinted-handoff queue depth is the "we are running degraded" SLI** most people never name |
| **28** Locking | **28.1, 28.4, 28.6** 🥇 | **28.6 is the thesis of the entire system: a leaderless KV store is a coordination-avoidance machine.** 28.1 matters as a negative — you should be able to say you need *no* lock manager. 28.4 fencing tokens become real the moment you offer compare-and-set |

---

## 🥈 Tier B — Staff-Level Differentiators

| Topic | Subtopics | What it buys you |
|---|---|---|
| **16** Replication | **16.1, 16.2** 🥈 | Positions leaderless against its alternatives. 16.2 multi-leader is also the multi-region KV story — DynamoDB Global Tables is multi-leader with LWW, and saying that out loud is a strong signal |
| **18** Consensus | **18.3** 🥈 | Raft log replication is the *other* branch of the 18.6 fork. If you claim "I'd go CP for this workload," this is the mechanism you owe them |
| **12** Message Queues | **12.1, 12.2, 12.3** 🥇 | **The answer to "but I need to query by a non-key attribute."** Change streams (DynamoDB Streams / CDC → Kafka) build secondary indexes and materialized views *outside* the store, keeping the core API clean |
| **9** Object Storage | **9.6** 🥈 · 9.4 🥇 | Tiered storage — cold SSTables offloaded to object storage. 9.4 gives you erasure coding as the durability alternative to RF=3 at large object sizes |
| **21** Chaos Engineering | **21.1, 21.3** 🥈 | A KV ring is *the* canonical chaos target: kill a node, partition the ring, verify convergence. This is how you demonstrate the eventual-consistency claims you made |
| **37** Multi-Region | **37.1, 37.2** | Cross-region replication and WAN conflict resolution — the natural "now make it global" follow-up |
| **5** Caching ✅ | **5.8** | Row cache + key cache in front of SSTables is exactly the L1/L2 pattern (Cassandra ships both). Free — already complete |
| **8** DB Fundamentals | 8.5 🥈 | Modest here; read-path cost modelling |

---

## 🥉 Tier C — Name and Move On

- **13.8** — TCP vs. UDP. Gossip runs over UDP; it's lossy by design and that's fine because it's epidemic
- **23.6** — TLS/mTLS for **inter-node** traffic on the ring, not just client-facing
- **23.7** — encryption at rest, envelope encryption. Table stakes for anything marketed as a storage product
- **17.2** — sequential consistency. Name it, distinguish it from linearizability, move on
- **18.4** — Paxos. One sentence: "same guarantees as Raft, harder to implement, which is why Raft won"

> 🚫 **What is conspicuously absent:** Topics 6 (CDN), 24 (feeds), 26 (realtime), 30–32
> (search/geo). This is the first canonical problem where **the entire answer sits behind
> the API line.** If you find yourself drawing a CDN, you have misread the question.

---

## ✅ Roadmap Gaps — Filed 2026-08-19

Two genuine gaps, both 🥇, and both sat directly on the critical path of this problem.
Neither was covered anywhere in Topics 1–39. **All three subtopics are now filed into the
roadmap** (Topic 16 → 7h, Topic 18 → 7h; tier distribution rebased to 66 🥇 / 64 🥈 / 32 🥉).

### Gap 1 — Gossip protocols & decentralized failure detection 🥇 *(critical — now **18.7**)*

**4.3 covers health checks from a load balancer**: an external prober, centralized, binary
up/down. A Dynamo-style ring has **no external prober.** Every node must learn membership
and liveness from its peers. Missing entirely:

- gossip / epidemic dissemination and why convergence is O(log N) rounds
- **SWIM** — indirect probing through k random peers to cut false positives
- **phi-accrual failure detection** — liveness as a continuous *suspicion score* rather than
  a boolean, because a 3-second GC pause and a dead machine look identical over one probe
- seed nodes, ring-state propagation, and why a premature "node down" is expensive
  (it triggers rebalancing, which moves terabytes, which causes more timeouts)

**Why it matters:** the guaranteed follow-up is *"a node stops responding — how does the rest
of the ring find out, and how do you avoid evicting a node over a GC pause?"* Nothing in the
roadmap answers this today. It also unlocks **#7 Kafka-like queue**, **#14 job scheduler**,
and every peer-to-peer archetype.

> **Filed as 18.7 🥇 — *Gossip protocols and decentralized failure detection
> (SWIM, phi-accrual).*** Topic 18 is right because gossip is the **membership** sibling of
> leader election: 18.2 answers *"who is in charge,"* 18.7 answers *"who is alive."* The
> build chain is decisive — 18.6 ends on "so you don't need consensus here," and the very
> next question is "then what *do* you use?" Cross-reference **4.3** (as contrast) and
> **18.5** (split-brain).

### Gap 2 — Anti-entropy and replica repair 🥇 + 🥈 *(critical — now **16.7 / 16.8**)*

**15.3 gives you a strict quorum. 16.3 tells you how to resolve two conflicting values once
you are holding both.** Nothing covers how divergent replicas *find* each other and converge.
That is the entire second half of this interview. Missing:

- **read repair** — synchronous on the read path vs. asynchronous in the background
- **hinted handoff and sloppy quorum** — accepting a write on a substitute node when a
  preference-list node is down, storing a hint, and replaying it on recovery
- **Merkle-tree anti-entropy** — diffing two replicas' key ranges in O(log n) transfers
  instead of shipping the whole range
- **tombstones and data resurrection** — why deletes need a grace period, and what happens
  when a node returns after it expires

**Why it matters:** without these, "eventually consistent" is a claim with no mechanism
behind it. Read repair alone is insufficient and knowing *why* is the staff signal — it only
fixes keys someone actually reads, so cold keys drift forever. That is what background
anti-entropy exists for.

> **Filed as two subtopics** (matching the 8.9 / 8.10 precedent, because one T1 budget
> cannot hold all of this):
>
> - **16.7 🥇 — *Read repair, hinted handoff, and sloppy quorum.*** The synchronous, on-the-
>   request-path half. Directly extends 16.4 and 15.3.
> - **16.8 🥈 — *Merkle trees and background anti-entropy repair.*** The asynchronous half,
>   plus tombstone GC.
>
> Topic 16 over Topic 15 because this is the **repair** half of replication and it builds
> straight out of 16.4 (leaderless) and 16.3 (conflict resolution). Study order:
> **16.4 → 16.3 → 16.7 → 16.8.**

### Near-misses — *not* gaps

- **Tunable consistency as a per-request dial.** 15.3 (R+W>N) and 17.7 (PACELC applied)
  cover this between them. The one thing missing is a single framing paragraph: in
  Dynamo/Cassandra the consistency level is chosen **per request** (`ONE` / `QUORUM` / `ALL`),
  not fixed per cluster. Add that note to 15.3's doc — it is a paragraph, not a subtopic.
- **Global secondary indexes.** Real KV design question, but adequately reachable through
  **12.1–12.3** (change streams → derived index) plus 8.4. Note it in the connection map.

---

## 📊 Readiness Assessment

**Phases A and B are ✅ complete and they pay off unusually well here** — Topic 7 hands you the
partitioner outright, and 8.4 hands you the storage engine. That is roughly the bottom third
of the design already owned.

**Phase E is the wall.** Topics 15, 16, 17 and 18 are **0 of 25 studied**, and 20 of those 25
are Tier A for this problem. There is no way around them.

| | Count | Est. hours |
|---|---|---|
| Tier A unfinished (existing subtopics) | 24 🥇 + 11 🥈 = **35** | **~91h** |
| Tier A unfinished (incl. newly filed 16.7 / 16.8 / 18.7) | 26 🥇 + 12 🥈 = **38** | **~99h** |
| Tier B unfinished | ~12 subtopics | ~28h |

> ⚠️ Hours use the calibrated T1 = 3h / T2 = 1.75h budgets.

### 🔑 The overlap insight — this is where the cheap era ends

```
 P1 ∪ P2 Tier A remaining              27
 P3 Tier A remaining                   35
 Shared with P1/P2                     18
 ─────────────────────────────────────────
 Marginal cost of adding P3            17 subtopics ≈ 41h  (+3 gap subtopics ≈ 8h)
 Union of all three problems           44 subtopics
```

**Rate limiter was a 12-hour add-on to the URL shortener. Key-value store is not.** It shares
18 subtopics with what you already owe, but the 17 it adds are the *entire Phase E core* —
15.1, 15.4, 16.3, 16.4, 17.1, 17.3, 17.7, 18.1, 18.2, 18.5, 18.6, 19.5, 20.1, 20.3, 20.6,
28.4, 8.10.

The compensating fact: **those 17 are the highest-reuse subtopics in the entire roadmap.**
Phase E is the shared substrate under #4 Distributed Cache, #5 Dropbox, #7 Kafka-like queue,
and #11 Chat. Paying for P3 is really paying for Phase E, and Phase E is the gate on four
more canonical problems.

> 📌 Treat P3 as **"study Phase E, and the KV store falls out of it"** — not as a third
> standalone design project.

---

## 🎯 Highest-Leverage Sprint (~17h)

Six subtopics. The chain is the tightest of the three problems so far — each one exists
*because* the previous one is insufficient.

 15.3  Quorum reads and writes — R + W > N            🥇 3h
        │  you now have a dial — but who enforces it with no leader?
        ▼
 16.4  Leaderless replication — Dynamo-style          🥈 1.75h
        │  no leader means replicas can diverge. What are you promising instead?
        ▼
 17.4  Eventual consistency                           🥇 3h
        │  "converges" is a promise — convergence needs a merge rule
        ▼
 16.3  Conflict resolution — LWW, vector clocks, CRDTs 🥇 3h
        │  you can merge once you hold both values. How do you come to hold both?
        ▼
 16.7  Read repair, hinted handoff, sloppy quorum      🥇 3h
        │  all of this avoided consensus. Was that legitimate?
        ▼
 18.6  When consensus is and is not needed             🥇 3h
        │  if not consensus, then what coordinates the ring?
        ▼
 18.7  Gossip and decentralized failure detection      🥇 3h

- [ ] 15.3 Quorum reads and writes — R + W > N 🥇
- [ ] 16.4 Leaderless replication — Dynamo-style 🥈
- [ ] 16.3 Conflict resolution — LWW, vector clocks, CRDTs 🥇
- [ ] **16.7 Read repair, hinted handoff, sloppy quorum** 🥇
- [ ] **18.7 Gossip and decentralized failure detection** 🥇
- [ ] 18.6 When consensus is and is not needed 🥇

> ✅ **16.7** and **18.7** were filed into the roadmap on 2026-08-19 — the sprint is ready to
> run as written.
>
> 💡 Overlap with prior sprints: **15.3** is already on the URL-shortener list. The other
> five are new, which is the concrete form of "P3 is a real second project."

---

## ✅ Tier A Remaining — Checklist

**Already complete (26 of 61 Tier A subtopics)**

- [x] Topic 1 — Estimation (1.6, 1.9, 1.10, 1.11, 1.14, 1.15)
- [x] Topic 2 — Core Principles (2.1, 2.2, 2.5, 2.6, 2.7, 2.10)
- [x] 3.6 · 4.3 · 5.4 · 5.7
- [x] Topic 7 — Sharding (7.2, 7.4, 7.5, 7.6, 7.7)
- [x] 8.1 · 8.4 · 8.6 · 8.7 · 11.1

**Remaining (35)**

- [ ] 8.10 Bloom filters — probabilistic membership testing 🥈
- [ ] 15.1 Replication — why and how 🥇
- [ ] 15.2 Leader/follower model 🥇
- [ ] 15.3 Quorum reads and writes — R + W > N 🥇
- [ ] 15.4 Durability guarantees and replication factor 🥈
- [ ] 15.5 Synchronous vs. asynchronous replication trade-offs 🥇
- [ ] 15.6 Replication lag and read anomalies 🥇
- [ ] 16.3 Conflict resolution — LWW, vector clocks, CRDTs 🥇
- [ ] 16.4 Leaderless replication — Dynamo-style 🥈
- [ ] 16.5 Read replicas — architecture and failover 🥇
- [ ] 16.6 Write propagation and replication lag 🥈
- [ ] 17.1 Linearizability (strong consistency) 🥇
- [ ] 17.3 Causal consistency 🥈
- [ ] 17.4 Eventual consistency 🥇
- [ ] 17.5 Read-after-write consistency 🥇
- [ ] 17.6 CAP theorem in practice 🥇
- [ ] 17.7 PACELC applied to real system choices 🥈
- [ ] 18.1 The consensus problem — safety, liveness, FLP 🥈
- [ ] 18.2 Raft — leader election 🥇
- [ ] 18.5 Split-brain — cause and prevention 🥇
- [ ] 18.6 When consensus is and is not needed 🥇
- [ ] 19.1 Retries — naive vs. exponential backoff 🥇
- [ ] 19.2 Jitter 🥇
- [ ] 19.4 Graceful degradation 🥇
- [ ] 19.5 Redundancy patterns — active-active, active-passive 🥈
- [ ] 19.7 Timeout strategies 🥈
- [ ] 20.1 RPO vs. RTO 🥇
- [ ] 20.3 Point-in-time recovery — WAL/binary log replay 🥈
- [ ] 20.6 Backup vs. replication — complementary roles 🥇
- [ ] 22.3 Metrics — counters, gauges, histograms 🥈
- [ ] 22.5 SLO, SLA, SLI 🥇
- [ ] 22.6 Distributed tracing 🥇
- [ ] 28.1 When distributed locking is needed 🥇
- [ ] 28.4 Fencing tokens — preventing stale lock holders 🥇
- [ ] 28.6 Alternatives to locking — idempotency and optimistic concurrency 🥇

**Filed into the roadmap 2026-08-19 (included in the 35 → 38 count)**

- [ ] 16.7 Read repair, hinted handoff, and sloppy quorum 🥇 *(new)*
- [ ] 16.8 Merkle trees and background anti-entropy repair 🥈 *(new)*
- [ ] 18.7 Gossip protocols and decentralized failure detection 🥇 *(new)*

> 🔎 **Data discrepancy noted 2026-08-19:** `index.html` marks **8.5** as `done: true` and a
> doc file exists, but the roadmap still shows `- [ ] 🥈 8.5`. The roadmap is the source of
> truth, so 8.5 is treated as unfinished above. Worth reconciling.

---

## 🧨 The Three Questions That Separate Staff from Senior

1. **"A node goes down mid-write. What happens to that write?"**
   Strict quorum: if W replicas can't ack, the write **fails** — you traded availability away
   at exactly the moment you needed it. Sloppy quorum + hinted handoff: any W *healthy* nodes
   accept it, a hint is stored on a stand-in, replayed on recovery. The cost is the part
   people miss — during a partition both sides may accept writes for the same key, which
   **guarantees** a conflict, which forces you into 16.3. The staff answer names the whole
   cascade, not just the words "hinted handoff."
   → 15.3, **16.7**, 16.3

2. **"How does the cluster know a node is down, and how do you avoid a false positive?"**
   Not a load-balancer health check — there is no external prober in a peer ring. Gossip
   plus phi-accrual: liveness is a **suspicion score**, not a boolean, because a 3-second GC
   pause and a dead machine are indistinguishable over one probe. And a false positive is
   *expensive*: declaring a node dead triggers rebalancing, which moves terabytes, which
   causes more timeouts, which declares more nodes dead.
   → **18.7**, contrast with 4.3, 18.5

3. **"Two clients write the same key at the same instant. Which one wins?"**
   LWW: trivial, needs synchronised clocks, and **silently discards a write** — sometimes
   acceptable, sometimes a lost shopping cart. Vector clocks: correct, but they push the
   merge onto the client and grow unboundedly without pruning. CRDTs: auto-merge, but only
   for data types that admit it. The staff move is to establish **what the application can
   tolerate first**, then pick — not to lead with the mechanism.
   → 16.3, 17.4, 16.2

> 🎯 **Bonus, and the real fork:** *"Why not just run Raft and get strong consistency?"* You
> can — that's etcd and Spanner. It costs you a leader per partition, a round trip to that
> leader on every write, and availability during leader election. Dynamo said no because the
> shopping cart had to accept writes during a datacenter partition. Naming the workload that
> justifies your side of the fork is the answer. → **18.6**, 18.2, 2.2

---

## 🔗 Related Files

- `system_design_study_roadmap.md` — source of truth for tiers and completion
- `01_url_shortener_topic_coverage.md` — shares 15.x / 16.5 / 17.x / 19.x / 28.x
- `02_rate_limiter_topic_coverage.md` — shares 17.4 / 17.6 / 19.x / 22.x / 28.1 / 28.6
- `topic_connection_map.md` — cross-topic interview connections
- `system_design/docs/index.html` — P3 filter registered 2026-08-19
