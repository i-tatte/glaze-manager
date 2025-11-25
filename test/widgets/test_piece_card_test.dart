import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/widgets/test_piece_card.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

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
      MultiProvider(
        providers: [
          Provider<FirestoreService>.value(value: mockFirestoreService),
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
    await tester.pump(); // Start navigation
    await tester.pump(); // Build next screen

    // Check if navigation happened by looking for title
    expect(find.text('テストピース詳細'), findsOneWidget);
  });
}
