# 25.5 Distributed Rate Limiting with Redis

> **Topic:** Topic 25 — Rate Limiting Systems
> **Phase:** H — System Archetypes
> **Depth Tier:** 🥇 T1 (Core) — budget ~3h
> **Prereqs:** 25.1 (Token Bucket Algorithm), 25.4 (Sliding Window Log and Sliding Window Counter)
> **Date studied:** 2026-08-18

---

## 0. 🧭 The Question This Answers

25.1 and 25.4 both got the algorithm right and both got the atomicity right — a single Redis client, running a single Lua script, correctly and atomically checks-and-deducts against one key. What neither doc had to confront is where that client actually lives. Real API traffic never hits one process. It hits a fleet of stateless application or gateway instances (Topic 3, Topic 4) behind a load balancer, and every single one of them is being asked to enforce the *same* limit against the *same* client, independently, at the same time. Token bucket and sliding window are both correct answers to "how do I count requests for one key," but neither one answers "how do many separate processes, that don't talk to each other, agree on one shared count."

The naive move is obvious once you say it out loud: point every instance at the same Redis, reuse the atomic Lua-script pattern 25.1 and 25.4 already established, and call it solved. That fixes the correctness problem — but it introduces a set of costs that a single-process algorithm never had to pay, because a single process never had a network in the middle of its own arithmetic. Every check now costs a round trip. Redis is now a dependency every instance shares, which means it's also a single point of failure every instance shares. At high enough aggregate volume, one Redis node becomes the ceiling on throughput for every instance behind it, not just a convenience. And because requests now cross the network to reach the count, questions that were trivial in-process — "what time is it," "did my write actually happen," "is this the freshest copy of the count" — become real distributed-systems problems.

**The question:** *How do you make many independently-scaled application instances enforce one true, shared rate limit, without the shared state they now depend on becoming a new bottleneck, a new single point of failure, or a new source of unbounded latency on every request?*

> **→ Next:** Before the fix, what exactly goes wrong if you don't centralize the state — and how bad is it, concretely?

---

## 1. 🎯 Interview Quick Reference Card

> *Not a summary — a live-recall tool, built for retrieval speed under interview pressure. If you need the reasoning behind anything here, that's what §2 (cheatsheet) and the rest of the doc are for.*

**The checklist — walk this on the whiteboard, in order:**

1. Name why local, per-instance state fails first: N stateless instances each running their own token bucket or sliding window means the *effective* limit is N × the configured limit, because no instance knows what any other instance has admitted
2. Name the fix at the definitional level: move the counter state out of every instance and into one shared Redis — every instance now reads and writes the *same* key for the *same* client
3. Name the atomicity requirement, now across a network: the read-check-write from 25.1/25.4 must still be one atomic step, done via a Lua script (`EVAL`/`EVALSHA`) that Redis executes single-threaded — no interleaving is possible even with dozens of instances calling concurrently
4. Name the new failure mode unprompted: Redis is now a shared dependency — state the fail-open vs. fail-closed decision for when it's unreachable, and say which you'd pick and why
5. Name the scaling fix for aggregate throughput: shard rate-limit keys across a Redis Cluster (hash slot per key) — and name its limit unprompted: sharding spreads *different* keys across nodes, it does not speed up one hot key
6. Name the latency-reduction option for extreme QPS: local leasing / periodic sync — each instance holds a slice of the limit locally and reports back on an interval, trading exactness for fewer round trips
7. Name the response contract: still `429` + `Retry-After`, same `X-RateLimit-*` headers as every other subtopic in this topic (25.1/25.4/25.7)

**Trigger → action:**

| Interviewer says | You do |
|---|---|
| "You said each service instance runs the rate limiter — what happens with 10 instances behind a load balancer?" | Name the multiplication bug directly: local state means the effective limit is instances × configured limit, because no instance sees another's admissions |
| "How do you fix that?" | Centralize state in a shared Redis; every instance performs the same atomic Lua-script check-and-deduct against the same key |
| "What if Redis goes down?" | Name the trade explicitly: fail-open (protect availability, lose enforcement temporarily) vs. fail-closed (protect the limit, take an outage). State which you'd pick and why, tied to what the limit protects |
| "Won't Redis become a bottleneck at scale?" | Shard rate-limit keys across a Redis Cluster by hash slot — then immediately name the limit: a single very hot key still funnels through one node/slot regardless of sharding |
| "Do you really need a network round trip on every single request?" | No, not always — local leasing: each instance holds a small local slice of the limit and syncs periodically, trading strict exactness for far fewer round trips |

**Fast disambiguation — the pairs that get confused live:**

| Pair | The distinction |
|---|---|
| **Local (per-instance) rate limiting vs. distributed (Redis-backed) rate limiting** | Local is correct only when there is exactly one instance. The moment there's more than one, local state silently multiplies the effective limit — it isn't a smaller version of the correct answer, it's a different, wrong answer. |
| **Atomicity within one process (25.1/25.4) vs. atomicity across the network (this doc)** | 25.1/25.4's Lua script protects against races between concurrent requests *hitting the same process*. This doc's Lua script protects against races between concurrent requests hitting *different processes* that all reach the same Redis key. |
| **Sharding vs. hot-key mitigation** | Sharding (Redis Cluster, hash slots) spreads *different* keys across nodes to raise aggregate throughput. It does nothing for one key that's hot — that traffic still lands on one node no matter how many nodes exist (7.6). |
| **Fail-open vs. fail-closed** | Fail-open keeps the protected resource serving traffic when Redis is unreachable, at the cost of losing enforcement exactly when something (an outage-driven retry storm) may be stressing the system most. Fail-closed keeps the limit airtight, at the cost of coupling your service's availability to Redis's. |

**High-yield anchors:**

```
Multiplication bug: N stateless instances, each enforcing limit L locally
  ⇒ effective limit up to N × L, not L.
Atomicity mechanism: EVAL/EVALSHA — Redis is single-threaded for command
  execution, so a Lua script runs start-to-finish with no other client's
  command interleaved, on that one node.
Redis Cluster: 16,384 hash slots; multi-key Lua scripts must keep all
  keys in one slot via a hash tag, e.g. ratelimit:{client_id}:zset, or
  Redis raises CROSSSLOT and refuses the script.
Round-trip cost: roughly sub-millisecond to low single-digit ms same-AZ;
  tens to hundreds of ms cross-region — the concrete cost a synchronous
  per-request check pays that local state never did.
HTTP contract: unchanged — 429 Too Many Requests, Retry-After,
  X-RateLimit-Limit / -Remaining / -Reset (same as 25.1/25.4/25.7).
```

**The script — say this close to verbatim:**

