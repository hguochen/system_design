# Practice 2 — Photo Sharing (e.g. Instagram)

## Given Assumptions
- 1B DAU
- Each user views 20 photos/day (reads)
- Each user uploads 1 photo/day (writes)
- Average photo size: 3 MB (after compression)
- Average photo metadata record: `photo_id` (8B) + `user_id` (8B) + `caption` (300B) + `created_at` (8B) + `location` (16B)
- Photos retained indefinitely; estimate for 10 years
- Encoding: 3 variants (thumbnail, medium, full) — 3× multiplier on photo storage
- Replication: 3×

## Your Task

Estimate all of the following. Show your working step by step. State any additional assumptions you make.

1. Write RPS (photo uploads/sec)
2. Read RPS (photo views/sec)
3. Read:Write ratio
4. Metadata record size
5. Total raw photo storage after 10 years
6. Total raw metadata storage after 10 years
7. Total storage footprint (photos + metadata, with encoding and replication)
8. Inbound and outbound bandwidth

---

## Answer Key

### 1. Write RPS
- Uploads: 1B × 1 = 1B uploads/day
- Write RPS: 1B / 10^5 = **10,000 writes/sec**

### 2. Read RPS
- Views: 1B × 20 = 20B views/day
- Read RPS: 20B / 10^5 = **200,000 reads/sec**

### 3. Read:Write ratio
- 200K : 10K = **20:1**

### 4. Metadata record size
- 8 + 8 + 300 + 8 + 16 = **340B ≈ 350B**

### 5. Total raw photo storage after 10 years
- Photos: 1B/day × 365 × 10 = 3,650B photos
- Storage: 3,650B × 3 MB = 10,950,000 TB ≈ **~10.95 EB raw**

### 6. Total raw metadata storage after 10 years
- Records: 3,650B records × 350B = 1,277,500 GB ≈ **~1.28 PB**

### 7. Total storage footprint
| Component | Raw | × Encoding | × Replication | Total |
|---|---|---|---|---|
| Photos | 10.95 EB | × 3 = 32.85 EB | × 3 = **~98.5 EB** | |
| Metadata | 1.28 PB | × 1 | × 3 = **~3.84 PB** | |
| **Combined** | | | | **~98.5 EB** (photos dominate) |

### 8. Bandwidth
| Direction | Calculation | Result |
|---|---|---|
| Write inbound | 10K/s × 3 MB | **~30 GB/s** |
| Write outbound | 10K/s × ~1 KB (confirmation) | ~10 MB/s |
| Read inbound | 200K/s × ~100B (GET request) | ~20 MB/s |
| Read outbound | 200K/s × 3 MB | **~600 GB/s** |

> Note: Read outbound (600 GB/s) dominates — CDN and caching are essential for this system.
