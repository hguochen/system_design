# 11.7 API Gateway Patterns

> **Topic:** Topic 11 — API Design & Service Boundaries
> **Phase:** D — Networking Branch
> **Depth Tier:** 🥇 T1 (Core) — budget ~3h
> **Prereqs:** 4.5 (Reverse Proxies), 11.1 (REST — Principles, Resource Design, HTTP Methods, Status Codes)
> **Date studied:** Not yet studied

---

## 0. 🧭 The Question This Answers

11.1 established that a well-designed API is a resource-oriented contract between a client and a service. 4.5 established that a reverse proxy can sit in front of a backend and terminate connections on its behalf. Once a system stops being one service and becomes many — an order service, a user service, an inventory service, each with its own REST API — a new problem appears that neither of those subtopics solves on its own: every one of those services now needs authentication, TLS termination, rate limiting, and a consistent way for clients to find it, and none of that is core business logic. **An API gateway is the architectural answer: one edge component that owns every cross-cutting concern once, so that N backend services don't each reinvent it, and so that a client sees one coherent API surface instead of N independently-addressed ones.**

The tension is that centralizing this logic in one place trades duplication for concentration — you stop writing the same auth check five times, but you also create one component that every request must pass through, whose failure now means every service is unreachable. The obvious move — let each service handle its own auth, its own rate limiting, its own TLS — avoids that concentration risk, but it means five teams independently reimplement (and independently get wrong) the same cross-cutting logic, and a client integrating with your system has to learn five different hostnames and five different auth mechanisms instead of one.

**The question:** *When you have many backend services instead of one, where do cross-cutting concerns — authentication, rate limiting, routing, TLS termination — belong, and what do you give up by concentrating them in a single edge component instead of leaving them distributed?*

> **→ Next:** Before naming the pattern, what actually breaks when every service handles its own edge concerns?

---

## 1. 🎯 Interview Quick Reference Card

> *Not a summary — a live-recall tool, built for retrieval speed under interview pressure. If you need the reasoning behind anything here, that's what §2 (cheatsheet) and the rest of the doc are for.*

**The checklist — walk this on the whiteboard, in order:**

1. Name the edge: one entry point in front of N backend services, not N independently-addressed hostnames
2. List what moves to the gateway: TLS termination, authentication, rate limiting, request routing — cross-cutting, not business logic
3. Pick a routing strategy: path-based (`/orders/*` → order-service) is the default; name host-based and header-based as alternatives
4. Say what does NOT belong in the gateway: business logic, service-specific validation, anything that would make the gateway a second monolith
5. Name the failure mode up front: the gateway is now a single point of failure and adds a hop of latency — mitigate with stateless horizontal scaling (3.1, 4.5) and circuit breaking per backend

**Trigger → action:**

| Interviewer says | You do |
|---|---|
| "How do you handle auth across all these microservices?" | Terminate auth once at the gateway (validate the token), not once per service |
| "Where does rate limiting live?" | Gateway, keyed per API key/user, token bucket, reject with `429` before load reaches a backend |
| "The client needs data from 3 services for one screen" | Name it explicitly: aggregate at the gateway for a fixed shape, or split into a Backend-for-Frontend if it diverges per client type |
| "What if the gateway goes down?" | It's a SPOF by construction — mitigate with stateless instances behind a load balancer, never a single box |
| "Gateway vs. load balancer vs. reverse proxy — what's the difference?" | LB picks a healthy backend; reverse proxy forwards on behalf of a backend; gateway does both **plus** app-aware routing, auth, and per-route policy |
| "Gateway vs. service mesh?" | Gateway = north-south (client → services, edge). Mesh sidecar (Envoy/Istio) = east-west (service → service, internal) |

**Fast disambiguation — the pairs that get confused live:**

| Pair | The distinction |
|---|---|
| API gateway vs. reverse proxy | A reverse proxy forwards traffic; a gateway is a reverse proxy that's *application-aware* — it understands routes, API keys, and per-endpoint policy, not just "forward to backend X." |
| API gateway vs. load balancer | A load balancer picks *which healthy instance* of one service to hit. A gateway decides *which service* a request even belongs to, then usually hands off to a load balancer for the instance-level pick. |
| API gateway vs. service mesh (sidecar) | Gateway sits at the edge and handles external (north-south) traffic. A mesh sidecar (Envoy) sits next to *every* service and handles internal (east-west) traffic. Same proxy tech (often literally Envoy), different topological role. |
| Gateway aggregation vs. BFF | A single generic gateway aggregating for every client type becomes a routing monolith as client needs diverge. A Backend-for-Frontend is a *separate* thin aggregation layer per client type (mobile BFF, web BFF), each shaped to that client only. |

**High-yield anchors:**

```
North-south traffic → API gateway (edge, client-facing)
East-west traffic   → service mesh sidecar (internal, service-to-service)
Same proxy tech often runs both roles (e.g. Envoy) — the role is topological, not technological
AWS API Gateway's published account-level default throttle is on the order of
  10,000 req/s steady-state / 5,000 req/s burst — treat as an order-of-magnitude
  anchor, not a memorized constant; AWS revises these over time
Kong is built on nginx/OpenResty; auth, rate limiting, and logging ship as plugins
```

**The script — say this close to verbatim:**

