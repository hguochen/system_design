# 25.1 Token Bucket Algorithm

> **Topic:** Topic 25 — Rate Limiting Systems
> **Phase:** H — System Archetypes
> **Depth Tier:** 🥇 T1 (Core) — budget ~3h
> **Prereqs:** 2.9 (Backpressure Fundamentals), 11.7 (API Gateway Patterns)
> **Date studied:** 2026-08-18

---

## 0. 🧭 The Question This Answers

11.7 established that the gateway is where cross-cutting concerns — auth, routing, SSL termination — live because it is the one place every request already passes through. Rate limiting is the concern that lives there most visibly: the gateway is the natural choke point for deciding how fast any one client is allowed to call you. But "count requests and cut them off" is not a design, it's a slogan, and the naive version of that slogan breaks in a specific, predictable way the moment real traffic — which arrives in bursts, not a smooth drip — hits it.

The tension this subtopic resolves is that you want two things that look like they conflict: tolerate the burstiness that normal usage actually has (a page load firing six requests in parallel, a client retrying after a network blip), while still strictly bounding the long-run average rate so your backend capacity planning holds. A limiter that only tracks "how many requests in the current window" is forced to pick one of those badly, and it has a boundary bug besides. Token bucket is the algorithm that gives you both as two independent, tunable numbers, and it is the default answer to "how would you rate limit this" for exactly that reason.

**The question:** *How do you let a client burst above its steady-state rate for a short period, while still strictly bounding its long-run average rate, using a check cheap enough to run on every single request?*

> **→ Next:** Before the algorithm, what was rate limiting like without it, and why does the obvious first fix — just count and reset — fail?

---

## 1. 🎯 Interview Quick Reference Card

> *Not a summary — a live-recall tool, built for retrieval speed under interview pressure. If you need the reasoning behind anything here, that's what §2 (cheatsheet) and the rest of the doc are for.*

**The checklist — walk this on the whiteboard, in order:**

1. Name the two knobs: **capacity** (max tokens the bucket holds — the burst allowance) and **refill rate** (tokens added per second — the sustained rate you actually enforce)
2. Name the per-request cost: usually 1 token = 1 request, but expensive endpoints can cost more
3. State the check: on each request, refill lazily (`elapsed × rate`, capped at capacity), then if `tokens ≥ cost` deduct and admit, else reject
4. Say the sentence that explains the whole design: **the bucket separates "how much can be banked up" from "how fast it refills"** — that's two independent numbers instead of one reset-based window
5. Name the state per client: exactly two numbers — `tokens`, `last_refill_timestamp` — O(1), which is why this scales to millions of keys
6. Name the concurrency requirement unprompted: check-and-deduct must be **atomic** (single Redis Lua script, or `CL.THROTTLE`/RedisCell) — a naive read-then-write across processes over-admits
7. Name the response contract: reject with `429` + `Retry-After` computed from `(cost − tokens) / rate`, plus `X-RateLimit-*` headers (25.7)

**Trigger → action:**

| Interviewer says | You do |
|---|---|
| "How would you rate limit this API?" | Open with token bucket by default — name the two parameters immediately, then contrast leaky bucket only if they push for hard smoothing |
| "What happens if a client sends a burst?" | State it precisely: up to `capacity` requests succeed instantly, then it throttles to the refill rate — that's the design goal, not a bug |
| "How do you refill tokens without running a timer per bucket?" | Lazy refill: compute elapsed time since the last check, multiply by rate, cap at capacity — done inline on every request, no background thread |
| "How does this work across multiple gateway instances?" | Centralize bucket state in Redis, keyed per client, and do check-and-deduct as one atomic Lua script — a naive two-call read/write races |
| "What do you return to a throttled client?" | `429 Too Many Requests`, `Retry-After` in seconds, and `X-RateLimit-Limit/Remaining/Reset` headers |

**Fast disambiguation — the pairs that get confused live:**

| Pair | The distinction |
|---|---|
| **Token bucket vs. leaky bucket** | Token bucket lets bursts up to `capacity` through instantly, then throttles to the rate. Leaky bucket forces a strictly constant *output* rate regardless of input burst — it queues or drops, it never lets a burst pass. One optimizes for tolerant UX, the other for hard downstream protection. |
| **Capacity vs. refill rate** | Capacity = how big a burst you tolerate (short-term, one-time). Refill rate = the long-run average you actually enforce (steady-state, forever). Conflating the two — thinking a bigger bucket raises the sustained rate — is the most common mistake. |
| **Rate limiting vs. backpressure** | Rate limiting (this doc) is the caller-facing boundary rejecting or delaying over-quota requests. Backpressure (2.9) is the *callee* signaling the caller to slow down — a different direction of control, sometimes implemented using the same bucket primitive internally. |
| **Per-client bucket vs. global bucket** | A per-client bucket (keyed by API key/user/IP) enforces fairness between clients. A single global bucket enforces total system throughput regardless of who's calling. Most real systems layer both. |

**High-yield anchors:**