> "The moment you have more than one instance of the service enforcing a rate limit, local, per-instance state stops being correct — with N instances, the effective limit becomes up to N times the configured one, because no instance knows what any other instance has already admitted. The fix is to centralize the state in a shared Redis that every instance reads and writes against the same key, and reuse the same atomic-check-and-deduct pattern from token bucket or sliding window, but as a Lua script — Redis executes it single-threaded, so no two instances' checks can interleave, even calling concurrently from a dozen different servers. The cost I'm accepting is a network round trip on every check, and a new shared dependency: if Redis is unreachable, I have to explicitly decide whether to fail open — keep serving traffic, temporarily lose enforcement — or fail closed — keep the limit airtight, but couple my service's availability to Redis's. If aggregate throughput outgrows one Redis node, I'd shard rate-limit keys across a Redis Cluster by hash slot, which scales throughput across many different keys but does nothing for one key that's genuinely hot. And if per-request round-trip latency itself becomes the bottleneck, I'd move to local leasing — each instance holds a small local slice of the limit and syncs back on an interval — which trades strict global exactness for far fewer network calls."

> **If pushed on "why not just let each instance keep its own smaller limit":** "That's dividing the limit by instance count instead of centralizing it, and it has its own failure mode: it only works if traffic is evenly distributed across instances, which a load balancer doesn't guarantee under real traffic patterns or during instance scale-up and scale-down. A client routed disproportionately to one instance would get throttled well below the intended limit, while the same client spread evenly across all instances would never trip it at all — the enforcement becomes a function of load-balancing behavior, not of the client's actual request rate. Centralizing in Redis removes that dependency entirely: the count is correct regardless of which instance, or how many instances, happen to receive the traffic."

---

## 2. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*
>
> ⏭️ **First time through this topic?** Skip to §3 and come back here for revision.

```
§ 1  WHY IT EXISTS
25.1 and 25.4 solved the algorithm and the single-process atomicity
problem. Neither addressed where the algorithm's state actually lives:
real traffic hits a fleet of stateless instances, not one process. If
each instance keeps its own local counter, the effective limit
multiplies by however many instances happen to be running, because no
instance can see what any other instance has admitted.

§ 2  WHAT IT IS
CENTRALIZED   Rate-limit state lives in one shared Redis, not in any
STATE         individual instance's memory. Every instance reads/writes
              the same key for the same client.
ATOMIC        The read-check-write from 25.1/25.4 runs as a Redis Lua
CROSS-NETWORK script (EVAL/EVALSHA), executed single-threaded server-
              side — no interleaving even across many concurrent
              instances.
SHARDING      Spreading different rate-limit keys across multiple Redis
              Cluster nodes (16,384 hash slots) to scale aggregate
              throughput.
LOCAL LEASING Each instance holds a small local slice of the global
              limit and syncs to Redis on an interval instead of every
              request — trades exactness for far fewer round trips.

§ 3  THE MECHANISM
CHECK    App instance computes the rate-limit key, calls Redis with
         EVALSHA running the algorithm's Lua script (token bucket or
         sliding window's prune-count-add), Redis executes it as one
         atomic, single-threaded step, returns ADMIT/REJECT.
SHARD    Redis Cluster hashes the key to one of 16,384 slots; multi-key
         scripts need a hash tag (ratelimit:{client_id}:...) to keep all
         keys for one client in the same slot, or Redis raises
         CROSSSLOT.
FAILURE  On Redis timeout/unreachable: FAIL-OPEN (admit, log it, keep
         serving) or FAIL-CLOSED (reject, protect the limit) — a
         deliberate policy choice, not a default.

§ 4  USE / AVOID
USE a synchronous shared-Redis check when: the limit must be exact
  across every instance with no tolerance for overshoot (compliance,
  billing, a hard backend-protection ceiling).
USE local leasing when: per-request Redis round-trip latency or load is
  the actual bottleneck, and a small, bounded overshoot is tolerable.
AVOID assuming sharding fixes a hot key: sharding spreads throughput
  across many different keys, not across one busy key, which still
  lands on a single node/slot regardless of cluster size (7.6).
AVOID reading from Redis replicas for the live admit/reject decision:
  asynchronous replication lag means a replica's count can be stale,
  which under-enforces the limit at the exact moment it's checked.

§ 5  FAIL-OPEN VS. FAIL-CLOSED
FAIL-OPEN    Admit requests when Redis is unreachable. Protects the
             protected resource's availability; loses enforcement
             exactly when an outage-driven retry storm may need it most.
FAIL-CLOSED  Reject requests when Redis is unreachable. Keeps the limit
             airtight; couples your service's availability to Redis's —
             a Redis blip becomes a full outage of your API.

§ 6  NUMBERS TO ANCHOR THE DISCUSSION
Multiplication bug: N instances × local limit L ⇒ effective limit up to
  N × L.
Redis Cluster: 16,384 hash slots; hash tags {client_id} keep multi-key
  scripts atomic within one slot.
Round-trip cost: ~sub-ms–low single-digit ms same-AZ; tens–hundreds of
  ms cross-region — the price a synchronous check pays per request.
HTTP: 429 Too Many Requests · Retry-After · X-RateLimit-Limit /
  -Remaining / -Reset (same contract as 25.1/25.4/25.7).

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "Multiple instances — does the limit still hold?" → name the
                                          multiplication bug, then Redis
→ "What if Redis is down?"             → fail-open vs. fail-closed,
                                          state which and why
→ "Won't Redis be a bottleneck?"       → shard by hash slot; hot key
                                          still isn't fixed by sharding
GOTCHA: Treating Redis Cluster sharding as a fix for a single hot
  client's traffic. Sharding raises aggregate throughput across many
  different keys — one very busy key still funnels through exactly one
  node/slot no matter how large the cluster is (§6/§7).
```

---

## 3. 🧠 The Mindmap

> *The picture to hold in your head while you study. Everything below hangs off this.*

```
                      ┌───────────────────────────┐
                      │  DISTRIBUTED RATE LIMITING  │
                      └─────────────┬───────────────┘
                                    │
    ┌───────────────┬───────────────┼───────────────┬───────────────┐
    ▼                ▼               ▼               ▼               ▼
① THE PROBLEM   ② THE FIX        ③ SCALING IT    ④ WHEN REDIS    ⑤ WHERE IT
  (local state     (centralize +    (sharding /      FAILS           LIVES
   multiplies)      atomic Lua)      hot keys)      (the policy      (production
                                                       choice)          + connections)
├ N instances,   ├ shared Redis,   ├ Cluster:      ├ fail-open:     ├ Envoy/Lyft
│ each with       │ same key for    │ 16,384 hash    │ availability    ratelimit
│ local state      │ same client     │ slots           │ over exact      service
├ effective       ├ EVALSHA runs    ├ hash tag        ├ fail-closed:   ├ Stripe's
│ limit = N×L,     │ atomically,     │ {client_id}     │ exactness       GCRA + Redis
│ not L             │ single-         │ for multi-key   │ over avail.    ├ Kong: local
├ load-balancer     │ threaded,       │ scripts         ├ HA (Sentinel/  vs cluster vs
│ skew makes it       │ no interleave  ├ hot key still   │ Cluster) still  redis+sync_rate
│ worse, not          │ across          │ 1 node no       │ has a brief    ├ feeds: 25.6
│ predictable          │ instances       │ matter how      │ failover gap   layered
│                       │                 │ many nodes      │                limiting
```

