import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/widgets/tag_management_widget.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

class MockFirestoreService extends Mock implements FirestoreService {
  @override
  Stream<List<String>> getTags() => super.noSuchMethod(
    Invocation.method(#getTags, []),
    returnValue: Stream<List<String>>.empty(),
  );

  @override
  Future<void> deleteTag(String tag) => super.noSuchMethod(
    Invocation.method(#deleteTag, [tag]),
    returnValue: Future.value(),
  );
}

void main() {
  testWidgets('TagManagementWidget displays tags', (WidgetTester tester) async {
    final mockFirestoreService = MockFirestoreService();
    when(
      mockFirestoreService.getTags(),
    ).thenAnswer((_) => Stream.value(['Tag1', 'Tag2']));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FirestoreService>.value(value: mockFirestoreService),
        ],
        child: const MaterialApp(home: TagManagementWidget()),
      ),
    );

    await tester.pump(); // Build stream builder

    expect(find.text('Tag1'), findsOneWidget);
    expect(find.text('Tag2'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('TagManagementWidget shows empty message', (
    WidgetTester tester,
  ) async {
    final mockFirestoreService = MockFirestoreService();
    when(mockFirestoreService.getTags()).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FirestoreService>.value(value: mockFirestoreService),
        ],
        child: const MaterialApp(home: TagManagementWidget()),
      ),
    );

    await tester.pump();

    expect(find.text('登録されているタグはありません'), findsOneWidget);
  });

  testWidgets('TagManagementWidget deletes tag', (WidgetTester tester) async {
    final mockFirestoreService = MockFirestoreService();
    when(
      mockFirestoreService.getTags(),
    ).thenAnswer((_) => Stream.value(['Tag1']));
    when(mockFirestoreService.deleteTag('Tag1')).thenAnswer((_) async => {});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FirestoreService>.value(value: mockFirestoreService),
        ],
        child: const MaterialApp(home: TagManagementWidget()),
      ),
    );

    await tester.pump();

    // Tap delete button
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Dialog should appear
    expect(find.text('タグの削除'), findsOneWidget);
    expect(
      find.text(
        'タグ「Tag1」を削除しますか？\n\n※この操作は「タグの候補リスト」から削除するだけです。\nすでにこのタグが設定されている釉薬からは削除されません。',
      ),
      findsOneWidget,
    );

    // Confirm delete
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    verify(mockFirestoreService.deleteTag('Tag1')).called(1);
    expect(find.text('タグ「Tag1」を削除しました'), findsOneWidget); // SnackBar
  });
}
