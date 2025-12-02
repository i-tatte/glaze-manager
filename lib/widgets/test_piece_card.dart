import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/test_piece_detail_screen.dart';
import 'package:glaze_manager/theme/app_colors.dart';

class TestPieceCard extends StatelessWidget {
  // TestPieceオブジェクトと、それに関連する釉薬名を受け取る
  final TestPiece testPiece;
  final String glazeName;
  final String clayName;
  final String firingAtmosphereName;
  final String firingProfileName;

  const TestPieceCard({
    super.key,
    required this.testPiece,
    required this.glazeName,
    required this.clayName,
    required this.firingAtmosphereName,
    required this.firingProfileName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color? cardColor;

    // 焼成雰囲気による色分け
    // "酸化" または "OF" を含む場合は酸化色
    // "還元" または "RF" を含む場合は還元色
    if (firingAtmosphereName.contains('酸化') ||
        firingAtmosphereName.contains('OF')) {
      cardColor = isDark
          ? AppColors.oxidationCardDark
          : AppColors.oxidationCardLight;
    } else if (firingAtmosphereName.contains('還元') ||
        firingAtmosphereName.contains('RF')) {
      cardColor = isDark
          ? AppColors.reductionCardDark
          : AppColors.reductionCardLight;
    }

    return Card(
      clipBehavior: Clip.antiAlias, // カードの角を丸くするために必要
      elevation: 2.0,
      margin: EdgeInsets.zero, // GridViewでスペースを管理するため、Cardのマージンは0にする
      color: cardColor, // 背景色を適用 (nullの場合はテーマのデフォルト)
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TestPieceDetailScreen(testPiece: testPiece),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 画像部分
            AspectRatio(
              aspectRatio: 1.0,
              child: Hero(
                tag: 'testPieceImage_${testPiece.id}',
                child: testPiece.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: testPiece.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) {
                          // サムネイルがあればそれを表示、なければインジケーター
                          if (testPiece.thumbnailUrl != null) {
                            return CachedNetworkImage(
                              imageUrl: testPiece.thumbnailUrl!,
                              fit: BoxFit.cover,
                            );
                          }
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                        errorWidget: (context, url, error) => const Icon(
                          Icons.broken_image,
                          size: 40,
                          color: Colors.grey,
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.photo,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
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
