import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/recipe_snapshot.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/models/lab_color.dart';

void main() {
  group('TestPiece.toUpdateFields', () {
    final piece = TestPiece(
      glazeId: 'g1',
      additionalGlazeIds: ['g2'],
      clayId: 'c1',
      imageUrl: 'u',
      imagePath: 'p',
      thumbnailUrl: 't',
      colorData: [LabColor(l: 1, a: 2, b: 3, percentage: 4)],
      note: 'n',
      createdAt: Timestamp.now(),
    );

    test('Functions が書く値と createdAt は含まれない', () {
      final f = piece.toUpdateFields(
        includeImagePath: true,
        includeColorData: true,
        includeSnapshot: true,
      );
      expect(f.containsKey('imageUrl'), isFalse);
      expect(f.containsKey('thumbnailUrl'), isFalse);
      expect(f.containsKey('createdAt'), isFalse);
      expect(f['relatedGlazeIds'], ['g1', 'g2']);
      expect(f['note'], 'n');
    });

    test('imagePath と colorData は引数で切り替わる', () {
      final on = piece.toUpdateFields(
        includeImagePath: true,
        includeColorData: true,
        includeSnapshot: true,
      );
      expect(on['imagePath'], 'p');
      expect(on.containsKey('colorData'), isTrue);

      final off = piece.toUpdateFields(
        includeImagePath: false,
        includeColorData: false,
        includeSnapshot: false,
      );
      expect(off.containsKey('imagePath'), isFalse);
      expect(off.containsKey('colorData'), isFalse);
      expect(off['relatedGlazeIds'], ['g1', 'g2']);
    });
  });

  group('TestPiece Model Test', () {
    test('toFirestore returns correct map', () {
      final now = Timestamp.now();
      final testPiece = TestPiece(
        glazeId: 'g1',
        clayId: 'c1',
        firingProfileId: 'fp1',
        firingAtmosphereId: 'fa1',
        imageUrl: 'http://example.com/image.png',
        note: 'Test description',
        createdAt: now,
        additionalGlazeIds: ['g2'],
        colorData: [LabColor(l: 50, a: 10, b: 20, percentage: 0.5)],
      );
      final map = testPiece.toFirestore();
      expect(map['glazeId'], 'g1');
      expect(map['clayId'], 'c1');
      expect(map['firingProfileId'], 'fp1');
      expect(map['firingAtmosphereId'], 'fa1');
      expect(map['imageUrl'], 'http://example.com/image.png');
      expect(map['note'], 'Test description');
      expect(map['createdAt'], now);
      expect(map['additionalGlazeIds'], ['g2']);
      expect(map['relatedGlazeIds'], ['g1', 'g2']); // Computed field
      expect(map['colorData'], isA<List>());
      expect((map['colorData'] as List).length, 1);
    });

    test('fromFirestore creates correct instance', () async {
      final fakeDb = FakeFirebaseFirestore();
      final now = Timestamp.now();
      await fakeDb.collection('test_pieces').doc('tp1').set({
        'glazeId': 'g1',
        'clayId': 'c1',
        'firingProfileId': 'fp1',
        'firingAtmosphereId': 'fa1',
        'imageUrl': 'http://example.com/image.png',
        'note': 'Test description',
        'createdAt': now,
        'additionalGlazeIds': ['g2'],
        'colorData': [
          {'L': 50.0, 'a': 10.0, 'b': 20.0, 'percentage': 0.5},
        ],
      });
      final snapshot = await fakeDb.collection('test_pieces').doc('tp1').get();

      final testPiece = TestPiece.fromFirestore(snapshot);
      expect(testPiece.id, 'tp1');
      expect(testPiece.glazeId, 'g1');
      expect(testPiece.clayId, 'c1');
      expect(testPiece.firingProfileId, 'fp1');
      expect(testPiece.firingAtmosphereId, 'fa1');
      expect(testPiece.imageUrl, 'http://example.com/image.png');
      expect(testPiece.note, 'Test description');
      expect(testPiece.createdAt, now);
      expect(testPiece.additionalGlazeIds, ['g2']);
      expect(testPiece.colorData!.length, 1);
      expect(testPiece.colorData!.first.l, 50.0);
    });

    test('constructor copies collections defensively (R-7)', () {
      final additionalGlazeIds = ['g2'];
      final colorData = [LabColor(l: 50, a: 10, b: 20, percentage: 0.5)];
      final testPiece = TestPiece(
        glazeId: 'g1',
        clayId: 'c1',
        additionalGlazeIds: additionalGlazeIds,
        colorData: colorData,
        createdAt: Timestamp.now(),
      );

      // コンストラクタに渡したリストを後から変更してもモデルに影響しない
      additionalGlazeIds.add('g3');
      colorData.add(LabColor(l: 0, a: 0, b: 0, percentage: 0));

      expect(testPiece.additionalGlazeIds, ['g2']);
      expect(testPiece.colorData!.length, 1);
    });

    test('fromFirestore handles missing data with defaults', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('test_pieces').doc('tp2').set({});
      final snapshot = await fakeDb.collection('test_pieces').doc('tp2').get();

      final testPiece = TestPiece.fromFirestore(snapshot);
      expect(testPiece.id, 'tp2');
      expect(testPiece.glazeId, '');
      expect(testPiece.clayId, '');
      expect(testPiece.firingProfileId, null);
      expect(testPiece.firingAtmosphereId, null);
      expect(testPiece.imageUrl, null);
      expect(testPiece.note, null);
      expect(testPiece.createdAt, isA<Timestamp>());
      expect(testPiece.additionalGlazeIds, []);
      expect(testPiece.colorData, null);
      expect(testPiece.snapshot, isNull);
    });
  });

  group('TestPiece の調合の写し', () {
    final snapshot = TestPieceSnapshot(
      glaze: GlazeSnapshot(
        glazeId: 'g1',
        name: '青磁',
        lines: const [
          RecipeLine(
            materialId: 'm1',
            name: '長石',
            category: 'base',
            amount: 60,
          ),
        ],
      ),
      additionalGlazes: [
        GlazeSnapshot(glazeId: 'g2', name: '鉄赤', lines: const []),
      ],
      clayName: '信楽白',
      source: SnapshotSource.saved,
      takenAt: Timestamp.fromMillisecondsSinceEpoch(1000),
    );

    test('写しは Firestore を往復できる', () async {
      final fakeDb = FakeFirebaseFirestore();
      final piece = TestPiece(
        glazeId: 'g1',
        additionalGlazeIds: ['g2'],
        clayId: 'c1',
        createdAt: Timestamp.now(),
        snapshot: snapshot,
      );
      await fakeDb
          .collection('test_pieces')
          .doc('tp1')
          .set(piece.toFirestore());
      final doc = await fakeDb.collection('test_pieces').doc('tp1').get();

      final read = TestPiece.fromFirestore(doc).snapshot!;
      expect(read.source, 'saved');
      expect(read.clayName, '信楽白');
      expect(read.takenAt, Timestamp.fromMillisecondsSinceEpoch(1000));
      expect(read.glaze!.name, '青磁');
      expect(read.glaze!.recipe, {'m1': 60.0});
      expect(read.additionalGlazes.single.glazeId, 'g2');
    });

    test('写しがなければ snapshot を出力しない', () {
      final piece = TestPiece(
        glazeId: 'g1',
        clayId: 'c1',
        createdAt: Timestamp.now(),
      );
      expect(piece.toFirestore().containsKey('snapshot'), isFalse);
    });

    test('snapshot が Map でなければ null として読む', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('test_pieces').doc('tp1').set({
        'glazeId': 'g1',
        'snapshot': 'broken',
      });
      final doc = await fakeDb.collection('test_pieces').doc('tp1').get();
      expect(TestPiece.fromFirestore(doc).snapshot, isNull);
    });

    test('toUpdateFields は includeSnapshot で写しの有無が切り替わる', () {
      final piece = TestPiece(
        glazeId: 'g1',
        clayId: 'c1',
        createdAt: Timestamp.now(),
        snapshot: snapshot,
      );
      final on = piece.toUpdateFields(
        includeImagePath: false,
        includeColorData: false,
        includeSnapshot: true,
      );
      expect(on['snapshot'], isA<Map>());
      final off = piece.toUpdateFields(
        includeImagePath: false,
        includeColorData: false,
        includeSnapshot: false,
      );
      expect(off.containsKey('snapshot'), isFalse);
    });
  });

  group('TestPiece の評価と番号', () {
    Future<TestPiece> readBack(Map<String, dynamic> data) async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('test_pieces').doc('tp1').set(data);
      final doc = await fakeDb.collection('test_pieces').doc('tp1').get();
      return TestPiece.fromFirestore(doc);
    }

    test('rating と label は Firestore を往復できる', () async {
      final piece = TestPiece(
        glazeId: 'g1',
        clayId: 'c1',
        createdAt: Timestamp.now(),
        rating: 4,
        label: '1108-3',
      );
      final read = await readBack(piece.toFirestore());
      expect(read.rating, 4);
      expect(read.label, '1108-3');
    });

    test('rating と label は null でも出力する', () {
      final map = TestPiece(
        glazeId: 'g1',
        clayId: 'c1',
        createdAt: Timestamp.now(),
      ).toFirestore();
      expect(map.containsKey('rating'), isTrue);
      expect(map['rating'], isNull);
      expect(map.containsKey('label'), isTrue);
      expect(map['label'], isNull);
    });

    test('範囲外の rating は未評価として読む', () async {
      expect((await readBack({'rating': 0})).rating, isNull);
      expect((await readBack({'rating': 6})).rating, isNull);
      expect((await readBack({'rating': 'x'})).rating, isNull);
      expect((await readBack({})).rating, isNull);
    });

    test('double で保存された rating は整数として読む', () async {
      expect((await readBack({'rating': 3.0})).rating, 3);
    });

    test('空文字列の label は null として読む', () async {
      expect((await readBack({'label': ''})).label, isNull);
    });
  });

  group('TestPiece の焼成回', () {
    test('firingId は Firestore を往復できる', () async {
      final fakeDb = FakeFirebaseFirestore();
      final piece = TestPiece(
        glazeId: 'g1',
        clayId: 'c1',
        createdAt: Timestamp.now(),
        firingId: 'f1',
      );
      await fakeDb
          .collection('test_pieces')
          .doc('tp1')
          .set(piece.toFirestore());
      final doc = await fakeDb.collection('test_pieces').doc('tp1').get();
      expect(TestPiece.fromFirestore(doc).firingId, 'f1');
    });

    test('firingId は null でも toUpdateFields に含まれる', () {
      final fields =
          TestPiece(
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ).toUpdateFields(
            includeImagePath: false,
            includeColorData: false,
            includeSnapshot: false,
          );
      expect(fields.containsKey('firingId'), isTrue);
      expect(fields['firingId'], isNull);
    });

    test('firingId のない文書は null として読む', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('test_pieces').doc('tp1').set({'glazeId': 'g1'});
      final doc = await fakeDb.collection('test_pieces').doc('tp1').get();
      expect(TestPiece.fromFirestore(doc).firingId, isNull);
    });
  });
}
