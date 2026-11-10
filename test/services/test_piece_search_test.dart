import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/lab_color.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/services/test_piece_search.dart';

Glaze _glaze(
  String id,
  String name, {
  List<String> tags = const [],
  Map<String, double> recipe = const {},
}) {
  return Glaze(
    id: id,
    name: name,
    recipe: recipe,
    tags: tags,
    createdAt: Timestamp.now(),
  );
}

TestPiece _piece(
  String id,
  String glazeId, {
  List<LabColor>? colorData,
  Timestamp? createdAt,
}) {
  return TestPiece(
    id: id,
    glazeId: glazeId,
    clayId: 'c1',
    colorData: colorData,
    createdAt: createdAt ?? Timestamp.now(),
  );
}

/// テキスト・タグ検索ではマップ内容（色・素地など）は使わないので空でよい。
List<TestPiece> _filter({
  required List<TestPiece> pieces,
  String query = '',
  List<String> selectedTags = const [],
  Color? color,
  double deltaEThreshold = 30.0,
  TestPieceSortOrder sortOrder = TestPieceSortOrder.relevance,
  required Map<String, Glaze> glazeMap,
  Map<String, String> materialMap = const {},
}) {
  return filterTestPieces(
    pieces: pieces,
    query: query,
    selectedTags: selectedTags,
    color: color,
    deltaEThreshold: deltaEThreshold,
    sortOrder: sortOrder,
    glazeMap: glazeMap,
    clayMap: const <String, Clay>{},
    atmosphereMap: const <String, FiringAtmosphere>{},
    profileMap: const <String, FiringProfile>{},
    materialMap: materialMap,
  );
}

