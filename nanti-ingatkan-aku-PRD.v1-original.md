NANTI INGATKAN AKU — PERSONAL MEMORY ASSISTANT
Product Requirements Document + Implementation Blueprint + AI Agent Brief
Version: 1.0 | Status: Proposed | Target: Android-first mobile MVP

======================================================================
0. INSTRUCTIONS FOR THE IMPLEMENTING AI AGENT
======================================================================

You are building a personal, offline-first mobile application called
"Nanti Ingatkan Aku" ("Remind Me Later"). Treat this document as the
product specification, not as a request to implement everything at once.

Before changing code:
1. Inspect the repository, existing work, framework, package manager,
   tests, platform configuration, and any repository-specific instructions.
2. Report your findings, proposed architecture, platform constraints,
   security trade-offs, and a phased implementation plan to the owner.
3. Prefer existing conventions. If no mobile project exists, propose Flutter
   with Dart, SQLite-backed persistence, and Android as the first platform.
   Request approval before introducing the stack into an existing project.
4. Do not overwrite unrelated files or assume paid APIs, credentials, a
   backend, an AI model, or iOS build/signing infrastructure exist.
5. Implement one verifiable vertical slice at a time. Run applicable tests
   and explain what was tested versus what still requires a physical device.
6. If a requirement is impossible in the available environment, explain the
   limitation and propose a working fallback. Do not simulate success.

Priority notation: P0 = required for MVP; P1 = next iteration; P2 = future
experiment. MUST means release-blocking for the specified priority.

======================================================================
1. PRODUCT VISION
======================================================================

Problem: Small but important personal facts are scattered across chat,
screenshots, notes, and memory. People forget warranty deadlines, where an
item was stored, who borrowed a book, or when maintenance is due. Standard
to-do apps focus on actions; note apps focus on writing. Neither reliably
connects personal facts, retrieval, and timely follow-up.

Solution: A private pocket memory that lets a person capture a fact in
seconds, find it later, and optionally attach a reminder. The core loop is:

  Capture -> Organize lightly -> Retrieve or get reminded -> Resolve/retain

Primary user: One person using their own phone. No collaboration or account
is required for the MVP. Default product UI language: Indonesian; keep UI
strings centralized for later localization. This specification is in English.

Product principles:
- Capture is faster than filing. Title/body input and Save are sufficient.
- A saved memory remains useful without a scheduled reminder.
- Reminder delivery is best-effort; the record is always visible in-app.
- Offline use is a first-class requirement, not a degraded fallback.
- Personal data belongs to the user and must be portable.
- Do not claim AI interpretation, OCR, or background delivery that does not
  actually work on the target device.

MVP outcome targets (validate through usability tests, not invented analytics):
- Save a simple memory in <= 30 seconds during a manual usability test.
- Find a stored memory by keyword in <= 15 seconds.
- A fresh install can create, retrieve, edit, and export data without login
  or network access.
- 100% of reminder records remain visible in-app regardless of notification
  permission or delivery status.

MVP non-goals: cloud sync, social features, bank integrations, AI chat,
semantic search, OCR, voice transcription, location triggers, automatic
ingestion of chats/screenshots, background server jobs, and recurring
reminders. These belong to the explicitly prioritized backlog below.

======================================================================
2. CORE USER STORIES AND SCENARIOS
======================================================================

US-01 [P0] As a user, I can quickly save a fact with a title and optional
details, so it is not lost when I need it later.

US-02 [P0] I can classify a memory as General, Borrowed item, Warranty, or
Maintenance; category-specific fields are optional and never block saving.

US-03 [P0] I can attach one scheduled reminder to a memory, choose the date
and local time, and see its current status within the app.

US-04 [P0] I can search titles and details, filter by category, and view
recent records, so retrieval works while offline.

US-05 [P0] I can mark a reminder done, leave the underlying memory intact,
edit or reschedule it, and delete it intentionally if no longer relevant.

US-06 [P0] I can export my data and import it on a fresh install after
reviewing what will be replaced, so the app remains usable long-term.

US-07 [P0] When notification permission is denied or scheduling fails, I
still see due/overdue reminders inside the app and understand the limitation.

Examples:
- "Warranty for my laptop ends 12 Dec 2027" -> Warranty memory + reminder.
- "I lent a book to Rina" -> Borrowed item memory; optional follow-up date.
- "The spare charger is in the blue drawer" -> General memory; no reminder.
- "Check AC filter in three months" -> Maintenance memory + reminder.

