import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/lab_color.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/models/test_piece_group_key.dart';
import 'package:glaze_manager/utils/test_piece_grouping.dart';

TestPiece _piece(
  String id, {
  String clayId = 'c1',
  List<LabColor>? colorData,
}) {
  return TestPiece(
    id: id,
    glazeId: 'g1',
    clayId: clayId,
    colorData: colorData,
    createdAt: Timestamp.now(),
  );
}

/// 彩度 C* と色相角 h (度) から LabColor を作る (テストの可読性のため)
LabColor _lch(double l, double chroma, double hueDegrees) {
  final rad = hueDegrees * pi / 180;
  return LabColor(
    l: l,
    a: chroma * cos(rad),
    b: chroma * sin(rad),
    percentage: 50,
  );
}

List<TestPieceGroup> _group(
  List<TestPiece> pieces,
  TestPieceGroupKey key, {
  Map<String, Clay> clayMap = const {},
}) {
  return groupTestPieces(
    pieces: pieces,
    key: key,
    clayMap: clayMap,
    atmosphereMap: const <String, FiringAtmosphere>{},
    profileMap: const <String, FiringProfile>{},
  );
}

void main() {
  group('colorHueBucket', () {
    test('無彩色は明度で 白/グレー/黒 に分かれる', () {
      expect(colorHueBucket(_lch(80, 5, 0)), '白');
      expect(colorHueBucket(_lch(50, 5, 0)), 'グレー');
      expect(colorHueBucket(_lch(20, 5, 0)), '黒');
    });

    test('無彩色判定の彩度境界 (C*=12)', () {
      expect(colorHueBucket(_lch(50, 11.9, 90)), 'グレー');
      expect(colorHueBucket(_lch(60, 12.1, 90)), '黄系');
    });

    test('暗い橙〜黄は茶系、明るければ黄系', () {
      expect(colorHueBucket(_lch(40, 30, 60)), '茶系');
      expect(colorHueBucket(_lch(60, 30, 60)), '黄系');
      // 茶系判定は赤系レンジ (h<45) にも先に効く
      expect(colorHueBucket(_lch(40, 30, 35)), '茶系');
      expect(colorHueBucket(_lch(60, 30, 35)), '赤系');
    });

    test('色相角の境界値 (LCh→Lab→LCh の往復で誤差が出るため±0.5°で確認)', () {
      expect(colorHueBucket(_lch(60, 40, 20)), '赤系');
      expect(colorHueBucket(_lch(60, 40, 350)), '赤系');
      expect(colorHueBucket(_lch(60, 40, 44.5)), '赤系');
      expect(colorHueBucket(_lch(60, 40, 45.5)), '黄系');
      expect(colorHueBucket(_lch(60, 40, 109.5)), '黄系');
      expect(colorHueBucket(_lch(60, 40, 110.5)), '緑系');
      expect(colorHueBucket(_lch(60, 40, 199.5)), '緑系');
      expect(colorHueBucket(_lch(60, 40, 200.5)), '青系');
      expect(colorHueBucket(_lch(60, 40, 299.5)), '青系');
      expect(colorHueBucket(_lch(60, 40, 300.5)), '紫系');
      expect(colorHueBucket(_lch(60, 40, 344.5)), '紫系');
      expect(colorHueBucket(_lch(60, 40, 345.5)), '赤系');
    });
  });

  group('representativeColor', () {
    test('percentage 最大のエントリを返す', () {
      final minor = LabColor(l: 50, a: 0, b: 0, percentage: 10);
      final major = LabColor(l: 60, a: 10, b: 10, percentage: 80);
      expect(representativeColor([minor, major]), major);
    });

    test('全て percentage 0 (手動追加のみ) なら先頭を返す', () {
      final first = LabColor(l: 50, a: 0, b: 0, percentage: 0);
      final second = LabColor(l: 60, a: 10, b: 10, percentage: 0);
      expect(representativeColor([first, second]), first);
    });

    test('null / 空なら null', () {
      expect(representativeColor(null), isNull);
      expect(representativeColor([]), isNull);
    });
  });

  group('groupTestPieces', () {
    test('素地土: 名前昇順、未設定と不明は末尾。グループ内は入力順を維持', () {
      final clayMap = <String, Clay>{
        'c1': Clay(id: 'c1', name: 'い土', order: 0),
        'c2': Clay(id: 'c2', name: 'あ土', order: 1),
      };
      final p1 = _piece('p1', clayId: 'c1');
      final p2 = _piece('p2', clayId: 'c2');
      final p3 = _piece('p3', clayId: 'c1');
      final p4 = _piece('p4', clayId: ''); // 未設定
      final p5 = _piece('p5', clayId: 'deleted'); // マスタ欠落

      final groups = _group(
        [p1, p2, p3, p4, p5],
        TestPieceGroupKey.clay,
        clayMap: clayMap,
      );

      expect(groups.map((g) => g.label), ['あ土', 'い土', '未設定', '不明']);
      expect(groups[1].pieces, [p1, p3]); // 入力順維持
      expect(groups[2].pieces, [p4]);
      expect(groups[3].pieces, [p5]);
    });

    test('色味: 固定順で並び、色データなしは末尾。空グループは返さない', () {
      final red = _piece('red', colorData: [_lch(60, 40, 20)]);
      final blue = _piece('blue', colorData: [_lch(60, 40, 250)]);
      final noData = _piece('noData');

      final groups = _group([blue, red, noData], TestPieceGroupKey.colorHue);

      expect(groups.map((g) => g.label), ['赤系', '青系', noColorDataLabel]);
      expect(groups[0].pieces, [red]);
      expect(groups[1].pieces, [blue]);
      expect(groups[2].pieces, [noData]);
    });
  });
}
