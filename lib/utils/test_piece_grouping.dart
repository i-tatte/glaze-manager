import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/lab_color.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/models/test_piece_group_key.dart';
import 'package:glaze_manager/utils/test_piece_display.dart';

/// グループ表示の1セクション
class TestPieceGroup {
  final String label;
  final List<TestPiece> pieces;

  /// 焼成回のグループのとき、その焼成回の ID
  final String? firingId;

  const TestPieceGroup({
    required this.label,
    required this.pieces,
    this.firingId,
  });
}

// --- 色味バケツの閾値 (使用感に応じてチューニングする) ---

/// これ未満の彩度 C* は無彩色 (白/グレー/黒) とみなす
const double achromaticChromaThreshold = 12.0;

/// 無彩色のうち、この明度以上は「白」
const double whiteLightnessMin = 75.0;

/// 無彩色のうち、この明度以下は「黒」
const double blackLightnessMax = 30.0;

/// 橙〜黄の色相域でこの明度未満なら「茶系」(飴釉・鉄釉など)
const double brownLightnessMax = 50.0;

/// 「色データなし」グループのラベル
const String noColorDataLabel = '色データなし';

/// 色味グループの固定表示順
const List<String> colorHueBucketOrder = [
  '赤系',
  '黄系',
  '緑系',
  '青系',
  '紫系',
  '茶系',
  '白',
  'グレー',
  '黒',
  noColorDataLabel,
];

/// 未設定 (ID が null/空) グループのラベル
const String unsetGroupLabel = '未設定';

/// 不明 (ID はあるがマスタに存在しない) グループのラベル
const String unknownGroupLabel = '不明';

/// 焼成回を参照しないテストピースのグループのラベル
const String noFiringGroupLabel = '焼成回なし';

/// 未評価のグループのラベル
const String unratedGroupLabel = '未評価';

/// テストピースをグループ分けする純関数。
///
/// - 各グループ内の並びは [pieces] の入力順 (createdAt 降順) を維持する
/// - 空のグループは返さない
/// - 素地土/雰囲気/プロファイル: 名前昇順、末尾に「未設定」「不明」。
///   雰囲気とプロファイルは [resolveFiring] で解決した名前で束ねる
/// - 焼成回: 焼成日の降順、末尾に「焼成回なし」「不明」
/// - 色味: [colorHueBucketOrder] の固定順、末尾に「色データなし」
/// - 評価: ★5〜★1、末尾に「未評価」
List<TestPieceGroup> groupTestPieces({
  required List<TestPiece> pieces,
  required TestPieceGroupKey key,
  required Map<String, Clay> clayMap,
  required Map<String, FiringAtmosphere> atmosphereMap,
  required Map<String, FiringProfile> profileMap,
  required Map<String, Firing> firingMap,
}) {
  ResolvedFiring resolve(TestPiece tp) => resolveFiring(
    tp,
    firingMap: firingMap,
    atmosphereMap: atmosphereMap,
    profileMap: profileMap,
  );

  switch (key) {
    case TestPieceGroupKey.none:
      return [TestPieceGroup(label: '', pieces: pieces)];
    case TestPieceGroupKey.clay:
      return _groupByName(pieces, (tp) => tp.clayId, (id) => clayMap[id]?.name);
    case TestPieceGroupKey.firingAtmosphere:
      return _groupByResolvedName(
        pieces,
        resolve,
        (r) => r.atmosphereName,
        (tp) => tp.firingAtmosphereId,
      );
    case TestPieceGroupKey.firingProfile:
      return _groupByResolvedName(
        pieces,
        resolve,
        (r) => r.profileName,
        (tp) => tp.firingProfileId,
      );
    case TestPieceGroupKey.firing:
      return _groupByFiring(pieces, firingMap);
    case TestPieceGroupKey.colorHue:
      return _groupByColorHue(pieces);
    case TestPieceGroupKey.rating:
      return _groupByRating(pieces);
  }
}

/// [resolveFiring] で解決した名前でグループ化する。
///
/// 焼成回を参照するテストピースは、焼成回が見つからなければ「不明」、
/// 名前がなければ「未設定」に入れる。焼成回を参照しないテストピースは従来通り、
/// 参照 ([legacyIdOf]) がなければ「未設定」、参照先が見つからなければ「不明」。
List<TestPieceGroup> _groupByResolvedName(
  List<TestPiece> pieces,
  ResolvedFiring Function(TestPiece) resolve,
  String? Function(ResolvedFiring) nameOf,
  String? Function(TestPiece) legacyIdOf,
) {
  final named = <String, List<TestPiece>>{};
  final unset = <TestPiece>[];
  final unknown = <TestPiece>[];

  for (final tp in pieces) {
    final resolved = resolve(tp);
    final name = nameOf(resolved);
    if (resolved.firingMissing) {
      unknown.add(tp);
    } else if (name != null && name.isNotEmpty) {
      named.putIfAbsent(name, () => []).add(tp);
    } else if (resolved.firing != null) {
      unset.add(tp);
    } else {
      final id = legacyIdOf(tp);
      (id == null || id.isEmpty ? unset : unknown).add(tp);
    }
  }

  final sortedNames = named.keys.toList()..sort();
  return [
    for (final name in sortedNames)
      TestPieceGroup(label: name, pieces: named[name]!),
    if (unset.isNotEmpty) TestPieceGroup(label: unsetGroupLabel, pieces: unset),
    if (unknown.isNotEmpty)
      TestPieceGroup(label: unknownGroupLabel, pieces: unknown),
  ];
}

