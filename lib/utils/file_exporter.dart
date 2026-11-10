import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

enum FileExportResult { success, cancelled }

/// 作成済みのファイルを利用者に渡す。
class FileExporter {
  /// Android / iOS ではデスクトップ以外のため [isMobile] の判定に使う。
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// [file] を利用者に渡す。
  ///
  /// - Android / iOS: share_plus の共有シートを開く
  /// - Windows / macOS / Linux: 保存ダイアログで保存先を選ばせ、複写する
  ///   (file_picker の saveFile はデスクトップではパスを返すだけでファイルを
  ///   書かないため、複写はこちらの責務)
  static Future<FileExportResult> export({
    required File file,
    required String fileName,
    required String mimeType,
    required String extension,
    String? dialogTitle,
  }) async {
    if (isMobile) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: mimeType)]),
      );
      return FileExportResult.success;
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
    );
    if (path == null) return FileExportResult.cancelled;
    await file.copy(path);
    return FileExportResult.success;
  }
}
