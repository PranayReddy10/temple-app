# Product Roadmap — Working Name: "Temple Passport"

> **The product name is not finalised.** It is never hard-coded. The brand name,
> tagline and domain all come from `config/brand.php`, driven by `.env`
> (`BRAND_NAME`, `BRAND_TAGLINE`). Renaming the product later is a one-line
> `.env` change, not a find-and-replace across the codebase.

A digital pilgrimage companion for India: discover temples, plan yatras,
collect digital stamps, preserve pilgrimage memories.

**Product loop:** Discover → Learn → Plan → Visit → Check-in → Collect Stamp →
Save Photo → Share → Plan the next Yatra.

---

## Repository split

| Repo | Contains |
| --- | --- |
| `temple-website` | Laravel 12 REST API + Filament admin + temple portal + public web |
| `temple-app` | Flutter — Android, iOS and Flutter Web from one codebase |

The Flutter app talks to this repo only through versioned REST endpoints
(`/api/v1/...`). Nothing in the app depends on Laravel specifics, so the
backend can migrate to Node/VPS in a later phase without an app release.

## Why Laravel 12 + MySQL

Hosting is **shared Hostinger**, which runs PHP 8.2+ and MySQL 8 on every plan
but cannot run persistent Node.js processes (that needs a VPS). The project
plan lists Laravel as an accepted backend, so we take the option that deploys
to the hosting we actually have.

Laravel **12**, not 11: the 11.x line is past security support and carries two
unpatched advisories (CRLF injection in the default email rule, signed-URL path
confusion) that were fixed only in 12.x. Laravel 12 needs PHP 8.2, which shared
Hostinger has; Laravel 13 needs PHP 8.3, which is less reliably available.

## Storage

Temple photos live in **DigitalOcean Spaces**, not on the web host. Spaces is
S3-compatible, so Laravel's own `s3` driver reaches it with no
DigitalOcean-specific package, and images are delivered from its CDN.

This matters for the hosting plan: photo storage was the thing that would
otherwise have forced a move off shared Hostinger at slice 2. With media
elsewhere, shared hosting carries the project comfortably through slice 4.

`MEDIA_DISK` defaults to the local `public` disk, so a fresh clone, the test
suite and CI all run with no DigitalOcean account. Only production sets it to
`spaces`. Each photo row records the disk it was written to, so photos uploaded
before the switch keep resolving afterwards.

---

## Three audiences, three logins

The platform serves three groups with almost nothing in common. Each gets its
own entry point.

| Audience | Entry point | Authentication | Stored in |
| --- | --- | --- | --- |
| **Staff** — super admin, editors | `/admin` | Session (Filament) | `users` |
| **Temple authority** — trust, temple office | `/temple` | Session (Filament) | `users`, scoped to their temples |
| **Devotees** — app and web users | Flutter app, public web | API token (Sanctum) | `devotees` (separate table) |

**Staff and temple authorities share the `users` table.** Both are small,
known populations who manage content through a Filament panel. A
`temple_user` pivot decides which temples an authority may touch, and every
query in that panel is scoped through it. A temple admin who can edit a
temple they do not own is the failure mode to design against.

**Devotees get their own table, deliberately.** Three reasons:

1. **Scale.** Devotees are expected in the millions; staff in the hundreds.
2. **Different auth.** Devotees will sign in with phone OTP or a social
   provider; staff use passwords and, later, two-factor.
3. **Blast radius.** If both lived in one table, a single mass-assignment
   mistake could give a devotee account a staff role. Separate tables make
   that class of bug impossible rather than merely unlikely.

They also share almost no columns: a devotee has a Passport, stamps, visits
and memories; a staff user has a role and an audit trail.

---

## Delivery slices

Features ship one slice at a time. Each slice is independently testable and
leaves the system in a working state. **Nothing is built all at once.**

### Phase 1 — Backend and admin foundation

