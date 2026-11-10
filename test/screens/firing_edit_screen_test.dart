import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/firing_edit_screen.dart';
import 'package:mockito/mockito.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockFirestoreService mockFirestoreService;

  final atmosphere = FiringAtmosphere(
    id: 'a1',
    name: '還元',
    type: FiringAtmosphereType.reduction,
  );
  final profile = FiringProfile(
    id: 'p1',
    name: '本焼き',
    curveData: '60,600\n300,1230',
  );

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    when(
      mockFirestoreService.getFirings(),
    ).thenAnswer((_) => Stream.value(<Firing>[]));
    when(
      mockFirestoreService.getFiringAtmospheres(),
    ).thenAnswer((_) => Stream.value([atmosphere]));
    when(
      mockFirestoreService.getFiringProfiles(),
    ).thenAnswer((_) => Stream.value([profile]));
    when(
      mockFirestoreService.getTestPieces(),
    ).thenAnswer((_) => Stream.value(<TestPiece>[]));
    when(mockFirestoreService.createFiringId()).thenReturn('new-id');
    when(mockFirestoreService.setFiring(any, any)).thenAnswer((_) async {});
    when(mockFirestoreService.updateFiring(any)).thenAnswer((_) async {});
  });

  Widget createTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [
        firestoreServiceProvider.overrideWithValue(mockFirestoreService),
        authStateChangesProvider.overrideWith(
          (ref) => Stream<User?>.value(null),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  /// 編集画面をボタンから開き、pop の戻り値を [onResult] で受け取る
  Widget launcher(Widget screen, void Function(Object?) onResult) {
    return createTestableWidget(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => screen));
              onResult(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  group('FiringEditScreen Widget Tests', () {
    testWidgets('新規作成のフォームを出す', (tester) async {
      await tester.pumpWidget(createTestableWidget(const FiringEditScreen()));
      await tester.pumpAndSettle();

      expect(find.text('焼成回の新規作成'), findsOneWidget);
      expect(find.text('焼成日'), findsOneWidget);
      expect(find.text('窯 (任意)'), findsOneWidget);
      expect(find.text('焼成雰囲気'), findsOneWidget);
      expect(find.text('焼成プロファイル'), findsOneWidget);
      expect(find.byTooltip('削除'), findsNothing);
    });

    testWidgets('新規作成で保存すると、写しを含めて作成し ID を返す', (tester) async {
      Object? result;
      await tester.pumpWidget(
        launcher(const FiringEditScreen(), (r) => result = r),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '窯 (任意)'),
        '電気窯',
      );
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String?>, '焼成雰囲気'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('還元').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String?>, '焼成プロファイル'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('本焼き').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();

      final captured =
          verify(
                mockFirestoreService.setFiring('new-id', captureAny),
              ).captured.single
              as Firing;
      expect(captured.kilnName, '電気窯');
      expect(captured.firedOn.toDate().hour, 12);
      expect(captured.firingAtmosphereId, 'a1');
      expect(captured.atmosphereName, '還元');
      expect(captured.atmosphereType, 'reduction');
      expect(captured.firingProfileId, 'p1');
      expect(captured.profile!.name, '本焼き');
      expect(captured.profile!.curveData, '60,600\n300,1230');
      expect(result, 'new-id');
    });

    testWidgets('プロファイルの選択を変えない編集では、既存の写しを保つ', (tester) async {
      final firing = Firing(
        id: 'f1',
        firedOn: Firing.noonOf(DateTime(2026, 11, 8)),
        firingProfileId: 'p1',
        profile: const FiringProfileSnapshot(name: '本焼き (当時)'),
        createdAt: Timestamp.now(),
      );
      await tester.pumpWidget(
        launcher(FiringEditScreen(firing: firing), (_) {}),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('焼成回の編集'), findsOneWidget);
      expect(find.text('2026/11/8'), findsOneWidget);

      // チャートのプレビューの下にあるので、見えるところまで送ってから入力する
      final coneField = find.widgetWithText(TextFormField, 'コーン (任意)');
      await tester.scrollUntilVisible(
        coneField,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(coneField, 'SK8');
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();

      final captured =
          verify(mockFirestoreService.updateFiring(captureAny)).captured.single
              as Firing;
      expect(captured.id, 'f1');
      expect(captured.cone, 'SK8');
      expect(captured.profile!.name, '本焼き (当時)');
    });

    testWidgets('削除済みの雰囲気・プロファイルを参照していても開ける', (tester) async {
      final firing = Firing(
        id: 'f1',
        firedOn: Firing.noonOf(DateTime(2026, 11, 8)),
        firingAtmosphereId: 'a-deleted',
        firingProfileId: 'p-deleted',
        createdAt: Timestamp.now(),
      );
      await tester.pumpWidget(
        createTestableWidget(FiringEditScreen(firing: firing)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('不明な焼成雰囲気'), findsOneWidget);
      expect(find.text('不明な焼成プロファイル'), findsOneWidget);
    });

    testWidgets('削除の確認で、参照するテストピースの件数を出す', (tester) async {
      final firing = Firing(
        id: 'f1',
        firedOn: Firing.noonOf(DateTime(2026, 11, 8)),
        createdAt: Timestamp.now(),
      );
      when(mockFirestoreService.getTestPieces()).thenAnswer(
        (_) => Stream.value([
          for (final id in ['tp1', 'tp2'])
            TestPiece(
              id: id,
              glazeId: 'g1',
              clayId: 'c1',
              createdAt: Timestamp.now(),
              firingId: 'f1',
            ),
        ]),
      );
      await tester.pumpWidget(
        createTestableWidget(FiringEditScreen(firing: firing)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('削除'));
      await tester.pumpAndSettle();

      expect(find.textContaining('この焼成回は2件のテストピースで使用されています。'), findsOneWidget);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      verifyNever(mockFirestoreService.deleteFiring(any));
    });
  });
}
