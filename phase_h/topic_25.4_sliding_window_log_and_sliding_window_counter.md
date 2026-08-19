# 25.4 Sliding Window Log and Sliding Window Counter

> **Topic:** Topic 25 — Rate Limiting Systems
> **Phase:** H — System Archetypes
> **Depth Tier:** 🥇 T1 (Core) — budget ~3h
> **Prereqs:** 25.1 (Token Bucket Algorithm)
> **Date studied:** 2026-08-18

---

## 0. 🧭 The Question This Answers

25.1 fixed one half of the fixed-window problem and left the other half standing. Token bucket eliminates the boundary bug — there's no reset clock to double up around — but it does that by tracking an *aggregate* budget (how many tokens are banked), not a per-timestamp count. It can tell you "is there room right now," but it can never answer "exactly how many requests happened in the last 60 seconds," because it never recorded when any individual request occurred. Most of the time that's fine. Some of the time — a contractual quota, a billing boundary, an audit requirement — it isn't, and "close enough" is not an acceptable answer.

The tension this subtopic resolves is the same one every rate limiter in this topic keeps running into, now sharpened: how do you get a rolling-window guarantee — "no more than N requests in *any* W-second span, not just calendar-aligned ones" — and how exact does that guarantee actually need to be, given that exactness has a real memory cost attached to it. The naive fix — record every request's timestamp and count how many are still recent enough to matter — is exact by construction and has zero boundary bug, but its memory grows with how much traffic a client sends, forever, for as long as that client keeps sending traffic. The sliding window counter is the answer to "can I keep the no-boundary guarantee and give back the O(1) memory," at the cost of turning an exact count into a good estimate.

**The question:** *How do you enforce a rolling-window rate limit that has no reset boundary, and how do you choose between paying for exact precision and paying for constant memory?*

> **→ Next:** Before either algorithm, what exactly is still broken after token bucket — and what does the most obvious fix cost you?

---

## 1. 🎯 Interview Quick Reference Card

> *Not a summary — a live-recall tool, built for retrieval speed under interview pressure. If you need the reasoning behind anything here, that's what §2 (cheatsheet) and the rest of the doc are for.*

**The checklist — walk this on the whiteboard, in order:**

1. Name why fixed window still isn't enough: the boundary bug — a client can send a full quota at the end of one window and again at the start of the next
2. Name the fix at the definitional level: the window is `[now - W, now]`, recomputed on *every* request — there's no clock tick to reset on, so there's no boundary to exploit
3. Name the two variants and the axis they trade on: **sliding window log** (exact count, memory grows with request volume) vs. **sliding window counter** (O(1) memory, estimated count)
4. State the log mechanism: one Redis sorted set per client key, timestamp as score — on each request, prune everything older than `W` (`ZREMRANGEBYSCORE`), count what's left (`ZCARD`), and if under the limit, add this request (`ZADD`) and admit
5. State the counter mechanism: two fixed-window counters, `previous` and `current` — `estimated_count = previous × (1 − elapsed_fraction) + current`; if under the limit, increment `current` and admit
6. Name the concurrency requirement unprompted: prune-count-add (log) or read-weight-increment (counter) must be one atomic step per request — same Lua-script pattern as token bucket (25.1), or it races
7. Name the response contract: `429` + `Retry-After`, same `X-RateLimit-*` headers as 25.1/25.7

**Trigger → action:**

| Interviewer says | You do |
|---|---|
| "How would you fix the fixed-window boundary problem exactly?" | Redefine the window as `now - W` to `now`, recomputed every request — no clock-anchored reset, so no boundary |
| "How would you implement an exact rolling rate limit?" | Sliding window log: a Redis sorted set per client, timestamp as score; prune, count, add — atomically |
| "That sorted set will grow forever for a busy client, won't it?" | No — it's pruned every check, but its steady-state size is proportional to that client's request volume, not constant. Name the fix: sliding window counter, O(1) state |
| "Is the counter's estimate exact?" | No — state the assumption unprompted: it assumes requests are spread evenly across the previous window; a burst concentrated at one edge breaks the estimate |
| "How does this compare to token bucket?" | Token bucket trades precision for O(1) state via *aggregate* accounting; sliding window log keeps precision at the cost of memory; sliding window counter is the deliberate middle ground |

**Fast disambiguation — the pairs that get confused live:**

| Pair | The distinction |
|---|---|
| **Sliding window log vs. sliding window counter** | Log stores every timestamp still inside the window — exact, O(requests-in-window) memory. Counter stores two aggregate numbers — approximate, O(1) memory. Same no-boundary guarantee, opposite cost. |
| **Sliding window vs. fixed window** | Fixed window's boundary is a clock tick that resets. Sliding window's boundary is `now - W` — it never resets, it just moves forward with every check. |
| **Sliding window counter vs. token bucket** | Both are ~O(1) state, but they answer different questions. Counter estimates "how many requests happened in the last W seconds" (a rolling count). Token bucket tracks "how much capacity is currently banked" (an aggregate budget). Neither can answer the other's question. |
| **Pruning vs. expiry (log)** | Pruning (`ZREMRANGEBYSCORE`) removes entries that have aged out of the window on *every single check* — it's the enforcement mechanism. A `TTL` on the whole key is a separate, coarser safety net for keys that go fully idle, not how the count stays correct. |

**High-yield anchors:**

```
Log memory: one ZSET entry per request currently inside the window — for a
  limit of 100/min that's up to ~100 live entries per active key; for
  10k/hour, up to 10k. Proportional to volume, not O(1).
Counter formula: estimated_count = previous_window_count *
  (1 - elapsed_fraction_of_current_window) + current_window_count.
Redis ops for the log: ZADD (insert) / ZREMRANGEBYSCORE (prune) / ZCARD
  (count) — three ops, one atomic Lua script per request.
Counter's one assumption to name unprompted: requests are spread evenly
  across the previous window. A real burst at one edge breaks the estimate
  in a describable direction (§6).
HTTP contract: same as 25.1/25.7 — 429 Too Many Requests, Retry-After,
  X-RateLimit-Limit / -Remaining / -Reset.
```

**The script — say this close to verbatim:**

