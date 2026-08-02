# 🔗 Design Problem #1 — URL Shortener (bit.ly)

> **Roadmap coverage map — what you must own to answer this at staff level.**
> Source of truth for tiers and completion: `system_design_study_roadmap.md`
> Generated: 2026-08-01

---

## 🧭 The Framing

The roadmap marks this problem **"unlocked after Phase B."** That is accurate for a **senior**
answer — read path, caching, sharding, load balancing.

A **staff** answer pulls from Phases C, D, E, F, G, and H. The difference is not the redirect;
everyone gets the redirect. The difference is the **write path** (ID allocation, uniqueness,
consistency) and the **operational plane** (rate limiting, analytics, observability, abuse).

**Legend:** ✅ complete · 🥇 T1 Core · 🥈 T2 Depth · 🥉 T3 Awareness

---

## 🥇 Tier A — The Spine

You cannot produce a passing answer without these.

| Topic | Subtopics | Why it's load-bearing here |
|---|---|---|
| **1** Estimation ✅ | 1.3–1.8, 1.10, 1.12, 1.15, 1.16 + Practice 1 | 100:1 read/write ratio, short-code length derived from total-URL count, cache size from Zipf distribution |
| **2** Core Principles ✅ | 2.1, 2.3, 2.5, 2.6, 2.7, 2.8 | The redirect path is **AP**; the create path can be **CP**. Naming that split *is* the answer |
| **3** Stateless ✅ | 3.1, 3.5, 3.6, 3.7 | Idempotency on `POST /urls` — same long URL submitted twice must not burn two codes |
| **4** Load Balancing ✅ | 4.1, 4.2, 4.3, 4.7 | **4.7 global LB** is what makes redirect latency a solved problem |
| **5** Caching ✅ | 5.1, 5.4, 5.5, 5.6, 5.7, 5.8 | Cache-aside + TTL is the core read path. **5.7 hot key is the canonical trap** — one viral link is the entire failure mode |
| **6** CDN ✅ | 6.1, 6.4, 6.5, 6.7 | Can the redirect itself be served at edge? Strong staff signal |
| **7** Sharding ✅ | 7.2, 7.4, 7.5, 7.6 | Hash-partition on short code; be ready to explain why range partitioning is wrong here |
| **8** DB Fundamentals | 8.1 ✅ · 8.3 ✅ · **8.4** 🥇 · **8.6** 🥇 · **8.7** 🥈 · **8.9** 🥇 | **8.9 is the centerpiece of this problem** — base62 sizing, ticket server vs. Snowflake. **8.4 index design on `short_code` is the single most-probed storage detail.** 8.6 ACID for custom-alias uniqueness |
| **11** API Design | **11.1** 🥇 · **11.7** 🥇 | **301 vs 302** — 301 kills your analytics. Interviewers wait for this |
| **15** Distributed Storage | **15.2, 15.3, 15.5, 15.6** 🥇 | Read-replica fan-out is how you serve 10k redirects/sec |
| **16** Replication | **16.5** 🥇 · **16.6** 🥈 | Replication lag → the "I just created a link and it 404s" bug |
| **17** Consistency | **17.4, 17.5, 17.6** 🥇 | **17.5 read-after-write is the defining consistency question for this problem** |
| **19** Fault Tolerance | **19.1–19.4** 🥇 | Graceful degradation: cache down ≠ service down |
| **22** Observability | **22.5, 22.6** 🥇 | Redirect p99 as the SLI; what you'd alert on vs. merely log |
| **23** Security | **23.1, 23.3** 🥇 · **23.8** 🥈 | Malicious-URL scanning, open-redirect abuse, API-key scoping |
| **25** Rate Limiting | **25.1, 25.4, 25.5** 🥇 | Guaranteed follow-up. Per-API-key create limits |
| **28** Locking | **28.1, 28.2, 28.6** 🥇 | Counter-range allocation and alias collision. **28.6 (optimistic concurrency *over* locking) is the staff answer** |

---

## 🥈 Tier B — Staff-Level Differentiators

What separates a staff answer from a senior one. Most candidates stop at the redirect;
staff candidates design the **analytics plane** and the **global story**.

