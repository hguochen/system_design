# Practice 7 — File Storage (e.g. Dropbox)

## Given Assumptions
- 500M registered users; 100M DAU
- Each DAU uploads 2 files/day; average file size: 500 KB
- Each DAU downloads/syncs 10 files/day; average file size: 500 KB
- File metadata record: `file_id` (8B) + `owner_id` (8B) + `filename` (200B) + `size` (8B) + `created_at` (8B) + `checksum` (32B)
- Files retained indefinitely; estimate for 5 years
- Deduplication: assume 30% of uploaded files are duplicates (store only once)
- Replication: 3×
- Chunk size for uploads: 4 MB (files split into 4 MB chunks)

## Your Task

Estimate all of the following. Show your working step by step. State any additional assumptions you make.

1. Write RPS (file uploads/sec)
2. Read RPS (file downloads/sec)
3. Read:Write ratio
4. Metadata record size
5. Total raw file storage after 5 years (after deduplication)
6. Total raw metadata storage after 5 years
7. Total storage footprint (with replication)
8. Inbound and outbound bandwidth
9. How many chunks per upload on average, and why does chunking matter?

---

## Answer Key

### 1. Write RPS
- Uploads: 100M × 2 = 200M files/day
- Write RPS: 200M / 10^5 = **2,000 writes/sec**

### 2. Read RPS
- Downloads: 100M × 10 = 1B files/day
- Read RPS: 1B / 10^5 = **10,000 reads/sec**

### 3. Read:Write ratio
- 10K : 2K = **5:1**

### 4. Metadata Record Size
- 8+8+200+8+8+32 = **264B ≈ 280B**

### 5. Total Raw File Storage (5 years, after dedup)
- Raw uploads: 200M × 500 KB × 365 × 5 = 182,500B KB = 182.5B MB = 182.5 PB
- After 30% dedup: 182.5 PB × 70% = **~127.75 PB**

### 6. Total Raw Metadata Storage (5 years)
- Records: 200M/day × 365 × 5 = 365B records
- Storage: 365B × 280B = 102,200 GB ≈ **~102 TB**

### 7. Total Storage Footprint
| Component | Raw | × Replication | Total |
|---|---|---|---|
| Files | 127.75 PB | × 3 | **~383 PB** |
| Metadata | 102 TB | × 3 | ~306 TB |
| **Combined** | | | **~383 PB** (files dominate) |

### 8. Bandwidth
| Direction | Calculation | Result |
|---|---|---|
| Write inbound | 2K/s × 500 KB | **~1 GB/s** |
| Read outbound | 10K/s × 500 KB | **~5 GB/s** |

### 9. Chunking
- Avg file = 500 KB; chunk = 4 MB → files < chunk size, so most files = **1 chunk**
- For larger files (e.g. 40 MB): 40 MB / 4 MB = 10 chunks
- Chunking enables: resumable uploads, parallel transfer, deduplication at chunk level, and efficient delta sync (only re-upload changed chunks)
