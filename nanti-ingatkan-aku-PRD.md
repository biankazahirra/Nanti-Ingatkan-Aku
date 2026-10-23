# NANTI INGATKAN AKU

**Personal Memory Assistant — Product Requirements Document, Technical Blueprint, and AI Agent Brief**

| Field | Value |
| --- | --- |
| Document version | 2.0 |
| Status | Draft for owner approval (supersedes v1.0) |
| Last updated | 2026-10-23 |
| Product | "Nanti Ingatkan Aku" ("Remind Me Later") |
| Platform (MVP) | Android, offline-first |
| Product UI language | Indonesian (`id-ID`), architected for later localization |
| Spec language | English |
| Owner | *(to be filled)* |
| Implementer | AI coding agent + human reviewer |
| Supersedes | `nanti-ingatkan-aku-PRD.v1-original.md` |

---

## 0. Document control

### 0.1 Changelog

| Version | Date | Summary |
| --- | --- | --- |
| 1.0 | — | Initial PRD / blueprint / agent brief. |
| 2.0 | 2026-10-23 | Restructured into testable Markdown. Added executive summary, personas, measurable success criteria, requirement IDs, per-requirement acceptance rules, concrete SQLite DDL, notification state machine and Android policy handling, search algorithm, import/export schema with limits, accessibility and performance budgets, device test matrix, risk register, and a decision log with default assumptions. Fixed: category naming (`borrowed_item` → `lent_item`), touch-target size (44 → 48 dp), single-reminder lifecycle dead-end, SQLite case-insensitivity claim, missing notification deep link, missing notification-content privacy control, missing delete-all-data, undefined DST/archive/import edge cases. |

### 0.2 How to read this document

- **P0** = required for MVP. **P1** = next iteration. **P2** = future experiment.
- **MUST** = release-blocking at its stated priority. **SHOULD** = strongly expected; deviation needs a recorded reason. **MAY** = optional.
- Requirement IDs are stable (`FR-MEM-03`, `NFR-PERF-02`, `AC-09`, `RSK-04`, `DEC-07`). Cite them in commits, tests, and status reports.
- The tag **`[verify]`** marks a claim that depends on the target Android SDK, device, or package version. It must be confirmed on a real device before it is reported as working.
- Every requirement should map to at least one acceptance check in §9.4.

### 0.3 Instructions for the implementing AI agent

You are building a personal, offline-first Android app. Treat this document as the product specification. It is intentionally explicit about scope, data, and failure behavior; follow it and record deviations.

**Before changing code**

1. Inspect the repository, existing work, framework, package manager, tests, CI, Android manifest, and any repository-specific instructions.
2. Report: findings, proposed architecture, platform constraints (min/target SDK), security and backup trade-offs, dependency choices, and a phased plan.
3. Prefer existing conventions. If the repository is empty, bootstrap **Flutter + Dart + sqflite** (§7.1) and request approval before introducing any other stack.
4. Never assume a backend, paid API, AI model, credentials, or iOS signing exists.
5. Implement one verifiable vertical slice at a time. Run the checks that actually exist (`flutter analyze`, `flutter test`, integration tests) and report real output.

**Guardrails**

- Do **not** add network permission, analytics, crash-reporting SDKs, or remote services without explicit owner approval (see `DEC-10`).
- Do **not** perform a destructive database migration without a backup path and a migration test.
- Do **not** invent metrics, benchmarks, test results, or device validation.
- Do **not** claim "exact", "guaranteed", "encrypted", "AI", or "OCR" behavior that the build does not provide.
- Do **not** store memory text, notification text, or exported payloads in logs.
- Stop and ask when a decision is security-sensitive, irreversible, or changes the product scope.

**Definition of done for every deliverable**

- [ ] `flutter analyze` passes with no new warnings.
- [ ] `dart format` applied; new unit/widget tests added and passing.
- [ ] Any schema change ships with a migration and a migration test.
- [ ] UI strings live in ARB files (no hardcoded user-facing text).
- [ ] Touch targets ≥ 48 dp; semantics labels present; usable at 200% font scale.
- [ ] No PII in logs or error messages.
- [ ] New `[verify]` items recorded as pending device checks, not silently assumed.
- [ ] README / CHANGELOG updated if behavior or setup changed.

**Required report format at the end of each phase**

1. What changed (files/areas) and why.
2. Commands run and their actual results.
3. Tests passing, failing, or not written — with reasons.
4. What was verified on a physical device vs. what remains unverified.
5. Risks, unknowns, and deviations from this PRD.
6. The smallest next milestone.
7. Decisions needed from the owner.

---

## 1. Executive summary

**Nanti Ingatkan Aku** is a private pocket memory for one person. It captures a small but important fact in seconds ("the spare charger is in the blue drawer", "Rina borrowed the book", "laptop warranty ends 12 Dec 2027"), makes it findable offline, and optionally attaches a one-time reminder.

**The product bet:** people do not need another to-do list or note hierarchy. They need *fast capture + reliable retrieval + optional follow-up*, with the record remaining authoritative even when a notification never arrives.

**MVP boundary:** Android, local-only, one-time reminders, four categories, keyword search, JSON export/import. No accounts, no cloud, no AI, no OCR, no recurring reminders, no collaboration.

**Top risks:** Android notification delivery on OEM devices; exact-alarm policy changes; data loss during import; scope creep toward AI features; storage privacy vs. OS auto-backup.

**What makes v2.0 different:** every P0 requirement is now testable, the data model is concrete, notification failure modes are specified, and open questions have default decisions so implementation can start without guessing.

---

## 2. Problem, users, and principles

### 2.1 Problem

Important personal facts are scattered across chat threads, screenshots, notes, and memory. People forget warranty deadlines, where an item was stored, who borrowed a book, or when maintenance is due. To-do apps optimize for actions; note apps optimize for writing. Neither reliably connects *a personal fact*, *retrieval*, and *a timely follow-up*.

Current workarounds fail in predictable ways:

- Chat search is noisy and the fact scrolls away.
- Screenshots are unsearchable text.
- Notes apps store the fact but never remind.
- Reminder apps store the reminder but lose the context.

### 2.2 Users

**Primary persona — "Rina, 29, urban professional"**
Lives on her phone, has 30–80 small facts in flight (warranties, loans, service dates, storage locations), avoids complex apps, and will abandon anything that needs an account or more than a few taps. Device: mid-range Android (4 GB RAM, Android 13). Network: often offline or metered. Privacy expectation: "my notes are mine; do not upload them."

**Secondary persona — "Budi, 45, household manager"**
Tracks appliance warranties, AC service, and items lent to family. Low tolerance for configuration. Wants a printed/exported copy before switching phones.

**Anti-persona (explicitly not served in MVP)**
Teams, shared households, project managers, users who want AI chat over their notes, users who need server-side integrations.

### 2.3 Jobs to be done

| # | Job | Current workaround | MVP answer |
| --- | --- | --- | --- |
| JTBD-1 | "When I learn a small fact, I want to save it in seconds before I forget." | Screenshot, chat to self | Title-first capture, Save in ≤ 3 interactions |
| JTBD-2 | "When I need the fact later, I want to find it by a word I remember." | Scroll chats, scroll gallery | Offline keyword search across title + body |
| JTBD-3 | "When a deadline matters, I want to be reminded without managing a system." | Mental note, calendar event | One optional dated reminder per memory |
| JTBD-4 | "When I switch or reset my phone, I want my facts back." | Manual copy, loss | Versioned JSON export/import |
| JTBD-5 | "When a notification fails, I still want to see what is due." | None | Due/overdue state always visible in-app |

### 2.4 Product principles (tie-breakers)

1. **Capture beats filing.** A title and Save are sufficient; everything else is optional.
2. **A memory is useful without a reminder.** Reminders are an attachment, never the record.
3. **The database is the truth; notifications are a channel.** Delivery failure must never lose or hide a record.
4. **Offline is the default state.** No feature may require connectivity.
5. **Honest UI.** No fake precision, no fake AI, no hidden uploads, no silent data replacement.
6. **User data is portable.** Export must always work without a server or account.
7. **When in doubt, do less and say so.** Prefer a documented limitation over an unreliable promise.

---

## 3. Goals, success metrics, non-goals

### 3.1 MVP goals

- G1: Capture a simple memory in ≤ 30 seconds (observed, not instrumented).
- G2: Retrieve a known memory by keyword in ≤ 15 seconds.
- G3: Never lose a memory because a notification failed or a permission was denied.
- G4: Allow a full export → wipe → import round trip with identical content.
- G5: Ship an app that a non-technical Indonesian speaker can use without a tutorial.

### 3.2 Success metrics and how they are measured

The MVP ships **without analytics** (`DEC-10`). Metrics are measured in moderated usability sessions and release-build device checks, not in production telemetry.

| ID | Metric | Target | Method |
| --- | --- | --- | --- |
| M-01 | Time to save a title-only memory | Median ≤ 30 s, all participants ≤ 60 s | Stopwatch, 5–8 participants, first-time users |
| M-02 | Time to find a stored memory by keyword | Median ≤ 15 s | Same session, 3 pre-seeded facts |
| M-03 | Task success rate (save, find, remind, complete, export, import) | ≥ 90% unassisted | Moderated script, 6 tasks |
| M-04 | Reminder records visible in-app | 100% of pending/overdue records | Device test with permission denied, notification dismissed, reboot |
| M-05 | Offline completeness | 100% of P0 flows work in airplane mode | Device test checklist |
| M-06 | Search latency | ≤ 100 ms at 1,000 memories | Release build, reference device |
| M-07 | Cold start to interactive Today | ≤ 2.0 s | Release build, reference device, 5 runs, median |
| M-08 | Crash-free device soak | 0 unhandled exceptions in 72 h of normal use | Manual soak, debug log reviewed locally |
| M-09 | Accessibility | All P0 tasks completable via TalkBack at 200% text scale | Manual device pass |

