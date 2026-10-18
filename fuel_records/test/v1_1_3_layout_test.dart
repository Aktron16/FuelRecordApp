import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuel_records/services/fuel_app_state.dart';
import 'package:fuel_records/widgets/gemini_fallback_card.dart';
import 'package:fuel_records/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Version 1.1.3 Layout & Responsiveness Tests', () {
    testWidgets('GeminiFallbackCard renders without RenderFlex overflow at 317px width', (tester) async {
      // Set physical size to a narrow 317px width (the exact boundary where 10px overflow occurred)
      tester.view.physicalSize = const Size(317, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterErrorDetails? captured;
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        captured = details;
        prevOnError?.call(details);
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GeminiFallbackCard(
                onParseCsv: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      FlutterError.onError = prevOnError;

      if (captured != null) {
        debugPrint('CAPTURED_EX: ${captured!.summary}');
        for (final item in captured!.informationCollector?.call() ?? []) {
          debugPrint('COLLECTOR: $item');
        }
      }

      // Ensure Step 1 and Step 2 elements exist and rendered cleanly
      expect(find.text('Step 2: Paste Cleaned Data'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Copy & Open Gemini'), findsOneWidget);
      expect(captured, isNull);
    });

    testWidgets('SettingsScreen dropdowns render without RenderFlex overflow at 320px width', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = Directory.systemTemp.createTempSync('fuel_v113_settings_');
      final appState = FuelAppState(customStorageDir: tempDir);
      await appState.loadFromStorage();

      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      FlutterErrorDetails? settingsCaptured;
      final prevOnError2 = FlutterError.onError;
      FlutterError.onError = (details) {
        settingsCaptured = details;
        prevOnError2?.call(details);
      };

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(appState: appState),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to reveal the Units card and verify Default Fuel Efficiency dropdown renders without error
      await tester.scrollUntilVisible(
        find.text('Default Fuel Efficiency'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      FlutterError.onError = prevOnError2;

      if (settingsCaptured != null) {
        debugPrint('SETTINGS_EX: ${settingsCaptured!.summary}');
        for (final item in settingsCaptured!.informationCollector?.call() ?? []) {
          debugPrint('SETTINGS_COLLECTOR: $item');
        }
      }

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Default Fuel Efficiency'), findsOneWidget);
      expect(settingsCaptured, isNull);
    });
  });
}