| Topic | Subtopics | What it buys you |
|---|---|---|
| **8 / 10** OLTP ↔ OLAP | 8.2 ✅ · **10.1** 🥈 | Click events don't belong in the serving DB. Splitting the write path is a staff move |
| **12** Message Queues | **12.1, 12.2, 12.3** 🥇 | Async click ingestion; at-least-once + dedup for accurate counts |
| **29** Background Processing | **29.4, 29.5** 🥇 · 29.1 🥇 | TTL expiry sweeper; distributed cron without double-fire |
| **20** Backup & Recovery | **20.1** 🥇 · **20.6** 🥇 | RPO/RTO for a mapping table you can never regenerate |
| **37** Multi-Region | **37.1, 37.3** | Where codes get allocated globally without collision |
| **19** Resilience | 19.5, 19.7 🥈 | Timeout budgets on the redirect hot path |

---

## 🥉 Tier C — Name and Move On

- **13.1 / 13.2** — HTTP keep-alive, HTTP/2 multiplexing
- **23.6** — TLS termination at the edge
- **33.1 / 33.4** — Kafka + windowing (only if they push hard on real-time analytics)
- **22.3** — metric types (counter for redirects, histogram for latency)

---

## ✅ Roadmap Gaps — Closed 2026-08-01

Both gaps identified in the first pass have been filed into the roadmap under Topic 8.

### 8.9 Unique ID Generation 🥇 — *was the critical gap*

The **literal centerpiece** of this problem, previously absent from Topics 1–39. Covers:

- base62 encoding and short-code length sizing
- counter / ticket servers vs. Snowflake IDs vs. hash-and-truncate
- collision probability math for the truncated-hash approach
- pre-allocated ID ranges per app server

**Why Topic 8 and not Topic 7.** Sharding answers *"which node owns this key?"*; ID
generation answers *"what key do I mint?"* — related but not the same. Topic 7 is also
already ✅ complete, so appending to it would reopen a closed topic. The decisive argument
is the build chain with **8.4**: random UUIDv4 primary keys destroy B-tree insert locality
→ page splits → write amplification, which is exactly *why* time-sortable schemes
(UUIDv7, Snowflake) exist.

> ⚠️ **Study 8.9 immediately after 8.4, not in numeric order.**

**The purest conceptual home is Topic 28** — ID generation is fundamentally a
*coordination-avoidance* problem, which is 28.6's thesis. But Topic 28 is Phase H, and
this problem unlocks after Phase B. Owned in 8.9 from the key-design angle; revisited as
a callback in 28.6.

### 8.10 Bloom Filters 🥈

Custom-alias existence checks without hitting the DB on every create. Deliberately kept
**out of 8.9** — probabilistic membership testing is a separate primitive, and folding it
in would push 8.9 past a single T1 budget. Also serves Topics 30 (search) and 9 (object
storage).

---

## 📊 Readiness Assessment

**Phase B completion covers roughly the front half of the spine.** Topics 1–7 are done ✅ —
genuinely most of the read path: caching, sharding, load balancing.

**What's missing** is the write path (ID allocation, uniqueness, consistency) and the
operational plane (rate limiting, observability, resilience).

| | Count | Est. hours |
|---|---|---|
| Tier A unfinished | 27 × 🥇 + 3 × 🥈 = **30 subtopics** | **~86h** |
| Tier B unfinished | ~12 subtopics | ~32h |

> ⚠️ Hour estimate derived from the calibrated T1 = 3h / T2 = 1.75h budgets. Only one
> calibration point exists so far (the 8.3 session), so treat as approximate.

---

## 🎯 Highest-Leverage Sprint (~18h)

Six subtopics that convert a hand-wavy answer into one that survives probing.
**Order matters — each depends on the one before it.**

```
  8.4  Indexing (B-tree on short_code)
        │  random keys wreck insert locality — so which key do you mint?
        ▼
  8.9  Unique ID generation (base62, ticket server, Snowflake)
        │  minting raises: how is uniqueness actually enforced?
        ▼
  8.6  ACID transactions
        │  which raises: what does a reader see mid-write?
        ▼
 17.5  Read-after-write consistency
        │  which forces: how do you enforce it without locks?
        ▼
 28.6  Optimistic concurrency over locking
        │  same primitive, applied to abuse control
        ▼
 25.5  Distributed rate limiting with Redis
```