======================================================================
3. MVP INFORMATION ARCHITECTURE AND UX
======================================================================

Bottom navigation (or equivalent accessible mobile navigation):
- Today: due today, overdue, upcoming reminders, and one-tap Quick Capture.
- Memories: searchable list with category filters and archive visibility.
- Settings: notification health, export/import, privacy, and about.

Memory detail: title, body, category, optional structured metadata, created
and updated timestamps, reminder state, Edit, Archive, and Delete actions.

Capture flow: from Today or Memories -> title -> optional detail/category/
reminder -> Save -> memory detail or list with clear success feedback. Do not
force category selection; General is the default. Preserve draft content on
validation failure or accidental navigation where feasible.

Today grouping: Overdue (scheduled time < now, not done), Today (local date
is today, not done), Upcoming (future local dates), with stable ordering by
scheduled instant then ID. Completed reminders do not appear as actionable.
Show honest empty states; a fresh install should explain what to save first.

Search: case-insensitive keyword search over title and body with predictable
matching. Optional category filter composes with search. No fake AI search.
List items include category, concise excerpt, and reminder status, if any.

Interaction rules: 44 x 44 logical-pixel minimum touch targets; legible
text; screen-reader labels; visible errors and focus order; support dynamic
font scaling without clipped controls. Support dark mode if provided by the
chosen framework without delaying core functionality.

======================================================================
4. FUNCTIONAL REQUIREMENTS
======================================================================

4.1 Memory lifecycle [P0]
- Create, read, update, archive/unarchive, and delete a memory offline.
- Required: nonblank title (1-120 characters after trimming). Optional:
  body (<= 10,000 characters). Reject invalid values with inline feedback.
- Categories: general, borrowed_item, warranty, maintenance. Metadata is
  optional: person_name for borrowed_item; warranty_end_date for warranty;
  item_name for borrowed_item/warranty/maintenance. Metadata never generates
  a reminder silently; users explicitly choose a reminder date and time.
- Deletion requires confirmation and also cancels associated scheduled
  notifications. Archive removes an item from the default list but retains
  it in search when archived items are explicitly included.
- Plain user text only; no raw HTML rendering or executable content.

4.2 Reminder lifecycle [P0]
- A memory has zero or one active one-time reminder in the MVP. One-time
  reminders can be edited, rescheduled, completed, or removed.
- The user chooses a future local date/time via a date/time picker. Store
  an absolute due instant (UTC), the IANA timezone used at scheduling, and
  the originally chosen local date/time for faithful display/recovery.
- Timezone policy: the scheduled instant remains fixed after travel or a
  device timezone change; display it in the device's current local timezone
  with a clear label if it differs from the original timezone. Editing the
  reminder uses the currently selected device timezone.
- On save/edit/delete, update local persistence first and reconcile the OS
  notification schedule. A scheduling failure must NOT erase the reminder.
  Surface a clear status: scheduled, permission_needed, or scheduling_failed.
- Use stable notification identifiers derived from stored reminder IDs so
  rescheduling replaces the previous notification instead of duplicating it.
- At app launch/foreground, compare pending reminders with stored records
  and repair scheduling when the platform allows it. Explain any Android
  reboot/OS scheduling limitations; test reboot persistence on-device.
- When the scheduled time passes, an incomplete reminder is due/overdue
  even if no notification was delivered. Completing it cancels any pending
  OS notification. No claim of guaranteed delivery or exact alarm timing.
- Request notification permission in context, when the user first schedules
  a reminder. If denied, continue saving and show a path to system settings.
- Platform-specific notification channels and Android exact-alarm policies
  must be checked against the actual target SDK; prefer compliant best-effort
  scheduling and document precision limits. No background location access.

4.3 Data portability [P0]
- Export a versioned UTF-8 JSON snapshot containing memories, metadata, and
  reminders; include schema_version and exported_at. No photos/files in MVP.
- User explicitly chooses the export destination via the platform share/
  document picker. Warn that the exported file is unencrypted and sensitive.
  Do not silently upload or send it anywhere.
- Import validates the schema, size limit, references, enums, field lengths,
  and dates before modifying existing data. Show counts and a confirmation
  that import REPLACES current data. Perform replacement atomically; if
  validation or persistence fails, original data remains untouched.
