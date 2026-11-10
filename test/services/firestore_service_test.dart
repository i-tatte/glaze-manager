import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:mockito/mockito.dart';

// Mocks
class MockFirebaseAuth extends Mock implements FirebaseAuth {
  @override
  User? get currentUser => super.noSuchMethod(
    Invocation.getter(#currentUser),
    returnValue: MockUser(),
  );
}

class MockUser extends Mock implements User {
  @override
  String get uid => 'test_uid';
}

void main() {
  late FirestoreService firestoreService;
  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    // Stub currentUser to return a user by default
    when(mockAuth.currentUser).thenReturn(MockUser());
    firestoreService = FirestoreService(db: fakeDb, auth: mockAuth);
  });

  group('FirestoreService Test', () {
    test('addMaterial adds document to correct collection', () async {
      final material = Material(
        name: 'Test Material',
        order: 1,
        components: {},
        category: MaterialCategory.base,
      );

      await firestoreService.addMaterial(material);

      final snapshot = await fakeDb
          .collection('users')
          .doc('test_uid')
          .collection('materials')
          .get();

      expect(snapshot.docs.length, 1);
      final doc = snapshot.docs.first;
      expect(doc.data()['name'], 'Test Material');
      expect(doc.data()['category'], 'base');
    });

    test('addMaterial throws if user not logged in', () async {
      final material = Material(
        name: 'Test Material',
        order: 1,
        components: {},
        category: MaterialCategory.base,
      );

      when(mockAuth.currentUser).thenReturn(null);

      expect(() => firestoreService.addMaterial(material), throwsException);
    });
  });

  group('backfillTestPieceSnapshots', () {
    CollectionReference<Map<String, dynamic>> col(String name) =>
        fakeDb.collection('users').doc('test_uid').collection(name);

    test('写しのないテストピースだけに、現在の調合から写しを埋める', () async {
      await col('materials').doc('m1').set({
        'name': '長石',
        'order': 0,
        'components': <String, dynamic>{},
        'category': 'base',
      });
      await col('glazes').doc('g1').set({
        'name': '青磁',
        'recipe': {'m1': 60},
        'tags': <String>[],
        'createdAt': Timestamp.now(),
      });
      await col('clays').doc('c1').set({'name': '信楽白', 'order': 0});
      // 写しなし (対象)
      await col('test_pieces').doc('tp1').set({
        'glazeId': 'g1',
        'clayId': 'c1',
        'createdAt': Timestamp.now(),
      });
      // すでに写しがある (対象外。上書きしない)
      await col('test_pieces').doc('tp2').set({
        'glazeId': 'g1',
        'clayId': 'c1',
        'createdAt': Timestamp.now(),
        'snapshot': {
          'source': 'saved',
          'takenAt': Timestamp.now(),
          'clayName': '当時の土',
          'glaze': {
            'glazeId': 'g1',
            'name': '青磁',
            'lines': [
              {
                'materialId': 'm1',
                'name': '長石',
                'category': 'base',
                'amount': 50,
              },
            ],
          },
          'additionalGlazes': <dynamic>[],
        },
      });
      // 主たる釉薬が見つからない (対象外)
      await col('test_pieces').doc('tp3').set({
        'glazeId': 'deleted',
        'clayId': 'c1',
        'createdAt': Timestamp.now(),
      });

      final count = await firestoreService.backfillTestPieceSnapshots();

      expect(count, 1);
      final tp1 = (await col('test_pieces').doc('tp1').get()).data()!;
      final snapshot = tp1['snapshot'] as Map<String, dynamic>;
      expect(snapshot['source'], 'backfilled');
      expect(snapshot['clayName'], '信楽白');
      expect((snapshot['glaze'] as Map)['lines'], [
        {'materialId': 'm1', 'name': '長石', 'category': 'base', 'amount': 60.0},
      ]);

      final tp2 = (await col('test_pieces').doc('tp2').get()).data()!;
      expect((tp2['snapshot'] as Map)['source'], 'saved');
      expect((tp2['snapshot'] as Map)['clayName'], '当時の土');

      final tp3 = (await col('test_pieces').doc('tp3').get()).data()!;
      expect(tp3.containsKey('snapshot'), isFalse);

      // 二度目は何も書かない
      expect(await firestoreService.backfillTestPieceSnapshots(), 0);
    });
  });
}