Reference device for M-06/M-07: mid-range 2022–2023 Android (≈ Snapdragon 680, 4 GB RAM, Android 13) or the closest available device, recorded in the test report.

### 3.3 Non-goals (MVP)

Cloud sync, accounts, collaboration, sharing, social features, bank or e-commerce integrations, AI chat, semantic search, OCR, voice transcription, location triggers, automatic ingestion of chats/screenshots, background server jobs, recurring reminders, multiple reminders per memory, attachments, encryption at rest, app lock, iOS support. These are backlog items (§4.2), not silent omissions.

---

## 4. Scope

### 4.1 MVP cut line

| Area | In MVP (P0) | Out of MVP |
| --- | --- | --- |
| Capture | Title, optional body, 4 categories, optional metadata | Photos, files, voice, OCR |
| Organisation | Recent list, archive, category filter, keyword search | Tags, folders, nested notebooks |
| Reminders | One one-time reminder per memory, quick presets, edit, complete, cancel | Recurrence, snooze, multiple reminders, location |
| Today | Overdue / Today / Next 7 days, tap-through to detail | Calendar view, drag-to-reschedule |
| Delivery | Local notification, in-app due state, health diagnostics | Push, server, guaranteed delivery |
| Data | Local SQLite, JSON export, atomic replace import, delete all | Merge import, cloud backup, encryption |
| Settings | Notification health, privacy content toggle, about, export/import | Theming engine, accounts, sync |
| Platforms | Android | iOS, web, desktop |

### 4.2 Backlog (not MVP commitments)

| Priority | Item | Why later |
| --- | --- | --- |
| P1 | Snooze (1 hour / tonight / tomorrow 09:00) | High user value, but needs its own state rules; MVP "reschedule" covers the need |
| P1 | Recurring reminders with occurrence IDs | Requires schema change from one-reminder-per-memory |
| P1 | Multiple reminders per memory | Same as above; MVP `UNIQUE(memory_id)` is intentional |
| P1 | Encrypted export (password-based) | Key management and recovery UX needed |
| P1 | App lock (biometric) + `FLAG_SECURE` | Privacy hardening after core flows |
| P1 | Database encryption (SQLCipher + Keystore) | Migration and recovery risk |
| P1 | Home-screen widget / quick-capture shortcut | Platform work, not core loop |
| P1 | Attachments with secure storage and export | Storage lifecycle and size limits |
| P1 | Merge-mode import | Needs conflict rules and ID remapping |
| P1 | SQLite FTS5 + saved searches | Only if M-06 fails at realistic dataset |
| P1 | Natural-language date parsing with mandatory confirmation | Risk of silently wrong dates |
| P2 | On-device semantic retrieval (opt-in model) | Battery/storage cost, evaluation burden |
| P2 | Voice capture / transcription | Permission and privacy surface |
| P2 | Location-based reminders | Background location policy |
| P2 | E2EE multi-device sync | Server, key management, conflicts |
| P2 | Automation / plugin API | No ecosystem yet |
| P2 | iOS release | Requires build, signing, and device tests |

**Experiment rule:** prototype behind a feature flag or separate branch. An experimental parser or model may **never** silently change a reminder date or export private records.

---

## 5. Information architecture and UX

### 5.1 Navigation map

```
App
├── Onboarding (first run only)
│   ├── "Mulai" → Today
│   └── "Pulihkan dari cadangan" → Import flow
├── Today (default tab)
│   ├── Overdue
│   ├── Today
│   ├── Next 7 days → "Lihat semua" (Upcoming list)
│   └── FAB "+ Catat" → Capture
├── Catatan (Memories)
│   ├── Search field
│   ├── Category filter chips
│   ├── Archived toggle
│   └── Memory detail → Edit / Archive / Delete
├── Capture (full screen or bottom sheet)
│   └── Save → Memory detail
└── Pengaturan
    ├── Notification health (permission, exact alarm, channel, battery guidance)
    ├── Privacy (hide notification content, privacy statement, delete all data)
    ├── Backup (export, import)
    ├── About (version, licenses, schema version)
    └── Diagnostics (counts, last reconcile, scheduling failures — no content)
```

Three bottom tabs maximum. Settings is never required for the core loop.

### 5.2 Screen inventory

| Screen | Purpose | Required states |
| --- | --- | --- |
| Onboarding | Explain value, offer restore | Default only |
| Today | Act on what is due | Empty, populated, permission warning banner |
| Memories | Retrieve | Empty, list, searching, no results, archived mode |
| Capture | Create | Empty, validation error, saving, save failed |
| Memory detail | Read, act | Default, reminder pending/completed/overdue, archived |
| Edit | Update | Default, validation error, save failed |
| Import preview | Confirm destructive action | Valid file, invalid file, oversize file, confirming, importing, failed |
| Settings | Health and portability | Default, permission needed, scheduling failures present |
| Diagnostics | Support without PII | Default |

### 5.3 Core flows

**F1 — Quick capture (target ≤ 30 s, ≤ 3 primary interactions)**

1. Tap FAB `+ Catat`.
2. Type a title (autofocus, keyboard open, counter appears after 100 characters).
3. Tap `Simpan`. Category defaults to `Umum`; body and reminder are optional.
4. App writes to SQLite, then shows detail with a `Tersimpan` confirmation.

Failure: validation error keeps all entered text and focus on the invalid field. A persistence error shows `Gagal menyimpan. Coba lagi.` and keeps the draft.

**F2 — Capture with reminder**

`+ Catat` → title → `Ingatkan aku` → presets (`1 jam lagi`, `Nanti malam 20.00`, `Besok 09.00`, `Minggu depan`) or `Pilih tanggal & waktu` → Save.

The notification permission is requested **at this moment**, after the user has expressed intent, with a pre-permission rationale dialog. Denial never blocks saving.

**F3 — Retrieve**

`Catatan` → type query → results update after 150 ms debounce → tap result. Category chips and the archived toggle compose with the query. Clearing the query restores the recent list.

**F4 — Complete a reminder**

Today → tap item → `Tandai selesai` → reminder status `completed`, OS notification cancelled, memory stays intact. Undo is offered for 5 seconds via snackbar and restores `pending` with the same due time **and reschedules the notification**.

**F5 — Reschedule**

Detail → `Ubah pengingat` → picker (pre-filled with the current local time) → Save → single OS notification replaced by the same notification ID.

**F6 — Archive**

Detail → `Arsipkan` → hidden from the default Memories list. If a pending reminder exists, a confirmation explains: `Pengingat tetap aktif dan tetap muncul di Hari Ini.` Archive never silently cancels a reminder (`DEC-08`).

**F7 — Delete**

Detail → `Hapus` → dialog naming the memory and stating that its reminder is deleted too → confirm → cascade delete + cancel notification. No undo for delete.

**F8 — Export**

Settings → `Ekspor cadangan` → privacy warning → system save/share picker → file written → confirmation with the file name. If writing fails or the user cancels, no partial file is left behind and the app reports `Ekspor dibatalkan` or `Gagal mengekspor.`

**F9 — Import**

Settings → `Impor cadangan` → system file picker → validation + preview counts (`24 catatan, 9 pengingat`) → explicit replace confirmation → atomic transaction → success summary + separate scheduling warnings.

**F10 — Notification tap**

Tap notification (warm or cold start) → memory detail for that reminder. If the memory was deleted meanwhile, open Today with `Catatan ini sudah dihapus.`

### 5.4 Today specification

Definitions use the device's current local timezone and calendar date.

| Group | Rule | Order |
| --- | --- | --- |
| Terlewat | `status = pending` and `due_at_utc < now` | Oldest due first |
| Hari ini | `status = pending` and local date of `due_at_utc` = today and `due_at_utc >= now` | Earliest due first |
| 7 hari ke depan | `status = pending` and local date in (today, today + 7] | Earliest due first |
| (hidden) | `status = completed`, or memory archived with no pending reminder | — |

- Rows show: title, category label, due time (`HH.mm` for today, `Sen, 12 Des` otherwise), status chip, and an `Diarsipkan` badge when the memory is archived.
- Archived memories with a pending reminder **do** appear in Today (their reminder is still active). This is deliberate and must be tested (AC-07).
- Completed reminders never appear as actionable; they are shown on the memory detail as `Selesai pada …`.
- Empty state copy: `Belum ada yang perlu diingat hari ini.` with a secondary `Catat sesuatu` action.
- A permission banner appears when any pending reminder has `scheduling_status` of `permission_needed` or `scheduling_failed`, linking to Settings.
- The list refreshes on resume and every 60 s while visible; time-based regrouping is recomputed from the injected clock, never cached as a stored flag.

### 5.5 Memories specification

- Default view: non-archived memories, `updated_at_utc` descending, paginated 50 at a time.
- Search: tokens ANDed across `title_norm` and `body_norm` (§7.7). Result order: title matches first, then `updated_at_utc` descending, then `id` ascending for determinism.
- Filters: category chips (`Semua`, `Umum`, `Dipinjamkan`, `Garansi`, `Perawatan`) plus an `Arsip` toggle. Filters compose with search. Archived memories appear only when the toggle is on; there is no implicit global archived search. Filter state survives tab switches during the session but is not persisted after restart.
- Row content: title (max 2 lines), body excerpt (max 1 line), category, relative reminder status, archived badge.
- Empty states: no memories at all → `Belum ada catatan. Mulai dari hal kecil yang mudah lupa.`; no search results → `Tidak ada hasil untuk "<query>".`; empty archive → `Belum ada catatan yang diarsipkan.`
- The list must remain usable with the keyboard open and at 200% text scale.

