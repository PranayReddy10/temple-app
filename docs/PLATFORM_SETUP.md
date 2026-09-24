# Sign-in, push, ads and payments — setup checklist

Almost everything is set in the admin panel and read by the app from
`GET /api/v1/app/config`, so it changes without a new build. The few things
below are compiled into the app and have to be set once before release.

## Google sign-in

1. Google Cloud Console → Credentials: create a **Web** OAuth client, an
   **Android** client (package `app.templepassport.temple_app` + the SHA-1 of
   the release signing key *and* of the Play App Signing key) and an **iOS**
   client (the bundle id).
2. Admin → App → Sign-in methods: paste the Web client id and the iOS client
   id, switch Google on.
3. iOS only: in `ios/Runner/Info.plist`, replace
   `com.googleusercontent.apps.REPLACE-WITH-IOS-CLIENT-ID` with the iOS
   client's *reversed* id.

## Sign in with Apple (iPhone and iPad)

1. Apple Developer → Identifiers → the app id → enable **Sign in with Apple**.
2. Xcode → Runner → Signing & Capabilities → **+ Capability → Sign in with
   Apple** (this adds `Runner.entitlements`).
3. Admin → App → Sign-in methods: add the bundle id to "Accepted client ids"
   and switch Apple on. Apple requires this button whenever Google sign-in is
   offered on iOS.

## Push notifications (Firebase)

1. Firebase console: create a project, add an Android app and an iOS app.
2. Admin → App → Push setup: copy the project id, sender id, and each app's
   API key and app id; paste the service account JSON (Project settings →
   Service accounts → Generate new private key); switch push on.
3. iOS only: upload an APNs key under Firebase → Cloud Messaging, and in
   Xcode add the **Push Notifications** and **Background Modes → Remote
   notifications** capabilities.
4. Scheduled notifications need the Laravel scheduler cron on the server:
   `* * * * * php /path/to/artisan schedule:run`.

No `google-services.json` or `GoogleService-Info.plist` is needed: the app
starts Firebase with the ids from the admin panel.

## Ads

1. AdMob (or AppLovin MAX) account → create the app and **native** ad units.
2. Replace Google's test **app id** in both
   `android/app/src/main/AndroidManifest.xml`
   (`com.google.android.gms.ads.APPLICATION_ID`) and `ios/Runner/Info.plist`
   (`GADApplicationIdentifier`). The app closes on launch without one, so a
   test id ships until then.
3. Admin → Monetisation → Ads: choose the network, paste the unit ids, pick
   placements, and keep **Test ads only** on until the store release.
4. Meta Audience Network: add it as a bidder in AdMob mediation or MAX, and
   add its adapter dependency to `android/app/build.gradle.kts`
   (`com.google.ads.mediation:facebook` for AdMob, or
   `com.applovin.mediation:facebook-adapter` for MAX) and the matching pod.
5. Host `app-ads.txt` at the website root.

## Payments

Admin → Monetisation → Payment gateways; see
`temple-website/docs/MONETISATION.md` for the flow and the Play / App Store
rules on selling digital subscriptions.

UPI apps are opened from the checkout page: Android declares the `upi`
scheme in `<queries>`; iOS lists `upi`, `phonepe`, `tez` and `paytmmp` in
`LSApplicationQueriesSchemes`.
