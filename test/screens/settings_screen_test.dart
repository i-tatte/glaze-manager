import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/screens/settings_screen.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockSettingsService mockSettingsService;

  setUp(() {
    mockSettingsService = MockSettingsService();
    // Default stubs
    when(mockSettingsService.gridCrossAxisCount).thenReturn(2);
    when(mockSettingsService.maxGridCrossAxisCount).thenReturn(6);
    when(mockSettingsService.themeMode).thenReturn(ThemeMode.system);
    when(mockSettingsService.addListener(any)).thenReturn(null);
    when(mockSettingsService.removeListener(any)).thenReturn(null);
  });

  Widget createTestableWidget(Widget child) {
    return ChangeNotifierProvider<SettingsService>.value(
      value: mockSettingsService,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('SettingsScreen Widget Tests', () {
    testWidgets('should display all settings sections', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestableWidget(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('表示'), findsOneWidget);
      expect(find.text('データ管理'), findsOneWidget);
      expect(find.text('サポート'), findsOneWidget);
    });

    testWidgets('should display grid count slider', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestableWidget(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Find slider
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      // Drag slider
      await tester.drag(sliderFinder, const Offset(50, 0));
      await tester.pumpAndSettle();

      // Verify setGridCrossAxisCount is called
      verify(mockSettingsService.setGridCrossAxisCount(any)).called(1);
    });
  });
}
