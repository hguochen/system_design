# 🧠 Subtopic 15 - Assumption Setting

>“He who controls the assumptions controls the system design.”

* * *


# 0. 🎯 Goal of This Subtopic

What you must achieve

* Convert ambiguous problem → concrete numbers
* Drive all estimations from explicit assumptions
* Control the scope of the system

* * *


## 🏆 What Mastery Looks Like

* Never start calculating blindly
* State assumptions before every estimate
* Justify each assumption clearly
* Adjust assumptions dynamically when challenged

Why this matters?

* System design problems are underdetermined
* Without assumptions → infinite possible answers
* With assumptions → you control the problem space

* * *

# 1. 🧾 Cheat Sheet

```
1. Define scale
    - Users: DAU / MAU
    - Example: "Assume 10M DAU"

2. Define behavior
    - Requests per user per day
    - Example: "User sends 20 messages/day"

3. Define system scope
    - Features included/excluded
    - Example: "We ignore media uploads"

4. Define data size
    - Object size per entity
    - Example: "Peak = 3x average"

5. Define time window
    - Peak vs average
    - Example: "Peak = 3x average"

6. Define retention
    - Data lifespan
    - Example: "Store messages for 1 year"

7. Define infra assumptions
    - Replication factor
    - Example: "RF = 3"

RULES:
- Always state assumptions BEFORE calculation
- Round numbers (1M, 10M, 100M)
- Prefer powers of 10 for speed
- Be consistent across calculations
- Sanity check after estimation

COMMON DEFAULTS:
- 1 day = 10^5
- Peak = 3x average
- Replication = 3x
- Cache hit rate = 80%
- Active ratio (DAU/MAU) = 10%
```

* * *


# 2. 🧩 Core Concepts

## 2.1 Assumptions define the system

Why?

* the problem statement is intentionally vague
* you must create the constraints yourself

With assumptions:

* 1B users, 100M DAU, 20 msgs/user/day

Now you can compute:

* QPS
* Storage
* Bandwidth



## 2.2 Assumptions must be explicit

Why?

* Interviewer evaluates your reasoning, not correctness
* Hidden assumptions = fragile design

“Assume 100M DAU × 20 actions/day → 2B requests/day → ~20K QPS”

Shows:

* thought process
* traceability



## 2.3 Assumptions are layered

Think in layers

```
Users → Behavior → Traffic → Data → Infra
```

Why?

* each layer feeds the next
* prevents random guessing



## 2.4 Assumptions are negotiable

Why?

* there is no “correct” number
* interviewer may challenge you

You

* adjust assumptions
* recompute quickly

This tests adaptability


## 2.5 Assumptions must be consistent

Why?

* inconsistent assumptions break your model

Do:

* Keep same base number across system

Don’t

* Assume 10M DAU
* Later use 100M users for storage

* * *


# 3. 🧠 Mental Models

Assumption Setting Pipeline


```
1. Clarify scope
2. Define scale
3. Define behavior
4. Define data model
5. Define constraints
6. Drive all calculations
7. Sanity check
```



## 3.1 “You are defining reality”

Why?

* System design = building a fictional world

You choose:

* scale
* usage
* constraints



## 3.2 “Start coarse, refine later”

Why

* early precision is wasteful
* you need speed

Example

* Start: 1M users
* Later: refine to 1.2M if needed



## 3.3 “Assumptions → Constraints → Architecture”

Why?

* Architecture depends on scale



## 3.4 “Every number must come from somewhere”

Why?

* Prevents magic numbers



## 3.5 “Think in orders of magnitude”

Why?

* Interviews reward approximation speed

* * *


# 4. ⚙️ Key Formulas

## 4.1 Traffic

```
QPS = (users x action per day) / 10^5
```



## 4.2 Storage

```
Storage = objects/day x size x retention
```



## 4.3 Bandwidth

```
Bandwidth = QPS x request size
```



## 4.4 Concurrency

```
Concurrent users = DAU x concurrency ratio
```



## 4.5 Cache size

```
Cache = working set x object size
```

* * *


# 5. ⚡ Patterns

## 5.1 Standard Assumption Stack

Why?

* ensures completeness

```
Users → Behavior → Traffic → Data → Storage → Infra
```

Example

*    10M users
*    10 actions/day
*    → 1K QPS
*    → 100B per request
*    → 100MB/s



## 5.2 Default Assumptions