| # | Slice | Scope | Status |
| --- | --- | --- | --- |
| 1 | **Admin auth + Temple CRUD** | Admin login, roles, temples table, deities, categories, states/districts, draft→published workflow, seed data | ✅ **Done** |
| 2 | Temple media + timings | Photo gallery upload, image processing, opening/darshan/aarti timings, special-day and closure overrides | ⬜ Next |
| 3 | Puja / Seva + facilities | Published pujas with time, duration, eligibility, fee, official booking route; visitor rules and facilities | ⬜ |
| 4 | Public REST API v1 | Read endpoints for the Flutter app: search, filter, nearby, temple detail, deity and category listings | ⬜ |
| 5 | **Flutter app shell** | Temple design system tinted per weekday deity, temple-door transitions, 5-tab navigation, API client with offline fallback | ✅ **Done** |
| 6 | **Explorer + temple profile** | Search by name/deity/city/state, nearby, filters, lamp map, day pages, full temple profile with timings, pujas, facilities and trust | ✅ **Done** |
| 7 | **User accounts + Passport** | Registration and login, visited state, manual check-in, ink stamps, circuit collections, achievements | ✅ **Done** |
| 8 | **Photo Stamp** | Attach a visit photo, compose a temple-themed memory card with the stamp, share; original kept untouched | ✅ **Done** |
| 9 | **Favourites + basic Yatra planner** | Saved temples (synced to the account), itinerary by days, reorder, Yatra mode, route in Maps | ✅ **Done** |
| 10 | **Languages: EN / TE / HI** | Interface strings in three languages with bundled Indic fonts; alternate temple names come from the API | ✅ **Done** |

### Phase 2 — Profile and media  ✅ **Done** (app)

Complete devotee profile, memories, songs, chants and darshan videos on
Home, on each weekday page and on every temple, galleries with a viewer,
and the redesigned temple page.

### Phase 3 — Scale and trust  ✅ **Done** (app side)

| Feature | What shipped in the app | Still needs backend |
| --- | --- | --- |
| GPS visit verification | Check-in verifies the device is within 2 km of the temple's coordinates; the passport shows GPS, QR or manual on every visit | Server-side attestation |
| QR visit verification | Scans a temple-issued code (`templepassport://checkin/<slug>`, a temple URL, or the slug) and refuses a code for another temple | Signed codes and the official QR network |
| Festival calendar and notifications | Month grid with the weekday deity on every cell, festival dots, reminders that surface on Home, "Add to calendar" | Push notifications |
| Family Passport | Family members with their own colour; check-ins name who came; per-member stamps | Account-linked family |
| Certificates and achievements | Certificates for completed circuits and yatras, rendered and shareable; two new achievements | — |
| Offline trip packs | Every temple on a yatra saved to the device, served before the bundled sample when offline | — |
| Advanced Yatra planner | Straight-line distances per day, shortest-route ordering (nearest neighbour + 2-opt), automatic split into days by stop count and distance | Road routing |
| Community submissions | Corrections from any temple page and new temples, kept locally and sent to editors by email | Submissions API and moderation queue |
| Temple authority verification, hotel and travel partnerships | Stay & travel links (hotels, transit, food) open in Maps | Partner integrations |

### Phase 4 — Ecosystem  ✅ **Done** (app side)

| Feature | What shipped in the app | Still needs backend |
| --- | --- | --- |
| Official QR Passport network | The devotee's own Passport QR for temple counters; temple-code scanning | The network itself |
| Authorized puja / seva / prasadam | "I booked this" on every puja records the devotee's own booking note against the official route; My seva bookings | Booking integrations |
| AI assistant grounded in verified temple data | The temple guide: a retrieval engine over the app's records (timings, pujas, rules, contact, deities, circuits, nearby, weekday) that never invents a fact and names the record's trust level | A server-side assistant on the same data |
| Expanded Indian-language support | Tamil and Kannada interface strings with bundled Noto fonts, alongside English, Telugu and Hindi | Content translations |
| 100,000+ temple records | Paginated search, offline packs | The records |
| Temple Admin SaaS | — | Backend product |

## Data quality is the product

The database is the core asset. Per the project plan, temple information is
**sourced and maintained**, not scraped from random websites:

- Official temple and government sources take priority.
- Every important field records its **source** and **last-verified date**.
- Content is labelled **official**, **verified**, **community** or **sponsored** —
  these are never blurred.
- An unofficial payment or booking route is **never** presented as official.
- Community submissions are moderated; edit history is retained.
- Stale timings are flagged for review.

These rules are enforced in the schema from slice 1, not bolted on later.
