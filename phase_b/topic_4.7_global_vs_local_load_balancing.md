# 4.7 Global vs. Local Load Balancing

> **Topic:** Topic 4 — Load Balancing
> **Phase:** B — Scalability Branch
> **Date studied:** 2026-05-24

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

Global vs. local load balancing is the architectural distinction between routing traffic within a single data center (local) and routing traffic across multiple data centers or cloud regions globally (global). Local load balancing — the focus of subtopics 4.1–4.6 — distributes requests across a fleet of servers within one region. Global load balancing sits one level above: it decides which region or data center a user's request should go to before local LB takes over. The central tension is between latency reduction, fault isolation, and the complexity of health-aware cross-region traffic steering.

### 🎯 What to Focus On

**1. The two-tier hierarchy.** Global LB selects the region; local LB selects the server within the region. Be able to draw and explain this two-layer stack in an interview. Every globally distributed system has both.

**2. DNS-based geo-routing vs. anycast.** These are the two dominant global LB mechanisms. DNS routing (Route 53, Cloudflare) directs users based on their resolver's geolocation. Anycast routes packets via BGP to the topologically nearest PoP. Each has different failover latency, TTL constraints, and failure modes.

**3. Failover propagation speed.** DNS TTL is the biggest gotcha — a region going down doesn't redirect existing clients until their DNS TTL expires. This is the primary operational risk of DNS-based global LB and a common interview probe.

**4. Session and data locality.** Global LB creates cross-region consistency challenges. If a user's session is stored in US-East and global LB redirects them to EU-West, their session is gone unless state is globally replicated. Know the implications.

**5. Health checking at global scale.** Global LB health checks operate at region granularity, not server granularity — they probe regional endpoints and take entire regions in or out. Understand how threshold-based failover prevents flapping.

---

## 1. 🎯 Goal of This Subtopic

> *Why are you studying this? What should you be able to do after this session?*

Be able to explain the difference between global and local load balancing, describe the two-tier traffic routing architecture used by globally distributed systems, and reason about when and how to apply DNS-based routing vs. anycast. Critically, be able to articulate the failover latency problem caused by DNS TTLs and propose mitigation strategies — this is the most common interview follow-up on this topic.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can explain the two-tier hierarchy (global LB selects region → local LB selects server) with a concrete example
- [ ] Can compare DNS-based geo-routing and anycast: how each works, what layer it operates at, and the failure modes of each
- [ ] Can articulate the DNS TTL failover problem and propose at least two mitigations (short TTL + health check integration, anycast fallback)
- [ ] Can identify what happens to user sessions when global LB redirects a user to a different region mid-session
- [ ] Can name at least three real production systems that use global LB and describe which mechanism each uses

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] Read **AWS Route 53 — Routing Policies** (docs.aws.amazon.com/Route53) — covers latency, geolocation, failover, and health-check-integrated routing
- [ ] Read **Cloudflare — How Anycast works** (cloudflare.com/learning/cdn/glossary/anycast-network-routing) — the definitive short explanation
- [ ] Read **ByteByteGo — "How does Google Global Load Balancer work?"** (blog.bytebytego.com) — covers Maglev and the two-tier model
- [ ] Read **Google Cloud — Global vs. Regional Load Balancing** (cloud.google.com/load-balancing/docs) — practical decision framework
- [ ] Read through **Sections 5–9** (Core Definition → How It Works) carefully — don't skim
- [ ] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **Core Definition** from memory, then compare
- [ ] Explain **First Principles** out loud without notes — what problem does this solve and why?
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
ONE-LINER
  Global LB routes traffic to the right region; local LB routes it to the
  right server — they are a mandatory two-tier stack in any global system.

KEY PROPERTIES / RULES
  1. Global LB operates at DNS or network layer (L3/L7); local LB at L4/L7.
  2. DNS-based: latency/geo-routing, TTL-bounded failover, simple to operate.
  3. Anycast: BGP routes packets to nearest PoP — sub-second failover, no TTL.
  4. DNS TTL = failover lag: if TTL=60s, downed regions still receive traffic
     for up to 60s after health check failure is detected.
  5. Global LB health checks are region-level, not server-level.