Why?

* saves time

Common defaults

* Peak = 3x average
* Replication = 3x
* JSON overhead = 2x



## 5.3 Clarify scope early

Why

* prevents wasted work

Example
“Are we including video uploads or just text”



## 5.4 Backsolve assumptions

Why?

* Sometimes easier to assume final metric

Example

* Assume 10K QPS
* Then derive required users



## 5.5 Progressive refinement

Why?

* Start simple, refine later

Example

*    First pass: rough QPS
*    Second pass: peak QPS
*    Third pass: per-region QPS

* * *


# 6. ⚠️ Common Pitfalls

## 6.1 Jumping into calculations

Why it’s bad

* Leads to inconsistent numbers

Example

* randomly saying “100K QPS”

## 6.2 Over-precision

Why it’s bad

*    Slows you down

Example

*    Using 1,234,567 users instead of 1M



## 6.3 Missing key assumptions

Why it’s bad

*    Breaks downstream estimates

Example

*    Forgetting retention → wrong storage



## 6.4 Inconsistent assumptions

Why it’s bad

* System becomes logically invalid



## 6.5 Not stating assumptions aloud

Why it’s bad

* interview cannot follow your logic



## 6.6 Unrealistic assumptions

Why it’s bad

*    Breaks credibility

Example

*    “Each user sends 1000 messages/day”

* * *


# 7. Interview Template

```
1. Scope
2. Scale
3. Behavior
4. Traffic
5. Data
6. Retention
7. Peak/Load characteristics
8. Infra
```

## 1. Scope

>“Let me clarify scope first”

### Objective

* define the right system to design

### Questions to ask

* What are the core features? Bucket into read/write.
* What’s out of scope?
* Determine type of system (read/write heavy? realtime?)

### 🔗 What it INFLUENCES

*    Behavior assumptions
*    Data size
*    Architecture complexity

### Example: Chat System

* include: send/receive text
* out of scope: file/video sharing
* type of system: read + write ratio => 1:1



## 2. Scale

>“Assume X DAU”

### Objective

* Determine a realistic DAU number of system
    * impacts total requests, total data, concurrency concerns

### Questions to ask

* What’s DAU for system?
* MAU optional
* Growth optional

### 🔗 What it DERIVES

*    Total requests
*    Total data
*    Concurrency

### 🔗 What it INFLUENCES

*    Everything downstream

### Example

* Assume 10M DAU



## 3. Behavior

>“Each user performs X actions/day”

System behavior defines workload shape, not just volume.

### Objective

* no. of writes per user
* no. of reads per user
* read/write ratio

### Questions to ask

* What actions per user?
    * how many writes per user?
    * how many reads per user?
* What’s the read/write ratio?

### 🔗 What it DERIVES

*    Total requests/day
*    Read vs write load



### 🔗 What it INFLUENCES

*    DB design
*    Cache strategy

### Example:

* 20 messages/user/day
    * 20 writes
    * 200 reads
* read/write = 10:1



## 4. Traffic (QPS)

>“Total requests/day → QPS = ...”

### Objective

* convert daily → per second
    * QPS = total_requests_per_day / 10^5

### Questions to ask

* Whats the total requests count per day?
* What does total requests per day equates to in QPS?

### 🔗 What it INFLUENCES

*    Server count
*    Load balancing
*    API scaling

### Example

* 10M x 20 = 200M/day
* → 2K QPS



## 5. Data (Object Size)

>“Each object is ~X bytes”

### Objective

* Compute the total amount of bytes for each object
    * breakdown field data size then sum up
    * identify dominant field
* Compute the total amount of storage 
* Compute the total amount of bandwidth
* Compute the final object size:
    * after encoding, indexing, replication multipliers

### Questions to ask

* What are the object fields?
* What’s the dominant field?

### 🔗 What it DERIVES

*    Storage
*    Bandwidth



### 🔗 What it INFLUENCES

*    DB choice
*    Network cost

### Example

* IDs: 16B
* timestamp: 8B
* text: 100B

total: ~150B

NOTE: always round UP, never down


## 6. Storage

>“We store data for X duration”

### Objective

* Decide nature of storage
    * hot vs cold storage
* Compute total storage

### Questions to ask

* What’s the TTL for data objects?
* What storage method do we need? tiered hot vs cold storage?
* Is data stored forever?

### 🔗 What it DERIVES

*    Total storage