### 5.6 Memory detail specification

Shows: title, body (preserving line breaks), category, category metadata, created/updated timestamps (local, `id-ID` format), reminder block, and actions: `Ubah`, `Ubah pengingat` (or `Buat pengingat`), `Tandai selesai`, `Arsipkan`, `Hapus`.

Reminder block states:

| State | Display |
| --- | --- |
| No reminder | `Belum ada pengingat.` + `Buat pengingat` |
| Pending, scheduled | `Terjadwal Sen, 12 Des 2027 • 20.00` + precision note when inexact: `Perkiraan waktu (bisa terlambat beberapa menit).` |
| Pending, permission needed | `Perlu izin notifikasi` + `Buka pengaturan` |
| Pending, scheduling failed | `Gagal dijadwalkan` + `Coba lagi` |
| Pending, deferred | `Menunggu penjadwalan` (rare; reconcile will schedule it) |
| Pending, overdue | `Terlewat sejak Sen, 12 Des 2027 • 20.00` |
| Completed | `Selesai pada …` + `Buat pengingat baru` |
| Timezone differs | Extra line: `Diatur pada zona Asia/Jakarta; perangkat sekarang di Asia/Tokyo.` |

### 5.7 Capture specification

- Title field: required, autofocus, `Apa yang ingin kamu ingat?`, 1–120 user-perceived characters (`characters` package), counter after 100.
- Body field: optional, multiline, ≤ 10,000 characters, `Detail (opsional)`.
- Category: segmented chips, default `Umum`. Selecting a category reveals only its optional fields:
  - `Dipinjamkan` → `Dipinjamkan ke` (person, ≤ 80 chars), `Nama barang` (≤ 120 chars).
  - `Garansi` → `Nama barang` (≤ 120 chars), `Garansi berakhir` (calendar date).
  - `Perawatan` → `Nama barang` (≤ 120 chars).
- Reminder: collapsed by default (`Ingatkan aku` switch/row). Enabling shows four presets and a `Pilih tanggal & waktu` picker.
- Save is enabled only when the title is non-blank; invalid attempts show inline messages and never discard input.
- Draft protection: if the user navigates back with unsaved content, show `Buang catatan ini?` with `Lanjutkan menulis` / `Buang`. Survive app backgrounding to a draft in memory (not persisted across process death — documented limitation).
- Past reminder times are rejected: `Waktu pengingat harus di masa depan.` Presets are computed from the injected clock.

### 5.8 Accessibility and interaction rules

- Minimum touch target 48 × 48 dp (Android/Material), with ≥ 8 dp spacing between adjacent targets.
- Body text ≥ 14 sp, primary content ≥ 16 sp; layout must survive 200% font scale and display size changes.
- Contrast ≥ 4.5:1 for body text, ≥ 3:1 for large text and UI boundaries.
- Every icon-only control has a `semanticLabel`; status is never conveyed by color alone (chip includes text).
- TalkBack order follows visual order; dialogs trap focus; the first invalid field receives focus after validation.
- Snackbars are announced politely; destructive confirmations are reachable without gestures.
- Reduce-motion is respected where animations exist.
- No interaction requires a long-press, swipe, or drag in MVP.
- All user-facing strings come from ARB files (Indonesian first). Dates use `intl` with `id_ID`.

### 5.9 Copy deck (Indonesian, source of truth for ARB)

| Key | Copy |
| --- | --- |
| `app.name` | Nanti Ingatkan Aku |
| `app.tagline` | Simpan hal kecil sebelum lupa. |
| `nav.today` | Hari Ini |
| `nav.memories` | Catatan |
| `nav.settings` | Pengaturan |
| `capture.title_hint` | Apa yang ingin kamu ingat? |
| `capture.body_hint` | Detail (opsional) |
| `capture.remind_me` | Ingatkan aku |
| `capture.save` | Simpan |
| `capture.saved` | Catatan tersimpan |
| `category.general` | Umum |
| `category.lent_item` | Dipinjamkan |
| `category.warranty` | Garansi |
| `category.maintenance` | Perawatan |
| `field.lent_to` | Dipinjamkan ke |
| `field.item_name` | Nama barang |
| `field.warranty_end` | Garansi berakhir |
| `reminder.preset_1h` | 1 jam lagi |
| `reminder.preset_tonight` | Nanti malam (20.00) |
| `reminder.preset_tomorrow` | Besok (09.00) |
| `reminder.preset_week` | Minggu depan |
| `reminder.pick` | Pilih tanggal & waktu |
| `reminder.scheduled` | Terjadwal |
| `reminder.inexact` | Perkiraan waktu (bisa terlambat beberapa menit). |
| `reminder.permission_needed` | Perlu izin notifikasi |
| `reminder.failed` | Gagal dijadwalkan |
| `reminder.overdue` | Terlewat |
| `reminder.done` | Selesai |
| `reminder.mark_done` | Tandai selesai |
| `error.title_empty` | Judul tidak boleh kosong. |
| `error.title_too_long` | Judul maksimal 120 karakter. |
| `error.body_too_long` | Detail maksimal 10.000 karakter. |
| `error.due_past` | Waktu pengingat harus di masa depan. |
| `error.save_failed` | Gagal menyimpan. Coba lagi. |
| `permission.rationale` | Supaya pengingat muncul, izinkan notifikasi. Catatanmu tetap tersimpan tanpa izin ini. |
| `permission.denied_banner` | Izin notifikasi belum aktif. Pengingat tetap terlihat di Hari Ini, tapi tidak ada notifikasi. |
| `today.empty` | Belum ada yang perlu diingat hari ini. |
| `export.warning` | File cadangan tidak terenkripsi. Siapa pun yang membukanya bisa membaca semua catatanmu. |
| `import.replace_title` | Ganti seluruh data? |
| `import.replace_body` | File ini berisi {memories} catatan dan {reminders} pengingat. Semua data yang ada sekarang akan diganti. |
| `import.invalid` | File cadangan tidak valid atau tidak didukung. Data kamu tidak diubah. |
| `archive.keeps_reminder` | Pengingat tetap aktif dan tetap muncul di Hari Ini. |
| `delete.confirm` | Hapus catatan ini? Pengingatnya juga akan dihapus. Tindakan ini tidak bisa dibatalkan. |
| `delete_all.confirm` | Hapus semua data? Semua catatan dan pengingat akan dihapus permanen. |
| `notif.hidden_body` | Kamu punya pengingat. Buka aplikasi untuk melihat. |
| `notif.channel_name` | Pengingat |
| `notif.channel_desc` | Pengingat dari catatanmu. |
| `notif.generic_title` | Nanti Ingatkan Aku |
| `privacy.statement` | Semua catatan disimpan di HP ini. Tidak ada akun, tidak ada server, tidak ada pelacakan. |
| `onboarding.start` | Mulai |
| `onboarding.restore` | Pulihkan dari cadangan |

### 5.10 Wireframes (layout intent, not pixel specs)

```
TODAY (tab 1)

┌──────────────────────────────────┐
│ Nanti Ingatkan Aku               │
│ [!] Izin notifikasi belum aktif  │
│                                  │
│ TERLEWAT                         │
│ • Servis AC           Terlewat   │
│                                  │
│ HARI INI                         │
│ • Kunci cadangan       20.00     │
│                                  │
│ 7 HARI KE DEPAN                  │
│ • Garansi laptop  Sen, 12 Des    │
│                                  │
│                  (+ Catat)       │
└──────────────────────────────────┘

MEMORIES (tab 2)

┌──────────────────────────────────┐
│ Catatan                          │
│ [Cari judul atau detail...]      │
│ (Semua) (Umum) (Dipinjamkan)     │
│ ------------------------------   │
│ Servis AC          Perawatan     │
│ Ganti filter        Terlewat     │
│ ------------------------------   │
│ Buku Rina       Dipinjamkan      │
│ Rina                  12 Des     │
│ ------------------------------   │
│                  (+ Catat)       │
└──────────────────────────────────┘
```

---

## 6. Functional requirements

### 6.1 Memory lifecycle

**FR-MEM-01 (P0, MUST) — Create.** Create a memory offline with a title (1–120 user-perceived characters after trim) and optional body (≤ 10,000 characters). Invalid input is rejected inline without losing entered text. Default category is `general`. Validation lives in the domain layer and is mirrored by DB constraints.

**FR-MEM-02 (P0, MUST) — Read.** List non-archived memories by `updated_at_utc` descending, 50 per page, and open a detail view. Metadata, timestamps, and reminder state are visible.

**FR-MEM-03 (P0, MUST) — Update.** Edit title, body, category, and metadata. `updated_at_utc` changes; `created_at_utc` and `id` never change. Clearing the title is invalid. Changing category clears metadata fields that no longer apply, after confirming when they contain data.

**FR-MEM-04 (P0, MUST) — Archive/unarchive.** Archive hides a memory from the default list only. Reminders stay active. Archived memories are searchable when the `Arsip` toggle is on (or when the query matches with the toggle on — there is no hidden global search). Unarchive restores the default listing.

**FR-MEM-05 (P0, MUST) — Delete.** Requires a confirmation naming the memory and warning about the reminder. Deletes the memory and its reminder in one transaction, then cancels the OS notification. Hard delete; no undo.

**FR-MEM-06 (P0, MUST) — Plain text only.** Render user text as plain text. Never render HTML/markdown as markup, never execute content, never fetch remote resources.

