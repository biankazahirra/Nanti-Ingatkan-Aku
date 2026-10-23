# Nanti Ingatkan Aku

Offline-first personal memory assistant. One place to write down the small things
people forget — where an item is, what was lent to whom, when a warranty ends,
when service is due — and an optional reminder on top of each note.

Indonesian-only UI (DEC-02), no account, no server, no analytics, no network
permission in release.

- Status: v1.0.0+1 (MVP, P0 scope complete)
- Spec: [`nanti-ingatkan-aku-PRD.md`](nanti-ingatkan-aku-PRD.md)

---

## 1. What it does

| Area | Behaviour |
| --- | --- |
| Capture | Title (1–120 graphemes) and optional body (≤ 10,000), four categories: `Umum`, `Dipinjamkan`, `Garansi`, `Perawatan` |
| Category metadata | `Dipinjamkan` → person + item; `Garansi` → item + end date; `Perawatan` → item |
| Reminders | At most one per note; four presets plus a date/time picker; past times are rejected, DST gaps and overlaps are explained before saving |
| Today | Three mutually exclusive groups — `Terlewat`, `Hari ini`, `7 hari ke depan` — computed from the injected clock, never from a stored flag |
| Search | Case- and whitespace-insensitive over title and body, AND across up to 5 tokens, `LIKE` metacharacters escaped, title hits ranked first |
| Archive | Soft hide; a pending reminder keeps firing (DEC-08) |
| Backup | Manual export to a user-chosen `.json` file, replace-only import with a full pre-write validation gate |
| Privacy | No `INTERNET` permission, Android auto-backup disabled (DEC-03), unencrypted export with an explicit warning (DEC-04) |

## 2. Requirements

- Flutter 3.47.x (Dart 3.13.x) — `environment: sdk: ">=3.13.0 <4.0.0"`
- Android SDK with API 26+ target for a device build
- Dependencies are pinned with caret constraints in `pubspec.yaml` and fixed by
  `pubspec.lock`
- Android platform (PRD §6.2): `minSdk 26`, `compileSdk`/`targetSdk 36`, Java 17,
  core library desugaring, AGP 9.1.0, Kotlin 2.4.0, Gradle 9.3.1

## 3. Getting started

```bash
flutter pub get                 # also runs `gen-l10n` (generate: true)
flutter analyze
flutter test
flutter run -d <device>         # debug build on a real phone
flutter build apk --release
```

`lib/l10n/app_localizations.dart` is generated from `lib/l10n/app_id.arb`
(`l10n.yaml`, `nullable-getter: false`). It is not committed; `flutter pub get`
or any build regenerates it.

`gen-l10n` accepts only Dart identifiers as resource names, so a dotted domain
key is spelled in camelCase in the deck: `error.title_empty` →
`errorTitleEmpty`. `test/l10n/arb_test.dart` guards both the spelling and the
domain-key coverage, and `lib/l10n/messages.dart` maps `error.title_empty` to
`errorTitleEmpty` at the presentation boundary.

### Localizations

All user-facing copy lives in `lib/l10n/app_id.arb`. Widgets read it through
`AppLocalizations.of(context)`; the domain never imports Flutter and returns ARB
keys (`error.title_empty`, `import.bad_date`, …) which
`lib/l10n/messages.dart` maps at the presentation boundary. The tests in
`test/l10n/arb_test.dart` fail if a domain key has no deck entry.

## 4. Project layout (§7.2)

```
lib/
  main.dart                     bootstrap, DI assembly, fatal-error screen
  app/                          MaterialApp, providers, theme, home shell
  core/                         database + migrations, clock, time/DST, ids,
                                logging, text normalization, failures, limits
  features/
    memories/                   domain (models, validation, repository port)
                                data (dao, query builder, repository impl)
                                presentation (list, form, detail, widgets)
    reminders/                  domain (model, due grouping, ports)
                                data (dao, repository impl, reconcile)
                                platform (flutter_local_notifications adapter,
                                          notification content policy)
                                presentation (Today, reminder editor)
    backup/                     domain (backup model, import validator)
                                data (serializer, file port, service)
    settings/                   shared_preferences repository + screens
    onboarding/                 first-run screen
  l10n/                         app_id.arb + message-key mapper
```