### 🔗 What it INFLUENCES

*    Storage system choice
*    Archival strategy

### Example

Typical Retention periods
Logs → 7 - 30 days
Chat → months - years
Analytics → long term


## 7. Peak / Load Characteristics

>“Peak = X x average”

Systems fail at peak, not average. Always design for peak load.

### Objective

* Determine the peak multiplier and justify
* Determine the traffic pattern(bursty, steady)

### Question to ask

* What should the peak multiplier be? Why?
* What traffic patterns do we expect?

### 🔗 What it DERIVES

*    Peak QPS

### 🔗 What it INFLUENCES

*    Capacity planning
*    Auto-scaling

### Example

* 2K QPS → peak = 6K QPS



## 8. Infra Assumptions

>“Assume replication / caching / overhead”

### Objective

* Decide replication factor. default 3x.
* Decide cache hit rate. (eg. ~20%)
* Decide if any encoding overhead is needed

### Question to ask

* What should the replication factor be? Why?
* What cache hit rate are we designing for?
* What’s the encoding overhead, if any?

### 🔗 What it DERIVES

*    Real storage
*    Real bandwidth

### 🔗 What it INFLUENCES

*    Cost
*    Availability

### Example

* 10 TB → RF=3 → 30TB

* * *

# 9. 🧪 Practice Systems (Active Recall)

## 9.1 Chat System

```
Design Chat System

Scope
- 1:1 text chat only
- send messages
- receive messages
- sync message across devices
- no group chat
- no media/file attachments
- system type: moderately read-heavy with write-triggered fanout

Scale
- 50M DAU
- global usage

Behavior
- each user/day:
    - 10 writes
    - 30 reads / fetches / sync actions
- read/write ratio = 3:1
- one sent message may be delivered to multiple recipient devices

Traffic
- writes/day = 50M * 10 = 500M/day
- reads/day = 50M * 30 =1.5B/day
- write QPS = 500M/10^5 = 5K write QPS
- read QPS = 1.5B/10^5 = 15K read QPS

Data
- Message object = 200B
    - message_id -> 8B
    - sender_id -> 8B
    - receiver_id -> 8B
    - created_at -> 8B
    - updated_at -> 8B
    - message text -> 100B
    - status -> 8B
    - metadata -> 60B
- dominant field -> message text

Retention
- recent messages in hot storage for 30 days
- older message archived to cold storage
- total retention = forever
- system storage is unbounded

Peak
- peak multiplier = 3x
- globally smoothed traffic, but still moderate bursts

Infra assumptions
- JSON encoding overhead = 2x
- indexing overhead = 1.5x
    - (receiver_id, created_at) -> fetch inbox
    - (sender_id, created_at) -> sent messages
    - message_id -> direct lookup
- cache hit rate = 80% for recent conversations / recent messages
- replication factor = 3x
- compression (optional) -> reduces storage/bandwidth
```

## 9.2 Twitter / Feed System

```
Design Twitter

# fanout-on-write system
Scope
- post tweets
- read home timeline
- follow relationships assumed
- no DMs
- no media uploads
- system type: read-heavy with fanout-on-write

Scale
- 100M DAU
- global usage

Behavior
- each user:
    - 2 tweets/day
    - 100 reads/day
- average followers = 20 -> fanout on write
- read/write ratio: 50:1

Traffic
- external writes = 200M/day -> 2K QPS
- fanout writes = 4B/day -> 40K QPS
- reads = 10B/day -> 100K QPS

Data
- Tweet object: ~300B
    - tweet_id, user_id, timestamps
    - text(200B)
    - metadata
dominant field: text

Retention
- hot: recent tweets(days)
- warm: weeks
- cold: long time archive(S3)
- system storage: unbounded

Peak
- peak multiplier: 10x
- traffic pattern: bursty(event-drive spikes)

Infrastructure
- replication factor = 3x
- indexing:
    - timeline (user_id, created_at)
    - tweet_id lookup
- cache hit = 80% for timelines
- encoding = 2x (JSON)
```

