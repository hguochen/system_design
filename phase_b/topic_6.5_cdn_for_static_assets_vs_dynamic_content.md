# 6.5 CDN for Static Assets vs. Dynamic Content

> **Topic:** Topic 6 — CDN
> **Phase:** B — Scalability Branch
> **Date studied:** 2026-07-05

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

Not all content is equally CDN-friendly. **Static assets** — CSS, JS bundles, images, fonts, video segments — are identical for every user and change rarely, so they can be cached at the edge with long TTLs and served entirely from a nearby PoP without ever touching the origin. **Dynamic content** — personalized dashboards, API responses, search results, authenticated pages — is generated per-request and traditionally can't be cached at all. The core skill in this subtopic is knowing *where a given piece of content sits on the cacheability spectrum* and choosing the right CDN strategy: long-TTL edge caching for static, micro-caching for semi-dynamic, and **dynamic content acceleration (DCA)** — which speeds up delivery *without caching the body* — for truly personalized content.

### 🎯 What to Focus On

**1. The cacheability spectrum.** Content isn't binary static-vs-dynamic. It's a gradient: fully static (immutable, long TTL) → semi-dynamic (micro-cacheable for 1–10s) → personalized (uncacheable body, DCA only) → real-time (bypass CDN). Being able to place any content on this gradient is the interview skill.

**2. Static caching mechanics.** Cache-Control headers, `immutable`, versioned/fingerprinted URLs for cache-busting, and why versioned URLs make static invalidation a non-problem. Know why you set `max-age=31536000, immutable` on a hashed bundle.

**3. Dynamic content acceleration (DCA).** The key insight most candidates miss: a CDN helps uncacheable content *even when it caches nothing*. TLS/TCP termination at the edge, warm keep-alive connections to origin, route optimization over a private backbone, and HTTP/2/3 all cut latency without a single cache hit.

**4. Micro-caching and edge assembly.** For semi-dynamic content (a news homepage seen by millions), caching for even 1 second collapses origin load by orders of magnitude. Edge Side Includes (ESI) and edge compute (Workers/Lambda@Edge) let you cache the static skeleton and fill dynamic holes at the edge.

**5. What breaks caching.** Cookies, `Vary` headers, query strings, and personalization tokens all fragment or defeat the cache. Know how cache keys are constructed and how to normalize them.

---

## 1. 🎯 Goal of This Subtopic

