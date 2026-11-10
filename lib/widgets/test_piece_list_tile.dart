import 'package:flutter/material.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/theme/atmosphere_card_color.dart';
import 'package:glaze_manager/widgets/common/app_network_image.dart';

class TestPieceListTile extends StatelessWidget {
  final TestPiece testPiece;
  final String glazeName;
  final String clayName;
  final String firingAtmosphereName;
  final FiringAtmosphereType firingAtmosphereType;
  final String firingProfileName;
  final VoidCallback? onTap;

  const TestPieceListTile({
    super.key,
    required this.testPiece,
    required this.glazeName,
    required this.clayName,
    required this.firingAtmosphereName,
    this.firingAtmosphereType = FiringAtmosphereType.other,
    required this.firingProfileName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 焼成雰囲気による色分け (nullの場合はテーマのデフォルト)
    final cardColor = firingAtmosphereType.cardColor(
      Theme.of(context).brightness,
    );

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail (80pxの表示にはサムネイルで十分。原寸は詳細画面のみ)
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: AppNetworkImage(
                    url: testPiece.thumbnailUrl ?? testPiece.imageUrl,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            glazeName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (testPiece.rating != null)
                          Text('★${testPiece.rating}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.landscape, size: 16),
                        const SizedBox(width: 4),
                        Text(clayName),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department, size: 16),
                        const SizedBox(width: 4),
                        Text('$firingAtmosphereName / $firingProfileName'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