```
Design Twitter

# fanout-on-read system
Scope
- user can post tweets
- user reads home timeline
- assume follow graph exists
- no DMs
- no media/file uploads
- system type: read-heavy with fanout-on-read

Scale
- 100M DAU
- global usage

Behavior
- each user:
    - posts 2 tweets/day
    - reads 100 timelines/day
- assume average relevant follow set ≈ 20
- pull model: tweets are fetched when user requests timeline
- user-level read/write ratio = 50:1
- backend effective read/write ratio after fanout-on-read = 1000:1

Traffic
- writes/day = 100M * 2 = 200M/day
- write QPS = 200M / 10^5 = 2K QPS
- effective reads/day = 100M * 100 * 20 = 200B/day
- read QPS = 200B / 10^5 = 2M QPS

Data
- Tweet object: ~300B
    - tweet_id -> 8B
    - user_id -> 8B
    - created_at -> 8B
    - updated_at -> 8B
    - text -> 200B
    - metadata -> 50B
- dominant field -> text

Retention
- hot: recent tweets for 7 days
- warm: tweets from 8 to 30 days
- cold: archived in S3 long-term storage
- tweets are stored forever
- system storage is unbounded

Peak
- peak multiplier: 10x
- traffic pattern: bursty

Infrastructure
- encoding overhead: 2x
    - use JSON for simplicity and interoperability
- cache hit ratio: ~90%
    - cache recent tweets / hot author timelines
- indexing:
    - (author_id, created_at) -> fetch recent tweets from followed users
    - tweet_id -> direct tweet lookup
- replication factor: 3x
```

## 9.3 YouTube

```
Design Youtube

Scope
- users can upload videos
- users can watch videos
- no comments/likes/subscriptions
- no ads
- no live streaming
- system type: watch-heavy large-object system

Scale
- 500M DAU viewers
- global usage
- assume 1% are active uploaders

Behavior
- each uploader uplaods 1 video/day
- each viewer watches 50 videos/day
- average video size = 50MB
- average bytes consumed per watch = 25MB
- watch: upload ratio is highly read-heavy

Traffic
- uploads/day = 500M * 1% * 1 = 5M/day
- write QPS = 5M / 10^5 = 50 QPS
- watches/day = 500M * 50 =25B/day
- read QPS = 25B / 10^5 = 250K QPS
- upload bandwidth = 50 QPS * 50MB = 2.5GB/s
- watch bandwidth = 250K QPS * 25MB = 6.25TB/s

Data
- video metadata object -> 200B
- video content object -> ~50MB
- dominant field -> video payload

Retention
- hot: frequently watched videos cached near users
- warm: moderately accessed videos in standard storage
- cold: infrequently watched videois in cheaper archival tiers
- videos retained forever
- system storage is unbounded

Peak
- peak multiplier = 10x
- busty traffic due to viral videos and events

Infra assumptions
- metadata encoding overhead negligable relative to video payload
- storage overhead may increase due to multiple transcoded versions
- cache hit rate ~70% for hot video segments via CDN / edge
- indexing: ~1.2x - 1.5x
    - video_id -> direct access
    - (author_id, created_at) -> channel page
- replication factor = 3x
```

## 9.4 Uber / Ride Matching

```
Design Uber

Scope
- users can book rides
- users receive driver location updates
- drivers update ride status and location
- no payments
- no social features
- system type: real-time + high-frequency updates

Scale
- 50M rides/day
- global usages

Behavior
- per ride:
    - before/after ride:
        - 3 writes (request, accept, complete)
        - 3 reads
    - during ride(~20mins):
        - driver sends ~20 location updates/min
        - total ~400 writes per ride
        - system pushes updates to user
- effective read/write ratio: 1:1 (writes dominate backend)

Traffic
- writes/day = 50M * 400 =20B writes/day
- write QPS = 20B / 10^5 = 200K QPS
- reads much lower than writes(mostly status checks)
- small object size (~150B)
- bandwidth relatively low, latency critical

Data
- Ride object ~150B
    - ride_id, customer_id, driver_id
    - timestamps
    - location (lat, long)
    - metadata
- dominant: metadata / frequent updates

Retention
- hot: recent rides (7 days)
- cold: archived in S3
- retained for audit/analytics
- storage unbounded

Peak
- peak multiplier = 5x
- predictable bursty (time-of-day, location)

Infra assumptions
- encoding overhead ~2x (JSON)
- indexing:
    - ride_id lookup
    - (customer_id, created_at) -> customer past rides
    - (driver_id, created_at) -> driver past rides
- cache useful for history, not real-time updates
- replication factor: 3x
```

## 9.5 Dropbox / Google Drive

