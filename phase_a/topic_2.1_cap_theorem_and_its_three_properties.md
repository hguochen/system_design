# 2.1 CAP Theorem and Its Three Properties

> **Topic:** Topic 2 — System Design Core Principles & Scalability Fundamentals
> **Phase:** A — Core First Principles
> **Date studied:** 2026-04-21

* * *


## 1. 🎯 Goal of This Subtopic

* Be able to name and define all three CAP properties and explain what violating each one means in a real system
* Understand why "CA" is not a realistic choice for distributed systems and what the real trade-off space actually is
* Identify whether a given system requirement calls for a CP or AP design and justify the choice
* Connect CAP reasoning to real production systems (e.g., Cassandra as AP, HBase as CP)

* * *


## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*


- [x] Can define Consistency, Availability, and Partition Tolerance without notes and explain what each one means when violated
- [x] Can explain why no distributed system can be both fully consistent and fully available during a partition — and why P is non-negotiable
- [x] Can classify at least four real systems (e.g., Zookeeper, Cassandra, DynamoDB, HBase) as CP or AP and justify each with a behavioral reason
- [ ] Can take a fictional system requirement and identify the correct CAP classification, explaining the consistency trade-off being made
- [ ] Can articulate the key limitation of CAP (partition-only framing) and explain why PACELC extends it

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

* * *


## 3. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

**One-liner:**
> [The single most important sentence about this concept.]

**Key properties / rules:**

* [Bullet: most important property]
* [Bullet: second most important]
* [Bullet: third — keep to ≤5 bullets total]

**Decision rule:**
> Use [X] when [condition]. Avoid [X] when [condition].

**Numbers / formulas to remember:**

* [e.g., Quorum: R + W > N]
* [e.g., Rule of thumb for X]

**Gotcha to never forget:**
> [The one thing candidates get wrong. One sentence.]

* * *


## 4. 🧠 Core Definition

> *What is it, in one sentence?*

[Write a crisp 1-2 sentence definition here. Aim for something you could say out loud in an interview without hedging.]

CAP in CAP Theorem stands for Consistency, Availability and Partition Tolerance. 


```
Consistency:
After a write completes. All clients receive the latest value regardless of which node they read from

Availability:
The request to a non-failing node must receive a valid response. A timeout or error is not acceptable

Partition Tolerance:
The system continues to operate despite messages being dropped as the network is
partitioned.
```

Availability: The request to a non-failing node must receive a valid response. A timeout or error is not acceptable.
Partition tolerance: The system continues to operate despite having packages dropped as network is partitioned.

The theorem states that partition tolerance is not a design choice. It is a certainty in any distributed system. Networks will fail. When a network partition happens, we can only choose 1 of the remaining 2, Consistency or Availability.

* When we choose consistency, we build a CP system. The node refuses to respond during a partition rather than risk returning stale data.
* When we choose availability we build an AP system. The node always responds even if the data may be stale

* * *


## 5. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*


### Consistency

* After a write completes, all clients receive the latest value regardless of which note they read from

Why it matters

* Inconsistency in distributed systems doesn't just confuse users — it can cause double-spending, overselling inventory, acquiring the same lock twice, or split-brain decisions. The cost isn't just credibility — it's data corruption that can be impossible to reverse.



### Availability

* The request to a non-failing node must receive a valid response. A timeout or error is not acceptable

Why it matters

* Availability matters because an unavailable node creates cascading failures. If Service A calls Service B and B returns a timeout, A must either fail too or implement complex fallback logic. In high-traffic systems, even brief unavailability causes request queues to pile up, threads to exhaust, and the entire system to degrade — not just the partitioned node.



### Partition Tolerance

* The system continues to operate despite messages being dropped as the network is partitioned.

Why it matters

* Partition tolerance matters because network partitions are not edge cases - they are guaranteed to occur in any distributed system. Switches fail, packets drop, data centers split. A system that is not designed to tolerate partitions has undefined behavior when a partition occurs. The designer who ignores P hasn’t avoid the problem - they’ve just left it unhandled.

### CAP Core Idea

