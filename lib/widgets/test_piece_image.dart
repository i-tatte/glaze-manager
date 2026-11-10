import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/widgets/common/app_network_image.dart';

/// テストピースの写真の表示。一覧・詳細・比較・共有で共通に使う。
///
/// - アップロード待ちがあれば、端末内の画像を表示し、左上に印を重ねる
///   (直前の送信が失敗していれば印を cloud_off にする)
/// - 待ちがなく URL があれば、ネットワークの画像を表示する
/// - 待ちも URL もなく imagePath があれば、Cloud Functions の処理待ち
/// - imagePath もなければ、写真がない
class TestPieceImage extends ConsumerWidget {
  final TestPiece testPiece;

  /// 一覧では true (サムネイル優先)、詳細では false
  final bool preferThumbnail;
  final BoxFit fit;
  final double iconSize;

  /// アップロード待ちの印を出すか。共有画像のように、写真だけを書き出す
  /// 場面では false にする。
  final bool showPendingBadge;

  const TestPieceImage({
    super.key,
    required this.testPiece,
    this.preferThumbnail = true,
    this.fit = BoxFit.cover,
    this.iconSize = 40,
    this.showPendingBadge = true,
  });

  /// AppNetworkImage と同じ見た目の灰色の地とアイコン
  Widget _iconContainer(IconData icon) {
    return Container(
      color: Colors.grey[200],
      child: Icon(icon, size: iconSize, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = testPiece.id;
    final pending = id == null
        ? null
        : ref.watch(uploadQueueProvider).pending[id];

    if (pending != null) {
      final image = Image.file(
        File(pending.localPath),
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            _iconContainer(Icons.broken_image),
      );
      if (!showPendingBadge) return image;
      return Stack(
        fit: StackFit.expand,
        children: [
          image,
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                pending.hasFailed
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_upload_outlined,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    final url = preferThumbnail
        ? _nonEmpty(testPiece.thumbnailUrl) ?? _nonEmpty(testPiece.imageUrl)
        : _nonEmpty(testPiece.imageUrl) ?? _nonEmpty(testPiece.thumbnailUrl);
    if (url != null) {
      return AppNetworkImage(url: url, fit: fit, iconSize: iconSize);
    }

    final imagePath = testPiece.imagePath;
    if (imagePath != null && imagePath.isNotEmpty) {
      // アップロードは済み、Cloud Functions の処理を待っている
      return _iconContainer(Icons.hourglass_empty);
    }
    return _iconContainer(Icons.photo);
  }

  static String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;
}
