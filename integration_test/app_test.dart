import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ticket_tracker_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full login flow navigates to HomeScreen', (WidgetTester tester) async {
    // Start the app
    app.main();
    await tester.pumpAndSettle();

    // Enter User ID
    final userIdField = find.widgetWithText(TextField, 'User ID:');
    await tester.enterText(userIdField, '12819');

    // Enter Password
    final passwordField = find.widgetWithText(TextField, 'Password:');
    await tester.enterText(passwordField, '6779');

    // Tap Login button
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ✅ Expect HomeScreen to load
    expect(find.text('Porter Lee Corporation'), findsNothing);
    expect(find.text('Home'), findsWidgets); // Adjust text to something unique in HomeScreen
  });
}