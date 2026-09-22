# Temple App — Flutter Client

Flutter client for the temple pilgrimage platform (working name:
**Temple Passport** — not finalised). One codebase targets **Android, iOS and
Flutter Web**.

The backend API and admin panel live in
[`temple-website`](https://github.com/PranayReddy10/temple-website).

See **[ROADMAP.md](ROADMAP.md)** for the feature slices and delivery order.

## Status

**No Flutter code has been written yet.** This repository holds this README
and the shared roadmap; everything built so far is backend and admin panel
work in `temple-website`.

That was deliberate — building the app shell before the API existed would
have meant writing throwaway mock layers — and the wait is now over. The
backend half of every Phase 3 slice is done and documented, so slice 10 (the
app shell) is what starts here next.

### What the app can be built against today

| Area | Endpoints | Notes |
| --- | --- | --- |
| Temples | `GET /api/v1/temples`, `…/{slug}` | Search, nearby with real distance, filters by deity, category and state |
| Reference data | `deities`, `categories`, `states`, `facilities` | |
| Daily devotion | `today`, `days`, `days/{weekday}` | Monday Shiva, Tuesday Hanuman, with songs, photos and a per-day accent colour |
| Events | `GET /api/v1/events` | Published festivals and programs |
| Accounts | `auth/register`, `auth/login`, `auth/logout`, `me` | Sanctum tokens on the `devotee` guard |
| Favourites | `me/saved-temples` | |
| **Passport** | `me/passport`, `me/visits`, `temples/{slug}/visits` | Stamps, circuit progress, GPS and QR check-in |
| **Photo Stamp** | `me/photos`, `temples/{slug}/photos` | Original and generated card stored separately; moderated |
| **Memories** | `me/memories` | Private by default |
| **Yatra planner** | `me/yatras`, `…/temples/{slug}` | Itinerary by day and order; a recorded visit closes its stop |
| **Languages** | `GET /api/v1/languages`, `?lang=` on everything | Twelve configured, three shipping |

Full request and response detail, including the rules the app has to respect
(a manual check-in never counts as a stamp; a private memory stays private
through a PATCH that omits the field), is in
[`temple-website/docs/API.md`](https://github.com/PranayReddy10/temple-website/blob/main/docs/API.md).

Send `X-Platform` and `X-App-Version` on requests: they are recorded against
each sign-in and are what the admin's analytics screen reads.

## Planned structure

```
lib/
├── core/
│   ├── theme/        # Temple design system — saffron, kumkum, gold
│   ├── api/          # REST client against /api/v1
│   └── l10n/         # English, Telugu, Hindi — the language list is
│                     # served by GET /api/v1/languages, not compiled in,
│                     # so a new language does not need an app store review
├── features/
│   ├── home/         # Search, nearby, popular, festivals
│   ├── explore/      # Map, categories, states, advanced search
│   ├── passport/     # Stamps, visits, collections, achievements
│   ├── yatra/        # Itinerary creation and Yatra mode
│   └── profile/      # Memories, family, settings, language
└── main.dart
```

## Navigation

Five tabs, per the project plan:

| Tab | Purpose |
| --- | --- |
| Home | Search, nearby, popular temples, festivals, recommendations |
| Explore | Map, categories, states, advanced search |
| Passport | Stamps, visits, collections, achievements, certificates |
| Yatra | Create, manage and complete pilgrimage itineraries |
| Profile | Memories, family, settings, language, subscription |

## Theme

Visual language draws on Indian temple tradition — saffron and kumkum reds,
temple gold, and motifs referencing gopuram architecture. The palette is
defined once in `core/theme/` so the app, admin panel and public web stay
visually consistent.

## Branding

The product name is not final and is never hard-coded. It resolves from a
single constant in `core/` so renaming is a one-file change.