> "I'd put an API gateway — something like Kong or AWS API Gateway — in front of the order-service, user-service, and inventory-service, so clients see one host instead of three. It terminates TLS once, validates the auth token before any backend sees the request, and enforces a per-API-key rate limit with a token bucket, rejecting with `429` before load ever reaches a backend. Path-based routing — `/orders/*` to order-service, `/users/*` to user-service — means I can move, split, or scale a backend without any client-facing change. The cost is that the gateway becomes a single point of failure and adds a hop of latency to every request, so I run it as stateless instances behind a load balancer rather than a single box, and I keep it limited to routing and cross-cutting policy — the moment it starts doing real aggregation or business logic, it's turned into a second monolith I now have to operate."

**If pushed on gateway vs. service mesh specifically:**
> Gateway handles north-south (external client → your services) traffic. A service mesh sidecar handles east-west (service → service) traffic. I'd introduce a mesh only once service-to-service call volume and observability needs grow past what a shared library or convention can handle — not as a default alongside the gateway from day one.

---

## 2. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*
>
> ⏭️ **First time through this topic?** Skip to §3 and come back here for revision.

```
§ 1  WHY IT EXISTS
Once a system has more than a couple of backend services, each one independently
needs TLS termination, authentication, rate limiting, and a stable address a
client can find it at. Building that into every service means five teams
duplicate — and independently get wrong — the same cross-cutting logic, and a
client has to learn N hostnames and N auth mechanisms instead of one. The
API gateway's fix is to centralize all of that at a single edge component that
every external request passes through once, so it's implemented correctly one
time instead of N times, and the client sees one coherent surface.

§ 2  WHAT IT IS
API GATEWAY          A reverse proxy (4.5) specialized for API traffic: it does
                     app-aware routing (path/host/header → backend service),
                     not just "forward to backend X."
NORTH-SOUTH TRAFFIC   Traffic entering from outside the system (client → edge).
                     This is the gateway's job.
EAST-WEST TRAFFIC     Traffic between your own services (service → service).
                     This is a service mesh's job, not the gateway's.
CROSS-CUTTING CONCERN A behavior every service needs (auth, rate limiting, TLS,
                     logging) that has nothing to do with any one service's
                     actual business logic.
BFF (BACKEND FOR      A thin, client-specific aggregation layer (one per client
FRONTEND)             type: mobile, web, partner) instead of one generic gateway
                     trying to serve every client's shape.

§ 3  THE MECHANISM
TERMINATE TLS ONCE    Gateway holds the certificate, decrypts once at the edge;
                     internal hops run over a trusted network (4.5's argument,
                     applied to many backends instead of one).
AUTHENTICATE ONCE     Validate the token/session at the gateway; backends trust
                     a forwarded identity instead of each re-implementing auth.
ROUTE BY PATH/HOST     Match the incoming request to exactly one backend service
                     — path-based is the default (/orders/* -> order-service).
RATE LIMIT AT THE EDGE Reject overload with 429 BEFORE it reaches a backend, not
                     after — protects every downstream service in one place.
KEEP IT STATELESS      Same 3.1 constraint as everywhere else: gateway instances
                     carry no session, so they scale horizontally behind a
                     plain load balancer and any instance can serve any request.

§ 4  USE / AVOID
USE a gateway when you have multiple backend services and want ONE place to
  enforce auth, rate limiting, and routing instead of N places.
USE path-based routing as the default; reach for header-based routing only for
  things like API versioning or canary traffic splitting.
USE a BFF when different client types (mobile vs. web vs. partner) need
  genuinely different response shapes from the same underlying services.
AVOID putting business logic in the gateway — that turns your edge component
  into a second, harder-to-deploy monolith that every team now depends on.
AVOID a single generic gateway trying to aggregate for every client type at
  once — that's the routing-monolith failure mode BFF exists to prevent.
AVOID treating the gateway as free — it is a real hop, a real SPOF risk, and a
  real thing to capacity-plan and scale.

§ 5  GATEWAY vs. REVERSE PROXY vs. LOAD BALANCER vs. SERVICE MESH
REVERSE PROXY (4.5)   Forwards on behalf of a backend; doesn't need to
                     understand routes or app-level policy.
LOAD BALANCER          Picks WHICH healthy instance of one service to hit.
API GATEWAY            Decides WHICH SERVICE a request belongs to, applies
                     app-aware policy (auth, rate limit, routing), then USUALLY
                     hands off to a load balancer for the instance-level pick.
SERVICE MESH SIDECAR   Same proxy technology as a gateway (often literally
                     Envoy), but placed next to every internal service to
                     handle east-west traffic instead of north-south.

§ 6  NUMBERS TO ANCHOR THE DISCUSSION
North-south (client -> edge) is the gateway's job; east-west (service -> service)
  is the mesh's job — this single distinction resolves most gateway-vs-mesh
  interview questions.
AWS API Gateway's documented account-level default throttle is on the order of
  10,000 req/s steady-state / 5,000 req/s burst — an order-of-magnitude anchor,
  not a number to over-commit to, since providers revise these over time.
Kong runs on nginx/OpenResty (Lua); auth, rate limiting, and transformation
  ship as composable plugins rather than one monolithic codebase.
Envoy is the proxy underneath both edge gateways (e.g. Ambassador, Contour) AND
  Istio's service mesh sidecars — the SAME technology serving two different
  topological roles.
Netflix's move from a single generic Zuul gateway toward Backend-for-Frontend
  layers per client (mobile, TV, web) is the canonical real-world BFF story.

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "How do you handle auth across N microservices?"  → once, at the gateway —
                                                        not once per service
→ "Where does rate limiting live?"                   → the edge/gateway, keyed
                                                        per client, BEFORE load
                                                        reaches a backend
→ "What happens if the gateway goes down?"           → name the SPOF risk
                                                        directly, then the fix:
                                                        stateless + horizontal
                                                        scaling behind an LB
→ "Gateway or service mesh here?"                     → north-south vs.
                                                        east-west, not "which
                                                        is better"
GOTCHA: Treating the gateway as a place to put business logic or heavy
  aggregation "since it's already there." The gateway's value is in NOT
  knowing about your domain — the moment it does, you've built a second
  monolith that's harder to deploy than the one you decomposed.
```

