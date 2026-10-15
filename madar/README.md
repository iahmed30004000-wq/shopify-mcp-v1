# مَدار · Madar

A personal life operating system whose day orbits the five prayers.
Arabic-first (RTL), offline-first, encrypted on device, built in Flutter.

> Status: **Phases 0–7 in the app** — foundation, The Astrolabe Orbit, prayer &
> faith essentials, Quran, Health, Money, the six Life planets, and Madar
> Cinema (the Film Reel Engine with the demo, Metropolis Machine, Flappy Orbit
> and Saved Games). Built and tested but not yet wired into the app: global
> search, the notification centre, export & encrypted backup, AI chat,
> home-screen widgets, Together Mode, and the rules engines for the Tier 2
> games — see [`PLAN.md`](PLAN.md) for the ordered plan of what is left.
> See also the [Feature checklist](#feature-checklist). This README is updated
> at the end of every phase.

---

## Build

### Requirements

| Tool | Version |
| --- | --- |
| Flutter | 3.47.5 (stable) · Dart 3.13 |
| JDK | 17–21 |
| Android SDK | platform 36, build-tools, NDK (installed automatically by Gradle when licences are accepted) |
| Android Gradle Plugin / Gradle | 9.1 / 9.3.1 (wrapper) |

### Commands

```bash
cd madar
flutter pub get
dart run tool/merge_arb.dart && flutter gen-l10n   # after editing strings
dart run build_runner build                         # after editing Drift tables
tool/check_shaders.sh                               # validate GLSL (SkSL + SPIR-V)
flutter analyze
flutter test --exclude-tags screenshot
flutter test --tags screenshot                      # renders screens to screenshots/ for visual review
flutter build apk --release
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk`.

### Continuous integration

`.github/workflows/madar-android.yml` (repository root) analyses, tests and
builds a signed release APK on every push to `main` or `claude/madar-**` that
touches `madar/`, and uploads it as the artifact `madar-apk-<run>` (APK plus
`SHA256SUMS.txt`). It can also be started manually (**Actions → Madar Android →
Run workflow**).

### Signing (keystore)

Release builds are signed with, in order of preference:

1. `android/key.properties` (local builds; git-ignored):

   ```properties
   storeFile=/absolute/path/madar-release.jks
   storePassword=…
   keyAlias=madar
   keyPassword=…
   ```

2. Environment variables (CI): `MADAR_KEYSTORE_PATH`, `MADAR_KEYSTORE_PASSWORD`,
   `MADAR_KEY_ALIAS`, `MADAR_KEY_PASSWORD`.
3. The debug key, as a fallback so a release build always succeeds. The CI
   artifact name ends in `-debug-key` in that case.

To sign CI builds with your own key, add these **repository secrets**
(Settings → Secrets and variables → Actions):

| Secret | Value |
| --- | --- |
| `MADAR_KEYSTORE_BASE64` | `base64 -w0 madar-release.jks` |
| `MADAR_KEYSTORE_PASSWORD` | keystore password |
| `MADAR_KEY_ALIAS` | `madar` |
| `MADAR_KEY_PASSWORD` | key password |

Create a keystore with:

```bash
keytool -genkeypair -v -keystore madar-release.jks -storetype PKCS12 \
  -alias madar -keyalg RSA -keysize 4096 -validity 36500
```

Keep the keystore and its passwords safe and out of git: Android only installs
an update over an existing install when it is signed with the same key.

---

## Architecture

Feature-first clean architecture: `lib/core` holds cross-cutting systems,
`lib/features/<feature>` holds screens, controllers and feature data access.
State and dependency injection use Riverpod; navigation uses go_router;
persistence uses Drift over SQLCipher.

```
lib/
  app/                 bootstrap, root app, gates (unlock / lock)
  core/
    astro/             sun, moon and star positions, Yale Bright Star Catalog
    db/                Drift schema (tables/), encryption, repositories, snapshot
    design/            tokens, 5 themes, typography, glass widgets, painters
    domain/            enums, money value type, budget math
    i18n/              ARB parts → ARB → generated L10n, formatters (digits, bidi)
    import/            tolerant importer for the HTML prototype export
    interaction/       long-press menu, swipe actions, reorder, edit/move/reminder sheets, quick-add
    motion/            motion language, transitions, springs, particles
    settings/          UI preferences readable before unlock
    sound/             procedural synthesiser, per-theme sound kits, ambient, haptics
  features/
    orbit/             The Astrolabe Orbit (home scene)
      domain/          scene math, prayer schedule (adhan, Jordan preset), planet scores, moons, neglect reasons
      data/            OrbitRepository (DB → scene snapshot), providers, customisation, completion pulses
      render/          astrolabe (brass, rete, fire, ring text), sky (real sky + stars), planets + moons, shaders
      presentation/    OrbitScene, camera/gestures/gyro, fly-in, planet pages, prayer & customise sheets, governor
    home/ settings/ onboarding/ import/ gallery/
shaders/               GLSL fragment shaders (Flutter FragmentProgram)
  orbit/lib/common.glsl  shared noise / lighting / living-state library
tool/                  merge_arb.dart, check_shaders.sh
```

### Data model

About 50 encrypted Drift tables grouped by domain (`lib/core/db/tables/`):

* **Core**: planets, key/values, reminders, activity log, tasks (placed in
  prayer windows), prayer logs, import archive.
* **Health**: alerts, conditions, medications (times, taken-with, stock,
  titration), courses (phases), timing rules, doses, lab tests and readings,
  appointments, doctor questions, pain, mood, tag options, habits, worries.
* **Money** (integer milli-units, no tax/VAT/zakat fields): currencies with
  manual rates, wallets, nested budget items (amount or percent of parent or
  total, monthly or weekly), transactions, jars, deposits, debts, payments,
  recurring obligations.
* **Life**: people and contact logs, projects and items, boards and cards,
  trips, packing, documents, learning goals and logs, exercises, workouts,
  avoid list, fasting, water, custom modules and entries.

### Security

* The database is encrypted with SQLCipher (sqlite3 build hooks,
  `source: sqlcipher` on Android). The 256-bit key is generated on first run
  and kept in Android Keystore-backed secure storage.
* Only UI preferences (theme, language, lock settings) live outside the
  encrypted database.
* No analytics, no ads, no backend. The network is used only for Quran
  text/audio, optional downloads, user-initiated AI calls and the optional
  Together Mode online sync (off by default).

### Import format

See [`docs/import-format.md`](docs/import-format.md).

---

## Data sources and credits

| Asset | Source | Licence |
| --- | --- | --- |
| IBM Plex Sans Arabic | IBM / Google Fonts | SIL OFL 1.1 |
| Reem Kufi | Khaled Hosny / Google Fonts | SIL OFL 1.1 |
| Amiri, Amiri Quran | Khaled Hosny / Google Fonts | SIL OFL 1.1 |
| Bright stars (V ≤ 5.2) | Yale Bright Star Catalog, 5th rev. ed. (Hoffleit & Warren), NASA ADC / Harvard CfA | public scientific data |
| Sun & moon positions | NOAA solar calculator, Meeus *Astronomical Algorithms* | algorithms |
| All UI sounds, ambient, game music | procedurally synthesised in Dart | original |
| All visuals | code (shaders, painters) — no image files | original |

---

## Feature checklist

Legend: ✅ done · 🟡 partial · ⏳ planned phase

| Area | Status |
| --- | --- |
| Phase 0 – setup, architecture, design system, motion, sound, interaction kit, encrypted DB, JSON import | ✅ |
| Phase 1 – The Astrolabe Orbit: astrolabe prayer dial, 8 living procedural worlds + data moons, real sky (sun, moon phase, 2,068 real stars, Milky Way), camera & gestures, fly-in pages, glass panel with windows / tasks / Neglect Radar, performance & power modes | ✅ (device profiling pending) |
| Phase 2 – app lock (fingerprint + PIN; the fingerprint prompt opens by itself while the astrolabe assembles), themes + i18n audit, prayer times (21 methods, GPS or 809 offline cities, Hijri, time zones), exact full-screen adhan (alarm-clock alarms a week ahead, per-prayer sounds, pre-adhan reminders, permissions card), prayer tracker (sunnah, Duha, Witr, Qiyam, jamaah, mosque, streaks, qada), adhkar (Hisn al-Muslim) + tasbeeh, Faith hub | ✅ (device checks pending: adhan on a locked phone, after reboot, in battery saver) |
| Phase 3 – Quran (offline Tanzil Uthmani text, 18-rule tajweed colouring, mushaf pages + verse list, search, bookmarks, Quran.com v4 on demand), recitation (19 EveryAyah reciters, per-ayah highlighting, repeats, background playback, offline downloads), daily wird plans, Hifz with SM-2 (ayat + An-Nawawi's 40), Qibla astrolabe compass (WMM declination, sun-compass fallback) | ✅ (device checks pending: streaming, background playback, compass) |
| Phase 4 – Health: medications & supplements with timing rules, titration and injection courses, labs with reference bands and a doctor-ready PDF, appointments and doctor questions, pain tracker with a body map, mood & stress with a worry window and guided breathing | ✅ (device checks pending) |
| Phase 5 – Money: multi-currency wallets with manual rates, transactions, nested budget by amount or percent, savings jars, debts, recurring obligations with due reminders, and the Money hub on its planet | ✅ (device checks pending) |
| Phase 6 – Life: Work (boards, projects, Top 3), Family (people, contact rhythm, one-tap contact), Travel (trips, packing templates, document expiry), Growth (learning goals), Body (exercises, fasting, water), and the Custom Modules Builder — each on its planet with routes, reminders and settings | ✅ (device checks pending) |
| Phase 7 – Film Reel Engine (six era skins, film FX shaders, rubber-hose rig, procedural score and SFX, stage, HUD, transitions) + the movie-palace hall reached from the Growth planet; Tier 1 games: Metropolis Machine and Flappy Orbit playable, Caravan Dash / Noir Rooftops / Neon Souk Racer still to come | 🔄 2 of 5 games |
| Phase 8 – Tier 2 games | ⏳ |
| Phase 9 – AI Bridge, notifications, widgets, search, backup | ⏳ |
| Phase 10 – Together Mode | ⏳ |
