import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsService Test', () {
    test('loads default values', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      // Wait for loadSettings to complete. Since it's called in constructor and async,
      // we might need to wait a bit or expose a way to await it.
      // However, the service notifies listeners.
      // A better way is to await a small delay or check initial value.
      // Actually _loadSettings is async but called in constructor without await.
      // So initially it will have default value.
      expect(settings.gridCrossAxisCount, 4);
    });

    test('loads saved values', () async {
      SharedPreferences.setMockInitialValues({'gridCrossAxisCount': 6});
      final settings = SettingsService();

      // We need to wait for the async load to finish.
      // Since we can't await the constructor, we can wait for a notification?
      // Or just wait a simplified delay.
      await Future.delayed(Duration(milliseconds: 50));

      expect(settings.gridCrossAxisCount, 6);
    });

    test('setGridCrossAxisCount updates value and prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await Future.delayed(Duration(milliseconds: 10)); // Ensure init is done

      await settings.setGridCrossAxisCount(5);
      expect(settings.gridCrossAxisCount, 5);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('gridCrossAxisCount'), 5);
    });

    test('clamps values', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await Future.delayed(Duration(milliseconds: 10));

      await settings.setGridCrossAxisCount(100); // Too high
      // Max depends on platform. In test environment (likely linux/windows/macos), it might be 20.
      // The service checks defaultTargetPlatform.
      // On 'linux' (which tests might run as), it returns 20.
      expect(settings.gridCrossAxisCount, lessThanOrEqualTo(20));

      await settings.setGridCrossAxisCount(1); // Too low
      expect(settings.gridCrossAxisCount, 2);
    });
  });
}
