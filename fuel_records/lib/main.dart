import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/fuel_app_state.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final appState = FuelAppState();

  runApp(FuelRecordApp(appState: appState));
}

class FuelRecordApp extends StatelessWidget {
  final FuelAppState appState;

  const FuelRecordApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (appState.isLoading) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        return MaterialApp(
          title: 'Fuel Metrics',
          debugShowCheckedModeBanner: false,
          themeMode: appState.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E88E5),
              brightness: Brightness.light,
              surface: const Color(0xFFF8F9FD),
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F6FB),
            cardTheme: const CardThemeData(
              color: Colors.white,
              elevation: 0,
            ),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: false,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E88E5),
              brightness: Brightness.dark,
              surface: const Color(0xFF161620),
            ),
            scaffoldBackgroundColor: const Color(0xFF101018),
            cardTheme: const CardThemeData(
              color: Color(0xFF1A1A26),
              elevation: 0,
            ),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: false,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          home: HomeScreen(appState: appState),
        );
      },
    );
  }
}