```
Token cost: 1 token = 1 request by default; weighted endpoints (e.g. search,
  export) can cost more, still checked against the same bucket.
Typical shape: capacity set to a few seconds' to tens-of-seconds' worth of
  tokens at the refill rate (e.g. rate = 100 req/s, capacity = 100–300).
State per client: exactly 2 numbers (tokens, last_refill_ts) — O(1), which
  is what makes per-key limiting affordable at millions of keys.
GCRA (Generic Cell Rate Algorithm): a mathematically equivalent
  reformulation using ONE timestamp ("theoretical arrival time") instead of
  a separate float counter — same guarantees, even less state. Used by
  Stripe and Cloudflare.
Redis: RedisCell's CL.THROTTLE command implements GCRA as a single atomic
  command — no hand-written Lua script, no race, one round trip.
HTTP contract: 429 Too Many Requests, Retry-After (seconds), and the de
  facto X-RateLimit-Limit / -Remaining / -Reset headers (25.7).
```

**The script — say this close to verbatim:**

> "I'd rate limit with a token bucket per client key — API key, user ID, or IP depending on the layer. Each bucket has two independent numbers: capacity, the burst it can absorb, and refill rate, the sustained rate I actually want to enforce. On every request I lazily compute the elapsed time since the last check, refill up to the cap, and if there's at least one token I deduct it and let the request through; otherwise I reject with a 429 and a Retry-After computed from how many tokens are needed divided by the refill rate. I default to token bucket over leaky bucket because it's the same O(1) state per client but it tolerates real traffic shape — a client firing a few parallel requests on page load isn't a violation, it's normal usage, and the bucket absorbs it instead of rejecting it. The cost I'm accepting is that a client can legitimately spike to `capacity` requests in a single instant, so downstream capacity has to be provisioned for that burst, not just the average. Across multiple gateway instances I'd centralize the bucket in Redis and do the check-and-deduct as a single atomic Lua script or a `CL.THROTTLE` call, because a naive read-then-write from two nodes races and silently over-admits."

> **If pushed on the distributed case specifically:** "A naive implementation reads the token count, decides locally, then writes the new count back — across two concurrent requests on two different gateway nodes, both can read the same 'one token left' state and both admit, which quietly doubles your effective limit under load. The fix is making the read-check-write one atomic operation server-side — a Lua script in Redis, or a purpose-built command like `CL.THROTTLE`, so there's no gap between reading the state and committing the decision for anyone else to race into."

---

## 2. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*
>
> ⏭️ **First time through this topic?** Skip to §3 and come back here for revision.

```
§ 1  WHY IT EXISTS
Without any limiter, one client — buggy retry loop, scraper, or attacker —
can consume backend capacity meant for everyone. The obvious first fix is
a fixed window counter: count requests in the current calendar window,
reset at the boundary. It has a boundary bug — a client can send the full
quota in the last instant of one window and again in the first instant of
the next, doubling the effective rate right at the reset — and it forces
an ugly choice between being too strict (blocking a normal 3-request
burst because the window is already 8/10 used) or too loose. The insight
is to stop resetting on a clock and instead track two continuously
updating numbers: how much is currently banked (tokens) and how fast it
refills (rate). There's no boundary because there's no reset.

§ 2  WHAT IT IS
BUCKET       A counter bounded by `capacity`, holding `tokens` (0..cap).
CAPACITY     Max tokens the bucket can hold = the burst allowance.
REFILL RATE  Tokens added per second = the enforced sustained/average rate.
COST         Tokens a single request consumes. Usually 1; can be weighted
             per endpoint (a search call might cost 5).
STATE        Exactly 2 numbers per client: `tokens`, `last_refill_ts`.

§ 3  THE MECHANISM
LAZY REFILL   On each check: elapsed = now - last_refill_ts;
              tokens = min(capacity, tokens + elapsed * rate);
              last_refill_ts = now. No background timer needed.
ADMIT/REJECT  If tokens >= cost: tokens -= cost, ADMIT.
              Else: REJECT, do not deduct, return 429 + Retry-After.
ATOMICITY     Refill + check + deduct must happen as ONE atomic step per
              request. Split into separate read/write calls, it races
              under concurrency.

§ 4  USE / AVOID
USE token bucket when: you want to tolerate normal bursty client behavior
  (parallel page-load requests, retry-after-blip) while still bounding
  the long-run average. This is the default choice for public APIs.
AVOID token bucket when: you need the OUTPUT rate to be strictly constant
  regardless of input burst (feeding a fixed-throughput downstream system)
  — that's leaky bucket's job, not token bucket's (25.2).
AVOID a per-gateway-node-local bucket when multiple nodes sit behind a
  load balancer without shared state — N nodes each enforcing the full
  capacity independently means the client's real ceiling is capacity × N.
AVOID sizing capacity by intuition — size it from measured legitimate
  burst shape (1.4 Peak traffic estimation), not a round number.

§ 5  DISTRIBUTED / CONCURRENCY
THE RACE      Two concurrent requests both read tokens=1, both decide
              "I can admit", both deduct → both succeed. Read-then-write
              is not safe under concurrency.
THE FIX       Make check-and-deduct one atomic operation: a Redis Lua
              script (read, compute, write, all server-side in one round
              trip) or a native atomic command (RedisCell's CL.THROTTLE,
              implementing GCRA).
GCRA          A reformulation of token bucket using a single timestamp
              ("theoretical arrival time") instead of a float counter —
              same guarantees, even less state, used by Stripe/Cloudflare.
LOCAL VS      Centralized (Redis): exact, costs one network round trip per
GLOBAL        request. Per-node local buckets: zero extra hop, but only
              approximate once you have more than one node.

§ 6  NUMBERS TO ANCHOR THE DISCUSSION
Token cost: 1 = 1 request by default; weighted for expensive endpoints.
Capacity shape: a few to tens of seconds' worth of tokens at the refill
  rate (e.g. rate=100/s, capacity=100–300) is a typical starting point.
State: 2 numbers per client key — O(1) — affordable at millions of keys.
HTTP: 429 Too Many Requests · Retry-After (seconds) · X-RateLimit-Limit /
  -Remaining / -Reset (de facto standard, formalized in 25.7).

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "How would you rate limit an API?"     → token bucket by default, name
                                            capacity + rate immediately
→ "What if a client bursts?"             → up to capacity admitted
                                            instantly, then throttled —
                                            that's the design, not a bug
→ "Multiple gateway nodes?"              → centralize state in Redis,
                                            atomic check-and-deduct
GOTCHA: Keeping the bucket in each gateway instance's local memory with no
  shared state. It "works" in a demo with one node. Behind a load
  balancer with N nodes, each enforces the FULL capacity independently —
  the client's actual achievable burst is capacity × N, not capacity.
```

