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
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Customer Support System',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey, // ✅ This enables global dialog access
      home: LoginScreen(),
    );
  }
}