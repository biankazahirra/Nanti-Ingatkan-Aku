// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appName => 'Nanti Ingatkan Aku';

  @override
  String get appTagline => 'Simpan hal kecil sebelum lupa.';

  @override
  String get navToday => 'Hari Ini';

  @override
  String get navMemories => 'Catatan';

  @override
  String get navSettings => 'Pengaturan';

  @override
  String get captureTitleHint => 'Apa yang ingin kamu ingat?';

  @override
  String get captureBodyHint => 'Detail (opsional)';

  @override
  String get captureRemindMe => 'Ingatkan aku';

  @override
  String get captureSave => 'Simpan';

  @override
  String get captureSaved => 'Catatan tersimpan';

  @override
  String get captureNewTitle => 'Catat';

  @override
  String get captureEditTitle => 'Ubah catatan';

  @override
  String captureTitleCounter(int count, int max) {
    return '$count/$max';
  }

  @override
  String captureBodyCounter(int count, int max) {
    return '$count/$max';
  }

  @override
  String get categoryGeneral => 'Umum';

  @override
  String get categoryLentItem => 'Dipinjamkan';

  @override
  String get categoryWarranty => 'Garansi';

  @override
  String get categoryMaintenance => 'Perawatan';

  @override
  String get categoryAll => 'Semua';

  @override
  String get categoryChangeTitle => 'Ganti kategori?';

  @override
  String get categoryClearMetadata =>
      'Isian yang tidak lagi berlaku untuk kategori baru akan dihapus.';

  @override
  String get fieldLentTo => 'Dipinjamkan ke';

  @override
  String get fieldItemName => 'Nama barang';

  @override
  String get fieldWarrantyEnd => 'Garansi berakhir';

  @override
  String get fieldPickDate => 'Pilih tanggal';

  @override
  String get reminderSectionTitle => 'Pengingat';

  @override
  String get reminderPreset1h => '1 jam lagi';

  @override
  String get reminderPresetTonight => 'Nanti malam (20.00)';

  @override
  String get reminderPresetTomorrow => 'Besok (09.00)';

  @override
  String get reminderPresetWeek => 'Minggu depan';

  @override
  String get reminderPick => 'Pilih tanggal & waktu';

  @override
  String get reminderScheduled => 'Terjadwal';

  @override
  String reminderScheduledAt(String when) {
    return 'Terjadwal $when';
  }

  @override
  String get reminderInexact =>
      'Perkiraan waktu (bisa terlambat beberapa menit).';

  @override
  String get reminderPermissionNeeded => 'Perlu izin notifikasi';

  @override
  String get reminderFailed => 'Gagal dijadwalkan';

  @override
  String get reminderOverdue => 'Terlewat';

  @override
  String reminderOverdueSince(String when) {
    return 'Terlewat sejak $when';
  }

  @override
  String get reminderDone => 'Selesai';

  @override
  String reminderDoneAt(String when) {
    return 'Selesai pada $when';
  }

  @override
  String get reminderMarkDone => 'Tandai selesai';

  @override
  String get reminderCreate => 'Buat pengingat';

  @override
  String get reminderChange => 'Ubah pengingat';

  @override
  String get reminderNew => 'Buat pengingat baru';

  @override
  String get reminderDeferred => 'Menunggu penjadwalan';

  @override
  String get reminderRetry => 'Coba lagi';

  @override
  String get reminderOpenSettings => 'Buka pengaturan';

  @override
  String get reminderNone => 'Belum ada pengingat.';

  @override
  String reminderZoneNote(String original, String current) {
    return 'Diatur pada zona $original; perangkat sekarang di $current.';
  }

  @override
  String reminderShiftedNote(String zone, String when) {
    return 'Waktu ini tidak ada di zona $zone (perubahan DST). Digeser ke $when.';
  }

  @override
  String reminderAmbiguousNote(String zone, String when) {
    return 'Waktu ini terjadi dua kali di zona $zone. Dipakai yang lebih awal: $when.';
  }

  @override
  String get reminderDoneSnack => 'Pengingat selesai';

  @override
  String get reminderUndo => 'Urungkan';

  @override
  String get errorTitleEmpty => 'Judul tidak boleh kosong.';

  @override
  String get errorTitleTooLong => 'Judul maksimal 120 karakter.';

  @override
  String get errorBodyTooLong => 'Detail maksimal 10.000 karakter.';

  @override
  String get errorPersonTooLong => 'Nama orang maksimal 80 karakter.';

  @override
  String get errorItemTooLong => 'Nama barang maksimal 120 karakter.';

  @override
  String get errorDateInvalid => 'Tanggal tidak valid.';

  @override
  String get errorDuePast => 'Waktu pengingat harus di masa depan.';

  @override
  String get errorSaveFailed => 'Gagal menyimpan. Coba lagi.';

  @override
  String get errorGeneric => 'Terjadi masalah. Coba lagi.';

  @override
  String get errorDbNewer => 'Data dibuat oleh versi aplikasi yang lebih baru.';

  @override
  String get permissionRationale =>
      'Supaya pengingat muncul, izinkan notifikasi. Catatanmu tetap tersimpan tanpa izin ini.';

  @override
  String get permissionRationaleContinue => 'Lanjutkan';

  @override
  String get permissionRationaleCancel => 'Nanti saja';

  @override
  String get permissionDeniedBanner =>
      'Izin notifikasi belum aktif. Pengingat tetap terlihat di Hari Ini, tapi tidak ada notifikasi.';

  @override
  String get todayTitle => 'Hari Ini';

  @override
  String get todayEmpty => 'Belum ada yang perlu diingat hari ini.';

  @override
  String get todayEmptyCta => 'Catat sesuatu';

  @override
  String get todayCoach => 'Catatan tanpa pengingat tetap ada di tab Catatan.';

  @override
  String get todaySectionOverdue => 'Terlewat';

  @override
  String get todaySectionToday => 'Hari ini';

  @override
  String get todaySectionUpcoming => '7 hari ke depan';

  @override
  String get todaySeeAll => 'Lihat semua';

  @override
  String get todayDeletedMemory => 'Catatan ini sudah dihapus.';

  @override
  String get memoriesTitle => 'Catatan';

  @override
  String get memoriesSearchHint => 'Cari judul atau detail...';

  @override
  String get memoriesEmpty =>
      'Belum ada catatan. Mulai dari hal kecil yang mudah lupa.';

  @override
  String memoriesNoResults(String query) {
    return 'Tidak ada hasil untuk \"$query\".';
  }

  @override
  String get memoriesArchiveEmpty => 'Belum ada catatan yang diarsipkan.';

  @override
  String get memoriesLoadMore => 'Muat lagi';

  @override
  String get memoriesArchivedToggle => 'Arsip';

  @override
  String get memoriesArchivedBadge => 'Diarsipkan';

  @override
  String detailCreated(String when) {
    return 'Dibuat $when';
  }

  @override
  String detailUpdated(String when) {
    return 'Diperbarui $when';
  }

  @override
  String get detailActionEdit => 'Ubah';

  @override
  String get detailActionArchive => 'Arsipkan';

  @override
  String get detailActionUnarchive => 'Kembalikan dari arsip';

  @override
  String get detailActionDelete => 'Hapus';

  @override
  String get detailArchiveSnack => 'Diarsipkan';

  @override
  String get archiveKeepsReminder =>
      'Pengingat tetap aktif dan tetap muncul di Hari Ini.';

  @override
  String get detailUnarchiveSnack => 'Dikembalikan ke daftar';

  @override
  String deleteConfirmNamed(String title) {
    return 'Hapus \"$title\"? Pengingatnya juga akan dihapus. Tindakan ini tidak bisa dibatalkan.';
  }

  @override
  String get draftDiscardTitle => 'Buang catatan ini?';

  @override
  String get draftKeep => 'Lanjutkan menulis';

  @override
  String get draftDiscard => 'Buang';

  @override
  String get exportAction => 'Ekspor cadangan';

  @override
  String get exportWarning =>
      'File cadangan tidak terenkripsi. Siapa pun yang membukanya bisa membaca semua catatanmu.';

  @override
  String get exportContinue => 'Lanjutkan';

  @override
  String exportDone(String fileName) {
    return 'Cadangan tersimpan: $fileName';
  }

  @override
  String get exportCancelled => 'Ekspor dibatalkan.';

  @override
  String get exportFailed => 'Gagal mengekspor.';

  @override
  String get importAction => 'Impor cadangan';

  @override
  String get importPreviewTitle => 'Pratinjau impor';

  @override
  String get importReplaceTitle => 'Ganti seluruh data?';

  @override
  String importReplaceBody(int memories, int reminders) {
    return 'File ini berisi $memories catatan dan $reminders pengingat. Semua data yang ada sekarang akan diganti.';
  }

  @override
  String get importConfirm => 'Ganti data';

  @override
  String get importCancel => 'Batal';

  @override
  String get importInvalid =>
      'File cadangan tidak valid atau tidak didukung. Data kamu tidak diubah.';

  @override
  String get importNotThisApp => 'Bukan file cadangan aplikasi ini.';

  @override
  String get importVersionUnsupported => 'Versi cadangan tidak didukung.';

  @override
  String get importInconsistent => 'Isi file tidak konsisten.';

  @override
  String get importDuplicate => 'Data duplikat ditemukan.';

  @override
  String get importBadReference => 'Referensi data tidak valid.';

  @override
  String get importBadMemory => 'Data catatan tidak valid.';

  @override
  String get importBadReminder => 'Data pengingat tidak valid.';

  @override
  String get importBadDate => 'Tanggal tidak valid.';

  @override
  String get importFileTooBig => 'File terlalu besar.';

  @override
  String get importCancelled => 'Impor dibatalkan.';

  @override
  String get importFailed => 'Impor gagal. Data kamu tidak diubah.';

  @override
  String importSuccess(int memories, int reminders) {
    return 'Berhasil memulihkan $memories catatan dan $reminders pengingat.';
  }

  @override
  String get importWarnTimezone =>
      'Ada pengingat dengan zona waktu yang tidak dikenal.';

  @override
  String get importWarnLocalDatetime =>
      'Ada pengingat tanpa waktu lokal yang bisa dibaca.';

  @override
  String get importSchedulingWarningTitle =>
      'Pengingat perlu dijadwalkan ulang';

  @override
  String get notifHiddenBody =>
      'Kamu punya pengingat. Buka aplikasi untuk melihat.';

  @override
  String get notifChannelName => 'Pengingat';

  @override
  String get notifChannelDesc => 'Pengingat dari catatanmu.';

  @override
  String get notifGenericTitle => 'Nanti Ingatkan Aku';

  @override
  String get privacyTitle => 'Privasi';

  @override
  String get privacyStatement =>
      'Semua catatan disimpan di HP ini. Tidak ada akun, tidak ada server, tidak ada pelacakan.';

  @override
  String get privacyBackupDisabled =>
      'Pencadangan otomatis Android dimatikan supaya catatan tidak ikut ke cloud. Karena itu, ekspor cadangan adalah satu-satunya cara memulihkan data.';

  @override
  String get privacyExportUnencrypted =>
      'File ekspor tidak terenkripsi dan tidak bisa dikunci dengan kata sandi.';

  @override
  String get privacyHideContent => 'Sembunyikan isi notifikasi';

  @override
  String get privacyHideContentDesc =>
      'Kalau aktif, layar kunci hanya menampilkan pemberitahuan umum tanpa judul catatan.';

  @override
  String get privacyDeleteAll => 'Hapus semua data';

  @override
  String get deleteAllConfirm =>
      'Hapus semua data? Semua catatan dan pengingat akan dihapus permanen.';

  @override
  String deleteAllConfirmCount(int count) {
    return 'Hapus semua data? $count catatan dan semua pengingat akan dihapus permanen, dan aplikasi kembali ke awal.';
  }

  @override
  String get onboardingBody =>
      'Catat dalam beberapa detik: lokasi barang, pinjaman, garansi, jadwal perawatan. Cari lagi kapan saja tanpa internet. Pengingat bisa ditambahkan, tapi catatanmu tetap tersimpan walau notifikasi gagal.';

  @override
  String get onboardingStart => 'Mulai';

  @override
  String get onboardingRestore => 'Pulihkan dari cadangan';

  @override
  String get onboardingPrivacy =>
      'Tidak ada akun. Tidak ada server. Tinggal di HP ini.';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsSectionNotifications => 'Notifikasi';

  @override
  String get settingsSectionBackup => 'Cadangan';

  @override
  String get settingsSectionPrivacy => 'Privasi';

  @override
  String get settingsSectionAbout => 'Tentang';

  @override
  String get settingsSectionDiagnostics => 'Diagnostik';

  @override
  String get settingsNotificationsEnabled => 'Izin notifikasi';

  @override
  String get settingsExactAlarm => 'Alarm tepat waktu';

  @override
  String get settingsChannelEnabled => 'Kanal pengingat';

  @override
  String settingsPermissionNeededCount(int count) {
    return '$count pengingat menunggu izin notifikasi';
  }

  @override
  String settingsSchedulingFailedCount(int count) {
    return '$count pengingat gagal dijadwalkan';
  }

  @override
  String get settingsBatteryGuidance =>
      'Beberapa merek HP (Xiaomi, OPPO, vivo, Samsung) membatasi alarm latar belakang. Aplikasi ini tidak bisa menjamin notifikasi tepat waktu; buka pengaturan baterai kalau pengingat sering terlambat.';

  @override
  String get settingsOpenAppSettings => 'Buka pengaturan aplikasi';

  @override
  String get settingsEnabled => 'Aktif';

  @override
  String get settingsDisabled => 'Tidak aktif';

  @override
  String get settingsUnavailable => 'Tidak tersedia';

  @override
  String get settingsAboutLimitations =>
      'Pengingat dikirim oleh sistem Android: pengirimannya best-effort dan bisa tertunda. Catatanmu selalu jadi sumber kebenaran dan selalu terlihat di aplikasi.';

  @override
  String settingsVersion(String version) {
    return 'Versi $version';
  }

  @override
  String get settingsBackupNudge =>
      'Belum pernah mencadangkan data. Kalau HP hilang, catatan tidak bisa dipulihkan.';

  @override
  String get settingsBackupNudgeDismiss => 'Tutup';

  @override
  String get settingsDiagnosticsLink => 'Lihat diagnostik';

  @override
  String get settingsPrivacyLink => 'Baca pernyataan privasi';

  @override
  String get diagnosticsTitle => 'Diagnostik';

  @override
  String diagnosticsCounts(int memories, int reminders) {
    return 'Catatan: $memories • Pengingat: $reminders';
  }

  @override
  String diagnosticsPending(int count) {
    return 'Pengingat aktif: $count';
  }

  @override
  String diagnosticsLastReconcile(String when) {
    return 'Pemeriksaan terakhir: $when';
  }

  @override
  String diagnosticsLastErrorCode(String code) {
    return 'Kode kesalahan terakhir: $code';
  }

  @override
  String get diagnosticsNone => 'Tidak ada';

  @override
  String diagnosticsSchema(int version) {
    return 'Skema basis data: $version';
  }

  @override
  String diagnosticsTimezone(String zone) {
    return 'Zona perangkat: $zone';
  }

  @override
  String get diagnosticsNoContentNotice =>
      'Halaman ini tidak pernah menampilkan isi catatan atau notifikasi.';

  @override
  String get commonCancel => 'Batal';

  @override
  String get commonRetry => 'Coba lagi';

  @override
  String get commonDelete => 'Hapus';

  @override
  String get commonClose => 'Tutup';

  @override
  String get commonOk => 'Mengerti';

  @override
  String get a11yClearSearch => 'Hapus pencarian';

  @override
  String a11yStatusChip(String status) {
    return 'Status: $status';
  }

  @override
  String a11yOpenMemory(String title) {
    return 'Buka catatan $title';
  }
}