> "I'd fix the fixed-window boundary bug with a sliding window: instead of resetting on a clock tick, define the window as the last W seconds relative to right now, recomputed on every request, so there's no instant to double up around. For an exact, auditable count, I'd implement it as a sliding window log — one Redis sorted set per client, timestamp as the score — and on every request I prune anything older than W seconds, count what's left, and if that's under the limit I add the new timestamp and admit, otherwise I reject with a 429 and a Retry-After computed from when the oldest in-window entry ages out. The cost I'm accepting is memory: unlike token bucket's two numbers per key, the log holds one entry per request currently inside the window, so a high-volume client can mean thousands of entries per key, growing and shrinking continuously. If that memory cost is a real problem — high request volume, long windows — I'd switch to the sliding window counter instead: keep just two counters, the previous fixed window and the current one, and estimate the rolling count as a weighted blend of the two based on how far into the current window we are. That gets O(1) state back, at the cost of assuming requests are spread evenly across the previous window, which is usually close enough but is only an estimate, not an exact count."

> **If pushed on the memory cost specifically:** "That's exactly the sliding window log's real cost, and it's worth pricing before anyone asks: the sorted set holds one entry per request that's still inside the window, not two aggregate numbers like token bucket, so a client sending 500 requests a minute against a 60-second window can have up to 500 live entries at once, continuously churning as old ones age out and new ones get added. It never grows unbounded, because every check prunes entries older than the window before counting — but the steady-state size is proportional to that client's request volume, not a constant. If that's too much memory at the scale I'm operating — millions of keys, some with high per-key volume — I'd switch to the sliding window counter, which caps state at exactly two numbers per key regardless of volume, and accept its weighted-interpolation estimate instead of the log's exact count."

---

## 2. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*
>
> ⏭️ **First time through this topic?** Skip to §3 and come back here for revision.

```
§ 1  WHY IT EXISTS
Token bucket (25.1) kills the fixed-window boundary bug, but it tracks an
aggregate budget, not individual request timestamps — it can answer "is
there room right now" but never "exactly how many requests happened in
the last 60 seconds." Some designs need that exact rolling answer
(contractual quotas, billing, audits). The naive fix — record every
request's timestamp, count how many are still within the window — is
exact and has no boundary bug, but its memory grows with how much
traffic a client sends, forever, as long as traffic keeps coming.

§ 2  WHAT IT IS
WINDOW        The span [now - W, now], recomputed on every single
              request. Never resets on a clock tick — it just slides.
SLIDING LOG   One entry per request, timestamp as the value, kept in a
              structure that supports range queries (Redis sorted set).
SLIDING       Two fixed-window counters (previous, current) blended by a
COUNTER       weight based on how far into the current window "now" is.
PRUNE         Removing log entries older than W — happens on every
              check, not on a timer.

§ 3  THE MECHANISM
LOG            ZREMRANGEBYSCORE (prune stale) -> ZCARD (count) -> if
               count < limit: ZADD (insert) + ADMIT, else REJECT.
COUNTER        elapsed_fraction = time_into_current_window / W;
               estimate = prev_count*(1-elapsed_fraction) + curr_count;
               if estimate < limit: curr_count += 1, ADMIT, else REJECT.
ATOMICITY      Both variants need prune/read + count/weight + write to
               happen as ONE atomic step per request — split into
               separate calls, it races under concurrency (same failure
               mode as token bucket's check-and-deduct, 25.1).

§ 4  USE / AVOID
USE sliding window LOG when: the count must be exact and auditable
  (contractual "no more than N in any rolling W," billing, compliance),
  and per-key request volume is low enough that O(requests) memory is
  affordable.
USE sliding window COUNTER when: you want the no-boundary guarantee at
  O(1) memory and can accept a close estimate instead of an exact count.
AVOID the LOG when per-key volume is high and windows are long — the
  ZSET can grow to thousands of entries per busy key.
AVOID assuming the COUNTER is exact — it assumes uniform request
  distribution inside the previous window; a real burst at one edge
  breaks that assumption in a specific, describable direction (§6).

§ 5  LOG VS. COUNTER VS. TOKEN BUCKET
LOG           Exact count of requests in [now-W, now]. Memory scales
              with per-key request volume. Best when precision matters.
COUNTER       Estimated count via 2-number weighted interpolation. O(1)
              memory. Best when precision can be approximate.
TOKEN BUCKET  Answers a different question entirely — "how much budget
              is banked," not "how many requests in the last W seconds."
              Coarser, but cheapest and simplest when a burst/sustained
              pair is all you actually need (25.1).

§ 6  NUMBERS TO ANCHOR THE DISCUSSION
Log memory: ~1 entry per in-window request per key — 100/min limit ⇒ up
  to ~100 live entries per active key.
Counter formula: estimate = prev*(1-elapsed_fraction) + curr.
Redis ops (log): ZADD / ZREMRANGEBYSCORE / ZCARD, one atomic Lua script.
HTTP: 429 Too Many Requests · Retry-After (seconds) · X-RateLimit-Limit /
  -Remaining / -Reset (same contract as 25.1/25.7).

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "Fix the boundary bug exactly?"      → window = now-W to now, no reset
→ "Exact rolling count?"               → sliding window log, Redis ZSET
→ "Won't the ZSET grow forever?"       → pruned every check; switch to
                                          counter if volume makes it big
GOTCHA: Treating the sliding window counter's estimate as exact. It
  assumes requests are spread evenly across the previous window — a
  client that fires all its previous-window traffic in the last instant
  before the boundary makes the estimate wrong in a specific, provable
  direction (§6).
```

---

## 3. 🧠 The Mindmap

> *The picture to hold in your head while you study. Everything below hangs off this.*