**FR-MEM-07 (P0, MUST) — Categories and naming.** Allowed categories: `general` (`Umum`), `lent_item` (`Dipinjamkan`), `warranty` (`Garansi`), `maintenance` (`Perawatan`). `lent_item` means *an item the user lent to someone*, not an item the user borrowed. Unknown category values are rejected on import and coerced to `general` only in UI code paths that never touch persistence.

**FR-MEM-08 (P0, MUST) — Optional metadata.** `person_name` (lent only), `item_name` (lent/warranty/maintenance), `warranty_end_date` (warranty only, ISO calendar date). Metadata never creates a reminder implicitly; only the user's explicit reminder action does.

**FR-MEM-09 (P0, MUST) — Timestamps.** Store UTC ISO-8601 with milliseconds (`YYYY-MM-DDTHH:mm:ss.SSSZ`). Display in local time with `id-ID` formatting. Lexicographic ordering must equal chronological ordering.

**FR-MEM-10 (P1, SHOULD) — Undo archive.** Snackbar `Diarsipkan` with `Urungkan` for 5 seconds.

### 6.2 Reminder lifecycle

**FR-REM-01 (P0, MUST) — Cardinality.** Zero or one reminder per memory in MVP (enforced by `UNIQUE(memory_id)`). A completed reminder can be reactivated (`Buat pengingat baru`) on the same row with a new due time and `completed_at_utc = NULL`; this is the only path that changes a `completed` reminder back to `pending`.

**FR-REM-02 (P0, MUST) — Scheduling.** The user picks a future local date/time (minute precision). Persist: absolute UTC instant, the original local date/time string, the IANA timezone, and precision mode. Past times are rejected. Rejecting is validated at save time and again at reconcile time (a record whose due time passed is simply due; it is never silently moved).

**FR-REM-03 (P0, MUST) — State machine.**

```
            create
  (none) ─────────────► pending(active)
     ▲                    │  ▲
     │ delete reminder    │  │ reschedule / retry
     │                    ▼  │
     │                 pending(active)
     │                    │
     │      complete      ▼
     └──────────────  completed ──► pending (new due, completed_at=null)
                          │
             delete memory│ (cascade)
                          ▼
                        (none)
```

`scheduling_status` is orthogonal and only meaningful while `status = pending`:
`scheduled` → `deferred` → `permission_needed` → `scheduling_failed` are *delivery* facts, never memory facts.

**FR-REM-04 (P0, MUST) — Persist before notify.** Every create/edit/complete/delete writes SQLite first, then reconciles the OS schedule. A notification failure must not roll back or delete the reminder; it updates `scheduling_status` and `schedule_error_code`.

**FR-REM-05 (P0, MUST) — Stable notification IDs.** Each reminder stores a 32-bit `notification_id` derived deterministically from its UUID and checked for uniqueness. Rescheduling uses the same ID so the OS replaces rather than duplicates. Completing or deleting cancels it. `cancelAll()` is used only by "delete all data".

**FR-REM-06 (P0, MUST) — Permission UX.** Request `POST_NOTIFICATIONS` on Android 13+ only when the user first schedules a reminder, after a rationale. If permanently denied, mark `permission_needed`, show the Settings path, and never re-prompt automatically.

**FR-REM-07 (P0, MUST) — Exact vs inexact.** Use exact alarms only when the platform grants the capability; otherwise schedule inexact and set `precision = 'inexact'`. The UI must state that timing is approximate. Never block saving because exact alarms are unavailable.

**FR-REM-08 (P0, MUST) — Completion.** Marking complete sets `status = completed`, `completed_at_utc`, cancels the OS notification, and leaves the memory intact. Reopening via `Buat pengingat baru` requires a new future time.

**FR-REM-09 (P0, MUST) — Reschedule limits.** Reconcile schedules at most the 100 nearest pending reminders; the rest stay `deferred` and are topped up on the next reconcile. If the cap changes after device testing, update this number and `DEC-07`.

**FR-REM-10 (P0, MUST) — Notification content and tap.** Notification payload is `memory:<uuid>`. Tapping opens the memory detail in warm and cold start. A deleted target opens Today with a dismissible message. Default content shows the memory title; when `settings.hide_notification_content` is true, show only `Kamu punya pengingat. Buka aplikasi untuk melihat.`

**FR-REM-11 (P0, MUST) — Notification channel.** One channel, `reminders`, importance `high`, with a stable ID, Indonesian name `Pengingat`, description `Pengingat dari catatanmu.`, and vibration enabled. Channel settings changes must not create duplicates.

**FR-REM-12 (P0, MUST) — Reboot and reconciliation.** On every launch (after the first frame) and on resume (throttled to 60 s), compare pending reminders against `pendingNotificationRequests()` and repair missing or stale schedules where the platform allows. Cancel schedules for reminders that are completed or whose memory no longer exists; never schedule a notification for an already-overdue reminder. Persist the outcome and surface unresolved failures. Record reboot behavior per device in the release notes; unverified behavior must be labeled unverified.

### 6.3 Due state and Today

**FR-TODAY-01 (P0, MUST) — Derived state.** `overdue` and `today` are computed from `status`, `due_at_utc`, and the injected clock. No persisted "overdue" flag exists.

**FR-TODAY-02 (P0, MUST) — Grouping.** Overdue includes anything due before *now* (including earlier today). Today includes due later today. Upcoming includes the next 7 local days. Groups are mutually exclusive and ordered as specified in §5.4.

**FR-TODAY-03 (P0, MUST) — Archived visibility.** Pending reminders of archived memories appear in Today with an `Diarsipkan` badge.

**FR-TODAY-04 (P0, MUST) — Refresh.** Recompute on resume, on clock minute change while visible (throttled to 60 s), after any reminder mutation, after import, and after a timezone change is detected.

**FR-TODAY-05 (P0, MUST) — Honest empty state.** An empty Today screen must not imply that nothing exists elsewhere; it links to capture and explains the difference between notes and reminders.

**FR-TODAY-06 (P0, MUST) — Group size limit.** Render at most 20 items per group with a `Lihat semua` action that opens a filtered list. Never load an unbounded list into a single scroll view; a user returning after months must still get a responsive screen.

### 6.4 Search and retrieval

**FR-SRH-01 (P0, MUST) — Normalized search.** Search over `title_norm` and `body_norm`, which are produced by `trim → lowercase (Unicode) → collapse whitespace`. This replaces naive SQLite `LIKE` case-insensitivity, which only handles ASCII.

**FR-SRH-02 (P0, MUST) — Token semantics.** Split the query on whitespace (max 5 tokens, each ≤ 50 chars). A record matches when **every** token appears in `title_norm` or `body_norm`. Empty/whitespace query returns the unfiltered list.

**FR-SRH-03 (P0, MUST) — Escaping.** Escape `\`, `%`, and `_` in tokens and use `ESCAPE '\'` with bound parameters. Special characters must never throw, alter SQL, or match unexpectedly.

**FR-SRH-04 (P0, MUST) — Composition.** Category filter, archived toggle, and search compose. Results include archived memories only when the toggle is on.

**FR-SRH-05 (P0, MUST) — Ordering.** Title matches first, then `updated_at_utc` descending, then `id` ascending.

**FR-SRH-06 (P0, MUST) — Responsiveness.** Debounce input by 150 ms, cancel stale results, cap results at 50 per page, and show a loading state only after 150 ms.

### 6.5 Portability

**FR-EXP-01 (P0, MUST) — Export.** Write a UTF-8 JSON snapshot (§7.8) including `app`, `schema_version`, `exported_at`, `app_version`, `device_timezone`, counts, memories (including archived), and reminders (including completed). File name `nanti-ingatkan-aku-backup-YYYYMMDD-HHmmss.json`.

**FR-EXP-02 (P0, MUST) — Explicit destination.** The user chooses the destination through the system document picker or share sheet. No upload, no default cloud path, no silent write outside the app sandbox.

**FR-EXP-03 (P0, MUST) — Warning.** Show the unencrypted-file warning before writing, with `Lanjutkan` / `Batal`.

**FR-IMP-01 (P0, MUST) — Validate before touching data.** Validate structure, `schema_version`, enums, lengths, required fields, ISO dates, IANA timezones, referential integrity, duplicate IDs, and file limits (≤ 10 MB; ≤ 20,000 memories; ≤ 20,000 reminders). Failure produces a specific message and leaves existing data logically unchanged (same rows and field values).

**FR-IMP-02 (P0, MUST) — Replace, atomically.** MVP supports replace-only import. Show counts and require explicit confirmation. Perform delete + insert inside one transaction, with `PRAGMA foreign_keys = ON`. On any error, roll back and report failure.

**FR-IMP-03 (P0, MUST) — Recompute delivery.** After import, clear OS notifications, then reconcile every pending reminder. Report scheduling warnings separately from import success; import success is not conditional on notification permission.

**FR-IMP-04 (P0, MUST) — Preserve identity.** Keep imported memory/reminder IDs, timestamps, archive flags, and completion state. Generate fresh `notification_id` values and reset delivery facts (`scheduling_status`, precision attempt metadata) because they belong to the exporting device, not the importing one.

**FR-IMP-05 (P1, SHOULD) — Merge mode.** Out of MVP scope; if added, requires documented ID-collision and conflict rules.

### 6.6 Settings, privacy, and diagnostics

**FR-SET-01 (P0, MUST) — Notification health.** Show: notifications enabled, exact-alarm available, channel enabled, count of `permission_needed`, count of `scheduling_failed`, and platform guidance for battery optimization (with a button to open app settings). Never claim guaranteed delivery.

**FR-SET-02 (P0, MUST) — Privacy statement.** One screen explaining local storage, disabled OS backup (if `DEC-03` holds), unencrypted export, and the absence of accounts/tracking.

