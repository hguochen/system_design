# 7.5 Rebalancing — Adding and Removing Nodes

> **Topic:** Topic 7 — Data Partitioning / Sharding
> **Phase:** B — Scalability Branch
> **Date studied:** 2026-07-16

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

Rebalancing is the process of **moving data (and the request load that follows it) between nodes when the cluster's membership or data distribution changes** — a node is added to scale out, a node is removed or fails, or one shard has grown far hotter/larger than its peers. The previous subtopic (7.4 Consistent Hashing) gave you a *placement rule* that keeps the number of keys that must move small (`~K/N`); rebalancing is the *operational discipline* of actually executing that movement safely, incrementally, and without taking the system down or degrading it into a brownout. The central question this subtopic answers is: **"When you add or remove capacity, how does data get redistributed — who decides, how much moves, how do reads/writes stay correct during the move, and how do you avoid making the cluster slower while you're trying to make it bigger?"**

The heart of the topic is a set of **rebalancing strategies** and why the naive ones fail. `hash mod N` rebalancing is rejected outright (nearly everything moves). Consistent hashing minimizes *how many* keys move but introduces its own operational realities (streaming, token assignment). The strategy that most production systems actually use — **a fixed, large number of partitions** decoupled from the node count — is the key insight to internalize: you don't split or merge partitions on membership change, you just *reassign whole partitions* between nodes. Layered on top are the questions of **automatic vs. manual rebalancing**, **rate-limiting/throttling the data movement**, **request routing during the transition**, and **detecting when rebalancing is even needed**.

### 🎯 What to Focus On

**1. Why `hash mod N` is disqualified and what "minimal movement" really costs.** You already know mod-N remaps ~everything. The focus here is the operational consequence: rebalancing isn't free even when minimal — moving `K/N` keys still means streaming gigabytes-to-terabytes across the network while serving live traffic. The interviewer wants you to reason about *movement volume*, *network/disk saturation*, and *time-to-rebalance*, not just "consistent hashing fixes it."

**2. Fixed partition count (the dominant production strategy).** This is the single most important idea in the subtopic. Create a large fixed number of partitions up front (e.g., 1,000s), assign many partitions to each node, and on membership change **move whole partitions between nodes** — never split them. Nodes gain/lose partitions; keys never change which partition they belong to. Know why this is simpler and more predictable than dynamic splitting. (Riak, Elasticsearch, Couchbase, Citus, Kafka consumer groups all use variants.)

**3. Dynamic partitioning (split/merge) and its trade-offs.** The alternative: partitions split when they exceed a size threshold and merge when they shrink (HBase regions, MongoDB chunks, CockroachDB/Spanner ranges). It adapts to data volume automatically but adds complexity, can cause split storms, and needs a bootstrap strategy (pre-splitting) to avoid a single hot partition at the start.

**4. The operational mechanics of a live move.** How a partition actually migrates without losing writes: snapshot + stream the bulk, then catch up the delta (log/changes since snapshot), then an atomic-ish ownership cutover, then route to the new owner. Understand dual-reads/dual-writes or read-from-old-until-caught-up, and why you throttle streaming to protect foreground latency.

**5. Automation, routing, and detection.** Who decides to rebalance — fully automatic (can amplify failures into cascades) vs. human-in-the-loop (safer, slower)? How does the request router learn the new mapping (gossip, coordination service like ZooKeeper/etcd, or a routing tier)? And how do you *detect* imbalance in the first place (per-shard size, QPS, p99, storage skew)? This ties directly forward into 7.6 Hot Partitions.

---

## 1. 🎯 Goal of This Subtopic

After studying this, you should be able to:

- **Explain why rebalancing is a first-class operational concern**, not a side effect — and why `hash mod N` is unusable because a single membership change would move almost all data.
- **Compare the three main rebalancing strategies** (fixed partition count, dynamic split/merge, and consistent-hashing token reassignment) and pick the right one for a given workload, naming a real system that uses each.
- **Walk through a live partition migration step by step** — snapshot, stream, catch-up delta, ownership cutover, reroute — and explain how reads/writes stay correct throughout.
- **Reason about the cost of rebalancing**: how much data moves, how long it takes, why you throttle it, and how it can degrade foreground traffic (the "rebalancing makes things slower" trap).
- **Decide between automatic and manual rebalancing** and justify the choice in terms of blast radius and cascading-failure risk.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can explain why rebalancing on `hash mod N` moves nearly all keys, and contrast it with the ~`K/N` (or "one partition's worth") movement of consistent hashing / fixed partitions
- [ ] Can describe the **fixed-partition-count** strategy precisely — partitions ≫ nodes, whole partitions reassigned on membership change, keys never change partition — and explain why it's the production default
- [ ] Can contrast **dynamic partitioning** (split/merge by size, e.g. HBase/MongoDB) with fixed partitioning and state the trade-off (adapts to volume vs. added complexity + split storms + pre-split bootstrap)
- [ ] Can walk through a **live migration** end to end and explain how in-flight writes aren't lost during the cutover
- [ ] Can explain why you **throttle/rate-limit** rebalancing and how unthrottled rebalancing degrades or cascades (rebalancing storm during a failure)
- [ ] Can argue **automatic vs. manual** rebalancing in terms of blast radius, and describe how the **request router** discovers the new key→node mapping
- [ ] Can estimate roughly how long a rebalance takes given data volume and a throttled transfer rate

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] Read **"Designing Data-Intensive Applications" Chapter 6 — Partitioning** (Martin Kleppmann), the "Rebalancing Partitions" section — the canonical treatment of fixed partitions, dynamic partitioning, and "partitioning proportionally to nodes"
- [ ] Read the **Amazon Dynamo paper (SOSP 2007)**, Section 6.2 — "Partitioning and placement of key," including the evolution away from the naive random-token strategy to fixed partitions ("Strategy 3")
- [ ] Read the **HBase / MongoDB docs on region/chunk splitting and pre-splitting** to see dynamic partitioning in production
- [ ] Read **Sections 5–9** of this doc (Core Definition → How It Works) carefully — don't skim
- [ ] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **Core Definition** from memory, then compare
- [ ] Explain **First Principles** out loud without notes — why can't you just re-run `hash mod N`, and why is even "minimal" movement operationally expensive?
- [ ] Reconstruct the **How It Works** mechanics — fixed-partition reassignment and a live migration's snapshot→stream→catch-up→cutover — step by step from memory
- [ ] Restate each **Trade-off** row in your own words — if you can't explain the cost, you don't own it yet

