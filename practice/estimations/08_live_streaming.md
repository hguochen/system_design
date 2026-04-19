# Practice 8 — Live Streaming (e.g. Twitch)

## Given Assumptions
- 30M DAU (viewers)
- 2M concurrent streamers at peak
- Average viewer watches 2 hours/day
- Average stream bitrate: 6 Mbps (1080p60)
- Average viewer consumes at: 4 Mbps (720p)
- Each stream is recorded and stored; average stream duration: 4 hours
- Recorded stream storage: raw at 6 Mbps → encode to 2 variants (720p, 480p) = 2× multiplier
- Stream metadata: `stream_id` (8B) + `streamer_id` (8B) + `title` (200B) + `start_time` (8B) + `duration` (4B)
- Recordings retained for 60 days
- Replication: 3×

## Your Task

Estimate all of the following. Show your working step by step. State any additional assumptions you make.

1. Peak concurrent viewers
2. Outbound bandwidth to viewers
3. Inbound bandwidth from streamers
4. Raw recorded video storage produced per day
5. Total raw recording storage (60-day retention, with encoding multiplier)
6. Total storage footprint (with replication)
7. Metadata record size and total metadata storage (60 days)

---

## Answer Key

### 1. Peak Concurrent Viewers
- DAU: 30M; avg watch time: 2 hr/day out of 24 hr
- Concurrent viewers: 30M × (2/24) = **~2.5M concurrent viewers**

### 2. Outbound Bandwidth to Viewers
- 2.5M viewers × 4 Mbps = 10,000,000 Mbps = **~1.25 TB/s outbound**

> This is why Twitch relies entirely on CDN edge nodes — origin servers cannot serve this load.

### 3. Inbound Bandwidth from Streamers
- 2M streamers × 6 Mbps = 12,000,000 Mbps = **~1.5 TB/s inbound**

### 4. Raw Recorded Video Per Day
- Streams per day: assume 2M streamers × 1 stream each = 2M streams
- Avg duration: 4 hours = 14,400 sec
- Per stream: 6 Mbps × 14,400s = 86,400 Mb = 10.8 GB
- Total/day: 2M × 10.8 GB = 21,600,000 GB = **~21.6 PB/day**

### 5. Total Recording Storage (60 days, with encoding)
- Raw 60-day: 21.6 PB × 60 = 1,296 PB
- After 2× encoding variants: 1,296 × 2 = **~2,592 PB ≈ 2.6 EB**

### 6. Total Storage Footprint
- 2.6 EB × 3 replication = **~7.8 EB**

### 7. Metadata
- Record size: 8+8+200+8+4 = **228B ≈ 250B**
- Records/day: 2M streams/day × 60 days = 120M records
- Storage: 120M × 250B = 30 GB — **negligible**
