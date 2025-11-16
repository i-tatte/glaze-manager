import 'package:cloud_firestore/cloud_firestore.dart';

class TestPiece {
  final String? id;
  final String glazeId; // 関連するGlazeのID
  final String clayId; // 関連するClayのID
  final String? firingAtmosphereId; // 関連するFiringAtmosphereのID
  final String? firingProfileId; // 関連するFiringProfileのID
  final String? imageUrl; // Storageへのパス
  final String? thumbnailUrl; // サムネイル画像のURL
  final String? blurHash; // サムネイルのぼかし表示用ハッシュ
  final Map<String, double>? colorData; // 例: {'L': 95.5, 'a': -1.2, 'b': 3.4}
  final Timestamp createdAt; // 作成日時

  TestPiece({
    this.id,
    required this.glazeId,
    required this.clayId,
    this.firingAtmosphereId,
    this.firingProfileId,
    this.imageUrl,
    this.thumbnailUrl,
    this.blurHash,
    this.colorData,
    required this.createdAt,
  });

  factory TestPiece.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return TestPiece(
      id: snapshot.id,
      glazeId: data['glazeId'] ?? '',
      clayId: data['clayId'] ?? '',
      firingAtmosphereId: data['firingAtmosphereId'],
      firingProfileId: data['firingProfileId'],
      imageUrl: data['imageUrl'],
      thumbnailUrl: data['thumbnailUrl'],
      blurHash: data['blurHash'],
      colorData: data['colorData'] != null
          ? Map<String, double>.from(data['colorData'] as Map)
          : null,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'glazeId': glazeId,
      'clayId': clayId,
      'firingAtmosphereId': firingAtmosphereId,
      'firingProfileId': firingProfileId,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'blurHash': blurHash,
      'colorData': colorData,
      'createdAt': createdAt,
    };
  }
}
