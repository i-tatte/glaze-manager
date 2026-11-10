import 'package:flutter/material.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/lab_color.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/utils/test_piece_display.dart';

/// 検索クエリの語分割に使う正規表現。半角・全角スペースの連続を 1 区切りとして扱う。
/// Dart(ECMAScript) の \s は U+3000 を含むため、全角スペースも分割対象になる。
final RegExp searchTermSplitter = RegExp(r'\s+');

/// 検索結果の並び順
enum TestPieceSortOrder {
  /// フィルタが決めた順序を維持 (テキスト検索は釉薬名等マッチ→原料名マッチの順、
  /// 条件なしなら入力リスト順 = 作成日の新しい順)
  relevance('関連度順'),

  /// 作成日の新しい順
  newest('作成が新しい順'),

  /// 作成日の古い順
  oldest('作成が古い順'),

  /// 選択色との色差 (ΔE) が小さい順。色検索時のみ意味を持ち、
  /// 色条件がない場合は [relevance] と同じ
  colorDistance('色が近い順');

  const TestPieceSortOrder(this.label);

  /// UI 表示用ラベル
  final String label;
}

/// テストピース一覧をテキスト・タグ・色でフィルタし、[sortOrder] に従って並べた
/// 新しいリストを返す純関数。
///
/// SearchScreen の `_applyFilters` から表示ロジック（setState 等）と分離して
/// 抽出したもの。フィルタの挙動:
///  - テキストはスペース区切り AND、`-語` は除外語
///  - 釉薬が [glazeMap] に無く、調合の写しもないテストピースはテキスト検索時に
///    除外される (写しがあれば写しの釉薬名・原料名で検索できる)
///  - 原料名のみにマッチしたものは、釉薬名等にマッチしたものより後ろに並ぶ
///  - タグは AND
///  - 色検索は ΔE 閾値以下を残す。[TestPieceSortOrder.colorDistance] 指定時は
///    ΔE の近い順にソート
List<TestPiece> filterTestPieces({
  required List<TestPiece> pieces,
  required String query,
  required List<String> selectedTags,
  Color? color,
  double deltaEThreshold = 30.0,
  TestPieceSortOrder sortOrder = TestPieceSortOrder.relevance,
  required Map<String, Glaze> glazeMap,
  required Map<String, Clay> clayMap,
  required Map<String, FiringAtmosphere> atmosphereMap,
  required Map<String, FiringProfile> profileMap,
  required Map<String, String> materialMap,
}) {
  List<TestPiece> filtered = pieces;

  // 1. テキスト検索 (Positive & Negative)
  if (query.isNotEmpty) {
    final terms = query.split(searchTermSplitter).where((t) => t.isNotEmpty);
    final positiveTerms = terms
        .where((t) => !t.startsWith('-'))
        .map((t) => t.toLowerCase())
        .toList();
    final negativeTerms = terms
        .where((t) => t.startsWith('-') && t.length > 1)
        .map((t) => t.substring(1).toLowerCase())
        .toList();

    final primaryMatches = <TestPiece>[];
    final materialMatches = <TestPiece>[];

    for (final tp in filtered) {
      final glaze = glazeMap[tp.glazeId];
      final snapshotGlaze = tp.snapshot?.glaze;
      // 釉薬が見つからず、写しもないものは外す
      if (glaze == null && snapshotGlaze == null) continue;

      final atmosphere = atmosphereMap[tp.firingAtmosphereId];
      final profile = profileMap[tp.firingProfileId];

      // 検索対象の文字列を結合して検索しやすくする
      // (釉薬名・素地土名は現存すれば現在の名前、なければ写しの名前。
      //  タグは釉薬が現存するときだけ)
      final searchableText = [
        glazeDisplayName(tp, glazeMap, fallback: ''),
        ...?glaze?.tags,
        clayDisplayName(tp, clayMap, fallback: ''),
        atmosphere?.name ?? '',
        profile?.name ?? '',
      ].join(' ').toLowerCase();

      // 原料名の検索対象 (写しがあれば写しの各行、なければ現在の調合)
      final materialNames =
          (snapshotGlaze != null
                  ? snapshotGlaze.lines.map(
                      (line) => materialMap[line.materialId] ?? line.name,
                    )
                  : glaze!.recipe.keys.map((id) => materialMap[id] ?? ''))
              .join(' ')
              .toLowerCase();

      // Negative Terms Check (Common)
      bool matchesNegative =
          negativeTerms.isNotEmpty &&
          negativeTerms.any(
            (term) =>
                searchableText.contains(term) || materialNames.contains(term),
          );

      if (matchesNegative) continue;

      // Positive Terms Check
      bool matchesPrimary =
          positiveTerms.isEmpty ||
          positiveTerms.every((term) => searchableText.contains(term));

      bool matchesMaterial =
          positiveTerms.isEmpty ||
          positiveTerms.every((term) => materialNames.contains(term));

      if (matchesPrimary) {
        primaryMatches.add(tp);
      } else if (matchesMaterial) {
        materialMatches.add(tp);
      }
    }

    // プライマリマッチを優先、その後に原料マッチを追加
    filtered = [...primaryMatches, ...materialMatches];
  }

  // 2. タグフィルタ (AND検索)
  if (selectedTags.isNotEmpty) {
    filtered = filtered.where((tp) {
      final glaze = glazeMap[tp.glazeId];
      if (glaze == null) return false;
      return selectedTags.every((tag) => glaze.tags.contains(tag));
    }).toList();
  }

  // 3. 色検索 & ソート
  if (color != null) {
    final targetLabColor = LabColor.fromColor(color);
    final List<(TestPiece, double)> matchedPieces = [];

    for (final testPiece in filtered) {
      final swatches = significantColors(testPiece.colorData);
      if (swatches.isEmpty) continue;

      double minDeltaE = double.infinity;
      for (final swatch in swatches) {
        final deltaE = targetLabColor.deltaE(swatch);
        if (deltaE < minDeltaE) {
          minDeltaE = deltaE;
        }
      }

      if (minDeltaE <= deltaEThreshold) {
        matchedPieces.add((testPiece, minDeltaE));
      }
    }

    // 色が近い順の指定時のみ ΔE 昇順にソート (それ以外はここまでの順序を維持)
    if (sortOrder == TestPieceSortOrder.colorDistance) {
      matchedPieces.sort((a, b) => a.$2.compareTo(b.$2));
    }
    filtered = matchedPieces.map((e) => e.$1).toList();
  }

  // 4. 並び替え
  switch (sortOrder) {
    case TestPieceSortOrder.relevance:
    case TestPieceSortOrder.colorDistance:
      // relevance はフィルタが決めた順序を維持。
      // colorDistance は色検索ブロック内で適用済み (色条件なしなら維持)。
      break;
    case TestPieceSortOrder.newest:
      // 入力リストを直接ソートしないようコピーする (filtered が pieces のままの場合がある)
      filtered = List.of(filtered)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case TestPieceSortOrder.oldest:
      filtered = List.of(filtered)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  return filtered;
}
