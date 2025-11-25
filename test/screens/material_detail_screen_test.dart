import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/screens/material_detail_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

// Manual mock
class ManualMockFirestoreService implements FirestoreService {
  final StreamController<app.Material> controller =
      StreamController<app.Material>.broadcast();

  @override
  Stream<app.Material> getMaterialStream(String id) {
    return controller.stream;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ManualMockFirestoreService mockFirestoreService;

  setUp(() {
    mockFirestoreService = ManualMockFirestoreService();
  });

  tearDown(() {
    mockFirestoreService.controller.close();
  });

  Widget createTestableWidget(Widget child) {
    return Provider<FirestoreService>(
      create: (_) => mockFirestoreService,
      child: MaterialApp(home: child),
    );
  }

  group('MaterialDetailScreen Widget Tests', () {
    testWidgets('should display material details', (WidgetTester tester) async {
      final material = app.Material(
        id: 'm1',
        name: 'Test Material',
        order: 1,
        category: app.MaterialCategory.base,
        components: {'SiO2': 60.0, 'Al2O3': 20.0},
      );

      // Set screen size to avoid overflow
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestableWidget(MaterialDetailScreen(material: material)),
      );

      // Initial state should be loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Emit value
      mockFirestoreService.controller.add(material);
      await tester.pump(); // Rebuild with data

      if (tester.takeException() != null) {
        debugPrint('Exception after pump: ${tester.takeException()}');
      }

      expect(find.text('Test Material'), findsOneWidget);
      expect(find.text('母剤'), findsOneWidget);
      expect(find.text('化学成分'), findsOneWidget);
      expect(find.text('SiO2'), findsOneWidget);
      expect(find.text('60.0'), findsOneWidget);
      expect(find.text('Al2O3'), findsOneWidget);
      expect(find.text('20.0'), findsOneWidget);
    });
  });
}