### Phase 3 — Apply 🔧 💪💪💪💪
*Goal: Connect to real systems and simulate interview scenarios.*

- [ ] Go through **Real-World System Examples** (Section 10) — verify each claim independently and add anything missed to **My Notes**
- [ ] Practice the **Interview Application** (Section 12) out loud — say the trigger phrases and your response as if in a live interview
- [ ] Work through **Common Misconceptions** (Section 13) — for each, make sure you can explain *why* the misconception is wrong, not just that it is
- [ ] Trace the **Relationships to Other Concepts** (Section 14) — can you explain each connection without looking?

### Phase 4 — Validate 🧪 💪💪💪💪💪
*Goal: Confirm you actually own it, not just recognize it.*

- [ ] Answer every **Self-Check Quiz** question (Section 15) out loud without looking at your notes
- [ ] Recite the **Cheatsheet** (Section 4) from memory — if you can't, re-do Phase 2
- [ ] Tick off items in **What Mastery Looks Like** (Section 2) — only check a box if you can demonstrate it on demand, not just if it sounds familiar
- [ ] Teach this concept out loud to an imaginary interviewer for 2 minutes without hesitation or notes

---

## 4. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

### 🗺️ Rebalancing Strategy Decision Map

```
Cluster membership or data distribution changed (add/remove node, skew, hot shard)?
├── No  ──────────────────────────────────────────► No rebalance needed
└── Yes
    │
    ▼
Are you tempted to re-run hash(key) % N?
├── Yes ──► ❌ STOP. Changing N remaps ~all keys → mass movement + miss storm.
└── No
    │
    ▼
Does data VOLUME per key-range vary a lot and grow unpredictably
(time-series, uneven key density)?
├── Yes ─────────────────────────────► DYNAMIC PARTITIONING (split/merge by size)
│                                        HBase regions, MongoDB chunks, Spanner/CRDB ranges
│                                        + pre-split to avoid single hot start partition
└── No (roughly uniform, count-driven scaling)
    │
    ▼
                  FIXED PARTITION COUNT (the default)
          Create P ≫ N partitions up front; assign many per node.
          On membership change: MOVE WHOLE PARTITIONS between nodes.
          Keys NEVER change partition; only partition→node mapping changes.
    │
    ▼
Executing the move — protect live traffic:
    ┌─────────────────────────────────────────────────────────┐
    │  1. Snapshot partition → 2. Stream bulk to new owner      │
    │  3. Catch up delta (writes since snapshot)                │
    │  4. Atomic ownership cutover → 5. Reroute requests        │
    │  THROTTLE the transfer (cap bandwidth/concurrent moves)   │
    └─────────────────────────────────────────────────────────┘
    ⚠️  AUTOMATIC rebalance + node failure = rebalancing storm → cascade.
        Prefer human-in-the-loop for the trigger; automate the mechanics.
    ⚠️  Router must learn the NEW mapping (gossip / ZooKeeper-etcd / routing tier)
        or requests hit the wrong node during transition.
```

