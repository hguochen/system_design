# 4.6 Sticky Sessions — Trade-offs and Alternatives

> **Topic:** Topic 4 — Load Balancing
> **Phase:** B — Scalability Branch
> **Date studied:** 2026-05-22

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

Sticky sessions (also called session affinity) is a load balancing configuration where a client is consistently routed to the same backend server across multiple requests. This exists because some services store session state locally on the server — without affinity, subsequent requests from the same client might land on a different server that has no record of the session. The central tension is that stickiness restores stateful behavior on top of a load-balanced tier, which directly undermines the horizontal scalability that load balancing is supposed to enable.

### 🎯 What to Focus On

**1. Why stickiness is needed in the first place.** It only exists as a band-aid over server-side session state. Understand the root cause, not just the symptom.

**2. How stickiness is implemented.** Cookie-based affinity (LB inserts a cookie) vs. IP-hash affinity (LB hashes source IP to a server). Both mechanisms have distinct failure behaviors — know them.

**3. The scaling trap.** Sticky sessions break free horizontal scaling: adding a server doesn't help existing "stuck" users, and losing a server drops all sessions pinned to it. Interviewers specifically probe for this.

**4. Alternatives that eliminate the need for stickiness.** Externalizing session state to Redis, using JWTs, or designing stateless services altogether. This is the right architectural answer — not a workaround.

**5. When stickiness is the pragmatic choice.** Not all systems can be refactored immediately. Know when to accept stickiness as a deliberate trade-off vs. an anti-pattern to avoid.

---

## 1. 🎯 Goal of This Subtopic

> *Why are you studying this? What should you be able to do after this session?*

Be able to explain why sticky sessions exist, how they are implemented (cookie-based vs. IP-hash), and why they create a ceiling on horizontal scalability. More importantly, be able to propose the correct architectural alternatives — externalizing session state, token-based auth, or stateless service redesign — and justify the trade-off between refactoring cost and scalability benefit in a given interview scenario.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can explain the problem sticky sessions solve and why that problem arises from stateful server design
- [ ] Can describe both implementation mechanisms (cookie-based and IP-hash) and name a failure scenario specific to each
- [ ] Can articulate exactly why sticky sessions prevent free horizontal scaling — both in terms of new server utilization and node failure impact
- [ ] Can propose three concrete alternatives to sticky sessions and explain the trade-off of each vs. stickiness
- [ ] Can identify in a system design interview when a proposed architecture implicitly requires sticky sessions and call it out proactively

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] Read **DDIA Chapter 1** (Reliability, Scalability, Maintainability) — the scaling section frames why stateless matters
- [ ] Read **AWS Elastic Load Balancing — Sticky Sessions documentation** (docs.aws.amazon.com/elasticloadbalancing) — concrete implementation reference
- [ ] Read **Martin Fowler — "Patterns of Enterprise Application Architecture" session state patterns** — covers the spectrum from server-side to client-side session
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
  Sticky sessions route a client to the same server every time — a
  band-aid over server-side state that caps horizontal scalability.

KEY PROPERTIES / RULES
  1. Implemented via cookie-based affinity (LB inserts a Set-Cookie)
     or IP-hash affinity (source IP deterministically maps to a node).
  2. Breaks even load distribution — "hot" users stay on the same server.
  3. Node failure drops all sessions pinned to that node (no redundancy).
  4. New servers don't absorb existing sticky traffic — no re-balancing.
  5. The correct fix is stateless redesign, not better stickiness.

DECISION RULE
  Use sticky sessions when: you cannot refactor server-side session state
  in the short term and need a pragmatic stopgap (legacy migration, COTS software).
  Avoid sticky sessions when: you are designing a new system or scaling
  beyond a few nodes — externalize state to Redis or use JWTs instead.

NUMBERS / FORMULAS
  Cookie TTL = session timeout (e.g., 30 min); keep short to reduce drift.
  IP-hash distributes ~evenly for large user sets but degrades under NAT
  (thousands of users behind one corporate IP → all hit one server).

GOTCHA TO NEVER FORGET
  IP-hash affinity silently collapses when users are behind NAT or a
  corporate proxy — all traffic maps to one server and you've recreated
  the hot-node problem you were trying to avoid.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

Sticky sessions (session affinity) is a load balancer configuration that consistently routes all requests from a given client to the same backend server, allowing that server to serve the client's locally-stored session state across multiple requests. It is a mechanism to preserve stateful server behavior in front of a load-balanced tier — at the cost of free horizontal scaling.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*

### Server-Side Session State
When a server stores user session data (auth tokens, shopping cart, user preferences) in its own process memory or local disk, that data is only accessible on that specific server. If the next request lands on a different server, the session is lost — this is the root problem that sticky sessions paper over. Without sticky sessions, every stateful server-side request requires either replication or centralized state storage.