Because partitions are certain, the real design decision is: when a partition occurs, which do you sacrifice- C or A?
This is not a theoretical trade-off. It is a concrete engineering decision that determines whether your system becomes CP or AP.


|Classification	|Behavior during partition	|
|---	|---	|
|CP	|Node refuses to respond - returns error rather than stale data	|
|AP	|Node always responds - may return stale data	|

### CA doesn’t exist

CA systems don't exist in distributed systems because P cannot be avoided. A single-node database is CA by definition but it is not a distributed system
* * *


## 6. 🔍 First Principles — Why Does This Exist?

CAP theorem exists because **reliable coordination is impossible over an unreliable network** — and once you accept that, you must explicitly choose what your system does when coordination fails.

**The single-node world has no CAP problem**


* A single database server is simple. One machine holds the data, one machine responds to requests. Consistency is guaranteed by default because there is only one copy of the data.


**The moment you add a second node, a new problem emerges**


* You add a second node to handle more traffic, survive hardware failure, or serve users across geographic regions.
* Once two nodes hold the same data, they must agree on the current state of that data.
* The only way they can agree is by communicating over a network.
* Networks are unreliable — packets drop, switches fail, cables are cut. This is not an engineering failure. It is a physical   certainty at scale.


**When the network fails, nodes diverge**


* Node A receives a write. Before it can inform Node B, the network drops. Node B now has stale data.
* When Node B receives a read request, it faces an impossible choice:
* Respond immediately with stale data → available but inconsistent (AP)
* Refuse to respond until the network recovers → consistent but unavailable (CP)
* There is no third option. Node B cannot be both correct and responsive when it has no way to know what it doesn't know.


**CAP theorem formalizes this inescapable dilemma**


* Brewer identified in 2000 — formally proved by Gilbert and Lynch in 2002 — that this is not a fixable engineering problem. It is a mathematical certainty.
* CAP exists to give engineers precise language for a trade-off that was previously handled implicitly, inconsistently, and often incorrectly.
* Every distributed system must answer: when coordination fails, what does your system do?


**One-liner:**

* Reliable coordination is impossible over an unreliable network. CAP forces you to explicitly choose what your system does when coordination fails.

* * *


## 7. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*


### Model 1: The emergency room triage

[Describe the analogy, frame, or heuristic. Good mental models are vivid and transferable — e.g., "CAP theorem is like a 3-legged stool: you can only lean on 2 legs at once." Explain why the model works and where it breaks down.]
A hospital emergency room during a disaster(the partition) has two options:

* CP behavior: Refuse to treat any patient until the full medical record system is back online and every doctor has the complete consistent patient history. No one gets treated with incomplete information. A patient dies waiting
* AP behavior: Treat patients immediately with whatever information is available locally even if some records are outdated or missing. People get treated but a doctor might not know about a drug allergy recorded in another system

Why it works: Captures the real human cost of each trade-off. Consistency isn't free. Refusing to respond has consequences. Availability isn't free. Still data has consequences. The right choice depends entirely on what kind of harm you can tolerate.

### Model 2: The telephone game under silence

Imagine five people standing in a circle, each holding a piece of paper with a number. They can only know the current number by passing notes to each other. Now someone cuts the string between two people, the partition

* People who can still pass notes can stay in sync
* Created by Card Face A Choice. Do they stop responding until the string is repaired (CP) or do they keep responding with the last number they know (AP)?

Why it works: It makes the mechanics of node divergence visceral. The string being cut is not a catastrophic event. It happens quietly in the middle of normal operation. The system doesn't know when it will be repaired. It must decide its behavior right now

### Model 3: The dimmer switch not a light switch

Most people think CAP is a binary: You are either CP or AP. Klepperman's critique is that consistency and availability are both dials not switches. 
Think of a demo switch rather than an on/off switch

* Cassandra with W=1, R=1 → dial turned fully toward availability
* Cassandra with W=QUORUM, R=QUORUM → dial turned toward consistency
* DynamoDB with eventual reads → availability dial up
* DynamoDB with strongly consistent reads → consistency dial up

