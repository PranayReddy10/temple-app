# Temple App — Flutter Client

Flutter client for the temple pilgrimage platform (working name:
**Temple Passport** — not finalised). One codebase targets **Android, iOS and
Flutter Web**.

The backend API and admin panel live in
[`temple-website`](https://github.com/PranayReddy10/temple-website).

See **[ROADMAP.md](ROADMAP.md)** for the feature slices and delivery order.

## Status

Flutter work begins at **slice 5** of the roadmap, once the public REST API
(slice 4) is available to build against. Slices 1–4 are backend and admin
panel work in `temple-website`.

Building the app shell before the API exists would mean writing throwaway
mock layers, so the order is deliberate.

## Planned structure

```
lib/
├── core/
│   ├── theme/        # Temple design system — saffron, kumkum, gold
│   ├── api/          # REST client against /api/v1
│   └── l10n/         # English, Telugu, Hindi
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
