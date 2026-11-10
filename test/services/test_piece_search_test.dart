import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/lab_color.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/recipe_snapshot.dart';
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
  int? rating,
  String? label,
  String? firingId,
}) {
  return TestPiece(
    id: id,
    glazeId: glazeId,
    clayId: 'c1',
    colorData: colorData,
    createdAt: createdAt ?? Timestamp.now(),
    rating: rating,
    label: label,
    firingId: firingId,
  );
}

/// テキスト・タグ検索ではマップ内容（色・素地など）は使わないので空でよい。
List<TestPiece> _filter({
  required List<TestPiece> pieces,
  String query = '',
  List<String> selectedTags = const [],
  int? minRating,
  Color? color,
  double deltaEThreshold = 30.0,
  TestPieceSortOrder sortOrder = TestPieceSortOrder.relevance,
  required Map<String, Glaze> glazeMap,
  Map<String, String> materialMap = const {},
  Map<String, FiringAtmosphere> atmosphereMap = const {},
  Map<String, Firing> firingMap = const {},
}) {
  return filterTestPieces(
    pieces: pieces,
    query: query,
    selectedTags: selectedTags,
    minRating: minRating,
    color: color,
    deltaEThreshold: deltaEThreshold,
    sortOrder: sortOrder,
    glazeMap: glazeMap,
    clayMap: const <String, Clay>{},
    atmosphereMap: atmosphereMap,
    profileMap: const <String, FiringProfile>{},
    firingMap: firingMap,
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

    test('釉薬が削除されていても写しがあれば釉薬名と原料名で見つかる', () {
      final orphan = TestPiece(
        id: 'orphan',
        glazeId: 'deleted',
        clayId: 'c1',
        createdAt: Timestamp.now(),
        snapshot: TestPieceSnapshot(
          glaze: GlazeSnapshot(
            glazeId: 'deleted',
            name: '消えた釉',
            lines: const [
              RecipeLine(
                materialId: 'gone',
                name: '消えた原料',
                category: 'base',
                amount: 10,
              ),
              RecipeLine(
                materialId: 'm1',
                name: '旧名',
                category: 'base',
                amount: 5,
              ),
            ],
          ),
          source: SnapshotSource.saved,
          takenAt: Timestamp.now(),
        ),
      );
      final pieces = [tp1, orphan];
      const materialMap = {'m1': '長石'};

      expect(
        _filter(
          pieces: pieces,
          query: '消えた釉',
          glazeMap: glazeMap,
          materialMap: materialMap,
        ),
        [orphan],
      );
      // 削除された原料は写しの名前で、現存する原料は現在の名前で見つかる
      expect(
        _filter(
          pieces: pieces,
          query: '消えた原料',
          glazeMap: glazeMap,
          materialMap: materialMap,
        ),
        [orphan],
      );
      expect(
        _filter(
          pieces: pieces,
          query: '長石',
          glazeMap: glazeMap,
          materialMap: materialMap,
        ),
        [orphan],
      );
      expect(
        _filter(
          pieces: pieces,
          query: '旧名',
          glazeMap: glazeMap,
          materialMap: materialMap,
        ),
        isEmpty,
      );
      // タグの絞り込みは、釉薬が現存しないものを外す
      expect(
        _filter(pieces: pieces, selectedTags: ['glossy'], glazeMap: glazeMap),
        [tp1],
      );
    });
  });

  group('評価と番号', () {
    final glazeMap = {'g1': _glaze('g1', 'Blue Glaze')};
    final tp5 = _piece('tp5', 'g1', rating: 5, label: '1108-1');
    final tp3 = _piece('tp3', 'g1', rating: 3, label: '1108-2');
    final tpNone = _piece('tpNone', 'g1');
    final tp4 = _piece('tp4', 'g1', rating: 4);
    final pieces = [tp3, tpNone, tp5, tp4];

    test('minRating 以上だけを残し、未評価は外れる', () {
      final result = _filter(pieces: pieces, minRating: 4, glazeMap: glazeMap);
      expect(result, [tp5, tp4]);
    });

    test('minRating がなければ絞り込まない', () {
      final result = _filter(pieces: pieces, glazeMap: glazeMap);
      expect(result, pieces);
    });

    test('番号で検索できる', () {
      final result = _filter(
        pieces: pieces,
        query: '1108-2',
        glazeMap: glazeMap,
      );
      expect(result, [tp3]);
    });

    test('評価が高い順に並び、未評価は末尾', () {
      final result = _filter(
        pieces: pieces,
        sortOrder: TestPieceSortOrder.ratingDesc,
        glazeMap: glazeMap,
      );
      expect(result, [tp5, tp4, tp3, tpNone]);
    });

    test('評価が同じものは元の順序を保つ', () {
      final a = _piece('a', 'g1', rating: 2);
      final b = _piece('b', 'g1', rating: 2);
      final c = _piece('c', 'g1', rating: 2);
      final result = _filter(
        pieces: [a, b, c],
        sortOrder: TestPieceSortOrder.ratingDesc,
        glazeMap: glazeMap,
      );
      expect(result, [a, b, c]);
    });
  });

  group('焼成回', () {
    final glazeMap = {'g1': _glaze('g1', 'Blue Glaze')};
    final firing = Firing(
      id: 'f1',
      firedOn: Timestamp.fromDate(DateTime(2026, 11, 8, 12)),
      kilnName: '電気窯',
      firingAtmosphereId: 'a-deleted',
      atmosphereName: '還元',
      createdAt: Timestamp.now(),
    );
    final inFiring = _piece('in', 'g1', firingId: 'f1');
    final other = _piece('other', 'g1');

    test('窯の名前で検索できる', () {
      final result = _filter(
        pieces: [inFiring, other],
        query: '電気窯',
        glazeMap: glazeMap,
        firingMap: {'f1': firing},
      );
      expect(result, [inFiring]);
    });

    test('焼成日で検索できる', () {
      final result = _filter(
        pieces: [inFiring, other],
        query: '2026/11/8',
        glazeMap: glazeMap,
        firingMap: {'f1': firing},
      );
      expect(result, [inFiring]);
    });

    test('雰囲気名は焼成回から解決する', () {
      final result = _filter(
        pieces: [inFiring, other],
        query: '還元',
        glazeMap: glazeMap,
        firingMap: {'f1': firing},
      );
      expect(result, [inFiring]);
    });
  });
}