---

## 3. 🧠 The Mindmap

> *The picture to hold in your head while you study. Everything below hangs off this.*

```
                          ┌───────────────────────────────────┐
                          │        API GATEWAY PATTERNS        │
                          │  "one edge, cross-cutting concerns │
                          │   owned once, not N times"         │
                          └──────────────────┬──────────────────┘
                                             │
   ┌────────────────┬────────────────────────┼────────────────────┬────────────────┐
   ▼                ▼                        ▼                    ▼                ▼
WHY IT EXISTS    CROSS-CUTTING           ROUTING              FAILURE MODES    REAL SYSTEMS
├ N services      CONCERNS               STRATEGIES           ├ SPOF at the    ├ Kong —
│  each need     ├ TLS termination      ├ path-based           edge             nginx/OpenResty,
│  auth/TLS/       (once, at edge)        (default)           ├ added latency    plugin
│  rate limits   ├ authentication       ├ host-based             every request    architecture
├ duplicated       (validate once,      ├ header-based          passes through  ├ AWS API Gateway
│  N times          not per service)      (versioning,         ├ config sprawl    — Lambda
├ client learns   ├ rate limiting          canary)               across many       integration,
│  N hostnames,     (token bucket,      ├ decouples client      routes             usage plans
│  N auth            reject BEFORE        from internal        ├ orchestration   ├ Netflix Zuul →
│  mechanisms        backend hit)         topology                creep — gateway   BFF per client
└ fix: ONE edge,  └ ⚠ never business                              becomes a       ├ Envoy — powers
    everything       logic here —                                 monolith          BOTH gateways
    owned once        that's a second                           ⚠ mitigate:        AND mesh
                       monolith                                    stateless +      sidecars
                                                                     horizontal      └ Istio — mesh
                                                                     scaling +          for east-west
                                                                     circuit breaking
```

**How to read it:** **why it exists** is the motivating problem — duplication and client-side complexity that grows with every new service. **Cross-cutting concerns** are what the gateway centralizes, and the warning inside that box (never business logic) is the boundary that keeps the pattern honest. **Routing strategies** are the mechanism that turns one edge address into many backend destinations. **Failure modes** are the price of centralizing — a gateway that solves duplication also concentrates risk, and the mitigations are the same statelessness and horizontal-scaling arguments from 3.1 and 4.5, applied here. **Real systems** are where you check the pattern against production names and the concrete architectural choices they made.

---

## 4. 🔥 The Problem

Once a system decomposes from one service into several — order-service, user-service, inventory-service, each independently deployed with its own REST API (11.1) — every one of those services independently faces the same set of edge concerns: it needs to terminate TLS, it needs to authenticate the caller, it needs to protect itself from being overwhelmed by traffic, and it needs a stable address a client can find it at. None of that is the service's actual job. The order-service's job is to manage orders; validating a JWT and enforcing a rate limit are the same problem repeated verbatim across every service in the system, and repeated logic is where inconsistency lives — one team gets the token validation subtly wrong, another team forgets rate limiting entirely until an incident forces it in, and a third team implements it differently enough that debugging an auth failure means knowing which service you're even looking at.

The instinctive first fix is "give each service a reverse proxy (4.5) in front of it and let it handle its own TLS and rate limiting locally." This helps at the level of a single service, but it doesn't solve the client-side half of the problem at all: a client integrating with the system still has to know that orders live at `orders.internal.example.com`, users live at `users.internal.example.com`, and each of those hosts might have a slightly different auth header format or rate-limit response shape. Every new service is a new integration point for every existing client, and moving, splitting, or renaming a service becomes a breaking change for everyone calling it directly.

The insight that resolves this is to stop repeating the cross-cutting logic per service and instead centralize it at a single edge component every external request passes through exactly once. An API gateway is a reverse proxy specialized for this job: it terminates TLS once, authenticates once, rate-limits once, and then routes the now-trusted, now-throttled request to whichever backend actually owns it — by path, host, or header. The client sees one address and one contract; the backend services see only traffic that has already passed the checks they used to each implement themselves.

**Before and after:**

```
  BEFORE — every service owns its own edge                AFTER — one gateway, N services behind it
  ─────────────────────────────────────────                ──────────────────────────────────────────
   orders.internal.example.com                              api.example.com/orders/*  ──┐
     ├─ own TLS cert                                         api.example.com/users/*   ──┼──▶ ONE
     ├─ own auth check                                       api.example.com/inv/*     ──┘   GATEWAY
     └─ own rate limiter                                        │  TLS terminated once
   users.internal.example.com                                   │  auth validated once
     ├─ own TLS cert (maybe expired differently)                │  rate limit enforced once
     ├─ own auth check (subtly different)                       ▼
     └─ own rate limiter (or none at all)                  order-service   user-service   inventory-service
   inventory.internal.example.com                            (trusts the gateway's identity + throttling)
     ├─ own TLS cert
     ├─ own auth check
     └─ own rate limiter

   ✓ each service is independently simple                  ✓ auth/TLS/rate-limiting logic exists ONCE
   ✗ auth/TLS/rate-limit logic reimplemented 3x              ✓ client learns ONE host, ONE auth mechanism
   ✗ client must know 3 hostnames + 3 auth flavors           ✓ moving/splitting a backend is invisible
   ✗ moving a service is a breaking change for callers          to the client — only routing rules change
   ✗ inconsistency across services is where bugs hide         ✗ the gateway is now a single point of failure
```

