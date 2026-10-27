import 'package:flutter/material.dart';
import 'constants.dart';
import 'screens/login_screen.dart';
import 'utils/spinner_helper.dart'; // ⬅️ Add this import to access rootNavigatorKey
//import 'utils/log_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Constants.loadConfig();
  //await LogHelper.init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Customer Support System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue).copyWith(
          primary: const Color(0xFF1565C0),
          secondary: const Color(0xFF1565C0),
          tertiary: const Color(0xFF1565C0),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.lightBlueAccent,
            foregroundColor: Colors.black,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlueAccent,
            foregroundColor: Colors.black,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF1565C0)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1565C0)),
        ),
      ),
      navigatorKey: rootNavigatorKey, // ✅ This enables global dialog access
      home: LoginScreen(),
    );
  }
}
