import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/fuel_app_state.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final appState = FuelAppState();

  runApp(FuelRecordApp(appState: appState));
}

class FuelRecordApp extends StatefulWidget {
  final FuelAppState appState;

  const FuelRecordApp({super.key, required this.appState});

  @override
  State<FuelRecordApp> createState() => _FuelRecordAppState();
}

class _FuelRecordAppState extends State<FuelRecordApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.appState.checkAndSyncMonthlyFuelPrices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Fuel Metrics',
          debugShowCheckedModeBanner: false,
          themeMode: widget.appState.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: widget.appState.isLoading
              ? const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : HomeScreen(appState: widget.appState),
        );
      },
    );
  }
}