DECISION RULE
  Use DNS-based global LB when: operationally simple geo-routing is enough,
  and ~60s failover lag is acceptable (most stateless web apps).
  Use anycast when: you need sub-second failover or DDoS absorption at edge
  (CDNs, DNS resolvers, real-time systems).

NUMBERS / FORMULAS
  DNS TTL recommendation: 60–300s for prod; 30–60s during maintenance windows.
  Anycast failover: <1s (BGP route withdrawal propagation).
  Typical GSLB health check interval: 10–30s.

GOTCHA TO NEVER FORGET
  DNS TTL is NOT the only latency — resolvers cache aggressively and often
  ignore TTLs. Real failover lag is TTL + resolver non-compliance; plan for 2–5×
  longer than your configured TTL.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

Local load balancing distributes traffic across servers within a single data center using L4/L7 mechanisms; global load balancing sits above this layer and steers traffic across multiple geographically distributed data centers or cloud regions — typically via DNS-based geo-routing or anycast — to minimize latency, absorb regional failures, and distribute capacity across the globe.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*

### Local Load Balancing
Local LB operates within a single data center or availability zone, distributing requests across a fleet of identical servers using algorithms like round robin, least connections, or IP hash. It operates at L4 (TCP/UDP) or L7 (HTTP) and makes decisions in microseconds based on per-server health and load. Everything covered in subtopics 4.1–4.6 describes local LB. Local LB is unaware of geography — it assumes all backends are reachable and roughly equivalent in cost.

### Global Load Balancing (GSLB)
GSLB routes incoming traffic to one of several regional clusters worldwide before local LB takes over. It decisions are coarser — select the US-East cluster, not server-7 within US-East. GSLB health checks operate at the region level: it probes a regional virtual IP or health endpoint and marks the entire region healthy or unhealthy. The two primary mechanisms are DNS-based routing and anycast.

### DNS-Based Geo-Routing
The DNS resolver for a domain returns different A/AAAA records depending on the requesting client's location or the measured latency to each region. AWS Route 53 supports latency-based routing (return the IP of the region with the lowest measured RTT to the client), geolocation routing (return the IP for the geographically closest region), and failover routing (primary/secondary with health check integration). Failover is bounded by DNS TTL — clients cache the DNS response and continue routing to the old IP until the TTL expires, even if the health check has already failed.

### Anycast
Anycast assigns the same IP address to servers in multiple locations. BGP routing naturally delivers packets to the topologically nearest instance of that IP. When a PoP goes down, BGP withdraws the route and packets are automatically redirected to the next-nearest PoP — typically within milliseconds. Cloudflare, Google's DNS (8.8.8.8), and large CDNs use anycast extensively. The trade-off: anycast requires BGP control (you need your own AS and IP block), making it complex to operate and inaccessible to most application teams directly.

### Two-Tier Traffic Architecture
Every globally distributed system uses a two-tier model: (1) Global LB steers the client to the correct region, and (2) Local LB within that region distributes the request across servers. The global tier is coarse, health-check-driven, and geography-aware. The local tier is fine-grained, server-aware, and latency-optimized. Confusing the two layers in an interview is a common mistake — be explicit about which tier you're describing.

### Region-Level Health Checks
Global LBs do not health-check individual servers — that's the local LB's job. GSLB health checks probe a regional endpoint (e.g., `/healthz` on a regional load balancer VIP) and mark the entire region in or out based on response. Threshold-based failover (e.g., fail only after 3 consecutive check failures) prevents flapping during transient blips. The check interval (typically 10–30s) plus the TTL determines the maximum expected failover window.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

A single local load balancer — even a highly available, redundant one — is physically located in one data center. Two fundamental problems forced global load balancing into existence:

