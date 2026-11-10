import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart';

/// 写しの出どころ。
class SnapshotSource {
  SnapshotSource._();

  /// 登録や編集のときに取った写し
  static const saved = 'saved';

  /// 既存データに一度だけ埋めた写し
  static const backfilled = 'backfilled';

  /// 釉薬の誤記の修正を反映した写し
  static const corrected = 'corrected';
}

/// 調合の 1 行。
class RecipeLine {
  final String materialId;
  final String name; // 記録時の原料名
  final String category; // 記録時の MaterialCategory.name
  final double amount; // 重量 (g)

  const RecipeLine({
    required this.materialId,
    required this.name,
    required this.category,
    required this.amount,
  });

  factory RecipeLine.fromMap(Map<String, dynamic> map) {
    final amount = map['amount'];
    return RecipeLine(
      materialId: map['materialId'] as String? ?? '',
      name: map['name'] as String? ?? '不明な原料',
      category: map['category'] as String? ?? MaterialCategory.base.name,
      amount: amount is num ? amount.toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'materialId': materialId,
    'name': name,
    'category': category,
    'amount': amount,
  };
}

/// ある時点の釉薬の調合。
class GlazeSnapshot {
  final String glazeId;
  final String name;
  final String? registeredName;
  final List<RecipeLine> lines;

  GlazeSnapshot({
    required this.glazeId,
    required this.name,
    this.registeredName,
    required List<RecipeLine> lines,
  }) : lines = List.unmodifiable(lines);

  /// 現在の釉薬と原料から写しを作る。
  /// 原料が見つからない行は name を '不明な原料'、category を 'base' とする。
  factory GlazeSnapshot.capture(
    Glaze glaze,
    Map<String, Material> materialById,
  ) {
    return GlazeSnapshot(
      glazeId: glaze.id ?? '',
      name: glaze.name,
      registeredName: glaze.registeredName,
      lines: [
        for (final entry in glaze.recipe.entries)
          RecipeLine(
            materialId: entry.key,
            name: materialById[entry.key]?.name ?? '不明な原料',
            category:
                materialById[entry.key]?.category.name ??
                MaterialCategory.base.name,
            amount: entry.value,
          ),
      ],
    );
  }

  factory GlazeSnapshot.fromMap(Map<String, dynamic> map) {
    final rawLines = map['lines'];
    return GlazeSnapshot(
      glazeId: map['glazeId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      registeredName: map['registeredName'] as String?,
      lines: rawLines is List
          ? [
              for (final line in rawLines)
                if (line is Map)
                  RecipeLine.fromMap(Map<String, dynamic>.from(line)),
            ]
          : const [],
    );
  }

  /// Map でなければ null を返す寛容な読み取り。
  static GlazeSnapshot? tryFromMap(Object? value) {
    if (value is! Map) return null;
    return GlazeSnapshot.fromMap(Map<String, dynamic>.from(value));
  }

  Map<String, dynamic> toMap() => {
    'glazeId': glazeId,
    'name': name,
    'registeredName': registeredName,
    'lines': lines.map((l) => l.toMap()).toList(),
  };

  /// 原料 ID → 量。
  Map<String, double> get recipe => {
    for (final line in lines) line.materialId: line.amount,
  };

  /// 原料 ID の集合が同じで、すべての量の差が 1e-9 以下なら true。
  bool hasSameRecipeAs(Map<String, double> other) {
    final mine = recipe;
    if (mine.length != other.length) return false;
    for (final entry in mine.entries) {
      final value = other[entry.key];
      if (value == null) return false;
      if ((value - entry.value).abs() > 1e-9) return false;
    }
    return true;
  }
}

/// テストピースが持つ写しの全体。
class TestPieceSnapshot {
  final GlazeSnapshot? glaze; // 主たる釉薬
  final List<GlazeSnapshot> additionalGlazes; // 追加釉薬。対応は glazeId で取る
  final String? clayName;
  final String source; // 'saved' | 'backfilled' | 'corrected'
  final Timestamp takenAt;

  TestPieceSnapshot({
    this.glaze,
    List<GlazeSnapshot> additionalGlazes = const [],
    this.clayName,
    required this.source,
    required this.takenAt,
  }) : additionalGlazes = List.unmodifiable(additionalGlazes);

  /// テストピースの参照先から写しを作る。
  ///
  /// 見つからない釉薬は、[previous] に同じ glazeId の写しがあればそれを残し、
  /// なければ写しに含めない。素地土が見つからない場合も [previous] の名前を残す。
  factory TestPieceSnapshot.capture({
    required String glazeId,
    required List<String> additionalGlazeIds,
    required String clayId,
    required Map<String, Glaze> glazeMap,
    required Map<String, Material> materialMap,
    required Map<String, Clay> clayMap,
    required String source,
    TestPieceSnapshot? previous,
  }) {
    GlazeSnapshot? captureGlaze(String id) {
      final glaze = glazeMap[id];
      if (glaze != null) return GlazeSnapshot.capture(glaze, materialMap);
      return previous?.glazeSnapshotFor(id);
    }

    return TestPieceSnapshot(
      glaze: captureGlaze(glazeId),
      additionalGlazes: [
        for (final id in additionalGlazeIds)
          if (captureGlaze(id) case final snapshot?) snapshot,
      ],
      clayName: clayMap[clayId]?.name ?? previous?.clayName,
      source: source,
      takenAt: Timestamp.now(),
    );
  }

  /// Map でなければ null を返す寛容な読み取り。
  static TestPieceSnapshot? tryFromMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final rawAdditional = map['additionalGlazes'];
    final takenAt = map['takenAt'];
    return TestPieceSnapshot(
      glaze: GlazeSnapshot.tryFromMap(map['glaze']),
      additionalGlazes: rawAdditional is List
          ? [
              for (final item in rawAdditional)
                if (GlazeSnapshot.tryFromMap(item) case final snapshot?)
                  snapshot,
            ]
          : const [],
      clayName: map['clayName'] as String?,
      source: map['source'] as String? ?? SnapshotSource.saved,
      takenAt: takenAt is Timestamp ? takenAt : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'source': source,
    'takenAt': takenAt,
    'clayName': clayName,
    'glaze': glaze?.toMap(),
    'additionalGlazes': additionalGlazes.map((g) => g.toMap()).toList(),
  };

  /// 主たる釉薬または追加釉薬のうち、[glazeId] の写しを返す。
  GlazeSnapshot? glazeSnapshotFor(String glazeId) {
    if (glaze?.glazeId == glazeId) return glaze;
    for (final g in additionalGlazes) {
      if (g.glazeId == glazeId) return g;
    }
    return null;
  }

  /// [glazeId] の写しを主たる釉薬または追加釉薬として含むなら true。
  bool containsGlaze(String glazeId) => glazeSnapshotFor(glazeId) != null;

  /// 写しのうち [replacement] と同じ glazeId の部分を置き換えた新しい写しを返す。
  /// ほかの釉薬と素地土名はそのまま残す。
  TestPieceSnapshot replacingGlaze(
    GlazeSnapshot replacement, {
    required String source,
  }) {
    final id = replacement.glazeId;
    return TestPieceSnapshot(
      glaze: glaze?.glazeId == id ? replacement : glaze,
      additionalGlazes: [
        for (final g in additionalGlazes) g.glazeId == id ? replacement : g,
      ],
      clayName: clayName,
      source: source,
      takenAt: Timestamp.now(),
    );
  }
}
