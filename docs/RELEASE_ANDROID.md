# Releasing Darshan Saathi on Google Play

Package name: `com.darshansaathi.templevisit`

## 1. Make the upload key (once, on your own computer)

```bash
keytool -genkey -v -keystore ~/keys/darshan-saathi-upload.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

It asks for a password and your name/organisation. Keep the `.jks` file
and both passwords safe and backed up (a password manager plus a second
copy off the computer). Do not put them in Git, email or chat.

With **Play App Signing** (the default for new apps), Google holds the key
that signs what devotees install; this file is only the *upload* key. If it
is ever lost, Play Console → App integrity → *Request upload key reset*
replaces it.

## 2. Tell the build where it is

Copy `android/key.properties.example` to `android/key.properties` and fill
it in. `key.properties`, `*.jks` and `*.keystore` are in .gitignore.

## 3. Raise the version

In `pubspec.yaml`, `version: 1.0.0+7` means version name 1.0.0 and version
code 7. Every upload needs a higher version code than the last one.

## 4. Build the signed bundle

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

The bundle is `build/app/outputs/bundle/release/app-release.aab`.

Check it is signed with your key, not the debug key:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

The owner shown should be the name you gave in step 1, not "Android Debug".
Without `key.properties` the build falls back to the debug key, which Play
Console refuses.

## 5. Upload

Play Console → the app → Test and release → Internal testing (first), then
Production → Create new release → upload `app-release.aab`.

## 6. After the first upload

Play Console → Test and release → App integrity → App signing: copy the
**App signing key certificate SHA-256** into the admin panel (Admin → App
control → Open temple links in the app), so shared temple links open in the
installed app. Add the upload key's SHA-256 as well (from
`keytool -list -v -keystore ~/keys/darshan-saathi-upload.jks -alias upload`)
for builds installed straight from your computer.
