import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('id')];

  /// No description provided for @appName.
  ///
  /// In id, this message translates to:
  /// **'Nanti Ingatkan Aku'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In id, this message translates to:
  /// **'Simpan hal kecil sebelum lupa.'**
  String get appTagline;

  /// No description provided for @navToday.
  ///
  /// In id, this message translates to:
  /// **'Hari Ini'**
  String get navToday;

  /// No description provided for @navMemories.
  ///
  /// In id, this message translates to:
  /// **'Catatan'**
  String get navMemories;

  /// No description provided for @navSettings.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get navSettings;

  /// No description provided for @captureTitleHint.
  ///
  /// In id, this message translates to:
  /// **'Apa yang ingin kamu ingat?'**
  String get captureTitleHint;

  /// No description provided for @captureBodyHint.
  ///
  /// In id, this message translates to:
  /// **'Detail (opsional)'**
  String get captureBodyHint;

  /// No description provided for @captureRemindMe.
  ///
  /// In id, this message translates to:
  /// **'Ingatkan aku'**
  String get captureRemindMe;

  /// No description provided for @captureSave.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get captureSave;

  /// No description provided for @captureSaved.
  ///
  /// In id, this message translates to:
  /// **'Catatan tersimpan'**
  String get captureSaved;

  /// No description provided for @captureNewTitle.
  ///
  /// In id, this message translates to:
  /// **'Catat'**
  String get captureNewTitle;

  /// No description provided for @captureEditTitle.
  ///
  /// In id, this message translates to:
  /// **'Ubah catatan'**
  String get captureEditTitle;

  /// No description provided for @captureTitleCounter.
  ///
  /// In id, this message translates to:
  /// **'{count}/{max}'**
  String captureTitleCounter(int count, int max);

  /// No description provided for @captureBodyCounter.
  ///
  /// In id, this message translates to:
  /// **'{count}/{max}'**
  String captureBodyCounter(int count, int max);

  /// No description provided for @categoryGeneral.
  ///
  /// In id, this message translates to:
  /// **'Umum'**
  String get categoryGeneral;

  /// No description provided for @categoryLentItem.
  ///
  /// In id, this message translates to:
  /// **'Dipinjamkan'**
  String get categoryLentItem;

  /// No description provided for @categoryWarranty.
  ///
  /// In id, this message translates to:
  /// **'Garansi'**
  String get categoryWarranty;

  /// No description provided for @categoryMaintenance.
  ///
  /// In id, this message translates to:
  /// **'Perawatan'**
  String get categoryMaintenance;

  /// No description provided for @categoryAll.
  ///
  /// In id, this message translates to:
  /// **'Semua'**
  String get categoryAll;

  /// No description provided for @categoryChangeTitle.
  ///
  /// In id, this message translates to:
  /// **'Ganti kategori?'**
  String get categoryChangeTitle;

  /// No description provided for @categoryClearMetadata.
  ///
  /// In id, this message translates to:
  /// **'Isian yang tidak lagi berlaku untuk kategori baru akan dihapus.'**
  String get categoryClearMetadata;

  /// No description provided for @fieldLentTo.
  ///
  /// In id, this message translates to:
  /// **'Dipinjamkan ke'**
  String get fieldLentTo;

  /// No description provided for @fieldItemName.
  ///
  /// In id, this message translates to:
  /// **'Nama barang'**
  String get fieldItemName;

  /// No description provided for @fieldWarrantyEnd.
  ///
  /// In id, this message translates to:
  /// **'Garansi berakhir'**
  String get fieldWarrantyEnd;

  /// No description provided for @fieldPickDate.
  ///
  /// In id, this message translates to:
  /// **'Pilih tanggal'**
  String get fieldPickDate;

  /// No description provided for @reminderSectionTitle.
  ///
  /// In id, this message translates to:
  /// **'Pengingat'**
  String get reminderSectionTitle;

  /// No description provided for @reminderPreset1h.
  ///
  /// In id, this message translates to:
  /// **'1 jam lagi'**
  String get reminderPreset1h;

  /// No description provided for @reminderPresetTonight.
  ///
  /// In id, this message translates to:
  /// **'Nanti malam (20.00)'**
  String get reminderPresetTonight;

  /// No description provided for @reminderPresetTomorrow.
  ///
  /// In id, this message translates to:
  /// **'Besok (09.00)'**
  String get reminderPresetTomorrow;

  /// No description provided for @reminderPresetWeek.
  ///
  /// In id, this message translates to:
  /// **'Minggu depan'**
  String get reminderPresetWeek;

  /// No description provided for @reminderPick.
  ///
  /// In id, this message translates to:
  /// **'Pilih tanggal & waktu'**
  String get reminderPick;

  /// No description provided for @reminderScheduled.
  ///
  /// In id, this message translates to:
  /// **'Terjadwal'**
  String get reminderScheduled;

  /// No description provided for @reminderScheduledAt.
  ///
  /// In id, this message translates to:
  /// **'Terjadwal {when}'**
  String reminderScheduledAt(String when);

  /// No description provided for @reminderInexact.
  ///
  /// In id, this message translates to:
  /// **'Perkiraan waktu (bisa terlambat beberapa menit).'**
  String get reminderInexact;

  /// No description provided for @reminderPermissionNeeded.
  ///
  /// In id, this message translates to:
  /// **'Perlu izin notifikasi'**
  String get reminderPermissionNeeded;

  /// No description provided for @reminderFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal dijadwalkan'**
  String get reminderFailed;

  /// No description provided for @reminderOverdue.
  ///
  /// In id, this message translates to:
  /// **'Terlewat'**
  String get reminderOverdue;

  /// No description provided for @reminderOverdueSince.
  ///
  /// In id, this message translates to:
  /// **'Terlewat sejak {when}'**
  String reminderOverdueSince(String when);

  /// No description provided for @reminderDone.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get reminderDone;

  /// No description provided for @reminderDoneAt.
  ///
  /// In id, this message translates to:
  /// **'Selesai pada {when}'**
  String reminderDoneAt(String when);

  /// No description provided for @reminderMarkDone.
  ///
  /// In id, this message translates to:
  /// **'Tandai selesai'**
  String get reminderMarkDone;

  /// No description provided for @reminderCreate.
  ///
  /// In id, this message translates to:
  /// **'Buat pengingat'**
  String get reminderCreate;

  /// No description provided for @reminderChange.
  ///
  /// In id, this message translates to:
  /// **'Ubah pengingat'**
  String get reminderChange;

  /// No description provided for @reminderNew.
  ///
  /// In id, this message translates to:
  /// **'Buat pengingat baru'**
  String get reminderNew;

  /// No description provided for @reminderDeferred.
  ///
  /// In id, this message translates to:
  /// **'Menunggu penjadwalan'**
  String get reminderDeferred;

  /// No description provided for @reminderRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get reminderRetry;

  /// No description provided for @reminderOpenSettings.
  ///
  /// In id, this message translates to:
  /// **'Buka pengaturan'**
  String get reminderOpenSettings;

  /// No description provided for @reminderNone.
  ///
  /// In id, this message translates to:
  /// **'Belum ada pengingat.'**
  String get reminderNone;

  /// No description provided for @reminderZoneNote.
  ///
  /// In id, this message translates to:
  /// **'Diatur pada zona {original}; perangkat sekarang di {current}.'**
  String reminderZoneNote(String original, String current);

  /// No description provided for @reminderShiftedNote.
  ///
  /// In id, this message translates to:
  /// **'Waktu ini tidak ada di zona {zone} (perubahan DST). Digeser ke {when}.'**
  String reminderShiftedNote(String zone, String when);

  /// No description provided for @reminderAmbiguousNote.
  ///
  /// In id, this message translates to:
  /// **'Waktu ini terjadi dua kali di zona {zone}. Dipakai yang lebih awal: {when}.'**
  String reminderAmbiguousNote(String zone, String when);

  /// No description provided for @reminderDoneSnack.
  ///
  /// In id, this message translates to:
  /// **'Pengingat selesai'**
  String get reminderDoneSnack;

  /// No description provided for @reminderUndo.
  ///
  /// In id, this message translates to:
  /// **'Urungkan'**
  String get reminderUndo;

  /// No description provided for @errorTitleEmpty.
  ///
  /// In id, this message translates to:
  /// **'Judul tidak boleh kosong.'**
  String get errorTitleEmpty;

  /// No description provided for @errorTitleTooLong.
  ///
  /// In id, this message translates to:
  /// **'Judul maksimal 120 karakter.'**
  String get errorTitleTooLong;

  /// No description provided for @errorBodyTooLong.
  ///
  /// In id, this message translates to:
  /// **'Detail maksimal 10.000 karakter.'**
  String get errorBodyTooLong;

  /// No description provided for @errorPersonTooLong.
  ///
  /// In id, this message translates to:
  /// **'Nama orang maksimal 80 karakter.'**
  String get errorPersonTooLong;

  /// No description provided for @errorItemTooLong.
  ///
  /// In id, this message translates to:
  /// **'Nama barang maksimal 120 karakter.'**
  String get errorItemTooLong;

  /// No description provided for @errorDateInvalid.
  ///
  /// In id, this message translates to:
  /// **'Tanggal tidak valid.'**
  String get errorDateInvalid;

  /// No description provided for @errorDuePast.
  ///
  /// In id, this message translates to:
  /// **'Waktu pengingat harus di masa depan.'**
  String get errorDuePast;

  /// No description provided for @errorSaveFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan. Coba lagi.'**
  String get errorSaveFailed;

  /// No description provided for @errorGeneric.
  ///
  /// In id, this message translates to:
  /// **'Terjadi masalah. Coba lagi.'**
  String get errorGeneric;

  /// No description provided for @errorDbNewer.
  ///
  /// In id, this message translates to:
  /// **'Data dibuat oleh versi aplikasi yang lebih baru.'**
  String get errorDbNewer;

  /// No description provided for @permissionRationale.
  ///
  /// In id, this message translates to:
  /// **'Supaya pengingat muncul, izinkan notifikasi. Catatanmu tetap tersimpan tanpa izin ini.'**
  String get permissionRationale;

  /// No description provided for @permissionRationaleContinue.
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan'**
  String get permissionRationaleContinue;

  /// No description provided for @permissionRationaleCancel.
  ///
  /// In id, this message translates to:
  /// **'Nanti saja'**
  String get permissionRationaleCancel;

  /// No description provided for @permissionDeniedBanner.
  ///
  /// In id, this message translates to:
  /// **'Izin notifikasi belum aktif. Pengingat tetap terlihat di Hari Ini, tapi tidak ada notifikasi.'**
  String get permissionDeniedBanner;

  /// No description provided for @todayTitle.
  ///
  /// In id, this message translates to:
  /// **'Hari Ini'**
  String get todayTitle;

  /// No description provided for @todayEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada yang perlu diingat hari ini.'**
  String get todayEmpty;

  /// No description provided for @todayEmptyCta.
  ///
  /// In id, this message translates to:
  /// **'Catat sesuatu'**
  String get todayEmptyCta;

  /// No description provided for @todayCoach.
  ///
  /// In id, this message translates to:
  /// **'Catatan tanpa pengingat tetap ada di tab Catatan.'**
  String get todayCoach;

  /// No description provided for @todaySectionOverdue.
  ///
  /// In id, this message translates to:
  /// **'Terlewat'**
  String get todaySectionOverdue;

  /// No description provided for @todaySectionToday.
  ///
  /// In id, this message translates to:
  /// **'Hari ini'**
  String get todaySectionToday;

  /// No description provided for @todaySectionUpcoming.
  ///
  /// In id, this message translates to:
  /// **'7 hari ke depan'**
  String get todaySectionUpcoming;

  /// No description provided for @todaySeeAll.
  ///
  /// In id, this message translates to:
  /// **'Lihat semua'**
  String get todaySeeAll;

  /// No description provided for @todayDeletedMemory.
  ///
  /// In id, this message translates to:
  /// **'Catatan ini sudah dihapus.'**
  String get todayDeletedMemory;

  /// No description provided for @memoriesTitle.
  ///
  /// In id, this message translates to:
  /// **'Catatan'**
  String get memoriesTitle;

  /// No description provided for @memoriesSearchHint.
  ///
  /// In id, this message translates to:
  /// **'Cari judul atau detail...'**
  String get memoriesSearchHint;

  /// No description provided for @memoriesEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada catatan. Mulai dari hal kecil yang mudah lupa.'**
  String get memoriesEmpty;

  /// No description provided for @memoriesNoResults.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada hasil untuk \"{query}\".'**
  String memoriesNoResults(String query);

  /// No description provided for @memoriesArchiveEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada catatan yang diarsipkan.'**
  String get memoriesArchiveEmpty;

  /// No description provided for @memoriesLoadMore.
  ///
  /// In id, this message translates to:
  /// **'Muat lagi'**
  String get memoriesLoadMore;

  /// No description provided for @memoriesArchivedToggle.
  ///
  /// In id, this message translates to:
  /// **'Arsip'**
  String get memoriesArchivedToggle;

  /// No description provided for @memoriesArchivedBadge.
  ///
  /// In id, this message translates to:
  /// **'Diarsipkan'**
  String get memoriesArchivedBadge;

  /// No description provided for @detailCreated.
  ///
  /// In id, this message translates to:
  /// **'Dibuat {when}'**
  String detailCreated(String when);

  /// No description provided for @detailUpdated.
  ///
  /// In id, this message translates to:
  /// **'Diperbarui {when}'**
  String detailUpdated(String when);

  /// No description provided for @detailActionEdit.
  ///
  /// In id, this message translates to:
  /// **'Ubah'**
  String get detailActionEdit;

  /// No description provided for @detailActionArchive.
  ///
  /// In id, this message translates to:
  /// **'Arsipkan'**
  String get detailActionArchive;

  /// No description provided for @detailActionUnarchive.
  ///
  /// In id, this message translates to:
  /// **'Kembalikan dari arsip'**
  String get detailActionUnarchive;

  /// No description provided for @detailActionDelete.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get detailActionDelete;

  /// No description provided for @detailArchiveSnack.
  ///
  /// In id, this message translates to:
  /// **'Diarsipkan'**
  String get detailArchiveSnack;

  /// No description provided for @archiveKeepsReminder.
  ///
  /// In id, this message translates to:
  /// **'Pengingat tetap aktif dan tetap muncul di Hari Ini.'**
  String get archiveKeepsReminder;

  /// No description provided for @detailUnarchiveSnack.
  ///
  /// In id, this message translates to:
  /// **'Dikembalikan ke daftar'**
  String get detailUnarchiveSnack;

  /// No description provided for @deleteConfirmNamed.
  ///
  /// In id, this message translates to:
  /// **'Hapus \"{title}\"? Pengingatnya juga akan dihapus. Tindakan ini tidak bisa dibatalkan.'**
  String deleteConfirmNamed(String title);

  /// No description provided for @draftDiscardTitle.
  ///
  /// In id, this message translates to:
  /// **'Buang catatan ini?'**
  String get draftDiscardTitle;

  /// No description provided for @draftKeep.
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan menulis'**
  String get draftKeep;

  /// No description provided for @draftDiscard.
  ///
  /// In id, this message translates to:
  /// **'Buang'**
  String get draftDiscard;

  /// No description provided for @exportAction.
  ///
  /// In id, this message translates to:
  /// **'Ekspor cadangan'**
  String get exportAction;

  /// No description provided for @exportWarning.
  ///
  /// In id, this message translates to:
  /// **'File cadangan tidak terenkripsi. Siapa pun yang membukanya bisa membaca semua catatanmu.'**
  String get exportWarning;

  /// No description provided for @exportContinue.
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan'**
  String get exportContinue;

  /// No description provided for @exportDone.
  ///
  /// In id, this message translates to:
  /// **'Cadangan tersimpan: {fileName}'**
  String exportDone(String fileName);

  /// No description provided for @exportCancelled.
  ///
  /// In id, this message translates to:
  /// **'Ekspor dibatalkan.'**
  String get exportCancelled;

  /// No description provided for @exportFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengekspor.'**
  String get exportFailed;

  /// No description provided for @importAction.
  ///
  /// In id, this message translates to:
  /// **'Impor cadangan'**
  String get importAction;

  /// No description provided for @importPreviewTitle.
  ///
  /// In id, this message translates to:
  /// **'Pratinjau impor'**
  String get importPreviewTitle;

  /// No description provided for @importReplaceTitle.
  ///
  /// In id, this message translates to:
  /// **'Ganti seluruh data?'**
  String get importReplaceTitle;

  /// No description provided for @importReplaceBody.
  ///
  /// In id, this message translates to:
  /// **'File ini berisi {memories} catatan dan {reminders} pengingat. Semua data yang ada sekarang akan diganti.'**
  String importReplaceBody(int memories, int reminders);

  /// No description provided for @importConfirm.
  ///
  /// In id, this message translates to:
  /// **'Ganti data'**
  String get importConfirm;

  /// No description provided for @importCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get importCancel;

  /// No description provided for @importInvalid.
  ///
  /// In id, this message translates to:
  /// **'File cadangan tidak valid atau tidak didukung. Data kamu tidak diubah.'**
  String get importInvalid;

  /// No description provided for @importNotThisApp.
  ///
  /// In id, this message translates to:
  /// **'Bukan file cadangan aplikasi ini.'**
  String get importNotThisApp;

  /// No description provided for @importVersionUnsupported.
  ///
  /// In id, this message translates to:
  /// **'Versi cadangan tidak didukung.'**
  String get importVersionUnsupported;

  /// No description provided for @importInconsistent.
  ///
  /// In id, this message translates to:
  /// **'Isi file tidak konsisten.'**
  String get importInconsistent;

  /// No description provided for @importDuplicate.
  ///
  /// In id, this message translates to:
  /// **'Data duplikat ditemukan.'**
  String get importDuplicate;

  /// No description provided for @importBadReference.
  ///
  /// In id, this message translates to:
  /// **'Referensi data tidak valid.'**
  String get importBadReference;

  /// No description provided for @importBadMemory.
  ///
  /// In id, this message translates to:
  /// **'Data catatan tidak valid.'**
  String get importBadMemory;

  /// No description provided for @importBadReminder.
  ///
  /// In id, this message translates to:
  /// **'Data pengingat tidak valid.'**
  String get importBadReminder;

  /// No description provided for @importBadDate.
  ///
  /// In id, this message translates to:
  /// **'Tanggal tidak valid.'**
  String get importBadDate;

  /// No description provided for @importFileTooBig.
  ///
  /// In id, this message translates to:
  /// **'File terlalu besar.'**
  String get importFileTooBig;

  /// No description provided for @importCancelled.
  ///
  /// In id, this message translates to:
  /// **'Impor dibatalkan.'**
  String get importCancelled;

  /// No description provided for @importFailed.
  ///
  /// In id, this message translates to:
  /// **'Impor gagal. Data kamu tidak diubah.'**
  String get importFailed;

  /// No description provided for @importSuccess.
  ///
  /// In id, this message translates to:
  /// **'Berhasil memulihkan {memories} catatan dan {reminders} pengingat.'**
  String importSuccess(int memories, int reminders);

  /// No description provided for @importWarnTimezone.
  ///
  /// In id, this message translates to:
  /// **'Ada pengingat dengan zona waktu yang tidak dikenal.'**
  String get importWarnTimezone;

  /// No description provided for @importWarnLocalDatetime.
  ///
  /// In id, this message translates to:
  /// **'Ada pengingat tanpa waktu lokal yang bisa dibaca.'**
  String get importWarnLocalDatetime;

  /// No description provided for @importSchedulingWarningTitle.
  ///
  /// In id, this message translates to:
  /// **'Pengingat perlu dijadwalkan ulang'**
  String get importSchedulingWarningTitle;

  /// No description provided for @notifHiddenBody.
  ///
  /// In id, this message translates to:
  /// **'Kamu punya pengingat. Buka aplikasi untuk melihat.'**
  String get notifHiddenBody;

  /// No description provided for @notifChannelName.
  ///
  /// In id, this message translates to:
  /// **'Pengingat'**
  String get notifChannelName;

  /// No description provided for @notifChannelDesc.
  ///
  /// In id, this message translates to:
  /// **'Pengingat dari catatanmu.'**
  String get notifChannelDesc;

  /// No description provided for @notifGenericTitle.
  ///
  /// In id, this message translates to:
  /// **'Nanti Ingatkan Aku'**
  String get notifGenericTitle;

  /// No description provided for @privacyTitle.
  ///
  /// In id, this message translates to:
  /// **'Privasi'**
  String get privacyTitle;

  /// No description provided for @privacyStatement.
  ///
  /// In id, this message translates to:
  /// **'Semua catatan disimpan di HP ini. Tidak ada akun, tidak ada server, tidak ada pelacakan.'**
  String get privacyStatement;

  /// No description provided for @privacyBackupDisabled.
  ///
  /// In id, this message translates to:
  /// **'Pencadangan otomatis Android dimatikan supaya catatan tidak ikut ke cloud. Karena itu, ekspor cadangan adalah satu-satunya cara memulihkan data.'**
  String get privacyBackupDisabled;

  /// No description provided for @privacyExportUnencrypted.
  ///
  /// In id, this message translates to:
  /// **'File ekspor tidak terenkripsi dan tidak bisa dikunci dengan kata sandi.'**
  String get privacyExportUnencrypted;

  /// No description provided for @privacyHideContent.
  ///
  /// In id, this message translates to:
  /// **'Sembunyikan isi notifikasi'**
  String get privacyHideContent;

  /// No description provided for @privacyHideContentDesc.
  ///
  /// In id, this message translates to:
  /// **'Kalau aktif, layar kunci hanya menampilkan pemberitahuan umum tanpa judul catatan.'**
  String get privacyHideContentDesc;

  /// No description provided for @privacyDeleteAll.
  ///
  /// In id, this message translates to:
  /// **'Hapus semua data'**
  String get privacyDeleteAll;

  /// No description provided for @deleteAllConfirm.
  ///
  /// In id, this message translates to:
  /// **'Hapus semua data? Semua catatan dan pengingat akan dihapus permanen.'**
  String get deleteAllConfirm;

  /// No description provided for @deleteAllConfirmCount.
  ///
  /// In id, this message translates to:
  /// **'Hapus semua data? {count} catatan dan semua pengingat akan dihapus permanen, dan aplikasi kembali ke awal.'**
  String deleteAllConfirmCount(int count);

  /// No description provided for @onboardingBody.
  ///
  /// In id, this message translates to:
  /// **'Catat dalam beberapa detik: lokasi barang, pinjaman, garansi, jadwal perawatan. Cari lagi kapan saja tanpa internet. Pengingat bisa ditambahkan, tapi catatanmu tetap tersimpan walau notifikasi gagal.'**
  String get onboardingBody;

  /// No description provided for @onboardingStart.
  ///
  /// In id, this message translates to:
  /// **'Mulai'**
  String get onboardingStart;

  /// No description provided for @onboardingRestore.
  ///
  /// In id, this message translates to:
  /// **'Pulihkan dari cadangan'**
  String get onboardingRestore;

  /// No description provided for @onboardingPrivacy.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada akun. Tidak ada server. Tinggal di HP ini.'**
  String get onboardingPrivacy;

  /// No description provided for @settingsTitle.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get settingsTitle;

  /// No description provided for @settingsSectionNotifications.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi'**
  String get settingsSectionNotifications;

  /// No description provided for @settingsSectionBackup.
  ///
  /// In id, this message translates to:
  /// **'Cadangan'**
  String get settingsSectionBackup;

  /// No description provided for @settingsSectionPrivacy.
  ///
  /// In id, this message translates to:
  /// **'Privasi'**
  String get settingsSectionPrivacy;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In id, this message translates to:
  /// **'Tentang'**
  String get settingsSectionAbout;

  /// No description provided for @settingsSectionDiagnostics.
  ///
  /// In id, this message translates to:
  /// **'Diagnostik'**
  String get settingsSectionDiagnostics;

  /// No description provided for @settingsNotificationsEnabled.
  ///
  /// In id, this message translates to:
  /// **'Izin notifikasi'**
  String get settingsNotificationsEnabled;

  /// No description provided for @settingsExactAlarm.
  ///
  /// In id, this message translates to:
  /// **'Alarm tepat waktu'**
  String get settingsExactAlarm;

  /// No description provided for @settingsChannelEnabled.
  ///
  /// In id, this message translates to:
  /// **'Kanal pengingat'**
  String get settingsChannelEnabled;

  /// No description provided for @settingsPermissionNeededCount.
  ///
  /// In id, this message translates to:
  /// **'{count} pengingat menunggu izin notifikasi'**
  String settingsPermissionNeededCount(int count);

  /// No description provided for @settingsSchedulingFailedCount.
  ///
  /// In id, this message translates to:
  /// **'{count} pengingat gagal dijadwalkan'**
  String settingsSchedulingFailedCount(int count);

  /// No description provided for @settingsBatteryGuidance.
  ///
  /// In id, this message translates to:
  /// **'Beberapa merek HP (Xiaomi, OPPO, vivo, Samsung) membatasi alarm latar belakang. Aplikasi ini tidak bisa menjamin notifikasi tepat waktu; buka pengaturan baterai kalau pengingat sering terlambat.'**
  String get settingsBatteryGuidance;

  /// No description provided for @settingsOpenAppSettings.
  ///
  /// In id, this message translates to:
  /// **'Buka pengaturan aplikasi'**
  String get settingsOpenAppSettings;

  /// No description provided for @settingsEnabled.
  ///
  /// In id, this message translates to:
  /// **'Aktif'**
  String get settingsEnabled;

  /// No description provided for @settingsDisabled.
  ///
  /// In id, this message translates to:
  /// **'Tidak aktif'**
  String get settingsDisabled;

  /// No description provided for @settingsUnavailable.
  ///
  /// In id, this message translates to:
  /// **'Tidak tersedia'**
  String get settingsUnavailable;

  /// No description provided for @settingsAboutLimitations.
  ///
  /// In id, this message translates to:
  /// **'Pengingat dikirim oleh sistem Android: pengirimannya best-effort dan bisa tertunda. Catatanmu selalu jadi sumber kebenaran dan selalu terlihat di aplikasi.'**
  String get settingsAboutLimitations;

  /// No description provided for @settingsVersion.
  ///
  /// In id, this message translates to:
  /// **'Versi {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsBackupNudge.
  ///
  /// In id, this message translates to:
  /// **'Belum pernah mencadangkan data. Kalau HP hilang, catatan tidak bisa dipulihkan.'**
  String get settingsBackupNudge;

  /// No description provided for @settingsBackupNudgeDismiss.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get settingsBackupNudgeDismiss;

  /// No description provided for @settingsDiagnosticsLink.
  ///
  /// In id, this message translates to:
  /// **'Lihat diagnostik'**
  String get settingsDiagnosticsLink;

  /// No description provided for @settingsPrivacyLink.
  ///
  /// In id, this message translates to:
  /// **'Baca pernyataan privasi'**
  String get settingsPrivacyLink;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In id, this message translates to:
  /// **'Diagnostik'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsCounts.
  ///
  /// In id, this message translates to:
  /// **'Catatan: {memories} • Pengingat: {reminders}'**
  String diagnosticsCounts(int memories, int reminders);

  /// No description provided for @diagnosticsPending.
  ///
  /// In id, this message translates to:
  /// **'Pengingat aktif: {count}'**
  String diagnosticsPending(int count);

  /// No description provided for @diagnosticsLastReconcile.
  ///
  /// In id, this message translates to:
  /// **'Pemeriksaan terakhir: {when}'**
  String diagnosticsLastReconcile(String when);

  /// No description provided for @diagnosticsLastErrorCode.
  ///
  /// In id, this message translates to:
  /// **'Kode kesalahan terakhir: {code}'**
  String diagnosticsLastErrorCode(String code);

  /// No description provided for @diagnosticsNone.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada'**
  String get diagnosticsNone;

  /// No description provided for @diagnosticsSchema.
  ///
  /// In id, this message translates to:
  /// **'Skema basis data: {version}'**
  String diagnosticsSchema(int version);

  /// No description provided for @diagnosticsTimezone.
  ///
  /// In id, this message translates to:
  /// **'Zona perangkat: {zone}'**
  String diagnosticsTimezone(String zone);

  /// No description provided for @diagnosticsNoContentNotice.
  ///
  /// In id, this message translates to:
  /// **'Halaman ini tidak pernah menampilkan isi catatan atau notifikasi.'**
  String get diagnosticsNoContentNotice;

  /// No description provided for @commonCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get commonRetry;

  /// No description provided for @commonDelete.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get commonClose;

  /// No description provided for @commonOk.
  ///
  /// In id, this message translates to:
  /// **'Mengerti'**
  String get commonOk;

  /// No description provided for @a11yClearSearch.
  ///
  /// In id, this message translates to:
  /// **'Hapus pencarian'**
  String get a11yClearSearch;

  /// No description provided for @a11yStatusChip.
  ///
  /// In id, this message translates to:
  /// **'Status: {status}'**
  String a11yStatusChip(String status);

  /// No description provided for @a11yOpenMemory.
  ///
  /// In id, this message translates to:
  /// **'Buka catatan {title}'**
  String a11yOpenMemory(String title);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