```
Design Dropbox

Scope
- users can upload files
- users can download files
- users can share files via links
- file sync across user devices is in scope
- no collaboration features
- system type:
    - write-heavy in storage/bandwidth
    - moderate read/write in request QPS

Scale
- 100M DAU
- global usage
- assume 10% uploaders/day

Behavior
- uploaders upload 5 files/day
- each file ~5MB
- users read ~5 files/day
- each upload triggers sync to 2-3 devices
- introduces read amplification

Traffic
- uploads/day = 100M * 10% * 5 = 50M
- upload QPS = 50M / 10^5 = 500 QPS
- user reads/day = 100M * 5 =500M
- read QPS = 500M / 10^5 = 5K QPS
- upload bandwidth = 500 * 5MB = 2.5GB/s
- read bandwithd = 5K * 5MB =25GB/s

Data
- metadata object: 100B - 500B
- file blob: 5MB
- dominant field: file blob

Retention
- hot: recently accessed files
- cold: archival storage (S3)
- retained forever
- storage unbounded

Peak
- peak multiplier = 2-3x
- traffic pattern: mostly steady, mild work-hour peaks

Infra assumptions
- metadata encoding overhead: 2x
- file blob stored as binary
- cache:
    - metadata cached
    - file content via CDN/object storage
- indexing:
    - file_id -> lookup
    - (owner_id, timestamp)
- replication factor = 3x
```

## 9.6 TikTok / Reels

```
Design TikTok

Scope
- users can upload short videos
- users can watch a recommended short-video feed
- no sharing
- no comments / reactions / likes
- no live streaming
- system type: read-heavy short video feed system

Scale
- 200M DAU
- global usage
- assume 5% of users upload videos

Behavior
- active uploaders upload 2 videos/day
- each user watchers 40 videos/day
- average video duration = 20s
- average video size = 2MB
- system-wide watch:upload ratio = 8B : 20M = 400:1

Traffic
- uploads/day = 200M * 5% * 2 = 20M/day
- watches/day = 200M * 40 = 8B/day
- upload QPS = 20M / 10^5 = 200 QPS
- watch QPS = 8B / 10^5 = 80K QPS
- upload bandwidth = 200 * 2MB = 400MB/s
- watch bandwidth = 80K * 2MB =160GB/s

Data
- Video object: ~2MB
    - video_id -> 8B
    - author_id -> 8B
    - timestamp -> 16B
    - metadata -> 200B
    - video blob -> 2MB
- dominant field = video blob

Retention
- hot: frequently watched videos cached via CDN
- warm: moderately accessed videos in standard storage
- cold: rarely accessed videos in long term storage
- videos retained forever
- storage unbounded

Peak
- peak multiplier = 10x
- traffic pattern = bursty

Infra assumptions
- encoding overhead:
    - metadata encoding overhead is negligible
    - video blobs may be transcoded into multiple display qualities
- indexing:
    - video_id -> direct access
    - (author_id, created_at) -> creator page
    - feed requests served from feed/recommendation pipeline
- cache hit rate = 80%
    - hot vidoe blobs served via CDN
    - video metadata cached
- replication factor = 3x
```

## 9.7 Logging / Metrics System

```
Design Logging System

Scope
- producers can write logs into the system
- operators can read logs
- operators can search logs
- no sharing
- no analytics
- no 3rd-party integrations
- system type: heavy-write append-only system

Scale
- assume 1M logical producers / tenants
- global usage

Behavior
- each producer writes logs once every 1 min -> 1,440/day
- operators perform ~20 reads/searches per day
- average log text size = 1KB
- write workload dominates user-facing reads

Traffic
- write QPS = 1M * 1440 / 10^5 = 14.4K QPS
- read/search QPS = 1M * 20 / 10^5 = 200 QPS
- write bandwidth = 14.4K * 1.2KB = 17MB/s
- user-facing read bandwidth is low
- backend search read amplification may be much higher than 200 QPS suggests

Data
- Log object: ~1.2KB
 - log_id -> 8B
 - customer_id -> 8B
 - timestamp -> 16B
 - metadata -> 50B
 - text -> 1KB
- dominant field: text

Retention
- hot: recent logs for 7 days
- warm: logs from 7 to 30 days
- cold: archived logs in S3 glacier
- retained long-term / forever
- storage unbounded

Peak
- peak multiplier = 2x
- traffic pattern = steady and predictable

Infra
- encoding overhead = 2x for JSON ingestion
- indexing overhead higher because search is in scope
 - (customer_id, timestamp) -> logs by customer for past x days
 - severity / service filters
 - possible inverted index for text search
- cache more useful for recent queries / recent log windows than full-object caching
- replication factor = 3x for
```

