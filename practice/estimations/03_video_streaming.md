# Practice 3 — Video Streaming (e.g. YouTube)

## Given Assumptions
- 2B DAU
- Each user watches an average of 30 min of video/day
- 1% of users upload 1 video/day; average uploaded video length: 10 min
- Average video bitrate for playback: 4 Mbps (1080p)
- Average raw uploaded video size: 1 GB per 10-min video
- Encoding produces 4 quality variants (360p, 480p, 720p, 1080p) — treat as 4× multiplier on storage
- Video metadata record: `video_id` (8B) + `uploader_id` (8B) + `title` (200B) + `duration` (4B) + `created_at` (8B)
- Videos retained indefinitely; estimate for 5 years
- Replication: 3×

## Your Task

Estimate all of the following. Show your working step by step. State any additional assumptions you make.

1. Write RPS (video uploads/sec)
2. Read RPS (video stream requests/sec)
3. Read:Write ratio
4. Metadata record size
5. Total raw video storage after 5 years
6. Total storage footprint (with encoding and replication)
7. Inbound bandwidth (uploads)
8. Outbound bandwidth (streaming)

---

## Answer Key

### 1. Write RPS
- Uploaders: 2B × 1% = 20M uploads/day
- Write RPS: 20M / 10^5 = **200 uploads/sec**

### 2. Read RPS (stream requests/sec)
- Total watch time: 2B × 30 min = 60B min/day
- Average video = 10 min → stream requests: 60B / 10 = 6B requests/day
- Read RPS: 6B / 10^5 = **60,000 stream requests/sec**

### 3. Read:Write ratio
- 60K : 200 = **300:1**

### 4. Metadata record size
- 8 + 8 + 200 + 4 + 8 = **228B ≈ 250B**

### 5. Total raw video storage after 5 years
- Videos: 20M/day × 365 × 5 = 36.5B videos
- Storage: 36.5B × 1 GB = 36.5B GB = **~36.5 EB**

### 6. Total storage footprint
| Component | Raw | × Encoding | × Replication | Total |
|---|---|---|---|---|
| Videos | 36.5 EB | × 4 = 146 EB | × 3 = **~438 EB** | |
| Metadata | 36.5B × 250B ≈ 9 TB | × 1 | × 3 ≈ ~27 TB | negligible |

> **Total ≈ ~438 EB** — video storage completely dominates.

### 7. Inbound bandwidth (uploads)
- 200 uploads/sec × 1 GB = **~200 GB/s inbound**

### 8. Outbound bandwidth (streaming)
- 60,000 concurrent streams × 4 Mbps = 240,000 Mbps = **~240 Gbps = ~30 GB/s outbound**

> Note: Unlike photo sharing, inbound and outbound are in the same order of magnitude here due to large upload sizes.