**FR-SET-03 (P0, MUST) — Hide notification content.** Toggle, default off. When on, lock-screen and notification content must not reveal the memory title.

**FR-SET-04 (P0, MUST) — Delete all data.** Double confirmation with the count of memories. Deletes all rows in one transaction, cancels all notifications, clears settings, returns to onboarding. Irreversible.

**FR-SET-05 (P0, MUST) — Diagnostics without PII.** Show schema version, counts, last reconcile time, last error *codes*, app version. Never show titles, bodies, or notification text.

**FR-SET-06 (P0, MUST) — About.** App version, build number, licenses, privacy text, and a line stating the MVP's limitations (delivery is best-effort).

**FR-SET-07 (P1, SHOULD) — Backup nudge.** After 10 or more memories, if no export has been recorded in 30 days, show a dismissible Settings card: `Belum pernah mencadangkan data. Kalau HP hilang, catatan tidak bisa dipulihkan.` Record only `last_export_at_utc`; do not nag more than once per 30 days.

### 6.7 First run

**FR-ONB-01 (P0, MUST) — Value + restore.** First launch explains the product in one screen with `Mulai` and `Pulihkan dari cadangan`. Completing either sets `onboarding_complete`; the screen never appears again unless data is wiped.

**FR-ONB-02 (P0, SHOULD) — Empty-state coaching.** The first Today visit explains that notes without reminders live in `Catatan`.

---

## 7. Technical blueprint

### 7.1 Stack decision (if the repository is empty)

| Layer | Choice | Rationale / caveat |
| --- | --- | --- |
| Language / UI | Flutter (stable channel) + Dart 3 | Single codebase, strong Android support, owner-requested fallback |
| State | `flutter_riverpod` | Testable providers, no global singletons; replace if repo convention differs |
| Local DB | `sqflite` + explicit migrations | Small, mature, no codegen; `drift` acceptable if the team prefers typed queries |
| Preferences | `shared_preferences` | Small non-secret settings only |
| Notifications | `flutter_local_notifications` | Channels, zoned scheduling, boot receiver, permission helpers |
| Timezone | `timezone` + `flutter_timezone` | IANA conversions and device zone detection |
| IDs | `uuid` (v4) | Locally generated stable identity |
| Localization | `flutter_localizations` + `intl` + ARB | Indonesian first, English later |
| Files | `file_picker` (SAF) | Export target + import source; verify on target devices |
| Characters | `characters` | Grapheme-accurate length limits |
| Testing | `flutter_test`, `integration_test`, `clock`, `sqflite_common_ffi` | Fake clock + in-memory DB on CI |

All versions must be pinned in `pubspec.yaml` and verified as maintained and compatible with the target SDK **before** adoption. Do not add a dependency whose platform setup cannot be verified on a device.

Not selected for MVP: Firebase/Crashlytics/analytics (privacy), `workmanager` (not needed), any cloud SDK.

### 7.2 Architecture and module layout

Feature-first, with a pure domain layer:

```
lib/
  main.dart                 # bootstrap, DI, notification init
  app/                      # MaterialApp, router, theme, l10n delegates
  core/                     # clock, id generator, failures, result, logging, constants
  l10n/                     # app_id.arb, app_en.arb
  features/
    memories/
      domain/               # Memory, Category, validation, repository interface
      data/                 # sqflite DAO, row mapping, migrations
      presentation/         # list, detail, edit, capture controllers/widgets
    reminders/
      domain/               # Reminder, due/overdue rules, scheduler interface
      data/                 # reminder DAO
      platform/             # flutter_local_notifications adapter, permissions
      presentation/         # Today, reminder editor, status chips
    backup/
      domain/               # export payload models, import validator
      data/                 # JSON serializer, atomic importer, file IO
      presentation/         # export/import screens
    settings/
      data/                 # preferences
      presentation/         # settings, diagnostics, privacy
```

Rules:

- Domain has no Flutter/plugin imports; it is unit-testable with `FakeClock`.
- Repositories are interfaces in domain, implemented in data.
- All time reads go through `Clock`; direct `DateTime.now()` is banned outside `SystemClock`.
- All paths/plugins go through adapters so tests can substitute fakes.
- Failures are typed (`ValidationFailure`, `StorageFailure`, `SchedulingFailure`, `ImportFailure`) and mapped to localized messages at the presentation boundary.

### 7.3 Data model

SQLite, `PRAGMA foreign_keys = ON` on every connection, `PRAGMA journal_mode = WAL`.

```sql
CREATE TABLE memories (
  id                TEXT PRIMARY KEY NOT NULL,
  title             TEXT NOT NULL,
  body              TEXT NOT NULL DEFAULT '',
  category          TEXT NOT NULL DEFAULT 'general'
                      CHECK (category IN ('general','lent_item','warranty','maintenance')),
  item_name         TEXT,
  person_name       TEXT,
  warranty_end_date TEXT,
  title_norm        TEXT NOT NULL,
  body_norm         TEXT NOT NULL,
  is_archived       INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0,1)),
  created_at_utc    TEXT NOT NULL,
  updated_at_utc    TEXT NOT NULL,
  CHECK (length(trim(title)) BETWEEN 1 AND 120),
  CHECK (length(body) <= 10000),
  CHECK (warranty_end_date IS NULL
         OR warranty_end_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
  CHECK (person_name IS NULL OR category = 'lent_item'),
  CHECK (item_name IS NULL
         OR category IN ('lent_item','warranty','maintenance')),
  CHECK (warranty_end_date IS NULL OR category = 'warranty')
);

CREATE TABLE reminders (
  id                       TEXT PRIMARY KEY NOT NULL,
  memory_id                TEXT NOT NULL UNIQUE
                             REFERENCES memories(id) ON DELETE CASCADE,
  notification_id          INTEGER NOT NULL UNIQUE,
  due_at_utc               TEXT NOT NULL,
  scheduled_local_datetime TEXT NOT NULL,
  scheduled_timezone       TEXT NOT NULL,
  precision                TEXT NOT NULL DEFAULT 'inexact'
                             CHECK (precision IN ('exact','inexact')),
  status                   TEXT NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending','completed')),
  scheduling_status        TEXT NOT NULL DEFAULT 'deferred'
                             CHECK (scheduling_status IN
                               ('scheduled','deferred','permission_needed','scheduling_failed')),
  schedule_attempt_at_utc  TEXT,
  schedule_error_code      TEXT,
  completed_at_utc         TEXT,
  created_at_utc           TEXT NOT NULL,
  updated_at_utc           TEXT NOT NULL,
  CHECK (status <> 'completed' OR completed_at_utc IS NOT NULL),
  CHECK (due_at_utc GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')
);

CREATE INDEX idx_memories_list   ON memories (is_archived, updated_at_utc DESC);
CREATE INDEX idx_memories_cat    ON memories (category, is_archived);
CREATE INDEX idx_reminders_due   ON reminders (status, due_at_utc);
```

Notes:

- `title_norm`/`body_norm` are derived in the repository on every write; they are never edited directly.
- `notification_id` is `int.parse(first8HexOfUuid, radix:16) & 0x7FFFFFFF`, with 0 remapped to 1 and a linear probe on collision.
- `scheduled_local_datetime` is `YYYY-MM-DDTHH:mm` (no zone) and exists for faithful display and recovery, never as the scheduling authority.
- No `overdue` column, no cached counts, no duplicated status flags.
- Gallery/attachment tables are intentionally absent until P1.

### 7.4 Migrations

- `PRAGMA user_version` is the schema version (start at 1).
- Each migration is a named, ordered list of SQL steps executed in a transaction, plus a Dart data fix-up if needed.
- Before a migration that rewrites data, copy the DB file to `nanti.pre-migration.db` in the app support directory; delete it after a successful open + integrity check.
- Reject and refuse to open a DB with `user_version` newer than the app supports; show `Data dibuat oleh versi aplikasi yang lebih baru.` and offer export-from-that-install guidance. Never downgrade destructively.
- Tests: a fixture DB per historical version, migrate forward, assert row counts and field values.
- Export `schema_version` is independent of DB `user_version`; bump it only when the JSON shape changes.

### 7.5 Time and timezone rules

- Every reminder stores `due_at_utc`, `scheduled_local_datetime`, and `scheduled_timezone`.
- Device zone comes from `flutter_timezone`; resolve it with `tz.getLocation(id)`. If the identifier is unknown (vendor alias), try a small alias map, then `tz.local`; store the resolved name and add a diagnostics warning. Never crash on an unknown zone.
- **DST gap** (chosen local time does not exist): shift forward by the gap length, persist the shifted instant, and show an inline note before saving.
- **DST overlap** (time occurs twice): choose the earlier (first) occurrence and note it.
- **Zone change after travel:** `due_at_utc` is immutable. Display in the current device zone, plus a line naming the original zone when they differ.
- Editing uses the current device zone and replaces all three time fields.
- Unit tests must cover: Asia/Jakarta (no DST), a DST-gap zone (e.g. `Europe/Berlin` spring forward), a DST-overlap zone (fall back), and a device-zone change.
- Never persist only a formatted string as the scheduling authority; never parse localized date strings.

### 7.6 Notification subsystem

**Initialization (once, before `runApp`)**

1. `tz.initializeTimeZones()`; set local zone from `flutter_timezone`.
2. `FlutterLocalNotificationsPlugin.initialize` with an `onDidReceiveNotificationResponse` handler and `getNotificationAppLaunchDetails()` for cold start.
3. Create the `reminders` channel on Android 8+.
4. Wire the boot receiver in the manifest per plugin docs.

**Scheduling a reminder**

