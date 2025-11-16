import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/test_piece_detail_screen.dart';

class TestPieceCard extends StatelessWidget {
  // TestPieceオブジェクトと、それに関連する釉薬名を受け取る
  final TestPiece testPiece;
  final String glazeName;
  final String clayName;

  const TestPieceCard({
    super.key,
    required this.testPiece,
    required this.glazeName,
    required this.clayName,
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
              aspectRatio: 1.0,
              child: Hero(
                tag: 'testPieceImage_${testPiece.id}',
                child: testPiece.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: testPiece.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) {
                          // BlurHashがあればそれを表示、なければサムネイル、それもなければインジケーター
                          if (testPiece.blurHash != null) {
                            return AspectRatio(
                              aspectRatio: 1.0,
                              child: BlurHash(hash: testPiece.blurHash!),
                            );
                          } else if (testPiece.thumbnailUrl != null) {
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
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    clayName,
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