**Latency is physics.** Light travels ~200km/ms in fiber. A user in Tokyo making a request to a US-East data center experiences ~150ms of irreducible round-trip latency just from the speed of light, before the application processes anything. For latency-sensitive applications (web UIs, APIs, real-time systems), this is unacceptable. You must place compute near users — and then you need a mechanism to route users to the nearest compute.

**Single-region failure is catastrophic.** A natural disaster, power grid failure, cloud provider outage, or network partition can take an entire data center offline. With a single region, this means total application unavailability. With multiple regions, you need a mechanism that detects the regional failure and redirects traffic to surviving regions — automatically and quickly. This is the disaster recovery / high availability motivation for GSLB.

Local LB only solves within-region distribution. It cannot reason about geography or cross-region failover. GSLB was invented specifically to add the geographic routing layer that local LB was never designed to handle.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*

### Model 1: Airport Hub-and-Spoke
Think of global LB as the international flight booking system and local LB as the shuttle bus network within each city. When you book a flight from Singapore, the booking system (GSLB) decides you'll fly into New York JFK — not London or Tokyo. Once you land at JFK, the ground transport system (local LB) gets you to your specific hotel. The booking system has no idea which hotel you're going to — that's not its job. It just picks the right city. If JFK closes due to a snowstorm (region failure), the booking system reroutes your flight to Chicago. This model captures the two-tier hierarchy and regional failover perfectly. It breaks down for anycast (there's no geographic assignment — you just go to whichever airport is closest at that moment).

### Model 2: DNS TTL as a Stale Map
Imagine your GPS downloaded a map of road closures at midnight (DNS resolution). You're navigating at 6am using that stale map. If a highway closed at 3am (region went down), your GPS still routes you that way until you re-download the map (DNS TTL expires and you re-resolve). Short TTLs = more frequent map downloads = fresher data, but more DNS query load. This model makes the TTL failover lag viscerally concrete and explains why "just use DNS-based failover" isn't instantaneous.

### Model 3: Anycast as a Floating Hotspot
Anycast is like Wi-Fi roaming across a corporate campus — you have one network SSID (one IP address), and whichever access point is nearest picks up your device automatically as you walk around. If one access point fails, your device seamlessly connects to the next nearest one without you doing anything. There's no "check which access point is closest" step — the network handles it at the routing layer. This model captures the BGP-level transparency and sub-second failover of anycast. It breaks down when explaining why not every system uses anycast (you need BGP control, your own IP block, and significant network infrastructure).

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

### DNS-Based Geo-Routing — Happy Path

1. User in Tokyo types `api.example.com`. Their device queries their local DNS resolver.
2. The resolver queries the authoritative DNS (e.g., Route 53). Route 53 checks the client's resolver IP geolocation or measured RTT to each regional endpoint.
3. Route 53 returns the IP of the Tokyo regional cluster (or nearest available healthy region). TTL is set to 60 seconds.
4. Client connects to the Tokyo regional IP → hits the regional load balancer → local LB distributes to a healthy server in the Tokyo cluster.
5. Client caches the Tokyo IP for 60 seconds; all requests within that window bypass DNS.

### DNS-Based Geo-Routing — Regional Failure

1. Tokyo cluster fails health checks (e.g., 3 consecutive failures over 30s).
2. Route 53 marks Tokyo as unhealthy and begins returning the Singapore IP for new DNS queries.
3. Clients who already resolved Tokyo continue hitting it for up to their remaining TTL. With TTL=60s, worst case is 60s of failed requests being sent to the dead region before DNS re-resolution kicks in.
4. Client re-resolves → gets Singapore IP → traffic redirects. Total failover lag: health check detection time + TTL expiry.

### Anycast — Routing and Failover

1. Cloudflare advertises `104.16.x.x/20` from 300+ PoPs globally via BGP. Every PoP announces the same prefix.
2. The internet's BGP routers naturally route your packets to the topologically nearest PoP — not because Cloudflare directs you there, but because BGP shortest-path routing does it automatically.
3. If the Tokyo PoP goes down, it withdraws its BGP announcement. Within seconds, BGP convergence redirects packets to the next-nearest PoP (e.g., Singapore).
4. No DNS change. No TTL wait. The IP address never changes — only which physical server answers it does.

