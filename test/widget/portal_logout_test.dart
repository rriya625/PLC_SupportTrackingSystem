import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/widgets/portal_app_bar.dart';
import 'package:ticket_tracker_app/screens/login_screen.dart';

void main() {
  testWidgets('Logout is last on narrow headers and clears session and routes', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Constants.userID = 12819;
    Constants.accessToken = 'test-token';
    Constants.userPassword = 'test-password';
    Constants.userType = 'EMPLOYEE';
    Constants.debugMode = 'T';
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      appBar: PortalAppBar(title: const Text('Documents'), actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
      ]),
    )));
    expect(tester.getCenter(find.byIcon(Icons.logout)).dx,
      greaterThan(tester.getCenter(find.byIcon(Icons.refresh)).dx));
    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(Constants.accessToken, isNull);
    expect(Constants.userID, 0);
    expect(Constants.userPassword, isEmpty);
    expect(Constants.isEmployee, isFalse);
    expect(Constants.isDebugModeEnabled, isFalse);
    expect(Navigator.of(tester.element(find.byType(LoginScreen))).canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
