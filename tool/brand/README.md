# Darshan Saathi logo

The mark is concept A, "Gopuram & Diya": the temple tower with a lamp's flame
over its finial and a lit doorway, in ivory on the saffron-to-kumkum gradient.

- `mark.js`: the mark itself (a 100×100 SVG fragment) and the brand colours.
- `render.js`: draws every icon from it into both repos: Android launcher
  and adaptive foreground, iOS AppIcon set, and the website's favicon, share
  image and icons (`temple-website/public/favicon.png`, `public/og.png`,
  `public/icons`), plus the SVG masters here and in
  `temple-website/public/brand`.
- `logo-*.svg`: masters for print, the store listings and anything new.

To change the logo, edit `mark.js` and run, from `temple-app`:

    node tool/brand/render.js

(Needs Playwright's Chromium; set PLAYWRIGHT to its module path if it is
installed globally.) Then rebuild the app, and write
`temple-website/public/favicon.ico` from `public/icons/favicon-32.png`.