void main() {
  group('filterTestPieces', () {
    final g1 = _glaze('g1', 'Blue Glaze', tags: ['glossy', 'blue']);
    final g2 = _glaze('g2', 'Red Glaze', tags: ['matte']);
    final glazeMap = {'g1': g1, 'g2': g2};

    final tp1 = _piece('tp1', 'g1');
    final tp2 = _piece('tp2', 'g2');
    final tp3 = _piece('tp3', 'missing'); // 釉薬が glazeMap に無い

    test(
      'no filters returns the pieces unchanged (including missing glaze)',
      () {
        final result = _filter(pieces: [tp1, tp2, tp3], glazeMap: glazeMap);
        expect(result, [tp1, tp2, tp3]);
      },
    );

    test('space-separated terms are AND-matched', () {
      final result = _filter(
        pieces: [tp1, tp2],
        query: 'blue glossy',
        glazeMap: glazeMap,
      );
      expect(result, [tp1]);
    });

    test('-term excludes matching pieces', () {
      final result = _filter(
        pieces: [tp1, tp2],
        query: '-red',
        glazeMap: glazeMap,
      );
      expect(result, [tp1]);
    });

    test('pieces whose glaze is missing are excluded during text search', () {
      final result = _filter(
        pieces: [tp1, tp2, tp3],
        query: 'glaze',
        glazeMap: glazeMap,
      );
      expect(result, containsAll([tp1, tp2]));
      expect(result, isNot(contains(tp3)));
    });

    test('material-name matches sort after primary (name/tag) matches', () {
      // g3 は名前に 'kaolin' を含む(プライマリ)。g1 は原料名に 'kaolin' を含む(材料)。
      final g3 = _glaze('g3', 'Kaolin Special', recipe: {'m2': 50});
      final gMap = {
        'g1': _glaze('g1', 'Blue Glaze', recipe: {'m1': 50}),
        'g3': g3,
      };
      final tpName = _piece('tpName', 'g3'); // 名前マッチ
      final tpMaterial = _piece('tpMaterial', 'g1'); // 原料マッチ
      final result = _filter(
        pieces: [tpMaterial, tpName],
        query: 'kaolin',
        glazeMap: gMap,
        materialMap: {'m1': 'Kaolin', 'm2': 'Feldspar'},
      );
      expect(result, [tpName, tpMaterial]);
    });

    test('tag filter is AND', () {
      final result = _filter(
        pieces: [tp1, tp2],
        selectedTags: ['glossy', 'blue'],
        glazeMap: glazeMap,
      );
      expect(result, [tp1]);
    });

    test('color search keeps within-threshold pieces sorted nearest-first', () {
      const target = Color(0xFFFF0000); // red
      final near = _piece(
        'near',
        'g1',
        colorData: [LabColor.fromColor(const Color(0xFFFF0000))],
      );
      final far = _piece(
        'far',
        'g2',
        colorData: [LabColor.fromColor(const Color(0xFF0000FF))], // blue
      );
      final result = _filter(
        pieces: [far, near],
        color: target,
        deltaEThreshold: 200.0, // 両方含む十分大きい閾値
        sortOrder: TestPieceSortOrder.colorDistance,
        glazeMap: glazeMap,
      );
      expect(result, [near, far]);
    });

    test('color search with relevance keeps the incoming order', () {
      const target = Color(0xFFFF0000); // red
      final near = _piece(
        'near',
        'g1',
        colorData: [LabColor.fromColor(const Color(0xFFFF0000))],
      );
      final far = _piece(
        'far',
        'g2',
        colorData: [LabColor.fromColor(const Color(0xFF0000FF))],
      );
      final result = _filter(
        pieces: [far, near],
        color: target,
        deltaEThreshold: 200.0,
        glazeMap: glazeMap,
      );
      expect(result, [far, near]); // ΔEソートされず入力順のまま
    });

    test('color search drops pieces beyond the deltaE threshold', () {
      const target = Color(0xFFFF0000); // red
      final near = _piece(
        'near',
        'g1',
        colorData: [LabColor.fromColor(const Color(0xFFFF0000))],
      );
      final far = _piece(
        'far',
        'g2',
        colorData: [LabColor.fromColor(const Color(0xFF0000FF))],
      );
      final result = _filter(
        pieces: [near, far],
        color: target,
        deltaEThreshold: 5.0, // near(ΔE≈0)のみ通す
        glazeMap: glazeMap,
      );
      expect(result, [near]);
    });

    test('面積の小さい自動解析の色は色検索に当たらず、手動の色は当たる', () {
      const target = Color(0xFFFFFFFF); // white
      final white = LabColor.fromColor(const Color(0xFFFFFFFF));
      final dark = LabColor.fromColor(const Color(0xFF202020));
      final tiny = _piece(
        'tiny',
        'g1',
        colorData: [
          LabColor(l: dark.l, a: dark.a, b: dark.b, percentage: 98),
          LabColor(l: white.l, a: white.a, b: white.b, percentage: 2),
        ],
      );
      final manual = _piece(
        'manual',
        'g2',
        colorData: [white], // percentage 0 = 手動登録
      );
      final result = _filter(
        pieces: [tiny, manual],
        color: target,
        deltaEThreshold: 5.0,
        glazeMap: glazeMap,
      );
      expect(result, [manual]);
    });

    test('newest / oldest sort by createdAt', () {
      final older = _piece(
        'older',
        'g1',
        createdAt: Timestamp.fromMillisecondsSinceEpoch(1000),
      );
      final newer = _piece(
        'newer',
        'g2',
        createdAt: Timestamp.fromMillisecondsSinceEpoch(2000),
      );
      expect(
        _filter(
          pieces: [older, newer],
          sortOrder: TestPieceSortOrder.newest,
          glazeMap: glazeMap,
        ),
        [newer, older],
      );
      expect(
        _filter(
          pieces: [newer, older],
          sortOrder: TestPieceSortOrder.oldest,
          glazeMap: glazeMap,
        ),
        [older, newer],
      );
    });

    test('newest sort does not mutate the input list', () {
      final older = _piece(
        'older',
        'g1',
        createdAt: Timestamp.fromMillisecondsSinceEpoch(1000),
      );
      final newer = _piece(
        'newer',
        'g2',
        createdAt: Timestamp.fromMillisecondsSinceEpoch(2000),
      );
      final input = [older, newer];
      _filter(
        pieces: input,
        sortOrder: TestPieceSortOrder.newest,
        glazeMap: glazeMap,
      );
      expect(input, [older, newer]);
    });

    test('pieces without color data are excluded from a color search', () {
      const target = Color(0xFFFF0000);
      final withColor = _piece(
        'withColor',
        'g1',
        colorData: [LabColor.fromColor(const Color(0xFFFF0000))],
      );
      final withoutColor = _piece('withoutColor', 'g2'); // colorData == null
      final result = _filter(
        pieces: [withColor, withoutColor],
        color: target,
        deltaEThreshold: 200.0,
        glazeMap: glazeMap,
      );
      expect(result, [withColor]);
    });
  });
}
