import 'package:flutter/material.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/lab_color.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';

/// 検索クエリの語分割に使う正規表現。半角・全角スペースの連続を 1 区切りとして扱う。
/// Dart(ECMAScript) の \s は U+3000 を含むため、全角スペースも分割対象になる。
final RegExp searchTermSplitter = RegExp(r'\s+');

/// テストピース一覧をテキスト・タグ・色でフィルタし、色検索時は近い順に並べた
/// 新しいリストを返す純関数。
///
/// SearchScreen の `_applyFilters` から表示ロジック（setState 等）と分離して
/// 抽出したもの。挙動は従来どおり:
///  - テキストはスペース区切り AND、`-語` は除外語
///  - 釉薬が [glazeMap] に無いテストピースはテキスト検索時に除外される
///  - 原料名のみにマッチしたものは、釉薬名等にマッチしたものより後ろに並ぶ
///  - タグは AND
///  - 色検索は ΔE 閾値以下を残し、ΔE の近い順にソート
List<TestPiece> filterTestPieces({
  required List<TestPiece> pieces,
  required String query,
  required List<String> selectedTags,
  Color? color,
  double deltaEThreshold = 30.0,
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
      if (glaze == null) continue;

      final clay = clayMap[tp.clayId];
      final atmosphere = atmosphereMap[tp.firingAtmosphereId];
      final profile = profileMap[tp.firingProfileId];

      // 検索対象の文字列を結合して検索しやすくする
      final searchableText = [
        glaze.name,
        ...glaze.tags,
        clay?.name ?? '',
        atmosphere?.name ?? '',
        profile?.name ?? '',
      ].join(' ').toLowerCase();

      // 原料名の検索対象
      final materialNames = glaze.recipe.keys
          .map((id) => materialMap[id] ?? '')
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
      if (testPiece.colorData == null || testPiece.colorData!.isEmpty) {
        continue;
      }

      double minDeltaE = double.infinity;
      for (final swatch in testPiece.colorData!) {
        final deltaE = targetLabColor.deltaE(swatch);
        if (deltaE < minDeltaE) {
          minDeltaE = deltaE;
        }
      }

      if (minDeltaE <= deltaEThreshold) {
        matchedPieces.add((testPiece, minDeltaE));
      }
    }

    // 色に近い順にソート
    matchedPieces.sort((a, b) => a.$2.compareTo(b.$2));
    filtered = matchedPieces.map((e) => e.$1).toList();
  }

  return filtered;
}