Why it works: It directly counters the most common CAP misconception that classification is permanent and binary. In practice the same database can behave like CP or AP depending on how you configure it. The label is a default not a destiny.
* * *


## 8. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

**Normal operation (happy path)**

* Client sends a write to Node A
* Node A updates its local state and propagates the change to Node B and Node C via the network
* All nodes acknowledge the write
* Any subsequent read from any node returns the latest value — consistency holds
* All nodes respond to requests — availability holds
* System is functioning as both consistent and available

**Network partition occurs**

* The network link between Node A and Node B drops
* Node A can no longer communicate with Node B
* Node A receives a new write — updates its local state
* Node B does not receive this update — its data is now stale
* Node B receives a read request — it must now make a decision

**The decision point — CP or AP**

* Node B cannot know what it doesn't know. It has stale data but no way to detect how stale
* It faces exactly one choice:

| Path | What Node B does | Property preserved | Property sacrificed |
|---|---|---|---|
| CP | Refuses to respond — returns error or blocks | Consistency | Availability |
| AP | Responds immediately with stale data | Availability | Consistency |

**CP path — step by step**

* Node B detects it cannot reach quorum (cannot confirm its data is latest)
* Node B rejects the read request — returns an error or timeout
* Client receives no data — must retry or fail
* When the partition heals and Node B re-syncs with Node A, it resumes serving requests
* Data is always correct — but the system was silent during the partition window

**AP path — step by step**

* Node B receives the read request
* Node B responds immediately with its local state — even though it may be stale
* Client receives data — potentially outdated but a valid response
* When the partition heals, Node B reconciles diverged state with Node A
* Conflict resolution strategies: last-write-wins, vector clocks, CRDTs
* Data may have been wrong during the partition window — but the system was never silent

**Partition recovery**

* Network link is restored between Node A and Node B
* Nodes exchange their diverged state
* CP systems: Node B was already consistent — no reconciliation needed
* AP systems: conflicting writes must be resolved using a conflict resolution strategy
* Normal operation resumes

* * *


## 9. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | Classification | Behavioral Reason |
|---|---|---|
| Cassandra | AP | Uses leaderless replication. By default W=1, R=1 — writes are acknowledged after reaching one node. During a partition, nodes keep responding with potentially stale data. Conflicts resolved via last-write-wins on partition recovery. |
| DynamoDB (default) | AP | Serves eventually consistent reads by default — returns data from nearest replica without waiting for all replicas to agree. Keeps responding during a partition even if data is stale. Can opt into strongly consistent reads at the cost of higher latency. |
| Zookeeper | CP | Uses ZAB (Zookeeper Atomic Broadcast) consensus protocol. Requires a quorum (majority of nodes) to process any write. During a partition, nodes that cannot reach quorum refuse to serve requests entirely — goes silent rather than risk returning inconsistent state. |
| HBase | CP | Built on top of HDFS and uses Zookeeper for coordination. Strongly consistent reads and writes — a read always reflects the last successful write. During a partition, HBase will refuse requests rather than return stale data. Used where correctness is non-negotiable. |
| Google Spanner | CP (with nuance) | Globally distributed CP system. Uses TrueTime (GPS + atomic clocks) to achieve external consistency across regions. Chooses consistency over availability during a partition — but partitions are extremely rare given Google's private network infrastructure. |

**Key behavioral pattern to remember:**

* AP systems (Cassandra, DynamoDB default): keep responding during a partition — stale data is acceptable, silence is not
* CP systems (Zookeeper, HBase, Spanner): go silent during a partition — returning wrong data is worse than returning nothing

**The label is not permanent — configuration matters:**

* Cassandra with W=QUORUM, R=QUORUM → behaves like CP
* DynamoDB with strongly consistent reads → behaves like CP for that read
* The CP/AP label describes default behavior, not a fixed identity


* * *


## 10. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

**Choosing CP (consistency over availability)**

| ✅ Benefit | ❌ Cost / Limitation |
|---|---|
| Data is always correct — no stale reads, no conflicting writes | Nodes go silent during partition — clients get errors or timeouts |
| Safe for systems where correctness is critical (banking, locks, leader election) | Cascading failures if dependent services cannot handle errors gracefully |
| Simpler conflict resolution — no diverged state to reconcile on recovery | Lower availability — system may be briefly unreachable during partition window |

