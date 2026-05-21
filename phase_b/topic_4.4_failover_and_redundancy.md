# 4.4 Failover and Redundancy

> **Topic:** Topic 4 — Load Balancing
> **Phase:** B — Scalability Branch
> **Date studied:** 2026-05-20

---

## 1. 🎯 Goal of This Subtopic

> *Why are you studying this? What should you be able to do after this session?*

Be able to design a load balancing setup that has no single point of failure by applying the right failover strategy (active-active vs. active-passive) for a given availability requirement. Understand how redundancy is achieved at each tier — load balancer, application server, and database — and be able to walk an interviewer through the failure path and recovery path of any component in your design. Identify when failover is automatic vs. manual and why that distinction matters.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can define active-active and active-passive failover and state the availability, cost, and complexity trade-off of each without notes.
- [ ] Can design a load balancer setup with no SPOF — including how the load balancer itself is made redundant (floating IP / VRRP / anycast).
- [ ] Can walk through the failure path of any component in a tiered architecture: what fails, who detects it, what happens to in-flight requests, and how the system recovers.
- [ ] Can explain the difference between RTO and RPO and apply both to justify a failover strategy.
- [ ] Can identify when to use warm standby vs. hot standby vs. cold standby based on RTO requirements.

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] **DDIA Chapter 8** — "Trouble with Distributed Systems" (Kleppmann) — fundamental limits of failure detection in async networks
- [ ] **AWS Docs: High Availability and Failover** — docs.aws.amazon.com/whitepapers/latest/real-time-communication-on-aws/high-availability-and-scalability-on-aws.html
- [ ] **Keepalived / VRRP Overview** — keepalived.readthedocs.io — how virtual IPs float between load balancers on failure
- [ ] **ByteByteGo: "How to Avoid Single Points of Failure"** — blog.bytebytego.com — visual walkthrough of redundancy at each tier
- [ ] Read through **Sections 5–9** (Core Definition → How It Works) carefully — don't skim
- [ ] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **Core Definition** from memory, then compare
- [ ] Explain **First Principles** out loud without notes — what was the pain before redundancy existed?
- [ ] Reconstruct the **active-active vs. active-passive** failure paths step by step from memory
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

![4.4 Failover and Redundancy — Mindmap](../assets/images/topic_4.4_failover_and_redundancy_mindmap.png)

