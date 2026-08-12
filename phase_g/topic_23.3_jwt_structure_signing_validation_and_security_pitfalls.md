# 23.3 JWT — Structure, Signing, Validation, and Security Pitfalls

> **Topic:** Topic 23 — Security
> **Phase:** G — Security Branch
> **Depth Tier:** 🥇 T1 (Core) — budget ~3h
> **Prereqs:** 3.4 (JWT as Stateless Session Token), 23.1 (Authentication vs. Authorization), 23.2 (OAuth2)
> **Date studied:** 2026-08-11

---

## 0. 🧭 The Question This Answers

3.4 established *why* a JWT is attractive: a self-contained, signed token means any service can establish identity without a round trip to a session store, which is what makes a stateless tier genuinely stateless. 23.1 established that establishing identity is only half the job — a verified identity still has to be checked against a policy before anything is allowed. Both of those treated the token as a sealed box: something the auth server hands out and the resource server trusts.

This subtopic opens the box. That matters because almost every real JWT vulnerability lives in the gap between "the library returned true" and "this token actually means what I think it means." A signature that verifies proves exactly one thing — that some key produced these exact bytes. It says nothing about *which* key, *which* algorithm, *who* the token was meant for, or *whether it is still supposed to work*. Every one of those is a separate check the verifier has to perform deliberately, and the format is flexible enough — the algorithm is named in a header the attacker controls — that a verifier written the obvious way can be talked into validating a token the attacker signed themselves.

**The question:** *What exactly is inside a JWT, what does its signature actually prove, and which checks must the verifier perform — in what order — before trusting a single claim, given that skipping any one of them can hand an attacker the ability to mint their own identity?*

> **→ Next:** Before opening up the format, what problem forced tokens to be self-contained and signed in the first place — and why doesn't a simpler encoding work?

---

## 1. 🎯 Interview Quick Reference Card

> *Not a summary — a live-recall tool, built for retrieval speed under interview pressure. If you need the reasoning behind anything here, that's what §2 (cheatsheet) and the rest of the doc are for.*

**The checklist — walk this on the whiteboard, in order:**

1. Draw the three dot-separated segments and name them: `header.payload.signature` — all three base64url-encoded, the first two are plain readable JSON
2. Say the sentence that prevents half the mistakes: **base64url is encoding, not encryption** — anyone holding the token can read every claim
3. Name what the signature covers: the bytes `base64url(header) + "." + base64url(payload)` — change one character of either and verification fails
4. Name the signing choice and what it actually decides: HS256 (shared secret — every verifier can also mint) vs. RS256/ES256 (private key mints, public key verifies — verifiers *cannot* mint)
5. Walk the validation order out loud: **pin the expected algorithm → resolve the key (allowlisted `kid`) → verify the signature → check `exp`/`nbf` → check `iss` and `aud` → only then read claims**
6. Name the structural cost: the issuer cannot take the token back — it is valid until `exp`, so revocation means short lifetimes, refresh rotation, or reintroducing a server-side check (`jti` denylist)
7. Name the pitfall class unprompted: `alg: none`, RS256→HS256 confusion, missing `aud` check, `kid`/`jku` injection — all of them are "the verifier let the token decide how it would be verified"

**Trigger → action:**

| Interviewer says | You do |
|---|---|
| "How do the services authenticate requests to each other?" | RS256 JWT verified locally against a cached JWKS — name that verification needs no round trip, then price the revocation gap unprompted |
| "Walk me through what's inside a JWT." | Three segments, what's in each, which bytes the signature covers, then the validation order — structure *and* validation, never structure alone |
| "How do you log someone out?" | Say plainly that client-side deletion changes nothing server-side; give short TTL + refresh rotation, and `jti` denylist if instant revocation is required |
| "What could go wrong with how you validate that?" | Algorithm pinning first — `alg: none` and RS256→HS256 confusion — then missing `aud`, then `kid` injection |
| "Can we just put the user's permissions in the token?" | Only slow-changing coarse claims; name the staleness window (23.1) and the size cost per request |
| "HS256 or RS256?" | Frame it as *who is allowed to mint*, not as crypto strength — the moment a second party verifies, go asymmetric |

**Fast disambiguation — the pairs that get confused live:**

| Pair | The distinction |
|---|---|
| **JWT vs. JWS vs. JWE** | JWS = signed (integrity, contents readable). JWE = encrypted (contents hidden). "JWT" in practice almost always means a JWS. If you need secrecy you need JWE — signing does not give it to you. |
| **Encoded vs. encrypted** | base64url is a transport encoding with no key and no secrecy — reversible by anyone. Encryption requires a key to reverse. A JWT payload is the former. |
| **HS256 vs. RS256** | HS256 = one shared secret, so anyone who can verify can also forge. RS256 = private key signs, public key verifies, so verification confers no minting power. The choice is about trust topology, not strength. |
| **Access token vs. refresh token vs. ID token** | Access token = presented to an API to get in. Refresh token = presented to the auth server only, to get a new access token. ID token (OIDC) = tells the *client* who the user is; `aud` is the client_id, and it is not an API credential. |
| **`exp` vs. `iat` vs. `nbf`** | `exp` = stop accepting after. `iat` = when it was issued (use for max-age policies). `nbf` = do not accept before. All are seconds since epoch, and all need a small clock-skew leeway (~60s), not an unbounded one. |
| **JWT vs. opaque token** | JWT = self-describing, verified locally, no round trip, cannot be revoked early. Opaque = random string, meaningless without an introspection call, revocable instantly. You are trading a lookup for revocability. |

**High-yield anchors:**

```
RFC 7519 = JWT.  RFC 7515 = JWS (the signing input definition).
RFC 8725 = JWT Best Current Practices — the pitfalls doc; "do not trust
  the alg header" is its headline recommendation.
Typical sizes: ~300–800 bytes signed. Servers commonly cap total request
  headers at 8 KB — a bloated token surfaces as a 431/400, not a 401.
Typical lifetimes: access token 5–15 min, refresh token 7–30 days with
  rotation. AWS Cognito defaults: 1 h access, up to 30 d refresh.
2015 — Auth0 disclosed the `alg: none` and RS256→HS256 confusion flaws
  across many JWT libraries. Both are verifier bugs, not format bugs.
Signing input is EXACTLY: base64url(header) + "." + base64url(payload)
```

**The script — say this close to verbatim:**

> "I'd use RS256 JWTs issued by the auth service. Each downstream service verifies locally against the issuer's JWKS, cached and keyed by `kid`, so identity verification costs no round trip on the hot path — which is the whole reason to pick JWTs over opaque tokens with introspection. The verification isn't just the signature: I'd pin the expected algorithm to RS256 in the verifier config rather than reading it from the token's header, check `exp` with about sixty seconds of skew leeway, and check `iss` and `aud` so an access token minted for the payments API can't be replayed against the admin API. The cost I'm accepting is that I can't revoke a token before it expires — nothing server-side can reach out and cancel a signed string — so I'd keep access tokens at fifteen minutes with a rotating refresh token, and accept that a stolen token is good for up to fifteen minutes. If instant revocation became a hard requirement — say a compliance rule that terminating an employee cuts access immediately — I'd add a `jti` denylist check on every request, or move to opaque tokens with introspection, and pay the lookup I was trying to avoid."

**If pushed on validation safety specifically:**
> The single most important line in a JWT verifier is the one that specifies the algorithm out of band. If the verifier reads `alg` from the token's own header and dispatches on it, an attacker can set `alg` to `none` and strip the signature, or switch RS256 to HS256 and HMAC the token using the *public* key as the shared secret — which they have, because it's published. Rotating the key pair does not fix that, because the new public key is public too. The fix is pinning: the verifier is configured to accept exactly RS256 with exactly this key set, and anything else is rejected before the signature is even examined.

