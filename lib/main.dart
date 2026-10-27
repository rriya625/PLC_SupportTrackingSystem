import 'package:flutter/material.dart';
import 'constants.dart';
import 'widgets/portal_scroll_behavior.dart';
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
      scrollBehavior: const PortalScrollBehavior(),
      theme: ThemeData(
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF1565C0),
        ),
        dialogTheme: const DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        scrollbarTheme: const ScrollbarThemeData(
          thumbVisibility: WidgetStatePropertyAll(true),
          trackVisibility: WidgetStatePropertyAll(true),
          thickness: WidgetStatePropertyAll(10),
          thumbColor: WidgetStatePropertyAll(Color(0xFF1565C0)),
          trackColor: WidgetStatePropertyAll(Color(0xFFE3F2FD)),
          trackBorderColor: WidgetStatePropertyAll(Color(0xFF90CAF9)),
          radius: Radius.circular(5),
        ),
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
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1565C0),
          ),
        ),
      ),
      navigatorKey: rootNavigatorKey, // ✅ This enables global dialog access
      home: LoginScreen(),
    );
  }
}