### Cookie-Based Affinity
The load balancer injects a special cookie (e.g., `AWSALB` for AWS ALB, `SERVERID` for HAProxy) into the HTTP response. On every subsequent request, the client sends this cookie back, and the LB uses it to route to the correct backend. This is the most common and reliable implementation because cookies survive IP changes (mobile users switching networks, VPN connects). The LB must be L7 (HTTP-aware) to inspect and set cookies.

### IP-Hash Affinity
The load balancer computes a hash of the client's source IP address and deterministically maps it to a backend server. No cookie is required — the routing is stateless from the LB's perspective. This works at L4 or L7 but degrades severely when many clients share a single public IP (corporate NAT, ISP CGNAT), routing all those users to one server and creating a hot node.

### Session Draining (Connection Draining)
When a backend node must be taken out of service (deployment, failure recovery), active sticky sessions cannot be immediately cut off without losing state. Session draining allows the LB to stop sending new sessions to the departing node while letting existing sessions complete. This graceful wind-down avoids session loss during planned maintenance but doesn't help with sudden node failures.

### Stateless Alternatives
The architecturally correct remedy: externalize session state to a shared store (Redis, Memcached) so any backend can serve any request. Alternatives include JWT-based auth (client carries all session state in a signed token, no server-side storage needed) and share-nothing architecture (stateless services backed by external state stores). These eliminate the need for affinity entirely and restore true horizontal scalability.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

HTTP is stateless by design — each request carries no memory of prior requests. Web applications needed persistent sessions (login state, cart contents, multi-step workflows) so they began storing session objects in server memory keyed by a session ID cookie. This worked fine with a single server. When load balancers appeared to distribute traffic across a pool of servers, the problem surfaced immediately: if server A issued session ID `abc123` and stored the state in its memory, a subsequent request carrying `abc123` that landed on server B would find no matching session and return a 401 or blank cart.

The immediate fix was to tell the load balancer: "once you've sent a client to server A, keep sending them to server A." This preserved existing application code without any refactoring. Sticky sessions were thus invented as a compatibility shim between stateful application architectures and the load-balanced multi-server deployments that scale required. The cost was that the horizontal scalability benefit was partially surrendered — you added more servers, but existing users didn't benefit from them.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*

### Model 1: The Assigned Cashier
Imagine a supermarket where each shopper has a running tab stored in the cashier's personal notepad. The load balancer (store manager) assigns each new shopper to a specific cashier (sticky session). If that cashier goes on break (node failure), the shopper's tab is lost. If the store adds new cashiers, the manager doesn't reassign existing shoppers — the new cashiers stand idle while the old ones are overloaded. The fix: move all tabs to a central register system (Redis) so any cashier can look up any shopper's tab. This model captures the loss-on-failure, uneven load, and the correct fix in one frame. It breaks down for the IP-hash nuance (you'd never assign a cashier based purely on a shopper's home address), which is where you'd switch to the next model.

### Model 2: Reserved Parking vs. Pay-and-Display
Cookie-based affinity is like a reserved parking spot — a valet gives you a ticket (cookie) and guarantees your car (session) goes to space B-7 every time. IP-hash is like always assigning you to the parking level based on your license plate region — it works for individual cars but if a bus parks (corporate IP with 5,000 users), the entire fleet floods one level. The "correct fix" framing: the real solution is self-driving cars that park anywhere and know where they are without a reserved space — i.e., stateless services where state is carried externally. This model breaks down when thinking about session draining, but it's ideal for explaining the IP-hash NAT problem quickly.

### Model 3: The Sticky-Note Anti-Pattern
Think of server-side session state as sticky notes plastered on one specific server's monitor. Sticky sessions are the rule "always send this user back to the server with their sticky notes." If that server burns down, the notes are gone. If you want to add a new monitor (server), you can't move the notes automatically. The right answer isn't better rules about who can see whose sticky notes — it's to stop using sticky notes and use a shared whiteboard (Redis/JWT) that anyone can read.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

**Cookie-based affinity — happy path:**
1. Client sends first request to the load balancer (no affinity cookie yet).
2. LB selects a backend via normal routing algorithm (e.g., round robin) → assigns backend B2.
3. LB inserts an affinity cookie into the HTTP response: `Set-Cookie: AWSALB=<encoded_B2_id>; Path=/; Max-Age=86400`.
4. Client stores the cookie and sends it on all subsequent requests.
5. LB reads the cookie, extracts the target backend ID, and routes directly to B2 — bypassing the normal routing algorithm.
6. On B2 failure: LB detects the failure via health check, removes B2 from the pool. Requests with the stale affinity cookie are re-routed to a new backend (session state is lost unless externalized). Some LBs invalidate the cookie and restart affinity from a new backend.

