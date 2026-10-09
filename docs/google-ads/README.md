# Google Ads: app campaign for Darshan Saathi

Everything for an **App promotion → App installs** campaign for the devotee
app on Android (`com.darshansaathi.templevisit`), in English, Telugu and
Hindi.

| What | Where |
| --- | --- |
| Headlines and descriptions, per language | [`AD-TEXT.md`](AD-TEXT.md) (also `ad-text.csv`) |
| Images: 6 per shape, 3 shapes, per language | `images/en/`, `images/te/`, `images/hi/` |
| 15-second videos: portrait, landscape, square, per language | `videos/` |
| The scripts that make them | `tools/` |

The app icon comes from Google Play automatically; it is not uploaded here.

## Images

Each language has the same six images in Google's three shapes:

| Image | Shows | Files |
| --- | --- | --- |
| Temple companion | Home: today's deity, search, your pilgrimage | `companion-*.png` |
| Know before you go | A temple: timings, dress code, directions | `timings-*.png` |
| Book pujas & sevas | Seva booking with time slots | `sevas-*.png` |
| Never miss a festival | Festival calendar with reminders | `festivals-*.png` |
| Temple passport | Passport stamps | `passport-*.png` |
| Brand | Icon, name, "Free on Android" | `brand-*.png` |

Shapes: `-landscape` 1200 × 628 (1.91:1), `-square` 1200 × 1200 (1:1),
`-portrait` 1200 × 1500 (4:5). All are real app screens with demo data (the
names on them are made up).

## Videos

`videos/darshan-saathi-<lang>-<shape>.mp4`: 15 seconds, 30 fps, with the
app's temple bell. Each one runs through the opening, the home screen, a
temple page, seva booking, the festival calendar, and an end card saying
"Search 'Darshan Saathi' on Google Play".

Google Ads takes videos as **YouTube links**:
1. Upload all nine to the Darshan Saathi YouTube channel. **Unlisted** is fine,
   and they don't need to show on the channel.
2. Title each one, e.g. "Darshan Saathi – Temple companion (Telugu, portrait)".
3. Paste the links into the ad group of the same language.

Videos make a big difference: ad groups without one get a video Google makes
from the images, which usually performs worse.

## Setting up the campaign

**Before you start:** the app must be live on Google Play (production, or at
least open testing), and the Play Console account should be linked to Google
Ads (*Google Ads → Tools → Linked accounts → Google Play*). Installs from
Google Play are then counted automatically.

### 1. Campaigns: one per language

Text in an ad group should match the campaign's language setting, so make
three campaigns:

| Campaign | Language setting | Locations to start with |
| --- | --- | --- |
| Darshan Saathi – Telugu | Telugu, English | Telangana, Andhra Pradesh |
| Darshan Saathi – Hindi | Hindi, English | Delhi, Uttar Pradesh, Maharashtra, Madhya Pradesh, Rajasthan, Gujarat |
| Darshan Saathi – English | English | All of India |

For each one: **New campaign → App promotion → App installs → Android →**
search "Darshan Saathi" and pick the app.

- **Bidding:** "Install volume". Set a **target cost per install** once the
  campaign has had about 50 installs.
- **Budget:** start with about **₹500 a day** per campaign. Google learns faster
  when the daily budget is about 50 times the target cost per install.
- **Leave it alone for a week** after starting or changing anything. App
  campaigns need that long to learn.

### 2. Ad group: assets

In each campaign's ad group, add the assets of its language:

| Asset | How many | From |
| --- | --- | --- |
| Headlines | 5 | `AD-TEXT.md`, that language |
| Descriptions | 5 | `AD-TEXT.md`, that language |
| Images | 18 (all 6 × 3 shapes) | `images/<lang>/` |
| Videos | 3 (portrait, landscape, square) | YouTube links of `videos/darshan-saathi-<lang>-*.mp4` |

Codes: `en` English, `te` Telugu, `hi` Hindi. In the English campaign, you can
also add a second ad group with the Telugu or Hindi images if you want to try
them on English readers.

### 3. After two weeks

- *Campaign → Assets* rates each asset Low / Good / Best. Replace the
  **Low** ones; the scripts below make it quick to change a line and render
  again.
- Look at installs by location, and move budget to where installs are
  cheapest.

## Ad policy notes

The text and images stay within Google's rules for this app:
- It only claims what the app does. Bookings are "at participating temples",
  and the app is never called "official", "#1" or "best".
- It doesn't name a temple in a way that suggests a tie-up.
- There's no targeting by religion: Google doesn't allow it, and app campaigns
  don't offer it anyway. Location and language do the job.

"Free" is accurate (the app is free to download). If paid features are added
later, keep the word "free" about the download only.

## Making them again

After a screen or a line changes:

```sh
cd docs/google-ads/tools
python3 copy.py          # text: checks the limits, writes AD-TEXT.md and ad-text.csv
node images.js           # 54 images (needs Playwright with Chromium)
FFMPEG=/path/to/ffmpeg node video.js            # all 9 videos (about 5 minutes)
FFMPEG=/path/to/ffmpeg node video.js te portrait  # just one
```

- **Where things are:** the text is in `copy.py`; the image and video lines
  are in `creative.js` (`THEMES`); the app screens are `tools/screens/*.jpg`.
  New screens come from the Play Store capture (see
  `../play-store/README.md`).
- **ffmpeg:** if it isn't installed, `pip install imageio-ffmpeg` brings one
  (`python3 -c "import imageio_ffmpeg as f; print(f.get_ffmpeg_exe())"`).