```
ONE-LINER
  Failover is the mechanism that routes traffic away from a failed component;
  redundancy is the design that ensures a replacement always exists.

KEY PROPERTIES / RULES
  1. Active-Active:  All nodes handle traffic simultaneously; failover = traffic redistributed.
  2. Active-Passive: One hot standby — takes over via floating IP/DNS flip on primary failure.
  3. LB redundancy:  The LB itself must be redundant (VRRP/floating IP) or it IS the SPOF.
  4. Detection lag:  Failover can't happen faster than health check detects failure
                    (interval × fall_threshold).
  5. RTO vs. RPO:   RTO = how fast you recover; RPO = how much data you can lose.

DECISION RULE
  Use active-active when: cost allows it and stateless routing makes it feasible.
  Use active-passive when: cost is constrained or state makes dual-active unsafe.
  Always: make the LB itself redundant before worrying about backend redundancy.

NUMBERS / FORMULAS
  Failover detection window = health_check_interval × fall_threshold
  e.g., 5s interval × 3 failures = up to 15s of impact before failover
  Active-active: ~50% capacity loss per node failure (plan headroom accordingly)

GOTCHA TO NEVER FORGET
  Adding a second load balancer without a floating IP just moves the SPOF — it doesn't
  eliminate it.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

**Failover** is the automatic (or manual) process of redirecting traffic from a failed component to a healthy standby, while **redundancy** is the architectural practice of provisioning duplicate components so that no single failure takes down the system.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic.*

### Active-Active Failover
In active-active, all nodes in the redundancy group simultaneously serve traffic. When one node fails, the load balancer simply stops routing to it and the remaining nodes absorb its share. This maximizes resource utilization but requires every node to be sized to handle the full load redistribution — a cluster of 3 nodes each at 33% must survive at 50% if one fails. Stateless services fit naturally; stateful services require session replication or externalized state.

### Active-Passive Failover
In active-passive, one primary node handles all traffic while one or more standby nodes sit idle (or handle minimal load). On failure, a floating IP or DNS update flips traffic to the standby. The standby can be hot (running, in sync, near-instant takeover), warm (running but partially synced, short recovery time), or cold (off, full boot required, long recovery). Hot standby is expensive but achieves RTO of seconds; cold standby is cheap but can mean minutes or longer of downtime.

### Floating IP / VRRP
The load balancer itself is a component that can fail. To avoid making it a SPOF, two LB nodes share a Virtual IP (VIP) using VRRP (Virtual Router Redundancy Protocol) or a cloud-native equivalent. The VIP is "owned" by the primary LB. If the primary dies, the secondary claims the VIP within seconds — from the client's perspective, the IP never changed. Without this, adding a second LB is theater: DNS or upstream routing still points at one specific machine.

### RTO and RPO
Recovery Time Objective (RTO) is how quickly the system must be restored after a failure — the acceptable downtime window. Recovery Point Objective (RPO) is how much data loss is acceptable — the acceptable staleness of the standby. A financial ledger might require RPO = 0 (zero data loss, synchronous replication required) and RTO = 30 seconds. An analytics dashboard might accept RPO = 1 hour and RTO = 10 minutes. Failover strategy selection is fundamentally driven by these two parameters.

### Failover Detection and Propagation
Failover cannot happen faster than the health check system detects the failure. Detection latency = `check_interval × fall_threshold`. After detection, the LB must drain in-flight connections (or abruptly drop them), update its routing table, and optionally signal DNS. DNS propagation adds further delay if failover relies on it (TTLs of 30–60 seconds are common). For sub-second failover, floating IPs at the network layer are far faster than DNS-based cutover.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

In any sufficiently large system, failure of individual components is not exceptional — it is the baseline expectation. Hardware fails, processes crash, networks partition, deployments introduce bugs. Before redundancy patterns were formalized, a single server failure meant full service outage. The root pain: no single piece of software can guarantee its own availability, because it cannot rescue itself after a crash. The solution is to externalize responsibility for failure detection and recovery to a separate component (the load balancer and standby nodes), which observes the failing component from outside and routes around it. Redundancy formalizes this into an architectural property — not a heroic operational response, but a designed-in capability.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast.*

### Model 1: The Understudy Actor
Think of active-passive like a Broadway understudy: the primary actor is always on stage; the understudy watches every rehearsal and knows every line, but never goes on unless the star is incapacitated. The audience (traffic) sees the same show. The cost: you pay two salaries but get one performance at a time. The limit: the understudy still needs lead time to take the stage — the faster the handoff, the more expensive the preparation.

### Model 2: The Two-Lane Highway
Active-active is a two-lane highway where both lanes carry traffic simultaneously. If one lane is blocked, all traffic shifts to the other — it slows down but keeps moving. This model breaks when you forget that a two-lane highway with a two-lane demand is already at 100% capacity: one lane closure → gridlock. Capacity headroom is non-negotiable in active-active designs.

### Model 3: The Floating Phone Number
A floating IP / VRRP is like a Google Voice number: the number never changes, but which phone it rings is reassigned on the fly. Clients call the same number (VIP) and the routing infrastructure silently updates which physical machine answers. This is why LB redundancy via floating IP is invisible to clients — unlike DNS failover, which forces every client to re-resolve.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step explanation of the internal mechanism.*

**Active-Passive Failover Flow (Happy Path):**
1. Primary LB serves all traffic. Secondary LB runs VRRP heartbeats to primary every ~1s.
2. Primary LB runs health checks against all backend nodes (e.g., HTTP GET /health every 5s, fall threshold = 3).
3. If a backend fails 3 consecutive checks → LB marks it down, stops routing new connections, drains existing connections (connection draining, typically 30s), then removes from pool.
4. If primary LB itself fails → VRRP heartbeat stops → secondary LB claims the floating VIP after `dead_interval` (typically 3s) → clients resume connecting, unaware of the switch.

**Active-Active Failover Flow:**
1. Two (or more) LBs both hold the VIP via anycast or DNS round-robin. Both simultaneously receive and route traffic.
2. Each LB independently monitors backend health. Both update their own routing tables.
3. On backend failure: whichever LB detects it removes it from its pool. Both should converge to the same view within one check cycle.
4. On LB failure: traffic naturally stops arriving at the failed LB (TCP connections time out); clients retry and hit the surviving LB.

**Key parameters to memorize:**
- Health check interval: 5–10s is typical production default
- Fall threshold: 2–3 consecutive failures (balances detection speed vs. flap sensitivity)
- Rise threshold: 2–3 consecutive successes before re-adding to pool (prevents oscillation)
- VRRP dead interval: 3 × advertisement interval (typically 3s)
- Connection draining: 15–60s depending on request duration

**Stateful failover consideration:** If the primary holds session state in memory and fails, the passive inherits the VIP but not the session state. This is why session state must be externalized (Redis, database) before active-passive failover is truly seamless.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| AWS ELB / ALB | Active-active across multiple AZs; each AZ runs independent LB nodes; cross-zone load balancing distributes traffic evenly | AWS abstracts VRRP — you configure multi-AZ and AWS handles LB redundancy |
| HAProxy + Keepalived | Classic on-prem pattern: two HAProxy nodes share a VIP via VRRP (Keepalived); primary serves, secondary takes VIP if primary's VRRP heartbeat stops | VRRP dead interval ~3s; failover is near-instant and DNS-independent |
| Nginx + Keepalived | Same pattern as HAProxy — common in self-managed Kubernetes ingress setups | Keepalived also supports health check scripts to demote the primary if Nginx process dies |
| Google Cloud DNS with health checks | DNS-based failover: health check failure → DNS record automatically updated to point to backup IP | DNS TTL of 30–60s means 30–60s of impact even after health check detects failure — slower than floating IP |
| MySQL with MHA / Orchestrator | Active-passive database failover: replica is promoted to primary on primary failure; VIP or DNS updated to point at new primary | RPO depends on whether sync or async replication was used; async replication can mean seconds of data loss |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Active-active: full resource utilization, seamless failover | Requires stateless or replicated state; capacity must be headroom-aware (N-1 capacity planning) |
| Active-passive: simpler state management, no split-brain risk | Idle standby wastes 50%+ of resource cost; failover takes longer (VRRP or DNS flip) |
| Floating IP (VRRP): near-instant, client-transparent LB failover | Only works on L2-adjacent nodes (same subnet/VLAN); not viable across datacenters or cloud regions |
| DNS-based failover: works globally across regions | DNS TTL means 30–300s of in-flight requests still hitting the failed node after failover triggers |
| Hot standby: RTO of seconds | Doubles hardware/cloud cost; synchronous replication required for RPO = 0, adding write latency |
| Cold standby: minimal cost | RTO of minutes to tens of minutes; unacceptable for low-tolerance services |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview?*

**When an interviewer asks / says:**
- "What happens when this load balancer goes down?"
- "How do you ensure high availability for the frontend tier?"
- "What's your recovery time if the primary database fails?"
- "Walk me through a failure scenario — how does your system recover?"

**What you say / do:**
When asked about availability, immediately address each tier top-to-bottom: load balancer → application servers → database. For the LB, name VRRP/floating IP for on-prem or multi-AZ ELB for cloud. For app servers, state active-active with health-check-based eviction. For database, name active-passive with a stated RTO/RPO. This structured sweep signals system-level thinking.

**The trade-off statement (memorize this pattern):**
> "If we choose active-active, we get zero-downtime failover and full resource utilization, but we pay in complexity — every node must be stateless or share state, and we must size each node for N-1 capacity. For this system's stateless API tier, active-active is the right call. For the database, we'll use active-passive with async replication — accepting a potential RPO of a few seconds — because synchronous replication would add write latency we can't afford."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong?*

- ❌ **Misconception:** Adding a second load balancer eliminates the LB SPOF.
  ✅ **Reality:** Only if both share a floating IP (VRRP) or DNS round-robin routes to both. If upstream DNS or the router still points to a single IP, the second LB is unreachable on primary failure — it's not a hot standby, it's a cold one you can't reach.

- ❌ **Misconception:** Active-active is strictly better than active-passive because both nodes are utilized.
  ✅ **Reality:** Active-active requires stateless design or synchronized state. For stateful services (session-heavy, write-heavy databases), active-active creates split-brain risk. Active-passive is often the correct and safer choice for databases.

- ❌ **Misconception:** DNS failover is fast because health checks trigger it immediately.
  ✅ **Reality:** DNS failover triggers the DNS record update immediately, but clients cache the old record until TTL expires (30–300s). In-flight requests and new connections from clients with a cached record still hit the dead node. Floating IP failover has no such lag.

- ❌ **Misconception:** Failover automatically handles in-flight requests without any user impact.
  ✅ **Reality:** TCP connections to the failed node are dropped. Connection draining reduces the impact window but cannot eliminate it for already-established connections to a crashed (vs. gracefully removed) node. Brief user errors during failover are expected — the goal is to minimize, not eliminate, the window.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** 4.3 Health Checks and Failure Detection — failover can't trigger without health check detecting failure first; the detection latency formula (interval × fall_threshold) directly bounds the fastest possible failover time.
- **Enables:** 4.7 Global vs. Local Load Balancing — multi-region failover is the global-scale extension of the same active-passive / active-active patterns, with DNS-based routing replacing VRRP.
- **Tension with:** 2.7 Stateless vs. Stateful Systems — active-active failover is trivial for stateless services and dangerous for stateful ones; this is why stateless design (Topic 3) is the prerequisite for scalable, simple failover.

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking?*

1. What is the difference between active-active and active-passive failover? Give one scenario where each is clearly the right choice.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6.*

2. A system uses two HAProxy load balancers with Keepalived. The VRRP advertisement interval is 1s and the dead interval is 3s. How long does it take for the secondary to claim the VIP after the primary crashes?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 9.*

3. What is the cost of DNS-based failover that floating IP (VRRP) avoids? When would you still use DNS-based failover despite this cost?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Sections 9 and 11.*

4. Name a real system that uses active-passive database failover and explain what determines its RPO in that configuration.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 10.*

5. An interviewer says: "Your design has two load balancers — so there's no SPOF at the LB tier, right?" What's the missing detail you need to verify before agreeing?

   > 💡 *Think through your answer before expanding — this is a gotcha question — revisit Section 13.*

---

## 16. 📚 Further Reading

> *High-quality resources for deeper understanding.*

- [ ] **DDIA Chapter 8** — "Trouble with Distributed Systems" — Kleppmann; covers why failure detection in async networks is fundamentally bounded, which explains why failover will always have a non-zero detection window
- [ ] **AWS Whitepaper: High Availability and Scalability on AWS** — docs.aws.amazon.com/whitepapers/latest/real-time-communication-on-aws/high-availability-and-scalability-on-aws.html — practical failover architecture patterns for cloud deployments
- [ ] **Keepalived Documentation** — keepalived.readthedocs.io — canonical reference for VRRP-based floating IP failover; excellent for understanding the VRRP state machine
- [ ] **ByteByteGo: "How to Avoid Single Points of Failure"** — blog.bytebytego.com — visual, interview-ready walkthrough of redundancy at each tier

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

