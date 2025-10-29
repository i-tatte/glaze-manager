import 'package:cloud_firestore/cloud_firestore.dart';

class TestPiece {
  final String? id;
  final String glazeId; // 関連するGlazeのID
  final String clayName; // 素地土名
  final String? firingCurve; // 焼成温度曲線 (CSVパス or 文字列データ)
  final String? imageUrl; // Storageへのパス
  final Map<String, double>? colorData; // 例: {'L': 95.5, 'a': -1.2, 'b': 3.4}
  final Timestamp createdAt; // 作成日時

  TestPiece({
    this.id,
    required this.glazeId,
    required this.clayName,
    this.firingCurve,
    this.imageUrl,
    this.colorData,
    required this.createdAt,
  });

  factory TestPiece.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return TestPiece(
      id: snapshot.id,
      glazeId: data['glazeId'] ?? '',
      clayName: data['clayName'] ?? '',
      firingCurve: data['firingCurve'],
      imageUrl: data['imageUrl'],
      colorData: data['colorData'] != null
          ? Map<String, double>.from(data['colorData'] as Map)
          : null,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'glazeId': glazeId,
      'clayName': clayName,
      'firingCurve': firingCurve,
      'imageUrl': imageUrl,
      'colorData': colorData,
      'createdAt': createdAt,
    };
  }
}