**How to read it:** ① is the failure that motivates everything else — say it first, in one sentence, with the multiplication framing, because every other branch is a response to it. ② is the direct fix and the one every interviewer expects immediately. ③ and ④ are the two costs the fix itself introduces — they are parallel, not sequential: ③ is "what happens as load grows," ④ is "what happens when the dependency breaks." Neither is optional to mention; naming ② without ③ and ④ reads as not having thought past the happy path. ⑤ closes it by grounding the abstraction in real systems and where this feeds forward (25.6) — the same closing move 25.1's and 25.4's mindmaps both made, and the graders notice when it's missing.

> **→ Next:** Made concrete — what exactly breaks with local state, and by how much?

---

## 4. 🔥 The Problem

25.1 and 25.4 both quietly assumed a rate limiter runs as one logical process with one in-memory (or single-Redis-key) source of truth. That assumption is invisible until you deploy the service the way almost every real API is deployed: as a fleet of identical, stateless instances behind a load balancer (Topic 3, Topic 4), scaled horizontally to handle load and to survive individual instance failures. Nothing about token bucket or sliding window log/counter changes when you do this — you can absolutely run either algorithm, correctly, inside each instance. The problem isn't the algorithm. It's that "correctly, inside each instance" is now the wrong scope for correctness.

If every instance keeps its own local token bucket or its own local sliding-window log, each instance is enforcing the configured limit against *its own view* of that client's traffic — and no instance has any way of knowing what any other instance has already admitted. A client sending requests that get spread across 10 instances by the load balancer isn't being rate-limited at the configured limit at all; it's effectively being rate-limited at up to 10 times that limit, because each of the 10 instances independently believes it hasn't seen this client yet reach the cap. The bug isn't rare or subtle — it's the default outcome of running any correct single-process algorithm in a horizontally scaled fleet without changing where its state lives.

Making it worse: the multiplication factor isn't even a stable, predictable N. Real load balancers don't guarantee perfectly even distribution, especially under connection reuse, sticky sessions (3.6/4.6), or during a rolling deployment when instance counts are actively changing. A client might land disproportionately on 2 of 10 instances and get throttled well under the intended limit, or spread evenly across all 10 and blow past it by nearly 10x — the actual enforced limit becomes a function of load-balancing behavior on any given day, not a property of the system's design. The fix that resolves this is the same move every earlier subtopic in this topic made when it needed a shared source of truth: stop keeping the state locally, and centralize it somewhere every instance can reach and agree on — which is exactly what 25.1 and 25.4 already used Redis for, just not yet across more than one caller.

**Before and after:**

```
  BEFORE — local state, per instance          AFTER — centralized state (this doc)
  ────────────────────────────────────        ──────────────────────────────────
   each instance runs its own token             one shared Redis holds the ONE
   bucket / sliding window, in memory            count every instance reads AND
                                                  writes against

   ✗ 10 instances, limit=100 each ⇒             ✓ 10 instances, ONE shared count,
     effective limit up to 1,000, not              limit enforced at exactly 100
     100                                            regardless of instance count
   ✗ actual enforced limit depends on            ✓ correctness no longer depends
     load-balancer distribution — not               on how the load balancer
     a stable, designed property                     happens to spread traffic
```

**The multiplication bug, made concrete — one client, 10 instances, limit = 100/min:**

```
   Client "X" sends 1,000 requests/min, spread evenly across 10 instances
   by the load balancer — 100 requests/min arrive at each instance.

   Instance 1  [local bucket, cap=100] → sees 100 req/min → "at the limit" ✓
   Instance 2  [local bucket, cap=100] → sees 100 req/min → "at the limit" ✓
   ...
   Instance 10 [local bucket, cap=100] → sees 100 req/min → "at the limit" ✓

   Every single instance independently reports "correctly enforcing the
   100/min limit." Client X's REAL total: 1,000 requests/min admitted —
   10x over the configured limit — and nothing in the system ever
   observes the violation, because no instance's local view includes
   the other nine.
```

### ✅ Checkpoint

1. A teammate argues this isn't really a bug: "each instance is still correctly enforcing 100/min, so the system as a whole is fine." Using the concrete 10-instance example, explain precisely what's wrong with defining "correct" at the instance level here, and why the load-balancer's traffic distribution — not the algorithm — ends up determining the real enforced limit.

   > 💡 *If you hesitate, re-read the "multiplication bug, made concrete" example and the paragraph before it about the enforced limit depending on load-balancing behavior.*

Defining "correct" at the instance level is a scoping error: each instance
only has visibility into requests it personally received, so "I'm at
100/100" is a true statement about that instance's local view, but it says
nothing about the client's actual total request rate across all 10
instances. With no instance aware of what the other nine have admitted,
the system has no representation of the client's true aggregate rate
anywhere — the "limit" only exists per-instance, not globally.

This is why the load balancer, not the algorithm, ends up determining the
real enforced limit. The algorithm is correct in isolation — each bucket
correctly enforces its own 100/min. But how much total throughput a
client gets past all 10 buckets combined depends entirely on how the load
balancer happens to spread that client's requests: perfectly even
routing produces the largest violation (up to 1,000/min admitted), while
skewed routing onto fewer instances produces a smaller — but still
uncontrolled — violation. Nothing about the rate-limiting algorithm
changed in either case; only the routing pattern did. That's the tell
that "correct" was defined at the wrong scope.

> **→ Next:** If the fix is centralizing state in Redis, what exactly does that design look like, and what does it cost that local state never had to pay?

---

## 5. 💡 The Core Idea

**A distributed rate limiter takes the exact algorithm and atomicity guarantees already established for a single process (25.1, 25.4) and relocates the state into one shared Redis that every horizontally-scaled instance reads and writes against the same key, using a Lua script for network-wide atomicity — and then, only once that's correct, decides how to spend three further, genuinely independent design budgets: what happens when Redis is unreachable, how to keep one Redis from becoming a throughput ceiling, and whether every single check truly needs a network round trip at all.**

**Visual required:** build-chain diagram.

```
 [CENTRALIZE      ──▶ [ATOMICITY        ──▶ [SHARDING FOR   ──▶ [THE FAILURE   ──▶ [CUTTING ROUND
  STATE IN REDIS]        ACROSS THE           AGGREGATE          POLICY]              TRIPS AT
   because                NETWORK]            THROUGHPUT]         because              EXTREME SCALE]
   local, per-             because              because             a shared             because even a
   instance state           many instances       one Redis           dependency            correct,
   silently                  now race over         node has a         needs an               atomic,
   multiplies the             the SAME key,          real ceiling       explicit               sharded
   effective limit             not just one            on request        policy for              design still
   (§4)                         process's               volume at         when it's                pays a network
                                  own requests            extreme            unreachable,             RTT on every
                                                            QPS                 not a                    single check
                                                                                 silent
                                                                                 default
```

