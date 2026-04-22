# 🧠 Subtopic 16 - Sanity Checking

* * *


# 0. 🎯 Goal of This Subtopic

## What is the goal?

* Ensure all your estimations are realistic, internally consistent, and defensible
* Catch mistakes before the interviewer does

* * *


## 🏆 What Mastery Looks Like

You have mastered this subtopic when you can:

* Quickly detect if a number is off by 10x - 1000x
* Validate results using multiple independent methods
* Explain why you numbers makes sense in the real world
* Adjust assumptions confidently under pressure

* * *

# 1. 🧾 Cheat Sheet

```
Sanity Check Framework

1. Order of Magnitude Check
- Is this number realistic (10x - 1000x error?)

2. Backward Check
- Reverse the formula to validate result

3. Real-World Anchor
- Compare against known systems / physical limits

4. Unit Check
- Are units consistent? (bytes, seconds, QPS)

5. Extreme Case Check
- What happens at peak? worst case?

6. Ratio Check
- Do ratios make sense? (read/write, per-user usage)

7. Component Sum Check?
- Do parts add up tot he total?

8. Resource Limit Check
- CPU / network / disk realistic?

Rule of Thumb:
-> If you don't sanity check, assume your answer is wrong
```

* * *


# 2. 🧩 Core Concepts

## 2.1 Sanity Checking  = Error Detection Layer

* Estimation is prone to compounding errors
* A small mistake early → huge errors later
* Sanity checking acts as a guardrail

Example:

* You compute:
    * Storage = 10PB for 1M users
* Sanity check:
    * 1M users → 10 PB → 10GB per user
* That’s unrealistic → something is wrong

Why?

* Humans are bad at large numbers
* System design depends on correct scale intuition

## 2.2 Order-of-Magnitude Thinking

* You don’t need exact values
* You need correct scale (10x accuracy)

Example:

* if real answer = 2TB
* Your answer = 1.5TB → good
* Your answer == 200TB → bad

Why?

* System decisions(architecture, sharding, caching depend on scale)
* Not exact precision

## 2.3 Independent Verification

* Always validate using a second method

Example:

* Method 1:
    * QPS → bandwidth → storage
* Method 2:
    * Users → per-user data → storage
* If both = same → correct
* if mismatch → bug in reasoning

Why?

* reduces reliance on single flawed assumption

## 2.4 Real-World Anchoring

* Compare against known benchmarks

Example:

* Network
    * 1 server = 1 - 10 Gbps
* Storage
    * 1 disk = few TB
* Memory
    * 1 server = 32 - 256 GB

Why?

* Prevents “fantasy numbers”

* * *


# 3. 🧠 Mental Models

## 3.1 “Smell Test” Model

* Ask “Does this feel right?”

Example:

* Tiktok system:
    * 1 user generates 1TB/day
    * Immediate rejection

Why?

* Fastest way to detect nonsense

## 3.2 “Per-Unit Breakdown” model

* Reduce large numbers into per-user / per-second

Example:

* 1PB/day → per second:
    * ~10GB/s
* Does infra support that?

Why?

* Easier to reason at smaller granularity

## 3.3 “Bottleneck First” Model

* Identify which resource should dominate

Example:

* Video system:
    * Network >> CPU
* If CPU dominates → suspicious

Why?

* Each system has a natural dominant constraint

## 3.4 “Conservation of Data” Model

* Data doesn’t disappear

Example:

* Writes = 100MB/s
* Replication factor = 3
* Total system writes must be = 300MB/s

Why?

* Prevents undercounting system load

* * *


# 4. ⚙️ Key Formulas

## 4.1 Reverse Check

* Validate output by reversing calculation

Example:

* You compute:
    * 100K QPS → 10MB/s
* Reverse:
    * 10MB/s / 100K = 100B/request
* Does that match object size?

Why?

* Detects arithmetic + assumption mismatch

## 4.2 Per-User Check

* Normalize metrics

Example:

* Storage = 100TB
* Users = 10M
* → 10MB/user

Why?

* Easy reality check

## 4.3 Time Conversion Check

* Convert between units to validate

Example:

* 1MB/s = 100GB/day

Why?

* Catch unit conversion mistakes (very common)

## 4.4 Peak vs Average Check

* Ensure peak aligns with multiplier

Example:

* Avg QPS = 10K
* Peak = 30K (3x)

Why?

* Many candidates forget peak scaling

* * *


# 5. ⚡ Patterns

## 5.1 Double Estimation Pattern

* Solve using 2 different approaches

Example:

* Storage
    * Approach A: QPS-based
    * Approach B: user-based

Why?

* High confidence answer

## 5.2 Bounding pattern

* Estimate upper and lower bounds

Example:

* Video size:
    * Min: 1MB
    * Max: 10MB

Why?

* Prevents overconfidence in single estimate

## 5.3 Incremental Validation Pattern

* Validate at every step, not just final answer

Example:

* QPS → bandwidth → storage
* Sanity check after each step

Why?

* easier to isolate errors

## 5.4 Compare-to-Known Pattern

* Compare to known systems

Example:

* Netflix bandwidth scale
* Youtube upload rate

Why?

* Anchors your intuition

* * *


# 6. ⚠️ Common Pitfalls

## 6.1 Blind Trust in Math

* Assuming calculations are correct without validation

Example:

* “I got 500PB, so it must be right”

Why dangerous:

* Math can be correct, assumptions wrong

## 6.2 Ignoring Units

* Mixing MB, Mb, seconds, days

Example:

* Treating Mbps as MB/s → 8x error

## 6.3 No Real-World Check

* Not comparing against infrastructure limits

Example:

* 1 server handling 100GB/s

## 6.4 Over-Precision

* Trying to be exact instead of approximate

Example:

* Saying 1.234TB instead of ~1TB

Why?

* Wastes time, no extra value

## 6.5 Missing Peak Scenarios

* Only validating average

Example

* Avg OK, peak overloads system

## 6.6 Inconsistent Assumptions

* Using different assumptions in different steps

Example:

* 100B/request here, 1KB/request later

* * *


# 7. 🧪 Mini Drills (Active Recall)

Try this mentally:

You estimate a system:

* 50M users
* 20 requests/day
* 1KB request

You compute:

* Storage = 1PB/year

Sanity check it:

* Per user:
    * 20KB/day → 7MB/year
* Total:
    * 50M x 7MB= 350TB/year

Your 1 PB is ~3x too high → investigate
* * *