---

## 2. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*
>
> ⏭️ **First time through this topic?** Skip to §3 and come back here for revision.

```
§ 1  WHY IT EXISTS
Server-side sessions require every service that wants to know who is
calling to consult a shared store, which turns identity into a
synchronous dependency shared by the whole fleet. The obvious escape —
just put the user's ID and role in the cookie — fails immediately,
because the client can edit it. Encrypting it instead is worse in a
different way: you now need every verifier to hold the decryption key,
and the contents were never actually secret in the first place. The
insight is that the claims don't need to be hidden, they need to be
unforgeable. Sign them, publish the verification key, and any service
can confirm the issuer produced these exact bytes without asking the
issuer anything.

§ 2  WHAT IT IS
JWT                     Three base64url segments joined by dots:
                        header.payload.signature. RFC 7519.
HEADER                  JSON: `alg` (signing algorithm), `typ`, and
                        usually `kid` (which key signed this).
                        ATTACKER-CONTROLLED — never trust `alg`.
PAYLOAD                 JSON claims. Registered: iss, sub, aud, exp,
                        nbf, iat, jti. Plus whatever custom claims you
                        add. READABLE BY ANYONE HOLDING THE TOKEN.
SIGNATURE               Computed over base64url(header) + "." +
                        base64url(payload). Proves those exact bytes
                        came from the holder of the signing key.
                        Proves nothing else.
JWS vs JWE              JWS = signed, contents readable (what people
                        mean by "JWT"). JWE = encrypted, contents
                        hidden. Signing is not encryption.

§ 3  THE MECHANISM
MINT                    Auth server builds header + payload, signs the
                        joined bytes with its private key (RS256) or
                        shared secret (HS256), appends the signature.
CARRY                   Client sends `Authorization: Bearer <jwt>` on
                        every request. Pure bearer — possession is the
                        whole credential, no binding to the holder.
VALIDATE (ordered)      1. Pin expected alg (from config, NOT the
                           token's header)
                        2. Resolve the key — allowlisted `kid` against
                           a cached JWKS; never fetch a URL named in
                           the token
                        3. Verify the signature
                        4. Check `exp` / `nbf` with ~60s skew leeway
                        5. Check `iss` and `aud` — is this token for
                           THIS service, from the expected issuer
                        6. Only now read the claims and hand identity
                           to authorization (23.1)
FAIL                    Any of steps 1–5 failing is a 401 — identity
                        was never established. A claim failing an
                        authorization policy is a 403.

§ 4  USE / AVOID
USE JWT when: many independent services (or a third party) must verify
  identity without a round trip to the issuer, and a bounded staleness
  window is acceptable.
USE opaque tokens + introspection when: instant revocation is a hard
  requirement, or the token's contents are sensitive, or you already
  run a session store the lookup would hit anyway.
USE HS256 when: a single service both issues and verifies — a monolith
  talking only to itself.
USE RS256/ES256 when: anyone other than the issuer verifies. Verifying
  must not confer the ability to mint.
AVOID putting fine-grained, fast-changing permissions in the payload —
  they freeze at issuance and stay valid until expiry (23.1's
  revocation problem, in token form).
AVOID putting anything sensitive in the payload. It is readable, and it
  is often logged, cached, and stored on the client.
AVOID letting the token choose its own algorithm or its own key source
  (`alg`, `jku`, `x5u`, unbounded `kid`). That is the whole pitfall
  class in one sentence.
AVOID treating "the signature verified" as "the token is valid" — that
  skips `exp`, `iss`, and `aud`, and accepts tokens minted for a
  different service.

§ 5  NUMBERS TO ANCHOR THE DISCUSSION
RFC 7519 (JWT) · RFC 7515 (JWS) · RFC 8725 (JWT Best Current Practices,
  whose headline rule is "do not trust the alg header").
Sizes: ~300–800 bytes typical; ~8 KB is a common total-header server
  limit — bloated tokens fail as 431/400, not 401.
Lifetimes: 5–15 min access + 7–30 day rotating refresh is the common
  shape. AWS Cognito defaults to 1 h access, up to 30 d refresh.
2015: Auth0 disclosed `alg: none` acceptance and RS256→HS256 confusion
  across many libraries — both are verifier bugs, not format bugs.
Clock skew leeway: ~60 seconds is standard. Unbounded leeway is a bug.

§ 6  INTERVIEW TRIGGERS + GOTCHA
→ "What's inside a JWT?"                → three segments, then the
                                            VALIDATION ORDER, not just
                                            the structure
→ "How do you log a user out?"           → client-side deletion changes
                                            nothing; short TTL + refresh
                                            rotation, or a jti denylist
→ "HS256 or RS256?"                       → it's a question about who may
                                            MINT, not about strength
→ "What could go wrong in validation?"    → alg pinning first, then aud,
                                            then kid/jku injection
GOTCHA: Assuming a valid signature means a valid token. The signature
  proves only that some key produced these bytes. Which algorithm,
  which key, for which audience, and still-in-date are four separate
  checks the verifier must make deliberately — and the classic attacks
  all work by getting the verifier to skip one of them.
```

---

## 3. 🧠 The Mindmap

> *The picture to hold in your head while you study. Everything below hangs off this.*

```
   ① MINT              ② CARRY             ③ VALIDATE            ④ EXPIRE /
   (auth server)       (client)            (resource server)       REVOKE
      │                   │                     │                     │
      ▼                   ▼                     ▼                     ▼
 ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐  ┌──────────────┐
 │ HEADER       │  │ Authorization│  │ ORDERED GATE CHAIN  │  │ exp reached  │
 │  alg, typ,   │  │  : Bearer    │  │ 1 pin alg (config)  │  │  → dead      │
 │  kid         │─▶│    <jwt>     │─▶│ 2 resolve key (kid  │─▶│ before exp   │
 │ PAYLOAD      │  │              │  │   → cached JWKS)    │  │  → nothing   │
 │  iss sub aud │  │ pure bearer: │  │ 3 verify signature  │  │    can stop  │
 │  exp nbf iat │  │ possession   │  │ 4 exp / nbf (±60s)  │  │    it        │
 │  jti + custom│  │ IS the       │  │ 5 iss / aud         │  │              │
 │ SIGNATURE    │  │ credential   │  │ 6 hand to authz     │  │ mitigations: │
 │  over h "." p│  │              │  │   (23.1) → 403      │  │  short TTL,  │
 └──────────────┘  └──────────────┘  └─────────────────────┘  │  refresh     │
      │                   │                     │              │  rotation,   │
      │                   │                     │              │  jti denylist│
      ▼                   ▼                     ▼              └──────────────┘
 ⚠ secrets in       ⚠ localStorage       ⚠ skip 1 → alg:none         │
   payload: it's      → any XSS steals      or RS256→HS256            ▼
   ENCODED, not       it. Cookie →          confusion: attacker  ⚠ "logout"
   encrypted          CSRF instead.         MINTS ANY IDENTITY     that only
 ⚠ HS256 = every    ⚠ token in a URL     ⚠ skip 2 → kid/jku       deletes the
   verifier can       lands in logs,        injection: verifier    client copy
   also MINT          referrers, history    fetches ATTACKER key   changes
                                          ⚠ skip 5 → token for    NOTHING
                                            service A replayed
                                            against service B
```

**How to read it:** this is a timeline, not a set of categories — read it left to right as the life of a single token, because each stage's guarantees are consumed by the next one. Stage ① decides what the token can ever say and who is capable of saying it (the HS256/RS256 choice is made here and constrains everything downstream). Stage ② is where the token stops being under the issuer's control at all. Stage ③ is the only stage where anything is *enforced*, which is why it is an ordered chain rather than a bag of checks: gate 1 decides which key material is even eligible, so a verifier that skips it makes gates 2 and 3 meaningless. Stage ④ is where the format's central cost lands — the issuer has no reach into a token already in the wild. The ⚠ notes hanging below each stage are deliberately positioned: every one of the classic JWT attacks is a specific gate that a specific stage failed to enforce, so if you can name the stage, you can reconstruct the attack.

