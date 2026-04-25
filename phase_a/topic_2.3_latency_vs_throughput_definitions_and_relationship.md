# 2.3 Latency vs. Throughput — Definitions and Relationship

> **Topic:** Topic 2 — System Design Core Principles & Scalability Fundamentals
> **Phase:** A — Core First Principles
> **Date studied:** 2026-04-23

---

## 1. 🎯 Goal of This Subtopic

- Be able to define latency and throughput precisely and explain the difference without conflating them.
- Understand the relationship between latency, throughput, and concurrency, and apply it to real system constraints.
- Identify when a system is latency-bound vs. throughput-bound and reason about the right optimization target for a given requirement.
- Use Little's Law to calculate effective throughput given average latency and parallelism, applying it directly to capacity planning scenarios.

---

## 2. ✅ What Mastery Looks Like

- [x] Can define latency and throughput in one sentence each, and explain why improving one does not always improve the other.
- [x] Can apply Little's Law (L = λW) to a given system description and derive throughput, concurrency, or latency from the other two.
- [x] Can identify whether a system bottleneck is latency-bound or throughput-bound and describe the appropriate remediation for each.
- [x] Can explain the latency-throughput trade-off concretely using batching as an example (throughput up, tail latency up).
- [x] Can name two real-world systems where throughput is prioritized over latency and two where the reverse is true, with specific mechanisms cited.

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [x] Read the **Further Reading** resources (Section 16) — DDIA Chapter 1, ByteByteGo explainer, Jeff Dean's numbers
- [x] Read through **Sections 5–9** (Core Definition → How It Works) carefully — don't skim
- [x] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [x] Close the doc — write out the **Core Definition** from memory, then compare
- [x] Explain **First Principles** out loud without notes — what problem does this solve and why?
- [x] Reconstruct the **Little's Law mechanics** step by step from memory, including all three derivations
- [x] Restate each **Trade-off** row in your own words — if you can't explain the cost, you don't own it yet

### Phase 3 — Apply 🔧 💪💪💪💪
*Goal: Connect to real systems and simulate interview scenarios.*

- [x] Go through **Real-World System Examples** (Section 10) — for each system, verify the claim independently and add anything the doc missed to **My Notes**
- [x] Practice the **Interview Application** (Section 12) out loud — say the trigger phrases and your response as if in a live interview
- [x] Work through **Common Misconceptions** (Section 13) — for each, make sure you can explain *why* the misconception is wrong, not just that it is
- [x] Trace the **Relationships to Other Concepts** (Section 14) — can you explain the connection to CAP, PACELC, and Little's Law without looking?

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
  Latency measures how fast one request completes; throughput measures how many
  complete per second — they are related but distinct, and optimizing for one
  can hurt the other.

KEY PROPERTIES / RULES
  Latency = time from request start to response delivery (one request, one measurement)
  Throughput = number of requests (or bytes) processed per unit time (a rate)
  Higher concurrency can increase throughput even when per-request latency is unchanged
  Batching increases throughput by amortizing fixed overhead, but increases per-item latency
  Bottlenecks cap throughput — no amount of parallelism helps if the bottleneck is untouched

DECISION RULE
  Optimize for latency when: the user is waiting synchronously (interactive UIs, payment
    APIs, real-time systems, synchronous RPCs).
  Optimize for throughput when: the system processes jobs in bulk with no human waiting
    (ETL pipelines, log processing, video transcoding, async analytics).

NUMBERS / FORMULAS
  Little's Law: L = λ × W
    L = average number of requests in the system (concurrency / queue depth)
    λ = throughput (requests per second)
    W = average latency (seconds)
  Rearranged for throughput: λ = L / W
  Example: 100 concurrent requests, 200ms avg latency → λ = 100 / 0.2 = 500 req/s

GOTCHA TO NEVER FORGET
  Batching always increases tail latency — the last item in a batch waits for the
  whole batch to fill before being processed, even if it arrived first.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

**Latency** is the time elapsed between initiating a request and receiving its response — a measure of speed for a single operation. **Throughput** is the number of operations (or units of data) a system completes per unit of time — a measure of volume capacity. They are related through concurrency via Little's Law (throughput = concurrency / latency), but they can move independently depending on architecture and workload.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*

### Latency
Latency measures the duration of a single end-to-end operation, from the moment a request is issued to the moment a response is received. It includes network round-trip time, queuing delays, processing time, and serialization overhead. Reducing latency matters most when a human or a dependent service is blocked waiting for the result — for example, a synchronous API call in a user-facing product.