### Centralize State in Redis

Everything starts from the same move §4 already pointed at: the state that decides admit-or-reject cannot live inside any individual instance, because individual instances don't share memory and can't see each other's traffic. It has to live somewhere every instance can reach over the network and agree on as the single source of truth. Redis is the natural fit — it's already the store 25.1 and 25.4 used for the algorithm's own bookkeeping (the bucket's token count, the sliding window's sorted set), so moving from "one process talking to Redis" to "many processes talking to the same Redis key" doesn't change what's stored, only who's allowed to read and write it. Every instance, for a given client, computes the identical rate-limit key and directs its check at that one key — there is exactly one bucket, or one sorted set, per client, no matter how many application instances exist.

### Atomicity Across the Network

25.1 and 25.4 already established that the check-and-deduct has to be one atomic step, because two concurrent requests both reading the state before either writes it can both be admitted past the limit. That requirement doesn't go away when the callers are on different machines — it gets harder to satisfy, because now the race isn't between two threads in one process, it's between however many application instances happen to call Redis in the same few milliseconds. The mechanism that resolves it is the same one 25.1 and 25.4 already used in production: the entire check runs as a single Lua script, submitted via `EVAL` or a cached `EVALSHA`. Redis executes commands single-threaded — while one script is running, no other client's command, from any instance, can execute on that Redis node. The script's read, its comparison against the limit, and its write all happen as one indivisible unit from every other caller's point of view, which is exactly what closes the race regardless of how many instances are calling concurrently.

### Sharding for Aggregate Throughput

Centralizing state fixed correctness, but it created a new, real constraint that per-instance state never had: every check for every client, from every instance, now funnels through the same Redis. At low-to-moderate aggregate request volume this is nothing — a single Redis node handles enormous throughput. At extreme aggregate scale, one node's request-handling capacity becomes a genuine ceiling, shared by every instance and every client behind it. Redis Cluster resolves this the standard way any partitioned store does (Topic 7): keys are distributed across multiple primary nodes by a hash of the key, 16,384 possible hash slots split across however many nodes are in the cluster. Different clients' rate-limit keys land on different nodes, so aggregate throughput scales with the number of nodes. The one thing sharding does not fix — worth stating unprompted — is a single client whose traffic is disproportionately large: that client's key still hashes to exactly one slot on exactly one node, so a genuinely hot key concentrates load the same way it would on an unsharded single instance (the same structural limit as 7.6's hot partitions).

### The Failure Policy

Once state lives in Redis, Redis is a dependency every instance shares — and unlike an in-process bucket, it can become unreachable independently of the application code that relies on it. This is a decision that has to be made explicitly, because there is no default that's safe for every system: **fail-open** means admitting requests when Redis can't be reached, keeping the protected resource available at the cost of losing enforcement for as long as the outage lasts; **fail-closed** means rejecting requests, keeping the limit airtight at the cost of taking the entire protected API down for every client, coupling its availability directly to Redis's. Neither choice is universally correct — it depends entirely on what the limit exists to protect, which is exactly the judgment call §7 formalizes.

### Cutting Round Trips at Extreme Scale

Even a fully correct, atomic, sharded design pays one unavoidable cost that local state never had: a network round trip on every single check, because the state being checked no longer lives in the same process making the request. At most scales this cost is trivial — a same-AZ Redis round trip is typically sub-millisecond to a few milliseconds. At the extreme end — very high per-request-latency budgets, or Redis genuinely saturated by check volume rather than by any one hot key — the fix isn't to abandon centralization, it's to check less often. Local leasing has each instance hold a small local slice of the global limit (for example, a fair share it can admit against without asking Redis at all) and periodically reports usage back to and refreshes its slice from Redis, on an interval rather than per-request. This is a direct continuation of 25.4's own precision-vs-cost axis: exactly as the sliding window counter traded per-timestamp exactness for O(1) memory, local leasing trades strict global exactness — the possibility of brief, bounded overshoot — for a large reduction in network round trips.

### ✅ Checkpoint

1. Using only the "Centralize State in Redis" and "Atomicity Across the Network" concepts, explain precisely why simply pointing every instance at the same Redis key, without also making the check-and-deduct a single atomic script, does not actually fix §4's multiplication bug — only shrinks it.

   > 💡 *If you hesitate, re-read "Atomicity Across the Network" — the sentence about the race being between however many instances happen to call Redis in the same few milliseconds.*

Pointing every instance at the same Redis key removes the "each instance
has its own independent 100-request budget" problem — there's now only
one true count, and every instance is reading and writing against it.
But if the check ("is there room?") and the write ("deduct one") are two
separate round trips instead of one atomic step, a race window opens:
two (or more) instances can both read the count before either one writes
its deduction, both see "under the limit," and both proceed to admit —
one unit of remaining capacity ends up admitting more than one request.

This is why it only shrinks the bug rather than fixing it. §4's
multiplication was bounded by N — 10 instances, each holding a full,
independent 100-request local budget, for up to 1,000 admitted. The
non-atomic shared-Redis version has no such per-instance budget anymore;
the only thing that can over-admit is however many requests happen to
race inside the brief network-round-trip window between one instance's
read and its write. That window is milliseconds wide, so the possible
over-admission is bounded by concurrent request volume during that
narrow gap — a handful of extra admissions, not a full second copy of
the limit per instance. Making the check-and-deduct one atomic Lua
script closes that window entirely, because Redis executes it as a
single indivisible step no other client's command can interleave with.

2. Trace the link from "Sharding for Aggregate Throughput" into "The Failure Policy": both respond to Redis becoming a shared, load-bearing dependency, but they respond to different failure shapes. Name precisely which failure shape each concept addresses, and explain why solving one does nothing for the other.

   > 💡 *If you hesitate, re-read the closing sentences of both concept blocks — one names a throughput ceiling, the other names unreachability.*

Sharding for Aggregate Throughput and The Failure Policy respond to two
genuinely different failure shapes, and fixing one does nothing for the
other because they sit on independent axes.

Sharding addresses a THROUGHPUT CEILING: as aggregate check volume from
every instance and every client grows, one Redis node's capacity to
handle requests per second becomes the bottleneck. Spreading rate-limit
keys across a Redis Cluster's hash slots spreads that request load
across multiple nodes, raising the ceiling on total volume the system
can check per second. This says nothing about availability — a sharded
cluster is just as capable of becoming unreachable as a single node is
(a network partition, a node crash, a shard's primary failing before a
replica is promoted). More shards means more capacity while Redis is
healthy; it does not mean Redis is less likely to become unreachable.

