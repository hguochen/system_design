# 6.6 CDN for Media Delivery (Images, Video)

> **Topic:** Topic 6 — CDN
> **Phase:** B — Scalability Branch
> **Date studied:** 2026-07-06

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

Media delivery is where CDNs stop being a "nice latency optimization" and become the load-bearing wall of the architecture. Images and video dominate the byte volume of most consumer systems — a single 1080p stream is ~5 Mbps, and a viral image can be requested billions of times. The core challenge is twofold: **images** need to be transformed (resized, reformatted, compressed) into many variants and served from cache with high hit rates; **video** needs to be chunked, encoded into multiple bitrates, and streamed adaptively so playback survives changing network conditions. Mastering this topic means knowing how HLS/DASH adaptive bitrate streaming works, why video is delivered as small segments over HTTP rather than as one big file, how image transformation pipelines cache their output, and how origin shielding protects your storage tier from the long tail of cache misses.

### 🎯 What to Focus On

**1. Why media is different from static assets.** A CSS file is a few KB and identical for everyone. A video is gigabytes, has dozens of encoded renditions, and is consumed as a stream. The delivery model, cache strategy, and origin protection all differ. Be able to articulate why you can't just "put video behind a CDN" the way you would a favicon.

**2. Adaptive Bitrate Streaming (ABR) — HLS and DASH.** This is the single most important mechanism. Video is split into short segments (2–10s), each encoded at multiple bitrates; the player fetches a manifest and switches renditions per-segment based on measured bandwidth. Every segment is a cacheable HTTP object — this is what makes CDNs perfect for video. You must be able to walk through the manifest → segment → adaptive-switch flow.

**3. Image transformation and on-the-fly variants.** Modern image CDNs resize, crop, and reformat (WebP/AVIF) at the edge on first request, then cache the result keyed by the transform parameters. Understand the "transform once, serve many" pattern and why cache key design (including device/format) is critical to hit rate.

**4. Origin shielding and cache hierarchy for large objects.** Media misses are expensive — pulling a 4 GB video from origin storage repeatedly would saturate it. A shield/tier-1 layer consolidates misses so the origin sees one fetch per object, not one per edge PoP. This is multi-level caching (5.8) applied to media.

**5. Cost, live vs. VOD, and DRM boundaries.** Know the difference between video-on-demand (fully cacheable) and live streaming (near-real-time segmenting, low-latency variants), where transcoding happens, and how signed URLs / token auth protect paid content at the edge.

---

## 1. 🎯 Goal of This Subtopic

After studying this, you should be able to:

