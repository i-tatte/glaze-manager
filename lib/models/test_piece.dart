import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glaze_manager/models/lab_color.dart';

class TestPiece {
  final String? id;
  final String glazeId; // Primary Glaze ID
  final List<String> additionalGlazeIds; // Additional Glaze IDs
  final String clayId; // 関連するClayのID
  final String? firingAtmosphereId; // 関連するFiringAtmosphereのID
  final String? firingProfileId; // 関連するFiringProfileのID
  final String? imageUrl; // Storageへのパス
  final String?
  imagePath; // Storage内のファイルパス (例: users/xxx/test_pieces/images/yyy.jpg)
  final String? thumbnailUrl; // サムネイル画像のURL
  final List<LabColor>? colorData; // 解析された色のリスト
  final String? note; // 備考
  final Timestamp createdAt; // 作成日時

  TestPiece({
    this.id,
    required this.glazeId,
    List<String> additionalGlazeIds = const [],
    required this.clayId,
    this.firingAtmosphereId,
    this.firingProfileId,
    this.imageUrl,
    this.imagePath,
    this.thumbnailUrl,
    List<LabColor>? colorData,
    this.note,
    required this.createdAt,
  }) : additionalGlazeIds = List.of(additionalGlazeIds),
       colorData = colorData == null ? null : List.of(colorData);

  factory TestPiece.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return TestPiece(
      id: snapshot.id,
      glazeId: data['glazeId'] ?? '',
      additionalGlazeIds: data.containsKey('additionalGlazeIds')
          ? List<String>.from(data['additionalGlazeIds'])
          : [],
      clayId: data['clayId'] ?? '',
      firingAtmosphereId: data['firingAtmosphereId'],
      firingProfileId: data['firingProfileId'],
      imageUrl: data['imageUrl'],
      imagePath: data['imagePath'],
      thumbnailUrl: data['thumbnailUrl'],
      colorData: (data['colorData'] as List<dynamic>?)?.map((swatchMap) {
        return LabColor.fromMap(swatchMap as Map<String, dynamic>);
      }).toList(),
      note: data['note'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'glazeId': glazeId,
      'additionalGlazeIds': additionalGlazeIds,
      'relatedGlazeIds': [glazeId, ...additionalGlazeIds], // For querying
      'clayId': clayId,
      'firingAtmosphereId': firingAtmosphereId,
      'firingProfileId': firingProfileId,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'imagePath': imagePath,
      if (colorData != null)
        'colorData': colorData!.map((swatch) => swatch.toMap()).toList(),
      'note': note,
      'createdAt': createdAt,
    };
  }
}