```
                        ┌─────────────────────────┐
                        │   SLIDING WINDOW          │
                        └────────────┬────────────┘
                                     │
     ┌───────────────┬───────────────┼───────────────┬───────────────┐
     ▼                ▼               ▼               ▼               ▼
 ① THE FIX        ② LOG           ③ COUNTER       ④ THE TRADE     ⑤ WHERE IT
   (why no          VARIANT          VARIANT          -OFF AXIS       LIVES
   boundary)
 ├ window =       ├ Redis ZSET     ├ 2 fixed-      ├ log: exact,   ├ gateway /
 │ [now-W, now]    │ per key,       │  window        │  O(requests)   Redis (11.7)
 ├ recomputed      │ score=ts       │  counters      ├ counter:      ├ contrast:
 │ every request   ├ ZREMRANGE-     ├ weighted        │  O(1),         fixed window
 ├ no clock        │  BYSCORE:      │  blend by        │  estimate      (25.3),
 │ tick to          │  prune         │  elapsed        ├ neither has    token bucket
 │ reset on         ├ ZCARD: count  │  fraction        │  fixed         (25.1)
 │                 ├ ZADD: insert  ├ assumes         │  window's     ├ feeds: 25.5
 │                 │  on admit      │  uniform         │  boundary      distributed
 │                 │  only          │  distribution    │  bug           Redis design
 │                 │                │  in prev        ├ token bucket ├ 429 +
 │                 │                │  window          │  trades        Retry-After
 │                 │                │                  │  differently:  (25.1/25.7)
 │                 │                │                  │  aggregate,
 │                 │                │                  │  not
 │                 │                │                  │  timestamp
```

**How to read it:** ① is the foundation every other branch depends on — say it first, it's the single sentence that explains why *both* variants below have no boundary bug at all. ② and ③ are the two ways to actually build ①, and they are parallel choices, not a sequence — pick based on ④'s trade-off, don't default to one without naming why. ④ is the axis the whole subtopic hangs on: it's not "which is better," it's "what are you willing to pay for." ⑤ closes the answer by placing this back where it's enforced and what it contrasts against, the same way 25.1's mindmap did — don't skip it, it's how you signal you know this fits into a bigger picture, not just as an isolated algorithm.

---

## 4. 🔥 The Problem

Token bucket (25.1) solved the fixed-window boundary bug, but it did so by changing what's being tracked, not by making the tracking more precise. A bucket's `tokens` number is an aggregate — "how much budget is currently available" — and that number alone cannot answer a more specific question a real system sometimes has to answer exactly: how many requests, precisely, occurred in the last 60 seconds, right now, no approximation. If a contract says "no more than 1,000 calls in any rolling 24-hour window," or a billing system charges per request-over-quota, "the bucket has room" is not the same statement as "exactly 743 requests happened in the last 24 hours" — and the difference matters when money or compliance is on the line.

The instinctive fix is the most literal one possible: keep a log. For each client, record the timestamp of every request. To check whether a new request is allowed, discard any timestamps older than the window, count what's left, and admit only if that count is under the limit. This is not an approximation of anything — it is, by construction, an exact count of requests in `[now - W, now]`, recomputed fresh on every single check. Because the window boundary is defined relative to *now* rather than to a fixed clock tick, there is no instant at which the count resets to zero and a client can "reload" a full quota — the fixed-window boundary bug simply has no equivalent here, for the same structural reason token bucket has none: nothing ever resets.

But the log's exactness has a cost token bucket never had to pay: memory that scales with traffic. Token bucket's state is two numbers, full stop, regardless of how many requests a client sends. The log's state is one entry *per request currently inside the window* — a client sending 500 requests a minute against a 60-second window can have up to 500 live entries at any moment, continuously churning as old ones expire and new ones arrive. For a low-volume client this is nothing. For a high-volume client, or a long window (a daily quota logged at second-level granularity), it can mean thousands of entries per key, held in memory, for every active key, all the time. The insight that resolves this without giving back the no-boundary guarantee is to stop storing individual timestamps and instead approximate the same rolling count from two aggregate numbers — the counts of the current and immediately preceding fixed windows — blended by how far into the current window "now" happens to be. That's the sliding window counter: the log's no-boundary guarantee, at O(1) memory, in exchange for an estimate instead of an exact count.

**Before and after:**

```
  BEFORE — fixed window (25.1's baseline)      AFTER — sliding window (this doc)
  ──────────────────────────────────────       ─────────────────────────────────
   window = current calendar minute             window = [now - W, now],
   count resets to 0 at each boundary            recomputed on EVERY request
                                                  (no clock-tick reset, ever)

   ✗ boundary doubling: full quota at            ✓ no boundary to double around —
     :59 + full quota at :00 = 2x burst            the count is always relative
   ✗ token bucket (25.1) fixes the                 to right now
     boundary bug, but tracks only an             ✓ TWO implementations of the
     aggregate budget — never an exact              same no-boundary idea:
     "requests in the last W seconds"               LOG (exact, memory scales
     count                                            with volume) and COUNTER
                                                       (O(1), estimated)
```

**The boundary bug, made concrete — the same traffic, two views:**

```
   14:03 ..........................●●●●●●●●●●  |  ●●●●●●●●●●.......................... 14:05
                                    10 reqs @ :59 | 10 reqs @ :00
         WINDOW 1 (14:03:00–14:03:59)             |  WINDOW 2 (14:04:00–14:04:59)
                                             RESET HAPPENS HERE ▲

   Fixed window: each window independently reports "10/10 — within limit."
   Real traffic: any 1-second span straddling 14:03:59–14:04:00 saw all 20
   requests — double the configured limit — and the fixed-window counter
   never sees it, because it only ever looks inside one window at a time.

   A sliding window drawn over this SAME traffic has no reset to hide
   behind — its [now-1s, now] view sees all 20 requests and rejects.
```

### ✅ Checkpoint

1. A candidate argues that token bucket already "solves sliding windows" because it has no reset boundary, so a separate sliding window algorithm is redundant. Using the distinction drawn in the first paragraph, explain precisely what question token bucket's `tokens` number can and cannot answer, and why "no boundary bug" is not the same claim as "exact rolling count."

   > 💡 *If you hesitate, re-read the first paragraph — the sentence distinguishing "the bucket has room" from "exactly 743 requests happened in the last 24 hours."*

> **→ Next:** If a log gives you exactness and a counter gives you back O(1) memory, what exactly are the two mechanisms, and how do they both eliminate the boundary?

---

## 5. 💡 The Core Idea

**A sliding window rate limiter defines its window as `[now - W, now]`, recomputed on every request instead of reset on a clock tick, and then answers "how many requests fall inside it" either exactly — by keeping a timestamped log, at a memory cost proportional to request volume — or approximately — by blending two adjacent fixed-window counters into an O(1) estimate — making the choice between them a direct trade of precision against memory, not a trade against correctness.**

