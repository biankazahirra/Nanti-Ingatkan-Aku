import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// File-system port so the backup flows are testable without a device picker
/// (FR-EXP-02: the user always chooses the destination).
abstract class BackupFilePort {
  /// Returns the chosen destination path, or null when cancelled.
  Future<String?> saveJson({
    required String fileName,
    required String content,
    required String dialogTitle,
  });

  /// Returns the chosen source path, or null when cancelled.
  Future<String?> pickJsonFile({required String dialogTitle});

  Future<int> sizeOf(String path);

  Future<String> readText(String path, {required int maxBytes});
}

class FilePickerBackupFilePort implements BackupFilePort {
  const FilePickerBackupFilePort();

  @override
  Future<String?> saveJson({
    required String fileName,
    required String content,
    required String dialogTitle,
  }) async {
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(content)),
      mimeType: 'application/json',
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    ).then((uri) => uri?.toString());
  }

  @override
  Future<String?> pickJsonFile({required String dialogTitle}) async {
    final files = await FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.length != 1) return null;
    final file = files.first;
    final path = file.path;
    if (path != null && path.isNotEmpty) return path;
    // SAF/content URI: no local path, so stage a readable copy.
    final bytes = await file.xFile.readAsBytes();
    final staged = File(
      p.join((await getTemporaryDirectory()).path, file.name),
    );
    await staged.writeAsBytes(bytes, flush: true);
    return staged.path;
  }

  @override
  Future<int> sizeOf(String path) => File(path).length();

  @override
  Future<String> readText(String path, {required int maxBytes}) async {
    final file = File(path);
    final length = await file.length();
    if (length > maxBytes) {
      throw const BackupFileTooLarge();
    }
    // Byte cap enforced before decoding; the decoder never sees a bigger buffer.
    final bytes = await file
        .openRead(0, maxBytes)
        .fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk));
    return utf8.decode(bytes);
  }
}

/// Thrown before any decode when the file exceeds [Limits.importMaxBytes].
class BackupFileTooLarge implements Exception {
  const BackupFileTooLarge();

  @override
  String toString() => 'BackupFileTooLarge';
}