### ✅ Checkpoint

1. A teammate argues: "Let's just put a reverse proxy in front of each service instead of one shared gateway — same TLS and rate-limiting benefit, less centralized risk." Explain precisely what this fixes and what it still leaves broken, using the client-side half of the problem specifically.

   > 💡 *If you hesitate, re-read the second paragraph — the part about what a per-service reverse proxy does and doesn't solve for the client calling in.*

> **→ Next:** If the fix is one edge component owning cross-cutting concerns, what exactly does it consist of, and how do the pieces build on each other?

---

## 5. 💡 The Core Idea

**An API gateway is a single edge component, application-aware rather than a plain forwarder, that owns every cross-cutting concern — TLS termination, authentication, rate limiting, and routing — for all of a system's backend services, so a client integrates with one coherent surface instead of learning the internal service topology.**

**Visual required:** build-chain diagram.

```
 [ONE EDGE, NOT ──▶ [APP-AWARE ──▶ [ROUTING DECOUPLES ──▶ [STATELESSNESS LETS
  N ENTRY POINTS]    ROUTING]       CLIENT FROM TOPOLOGY]   THE EDGE SCALE]
   because cross-      therefore     so a service can be     which means the
   cutting concerns    the gateway   moved, split, or        gateway itself
   are the same for    matches       renamed without any     must obey 3.1's
   every service       requests to   client-facing change    constraint or it
                        a BACKEND,                            becomes the new
                        not just a                            bottleneck it was
                        raw forward                           built to remove
```

### One Edge, Not N Entry Points

Everything starts with concentration: instead of every backend service independently exposing itself to the outside world, exactly one component — the gateway — is externally reachable, and every backend sits behind it on an internal network. This is the direct fix for §4's duplication problem: TLS certificates, authentication logic, and rate-limit enforcement are implemented once, at the gateway, instead of once per service. A client that used to need three hostnames and three auth flavors now needs one of each. This single shift is what makes the rest of the pattern possible — you cannot centralize a cross-cutting concern without first centralizing the entry point it needs to run at.

### App-Aware Routing

Once there's one edge, the gateway has to do something a plain reverse proxy (4.5) doesn't: decide *which backend service* a given request even belongs to. A reverse proxy forwards on behalf of a single backend it already knows about; a gateway inspects the request — its path, its host, sometimes a header — and matches it against a routing table that maps `/orders/*` to the order-service, `/users/*` to the user-service, and so on. This is the "application-aware" part of "application-aware reverse proxy": the gateway understands enough about your API surface to route correctly, without understanding anything about what an order or a user actually *is*.

### Routing Decouples the Client From Topology

Because the client only ever sees the gateway's routing table, not the backend services directly, the mapping from path to service becomes an internal implementation detail you're free to change. The order-service can be split into an orders-read-service and an orders-write-service, or moved to a different cluster, or scaled from three instances to thirty, and none of that is visible to a client — only the gateway's routing rules change, and only if the *path* itself changes, which it usually doesn't. This is the direct payoff of the pattern: the cost of evolving your service topology drops from "every caller needs a change" to "update one routing table."

### Statelessness Lets the Edge Scale

None of the above holds up if the gateway itself becomes a bottleneck, and it will unless it obeys the same constraint that made REST (11.1) and reverse proxies (4.5) scalable in the first place: no server-side session tied to a specific gateway instance. A stateless gateway can run as many identical instances behind a plain load balancer, and any instance can handle any request, because none of them privately remembers anything about a client between requests. This is what turns "one edge component" from a liability (a single box that falls over under load) into an asset (a horizontally-scalable layer that's still logically singular from the client's point of view).

### ✅ Checkpoint

1. Explain, using the build chain above, why a gateway that inspects only the *destination IP and port* of a request (like a plain load balancer) cannot do the job a gateway needs to do, even though both sit "in front of" the backend services.

   > 💡 *If you hesitate, re-read "App-Aware Routing" and think about what information a load balancer has versus what a gateway needs to route `/orders/*` correctly.*

2. A teammate proposes adding a small in-memory cache *inside* a single gateway instance, keyed by client IP, to speed up repeated auth checks. Using the build chain, explain what this breaks and why it's the same mistake REST's statelessness constraint (11.1) was built to prevent.

   > 💡 *If you hesitate, trace the build chain from ONE EDGE through STATELESSNESS LETS THE EDGE SCALE — the answer is about what happens when a client's second request lands on a different gateway instance.*

> **→ Next:** You know the pieces. What actually happens, request by request, when a call comes through the gateway?

---

## 6. ⚙️ How It Actually Works

**Happy path — a request through the gateway:**