**Visual required:** build-chain diagram.

```
 [THE WINDOW      ──▶ [LOG: EXACT VIA   ──▶ [COUNTER: O(1)  ──▶ [THE CHOICE IS
  FOLLOWS "NOW",         PER-REQUEST          VIA WEIGHTED         PRECISION VS.
  NOT A CLOCK]           TIMESTAMPS]          INTERPOLATION]       MEMORY, NOT A
   because                because                because             BUG FIX]
   the boundary            answering               the log's            because both
   must move with          "how many in             per-request           already fixed
   every check to           [now-W,now]"             cost is               the boundary —
   have no reset             exactly needs            unacceptable          what's left is
   instant to                 to know every             at high              purely how
   exploit                     request's                 volume, so           exact the
                                 timestamp                 approximate           count needs
                                                             the same             to be
                                                             answer with
                                                             2 numbers
```

### The Window Follows "Now," Not a Clock

Everything starts from redefining what "the window" even means. A fixed window is anchored to the clock — minute 14:03, then minute 14:04 — and resets the instant the clock ticks over. A sliding window has no clock anchor at all: at the moment any request arrives, the window is simply `[now - W, now]`, recomputed fresh for that exact instant. There is no reset event, because there is nothing to reset — the window boundary is a moving target that always trails "now" by exactly `W` seconds.

**Watch the window slide — three snapshots of the same 8 requests, W = 60s:**

```
 FRAME 1 — now = 60s.  window = [0, 60]
   ●────●───●─────●───●───────●──●──●
  12   18  25     33  41     52 57 60(now)
  └──────────────── window: [0, 60] ────────────────┘
  all 8 requests inside → count = 8

 FRAME 2 — now = 75s (+15s).  window = [15, 75]
   ○────●───●─────●───●───────●──●──●
  12   18  25     33  41     52 57 60        75(now)
       └──────────────── window: [15, 75] ────────────────┘
  ●@12 aged out (○) — nothing reset, it just fell out of range → count = 7

 FRAME 3 — now = 95s (+35s).  window = [35, 95]
   ○────○───○─────●───●───────●──●──●
  12   18  25     33  41     52 57 60             95(now)
                   └──────────────── window: [35, 95] ────────────────┘
  3 more age out one at a time as the window keeps trailing "now" → count = 4
```

This single redefinition is what removes the fixed-window boundary bug (§4) by construction: a client trying to send a full quota "right before the reset" and another full quota "right after" finds there is no reset to time an attack around, only a boundary that has already moved by the time the second burst arrives.

### Sliding Window Log: Exact via Per-Request Timestamps

Given that the window is now defined relative to *now*, the most literal way to answer "how many requests are inside it" is to know every request's exact timestamp and check each one against the boundary directly. That's the sliding window log: for each client key, keep every request's timestamp in a structure that supports efficient range queries — a Redis sorted set, timestamp as the score. On each check: discard entries older than `now - W` (they're no longer inside the window by definition), count what remains, and if that count is under the limit, record this request's timestamp too and admit it.

**The ZSET itself, visualized as a timeline:**

```
   ZSET key = "ratelimit:client:123"   (score = request timestamp, seconds)

   ●35.0   ●38.5   ●42.1   ●50.2   ●55.9   ●58.0        now = 60.0, W = 20s
     └───┬───┘                                           prune cutoff = now-W = 40.0
         pruned by ZREMRANGEBYSCORE (score < 40.0) — 2 removed
                    └────────── kept: 4 entries → ZCARD = 4 ──────────┘
                    new request arrives at 60.0 → ZADD → count becomes 5
```

Because every timestamp is real and every comparison is exact, the resulting count is not an approximation of anything — it is, precisely, the number of requests that occurred in the last `W` seconds, which is exactly what §4 established token bucket cannot answer.

### Sliding Window Counter: O(1) via Weighted Interpolation

The log's exactness comes from tracking one entry per request, and §4 already named the cost that creates: memory proportional to how much traffic a client sends within the window. The sliding window counter keeps the same no-boundary definition from the first concept block but answers the "how many" question with only two numbers instead of one per request: a count for the *previous* fixed window and a count for the *current* one. The estimate is a weighted blend — `estimate = previous_count × (1 - elapsed_fraction) + current_count`, where `elapsed_fraction` is how far "now" is into the current fixed window. If the estimate is under the limit, the current window's counter increments and the request is admitted. This assumes requests are spread evenly across the previous window — which is usually a reasonable approximation, but is an assumption, not a fact derived from any individual timestamp, because no individual timestamp was ever recorded.

### The Choice Is Precision vs. Memory, Not a Correctness Fix

Because both variants already solve the boundary problem the same way — by defining the window relative to now — choosing between them is never about fixing a bug. It's a direct trade: the log pays memory proportional to request volume to get an exact count; the counter pays approximation error to get O(1) memory. Neither is "more correct" than the other in the way sliding window is more correct than fixed window — they are two different, valid answers to "how precisely do I need to know the rolling count," and the right choice depends entirely on what the number is being used for downstream (§7).

### ✅ Checkpoint

1. Using only the definition from "The Window Follows 'Now,' Not a Clock," explain why a sliding window — either variant — cannot exhibit the "full quota at the end of one window, full quota at the start of the next" attack that fixed window is vulnerable to, even though the sliding window counter is only an estimate.

   > 💡 *If you hesitate, re-read the first concept block — the sentence about the boundary being "a moving target that always trails 'now' by exactly W seconds."*

2. Trace the link from "Sliding Window Log" into "Sliding Window Counter": explain precisely what specific cost of the log the counter is designed to eliminate, and what it gives up in exchange to eliminate it.

   > 💡 *If you hesitate, re-read the second concept block's cost claim and the third concept block's opening sentence, which names exactly what's kept and what's changed.*

> **→ Next:** You know the shape of both mechanisms. What actually happens, step by step, on a real request — for each variant — and what breaks?

---

## 6. ⚙️ How It Actually Works

**Happy path — sliding window log, one request end to end:**