**IP-hash affinity — happy path:**
1. Client sends first request; LB computes `hash(source_IP) % num_backends` → deterministically maps to backend B3.
2. All future requests from that IP always resolve to B3 — no cookie required.
3. On backend scaling events (adding or removing a node), the modulus changes and all hash mappings are recomputed — causing mass session disruption (same problem as naive consistent hashing without virtual nodes).

**Session draining during deployment:**
1. Operator marks B2 as "draining" in the LB config.
2. LB stops sending new sessions to B2 but continues honoring existing affinity cookies pointing to B2.
3. LB monitors active connection count on B2; once it reaches 0 (or a configurable timeout expires), B2 is removed from the pool.
4. Remaining sessions that didn't complete are lost or must reconnect.

**Failure scenario unique to stickiness:**
A key failure mode is that sticky sessions create a hidden single point of failure at the session level. Even if you have 10 backend nodes and 99.9% availability per node, any given user's session has only 99.9% availability — the probability of their pinned node being down. Contrast with stateless: all 10 nodes serve all users, and the effective availability is `1 - (0.001)^10` ≈ 100%.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| **AWS Application Load Balancer (ALB)** | Supports duration-based sticky sessions via `AWSALB` cookie; configurable TTL. Cookie-based. | AWS docs note that stickiness can cause uneven load; recommends session stores for stateless design instead. |
| **HAProxy** | Implements stickiness via `stick-table` and `stick on src` (IP-hash) or `appsession` (cookie parsing). Widely used in on-prem and self-hosted deployments. | HAProxy's `balance source` mode for IP-hash; suffers NAT collapse as expected. |
| **NGINX** | `ip_hash` directive pins clients to upstreams. Also supports `sticky` cookie directive in NGINX Plus (commercial). | Open-source NGINX only natively supports IP-hash; cookie-based affinity requires Plus or a Lua module. |
| **Legacy Java EE / PHP session apps** | Classic use case — Tomcat `JSESSIONID`, PHP `PHPSESSID` sessions stored in server memory require sticky routing to function. | Motivating example of why stickiness was invented; modern containerized versions externalize to Redis. |
| **WebSocket long-lived connections** | WebSocket upgrades require all packets of a session to reach the same server. LBs must maintain affinity for the duration of the TCP connection. | This is a legitimate, unavoidable use case — not a band-aid. The connection itself is stateful at the transport layer. |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Zero application code change needed — works with existing stateful apps | New backend nodes don't receive existing sticky traffic; horizontal scaling benefit is reduced to only new sessions |
| Simple to configure at the LB level (one flag or directive) | Node failure drops all sessions pinned to that node — no redundancy at the session level |
| No external state store required — avoids Redis/Memcached operational overhead | Load becomes uneven over time as active users cluster on specific nodes while others are underutilized |
| Works for protocols where externalizing state is genuinely hard (legacy COTS software, WebSockets at transport layer) | IP-hash affinity collapses under NAT/CGNAT — all traffic from a corporate network routes to one node |
| Buys time during migration from stateful to stateless architecture | Increases deployment complexity: session draining required for rolling deploys; no instant blue/green switch |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "How would you handle user sessions across multiple servers?"
- "What happens if a backend node goes down mid-session?"
- "Why can't you just add more servers to handle the load?" (in a context where you've implied server-side state)
- "The app currently uses in-memory session storage — how do you scale it?"

**What you say / do:**
Proactively flag sticky sessions as a smell: "If this service stores session state server-side, we'd need sticky sessions to function correctly — but that limits our scaling. I'd prefer to externalize session state to Redis so any node can serve any request, which gives us true horizontal scalability and fault tolerance." Frame it as a design decision, not a given — show you recognize the trade-off and know the alternative.

**The trade-off statement (memorize this pattern):**
> "If we choose sticky sessions, we preserve compatibility with server-side session state without refactoring, but we pay in reduced horizontal scalability and no session-level redundancy — a node failure drops all active sessions on that node. For a new system, the right call is to externalize state to Redis and design stateless services; for a legacy migration, sticky sessions can be an acceptable interim while we refactor."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** Sticky sessions give you session redundancy — if I have 3 servers and one fails, the other 2 pick up the sessions.
  ✅ **Reality:** Stickiness is about routing, not replication. Sessions pinned to a failed node are simply lost. The remaining 2 nodes know nothing about those sessions. True redundancy requires externalizing state.

- ❌ **Misconception:** IP-hash is more reliable than cookie-based affinity because it doesn't depend on client-side cookies.
  ✅ **Reality:** IP-hash is fragile in enterprise and mobile environments where many users share a single public IP (corporate NAT, carrier-grade NAT). All such users hash to one server, creating a hot node. Cookie-based affinity is generally more robust and widely preferred for HTTP workloads.

- ❌ **Misconception:** Adding more backend nodes while using sticky sessions improves performance proportionally for existing users.
  ✅ **Reality:** New nodes only absorb new sessions. Existing sessions stay pinned to their original nodes until they expire or those nodes are restarted. The performance benefit of new nodes is limited to net-new traffic.

- ❌ **Misconception:** WebSocket stickiness is the same problem as HTTP session stickiness and should be solved the same way.
  ✅ **Reality:** WebSocket stickiness is a transport-layer requirement — a WebSocket upgrade and all subsequent frames must traverse the same TCP connection to the same backend. This isn't a design smell; it's a protocol constraint. Externalizing message state to Redis Pub/Sub handles fan-out, but the persistent connection still requires affinity.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** **3.1 Stateless vs. Stateful Architecture** — sticky sessions are the load balancing manifestation of server-side state; you can't understand why stickiness is a problem without first understanding the stateless/stateful distinction and why stateless scales better.
- **Enables:** **3.3 Externalizing State to Redis / Distributed Stores** — the canonical remedy for sticky sessions is to externalize session state; understanding stickiness motivates why Redis session stores exist and why they matter.
- **Tension with:** **4.2 Routing Algorithms** — all routing algorithms (round robin, least connections, weighted) assume any backend can handle any request. Sticky sessions override the routing algorithm for pinned clients, reducing effective load distribution and making "least connections" routing partially ineffective.

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. What is a sticky session, and what underlying server design flaw makes it necessary?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 5 (Core Definition) and Section 7 (First Principles).*

2. A team is designing a user-facing web app with 10 backend nodes. They currently store session tokens in server memory. An interviewer asks: "How do you scale this?" What is the wrong answer, the stopgap answer, and the right answer?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Sections 6 and 9 (Core Concepts and How It Works).*

3. You configure IP-hash affinity on your load balancer. Three months later, the ops team reports that one backend node is running at 80% CPU while the other three are at 10%. What is the most likely cause, and what do you do?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit the NAT collapse gotcha in Section 6 and the Cheatsheet.*

4. Name two production systems that use or have historically used sticky sessions, and explain why each did so.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 10 (Real-World System Examples).*

5. A team asks: "Can't we just replicate session state across all servers so sticky sessions aren't needed?" What are the problems with this approach compared to externalizing to Redis?

   > 💡 *Think through your answer before expanding — if you hesitate, think about write amplification, consistency, and operational cost vs. a single authoritative Redis store.*

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **DDIA — Designing Data-Intensive Applications**, Martin Kleppmann — Chapter 1 (Scalability section) and Chapter 5 (Replication) for context on stateful vs. stateless scaling
- [ ] **AWS Elastic Load Balancing — Sticky Sessions docs**: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/sticky-sessions.html — concrete cookie duration-based and application-based stickiness config
- [ ] **HAProxy sticky session configuration guide**: https://www.haproxy.com/documentation/haproxy-configuration-tutorials/load-balancing/sticky-sessions/ — low-level implementation reference
- [ ] **ByteByteGo — "How do you scale a web app?"** (YouTube, Alex Xu) — covers the stateless evolution arc from single server → LB → externalize sessions

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

ONE-LINER
  Sticky sessions route a client to the same server every time — a band-aid
  over server-side state that caps horizontal scalability.

KEY PROPERTIES / RULES
  1. Implemented via cookie-based affinity (LB inserts Set-Cookie)
     or IP-hash affinity (source IP deterministically maps to a node).
  2. Breaks even load distribution — "hot" users cluster on the same node.
  3. Node failure drops ALL sessions pinned to that node — no redundancy.
  4. New servers don't absorb existing sticky traffic — no re-balancing.
  5. The correct fix is stateless redesign, not better stickiness.

DECISION RULE
  Use sticky sessions when: you cannot refactor server-side state in the
  short term (legacy migration, COTS software, WebSocket transport layer).
  Avoid sticky sessions when: designing a new system or scaling beyond a
  few nodes — externalize state to Redis or use JWTs instead.

NUMBERS / FORMULAS
  Cookie TTL = session timeout (e.g., 30 min); keep short to limit drift.
  IP-hash: hash(src_IP) % num_backends — recomputes on every scaling event.

GOTCHA TO NEVER FORGET
  IP-hash collapses under NAT — thousands of corporate users share one IP,
  all routing to one server. Cookie-based affinity is generally preferred.

  