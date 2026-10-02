# Google Play assets

| File | Use in Play Console |
| --- | --- |
| `icon-512.png` | App icon (512 × 512, full square: Play rounds it) |
| `feature-graphic-1024x500.png` | Feature graphic |
| `screenshots/screenshot-1…9.png` | Phone screenshots (1080 × 1920), in this order |
| `store-listing.csv` | Title and descriptions in en, te, hi, ta, kn (`listing.py` builds and length-checks it) |

The screenshots are the real app (the web build) against a local backend with
demo data, framed with a caption:

1. Your daily darshan: home
2. Every temple, in detail: temple page
3. Book pujas and sevas: seva booking with time slots
4. Your ticket at the counter: QR ticket
5. Your temple passport: stamps
6. Festival calendar 2026–27
7. Bhajans this week: home
8. Join bhajan gatherings: event page
9. Online hundi

To redo them after the UI changes: run temple-website locally (sqlite,
`migrate:fresh --seed`, demo temples, sevas, a bhajan, a devotee with
stamps), `flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:8000`,
serve it on :8811, write the devotee's `/api/v1/me` JSON to
`tools/devotee.json`, then from `tools/` with Playwright installed:

    DEVOTEE_TOKEN=... node capture.js     # raw_1..9.png, 390×780 at 3×
    node compose.js                        # out/: framed screenshots, icon, feature graphic

(`compose.js` reads the Noto fonts from `store/` and the logo from
`tool/brand/mark.js`; adjust the paths at the top.)
