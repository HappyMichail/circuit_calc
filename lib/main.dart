import 'package:material_ui/material_ui.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const CircuitCalcApp());
}

class CircuitCalcApp extends StatefulWidget {
  const CircuitCalcApp({super.key});

  @override
  State<CircuitCalcApp> createState() => _CircuitCalcAppState();
}

class _CircuitCalcAppState extends State<CircuitCalcApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CircuitCalc — Рабочая станция ТОЭ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: HomeScreen(
        themeMode: _themeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
