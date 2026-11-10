import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/theme/app_colors.dart';
import 'package:glaze_manager/widgets/test_piece_card.dart';
import 'package:mockito/mockito.dart';

class MockFirestoreService extends Mock implements FirestoreService {
  @override
  Future<void> updateViewHistory(String testPieceId) => super.noSuchMethod(
    Invocation.method(#updateViewHistory, [testPieceId]),
    returnValue: Future.value(),
  );

  @override
  Stream<TestPiece> getTestPieceStream(String id) => super.noSuchMethod(
    Invocation.method(#getTestPieceStream, [id]),
    returnValue: Stream<TestPiece>.empty(),
  );

  // 詳細画面がデータプロバイダ経由で参照するリスト系メソッド
  @override
  Stream<List<Glaze>> getGlazes() => Stream.value(<Glaze>[]);

  @override
  Stream<List<Clay>> getClays() => Stream.value(<Clay>[]);

  @override
  Stream<List<FiringProfile>> getFiringProfiles() =>
      Stream.value(<FiringProfile>[]);

  @override
  Stream<List<FiringAtmosphere>> getFiringAtmospheres() =>
      Stream.value(<FiringAtmosphere>[]);

  @override
  Stream<List<app.Material>> getMaterials() => Stream.value(<app.Material>[]);

  @override
  Stream<List<Firing>> getFirings() => Stream.value(<Firing>[]);

  @override
  Stream<List<String>> getTags() => Stream.value(<String>[]);
}

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return createMockImageHttpClient(context);
  }
}

