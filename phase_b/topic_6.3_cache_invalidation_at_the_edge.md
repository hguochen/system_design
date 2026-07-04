# 6.3 Cache Invalidation at the Edge

> **Topic:** Topic 6 — CDN
> **Phase:** B — Scalability Branch
> **Date studied:** 2026-07-02

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

Cache invalidation at the edge is the set of techniques used to make a globally distributed CDN serve *fresh* content without giving up the latency and origin-offload benefits that made you put a CDN in front of your origin in the first place. The central tension is **freshness vs. propagation**: a CDN has hundreds or thousands of independent edge caches spread across the planet, and there is no single "delete" button that atomically clears them all instantly. You must choose how each object becomes stale — passively by a TTL clock, by getting a brand-new URL, or by an active purge command that fans out to every PoP. Mastering this topic means knowing which of the three strategies fits which content type, understanding the propagation and thundering-herd failure modes, and being able to defend your choice in an interview.

### 🎯 What to Focus On

**1. The three invalidation strategies and when to use each.** TTL-based expiry, versioned/fingerprinted URLs, and API-based active purge are the three tools. The single most important skill is matching each to a content type: immutable static assets → versioned URLs; frequently changing HTML/API responses → short TTL + purge; everything in between → tune the TTL.

**2. Cache-Control semantics.** You must be fluent in `max-age` vs. `s-maxage`, `stale-while-revalidate`, `stale-if-error`, `no-cache` vs. `no-store`, and `immutable`. These headers *are* the invalidation policy for the passive (TTL) path.

**3. Active purge mechanics and their limits.** Purge-by-URL, purge-by-tag (surrogate keys), and purge-everything differ enormously in blast radius and cost. Know that purge is not globally instant, that "purge everything" can stampede your origin, and that CDNs price and rate-limit purges.

**4. Revalidation with ETag / Last-Modified.** Conditional requests (`If-None-Match`, `If-Modified-Since`) let an edge revalidate a stale object with a cheap `304 Not Modified` instead of re-downloading the body. This is the freshness mechanism that runs *after* a TTL expires.

**5. The browser-cache boundary.** The CDN edge is not the only cache. Purging the CDN does nothing to copies already sitting in end-user browsers — which is the whole reason versioned URLs exist. Never conflate the two layers.

---

## 1. 🎯 Goal of This Subtopic