Rules that the code relies on:

- The database is the truth. An OS notification failure never rolls back or
  deletes a note (principle 3, FR-REM-04).
- Order: persist → schedule → record the delivery fact.
- `overdue` is derived at read time, never stored.
- One reminder per note, enforced by a `UNIQUE(memory_id)` constraint.
- Export/import never carries device-local delivery facts (`notification_id`,
  `scheduling_status`, `schedule_attempt_at_utc`, `schedule_error_code`); fresh
  ids are derived on import from the reminder id.
- No user text in logs, ever. Only codes, counts and timestamps.

## 5. Data and migrations (§7.3, §7.4)

SQLite via `sqflite`, schema version 1, `PRAGMA foreign_keys = ON`,
`journal_mode = WAL`. The DDL enforces the business rules it can: title length,
body cap, category enum, metadata/category consistency, `warranty_end_date`
shape, ISO-8601 UTC timestamps, enum values for reminder status and precision,
and "completed requires `completed_at_utc`".

Migrations live in `lib/core/app_database.dart` as an ordered `kMigrations`
list. Before an upgrade that rewrites data the database file is copied to
`<db>_nanti.pre-migration.db`, an `integrity_check` runs after the migration and
the copy is deleted on success. A database written by a newer build is refused
(`DbVersionTooNewFailure`) instead of being downgraded destructively.

## 6. Notifications (§7.6)

`NotificationScheduler` (port) has one platform implementation:
`LocalNotificationScheduler`, hard-wired to channel id `reminders` — the id is
stable and must never be renamed after release (FR-REM-11).

- Notification ids are derived deterministically from the reminder UUID
  (`int.parse(first8Hex, radix:16) & 0x7FFFFFFF`, `0` remapped to `1`) with a
  linear probe for uniqueness, so a reschedule reuses the same OS slot.
- Exact alarms are used only when the platform grants them
  (`canScheduleExactNotifications`); otherwise scheduling falls back to an
  inexact mode and is recorded as `inexact`. This is a normal path on Android
  14+, not an error.
- `ReconcileService` repairs the OS schedule against the database on launch, on
  resume (throttled to 60 s), after every mutation, after import and after a
  timezone change. It cancels entries for completed reminders and for rows whose
  memory is gone, reschedules anything missing from the OS queue, and keeps at
  most `Limits.scheduleCap` (100) of the nearest reminders scheduled — the rest
  are marked `deferred` for the next pass.
- `hide_notification_content` (default off) replaces the title and body with
  generic copy on the lock screen.
- The port also owns the one OS screen the app cannot draw: `openAppSettings()`
  is answered by `MainActivity.kt` over the `nanti_ingatkan_aku/platform`
  channel. `AppDependencies.notifications` is typed as the port, so widget tests
  substitute the fake and never touch a platform channel.

### Honest limitations

- Delivery is delegated to the OS: it is best-effort and can be delayed,
  especially with inexact alarms or aggressive OEM battery management. The app
  says this in Settings instead of promising punctuality.
- The app cannot claim a notification was delivered. It only records what it
  asked the OS to do.
- Manual export is the only recovery path, precisely because Android auto-backup
  is disabled.

## 7. Backup, import and deletion (§7.8)

Export writes UTF-8 JSON (`nanti-ingatkan-aku-backup-YYYYMMDD-HHmmss.json`) to a
location the user picks, after a warning that the file is not encrypted.

Import is a hard gate: size cap (10 MB) → JSON parse → envelope and
`schema_version` → counts and row caps (20,000) → per-field typing → category
metadata rules → uniqueness → references → reminder enums and dates. An unknown
timezone or an unreadable local datetime is a warning, never fatal. Only after
the whole file validates is the user shown a preview and asked to replace
everything; the swap happens in one transaction with fresh notification ids and
`deferred` scheduling status, and any error rolls the transaction back and leaves
the previous data untouched. Delivery is then recomputed and reported separately
— a scheduling problem never fails an import.

`Hapus semua data` deletes both tables, cancels every notification and clears all
device settings.