---

## 3. 🧠 The Mindmap

> *The picture to hold in your head while you study. Everything below hangs off this.*

```
                        ┌─────────────────────────┐
                        │   TOKEN BUCKET           │
                        └────────────┬────────────┘
                                     │
     ┌───────────────┬───────────────┼───────────────┬───────────────┐
     ▼                ▼               ▼               ▼               ▼
 ① PARAMETERS    ② MECHANISM    ③ BURST         ④ DISTRIBUTED/  ⑤ WHERE IT
                                   BEHAVIOR         CONCURRENCY     LIVES
 ├ capacity      ├ lazy refill   ├ full bucket   ├ read-then-    ├ gateway /
 │ (burst cap)   │  formula      │  → instant     │  write races   edge (11.7)
 ├ refill rate   ├ check tokens  │  burst admit   ├ fix: atomic   ├ per-client
 │ (sustained)   │  >= cost      ├ empty bucket   │  Lua / CAS     key: IP,
 ├ token cost    ├ deduct on     │  → throttle    ├ GCRA: same     API key,
 │ (per request) │  admit only   │  to rate        │  guarantee,     user ID
 └ state: 2 nums ├ atomic step   └ new key starts │  1 timestamp  ├ 429 +
   (tokens,      │  (refill +      full by         ├ centralized    Retry-After
   last_ts)      │  check +        default          Redis vs      ├ contrast:
                 │  deduct)                          per-node        leaky
                 └ O(1) per key                      local            bucket
                                                      approx          (25.2),
                                                                       sliding
                                                                       window
                                                                       (25.4)
```

**How to read it:** these are parallel facets, not a sequence — but there's still a natural order to reach for them in an interview. ① and ② are what you say first: the two parameters and the check that uses them. ③ is the direct, provable *consequence* of ① and ② — walk it out loud so the interviewer sees you understand what the numbers actually produce. ④ only enters once "multiple instances" or "at scale" comes up, and it's the branch most candidates skip until pushed — don't wait to be pushed. ⑤ ties the algorithm back to where it's enforced and what it's being compared against, which is how you close a design answer instead of leaving it as an abstract mechanism.

---

## 4. 🔥 The Problem

Before any limiter, a public API has no defense against a single client consuming capacity meant for everyone: a buggy retry loop with no backoff, a scraper, or a straightforwardly malicious actor can all send requests as fast as the network allows, and the backend — sized for aggregate legitimate traffic, not one client's ceiling — degrades or falls over for every other client at the same time. This is the multi-tenant version of the noisy-neighbor problem, and "add more servers" doesn't fix it, because the unbounded client simply consumes whatever capacity you add.

The instinctive first fix is a **fixed window counter**: count requests per client in the current calendar window (say, per minute), and once the count hits the limit, reject the rest until the window resets. It is simple to reason about and cheap to implement, and it is also wrong in a specific, provable way: a client can send its full quota in the last instant of one window and its full quota again in the first instant of the next window, and nothing in the design prevents it — from the backend's perspective, that's two back-to-back full bursts with almost no gap between them, meaning the *effective* short-term rate at the boundary can be double the configured limit. The second failure is orthogonal but just as real: a fixed window forces a false choice at every point *inside* the window too. A client that legitimately fires three parallel requests on a page load either gets blocked because the window happens to already be near its cap from unrelated earlier traffic, or the limit has to be set generously enough to never do that — which defeats the point of limiting anything.

The insight that resolves both problems at once is to stop tying the limit to a reset clock at all. Instead of one number ("count so far this window"), use two independent numbers: how much burst capacity is currently banked, and how fast more of it accrues. Let the first number decay and refill continuously rather than jumping to zero on a boundary, and there is no boundary left to have a bug at — and because burst capacity and sustained rate are now separate knobs, you can tune generous burst tolerance and a strict long-run average at the same time, instead of being forced to trade one against the other.

**Before and after:**

```
  BEFORE — fixed window counter                AFTER — token bucket
  ──────────────────────────────               ─────────────────────────────
   count = requests_in(current_minute)          tokens = min(cap, tokens +
   if count >= limit: reject                             elapsed * rate)
   else: count += 1; admit                      if tokens >= cost: admit
                                                 else: reject

   ✓ trivial to reason about                     ✓ no reset boundary — refill
   ✗ boundary doubling: full quota                 is continuous
     at :59 + full quota at :00                  ✓ burst tolerance (capacity)
     = 2x burst, undetected                        and sustained rate (rate)
   ✗ one knob does two jobs:                        are independent knobs
     "burst allowance" and "average                ✓ tunes both at once instead
     rate" are the same number,                      of trading one for the
     so tuning one wrecks the other                  other
```