After studying this, you should be able to design a complete edge-invalidation strategy for a given system — specifying the Cache-Control policy per content type, when to reach for versioned URLs versus active purge, how to group related objects for bulk invalidation (cache tags / surrogate keys), and how to avoid overwhelming the origin when a large set of objects is invalidated at once. You should also be able to reason about the staleness window each approach creates and defend the trade-off out loud.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can name the three edge-invalidation strategies (TTL, versioned URLs, active purge) and choose the right one for static assets vs. HTML vs. API responses
- [ ] Can explain the difference between `max-age`, `s-maxage`, `stale-while-revalidate`, and `immutable`, and say which cache each targets
- [ ] Can describe how a `304 Not Modified` revalidation works with ETag / Last-Modified and why it saves bandwidth
- [ ] Can explain why active purge is not globally instant and why "purge everything" risks a thundering herd on the origin
- [ ] Can explain why purging the CDN does not refresh content already cached in users' browsers, and how versioned URLs solve this
- [ ] Can design tag-based (surrogate key) invalidation to purge a group of related objects with a single call

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] Read **MDN — HTTP Caching** (https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching) — the authoritative reference on Cache-Control, ETag, and revalidation
- [ ] Read **Fastly — "Purging" and "Surrogate Keys" docs** (https://developer.fastly.com/learning/concepts/purging/) — the clearest model of tag-based instant purge
- [ ] Read **Cloudflare — "Cache Control" and "Purge cache"** docs (https://developers.cloudflare.com/cache/) — how a large CDN exposes purge
- [ ] Read through **Sections 5–9** (Core Definition → How It Works) carefully — don't skim
- [ ] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **Core Definition** from memory, then compare
- [ ] Explain **First Principles** out loud without notes — why can't a CDN just "delete everywhere instantly"?
- [ ] Reconstruct the **three strategies** and the content type each fits, from memory
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
- [ ] Tick off items in **What Mastery Looks Like** (Section 2) — only check a box if you can demonstrate it on demand
- [ ] Teach this concept out loud to an imaginary interviewer for 2 minutes without hesitation or notes

---

## 4. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

### 🗺️ Edge Invalidation Decision Map

```
What kind of content is it?
│
├── Static asset (JS, CSS, images, fonts) that can change on deploy
│   └──► VERSIONED / FINGERPRINTED URL
│        app.a3f8b2.js  +  Cache-Control: public, max-age=31536000, immutable
│        New content = new filename. Old one just ages out. No purge needed.
│
├── HTML page / API response that changes unpredictably
│   └──► SHORT TTL + ACTIVE PURGE
│        s-maxage=60, stale-while-revalidate=30
│        On content change → purge by URL or by cache tag (surrogate key)
│
└── Content that changes on a known schedule (feeds, listings)
    └──► TUNE THE TTL to the update cadence
         s-maxage matched to how often the source changes; let it expire passively

⚠️  Purge is NOT globally instant — it fans out to every PoP (ms to seconds).
⚠️  "Purge everything" → all PoPs miss at once → THUNDERING HERD on origin.
⚠️  Purging the CDN does NOT clear copies already in users' browsers.
```

```
§ 1  WHY IT EXISTS
A CDN caches copies of your content at hundreds of edge PoPs to cut latency and
offload the origin. But a cached copy can go stale the instant the origin changes.
There is no atomic "delete everywhere" — each PoP is an independent cache spread
across the planet. Edge invalidation is how you make content become fresh again
without losing the caching benefit. The whole game is choosing HOW each object
expires: passively (TTL), by renaming (versioned URL), or actively (purge).

§ 2  THE THREE STRATEGIES
TTL-based (passive):   Cache-Control: s-maxage=N. Edge serves the copy until the
                       clock runs out, then revalidates or re-fetches. Simplest;
                       staleness bounded by the TTL. No control-plane call needed.
Versioned URLs:        Fingerprint the filename (app.a3f8b2.js). New content = new
                       URL, so the old cached object is never served again — it just
                       ages out. Cache the asset "forever" (immutable). Sidesteps
                       invalidation entirely. Best for static assets.
Active purge (push):   API/dashboard command that tells every PoP to drop an object.
                       By URL, by tag/surrogate key, or purge-everything. Near-real-
                       time freshness; needed for HTML/dynamic content. Costs, rate
                       limits, and propagation delay apply.

§ 3  CACHE-CONTROL YOU MUST KNOW
max-age=N             → browser (private) cache lifetime, seconds
s-maxage=N            → shared/CDN cache lifetime; overrides max-age for the CDN
immutable             → asset never changes for this URL; browser skips revalidation
stale-while-revalidate=N → serve stale up to N sec while fetching fresh in background
stale-if-error=N      → serve stale up to N sec if origin errors (resilience)
no-cache              → may cache, but MUST revalidate (304) before serving
no-store              → never cache anywhere
Surrogate-Control     → CDN-only header; stripped before reaching the client

§ 4  USE / AVOID
Use versioned URLs:   static assets on deploy; want cache-forever + instant "update".
Use short TTL:        content with a predictable freshness tolerance (seconds–minutes).
Use tag/surrogate purge: one content change invalidates many pages (e.g., product 123
                      appears on 40 pages → tag them, purge the tag once).
Use stale-while-revalidate: hide origin latency on expiry; smooth out refreshes.
Avoid purge-everything routinely: it cold-starts every PoP → origin stampede.
Avoid long TTL on volatile HTML with no purge path: guarantees stale content.
Avoid relying on purge to fix browser-cached assets: use versioned URLs instead.

§ 5  INTERVIEW TRIGGERS
→ "How do users see the new version right after a deploy?"
→ "The CDN is serving stale content after we updated the page — how do you fix it?"
→ "We changed a product's price; it's shown on many pages. How do you invalidate?"
→ "How do you push a static asset update without waiting for TTLs to expire?"

§ 6  FTAC
F  "A CDN trades freshness for latency — cached edge copies can go stale. The design
   question is how each object becomes fresh again across all PoPs without killing the
   cache-hit benefit."
T  "Versioned URLs give instant, purge-free updates and cache-forever hit rates, but
   only work for content you rename on change. Active purge gives near-real-time
   freshness for un-renamable content but isn't globally instant and can stampede the
   origin. TTL is simplest but bounds staleness to the clock."
A  "Assuming static assets are build-fingerprinted and HTML changes are event-driven —"
C  "Serve fingerprinted assets with max-age=1y, immutable. Serve HTML with s-maxage=60
   + stale-while-revalidate, tagged with a surrogate key; on change, purge that tag.
   Never purge-everything on a routine path."

§ 7  NUMBERS & GOTCHA
Immutable asset TTL:   Cache-Control: public, max-age=31536000, immutable  (1 year)
Purge propagation:     Fastly ~150ms global; Cloudflare ~seconds; Akamai ~5s;
                       CloudFront invalidations seconds–minutes.
CloudFront purge cost: first 1,000 invalidation paths/month free, then ~$0.005/path.
Revalidation:          304 Not Modified returns headers only — near-zero body bytes.
GOTCHA: "Purge everything" makes every PoP miss simultaneously, so N PoPs fire
  concurrent origin fetches for the hottest objects — a thundering herd that can be
  worse than having no CDN. Prefer targeted purge-by-tag; if you must flush broadly,
  pre-warm or ramp, and protect origin with request coalescing.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

Cache invalidation at the edge is the practice of controlling when and how a CDN's distributed edge caches stop serving a stale copy of an object and fetch or reveal a fresh one — achieved through TTL-based expiry, versioned URLs, or active purge — so that content stays acceptably fresh across all PoPs without sacrificing the cache-hit rate that makes the CDN valuable.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*

### TTL-Based Expiration (Passive Invalidation)
Every cached object carries a freshness lifetime, set primarily by the `Cache-Control` header (`s-maxage` for shared/CDN caches, `max-age` for browsers) or the legacy `Expires` header. While the object is "fresh," the edge serves it directly. Once the TTL elapses, the object becomes "stale" and the edge must either revalidate it with the origin or re-fetch it before serving. This is the simplest strategy and requires no active signal — but the maximum staleness a user can experience equals the TTL you chose.

### Versioned / Fingerprinted URLs (Cache Busting)
Instead of invalidating an object, you give the new version a *different URL* — typically by embedding a content hash in the filename (`app.a3f8b2c9.js`) or a query/path version. Because the URL is new, no cache anywhere is holding it, so it's fetched fresh; the old URL is simply never requested again and ages out naturally. This lets you set an effectively infinite TTL (`immutable`, `max-age=31536000`) on static assets while still "updating" them instantly on deploy. It is the only technique that also refreshes copies sitting in end-user browsers.

### Active Purge (Explicit Invalidation)
A control-plane command — via API or dashboard — that tells the CDN to evict an object from its caches before its TTL expires. Three granularities matter: **purge by URL** (one exact object), **purge by tag / surrogate key** (all objects sharing a label, e.g., everything tagged `product-123`), and **purge everything** (flush the entire cache). Purge gives near-real-time freshness for content you cannot rename, but it is not globally instant, is often rate-limited and billed, and — at broad scope — can stampede the origin.

### Revalidation with ETag / Last-Modified
When a stale object needs checking, the edge sends a *conditional request* to the origin using `If-None-Match` (with the object's `ETag`) or `If-Modified-Since` (with its `Last-Modified` date). If nothing changed, the origin replies `304 Not Modified` with no body — the edge simply refreshes the object's TTL and keeps serving the copy it already has. This makes expiry cheap: a stale-but-unchanged object costs a tiny round-trip, not a full re-download.

### Cache Tags / Surrogate Keys
A mechanism for grouping related cached objects so they can be invalidated together. The origin attaches one or more tags to each response (e.g., Fastly's `Surrogate-Key: product-123 category-shoes`). When product 123 changes, a single purge of the `product-123` tag invalidates every cached page and fragment that referenced it — the homepage, the category page, the product page — without you having to enumerate their URLs. This is how large content sites keep dynamic pages fresh without brittle URL lists.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

A CDN exists to serve copies of your content close to users, which means the same object physically exists in hundreds of independent caches scattered across the globe. The moment your origin changes that object, every one of those copies is potentially wrong. Unlike a single database row you can update in place, there is no shared memory and no atomic transaction that spans every PoP — invalidation is inherently a *distributed* problem, and distributed systems cannot make a change appear everywhere simultaneously. Even a "fast" purge has to propagate over the network to every edge node, and some will get the message milliseconds or seconds after others.

So the root problem is this: **you cannot have perfect freshness and maximum cache-hit rate at the same time across a planet-scale cache.** Every design decision is a negotiation of that tension. TTLs were the first answer — let each copy expire on its own clock, accepting bounded staleness in exchange for zero coordination. Versioned URLs were a clever sidestep: if you never reuse a URL, you never have to invalidate one, so you can cache forever. Active purge came last, for the content you genuinely must update in place and cannot rename — accepting the cost, rate limits, and propagation delay of pushing a signal to every PoP. Edge invalidation exists because the alternative — no caching, or permanently stale caching — is unacceptable for real systems.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*

### Model 1: Whiteboards in Every Branch Office
Imagine your content is a notice written on a whiteboard in every one of your company's 300 branch offices (the PoPs). TTL is telling each office "erase this after 60 minutes." A versioned URL is posting a *brand-new notice with a new title* — nobody confuses it with the old one, which just gets ignored until someone wipes it. Active purge is phoning every office and telling them to erase notice #123 *right now* — effective, but the calls take time to complete and some offices pick up before others. This model captures why invalidation is hard: there is no central whiteboard, only many copies, and reaching all of them takes coordination. Where it breaks down: real PoPs also *revalidate* (call HQ to check if the notice changed) rather than always erasing blindly.

### Model 2: Pull vs. Push Invalidation
Frame the three strategies by *who initiates freshness*. TTL and revalidation are **pull**: the edge lazily checks/expires on its own schedule; the origin does nothing special. Active purge is **push**: the origin (or an operator) actively broadcasts "drop this" to every edge. Versioned URLs are neither — they *avoid* the problem by making staleness impossible for a given URL. This model is powerful in interviews because it maps directly onto cost and latency: pull is cheap and eventual; push is immediate but expensive and must fan out. Where it breaks down: `stale-while-revalidate` blends the two — the edge serves stale (pull) while refreshing in the background, decoupling freshness from user-facing latency.

### Model 3: The Rename Trick
The cleanest invalidation is the one you never have to do. Versioned URLs work on the principle that *an object under a URL you never reuse can be treated as immutable* — and immutable data is trivially cacheable forever, at every layer, including the browser. Whenever you find yourself designing a purge pipeline for content that could instead be fingerprinted, ask: "Can I just rename it on change?" For build artifacts the answer is almost always yes. Where it breaks down: content with a *stable, meaningful* URL that users bookmark or that SEO depends on (like `/products/123` or `index.html`) cannot be renamed on every change — that's precisely the content that needs TTL + purge.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

**Passive path (TTL + revalidation):**
1. Origin responds with a body plus `Cache-Control: s-maxage=60`, an `ETag`, and/or `Last-Modified`. The edge stores the object and marks it fresh for 60 seconds.
2. Requests within the fresh window are served directly from the edge — a cache hit, no origin contact.
3. After 60 seconds the object is stale. On the next request, the edge sends a conditional request to the origin: `GET` with `If-None-Match: "<etag>"`.
4. If unchanged, the origin returns `304 Not Modified` (headers only). The edge refreshes the TTL and keeps serving the existing body — cheap.
5. If changed, the origin returns `200` with the new body and new validators. The edge replaces the object and serves fresh.
6. `stale-while-revalidate=30` improves step 3–4: the edge serves the stale copy *immediately* to the user and revalidates in the background, so no user waits on the origin round-trip.

**Versioned URL path:**
1. The build pipeline fingerprints assets: `app.js` → `app.a3f8b2c9.js`, and rewrites HTML references to the new names.
2. Assets are served with `Cache-Control: public, max-age=31536000, immutable` — cache for a year, never revalidate.
3. On the next deploy, contents change → new hash → new filename `app.7d1e40.js`. The HTML now points to the new URL.
4. Edges and browsers have never seen the new URL, so they fetch it fresh once, then cache it forever. The old `a3f8b2c9` object is never requested again and eventually evicts by LRU. No purge call is ever made.

**Active purge path:**
1. A content change triggers a purge — an API call to the CDN's control plane (e.g., `POST /purge` with a URL, or a `Surrogate-Key` value).
2. The control plane fans the invalidation out to every PoP. Fastly propagates in ~150ms; other CDNs take seconds. Until a PoP receives it, that PoP may still serve the old copy.
3. **Soft purge (mark-stale):** the object is marked stale rather than deleted; the next request triggers revalidation (and can serve stale-if-error). This avoids a hard cache gap.
4. **Hard purge (delete):** the object is removed outright; the next request is a full miss to origin.
5. Tag/surrogate-key purge: the control plane looks up every object bearing the tag and invalidates them together — one call, many objects.

**Failure and edge cases:**
- **Thundering herd on broad purge:** purge-everything (or purging a very hot object) makes many PoPs miss at once and fetch concurrently from origin. Mitigate with soft purge (serve stale during revalidation), request coalescing at the shield/tiered-cache layer, and origin request collapsing.
- **Propagation race:** during the seconds a purge is propagating, some users hit updated PoPs and some hit not-yet-updated PoPs — briefly inconsistent. Acceptable for most content; use versioned URLs where it isn't.
- **Browser cache is out of reach:** purge only affects the CDN. A browser holding `max-age` content won't re-fetch until its own TTL expires — hence versioned URLs for anything a browser caches aggressively.

**Parameters worth memorizing:**
- `max-age` (browser TTL) vs. `s-maxage` (CDN TTL) — `s-maxage` wins at the CDN.
- Immutable static assets: `max-age=31536000, immutable`.
- `stale-while-revalidate` / `stale-if-error` window sizes tune the resilience/freshness trade.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| **Fastly** | Instant purge (~150ms globally) plus **surrogate keys** for tag-based bulk invalidation; supports **soft purge** (mark stale + revalidate) | The reference implementation for fine-grained, near-real-time edge invalidation; heavily used by news/e-commerce sites that need fresh HTML at the edge |
| **Cloudflare** | Purge by single URL, by **cache-tag / prefix / hostname** (Enterprise), or **purge everything**; `Cache-Control` and page rules set TTLs; Tiered Cache reduces origin load | Purge typically propagates in seconds; cache tags require Enterprise plan; recommends versioned URLs for assets |
| **AWS CloudFront** | **Invalidation paths** (with wildcards like `/images/*`); first 1,000 paths/month free, then billed per path; propagation takes seconds to minutes | AWS explicitly recommends **versioned object names** over invalidation for static assets because invalidation is slower and costs money at scale |
| **Akamai** | **Fast Purge (CCU API)** with purge-by-URL and **Cache Tags**; supports invalidate (revalidate) vs. delete semantics; ~5s propagation | One of the largest edge networks; cache tags and "invalidate" (soft) vs. "delete" (hard) mirror the soft/hard purge distinction |
| **Vercel / Netlify (static hosting)** | Build pipeline **fingerprints assets** and serves them `immutable, max-age=31536000`; HTML served with short TTL + automatic purge on new deploy | Consumer-facing example of the versioned-URL strategy done automatically — deploys "just work" without manual purges |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| TTL-based expiry needs zero coordination and no control-plane calls | Staleness is bounded only by the TTL — shorter TTL means fresher content but more origin traffic and lower hit rate |
| Versioned URLs enable cache-forever hit rates and instant, purge-free updates — including in browsers | Only works for content you can rename on change; requires a build/fingerprint pipeline and HTML rewriting |
| Active purge gives near-real-time freshness for content you can't rename | Not globally instant; rate-limited and often billed; broad purges can stampede the origin |
| Tag / surrogate-key purge invalidates many related objects with one call | Requires the origin to attach and maintain correct tags; a mis-tag silently leaves stale content or over-purges |
| `stale-while-revalidate` hides origin latency and smooths refresh spikes | Users can briefly see stale content during the revalidation window — unacceptable for strongly-consistent data |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "After a deploy, how do users get the new JavaScript/CSS immediately?"
- "The CDN keeps serving an old version of the page after we update it — how do you fix that?"
- "We changed a product's price and it appears on dozens of pages. How do you invalidate all of them?"
- "How do you keep a CDN-fronted page fresh without hammering the origin?"

**What you say / do:**
This surfaces in the CDN/caching portion of a design — usually the deep dive on the read path. Split the answer by content type: "For static assets I'd fingerprint filenames and serve them `immutable, max-age=1 year`, so a deploy just changes the URL — instant update, no purge, and it even refreshes browser caches. For HTML and API responses I can't rename, I'd use a short `s-maxage` with `stale-while-revalidate`, tag each response with a surrogate key like `product-123`, and on a content change purge that tag — one call invalidates every page that shows the product. I'd avoid purge-everything on any routine path because it cold-starts every PoP and stampedes the origin."

**The trade-off statement (memorize this pattern):**
> "Versioned URLs give me instant, purge-free updates and cache-forever hit rates, but only for content I can rename. For content with stable URLs, active tag-based purge gives near-real-time freshness at the cost of propagation delay and origin-stampede risk. For this system — fingerprinted assets plus event-driven HTML changes — I'd combine immutable versioned assets with short-TTL, surrogate-key-purged HTML, and never purge everything on the hot path."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** Purging the CDN makes every user immediately see the new content.
  ✅ **Reality:** Purge only affects the CDN's edge caches, and even that isn't globally instant — it propagates PoP by PoP over milliseconds to seconds. Content already cached in end-user *browsers* is untouched and will keep serving until its own `max-age` expires. That browser-cache gap is exactly why versioned URLs exist for anything browsers cache aggressively.

- ❌ **Misconception:** A shorter TTL is always safer because content stays fresher.
  ✅ **Reality:** Shorter TTLs lower your cache-hit rate and push more traffic to the origin. Push it too low and the CDN barely helps — you get frequent revalidations and origin load spikes. The right TTL balances tolerable staleness against origin protection; for truly volatile content, pair a modest TTL with active purge rather than shrinking the TTL toward zero.

- ❌ **Misconception:** `max-age` and `s-maxage` are interchangeable.
  ✅ **Reality:** `max-age` sets the lifetime in *private* (browser) caches; `s-maxage` sets it in *shared* (CDN/proxy) caches and overrides `max-age` there. You routinely want them different — e.g., a long CDN TTL with active purge, but a short or zero browser TTL so users don't hold stale HTML you can't purge from their machines.

- ❌ **Misconception:** "Purge everything" is a safe, clean way to guarantee freshness.
  ✅ **Reality:** Flushing the whole cache makes every PoP miss simultaneously, so many edges fire concurrent origin fetches for the hottest objects at the same instant — a thundering herd that can overwhelm an origin that was comfortably shielded a moment earlier. Prefer targeted purge-by-tag; if you must flush broadly, use soft purge, pre-warming, or request coalescing at a shield tier.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** 6.1 CDN Architecture (PoPs and edge servers) — you can't reason about invalidation without knowing that content lives in many independent edge caches; and 5.5 Cache Consistency & Invalidation Strategies — edge invalidation is the same TTL/versioning/purge problem applied to a geographically distributed cache tier
- **Enables:** 6.5 CDN for static assets vs. dynamic content — the invalidation strategy is what determines whether a given content type is even *cacheable* at the edge; and 6.6 CDN for media delivery — versioned URLs and long TTLs are how large immutable media is cached forever
- **Tension with:** 5.8 Multi-Level Caching / cache consistency broadly — every additional cache layer (browser → edge → shield → origin) is another place content can go stale, and edge invalidation must account for all of them; the more tiers, the harder true freshness becomes

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. What are the three strategies for invalidating content at a CDN edge, and which content type does each best fit?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6.*

Three strategies:
TTL-based (passive)  — set s-maxage; edge expires on a clock. Best for content with a
                       known, tolerable staleness window (feeds, listings).
Versioned URLs       — fingerprint the filename; new content = new URL, cache forever.
                       Best for static assets (JS/CSS/images) on deploy.
Active purge (push)  — API command evicts objects before TTL. Best for HTML / API
                       responses with stable URLs you can't rename.

2. A user reports that after your deploy, they still see the old JavaScript even though you purged the CDN. What's happening and how should you have prevented it?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 13 (browser-cache boundary).*

The old JS is cached in the USER'S BROWSER, not the CDN. Purging the CDN doesn't touch
browser caches — the browser holds it until its own max-age expires. Prevention: serve
the asset from a fingerprinted/versioned URL (app.<hash>.js) with immutable, max-age=1y.
On deploy the filename changes, so the browser requests a URL it has never cached and
fetches fresh — no purge needed and no browser-cache staleness.

3. Explain how a `304 Not Modified` revalidation works and why it's cheaper than a normal re-fetch.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Sections 6 and 9.*

When a cached object goes stale, the edge sends a CONDITIONAL request to origin:
If-None-Match: "<etag>"  (or If-Modified-Since: <date>).
If the content is unchanged, origin returns 304 Not Modified with HEADERS ONLY — no body.
The edge just refreshes the object's TTL and keeps serving the copy it already holds.
Cheaper because no body bytes are transferred; only a small round-trip, not a full download.

4. Name a production CDN and describe its purge model, including tag-based invalidation.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 10.*

Fastly: instant purge (~150ms globally), plus SURROGATE KEYS for tag-based bulk purge.
The origin attaches Surrogate-Key: product-123 category-shoes to responses. When product
123 changes, one purge of the "product-123" key invalidates every cached page/fragment
tagged with it. Fastly also supports SOFT PURGE (mark stale + revalidate) vs. hard purge
(delete). (CloudFront alternative: invalidation paths with wildcards, slower + billed;
AWS recommends versioned URLs instead.)

5. Your team runs "purge everything" after each content update on a site doing 40,000 RPS. What failure mode does this risk, and what would you do instead?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Sections 9 and 13 (thundering herd).*

Failure mode: THUNDERING HERD on the origin. Purge-everything cold-starts every PoP at
once, so all edges simultaneously miss and fire concurrent origin fetches for the hottest
objects — the origin that was shielded a second ago now takes a synchronized flood.
Instead:
1. Purge by TAG / surrogate key — invalidate only the objects that actually changed.
2. Use SOFT PURGE — serve stale while revalidating so PoPs don't hard-miss.
3. Add a shield / tiered cache with REQUEST COALESCING so only one fetch per key hits origin.
4. If a broad flush is unavoidable, pre-warm hot objects or ramp traffic gradually.

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **MDN — HTTP Caching** — https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching — authoritative reference on Cache-Control, ETag, and revalidation semantics
- [ ] **Fastly — Purging & Surrogate Keys** — https://developer.fastly.com/learning/concepts/purging/ — the clearest model of instant, tag-based, and soft purge
- [ ] **Cloudflare — Cache Control & Purge** — https://developers.cloudflare.com/cache/ — how a large CDN exposes TTLs and purge granularities
- [ ] **AWS — Invalidating Files (CloudFront)** — https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html — invalidation cost/latency and why AWS recommends versioned URLs
- [ ] **Google web.dev — HTTP caching / cache-busting with fingerprinting** — https://web.dev/articles/http-cache — the versioned-URL strategy explained end to end

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

