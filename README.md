# Zero-Trust Fitness

An end-to-end encrypted fitness tracker: activity goals, GPS workouts, sleep
and a full journal, where your health data is encrypted on your phone before
it syncs. On the phone it is called **ZT Fitness**; in stores and on release
pages, **Zero-Trust Fitness**. Same account, settings and look as the other
Zero-Trust apps, built on
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core). Part of the
[Zero-Trust suite](https://zerotrust.bz).

> ZT Fitness is for general fitness and wellness. It is not a medical device
> and does not diagnose or treat any condition.

## What it does

- **Today:** rings for steps, Move Minutes and Heart Points, with weekly
  goals, trends and achievements.
- **Health Connect** (Android): reads steps, heart rate, sleep, weight and
  more from your watch and other apps. Writing your workouts and water back
  is a switch, off by default. Everything is read on the phone.
- **GPS workouts:** auto-pause, voice cues, lap splits per kilometre or
  mile, and Pause and Lap buttons on the lock screen.
- **Route maps from offline tiles:** map tiles are kept on the phone, and
  "Offline maps only" stops downloads, so looking at a route doesn't tell a
  map server where you have been.
- **Journal:** every workout and entry, with edit and delete, and workout
  templates for the ones you repeat.
- **Sleep:** each night with its stages (from Health Connect or entered by
  hand), counted on the morning it ends, against your sleep goal.
- **Water and food:** water, meals and nutrition.
- **Reminders:** hydration (counted from the last water you logged), sleep,
  and an optional weekly summary notification.
- **Challenges with friends** (Settings > Challenges, and on Today while one
  runs): race on steps or Heart Points, by highest total or by days that
  hit a daily target, for 3 to 92 days. Invite by link or QR code and
  confirm with a matching code.
- **Import:** workout files (.fit, .tcx and .gpx, also gzipped) from Garmin,
  Polar, Coros, Wahoo, Suunto, Strava, Komoot and others, and Google Fit
  (Google Takeout). Importing the same file again adds nothing twice.
- **Export:** a route as GPX, a report to share, and a full backup as JSON
  that can be restored.
- **Wear OS companion** (opt-in): today's Heart Points, steps and water on
  a paired watch, tiles for Heart Points and Water, and adding water from
  the watch. Sent only to the watch.
- **Home screen widget** (Android), resizable, with your rings.
- **ZT Quests:** with Health Connect write-back on, ZT Quests can count your
  workouts and water toward its quests.

## Privacy

Like every Zero-Trust app, it is zero-knowledge: your data is encrypted on
your device, with keys made from your password, before anything is sent.
The server stores only ciphertext and your password itself is never
sent, so neither we nor anyone who breaks into the server can read your
data. The recovery key shown at sign-up is the only way back in if you
forget the password. How the keys work:
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core#key-hierarchy) and
[zerotrust.bz/security](https://zerotrust.bz/security/).

- Workouts, daily metrics, meals, goals and templates are items in the
  shared `vault_items` table, encrypted on the device with the Fitness app
  key (`app = 'fitness'`). On the phone they sit in the core's encrypted
  store; nothing readable is written to disk.
- Health Connect data is read on the phone and never sent anywhere
  unencrypted. Deleting your Fitness data does not touch Health Connect.
- A challenge is a Zero-Trust shared space: friends see only your total for
  the challenge's measure and days, encrypted for the members. The server
  can't read it, and nobody can post numbers in your name.
- The Privacy dashboard in the app shows what is stored in your vault and
  how it is protected.
- Exported files (GPX, reports, JSON backups) are plain files.
- Data from before the core is brought over on first unlock
  (`lib/features/legacy_import/`).

## One account, one core

One Zero-Trust account opens every app in the suite. Sign-in, unlock
(fingerprint or face, auto-lock), the recovery key, settings, the look,
sync and languages come from
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core), so they work
the same in every app. Accounts made before the core still sign in and
see their data.

## Install

Android: get the latest signed APK from this repository's
[Releases](https://github.com/EdoSag/Zero-Trust-Fitness/releases/latest),
or from [zerotrust.bz/install](https://zerotrust.bz/install/#fitness),
which also shows each file's SHA-256, the signing fingerprint and an
Obtainium link. GitHub Releases are the main way the apps are published.

Builds from GitHub check for a newer release themselves (Settings > About,
one anonymous request a day, can be turned off). Every Zero-Trust app is signed
with the same key, and Android only installs an update signed with it.

## Languages

English and Hebrew, with right-to-left layout. Choose under
Settings > Appearance > Language.

## How it is built

- Flutter on Zero-Trust-Core. `lib/pages/` holds the screens, `lib/features/`
  the logic per feature (health, gpx, maps, sleep, challenges, import,
  summary, wear, achievements), `lib/core/` storage and services.
- Health data comes through the `health` package (Health Connect), GPS
  through `geolocator`, maps through `flutter_map` with the app's own tile
  cache (`lib/features/maps/tile_cache.dart`).
- The Wear OS app is the Gradle module `android/wear` (same application id),
  built by CI and attached to each release.

## Build from source

Flutter 3.47.9, the version CI pins (3.50 deprecates `material.dart` and
fails analyze).

```bash
# .env (not committed; CI writes its own). Public client values only:
# never a service-role key, because .env is bundled into the APK.
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<publishable key>

flutter pub get
dart run zt_release_checks --app fitness   # shared release checks
flutter analyze && flutter test
flutter run
```

Never add `cryptography_flutter`: it breaks the core's key derivation and
sign-in fails.

Launcher icons are drawn from the suite's brand mark:
`flutter test tool/launcher_icon_test.dart`.

## Branches and releases

Work happens on `Dev`: pull requests target `Dev`, never `main`, and get a
test build. A release is one `Dev` → `main` pull request. Every push to
`main` runs the suite's release checks, builds a signed APK, the Wear OS APK and a Google Play bundle
and publishes them as a GitHub Release named "Zero-Trust Fitness"
(`.github/workflows/android-apk.yml`). The workflow needs the repository
secrets `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`, the
keystore shared by all Zero-Trust apps.

## Support and security

- Help centre: [zerotrust.bz/help](https://zerotrust.bz/help/). Questions and
  account deletion: support@zerotrust.bz.
- Security problems: please report them privately to cyber@zerotrust.bz. What
  the encryption does and doesn't protect against is on
  [zerotrust.bz/security](https://zerotrust.bz/security/).
- [Privacy policy](https://zerotrust.bz/privacy/) and
  [terms](https://zerotrust.bz/terms/).

## License

Copyright (C) 2026 Edo Sagron (https://zerotrust.bz)

Zero-Trust is open source under the [GNU Affero General Public License v3.0](LICENSE)
(AGPL-3.0-only), the same licence Signal uses.

- You may use, study, change and share the code, including in your own projects.
- If you share a changed version, or run it for other people over a network, you must
  publish your full source code under the same licence.
- This program comes with no warranty; see the licence for details.

Third-party libraries keep their own licences; the app lists them under
Settings > Open-source licences.

### Name and logo

The AGPL covers the code, not the brand. "Zero-Trust", "ZT", the app names and icons are
reserved. If you publish a fork, give it a different name and icon so nobody mistakes it
for an official Zero-Trust app.

### Servers

The official apps use the Zero-Trust servers. A fork must use its own backend (for
example its own Supabase project) and must not connect to the official servers.

### Contributing

Pull requests are welcome. By sending one you agree that your contribution is licensed
under the AGPL-3.0 and that the copyright holder may also license it under other terms,
including commercially. This keeps the project able to offer paid plans and other licences.