### ✅ Checkpoint

1. A teammate proposes fixing the fixed-window boundary bug by shrinking the window from one minute to one second — "then the worst case is only a tiny burst." Explain precisely why this doesn't remove the boundary bug (only shrinks its absolute size), and explain the separate problem it still doesn't solve: a client whose legitimate traffic is naturally bursty within a single window.

   > 💡 *If you hesitate, re-read the second paragraph — the boundary math applies at any window size, and the third paragraph's point about one number doing two jobs.*

> **→ Next:** If two independent numbers are the fix, what exactly are they, and what does the algorithm built on them actually look like?

---

## 5. 💡 The Core Idea

**A token bucket holds up to `capacity` tokens that refill continuously at `rate` tokens per second; a request is admitted only if it can pay `cost` tokens from the bucket, and because capacity and rate are two independent, continuously-updating numbers instead of one reset-based counter, a client's momentary burst and its sustained average rate can be bounded separately instead of being forced into the same number.**

**Visual required:** build-chain diagram.

```
 [TWO INDEPENDENT ──▶ [REFILL IS       ──▶ [ADMISSION IS AN ──▶ [STATE IS O(1),
  KNOBS: CAPACITY       CONTINUOUS,          ATOMIC CHECK-       SO IT SCALES TO
  AND RATE]             NOT A RESET]         AND-DEDUCT]         MILLIONS OF KEYS]
   because               because the           so the refill        because state
   burst tolerance       two knobs must         and admission        is just two
   and sustained          each be tunable        decision must         numbers per
   rate are separate      on their own            happen as one         client, it's
   guarantees              schedule, refill        indivisible            cheap enough
                            is computed              step per               to keep per-
                            on demand from            request, not           API-key, not
                            elapsed time,             two separate           just per
                            not a clock reset         calls                  system
```

### Two Independent Knobs: Capacity and Rate

Everything starts with separating the two things a "requests per minute" number was quietly conflating. **Capacity** is the maximum number of tokens the bucket can ever hold — this is the burst allowance, the one-time amount a client can draw down instantly if it's been idle. **Refill rate** is how many tokens are added per second — this is the sustained, long-run average you actually enforce, forever, with no time limit on how long it's checked. **Cost** is how many tokens a single request consumes, almost always 1, though a system can weight expensive endpoints — a bulk export costing 5 tokens against the same bucket a cheap lookup costs 1. The load-bearing consequence: because capacity and rate are independent, you can be generous on one without being generous on the other — a client can burst 300 requests in one instant (capacity=300) while still being strictly held to 100/s (rate=100) over any longer window. A single "requests per window" number cannot express that at all.

### Refill Is Continuous, Not a Reset

Given two knobs instead of one, the natural next question is how the bucket actually fills back up, and the answer is the piece that eliminates §4's boundary bug entirely: refill happens **lazily**, computed on demand rather than on a background timer or a clock reset. On every check, the limiter computes `elapsed = now - last_refill_timestamp`, adds `elapsed * rate` tokens (capped at `capacity`), and updates the timestamp. There is no "window" to reset, so there is no boundary at which two full bursts can stack — refill is a smooth, continuous function of wall-clock time, evaluated fresh at whatever moment a request happens to arrive. This is also why no background thread is required per bucket: the "time since last refill" calculation folds the passage of time into the very next request that checks the bucket, whether that's 10 milliseconds or 10 minutes later.

### Admission Is One Atomic Check-and-Deduct

Because the refill calculation and the admission decision both happen at the moment a request arrives, and because the decision has to be correct even when many requests for the same client arrive at nearly the same instant, the two steps — "does the bucket have enough tokens" and "take the tokens" — must be a single indivisible operation, not two separate calls. If a request reads the token count, decides to admit, and only *then* writes the decremented count back, a second concurrent request can read the same pre-decrement count in between and make the same decision — both admit, and the bucket has silently over-admitted. This is not a theoretical edge case; it is the default failure mode of the naive implementation the moment more than one process can touch the same bucket concurrently, which in a real gateway is immediately.

### State Is O(1) Per Client, So It Scales

Because the whole mechanism reduces to two numbers — `tokens` and `last_refill_timestamp` — and one atomic operation, the memory and compute cost per client is constant regardless of how much traffic that client sends. That is precisely what makes **per-client** rate limiting (one bucket per API key, per user, or per IP) affordable at the scale a real gateway operates at: millions of distinct keys, each needing independent enforcement, cost only a few bytes and one small atomic operation apiece. A heavier per-client structure — say, storing every individual request timestamp — would not scale the same way, which is exactly the trade-off 25.4's sliding window log makes deliberately in exchange for tighter precision.

### ✅ Checkpoint

1. Explain, using only the two knobs from the first concept block, why a system with `capacity=500, rate=50` and a system with `capacity=50, rate=50` enforce the *same* long-run average rate but behave completely differently for a client that has been idle for an hour and then sends a sudden burst.

   > 💡 *If you hesitate, re-read "Two Independent Knobs: Capacity and Rate" — specifically the sentence about being generous on one without being generous on the other.*

2. Trace the link from "Refill Is Continuous, Not a Reset" into "Admission Is One Atomic Check-and-Deduct": explain why moving to continuous, on-demand refill is precisely what turns the admission check from something that could previously be a simple counter compare into something that now *requires* atomicity to stay correct.

   > 💡 *If you hesitate, re-read the third concept block's second sentence — the one describing what happens when read and write are split into two calls.*

