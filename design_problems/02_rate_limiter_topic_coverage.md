# 🚦 Design Problem #2 — Rate Limiter

> **Roadmap coverage map — what you must own to answer this at staff level.**
> Source of truth for tiers and completion: `system_design_study_roadmap.md`
> Generated: 2026-08-01

---

## 🧭 The Framing

Rate limiting is the most **deceptively simple** problem in the canonical 20. The senior
answer is three sentences: *pick sliding window counter, put it in Redis, return 429.*
Everyone gets there. Nobody is differentiated by it.

The staff answer is differentiated on one thing: **the rate limiter sits on the critical
path of every single request.** That single fact generates every hard question in the
problem —

- It adds latency to 100% of traffic → so the counter cannot live one round trip away
- It is a shared-state component in a stateless tier → so N gateway nodes must agree
- It is the thing that protects you during an incident → so what happens when *it* fails?

If you only prepare one thing for this problem, prepare **fail-open vs. fail-closed.**

**Legend:** ✅ complete · 🥇 T1 Core · 🥈 T2 Depth · 🥉 T3 Awareness

---

## 🥇 Tier A — The Spine

| Topic | Subtopics | Why it's load-bearing here |
|---|---|---|
| **1** Estimation ✅ | 1.3, 1.4, 1.8, 1.13, 1.15 | **1.8 is the one that bites** — Redis memory for a sliding window *log* is O(requests), not O(users). Sizing that is what kills the naive design |
| **2** Core Principles ✅ | 2.1, 2.3, 2.5, 2.7, **2.9** | **2.9 backpressure** — rate limiting *is* backpressure applied at the edge. 2.3: a 5ms Redis hop on a 20ms p50 API is 25% latency overhead |
| **3** Stateless ✅ | 3.1, **3.3**, 3.7 | The counter is the textbook case of **3.3 externalized state**. It's the one piece of state a "stateless" gateway tier actually has |
| **4** Load Balancing ✅ | 4.1, **4.2**, 4.6 | **Sharp insight:** if the LB used IP hash (4.2), each client always lands on the same node — and local counters would just work. The distributed counter problem is *created* by round-robin |
| **5** Caching ✅ | 5.1, 5.4, **5.7**, **5.8** | **5.7 hot key is the core scaling failure** — one abusive client concentrates every counter write on one Redis shard. **5.8** is the fix: local L1 counter + Redis L2 |
| **6** CDN ✅ | 6.1, **6.7** | IP-level limiting belongs at the edge, before your origin ever sees the packet |
| **7** Sharding ✅ | 7.2, 7.4, **7.6** | Counter keyspace partitioning; hot partition is the same failure as 5.7 seen from the storage side |
| **8** DB Fundamentals | 8.1 ✅ | Justify why this is in-memory KV and never a relational DB. One line, but they check |
| **11** API Design | **11.1** 🥇 · **11.7** 🥇 | 429 vs. 503, `Retry-After` semantics. **11.7 API gateway is the canonical home for the limiter** |
| **17** Consistency | **17.4** 🥇 · **17.6** 🥇 | Counters are eventually consistent by design. Over-admitting by 2% is fine; adding 10ms to be exact is not |
| **19** Fault Tolerance | **19.1, 19.2, 19.3, 19.4** 🥇 · **19.7** 🥈 | **19.4 fail-open is the single best staff signal in this problem.** 19.2 jitter: every throttled client honouring the same `Retry-After` retries in lockstep |
| **22** Observability | **22.5** 🥇 · **22.3, 22.8** 🥈 | Rejection rate is the SLI. Alert on *rejections spiking*, not on limiter latency |
| **23** Security | **23.1** 🥇 · **23.8** 🥈 · **23.5** 🥉 | **23.5 API keys define the limiter's identity** — you cannot limit what you cannot attribute. Unauthenticated traffic falls back to IP, which NAT ruins |
| **25** Rate Limiting | **25.1, 25.4, 25.5** 🥇 · **25.2, 25.3, 25.6** 🥈 · **25.7** 🥉 | The whole topic. **All 7 subtopics are Tier A here** — this is the only canonical problem where that's true |
| **28** Locking | **28.1, 28.2, 28.6** 🥇 | Check-then-increment is not atomic across nodes. **28.2's SET NX failure modes are exactly why 25.5 needs a Lua script**, not two round trips |

---

## 🥈 Tier B — Staff-Level Differentiators

| Topic | Subtopics | What it buys you |
|---|---|---|
| **37** Multi-Region | **37.2, 37.3** | *"Is a 1000 req/min limit global or per-region?"* Global costs a cross-region hop on every request; per-region silently gives a 3-region customer 3000. There is no clean answer — naming the trade-off is the point |
| **14** Service Mesh | **14.1, 14.2, 14.6** 🥈 | Envoy has a native rate-limit filter. Sidecar-level limiting vs. gateway-level is a real architecture fork at large microservice counts |
| **16** Replication | **16.5** 🥇 · **16.6** 🥈 | Redis replica failover loses in-flight counter increments — a brief window where limits under-enforce |
| **15** Distributed Storage | **15.3** 🥇 | Do you quorum-write the counter? Almost always no. Explaining *why not* is the staff move |
| **12** Message Queues | **12.4** 🥈 | Consumer-driven backpressure as the async sibling of synchronous rate limiting |
| **22** Observability | **22.6** 🥇 | Trace propagation through a rejected request — most limiters drop the trace and blind you |