```
persist(reminder)                       // transaction, scheduling_status = deferred
status = ensurePermission()             // granted | denied | permanently_denied
if denied: mark permission_needed; return
mode = canScheduleExact() ? exactAllowWhileIdle : inexactAllowWhileIdle
try:
  zonedSchedule(id, titleOrGeneric, body, tzDateTime, mode, payload, androidDetails)
  mark scheduled, precision = mode
catch e:
  mark scheduling_failed, code = normalizedErrorCode(e)
```

**Reconcile (launch after first frame, resume throttled to 60 s, after mutations, after import, after permission grant, after zone change)**

1. Read all reminders.
2. `cancel` notifications for completed reminders and for memories that no longer exist.
3. Build the pending list; sort by `due_at_utc`.
4. Do not schedule OS notifications for pending reminders that are now overdue (they stay visible in-app); leave any already-delivered notification untouched.
5. Take the first 100 future pending reminders; schedule any that are missing, failed, or stale; mark the rest `deferred`.
6. Persist `scheduling_status`, `schedule_attempt_at_utc`, and error codes.
7. Update `settings.last_reconcile_at`.

**Boot and OEM behavior `[verify]`**

- `RECEIVE_BOOT_COMPLETED` + the plugin's boot receiver restores alarms on most devices; verify on the target device.
- Some OEMs (Xiaomi/MIUI, OPPO/ColorOS, vivo/Funtouch, Samsung) aggressively kill background alarms. Settings must offer an "open battery settings" path and a plain-language explanation. Never promise reliable delivery.
- Record the exact device/OS result in the release notes; `AC-13` allows "documented as unverified" but not "assumed working".

**Exact-alarm policy `[verify]`**

- Manifest declares `SCHEDULE_EXACT_ALARM` (user-grantable). Do **not** use `USE_EXACT_ALARM` unless the Play policy review confirms eligibility for this app category.
- Android 12+: check `canScheduleExactNotifications()`; if false, offer a settings path and fall back to inexact.
- Android 14+: exact alarms are denied by default for many fresh installs; the fallback path is the normal path, not an edge case.
- Never block saving, never crash, never silently claim exact timing.

### 7.7 Search implementation

```sql
-- per token i, bound params: "%<escaped_token>%"
SELECT m.*
FROM memories m
WHERE m.is_archived = ?1                      -- 0 = default list, 1 = archived view
  AND (?2 IS NULL OR m.category = ?2)
  AND (m.title_norm LIKE ?3 ESCAPE '\' OR m.body_norm LIKE ?3 ESCAPE '\')
  -- ... repeat AND (...) for tokens 2..5
ORDER BY (m.title_norm LIKE ?3 ESCAPE '\') DESC,
         m.updated_at_utc DESC,
         m.id ASC
LIMIT 50 OFFSET ?;
```