/// 焼成回 ID でグループ化する。見出しは displayLabel、並びは焼成日の降順。
/// 同じ日・同じ窯の焼成回が二つあれば、見出しは同じでも別のグループになる。
List<TestPieceGroup> _groupByFiring(
  List<TestPiece> pieces,
  Map<String, Firing> firingMap,
) {
  final byId = <String, List<TestPiece>>{};
  final none = <TestPiece>[];
  final unknown = <TestPiece>[];

  for (final tp in pieces) {
    final id = tp.firingId;
    if (id == null || id.isEmpty) {
      none.add(tp);
    } else if (!firingMap.containsKey(id)) {
      unknown.add(tp);
    } else {
      byId.putIfAbsent(id, () => []).add(tp);
    }
  }

  final ids = byId.keys.toList()
    ..sort((a, b) {
      final byDate = firingMap[b]!.firedOn.compareTo(firingMap[a]!.firedOn);
      if (byDate != 0) return byDate;
      return firingMap[b]!.createdAt.compareTo(firingMap[a]!.createdAt);
    });
  return [
    for (final id in ids)
      TestPieceGroup(
        label: firingMap[id]!.displayLabel,
        pieces: byId[id]!,
        firingId: id,
      ),
    if (none.isNotEmpty)
      TestPieceGroup(label: noFiringGroupLabel, pieces: none),
    if (unknown.isNotEmpty)
      TestPieceGroup(label: unknownGroupLabel, pieces: unknown),
  ];
}

/// 評価でグループ化する。「★5」〜「★1」「未評価」の固定の順。
List<TestPieceGroup> _groupByRating(List<TestPiece> pieces) {
  final byRating = <int, List<TestPiece>>{};
  final unrated = <TestPiece>[];
  for (final tp in pieces) {
    final rating = tp.rating;
    if (rating == null) {
      unrated.add(tp);
    } else {
      byRating.putIfAbsent(rating, () => []).add(tp);
    }
  }
  return [
    for (var rating = 5; rating >= 1; rating--)
      if (byRating.containsKey(rating))
        TestPieceGroup(label: '★$rating', pieces: byRating[rating]!),
    if (unrated.isNotEmpty)
      TestPieceGroup(label: unratedGroupLabel, pieces: unrated),
  ];
}

/// ID → マスタ名 でグループ化する共通処理
List<TestPieceGroup> _groupByName(
  List<TestPiece> pieces,
  String? Function(TestPiece) idOf,
  String? Function(String) nameOf,
) {
  final named = <String, List<TestPiece>>{};
  final unset = <TestPiece>[];
  final unknown = <TestPiece>[];

  for (final tp in pieces) {
    final id = idOf(tp);
    if (id == null || id.isEmpty) {
      unset.add(tp);
      continue;
    }
    final name = nameOf(id);
    if (name == null) {
      unknown.add(tp);
    } else {
      named.putIfAbsent(name, () => []).add(tp);
    }
  }

  final sortedNames = named.keys.toList()..sort();
  return [
    for (final name in sortedNames)
      TestPieceGroup(label: name, pieces: named[name]!),
    if (unset.isNotEmpty) TestPieceGroup(label: unsetGroupLabel, pieces: unset),
    if (unknown.isNotEmpty)
      TestPieceGroup(label: unknownGroupLabel, pieces: unknown),
  ];
}

List<TestPieceGroup> _groupByColorHue(List<TestPiece> pieces) {
  final buckets = <String, List<TestPiece>>{};
  for (final tp in pieces) {
    final representative = representativeColor(tp.colorData);
    final bucket = representative == null
        ? noColorDataLabel
        : colorHueBucket(representative);
    buckets.putIfAbsent(bucket, () => []).add(tp);
  }
  return [
    for (final label in colorHueBucketOrder)
      if (buckets.containsKey(label))
        TestPieceGroup(label: label, pieces: buckets[label]!),
  ];
}

/// colorData の代表色 (percentage 最大) を返す。
/// スポイトで手動追加した色は percentage=0 なので、全て 0 なら先頭を使う。
/// null / 空なら null。
@visibleForTesting
LabColor? representativeColor(List<LabColor>? colorData) {
  final colors = significantColors(colorData);
  if (colors.isEmpty) return null;
  return colors.reduce((a, b) => b.percentage > a.percentage ? b : a);
}

/// 代表色を CIELCh に変換して色相バケツ名に分類する。
///
/// データは既に CIELAB で保持されているため、彩度 C* = sqrt(a²+b²) と
/// 色相角 h = atan2(b, a) だけで判定でき、sRGB への往復変換誤差が入らない。
@visibleForTesting
String colorHueBucket(LabColor color) {
  final chroma = sqrt(color.a * color.a + color.b * color.b);

  // 1. 無彩色 (白萩・天目などの白/グレー/黒)
  if (chroma < achromaticChromaThreshold) {
    if (color.l >= whiteLightnessMin) return '白';
    if (color.l <= blackLightnessMax) return '黒';
    return 'グレー';
  }

  var hue = atan2(color.b, color.a) * 180 / pi;
  if (hue < 0) hue += 360;

  // 2. 暗い橙〜黄は茶系 (飴釉・鉄釉)。赤系/黄系より先に判定する
  if (hue >= 30 && hue < 110 && color.l < brownLightnessMax) return '茶系';

  // 3. 色相角による分類 (Lab の色相角: 赤≈20-40°, 黄≈90°, 緑≈140-160°,
  //    青≈250-290°, 紫≈300-330°)
  if (hue >= 345 || hue < 45) return '赤系';
  if (hue < 110) return '黄系';
  if (hue < 200) return '緑系';
  if (hue < 300) return '青系';
  return '紫系';
}