> **→ Next:** You know the two knobs and the shape of the check. What actually happens, step by step, when a request arrives — and what breaks it?

---

## 6. ⚙️ How It Actually Works

**Happy path — one request, end to end:**

1. A request arrives tagged with a rate-limit key — an API key, a user ID, or an IP address, depending on which layer is enforcing (25.6).
2. The limiter loads that key's bucket state, `{tokens, last_refill_ts}` — or, if the key has never been seen, initializes it to a full bucket: `tokens = capacity`, `last_refill_ts = now`.
3. It computes `elapsed = now - last_refill_ts`, then `tokens = min(capacity, tokens + elapsed * rate)`, and updates `last_refill_ts = now`. This is the lazy refill — no separate timer process is involved.
4. If `tokens >= cost` (usually `cost = 1`): deduct — `tokens -= cost` — store the new state, and admit the request.
5. If `tokens < cost`: do **not** deduct. Store the refreshed-but-still-insufficient token count anyway (so the next request's elapsed-time calculation starts from *this* check, not the last successful one), reject the request, and return `429` with `Retry-After = (cost - tokens) / rate` seconds — the time until enough tokens will have accrued.

> 🗺️ **Mental model — the reservoir with a slow valve.** Picture a water tank of size `capacity`, fed by a valve that lets in `rate` liters per second. Every admitted request draws `cost` liters out instantly. If the tank has been full and untouched, you can drain it all at once — that's the burst. Once it's empty, you can only draw water as fast as the valve refills it — that's the throttle. *Where it breaks down:* a physical tank has exactly one tap open at a time; nothing about the plumbing needs to coordinate concurrent draws. A software bucket is checked by many requests arriving at effectively the same instant, and the reservoir picture hides that entirely — the atomicity requirement in step 4/5 above has no physical analogue in this model, which is exactly the part that trips people up when they move from "I understand the algorithm" to "I can implement it correctly under concurrency."

**Failure & edge cases:**

- **The concurrent-admission race.** Two requests for the same key arrive close enough together that both read `tokens = 1` before either writes back. Both compute "I can admit," both deduct, both succeed — the bucket has now given out one more token than it had. This happens the moment more than one process (or even two threads) can touch the same bucket state without serialization. **Fix:** make steps 3–5 one atomic operation — a Redis Lua script that does the read, compute, and write server-side in a single round trip, or a purpose-built atomic command like RedisCell's `CL.THROTTLE` (which implements the mathematically equivalent GCRA formulation). A mutex or CAS-retry loop works too, but costs more under contention than pushing the whole check into the data store.
- **Cold-start burst.** A brand-new key initializes with a *full* bucket by design (step 2) — the first-ever request from any client can be part of an instant `capacity`-sized burst. This is usually fine for one client, but if many new keys appear simultaneously (a cache flush, a mass client reconnect after an outage), the *aggregate* first burst across all of them can spike well above what steady-state capacity planning assumed. Mitigate by starting new buckets partially filled, or by sizing capacity with worst-case simultaneous cold-starts in mind.
- **Clock source consistency.** The elapsed-time calculation in step 3 must use the limiter's own clock consistently for both `now` and any stored `last_refill_ts` — mixing a client-supplied timestamp in, or reading `now` from hosts with meaningfully skewed clocks, corrupts the refill math in ways that are hard to notice until someone is getting throttled (or not throttled) for the wrong reason.
- **Weighted/variable cost.** Not every request should cost the same. A cheap read and an expensive bulk export sharing one bucket need different `cost` values so the expensive path drains the bucket faster and hits the limit sooner — the mechanism doesn't change, only the number subtracted in step 4 does.
- **Idle-key memory growth.** A bucket for a key that stops sending traffic should not live forever in memory. Because a bucket that's been idle longer than `capacity / rate` seconds is mathematically indistinguishable from a fresh full bucket (it would have refilled to the cap anyway), it's safe to `TTL` the stored state at roughly that interval and let step 2's cold-start path re-initialize it — this bounds memory at the number of *active* keys, not all keys ever seen.

**Mechanism flow, end to end:**

```
① REQUEST ARRIVES        ② LOAD / INIT STATE      ③ LAZY REFILL              ④ CHECK + DEDUCT (atomic)
  key = API key /          {tokens, last_ts}        elapsed = now - last_ts    if tokens >= cost:
  user / IP        ──▶     or full bucket if  ──▶    tokens = min(cap,  ──▶      tokens -= cost → ADMIT
                            never seen                tokens + elapsed*rate)   else:
                                                       last_ts = now              leave tokens as-is
                                                                                   → REJECT (429 +
                                                                                     Retry-After)
```

**Token level over time — burst then throttle:**

```
 tokens
 cap ┤███████████████╮
     │                ╲___                              (full bucket:
     │                    ╲___                            instant burst
     │                        ╲___                         admitted, then
     │                            ╲___  ← refill slope       throttled to
     │                                ╲___   = rate            steady rate)
   0 ┤                                    ╲___________________________
     └──────────────────────────────────────────────────────────────▶ time
        ▲ burst of      ▲ tokens hit 0:      ▲ admits now track the
          requests         further requests     refill rate exactly —
          drains the       rejected until        one admitted request
          bucket fast       enough refills       per (1/rate) seconds
```

### ✅ Checkpoint

1. Walk through exactly what happens, in order, when two requests for the *same* key arrive close enough together that both read the bucket state before either writes it back — assume `tokens = 1` and `cost = 1` for both. What does the naive (non-atomic) implementation do, and name precisely which step in the happy-path list above has to become a single atomic operation to prevent it.

   > 💡 *If you hesitate, re-read "The concurrent-admission race" and steps 3–5 of the happy path.*

2. A client has been completely idle for six hours and then sends 40 requests in the same second, on a bucket configured with `capacity=50, rate=10`. Using the lazy-refill formula from the happy path, explain exactly what happens to all 40 requests and why — then explain what would be different if the same client had been idle for only 2 seconds instead of six hours.

   > 💡 *If you hesitate, re-read step 3 (the refill formula, note the `min(capacity, ...)` cap) and step 2 (cold-start initialization).*

> **→ Next:** You can mint and check a bucket correctly. In a real design, when do you actually reach for this algorithm — and what does that choice cost you?

---

## 7. ⚖️ The Decision — When, and What It Costs

The baseline isn't really a judgment call: almost any public API benefits from *some* rate limiting, and token bucket's O(1) state makes "should I bother" rarely worth debating. The actual decisions are about which algorithm's *shape* fits the traffic and the downstream system, and how the state is held once more than one gateway process is involved.

**Normal, bursty client traffic and a bounded long-run average is enough.** This is the case token bucket exists for — the default. Page loads fire several requests in parallel, clients retry after transient blips, and none of that should be treated as a violation as long as the client's average rate over time stays within bounds. You get burst tolerance and average-rate enforcement as two independently tunable numbers, and O(1) state per client cheap enough to apply per API key rather than only globally.

**The downstream system genuinely cannot absorb any burst at all.** If what's on the other side of the limiter is something with a hard, fixed processing rate — a queue consumer with a strict SLA, a piece of hardware, a third-party API with its own unforgiving rate contract — then token bucket's entire point (letting a burst through) is the wrong feature to have. Leaky bucket (25.2) forces a constant egress rate by queuing or dropping excess, trading away the burst tolerance token bucket deliberately grants, in exchange for a downstream rate that never spikes.

**Multiple gateway nodes need to agree on one client's usage.** A bucket kept in a single process's local memory is correct for exactly one process. The moment a load balancer fans requests across N gateway instances, each keeping its own local bucket independently enforces the *full* capacity and rate — the client's real achievable ceiling becomes roughly `capacity × N` and `rate × N`, not the configured values. Centralizing the bucket state in Redis (25.5) with an atomic check-and-deduct restores a single source of truth at the cost of one network round trip per request; keeping buckets local-only is only correct if either there's exactly one instance, or the per-node limit is deliberately set to `configured_limit / N` and you accept that as an approximation.

**How precise does the burst boundary need to be, and can you afford more memory for it?** Token bucket's guarantee is coarse in one specific sense: it tracks *aggregate* tokens, not individual request timestamps, so it can't answer "how many requests arrived in exactly the last 500ms" — only "is there budget right now." If a design genuinely needs that finer-grained precision (25.4's sliding window log tracks every timestamp; the sliding window counter approximates it more cheaply), that's a real, separate trade against token bucket's cheaper but coarser accounting.

**Decision tree:**

```
        Must the downstream system see a strictly constant
        rate, with bursts queued or dropped rather than admitted?
                              │
              ┌──────yes──────┴──────no, some burst is fine───────┐
              ▼                                                    ▼
        Leaky bucket (25.2).                          Do multiple gateway nodes
        Token bucket's whole                          need to enforce ONE shared
        point (letting bursts                         limit per client?
        through) is the wrong                                    │
        feature here.                          ┌──────no──────────┴──────yes─────────┐
                                                ▼                                     ▼
                                    Local in-memory bucket             Centralize in Redis;
                                    per instance is fine.               atomic check-and-deduct
                                    (Single instance, or                (Lua script / CL.THROTTLE).
                                    accept N-way approximation.)         Costs one round trip/request.
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Bursts up to `capacity` are absorbed instantly**, so normal bursty client behavior (parallel page-load calls, retries) isn't punished as a violation | Downstream capacity must be provisioned for the full `capacity`-sized burst, not just the average rate — a *well-behaved* client can legitimately spike that high in one instant |
| **O(1) state per client** (two numbers) makes per-key limiting — one bucket per API key, not just one global limit — cheap enough at millions of keys | Concurrent access to the same key's state must be atomic; a naive read-then-write split across two calls (or two gateway processes) silently over-admits under load |
| **Continuous lazy refill has no reset boundary**, so there's no version of the fixed-window "2x burst at the boundary" bug | The refill math is easy to get subtly wrong in practice — forgetting the `min(capacity, ...)` cap, or computing elapsed time from an inconsistent clock source, breaks the guarantee silently rather than loudly |
| **Capacity and rate map directly onto SLA language** ("burst up to X, sustained no more than Y/sec"), which is simple to document and communicate to API consumers | Choosing the two numbers correctly requires knowing real traffic shape (1.4 Peak traffic estimation) — set capacity too high and it's a self-inflicted burst amplifier; too low and it throttles legitimate parallel requests |

### In production

| System | How it applies | The nuance |
|--------|----------------|------------|
| **Stripe API** | Rate limits per API key using GCRA, the single-timestamp reformulation of token bucket | Chosen specifically for O(1) memory per key with the same guarantees as a two-number bucket — documented publicly as their rate-limiting approach |
| **Amazon API Gateway (usage plans)** | Token bucket per API key: a `rateLimit` (steady-state req/sec) and a `burstLimit` (bucket capacity), configured directly | The two config fields customers set are literally token bucket's two parameters, exposed by name rather than hidden behind an abstraction |
| **Cloudflare** | Uses GCRA at the edge for per-IP and per-zone rate limiting rules | GCRA's single-timestamp state is what makes this affordable at edge-node scale — billions of distinct IPs, no room for a heavier per-key structure |
| **Redis (RedisCell module)** | Ships `CL.THROTTLE` as a native atomic GCRA command | Removes the need to hand-write and maintain a Lua script for the check-and-deduct step — one round trip, no race window, by construction |
| **NGINX (`limit_req` module)** | Implements a leaky-bucket-flavored limiter by default, with burst tolerance as an opt-in `burst`/`nodelay` directive | A useful contrast: NGINX's *default* behavior is closer to leaky bucket (smooth, queued output); token-bucket-style instant burst admission has to be explicitly requested, which is the opposite default from what this subtopic recommends for a public API |

### ✅ Checkpoint

1. You're designing rate limiting for an internal batch-ingestion API that feeds a downstream stream processor with a hard, fixed throughput ceiling — the processor falls over if it receives more than 200 events/sec, no matter how briefly. An engineer proposes a token bucket with `rate=200, capacity=2000` so "clients can burst when they need to." Using the decision tree, say whether you'd approve this design, name specifically what breaks if you do, and state what you'd build instead.

   > 💡 *If you hesitate, re-read the second boundary condition ("The downstream system genuinely cannot absorb any burst at all") and the first branch of the decision tree.*

> **→ Next:** Can you deliver this cleanly under interview pressure — including when the interviewer pushes on the distributed case specifically?

---

## 8. 🎯 In the Interview

**When an interviewer asks / says:**
- "How would you prevent a single client from overwhelming this API?"
- "What rate limiting algorithm would you use, and why that one?"
- "What happens if a client sends a burst of requests?"
- "How does this work once you have multiple gateway or API server instances?"

**What you say / do:**
This surfaces the moment you mention an API gateway or a public-facing endpoint in the high-level design, and it's worth naming proactively rather than waiting to be asked. It comes back in the deep dive from two directions: a burst-behavior probe ("what if a client sends 500 requests at once?") and a scaling probe ("what if there are 10 gateway instances?"). Deliver it in a fixed order: name the choice (token bucket, per-client key), give the mechanism reason (two independent knobs — capacity for burst, rate for sustained average — checked with a lazy, on-demand refill), price it unprompted (a well-behaved client can legitimately burst up to `capacity` in one instant, so downstream capacity has to be sized for that), then name the switch condition (centralize in Redis with an atomic check-and-deduct the moment more than one instance needs to share the limit, or switch to leaky bucket entirely if the downstream truly cannot tolerate any burst).

**The trade-off statement (memorize this pattern):**
> "I'd rate limit with a token bucket per API key, with a capacity and refill rate sized from the traffic shape I actually expect — say `rate=100/s` for the sustained average and `capacity=300` so a client can burst for a few seconds without being penalized. Each request costs one token by default, deducted only if there's enough in the bucket; if not, I reject with a 429 and a Retry-After computed from how long until enough tokens refill. I default to token bucket over a fixed window counter because it has no reset boundary — there's no moment where a client can double its effective rate by timing requests around a window edge — and I default to it over leaky bucket because it tolerates normal bursty client behavior instead of forcing every request onto a perfectly smooth output rate, which real traffic never actually has. The cost I'm accepting is that downstream capacity has to be provisioned for the full burst size, not just the average — that's the price of the tolerance. Once there's more than one gateway instance, a bucket kept in local memory per instance stops being correct, because each instance would enforce the full limit independently; I'd centralize the bucket state in Redis and do the check-and-deduct as a single atomic operation, which costs one extra network round trip per request in exchange for one shared, correct answer."

**A second trade-off variant — the "what about multiple instances" pushback:**
> "The naive move — read the token count, decide, write it back — works fine on one process and silently breaks the moment two requests for the same key can race, which in a multi-instance gateway is immediately. Two concurrent requests can both read 'one token left' before either writes, and both admit — the limit is effectively doubled under load, and it's the kind of bug that only shows up under real concurrency, never in a single-threaded test. The fix is to make the refill-check-deduct sequence one atomic operation server-side, not three separate calls: a Redis Lua script that does all three steps in a single round trip, or a purpose-built atomic command like RedisCell's `CL.THROTTLE`. That trades a small amount of latency — one network hop to a shared store instead of a local memory read — for a guarantee that holds no matter how many gateway instances are enforcing the same client's limit."

### ⚠️ Traps

- ❌ **Trap:** "I'll just count requests per minute per client and block once we hit the limit."
  ✅ **Reality:** That's a fixed window counter, and it has the boundary-doubling bug from §4 — a client can send the full quota at the end of one window and again at the start of the next, doubling the effective short-term rate right at the reset. Token bucket's continuous refill has no reset boundary to exploit.

- ❌ **Trap:** "Token bucket and leaky bucket are basically interchangeable — they both smooth out traffic."
  ✅ **Reality:** They enforce opposite guarantees. Token bucket lets a burst *through* up to `capacity`. Leaky bucket forces a strictly constant *output* rate and queues or drops anything above it — it never lets a burst pass. Picking one when the design actually needs the other's guarantee is a real design error, not a naming detail.

- ❌ **Trap:** "I'll keep the bucket in each gateway instance's local memory — it's simpler and avoids a network call."
  ✅ **Reality:** That's correct for exactly one instance. Behind a load balancer with N instances, each one independently enforces the full `capacity` and `rate`, so the client's real achievable ceiling is roughly `capacity × N`, not the configured value — a silent multiplier that only shows up once you scale past one node.

- ❌ **Trap:** "I'll check if tokens are available, then decrement them in a second call."
  ✅ **Reality:** Splitting the check and the deduct into two calls creates exactly the race §6 walks through — two concurrent requests can both pass the check before either commits its deduction. The check-and-deduct has to be one atomic operation, not two.

> **→ Next:** Can you combine what you've learned across sections, not just recall each one?

---

## 9. 🧪 Mastery Gate

> *Synthesis only. Each question must require combining two or more sections.*

1. **(§5 + §6)** A candidate implementation stores `tokens` as a plain integer and refills it with a background thread that runs once per second, adding `rate` tokens each tick, rather than using the lazy on-demand refill from §6. Using the build chain from §5 and the mechanism from §6, explain what precision this loses compared to on-demand lazy refill, and explain why a per-bucket background thread is also a scalability problem the O(1)-state argument from §5 was specifically trying to avoid.

2. **(§7 + §6, applied to a system not mentioned elsewhere in this doc)** You're designing rate limiting for a ride-hailing driver app's location-update endpoint: drivers' phones send a GPS ping every 4 seconds under normal conditions, but after a tunnel or dead zone, a phone can queue up several missed pings and flush them all at once on reconnect. Decide the bucket's capacity and rate, justify each choice against the decision tree in §7, and then explain — using the atomicity requirement from §6 — what would go wrong if this were implemented as a bucket held in the memory of whichever regional server happens to receive a given ping.

3. **(§4 + §6)** Explain precisely why token bucket's lazy refill formula (`elapsed × rate`, capped at capacity) has no equivalent of the fixed-window boundary bug from §4 — walk through what a client attempting the same "hit the boundary from both sides" strategy would actually experience against a token bucket, and explain why there is no boundary for them to target.

### Mastery criteria — tick only what you can demonstrate on demand

- [ ] Can state token bucket's parameters (capacity, refill rate, cost) from memory and explain precisely how each shapes burst tolerance versus sustained rate
- [ ] Can derive the lazy refill formula and explain why it has no window-boundary bug, contrasting it directly with a fixed window counter
- [ ] Can explain the concurrent check-and-deduct race under multiple gateway instances and name the atomic fix (Redis Lua script / GCRA-based command)
- [ ] Can describe the burst behavior and edge cases of the algorithm — cold-start bursts, idle-key cleanup, weighted request cost
- [ ] Can choose correctly between token bucket and a stated alternative (leaky bucket, fixed window) for a given scenario and justify the choice

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 10. 🔗 Connections & Sources

**Builds on:** **2.9 Backpressure Fundamentals**, which establishes the general principle of bounding load at a boundary — rate limiting is the specific caller-facing instance of that idea, rejecting or delaying at the edge rather than the callee signaling the caller to slow down. **11.7 API Gateway Patterns**, which establishes the gateway as the natural single choke point where cross-cutting concerns like this get enforced once, for every request, rather than duplicated per service.

**Enables:** **25.2 Leaky bucket algorithm**, the direct contrast — same problem, the opposite choice on whether bursts are ever allowed through. **25.4 Sliding window log and sliding window counter**, a tighter-precision alternative to token bucket's coarser aggregate-token accounting, at a higher memory cost. **25.5 Distributed rate limiting with Redis**, which takes this doc's §6/§7 distributed-and-concurrency material — the race condition, the atomic Lua-script fix — and builds the full multi-node Redis implementation on top of it.

**Tension with:** **1.4 Peak traffic estimation.** Token bucket's whole design point is tolerating bursts above the sustained rate, which means a system's real worst-case load isn't the average rate multiplied by client count — it's every active client's burst capacity landing at once. Capacity planning done only from the enforced average rate, without explicitly accounting for aggregate burst capacity across clients, will be underprovisioned the first time several clients burst simultaneously.

### 📚 Further reading

- [ ] **Stripe engineering blog — "Scaling your API with rate limiters"** — https://stripe.com/blog/rate-limiters — production GCRA implementation details and the reasoning behind choosing it over a plain token-counter bucket
- [ ] **Cloudflare blog — rate limiting at the edge** — https://blog.cloudflare.com/counting-things-a-lot-of-different-things/ — how GCRA-based limiting is made to work at billions-of-keys edge scale
- [ ] **Redis / RedisCell documentation — `CL.THROTTLE`** — https://github.com/brandur/redis-cell — the native atomic GCRA command referenced in §5/§6 as the alternative to a hand-written Lua script
- [ ] **NGINX docs — `ngx_http_limit_req_module`** — https://nginx.org/en/docs/http/ngx_http_limit_req_module.html — a real leaky-bucket-flavored default, useful as the concrete contrast case from §7's production table
- [ ] **"An alternative approach to rate limiting" (GCRA explainer)** — https://engineering.classdojo.com/2015/02/06/rolling-rate-limiter/ — walks the token-bucket-to-GCRA reformulation referenced throughout this doc

---

## 11. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
