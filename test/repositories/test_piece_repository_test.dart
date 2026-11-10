import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/repositories/test_piece_repository.dart';
import 'package:mockito/mockito.dart';

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
  late TestPieceRepository repository;
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    final mockAuth = MockFirebaseAuth();
    when(mockAuth.currentUser).thenReturn(MockUser());
    repository = TestPieceRepository(db: fakeDb, auth: mockAuth);
  });

  test('updateFieldsBatch は指定したフィールドだけを、区切りを跨いで更新する', () async {
    final collection = fakeDb
        .collection('users')
        .doc('test_uid')
        .collection('test_pieces');
    for (var i = 0; i < 5; i++) {
      await collection.doc('tp$i').set({'note': 'n$i', 'imageUrl': 'u$i'});
    }

    await repository.updateFieldsBatch({
      for (var i = 0; i < 5; i++)
        'tp$i': {
          'snapshot': {'source': 'backfilled'},
        },
    }, chunkSize: 2);

    for (var i = 0; i < 5; i++) {
      final data = (await collection.doc('tp$i').get()).data()!;
      expect(data['snapshot'], {'source': 'backfilled'});
      // ほかのフィールドには触れない
      expect(data['note'], 'n$i');
      expect(data['imageUrl'], 'u$i');
    }
  });
}