The Failure Policy addresses UNREACHABILITY: what every instance should
do the moment it cannot reach Redis at all, regardless of how many nodes
exist or how much spare capacity they had. Fail-open and fail-closed are
both answers to "Redis is gone right now" — they add no request-handling
capacity, because they only ever activate once the throughput question
is already moot (there's no check happening at all).

So a system can be perfectly sharded and still go fully unreachable
(sharding solved a capacity problem it never had an availability
problem to begin with), and a system can have a perfect fail-open/
fail-closed policy and still buckle under load the moment Redis is
healthy but overwhelmed (the policy only fires on unreachability, not
on being slow-but-up). Neither concept substitutes for the other.

> **→ Next:** You know the shape of the design. What actually happens, step by step, on a real request — and what specifically breaks when it's distributed rather than local?

---

## 6. ⚙️ How It Actually Works

**Happy path — a Redis-backed check, one request end to end (any app/gateway instance):**

1. A request arrives at whichever instance the load balancer routed it to — the instance's identity is irrelevant to the outcome, by design (this is the entire point of centralizing state).
2. The instance computes the rate-limit key for this client, identically to how any other instance would compute it for the same client (same convention as 25.1/25.4: API key, user ID, or IP).
3. The instance calls Redis with `EVALSHA`, running the pre-loaded Lua script that implements the chosen algorithm's atomic check-and-deduct — token bucket's refill-and-decrement, or sliding window's prune-count-add (25.4) — against that one key.
4. Redis executes the entire script as one atomic, single-threaded step on the node owning that key's hash slot. No other client's command — from this instance or any other — can interleave with it.
5. Redis returns the admit/reject decision plus whatever metadata the script computes (tokens/count remaining, or the timestamp needed to derive `Retry-After`).
6. The instance either forwards the request or responds `429` with `Retry-After` and the `X-RateLimit-*` headers — identical response contract regardless of which instance handled the check.

> 🗺️ **Mental model — Redis executing the Lua script is a bank teller who locks the door for one customer at a time.** While the teller is processing a withdrawal — checking the balance, deciding whether it covers the request, updating the ledger — no other customer can even approach the counter, regardless of how many customers (instances) are waiting in line. Every withdrawal is processed against the one true ledger, in full, before the next one starts.
> *Where it breaks down:* the locked-door guarantee only covers one teller — one Redis node, one hash slot. It says nothing about what happens if the branch itself is unreachable (the failure-policy question below), or about two different branches (a sharded cluster) with two different ledgers for two different clients, or about a teller who was just promoted from a backup ledger that hadn't seen the last few transactions (replica failover, below).

**Failure & edge cases:**

- **Redis unreachable is now a first-class failure mode, not an edge case.** Every instance's check depends on reaching Redis; a network partition, a Redis restart, or a saturated Redis node all produce the identical symptom from the application's point of view — the check simply doesn't return in time. Without an explicit fail-open/fail-closed policy (§5, §7), this default is undefined behavior, not a safe one.
- **Reading from a Redis replica for the live decision is unsafe.** Redis replication is asynchronous by default — a replica's copy of the count can lag the primary by some non-zero interval. Using a replica to read the count while writes go to the primary means the read can be stale, which under-enforces the limit at exactly the moment it's checked. The admit/reject decision has to read and write the same node — the primary.
- **A primary failover can briefly lose very recent writes.** If a Redis primary fails and a replica is promoted (via Sentinel or Cluster), any writes that hadn't yet replicated at the moment of failure are gone — the promoted replica's count can understate reality for a short window right after failover, which is an over-admission risk with the same shape as 25.4's counter estimate error, except caused by infrastructure rather than by algorithm design.
- **Clock consistency is solved differently here than in 25.1/25.4.** A single process trusted its own clock. Across many instances, trusting each instance's own wall clock risks clock skew between machines. The fix: have the Lua script call Redis's own `TIME` command internally rather than accept a timestamp from the calling instance — every instance's check then uses the *same* clock (Redis's), regardless of any skew between the instances themselves.
- **Multi-key scripts need a hash tag under Redis Cluster.** If an algorithm's Lua script touches more than one key for the same client (for example, a counter key and a separate metadata key), Redis Cluster requires every key the script touches to live in the same hash slot, or it refuses the script with a `CROSSSLOT` error. The fix is a hash tag — wrapping the client identifier in braces, e.g. `ratelimit:{client_id}:count`, `ratelimit:{client_id}:meta` — which forces Redis to hash only the tagged portion, co-locating both keys on the same node.

**Mechanism flow, end to end:**

```
① REQUEST ARRIVES        ② COMPUTE KEY            ③ EVALSHA (atomic,        ④ RESPOND
  at ANY instance —        same convention as        Redis-side single-       admit → forward
  instance identity  ──▶   every other instance ──▶  threaded, on the   ──▶   reject → 429 +
  is irrelevant             for this client            key's owning            Retry-After
                                                         hash slot                (identical from
                                                                                    any instance)
```

**Structural diagram — keyspace sharding across a Redis Cluster:**

```
   N STATELESS APP / GATEWAY INSTANCES  (Topic 3 / Topic 4 — any one can
   ┌────┐ ┌────┐ ┌────┐     ┌────┐      handle any client's request)
   │ I1 │ │ I2 │ │ I3 │ ... │ IN │
   └──┬─┘ └──┬─┘ └──┬─┘     └──┬─┘
      └───────┴───────┴─────────┘
                   │  every instance computes the SAME key for the
                   │  SAME client, then hashes it
                   ▼
   ┌─────────────────────── REDIS CLUSTER — 16,384 HASH SLOTS ───────────────────────┐
   │  slots 0–5460        slots 5461–10922         slots 10923–16383                 │
   │  ┌───────────┐        ┌───────────┐            ┌───────────┐                    │
   │  │  NODE A   │        │  NODE B   │            │  NODE C   │                    │
   │  │ client X  │        │ client Y  │            │ client Z  │                    │
   │  │ (hot key — │        │           │            │           │                    │
   │  │  1 node,   │        │           │            │           │                    │
   │  │  no matter  │        │           │            │           │                    │
   │  │  cluster    │        │           │            │           │                    │
   │  │  size)       │        │           │            │           │                    │
   │  └───────────┘        └───────────┘            └───────────┘                    │
   └───────────────────────────────────────────────────────────────────────────────────┘
   Sharding raises AGGREGATE throughput (different clients spread across
   nodes A/B/C) — it does NOT raise client X's ceiling if X alone is hot.
```

### ✅ Checkpoint

1. A team implements the distributed check as a plain `GET` (read the count), an application-side `if count < limit` comparison, then a separate `SET` (write the incremented count) — three separate round trips to Redis, no Lua script. Using the atomicity mechanism from §5 and the happy path above, walk through exactly what two concurrent instances can do to over-admit a client that's one request under the limit, and name precisely which change closes it.

   > 💡 *If you hesitate, re-read "Atomicity Across the Network" in §5 and step 3–4 of the happy path — the single-threaded, one-script guarantee.*

