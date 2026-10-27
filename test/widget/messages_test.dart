import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/screens/messages_screen.dart';
import 'package:ticket_tracker_app/utils/messages_api.dart';

class FakeMessages extends MessagesApi {
  final calls = <String>[];
  Map<String, dynamic>? sentBody;
  bool deleted = false;
  Map<String, String>? lastQuery;
  final bool employee;
  FakeMessages(this.employee);
  Map<String, dynamic> get row => {
    'MessageKey': 91,
    'TicketKey': 0,
    'MsgFrom': 'Muru',
    'Message': 'Inbox test message',
    'DateSent': '2026-10-25',
    'Unread': true,
    'CanReply': !deleted,
    'Deleted': deleted,
    'CanDelete': !deleted,
  };
  @override
  Future<Map<String, dynamic>> call(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    calls.add(endpoint);
    if (endpoint == 'SendPortalMessage') sentBody = body;
    if (endpoint == 'GetMessageFilterOptions')
      return {
        'Code': 300,
        'Data': [
          {
            'Code': query?['FilterType'] == 'CUSTOMER' ? 'QBPLC' : 'E:MURU',
            'Name': query?['FilterType'] == 'CUSTOMER'
                ? 'Porter Lee'
                : 'Murugan',
          },
        ],
      };
    if (endpoint == 'GetMessagesByStatus') lastQuery = query;
    if (endpoint == 'GetMessages' || endpoint == 'GetMessagesByStatus')
      return {
        'Code': 300,
        'Data':
            (query?['Status'] == 'ALL' ||
                (query?['Status'] == 'DELETED' ? deleted : !deleted))
            ? [row]
            : [],
        'HasMore': false,
        'UnreadCount': deleted ? 0 : 1,
      };
    if (endpoint == 'ReadPortalMessage')
      return {
        'Code': 300,
        'Data': {...row, 'Unread': false},
      };
    if (endpoint == 'DeletePortalMessage') deleted = true;
    if (endpoint == 'GetMessageRecipients' &&
        query?['RecipientType'] == 'CUSTOMER_LIST')
      return {
        'Code': 300,
        'Data': [
          {'ID': 'QB879', 'Name': 'QB879 - Illinois State Police'},
        ],
      };
    if (endpoint == 'GetMessageRecipients' &&
        query?['RecipientType'] == 'CUSTOMER_CONTACT') {
      lastQuery = query;
      return {
        'Code': 300,
        'Data': [
          {'ID': '20068', 'Name': '20068 - Clifford'},
        ],
      };
    }
    if (endpoint == 'GetMessageRecipients')
      return {
        'Code': 300,
        'Data': [
          {'ID': 'MURU', 'Name': 'Murugan'},
        ],
      };
    return {'Code': 300};
  }

  @override
  Future<List<String>> groups() async => [
    'LIMS Support Group',
    'QA Group: Development',
  ];
}