---

## 4. 🔥 The Problem

Before self-contained tokens, identity worked the way 3.2 described: the server issues an opaque random session ID, keeps the real user record in a store, and looks it up on every request. This is correct, revocable, and completely under the server's control — deleting the row logs the user out instantly. It also means that every service that wants to know who is calling must reach the same store. In a single application that is a local Redis call. Across twenty services in three regions, plus a mobile client and a partner API, identity has quietly become a synchronous shared dependency on the hot path of every request: extra latency, extra failure surface, and the exact stateful coupling that 3.6's share-nothing thinking exists to avoid.

The instinctive first fix is to stop looking anything up and just carry the answer with the request — put `user_id=1042&role=admin` in a cookie and read it. This fails in one move, and it fails *silently*: the client holds the cookie, so the client edits it, and `role=admin` costs an attacker one keystroke. The second instinct is to encrypt the cookie so the client can't tamper with it. That is closer, but it solves the wrong problem and creates a new one. It solves secrecy, when what was needed was integrity — the user's own ID and role were never secret from the user. And it requires every service that needs to read identity to hold the decryption key, which means every verifier can also produce valid tokens. You have handed twenty services the ability to mint admin credentials in order to let them read a user ID.

The insight that resolves this is to separate the two properties that "encrypt it" was conflating. The claims do not need to be hidden — they need to be **unforgeable**. Cryptographically sign the claims instead of encrypting them, and you get a token whose contents anyone can read but no one can alter without detection. Publish the verification key, and any service, in any region, run by anyone, can confirm that the issuer produced these exact bytes without asking the issuer anything. Identity verification stops being a network call and becomes a local computation.

That is genuinely the right trade — and it moves the entire security burden to a place it did not previously exist. With a session lookup, the store either returns a valid session or it doesn't; there is no interpretation. With a signed token, "valid" is now whatever the verifier decides to check, and the format hands the attacker input into that decision: the algorithm is named in a header the attacker can rewrite, and so is the key identifier. Every JWT vulnerability in the rest of this document is a consequence of this trade — not a flaw in signing, but a verifier that let the token influence how it would be verified.

**Before and after:**

```
  BEFORE — identity by lookup                  AFTER — identity by signature
  ──────────────────────────────               ─────────────────────────────────
   session_id = cookie["sid"]                   jwt = header.payload.signature
   user = store.get(session_id)   ◀── network   verify_locally(jwt, pubkey)  ◀─ CPU
   if not user: 401                  round trip  if not ok: 401                only

   ✓ instantly revocable — delete                ✓ no round trip: any service,
     the row and it's over                          any region, verifies alone
   ✓ "valid" has exactly one                     ✓ contents readable but
     meaning: the row exists                        unforgeable — integrity,
   ✗ every service needs the store                   not secrecy
     on its hot path                             ✓ verification key can be
   ✗ identity is a shared,                          published without granting
     synchronous dependency                          minting power (asymmetric)
   ✗ store outage = fleet-wide                   ✗ cannot be revoked before exp
     auth outage                                 ✗ "valid" now means whatever
                                                    the verifier checks — and the
   [naive escape: put user_id + role                token influences that
    in the cookie → client edits it]                (alg, kid are attacker input)
   [second escape: encrypt it → every
    verifier holds a minting key]
```

### ✅ Checkpoint

1. A teammate proposes skipping JWTs entirely: "we'll just AES-encrypt the user ID and role into the cookie with a key all our services share — the client can't read or change it, so it's strictly better than signing." Explain precisely which security property this actually provides, which one the system actually needed, and the specific operational failure this design creates that a signed token with an asymmetric key pair does not.

   > 💡 *If you hesitate, re-read the second paragraph — the part separating "hidden" from "unforgeable," and the sentence about what happens when every verifier holds the key.*

MODEL ANSWER — §4 Checkpoint (shared-AES-key cookie vs. signed token)

WHAT IT PROVIDES
  Secrecy (confidentiality). The client cannot read the contents.

WHAT WAS ACTUALLY NEEDED
  Integrity. And note that the secrecy is protecting nothing: the
  payload is the user's OWN id and role. They already know both.
  You are paying full key-distribution cost to hide a fact from the
  only party that already has it.

THE STRUCTURAL FAILURE
  AES is symmetric — one key both encrypts and decrypts. Any service
  that can READ a token can therefore also MINT one. To let twenty
  services read a user id, you have handed twenty services the
  ability to forge admin credentials. Verification power and minting
  power have been fused, and they should never be the same power.

THE 2AM OPERATIONAL TEST
  (a) Shared AES key. The key is now in the attacker's hands, so
      every token in existence is forgeable. You must rotate the key
      on all twenty services. You cannot do it incrementally — during
      a partial rollout, services holding the new key reject tokens
      minted with the old one and vice versa. It is a flag-day
      change: coordinated, simultaneous, with an auth outage across
      the whole fleet while it lands.

  (b) RS256. The compromised service held only the PUBLIC key. That
      key was already published at the JWKS endpoint — the attacker
      gained nothing that wasn't already theirs. The private key
      never left the auth service. There is no auth rotation to
      perform at all. You remediate the one compromised service; the
      other nineteen keep verifying, uninterrupted.

THE ONE-LINE VERSION
  Encryption forces you to distribute a minting key to every reader.
  Asymmetric signing lets you distribute a key that can only ever
  say "yes, this is genuine" — never "here, I made one."

> **→ Next:** If signing is the answer, what exactly is being signed — and what does the resulting token actually contain?

---

## 5. 💡 The Core Idea

**A JWT is three base64url-encoded segments — a header naming how it was signed, a payload of readable claims, and a signature over the first two — and the signature proves only that some key produced those exact bytes, which means every other property the verifier cares about must be checked separately and deliberately.**

**Visual required:** build-chain diagram.

```
 [THREE SEGMENTS, ──▶ [THE SIGNATURE ──▶ [SO VALIDATION IS ──▶ [AND THE ISSUER
  TWO OF THEM        MAKES THEM         AN ORDERED CHAIN,     CANNOT TAKE IT
  READABLE JSON]     UNFORGEABLE,        NOT ONE CHECK]         BACK]
   because           NOT SECRET]                                  because a
   base64url is       therefore the       so signature-valid       signed string
   an encoding,       only property       ≠ token-valid: alg,      is valid until
   not encryption     added is            key, exp, iss, aud       exp no matter
                      integrity — and     are separate             what changes
                      who holds the       necessary                server-side
                      signing key         conditions
                      decides who
                      can MINT
```

### Three Segments, Two of Them Readable JSON

