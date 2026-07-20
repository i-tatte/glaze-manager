import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/lab_color.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/models/test_piece_group_key.dart';

/// グループ表示の1セクション
class TestPieceGroup {
  final String label;
  final List<TestPiece> pieces;

  const TestPieceGroup({required this.label, required this.pieces});
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

/// テストピースをグループ分けする純関数。
///
/// - 各グループ内の並びは [pieces] の入力順 (createdAt 降順) を維持する
/// - 空のグループは返さない
/// - 素地土/雰囲気/プロファイル: 名前昇順、末尾に「未設定」「不明」
/// - 色味: [colorHueBucketOrder] の固定順、末尾に「色データなし」
List<TestPieceGroup> groupTestPieces({
  required List<TestPiece> pieces,
  required TestPieceGroupKey key,
  required Map<String, Clay> clayMap,
  required Map<String, FiringAtmosphere> atmosphereMap,
  required Map<String, FiringProfile> profileMap,
}) {
  switch (key) {
    case TestPieceGroupKey.none:
      return [TestPieceGroup(label: '', pieces: pieces)];
    case TestPieceGroupKey.clay:
      return _groupByName(
        pieces,
        (tp) => tp.clayId,
        (id) => clayMap[id]?.name,
      );
    case TestPieceGroupKey.firingAtmosphere:
      return _groupByName(
        pieces,
        (tp) => tp.firingAtmosphereId,
        (id) => atmosphereMap[id]?.name,
      );
    case TestPieceGroupKey.firingProfile:
      return _groupByName(
        pieces,
        (tp) => tp.firingProfileId,
        (id) => profileMap[id]?.name,
      );
    case TestPieceGroupKey.colorHue:
      return _groupByColorHue(pieces);
  }
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
  if (colorData == null || colorData.isEmpty) return null;
  return colorData.reduce((a, b) => b.percentage > a.percentage ? b : a);
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