- Preserve stable IDs and reminder states; recompute notification scheduling
  from imported records. Import may report scheduling warnings separately.
- Document how to back up and restore, including export privacy risks.

4.4 Settings and diagnostics [P0]
- Display whether notifications are enabled and whether any reminder needs
  attention due to permission or scheduling failure.
- Provide export/import actions and a short, clear data-privacy explanation.
- Do not log memory titles, bodies, exported data, or notification text in
  production diagnostics. Avoid third-party analytics and remote services.

======================================================================
5. TECHNICAL BLUEPRINT
======================================================================

Recommended starting point IF the repository is empty: Flutter/Dart,
Android-first, local SQLite, explicit schema migrations, repository layer,
and platform local-notification integration. The implementing agent must
confirm maintained package compatibility and OS requirements before picking
packages. Do not claim iOS support without an iOS build and device tests.

Suggested boundaries (adapt to established repo conventions):
- presentation: screens, reusable components, view state, localization;
- domain: Memory/Reminder entities, validation, due-state calculations;
- data: SQLite schema, migrations, repositories, import/export;
- platform: notification permission, scheduling, document picker, clock/
  timezone adapters.

Data model (conceptual; choose concrete SQL types in migration):

memories:
  id TEXT PRIMARY KEY (UUID or equivalent locally generated stable ID)
  title TEXT NOT NULL
  body TEXT NOT NULL DEFAULT ''
  category TEXT NOT NULL CHECK in allowed categories
  item_name TEXT NULL
  person_name TEXT NULL
  warranty_end_date TEXT NULL (ISO calendar date)
  is_archived INTEGER NOT NULL DEFAULT 0 CHECK in (0,1)
  created_at_utc TEXT NOT NULL (ISO 8601)
  updated_at_utc TEXT NOT NULL (ISO 8601)

reminders:
  id TEXT PRIMARY KEY
  memory_id TEXT NOT NULL UNIQUE REFERENCES memories(id) ON DELETE CASCADE
  due_at_utc TEXT NOT NULL (ISO 8601)
  scheduled_local_datetime TEXT NOT NULL (ISO local datetime)
  scheduled_timezone TEXT NOT NULL (IANA zone)
  status TEXT NOT NULL CHECK in ('pending','completed')
  scheduling_status TEXT NOT NULL CHECK in
    ('scheduled','permission_needed','scheduling_failed')
  completed_at_utc TEXT NULL
  created_at_utc TEXT NOT NULL
  updated_at_utc TEXT NOT NULL

Index reminders(status, due_at_utc), memories(is_archived, updated_at_utc).
Search may use parameterized LIKE for a small personal dataset; evaluate an
SQLite FTS index later if performance warrants it. Always escape search
metacharacters deliberately and use bound parameters.

Single source of truth: SQLite records. Derived due/overdue status is
computed from pending + due_at_utc + current time; do not persist an
"overdue" flag that can become stale. OS notifications are a replaceable
delivery channel, never the authoritative record. Repository operations
should be transactional where deleting/importing multiple records.

Privacy/security baseline: local-only storage in the application sandbox;
no network permission unless justified by an approved feature. Verify the
platform backup policy (automatic cloud/device backup) and document or
configure it explicitly rather than implying "local-only" if OS backup is
enabled. Consider database encryption and app lock as P1 after evaluating
key management, recovery, and device support; NEVER describe an unencrypted
SQLite database or JSON export as end-to-end encrypted.

Time/testability: inject a clock into reminder calculations, keep UTC and
IANA zone conversions in a dedicated module, and test DST gap/overlap and
device-timezone changes. Never store only a formatted date string as the
reminder authority.

======================================================================
6. NON-FUNCTIONAL REQUIREMENTS
======================================================================

- Offline: all P0 workflows except OS permission/settings operate in
  airplane mode; no backend account or API key.
- Durability: data survives app restart and device reboot; database
  migrations preserve existing memories. Export/import handles reinstalls.
- Performance: quick capture ready promptly on a mid-range Android phone;
  a 1,000-memory dataset searches and scrolls without noticeable stalls.
  Measure actual timings rather than claiming unverified benchmarks.
- Reliability: no duplicate notification for the same reminder after
  editing/reconciliation; scheduling errors are visible and retryable.
- Accessibility: semantic labels, keyboard navigation where applicable,
  screen-reader readable status, adequate contrast, scalable typography.
- Security: validate imported data, constrain export size/import size,
  parameterize SQL, and do not expose sensitive data in crash/log output.