```
§ 1  WHY IT EXISTS
Clusters aren't static: you scale out, nodes die, data grows unevenly. When membership
changes, SOME data must move so load and storage stay balanced. The naive move —
re-run hash(key) % N — is catastrophic: changing N changes the divisor so ~N/(N+1) of
all keys remap, meaning you move almost the entire dataset over the network while
serving live traffic. Rebalancing exists to make capacity changes CHEAP and SAFE: move
only the data that must move, do it incrementally, and keep reads/writes correct
throughout. It's the operational counterpart to the placement rule from consistent hashing.

§ 2  THE THREE STRATEGIES
1. FIXED PARTITION COUNT (default): create P partitions up front, P ≫ N. Each node holds
   many partitions. Add a node → it STEALS whole partitions from existing nodes. Remove a
   node → its partitions are redistributed. Keys never change partition; only the
   partition→node assignment changes. Simple, predictable. (Riak, Elasticsearch, Couchbase.)
2. DYNAMIC PARTITIONING (split/merge): a partition SPLITS when it exceeds a size threshold,
   MERGES when it shrinks. Partition count tracks DATA VOLUME, not node count. Adapts
   automatically; add complexity + "split storms"; needs pre-splitting to avoid a single
   hot partition at bootstrap. (HBase regions, MongoDB chunks, Spanner/CockroachDB ranges.)
3. PROPORTIONAL TO NODES (consistent-hash tokens): fixed partitions PER NODE; adding a node
   splits some existing partitions to give it a fair share. (Cassandra vnodes flavor.)

§ 3  THE LIVE MIGRATION (how a partition moves without losing writes)
  1. SNAPSHOT the partition on the source.
  2. STREAM the bulk snapshot to the destination (this is the slow part; THROTTLE it).
  3. CATCH UP: replay writes that landed since the snapshot (from a change log / hinted
     handoff), narrowing the delta until it's tiny.
  4. CUTOVER: briefly freeze/serialize, flip ownership atomically in the mapping.
  5. REROUTE: router now sends the key to the new owner; old owner can drop the data.
During transition: read from old owner until caught up, or dual-read; writes go to old
(and are logged for catch-up) or dual-write. Cutover is the only "stop-the-world" moment
and it's kept sub-second per partition.

§ 4  USE / AVOID
Use FIXED partitions:   general case, roughly uniform key density, count-driven scaling,
                        you want predictable ops. This is the safe default answer.
Use DYNAMIC partitions: data volume per range varies wildly / grows unpredictably
                        (time-series, wide key ranges), want auto-adaptation. Pre-split!
Use PROPORTIONAL:       consistent-hash/vnode systems where tokens scale with nodes.
AVOID hash % N rebalancing — changing N moves ~everything.
AVOID fully automatic rebalancing on failure — it can turn one dead node into a storm.
AVOID unthrottled streaming — it saturates NIC/disk and browns out foreground traffic.

§ 5  INTERVIEW TRIGGERS
→ "You add a node to the cluster — how does data get redistributed?"
→ "A shard is twice the size of the others. How do you rebalance?"
→ "How do you move a partition to a new node without downtime or losing writes?"
→ "Should rebalancing be automatic? What happens during a node failure?"

§ 6  FTAC
F  "Rebalancing moves data between nodes when membership or distribution changes. I'd never
   re-hash mod N — that moves everything. I'd use a large FIXED number of partitions
   assigned to nodes, and on a change just reassign whole partitions between nodes."
T  "Fixed partitions give predictable, minimal movement and simple ops, at the cost of
   choosing the partition count up front (can't easily change it) and some imbalance
   granularity. Dynamic split/merge adapts to volume but adds complexity and split storms."
A  "Assuming roughly uniform key density and count-driven scaling, with live traffic that
   can't take downtime —"
C  "Fix ~1000s of partitions up front, many per node. To add a node, migrate whole
   partitions to it: snapshot → stream (throttled) → catch up the write delta → atomic
   ownership cutover → reroute. Trigger manually or with guardrails; automate the mechanics."

§ 7  NUMBERS & GOTCHA
Movement volume:     fixed/consistent-hash ≈ one node's fair share ≈ K/N of data.
                     hash % N ≈ N/(N+1) of ALL data (e.g. 4→5 nodes ≈ 80%).
Partition count:     pick P ≫ N and fixed (e.g. Riak default 64–256 vnodes/ring;
                     Elasticsearch shards fixed at index creation; Kafka partitions fixed).
Rebalance time:      data_to_move ÷ throttled_rate. e.g. 500 GB ÷ 100 MB/s ≈ 83 min
                     (and you throttle BELOW line rate to protect p99).
Cutover freeze:      kept sub-second per partition; only the final delta is serialized.
GOTCHA #1: Fixed partition count is chosen ONCE and is painful to change later — too few
  and you can't spread across future nodes; too many and you pay per-partition overhead
  (metadata, open files, request fan-out). Size it for your MAX future cluster.
GOTCHA #2: Automatic rebalancing + failure detection can amplify a transient blip into a
  cascade: node looks dead → mass data movement starts → extra load makes MORE nodes look
  dead → storm. Rate-limit moves and require confirmation for the trigger.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

Rebalancing is the controlled redistribution of partitions (and their data and load) across nodes when the cluster changes — adding capacity, removing/failed nodes, or correcting skew — done so that only the minimum necessary data moves, the movement is incremental and throttled to protect live traffic, and reads and writes remain correct throughout; in practice it is almost always implemented by assigning a large **fixed** number of partitions to nodes and reassigning whole partitions on change, rather than by re-hashing keys with a node-count-dependent function.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*

### Fixed Partition Count (Decoupling Partitions from Nodes)

Create a large, fixed number of partitions `P` at cluster creation — many more than the number of nodes `N` (e.g., 1,000 partitions across 10 nodes = 100 each). A key's partition is determined once (`partition = hash(key) mod P`) and **never changes**, because `P` never changes. Only the *partition → node* assignment changes when you add or remove nodes. Adding a node hands it a fair slice of whole partitions stolen from existing nodes; removing a node redistributes its partitions to the survivors. This is the dominant production strategy because it makes movement predictable (you move whole partitions, integer counts) and keeps routing logic trivial (the partition function is stable).

### Dynamic Partitioning (Split and Merge)

Instead of a fixed count, partitions split when they grow past a size threshold (e.g., HBase splits a region at ~10 GB) and merge when they shrink. The number of partitions tracks the *data volume*, so a small dataset has few partitions and a large one has many — the system self-tunes. The costs: added complexity (split coordination, metadata churn), the risk of "split storms" under bursty writes, and a cold-start problem — a brand-new table has one partition on one node, so all initial writes hit a single machine until it splits. The fix is **pre-splitting**: seed the table with multiple empty partitions up front.

### Partition Reassignment vs. Key Remapping

The critical distinction. **Key remapping** (`hash mod N`) changes *which partition a key belongs to* when `N` changes — so nearly every key moves. **Partition reassignment** changes *which node owns a partition* while the key→partition mapping stays fixed — so only whole partitions move, and only as many as needed to rebalance. Every good rebalancing strategy is built on reassignment, not remapping. This is the single idea that separates a working design from a naive one.

### Live Migration (Snapshot → Stream → Catch-up → Cutover)

Moving a partition while it's serving traffic. You snapshot its current state, stream the (large) snapshot to the destination in the background, then replay the writes that occurred since the snapshot to shrink the delta, then perform a brief atomic ownership cutover and reroute requests to the new owner. The snapshot/stream phase is slow and throttled; the cutover is fast (sub-second) because only the tiny final delta is serialized. This machinery is what makes "zero-downtime" rebalancing possible.

### Throttling / Rate-Limiting the Move

Rebalancing competes with live traffic for the same NIC, disk, and CPU. Unthrottled, a big transfer saturates the network and spikes foreground p99 — you make the system *slower* while trying to make it *bigger*. So systems cap the streaming bandwidth and the number of concurrent partition moves (e.g., "move at most 2 partitions at once at 50 MB/s each"). The trade-off is time-to-rebalance vs. foreground impact; you deliberately transfer below line rate.

### Automatic vs. Manual Rebalancing

Who pulls the trigger. **Automatic** rebalancing reacts to detected imbalance or node loss with no human in the loop — fast recovery, but dangerous: a transient network blip can be misread as a dead node, kicking off mass data movement that adds load and makes *more* nodes look dead (a rebalancing storm / cascading failure). **Manual** (or semi-automatic) rebalancing keeps a human to confirm the trigger while the mechanics run automatically — safer, with a bounded blast radius, at the cost of slower response. The common production stance: automate the *how*, gate the *whether*.

### The Request Router (Mapping Discovery)

During and after a rebalance, requests must reach the current owner of each partition. Something has to know the live partition→node map: a coordination service (ZooKeeper/etcd) that clients or a routing tier watch, gossip among nodes (Dynamo/Cassandra style), or a dedicated routing layer that clients query. If the router's view is stale during a move, requests hit the wrong node — handled by forwarding, retry, or a short read-from-old window. This is the same "service discovery / routing" concern that shows up across distributed systems.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

The root problem is that **capacity and data are both moving targets, but a partitioning scheme assigns fixed ownership.** You shard data across nodes to spread storage and load; but the number of nodes changes (you scale out as traffic grows, nodes crash, hardware gets retired) and the data itself grows unevenly (some key ranges get far more data or traffic than others). The moment any of those change, the original assignment is no longer balanced — some node is now overloaded or holds too much data, or a dead node's share has to go somewhere. So *some* data must move. The question is only *how much* and *how safely*.

The naive answer, `node = hash(key) mod N`, is seductive because it needs no coordination and spreads keys evenly — but it couples the assignment to `N`. Change `N` by one and the modulus changes for almost every key, so almost the entire dataset must physically relocate. At scale that's terabytes streaming across the network, a cache-miss storm, and hours of degraded service just to add one machine — which defeats the entire purpose of elastic scaling. Rebalancing as a discipline exists to break that coupling: **make the amount of data that moves proportional to the amount of capacity that changed, not to the total dataset size.** Fixed partitions achieve this by making the key→partition mapping independent of `N` (only partition→node assignment depends on the cluster), so adding one node moves roughly `1/N` of the data. And because even that `1/N` is expensive to move over a live system, the second first-principle is *incrementality and safety*: move in throttled chunks, keep serving from the old owner until the new one is caught up, and cut over atomically — so the cluster stays correct and responsive while it reshapes itself.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*

### Model 1: Assigned Seating vs. Re-seating Everyone (Fixed Partitions)

Imagine a wedding with 1,000 named place-cards (partitions) distributed across 10 tables (nodes), 100 cards per table. Each guest (key) has a fixed place-card that never changes. To add an 11th table, you don't reprint every card — you just *move ~90 place-cards* from the existing tables to the new one until each table has ~91. Guests never learn a new card; only the card→table assignment shifts. Contrast this with `hash mod N` seating, where adding a table means recomputing every single guest's table from scratch — everyone gets up and moves. This model nails why fixed partitions move so little: you relocate whole *cards*, not *rewrite the seating function*. It breaks down if partitions are wildly uneven in size — a "place-card" that represents a huge chunk of data can't be moved as cheaply as the model implies.

### Model 2: Filling a Moving Truck While the Store Is Open (Live Migration)

Rebalancing a live partition is like relocating a store's inventory to a new location while customers keep shopping. You can't just lock the doors. So you (1) take an inventory snapshot, (2) truck the bulk of the goods over during off-peak hours at a controlled pace so you don't block the loading dock (throttling), (3) keep a running list of everything sold or restocked since the snapshot and reconcile it (catch-up), then (4) at the quietest possible moment, flip the "open" sign from the old store to the new one (cutover). Customers shop at the old store until the instant of the flip. This captures why the cutover is short (only the small final delta is frozen) and why you throttle (the loading dock is shared with live business). It breaks down if writes come faster than you can catch up — then the delta never shrinks and you can't cut over, which is a real failure mode under extreme write load.

### Model 3: The Thermostat That Can Start a Fire (Automatic Rebalancing)

Automatic rebalancing is a thermostat wired to a very powerful furnace. Normally it's great — it senses imbalance and corrects it without you. But if the *sensor* is flaky (a transient network partition makes a healthy node look dead), the thermostat blasts the furnace (mass data movement), the extra heat trips *other* sensors (added load makes more nodes look unresponsive), and now you have a runaway feedback loop — a rebalancing storm. The lesson: put a governor on the furnace (rate-limit moves) and a human hand near the thermostat for the big swings (gate the trigger). It breaks down as an argument against automation entirely — you *do* want automation for the mechanics and for small, confident corrections; the model is specifically about the danger of automating the *decision to move massive amounts of data* based on possibly-wrong signals.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

**Strategy A — Fixed partition count (the default):**
1. At cluster creation, choose `P` partitions with `P ≫ N` (e.g., `P = 1024`, `N = 10`). `P` is fixed for the life of the cluster.
2. Key placement: `partition = hash(key) mod P`; then look up `node = owner(partition)` in the mapping. The first step never changes; only the second is mutable.
3. **Add a node:** the new node claims a fair share of partitions — roughly `P/(N+1)` of them — taken a few from each existing node. Each claimed partition is migrated (see live migration below). Movement ≈ `1/(N+1)` of total data.
4. **Remove a node:** its `P/N` partitions are reassigned across the survivors, each migrated from a replica or the departing node. Movement ≈ that node's share.
5. Because you always move *whole partitions*, movement is a clean integer count and the routing function stays stable.

**Strategy B — Dynamic partitioning (split/merge):**
1. Start with few partitions (ideally *pre-split* into several to avoid a single hot start partition).
2. **Split:** when a partition exceeds the size threshold (e.g., HBase ~10 GB region, MongoDB 64–128 MB chunk logical bound), it splits into two at a midpoint key; one half may migrate to another node to balance.
3. **Merge:** when adjacent partitions shrink (e.g., after deletes), they merge to avoid partition sprawl.
4. Partition count now tracks data volume, so the system auto-adapts — at the cost of split coordination, metadata churn, and split-storm risk under bursty ingest.

**The live migration of a single partition (the core mechanic):**
1. **Snapshot:** capture a consistent point-in-time image of the partition on the source node.
2. **Bulk stream:** transfer the snapshot to the destination in the background, **rate-limited** to protect foreground latency. This dominates the wall-clock time.
3. **Catch-up (delta sync):** replay writes that landed on the source since the snapshot — from a change log, commit log, or hinted-handoff queue — repeatedly, shrinking the delta toward zero.
4. **Cutover:** briefly serialize writes for that one partition, apply the final tiny delta, and flip ownership atomically in the mapping (often via a coordination service). This freeze is sub-second.
5. **Reroute + cleanup:** the router directs requests for that partition to the new owner; the old owner may serve as a temporary forwarder, then drops the data.

**Request routing during the transition:**
- Clients/router learn the mapping from a coordination service (ZooKeeper/etcd), gossip (Dynamo/Cassandra), or a routing tier.
- If a request arrives at a node that no longer owns the partition, it's **forwarded** to the current owner or answered with a redirect/retry — so a stale router view degrades to an extra hop, not an error.

**Detecting that rebalancing is needed:**
- Track per-partition/per-node **storage size**, **request rate (QPS)**, and **tail latency (p99)**. An imbalance (one shard 2–3× the median size or QPS) or a membership change triggers a rebalance decision — automatically with guardrails, or surfaced to an operator.

**Key formulas / thresholds worth memorizing:**
- Movement on membership change (fixed/consistent-hash): ≈ `K/N` keys ≈ `1/N` of data. Modulo: ≈ `N/(N+1)` of all keys.
- Rebalance wall-clock ≈ `data_to_move ÷ throttled_transfer_rate` (e.g., `500 GB ÷ 100 MB/s ≈ 83 min`).
- Choose `P` for your *maximum future* `N`: `P` must be ≥ max node count, and large enough that `P/N` gives fine-grained balance without excessive per-partition overhead.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| **Riak** | Fixed ring of partitions (vnodes), count set at creation (default 64/128/256), power of two; on node add/remove, whole vnodes are handed off between physical nodes | Textbook fixed-partition rebalancing — the ring size never changes, only vnode→node placement |
| **Elasticsearch** | Shard count is **fixed at index creation** and cannot be changed without reindexing; the cluster rebalances by relocating whole shards between nodes to even out disk and load | Classic "choose P up front, can't change it" trade-off — over-sharding to allow future growth is a known anti-pattern too |
| **Apache HBase** | **Dynamic** partitioning: regions auto-split at a size threshold (~10 GB) and can be moved between RegionServers; pre-splitting is standard to avoid a single hot region at table creation | The canonical split/merge example; "region hotspotting" on monotonic keys is the classic failure |
| **MongoDB (sharded)** | **Dynamic** chunk-based partitioning; the balancer migrates chunks between shards to equalize count; chunks split when they grow; pre-splitting/zone sharding used to bootstrap | Balancer runs in the background and is throttled; migrations are online with a catch-up + cutover protocol |
| **Amazon Dynamo / Cassandra** | Dynamo's "Strategy 3" moved to **fixed equal-sized partitions** for predictable movement; Cassandra uses vnodes (tokens) so adding a node streams a fair share of ranges from many peers | Dynamo paper explicitly documents evolving *away* from naive random tokens toward fixed partitions |
| **Apache Kafka** | Partition count per topic is **fixed** (increasing is allowed but breaks key→partition ordering); consumer-group rebalancing reassigns whole partitions to consumers on membership change | Two rebalances: partition→broker (data) and partition→consumer (processing); both reassign whole partitions |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Fixed partition count → movement is minimal, predictable (whole partitions), and routing stays simple | `P` is chosen once and painful to change; too few limits future scale-out, too many adds per-partition overhead (metadata, open files, fan-out) |
| Dynamic split/merge auto-adapts partition count to data volume — no upfront sizing | Added complexity, split-storm risk under bursty writes, and a cold-start hot partition unless you pre-split |
| Live migration (snapshot→stream→catch-up→cutover) enables zero-downtime rebalancing | Complex to implement correctly; under extreme write rates the catch-up delta may never shrink enough to cut over |
| Throttling protects foreground p99 during rebalancing | Slower time-to-rebalance — you deliberately transfer below line rate, so recovery/scale-out takes longer |
| Automatic rebalancing recovers fast with no human in the loop | Can misread a transient blip as failure and trigger a rebalancing storm / cascade; safer designs gate the trigger manually |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "You add a node to scale out the cluster — walk me through how the data gets redistributed."
- "One shard is twice the size of the others / is getting hammered — how do you rebalance without downtime?"
- "How do you move a partition to a new node without losing in-flight writes?"
- "Should rebalancing be automatic? What could go wrong during a node failure?"

**What you say / do:**
Bring this up in the data-partitioning deep-dive or when discussing scaling/failure handling. Say something like: "I'd never rebalance by re-hashing mod N — that moves almost all the data. I'd create a large fixed number of partitions up front, say a few thousand, and assign many to each node. To add a node, I migrate whole partitions to it: snapshot the partition, stream it in the background under a bandwidth cap, catch up the write delta from the commit log, then do a sub-second atomic ownership cutover and reroute. That moves only about 1/N of the data and keeps foreground latency protected. If key density were wildly uneven — say time-series — I'd consider dynamic split/merge instead, with pre-splitting to avoid a hot start partition. I'd gate the *decision* to rebalance behind guardrails so a transient failure doesn't kick off a rebalancing storm, but automate the mechanics."

**The trade-off statement (memorize this pattern):**
> "Fixed-partition rebalancing gives me minimal, predictable data movement and simple routing — only whole partitions move, about 1/N of the data — at the cost of choosing the partition count up front, which I can't easily change later. Dynamic split/merge would remove that upfront sizing but adds complexity and split-storm risk. And whichever I pick, I throttle the movement so I don't brown out live traffic while I'm scaling — trading a slower rebalance for protected p99."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** To rebalance after adding a node, you just re-run `hash(key) % N` with the new N.
  ✅ **Reality:** Changing `N` changes the modulus for nearly every key, so ~`N/(N+1)` of *all* data moves — a mass migration and (for caches) a total miss storm. Real systems keep the key→partition mapping independent of `N` (fixed `P`) and only reassign partition→node ownership.

- ❌ **Misconception:** Fixed partitioning splits partitions when you add a node.
  ✅ **Reality:** Fixed partitioning *never* splits or merges on membership change — the count `P` is constant. Adding a node just *reassigns whole existing partitions* to it. Splitting/merging is the *dynamic* strategy, which is a different approach with different trade-offs.

- ❌ **Misconception:** Rebalancing is basically free once you use consistent hashing.
  ✅ **Reality:** Consistent hashing minimizes *how many* keys move, but you still physically stream that `1/N` of the data — potentially terabytes — across the network while serving live traffic. That's why throttling, catch-up, and careful cutover exist. "Minimal movement" ≠ "no cost."

- ❌ **Misconception:** Automatic rebalancing is strictly better because it recovers faster.
  ✅ **Reality:** Fully automatic rebalancing can amplify a transient blip into a cascade: a node briefly looks dead → mass movement starts → the extra load makes more nodes look dead → rebalancing storm. Production systems commonly automate the mechanics but gate the *trigger* (rate limits, thresholds, human confirmation for big moves).

- ❌ **Misconception:** More partitions are always better because they balance more finely.
  ✅ **Reality:** Each partition carries overhead — metadata, open file handles, a slot in every routing table, and request fan-out on scatter-gather queries. Too many partitions (over-sharding) bloats memory and slows queries. You size `P` for your *maximum future* cluster, not arbitrarily high.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** [[topic_7.4_consistent_hashing_algorithm_and_virtual_nodes]] 7.4 Consistent Hashing — provides the *placement rule* that makes movement minimal (`K/N`); rebalancing is the operational execution of that movement. Also builds on 7.2 Hash Partitioning (the `hash mod P` that assigns keys to partitions) and 7.1 Horizontal Partitioning (rebalancing only exists because data is spread horizontally across nodes).
- **Enables:** [[topic_7.6_hot_partitions_detection_and_mitigation]] 7.6 Hot Partitions — one mitigation for a hot shard is to split and rebalance it, so this subtopic's mechanics are a prerequisite; and elastic autoscaling of stateful tiers in general, which is only viable if adding/removing capacity is cheap and safe. Replication (Dynamo-style) also relies on rebalancing to re-establish replica placement after a change.
- **Tension with:** foreground latency / availability — rebalancing competes with live traffic for network and disk, so it's in direct tension with p99 SLOs (hence throttling); and with strong consistency during the cutover window, where in-flight writes must be handled carefully. There's also tension with 7.6 Hot Partitions in that a hot *key* can't be fixed by rebalancing at all (it maps to one partition), only a hot *partition* can.

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. What is rebalancing, and why is re-running `hash(key) % N` with the new node count the wrong way to do it?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 5 and Section 7.*

2. You have a 10-node cluster and add an 11th. Using the fixed-partition-count strategy with 1,000 partitions, roughly how many partitions move, from where to where, and does any key change which partition it belongs to?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6 (Fixed Partition Count) and Section 9.*

3. Walk through how a single partition migrates to a new node without losing writes that arrive during the move. What is the only "stop-the-world" moment and why is it short?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 9 (live migration) and Section 8 Model 2.*

4. Why do production systems throttle rebalancing, and what's the trade-off you're making when you do?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 11 and the §7 numbers.*

5. Give a concrete scenario where fully automatic rebalancing turns a single transient node failure into a cluster-wide outage. How would you prevent it?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 13 and Section 8 Model 3.*

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **"Designing Data-Intensive Applications" Chapter 6 — Partitioning** (Martin Kleppmann) — the "Rebalancing Partitions" section; the definitive comparison of fixed count, dynamic, and proportional strategies, plus "operations: automatic or manual rebalancing"
- [ ] **Amazon Dynamo paper (SOSP 2007)**, Section 6.2 — https://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf — the three partitioning strategies and why they landed on fixed equal-sized partitions
- [ ] **Apache HBase Reference Guide — Region Splitting & Pre-splitting** — https://hbase.apache.org/book.html#regions.arch — production dynamic partitioning and how to avoid hotspotting
- [ ] **MongoDB Docs — Sharded Cluster Balancer & Chunk Migration** — https://www.mongodb.com/docs/manual/core/sharding-balancer-administration/ — online chunk migration protocol and throttling
- [ ] **ByteByteGo / DDIA notes — "Rebalancing partitions"** — accessible visual walkthrough of moving partitions between nodes

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

MODEL ANSWER — Criterion 1

(a) hash(key) % N ties a key's destination NODE to N (the divisor = node count).
    hash(key) is stable, but the MODULO RESULT flips when N changes: a key that
    mapped to hash%4 now maps to hash%5, a different node for almost every key.
    Fraction that moves ≈ N/(N+1) → 4→5 nodes ≈ 4/5 (~80%). For a cache that's a
    near-total miss storm; for a store it's moving ~the whole dataset.

(b) Fixed-partition / consistent hashing decouples key placement from node count.
    Keys hash to a FIXED number of partitions (partition = hash(key) % P); P never
    changes, so a key's partition never changes. Nodes merely OWN partitions.
    Add a node → it takes over ~1/(N+1) of the partitions (≈ 1/5), and the keys
    inside those partitions ride along. Only that slice moves (~K/N ≈ 1/N of data);
    everything else stays put. Whole partitions move — not individual keys.

MODEL ANSWER — Criterion 2

(a) Create P ≫ N, sized for the MAXIMUM future cluster — e.g., 10,000 partitions
    for a cluster that may reach 100+ nodes (~100 partitions/node). Sizing P for
    today's 10 nodes is the mistake: P must be ≥ max N, ideally many partitions
    per node even at peak. High P:N buys (1) fine-grained balance (hand off single
    partitions to even load) and (2) headroom to grow. It does NOT change how much
    moves per node-add — that's ~1/N of data regardless of P.

(b) partition = hash(key) % P, and P is fixed for the cluster's life.
    (i)  Add node: it claims ~P/(N+1) whole partitions, a few from each existing
         node; the keys inside ride along. ~1/N of data moves. No key changes partition.
    (ii) Remove node: its partitions are reassigned across survivors, whole.
         ~1/N of data moves. No key changes partition.
    Only the partition→node assignment ever changes; key→partition is immutable.

(c) Default because it's simple and operationally predictable — whole-partition
    moves, stable routing, no split/merge machinery. Downside: P is chosen ONCE and
    painful to change. Too high → per-partition overhead (metadata, open files,
    fan-out) on a small dataset. Too low → you eventually hit a 1:1 partition:node
    ratio and can't spread across more nodes — a hard scaling ceiling.

MODEL ANSWER — Criterion 3

(a) DYNAMIC: partition count is driven by DATA VOLUME. A partition SPLITS when it
    crosses a size threshold (e.g., 10GB → two 5GB halves) and adjacent partitions
    MERGE when they fall below a low threshold (e.g., 2GB). Count self-tunes.
    FIXED: count is chosen ONCE up front and is painful to change.

(b) Bootstrap trap: a new table starts as ONE partition on ONE node, so all early
    writes hammer a single machine until it splits. A monotonic key (timestamp,
    auto-increment) makes it chronic: every new write targets the highest range, so
    even after splitting, the "tail" partition stays hot. Fix: pre-split to spread
    the initial load, AND design the key (salt / hash-prefix) so new writes scatter.

(c) Trade-off: dynamic self-tunes partition count to data volume (no upfront sizing,
    efficient at any scale) but costs split/merge coordination, metadata churn, and
    split-storm risk under bursty writes. Pick dynamic when volume per key-range is
    uneven or unpredictable — e.g., time-series/IoT/event logs, or multi-tenant
    stores with wildly different tenant sizes.

MODEL ANSWER — Criterion 4

(a) Phases:
    1. SNAPSHOT the partition on the current owner (point-in-time image).
    2. STREAM the snapshot to the new node in the background, THROTTLED so live
       traffic keeps priority on NIC/disk.
    3. CATCH UP: replay the ordered write-log accumulated since the snapshot,
       shrinking the delta toward ~0.
    4. CUTOVER: brief sub-second freeze on the old owner, apply the final tiny
       delta, flip ownership atomically (via the coordination service).
    5. REROUTE: router points the partition at the new owner; old owner drops data.

(b) The OLD node stays authoritative and serves BOTH reads and writes throughout.
    Every write it accepts is applied AND appended to an ordered log (WAL / change
    stream). Those logged writes are replayed to the new node in phase 3. Because
    each write is durably on the old node + captured in order, none can be lost.

(c) Cutover = brief freeze → apply final delta → atomic ownership flip → reroute.
    It's the only stop-the-world moment, but it's sub-second because only the tiny
    remaining delta is serialized (the bulk + most of the delta already moved live).
    Writes during the freeze are HELD and then applied — ZERO loss, just <1s delay.

MODEL ANSWER — Criterion 5

(a) Rebalancing shares NIC, disk I/O, and CPU with live traffic. Unthrottled, a big
    transfer saturates those and spikes foreground p99/p999 — you make the system
    SLOWER while making it bigger. Throttling (bandwidth cap + limited concurrent
    moves) protects tail latency; the trade-off is a longer time-to-rebalance.

(b) Storm loop (unthrottled + automatic): node blips → failure detector marks it
    dead → auto-rebalance starts mass data movement to re-replicate its partitions
    → that streaming load pushes OTHER nodes' latency up → detector marks THEM dead
    → even more movement → cascade. The cure becomes the disease.

(c) Guardrails: (1) MECHANISM — rate-limit concurrent moves / cap bandwidth so
    movement can't saturate the cluster. (2) TRIGGER — a grace period / averaging
    window before declaring a node dead, and human confirmation (or a hard
    threshold) for large moves. Automate the how; gate the whether.

MODEL ANSWER — Criterion 6

(a) Automatic = fast recovery (availability) but wide blast radius if the trigger
    misfires; manual = bounded blast radius but slower. Key axis is move SIZE and
    CONFIDENCE: automate the mechanics always, auto-run small confident corrections,
    but gate large/mass moves behind a human or hard threshold.

(b) The router/client learns the new partition→node map via:
    1. Coordination service (ZooKeeper/etcd) — authoritative map, watched for changes.
    2. Gossip — peer-to-peer ownership propagation (Dynamo/Cassandra/Riak).
    3. Routing tier / config servers (MongoDB mongos), often + client-side cache.

(c) A stale-view request hitting the old owner degrades to an EXTRA HOP, not an error:
    that node forwards it to the current owner (or returns a redirect the client
    retries). The request still succeeds; cost is a little latency. No loss, no
    atomicity issue.


Adversarial Stress-Test Gate
You're migrating a large partition using the exact snapshot → stream → catch-up → cutover flow you just described. But this partition is a write hotspot under a sustained, very high write rate. Every time you replay the accumulated delta to the new node, just as many new writes have piled up on the old node in the meantime — so the delta never shrinks toward zero. You can never reach a small-enough final delta to do a safe sub-second cutover. The migration is effectively stuck forever.
(a) What is fundamentally going on here — why does this specific flow break down?
(b) How do you actually get this partition migrated? Give me at least one concrete way to break the deadlock.

MODEL ANSWER — Adversarial Gate

Diagnosis: a RATE RACE. The delta shrinks only when catch-up DRAIN rate > incoming
WRITE rate. Throttling deliberately caps the drain to protect live traffic, so a
write-hot partition where ingest >= drain never converges — deadlock, regardless of
key design (a monotonic key is just one way to get write-hot).

Break it by widening drain > ingest:
  - Speed the DRAIN: lift/raise the migration throttle for a final sprint (trade p99).
  - Slow the INGEST: write backpressure on that partition, OR dual-write new writes to
    the new node so they stop feeding the delta (drain the historical backlog only).
  - Shrink the unit: split the hot partition first, migrate smaller pieces.
  - Last resort: extend the freeze, accept downtime proportional to delta size.

Limit: if it's a single HOT KEY, splitting won't help — indivisible, one node. That's
hot-key mitigation (replication / key-splitting), not rebalancing → Topic 7.6.