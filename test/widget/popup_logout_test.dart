import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/widgets/portal_app_bar.dart';

void main() {
  testWidgets('Logout stays on pages and is absent from dialogs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              appBar: PortalAppBar(title: const Text('Page')),
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: SizedBox(
                      width: 400,
                      height: 300,
                      child: Scaffold(
                        appBar: PortalAppBar(title: const Text('Popup')),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    expect(find.byTooltip('Logout'), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byTooltip('Logout'),
      ),
      findsNothing,
    );
  });
}