- Maintainability: migration tests, unit tests for domain rules, and a
  concise README for local development, backup behavior, and limitations.

======================================================================
7. IMPLEMENTATION MILESTONES
======================================================================

Phase 0 — Discovery and design gate: inspect repo; report architecture,
supported Android version, dependency choices, OS notification constraints,
security/backup policy, and any open decisions. Await owner approval for
major stack changes.

Phase 1 — Vertical slice: app shell -> create memory -> local persistence ->
list/detail -> restart and verify. Include migration setup and initial tests.

Phase 2 — Retrieval: edit/archive/delete, category metadata, keyword search,
filters, empty/error states, accessibility pass.

Phase 3 — Reminders: date/time scheduling, permission UX, Today grouping,
complete/reschedule/delete, reconciliation, timezone and device tests.

Phase 4 — Portability and release readiness: JSON export/import with atomic
replace, migrations, full regression tests, privacy copy, README, Android
release checklist and physical-device validation.

At each phase: summarize changes, commands/tests actually run, failures,
remaining risks, and the smallest next milestone. Do not mark an item done
solely because code compiles.

======================================================================
8. ACCEPTANCE CRITERIA / TEST MATRIX
======================================================================

AC-01: In airplane mode, create a General memory with just a title. After
force-close/relaunch, it appears in Memories and is searchable by title.

AC-02: Save an optional body and category metadata; edit them and verify
the changes persist after app restart.

AC-03: A memory with no reminder appears in search but not in Today.

AC-04: Schedule a reminder for the near future with permission granted;
verify a real local notification on an Android device, and verify the record
appears in Today even if the notification is dismissed.

AC-05: With permission denied, the reminder still saves, the UI reports
permission_needed, and it becomes due/overdue in Today at the right time.

AC-06: Rescheduling a reminder leaves one pending OS notification for that
reminder where inspection is supported; removing/completing it cancels the
pending notification and does not delete the memory.

AC-07: Archive hides an item from the default list but preserves it in
explicit archived search; deleting an item requires confirmation and also
removes its reminder.

AC-08: Search is case-insensitive, composes with category filters, and
handles empty input and special characters without errors/injection.

AC-09: Export on one installation, import on a clean installation, and
compare IDs, titles, metadata, and reminder statuses. Import of corrupted
or unsupported JSON leaves existing data unchanged.

AC-10: A timezone change does not alter the scheduled UTC instant; display
is correct for the device timezone. Unit tests cover a DST boundary.

AC-11: Migrations upgrade an older local database without data loss; no
external API, sign-in, or connectivity is needed for the P0 flows.

AC-12: Core capture, search, edit, and reminder flows are usable with a
screen reader and enlarged system text. No nonfunctional primary controls.

AC-13: Notification behavior after reboot and on the target Android SDK is
tested on a device or explicitly documented as unverified, not assumed.

======================================================================
9. EXPERIMENTAL BACKLOG (NOT MVP COMMITMENTS)
======================================================================

P1: Recurring reminders with explicit calendar rules and occurrence IDs;
camera/OCR-assisted capture with review before saving; secure attachment
storage and export; optional app lock and evaluated database encryption;
home-screen widget; natural-language parsing of dates with mandatory user
confirmation; SQLite FTS and saved search filters.

P2: On-device semantic retrieval with an opt-in model and measurable
battery/storage footprint; voice capture/transcription with clear privacy
controls; location-based reminders with explicit permissions; end-to-end
encrypted multi-device sync with conflict resolution; plugin/automation API.

Experiment rule: prototype behind a feature flag or separate branch, with
the user in control. Never let an experimental parser or AI silently change
a reminder's date or export private records.

======================================================================
10. QUESTIONS TO RESOLVE WITH THE OWNER BEFORE PHASE 1
======================================================================

1. Is Android-only acceptable for the first release, or is iOS required?
2. Is Indonesian the preferred launch UI language?
3. Should OS-level device backup be disabled, enabled with disclosure, or
   left as a documented platform-dependent setting?
4. Is unencrypted JSON export with an explicit warning acceptable for MVP,
   or is encrypted backup a release blocker?
5. What is the minimum supported Android version and is there an existing
   repository/stack that should take precedence over the suggested Flutter
   starting point?

If answers are unavailable, proceed only with reversible design work and
state the assumptions. Do not silently make security-sensitive decisions.