- Escape order: replace `\` → `\\`, then `%` → `\%`, then `_` → `\_`.
- Normalization uses Dart `toLowerCase()` (Unicode-aware) and whitespace collapsing; no stemming, no fuzzy matching, no synonyms.
- Ranking uses a first-token title hit as a cheap relevance proxy. Do not describe this as relevance scoring in the UI or docs.
- Keep the query builder in one place with tests for `%`, `_`, `\`, quotes, emoji, and 5-token input.
- Revisit FTS5 only if M-06 fails at 1,000 seeded records.

### 7.8 Export / import format

```json
{
  "app": "nanti-ingatkan-aku",
  "schema_version": 1,
  "exported_at": "2026-10-23T09:12:31.000Z",
  "app_version": "1.0.0+1",
  "device_timezone": "Asia/Jakarta",
  "counts": { "memories": 1, "reminders": 1 },
  "memories": [
    {
      "id": "3f1c8a2e-8b1d-4f0a-9a3e-5a7f0f2c9d11",
      "title": "Garansi laptop",
      "body": "Perpanjangan 1 tahun.",
      "category": "warranty",
      "item_name": "Laptop",
      "person_name": null,
      "warranty_end_date": "2027-12-12",
      "is_archived": false,
      "created_at_utc": "2026-10-20T02:11:00.000Z",
      "updated_at_utc": "2026-10-20T02:11:00.000Z"
    }
  ],
  "reminders": [
    {
      "id": "a1b2c3d4-1111-4222-8333-444455556666",
      "memory_id": "3f1c8a2e-8b1d-4f0a-9a3e-5a7f0f2c9d11",
      "due_at_utc": "2027-12-12T13:00:00.000Z",
      "scheduled_local_datetime": "2027-12-12T20:00",
      "scheduled_timezone": "Asia/Jakarta",
      "precision": "exact",
      "status": "pending",
      "scheduling_status": "scheduled",
      "completed_at_utc": null,
      "created_at_utc": "2026-10-20T02:11:00.000Z",
      "updated_at_utc": "2026-10-20T02:11:00.000Z"
    }
  ]
}
```

`notification_id`, `schedule_attempt_at_utc`, and `schedule_error_code` are **not exported** (device-local delivery facts). App settings (hide-notification-content, onboarding state, last reconcile) are device-local and **not exported**. `title_norm`/`body_norm` are recomputed on import.

**Validation rules (all must pass before any write)**

| Check | Rule | Failure message |
| --- | --- | --- |
| File size | ≤ 10 MB | `File terlalu besar.` |
| Parse | Valid UTF-8 JSON object | `File cadangan tidak valid.` |
| Envelope | `app == "nanti-ingatkan-aku"`, integer `schema_version` | `Bukan file cadangan aplikasi ini.` |
| Version | `schema_version` ∈ supported set (currently `{1}`) | `Versi cadangan tidak didukung.` |
| Counts | Arrays ≤ 20,000; `counts` must match array lengths | `Isi file tidak konsisten.` |
| Memory fields | Required types; title 1–120; body ≤ 10,000; category enum; booleans; ISO timestamps | `Data catatan tidak valid.` |
| Metadata | `person_name` only for `lent_item`; `item_name` only for `lent_item`/`warranty`/`maintenance`; `warranty_end_date` only for `warranty` and a real calendar date | `Data catatan tidak valid.` |
| Uniqueness | No duplicate memory IDs; no duplicate reminder IDs; one reminder per memory | `Data duplikat ditemukan.` |
| References | Every `memory_id` exists; every reminder maps to exactly one memory | `Referensi data tidak valid.` |
| Reminder fields | `status` enum; `scheduling_status` enum; `precision` enum; `due_at_utc` parseable UTC; completed requires `completed_at_utc` | `Data pengingat tidak valid.` |
| Timezone | `scheduled_timezone` resolvable by the timezone database (unknown → warning, not fatal) | Warning only |
| Dates | `warranty_end_date` is a real date (not 2027-02-30); `due_at_utc` is valid | `Tanggal tidak valid.` |

**Atomic import algorithm**

1. Read file with a hard byte cap; parse to typed models; validate fully in memory.
2. Show preview counts and the replace warning; require explicit confirmation.
3. `BEGIN` (via `db.transaction`), `DELETE FROM reminders`, `DELETE FROM memories`, insert memories, insert reminders with **fresh `notification_id` values** and `scheduling_status = 'deferred'`, `COMMIT`. Exported scheduling facts are never trusted as current device state.
4. On any exception: `ROLLBACK`, keep the original data, show the specific failure.
5. On success: `cancelAll()`, then reconcile, then show `Berhasil memulihkan N catatan dan M pengingat.` plus any scheduling warnings.

### 7.9 Settings storage

`shared_preferences` keys: `onboarding_complete` (bool), `hide_notification_content` (bool, default false), `last_reconcile_at_utc` (string), `last_known_timezone` (string), `last_export_at_utc` (string). No secrets, no user text.

### 7.10 Error handling and logging

- Typed failures at domain boundaries; localized copy at the UI; technical codes only in diagnostics.
- Storage failures: keep the draft on screen, offer retry, never silently drop input.
- Notification failures: persist the reminder, surface `scheduling_failed` + retry action.
- Import failures: no partial state, specific message, original data untouched.
- Logging: release builds log event codes only (`REM_SCHEDULE_FAILED`, code). Never log titles, bodies, query strings, file contents, or notification text.
- No third-party crash reporting. Debug logging must be disabled in release.

### 7.11 Android configuration checklist `[verify]`

| Item | Requirement |
| --- | --- |
| `minSdk` | 26 (Android 8.0) — notification channels and predictable timezone behavior. Default per `DEC-05`; confirm before Phase 1. |
| `targetSdk` / `compileSdk` | Latest stable required by Play at release time (likely 35/36) — verify at implementation time. |
| Permissions | `POST_NOTIFICATIONS` (33+), `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM` (optional grant). |
| Not present | `INTERNET` must be absent from the merged **release** manifest; verify with `aapt dump permissions` or the merged manifest report. If a plugin injects it, remove with `tools:node="remove"` and document why. |
| Backup | `android:allowBackup="false"`, `android:fullBackupContent="false"`, `android:dataExtractionRules` excluding everything (see `DEC-03`). |
| Receivers | Plugin boot + notification receivers declared with `android:exported` exactly as documented. |
| Channel | `reminders`, high importance, stable ID; never rename the channel ID after release. |
| Launch mode | Default; notification tap must not duplicate the activity stack. |

### 7.12 Delivery semantics (stated in-app, not just here)

- `scheduled` means "handed to the OS", not "guaranteed to fire on time".
- Inexact alarms may be delayed by Doze/battery saver; the UI labels them as approximate.
- The in-app record is always authoritative and always visible.
- Reboot behavior depends on the OS and OEM; the plugin's boot receiver handles the common case, and the next app open repairs anything missing. This is verified per device, never assumed. `[verify]`

---

## 8. Non-functional requirements

### 8.1 Offline and durability

- **NFR-OFF-01 (P0, MUST)** All P0 workflows except OS permission dialogs and the system file picker work in airplane mode.
- **NFR-DUR-01 (P0, MUST)** Data survives app restart, process death, and device reboot.
- **NFR-DUR-02 (P0, MUST)** Migrations preserve existing rows; verified by fixture tests.
- **NFR-DUR-03 (P0, MUST)** Export/import restores content after uninstall/reinstall (with OS backup disabled, this is the only recovery path — say so in Settings).

### 8.2 Performance (budgets, measured on the reference device)

- **NFR-PERF-01** Cold start to interactive Today ≤ 2.0 s (median of 5).
- **NFR-PERF-02** Capture screen interactive ≤ 1.0 s after tap.
- **NFR-PERF-03** Search ≤ 100 ms for 1,000 memories; input debounce 150 ms.
- **NFR-PERF-04** List scrolling at 60 fps with no sustained jank; images are absent in MVP.
- **NFR-PERF-05** DB size at 1,000 memories ≤ 5 MB.
- **NFR-PERF-06** No polling loops. Reconcile is event-driven with a 60 s throttle.
- Report measured values with device model and build mode; never publish unmeasured claims.

### 8.3 Reliability

- **NFR-REL-01** No duplicate OS notifications after edit/reschedule/reconcile (same `notification_id`).
- **NFR-REL-02** Scheduling errors are visible and retryable from detail and Settings.
- **NFR-REL-03** Import never leaves partial data (transaction + rollback test).
- **NFR-REL-04** A missing/corrupt DB file does not crash the app; it offers restore-onboarding and a diagnostics message.
- **NFR-REL-05** All writes are transactional per user action.

### 8.4 Accessibility

- **NFR-A11Y-01** 48 dp touch targets, 200% text scale without clipping, no horizontally scrolling primary layout.
- **NFR-A11Y-02** Contrast ≥ 4.5:1 body, ≥ 3:1 large text/borders.
- **NFR-A11Y-03** TalkBack labels for all controls and status chips; logical focus order; dialogs trap focus.
- **NFR-A11Y-04** Status conveyed by text + icon, never color alone.
- **NFR-A11Y-05** All P0 tasks completable without gestures (long-press/swipe/drag).
- **NFR-A11Y-06** Respect system font scale, display size, and reduce-motion.

### 8.5 Security and privacy

- **NFR-SEC-01** Local app-sandbox storage only; no network permission in release.
- **NFR-SEC-02** Parameterized SQL everywhere; no string-concatenated queries.
- **NFR-SEC-03** Import validation is a hard gate (size, schema, types, references) to resist malicious files.
- **NFR-SEC-04** No PII in logs, crash output, or diagnostics.
- **NFR-SEC-05** Export is unencrypted and clearly disclosed; never described as encrypted or end-to-end encrypted.
- **NFR-SEC-06** Notification content can be hidden (`FR-SET-03`).
- **NFR-SEC-07** OS auto-backup decision is explicit and documented (`DEC-03`), not incidental.
- **NFR-SEC-08** MVP data is stored **unencrypted**; this is disclosed in Settings and never described as encrypted. Database encryption remains a P1 backlog item.

**Threat model (MVP)**

| Threat | Impact | Mitigation |
| --- | --- | --- |
| Device lost/stolen, unlocked | Full read access | P1 app lock + `FLAG_SECURE`; document gap |
| Shoulder surfing / lock-screen preview | Fact leakage | Hide-content toggle; channel privacy note |
| Malicious/corrupt backup file | Data loss or crash | Strict validation + atomic import |
| Export file shared to wrong destination | Leakage | Explicit warning + user-chosen destination |
| Cloud auto-backup leaks DB | Leakage contrary to promise | Disable OS backup (`DEC-03`) and document |
| SQL injection via search | Corruption/leak | Bound parameters + escaping tests |
| Third-party SDK telemetry | Silent exfiltration | No analytics/network permission (`DEC-10`) |

### 8.6 Maintainability

- **NFR-MNT-01** Unit tests for validation, due rules, search escaping, import validation, ID/timezone helpers.
- **NFR-MNT-02** Migration tests per schema version.
- **NFR-MNT-03** `README.md` covering setup, run, test, backup behavior, and known limitations.
- **NFR-MNT-04** `CHANGELOG.md` and a short ADR for each `DEC-*` that changes.
- **NFR-MNT-05** No hardcoded UI strings; ARB-only.
- **NFR-MNT-06** Analyzer clean; formatter applied; CI (if available) runs analyze + test.

### 8.7 Localization

- **NFR-L10N-01** Indonesian is the default and only complete locale in v1.0; English ARB may ship incomplete only if the UI falls back cleanly.
- **NFR-L10N-02** Dates/times use `intl` `id_ID` (`Sen, 12 Des 2027 • 20.00`).
- **NFR-L10N-03** No concatenated sentences; use ICU placeholders for counts.
- **NFR-L10N-04** Layout tolerates ~35% string expansion (future English).

---

## 9. Test strategy

### 9.1 Test levels

| Level | Scope | Tooling |
| --- | --- | --- |
| Unit | Validation, categories, due/overdue, search escaping + tokens, ID derivation, timezone/DST, import validator, state machine | `flutter_test`, `clock`, `fake_async` |
| Persistence | DAO CRUD, cascade delete, transactions, migrations | `sqflite_common_ffi` in-memory + fixture DBs |
| Widget | Capture validation, empty states, chips, dialogs, semantics, 200% text scale | `flutter_test`, `SemanticsTester` |
| Integration | Capture → restart → search; reminder → fake scheduler → reconcile; import replace + rollback | `integration_test` with fake platform adapters |
| Manual device | Real notifications, permissions, exact alarms, reboot, SAF, TalkBack, OEM battery | Physical Android device matrix |

### 9.2 Fakes and fixtures

- `FakeClock` with settable `now`, used by all domain and widget tests.
- `FakeReminderScheduler` recording `schedule/cancel/cancelAll` calls and injectable failures/permission states.
- Seed generator: 1,000 memories (mixed categories, lengths, archived) + 60 reminders for performance and search tests.
- Corrupt fixtures: truncated JSON, wrong `app`, `schema_version: 99`, duplicate IDs, orphan `memory_id`, 10.1 MB file, `2027-02-30`, unknown timezone, 20,001 memories.

### 9.3 Device matrix

| Tier | OS | Why |
| --- | --- | --- |
| Minimum | Android 8.0 (API 26) | Channel + baseline behavior |
| Permission model | Android 13 (API 33) | `POST_NOTIFICATIONS` runtime flow |
| Exact-alarm restrictions | Android 14 (API 34) | Denied-by-default exact alarms |
| Current | Android 15/16 | Play target behavior `[verify]` |
| OEM stress | Xiaomi/Redmi or OPPO mid-range | Aggressive background killing |

At minimum one **physical** device must cover notification delivery, permission denial, reboot, SAF export/import, and TalkBack. Emulator results are never sufficient for those.

### 9.4 Acceptance matrix

| ID | Scenario | Pass condition | Requirements |
| --- | --- | --- | --- |
| AC-01 | Airplane mode; create title-only memory; force-close; relaunch | Memory present in Catatan and findable by title | FR-MEM-01/02, NFR-OFF-01, NFR-DUR-01 |
| AC-02 | Save body + metadata; edit; restart | All fields persist; `updated_at` advances; `created_at` unchanged | FR-MEM-03/08/09 |
| AC-03 | Memory without reminder | Appears in search/list, never in Today | FR-REM-01, FR-TODAY-02 |
| AC-04 | Schedule near-future reminder with permission granted | Real notification arrives on device; record visible in Today after dismissal | FR-REM-02/06, AC-13 |
| AC-05 | Deny notification permission; schedule | Reminder saves, status `permission_needed`, becomes Terlewat at the right time | FR-REM-06, FR-TODAY-01 |
| AC-06 | Reschedule; then complete; then delete | One pending OS request after reschedule (where the platform exposes pending requests); no duplicate notification fires; cancelled after complete/delete; memory intact | FR-REM-05/08, NFR-REL-01 |
| AC-07 | Archive with pending reminder | Hidden from default list; visible with Arsip toggle; still in Today with `Diarsipkan` badge; reminder still fires | FR-MEM-04, FR-TODAY-03 |
| AC-08 | Search `%`, `_`, `\`, quotes, emoji, uppercase, 5 tokens | No crash, no injection, correct matches, filters compose | FR-SRH-01..06 |
| AC-09 | Export → clean install → import | IDs, titles, metadata, archive flags, reminder states identical; scheduling warnings reported separately | FR-EXP-01, FR-IMP-01..04 |
| AC-10 | Corrupt/oversize/unsupported import | Specific error; existing data unchanged (row counts and field values) | FR-IMP-01/02 |
| AC-11 | Timezone change + DST fixtures | `due_at_utc` unchanged; display correct; gap/overlap rules applied | FR-REM-02, §7.5, NFR-L10N-02 |
| AC-12 | Migration from v1 fixture | No data loss; app opens; schema version incremented | NFR-DUR-02, §7.4 |
| AC-13 | Reboot + OEM battery restriction | Behavior tested and documented; unverified items labeled unverified | FR-REM-12, §7.6 |
| AC-14 | Tap notification, warm and cold start | Correct memory detail; deleted target shows Today message | FR-REM-10 |
| AC-15 | Hide notification content on | Lock-screen notification does not reveal the title | FR-SET-03, NFR-SEC-06 |
| AC-16 | Exact alarm unavailable | Reminder still saved + scheduled inexact; label shown; no crash | FR-REM-07 |
| AC-17 | Delete all data | All rows gone, all notifications cancelled, onboarding shown, Settings reset | FR-SET-04 |
| AC-18 | Import failure injected mid-transaction | Rollback; original data intact | FR-IMP-02, NFR-REL-03 |
| AC-19 | Usability: capture title-only | Median ≤ 30 s, ≤ 3 interactions, no assistance | M-01, FR-MEM-01 |
| AC-20 | 1,000-memory seed | Search ≤ 100 ms; cold start ≤ 2.0 s; no jank | NFR-PERF-01/03/04 |
| AC-21 | TalkBack at 200% text | All P0 tasks completable, no clipped primary controls | NFR-A11Y-01..06 |

### 9.5 Manual notification script (must be recorded on device)

1. Fresh install → grant notifications → create reminder 2 minutes ahead → wait for the due time → confirm the notification appears.
2. Deny permission → create reminder → confirm no system dialog loop, `permission_needed` chip, Today presence at due time.
3. Reschedule to +1 minute → confirm a single notification (not two).
4. Complete before due → confirm no notification arrives.
5. Reboot device → confirm pending reminder still fires (or document failure + repair on next open).
6. Enable battery saver / OEM restriction → observe and document delay; verify the Settings guidance path opens the right screen.
7. Tap notifications warm and cold → correct detail screen.
8. Toggle hide-content → confirm lock-screen text changes.

Record: device model, OS, build mode, exact/inexact, result, timestamp.

---

## 10. Milestones

Estimates are for one experienced Flutter developer, excluding owner review time. Treat them as ±40%, not commitments.

| Phase | Scope | Deliverables | Exit criteria | Est. |
| --- | --- | --- | --- | --- |
| 0 — Discovery & design gate | Inspect repo, confirm stack/SDK/dependencies, decide `DEC-03/04/05`, sketch schema | Findings report, architecture note, updated decision log | Owner approves stack + security defaults | 1 d |
| 1 — Vertical slice | Bootstrap app shell, DB + migration v1, create/read, list/detail, restart persistence | Running app, unit + DB tests, README skeleton | AC-01, AC-02 (without metadata) | 4 d |
| 2 — Retrieval | Edit, archive/unarchive, delete, categories/metadata, search, filters, empty/error states, a11y pass | Search implementation + tests, widget tests | AC-03, AC-07, AC-08, AC-21 | 4 d |
| 3 — Reminders | Scheduling, permissions, exact/inexact, Today groups, complete/reschedule, reconcile, deep link, privacy toggle | Notification adapter + fakes, device test notes | AC-04, AC-05, AC-06, AC-13, AC-14, AC-15, AC-16 | 6 d |
| 4 — Portability | Export/import UI, validator, atomic replace, delete-all, settings, privacy copy | Backup module + fixtures | AC-09, AC-10, AC-17, AC-18 | 4 d |
| 5 — Release readiness | Perf pass, migration drill, 72 h soak, README/CHANGELOG, Play checklist, privacy policy text | Release build, test report, known-limitations doc | All P0 ACs pass or are explicitly waived by owner | 3 d |

Sequencing rules: never start Phase 3 before Phase 1 persistence is proven across restart; never start Phase 4 before the schema is stable (import fixtures depend on it). Each phase ends with the report format in §0.3.

**Play Store readiness (Phase 5):** privacy policy URL or in-app policy text, Data Safety form answers (no data collected/shared, no network), notification permission declaration, exact-alarm justification if declared, content rating, screenshots in Indonesian, and a tested release build.

---

## 11. Risk register

| ID | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| RSK-01 | OEM battery managers suppress notifications | High | High | In-app guidance, documented limitation, reconcile on open, test on OEM device |
| RSK-02 | Exact-alarm policy rejection or denial | Medium | Medium | Inexact fallback by default path, no `USE_EXACT_ALARM`, honest copy |
| RSK-03 | Timezone/DST bugs produce wrong due times | Medium | High | Dedicated module, injected clock, gap/overlap rules, fixture tests |
| RSK-04 | Import corrupts or wipes data | Low | Critical | Full validation before write, single transaction, rollback test, pre-import data untouched |
| RSK-05 | OS auto-backup contradicts "local-only" claim | Medium | High | Disable backup + exclusion rules, disclose trade-off, export is the recovery path |
| RSK-06 | Scope creep to AI/OCR/sync | High | High | Explicit non-goals + P1/P2 backlog + experiment rule |
| RSK-07 | Accessibility regressions late in release | Medium | Medium | A11y checks in DoD, TalkBack pass each phase |
| RSK-08 | Plugin breakage after Flutter/SDK upgrade | Medium | Medium | Pin versions, upgrade deliberately, device regression checklist |
| RSK-09 | User loses device/data without a backup | Medium | High | Onboarding nudge, Settings export reminder after N memories, documented limits |
| RSK-10 | Search degrades as data grows | Low | Low | Budget + FTS5 fallback plan |
| RSK-11 | Accidental "mark done" hides a needed reminder | Low | Medium | 5 s undo; completed reminders stay visible on the memory detail; reactivation is one tap |
| RSK-12 | Notification text leaks on lock screen | Medium | Medium | Hide-content toggle, default channel copy |

---

## 12. Decisions and open questions

### 12.1 Decision log (defaults apply if the owner does not respond before Phase 1)

| ID | Decision | Default | Rationale | Owner may override |
| --- | --- | --- | --- | --- |
| DEC-01 | Platform scope | Android only for v1.0; iOS is P2 | No iOS build/signing capability; focus delivery quality | Yes |
| DEC-02 | UI language | Indonesian only in v1.0; ARB-ready for English | Target users are Indonesian speakers | Yes |
| DEC-03 | OS auto-backup | Disabled (`allowBackup=false` + exclusion rules), disclosed in Settings | Honest "local-only" claim; export/import is the recovery path | Yes (requires disclosure copy) |
| DEC-04 | Export encryption | Unencrypted JSON with explicit warning; encrypted export is P1 | Key management is a separate design problem | Yes |
| DEC-05 | Minimum Android | API 26 (Android 8.0) | Notification channels, timezone reliability, realistic device share | Yes |
| DEC-06 | Stack (empty repo) | Flutter + sqflite + riverpod + flutter_local_notifications | Fast, testable, no backend, mature Android support | Yes |
| DEC-07 | Reminder precision | Exact when granted, inexact otherwise; UI labels precision; cap 100 scheduled | Policy-safe and honest | Yes (raise cap after device testing) |
| DEC-08 | Archive vs reminders | Archive never cancels reminders | Avoid silent data loss; explicit delete exists | Yes |
| DEC-09 | Reminder cardinality | One per memory; recurrence is P1 | Keeps schema and UI simple | Yes |
| DEC-10 | Telemetry/network | No analytics, no crash SDK, no `INTERNET` in release | Privacy promise and reduced attack surface | Yes (requires privacy review) |
| DEC-11 | Import mode | Replace only | Deterministic, testable, simple recovery story | Yes |

### 12.2 Open questions for the owner

| ID | Question | Needed by | Default if unanswered |
| --- | --- | --- | --- |
| OQ-01 | Android-only acceptable for v1.0? | Phase 0 | Yes (`DEC-01`) |
| OQ-02 | Indonesian-only UI at launch? | Phase 0 | Yes (`DEC-02`) |
| OQ-03 | Confirm disabling OS backup? | Phase 0 | Yes (`DEC-03`) |
| OQ-04 | Is unencrypted export acceptable for MVP? | Phase 1 | Yes (`DEC-04`) |
| OQ-05 | Minimum Android version / existing repo or stack? | Phase 0 | API 26, Flutter (`DEC-05/06`) |
| OQ-06 | Brand assets, app icon, Play listing copy? | Phase 4 | Placeholder icon + copy in this doc |
| OQ-07 | Privacy policy hosting (URL vs in-app only)? | Phase 5 | In-app text + placeholder URL |
| OQ-08 | Any monetization or org account requirement? | Phase 3 | None; free, personal |
| OQ-09 | Is "Dipinjamkan" the intended meaning (items lent out)? | Phase 1 | Yes (`FR-MEM-07`) |

If an answer is still missing, proceed only with reversible work and state the assumption in the phase report. Never make a security-sensitive decision silently.

---

## 13. Glossary

| Term | Meaning |
| --- | --- |
| Memory / catatan | The stored fact: title, body, category, optional metadata |
| Reminder / pengingat | A one-time scheduled attachment to a memory |
| Due | `due_at_utc <= now` and not completed |
| Overdue / terlewat | Due before *now*, including earlier today; always visible in Today |
| Scheduled | Successfully handed to the OS; not a delivery guarantee |
| Precision | `exact` or `inexact` alarm behavior |
| `scheduling_status` | Delivery fact: `scheduled`, `deferred`, `permission_needed`, `scheduling_failed` |
| Archive | Hidden from the default list; reminders stay active |
| Replace import | Import that deletes all current data before inserting the file's data |
| Vertical slice | One end-to-end working feature through UI, domain, data, and tests |
| SAF | Android Storage Access Framework (system file picker) |
| IANA zone | Timezone identifier such as `Asia/Jakarta` |
| `schema_version` | Version of the JSON export format (independent of DB `user_version`) |

---

## Appendix A — Assumptions recorded for v2.0

1. The repository is empty at the time of writing; no existing stack takes precedence.
2. The owner accepts English for the specification and Indonesian for the UI.
3. No backend, account, AI model, or paid service will be introduced in MVP.
4. A physical Android device is available for Phase 3–5 verification.
5. Play Store distribution is the target channel; if sideload-only, the exact-alarm and target-SDK constraints relax but the privacy rules do not.
6. The MVP is free and personal; no monetization requirements exist.
