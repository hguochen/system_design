# 🧠 Subtopic 17 - Interview Communication

* * *


# 0. 🎯 Goal of This Subtopic

* Convert your thinking → signal the interviewer you can evaluate
    * why: interviewer cannot read your mind
* Drive the interview(not react to it)
    * why: Staff-level expectation = ownership
* Making your reasoning legible
    * why: hiring bar = clarity under ambiguity

* * *


## 🏆 What Mastery Looks Like

You have mastered this subtopic when you can:

* narrate estimation in <2min clearly
* structure entire interview top-down
* proactively call out assumptions + tradeoffs
* recover gracefully when wrong

If interviewer interrupts you less → you’re doing it right
* * *

# 1. 🧾 Cheat Sheet

```
System Design Communication Framework

Phase 1 - Problem Framing

1. Scope
- What are we building?
- What's IN/OUT?

2. Scale
- DAU/MAU
- system size level
- global/regional usage

3. Behavior
- What users do (reads, writes, patterns)
- read/write ratio
- peak multiplier / concurrency
- traffic pattern

4. Traffic
- QPS(read/write split)
- Bandwidth

5. Data
- object field breakdown
- dominant field

6. Retention
- storage strategy(eg. hot,warm,cold)
- system storage bounded/unbounded

7. Infra Assumptions
- encoding overhead
- indexing
- cache hit ratio
- replication factor
- CAP theorem, which 2 to prioritize?


Phase 2 - Solution Structuring

8. Outline Approach
- "I'll break this into estimation -> design -> deep dive"

9. High-level Design
- request flow
- major components

Phase 3 - System Deepening

10. Component Deep Dive
- DB, cache, LB, etc.

11. Tradeoffs
- consistency vs availability
- latency vs cost

12. Summary
- recap key decisions

--- Control & Clarity ---

Continuous Alignment
- check with interviewer

Iterative Refinement
- evolve system
```

* * *


# 2. 🧩 Core Concepts

## 2.1 Communication = Interface between you and interviewer

* your design is the internal system - communication is the interface that exposes it
* a great system behind a bad API is unusable - same principle applies here

Example:

* Bad: “Let’s add Redis”
* Good: “Reads dominate at 100:1 - i’ll add a cache layer to absorb that and cut DB load”

Insight: a correct design explained poorly = no signal


## 2.2 Structured thinking beats raw intelligence

* interviewers aren’t just scoring your answer = they’re scoring your decomposition, prioritization and clarity
* a chaotic but correct answer signals you’d be hard to work with under pressure

Example:

* Structured: “First i’ll nail QPS → then figure out storage needs → then layer in caching”

Insight: chaos thinking = reject signal regardless of technical depth


## 2.3 Explicit assumptions are a feature, not a crutch

* unstated assumptions are hidden bugs - they let you go 5 minutes in the wrong direction
* stating them invites the interviewer to correct you early, which saves everyone time
* it also demonstrates judgement: you know what matters and what to pin down

Example:

* “I’ll assume ~5MB per video minute and a 10:1 read/write ratio - I’ll revise if needed”

Insight: every unstated assumption is a land mine under your design


## 2.4 Incremental design shows your reasoning, not just your answer

* Interviewers want to see how you think through evolution, not just the end state
* jumping straight to the final distributed system skips all the reasoning that justifies it

Example:

* Step 1: single server + single DB → what breaks?
* Step 2: add load balancer → what breaks?
* Step 3: add cache → what breaks?
* Step 4: shard the DB → now you’ve earned the complexity

Insight: the journey is the answer - not the destination


## 2.5 Continuous alignment prevents silent derailment

* Interviews are collaborative - the interviewer may be nudging your toward something
* if you never check in, you can go deep on the wrong subsystem for 10 minutes

Example:

* “I’m about to go deep on the storage layer - does that match where you want me to focus?”

Insight: silence on both sides = misalignment building up


## 2.6 Tradeoff reasoning is the senior/staff signal

