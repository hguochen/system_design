# Practice 10 — Notification System (e.g. Firebase/APNs)

## Given Assumptions
- 1B registered devices (iOS + Android)
- 500M DAU (devices active each day)
- Each DAU receives an average of 20 push notifications/day
- 10% of notifications contain a rich payload (image thumbnail): avg 50 KB
- 90% are text-only notifications: avg 1 KB
- Notification record: `notif_id` (8B) + `device_id` (8B) + `payload` (1 KB avg) + `sent_at` (8B) + `status` (1B)
- Notifications retained for 30 days
- Delivery SLA: notifications must be delivered within 5 seconds of trigger
- Replication: 3×
- Assume 5% of notifications require retry (first delivery attempt fails)

## Your Task

Estimate all of the following. Show your working step by step. State any additional assumptions you make.

1. Total notifications/day
2. Notification send RPS (average and peak — use 3× peak multiplier)
3. Retry RPS
4. Notification record size
5. Total raw storage (30-day retention)
6. Total storage footprint (with replication)
7. Outbound bandwidth (to devices)
8. How many notification gateway servers are needed? (Assume 1 server handles 10K sends/sec)

---

## Answer Key

### 1. Total Notifications/Day
- 500M DAU × 20 = **10B notifications/day**

### 2. Notification Send RPS
- Average RPS: 10B / 10^5 = **100,000 sends/sec**
- Peak RPS (3×): **300,000 sends/sec**

### 3. Retry RPS
- 5% retry rate: 100K × 5% = **5,000 retry sends/sec** (avg)

### 4. Notification Record Size
- 8+8+1,024+8+1 = **~1,050B ≈ 1 KB**

### 5. Total Raw Storage (30 days)
- Records: 10B/day × 30 = 300B records
- Storage: 300B × 1 KB = 300,000 GB = **~300 TB**

### 6. Total Storage Footprint
- 300 TB × 3 = **~900 TB**

### 7. Outbound Bandwidth (to devices)
| Type | Calculation | Result |
|---|---|---|
| Text (90%) | 100K × 90% × 1 KB | **~90 MB/s** |
| Rich (10%) | 100K × 10% × 50 KB | **~500 MB/s** |
| **Total** | | **~590 MB/s ≈ 0.6 GB/s** |

> Rich notifications (10%) account for ~85% of outbound bandwidth — a common Pareto trap.

### 8. Gateway Server Count
- Peak RPS: 300,000 sends/sec
- Per server capacity: 10,000 sends/sec
- Raw servers: 300K / 10K = 30 servers
- With 1.5× buffer: **~45 notification gateway servers**

> Key insight: Notification systems are fan-out write problems — a single event (e.g., a celebrity tweet) can trigger 50M notifications in seconds. The gateway must be horizontally scalable and queue-backed to absorb these spikes.
