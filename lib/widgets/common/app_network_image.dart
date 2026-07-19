import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// ネットワーク画像表示の共通ウィジェット。
///
/// URL未設定・読み込み中・読み込み失敗の3状態の見た目をここで一元管理する。
/// テストピース画像などネットワーク画像を表示するときは必ずこれを使う。
class AppNetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;

  /// プレースホルダ・エラーアイコンの大きさ。表示領域に合わせて調整する。
  final double iconSize;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.iconSize = 40,
  });

  Widget _iconContainer(IconData icon) {
    return Container(
      color: Colors.grey[200],
      child: Icon(icon, size: iconSize, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url == null || url.isEmpty) {
      return _iconContainer(Icons.photo);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => _iconContainer(Icons.broken_image),
    );
  }
}
