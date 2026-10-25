import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/screens/home_screen.dart';
void main() {
  for (final size in [const Size(1440, 900), const Size(390, 844)]) {
    testWidgets('diagnostic controls fit '+size.toString(), (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Constants.debugMode = 'T';
      Constants.contactName = 'Development Test';
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();
      final button = find.text('Download Diagnostic Log');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Most Recent'), findsOneWidget);
      expect(find.text('Choose Day'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  }
}
