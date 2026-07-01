# 6.2 Pull CDN vs. Push CDN

> **Topic:** Topic 6 — CDN
> **Phase:** B — Scalability Branch
> **Date studied:** 2026-06-29

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

Pull CDN and Push CDN are the two fundamental models for getting content onto edge servers. The central tension is **control vs. automation**: Pull CDN is origin-driven on demand (the edge fetches on first miss), while Push CDN is operator-driven upfront (you explicitly upload content to all PoPs before any request arrives). Mastering this topic means understanding which model fits your content's update frequency, predictability, and volume — and being able to justify the choice in a system design without hand-waving.

### 🎯 What to Focus On

**1. The pull cache fill flow** — On a cache miss, the edge server fetches from origin and caches the response for subsequent requests. Understand the cold-start implication: the first user to request a piece of content from a PoP will get origin latency. This is the core UX risk of Pull CDN.

**2. The push pre-load flow** — You control what lives at the edge. Files are uploaded proactively, so the first request is always a cache hit. Understand that you own the entire lifecycle: upload, invalidate, and clean up. Operational burden is entirely on you.

**3. TTL and invalidation in Pull CDN** — TTL determines how long edges serve stale content. Short TTL = fresh content but high origin load; long TTL = low origin load but stale serving window. Know how to break this tension with versioned URLs or manual purge APIs.

**4. Storage and cost tradeoffs** — Push CDN can pre-populate every PoP (~200–500 globally) with every file you push, regardless of whether that PoP has any users. At scale this is expensive and wasteful. Pull CDN only stores what is actually requested at each PoP — organic, demand-driven population.

**5. When each model fits** — Pull = dynamic or frequently updated content with unpredictable demand geography; Push = large static assets (e.g., software binaries, game installs) with predictable global demand and infrequent updates. Many real systems use a hybrid.

---

## 1. 🎯 Goal of This Subtopic

> *Why are you studying this? What should you be able to do after this session?*

