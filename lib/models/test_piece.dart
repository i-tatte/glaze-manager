import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glaze_manager/models/lab_color.dart';
import 'package:glaze_manager/models/recipe_snapshot.dart';

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
  final TestPieceSnapshot? snapshot; // 記録した時点の調合と素地土名の写し
  final int? rating; // 評価 (星 1〜5)。null は未評価
  final String? label; // ピースの番号 (実物に書いた番号。自由入力、重複可)
  final String? firingId; // 焼成回の ID。あれば焼成の情報は焼成回を正とする

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
    this.snapshot,
    this.rating,
    this.label,
    this.firingId,
  }) : additionalGlazeIds = List.of(additionalGlazeIds),
       colorData = colorData == null ? null : List.of(colorData);

  /// 評価を読む。数値でないもの、1〜5 の範囲外は null (未評価) とする。
  static int? _readRating(Object? value) {
    if (value is! num) return null;
    final rating = value.toInt();
    return (rating >= 1 && rating <= 5) ? rating : null;
  }

  /// 空文字列を null として扱う。
  static String? _readNonEmptyString(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }

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
      snapshot: TestPieceSnapshot.tryFromMap(data['snapshot']),
      rating: _readRating(data['rating']),
      label: _readNonEmptyString(data['label']),
      firingId: _readNonEmptyString(data['firingId']),
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
      if (snapshot != null) 'snapshot': snapshot!.toMap(),
      'rating': rating,
      'label': label,
      // null でも出力する。部分更新 (toUpdateFields) で「（なし）」に戻したとき、
      // 文書の firingId を消すため
      'firingId': firingId,
    };
  }

  /// 更新時にクライアントが送るフィールド。
  /// imageUrl / thumbnailUrl（Cloud Functions が書く）と createdAt は含めない。
  Map<String, dynamic> toUpdateFields({
    required bool includeImagePath,
    required bool includeColorData,
    required bool includeSnapshot,
  }) {
    final fields = toFirestore()
      ..remove('imageUrl')
      ..remove('thumbnailUrl')
      ..remove('createdAt');
    if (!includeImagePath) fields.remove('imagePath');
    if (!includeColorData) fields.remove('colorData');
    if (!includeSnapshot) fields.remove('snapshot');
    return fields;
  }
}
