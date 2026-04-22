# 🧠 Subtopic 4 - Peak Traffic Estimation

## **🎯 0. Goal of This Subtopic**

Most candidates only estimate average traffic.

We should also estimate peak traffic.

Because systems don’t fail at average - they fail at peak load.

If you miss estimating peak traffic:

* you under-provision your system infrastructure
* you get outages

* * *

## **🧾** 1. Cheat Sheet

```
Always do this right after given a system design:
1. Estimate average
2. Apply multiplier
3. Split read/write
4. Consider fan-out
5. Add buffer

Peak QPS = (Requests/day / 10^5) x Multiplier

Multipliers
Normal -> 3x
Consumer -> 5-10x
Social -> 10-20x
Flash -> 50-100x
```

* * *

## 🧠 2. Core Mental Model

### Definition

Peak Traffic = Maximum load system must handle at any moment


### Formula

```
Peak QPS = Average QPS x Peak Multiplier
```



### Typical Multipliers (MEMORIZE THIS)

|Scenario	|Multiplier	|
|---	|---	|
|Normal system	|2-3x	|
|Consumer apps (daily cycles)	|5-10x	|
|Social media burst	|10 - 20x	|
|Flash events(concert tickets, drops)	|50 - 100x	|

### Why Peaks Exist

1. Time of day concentration
    1. Everyone logs in at same time
2. Event driven spikes
    1. sports game
    2. product launch
    3. breaking news
3. Fan-out amplification
    1. One action → millions of downstream actions

* * *

## 3. Types of Peaks (CRITICAL)

### 3.1 Daily Peak (Predictable)

* happens every day
* example: 8-10pm usage spike

**Use multiplier: 3 - 5x**


### 3.2 Burst Peak (Short spikes)

* sudden traffic spikes
* Example: viral post

**Use multiplier: 10 - 20x**


### 3.3 Extreme Peak (Rare but dangerous)

* Black Friday / ticket sales

**Use multiplier: 50 - 100x**


### 3.4 Write vs Read Peaks(IMPORTANT)

Reads and writes spike differently:

|Type	|Behavior	|
|---	|---	|
|Reads	|VERY spiky	|
|Writes	|more stable	|

Always separate:

```
Peak read QPS != Peak write QPS
```

* * *

## 🧮 4.  Step-by-Step Estimation Framework



### 4.1 Step 1 - Estimate Average QPS

Example:

```
100M requests/day
= 100M / 86400 ≈ 1,200 QPS
```



### 4.2 Step 2 - Apply Peak Multiplier

Assume:

```
Peak multiplier = 5x
```

```
Peak QPS = 1,200 x 5 = 6,000 QPS
```



### 4.3 Step 3 - Split Read vs Write

Example:

```
Reads = 90%
Writes = 10%
```

```
Peak read QPS = 5,400
Peak write QPS = 600
```



### 4.4 Step 4 - Consider Fan-out(if applicable)

Example:

```
1 write -> 100 followers
```

```
Effective read QPS = write QPS x 100
```



### 4.5 Step 5 - Add Safety Margin

Always add:

```
+ 20-50% buffer
```

* * *

## **💥** 5. Advanced Concepts

### 5.1. Peak != Sustained

Peak might last:

* seconds 
* minutes

Design options:

* queue
* buffer
* drop traffic



### 5.2. P99 vs Peak

Peak is not the same as latency percentile.

```
Peak QPS refers to load spikes
P99 latency refers to performance behaviors
```

### 5.3. Regional Peaks

Global systems:

* US peak != Asia peak

You can:

* smooth traffic
* or have multiple peaks



### 5.4 Thundering Herd Problem

When many clients retry:

```
peak -> failure -> retry -> bigger peak
```

### 5.5 Fan-out explosion

Example:

* Celebrity post → millions of notifications

This is often the real peak driver


### 5.5 When to use peak Multiplier?

When to use peak multiplier?


|Scenario	|Apply Multiplier?	|
|---	|---	|
|Uniform daily traffic	|✅ YES	|
|Time-compressed window	|
⚠️ SOMETIMES	|
|Already burst (explicit time window)	|❌ NO	|
|Fan-out spike	|❌ NO	|

Peak Logic:

```
Case 1: avg → peak
→ apply multiplier

Case 2: already compressed (X users in Y time)
→ DO NOT apply multiplier

Case 3: fan-out
→ already peak
→ DO NOT multiply again
```

* * *

## **⚠️ 6. Common Interview Mistakes**

### **❌** Mistake 1: Using average QPS only

### **❌ Mistake 2: Using wrong multiplier**

Example:

* chat system → 2x (WRONG)
* Should be 5-10x

### **❌ Mistake 3: Ignoring fan-out**

Failure to recognize that a write could lead to many more reads


### **❌ Mistake 4: Not separating read/write**

```
Read QPS != Write QPS
```

### **❌ Mistake 5: No Safety Margin**

Failure to factor for redundancy.
Example:

* you correctly factor 10 servers with peak traffic calculation
    * 10 server is just-enough to handle peak traffic
* what if 2 servers fail? what if traffic went beyond peak?
    * failure to factor additional servers for unforeseen circumstances 

* * *

## 7. Mental Understandings

### 7.1 Model 1 - Traffic is not smooth

Always assume:

```
Traffic is spiky, not uniform
```

### 7.2  Model 2 - Design for worst minute

Not per day - per second


### 7.3 Model 3 - Write small, read huge

Most systems:

```
writes << reads
```

### 7.4 Model 4 - Fan-out multiplies load

* * *

## 8. Practice Routine

Daily (15min):

* 5 peak estimation drills

Goal:

```
You should instantly say:
"Average QPS is X, peak is ~Y using a 5x multiplier"
```

* * *