1. A TLS connection is established with the gateway, which holds the certificate; the gateway decrypts once, and everything behind it runs over a trusted internal network (the same argument 4.5 makes for a single reverse proxy, applied here to every backend at once).
2. The gateway authenticates the request — validates a JWT, checks an API key, or checks a session cookie — *before* any backend sees it. On failure, it returns `401`/`403` immediately; no backend is invoked at all.
3. The gateway checks the request against a rate limit, typically a token bucket keyed by API key or user ID. If the bucket is empty, it returns `429` immediately, protecting every downstream service from that specific overload without any of them having to implement the check themselves.
4. The gateway matches the request's path (most commonly) against a routing table and resolves exactly one backend service — `/orders/*` → order-service. This step is what makes the gateway "application-aware" rather than a generic forwarder.
5. The gateway forwards the request to a healthy instance of that backend (often handing off the instance-level pick to a load balancer), optionally attaching a forwarded-identity header so the backend can trust "this request is already authenticated" instead of re-checking.
6. The backend's response passes back through the gateway to the client, sometimes with response transformation (stripping internal fields, unifying an error shape across services) applied on the way out.

> 🗺️ **Mental model — airport customs and security.** Every passenger, regardless of which airline or gate they're eventually headed to, passes through exactly one security checkpoint: identity is checked once, bags are scanned once, and only after clearing both do you get routed to your specific gate. The airport doesn't make every airline run its own independent security line. *Where it breaks down:* a security checkpoint doesn't dynamically reroute you if your gate changes at the last minute — a gateway's routing table can update to reflect a moved or scaled backend without the passenger (client) needing to be told anything changed at all, which is a stronger guarantee than the analogy provides.

**Failure & edge cases:**