## 8. Testing

```bash
flutter test
```

- `test/core/` — DST resolution, notification-id derivation, schema, migrations,
  constraint and downgrade behaviour.
- `test/features/` — validation, search building, reminder lifecycle, reconcile,
  import validation table, export/import round trip including rollback.
- `test/presentation/` — Today grouping, the capture form, and Settings, driven
  through the real localizations and the in-memory database.
- `test/l10n/` — ARB/deck consistency.

Tests use `sqflite_common_ffi` with an in-memory database and fakes for the
scheduler, the file picker and the clock (`test/support/`), so no plugin, device
or network access is needed.

Verified on Flutter 3.47.7 / Dart 3.13.5:

```
$ flutter analyze
No issues found! (ran in 27.9s)

$ dart format --set-exit-if-changed lib test
Formatted 67 files (0 changed) in 0.54 seconds.

$ flutter test
00:32 +202: All tests passed!
```

Widget tests that touch the database must wrap the call in `withDatabase`, or
settle the tree with `settleWithDatabase` (`test/support/widget_env.dart`). A
`testWidgets` body runs in the fake-async zone, which never drains the reply that
`sqflite` sends from its background isolate, so a bare `await deps.memories.count()`
inside a body hangs until the ten-minute test timeout.

## 9. Verified versus unverified

This repository was built and analysed on a machine without an Android SDK, so:

- Verified by tooling: `flutter analyze`, `flutter test`, ARB generation.
- **Unverified, must be checked on a real device**: notification delivery and
  exact-alarm behaviour, permission prompts, behaviour after reboot, timezone
  changes and travel, OEM battery restrictions, TalkBack flows, 48 dp touch
  targets, the file picker (SAF) on device, and the release manifest
  (`INTERNET` removal, `allowBackup=false`) in a built APK.

## 10. Documented deviations from the PRD

1. `SettingsRepository` uses `onboarding_complete`, `hide_notification_content`,
   `last_reconcile_at_utc`, `last_known_timezone`, `last_export_at_utc` and
   `last_backup_nudge_at_utc` as `shared_preferences` keys (a superset of §7.9).
2. Opening the OS app-settings screen needs an `Intent`, which no dependency in
   the stack provides, so `MainActivity.kt` answers a one-method
   `MethodChannel`. The Dart side is covered by tests; the Kotlin side is not
   compiled in this environment (no Android SDK) and must be checked on device.
3. English ARB resources are intentionally absent (DEC-02). The deck and the
   message mapper are ready for a second locale.
4. `scheduling_status` is validated on import only when present, because our own
   exports intentionally omit device-local delivery facts (§7.8 lists it as an
   enum check).
5. No geofencing, sharing, attachments, tags, recurring reminders, themes,
   multi-profile or encryption in v1.0 — out of P0 scope.
6. `delete.confirm` from §5.9 is not shipped: FR-MEM-05 requires the
   confirmation to name the memory, so only `delete.confirm_named` exists.
7. `onboarding.title` is not shipped either; §5.9 names `app.tagline` and the two
   carried identical copy, so the onboarding screen uses `app.tagline`.
8. Every ARB entry is referenced from `lib/`. Copy that the framework already
   announces correctly was dropped rather than duplicated into `Semantics`
   wrappers — a redundant label is worse for TalkBack than none. `a11y.*` now
   holds only `clear_search`, `status_chip` and `open_memory`.
9. ARB resource names are camelCase, not the dotted keys used throughout §5.9,
   because `gen-l10n` rejects anything that is not a Dart identifier
   (`Invalid ARB resource name "app.name"`). Section references to keys such as
   `delete_all.confirm_count` therefore read as `deleteAllConfirmCount` in the
   deck.
10. The Android shell adds three files the PRD does not name: a
    `res/values/strings.xml` so the launcher label is `Nanti Ingatkan Aku`
    instead of the package name, a `data_extraction_rules.xml` so DEC-03 also
    covers API 31+ cloud backup *and* device transfer, and a
    `src/release/AndroidManifest.xml` that strips `INTERNET` from the release
    merge without breaking hot reload in debug.

## 11. License

Private project. Not for redistribution.
