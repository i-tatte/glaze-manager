import 'package:flutter/material.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/test_piece_detail_screen.dart';

class TestPieceCard extends StatelessWidget {
  // TestPieceオブジェクトと、それに関連する釉薬名を受け取る
  final TestPiece testPiece;
  final String glazeName;

  const TestPieceCard({
    super.key,
    required this.testPiece,
    required this.glazeName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias, // カードの角を丸くするために必要
      elevation: 2.0,
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
              aspectRatio: 1.0, // 1:1の正方形
              child: testPiece.imageUrl != null
                  ? Image.network(
                      testPiece.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.broken_image,
                          size: 40,
                          color: Colors.grey,
                        );
                      },
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
            // テキスト部分
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    glazeName,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    testPiece.clayName,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