1. A request arrives tagged with a rate-limit key — API key, user ID, or IP, same convention as 25.1.
2. The limiter identifies that key's sorted set (creating an empty one if this is the first request ever seen for this key).
3. **Prune:** remove every entry with a score (timestamp) older than `now - W` — `ZREMRANGEBYSCORE key -inf (now-W)`. These requests are no longer inside the window by definition and must not count.
4. **Count:** get the number of remaining entries — `ZCARD key`.
5. If the count is `< limit`: **add** this request's timestamp as a new entry (`ZADD key now request_id`) and admit. If the count is `≥ limit`: do **not** add, reject with `429`, and compute `Retry-After` from the *oldest* remaining entry's timestamp — the request is allowed again once that entry ages out of the window.

**Happy path — sliding window counter, one request end to end:**

1. A request arrives tagged with the same kind of key.
2. The limiter loads (or initializes) two counters for that key: `previous_window_count` and `current_window_count`, plus which fixed window is currently "current."
3. If wall-clock time has crossed into a new fixed window since the last check, roll the counters forward: the old `current` becomes the new `previous`, and a fresh `current` starts at 0.
4. Compute `elapsed_fraction = (now - current_window_start) / W`, then `estimate = previous_window_count × (1 - elapsed_fraction) + current_window_count`.
5. If `estimate < limit`: increment `current_window_count` and admit. If `estimate ≥ limit`: reject with `429` and a `Retry-After` derived from how much `elapsed_fraction` needs to grow (or `current_window_count` needs to be exceeded further into the next window) before the estimate drops back under the limit.

> 🗺️ **Mental model — the log is a security camera with a rolling buffer; the counter is a water-meter with two dials.** The log never erases footage on a clock tick — it continuously discards anything older than the retention window and can always answer "exactly how many events in the last W seconds" by counting frames. The counter, instead, only ever reads two meter dials — last billing period's total and this period's total-so-far — and blends them by how far into this period you are, without ever knowing the exact moment any individual reading happened.
> *Where it breaks down:* the camera analogy hides the log's real cost — a busier scene means proportionally more footage to store, which is exactly the memory-scaling problem token bucket never has. And the water-meter analogy hides the counter's real assumption — it silently assumes usage was smooth across the previous period, which is invisible in the dial reading itself and is exactly the failure mode below.

**Failure & edge cases:**

- **The log's memory growth is real, just bounded per-check.** A busy key's sorted set holds one entry per request currently inside the window — it never grows *unboundedly*, because every check prunes anything stale before counting, but its steady-state size tracks that client's request volume directly. A key sending 10,000 requests/hour against a 1-hour window can steady-state at up to 10,000 live entries. This is the direct, unavoidable price of exactness, not a bug to be fixed.
- **The counter's uniform-distribution assumption can be provably wrong.** It's accurate exactly when traffic is smooth, and wrong in a specific, describable direction when it isn't — see the two cases below.
- **Both variants need one atomic operation per request, same as token bucket (25.1).** Log: prune + count + add must happen as one atomic step (a Redis Lua script covering all three `ZSET` operations), or two concurrent requests can both count a pre-prune, pre-add state and both admit past the limit. Counter: read-both-counters + compute-estimate + increment must be equally atomic, for the identical reason.
- **Clock source consistency matters for both**, exactly as it did for token bucket — the log's `now - W` cutoff and the counter's `elapsed_fraction` both depend on a consistent clock across whatever process is doing the check.
- **Idle-key cleanup differs by variant.** A log's sorted set for an idle key naturally shrinks to zero live entries as its old timestamps age past pruning — but the empty key itself should still be `TTL`'d so it doesn't linger forever. A counter's two numbers need the same idle-key `TTL`, since neither variant benefits from holding state for a key nobody is using.

**The counter's estimate, worked both directions (the SAME near-boundary burst, checked at two different times):**

```
 CASE A — burst near the boundary, checked SHORTLY AFTER crossing (elapsed_fraction ≈ 0.05)

  PREV [..........................●●●●●●●●●●(100, right before the boundary)]│CURR[.......(0 so far)]
                                                                        boundary▲   elapsed_fraction ≈ 0.05

  estimate = 100×(1 − 0.05) + 0 = 95   →  a true log check would also show ≈100 (the burst is still
                                            almost entirely inside the true window) — close enough,
                                            correctly flags it

 CASE B — the SAME burst, checked much LATER into the current window (elapsed_fraction ≈ 0.8)

  PREV [..........................●●●●●●●●●●(100, same burst — now "8/10ths old")]│CURR[..(0 so far)]
                                                                        boundary▲          elapsed_fraction ≈ 0.8

  estimate = 100×(1 − 0.8) + 0 = 20    →  but a true log check would STILL show ≈100 (the burst is
                                            recent enough to remain fully inside the rolling window) —
                                            the estimate UNDER-counts by 80
```

The lesson: the error isn't really about *where* within the previous window a burst happened — it's about *how much time has passed since the boundary* when you check. The same burst gets a nearly-correct weight right after the boundary, and a badly-wrong (too-low) weight the longer you wait into the current window, because the formula discounts purely by elapsed time, not by whether the burst is still genuinely recent enough to matter. (The mirror-image error also exists: a burst concentrated *early* in the previous window — already aged fully out of the true window by the time you check late — still gets partial credit from the formula, causing an *over*-count instead.)

**Mechanism flow, end to end (sliding window log):**

```
① REQUEST ARRIVES        ② PRUNE (ZREMRANGE-      ③ COUNT (ZCARD)        ④ CHECK + ADD (atomic)
  key = API key /          BYSCORE, remove          count = remaining      if count < limit:
  user / IP        ──▶     entries older     ──▶    entries in the  ──▶     ZADD now → ADMIT
                            than now - W              sorted set            else:
                                                                              leave as-is
                                                                              → REJECT (429 +
                                                                                Retry-After from
                                                                                oldest entry)
```

**Structural diagram — the counter's two fixed windows and the weight (timeline):**

```
        PREVIOUS WINDOW                  CURRENT WINDOW
   ┌───────────────────────┐  ┌──────────────●───────────────┐
   │   previous_count = 80  │  │ current_count = 20            │
   └───────────────────────┘  └──────────────┬───────────────┘
                                              │
                                              ▼  "now" sits here —
                                     elapsed_fraction ≈ 0.3 into
                                     the current window

   estimate = 80 * (1 - 0.3) + 20 = 76         (≈ what a log would show
                                                  if requests were spread
                                                  evenly across the
                                                  previous window)
```

