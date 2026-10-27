import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/screens/view_activity.dart';

void main() {
  testWidgets(
    'Every activity has Documents and populated activities stand out',
    (tester) async {
      Constants.userType = 'CUSTOMER';
      Constants.userID = 20068;
      await tester.pumpWidget(
        MaterialApp(
          home: ViewActivityScreen(
            ticketNumber: '79311',
            shortDescription: 'Attachment test',
            activityLoader: (_) async => [
              {'Number': '1', 'LongDesc': 'First activity', 'EnteredByID': 'WEB', 'ProspectKey': 20068},
              {'Number': '2', 'LongDesc': 'Second activity'},
            ],
            documentLoader: (_) async => [
              {
                'Source': 'ACTIVITY',
                'HistoryNumber': 1,
                'FileName': 'activity-one.png',
              },
              {
                'Source': 'CUSTOMER',
                'HistoryNumber': 0,
                'FileName': 'customer.pdf',
              },
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Documents'), findsNWidgets(2));
      final buttons = tester.widgetList<TextButton>(find.widgetWithText(TextButton, 'Documents')).toList();
      expect(buttons.first.style!.foregroundColor!.resolve({}), const Color(0xFF2E7D32));
      expect(buttons.last.style!.foregroundColor!.resolve({}), const Color(0xFF1565C0));
      await tester.tap(find.widgetWithText(TextButton, 'Documents').first);
      await tester.pumpAndSettle();
      expect(find.text('Activity Documents'), findsOneWidget);
      expect(find.text('activity-one.png'), findsOneWidget);
      expect(find.text('customer.pdf'), findsNothing);
      expect(find.text('Attach Documents'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Documents').last);
      await tester.pumpAndSettle();
      expect(find.text('No documents attached.'), findsOneWidget);
      expect(find.text('Attach Documents'), findsNothing);
    },
  );
}