- **The single point of failure.** Every request now depends on the gateway being up. A gateway with a single instance turns a distributed system with N independently-failing services back into a system with one hard dependency. The fix is the same one applied everywhere else in this doc: run multiple stateless gateway instances behind a load balancer, so no single instance's failure takes down the edge.
- **Added latency on every request.** Even a well-optimized gateway hop — TLS termination, auth check, route match — adds real time to every single call, and that cost is paid by every request in the system, not just the ones that need it. This is a cost you pay unconditionally in exchange for the consistency benefit; it doesn't disappear by ignoring it.
- **Orchestration creep.** A gateway that starts as "route and enforce policy" slowly accumulates real aggregation logic — "just call these two other services and merge the results here, it's convenient" — until the gateway itself becomes a service with business logic, deployment risk, and a release cycle every other team now depends on. This is the exact monolith the system was decomposed away from, rebuilt at the edge.
- **Cascading failure without circuit breaking.** If a backend service starts timing out, a gateway that keeps forwarding every request to it and waiting for the timeout will itself back up — its own thread/connection pool fills with requests stuck waiting on a dead backend, and healthy requests to *other* backends start failing too, purely from resource exhaustion at the gateway. A circuit breaker per backend (stop forwarding to a service that's failing, fail fast instead) isolates the blast radius to the one failing service.

**The design pipeline, end to end:**

```
① TLS           ──▶ ② authenticate  ──▶ ③ rate limit    ──▶ ④ match route
   terminated         (401/403 on          (429 on empty        (path/host/header
   once, at edge       failure, no          bucket, no           → exactly one
                        backend called)      backend called)      backend service)
                                                                        │
                                                                        ▼
                                              ⑥ response    ◀──   ⑤ forward to a
                                                 back to           healthy backend
                                                 client             instance
```

**In production**

| System | How it applies | The nuance |
|--------|----------------|------------|
| **Kong** | Built on nginx/OpenResty; auth, rate limiting, logging, and transformation ship as composable plugins rather than a single monolithic codebase | The plugin model is what keeps Kong from becoming its own monolith — you compose only the cross-cutting behaviors a given route actually needs |
| **AWS API Gateway** | Managed gateway with native Lambda integration, usage plans + API keys for per-client rate limiting, and request/response transformation | Fully managed removes the "run stateless instances behind a load balancer" operational burden entirely, at the cost of vendor lock-in to AWS's routing and throttling model |
| **Netflix (Zuul → BFF)** | Started with a single generic gateway (Zuul) in front of all services; moved toward Backend-for-Frontend layers per client type (mobile, TV, web) | The canonical real-world example of a single gateway becoming a routing-and-aggregation bottleneck once client needs diverged enough to justify splitting it |
| **Envoy (as edge gateway)** | The same Envoy proxy that powers Istio's service mesh sidecars (a tension covered in §10) is also used directly as an edge gateway (e.g. via Ambassador, Contour) | Demonstrates that "gateway" and "mesh sidecar" are topological roles, not different pieces of technology — the same proxy, placed differently, does either job |

### ✅ Checkpoint

1. A gateway forwards every request to a backend and blocks waiting for its response, with no circuit breaker configured. Walk through exactly how one backend service becoming slow (not down — just slow) can cause requests to *other, healthy* backends to start failing too, and name the specific mechanism that fixes it.

   > 💡 *If you hesitate, re-read the "Cascading failure without circuit breaking" failure case — the answer is about a shared resource at the gateway, not about the slow backend itself.*

2. A team adds a feature to their gateway: on every incoming order request, the gateway calls the inventory-service to check stock levels and rejects the order at the edge if stock is zero, before ever forwarding to the order-service. Explain why this is the "orchestration creep" failure case specifically, and where that logic should live instead.

   > 💡 *If you hesitate, re-read "Orchestration creep" and the Core Idea's warning about what the gateway is not supposed to understand.*

> **→ Next:** You can trace a request through the gateway. In a live design, when do you actually reach for one, and what does it cost you?

---

## 7. ⚖️ The Decision — When, and What It Costs

The default the moment a system has more than a couple of independently-deployed backend services with any external client is an API gateway at the edge — not per-service reverse proxies, not clients calling services directly. It collapses N auth implementations into one, gives you a single place to enforce and observe rate limiting, and lets your service topology evolve without breaking every caller. You leave that default, or extend it, at specific, nameable boundaries.

**The traffic is internal, service-to-service, not external client traffic.** A gateway is built for north-south traffic — external clients reaching into your system — and applying the same centralized-edge model to east-west traffic (service A calling service B internally) reintroduces the single-point-of-failure and added-latency costs for calls that don't need a client-facing contract at all. This is the boundary where a service mesh sidecar (Envoy/Istio, a decentralized per-service proxy) takes over instead — each service gets its own local proxy instance, so there's no single shared hop and no single shared failure domain for internal traffic.

**Different client types need genuinely different response shapes.** A single generic gateway trying to serve a mobile app, a web app, and a partner API with one aggregation layer will either over-fetch for the client that needs less, or accumulate special-case logic per client type until it becomes the routing-and-aggregation monolith Netflix hit with Zuul. The fix is a Backend-for-Frontend: a thin, separate aggregation layer per client type, sitting behind the shared gateway (or replacing it for that client), shaped to exactly what that client needs.

**The gateway is being asked to do real business logic.** Stock checks, pricing rules, workflow orchestration — none of that is a cross-cutting concern, and putting it in the gateway means every team now depends on the gateway's release cycle for changes that have nothing to do with routing, auth, or rate limiting. If you catch yourself justifying gateway logic with "it's convenient, it's already there," that's the signal to stop and put the logic in the service that owns the domain instead.

**Decision tree:**

```
                    Is this call external (client → your system)
                          or internal (service → service)?
                                      │
              ┌───────external, north-south────────┼────internal, east-west───────┐
              ▼                                     │                             ▼
     API GATEWAY at the edge.                       │                    SERVICE MESH SIDECAR.
     Default. Terminate TLS,                        │                    Per-service proxy
     auth, rate limit, route —                       ▼                   (Envoy/Istio). No
     once, for every backend.          Do different client types
                                        need genuinely different
                                        response shapes?
                                              │
                                    ┌────no────┴────yes────┐
                                    ▼                       ▼
                          Single shared gateway    Backend-for-Frontend
                          is sufficient.            per client type, behind
                          One shape fits all.        the shared gateway.
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Cross-cutting logic exists once** — auth, TLS, and rate limiting are implemented and audited in a single place instead of N times across N services | The gateway is a single point of failure by construction — every external request depends on it being up, which reintroduces the exact "one thing everything depends on" risk decomposition was trying to remove |
| **The client sees one coherent surface** — one hostname, one auth mechanism, regardless of how many backend services exist behind it | Every request pays an added hop of latency, unconditionally — even requests that would have been fine going straight to the backend |
| **Backend services can be moved, split, or scaled without breaking callers** — only the gateway's routing table changes | It's a real thing to capacity-plan, scale, and operate — under-provisioning the gateway throttles every service behind it at once, not just one |
| **Centralized observability** — request volume, error rates, and latency are visible for the whole system's external traffic in one place | Left unchecked, it accumulates aggregation and business logic until it becomes a second, harder-to-deploy monolith sitting in front of the first decomposition |

### ✅ Checkpoint

1. A team's gateway currently authenticates, rate-limits, and routes for six backend services. An engineer proposes also moving all *inter-service* calls (order-service calling inventory-service to check stock) through the same gateway, "since the auth logic is already there." Using the decision tree above, would you agree, and what would you actually recommend instead? Justify against the specific cost you'd be accepting either way.

   > 💡 *If you hesitate, re-read the first boundary condition — north-south vs. east-west traffic — and the trade-off row about the gateway being a single point of failure.*

> **→ Next:** Can you defend this under interview pressure — and hold up when the interviewer pushes on the cost you claimed you'd pay?

---

## 8. 🎯 In the Interview

**When an interviewer asks / says:**
- "How would you handle authentication across all these microservices?"
- "Where would you put rate limiting in this design?"
- "The client's dashboard needs data from three different services — where does that come together?"
- "What happens if this component goes down — doesn't that take out your whole API?"

**What you say / do:**
This surfaces right after you've decomposed the system into multiple services in the high-level design phase — the moment you draw more than one backend box, the interviewer is listening for whether you notice the cross-cutting concerns that now need a home. Lead with the edge, not the backend: name the gateway first, name exactly what moves into it (TLS, auth, rate limiting, routing), and be explicit about what stays out (business logic). When the interviewer pushes on the SPOF risk — and they usually will — that's your cue to name statelessness and horizontal scaling unprompted, not wait to be asked.

**The trade-off statement (memorize this pattern):**
> "I'd put an API gateway — something like Kong or AWS API Gateway — in front of the order-service, user-service, and inventory-service, so a client sees one host and one auth mechanism instead of three. It terminates TLS once, validates the auth token before any backend sees the request, and enforces a per-API-key rate limit with a token bucket, rejecting with `429` before load ever reaches a backend. Path-based routing — `/orders/*` to order-service, `/users/*` to user-service — means I can move, split, or scale a backend without any client-facing change; only the gateway's routing table updates. The cost is that the gateway becomes a single point of failure and adds a hop of latency to every request, so I run it as stateless instances behind a load balancer rather than one box, and I keep it strictly to routing and cross-cutting policy — the moment it starts doing real aggregation or business logic, it's become a second monolith I now have to operate and deploy. I'd change this answer if the traffic in question were service-to-service instead of external — that's a service mesh's job, not the gateway's."

**A second trade-off variant — when the interviewer pushes on client-shape divergence:**
> "If the mobile app, the web app, and a partner API all need meaningfully different data shapes from the same underlying services, I wouldn't try to make one gateway serve all three — that's how you end up with a pile of client-specific branches in a component that's supposed to stay generic. I'd introduce a Backend-for-Frontend per client type: a thin aggregation layer, one per client, sitting behind the shared gateway, each shaped to exactly what that client needs. The cost is now three things to deploy instead of one, but each one stays simple and client-specific instead of the shared gateway accumulating special cases for every client it serves — that's the trade Netflix made when they moved off a single generic Zuul gateway."

### ⚠️ Traps

- ❌ **Trap:** "I'd just have the gateway call the other services directly and stitch the response together — it's already sitting in the request path, so why not?"
  ✅ **Reality:** That's the orchestration-creep failure case. The moment the gateway starts making decisions based on business data (stock levels, pricing, workflow state) instead of routing and policy, it's stopped being a cross-cutting edge component and become a second service with real logic — one that every other team's release now depends on, sitting in the one place you can least afford an outage.

- ❌ **Trap:** "The gateway is basically the same thing as a load balancer, just with a different name."
  ✅ **Reality:** A load balancer picks *which healthy instance* of one known service to send a request to. A gateway first decides *which service* a request even belongs to, applies app-aware policy (auth, rate limiting per API key, path-based routing), and typically hands off to a load balancer afterward for the instance-level pick. They solve different problems and usually both exist in the same request path.

- ❌ **Trap:** "We should route all our internal service-to-service calls through the API gateway too, so we only maintain one routing layer."
  ✅ **Reality:** This conflates north-south and east-west traffic. Routing internal calls through the same edge gateway means every internal call now also depends on that single shared component, and pays its added latency — for traffic that never needed a client-facing contract in the first place. Internal traffic is a service mesh's job precisely because it wants a *decentralized*, per-service proxy, not one more shared bottleneck.

- ❌ **Trap:** "A single gateway instance is fine — we'll just make sure the server it runs on is really beefy."
  ✅ **Reality:** No amount of vertical scaling removes the single-point-of-failure risk; a single instance means a single restart, deploy, or crash takes out every backend service's external traffic at once. The fix is horizontal — multiple stateless gateway instances behind a load balancer — the same 3.1/4.5 argument applied at the gateway layer, not a bigger box.

### ✅ Checkpoint — adversarial stress test

1. You've designed a gateway that authenticates once at the edge and forwards a trusted-identity header (say, `X-User-Id`) to backend services instead of making them re-validate the token. The interviewer pushes: *"What stops a request from reaching a backend service directly, bypassing the gateway entirely, and just setting that `X-User-Id` header itself to impersonate any user it wants? Walk me through exactly what needs to be true at the network level and the backend level for this trusted-header pattern to actually be safe."*

   > 💡 *A complete answer covers: backend services must NOT be reachable from outside the trusted network at all — they sit on a private network/VPC with no public ingress, so the gateway is the only path in, and "bypass the gateway" is not a request path that exists, not merely one that's discouraged. It covers defense in depth: even on a private network, the backend should verify the request came from the gateway specifically (mutual TLS between gateway and backend, or a shared secret/signed header the gateway attaches that a spoofed direct request couldn't produce), not trust `X-User-Id` on its face just because it arrived on the internal network — because "internal network" and "trusted request" are not automatically the same thing once you have more than a few services and any lateral movement risk. If you can't name both the network-isolation requirement AND the additional verification layer, you are not done.*

MODEL ANSWER — §8 Adversarial Stress Test (trusted-header spoofing)

```
THE NETWORK-LEVEL REQUIREMENT
  Backend services must have NO public ingress at all — they're only
  reachable from inside the private network/VPC the gateway also lives
  in. "Bypass the gateway" has to be architecturally impossible, not
  merely something a well-behaved client wouldn't do. If a backend has
  even one exposed port, the trusted-header pattern is broken by
  construction, no matter how careful the gateway's own auth logic is.

WHY NETWORK ISOLATION ALONE ISN'T ENOUGH
  "Internal network" is not the same guarantee as "request came from
  the gateway." Once there's more than a handful of services, or any
  possibility of a compromised service / lateral movement inside the
  network, another internal caller could still set X-User-Id directly
  if nothing checks WHERE the header came from.

THE ADDITIONAL VERIFICATION LAYER
  The backend needs a way to verify the request specifically came from
  the gateway — mutual TLS (mTLS) between gateway and backend is the
  strongest version (the backend only accepts connections presenting a
  cert only the gateway holds); a signed or gateway-secret header the
  gateway attaches (which a spoofed internal caller can't reproduce
  without the secret) is a lighter-weight version of the same idea.

WHY BOTH LAYERS ARE REQUIRED, NOT EITHER/OR
  Network isolation without verification: a compromised or misconfigured
  internal service can still forge the header. Verification without
  network isolation: a public-facing backend could still be hit
  directly, and mTLS alone doesn't stop a public port from existing in
  the first place. The pattern is only safe with both: nothing reaches
  the backend except the gateway (isolation), and the backend confirms
  what did reach it really is the gateway (verification).
```

> **→ Next:** Can you combine what you've learned across sections, not just recall each one?

---

## 9. 🧪 Mastery Gate

> *Synthesis only. Each question must require combining two or more sections.*

1. **(§5 + §6 + 3.1/4.5)** A junior engineer argues that adding a small per-instance cache of validated auth tokens inside each gateway instance (to avoid re-validating the same token on every request from the same client) is a harmless performance optimization. Using the build chain from §5 and the mechanism steps from §6, explain everything that specifically breaks once that per-instance state exists — naming the concrete infrastructure behavior that stops working, not just "it's not stateless anymore."

2. **(§7 + §8, applied to a system not mentioned elsewhere in this doc)** You're designing the API layer for a food delivery platform with three backend services (restaurant-service, order-service, driver-location-service) and two very different clients: a consumer mobile app that needs a fast, minimal "track my order" view, and an internal ops dashboard that needs deep, denormalized data across all three services for support agents. Decide where a gateway fits, where a BFF fits (if at all), and justify the split using the specific cost each client's needs would impose on a single shared layer.

3. **(§4 + §6 + §8)** An interviewer asks what happens to your design if the inventory-service starts timing out under load, and your gateway has no circuit breaker configured. Walk through the failure cascade end to end — from the first slow inventory-service call to the effect on completely unrelated requests going through the same gateway — and name the specific fix, tying it back to why the gateway's shared nature makes this worse than if each service were called directly.

### Mastery criteria — tick only what you can demonstrate on demand

- [ ] Can explain why cross-cutting concerns (auth, TLS termination, rate limiting, routing) belong at a centralized edge rather than duplicated per service, and what specifically breaks when they're duplicated instead
- [ ] Can design path-based (and name host-based/header-based) routing rules that decouple a client from internal service topology
- [ ] Can distinguish an API gateway from a reverse proxy, a load balancer, and a service mesh sidecar, and correctly map north-south vs. east-west traffic to gateway vs. mesh
- [ ] Can explain when to introduce a Backend-for-Frontend instead of one generic gateway, and name the specific cost of not doing so
- [ ] Can name the failure modes a gateway introduces (SPOF, added latency, orchestration creep, cascading failure without circuit breaking) and the specific mitigation for each
- [ ] Can describe the responsibilities of an API gateway (auth, rate limiting, routing, SSL termination) and explain why it belongs at the edge — the topic's own mastery criterion, stated directly

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 10. 🔗 Connections & Sources

**Builds on:** **4.5 Reverse Proxies**, which supplies the exact mechanism (terminate TLS, forward on behalf of a backend) the gateway centralizes across many backends instead of one — a gateway *is* an application-aware reverse proxy, not a different technology. Also **11.1 REST**, which supplies the resource-oriented API surface the gateway routes requests toward, and whose statelessness precondition the gateway itself must obey to scale horizontally.

**Enables:** **11.4 Microservice Decomposition**, where the services being routed to are actually carved out — the gateway is the edge counterpart to that decomposition, the thing that keeps the client from ever seeing the seams. **23.1 Authentication vs. Authorization**, since "authenticate once at the gateway" is the concrete architectural home for that distinction. **25.6 Rate Limiting at CDN, Gateway, and Service Layers**, the direct deep dive on where in the stack rate limiting decisions get made, of which this subtopic covers exactly one layer. **14.5 Service Discovery**, which the gateway's routing table needs in order to know where a scaled or moved backend instance actually lives.

**Tension with:** **Service mesh / sidecar pattern (Envoy, Istio)** directly, on the centralized-edge-proxy-vs-decentralized-per-service-proxy axis — a gateway concentrates cross-cutting concerns for north-south traffic in one place, while a mesh deliberately distributes the same kind of proxy logic to every service for east-west traffic, trading a single shared hop for N independent ones. Neither replaces the other; they answer different traffic directions. Also tension with **11.1 REST**'s "keep the resource shape fixed and simple" — a gateway doing heavy response aggregation is, in effect, quietly rebuilding the multi-resource-shape flexibility REST doesn't natively provide, which is exactly the pressure that pushes toward either GraphQL (11.3) or a BFF instead of gateway-level aggregation.

### 📚 Further reading

- [ ] **Kong Gateway documentation — Plugin Hub** — https://docs.konghq.com/hub/ — see the plugin model in practice: auth, rate limiting, and transformation as composable, independently-deployable units rather than one monolithic gateway codebase
- [ ] **AWS API Gateway Developer Guide — Throttling** — https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-request-throttling.html — the account-level and per-method throttling model referenced in §2/§6
- [ ] **Sam Newman — "Backends For Frontends"** (from *Building Microservices*, and his standalone writing on the pattern) — the canonical treatment of when and why to split a shared gateway into per-client aggregation layers
- [ ] **Netflix Technology Blog — the Zuul and API Gateway evolution posts** — search "Netflix Zuul" and "Netflix API Gateway" on the Netflix Tech Blog — the real production story behind §6/§7's Netflix example
- [ ] **Envoy Proxy documentation — "What is Envoy"** — https://www.envoyproxy.io/docs/envoy/latest/intro/what_is_envoy — read specifically for how the same proxy serves both edge-gateway and service-mesh-sidecar roles, the §10 tension
- [ ] **Istio documentation — "Istio / Envoy relationship"** — https://istio.io/latest/docs/ops/deployment/architecture/ — the mesh-sidecar side of the north-south/east-west distinction

---

## 11. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