### ✅ Checkpoint

1. Walk through exactly what a naive, non-atomic sliding window log implementation does when two requests for the same key arrive close enough together that both run `ZCARD` before either runs `ZADD` — assume the count is one under the limit for both. Name precisely which three operations from the happy-path list have to become one atomic step to prevent this.

   > 💡 *If you hesitate, re-read "Both variants need one atomic operation per request" and steps 3–5 of the log's happy path.*

Two requests for the same key arrive close enough together that both run
ZCARD before either runs ZADD. Assume the count is one under the limit
(count = limit - 1) for both. Each request independently: prunes stale
entries, runs ZCARD and sees count = limit - 1, concludes "I'm under the
limit," and proceeds to ZADD its own timestamp. Because neither request
saw the other's ZADD before making its decision, both add and both admit
— the key now has limit + 1 entries, one over budget, and the bucket has
silently over-admitted.

The three operations that must become one atomic step are: prune
(ZREMRANGEBYSCORE), count (ZCARD), and the conditional add (ZADD) — steps
3-5 of the happy path. Wrapping all three in a single Redis Lua script
(or an equivalent atomic command) means no other request can observe an
in-between state — the read, the decision, and the write all happen as
one indivisible unit, closing the race.

2. Using the concrete numeric example in "The counter's uniform-distribution assumption can be provably wrong," explain in your own words why the sliding window counter's estimate can be *roughly accurate* for a burst that happened right at a window boundary when checked shortly after, but can *severely under-count* that same burst when checked much later into the current window.

   > 💡 *If you hesitate, re-read the "counter's estimate, worked both directions" diagram — Case A and Case B walk through the same burst checked at two different times.*

> **→ Next:** You can run both mechanisms correctly. In a real design, which one do you actually reach for, and what does that choice cost against token bucket and fixed window?

---

## 7. ⚖️ The Decision — When, and What It Costs

The baseline question isn't "sliding window or not" — if you've already ruled out fixed window's boundary bug, you're choosing a sliding-window shape by default. The real decisions are: which variant, and whether a sliding window is even the right tool compared to token bucket's coarser but cheaper aggregate accounting.

**The guarantee needs to be exact — auditable, contractual, or billing-grade.** This is the sliding window log's case: a customer contract that says "no more than 1,000 calls in any rolling 24-hour window," a billing system that charges per request over quota, or any context where "approximately correct" isn't a defensible engineering answer. You get a count that is, by construction, exactly right, at the cost of memory that scales with that client's request volume inside the window.

**An approximate rolling guarantee is genuinely fine, and per-key volume or window length makes the log's memory a real problem.** This is the sliding window counter's case — the default once you've decided you need *some* rolling-window precision beyond what token bucket offers, but don't need it exact. Two numbers per key, regardless of volume, at the cost of an estimate that assumes uniform distribution within the previous window and is measurably wrong when that assumption fails (§6).

**A burst/sustained pair is actually all the design needs — not a rolling count at all.** If nobody downstream cares about "exactly how many requests in the last W seconds" and the real requirement is closer to "tolerate normal bursts, bound the long-run average," token bucket (25.1) is simpler, cheaper, and answers the actual question being asked. Reaching for a sliding window here is solving a more precise problem than the one that exists.

**How much per-key volume are you actually expecting, and for how long a window?** This is the concrete sizing question that decides log vs. counter once "exact" is established as a requirement. A window of a few seconds to a few minutes at moderate volume keeps the log's memory trivial. A daily or weekly window at high volume can mean tens of thousands of entries per key — at that point, either accept the memory cost because exactness is genuinely non-negotiable, or push back on whether the requirement really demands per-request exactness rather than a periodic reconciliation job that audits the true count out-of-band.

**Decision tree:**

```
        Does the guarantee need to be EXACT — provably correct,
        not just a close estimate (contract, billing, audit)?
                              │
              ┌──────yes──────┴──────no, an estimate is fine───────┐
              ▼                                                     ▼
   Is per-key request volume low enough              Sliding window counter.
   that O(requests-in-window) memory                 O(1) state, no boundary
   is affordable (tens to low hundreds,               bug, accept the weighted-
   not thousands+, per active key)?                   interpolation estimate.
              │
   ┌──yes──────┴──────no──────────────────┐
   ▼                                       ▼
   Sliding window log.               Precision you need doesn't fit
   Redis ZSET, exact count,          your traffic. Fall back to the
   atomic prune-count-add.           counter and accept its estimate,
                                     or push back on whether "exact"
                                     is really required — or reach
                                     for token bucket if a rolling
                                     count was never the real need.
```

**Per-key memory over time, steady busy traffic (limit=100, W=60s):**

