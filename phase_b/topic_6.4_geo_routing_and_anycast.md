# 6.4 Geo-routing and Anycast

> **Topic:** Topic 6 — CDN
> **Phase:** B — Scalability
> **Date studied:** 2026-06-25

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

Geo-routing and anycast are the two primary mechanisms CDNs use to direct a user's request to the geographically or topologically closest edge server. Geo-routing uses DNS-level intelligence to resolve a domain to the nearest PoP's IP based on the client's location. Anycast advertises the same IP prefix from multiple PoPs simultaneously, letting BGP routing naturally steer packets to the closest announcing node. Together, these techniques minimize round-trip time (RTT) between users and the edge — the fundamental lever CDNs pull to reduce latency. Mastering this topic means understanding not just how traffic gets routed, but why each mechanism is used, when one outperforms the other, and how they interact with DDoS scrubbing and failover.

### 🎯 What to Focus On

**1. Anycast mechanics** — The same IP is announced from multiple PoPs via BGP. Understand why BGP naturally routes to the "nearest" announcer (AS path length + route metrics), and why "nearest" means topologically closest in BGP terms, not geographically closest.

**2. DNS-based geo-routing** — Authoritative DNS returns different A records based on the resolver's IP geolocation. Know the full resolution path: client → recursive resolver → authoritative DNS with geo-logic → PoP IP. Understand why resolver IP, not client IP, is what the authoritative DNS sees — and the accuracy implications.

**3. Anycast vs. DNS geo-routing trade-offs** — Anycast is faster (no DNS latency for per-request routing) and ideal for UDP-based protocols like DNS itself. DNS geo-routing is more flexible and supports per-user routing policies. Know when each is preferred.

**4. Failover behavior** — With anycast, PoP failure causes BGP to withdraw the route; traffic automatically re-converges to the next-closest announcer. With DNS geo-routing, TTL determines how long clients stay on a failed PoP — short TTL = faster failover but higher DNS load.

**5. The latency vs. accuracy tension** — Geo-routing accuracy depends on the quality of IP geolocation databases and the relationship between resolver location and user location. EDNS Client Subnet (ECS) partially solves this. Know the tradeoff.

---

## 1. 🎯 Goal of This Subtopic

> *Why are you studying this? What should you be able to do after this session?*

