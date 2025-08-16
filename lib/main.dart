import 'package:flutter/material.dart';
import 'constants.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Constants.loadConfig();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Customer Support System',
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}