```
   entries
   100 ┤     LOG — sawtooth, tracks in-window volume
       │   ╱╲    ╱╲    ╱╲    ╱╲    ╱╲
       │  ╱  ╲  ╱  ╲  ╱  ╲  ╱  ╲  ╱  ╲
     0 ┤─┴────┴┴────┴┴────┴┴────┴┴────┴──▶ time

     2 ┤───────────────────────────────────  COUNTER — flat, always 2 numbers
       │                                      (TOKEN BUCKET is flat here too — 25.1)
     0 ┤───────────────────────────────────▶ time
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Sliding window log gives an exact, auditable count** of requests in any rolling window — the count is derived from real timestamps, not an estimate | Memory scales with per-key request volume inside the window — a busy key can mean thousands of live sorted-set entries, unlike token bucket's fixed two numbers |
| **Sliding window counter keeps the no-boundary guarantee at O(1) state** — two numbers per key, same cost class as token bucket | The count is an *estimate* that assumes uniform request distribution within the previous window — provably wrong in a specific, describable direction when that assumption fails (§6) |
| **Neither variant has the fixed-window boundary bug**, because both define the window relative to "now" instead of a clock tick that resets | Both need atomic prune/read + count/weight + write per request, same as token bucket's check-and-deduct — a naive split into separate calls races identically |
| **The log's entries are individually inspectable** — you can audit exactly which requests counted, when, for compliance or debugging | More operations per request than token bucket's single read-compute-write — prune, count, and conditionally insert are three ZSET operations, not one |

### In production

| System | How it applies | The nuance |
|--------|----------------|------------|
| **Redis's own documented rate-limiting pattern** | The canonical sliding window log implementation — a sorted set per client key, `ZADD`/`ZREMRANGEBYSCORE`/`ZCARD` — is Redis's own recommended pattern for exact per-key rate limiting | Widely copied directly into application code because the three-operation shape maps almost one-to-one onto the algorithm itself, with the atomicity requirement usually solved via a Lua script |
| **Cloudflare's original Rate Limiting Rules product (pre-GCRA)** | Publicly documented as approximating a rolling window using a weighted blend of the current and previous fixed window counts — the sliding window counter, by name | Chosen specifically to avoid the log's per-request memory cost at Cloudflare's edge scale, before later products moved to GCRA (25.1) for an even lighter-weight, non-window-based approach |
| **Kong Gateway's rate-limiting-advanced plugin** | Offers a sliding-window mode as a configurable alternative to the plugin's default fixed-window counting, specifically to remove the edge-of-window burst behavior | Positioned as the middle ground between "simple but has the boundary bug" (fixed) and "exact but heavier" (a full log), matching this doc's counter variant |

### ✅ Checkpoint

1. A fintech company needs to enforce "no customer may submit more than 50 payment requests in any rolling 60-second window," and their compliance team requires the count to be exactly reproducible for any past 60-second span if a dispute arises. An engineer proposes the sliding window counter because "it's cheaper and close enough." Using the decision tree, say whether you'd approve this design, name specifically what breaks the compliance requirement if you do, and state what you'd build instead.

   > 💡 *If you hesitate, re-read the first boundary condition ("The guarantee needs to be exact") and the first branch of the decision tree.*

I'd disapprove of the sliding window counter here. It only ever tracks
two aggregate numbers — previous_window_count and current_window_count —
and blends them into a weighted estimate. That estimate is not precise
enough for this requirement: the compliance team needs an exact,
reproducible count for any past 60-second span, and an estimate that
assumes uniform distribution within the previous window cannot give
that, by construction — there's no way to reconstruct "was it 50 or 52"
from two blended totals after the fact.

Using the decision tree: this requirement needs to be exact (contract/
compliance-grade), which rules out the counter immediately. The second
gate — is per-key volume low enough that O(requests-in-window) memory is
affordable — is trivially yes here: a limit of 50 requests per 60-second
window means the sorted set never holds more than 50 live entries per
customer key, which is nothing.

So I'd build the sliding window log instead: one Redis sorted set per
customer, timestamp as the score. On each request, prune anything older
than 60 seconds, count what's left, and if under 50, add this request's
timestamp and admit. Because every entry is a real, individually
inspectable timestamp, compliance can reconstruct the exact count for
any disputed 60-second span directly from the stored data — the log
isn't just enforcing the limit, it's also the audit trail.

> **→ Next:** Can you deliver this cleanly under interview pressure, including when the interviewer pushes on the log's memory cost specifically?

---

## 8. 🎯 In the Interview

**When an interviewer asks / says:**
- "How would you fix the fixed-window boundary problem exactly?"
- "Can you enforce an exact rolling limit — no more than N requests in any W-second window?"
- "That sorted set is going to grow forever for a busy client, isn't it?"
- "How does this compare to the token bucket you mentioned earlier?"

**Where this surfaces in the design flow:** right after you've named the fixed-window boundary bug (or the interviewer names it for you) and they push for a fix that's actually precise, rather than just "no bug." It comes back a second time as a memory-cost pushback the moment you describe the log — expect it, and price it before being asked.

**What you say / do — delivered in this fixed order:**

| Step | Content |
|---|---|
| **1. Name the choice** | "Sliding window — the window is `[now - W, now]`, recomputed on every request, not reset on a clock tick." Then name the variant: **log** (exact) or **counter** (approximate) — state which, explicitly, don't leave it implicit. |
| **2. Give the mechanism reason** | Log: prune (`ZREMRANGEBYSCORE`) → count (`ZCARD`) → add (`ZADD`), one atomic step. Counter: `estimate = previous × (1 − elapsed_fraction) + current`, one atomic step. |
| **3. Price it unprompted** | Log: memory scales with per-key request volume, not O(1) like token bucket. Counter: it's an *estimate* — assumes uniform request distribution in the previous window. |
| **4. Name the switch condition** | Log → counter once per-key volume or window length makes the sorted set too large. Counter → token bucket if a rolling count was never actually needed, only a burst/sustained pair. |

**The trade-off statement (memorize this pattern):**
> "I'd fix the fixed-window boundary bug with a sliding window: instead of resetting on a clock tick, define the window as the last W seconds relative to right now, recomputed on every request, so there's no instant to double up around. For an exact, auditable count, I'd implement it as a sliding window log — one Redis sorted set per client, timestamp as the score — and on every request I prune anything older than W seconds, count what's left, and if that's under the limit I add the new timestamp and admit, otherwise I reject with a 429 and a Retry-After computed from when the oldest in-window entry ages out. The cost I'm accepting is memory: unlike token bucket's two numbers per key, the log holds one entry per request currently inside the window, so a high-volume client can mean thousands of entries per key, growing and shrinking continuously. If that memory cost is a real problem — high request volume, long windows — I'd switch to the sliding window counter instead: keep just two counters, the previous fixed window and the current one, and estimate the rolling count as a weighted blend of the two based on how far into the current window we are. That gets O(1) state back, at the cost of assuming requests are spread evenly across the previous window, which is usually close enough but is only an estimate, not an exact count."

**A second trade-off variant — the "won't that sorted set grow forever" pushback:**
> "That's exactly the sliding window log's real cost, and it's worth pricing before anyone asks: the sorted set holds one entry per request that's still inside the window, not two aggregate numbers like token bucket, so a client sending 500 requests a minute against a 60-second window can have up to 500 live entries at once, continuously churning as old ones age out and new ones get added. It never grows unbounded, because every check prunes entries older than the window before counting — but the steady-state size is proportional to that client's request volume, not a constant. If that's too much memory at the scale I'm operating — millions of keys, some with high per-key volume — I'd switch to the sliding window counter, which caps state at exactly two numbers per key regardless of volume, and accept its weighted-interpolation estimate instead of the log's exact count."

### ⚠️ Traps

- ❌ **Trap:** "I'll just shrink the fixed window to a few seconds — that fixes the boundary bug."
  ✅ **Reality:** It only shrinks the boundary bug's absolute size — a client can still double its effective rate right at any reset instant, however small the window. The fix isn't a smaller window, it's a window that doesn't reset at all (§4/§5).

- ❌ **Trap:** "Sliding window log and sliding window counter are basically the same algorithm with different names."
  ✅ **Reality:** They're two genuinely different implementations of the same no-boundary definition — one is exact and stores every timestamp, the other is an O(1) estimate built from two aggregate counters. Conflating them under interview pressure loses the "which one, and why" judgment that's the actual point of this subtopic.

- ❌ **Trap:** "I'll store every request forever so I always have exact history."
  ✅ **Reality:** The log has to prune on every check (`ZREMRANGEBYSCORE`), not just insert — without continuous pruning, the sorted set grows unboundedly instead of staying proportional to current in-window volume, which is a real bug, not just an inefficiency.

- ❌ **Trap:** "The counter's estimate is basically exact, it's just weighted math."
  ✅ **Reality:** It assumes requests are spread evenly across the previous window. A real burst concentrated at one edge of that window breaks the estimate in a specific, provable direction (§6) — it's an approximation with a named failure mode, not a rounding detail.

> **→ Next:** Can you combine what you've learned across sections, not just recall each one?

---

## 9. 🧪 Mastery Gate

> *Synthesis only. Each question must require combining two or more sections.*

1. **(§5 + §6)** A candidate implementation of the sliding window log inserts new timestamps with `ZADD` on every request but never runs `ZREMRANGEBYSCORE`. Using the build chain from §5 and the failure modes from §6, explain precisely what breaks, and why every individual admit/reject decision can still look "correct" in isolation even as the system degrades.

2. **(§7 + §6, applied to a system not mentioned elsewhere in this doc)** You're designing rate limiting for a hospital's medication-dispensing API: nurses' terminals can request at most 20 dispense authorizations per patient in any rolling 12-hour window, and a regulatory audit must be able to reconstruct the exact authorization count for any past 12-hour span for any patient. Decide log vs. counter using the decision tree in §7, justify the choice against the atomicity requirement and memory characteristics from §6, and state one concrete reason per-key volume here is unlikely to make your choice impractical.

3. **(§4 + §5)** Explain precisely, using the definition from §5's first concept block, why neither sliding window variant can be attacked the way a fixed window can — walk through what a client attempting the fixed-window "hit the boundary from both sides" strategy from §4 would actually experience against a sliding window log, and separately against a sliding window counter.

### Mastery criteria — tick only what you can demonstrate on demand

- [ ] Can explain why token bucket's aggregate accounting cannot answer an exact rolling-window count, and state precisely what question a sliding window answers that token bucket cannot
- [ ] Can describe the sliding window log mechanism using Redis sorted sets — the data structure, the prune/count/insert operations, and why they must be atomic
- [ ] Can derive the sliding window counter's weighted-interpolation formula and explain the uniform-distribution assumption it depends on, including a concrete case where that assumption breaks
- [ ] Can explain why neither sliding window variant exhibits the fixed-window boundary bug, tracing the argument back to the window's definition relative to "now"
- [ ] Can choose correctly between sliding window log, sliding window counter, and token bucket for a given scenario, justified by precision needs, memory cost, and per-key volume

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 10. 🔗 Connections & Sources

**Builds on:** **25.1 Token Bucket Algorithm**, which establishes the rate-limiting vocabulary this doc reuses directly — per-client key, the `429`/`Retry-After` response contract, and the atomic check-and-deduct pattern this doc's prune-count-add and read-weight-increment operations both mirror. It's also the direct contrast this doc is built against: token bucket eliminates the boundary bug via *aggregate* accounting; this doc eliminates it via a *rolling, per-timestamp-or-estimated* definition instead.

**Enables:** **25.5 Distributed rate limiting with Redis**, which takes this doc's ZSET-based sliding window log pattern and its atomicity requirement and builds the full multi-node Redis implementation on top of it, the same way it will for token bucket's distributed case. **25.6 Rate limiting at CDN, gateway, and service layers**, which needs an algorithm choice per layer, and this doc's precision-vs-memory trade-off is one of the concrete axes that choice turns on.

**Tension with:** **25.1 Token Bucket Algorithm.** Both eliminate the fixed-window boundary bug, but by opposite means: token bucket buys O(1) state by giving up exact per-timestamp precision entirely — it never answers "how many requests in the last W seconds," only "is there budget now." Sliding window log buys exact precision by giving up O(1) state. Neither is strictly better; picking between them (and between the counter as a middle ground) is a genuine, scenario-dependent trade, not a strict upgrade path.

### 📚 Further reading

- [ ] **Cloudflare blog — "Counting things: a lot of different ways to count things at Cloudflare"** — https://blog.cloudflare.com/counting-things-a-lot-of-different-things/ — covers the weighted current/previous-window approximation this doc's counter variant is built on, as historically used at Cloudflare's edge
- [ ] **Redis docs — Sorted sets** — https://redis.io/docs/latest/develop/data-types/sorted-sets/ — the data structure the sliding window log is built on (`ZADD`, `ZREMRANGEBYSCORE`, `ZCARD`)
- [ ] **"An alternative approach to rate limiting"** — https://engineering.classdojo.com/2015/02/06/rolling-rate-limiter/ — walks a Redis-sorted-set rolling rate limiter implementation, the direct blueprint for §6's log mechanism
- [ ] **Kong Gateway docs — rate-limiting-advanced plugin** — https://docs.konghq.com/hub/kong-inc/rate-limiting-advanced/ — documents the sliding-window algorithm option referenced in §7's production table
- [ ] **System Design Primer — Rate limiter section** — https://github.com/donnemartin/system-design-primer — a side-by-side comparison of fixed window, sliding window log, and sliding window counter, useful as a fast cross-check of this doc's trade-offs

---

## 11. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