### Health Check Design at Global Scale

Global LB health checkers probe regional endpoints from multiple vantage points simultaneously to avoid false positives from a single checker's connectivity issue. Threshold: typically 2-of-3 checkers must agree the region is unhealthy before failover triggers. This prevents a single packet loss event from taking a region out. The check interval (10–30s) × failure threshold (3) gives the maximum detection window before failover begins: e.g., 30s × 3 = 90s detection lag.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| **AWS Route 53** | Latency-based and geolocation routing policies with health-check integration for automatic regional failover | Most common DNS-based GSLB for AWS-hosted services; supports A/B failover between primary and secondary regions |
| **Cloudflare** | Anycast from 300+ PoPs globally — all traffic hits the nearest PoP; local LB within each PoP forwards to origin | Anycast absorbs DDoS at edge by distributing attack traffic across all PoPs rather than concentrating it |
| **Google GCLB (Global Load Balancer)** | Single anycast IP fronts Google's worldwide infrastructure; Maglev software LB handles local distribution within each region | Google's Andromeda/Maglev papers describe this two-tier architecture explicitly |
| **Netflix** | DNS-based geo-routing via Open Connect Appliances (OCAs); ISPs get direct OCA peering per region, GSLB steers clients to the nearest healthy OCA cluster | Uses latency-aware client-side steering in addition to DNS — client SDK measures and selects optimal server |
| **Fastly / Akamai CDN** | Anycast + DNS-based hybrid — edge PoPs use anycast for initial routing, with DNS-based overrides for certain client populations | CDNs were the earliest adopters of GSLB as they needed global distribution from day one |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Reduced latency — users reach the nearest region, shaving 50–200ms of RTT | DNS TTL creates a failover lag window — clients continue hitting failed regions until TTL expires |
| Regional fault isolation — a regional outage doesn't take down other regions | Session continuity breaks when global LB redirects a user to a different region (session data is region-local) |
| Capacity distribution across regions — traffic spikes in one geography don't overload a single data center | Operational complexity increases significantly — you now manage multiple regional deployments, data replication, and cross-region health |
| DDoS absorption at edge (with anycast) — attack traffic is spread across all PoPs rather than concentrated | Anycast requires BGP control and your own IP block — only feasible for large infrastructure operators |
| Enables compliance with data residency requirements (e.g., EU data stays in EU) | Cross-region data consistency is hard — eventual consistency is often the only practical model at global scale |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "How would you design this system for global users?" or "Users are distributed across the US, Europe, and Asia."
- "What happens if an entire data center goes down?"
- "How do you minimize latency for international users?"
- "Walk me through your traffic routing architecture end to end."

**What you say / do:**
Introduce the two-tier model explicitly: *"I'd use global load balancing to steer users to their nearest regional cluster, then local load balancing within each region to distribute across servers. For GSLB I'd use DNS-based latency routing with health-check-integrated failover for most services, or anycast for edge/CDN components where sub-second failover matters."* Then proactively call out the TTL failover lag as a known limitation and address session locality if state is involved.

**The trade-off statement (memorize this):**
> "If we use DNS-based global LB, we get simple geo-routing and regional failover with familiar tooling, but we pay with TTL-bounded failover lag — clients can continue hitting a dead region for up to our TTL window. For most stateless APIs this is acceptable; for real-time systems I'd supplement with anycast or a shorter TTL of 30 seconds, accepting higher DNS query volume as the cost."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** DNS failover is near-instantaneous — as soon as you update the DNS record, clients redirect.
  ✅ **Reality:** Clients cache DNS responses for the full TTL and many resolvers cache even longer in violation of the TTL spec. Real failover lag is often 2–5× the configured TTL. True instant failover requires anycast or an application-level redirect mechanism.

