import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/screens/login_screen.dart';

void main() {
  testWidgets('Login screen has username and password fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(),
      ),
    );

    // Check for username + password (2 TextFields)
    expect(find.byType(TextField), findsNWidgets(2));

    // Check for Login button text
    expect(find.text('Login'), findsOneWidget);
  });
}