# 6.1 CDN Architecture — PoPs and Edge Servers

> **Topic:** Topic 6 — CDN
> **Phase:** B — Scalability
> **Date studied:** 2026-06-23

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

A Content Delivery Network (CDN) is a geographically distributed network of servers (called Points of Presence, or PoPs) that caches and serves content close to end users, dramatically reducing round-trip latency. The core tension CDN architecture resolves is between **centralized origin simplicity** and **distributed edge performance**: you want a single source of truth for your content, but you need to serve it from dozens or hundreds of locations worldwide. Mastering CDN architecture means understanding how PoPs are structured, how requests are routed to the nearest edge server, and how the edge-to-origin relationship is managed.

### 🎯 What to Focus On

**1. PoP topology and what lives at the edge** — A PoP is not just a cache server. It contains load balancers, TLS terminators, caching layers, and sometimes compute (edge functions). Know what each component does and why co-locating them at the edge reduces latency.

**2. How a user request reaches the nearest PoP** — DNS-based routing and anycast are the two main mechanisms. Be able to explain each and why anycast is preferred for global scale. This is the first thing an interviewer will probe.

**3. Cache hit vs. cache miss path** — The performance contract only holds on a cache hit. On a miss, the edge must fetch from origin (cache fill). Know the full round-trip for both paths and the latency implications.

**4. Origin shield (mid-tier caching)** — Between the edge and the origin, many CDNs add a shield layer. This concentrates cache-miss traffic, protecting the origin from thundering herd at edge scale. Know why it exists and what it costs.

**5. When CDN helps and when it doesn't** — CDN is not a universal accelerator. It helps for static assets and cacheable content. It adds latency for non-cacheable API calls and personalized content. Knowing the limits is what separates a solid answer from a great one.

---

## 1. 🎯 Goal of This Subtopic

> *Why are you studying this? What should you be able to do after this session?*

