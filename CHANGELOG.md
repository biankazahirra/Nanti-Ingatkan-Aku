# Changelog

All notable changes to this project are recorded here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/).

## [1.0.0+1] — 2026-10-23

First release. Indonesian-only UI, offline-first, no account, no network
permission in release.

### Added

- **Notes (FR-MEM-01..10).** Create, edit, archive and delete a note with a
  title (1–120 graphemes), an optional body (≤ 10,000) and one of four
  categories: `Umum`, `Dipinjamkan` (person + item), `Garansi` (item + end date),
  `Perawatan` (item). Trim-on-save, grapheme-aware limits, inline field errors,
  draft protection when leaving a dirty form, and a named confirmation before a
  hard delete.
- **Reminders (FR-REM-01..12).** At most one reminder per note, four presets
  plus a date and time picker, past times rejected instead of silently moved, and
  explicit DST handling: a time inside a spring-forward gap is shifted forward
  with a warning, a time inside a fall-back overlap uses the earlier instant and
  says so. The notification permission is asked only after the user has turned the
  reminder switch on and read a rationale; declining leaves the switch off and
  never blocks saving the note.
- **Today (FR-TODAY-01..06).** `Terlewat` / `Hari ini` / `7 hari ke depan`
  groups, mutually exclusive and ordered by due time, computed from the injected
  clock rather than a stored flag, plus a full-list screen per group and an empty
  state that never implies nothing exists.
- **Search (FR-SRH-01..06).** Case- and whitespace-insensitive search over
  normalized title and body, AND across up to five tokens of at most 50
  characters, `%`/`_`/`\` escaped, title hits ranked first, one extra row fetched
  to detect the next page.
- **Scheduling engine (§7.6).** Deterministic notification ids derived from the
  reminder UUID with a linear-uniqueness probe, exact alarms only when the
  platform grants them, inexact fallback recorded as such, a cap of 100 scheduled
  reminders with the remainder marked `deferred`, and a reconcile pass on launch,
  on resume (throttled to 60 s), after every mutation, after import and after a
  timezone change.
- **Backup (FR-EXP-01..03, FR-IMP-01..04).** Manual export to a user-chosen JSON
  file with an unencrypted-file warning, and a replace-only import gated by full
  in-memory validation: size cap, parse, envelope, schema version, counts, row
  caps, field typing, category metadata rules, uniqueness, references, reminder
  enums and dates. The swap runs in one transaction with fresh notification ids;
  any failure rolls back and keeps the previous data. Scheduling is recomputed
  afterwards and reported separately.
- **Settings (FR-SET-01..07).** Notification health (permission, exact alarms,
  channel, unresolved counts) with a button to the OS app-settings screen and an
  offer of the exact-alarm grant screen when it is unavailable, hide-notification-
  content with a lock screen that then carries no note title, backup, a privacy
  statement, diagnostics that show counts, versions, zone and error codes only —
  never content — and `Hapus semua data`.
- **Onboarding.** Three-line first run with an explicit "no account, no server,
  stays on this phone" statement.
- **Android shell (§6.2, §7.6).** `minSdk 26`, `compileSdk`/`targetSdk 36`, Java
  17 with core library desugaring, multidex, `POST_NOTIFICATIONS` /
  `RECEIVE_BOOT_COMPLETED` / `SCHEDULE_EXACT_ALARM`, the
  `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver`
  receivers, and a one-method `MethodChannel` in `MainActivity.kt` that opens the
  per-app OS settings screen.
- **Database (§7.3, §7.4).** Schema version 1 with foreign keys enforced, WAL
  mode, business rules expressed as SQLite `CHECK` constraints, an ordered
  migration list, a pre-migration file copy, an `integrity_check` after every
  upgrade, and a refusal to open a database written by a newer build.

### Privacy

- No `INTERNET` permission in release: `src/release/AndroidManifest.xml` removes
  it from the merged manifest, so even a dependency cannot contribute it.
- Android auto-backup disabled by `allowBackup="false"` plus
  `data_extraction_rules.xml`, so notes reach neither a cloud backup nor a
  device-to-device transfer.
- No analytics, no crash reporting, no user text in logs (codes, counts and
  timestamps only).

### Verified

On Flutter 3.47.7 / Dart 3.13.5, against this tree:

- `flutter analyze` → `No issues found!`
- `dart format --set-exit-if-changed lib test tool` → `0 changed`
- `flutter test` → `+202: All tests passed!`
- `flutter build apk --release --target-platform android-arm64` → `app-release.apk`,
  19.7 MB. `apkanalyzer manifest print` against that artifact reports
  `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM` and
  `VIBRATE`, no `INTERNET`, `allowBackup="false"`, both notification receivers,
  `minSdk 26`, `targetSdk 36`.
- `flutter test tool/ui_screenshots.dart` → ten PNGs in `build/ui_preview/`,
  rendered from the real widgets, localizations and theme.

### Build notes

- `android/gradle.properties` sizes the Gradle and Kotlin JVMs for a small host.
  The Flutter template default (`-Xmx8G -XX:MaxMetaspaceSize=4G`) cannot fit a
  4 GB machine and killed the daemon before the build reached compilation. Raise
  both values on a roomier build machine.
- No `integration_test` dev dependency: it puts a plugin in the generated release
  registrant that no Android artifact provides, which fails
  `:app:compileReleaseJavaWithJavac`.

### Known limitations

- Notification delivery is delegated to Android and is best-effort; inexact
  alarms and aggressive OEM battery management can delay it. The app states this
  instead of promising timing.
- Manual export is the only recovery path, which is the direct consequence of
  disabling auto-backup.
- Items marked below are implemented but not machine-verifiable without an
  Android device: real notification delivery, permission prompts, behaviour after
  reboot, timezone travel, OEM battery restrictions, TalkBack flows, 48 dp touch
  targets, and the SAF file picker.