After studying this, you should be able to explain how a CDN routes a user in Tokyo to a Tokyo PoP rather than a US origin — covering both the DNS geo-routing path and the anycast BGP path. You should be able to compare the two mechanisms on accuracy, latency, failover speed, and protocol suitability, and select the right one for a given interview scenario. You should also know how EDNS Client Subnet and BGP route withdrawal enable accurate routing and automatic failover respectively.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can explain the anycast BGP mechanism step by step: same IP prefix announced from multiple PoPs, BGP selects shortest AS path, packets reach nearest announcer — without notes
- [ ] Can trace the full DNS geo-routing path (client → recursive resolver → authoritative DNS → PoP A record) and explain why the authoritative server sees the resolver IP, not the client IP
- [ ] Can compare anycast vs. DNS geo-routing on five dimensions: routing latency, accuracy, failover speed, protocol support, and operational complexity
- [ ] Can explain EDNS Client Subnet (ECS): what problem it solves, how it works, and its privacy trade-off
- [ ] Can describe the failover behavior for both mechanisms: BGP route withdrawal (anycast) vs. TTL expiry (DNS geo-routing) and the latency implications of each

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] **Cloudflare blog — "Load Balancing without Load Balancers" (anycast)** — [blog.cloudflare.com](https://blog.cloudflare.com/cloudflares-architecture-eliminating-single-points-of-failure/) — explains how anycast powers Cloudflare's global network
- [ ] **AWS Route 53 routing policies docs** — [docs.aws.amazon.com/Route53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html) — DNS geo-routing in practice (latency-based, geolocation, geoproximity)
- [ ] **RFC 7871 — EDNS Client Subnet** — [tools.ietf.org](https://tools.ietf.org/html/rfc7871) — original ECS spec; skim the motivation and overview sections
- [ ] Read Sections 5–9 of this doc carefully — don't skim
- [ ] Re-read the Cheatsheet (§4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the Core Definition from memory, then compare
- [ ] Explain First Principles out loud without notes — what problem does geo-routing solve and why?
- [ ] Reconstruct the anycast BGP path and the DNS geo-routing path from memory
- [ ] Restate each Trade-off row in your own words — if you can't explain the cost, you don't own it yet

### Phase 3 — Apply 🔧 💪💪💪💪
*Goal: Connect to real systems and simulate interview scenarios.*

- [ ] Go through Real-World System Examples (§10) — verify each claim independently and add anything missed to My Notes
- [ ] Practice the Interview Application (§12) out loud — say the trigger phrases and your response as if in a live interview
- [ ] Work through Common Misconceptions (§13) — for each, make sure you can explain *why* the misconception is wrong, not just that it is
- [ ] Trace the Relationships to Other Concepts (§14) — can you explain each connection without looking?

### Phase 4 — Validate 🧪 💪💪💪💪💪
*Goal: Confirm you actually own it, not just recognize it.*

- [ ] Answer every Self-Check Quiz question (§15) out loud without looking at your notes
- [ ] Recite the Cheatsheet (§4) from memory — if you can't, re-do Phase 2
- [ ] Tick off items in What Mastery Looks Like (§2) — only check a box if you can demonstrate it on demand, not just if it sounds familiar
- [ ] Teach this concept out loud to an imaginary interviewer for 2 minutes without hesitation or notes

---

## 4. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

```
ONE-LINER
  Geo-routing directs each user to the nearest CDN PoP via DNS (geo-aware A records)
  or anycast (same IP, BGP picks closest announcer) — cutting RTT from 200ms to <20ms.

KEY PROPERTIES / RULES
  Anycast: same /24 or /48 prefix announced from every PoP via BGP; routers
    converge packets to the topologically nearest announcer automatically.
  DNS geo-routing: authoritative DNS returns different A records per resolver region;
    accuracy depends on resolver IP location and geolocation DB quality.
  EDNS Client Subnet (ECS): DNS resolver forwards a /24 client IP prefix to the
    authoritative server so it can route on actual user location, not resolver.
  Anycast failover: PoP withdraws BGP route → traffic re-converges in seconds.
  DNS failover: bounded by TTL; use short TTL (30–60s) for fast failover.

DECISION RULE
  Use anycast when: routing UDP traffic (DNS, QUIC, DTLS), need sub-second failover,
    or want zero per-request DNS overhead. Ideal for DDoS scrubbing at edge.
  Use DNS geo-routing when: need fine-grained per-user policies (country/city level),
    TCP-based traffic (HTTPS), or when operational simplicity of DNS is preferred.
  Use both: most large CDNs combine anycast for L3/L4 + DNS geo-routing for L7.

NUMBERS / FORMULAS
  Typical transcontinental RTT without CDN: 150–300ms
  Typical RTT from user to nearest CDN PoP: 5–30ms
  BGP re-convergence after route withdrawal: 30–120s (fast failover: <5s with BFD)
  DNS TTL for geo-routed records: 30–300s (balance freshness vs. resolver caching)
  ECS prefix length: /24 for IPv4, /56 for IPv6 (privacy vs. accuracy trade-off)

GOTCHA TO NEVER FORGET
  With DNS geo-routing, the authoritative DNS sees the RECURSIVE RESOLVER's IP,
  not the client's IP — a user in Tokyo using Google's 8.8.8.8 resolver may get
  routed to a US PoP. ECS partially fixes this but not all resolvers support it.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

Geo-routing and anycast are complementary traffic steering mechanisms that ensure each user's request is handled by the CDN PoP with the lowest round-trip time: anycast achieves this at the network layer by advertising a single IP from all PoPs and letting BGP route to the nearest announcer, while DNS geo-routing achieves it at the application layer by resolving a domain to the A record of the nearest PoP based on the client's inferred location.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*

### Anycast IP Routing
A network addressing scheme where the same IP prefix (e.g., `192.0.2.0/24`) is announced by multiple autonomous systems (PoPs) simultaneously via BGP. When a packet is sent to that IP, the internet's routing infrastructure delivers it to whichever announcer is topologically closest as measured by BGP path selection (AS path length, local preference, MED). This requires no per-request DNS lookup for routing — the routing decision happens at the IP level. Cloudflare's entire network (300+ PoPs) operates on a handful of anycast prefixes.

### DNS-Based Geo-routing
The authoritative DNS server for a CDN domain inspects the source IP of the incoming DNS query (which comes from the recursive resolver, not the end user) and returns a different A record based on the inferred geography of that resolver. For example, a resolver in Singapore gets `203.0.113.10` (Singapore PoP), while a resolver in Frankfurt gets `198.51.100.20` (Frankfurt PoP). The routing decision happens at DNS resolution time, before any TCP connection is established.

### EDNS Client Subnet (ECS)
An extension to DNS (RFC 7871) where the recursive resolver includes a truncated version of the client's IP address (e.g., the /24 prefix) in the query to the authoritative DNS server. This allows the authoritative server to route based on the actual user's location rather than the resolver's location — critical when a user in Tokyo is using a resolver in the US. The trade-off is reduced privacy (client IP prefix is visible to the authoritative server and potentially logged).

### BGP Route Withdrawal and Re-convergence
When a PoP goes offline, it withdraws its BGP route announcements. Neighboring routers detect the withdrawal and propagate the change through the BGP mesh. Traffic that was flowing to the failed PoP automatically re-routes to the next-closest PoP as BGP reconverges — typically within 30–120 seconds without optimization, or under 5 seconds with Bidirectional Forwarding Detection (BFD). This is the automatic failover mechanism for anycast deployments.

### Geolocation Database Accuracy
DNS geo-routing depends on IP geolocation databases (MaxMind, IP2Location, etc.) to map resolver IPs to geographic regions. These databases are imperfect — IP blocks change ownership, VPNs and proxies obscure real location, and mobile carrier NATs can aggregate users from large regions behind a single IP. Geolocation accuracy is typically 95–99% at the country level but drops to 70–80% at the city level.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

The root problem is the speed of light. A packet traveling between Sydney and London covers roughly 17,000 km of fiber, and light propagates through fiber at ~200,000 km/s — meaning a one-way trip takes at least 85ms, giving a minimum RTT of 170ms. For a web page requiring 10 round trips, that's 1.7 seconds of irreducible latency — even if every server is instant.

The only solution is to move the server closer to the user. CDNs do this by deploying PoPs globally. But moving the server is only half the battle — you also need to reliably route each user to their nearest PoP. Without routing intelligence, DNS would always return the same IP (the origin), defeating the purpose.

Geo-routing and anycast solve the routing half of the problem. They ensure that a user in Singapore isn't routed to a US PoP when a Singapore PoP exists and is healthy. The consequence of getting this wrong isn't a correctness failure — the page still loads — but a latency failure: the user experiences origin-like latency even though a PoP is 20ms away.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*

### Model 1: The Post Office Network
Imagine a postal service that has thousands of sorting facilities worldwide. When you send a letter (packet), the postal system naturally routes it through the facility nearest to the destination — not because each letter carries routing instructions, but because the routing infrastructure has been pre-configured to send mail toward the closest facility. Anycast works identically: the IP prefix is like a "class of address" that any facility can accept, and the BGP routing mesh is the postal routing logic that directs packets to the closest claimant. *Where it breaks down:* BGP "closest" means fewest AS hops, not fewest kilometers — a geographically distant PoP with a better peering relationship can win over a physically closer one with worse BGP metrics.

### Model 2: The Smart Receptionist (DNS Geo-routing)
Think of the authoritative DNS server as a receptionist at a multinational company's main number. When you call in, the receptionist asks "where are you calling from?" and transfers you to the nearest regional office. The catch: the receptionist can only see the caller ID of the phone exchange (the recursive resolver), not your actual phone number. ECS is like telling the exchange to include your area code in the transfer request so the receptionist can route you more accurately. *Where it breaks down:* the receptionist's city database might be wrong, and once you're transferred, the routing decision is locked in for the duration of the DNS TTL — even if that office becomes unavailable mid-call.

### Model 3: The Two-Layer Routing Model
In production CDNs, geo-routing and anycast often work in tandem at different layers. Anycast handles L3/L4 steering (which datacenter receives the packet at the IP level), while DNS geo-routing handles L7 steering (which cluster or cache tier within a region serves the request). Think of anycast as choosing the city and DNS geo-routing as choosing the building within that city. This layered model is why you'll see Cloudflare use anycast globally but AWS CloudFront use DNS-based latency routing — different architectural philosophies for the same end goal.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

### Anycast — Happy Path

1. CDN operator announces the same IP prefix (e.g., `104.16.0.0/12`) from all PoPs via BGP to their upstream transit providers and peering partners.
2. Internet routers build routing tables where packets to `104.16.x.x` are forwarded toward whichever PoP has the best BGP path from that router's vantage point.
3. User in Tokyo sends an HTTPS request to `cdn.example.com` (resolved to `104.16.1.1`). Tokyo's ISP router forwards to Cloudflare's Tokyo PoP because it has the shortest AS path.
4. The Tokyo PoP terminates the TCP/TLS connection and serves the response from cache.

### Anycast — Failure Path

1. Tokyo PoP goes offline; its BGP sessions drop. Neighbors detect the missing announcements and withdraw the route.
2. BGP reconvergence propagates the withdrawal across the internet (~30–120s, or <5s with BFD).
3. Packets now route to the next-best PoP (e.g., Osaka or Seoul) without any client-side action — no DNS change, no connection reset for new connections.

### DNS Geo-routing — Happy Path

1. User in Frankfurt resolves `cdn.example.com`. The OS sends the query to its configured recursive resolver (e.g., `8.8.8.8`).
2. Google's recursive resolver queries the CDN's authoritative DNS server, identifying itself as coming from `8.8.8.8` (Mountain View, CA).
3. Without ECS, the authoritative server guesses the user is in the US and returns the US PoP IP. *With ECS*, the resolver includes the client's `/24` prefix (e.g., `212.95.0.0/24`, a Frankfurt block), and the authoritative server returns the Frankfurt PoP IP.
4. The resolver caches the response for the TTL (e.g., 60 seconds). All subsequent queries from that resolver get the same Frankfurt IP until TTL expires.

### DNS Geo-routing — Failure Path

1. Frankfurt PoP goes offline. Health checks detect the failure.
2. The authoritative DNS server updates its response: queries for Frankfurt resolver IPs now return the Amsterdam PoP IP instead.
3. However, clients with a cached Frankfurt PoP IP continue hitting the failed PoP until their cached TTL expires (up to 60 seconds if TTL = 60s). Short TTLs reduce this window at the cost of higher DNS query volume.

### Key Formulas and Thresholds

- **Minimum RTT** = 2 × (distance in km / 200,000 km/s) + processing time
- **BGP convergence** without BFD: 30–120s; with BFD: 1–5s
- **DNS TTL trade-off**: TTL 30s → failover in ≤30s, but 2× DNS query volume vs. TTL 60s
- **ECS prefix**: /24 for IPv4 preserves enough locality for geo-routing while limiting identifier precision to a ~256-user range

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| Cloudflare | Pure anycast — all 300+ PoPs announce the same IP prefixes; BGP steers every packet at L3 | Enables Cloudflare to absorb DDoS traffic globally without DNS changes |
| AWS CloudFront | DNS latency-based routing — Route 53 measures latency from resolver to each CloudFront region and returns the lowest-latency endpoint | Uses actual measured latency, not just geolocation — more accurate than pure IP-geo |
| Akamai | DNS geo-routing with global traffic management; Akamai's authoritative DNS (GSLB) returns PoP IPs based on resolver geography and PoP health | Combines geo-routing with real-time health checks to exclude unhealthy PoPs |
| Google (8.8.8.8 DNS) | Anycast — Google's public DNS resolver is reachable via anycast; your nearest Google datacenter responds | Same concept deployed at the DNS resolver level, not just CDN |
| Fastly | Anycast at the edge; DNS for origin routing | Uses anycast to handle user-to-edge routing, DNS for edge-to-origin selection |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Anycast: automatic failover via BGP route withdrawal — no operator action needed | BGP convergence takes 30–120s without BFD; clients experience errors during reconvergence |
| Anycast: no per-request DNS lookup for routing — routing at packet level | BGP "nearest" is topological, not geographic — a poorly peered close PoP may lose to a well-peered far PoP |
| DNS geo-routing: fine-grained per-user policies (country, city, ISP level) | Routing accuracy depends on recursive resolver location, not user location — resolver can be on another continent |
| DNS geo-routing: supports complex routing policies (weights, failover groups, health checks) | Short TTL needed for fast failover increases DNS query volume significantly |
| ECS improves DNS geo-routing accuracy by exposing client /24 prefix | ECS reduces user privacy — client IP prefix is visible to authoritative DNS and can be logged |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "The service needs to be globally available with low latency for users in every region"
- "How does the CDN route a user in Tokyo to the Tokyo PoP instead of the US origin?"
- "How does the system handle a CDN PoP going down without user-visible interruption?"
- "We need DDoS protection at the edge — how does traffic get absorbed globally?"

**What you say / do:**
In a CDN or globally distributed system design, introduce geo-routing during the high-level design when placing PoPs: "Each PoP announces an anycast prefix, so BGP naturally steers users to their nearest PoP — no per-request DNS overhead and automatic failover via route withdrawal." If the interviewer probes on DNS, add: "We use DNS geo-routing with 60-second TTL and health checks so if a PoP is degraded, we reroute within one TTL window."

**The trade-off statement (memorize this pattern):**
> "If we choose anycast, we get automatic BGP-driven failover and zero per-request routing latency, but we pay with 30–120 second reconvergence windows and imprecise geographic targeting due to BGP topology. For DDoS protection and global DNS resolution, anycast is the right call; for fine-grained user-level routing policies, DNS geo-routing gives us more control."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** "Anycast routes to the geographically nearest PoP."
  ✅ **Reality:** Anycast routes to the topologically nearest announcer as determined by BGP path selection — which is based on AS hop count, local preference, and MED, not geographic distance. A PoP with a shorter AS path can win over a physically closer PoP with worse peering.

- ❌ **Misconception:** "DNS geo-routing sees the user's actual IP address."
  ✅ **Reality:** The authoritative DNS server sees the recursive resolver's IP, not the end user's IP. A user in Tokyo using Google's 8.8.8.8 resolver may get routed to a US PoP. ECS partially addresses this but requires resolver support and has privacy implications.

- ❌ **Misconception:** "Short DNS TTL means instant failover."
  ✅ **Reality:** TTL determines when the cache entry expires, but clients that have already cached the old IP will keep using it until their TTL expires. Failover latency is bounded by the TTL of the cached record — not instant. Also, some resolvers and OS-level caches ignore TTL and cache longer.

- ❌ **Misconception:** "Anycast and DNS geo-routing are alternatives — you pick one."
  ✅ **Reality:** Production CDNs commonly use both in a layered model: anycast for L3/L4 routing (which PoP receives the packet at the IP level) and DNS for L7 routing (which cache cluster or origin to use within a region). Cloudflare uses anycast globally; AWS uses DNS-based latency routing — but even AWS CloudFront still uses anycast internally for certain services.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** 6.1 CDN Architecture — PoPs and Edge Servers (the PoP network that geo-routing and anycast operate over); 4.7 Global vs. Local Load Balancing (DNS-based global load balancing is the same mechanism as DNS geo-routing)
- **Enables:** 6.7 CDN as DDoS Mitigation Layer (anycast is the mechanism by which DDoS traffic is absorbed across all PoPs simultaneously — you can't do global DDoS scrubbing without anycast); 6.5 CDN for Static vs. Dynamic Content (geo-routing determines which edge serves the content — prerequisite for all CDN content decisions)
- **Tension with:** 6.3 Cache Invalidation at the Edge (geo-routing can complicate cache invalidation — if the same user is routed to different PoPs across requests, they may see inconsistent cached states during a purge propagation)

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. What is anycast, and how does BGP determine which PoP receives a packet sent to an anycast IP?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6.*

2. A user in Frankfurt uses Google's 8.8.8.8 DNS resolver. The CDN uses DNS geo-routing without ECS. Which PoP will they likely be routed to, and why is this a problem?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6 (EDNS Client Subnet).*

3. A CDN PoP in Singapore goes offline. Compare how long it takes for traffic to re-route under (a) anycast and (b) DNS geo-routing with a 60-second TTL.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 9 (failure paths).*

4. Cloudflare announces the same /24 prefix from 300 PoPs worldwide. A user in Johannesburg, South Africa sends a packet to that prefix. Walk through how the internet routes that packet to the Johannesburg PoP rather than the London PoP.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 9 (anycast happy path).*

5. An interviewer asks: "What happens if two CDN PoPs are equidistant (same AS path length) from a user under anycast?" What does BGP do, and what does the user experience?

   > 💡 *Think through your answer before expanding — consider BGP tiebreakers (MED, router-id) and TCP connection stickiness.*

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **Cloudflare blog — "Load Balancing without Load Balancers"** — [blog.cloudflare.com](https://blog.cloudflare.com/cloudflares-architecture-eliminating-single-points-of-failure/) — explains anycast-based architecture in production
- [ ] **AWS Route 53 Routing Policies docs** — [docs.aws.amazon.com/Route53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html) — covers latency-based, geolocation, and geoproximity routing in practice
- [ ] **RFC 7871 — EDNS Client Subnet** — [tools.ietf.org/html/rfc7871](https://tools.ietf.org/html/rfc7871) — motivation, mechanics, and privacy considerations
- [ ] **"BGP in Large-Scale Data Centers" (Facebook Engineering)** — [engineering.fb.com](https://engineering.fb.com/2021/05/13/data-center-engineering/bgp/) — how large networks use BGP for internal routing; context for anycast mechanics
- [ ] **ByteByteGo "How Does CDN Work?"** — [blog.bytebytego.com](https://blog.bytebytego.com/p/how-does-a-cdn-work) — accessible overview covering both DNS and anycast approaches

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

