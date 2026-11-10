import 'package:flutter/material.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/test_piece_detail_screen.dart';
import 'package:glaze_manager/theme/atmosphere_card_color.dart';
import 'package:glaze_manager/widgets/test_piece_image.dart';

class TestPieceCard extends StatelessWidget {
  // TestPieceオブジェクトと、それに関連する釉薬名を受け取る
  final TestPiece testPiece;
  final String glazeName;
  final String clayName;
  final String firingAtmosphereName;
  final FiringAtmosphereType firingAtmosphereType;
  final String firingProfileName;

  /// タップ時の動作。null なら詳細画面へ遷移する。
  final VoidCallback? onTap;

  /// 長押し時の動作 (比較のための選択など)。
  final VoidCallback? onLongPress;

  /// 選択中か。選択中は画像にチェックを重ね、縁を primary で囲む。
  final bool selected;

  const TestPieceCard({
    super.key,
    required this.testPiece,
    required this.glazeName,
    required this.clayName,
    required this.firingAtmosphereName,
    this.firingAtmosphereType = FiringAtmosphereType.other,
    required this.firingProfileName,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    // 焼成雰囲気による色分け (nullの場合はテーマのデフォルト)
    final cardColor = firingAtmosphereType.cardColor(
      Theme.of(context).brightness,
    );
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias, // カードの角を丸くするために必要
      elevation: 2.0,
      margin: EdgeInsets.zero, // GridViewでスペースを管理するため、Cardのマージンは0にする
      color: cardColor, // 背景色を適用 (nullの場合はテーマのデフォルト)
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primary, width: 3),
            )
          : null,
      child: InkWell(
        onTap:
            onTap ??
            () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      TestPieceDetailScreen(testPiece: testPiece),
                ),
              );
            },
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 画像部分
            // 一覧の小さなカードではサムネイル(200px)を優先して帯域とメモリを節約する。
            // 原寸画像は詳細画面でのみ読み込む。
            // 評価は画像の右上に重ねる (文字の領域の高さはグリッドの縦横比の前提)
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'testPieceImage_${testPiece.id}',
                    child: TestPieceImage(testPiece: testPiece),
                  ),
                  if (testPiece.rating != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '★${testPiece.rating}',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  // 左上はアップロード待ちの印が使うので、選択のチェックは右下
                  if (selected)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Icon(Icons.check_circle, color: primary, size: 28),
                    ),
                ],
              ),
            ),
            // テキスト部分
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    glazeName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  // 焼成雰囲気 & 素地土
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          firingAtmosphereName,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.landscape, size: 14, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          clayName,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