- [ ] 8.4 Indexing — B-tree, LSM-tree, composite indexes 🥇
- [ ] 8.9 Unique ID generation — base62, ticket servers, Snowflake, collision math 🥇
- [ ] 8.6 ACID transactions — properties and enforcement 🥇
- [ ] 17.5 Read-after-write consistency — failure modes and solutions 🥇
- [ ] 28.6 Alternatives to locking — idempotency and optimistic concurrency 🥇
- [ ] 25.5 Distributed rate limiting with Redis 🥇

---

## ✅ Progress Tracker

> Tier A throughout, plus 8.10 (Tier B) listed here since it studies alongside 8.9.

**Complete (Topics 1–7 + partial 8)**

- [x] Topic 1 — Estimation (incl. Practice 1: URL Shortener)
- [x] Topic 2 — Core Principles (2.1, 2.3, 2.5, 2.6, 2.7, 2.8)
- [x] Topic 3 — Stateless (3.1, 3.5, 3.6, 3.7)
- [x] Topic 4 — Load Balancing (4.1, 4.2, 4.3, 4.7)
- [x] Topic 5 — Caching (5.1, 5.4, 5.5, 5.6, 5.7, 5.8)
- [x] Topic 6 — CDN (6.1, 6.4, 6.5, 6.7)
- [x] Topic 7 — Sharding (7.2, 7.4, 7.5, 7.6)
- [x] 8.1 SQL vs. NoSQL 🥇
- [x] 8.2 OLTP vs. OLAP 🥇
- [x] 8.3 Normalization and denormalization 🥇

**Remaining**

- [ ] 8.4 Indexing 🥇
- [ ] 8.6 ACID transactions 🥇
- [ ] 8.7 Read vs. write optimization 🥈
- [ ] 11.1 REST — resource design, HTTP methods, status codes 🥇
- [ ] 11.7 API gateway patterns 🥇
- [ ] 15.2 Leader/follower model 🥇
- [ ] 15.3 Quorum reads and writes — R + W > N 🥇
- [ ] 15.5 Synchronous vs. asynchronous replication 🥇
- [ ] 15.6 Replication lag and read anomalies 🥇
- [ ] 16.5 Read replicas — architecture and failover 🥇
- [ ] 16.6 Write propagation and replication lag 🥈
- [ ] 17.4 Eventual consistency 🥇
- [ ] 17.5 Read-after-write consistency 🥇
- [ ] 17.6 CAP theorem in practice 🥇
- [ ] 19.1 Retries — naive vs. exponential backoff 🥇
- [ ] 19.2 Jitter 🥇
- [ ] 19.3 Circuit breaker 🥇
- [ ] 19.4 Graceful degradation 🥇
- [ ] 22.5 SLO, SLA, SLI 🥇
- [ ] 22.6 Distributed tracing 🥇
- [ ] 23.1 Authentication vs. authorization 🥇
- [ ] 23.3 JWT — structure, signing, validation 🥇
- [ ] 23.8 DDoS protection 🥈
- [ ] 25.1 Token bucket algorithm 🥇
- [ ] 25.4 Sliding window log and counter 🥇
- [ ] 25.5 Distributed rate limiting with Redis 🥇
- [ ] 28.1 When distributed locking is needed 🥇
- [ ] 28.2 Redis SET NX — naive lock and failure modes 🥇
- [ ] 28.6 Alternatives to locking 🥇
- [ ] 8.9 Unique ID generation — base62, ticket servers, Snowflake, collision math 🥇
- [ ] 8.10 Bloom filters — probabilistic membership testing 🥈 *(Tier B)*

---

## 🔗 Related Files

- `system_design_study_roadmap.md` — source of truth for tiers and completion
- `topic_connection_map.md` — cross-topic interview connections
- `system_design/docs/practice_url_shortener_playbook.html` — existing playbook