Be able to describe the full architecture of a CDN — from DNS resolution that routes a user to the nearest PoP, through the edge server's cache lookup, to a cache miss that fills from origin via an origin shield — and explain why each component exists. Be able to identify which user requests benefit from CDN placement and which don't, and justify CDN inclusion (or exclusion) in any system design you are asked to evaluate.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can explain how a user in Singapore reaches an Akamai PoP rather than a US-based origin, naming the routing mechanism (DNS or anycast) and why it works
- [ ] Can draw the full request flow for both a cache hit and a cache miss, including the origin shield layer, and state the latency difference
- [ ] Can explain what a PoP contains (LB, TLS terminator, caching tier, optionally edge compute) and why each component is co-located at the edge
- [ ] Can explain the origin shield's purpose: concentrating cache-fill requests to protect origin from fan-out during a cache miss storm
- [ ] Can identify at least three content types that are poor CDN candidates and explain why

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] Read **"How CDNs Work" — Cloudflare Learning Center** (https://www.cloudflare.com/learning/cdn/what-is-a-cdn/)
- [ ] Read **"AWS CloudFront Architecture"** — AWS docs on distributions, edge locations, and origin shield
- [ ] Read **"ByteByteGo System Design Interview — Chapter on CDN"** (Alex Xu, Vol 1 Chapter 11)
- [ ] Read through **Sections 5–9** carefully — don't skim
- [ ] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **Core Definition** from memory, then compare
- [ ] Explain **First Principles** out loud — why does geographic distance cause latency? What problem does a PoP solve?
- [ ] Reconstruct the **cache hit vs. cache miss flow** step by step from memory
- [ ] Restate each **Trade-off** row in your own words — if you can't explain the cost, you don't own it yet

### Phase 3 — Apply 🔧 💪💪💪💪
*Goal: Connect to real systems and simulate interview scenarios.*

- [ ] Go through **Real-World System Examples** (Section 10) — verify each independently
- [ ] Practice **Interview Application** (Section 12) out loud — trigger phrases and responses
- [ ] Work through **Common Misconceptions** (Section 13) — explain *why* each is wrong
- [ ] Trace the **Relationships to Other Concepts** (Section 14) without looking

### Phase 4 — Validate 🧪 💪💪💪💪💪
*Goal: Confirm you actually own it, not just recognize it.*

- [ ] Answer every **Self-Check Quiz** question (Section 15) out loud without notes
- [ ] Recite the **Cheatsheet** (Section 4) from memory — if you can't, re-do Phase 2
- [ ] Tick off items in **What Mastery Looks Like** (Section 2) — only if demonstrable on demand
- [ ] Teach this concept out loud to an imaginary interviewer for 2 minutes without hesitation

---

## 4. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

```
ONE-LINER
  A CDN is a geographically distributed network of PoPs that serves cached content
  close to users, cutting latency by eliminating long-haul round trips to origin.

KEY PROPERTIES / RULES
  PoP = Point of Presence = edge datacenter (LB + TLS + cache + optionally compute)
  Routing to nearest PoP: DNS-based geo-routing OR anycast (anycast preferred at scale)
  Cache hit path: User → PoP → response (fast; no origin round trip)
  Cache miss path: User → PoP → Origin Shield → Origin → PoP (cache fill) → User
  Origin shield = mid-tier cache layer that concentrates cache-miss load to protect origin

DECISION RULE
  Use CDN when: serving static assets (JS/CSS/images), media (video segments), or
    globally distributed users with cacheable content (high cache hit ratio expected).
  Avoid CDN (or use carefully) when: content is user-specific/personalized,
    responses are non-cacheable (auth headers, no-store), or latency of a miss > benefit.

NUMBERS / FORMULAS
  Typical PoP-to-user latency: < 20ms for well-distributed CDN
  Cross-continental origin latency: 100–300ms (what CDN eliminates on cache hit)
  Cache hit ratio target: > 90% for CDN to be net-positive for latency
  Cloudflare: ~300 PoPs worldwide; Akamai: ~4,000+ edge servers globally

GOTCHA TO NEVER FORGET
  CDN adds latency on a cache MISS — if your cache hit ratio is low (e.g., personalized
  content), CDN makes things WORSE, not better.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

A CDN (Content Delivery Network) is a globally distributed network of edge servers — organized into Points of Presence (PoPs) — that cache and serve content from locations physically close to end users, reducing latency by eliminating long round trips to a centralized origin server. A PoP is the atomic unit of CDN infrastructure: a co-located cluster of load balancers, TLS terminators, and caching servers deployed in Internet Exchange Points (IXPs) and carrier-neutral datacenters worldwide.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic.*

### Point of Presence (PoP)
A PoP is a CDN's edge datacenter — a physical location where the CDN operates servers close to end users. A typical PoP includes: an Anycast IP receiver or DNS resolution handler, one or more load balancers, TLS termination infrastructure (so TLS handshakes complete locally), a multi-layer cache (often L1 in-memory + L2 SSD), and increasingly, edge compute (Cloudflare Workers, Lambda@Edge). PoPs are strategically placed at Internet Exchange Points (IXPs) to peer directly with ISPs, minimizing network hops to reach users.

### Edge Server
An edge server is an individual server within a PoP that handles user requests. It checks its local cache for the requested content; on a hit, it responds immediately. On a miss, it fetches from the origin (or origin shield) and caches the response for subsequent requests. Edge servers are stateless with respect to business logic — their only job is cache lookup and cache fill.

### Origin Shield (Mid-Tier Cache)
An origin shield is an optional but critical intermediate caching layer between edge PoPs and the origin server. When hundreds of PoPs simultaneously miss the same object (e.g., after a cache invalidation or a popularity spike), they would each independently fetch from origin — creating an N×traffic amplification. The origin shield acts as a single rendezvous point: all PoPs funnel cache-miss requests through it, so the origin sees at most one fetch per object regardless of how many PoPs request it simultaneously. This is essential for protecting origin at CDN scale.

### Cache Fill and Cache Hit Ratio
Cache fill is the process of fetching content from origin to populate the edge cache after a miss. The cache hit ratio (CHR) is the fraction of requests served from cache without hitting origin. CHR is the primary CDN effectiveness metric: a CHR of 95% means only 5% of requests travel to origin. CHR is driven by content TTL, content uniqueness (highly personalized = low CHR), and the request volume per object (more requests → higher CHR for a given TTL).

### Routing to the Nearest PoP
Two mechanisms route users to their nearest PoP: **DNS-based geo-routing** uses the requester's IP to select a geographically appropriate DNS response (simple, but resolution latency and EDNS client subnet support affect accuracy); **Anycast routing** assigns the same IP address to all PoPs and relies on BGP to route packets to the topologically closest PoP (more accurate, lower latency, no DNS TTL limitation). Anycast is preferred for latency-sensitive CDNs (Cloudflare uses it extensively).

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve?*

The speed of light is finite. A round trip from Singapore to a US East Coast server takes approximately 200–300ms at the physical limit — and real network routing adds more on top. For web content, this means every asset (image, JS file, video segment) paid this latency tax on every request. Early internet content was hosted in single datacenters because storage and compute were expensive; geographic distribution was cost-prohibitive.

As bandwidth costs fell and static content (images, video, scripts) became the dominant volume of internet traffic, the latency problem became critical. Users in Tokyo shouldn't pay the latency cost of a server in Virginia for a static JavaScript file that hasn't changed in weeks. The solution is obvious in retrospect: cache the content close to where users are. CDNs were born to do exactly that — Akamai's founding insight in 1998 was that you could dramatically improve web performance by distributed caching near the network edge, without requiring website owners to operate their own global infrastructure.

---

## 8. 🗺️ Mental Models

> *Intuition frames for reasoning under interview pressure.*

### Model 1: The Library Branch Network
Think of the CDN as a public library system. The main library (origin) has every book (all content). Branch libraries (PoPs) hold popular books locally — anyone nearby can check them out instantly. If a branch doesn't have the book, they order it from the main library and keep a copy for future requests. The origin shield is a regional distribution center: branch libraries request from the regional hub, not directly from the main library, so the main library doesn't get a thousand simultaneous orders for the same new bestseller. **Where the model breaks:** library books don't expire — in CDNs, TTL means your "copy" may go stale and need to be discarded even if it hasn't been replaced yet.

### Model 2: Cache Hit Ratio Is Your CDN's Report Card
The CDN is only as good as its cache hit ratio. Every miss is a tax — you paid CDN fees, added a hop in the network, and still made an origin round trip. A CDN with 50% CHR on personalized API responses is not improving performance; it's adding infrastructure complexity and cost with no latency benefit. Before adding CDN to a design, estimate the CHR: how cacheable is the content, how long is the TTL, how many requests per object will warm the cache?

### Model 3: Anycast as "Nearest Subway Station"
Anycast routing is like a city where every subway station has the same address — you just enter "subway" into your navigation app and it routes you to the one physically nearest you. BGP does the routing automatically based on network topology. The beauty: if a PoP goes down, BGP reconverges and automatically routes traffic to the next-nearest PoP. No manual failover needed. **Where it breaks:** BGP convergence isn't instant (seconds to minutes), so during a PoP failure there's a brief disruption window.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step mechanics.*

**Cache Hit Path (happy path):**
1. User's browser issues a DNS query for `cdn.example.com`
2. CDN's DNS (or anycast routing) resolves to the nearest PoP's IP
3. TLS handshake completes at the PoP (not origin — this saves 1–2 round trips)
4. Edge server checks its local cache: object found and not expired → **cache HIT**
5. Edge server returns the cached response with `Age: <seconds>` and `X-Cache: HIT` headers
6. Total latency: ~10–30ms depending on PoP proximity

**Cache Miss Path:**
1. Steps 1–3 same as above
2. Edge server checks cache: object not found or expired → **cache MISS**
3. Edge forwards request to **origin shield** (if configured)
4. Origin shield checks its cache: hit → returns to edge; miss → forwards to origin server
5. Origin generates response, returns to origin shield → shield caches it → forwards to edge
6. Edge caches the response (per `Cache-Control` headers) and returns to user
7. Total latency: 20–30ms (PoP) + 50–200ms (shield-to-origin) depending on geography

**Key parameters:**
- `Cache-Control: max-age=<seconds>` — how long the edge caches the object
- `Cache-Control: s-maxage=<seconds>` — CDN-specific override of max-age
- `Cache-Control: no-store` — CDN must not cache (every request hits origin)
- `Surrogate-Key` / `Cache-Tag` headers — enable tag-based purging of related objects

**TLS termination at the edge:**
The TLS handshake is one of the most latency-expensive operations in HTTPS (1–2 round trips just for the handshake). By terminating TLS at the nearest PoP, the CDN ensures the handshake completes in ~20ms (PoP proximity) rather than ~200ms (origin proximity). The PoP-to-origin connection uses a persistent, pre-warmed TLS tunnel, so the user sees only the PoP-proximity handshake latency.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| **Cloudflare** | Uses anycast routing across ~300 PoPs globally; TLS terminates at edge; edge compute (Workers) runs at every PoP | Industry leader in anycast CDN; also provides DDoS scrubbing at edge |
| **AWS CloudFront** | ~600 edge locations + 13 regional edge caches (origin shield); integrates natively with S3, EC2, ALB as origins | Regional edge cache = CloudFront's origin shield implementation |
| **Akamai** | ~4,000+ edge servers; pioneered CDN for web content delivery; uses DNS-based routing with EDNS client subnet for accuracy | Largest CDN by edge node count; used heavily for media delivery |
| **Netflix Open Connect** | Netflix operates its own CDN (Open Connect Appliances) co-located inside ISP networks — the most extreme form of PoP proximity | ISP-embedded CDN; eliminates transit costs entirely; only practical at Netflix scale |
| **Fastly** | PoP-based CDN with instant purging API; Surrogate-Key headers enable tag-based invalidation of thousands of objects in <150ms | Favored by media companies (New York Times, GitHub) for its purging speed |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Dramatically reduces latency for globally distributed users (20ms vs. 200ms) | Cache misses add a network hop; if CHR is low, CDN makes performance worse |
| Reduces origin load — high CHR means origin handles only a fraction of total requests | Additional infrastructure complexity: TTL tuning, invalidation strategy, CDN vendor lock-in |
| TLS termination at edge eliminates long-distance handshake latency | Non-cacheable content (personalized, auth-required) receives no latency benefit and incurs CDN overhead |
| DDoS absorption at edge — traffic is scrubbed before reaching origin | Cost: CDN vendors charge per-GB egress; high-traffic sites pay significantly for CDN bandwidth |
| Origin shield concentrates cache-fill load, protecting origin from thundering herd | Origin shield adds one more network hop on a miss, slightly increasing cache-miss latency |
| Anycast provides automatic failover when a PoP goes down | BGP reconvergence during PoP failure takes seconds–minutes; brief disruption window |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview?*

**When an interviewer asks / says:**
- "How would you handle users in Asia accessing your US-hosted service?"
- "Your static assets are slow for users in Europe — what do you do?"
- "How do you reduce load on your origin servers?"
- "Walk me through the request path from a user to your content"

**What you say / do:**
Introduce CDN during the high-level design phase when you identify geographically distributed users or heavy static asset serving. Draw the PoP layer explicitly between users and origin. State your assumption about cache hit ratio and tie it to the content type (static assets = high CHR; personalized API = low CHR). Always mention origin shield if scale is large enough that cache-miss fan-out to origin is a concern.

**The trade-off statement (memorize this pattern):**
> "If we add CDN, we get sub-30ms latency for our static assets globally, but we pay for CDN bandwidth and need to manage cache invalidation carefully. For this system serving static JS/CSS and user-uploaded images, CDN is clearly the right call — but I'd explicitly exclude our personalized feed API from CDN since it's non-cacheable and CDN would just add a hop."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong?*

- ❌ **Misconception:** CDN always improves performance
  ✅ **Reality:** CDN only improves performance on a cache HIT. For non-cacheable content (personalized responses, `no-store` headers), CDN adds a network hop and makes latency slightly worse. Always ask "what is my expected cache hit ratio?" before adding CDN.

- ❌ **Misconception:** CDN is only for static files
  ✅ **Reality:** Modern CDNs accelerate dynamic content too — through TCP connection pre-warming (persistent tunnels to origin), edge compute (Cloudflare Workers run arbitrary logic at the PoP), and dynamic content caching with short TTLs. The distinction is not static vs. dynamic but cacheable vs. non-cacheable.

- ❌ **Misconception:** You need to host your own CDN for large scale
  ✅ **Reality:** Even Netflix uses a CDN (their own Open Connect) but that's exceptional — built to eliminate ISP transit costs at hundreds-of-Gbps scale. For virtually all systems at interview scale, a managed CDN (Cloudflare, CloudFront, Fastly) is the correct answer. Building your own CDN is a distraction unless you're designing "design Netflix at Netflix scale."

- ❌ **Misconception:** DNS-based geo-routing is as accurate as anycast
  ✅ **Reality:** DNS geo-routing maps the requesting DNS resolver's IP (not the user's IP) to a PoP. Since many users share a corporate or ISP resolver in a different location, the routing can be inaccurate. Anycast uses BGP, which routes at the packet level based on actual network topology — far more accurate and without the EDNS client subnet dependency.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics?*

- **Builds on:** Topic 5 (Caching Systems) — CDN edge servers are distributed caches; the same concepts of cache hit/miss, TTL, eviction, and invalidation apply. A CDN PoP is essentially a geographically distributed cache-aside layer.
- **Enables:** Topic 6.2 (Pull vs. Push CDN) — understanding PoP architecture is the prerequisite for reasoning about how content gets *into* the PoP (pull on first miss vs. push pre-population); Topic 6.3 (Cache Invalidation at the Edge) — invalidating across hundreds of PoPs is the hardest CDN operational challenge.
- **Tension with:** Topic 6.3 (Cache Invalidation) — longer TTLs improve CDN effectiveness (higher CHR) but make it harder to push fresh content to users quickly. This TTL vs. freshness tension is the central CDN operational challenge.

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking?*

1. What is a Point of Presence (PoP) and what components does it typically contain?

   > 💡 *Think through the full component list before checking — if you forget TLS termination, revisit Section 6.*
A PoP (Point of Presence) is an edge datacenter deployed at Internet Exchange Points (IXPs) and carrier-neutral facilities close to end users. It typically contains: a load balancer (distributes traffic across edge servers), a TLS terminator (handles HTTPS handshake locally, ~10ms vs ~150ms to origin), an L1 cache (in-memory, sub-ms lookup), an L2 cache (SSD, ~1–5ms), and optionally edge compute (Cloudflare Workers, Lambda@Edge). The IXP placement is what makes it "close" — direct peering with ISPs minimizes network hops.

2. A user in Tokyo requests a JavaScript file served from a CDN with a US-based origin. Walk through the complete request path assuming it's a cache HIT at the Tokyo PoP.

   > 💡 *Can you name the routing mechanism that sent the user to the Tokyo PoP? Revisit Section 6 (Anycast) if unsure.*
a. User's browser issues DNS query for the CDN hostname → anycast BGP routes to Tokyo PoP IP
b. TLS handshake completes at Tokyo PoP (~10ms, not 150ms to origin)
c. Edge server checks L1 (RAM) → hit; or L1 miss → L2 (SSD) → hit
d. Response returned with Age and X-Cache: HIT headers
e. Total: ~10–30ms depending on user-PoP distance. Origin never contacted.

3. What is an origin shield and why does it exist? What failure mode does it prevent?

   > 💡 *The answer involves a specific failure mode at CDN scale — if you can't name it, revisit Section 6 (Origin Shield).*
An origin shield is a mid-tier caching layer sitting between all edge PoPs and the origin server. It exists because when N PoPs simultaneously miss the same object (e.g., after a cache invalidation or TTL expiry), all N would independently fetch from origin — creating N× traffic amplification. The shield acts as a single rendezvous point: all PoP misses funnel through it, and it issues exactly 1 fetch to origin regardless of how many PoPs requested it. The failure mode it prevents is thundering herd at CDN scale.

4. Cloudflare uses anycast routing. AWS CloudFront uses DNS-based routing. What is the practical difference in routing accuracy and why does it matter?

   > 💡 *Think about what each mechanism uses to determine "nearest" — DNS resolver IP vs. actual BGP topology.*
DNS geo-routing maps the DNS resolver's IP (not the user's IP) to a PoP. Corporate or ISP resolvers are often shared across many users and may be in a different city or country — so all those users get routed to the PoP near the resolver, not near themselves. Anycast assigns the same IP to all PoPs and lets BGP route each packet to the topologically nearest PoP at the network level — accurate regardless of resolver location. Anycast is also faster to failover: if a PoP goes down, BGP reconverges automatically in seconds. DNS-based failover is bounded by DNS TTL (30–300s).

5. A candidate says "I'll put a CDN in front of our user profile API to reduce origin load." What's wrong with this? Under what conditions might it actually be correct?

   > 💡 *The answer depends on the cache hit ratio — think about what makes an API response cacheable or not.*
A user profile API returns personalized data — different response per user, per session. CHR ≈ 0%. Adding CDN adds a network hop with zero cache benefit, making latency slightly worse. It could be correct under two conditions: (1) dynamic content acceleration — the PoP maintains a pre-warmed persistent TCP/TLS tunnel to origin, so the user pays only the user→PoP handshake cost (~10ms) rather than the full user→origin cost (~200ms); (2) partial cacheability — if the profile API embeds any shared components (trending items, public metadata), those can be cached at the edge via ESI (Edge Side Includes) while personalized fields are fetched from origin and merged.

---

## 16. 📚 Further Reading

> *High-quality resources for deeper understanding.*

- [ ] **Cloudflare Learning Center — "What is a CDN?"** — https://www.cloudflare.com/learning/cdn/what-is-a-cdn/ (best free overview)
- [ ] **AWS CloudFront Developer Guide — "How CloudFront Delivers Content"** — docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/HowCloudFrontWorks.html
- [ ] **"Scaling Instagram Infrastructure" — USENIX 2016** — discusses CDN and object storage at Instagram scale
- [ ] **ByteByteGo System Design Interview Vol. 1 — Chapter 11 (Design a CDN)** — Alex Xu's treatment covers PoP architecture and push vs. pull
- [ ] **"Netflix Open Connect" — Netflix Tech Blog** — https://netflixtechblog.com/open-connect-meets-netflix-performance-in-home-networks-82c33eb5f2a4

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