* Junior engineers present solutions - senior engineers present decisions with costs
* every real system is a set of compromises; showing you understand them signals maturity

Example:

* “Async replication gives us higher write availability, but we accept slightly stale reads - that’s fie for this use case”

Insight: presenting a solution with no tradeoffs = you haven’t thought it through
* * *


# 3. 🧠 Mental Models

## 3.1 The Narrator Model

* You are narrating your internal reasoning live

Example:

* “Since reads dominate, i’ll prioritize caching first”

If you stop talking → interviewer loses content


## 3.2 Build in Layers

* Systems evolve from simple → complex

Example:

* Start with single DB
* Then:
    * add replication
    * add cache
    * add CDN

Always ask: what’s the simplest version first?


## 3.3 Driver seat model

* You should lead direction, not follow

Example:

* Next i’ll estimate bandwidth to size the system

If interviewer is steering → you’re losing signal


## 3.4 Make thinking visible

* Interviewer evaluates reasoning, not result

Example:

* Say “i’m choosing this because”

Hidden thinking = lost points


## 3.5 “Hypothesis → Validate”

* Good engineers test assumptions

Example:

* “This seems high - let me sanity check”

Shows rigor + maturity
* * *


# 4. ⚙️ Key Formulas

## 4.1 Signal Density Formula

```
Signal = (Clarity x Structure x Justification) / Time
```

* interview time is fixed → maximize signal

## 4.2 Thinking Visibility Formula

```
Score ∝ % of reasoning spoken out loud
```

* silent reasoning contributes nothing to your score
* the more of your internal model you externalize, the more surface area the interviewer has to evaluate

## 4.3 Interview Control Ratio

```
Strong candidate:  you drive 70% / interviewer drives 30%
Weak candidate:    you drive <40% / interviewer fills the gap
```

* the ratio of who’s driving reflects how much ownership you’re demonstrating
* every time the interviewer has to ask “what would you do next?” you’ve ceded control

## 4.4 Iterative Depth Model

```
Design Quality = Base Design + (# of Iterations × Depth of Each)
```

* iteration shows depth

Example:

* adding caching → then invalidation → then consistency

* * *


# 5. ⚡ Patterns

## 5.1 “Top-Down First” Pattern

* Gives interviewer a mental map before you go into the territory - they can follow you instead of piecing it together at the end

Example:

* “At a high level: client → load balancer → app servers → cache → DB. I’ll now walk through each”



## 5.2 “Estimate → Design” Pattern

* Grounds system in reality

Example:

* “QPS is ~80K → we need horizontal scaling”



## 5.3 “Assume → Proceed  → Validate” Pattern

* waiting for perfect information is a time sink - state the assumption, move forward, revisit at sanity check

Example:

* “I’ll assume 1KB per metadata record - cheap to revise, let me keep moving”



## 5.4 “Simple → Scale” Pattern

* Shows evolution

Example:

* Start monolith → then microservices



## 5.5 “Explain every component” Pattern

* Prevents black-box thinking

Example

* “Cache reduces DB load by X%”



## 5.6 “Frequent Checkpoint” Pattern

* Avoid misalignment

Example:

* “Does this match what you’re expecting?”

* * *


# 6. ⚠️ Common Pitfalls

## 6.1 Silent thinking

* interviewer sees nothing



## 6.2 Jumping to Final Design

* skips reasoning process



## 6.3 No Numbers

* design not grounded



## 6.4 No tradeoffs

* signals shallow understanding



## 6.5 Over-talking / Rambling

* low signal density - you’re burning time without adding evaluable content



## 6.6 Not Driving the interview

* passive candidate = weak signal



## 6.7 Ignoring Feedback

* lack of adaptability



## 6.8 Over-optimization Too Early

* premature complexity

* * *


# 7. 🎤 Interview Script