// Helper to create a mock HTTP client that returns an image
HttpClient createMockImageHttpClient(SecurityContext? _) {
  final client = MockHttpClient();
  final request = MockHttpClientRequest();
  final response = MockHttpClientResponse();
  final headers = MockHttpHeaders();

  // Use specific URL to avoid 'any' returning null issue
  when(
    client.getUrl(Uri.parse('http://example.com/image.png')),
  ).thenAnswer((_) async => request);
  when(request.headers).thenReturn(headers);
  when(request.close()).thenAnswer((_) async => response);
  when(response.contentLength).thenReturn(_transparentImage.length);
  when(response.statusCode).thenReturn(HttpStatus.ok);
  when(response.listen(any)).thenAnswer((invocation) {
    final void Function(List<int>) onData = invocation.positionalArguments[0];
    final void Function() onDone = invocation.namedArguments[#onDone];
    final void Function(Object, [StackTrace?])? onError =
        invocation.namedArguments[#onError];
    final bool? cancelOnError = invocation.namedArguments[#cancelOnError];

    return Stream<List<int>>.fromIterable([_transparentImage]).listen(
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  });

  return client;
}

class MockHttpClient extends Mock implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) => super.noSuchMethod(
    Invocation.method(#getUrl, [url]),
    returnValue: Future.value(MockHttpClientRequest()),
  );
}

class MockHttpClientRequest extends Mock implements HttpClientRequest {
  @override
  HttpHeaders get headers => super.noSuchMethod(
    Invocation.getter(#headers),
    returnValue: MockHttpHeaders(),
  );
  @override
  Future<HttpClientResponse> close() => super.noSuchMethod(
    Invocation.method(#close, []),
    returnValue: Future.value(MockHttpClientResponse()),
  );
}

class MockHttpClientResponse extends Mock implements HttpClientResponse {
  @override
  int get contentLength =>
      super.noSuchMethod(Invocation.getter(#contentLength), returnValue: 0);
  @override
  int get statusCode =>
      super.noSuchMethod(Invocation.getter(#statusCode), returnValue: 200);
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => super.noSuchMethod(
    Invocation.method(
      #listen,
      [onData],
      {#onError: onError, #onDone: onDone, #cancelOnError: cancelOnError},
    ),
    returnValue: Stream<List<int>>.empty().listen(null),
  );
}

class MockHttpHeaders extends Mock implements HttpHeaders {}

const List<int> _transparentImage = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = TestHttpOverrides();

  testWidgets('TestPieceCard displays info and handles tap', (
    WidgetTester tester,
  ) async {
    final testPiece = TestPiece(
      id: 'tp1',
      glazeId: 'g1',
      clayId: 'c1',
      imageUrl: 'http://example.com/image.png',
      createdAt: Timestamp.now(),
    );

    final mockFirestoreService = MockFirestoreService();
    // Stub methods needed for navigation
    when(
      mockFirestoreService.updateViewHistory('tp1'),
    ).thenAnswer((_) async => {});
    when(
      mockFirestoreService.getTestPieceStream('tp1'),
    ).thenAnswer((_) => Stream.value(testPiece));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreServiceProvider.overrideWithValue(mockFirestoreService),
          authStateChangesProvider.overrideWith(
            (ref) => Stream<User?>.value(null),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: TestPieceCard(
                testPiece: testPiece,
                glazeName: 'Test Glaze',
                clayName: 'Test Clay',
                firingAtmosphereName: 'Oxidation',
                firingProfileName: 'Standard Profile',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Test Glaze'), findsOneWidget);
    expect(find.text('Test Clay'), findsOneWidget);

    // Tap to navigate
    await tester.tap(find.byType(TestPieceCard));
    // 画面遷移 + データプロバイダのロード完了を待つ。
    // 釉薬が見つからなくても詳細画面は写真を表示するようになり、写真の読み込み
    // 表示が回り続けるので pumpAndSettle ではなく時間を進めて待つ
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Check if navigation happened by looking for title
    expect(find.text('テストピース詳細'), findsOneWidget);
  });

  testWidgets('TestPieceCard displays correct color for oxidation', (
    WidgetTester tester,
  ) async {
    final testPiece = TestPiece(
      id: 'tp1',
      glazeId: 'g1',
      clayId: 'c1',
      createdAt: Timestamp.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 300,
                child: TestPieceCard(
                  testPiece: testPiece,
                  glazeName: 'Test Glaze',
                  clayName: 'Test Clay',
                  firingAtmosphereName: 'Oxidation',
                  firingAtmosphereType: FiringAtmosphereType.oxidation,
                  firingProfileName: 'Standard Profile',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.color, AppColors.oxidationCardLight);
  });

  testWidgets('TestPieceCard displays correct color for reduction', (
    WidgetTester tester,
  ) async {
    final testPiece = TestPiece(
      id: 'tp1',
      glazeId: 'g1',
      clayId: 'c1',
      createdAt: Timestamp.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 300,
                child: TestPieceCard(
                  testPiece: testPiece,
                  glazeName: 'Test Glaze',
                  clayName: 'Test Clay',
                  firingAtmosphereName: 'Reduction',
                  firingAtmosphereType: FiringAtmosphereType.reduction,
                  firingProfileName: 'Standard Profile',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.color, AppColors.reductionCardLight);
  });

  group('評価のラベル', () {
    Widget card(TestPiece testPiece) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 300,
              child: TestPieceCard(
                testPiece: testPiece,
                glazeName: 'Test Glaze',
                clayName: 'Test Clay',
                firingAtmosphereName: '未設定',
                firingProfileName: '未設定',
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('評価があれば画像の右上に「★N」を表示する', (tester) async {
      await tester.pumpWidget(
        card(
          TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
            rating: 4,
          ),
        ),
      );
      expect(find.text('★4'), findsOneWidget);
    });

    testWidgets('未評価なら表示しない', (tester) async {
      await tester.pumpWidget(
        card(
          TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
        ),
      );
      expect(find.textContaining('★'), findsNothing);
    });
  });

  group('選択', () {
    TestPiece plain() => TestPiece(
      id: 'tp1',
      glazeId: 'g1',
      clayId: 'c1',
      createdAt: Timestamp.now(),
    );

    Widget card({
      VoidCallback? onTap,
      VoidCallback? onLongPress,
      bool selected = false,
    }) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 300,
              child: TestPieceCard(
                testPiece: plain(),
                glazeName: 'Test Glaze',
                clayName: 'Test Clay',
                firingAtmosphereName: '未設定',
                firingProfileName: '未設定',
                onTap: onTap,
                onLongPress: onLongPress,
                selected: selected,
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('onTap を渡すと詳細画面へは遷移せず、その動作を呼ぶ', (tester) async {
      var taps = 0;
      await tester.pumpWidget(card(onTap: () => taps++));

      await tester.tap(find.byType(TestPieceCard));
      await tester.pump(const Duration(milliseconds: 500));

      expect(taps, 1);
      expect(find.text('テストピース詳細'), findsNothing);
    });

    testWidgets('長押しで onLongPress を呼ぶ', (tester) async {
      var longPresses = 0;
      await tester.pumpWidget(card(onLongPress: () => longPresses++));

      await tester.longPress(find.byType(TestPieceCard));

      expect(longPresses, 1);
    });

    testWidgets('選択中はチェックを重ね、縁を primary で囲む', (tester) async {
      await tester.pumpWidget(card(selected: true));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      final shape =
          tester.widget<Card>(find.byType(Card)).shape
              as RoundedRectangleBorder;
      final primary = Theme.of(
        tester.element(find.byType(Card)),
      ).colorScheme.primary;
      expect(shape.side.color, primary);
    });

    testWidgets('選択のチェックは画像の右下に置く (左上はアップロード待ちの印)', (tester) async {
      await tester.pumpWidget(card(selected: true));

      final positioned = tester.widget<Positioned>(
        find
            .ancestor(
              of: find.byIcon(Icons.check_circle),
              matching: find.byType(Positioned),
            )
            .first,
      );
      expect(positioned.bottom, 4);
      expect(positioned.right, 4);
      expect(positioned.top, isNull);
      expect(positioned.left, isNull);
    });

    testWidgets('選択中でなければチェックも縁もない', (tester) async {
      await tester.pumpWidget(card());

      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(tester.widget<Card>(find.byType(Card)).shape, isNull);
    });
  });
}