### Throughput
Throughput is the rate at which a system processes operations or data — typically expressed in requests per second (RPS), transactions per second (TPS), or megabytes per second (MB/s). High throughput is achievable even with moderately high latency if the system handles many operations in parallel. A database that processes 10,000 writes per second at 20ms average latency has high throughput despite latency that would be unacceptable for a synchronous API.

### Concurrency
Concurrency is the number of operations that are in flight simultaneously. It is the bridge between latency and throughput: you can increase throughput without reducing latency simply by increasing concurrency — up to the point where a resource bottleneck is saturated. This relationship is formalized by Little's Law. A thread pool of 100 workers, each spending 50ms per request, achieves 2,000 req/s throughput even though each individual request takes 50ms.

### Latency-Throughput Trade-off
In many systems, improving throughput comes at the cost of latency. Batching is the canonical example: instead of writing one record at a time, a system groups 1,000 records and writes them together, amortizing the per-flush I/O overhead and dramatically increasing throughput. But the first record in the batch must wait until the batch is full — so its individual latency increases. This trade-off appears in Kafka's `linger.ms`, database write-ahead log group commit, and TCP Nagle's algorithm.

### Bottleneck and Throughput Ceiling
Every system has a bottleneck — a single resource (CPU, disk I/O, network bandwidth, memory bandwidth, lock contention) that limits the maximum throughput regardless of how well everything else scales. Identifying and relieving the bottleneck is the only way to increase the throughput ceiling. Adding capacity to non-bottleneck resources wastes money without improving performance.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

Engineers routinely conflate latency and throughput, leading to the wrong optimization decisions. A system that processes 50,000 records per second might still deliver terrible user experience if individual requests take 10 seconds — throughput is excellent, latency is unacceptable. Conversely, a system with 5ms p99 latency might collapse under load because it only handles 20 concurrent requests — latency is excellent, throughput is insufficient.

The two metrics address fundamentally different needs: latency is about perceived speed (a user's experience of responsiveness at a specific moment), throughput is about capacity (the system's ability to absorb sustained load). Confusing them leads to expensive and ineffective interventions — for example, vertically scaling a server to reduce latency when the actual problem is inadequate concurrency, or adding more workers to reduce per-request latency when the bottleneck is a single-threaded external dependency that serializes all requests regardless.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*

### Model 1: The Toll Booth Highway
Latency is the time it takes a single car to drive through a toll booth. Throughput is the number of cars that pass through per hour. You can increase throughput by adding more toll booths (concurrency) without making each car's toll booth experience any faster. But if you add more booths beyond the road's capacity to feed them (the upstream bottleneck), idle booths appear — throughput stops growing. This model makes the concurrency-throughput-latency relationship intuitive. It breaks down when requests are heterogeneous in size and processing time, which is common in production.

### Model 2: The Restaurant Kitchen
Latency is how long a customer waits from order to dish delivery. Throughput is how many dishes the kitchen sends out per hour. The kitchen can serve more dishes per hour by batching similar dishes and cooking them together — but that increases the wait for the first person who ordered that dish. Adding more chefs (concurrency) increases throughput, but if there's only one oven (bottleneck), chefs queue for it and throughput stops improving regardless of how many chefs are hired. This model works well for explaining both batching trade-offs and bottleneck dynamics in a single frame.

### Model 3: The Pipe and Flow Rate
Think of the system as a pipe: latency is how long it takes a single water molecule to travel the pipe's length; throughput is the volume flowing through per second. You can increase flow rate by widening the pipe (parallelism) without making individual molecules travel faster. A narrow section anywhere in the pipe (bottleneck) caps the flow rate regardless of how wide the rest is. This model is clean for bandwidth and bottleneck reasoning, but does not cleanly explain batching.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

**Little's Law** is the formal relationship between latency, throughput, and concurrency in any stable queuing system:

```
L = λ × W
```

Where:
- **L** = average number of requests in the system (concurrency / queue depth)
- **λ** (lambda) = throughput (requests per second arriving or completing)
- **W** = average time a request spends in the system (latency, in seconds)

"Stable" means the arrival rate ≤ departure rate. If arrival exceeds capacity, the queue grows unboundedly and Little's Law no longer holds — the system is overloaded.

**Practical derivations for capacity planning:**

1. **Compute throughput from concurrency and latency:** λ = L / W. With 200 concurrent DB connections averaging 50ms query time → throughput = 200 / 0.05 = **4,000 queries/second**.
2. **Compute required concurrency from throughput and latency:** L = λ × W. To handle 10,000 req/s at 100ms average latency → need **1,000 concurrent in-flight requests** (thread pool, connection pool, or async coroutines).
3. **Identify scaling lever:** If throughput must increase but latency is fixed, you must increase concurrency (L). If latency must decrease but throughput target is fixed, you must reduce processing time or eliminate queuing.