Everything starts with the physical shape of the token, because most JWT mistakes are made by people who never looked at one. A JWT is `xxxxx.yyyyy.zzzzz` — three base64url strings joined by dots. Decode the first and you get the **header**: a small JSON object naming the signing algorithm (`alg`, e.g. `RS256`), the type (`typ: "JWT"`), and usually a key identifier (`kid`) telling the verifier which of the issuer's keys signed this one. Decode the second and you get the **payload**: the claims. Some are registered by RFC 7519 and carry defined meanings — `iss` (who issued it), `sub` (who it's about), `aud` (who it's *for*), `exp`/`nbf`/`iat` (validity window, in seconds since epoch), `jti` (a unique token ID) — and the rest are whatever the issuer added. The third segment is the signature, and it is the only part that isn't plain text. The load-bearing consequence: **base64url is an encoding, not encryption.** Paste any JWT into jwt.io and you will read every claim in it. A token containing a user's internal database ID, their email, and their plan tier is broadcasting all three to anyone who ever holds the token — including, often, your own access logs.

### The Signature Makes Them Unforgeable, Not Secret

Given that the payload is readable, the signature's job is narrow and precise: it guarantees that these exact bytes came from a holder of the signing key. The signing input is exactly `base64url(header) + "." + base64url(payload)` — note that it covers the *header too*, which is why an attacker cannot quietly flip `alg` without invalidating the signature, and why the classic attacks work by getting the verifier to accept a signature the attacker computed rather than by forging the original one. Two families of algorithm are in play, and choosing between them is not a question of cryptographic strength. **HMAC (HS256)** uses one shared secret for both signing and verifying — which means every party that can verify a token can also mint one. **Asymmetric (RS256, ES256)** signs with a private key and verifies with the corresponding public key, so verification confers no minting power at all and the public key can be published openly, typically at a JWKS endpoint like `/.well-known/jwks.json`. That distinction is the whole decision: the moment anyone other than the issuer verifies your tokens, symmetric signing hands them the ability to impersonate anyone.

### So Validation Is an Ordered Chain, Not One Check

Because the signature establishes only integrity of bytes, everything else the verifier believes about a token is a separate check it has to make. And the order matters, which is the part candidates almost always miss. First, **pin the algorithm** — decided by the verifier's configuration, never read from the token's header, because the header is attacker-controlled input. Second, **resolve the key**: look up `kid` against an allowlisted, cached JWKS, and never fetch a key from a URL the token names. Third, **verify the signature** with that pinned algorithm and that resolved key. Fourth, check `exp` and `nbf` with a small clock-skew leeway of around sixty seconds. Fifth, check `iss` and `aud` — this is what stops a perfectly valid token minted for the payments API from being replayed against the admin API, since both trust the same issuer and the same key. Only after all five does the verifier have an identity worth handing to authorization (23.1), where the claims are evaluated against a policy and a failure means `403` rather than `401`. Gate one decides which key material is even eligible, so a verifier that skips it has made gates two and three meaningless — that is precisely why "the signature verified" is not the same sentence as "the token is valid."

### And the Issuer Cannot Take It Back

The last consequence follows directly from what makes the first three attractive. A verifier that never contacts the issuer also never learns anything the issuer discovers later. Fire an employee, change a user's role, detect a stolen device — none of it touches a token already in the wild, because that token is a self-contained signed string and nothing about revoking a database row changes its signature. It stays valid until `exp`, full stop. Every mitigation is a deliberate reintroduction of exactly the statefulness JWTs were adopted to remove: keep access tokens short (5–15 minutes) and pair them with a rotating refresh token so the staleness window is bounded; maintain a `jti` denylist checked on every request, which restores instant revocation at the cost of the lookup you were avoiding; or store a token-version counter on the user record and reject tokens minted before the current version. There is no fourth option that keeps both properties — that tension is the honest answer to "how do you log someone out," and stating it unprompted is what separates a good interview answer from a memorized one.

### ✅ Checkpoint

1. Your team is debating what to put in the JWT payload. Someone argues that since the token is cryptographically signed and travels only over TLS, it is safe to include the user's internal account number and their support-tier flag. Explain what is and isn't protected here, and give a concrete way that data leaks even though every request is encrypted in transit and the signature is unbreakable.

   > 💡 *If you hesitate, re-read "Three Segments, Two of Them Readable JSON" — specifically the sentence about what base64url is, and the last sentence about where tokens end up.*

MODEL ANSWER — §5 Checkpoint 1 (what belongs in the payload)

WHAT IS PROTECTED
  Integrity and authenticity, by the signature. Nobody can alter a
  claim without detection, and the claims provably came from the
  issuer. That is the complete list.

WHAT IS NOT PROTECTED — AND WHY EACH MECHANISM FAILS
  Confidentiality. The payload is base64url — an encoding with no
  key. Anyone holding the token reads every claim.

  The signature never had confidentiality as a goal; it is a
  one-way keyed function over the bytes, not a wrapper around them.

  TLS DOES provide confidentiality — but only IN TRANSIT, between
  two endpoints. Its protection ends the moment the connection
  terminates. Before the request and after it, the token is
  plaintext at rest.

CONCRETE LEAK PATHS — NO ATTACKER REQUIRED
  1. Access logs. The gateway/proxy logs the request; the APM agent
     captures headers on the trace; the error tracker snapshots
     request context on every 500. Retained 30–90 days, replicated,
     shipped to a third-party observability vendor, and searchable
     by every engineer with log access — none of whom were granted
     permission to see account numbers.
  2. Client-side at rest. The token sits in localStorage on the
     user's disk, readable by any XSS and by anyone with the device.
  3. Support workflows. A customer sends a HAR file or screen
     recording; the account number is now in a support ticket.
  4. Third parties. Any partner or downstream service you hand the
     token to reads every claim in it.
  5. URLs. If the token ever appears in a query string, it lands in
     browser history and Referer headers sent to other origins.

THE ONE-LINE VERSION
  Signing makes claims unforgeable, not private, and TLS only hides
  them while they are moving. Put identifying data in a payload and
  you have not created an attack — you have quietly pulled your
  entire logging pipeline into compliance scope.

2. Explain why choosing between HS256 and RS256 is a decision about *who is allowed to mint tokens* rather than a decision about cryptographic strength — and then use that to explain why the RS256→HS256 confusion attack is possible at all. Trace the link from "The Signature Makes Them Unforgeable, Not Secret" into "So Validation Is an Ordered Chain."

   > 💡 *If you hesitate, re-read the second and third concept blocks together — the answer hinges on what the verifier holds in each scheme, and on which gate decides what that held material is used for.*

MODEL ANSWER — §5 Checkpoint 2 (HS256 vs RS256 as a minting decision)

THE DECISION IS ABOUT MINTING AUTHORITY
  HS256 uses one shared secret for both signing and verifying. To
  give a service the ability to VERIFY, you must give it the secret
  — which is also the ability to MINT. The two capabilities are
  fused into one key and cannot be separated.

  RS256 splits them. The private key mints; the public key only
  verifies. You can hand verification capability to anyone —
  including a third party you do not trust — and it confers no
  power to produce a token.

  Both algorithms are cryptographically sound. Neither is "stronger."
  The question is only whether your trust topology has more than one
  party that needs to verify. The moment it does, HS256 hands every
  one of them impersonation capability.

WHY THAT MAKES THE CONFUSION ATTACK POSSIBLE
  Under RS256 the verifier holds the public key — deliberately
  published, so the attacker holds the identical bytes.

  A verifier that reads `alg` from the token's header lets the
  attacker choose which algorithm runs against that key material.
  Set `alg: HS256`, and the verifier feeds the RSA public key into
  the HMAC path as a shared secret. The attacker, holding the same
  bytes, computes the same HMAC. It matches. They can now mint any
  identity.

  The chain of causation runs directly through the build chain:
  RS256's central benefit is that the verification key is safe to
  publish → publishing it means the attacker has it → if the token
  can redefine that key as an HMAC secret, the benefit inverts into
  the vulnerability.

WHY ROTATION DOESN'T FIX IT, AND WHAT DOES
  The new public key is also public. Key hygiene is irrelevant.
  The only fix is pinning the algorithm out of band —
  `algorithms=["RS256"]` — so the token never influences how it is
  verified. That is gate 1, and it runs before the signature is
  even examined.

> **→ Next:** You know the pieces and the order. What actually happens, byte by byte, when a token is minted and then checked?

---

## 6. ⚙️ How It Actually Works

**Happy path — one request, end to end:**

1. The user authenticates (password, OAuth2 code exchange — 23.2, whatever the mechanism). The auth server builds a header, `{"alg":"RS256","typ":"JWT","kid":"2026-08"}`, and a payload, `{"iss":"https://auth.acme.com","sub":"user_1042","aud":"payments-api","exp":1786483200,"iat":1786482300,"jti":"a3f9…"}`.
2. It base64url-encodes each, joins them with a dot to form the **signing input**, signs that byte string with its RSA private key, base64url-encodes the signature, and appends it after a second dot. The result is `header.payload.signature` — typically 300–800 bytes.
3. The client stores the token and sends it on every request as `Authorization: Bearer <jwt>`. Nothing binds the token to this client: it is a pure bearer credential, so possession is the entire proof.
4. The resource server splits on dots, decodes the header, and runs the gate chain: pin `RS256` from its own config; look up `kid: "2026-08"` in its cached copy of the issuer's JWKS (refreshed periodically, not per request); verify the signature over the first two segments; check `exp`/`nbf` against the current time with ~60s leeway; check `iss` matches the expected issuer and `aud` equals `payments-api`.
5. All gates pass, so a verified identity (`sub: user_1042` plus claims) goes into the request context, and authorization takes over from there (23.1). A failure at any gate is a `401` — no identity was ever established. A failure at the authorization step is a `403`.

> 🗺️ **Mental model — the wax-sealed public notice.** A JWT is a public notice with the issuer's wax seal pressed into it. Anyone can walk up and read the whole notice — that's the point, it's a notice. What the seal provides is that no one can alter a word without visibly breaking it, and anyone who knows what the issuer's seal looks like can check it themselves without travelling to the issuer's office. *Where it breaks down:* a wax seal is checked by a human who also notices the notice is three years old, addressed to a different town, and stamped by a seal design the office stopped using. Software notices none of that unless you write the check — the seal verifying is one gate, and `exp`, `aud`, and the key's identity are gates that don't exist until you add them.

> 🗺️ **Mental model — the concert wristband.** Once the box office prints and clamps a wristband on you, every gate inside the venue can verify it independently, instantly, with no radio call back to the box office. That independence is exactly the JWT's payoff. *Where it breaks down:* the box office cannot un-print a wristband already on someone's wrist — which is the revocation problem exactly — and unlike a physical wristband, a bearer token can be copied and used from two continents at once, because nothing binds it to a wearer. That's why proof-of-possession schemes (mTLS-bound tokens, DPoP) exist, and why "short lifetime" is the standard answer instead of "revoke it."

**Failure & edge cases:**

- **`alg: none`.** The spec defines an "unsecured JWT" with `alg: "none"` and an empty signature. Libraries that dispatch on the header's `alg` will happily take that path: the attacker rewrites the payload to `sub: admin`, sets `alg` to `none`, drops the signature, and the verifier returns valid. This is the purest form of the whole pitfall class — the token told the verifier how to verify it.
- **RS256 → HS256 algorithm confusion.** More subtle and more dangerous. The verifier is configured with the issuer's RSA *public* key, which is public by design. The attacker rewrites the header to `alg: HS256` and computes an HMAC over their forged token *using that public key as the shared secret*. A verifier that dispatches on the header now calls the HMAC path with the same key bytes it would have used for RSA verification — and the HMAC matches, because the attacker had the key. The attacker can now mint any identity they like. Rotating the key pair does not help: the new public key is also public. The only fix is pinning the algorithm out of band.
- **`kid` and `jku` injection.** `kid` is attacker-controlled input used to *locate* a key. If it is interpolated into a file path (`keys/{kid}.pem`) or a SQL query, it becomes path traversal or injection. Worse, the JOSE spec allows `jku` and `x5u` headers naming a *URL* to fetch the key from — honour those and the attacker simply hosts their own key. Allowlist `kid` values; never fetch key material from a location the token specifies.
- **Missing `aud` (and `iss`) check.** Every service behind one identity provider trusts the same signing key. Without an audience check, a token legitimately issued for the low-privilege analytics API verifies perfectly against the admin API. This is a confused-deputy failure that a signature check cannot possibly catch, because the signature is genuinely valid. The OIDC version of the same mistake: sending an **ID token** (whose `aud` is a client_id, meant to tell the client who the user is) to a backend as if it were an access token.
- **No revocation.** Logout that only deletes the client's copy changes nothing — a copy of the token keeps working until `exp`. "Sign out of all devices," employee termination, and stolen-token response all require reintroducing server-side state (`jti` denylist, token-version claim) or living with the window (5–15 min TTL + refresh rotation).
- **Storage and exfiltration.** In `localStorage`, any XSS on the page reads the token directly. In an `HttpOnly; Secure; SameSite=Lax` cookie, XSS cannot read it — but you have taken on CSRF and must handle it. And a token placed in a URL query string ends up in server logs, browser history, and `Referer` headers sent to third parties.
- **Payload bloat and clock skew.** Stuffing a permission list into the payload grows every single request; many servers cap total request headers around 8 KB, so this surfaces as a `431`/`400`, not an auth error. And `exp` comparisons need a small leeway (~60s) for clock drift between issuer and verifier — but leeway measured in minutes quietly extends every token's real lifetime.

**Anatomy — what the signature actually covers:**

```
   eyJhbGciOiJSUzI1NiIsImtpZCI6IjIwMjYtMDgifQ  .  eyJzdWIiOiJ1c2VyXzEwNDIiLC4uLn0  .  SflKxwRJ…
   └──────────── HEADER (base64url) ────────────┘  └───── PAYLOAD (base64url) ─────┘  └ SIGNATURE ┘
                        │                                        │                          │
                        ▼                                        ▼                          ▼
        {"alg":"RS256",                          {"iss":"https://auth.acme.com",   RSA-SHA256 over
         "typ":"JWT",                             "sub":"user_1042",               the bytes to the
         "kid":"2026-08"}                         "aud":"payments-api",            LEFT of this dot
                                                  "exp":1786483200,
        ⚠ ATTACKER-CONTROLLED.                    "iat":1786482300,                signing input =
          Read `kid` only to LOOK UP              "jti":"a3f9…"}                     b64(header)
          an allowlisted key. NEVER                                                  + "."
          read `alg` to decide how                ⚠ READABLE BY ANYONE.               + b64(payload)
          to verify.                                base64url ≠ encryption.
                                                                                    ⚠ covers the
   ├──────────────── SIGNING INPUT (both segments + the dot) ─────────────┤            HEADER too —
                                                                                        which is why
   Change ONE character anywhere left of the second dot → signature fails.              alg-confusion
   Change the signature → fails. Change nothing but re-sign with YOUR OWN key            attacks re-sign
   → fails, UNLESS you can make the verifier use a key you control (that is               rather than
   exactly what alg-confusion and kid-injection achieve).                                  edit in place
```

**Mechanism flow, end to end:**

```
① MINT                    ② CARRY                ③ VALIDATE (ordered gates)          ④ USE
  build header+payload      Authorization:         ┌─ 1 pin alg    ← from CONFIG       verified
  sign(signing_input,  ──▶   Bearer <jwt>    ──▶   ├─ 2 resolve key ← allowlisted kid   identity
   private_key)              (pure bearer)         ├─ 3 verify signature                 in ctx
  append signature                                 ├─ 4 exp / nbf  (±60s skew)             │
                                                   └─ 5 iss / aud                          ▼
                                                        │                             authorization
                                                        ▼                              policy (23.1)
                                          ANY gate fails → 401                              │
                                          (identity never established)                       ▼
                                                                                     denied → 403
                                                                                     allowed → 2xx
```

### ✅ Checkpoint

1. Walk through exactly which bytes the signature covers, and use that to explain three separate attacker attempts and their outcomes: (a) editing `"sub"` in the payload and leaving the signature alone, (b) editing the payload and re-signing with a key the attacker generated, and (c) editing the payload and re-signing in a way that actually succeeds. What has to be true of the *verifier* for case (c) to work?

   > 💡 *If you hesitate, re-read the anatomy diagram — specifically the "signing input" bracket and the note about why alg-confusion attacks re-sign rather than edit in place.*

MODEL ANSWER — §6 Checkpoint 1 (what the signature covers, three attacks)

WHAT THE SIGNATURE COVERS
  Exactly: base64url(header) + "." + base64url(payload) — every byte
  to the left of the second dot, INCLUDING the header. The signature
  segment itself is not covered.

(a) EDIT THE PAYLOAD, LEAVE THE SIGNATURE
    The signature encodes a digest of the ORIGINAL bytes. The
    verifier computes a fresh digest over the bytes now present —
    which are different — and compares. Mismatch.
    FAILURE REASON: the signature does not match the content.
    → 401

(b) EDIT THE PAYLOAD, RE-SIGN WITH THE ATTACKER'S OWN KEY PAIR
    The token is now internally consistent: that signature IS a
    valid signature over exactly these bytes. But the verifier does
    not use the attacker's public key — it uses the ISSUER'S, from
    its cached JWKS. The math doesn't hold across a different key
    pair.
    FAILURE REASON: the signature matches the content but was
    produced by the wrong key.
    → 401

(c) EDIT THE PAYLOAD AND RE-SIGN SUCCESSFULLY
    The attacker sets alg: HS256 and computes
    HMAC-SHA256(signing_input, rsa_public_key_bytes), having
    downloaded the public key from the JWKS endpoint.

    The verifier reads alg from the header, dispatches to the HMAC
    path, and passes it the only key material it has for this
    issuer — the RSA public key. It computes the identical HMAC
    over the identical input. Match. Valid.
    → 200, as any identity the attacker chose

WHAT MUST BE TRUE OF THE VERIFIER FOR (c)
  It must read `alg` from the token's header and dispatch on it,
  rather than pinning the expected algorithm in its own config.

  Note what does NOT happen: the attacker never supplies a key.
  The verifier uses its own key throughout. The attack changes the
  ROLE that key plays — public verification key vs. HMAC shared
  secret — by changing one attacker-controlled string.

2. A service verifies RS256 tokens correctly — pinned algorithm, allowlisted `kid`, valid signature, unexpired. It has no `aud` check. Explain concretely what an attacker with a legitimately-issued token can now do, why the signature check is completely powerless to stop it, and why this is a different class of bug from algorithm confusion.

   > 💡 *If you hesitate, re-read "Missing `aud` (and `iss`) check" — the key point is that in this attack nothing about the token is forged.*

MODEL ANSWER — §6 Checkpoint 2 (missing aud check)

THE PRECONDITION
  Both the analytics API and the payments API verify against the
  SAME issuer — one IdP, one signing key, one JWKS. This is the
  normal architecture, and it is what lets a token minted for one
  pass the signature check at the other.

WHAT THE ATTACKER DOES
  Nothing to the token. They hold a legitimately issued token with
  aud: "analytics-api" — obtained honestly, it's their own token —
  and simply send it to the payments API instead. Every byte is
  exactly as the issuer minted it. aud still reads "analytics-api".
  The payments API just never looks at it.

WHY THE SIGNATURE IS POWERLESS
  The signature attests to one thing: the issuer produced these
  exact bytes. It genuinely protects the aud claim from tampering —
  but protecting a value is not the same as acting on it. The
  signature can guarantee aud says "analytics-api"; it has no
  opinion about whether the service reading it is analytics-api.
  Nothing was forged, so an integrity check has nothing to detect.

WHY IT IS A DIFFERENT CLASS OF BUG
  Algorithm confusion → "is this token real?" answered WRONG.
    An authentication/integrity failure. A forgery got in.
  Missing aud     → "is this token FOR ME?" never asked.
    An authorization/scope failure. A genuine token was used
    outside the scope it was issued for.

  The proof they're different classes: perfect cryptography does
  not help. ES512, HSM-held keys, flawless rotation, algorithm
  pinned — still fully vulnerable, because recipient scope is not
  a cryptographic property.

  This is 23.1's shape again: a valid credential used against
  something it was never scoped to — IDOR/BOLA, one layer down,
  at the token rather than the resource.

> **→ Next:** You can mint and validate them safely. In a live design, when do you actually reach for a JWT — and what does that choice cost you?

---

## 7. ⚖️ The Decision — When, and What It Costs

The baseline isn't a judgment call: if you use JWTs, you pin the algorithm, allowlist the key, and check `exp`, `iss`, and `aud`. Skipping any of those isn't a trade-off, it's a bug. The actual decisions are three: whether a self-contained token is the right shape at all, which signing family to use, and what you allow into the payload.

**Many independent verifiers, and a bounded staleness window is acceptable.** This is the case JWTs exist for. Twenty services, three regions, a mobile client, a partner API — each one verifies locally against a cached JWKS and never touches the auth service on the hot path. You get regional independence, no shared bottleneck, and no fleet-wide auth outage when the identity store has a bad day. What you accept in exchange is that revocation is not instantaneous, which you bound with short access-token lifetimes rather than eliminate.

**Instant revocation is a hard requirement, or the contents are sensitive.** Then an opaque token with server-side introspection is the honest answer, and reaching for JWTs anyway means quietly reimplementing the session store you were avoiding. A compliance rule that terminating an employee must cut access *now*, a system where token theft is high-impact, or a design that already runs a session store the lookup would hit regardless — in all three the JWT's central payoff has been cancelled and you're paying its central cost for nothing. The middle path exists: JWTs with a `jti` denylist consulted on every request, which is worth it only when the denylist is small and hot (a few thousand revoked IDs in Redis) rather than a full session lookup in disguise.

**Anyone other than the issuer verifies your tokens.** Then the signing family is decided for you: asymmetric, RS256 or ES256. Symmetric HS256 is legitimate exactly when one service both issues and verifies — a monolith talking to itself, where sharing a secret with yourself costs nothing. The moment a second party verifies, HS256 hands them minting power, and "our internal services are trusted" stops being true the first time one of them is compromised or a partner is added.

**And what goes in the payload.** Identity plus coarse, slow-changing claims. Fine-grained permissions in the token look efficient and are 23.1's revocation problem in concrete form — frozen at issuance, valid until expiry, no matter what changed server-side. Nothing sensitive, because it is readable. Nothing large, because every request pays the bytes.

**Decision tree:**

```
              Must a token stop working the instant it is revoked
              (compliance, high-value ops, immediate termination)?
                                   │
                    ┌─────yes──────┴──────no, a bounded window is OK───┐
                    ▼                                                   ▼
     Is the revoked set small and hot                        Do parties OTHER than the
     (a few thousand jti in Redis)?                          issuer need to verify?
              │                                                        │
       ┌─no───┴───yes──┐                                    ┌──no──────┴──────yes─────┐
       ▼               ▼                                    ▼                          ▼
  Opaque token +   JWT + jti denylist               HS256 is fine.            RS256 / ES256 +
  introspection.   checked per request.             One service issues        published JWKS,
  You wanted a     Keeps local verification         AND verifies; the         `kid`-based rotation.
  session store —  for everything else, pays        shared secret never       Verifying must not
  build one.       one small lookup.                leaves the boundary.      confer minting power.
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Verification is local** — any service in any region confirms identity with a signature check and no round trip, so identity stops being a shared synchronous dependency | The issuer permanently loses reach into tokens already in the wild: a fired employee, a changed role, or a stolen token stays valid until `exp`, and every mitigation reintroduces exactly the server-side state you removed |
| **Asymmetric signing lets you publish the verification key** to anyone, including third parties, without granting them the ability to mint | You now own key-rotation infrastructure — JWKS endpoints, `kid` tagging, overlapping key validity windows, cache TTLs — and a botched rotation is a fleet-wide authentication outage rather than a localized bug |
| **Claims travel with the request**, so a service knows who is calling without a lookup and can act on `sub`, `tenant`, or scope immediately | Every claim costs bytes on every single request forever; servers commonly cap total headers around 8 KB, so a bloated token surfaces as a `431`/`400` that looks nothing like an auth problem while you debug it |
| **A mature, standardized format** with well-tested libraries in every language, so you are not designing a token format yourself | The standard's flexibility — `alg`, `kid`, `jku` all sitting in an attacker-controlled header — is itself the attack surface, so your safety depends on how you configured the library rather than on the format being sound |

### In production

| System | How it applies | The nuance |
|--------|----------------|------------|
| **Auth0 / Okta** | Issue RS256 JWTs by default and publish verification keys at `/.well-known/jwks.json`, with `kid`-tagged rotation and overlapping key validity | The asymmetric default is deliberate: customer APIs verify these tokens, and symmetric signing would hand every customer API the ability to mint tokens for every other one |
| **AWS Cognito** | Issues separate RS256 ID and access tokens, defaulting to 1 h access lifetime with refresh tokens valid up to 30 days | Tokens carry a `token_use` claim (`id` vs `access`) and you must check it — a verifier that only checks the signature and `exp` will accept an ID token where an access token was required, which is the OIDC form of the missing-audience bug |
| **Google / OIDC ID tokens** | ID token's `aud` is the *client_id* of the application, not an API — it exists to tell the client which user just signed in | Forwarding an ID token to a backend as a bearer credential is one of the most common OIDC misuses in production; the backend should be issued its own access token with itself as the audience |
| **GitHub Actions OIDC** | Workflows request a short-lived JWT (minutes) and exchange it with AWS/GCP for cloud credentials, removing long-lived secrets from CI entirely | The cloud side must pin the `sub` claim to a specific repo and ref — a trust policy that only checks the issuer lets *any* repository in the organization assume the role, which has caused real incidents |
| **Kubernetes service account tokens** | Projected, bound tokens carry an explicit `aud`, a bounded `exp`, and a binding to the pod's lifetime, replacing the legacy never-expiring secret-mounted tokens | The migration away from non-expiring tokens happened specifically because of the no-revocation property: a leaked legacy token was valid forever, and there was nothing to expire |

### ✅ Checkpoint

1. You are designing auth for an internal banking operations tool: five services, roughly 400 employees, and a hard compliance requirement that revoking an employee's access takes effect immediately — not within fifteen minutes. An engineer proposes RS256 JWTs with a five-minute lifetime, arguing that five minutes is "basically immediate." Using the decision tree, say what you would actually build, name specifically what you are giving up relative to plain JWTs, and explain why the five-minute argument does or doesn't survive the requirement as written.

   > 💡 *If you hesitate, re-read the second boundary condition and the first branch of the decision tree — the question is whether a bounded window satisfies a requirement phrased as "immediately," and what the small-hot-denylist middle path buys you.*

MODEL ANSWER — §7 Checkpoint (banking ops tool, immediate revocation)

WHAT I'D BUILD
  RS256 JWTs with a jti claim, plus a Redis denylist checked on
  every request. Short access-token lifetime (15 min) is still
  worth keeping as defence in depth, but it is not the control —
  the denylist is.

  The denylist holds only tokens revoked BEFORE their natural
  expiry, with each entry TTL'd to the token's remaining lifetime
  so it deletes itself. With 400 employees it is normally empty
  and occasionally holds a handful of entries. It never grows.
  That is what keeps this branch cheap.

WHAT I'M GIVING UP
  1. Local, self-contained verification — the reason JWTs were
     chosen. Identity is a shared synchronous dependency on the
     hot path again. Not all the way back to session lookups (the
     denylist is tiny and memory-resident), but partially undone.
  2. A new critical-path dependency: Redis is now in the auth
     path of every request. Replicated with automatic failover,
     and I FAIL CLOSED — because fail-open makes the control
     bypassable by DoSing Redis, and a control that turns off
     when a component is unavailable is not a control.
  3. Latency on every authorization decision.

DOES THE FIVE-MINUTE ARGUMENT SURVIVE? NO — THREE REASONS
  1. It doesn't even deliver five minutes. The refresh token is
     still valid, so the employee mints fresh access tokens for
     as long as the refresh lifetime allows. Bounding the access
     token requires revoking the refresh token, which requires
     server-side state — the exact thing the proposal avoids.
  2. The window opens at the worst possible moment. You revoke
     BECAUSE something happened; that is when the person is most
     motivated and most attentive.
  3. "Immediately" is a written compliance control. An auditor
     asks you to demonstrate that access ends at revocation. The
     honest answer under this proposal is "up to five minutes
     later," which fails the control as written. If five minutes
     is truly acceptable, get the requirement changed in writing
     — don't reinterpret it.

> **→ Next:** Can you defend this under interview pressure — and hold up when the interviewer pushes on the validation code rather than the design?

---

## 8. 🎯 In the Interview

**When an interviewer asks / says:**
- "How do your services authenticate requests from each other?"
- "Walk me through what's actually inside a JWT and how the server verifies it."
- "How would you log a user out, or revoke access if a token is stolen?"
- "What could go wrong with the way you're validating those tokens?"

**What you say / do:**
This lands in the high-level design the moment you say "stateless services" — the interviewer will want to know how identity travels without a session store — and it comes back hard in the deep dive from two directions: logout/revocation, and a security probe on the validation itself. Deliver it in a fixed order. Name the choice (RS256 JWT, 15-minute access token, rotating refresh). Give the mechanism reason (each service verifies locally against a cached JWKS, so identity costs no network hop on the hot path). Price it without being asked (you cannot revoke before `exp`, so a stolen token is good for its full lifetime — that's *why* fifteen minutes). Name the switch condition (if instant revocation becomes a hard requirement, add a `jti` denylist or move to opaque tokens and accept the lookup). If the interviewer probes validation rather than design, drop straight into algorithm pinning — it is the highest-signal thing you can say about JWTs.

**The trade-off statement (memorize this pattern):**
> "I'd use RS256 JWTs issued by the auth service, and every downstream service verifies locally against the issuer's JWKS, cached and keyed by `kid`. That's the whole reason to pick JWTs over opaque tokens — the payments service confirms identity with a signature check instead of a network call to the auth service on every request, so identity isn't a shared synchronous dependency across the fleet. Validation is more than the signature, though: I pin `RS256` in the verifier's config rather than reading `alg` from the token's header, I allowlist the `kid` against the cached key set, and I check `exp` with about sixty seconds of skew leeway plus `iss` and `aud` — so an access token minted for the analytics API can't be replayed against the admin API, which a signature check alone would never catch because that signature is genuinely valid. The cost I'm accepting is that nothing server-side can cancel a token already in the wild: it's valid until it expires, no matter what changes. That's why access tokens are fifteen minutes with a rotating refresh token, and it means a stolen token is usable for up to fifteen minutes. I'd change that if immediate revocation became a hard requirement — then I'd add a `jti` denylist in Redis checked on every request, which restores instant revocation at the cost of one small lookup, or go to opaque tokens with introspection if the revoked set were large enough that the denylist stopped being cheap."

**A second trade-off variant — the "is your validation actually safe?" pushback:**
> "The single most important line in the verifier is the one that specifies the algorithm out of band. If the code reads `alg` from the token's header and dispatches on it, there are two ways in. The attacker can set `alg` to `none`, strip the signature, and get accepted as an unsecured token. Or — more dangerously with RS256 — they can switch the header to `HS256` and HMAC their forged token using the issuer's *public* key as the shared secret. A verifier that dispatches on the header hands that same public key to the HMAC path, and it matches, because the attacker had the key: it's published. At that point they can mint any identity they want. Rotating the key pair does not fix that, because the new public key is public too. The fix is that the verifier is configured to accept exactly RS256 with exactly this key set and rejects anything else before it looks at the signature at all. Everything else — allowlisting `kid` so it can't be turned into a path traversal, refusing to honour `jku` — is the same principle: the token never gets to influence how it is verified."

### ⚠️ Traps

- ❌ **Trap:** "JWTs are encrypted, so it's fine to put internal IDs and account details in the payload — it's all going over TLS anyway."
  ✅ **Reality:** base64url is an encoding with no key and no secrecy — the payload is readable by anyone who ever holds the token, which includes the client, any XSS on the page, your access logs, and any proxy that logs headers. TLS protects the token in transit; it does nothing once the token is at rest on the client or in a log line. Hiding contents requires JWE, which is a different thing you are almost certainly not using.

- ❌ **Trap:** "The signature verified, so the token is valid."
  ✅ **Reality:** The signature proves only that some key produced these exact bytes. It cannot tell you the token isn't expired, wasn't minted for a completely different service, or wasn't verified with a key the attacker chose. `exp`, `iss`, `aud`, and algorithm pinning are four separate necessary conditions — and the audience check in particular stops an attack where nothing about the token is forged at all.

- ❌ **Trap:** "Logout is easy — we delete the token from localStorage."
  ✅ **Reality:** That deletes one copy on one device and changes nothing server-side. Any copy made beforehand keeps working until `exp`. Real logout means bounding the window with short lifetimes and refresh rotation, or reintroducing state with a `jti` denylist or a token-version claim — and "sign out of all devices" is impossible without one of those.

- ❌ **Trap:** "We read the `alg` from the header — that's what the field is for."
  ✅ **Reality:** That field is attacker-controlled input, and trusting it is the `alg: none` and RS256→HS256 confusion vulnerability class in one line. RFC 8725's headline recommendation is to determine the algorithm out of band. The verifier decides how it verifies; the token only supplies data to be verified.

> **→ Next:** Can you combine what you've learned across sections, not just recall each one?

---

## 9. 🧪 Mastery Gate

> *Synthesis only. Each question must require combining two or more sections.*

1. **(§5 + §6 + 23.1)** A team moves their permission checks into the JWT: the payload now carries a full `permissions` array, and services authorize directly off it with no lookup. They point out — correctly — that this removes a database call from every request. Using the build chain from §5 and the revocation discussion from §6, explain exactly what has been traded away, then connect it to 23.1's rule about where authorization must be enforced: is this design failing at authentication, at authorization, or at both, and what specifically breaks the first time a permission is revoked?

2. **(§7 + §8, applied to a system not mentioned elsewhere in this doc)** You are designing authentication for a fleet of 50,000 field IoT sensors that report to an ingestion API over intermittent cellular connectivity — a device may be offline for hours and reconnect in bursts. Devices are physically accessible and occasionally stolen, and a stolen device must be cut off. Decide the token type, signing family, and lifetime, and justify each against the decision tree in §7. Then state, in the §8 delivery order, what you would say if an interviewer objected that short-lived tokens are impractical for devices that are frequently offline.

3. **(§4 + §6 + §7)** An interviewer asks you to design "sign out of all devices" for an existing JWT-based system with fifteen-minute access tokens and thirty-day refresh tokens. Walk through what happens to each token type when the user clicks it, name precisely which server-side state you are forced to reintroduce and where it is checked, and explain why §4's original motivation for adopting JWTs is partially — but only partially — undone by your answer.

### Mastery criteria — tick only what you can demonstrate on demand

- [ ] Can draw the three JWT segments from memory, name what's in each, and state exactly which bytes the signature covers
- [ ] Can explain why base64url encoding is not encryption, and decide correctly what may and may not go in a payload
- [ ] Can walk the full validation order — pin algorithm → resolve key → verify signature → `exp`/`nbf` → `iss`/`aud` → claims — and say what an attacker gains from skipping each one
- [ ] Can explain the RS256→HS256 algorithm confusion attack end to end, including why the public key is what makes it work and why key rotation doesn't fix it
- [ ] Can choose between HS256 and RS256/ES256 for a given topology and justify it as a decision about who may mint, not about cryptographic strength
- [ ] Can design revocation for a JWT system and state precisely what server-side state it reintroduces and where it is checked

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 10. 🔗 Connections & Sources

**Builds on:** **3.4 JWT as Stateless Session Token**, which established *why* a self-contained token is worth having — this subtopic is the inside of the box 3.4 handed you sealed, and the revocation cost 3.4 named in the abstract becomes concrete here as `exp`, `jti` denylists, and refresh rotation. **23.1 Authentication vs. Authorization**, which supplies the rule that makes §6's gate chain land correctly: every validation gate failing is a `401` because no identity was established, while a claim failing a policy is a `403`. **23.2 OAuth2**, which is the flow that actually issues these tokens and defines the access/refresh/ID token distinction that §6's audience bug depends on.

**Enables:** **23.4 RBAC — Roles, Permissions, Policy Enforcement Points**, where the question of whether role claims belong in the token payload gets its full treatment — §5 and §7 here give you the staleness argument it builds on. **23.6 TLS/SSL — Handshake, Certificates, mTLS**, which supplies both the transport that keeps a bearer token from being read off the wire and the proof-of-possession mechanism (mTLS-bound tokens) that answers §6's "a bearer token can be used from two continents at once." **23.7 Encryption at Rest / 23.9 Secrets Management**, which answer where the signing private key actually lives. **11.7 API Gateway Patterns**, the concrete place JWT validation is usually terminated in a real architecture.

**Tension with:** **3.2 Session Management Approaches** directly — the statefulness JWTs were adopted to eliminate is precisely the statefulness revocation requires back, and a `jti` denylist is a session store wearing a smaller hat. Also **3.7 Horizontal Scaling of Stateless Tiers**: the moment you add a per-request denylist lookup for instant revocation, the identity path stops being purely local again and reacquires a shared dependency — the same tension 23.1 flagged between JWT-embedded claims and live authorization lookups, now visible at the token layer instead of the policy layer.

### 📚 Further reading

- [ ] **RFC 8725 — JSON Web Token Best Current Practices** — https://datatracker.ietf.org/doc/html/rfc8725 — the single highest-yield document here; §3.1 ("Perform Algorithm Verification") is the formal statement of the pinning rule that defeats both `alg: none` and RS256→HS256 confusion
- [ ] **RFC 7519 — JSON Web Token** — https://datatracker.ietf.org/doc/html/rfc7519 — the format itself; read §4.1 on registered claims (`iss`, `sub`, `aud`, `exp`, `nbf`, `iat`, `jti`) and skip the rest
- [ ] **RFC 7515 — JSON Web Signature** — https://datatracker.ietf.org/doc/html/rfc7515 — the precise definition of the signing input (`base64url(header) + "." + base64url(payload)`) used in §6's anatomy diagram
- [ ] **Auth0 — "Critical Vulnerabilities in JSON Web Token Libraries"** — https://auth0.com/blog/critical-vulnerabilities-in-json-web-token-libraries/ — the 2015 disclosure of `alg: none` and algorithm confusion, with concrete verifier code; read this before the RFC if you learn better from the attack than the rule
- [ ] **OWASP — JSON Web Token Cheat Sheet** — https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html — the practitioner checklist covering storage, revocation, and the sidejacking/token-theft cases from §6
- [ ] **jwt.io debugger** — https://jwt.io — decode a real token from your own system and read its payload; do this once and "base64url is not encryption" stops being a fact you memorized

---

## 11. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