- ❌ **Misconception:** Global LB and CDN are the same thing.
  ✅ **Reality:** CDNs are one use case for global LB, but GSLB is a broader concept. A GSLB routes to origin data centers; a CDN routes to edge caches. CDNs typically use global LB internally, but not all GSLB systems are CDNs. A database or API service can use GSLB with no CDN layer.

- ❌ **Misconception:** Global LB handles session persistence — it will always send the same user to the same region.
  ✅ **Reality:** Global LB does not provide sticky sessions at the regional level (unless specifically configured). Failover will redirect users to a different region, and their session data — if stored regionally — will be unavailable. You must either replicate session state globally, use stateless JWTs, or accept session loss on regional failover.

- ❌ **Misconception:** Anycast is always better than DNS-based routing because it's faster.
  ✅ **Reality:** Anycast routes to the topologically nearest PoP as seen by BGP, which may not be the same as the geographically nearest or lowest-latency PoP due to asymmetric routing. DNS-based latency routing actively measures RTT to each region and routes based on empirical latency data, which can outperform BGP topology for certain client locations.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** 4.3 Health Checks and Failure Detection — global LB relies on the same health check concepts, applied at region granularity rather than server granularity. Regional health probing uses the same HTTP/TCP health check primitives, just targeting a regional VIP instead of individual servers.
- **Enables:** Topic 6 — CDN (CDNs are the most common real-world deployment of global LB via anycast PoPs) and Topic 37 — Global Multi-Region Systems (the full active-active / active-passive multi-region architecture builds directly on global LB as its traffic-steering foundation).
- **Tension with:** 4.6 Sticky Sessions — global LB failover fundamentally conflicts with session affinity. If a user's session is sticky to US-East and global LB redirects them to EU-West during a regional failure, their session is lost. Stateless design (3.1, 3.7) is the only clean resolution.

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. Explain the two-tier load balancing hierarchy used in globally distributed systems. What does each tier decide, and what mechanisms does each use?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 5 (Core Definition) and Section 6 (Core Concepts).*

2. A company uses DNS-based geo-routing with a 5-minute TTL. Their US-East region fails at 14:00. A user in New York last resolved DNS at 13:58. What happens, and when will they be redirected to the failover region?

   > 💡 *Think through your answer — if you hesitate, revisit Section 9 (How It Works — Regional Failure) and the Cheatsheet gotcha.*

3. What are the trade-offs between DNS-based geo-routing and anycast? When would you choose one over the other?

   > 💡 *Think through your answer — if you hesitate, revisit Section 6 (DNS-Based Geo-Routing vs. Anycast) and Section 11 (Trade-offs).*

4. Name two real-world systems that use global load balancing and describe which mechanism (DNS or anycast) each uses and why.

   > 💡 *Think through your answer — if you hesitate, revisit Section 10 (Real-World System Examples).*

5. A globally distributed e-commerce site uses DNS-based global LB and stores user shopping carts in a regional Redis. The EU-West region fails and global LB redirects EU users to US-East. What breaks, and how would you fix it?

   > 💡 *Think about session/data locality — what data is region-local? What would need to change architecturally to survive this failover cleanly?*

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **AWS Route 53 — Routing Policies**: docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html — covers latency, geolocation, failover, and weighted routing with health-check integration
- [ ] **Cloudflare — How Anycast Works**: cloudflare.com/learning/cdn/glossary/anycast-network-routing — concise, authoritative explanation of BGP-based anycast
- [ ] **ByteByteGo — "How does Google Global Load Balancer work?"**: blog.bytebytego.com — covers the Maglev/Andromeda two-tier architecture with real traffic flow diagrams
- [ ] **Google Cloud Load Balancing Docs — Global vs. Regional**: cloud.google.com/load-balancing/docs/choosing-load-balancer — practical framework for when to use each tier
- [ ] **DDIA Chapter 5 — Replication** (Kleppmann): covers geo-replication data challenges that arise from multi-region deployments enabled by global LB

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