```
Phase 1 - Problem Framing

1. Scope
- Let me start by clarifying the scope to make sure i'm solving the right problem
- We're building a system that allows users to [core functionality]
- For this discussion, i'll assume the following are in scope:
    - feature 1
    - feature 2
- And i'll explicitly keep these out of scope for now:
    - non-critical feature 1
    - non-critical feature 2
- This is a read/write heavy system with write-triggered fanout/heavy bandwidth req etc.
- Does that sound aligned, or should i include anything else?

2. Scale
- Next i will define the scale so we can ground the design
- I'll assume around [X DAU]
- This is a [small/medium/large/massive] scale system, likely requiring horizontal scaling
- I'll also assume this is a [global/regional] system, so latency and replication will matter
- I'll refine these numbers if needed as we go

3. Behavior
- Now i'll define user behavior since that drives traffic and system load
- On average, each user performs:
    - reads: [X actions/day]
    - writes: [Y actions/day]
- So the system is roughly [read-heavy, write-heavy], with a ratio of about [R:W]
- Traffic is likely [steady/spiky/bursty], depending on usage patterns
- I'll assume a peak multiplier of 3x

4. Traffic
- From that, i'll estimate system traffic
- Total requests per day = [DAU x actions]
- Converting to QPS using ~10^5 seconds/day, that gives roughly:
    - Total QPS: ~[X]
    - Read QPS: ~[Y]
    - Write QPS: ~[Z]
- For bandwidth, assuming each request transfers ~[size], we get:
    - [X MB/s], or roughly [Y TB/day]
- I'll use these numbers to size components going forward

5. Data
- Next, i'll estimate data size starting from the object level
- A typical object consists of:
    - field1 -> [size]
    - field2 -> [size]
- So raw object size is roughly [X bytes]
- The dominant field here is [eg. video/image/text], which will drive storage and bandwidth
- I'll use this to estimate total storage next

6. Retention
- Now i'll define retention and storage strategy
- I'll assume data is stored for [X duration]
- Given the data rate, that leads to roughly [X TB total storage]
- We can also tier storage:
    - hot: recent data
    - warm: less frequent
    - cold: archival
- This system is [bounded/unbounded], depending on whether data grows indefinitely

7. Infra Assumptions
- Before moving to design, i'll state a few infrastructure assumptions
- I'll assume
    - encoding overhead ~2x
    - indexing overhead ~2-3x
    - replication factor ~3x
- Cache hit rate might be around [20%-80%], depending on workload.
- From a CAP perspective, i'll prioritize [Consistency/Availability], given the use case.
- These assumptions will guide design decisions

Phase 2 - Solution Structuring

8. Outline Approach
- With these assumptions, I'll break this into three parts:
    - 1. High-level design
    - 2. Component deep dive
    - 3. Tradeoffs and optimizations
- I'll start simple and then scale it step by step

9. High-level Design
- At a high level, the system looks like this
- Client requests go through a load balancer, which routes to application servers
- For reads, we can use cache layer to reduce latency
- Data is stored in [DB type], with replication for reliability
- For large content, we may use object storage + CDN.
- The request flow would be
    - Client -> LB -> Cache -> App -> DB
- This handles the basic functionality - i can now dive deeper into key components

Phase 3 - System Deepening

10. Component Deep Dive
- Let me dive deeper into the critical components

11. Tradeoffs
- There are a few key tradeoffs in this design
    - Option A vs Option B
        → choose X because Y
        → downside is Z
- For consistency vs availability
    - choosing X improves [benefit]
    - but sacrifices [cost]
- For latency vs cost:
    - caching reduces latency
    - but increases infrastructure cost
- These tradeoffs depend on product requirements

12. Summary
- To summarize the design
- We started by defining assumptions around scale, traffic and data
- We designed a system with:
    - load-balanced application layer
    - caching for performance
    - scalable storage
- We then explored tradeoffs around consistency and latency
- This design should scale to [target QPS / storage]
- Happy to dive deeper into any part
```




```
→ choose X because Y
```




```
→ downside is Z
```

* * *


# 8. 🧪 Mini Drills (Active Recall)

* Drill 1:
* Drill 2:
* Drill 3:
* Drill 4:
* Drill 5:

* * *