- Design an end-to-end image delivery pipeline: upload → storage → edge transformation → cached variants, and reason about cache hit rate for the variant explosion.
- Explain adaptive bitrate streaming (HLS/DASH) from first principles — manifest, segments, per-segment bitrate switching — and why it makes video a CDN-friendly workload.
- Choose the right origin-protection strategy (origin shield, tiered cache) for large media objects and justify it with cache-miss economics.
- Distinguish VOD from live streaming and describe how the delivery pipeline changes for each.
- Secure paid or private media at the edge using signed URLs / token authentication without killing cacheability.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can walk through the full HLS/DASH playback flow: player requests manifest → parses rendition list → fetches segments → measures throughput → switches bitrate per segment.
- [ ] Can explain why video is delivered as short HTTP segments rather than a single file, and how that maps onto CDN caching.
- [ ] Can design an image transformation pipeline and reason about the cache-key/variant explosion trade-off (device, format, size).
- [ ] Can explain origin shielding for media and quantify why it matters when a 4 GB object is requested across 200 PoPs.
- [ ] Can contrast VOD vs. live streaming pipelines, including where transcoding sits and the latency implications.
- [ ] Can describe how signed URLs / token auth protect premium media at the edge while preserving cacheability.

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] Read **ByteByteGo — "How Netflix / YouTube stream video"** (https://blog.bytebytego.com/) — focus on ABR and segment delivery
- [ ] Read **Cloudflare Learning — "What is video streaming? | HLS vs DASH"** (https://www.cloudflare.com/learning/video/what-is-http-live-streaming/)
- [ ] Read **Netflix Open Connect overview** (https://openconnect.netflix.com/en/) — how Netflix embeds CDN appliances inside ISPs
- [ ] Read through **Sections 4–9** (Cheatsheet → How It Works) carefully — don't skim
- [ ] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **Core Definition** from memory, then compare
- [ ] Explain **First Principles** out loud without notes — why does media need a different delivery model than static assets?
- [ ] Reconstruct the **HLS playback flow** step by step from memory
- [ ] Restate each **Trade-off** row in your own words — if you can't explain the cost, you don't own it yet

### Phase 3 — Apply 🔧 💪💪💪💪
*Goal: Connect to real systems and simulate interview scenarios.*

- [ ] Go through **Real-World System Examples** (Section 10) — verify each claim independently and add anything missed to **My Notes**
- [ ] Practice the **Interview Application** (Section 12) out loud — say the trigger phrases and your response as if in a live interview
- [ ] Work through **Common Misconceptions** (Section 13) — for each, make sure you can explain *why* the misconception is wrong
- [ ] Trace the **Relationships to Other Concepts** (Section 14) — can you explain each connection without looking?

### Phase 4 — Validate 🧪 💪💪💪💪💪
*Goal: Confirm you actually own it, not just recognize it.*

- [ ] Answer every **Self-Check Quiz** question (Section 15) out loud without looking at your notes
- [ ] Recite the **Cheatsheet** (Section 4) from memory — if you can't, re-do Phase 2
- [ ] Tick off items in **What Mastery Looks Like** (Section 2) — only check a box if you can demonstrate it on demand
- [ ] Teach this concept out loud to an imaginary interviewer for 2 minutes without hesitation or notes

---

## 4. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

```
§ 1  WHY IT EXISTS
Media (images + video) is the overwhelming majority of internet bytes. A single 4K
stream is ~15–25 Mbps; a viral image is requested billions of times. Serving these from
origin storage would saturate it instantly and give users in far regions unwatchable
latency/buffering. CDNs solve this by caching media at the edge AND by making video
cacheable at all — via segmentation. The trick: turn a giant stream into thousands of
small, individually cacheable HTTP objects, and transform images into per-device variants.

§ 2  IMAGE DELIVERY
- Upload once to origin (object store: S3/GCS).
- Edge transforms on first request: resize, crop, compress, reformat (JPEG→WebP/AVIF).
- Result cached at edge keyed by transform params (width, format, quality, DPR).
- "Transform once, serve many." Variant explosion is the enemy of hit rate —
  constrain the allowed transform set (named presets), don't allow arbitrary sizes.
- Serve format via content negotiation (Accept header) or device detection.

§ 3  VIDEO DELIVERY — ADAPTIVE BITRATE (ABR)
- Transcode source into a ladder of renditions (e.g., 240p/480p/720p/1080p/4K).
- Segment each rendition into short chunks (2–10s), e.g. HLS .ts/fMP4 or DASH.
- Manifest/playlist (HLS .m3u8, DASH .mpd) lists renditions + segment URLs.
- Player: fetch manifest → start low → measure throughput per segment →
  switch UP/DOWN rendition at the next segment boundary. Smooth, no re-buffer.
- Every segment is a normal cacheable HTTP GET → CDN caches them like any static file.

§ 4  ORIGIN SHIELDING (multi-level caching for media)
- Problem: a cold object requested across 200 PoPs = 200 origin fetches of a huge file.
- Fix: a shield / tier-1 PoP sits between edge and origin. Edge misses go to shield;
  shield fetches origin ONCE, fans out to all edges. Origin sees 1 fetch, not 200.
- This is 5.8 multi-level caching applied at the network layer.

§ 5  VOD vs. LIVE
VOD:  content pre-transcoded + pre-segmented, fully cacheable, near-100% hit rate.
LIVE: segments produced in real time; low-latency HLS/DASH (LL-HLS) shrinks segment/
      chunk size to cut glass-to-glass delay; edge caches each segment for its short life.

§ 6  SECURITY / PAID CONTENT
- Signed URLs / signed cookies / token auth validated AT the edge → only authorized
  users fetch. Keep the cache key independent of the token so caching still works.
- DRM (Widevine/FairPlay/PlayReady) encrypts segments; license served separately.
- Hotlink protection via Referer/token to stop bandwidth theft.

§ 7  INTERVIEW TRIGGERS
→ "Design an image hosting / photo-sharing service" (Instagram, Imgur)
→ "Design a video streaming platform" (YouTube, Netflix, TikTok)
→ "How do you serve 4K video to users worldwide without buffering?"
→ "How do you resize images for mobile vs. desktop efficiently?"

§ 8  NUMBERS & GOTCHA
Segment length:   2–10s typical; LL-HLS ~1s or sub-second chunks
Bitrate ladder:   ~5–8 renditions from ~200 Kbps (240p) to 15–25 Mbps (4K)
1080p bitrate:    ~5 Mbps H.264;  4K ~15–25 Mbps
Image formats:    AVIF < WebP < JPEG in size; AVIF ~50% smaller than JPEG
GOTCHA: Manifests must have SHORT TTL (or be uncached for live), but SEGMENTS get LONG
  TTL — they're immutable. Caching a stale manifest breaks playback; treating segments
  as dynamic destroys your hit rate. Different TTLs for manifest vs. segments is the
  classic mistake candidates miss.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

CDN media delivery is the practice of distributing images and video to globally dispersed users by caching them at edge locations — where images are transformed into device-appropriate variants at the edge and video is transcoded into a ladder of bitrates and split into short, individually cacheable HTTP segments that a client streams adaptively based on its current network conditions.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*

### Adaptive Bitrate Streaming (ABR)
The client, not the server, decides quality. The video is pre-encoded at multiple bitrates ("the ladder"), each split into aligned short segments. The player continuously measures how fast segments are arriving and picks the highest rendition it can sustain, switching at segment boundaries. This is why a stream downgrades to 480p on a train and jumps back to 1080p on Wi-Fi without stopping. HLS (Apple) and MPEG-DASH are the two dominant ABR protocols; both deliver over plain HTTP.

### Segmentation and the Manifest
A stream is delivered as (1) a **manifest/playlist** — HLS `.m3u8` or DASH `.mpd` — that describes the available renditions and lists the segment URLs, and (2) the **segments** themselves (2–10s each, `.ts` or fragmented-MP4). The manifest is small and may change (especially for live); segments are immutable once produced. This separation is the heart of why video is CDN-friendly: each segment is just a static file the edge can cache.

### Image Transformation Pipeline
Rather than storing every crop/size/format up front, image CDNs store one high-quality master and generate variants on demand. A request like `image.jpg?w=400&format=webp` triggers an edge transform (resize + reformat), and the output is cached keyed by those parameters. Subsequent identical requests are pure cache hits. The design tension is variant explosion — allowing arbitrary widths shatters your hit rate, so production systems constrain to named presets or a small set of breakpoints.

### Origin Shield / Tiered Cache
For large media, a cache miss is very expensive (multi-GB transfer). An origin shield is a designated intermediate cache tier that all edge PoPs consult before hitting origin. It collapses N edge misses for the same object into a single origin fetch, protecting the storage tier and cutting egress cost. This is multi-level caching (5.8) at the CDN scale.

### VOD vs. Live
**Video-on-demand** is pre-processed: transcoded, segmented, and fully cacheable ahead of time, so hit rates approach 100%. **Live** produces segments in real time; the pipeline must transcode and segment on the fly, manifests update continuously, and latency ("glass-to-glass") becomes a first-class concern — addressed by low-latency variants (LL-HLS, LL-DASH) using shorter segments/chunked transfer.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

Two physical realities force media into a specialized delivery model. First, **bytes**: media dominates traffic volume by orders of magnitude. Text and markup are kilobytes; a two-hour movie in 4K is tens of gigabytes, and popular content is requested at planetary scale. Serving that from a central origin would saturate the origin's disks and network long before it saturated CPU, and every far-away user would pay hundreds of milliseconds of round-trip latency plus congestion. Caching media at the edge is the only economically and physically viable answer.

Second, **the network is variable and video is continuous**. Early video delivery tried to stream one fixed-bitrate file; if the user's bandwidth dropped below that bitrate, playback stalled and buffered. The insight of adaptive bitrate streaming was to stop treating video as one object and instead treat it as a sequence of small, independently-fetched segments, each available at several qualities. Now the client can react to bandwidth in real time — dropping quality to keep playing rather than freezing. Crucially, this also made video *cacheable*: because segments are ordinary immutable HTTP objects, the entire CDN machinery built for static files suddenly works for video. Images have a parallel story — the explosion of device sizes and modern formats (WebP, AVIF) made pre-generating every variant impractical, so transformation moved to the edge, computed once per variant and cached.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*

### Model 1: Video as "Netflix on a Flipbook"
Don't think of a stream as a river; think of it as a flipbook of short clips. Each page (segment) is a self-contained few-second file, and for each page you can choose a high-res or low-res version. The player flips pages one at a time, and before turning each page it glances at how fast the last few pages downloaded and picks the resolution accordingly. Because every page is just a file, the CDN caches pages exactly like it caches images. *Where it breaks down:* live streaming, where the pages are being drawn moments before you flip to them — now the flipbook is being written just ahead of your reading, and latency matters.

### Model 2: Image Transforms as a Short-Order Kitchen
The origin object store is the pantry holding raw ingredients (master images). The edge is a short-order cook: the first time someone orders "400px WebP," the cook prepares it fresh (transform) and also keeps a plate under a warmer (cache). Everyone who orders the identical dish afterward gets the warmed plate instantly. *Where it breaks down:* if every customer orders a slightly different size, the cook is always cooking from scratch and the warmer is useless — the argument for constraining to a fixed menu (named presets) instead of arbitrary transforms.

### Model 3: Origin Shield as a Wholesale Buyer
Imagine 200 corner shops (edge PoPs) that each want to sell the same rare product. Without coordination, all 200 phone the distant factory (origin) and order it — 200 shipments. With an origin shield, they all order from one regional wholesaler; the wholesaler places a single factory order and distributes to all 200 shops. The factory (your storage tier) sees one request instead of 200. *Where it breaks down:* the wholesaler is now a potential bottleneck/single point for that region — real CDNs use a tier of shields, not one.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

**Image request path (transform + cache):**
1. Client requests `photo.jpg?w=400&format=auto` (or the CDN infers format from the `Accept` header).
2. Edge checks its cache keyed by (object, width, format, quality, DPR). On hit → return immediately.
3. On miss, the edge (or an origin-side transform service) fetches the master from object storage, resizes/crops/re-encodes to the requested variant.
4. The edge stores the result with a long TTL (images are effectively immutable per URL) and returns it.
5. All subsequent identical requests are cache hits. New variants pay the transform cost once each.

**Video VOD ingest (offline, before anyone watches):**
1. Source uploaded to origin.
2. Transcoder produces a **bitrate ladder** — e.g., 240p @ 300 Kbps up to 4K @ 20 Mbps, plus multiple audio tracks.
3. Each rendition is **segmented** into aligned 2–10s chunks (HLS `.ts`/fMP4 or DASH), and a **manifest** (`.m3u8` / `.mpd`) is written listing renditions and segment URLs.
4. Segments + manifest land in origin storage, ready to be pulled into the CDN on first request.

**Video playback path (ABR in action):**
1. Player fetches the **master manifest**, sees the list of renditions.
2. Player requests the first segment at a conservative (low/mid) bitrate to start fast.
3. As each segment downloads, the player measures throughput and buffer level.
4. At each segment boundary it decides: bandwidth healthy and buffer full → step **up** a rung; throughput dropping or buffer draining → step **down**. Switches are seamless because renditions are time-aligned.
5. Each segment request is a plain HTTP GET → served from the nearest edge cache; misses pull through the shield to origin.

**Origin shielding for a cold object:**
1. Object not yet in any cache. Requests arrive at many edge PoPs simultaneously (e.g., a new release).
2. Each edge miss is routed to the designated **shield** PoP rather than directly to origin.
3. The shield deduplicates: the first miss triggers a single origin fetch; concurrent misses for the same object wait (request collapsing) and are served from the shield once populated.
4. Origin serves the object **once**; the shield fans it out to all edges. Origin egress and load are bounded regardless of PoP count.

**Manifest vs. segment TTL (the critical detail):**
- **Segments** are immutable → long/near-infinite TTL, cache aggressively.
- **VOD manifest** → moderate TTL (rarely changes).
- **Live manifest** → very short TTL or no-cache, because it updates every few seconds as new segments are produced. Getting these TTLs backwards is a classic failure: stale manifest = broken/frozen playback; uncached segments = origin meltdown.

**Live-specific additions:**
- A live encoder/packager produces segments in real time; low-latency modes (LL-HLS/LL-DASH) use ~1s or sub-second **partial** segments and chunked transfer to reduce glass-to-glass delay from ~30s down to 2–5s.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| **Netflix Open Connect** | Netflix ships its own CDN appliances (OCAs) into ISP networks; VOD content is pre-positioned/transcoded into ABR ladders and cached inside the ISP, so segments are served from within the user's own provider | Extreme edge caching; content is pushed to appliances during off-peak hours. Near-100% VOD cache hit inside the ISP |
| **YouTube** | Massive transcoding pipeline generates ABR ladders (incl. VP9/AV1) per upload; DASH delivery; Google's edge CDN caches segments globally | Uses AV1/VP9 to cut bitrate; per-segment adaptive switching is visible in the "Stats for nerds" overlay |
| **Cloudinary / imgix / Cloudflare Images** | On-the-fly image transformation at the edge: URL-encoded params (`w`, `h`, `format`, `quality`) produce cached variants; auto WebP/AVIF via content negotiation | Classic "transform once, serve many"; presets constrain variant explosion |
| **TikTok / Instagram Reels** | Short-form VOD pre-transcoded to ABR; aggressive edge caching + prefetch of the next video's first segments to make scrolling feel instant | Prefetch + tiny startup segments optimize perceived latency |
| **Twitch (live)** | Real-time ingest → live transcode → LL-HLS segments; short segment lengths for low latency; manifests update continuously and are near-uncacheable while segments cache briefly | Demonstrates the live pipeline and manifest/segment TTL split |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Segmentation makes video cacheable and enables seamless quality switching | Transcoding into a full bitrate ladder is CPU-expensive and multiplies storage (one source → many renditions × many segments) |
| Edge image transforms serve perfectly-sized assets without pre-generating every variant | Variant explosion destroys hit rate if arbitrary transforms are allowed; requires disciplined preset/cache-key design |
| Origin shielding collapses N PoP misses into 1 origin fetch, protecting storage | Adds a cache tier and a potential regional bottleneck; slightly higher latency on cold pulls (extra hop through shield) |
| ABR keeps playback alive on poor networks by degrading quality instead of stalling | Quality oscillation and startup-latency tuning are hard; aggressive switching looks janky, conservative switching wastes bandwidth |
| Signed URLs/DRM secure paid content at the edge | Auth/DRM adds complexity and can hurt cacheability if the cache key isn't decoupled from the token; DRM licensing is operationally heavy |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "Design a video streaming service like YouTube / Netflix"
- "Design an image hosting or photo-sharing platform (Instagram, Imgur)"
- "How would you serve 4K video worldwide without buffering?"
- "How do you efficiently deliver images sized for both mobile and desktop?"

**What you say / do:**
Bring this up during high-level design of the delivery/read path, right after you've placed object storage for the media. For video: "I'd transcode each upload into an adaptive bitrate ladder, segment each rendition into ~4-second chunks, and write an HLS/DASH manifest. The player streams adaptively, and because every segment is an immutable HTTP object, my CDN caches them with a long TTL — I only keep the manifest short-TTL. I'd add an origin shield so a cold title doesn't hammer storage across every PoP." For images: "I'd store one master and transform to device-specific variants at the edge, caching each variant keyed by size and format, and constrain to named presets to protect hit rate." Then proactively raise the manifest-vs-segment TTL split and origin shielding to show depth.

**The trade-off statement (memorize this pattern):**
> "By transcoding into an ABR ladder and delivering short cacheable segments, we get resilient global playback and near-100% CDN offload for VOD — at the cost of heavy upfront transcoding compute and multiplied storage. For a VOD-heavy product that's clearly worth it; for a live product I'd accept lower cache efficiency and add low-latency HLS to keep glass-to-glass delay acceptable."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** Video is streamed as one continuous file straight from the server.
  ✅ **Reality:** Modern streaming delivers many short, independent HTTP segments (2–10s each) at multiple bitrates. The client reassembles and adaptively switches quality per segment. This segmentation is exactly what lets a CDN cache video like any static file.

- ❌ **Misconception:** You should cache the manifest and segments the same way.
  ✅ **Reality:** Segments are immutable → long TTL. Manifests change (especially for live) → short or no TTL. Caching a stale live manifest freezes playback; treating segments as dynamic destroys hit rate. Different TTLs is mandatory.

- ❌ **Misconception:** Adaptive bitrate means the server picks the quality based on the user's device.
  ✅ **Reality:** The *client* picks. The player measures real-time throughput and buffer health and requests the rendition it can sustain, switching at segment boundaries. The server just offers the ladder.

- ❌ **Misconception:** Generate every image size and format up front and store them all.
  ✅ **Reality:** That's a combinatorial explosion (sizes × formats × crops × DPR). Production systems store one master and transform on demand at the edge, caching each variant — and constrain the allowed variants to protect hit rate.

- ❌ **Misconception:** Signed URLs make content uncacheable because every URL is unique.
  ✅ **Reality:** Only if you design the cache key badly. The CDN validates the token/signature but keys the cache on the underlying object path (not the token), so authorized requests still hit a shared cached object.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** 6.5 CDN for static assets vs. dynamic content — media is the extreme case of "large cacheable static content," and understanding what's cacheable is the prerequisite; also builds on 5.8 Multi-Level Caching, since origin shielding is literally multi-level caching applied at the CDN layer.
- **Enables:** Full system designs for YouTube/Netflix/Instagram (Phase H archetypes) — you can't design those without the media delivery pipeline; also enables reasoning about 6.7 CDN as DDoS mitigation, since the same edge that absorbs media traffic absorbs attack traffic.
- **Tension with:** Cache invalidation at the edge (6.3) — media wants aggressive long TTLs for hit rate, but that fights the need to update/replace content; solved via versioned/immutable URLs so you never invalidate, you just publish a new path.

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. Why is video delivered as short segments at multiple bitrates rather than as a single file, and how does that interact with the CDN?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6 and Section 9.*

2. You're designing an image service. A product manager wants to allow arbitrary width/height query params. What's the risk, and how do you mitigate it?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6 (Image Transformation) and Section 13.*

3. In HLS/DASH, what decides which bitrate the user gets at any given moment, and when does the switch happen?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6 (ABR) and Section 13.*

4. A brand-new movie is released and requested from 200 edge PoPs within seconds. Without origin shielding, what happens to your storage tier, and how does shielding fix it?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6 (Origin Shield) and Section 9.*

5. You cache the manifest and the segments with the same long TTL on a live stream. What breaks, and what's the correct TTL strategy?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 9 (Manifest vs. segment TTL).*

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **Cloudflare Learning — HTTP Live Streaming (HLS) & HLS vs DASH** — https://www.cloudflare.com/learning/video/what-is-http-live-streaming/ — clear primer on segments, manifests, and ABR
- [ ] **Netflix Open Connect** — https://openconnect.netflix.com/en/ — how Netflix pushes its CDN into ISPs and pre-positions VOD
- [ ] **ByteByteGo — video streaming / "How does Netflix work"** — https://blog.bytebytego.com/ — system-design-level overview of the streaming pipeline
- [ ] **Apple — HLS Authoring Specification & Low-Latency HLS** — https://developer.apple.com/documentation/http-live-streaming — the canonical HLS reference incl. LL-HLS
- [ ] **imgix / Cloudinary transformation docs** — https://docs.imgix.com/ — real image transformation params, presets, and cache-key design

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*
