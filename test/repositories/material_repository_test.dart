import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/repositories/material_repository.dart';
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
  late MaterialRepository repository;
  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    when(mockAuth.currentUser).thenReturn(MockUser());
    repository = MaterialRepository(db: fakeDb, auth: mockAuth);
  });

  group('MaterialRepository', () {
    test('findOrCreate creates only missing materials and returns their names',
        () async {
      await repository.add(
        Material(
          name: '長石',
          order: 0,
          components: {},
          category: MaterialCategory.base,
        ),
      );

      final created = await repository.findOrCreate(
        ['長石', '珪石', '珪石', ''],
        category: MaterialCategory.base,
      );

      // 既存(長石)・重複・空文字は除外され、珪石だけが新規作成される
      expect(created, ['珪石']);

      final all = await repository.getAll();
      expect(all.map((m) => m.name).toSet(), {'長石', '珪石'});
    });

    test('findOrCreate assigns the given category', () async {
      await repository.findOrCreate(
        ['弁柄'],
        category: MaterialCategory.pigment,
      );

      final all = await repository.getAll();
      expect(all.single.category, MaterialCategory.pigment);
    });

    test('getAll returns empty list when not logged in', () async {
      when(mockAuth.currentUser).thenReturn(null);
      expect(await repository.getAll(), isEmpty);
    });

    test('add throws when not logged in', () async {
      when(mockAuth.currentUser).thenReturn(null);
      expect(
        () => repository.add(
          Material(
            name: 'x',
            order: 0,
            components: {},
            category: MaterialCategory.base,
          ),
        ),
        throwsException,
      );
    });

    test('getIdByName resolves id and returns null for unknown name',
        () async {
      await repository.add(
        Material(
          name: '長石',
          order: 0,
          components: {},
          category: MaterialCategory.base,
        ),
      );

      final id = await repository.getIdByName('長石');
      expect(id, isNotNull);
      expect(await repository.getIdByName('存在しない'), isNull);
    });
  });
}