Two instances race like this: Instance A sends GET on the client's key
and gets back count = limit - 1 (one under the limit). Before A's SET
lands, Instance B — handling a different request from the same client
at nearly the same moment — also sends GET and also gets count =
limit - 1, because A's write hasn't happened yet. Both instances now
independently evaluate "count < limit" as true, and both proceed:
A performs its SET, incrementing the count and admitting its request;
B performs its SET, also incrementing the count and admitting its
request. Two requests get admitted against what was only one unit of
remaining headroom — the client is over-admitted by exactly the width
of that GET-to-SET gap, for however many instances raced into it.

The fix is to make the read (GET-equivalent), the comparison, and the
write (SET-equivalent) one atomic step — a Redis Lua script run via
EVAL/EVALSHA. Because Redis executes scripts single-threaded, only one
instance's script can run at a time on that key: whichever script runs
first reads the true current count, decides admit, and writes the
increment, all before the second instance's script is allowed to even
begin. The second instance's script then reads the already-updated
count, correctly sees the limit is reached, and returns reject. The
three separate round trips (GET / compare / SET) collapse into one
indivisible operation, closing the window entirely rather than just
narrowing it.

2. Using the primary-failover edge case above, explain why a Redis Cluster or Sentinel setup providing high availability for the *infrastructure* does not, by itself, guarantee the rate limit was never briefly over-admitted during a failover — and name what kind of error this produces (over-admission or under-admission), and why.

   > 💡 *If you hesitate, re-read "A primary failover can briefly lose very recent writes."*

Redis Cluster and Sentinel give you HA at the infrastructure layer — if
the primary dies, a replica gets promoted automatically, so the rate
limiter doesn't stay fully down. But that promotion doesn't guarantee
the promoted replica's data is identical to what the primary had at the
instant it failed, because Redis replication is asynchronous: the
primary acknowledges writes to clients before confirming the replica
has received them. Any writes that hadn't yet propagated to the replica
at the moment of failure are simply gone — the promoted node starts
serving traffic from a count that's stale by whatever that replication
lag was.

Because the promoted replica treats its own (lower, stale) count as
ground truth and keeps applying the same check-and-deduct logic against
it, it will keep admitting requests for a window after the real,
pre-failure count had already reached the configured limit — the system
believes there's still headroom that, in reality, was already consumed
before the failover. This is an over-admission error, not
under-admission: the gap in the data makes the system think a client
has sent fewer requests than it actually has, so it lets more through
than the limit intends. The failure mode has the same shape as 25.4's
sliding window counter systematically under-counting a burst, except
here the imprecision is injected by infrastructure failover timing
rather than by the algorithm's own design.

> **→ Next:** You can run this correctly end to end. In a real design, which choices do you actually make — fail-open or closed, sharded or not, synchronous or leased — and what does each one cost?

---

## 7. ⚖️ The Decision — When, and What It Costs

The baseline design — one shared Redis, atomic Lua-script checks, every instance pointed at the same key — is not optional; it's the correctness fix from §4/§5. The real decisions start once that baseline is in place: what happens when Redis is unreachable, whether one Redis node is enough, and whether every request truly needs a synchronous round trip.

**The limit needs to be exact, with zero tolerance for overshoot — compliance, billing, or a hard backend-protection ceiling.** This is the case for a synchronous, per-request check against Redis with **fail-closed** on unreachability: rejecting every request during a Redis outage is the only way to guarantee the limit was never silently exceeded, and it's the correct trade when the limit itself is the thing that must never be violated, even briefly.

**A brief, bounded overshoot during rare failure conditions is acceptable, and the protected resource's own availability is the higher priority.** This is the case for **fail-open**: keep serving traffic when Redis is unreachable, accept that enforcement is temporarily gone, and treat it as a known, monitored, bounded-risk window rather than a silent one — this is the more common production choice when rate limiting exists to protect against abuse or cost, not to satisfy a hard contractual ceiling.

**Aggregate check volume, not any single client, is approaching what one Redis node can handle.** This is when Redis Cluster sharding earns its complexity: spreading different clients' keys across multiple nodes by hash slot raises the ceiling on total throughput. It is not the fix for one client being disproportionately hot — that traffic concentrates on one node/slot regardless of cluster size, and needs the hot-key mitigations from 5.7/7.6 instead, not more shards.

**Per-request round-trip latency or Redis load itself is the bottleneck, and a small amount of overshoot is tolerable.** This is when local leasing earns its complexity: each instance holds a small local slice of the limit and syncs on an interval, cutting round trips dramatically at the direct cost of strict global exactness — the same precision-for-cost trade 25.4's sliding window counter already made, now applied to network calls instead of memory.

**Decision tree:**

```
        Does the limit need to be EXACT for every single request, with
        zero tolerance for brief overshoot (compliance, billing, a hard
        backend-protection ceiling)?
                              │
              ┌──────yes──────┴──────no, brief overshoot is tolerable──────┐
              ▼                                                              ▼
   Synchronous per-request check against a single,           Is per-request Redis round-trip
   region-pinned Redis (Cluster if aggregate                 latency or Redis load actually
   throughput needs sharding). FAIL-CLOSED on                the bottleneck at your scale?
   Redis outage — the limit's exactness matters                          │
   more than the protected resource's availability            ┌──yes────────┴────────no──────┐
   during that outage.                                        ▼                                ▼
                                                  Local leasing / periodic          Synchronous Redis check
                                                  sync — each instance holds        stays simplest and
                                                  a slice of the limit, reports     cheapest to reason
                                                  back on an interval.              about. FAIL-OPEN, since
                                                  FAIL-OPEN on outage — a           exact enforcement was
                                                  brief enforcement gap beats       never the requirement.
                                                  an availability outage.
```

**Cross-region latency, when app instances span multiple regions but the limit must be one shared count:**