## 9.8 Google Docs (Realtime Collaboration)

```
Design Google Docs (Realtime Collaboration)

Scope
- users can create documents
- multiple users can concurrently edit the same document
- users can join collaborative editing sessions
- no version control
- no media/file uploads
- no comments/likes/social features
- system type: concurrent real-time collaboration system

Scale
- 100M DAU
- average session length = 30mins
- global usage

Behavior
- concurrent users derived from session model:
    - concurrent users = 100M * 30 / 1440 = 2M
    - peak concurrent users = 2M * 3 = 6M
- each user performs 20 writes/session
- each write generates remote update delivery to collaborators
- average edit operation size = 200B
- average collaboration/session = 2

Traffic
- write QPS = 6M * (20/1800) = 66K QPS
- remote update delivery is the main read-like traffic
- if avg 2 collaborators/session, each write fans out to 1 other user
- effective update delivery QPS = same order as write QPS
- write bandwidth = 66K * 200B = 13.2MB/s
- delivery bandwidth of same order
- per-session generated edits = 2 users * 20 writes * 200B = 8KB

Data
- edit operation object = 200B
- average document object stored = 50KB - 100KB
- document metadata includes:
    - document_id
    - owner_id
    - collaborators
    - timestamps
- dominant persisted field -> document context

Retention
- active documents kept in hot storage
- inactive documents moved to cheaper long-term storage
- documents retained forever
- storage unbounded

Peak
- peak concurrency multiplier = 3x
- traffic pattern driven by overlapping sessions and collaboration bursts

Infra
- encoding overhead = 2x if using JSON for simplicity
- real systems may use more compact op formats
- indexing:
    - document_id -> direct access
    - (owner_id, timestamp) -> recent documents
    - collaborator/access lookup handled separately
- cache active document/session state in memory
- cache recent completed documents for fast reopen
- replication factor = 3x
- persisted document state is durable: session state is ephemeral

```

## 9.9 Stripe / Payment System

```
Design Stripe

Scope
- users can initiate payments (charge)
- system processes transactions
- system confirms success/failure
- system ensures idempotency (no double charge)
- refunds / reconciliation out of scope
- no fraud detection
- system type: correctness-critical + consistency-first system

Scale
- assume 50M DAU
- assume 10% of users perform payments daily
- global usage

Behavior
- active payers = 50M * 10% =5M users/day
- each payer performs ~2 transactions/day

- total transactions/day = 10M

- payment operations include:
    - initiate payment(write)
    - status check(read)
    - confirmation update(write)
- assume per transaction:
    - 2 writes (init + finalize)
    - 1 read (status check)
- read:write ratio: 1:2 (write-heavy logically)

Traffic
- total transactions/day = 10M
- writes/day = 10M * 2 =20M writes/day
- reads/day = 10M * 1 = 10M reads/day

- write QPS = 20M/10^5 = 200 QPS
- read QPS = 10M / 10^5 = 100 QPS

- avg transaction object size = 1KB

- write bandwidth = 200 * 1KB = 200KB/s
- read bandwidth = 100 * 1KB = 100KB/s

Data
- Transaction object = 1KB
    - transaction_id -> 16B
    - user_id -> 8B
    - merchant_id -> 8B
    - amount -> 8B
    - cureency -> 4B
    - status -> 4B
    - timestamp -> 16B
    - metadata -> remaining
- dominant field: metadata + status

Retention
- transactions must be stored long-term for audit/compliance
- hot: recent transactions (30 days)
- warm: months of data
- cold: archival storage
- retention: effectively forever
- system storage unbounded

Peak
- peak multiplier = 3x (payments more stable than social)
- traffic pattern:
    - daily peaks (shopping hours)
    - event spikes(sales, holidays)

Infra assumptions
- encoding overhead = 2x(JSON / structured format)
- indexing:
    - transaction_id -> direct lookup
    - (user_id, timestamp) -> user history
    - (merchant_id, timestamp) -> merchant reports
- cache hit rate low (20-30%)
    - correctness critical -> prefer DB over cache
    - caching mostly for read-only history
- replication factor = 3x
    - strong durability requirements

```

* * *

