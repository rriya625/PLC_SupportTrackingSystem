import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/screens/view_activity.dart';

void main() {
  testWidgets(
    'Attachment button appears only for activity with documents and opens its own list',
    (tester) async {
      Constants.userType = 'CUSTOMER';
      await tester.pumpWidget(
        MaterialApp(
          home: ViewActivityScreen(
            ticketNumber: '79311',
            shortDescription: 'Attachment test',
            activityLoader: (_) async => [
              {'Number': '1', 'LongDesc': 'First activity'},
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
      expect(find.byTooltip('Activity documents'), findsOneWidget);
      await tester.tap(find.byTooltip('Activity documents'));
      await tester.pumpAndSettle();
      expect(find.text('Activity #1 documents'), findsOneWidget);
      expect(find.text('activity-one.png'), findsOneWidget);
      expect(find.text('customer.pdf'), findsNothing);
    },
  );
}