```
   ONE GLOBAL REDIS (region-pinned)              PER-REGION REDIS (split quota)
   ────────────────────────────────              ──────────────────────────────
   Every region's instances pay a                 Every region's instances check a
   cross-region round trip for EVERY               region-LOCAL Redis — fast, but
   check, except the region Redis                  each region only enforces its
   itself lives in (tens–hundreds                  OWN slice of the global limit
   of ms added per non-local check)                (e.g. global/N regions)

   ✓ exact global count, always                    ✓ low latency everywhere
   ✗ heavy latency tax on every                     ✗ imbalanced traffic can starve
     non-local-region request                         one region's slice while another
                                                        region's sits unused — an
                                                        estimate, not an exact count
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Centralizing state in Redis gives one true, exact count** across every instance regardless of how many exist or how load is balanced across them | Every check now costs a network round trip, and every instance now shares one dependency that can fail independently of the application code itself |
| **Redis Cluster sharding scales aggregate throughput** across many different clients' keys, well past what a single node can handle | A single hot key still funnels through exactly one node/slot — sharding doesn't raise that client's ceiling, and multi-key scripts need hash tags to stay atomic, adding operational care |
| **Fail-open keeps the protected resource available** through a Redis outage, avoiding a Redis blip becoming a full API outage | Rate limiting silently disappears for the duration of the outage — precisely when an outage-driven retry storm might need it most |
| **Local leasing cuts per-request Redis round trips dramatically**, removing network latency from the hot path for most requests | Turns a hard global limit into a soft one — each instance can admit up to its local lease before the next sync, so brief, bounded overshoot beyond the configured limit becomes possible by design |

### In production

| System | How it applies | The nuance |
|--------|----------------|------------|
| **Envoy's rate limit service** (originally Lyft's `ratelimit`, widely reused) | A standalone gRPC service that many Envoy proxy instances call per request, itself backed by Redis for the actual counter storage — the exact shape this doc describes: many stateless proxies, one shared Redis-backed source of truth | Adds one more network hop than talking to Redis directly (proxy → ratelimit service → Redis), trading a bit more latency for centralizing the algorithm/Lua logic in one service instead of duplicating it in every proxy |
| **Stripe's publicly documented API rate limiting** | Centralizes counters (using a token-bucket-family algorithm) in Redis specifically to give a consistent limit across Stripe's many stateless API servers | Documented as choosing fail-open on Redis unavailability — prioritizing API availability over strict enforcement for that specific failure mode, consistent with this doc's §7 trade-off |
| **Kong Gateway's rate-limiting-advanced plugin** | Offers a `cluster` policy (every node checks shared Redis/DB synchronously, exact) versus a `local` policy (in-worker memory only, no shared truth) versus a `redis` policy with a configurable `sync_rate` that batches local counts and syncs them to Redis on an interval instead of every request | The `sync_rate` option is a direct, shipped implementation of this doc's local-leasing trade-off — configurable per deployment based on how much exactness a given API actually needs |

### ✅ Checkpoint

1. A ride-hailing company's surge-pricing service needs to cap fare-calculation requests at 500/second globally, across app instances deployed in 3 regions, and product wants the cap to be as close to exact as reasonably possible without adding hundreds of milliseconds of latency to every request. Using the decision tree and the cross-region latency diagram, propose a design, and explain specifically what you'd give up compared to a single global Redis, and why that trade is the right one for the stated latency requirement.

   > 💡 *If you hesitate, re-read the "cross-region latency" diagram and the third boundary condition (aggregate throughput / per-region split).*
With a separate region 
> **→ Next:** Can you deliver this cleanly under interview pressure, including when the interviewer pushes on the Redis-outage question specifically?

Design: split the global 500/sec into a fixed slice per region — roughly
500/3 ≈ 166–167/sec each — enforced by a region-local Redis, with no
cross-region round trip on any check. This avoids the hundreds-of-
milliseconds latency tax a single global Redis would impose on the two
non-local regions for every single request, which directly satisfies
product's latency constraint.

What I give up compared to a single global Redis: global exactness.
With a fixed per-region slice, each region's Redis has no visibility
into the other regions' traffic, so the split is static rather than
responsive to real demand. If traffic isn't evenly spread — say region 1
gets disproportionately more fare-calculation load than regions 2 and 3
— region 1 will start rejecting requests once it hits its 166/sec slice,
even though the true global total across all three regions could still
be well under 500/sec, because regions 2 and 3's unused headroom can't
be borrowed. The system behaves conservatively-correct (never exceeds
500/sec globally) but not exactly-correct (it can under-utilize the
configured limit and reject legitimate traffic it didn't need to).

That's the right trade for this requirement specifically because product
explicitly prioritized latency over exactness ("as close to exact as
reasonably possible, without adding hundreds of ms") — a single global
Redis would guarantee exactness but violate the latency constraint on
every non-local-region request, which is the one hard constraint stated.

---

## 8. 🎯 In the Interview

**When an interviewer asks / says:**
- "You mentioned this service runs on multiple instances — does the rate limit still hold?"
- "What happens to your rate limiter if Redis goes down?"
- "Won't a single Redis instance become a bottleneck at scale?"
- "Do you really need to hit Redis on every single request?"

**Where this surfaces — template:**

| Trigger point | What prompts the return to it |
|---|---|
| **First appearance** | Right after you've named the algorithm (token bucket / sliding window) and described it correctly for a single process — the interviewer asks about multiple instances, or the deep dive naturally reaches horizontal scaling (Topic 3/4 territory) |
| **Second appearance** | The moment you say "Redis" — expect an immediate "what if it's down" pushback; price it before being asked |
| **Third appearance** | If the design discussion reaches extreme scale or multi-region, expect a bottleneck/latency pushback on the synchronous per-request check itself |

**What you say / do — delivered in this fixed order:**

| Step | Content |
|---|---|
| **1. Name the choice** | "Centralize the rate-limit state in a shared Redis — every instance checks and deducts against the same key for the same client, via a Lua script." |
| **2. Give the mechanism reason** | "Redis executes the script single-threaded, so the check-and-deduct is atomic across every instance calling concurrently, not just within one process." |
| **3. Price it unprompted** | "That costs a network round trip per check, and makes Redis a shared dependency — I need an explicit policy for when it's unreachable." |
| **4. Name the switch condition** | "Fail-open vs. fail-closed depends on what the limit protects. If aggregate volume outgrows one node, I'd shard by hash slot — sharding doesn't fix one hot key, though. If round-trip latency itself is the bottleneck, I'd move to local leasing." |

**The trade-off statement (memorize this pattern):**

> "The moment you have more than one instance enforcing a rate limit, local state stops being correct — with N instances, the effective limit becomes up to N times the configured one, because no instance knows what any other has already admitted. The fix is to centralize the state in a shared Redis every instance reads and writes against the same key, and run the check-and-deduct as a Lua script — Redis is single-threaded, so it executes atomically across every instance calling concurrently, not just within one process. The cost is a network round trip on every check, plus a new shared dependency: if Redis is unreachable, I have to explicitly choose fail-open — keep serving, temporarily lose enforcement — or fail-closed — keep the limit airtight, couple my service's availability to Redis's. If aggregate throughput outgrows one node, I'd shard rate-limit keys across a Redis Cluster by hash slot, which raises throughput across many different keys but does nothing for one genuinely hot key. And if per-request latency itself is the bottleneck, I'd move to local leasing — each instance holds a small slice of the limit locally and syncs back on an interval — trading strict exactness for far fewer round trips."

**A second trade-off variant — the "what if Redis goes down" pushback:**

> "That's the real cost of centralizing state, and it's worth naming before it's asked: Redis is now a dependency every instance shares, so I need an explicit policy, not a default. Fail-open means admitting requests when Redis is unreachable — the protected resource stays available, but rate limiting is effectively off for the duration, which matters most if that outage is also driving a retry storm. Fail-closed means rejecting every request when Redis is unreachable — the limit is never silently exceeded, but a Redis blip becomes a full outage of my own API, because my service's availability is now coupled to Redis's. Which one I'd pick depends entirely on what the limit is protecting: if it's a hard, contractual, or billing-grade ceiling, I'd fail closed and invest in Redis high availability — Sentinel or Cluster with fast failover — to make that outage window as small as possible. If it's protecting against abuse or cost on a resource that still has other defenses, I'd fail open and treat the gap as a monitored, bounded risk rather than something to prevent outright."

### ⚠️ Traps

- ❌ **Trap:** "Each instance just needs a smaller local limit — divide the configured limit by the number of instances."
  ✅ **Reality:** That only works if traffic is perfectly evenly distributed across instances, which load balancers don't guarantee — under skewed routing, a client can be throttled well under the intended limit on some instances while never tripping it on others. The enforced limit becomes a function of load-balancing behavior, not a designed property of the system (§4).

- ❌ **Trap:** "I'll point every instance at the same Redis key — that's the fix, done."
  ✅ **Reality:** Pointing at the same key without an atomic Lua script only shrinks the race window, it doesn't close it — separate GET/compare/SET calls from different instances can still interleave and over-admit. The check-and-deduct has to be one atomic script (§5/§6).

- ❌ **Trap:** "I'll read from a Redis replica to reduce load on the primary."
  ✅ **Reality:** Redis replication is asynchronous — a replica's count can lag the primary, which under-enforces the limit at exactly the moment it's checked. The live admit/reject decision has to read and write the primary, not a replica (§6).

- ❌ **Trap:** "Sharding the keyspace across a Redis Cluster solves the bottleneck problem."
  ✅ **Reality:** Sharding raises aggregate throughput across many different clients' keys — it does nothing for one client whose traffic is genuinely hot, since that key still hashes to one node/slot regardless of cluster size (§6/§7).

> **→ Next:** Can you combine what you've learned across sections, not just recall each one?

---

## 9. 🧪 Mastery Gate

> *Synthesis only. Each question must require combining two or more sections.*

1. **(§5 + §6)** A team implements the Redis-backed check as a plain `GET`, an application-side comparison, then a separate `SET` — not a Lua script. Using the atomicity concept from §5 and the failure walkthrough in §6, explain precisely what race becomes possible across multiple app instances, and why this exact race was never a concern for 25.1's token bucket running in a single process.

2. **(§7 + §6, applied to a system not mentioned elsewhere in this doc)** A payments company processes fraud-check API calls from data centers in 3 regions and needs one global "no more than 200 fraud-checks per merchant per minute" limit, exact enough to satisfy a regulatory audit. Using the decision tree in §7 and the cross-region latency cost from §6/§7, decide between a single global Redis and per-region Redis with split quotas, and justify your choice against both the exactness requirement and the latency it imposes on the non-local regions.

3. **(§4 + §5's local-leasing concept)** Using the 10-instance numeric example from §4 and the local-leasing mechanism from §5's fifth concept block, explain why a design using local leasing with periodic sync does not reintroduce §4's N-times-overshoot failure, even though each instance is once again making some admit decisions from local state.

### Mastery criteria — tick only what you can demonstrate on demand

- [ ] Can explain why per-instance local rate-limit state silently multiplies the effective limit across N stateless nodes, and why centralizing state in Redis fixes it
- [ ] Can describe how a Redis Lua script (EVAL/EVALSHA) makes a check-and-deduct atomic across every concurrently-checking instance, and why Redis's single-threaded execution is what provides that guarantee
- [ ] Can explain the fail-open vs. fail-closed decision for Redis unavailability, including which real requirement — compliance vs. availability — drives each choice
- [ ] Can explain how Redis Cluster sharding scales aggregate rate-limiting throughput, and why it does not, by itself, fix a single hot key's throughput
- [ ] Can choose between a synchronous per-request Redis check and a local-leasing/periodic-sync design for a given QPS and precision requirement, naming what precision is given up in the local-leasing case

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 10. 🔗 Connections & Sources

**Builds on:** **25.1 Token Bucket Algorithm** and **25.4 Sliding Window Log and Sliding Window Counter**, which established the algorithms and the single-process atomic-check-and-deduct pattern (via Redis Lua scripts) this doc extends across a fleet of instances rather than reinventing. **Topic 3 (Stateless Architecture)** and **Topic 4 (Load Balancing)**, which establish exactly the horizontally-scaled, load-balanced deployment shape that makes §4's multiplication bug appear in the first place. **Topic 7 (Partitioning)**, whose hash-slot sharding model this doc's Redis Cluster discussion reuses directly, and **5.7 (Hot Key Problem)** / **7.6 (Hot Partitions)**, which this doc's hot-key caveat on sharding points back to explicitly.

**Enables:** **25.6 Rate limiting at CDN, gateway, and service layers**, which needs to decide, per layer, whether that layer's rate limiting is local, centralized, or leased — this doc's fail-open/fail-closed and synchronous/leased trade-offs are two of the concrete axes that per-layer choice turns on.

**Tension with:** **Per-instance local rate limiting**, which is simpler to implement and adds zero network latency, but is only correct when exactly one instance exists — the moment a system scales horizontally, local state stops being a simpler version of the correct answer and becomes a different, wrong one (§4). The tension isn't "centralized is always better" — it's that local state has a narrow domain of correctness that most production systems have already left the moment they add a second instance.

### 📚 Further reading

- [ ] **Envoy / envoyproxy/ratelimit (GitHub)** — https://github.com/envoyproxy/ratelimit — the reference implementation of a centralized, Redis-backed rate-limiting service called by many stateless proxy instances, the direct blueprint for this doc's overall shape
- [ ] **Redis docs — Cluster specification (hash slots, hash tags)** — https://redis.io/docs/latest/operate/oss_and_stack/reference/cluster-spec/ — the mechanics behind this doc's sharding and CROSSSLOT discussion
- [ ] **Redis docs — Scripting with Lua** — https://redis.io/docs/latest/develop/interact/programmability/eval-intro/ — the atomicity mechanism (EVAL/EVALSHA, single-threaded execution) this doc relies on throughout §5/§6
- [ ] **Kong Gateway docs — rate-limiting-advanced plugin, policies and sync_rate** — https://docs.konghq.com/hub/kong-inc/rate-limiting-advanced/ — documents the local/cluster/redis policies and the sync_rate local-leasing pattern referenced in §7
- [ ] **Stripe engineering blog — "Scaling your API with rate limiters"** — https://stripe.com/blog/rate-limiters — Stripe's public writeup on centralizing rate-limit counters in Redis across their API fleet, including their fail-open stance

---

## 11. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