void main() {
  setUp(() {
    Constants.qbLinkKey = 'QB879';
    Constants.departmentName = 'Illinois State Police';
  });
  testWidgets(
    'Customer agency stays locked and customer can delete own queue entry',
    (tester) async {
      Constants.userType = 'CUSTOMER';
      final api = FakeMessages(false);
      await tester.pumpWidget(MaterialApp(home: MessagesScreen(api: api)));
      await tester.pumpAndSettle();
      final agency = find.widgetWithText(
        OutlinedButton,
        'Customer: Illinois State Police',
      );
      expect(tester.widget<OutlinedButton>(agency).onPressed, isNull);
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(api.lastQuery?['QBLinkKey'], 'QB879');
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Customer: Illinois State Police'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(api.deleted, true);
      expect(find.text('No received messages.'), findsOneWidget);
    },
  );
  testWidgets('Delete from queue keeps message available in Deleted and All', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Constants.userType = 'EMPLOYEE';
    final api = FakeMessages(true);
    await tester.pumpWidget(MaterialApp(home: MessagesScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.deleted, false);
    await tester.tap(find.byTooltip('Delete message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No received messages.'), findsOneWidget);
    await tester.tap(find.text('Status: Current messages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deleted messages').last);
    await tester.pumpAndSettle();
    expect(api.lastQuery?['Status'], 'DELETED');
    expect(find.text('Muru'), findsOneWidget);
    expect(find.byTooltip('Delete message'), findsNothing);
    await tester.tap(find.text('Status: Deleted messages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All messages').last);
    await tester.pumpAndSettle();
    expect(api.lastQuery?['Status'], 'ALL');
    expect(find.text('Muru'), findsOneWidget);
  });
  testWidgets(
    'New message validates and preselects the inbox customer/contact',
    (tester) async {
      Constants.userType = 'EMPLOYEE';
      final api = FakeMessages(true);
      await tester.pumpWidget(
        MaterialApp(
          home: MessageComposeScreen(
            api: api,
            initialCustomer: 'QB879',
            initialSender: 'P:20068',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final selectors = tester
          .widgetList<DropdownMenu<String>>(find.byType(DropdownMenu<String>))
          .toList();
      expect(selectors.first.controller!.text, 'QB879 - Illinois State Police');
      expect(selectors.last.controller!.text, '20068 - Clifford');
      expect(selectors.last.initialSelection, '20068');
      expect(api.lastQuery!['Search'], 'QB879');
    },
  );
  testWidgets(
    'Customer login does not inherit employee-only customer recipients',
    (tester) async {
      Constants.userType = 'CUSTOMER';
      final api = FakeMessages(false);
      await tester.pumpWidget(
        MaterialApp(
          home: MessageComposeScreen(
            api: api,
            initialCustomer: 'QB879',
            initialSender: 'P:20068',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('GetMessageRecipients')));
      expect(find.text('Select customer'), findsNothing);
    },
  );

  testWidgets('Message filters load on demand and Clear restores inbox', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Constants.userType = 'EMPLOYEE';
    final api = FakeMessages(true);
    await tester.pumpWidget(MaterialApp(home: MessagesScreen(api: api)));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('GetMessageFilterOptions')));
    await tester.tap(find.text('Customer: All customers'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('GetMessageFilterOptions'));
    await tester.tap(find.text('Porter Lee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From: Anyone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Murugan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(api.lastQuery?['QBLinkKey'], 'QBPLC');
    expect(api.lastQuery?['SenderID'], 'E:MURU');
    expect(api.lastQuery?['BeforeKey'], '0');
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(api.calls.last, 'GetMessages');
    expect(find.text('Customer: All customers'), findsOneWidget);
    expect(find.text('From: Anyone'), findsOneWidget);
  });

  for (final size in [
    const Size(1440, 900),
    const Size(390, 844),
    const Size(320, 568),
  ]) {
    testWidgets('Inbox and customer reply at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Constants.userType = 'CUSTOMER';
      final api = FakeMessages(false);
      await tester.pumpWidget(MaterialApp(home: MessagesScreen(api: api)));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Muru')).style?.fontWeight,
        FontWeight.bold,
      );
      await tester.tap(find.text('Muru'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('ReadPortalMessage'));
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reply to: Muru'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Employee removal requires confirmation', (tester) async {
    Constants.userType = 'EMPLOYEE';
    final api = FakeMessages(true);
    await tester.pumpWidget(MaterialApp(home: MessagesScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Muru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('DeletePortalMessage')));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('DeletePortalMessage')));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('DeletePortalMessage'));
    expect(find.text('No received messages.'), findsOneWidget);
  });
  testWidgets('Customer compose uses existing groups and optional ticket', (
    tester,
  ) async {
    Constants.userType = 'CUSTOMER';
    await tester.pumpWidget(
      MaterialApp(home: MessageComposeScreen(api: FakeMessages(false))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recipient type'), findsNothing);
    expect(find.text('Ticket number (optional)'), findsOneWidget);
    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    expect(find.text('QA Group: Development'), findsWidgets);
  });
  testWidgets(
    'Employee selection loads recipients without a separate search step',
    (tester) async {
      Constants.userType = 'EMPLOYEE';
      final api = FakeMessages(true);
      await tester.pumpWidget(
        MaterialApp(home: MessageComposeScreen(api: api)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Employee'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('GetMessageRecipients'));
      expect(find.text('Find recipients'), findsNothing);
      expect(find.byType(DropdownMenu<String>), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Returning from message details refreshes inbox', (tester) async {
    Constants.userType = 'EMPLOYEE';
    final api = FakeMessages(true);
    await tester.pumpWidget(MaterialApp(home: MessagesScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Muru'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(api.calls.where((e) => e == 'GetMessages').length, 2);
  });
  testWidgets('Customer compose searches customer then its contacts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Constants.userType = 'EMPLOYEE';
    final api = FakeMessages(true);
    await tester.pumpWidget(MaterialApp(home: MessageComposeScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer'));
    await tester.pumpAndSettle();
    final customerField = find.descendant(
      of: find.byType(DropdownMenu<String>).first,
      matching: find.byType(TextField),
    );
    await tester.tap(customerField);
    await tester.enterText(customerField, 'QB879');
    await tester.pumpAndSettle();
    await tester.tap(find.text('QB879 - Illinois State Police').last);
    await tester.pumpAndSettle();
    expect(api.lastQuery, {
      'RecipientType': 'CUSTOMER_CONTACT',
      'Search': 'QB879',
    });
    final contactField = find.descendant(
      of: find.byType(DropdownMenu<String>).last,
      matching: find.byType(TextField),
    );
    await tester.tap(contactField);
    await tester.enterText(contactField, 'Cliff');
    await tester.pumpAndSettle();
    await tester.tap(find.text('20068 - Clifford').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Compose test');
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(api.sentBody?['RecipientID'], '20068');
    expect(api.sentBody?['RecipientType'], 'CUSTOMER');
  });
}
