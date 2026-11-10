import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/utils/test_piece_display.dart';

TestPiece _piece({
  String? firingId,
  String? firingAtmosphereId,
  String? firingProfileId,
}) {
  return TestPiece(
    id: 'tp1',
    glazeId: 'g1',
    clayId: 'c1',
    createdAt: Timestamp.now(),
    firingId: firingId,
    firingAtmosphereId: firingAtmosphereId,
    firingProfileId: firingProfileId,
  );
}

void main() {
  final atmosphere = FiringAtmosphere(
    id: 'a1',
    name: '還元 (現在)',
    type: FiringAtmosphereType.reduction,
  );
  final profile = FiringProfile(
    id: 'p1',
    name: '本焼き (現在)',
    curveData: '60,600\n300,1250',
    isReduction: true,
    reductionStartTemp: 1000,
    reductionEndTemp: 1200,
  );
  final firing = Firing(
    id: 'f1',
    firedOn: Firing.noonOf(DateTime(2026, 11, 8)),
    kilnName: '電気窯',
    firingProfileId: 'p1',
    profile: const FiringProfileSnapshot(
      name: '本焼き (写し)',
      curveData: '60,600\n300,1230',
      isReduction: true,
      reductionStartTemp: 950,
      reductionEndTemp: 1100,
    ),
    firingAtmosphereId: 'a1',
    atmosphereName: '還元 (写し)',
    atmosphereType: 'reduction',
    createdAt: Timestamp.now(),
  );

  group('resolveFiring', () {
    test('焼成回あり: 名前は現在の値、温度曲線と還元は焼成回の写し', () {
      final r = resolveFiring(
        _piece(firingId: 'f1', firingAtmosphereId: 'other'),
        firingMap: {'f1': firing},
        atmosphereMap: {'a1': atmosphere},
        profileMap: {'p1': profile},
      );
      expect(r.firing, same(firing));
      expect(r.firingMissing, isFalse);
      expect(r.firedOn, DateTime(2026, 11, 8, 12));
      expect(r.kilnName, '電気窯');
      expect(r.atmosphereName, '還元 (現在)');
      expect(r.atmosphereType, FiringAtmosphereType.reduction);
      expect(r.profileName, '本焼き (現在)');
      expect(r.curveData, '60,600\n300,1230');
      expect(r.isReduction, isTrue);
      expect(r.reductionStartTemp, 950);
      expect(r.reductionEndTemp, 1100);
    });

    test('焼成回あり: 雰囲気やプロファイルが削除されていれば写しの名前を使う', () {
      final r = resolveFiring(
        _piece(firingId: 'f1'),
        firingMap: {'f1': firing},
        atmosphereMap: const {},
        profileMap: const {},
      );
      expect(r.atmosphereName, '還元 (写し)');
      expect(r.atmosphereType, FiringAtmosphereType.reduction);
      expect(r.profileName, '本焼き (写し)');
      expect(r.atmosphereLabel, '還元 (写し)');
    });

    test('焼成回あり: プロファイルを選ばずに作った焼成回は曲線が null', () {
      final noProfile = Firing(
        id: 'f2',
        firedOn: Timestamp.now(),
        createdAt: Timestamp.now(),
      );
      final r = resolveFiring(
        _piece(firingId: 'f2'),
        firingMap: {'f2': noProfile},
        atmosphereMap: const {},
        profileMap: const {},
      );
      expect(r.profileName, isNull);
      expect(r.curveData, isNull);
      expect(r.isReduction, isFalse);
      expect(r.profileLabel, '未設定');
      expect(r.atmosphereLabel, '未設定');
    });

    test('焼成回が見つからない: firingMissing で、表示は「不明」', () {
      final r = resolveFiring(
        _piece(firingId: 'f-deleted', firingAtmosphereId: 'a1'),
        firingMap: const {},
        atmosphereMap: {'a1': atmosphere},
        profileMap: {'p1': profile},
      );
      expect(r.firingMissing, isTrue);
      expect(r.firing, isNull);
      expect(r.atmosphereName, isNull);
      expect(r.atmosphereType, FiringAtmosphereType.other);
      expect(r.isReduction, isFalse);
      expect(r.atmosphereLabel, '不明');
      expect(r.profileLabel, '不明');
    });

    test('焼成回なし: テストピースの参照から現在の値を引く', () {
      final r = resolveFiring(
        _piece(firingAtmosphereId: 'a1', firingProfileId: 'p1'),
        firingMap: {'f1': firing},
        atmosphereMap: {'a1': atmosphere},
        profileMap: {'p1': profile},
      );
      expect(r.firing, isNull);
      expect(r.firingMissing, isFalse);
      expect(r.firedOn, isNull);
      expect(r.atmosphereName, '還元 (現在)');
      expect(r.atmosphereType, FiringAtmosphereType.reduction);
      expect(r.profileName, '本焼き (現在)');
      expect(r.curveData, '60,600\n300,1250');
      expect(r.reductionStartTemp, 1000);
    });

    test('焼成回なし: 参照がなければ「未設定」', () {
      final r = resolveFiring(
        _piece(),
        firingMap: const {},
        atmosphereMap: const {},
        profileMap: const {},
      );
      expect(r.atmosphereLabel, '未設定');
      expect(r.profileLabel, '未設定');
      expect(r.atmosphereType, FiringAtmosphereType.other);
    });
  });
}