---

## 🥉 Tier C — Name and Move On

- **18.6** — *when consensus is NOT needed.* Counters need atomicity, not consensus. Worth one sentence to pre-empt an over-engineered follow-up
- **20.1** — RPO/RTO. **The correct answer is "counters need no backup"** — they're ephemeral and self-healing within one window. Knowing what you *don't* need is a signal
- **13.2** — HTTP/2: one connection, many streams, so per-connection limiting breaks
- **23.6** — TLS termination point determines where you can read the API key

---

## ⚠️ Roadmap Gaps

### Gap 1 — Load Shedding & Adaptive Concurrency 🥈 *(genuine gap)*

The roadmap covers **per-client quota enforcement** (Topic 25) and **isolation**
(19.6 bulkhead), but nothing covers **global overload protection**:

- load shedding by request priority when the system is saturated
- adaptive concurrency limits (Little's Law–derived, TCP Vegas–style) that discover
  capacity at runtime instead of using a static number
- the distinction between *this client is over quota* and *the whole system is unhealthy*

**Why it matters:** the standard staff follow-up is *"every client is within their limit
and the system is still falling over — now what?"* Topic 25 as written has no answer.

> **Proposed placement:** **25.8** 🥈 — *Load shedding and adaptive concurrency limits.*
> Sits better in 25 than 19 because it's the sibling of quota enforcement and shares
> 2.9's backpressure framing. Cross-reference 2.4 (Little's Law) and 19.6 (bulkhead).

### Near-miss — Global Rate Limiting *(not a gap)*

Multi-region limit enforcement is genuinely hard, but **37.2 / 37.3 cover it adequately**
by cross-reference. Adding a subtopic would duplicate. Note it in the connection map
instead.

---

## 📊 Readiness Assessment

Phase B is ✅ complete, which covers the read-path scaffolding. **Topic 25 is entirely
unstudied — 0 of 7.**

| | Count | Est. hours |
|---|---|---|
| Tier A unfinished | 16 🥇 + 7 🥈 + 2 🥉 = **25 subtopics** | **~61h** |
| Tier B unfinished | ~10 subtopics | ~25h |

### 🔑 The overlap insight

**Problems #1 and #2 share 17 Tier A subtopics** — 11.1, 11.7, 17.4, 17.6, 19.1–19.4,
22.5, 23.1, 23.8, 25.1, 25.4, 25.5, 28.1, 28.2, 28.6.

```
 URL Shortener Tier A remaining     30
 Rate Limiter Tier A remaining      25
 Shared                             17
 ─────────────────────────────────────
 Union (both problems)              38
 Marginal cost of adding #2          8 subtopics ≈ 12h
```

The 8 extra subtopics are 6 × 🥈 and 2 × 🥉 — all cheap tiers. **Rate limiter is a ~12
hour add-on to the URL shortener prep, not a 61 hour second project.** Do them as one
block; do not schedule them as separate efforts.

---

## 🎯 Highest-Leverage Sprint (~15h)

Five subtopics, and the chain is unusually tight — each one *breaks* the previous
one's assumption.

```
 25.1  Token bucket
        │  works perfectly on one node — but you have N gateways
        ▼
 25.4  Sliding window log / counter
        │  accuracy under distribution — so where does the counter live?
        ▼
 25.5  Distributed rate limiting with Redis
        │  check-then-increment is two round trips, not atomic
        ▼
 28.2  Redis SET NX — naive lock and its failure modes
        │  atomicity solved via Lua — but what if Redis is down?
        ▼
 19.4  Graceful degradation  →  FAIL OPEN
```

- [ ] 25.1 Token bucket algorithm 🥇
- [ ] 25.4 Sliding window log and sliding window counter 🥇
- [ ] 25.5 Distributed rate limiting with Redis 🥇
- [ ] 28.2 Redis SET NX — naive lock and failure modes 🥇
- [ ] 19.4 Graceful degradation — critical path vs. non-critical features 🥇

> 💡 This sprint shares **25.5, 28.2 and 19.4** with the URL shortener sprint. Running the
> rate limiter sprint first means arriving at problem #1 with three of its six already done.

---

## 🧨 The Three Questions That Separate Staff from Senior

1. **"Redis is down. What happens?"**
   Fail-closed = your API is now 100% unavailable because a *protective* component died.
   Fail-open = the origin gets crushed during the exact incident the limiter exists for.
   Real answer: **fail open, with a degraded local in-memory limit per node as a floor.**
   → 19.4, 19.7, 5.8

2. **"Every client is under their limit and you're still overloaded."**
   Per-client quotas don't compose into a global capacity guarantee. Needs load shedding
   by priority, not more rate limiting. → *roadmap gap 25.8*, 2.9, 2.4

3. **"Is the limit global or per-region?"**
   Global = cross-region round trip on the hot path. Per-region = a 3-region customer
   gets 3× their quota. Most real systems pick per-region and accept the drift.
   → 37.2, 37.3, 17.4

---

## 🔗 Related Files

- `system_design_study_roadmap.md` — source of truth for tiers and completion
- `01_url_shortener_topic_coverage.md` — 17 Tier A subtopics shared with this problem
- `topic_connection_map.md` — cross-topic interview connections
- `system_design/docs/practice_rate_limiter_mock_log.html` — existing mock log