**Batching mechanics:**
1. Producer sends individual items into a buffer
2. System waits until buffer reaches a threshold (size or time window, e.g., Kafka's `batch.size` and `linger.ms`)
3. Buffer flushes as a single I/O operation
4. Fixed per-flush overhead (network round trip, disk seek) is amortized across all items in the batch
5. **Effect:** Throughput increases; the first item in the batch experiences latency equal to the full buffer-fill wait time

**Bottleneck identification procedure:**
1. Instrument CPU, memory, disk I/O, and network utilization under realistic load
2. The resource that saturates first (hits ~100% utilization) is the bottleneck
3. No other optimization increases throughput until that resource is addressed
4. Common bottlenecks by system type:
   - Read-heavy web services → database reads: add read replicas, add caching layer
   - Write-heavy services → disk I/O: use SSDs, batch writes, or LSM-tree storage engines
   - Compute-heavy services → CPU: horizontal scaling, add workers
   - Fan-out services (notifications, feeds) → network bandwidth: reduce payload size, use compression

**Tail latency:**
p50 (median) latency hides the worst user experiences. At 1,000 req/s, a p99 latency of 2 seconds means 10 users per second get a 2-second response. Tail latency is often caused by resource contention, GC pauses, or retry storms. Optimizing for p99 and p999 requires different approaches than optimizing for median — often involving request hedging (sending a duplicate request to a second server if the first doesn't respond within a threshold).

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| Kafka | Optimized for maximum throughput via batching (`linger.ms`, `batch.size`), sequential disk I/O, and zero-copy transfers. Per-message latency is intentionally sacrificed for aggregate throughput. | End-to-end latency typically 10–100ms; throughput can reach millions of messages/second per broker on commodity hardware. |
| Redis | Optimized for latency (sub-millisecond p99). Single-threaded event loop eliminates lock contention. Throughput is high but bounded by a single core; use Redis Cluster to scale throughput horizontally. | Per-node throughput ceiling ≈ 1M ops/s; latency p99 < 1ms on local network. |
| Google Spanner | Optimizes for external consistency (linearizability) at the cost of both latency and throughput — every commit involves Paxos consensus plus a TrueTime clock uncertainty wait (~7ms). | Not suited for high-throughput write workloads; suited for financial systems where correctness outweighs throughput. |
| DynamoDB | Configurable per-request trade-off: eventually consistent reads have lower latency and consume fewer read capacity units; strongly consistent reads have higher latency and double the RCU cost. | Engineers consciously choose per read based on whether the use case can tolerate stale data. |
| Nginx (reverse proxy) | High throughput via event-driven, non-blocking I/O (epoll) — handles tens of thousands of concurrent connections with minimal per-connection overhead, without affecting per-request latency (which is dominated by upstream services). | Throughput scales with concurrency; Nginx itself rarely becomes the bottleneck. |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Batching dramatically increases throughput by amortizing fixed per-flush overhead | Increases tail latency — the first item in a batch waits for the batch to fill; worst-case latency = full buffer-fill time |
| Increasing concurrency (more workers/threads/async tasks) increases throughput without changing per-operation processing time | Concurrency is bounded by the bottleneck resource; beyond saturation, additional workers increase queuing delay and worsen latency |
| Low-latency optimizations (sync writes, immediate ACK, no batching) improve response time for interactive workloads | Reduce throughput by preventing batching and increasing per-operation overhead (each operation bears full fixed cost) |
| Async processing decouples producer throughput from downstream processing speed, allowing producers to run at full speed | Introduces buffering and queue-management complexity; downstream processing completion is no longer synchronously observable by the producer |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "How do you handle 10 million writes per day?"
- "The system needs to respond in under 50ms"
- "How would you scale the write path?"
- "What are your performance requirements?" (requirements gathering phase)

**What you say / do:**
During requirements gathering, explicitly ask whether the system is latency-sensitive (interactive, user-facing, synchronous) or throughput-sensitive (batch, background, async). State this clearly: "Before designing the write path, I want to confirm whether we're optimizing for low latency — each write must complete quickly and the caller waits — or for high throughput — we need to process a large volume and some buffering is acceptable. That determines whether we batch writes or flush immediately." Then size the system using Little's Law to validate concurrency requirements.

**The trade-off statement (memorize this pattern):**
> "If we choose batching on the write path, we get significantly higher throughput by amortizing I/O cost, but we pay with increased write latency — individual records may wait up to the buffer fill time before being flushed. For this system, batching is the right call because the write path is async and no user is waiting synchronously on the acknowledgment."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** Reducing latency always increases throughput.
  ✅ **Reality:** They are related but independently controllable. A system can have low latency and low throughput (one fast worker, no parallelism) or high latency and high throughput (batching with many workers). Reducing per-operation latency only increases throughput if processing time is the bottleneck — not if the system is I/O-bound or limited by concurrency slots.

- ❌ **Misconception:** Adding more servers always improves latency.
  ✅ **Reality:** More servers increase throughput capacity by distributing load, but they don't reduce the latency of a single request unless that request was previously queuing due to overload. If latency is dominated by a slow upstream dependency or expensive operation, adding application servers does nothing for per-request latency.

- ❌ **Misconception:** p50 (median) latency is the important latency metric to track.
  ✅ **Reality:** At scale, p99 and p999 tail latency matters far more. At 1,000 req/s, a p99 of 2 seconds means 10 users per second experience a 2-second response. Tail latency compounds into cascading timeouts and retry storms that can destabilize the system's throughput characteristics entirely.

- ❌ **Misconception:** Little's Law applies to any system regardless of load.
  ✅ **Reality:** Little's Law only holds in a stable system where the arrival rate ≤ departure rate. If the system is overloaded (queue growing unboundedly), the formula gives nonsensical results. Always verify stability before applying it — if measured concurrency is growing over time, the system is not in steady state.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** Basic intuition about queuing and finite resources (CPU, memory, disk, network) — you need to understand that systems have capacity ceilings before the latency/throughput distinction is meaningful.
- **Enables:** Little's Law application (Topic 2.4 — the direct next subtopic, which formalizes this relationship); bottleneck analysis (Topic 2.8); back-of-the-envelope capacity planning (Topic 1); reasoning about any write path, cache layer, or message queue design in Phase B–K topics.
- **Tension with:** Consistency requirements — achieving low latency often means avoiding synchronous cross-node coordination, which pushes toward eventual consistency (Topics 2.1 CAP, 2.2 PACELC, 2.5). Strong consistency trades latency for correctness guarantees that many systems cannot afford.

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. Define latency and throughput in one sentence each. What is the key difference between them?

Latency is the round-trip time between when the request is initiated and receiving the response. Throughput is measuring the amount of data processed or request handled per unit time. The key difference between these two is that latency is with respect to the user's experience, whereas throughput is a measure of the system.

2. A web service has 500 concurrent in-flight requests and an average response time of 200ms. Using Little's Law, what is the throughput in requests per second?

Little's Law
Concurrency = throughput x latency
throughput = concurrency / latency
throughput = 500 / 0.2 = 2500 req/s

3. Your team decides to batch writes to a database in groups of 500 before flushing. What happens to throughput? What happens to the latency experienced by the first write in each batch?

Throughput increases because fixed I/O overhead is amortized across 500 writes. The first write in each batch experiences the highest latency — it waits for all 499 remaining writes to arrive before the batch flushes. This structurally elevates tail latency (p99), since there will always be requests that arrive just after a flush and wait a full batch window.

4. Name a real production system explicitly optimized for throughput over latency. Name one mechanism it uses to achieve this and what latency trade-off it accepts.

One such example is the Kafka system. It basically chooses to batch requests in order to achieve a higher throughput. Having a batch write amortizes the I/O overhead that each write otherwise has to contend with. The latency trade-off here is that you have a higher latency for the first writes because the first write has to wait for the batch to fill up before it gets flushed off to the system and processed.

5. A service has p50 latency of 10ms but p99 of 3 seconds. The team wants to fix p99 by adding more application servers. Is this the right approach? Under what conditions would it help, and when would it not?

Adding servers increases concurrency, which helps when p99 is high because requests are queuing behind an overloaded server pool. But the p50/p99 gap here is the signal — p50 of 10ms means most requests are fine, so the system isn't fundamentally overloaded. A 3-second p99 points to an outlier problem: a slow query on specific data, a downstream timeout, GC pauses, or lock contention. Adding servers won't fix any of those — you need to identify what's structurally different about the 1% of slow requests first.

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] *Designing Data-Intensive Applications* by Martin Kleppmann — Chapter 1 (Reliable, Scalable, and Maintainable Applications): covers throughput, response time, and percentile latency in depth with concrete examples.
- [ ] ByteByteGo — "Latency vs Throughput" visual explainer (bytebytego.com): short and memorable walkthrough of the distinction with diagrams.
- [ ] *Systems Performance* by Brendan Gregg — Chapter 2 (Methodology): covers utilization, saturation, and the USE method (Utilization, Saturation, Errors) for systematic bottleneck identification.
- [ ] Jeff Dean's "Numbers Every Engineer Should Know" (multiple blog summaries available): latency numbers for common operations that anchor all throughput and latency reasoning in real interviews.

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*