**Choosing AP (availability over consistency)**

| ✅ Benefit | ❌ Cost / Limitation |
|---|---|
| Always responds — no silent failures, no cascading timeouts | Data may be stale — clients can read outdated values during a partition |
| Better user experience during network failures | Conflicts must be resolved on partition recovery — adds system complexity |
| Higher availability — system stays reachable even during partition window | Conflict resolution strategies (LWW, CRDTs) add engineering overhead |

**CAP theorem itself as a framework**

| ✅ Benefit | ❌ Cost / Limitation |
|---|---|
| Forces an explicit design decision about partition behavior | Oversimplifies the consistency spectrum — C and A are dials, not binary switches |
| Gives engineers a shared vocabulary for discussing distributed system trade-offs | Only describes behavior during partitions — ignores latency trade-offs during normal operation (PACELC addresses this) |


* * *


## 11. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**

* "What happens if two nodes can't communicate?"
* "How do you ensure data consistency across nodes?"
* "The system must always accept writes / reads — even during failures"
* "What database would you choose for this and why?"
* "How does your system handle network failures?"
* "Walk me through the consistency trade-offs in your design"

**Where in the interview this appears:**

* **Requirements stage** — clarify whether the system requires strong consistency or can tolerate stale data. This is the question that determines CP vs AP before you draw a single box.
* **High-level design** — when selecting a database or storage layer, state its CAP classification and tie it to the requirement.
* **Deep dive / trade-off discussion** — when asked to justify a choice, use the trade-off statement below.

**What you say / do:**

During requirements, ask: *"Does this system require that every read reflects the latest write, or can we tolerate briefly stale data in exchange for higher availability?"* The answer determines CP vs AP before you touch the design.

When classifying a system: state the classification, give the behavioral reason, and tie it to the requirement. Do not just name the label.

**The trade-off statement (memorize this pattern):**

> "If we choose consistency (CP), we get correct data on every read, but nodes will refuse to respond during a partition. For this system — a financial ledger — correctness is non-negotiable, so CP is the right call even at the cost of brief unavailability."

> "If we choose availability (AP), we always respond even during a partition, but clients may read stale data. For this system — a social media feed — stale data for a few seconds is acceptable, so AP is the right call."

* * *


## 12. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance does the interviewer is probing for?*

* ❌ **Misconception:** CA systems exist — you can build a system that is both consistent and available by avoiding partitions (e.g., using a single datacenter)
  
  ✅ **Reality:** Partitions cannot be avoided even within a single datacenter — failed switches, bad NICs, and dropped packets all cause partitions. CA is only valid for a single-node system, which is not a distributed system. A system that claims CA simply has undefined behavior when a partition inevitably occurs.

* ❌ **Misconception:** Partition tolerance is a design choice — you can opt out of P and choose CA instead
  
  ✅ **Reality:** P is not a choice — it is an assumption. Networks will fail. The real choice has always been: when a partition occurs, do you sacrifice C or A? The "choose 2 of 3" framing is misleading because P is always assumed.

* ❌ **Misconception:** CP/AP is a permanent, binary classification — a database is either one or the other
  
  ✅ **Reality:** C and A are dials, not switches. The same database can behave differently depending on configuration. Cassandra with W=QUORUM, R=QUORUM behaves like CP. DynamoDB with strongly consistent reads behaves like CP for that read. The label describes default behavior, not a fixed identity.

* ❌ **Misconception:** CAP Consistency is the same as ACID Consistency
  
  ✅ **Reality:** Completely different guarantees. CAP consistency = all replicas return the latest value immediately after a write (linearizability — a distributed systems property). ACID consistency = a transaction leaves the database in a valid state respecting all business rules (an application-level property). Same word, unrelated concepts.

* ❌ **Misconception:** CAP Availability is the same as High Availability (99.99% uptime)
  
  ✅ **Reality:** CAP availability is a formal, binary, node-level guarantee that only applies during a partition. High availability is an operational uptime metric achieved through redundancy and failover. A CP system can be 99.99% highly available because partitions are rare — even though it sacrifices CAP availability when a partition does occur.

