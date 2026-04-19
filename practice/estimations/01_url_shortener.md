# Practice 1 — URL Shortener (e.g. bit.ly)

## Given Assumptions
- 500M DAU
- 10% of users create 1 new short URL per day
- 90% of usage is redirects (reads)
- Shortened URLs are retained for 5 years
- Each URL mapping record: `short_code` (7B) + `long_url` (200B) + `created_at` (8B) + `user_id` (8B)
- Avg redirect response size: 500B
- Replication: 3×

## Your Task

Estimate all of the following. Show your working step by step. State any additional assumptions you make.

1. Write RPS (URL creations/sec)
2. Read RPS (redirect lookups/sec)
3. Read:Write ratio
4. Storage per record (bytes)
5. Total raw storage after 5 years
6. Total storage footprint with 3× replication
7. Bandwidth — inbound and outbound

---

## Answer Key

### 1. Write RPS
- Writers: 500M × 10% = 50M writes/day
- Write RPS: 50M / 10^5 = **500 writes/sec**

### 2. Read RPS
- Reads: 50M × 9 = 450M reads/day (9:1 ratio implied by 90% reads)
- Read RPS: 450M / 10^5 = **4,500 reads/sec**

### 3. Read:Write ratio
- 450M : 50M = **9:1**

### 4. Storage per record
- 7 + 200 + 8 + 8 = **223B ≈ 250B**

### 5. Total raw storage after 5 years
- Records: 50M/day × 365 × 5 = 91.25B records
- Storage: 91.25B × 250B = 22,812 GB ≈ **~23 TB**

### 6. Total storage footprint (3× replication)
- 23 TB × 3 = **~69 TB**

### 7. Bandwidth
| Direction | Calculation | Result |
|---|---|---|
| Write inbound | 500/s × 250B | ~125 KB/s |
| Write outbound | 500/s × ~50B (short URL response) | ~25 KB/s |
| Read inbound | 4,500/s × ~50B (tiny GET request) | ~225 KB/s |
| Read outbound | 4,500/s × 500B | **~2.25 MB/s** |

> Note: Read outbound dominates — typical for read-heavy redirect systems.
