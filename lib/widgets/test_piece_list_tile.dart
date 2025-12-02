import 'package:flutter/material.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/theme/app_colors.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color? cardColor;
    switch (firingAtmosphereType) {
      case FiringAtmosphereType.oxidation:
        cardColor = isDark
            ? AppColors.oxidationCardDark
            : AppColors.oxidationCardLight;
        break;
      case FiringAtmosphereType.reduction:
        cardColor = isDark
            ? AppColors.reductionCardDark
            : AppColors.reductionCardLight;
        break;
      case FiringAtmosphereType.other:
        cardColor = null;
        break;
    }

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
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: testPiece.imageUrl != null
                    ? Image.network(
                        testPiece.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image),
                      ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      glazeName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
