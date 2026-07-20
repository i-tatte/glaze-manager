import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

enum PngExportResult { success, cancelled }

/// RepaintBoundary のキャプチャと、プラットフォーム別の PNG エクスポートを担う。
class PngExporter {
  /// [key] が付いた RepaintBoundary を PNG バイト列にキャプチャする。
  static Future<Uint8List> captureBoundary(
    GlobalKey key, {
    double pixelRatio = 2.5,
  }) async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('PNGへの変換に失敗しました');
      }
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// PNG をエクスポートする。
  ///
  /// - Android / iOS: share_plus の共有シートを開く
  /// - Windows / macOS / Linux: 保存ダイアログでパスを選ばせて自前で書き込む
  ///   (デスクトップの共有UIは共有先が乏しく実用性が低いため share_plus は使わない。
  ///   また file_picker の saveFile はデスクトップではパスを返すだけでファイルを
  ///   書かないため、書き込みはこちらの責務)
  static Future<PngExportResult> export({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final file = XFile.fromData(bytes, mimeType: 'image/png', name: fileName);
      await SharePlus.instance.share(ShareParams(files: [file]));
      return PngExportResult.success;
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'PNGを保存',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['png'],
    );
    if (path == null) return PngExportResult.cancelled;
    await File(path).writeAsBytes(bytes);
    return PngExportResult.success;
  }

  /// ファイル名に使えない文字を除去する (Windows の禁止文字基準)
  static String sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'test_piece' : sanitized;
  }
}