- Be able to **classify any piece of content** in a system design as static, semi-dynamic, personalized, or real-time — and justify the classification.
- Be able to **specify the caching strategy per content type**: TTL, cache key, invalidation method, and header configuration.
- Understand **why a CDN accelerates dynamic content it never caches**, and be able to explain DCA mechanics to an interviewer.
- Be able to **design cache-busting via versioned URLs** and explain why it makes static invalidation trivial.
- Identify **when micro-caching or edge compute** is the right tool for content that sits between fully static and fully personalized.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can place any given content type (product image, user feed, stock ticker, marketing homepage) on the static→dynamic cacheability spectrum and defend the placement
- [ ] Can explain how a CDN reduces latency for a fully personalized, uncacheable API response (DCA: edge TLS termination, connection reuse, route optimization)
- [ ] Can design a cache-busting scheme with versioned/fingerprinted URLs and explain why `Cache-Control: max-age=31536000, immutable` is safe on them
- [ ] Can explain micro-caching (1–10s TTL on semi-dynamic content) and quantify the origin-load reduction it produces under high concurrency
- [ ] Can name the specific things that break edge caching (cookies, `Vary`, query strings, `Set-Cookie`) and how to normalize the cache key
- [ ] Can describe edge assembly (ESI / edge compute) for pages that mix static shell + dynamic fragments

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] Read **Cloudflare Learning — "What is dynamic content? Static vs dynamic"** (https://www.cloudflare.com/learning/cdn/serve-static-content/) and the DSA/Argo pages
- [ ] Read **MDN — HTTP caching** (https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching) — focus on `Cache-Control`, `immutable`, `Vary`, validation
- [ ] Read **AWS CloudFront — cache behaviors and Lambda@Edge** (https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cache-key-understand-cache-policy.html)
- [ ] Read through **Sections 5–9** (Core Definition → How It Works) carefully — don't skim
- [ ] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **cacheability spectrum** (4 tiers) from memory, then compare
- [ ] Explain **why DCA helps uncacheable content** out loud without notes
- [ ] Reconstruct the **static request path vs. dynamic request path** step by step from memory
- [ ] Restate each **Trade-off** row in your own words — if you can't explain the cost, you don't own it yet

### Phase 3 — Apply 🔧 💪💪💪💪
*Goal: Connect to real systems and simulate interview scenarios.*

- [ ] Go through **Real-World System Examples** (Section 10) — verify each claim independently and add anything missed to **My Notes**
- [ ] Practice the **Interview Application** (Section 12) out loud — say the trigger phrases and your response as if in a live interview
- [ ] Work through **Common Misconceptions** (Section 13) — for each, explain *why* the misconception is wrong
- [ ] Trace the **Relationships to Other Concepts** (Section 14) — can you explain each connection without looking?

### Phase 4 — Validate 🧪 💪💪💪💪💪
*Goal: Confirm you actually own it, not just recognize it.*

- [ ] Answer every **Self-Check Quiz** question (Section 15) out loud without looking at your notes
- [ ] Recite the **Cheatsheet** (Section 4) from memory — if you can't, re-do Phase 2
- [ ] Tick off items in **What Mastery Looks Like** (Section 2) — only check a box if you can demonstrate it on demand
- [ ] Teach this concept out loud to an imaginary interviewer for 2 minutes without hesitation or notes

---

## 4. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

```
§ 1  WHY IT EXISTS
Static assets (CSS/JS/images/fonts/video) are identical for every user and change
rarely — they can be cached at the edge with long TTLs and served from a nearby PoP,
never touching origin. Dynamic content (personalized dashboards, API responses) is
generated per-request and can't be cached the same way. But a CDN still accelerates
dynamic content WITHOUT caching it — by terminating TLS/TCP at the edge, reusing warm
origin connections, and routing over an optimized backbone. The topic is about matching
each content type to the right CDN strategy, not treating "CDN = static files only."

§ 2  THE CACHEABILITY SPECTRUM
FULLY STATIC     — hashed JS/CSS bundles, images, fonts, video segments.
                   Cache-Control: max-age=31536000, immutable. TTL = ~1 year.
SEMI-DYNAMIC     — news homepage, product listing, trending feed. Same for many users
                   for a short window → MICRO-CACHE 1–10s. Huge origin-load collapse.
PERSONALIZED     — user dashboard, cart, authenticated API. Body uncacheable →
                   DCA only (accelerate delivery, cache nothing) or edge-assemble.
REAL-TIME        — live prices, chat, presence. Bypass CDN cache; use it only for
                   TLS termination / routing (or don't route through it at all).

§ 3  THE 3 KEY DISTINCTIONS
1. Static = cache the BODY at edge (origin offload + latency win).
   Dynamic = accelerate DELIVERY, cache nothing (latency win, no offload).
2. Static invalidation is solved by VERSIONED URLs (content hash in filename) →
   new content = new URL = never serve stale, old URL just expires naturally.
   Dynamic freshness is handled by short TTL (micro-cache) or explicit purge.
3. What breaks caching: cookies, Set-Cookie, Vary, and raw query strings fragment
   or defeat the cache. Normalize the cache key; strip tracking params.

§ 4  USE / AVOID
Use long-TTL edge cache:  immutable, versioned static assets (max-age=1yr, immutable).
Use micro-caching:        semi-dynamic pages hit by many users; 1–10s TTL absorbs spikes.
Use DCA (no cache):       personalized/authenticated content — win latency via edge TLS,
                          connection reuse, route optimization.
Use edge compute/ESI:     pages = static shell + a few dynamic holes; assemble at edge.
Avoid caching:            per-user private data with a shared cache key (leak risk!),
                          real-time data, anything with Set-Cookie on the response.
Avoid short TTL on static: wastes revalidation round-trips; use versioned URLs + long TTL.

§ 5  INTERVIEW TRIGGERS
→ "How do you serve static assets to a global user base with low latency?"
→ "Can a CDN help with API responses / personalized content, or only static files?"
→ "Our news homepage gets millions of hits at once — how do we protect the origin?"
→ "How do you handle cache invalidation for your JS/CSS on deploy?"

§ 6  FTAC
F  "I split content by cacheability. Static assets are identical per user, so I cache
   them at the edge with a ~1-year TTL. Dynamic content is per-user, so the CDN can't
   cache the body — but it still cuts latency by terminating TLS at the edge and
   reusing warm connections to origin (dynamic content acceleration)."
T  "Static edge caching gives both origin offload and low latency; the cost is
   invalidation, which I solve with versioned URLs. DCA gives latency wins for dynamic
   content but no origin offload — every request still hits origin, just faster."
A  "Assuming static assets are fingerprinted at build time and the homepage is the same
   for anonymous users for a few seconds —"
C  "Long-TTL immutable cache on hashed assets; micro-cache the anonymous homepage for
   ~5s; route authenticated API calls through the CDN for DCA but mark them no-store."

§ 7  NUMBERS & GOTCHA
Static TTL:      max-age=31536000 (1 year) + immutable on versioned assets.
Micro-cache TTL: 1–10s — at 10k rps, a 1s cache = at most 1 origin hit/sec/key (~99.99%
                 offload) while keeping content "fresh within 1 second."
DCA offload:     0% (body never cached) — the win is latency (edge TLS + warm origin
                 keep-alive + backbone routing), not origin protection.
GOTCHA: Caching a personalized response under a URL-only cache key leaks one user's
  private data to another user. Never cache responses with Set-Cookie or per-user data
  unless the cache key includes the user/session identity AND you intend a private cache.
  Default to no-store for authenticated content; opt IN to caching deliberately.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

Serving content through a CDN by classifying it along a cacheability spectrum: **static assets** (identical for all users) are cached at edge PoPs with long TTLs for both origin offload and low latency, while **dynamic content** (generated per-request) is either micro-cached for short windows, assembled at the edge, or delivered via *dynamic content acceleration* — which reduces latency through edge TLS termination, connection reuse, and route optimization *without caching the response body*.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*

### Static Assets
Content that is byte-for-byte identical for every user and changes only on deploy — JS/CSS bundles, images, icons, fonts, and video segments. Because it's shared and stable, it's the ideal CDN payload: cache it once at each PoP with a long TTL (`max-age=31536000, immutable`) and virtually every request is served from the edge, never reaching origin. Freshness is handled not by short TTLs but by **versioned URLs** (a content hash in the filename), so a change produces a brand-new URL rather than requiring invalidation.

### Dynamic Content
Content generated per-request, often personalized or time-sensitive — a logged-in user's dashboard, cart, search results, or a real-time API response. The response body typically differs per user or per moment, so it can't be cached under a shared key. The naive conclusion ("CDNs are useless here") is wrong: CDNs still add value through acceleration, edge compute, or short-window micro-caching, depending on how dynamic the content actually is.

### Dynamic Content Acceleration (DCA)
The technique of using a CDN to speed up uncacheable content by optimizing the *transport*, not the *cache*. The edge PoP terminates the user's TLS/TCP handshake nearby (saving multiple RTTs over long distances), maintains warm keep-alive connections to origin, and routes the request over the CDN's optimized private backbone instead of the public internet (Cloudflare Argo, Akamai SureRoute). The origin still generates every response, but the round-trip is dramatically faster. **DCA gives latency wins with zero origin offload.**

### Micro-caching
Caching semi-dynamic content for a very short TTL (typically 1–10 seconds). Content like a news homepage or a "trending now" list is the same for many anonymous users within any given second. Caching it for even 1 second means the origin generates it at most once per second per key regardless of traffic — collapsing thousands of requests per second into a trickle while keeping content "fresh within one second." The trade-off is a bounded staleness window equal to the TTL.

### Cache Key & Cacheability Breakers
The cache key determines what counts as "the same" response. By default it's the URL (host + path + query). Personalization signals — cookies, `Authorization` headers, `Vary` headers, and query-string parameters — either fragment the cache (a separate entry per variation, killing hit rate) or, worse, cause private data to be cached under a shared key (a security leak). Understanding cache-key normalization (stripping tracking params, ignoring irrelevant cookies) is central to making dynamic content cacheable safely.

### Versioned URLs (Cache-Busting / Fingerprinting)
Embedding a content hash in an asset's filename (`app.9f3c2a.js`). Because the URL changes whenever the content changes, you can cache each version forever (`immutable`) with no invalidation logic: a deploy simply references new URLs in the HTML, old URLs age out of cache naturally, and users never see a stale mix. This is why static invalidation is essentially a solved problem — you don't invalidate, you re-version.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

A CDN's superpower is serving cached copies from a nearby PoP — but that only works when the copy is *reusable*. Static assets are perfectly reusable: one file serves every user, so caching it near users solves both latency (short physical distance) and scale (origin never sees the traffic). The problem is that most valuable content on modern sites is *not* reusable — it's personalized, authenticated, or real-time. If CDNs could only handle static files, they'd be relegated to serving logos and stylesheets while every meaningful request still made the full round-trip to a distant origin.

Two forces pushed CDNs beyond static caching. First, **latency physics**: a user in Singapore hitting a US origin pays ~200ms per round-trip, and TLS setup alone is multiple round-trips. Even if you can't cache the response, terminating the connection at a nearby edge and multiplexing over a warm backbone connection turns 4–5 slow public-internet round-trips into 1 slow trip plus several fast local ones — hence dynamic content acceleration. Second, **the "semi-dynamic" reality**: enormous amounts of traffic hit content that is technically dynamic but effectively identical for many users over short windows (a homepage, a product page, a trending feed). Micro-caching exploits that: a 1-second cache is invisible to users but reduces origin load by orders of magnitude. This subtopic exists because the naive static-vs-dynamic binary leaves most of the performance and scale opportunity on the table.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*

### Model 1: The Cacheability Spectrum (a dimmer, not a switch)
Don't think "static vs. dynamic" as a binary. Think of a dimmer switch from fully-static to real-time. Fully static (hashed bundle) → cache forever. Semi-dynamic (homepage) → micro-cache seconds. Personalized (dashboard) → accelerate but don't cache. Real-time (live price) → bypass. The interview skill is placing any content on this dimmer and reading off the strategy. The model works because it maps cleanly onto TTL length: more dynamic = shorter TTL, and at the extreme, TTL = 0 (DCA only). It breaks down when content is *partly* personalized — that's where edge assembly comes in, and you have to decompose the page rather than dim a single knob.

### Model 2: Cache the Body vs. Accelerate the Pipe
There are two independent levers a CDN pulls. Lever one caches the **response body** at the edge (works only for reusable content; gives offload + latency). Lever two optimizes the **transport pipe** — edge TLS termination, warm origin connections, backbone routing — which works for *any* content and gives latency but no offload. Static content pulls both levers; dynamic content pulls only the second. This model prevents the classic mistake of thinking a CDN does nothing for uncacheable content. It breaks down if you forget that lever two costs money per request with no origin relief — DCA is not free scale.

### Model 3: The Newsstand vs. The Print Shop
A static asset is like a stack of identical newspapers at a newsstand on every corner — anyone can grab one instantly, and the printing press (origin) is idle. A personalized dashboard is like a custom-printed document: it must go back to the print shop every time, but you can still put the print shop's *intake counter* on every corner (edge TLS termination) and use express couriers on private roads (backbone routing) so the trip is fast. Micro-caching is the newsstand restocking every few seconds from the press. The model makes the offload-vs-acceleration distinction visceral; it breaks down for edge compute, where the "corner stand" itself can do some of the printing (Workers/Lambda@Edge).

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

**Static asset request (cache the body — happy path):**
1. Browser requests `https://cdn.site.com/app.9f3c2a.js`.
2. DNS/anycast routes to the nearest PoP.
3. PoP checks its edge cache for that URL key. **Hit** → return immediately from edge (single short RTT, no origin contact). The response carries `Cache-Control: max-age=31536000, immutable`, so the browser also caches it locally and won't even re-request on the next page load.
4. **Miss** (cold PoP) → PoP fetches from origin (or a tiered/shield parent cache), stores it, and serves it. All subsequent users at that PoP get the hit. Because the URL is content-hashed, this cached copy is safe to keep for a year.

**Personalized/dynamic request (accelerate the pipe — DCA path):**
1. Browser requests `https://api.site.com/me/feed` with an auth cookie.
2. Anycast routes to the nearest PoP; the PoP terminates TLS locally (the expensive multi-RTT handshake happens over ~5ms instead of ~200ms).
3. The response is marked `Cache-Control: private, no-store` (or the cache key includes identity), so the PoP does **not** serve from cache.
4. The PoP forwards the request to origin over a **warm, pre-established keep-alive connection** across the CDN's optimized backbone (avoiding a fresh TCP+TLS handshake and public-internet congestion).
5. Origin generates the personalized response; the PoP streams it back. Nothing is cached, but the user saved several long round-trips.

**Semi-dynamic request (micro-cache):**
1. Many anonymous users request `https://site.com/` (homepage) within the same second.
2. PoP has a micro-cache entry with `max-age=5`. The first request after expiry goes to origin; the response is cached for 5s.
3. Every other request in that 5s window is served from edge. At 10k rps, origin sees ~1 request per 5s per PoP instead of 10k — a ~99.99% reduction — while content is never more than 5s stale.
4. **Edge case — stampede on expiry:** when the entry expires, concurrent requests could all miss and hit origin at once. Mitigations: `stale-while-revalidate` (serve stale while one request refreshes in the background) and request coalescing at the edge.

**Edge assembly (mixed page):**
1. A product page = static shell (layout, header, footer — cacheable) + dynamic holes (price, stock, "recommended for you").
2. Using ESI or an edge function (Cloudflare Workers, Lambda@Edge), the PoP serves the cached shell and fetches/injects only the dynamic fragments, or computes them at the edge.
3. Result: most of the page is edge-served; only small dynamic pieces round-trip to origin.

**Key headers & parameters to remember:**
- `Cache-Control: max-age=31536000, immutable` — static, versioned assets.
- `Cache-Control: no-store` / `private` — personalized, never cache.
- `Cache-Control: s-maxage=5, stale-while-revalidate=30` — micro-cache with graceful refresh (`s-maxage` targets the shared/CDN cache specifically).
- `Vary: Accept-Encoding` fine; `Vary: Cookie` usually catastrophic for hit rate.
- Cache key normalization: strip tracking query params (`utm_*`), ignore non-functional cookies.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| **Cloudflare (Argo + Workers)** | Static assets cached at edge with `Cache Everything` rules; **Argo Smart Routing** provides DCA over a private backbone for dynamic requests; **Workers** do edge assembly/compute | Argo advertises ~30% latency reduction for uncacheable content by routing around congestion — pure DCA, no caching |
| **Akamai (DSA / Ion)** | **Dynamic Site Accelerator** pioneered DCA: **SureRoute** finds optimal overlay paths, edge TLS termination, and TCP optimizations for uncacheable content | Akamai built the category — "dynamic content" acceleration without caching the body |
| **AWS CloudFront** | Per-path **cache behaviors**: static `/assets/*` gets long TTL; `/api/*` set to no-cache but still benefits from edge TLS termination + keep-alive to origin; **Lambda@Edge / CloudFront Functions** for edge compute | Cache policies control which headers/cookies/query strings enter the cache key |
| **Fastly** | Instant purge + **VCL** makes aggressive **micro-caching** of semi-dynamic content practical (news, e-commerce); `stale-while-revalidate` widely used | Fastly's sub-150ms global purge lets teams cache dynamic-ish content confidently, knowing they can invalidate instantly |
| **Netflix / YouTube (video)** | Video is chunked into small **static segments** (HLS/DASH `.ts`/`.m4s`) each with a stable URL → highly cacheable at edge, while the manifest/personalization stays dynamic | Turning "dynamic-feeling" streaming into cacheable static segments is the core CDN trick for video |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Long-TTL static edge caching gives both low latency and near-total origin offload | Requires versioned URLs and a build pipeline that fingerprints assets; getting cache headers wrong (short TTL) wastes the benefit |
| DCA accelerates personalized content the CDN can't cache | Zero origin offload — every request still hits origin; you pay CDN egress/compute for latency only, not scale relief |
| Micro-caching collapses origin load for semi-dynamic pages by orders of magnitude | Introduces a bounded staleness window (the TTL); wrong for content that must be strictly real-time or per-user |
| Edge assembly (ESI/Workers) caches the static shell while keeping dynamic holes fresh | Added complexity and a new place for bugs; edge compute has cost, cold-starts, and debugging challenges |
| Normalizing cache keys (stripping cookies/params) raises hit rate | Aggressive normalization can cache the *wrong* variant or leak personalized data under a shared key — a correctness/security risk |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "How do you serve static assets (images, JS, CSS) to a global audience with low latency?"
- "Can a CDN help with dynamic or personalized content, or is it only for static files?"
- "Our homepage gets a massive traffic spike — how do you protect the origin?"
- "How do you handle cache invalidation for your frontend assets on every deploy?"

**What you say / do:**
In the high-level design or a caching deep-dive, split content by cacheability: "Static assets are identical per user, so I'll fingerprint them at build time and cache them at the edge with a one-year immutable TTL — invalidation is handled by versioned URLs. For the anonymous homepage I'd micro-cache for a few seconds to absorb spikes. For authenticated API responses I can't cache the body, but I'll still route them through the CDN for dynamic acceleration — edge TLS termination and warm origin connections cut the round-trip significantly."

**The trade-off statement (memorize this pattern):**
> "Caching static assets at the edge buys me both latency and origin offload, at the cost of an asset-versioning pipeline — which I solve with content-hashed URLs. Routing dynamic content through the CDN buys me latency via acceleration, but zero origin offload: every request still hits origin, just faster. So I cache what's reusable and accelerate what isn't."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** CDNs are only for static files; dynamic content can't benefit.
  ✅ **Reality:** CDNs accelerate uncacheable dynamic content through DCA — edge TLS termination, warm keep-alive connections to origin, and optimized backbone routing. The body is never cached, but latency drops substantially. Naming DCA is exactly the nuance interviewers probe for.

- ❌ **Misconception:** You invalidate static assets by purging the CDN on every deploy.
  ✅ **Reality:** With versioned/fingerprinted URLs you rarely purge at all. New content = new URL, so you just deploy HTML referencing the new URLs; old URLs age out naturally. Purge is a fallback for mistakes, not the primary mechanism.

- ❌ **Misconception:** Micro-caching a few seconds isn't worth the staleness.
  ✅ **Reality:** Under high concurrency, a 1-second cache turns thousands of origin requests per second into one, a ~99.9%+ offload, while keeping content "fresh within a second." For anonymous, high-traffic pages this is one of the highest-leverage optimizations available.

- ❌ **Misconception:** You can just cache API responses at the edge to scale reads.
  ✅ **Reality:** Only if the response is not personalized *or* the cache key includes identity and you intend a private cache. Caching a personalized response under a URL-only key leaks one user's data to another — a serious security bug. Default authenticated content to `no-store`; opt into caching deliberately.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** 6.1 CDN architecture (PoPs/edge servers) — you must understand where edge caches live before deciding what to put in them; and 6.3 Cache invalidation at the edge — versioned URLs and purge are the invalidation tools applied here per content type.
- **Enables:** 6.6 CDN for media delivery — video is the ultimate "make dynamic content static" case (chunked segments with stable URLs); and 6.7 CDN as DDoS mitigation — edge caching and edge termination are what let the CDN absorb floods before they reach origin.
- **Tension with:** 5.5 Cache consistency and invalidation — every edge cache is another tier that can serve stale data; the more you cache dynamic-ish content (micro-caching), the more you trade freshness for offload, echoing the same consistency-vs-performance tension as application-tier caching.

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. Define the difference between static assets and dynamic content in CDN terms, and explain why one is cacheable at the edge and the other typically isn't.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6.*

MODEL ANSWER — Static vs. Dynamic (CDN terms)

STATIC ASSETS
  • Byte-for-byte identical for every user
  • Change only on deploy
  • Freshness handled by versioned/fingerprinted URLs (not short TTLs)
  • e.g. JS/CSS bundles, images, fonts, video segments

DYNAMIC CONTENT
  • Generated per request
  • May be personalized (dashboard, cart) OR just time-sensitive but
    shared (news homepage, stock price) — NOT always per-user
  • e.g. authenticated API responses, search results, feeds

WHY STATIC IS EDGE-CACHEABLE, DYNAMIC USUALLY ISN'T
  The property is REUSABILITY under a shared cache key.
  • Static: one cached copy serves every user → cache once at each PoP,
    serve millions from the edge → low latency AND origin offload.
  • Personalized dynamic: each response is unique → a shared cached copy
    would be wrong (or leak another user's data) → no reuse, don't cache.
  • Key nuance: "dynamic" ≠ "uncacheable." Dynamic-but-shared content is
    reusable for a short window → that's the micro-caching opening.

2. A user in Sydney hits an authenticated, personalized API served from a US origin. The response cannot be cached. How does routing it through a CDN still reduce latency?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6 (DCA) and Section 9.*

MODEL — DCA latency (Sydney → US, ~200ms RTT)
Anycast → nearest Sydney PoP. Response is no-store (can't cache), so the CDN
optimizes TRANSPORT instead:
  • Edge TLS termination → TCP+TLS handshake RTTs relocated to user↔PoP (~5ms
    each) instead of across the ocean (~200ms each).
  • Warm keep-alive edge→origin → no per-request handshake to origin.
  • Optimized backbone routing → the one remaining long-haul hop dodges public
    congestion.
QUANT: without CDN ~3–4 long-haul RTTs (TCP + TLS + request). With CDN → ~1
long-haul RTT (just request/response). "3–4 → 1." Zero caching, pure latency.

3. Your homepage is anonymous and gets 20,000 requests/second during a spike. Design a CDN strategy that protects the origin without serving badly stale content, and quantify the origin load.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 9 (micro-caching).*
MODEL — 20K rps anonymous homepage
Micro-cache: s-maxage=5–10, stale-while-revalidate=30. Staleness ≤ TTL (fine
for an anonymous homepage).
ORIGIN LOAD: without cache = 20K rps hitting origin. With a 10s micro-cache,
origin sees ~1 regeneration per 10s PER PoP (say 20 PoPs → ~2 origin fetches/sec
total) — a ~99.99% collapse. Everyone else served from edge in ~5ms.
On expiry: origin shield does single-flight (SET NX mutex) so only ONE request
refreshes; stale-while-revalidate serves the old copy meanwhile → no stampede.

4. Name a real production system/technique that accelerates dynamic content without caching the body, and explain the mechanism.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 10.*
Akamai. Dynamic Site Accelerator pioneered DCA: SureRoute finds optimal overlay paths, plus edge TLS termination and TCP optimizations for uncacheable content

5. You decide to cache an API response at the edge to reduce read load. What is the single most dangerous failure mode, and how do you prevent it?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 13 (cache-key / personalization leak).*
MODEL — Most dangerous edge-caching failure
FAILURE: caching a personalized response under a shared (URL-only) cache key →
one user's private data served to another user. Unauthorized data exposure —
serious security + compliance violation.
PREVENT:
  • Default authenticated/personalized responses to Cache-Control: private, no-store
    (no-store = never store; private = never in a shared cache).
    ⚠ NOT no-cache — no-cache stores + revalidates, so data is still stored.
  • Only cache per-user data if the cache key INCLUDES identity AND you intend a
    private/per-user cache.
  • Never cache a response carrying Set-Cookie.

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **Cloudflare Learning — Serve static vs dynamic content / Argo Smart Routing** — https://www.cloudflare.com/learning/cdn/serve-static-content/ — clean explanation of DCA and edge caching
- [ ] **MDN — HTTP Caching** — https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching — authoritative reference on `Cache-Control`, `immutable`, `Vary`, `stale-while-revalidate`
- [ ] **AWS CloudFront — Cache policies and behaviors** — https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cache-key-understand-cache-policy.html — how cache keys, headers, cookies, and query strings interact
- [ ] **Fastly — Enabling micro-caching / stale-while-revalidate** — https://developer.fastly.com/ — practical micro-caching patterns for dynamic content
- [ ] **Akamai — Dynamic Site Accelerator / SureRoute overview** — the origin of DCA as a category; search Akamai's technical docs

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

