import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_profile.dart';

void main() {
  Future<Firing> readBack(Map<String, dynamic> data) async {
    final fakeDb = FakeFirebaseFirestore();
    await fakeDb.collection('firings').doc('f1').set(data);
    final doc = await fakeDb.collection('firings').doc('f1').get();
    return Firing.fromFirestore(doc);
  }

  group('Firing', () {
    test('Firestore を往復できる', () async {
      final firing = Firing(
        firedOn: Firing.noonOf(DateTime(2026, 11, 8)),
        kilnName: '電気窯',
        firingProfileId: 'p1',
        profile: FiringProfileSnapshot.capture(
          FiringProfile(
            id: 'p1',
            name: '本焼き 1230',
            curveData: '60,600\n300,1230',
            isReduction: true,
            reductionStartTemp: 950,
            reductionEndTemp: 1100,
          ),
        ),
        firingAtmosphereId: 'a1',
        atmosphereName: '還元',
        atmosphereType: 'reduction',
        peakTemp: 1235,
        cone: 'SK8 倒れ',
        note: '上段がやや甘い',
        createdAt: Timestamp.fromMillisecondsSinceEpoch(1000),
      );

      final read = await readBack(firing.toFirestore());
      expect(read.id, 'f1');
      expect(read.firedOn.toDate(), DateTime(2026, 11, 8, 12));
      expect(read.kilnName, '電気窯');
      expect(read.firingProfileId, 'p1');
      expect(read.profile!.name, '本焼き 1230');
      expect(read.profile!.curveData, '60,600\n300,1230');
      expect(read.profile!.isReduction, isTrue);
      expect(read.profile!.reductionStartTemp, 950);
      expect(read.profile!.reductionEndTemp, 1100);
      expect(read.firingAtmosphereId, 'a1');
      expect(read.atmosphereName, '還元');
      expect(read.atmosphereType, 'reduction');
      expect(read.peakTemp, 1235);
      expect(read.cone, 'SK8 倒れ');
      expect(read.note, '上段がやや甘い');
      expect(read.createdAt, Timestamp.fromMillisecondsSinceEpoch(1000));
    });

    test('欠損した文書でも読める', () async {
      final read = await readBack({});
      expect(read.firedOn, isA<Timestamp>());
      expect(read.kilnName, isNull);
      expect(read.profile, isNull);
      expect(read.atmosphereName, isNull);
      expect(read.peakTemp, isNull);
      expect(read.note, isNull);
    });

    test('double で保存された数値は整数として読む', () async {
      final read = await readBack({
        'peakTemp': 1230.0,
        'profile': {'name': 'p', 'reductionStartTemp': 900.0},
      });
      expect(read.peakTemp, 1230);
      expect(read.profile!.reductionStartTemp, 900);
    });

    test('profile が Map でなければ null として読む', () async {
      final read = await readBack({'profile': 'broken'});
      expect(read.profile, isNull);
    });

    test('空にした項目を消すため、null も出力する', () {
      final map = Firing(
        firedOn: Timestamp.now(),
        createdAt: Timestamp.now(),
      ).toFirestore();
      expect(map.containsKey('kilnName'), isTrue);
      expect(map.containsKey('profile'), isTrue);
      expect(map.containsKey('note'), isTrue);
    });

    test('displayLabel は焼成日と窯の名前', () {
      final firing = Firing(
        firedOn: Firing.noonOf(DateTime(2026, 11, 8)),
        kilnName: '電気窯',
        createdAt: Timestamp.now(),
      );
      expect(firing.displayLabel, '2026/11/8 電気窯');
    });

    test('窯の名前がなければ displayLabel は焼成日だけ', () {
      final firing = Firing(
        firedOn: Firing.noonOf(DateTime(2026, 1, 5)),
        createdAt: Timestamp.now(),
      );
      expect(firing.displayLabel, '2026/1/5');
    });

    test('noonOf はその日の正午にする', () {
      expect(
        Firing.noonOf(DateTime(2026, 11, 8, 23, 59)).toDate(),
        DateTime(2026, 11, 8, 12),
      );
    });
  });
}