Be able to classify any CDN content delivery scenario as Pull, Push, or hybrid and justify the choice using concrete criteria: update frequency, file size, demand predictability, and latency requirements. You should also be able to explain the TTL/invalidation challenge specific to Pull CDN and the operational overhead specific to Push CDN — and state these trade-offs under interview pressure without hesitation.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can explain the Pull CDN request flow — including cold-start behavior — without notes in under 60 seconds
- [ ] Can explain the Push CDN upload and invalidation lifecycle and name the operator responsibilities
- [ ] Can select Pull vs. Push for a given scenario (e.g., social media avatars vs. a 4GB game client) and justify with concrete reasoning
- [ ] Can describe two invalidation strategies for Pull CDN (TTL expiry vs. versioned URLs vs. API purge) and state their trade-offs
- [ ] Can identify when a hybrid model is appropriate and describe the content split between Pull and Push

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] **Cloudflare Learning — "What is a CDN? Pull vs Push"** — [developers.cloudflare.com](https://developers.cloudflare.com/cache/) — covers pull model in detail with TTL mechanics
- [ ] **AWS CloudFront Developer Guide — Cache Behavior and Invalidation** — [docs.aws.amazon.com/cloudfront](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html) — real-world Pull CDN configuration
- [ ] **ByteByteGo "How does CDN work?"** — [blog.bytebytego.com](https://blog.bytebytego.com) — visual walkthrough of both models
- [ ] Read through **Sections 5–9** (Core Definition → How It Works) carefully — don't skim
- [ ] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **Core Definition** from memory, then compare
- [ ] Explain **First Principles** out loud without notes — what problem does each model solve and why?
- [ ] Reconstruct the **How It Works** mechanics step by step from memory
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

```
§ 1  ONE-LINER
Pull CDN caches on demand (first miss triggers origin fetch, TTL controls freshness);
Push CDN is pre-loaded by the operator before any user request arrives (zero cold-start,
but you own the full content lifecycle).

§ 2  PULL CDN MECHANICS
Cache miss flow:
  User → PoP (MISS) → origin fetch → cache at PoP with max-age TTL → serve user
  All subsequent requests from same PoP: HIT until TTL expires.

Cache hit flow:
  User → PoP (HIT) → return cached response (origin not contacted)

Key headers:
  Cache-Control: max-age=<seconds>    — TTL for both CDN and browser
  Cache-Control: s-maxage=<seconds>   — CDN-only TTL (overrides max-age for CDN)
  Cache-Control: no-store              — NEVER cache (defeats CDN entirely)
  Surrogate-Control: max-age=<sec>    — Fastly/Varnish CDN-only TTL

Invalidation before TTL:
  Versioned URLs: app.abc123.js — deploy new hash, old URL keeps serving from cache.
  Purge API: CloudFront Invalidation, Fastly Purge — global propagation in 1–10s.
  CDN shield (origin shield): single PoP fetches from origin, others fetch from shield.

§ 3  PUSH CDN MECHANICS
Lifecycle:
  1. Upload  → operator pushes files to CDN via API or rsync; CDN distributes to all PoPs
  2. Serve   → any request = immediate cache HIT (no cold-start, ever)
  3. Update  → re-upload new version; old content may need explicit delete
  4. Delete  → operator issues delete; confirmed globally before storage is released

Storage cost:
  Push 1GB binary × 300 PoPs = 300GB edge storage consumed immediately.
  Pull: same binary stored only at PoPs where it is actually requested.

§ 4  DECISION RULE
Use PULL when: content changes frequently, demand is unpredictable geographically,
              or file count is too large to pre-push everywhere (e.g., user avatars).
Use PUSH when: content is large, rarely changes, and globally demanded predictably
              (e.g., game client, OS installer, marketing video).
Use HYBRID:   static large assets (Push) + dynamic/personalized assets (Pull).
              Most production CDN setups are hybrids.

AVOID no-store on cacheable responses — confirms zero CDN benefit.
AVOID long TTL on frequently changing content — stale serving window widens.
AVOID forgetting to delete Push content — stale files persist until explicit delete.

§ 5  NUMBERS
Pull TTL typical range: 60s (dynamic) → 86400s (24h, static JS/CSS/images)
Purge API propagation: 1–10 seconds globally
Push storage math: (file count) × (avg size) × (PoP count) = total edge storage
AWS CloudFront invalidation: first 1000 paths/month free; $0.005/path after
Fastly purge: real-time (~150ms global), no per-purge charge

§ 6  GOTCHA TO NEVER FORGET
A Pull CDN with Cache-Control: no-store (or no cache header at all from origin)
provides ZERO caching benefit — every request hits origin as if CDN doesn't exist.
This is the most common CDN misconfiguration in production. Always verify origin
response headers before assuming CDN is working.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

Pull CDN is a demand-driven model where edge servers cache content on the first cache miss by fetching from origin; Push CDN is an operator-driven model where content is proactively uploaded to edge servers before any user request, guaranteeing zero cold-start latency at the cost of managing the full content lifecycle manually.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*

### Pull CDN — Demand-Driven Caching
An edge server that receives a request for uncached content fetches it from origin, caches it locally for future requests (duration controlled by TTL or Cache-Control headers), and returns it to the user. The first request per PoP per key always goes to origin — this is the "cold start" penalty. Pull CDN is self-maintaining: as TTLs expire, the edge automatically refreshes content on the next miss. This makes Pull ideal for content that changes frequently or has unpredictable geographic demand.

### Push CDN — Proactive Pre-Loading
Operators explicitly upload content to CDN edge nodes before any user requests it. The CDN stores the files and serves them directly — there is no origin fetch on demand. This eliminates cold-start latency entirely. However, the operator must manage the full content lifecycle: pushing updates, issuing deletes when content is retired, and monitoring storage usage across all PoPs. Push is appropriate for large, rarely-changed assets where you can predict global demand.

### TTL and Cache Invalidation (Pull-specific)
Time-To-Live controls how long Pull CDN edges serve a cached copy before considering it stale. Short TTLs (seconds to minutes) ensure freshness but increase origin load; long TTLs (hours to days) reduce origin load but mean users may receive outdated content. The standard mechanism is the HTTP `Cache-Control: max-age` header. When you need to invalidate before TTL expires, options include: versioned URLs (e.g., `style.v2.css`), which bypass the cached version entirely, or CDN purge APIs (e.g., CloudFront Invalidation API), which forcibly evict a key from all PoP caches at a cost.

### CDN PoP Storage Budget (Push-specific)
Push CDN requires reserving edge storage at every PoP you target. With 200–500 global PoPs and multi-GB files, storage costs multiply quickly. This is the primary scaling constraint of Push CDN — it works well for a small library of large files but becomes prohibitively expensive for thousands of small, frequently updated files. Pull CDN avoids this by only storing what is actually requested at each location.

### Hybrid CDN
Most production systems use both models simultaneously: static, large, rarely-changed assets (JS/CSS bundles, images, video assets) are served via Pull CDN with long TTLs; large binary distributions (software installers, game updates) may use Push CDN. Dynamic content (API responses, personalized pages) typically bypasses CDN entirely or uses very short TTLs with CDN as a shield to reduce origin connection count.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

Before CDNs, every user request went to the origin server regardless of geographic distance. A user in Tokyo requesting a file from a US-hosted server would traverse 150+ ms of round-trip latency on every single request — and the origin had to serve every user globally. This created two compounding problems: high latency for geographically distant users, and origin infrastructure that scaled with global traffic.

CDNs solved both by moving content closer to users. But the fundamental question immediately arose: **when should content move to the edge?** Two philosophies emerged. Pull CDN says "move it when someone asks for it" — let demand drive edge population organically. Push CDN says "move it before anyone asks" — trade edge storage cost for guaranteed low latency on first access. The split exists because different content types have fundamentally different demand patterns: a viral tweet's image is unpredictably demanded globally (Pull wins), while a Windows installer update is predictably demanded everywhere (Push wins).

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*

### Model 1: The Public Library vs. The Bookstore
Pull CDN is like a public library — books are brought in when patrons request them and placed in the local branch for others. The first patron who wants a rare book has to wait for it to arrive (cold start). Push CDN is like a bookstore that pre-stocks shelves before opening — every title is available the moment the doors open, but someone had to make buying decisions in advance and unsold stock sits on shelves. The model breaks down in that CDNs have global reach and near-instant distribution; the analogy works best for illustrating the demand-driven vs. supply-driven mental model.

### Model 2: Cache-Aside vs. Pre-Warming
Pull CDN is architecturally identical to cache-aside at the CDN layer — the edge is the cache, origin is the database, and TTL is the expiry. This is the same pattern as application-layer caching, just pushed to the network edge. Push CDN maps to cache pre-warming — explicitly seeding the cache before traffic arrives. If you understand cache-aside and pre-warming from caching systems, you already understand the CDN analogs. The key difference: cache-aside usually has one cache; Pull CDN has 200–500 PoP caches globally.

### Model 3: The Freshness Dial
Think of Pull CDN TTL as a dial between two extremes: TTL=0 is "always hit origin" (CDN as a shield only, no caching benefit), and TTL=∞ is "never update" (maximum performance, broken for changing content). Every Pull CDN configuration is finding the right position on that dial for a given content type. Where the model breaks down: TTL is per cache-control header on the response, not a global CDN setting — misconfigured origin responses result in unintended positions on the dial.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

### Pull CDN — Request Flow

**Happy path (cache hit):**
1. User's DNS resolves to the nearest PoP via anycast or geo-DNS
2. PoP looks up the requested URL in its cache — **HIT**
3. PoP returns the cached response directly; origin is not contacted
4. Cache hit rate for hot content: typically 80–99%

**Cache miss (cold start or TTL expired):**
1. User's DNS resolves to the nearest PoP
2. PoP looks up URL — **MISS** (not cached or TTL expired)
3. PoP forwards the request to origin (the "cache fill" request)
4. Origin returns the full response; PoP caches it with the TTL from the `Cache-Control: max-age` header
5. PoP returns the response to the user — latency = PoP-to-origin RTT + origin processing time
6. Subsequent requests from the same PoP hit the cache until TTL expires

**Key parameters:** `Cache-Control: max-age=N`, `Cache-Control: no-store` (prevents caching), `Surrogate-Control` (CDN-only TTL not sent to browsers), `Vary` header (creates separate cache entries per header value, e.g., per Accept-Encoding)

**Invalidation before TTL:**
- **Versioned URLs:** `app.abc123.js` — deploy a new hash, old URL keeps serving old content from cache (harmless), new URL starts cold and fills on first request. No explicit purge needed.
- **CDN Purge API:** CloudFront Invalidation, Fastly Purge — forcibly evicts a key from all PoP caches globally. Takes 1–10 seconds. Usually charged per invalidation at scale (AWS: first 1000/month free, then $0.005/path/distribution).

### Push CDN — Lifecycle

1. **Upload:** Operator uploads files to CDN via API or origin push. CDN distributes to all configured PoPs.
2. **Serve:** Any request for the pushed URL hits the PoP cache — always a cache hit (no cold start).
3. **Update:** To update, operator uploads new content. Old content may need to be explicitly deleted or the URL changed (versioning pattern works here too).
4. **Delete:** Operator explicitly issues delete to remove content from all PoPs. Storage is not released until deletion is confirmed globally.

**Storage cost math:** 1,000 files × average 10 MB × 300 PoPs = **3 TB** edge storage. For a game installer at 50 GB × 300 PoPs = **15 TB**. Push CDN providers typically charge for both storage and transfer; Pull CDN providers typically charge only for transfer (edge-to-user) and origin-fetch bandwidth.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| AWS CloudFront | Pull CDN by default — origin fetches on miss, TTL from Cache-Control headers | Supports invalidation API; also supports origin groups for failover |
| Cloudflare | Pull CDN with aggressive default caching + Page Rules for fine-grained TTL control | Cloudflare also supports "Cache Reserve" for pushing popular content to persistent edge storage |
| Fastly | Pull CDN with real-time purge (100ms global purge) — a key differentiator for news/media sites | VCL (Varnish Configuration Language) gives operators fine-grained cache key control |
| Akamai NetStorage | Push CDN product — operators upload directly to Akamai's edge storage | Used for software distribution, game patches, large media assets |
| Steam (Valve) | Push CDN for game content distribution — game files are pre-distributed globally before launches | Combined with delta patching to reduce re-push volume on updates |
| GitHub Releases | Pull CDN (via Fastly) for release artifacts — popular assets cached at edge after first hit | Hot releases (major OS, popular software) achieve very high cache hit rates quickly |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Pull CDN: self-managing — edges populate automatically | Cold-start latency for first user per PoP per content item |
| Pull CDN: efficient storage — only popular content stored at each PoP | Requires correct Cache-Control headers; misconfigured origins defeat CDN entirely |
| Pull CDN: handles unpredictable demand geography naturally | Cannot guarantee global cache warmth before a traffic spike (e.g., product launch) |
| Push CDN: zero cold-start — all users get cached response immediately | Operator must manage full content lifecycle; stale files must be explicitly deleted |
| Push CDN: predictable, controlled edge state | Storage cost multiplied by PoP count — expensive for large or numerous files |
| Push CDN: ideal for planned, high-demand events | Wasteful if content is not actually requested at all PoPs (unused edge storage) |
| Hybrid: optimizes for each content type | Operational complexity of managing two CDN delivery models simultaneously |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "How would you serve static assets globally with low latency?"
- "You're launching a new game — how do you ensure players download the client fast worldwide?"
- "Our homepage CSS/JS takes 2s to load for users in Asia. What do you do?"
- "How would you handle a massive simultaneous traffic spike on a new product launch?"

**What you say / do:**
During high-level design, when you propose a CDN layer, immediately distinguish which model applies to the specific content type. For static web assets: "We'd use Pull CDN with long TTLs and versioned filenames so we can deploy updates without manual purges." For large binary distributions: "We'd use Push CDN to pre-load content at all major PoPs before the launch — we can't afford first-request origin latency when millions of users hit simultaneously."

**The trade-off statement (memorize this pattern):**
> "If we choose Pull CDN, we get automatic edge population and storage efficiency, but we pay with cold-start latency for the first request per PoP and a dependency on correct Cache-Control headers. For this system — which has unpredictable demand geography and content that changes frequently — Pull is the right call because the cold-start penalty is rare and manageable."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** CDN always caches content — just put assets behind a CDN and they'll be served from the edge.
  ✅ **Reality:** Pull CDN only caches if the origin returns a cacheable Cache-Control header. An origin responding with `Cache-Control: no-store` or `no-cache` is not cached at all — every request hits origin regardless of CDN presence.

- ❌ **Misconception:** Push CDN is always better because there's no cold start.
  ✅ **Reality:** Push CDN multiplies storage cost by the number of PoPs. For thousands of small, frequently updated files (e.g., user avatars), Push is operationally infeasible. Pull handles dynamic/large-scale content libraries far more efficiently.

- ❌ **Misconception:** Cache invalidation in Pull CDN is instant — issue a purge and all users get fresh content immediately.
  ✅ **Reality:** CDN purge APIs propagate globally in 1–10 seconds (not instant), and at scale purge APIs are rate-limited and charged. Versioned URLs are more reliable for guaranteed freshness because they don't rely on purge propagation timing.

- ❌ **Misconception:** Pull and Push CDN are mutually exclusive — you pick one per CDN provider.
  ✅ **Reality:** Most production systems use both within the same CDN account: Pull for regularly updated web assets, Push for large static binaries. Most CDN providers support hybrid configurations.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** 6.1 CDN Architecture — PoPs and Edge Servers. Pull/Push are the two content population models built on top of the PoP infrastructure covered in 6.1. Without understanding how PoPs are organized and how requests are routed to them, the pull-miss-to-origin flow doesn't make sense.
- **Enables:** 6.3 Cache Invalidation at the Edge — the invalidation challenges discussed in 6.3 (TTL, versioned URLs, purge APIs) are entirely motivated by Pull CDN's staleness problem. Push CDN sidesteps most of these challenges since you control content explicitly.
- **Tension with:** 6.5 CDN for Static vs. Dynamic Content — the Pull vs. Push decision maps directly to the static vs. dynamic split. Static content (Pull-friendly) vs. dynamic/personalized content (CDN bypass or very short TTL Pull) represents the same trade-off at a different framing. In interviews, naming both framings shows depth.

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. What is the difference between Pull CDN and Push CDN? Explain both in two sentences each.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 5.*
Pull CDN: edge servers fetch content from origin on the first cache miss and cache it
for subsequent requests; TTL controls how long the cached copy is served before
re-fetching. It is self-populating — no operator action required.

Push CDN: the operator explicitly uploads content to all edge PoPs before any user
request arrives, guaranteeing every request is a cache hit. The operator owns the full
lifecycle: upload, update, and delete.

2. A social media platform serves user-uploaded profile photos (millions of unique images, updated occasionally). Which CDN model would you use and why?

   > 💡 *Consider: file count, update frequency, and storage economics. Revisit Section 6 if unsure.*
Pull CDN. There are millions of unique profile photos — pre-pushing all of them to
300+ PoPs would cost millions × file size × 300 in storage, which is prohibitive.
Pull CDN organically populates each PoP only with photos actually requested there,
making storage proportional to actual demand.

3. What is the cold-start problem in Pull CDN, and what two strategies can mitigate it?

   > 💡 *Think about what happens on the very first request. Revisit Section 9 if unsure.*
Cold-start is when a PoP has never cached a piece of content, so the first request
from that PoP incurs full origin latency instead of a cache hit. It affects every PoP
independently — a file cached in the US PoP is still cold in the Tokyo PoP.

Mitigation 1: Origin shield — designate a single intermediary PoP between all edge
PoPs and origin; simultaneous misses from N PoPs collapse into one origin fetch.

Mitigation 2: Cache pre-warming — proactively seed PoP caches with known hot content
before a traffic spike (e.g., before a product launch) so first requests are HITs.

4. Name a real system that uses Push CDN and explain specifically why Pull CDN would be a poor fit for that use case.

   > 💡 *Consider file size, demand predictability, and the consequence of cold-start. Revisit Section 10.*
Steam (Valve) uses Push CDN for game distributions. Pull CDN would be a poor fit
because game files are 50–100GB and millions of users download simultaneously at
launch — cold-start across all PoPs at the same moment would flood origin with
concurrent 100GB fetch requests, overwhelming it before any PoP warms up.

5. A developer sets `Cache-Control: no-store` on all API responses but wraps the API behind CloudFront. Are API responses cached? What's the implication for cache hit rate?

   > 💡 *This is the most common CDN misconfiguration gotcha. Revisit Section 13 if unsure.*
No — Cache-Control: no-store instructs CloudFront never to cache the response.
Every request passes through to origin as if CloudFront doesn't exist.
Cache hit rate = 0%. CloudFront provides connection offload only, not caching benefit.

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **Cloudflare Learning Center — "What is a CDN?"** — [cloudflare.com/learning/cdn/what-is-a-cdn](https://www.cloudflare.com/learning/cdn/what-is-a-cdn/) — accessible overview of both Pull and Push mechanics
- [ ] **AWS CloudFront Developer Guide — Managing Cache Expiration** — [docs.aws.amazon.com](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Expiration.html) — real-world Pull CDN TTL and invalidation configuration
- [ ] **Fastly Blog — "Cache invalidation for beginners"** — [developer.fastly.com](https://developer.fastly.com/learning/concepts/cache-freshness/) — strong treatment of TTL, surrogate keys, and purge strategies
- [ ] **ByteByteGo — "How does CDN work?"** — [blog.bytebytego.com](https://blog.bytebytego.com) — visual walkthrough of request flows for both models
- [ ] **Akamai NetStorage Technical Guide** — [techdocs.akamai.com](https://techdocs.akamai.com/netstorage) — reference implementation of a production Push CDN product

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

Pull/Pull Model Decision Tree

Is content dynamic or personalized (user-specific)?
│
├── YES → Bypass CDN entirely (or Pull with very short TTL, e.g., 60s)
│         API responses, user feeds, personalized pages
│
└── NO (static content) → continue
         │
         ├── Is content large (>100MB) AND globally demanded AND rarely changes?
         │   │
         │   ├── YES → Push CDN
         │   │         Game clients, OS installers, large video assets
         │   │         (pre-load before launch; cold-start would be catastrophic)
         │   │
         │   └── NO → continue
         │             │
         │             ├── Is file count very large (millions of unique files)?
         │             │   │
         │             │   └── YES → Pull CDN
         │             │             User avatars, article images, thumbnails
         │             │             (too many to pre-push; organic population wins)
         │             │
         │             └── Does content change frequently (deploys, updates)?
         │                 │
         │                 ├── YES → Pull CDN + versioned URLs + long TTL
         │                 │         JS/CSS bundles, image assets, fonts
         │                 │
         │                 └── NO → Pull CDN (long TTL, ≤TTL staleness acceptable)
         │                           OR Push if launch predictability matters
         │
         └── Does your system have BOTH large stable binaries AND dynamic content?
             │
             └── YES → Hybrid
                       Push: large binaries, stable marketing assets
                       Pull: everything else