* ❌ **Misconception:** Zookeeper is fully linearizable (strongly consistent) on all reads
  
  ✅ **Reality:** Zookeeper followers can return stale reads by default. To guarantee a linearizable read, you must call sync() before the read to force the follower to catch up with the leader. Calling Zookeeper "CP" without this nuance is an oversimplification.

* * *


## 13. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

* **Builds on:** The physical reality that distributed nodes communicate over unreliable networks — packets drop, switches fail, links go down. CAP theorem only makes sense if you first accept that network failures are inevitable and unpreventable at scale.

* **Enables:**
  * **2.2 PACELC** — PACELC is a direct extension of CAP. CAP describes the partition trade-off; PACELC adds the latency vs. consistency trade-off that exists during normal operation. You cannot understand PACELC without first owning CAP.
  * **2.5 Consistency vs. Availability spectrum** — CAP defines the two poles (strong consistency vs. full availability). Topic 2.5 fills in the spectrum between them — eventual consistency, causal consistency, read-your-writes, etc.
  * **Topic 8 Database Fundamentals** — CAP classification is the first filter when choosing a database. CP or AP determines which class of database is even in consideration before evaluating schema, query patterns, or scale.
  * **Topic 17 Consistency Models** — Linearizability (CAP's C), sequential consistency, causal consistency, and eventual consistency are the detailed, formal definitions of what CAP's C actually means along the spectrum.

* **Tension with:**
  * **ACID Consistency (Topic 8)** — Same word, completely different guarantee. CAP C is about replica agreement across nodes. ACID C is about application invariant preservation within a transaction. Conflating these is one of the most common misconceptions in system design interviews.
  * **High Availability (Topic 19)** — CAP availability and operational high availability are orthogonal. A CP system that refuses requests during partitions can still achieve 99.99% uptime because partitions are rare. Treating CAP availability and HA as the same thing leads to wrong design decisions.
  * **PACELC (2.2)** — PACELC critiques CAP's partition-only framing. CAP ignores latency during normal operation — PACELC exposes this as the more common day-to-day trade-off.

* * *


## 14. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*


1. [Core definition question — "What is X?"]
2. [Application question — "Given Y requirement, would you use X or Z?"]
3. [Trade-off question — "What does X cost you?"]
4. [Example question — "Name a real system that uses X and explain why."]
5. [Edge case question — "What breaks if you apply X in scenario W?"]

* * *


## 15. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [x] [CAP Theorem — Wikipedia](https://en.wikipedia.org/wiki/CAP_theorem) — Brewer's original conjecture, the Gilbert-Lynch formal proof, and the standard definitions. Good starting point.
- [x] [Please Stop Calling Databases CP or AP — Martin Kleppmann (2015)](https://martin.kleppmann.com/2015/05/11/please-stop-calling-databases-cp-or-ap.html) — The most important corrective to the oversimplified CAP framing. Explains why the binary label breaks down for real systems like Zookeeper and Cassandra.
- [x] Designing Data-Intensive Applications — Kleppmann, Chapter 9: *Linearizability* and *The Cost of Linearizability* sections — Formal definition of CAP's C as linearizability, and the explicit CAP theorem critique. ~25-30 pages focused reading.
- [x] Designing Data-Intensive Applications — Kleppmann, Chapter 8: *Unreliable Networks* section — Builds the case for why partitions are inevitable at any scale. Read before Chapter 9 for full context.
- [ ] [Towards Robust Distributed Systems — Eric Brewer (2000)](https://sites.cs.ucsb.edu/~rich/class/cs293b-cloud/papers/Brewer_podc_keynote_2000.pdf) — Brewer's original CAP conjecture keynote at PODC 2000. Short read, historically important.
- [ ] [CAP Twelve Years Later: How the "Rules" Have Changed — Eric Brewer (2012)](https://www.infoq.com/articles/cap-twelve-years-later-how-the-rules-have-changed/) — Brewer's own revisit and clarification of CAP, including partition management and the "2 of 3 is misleading" critique. Directly relevant to Q3 from today's session.

* * *


## 16. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

[Free-form space for your own annotations. Add examples that clicked, diagrams you sketched, or interview stories you connected to this concept.]

* * *

## 17. Q&A

**What is consistency?**
Consistency means All nodes see the same data at the same time

**How is consistency defined in CAP theorem different from consistency guaranteed in ACID database transactions?**
CAP consistency means after a write completes, any subsequent read from any node returns the latest value. No stale reads are allowed
ACID consistency means every transaction takes the database from one valid state to another valid state. All defined constraints and business rules must hold before and after
To summarize:

* CAP consistency =all nodes see the same value now
* ACID consistency = all rules still hold after this transaction


**What is availability?**
Availability = every request to a healthy node gets a valid response, always — stale data is acceptable, silence is not.

**How is availability in the CAP theorem different from high availability in software architecture?**
CAP Availability says nothing about uptime, redundancy, or how often the system is unreachable. It only governs node behavior when the network splits
High availability is an operational metric. The percentage of time a system is accessible and functional, typically expressed in “nines”

To summarize:

* CAP availability = will this node respond during a partition?
* High availability = is this system up and reachable over time?

**What is partition tolerance?**
The system continues to operate despite an arbitrary number of messages being dropped or delayed at the network between nodes
* * *

## 18. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*


### Phase 1 — Acquire 📖

*Goal: Get CAP into your head clearly — including what it does and doesn't say.*


- [x] Read the [CAP theorem Wikipedia article](https://en.wikipedia.org/wiki/CAP_theorem) — focus on Brewer's original conjecture and the formal proof intuition
- [x] Read [*Please stop calling databases CP or AP*](https://martin.kleppmann.com/2015/05/11/please-stop-calling-databases-cp-or-ap.html) by Martin Kleppmann — this is the most important corrective to the oversimplified CAP framing most candidates use
- [x] Skim the CAP chapter in *Designing Data-Intensive Applications* (Kleppmann, Chapter 9) — focus on the consistency vs. availability spectrum
- [x] Fill in **Core Definition** and **Core Concepts** from memory after reading (close all tabs first)

### Phase 2 — Consolidate ✍️

*Goal: Write it out in your own words. If you can't write it, you don't own it.*


- [x] Fill in **First Principles** — answer: "What problem were distributed system engineers hitting before CAP was formalised?"
- [x] Fill in **Mental Models** — write at least one analogy for why P is non-negotiable in a networked system
- [x] Fill in **How It Works** — explain the partition scenario step by step: what the two nodes must choose between, and why they can't have both
- [x] Fill in **Trade-offs** table — one row for CP choice, one row for AP choice

### Phase 3 — Apply 🔧

*Goal: Map CAP to systems you will actually be asked about in interviews.*


- [x] Fill in **Real-World System Examples** — look up and verify: Cassandra (AP), HBase (CP), ZooKeeper (CP), DynamoDB (AP by default), Spanner (CP with nuance)
- [x] Fill in **Interview Application** — write your CAP framing for the requirements stage: when you hear "the system must always accept writes", what do you say?
- [x] Fill in **Common Misconceptions** — research and add: the "CA systems exist" myth, the "P is optional" myth, and the oversimplification of treating CAP as binary
- [x] Fill in **Relationships to Other Concepts** — link to PACELC (2.2), Consistency vs. Availability spectrum (2.5), and Consistency Models (Topic 17)

### Phase 4 — Validate 🧪

*Goal: Prove you own it before moving to 2.2.*


- [ ] Answer all 5 **Self-Check Quiz** questions out loud without notes — if you hesitate on any, go back to Phase 2
- [ ] Complete the **Cheatsheet** — write the one-liner in a single sentence you'd say to an interviewer at the start of a design discussion
- [ ] Tick off each item in **What Mastery Looks Like** — only check if you can demonstrate it on demand right now
- [ ] Do a 2-minute verbal explanation of CAP as if the interviewer just asked "walk me through how you think about consistency vs. availability trade-offs"

