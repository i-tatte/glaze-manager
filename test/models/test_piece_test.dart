import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/models/color_swatch.dart';

void main() {
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
        colorData: [ColorSwatch(l: 50, a: 10, b: 20, percentage: 0.5)],
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
    });
  });
}
