import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/screens/messages_screen.dart';
import 'package:ticket_tracker_app/utils/messages_api.dart';

class FakeMessages extends MessagesApi {
  final calls = <String>[];
  final bool employee;
  FakeMessages(this.employee);
  Map<String, dynamic> get row => {'MessageKey': 91, 'TicketKey': 0, 'MsgFrom': 'Muru', 'Message': 'Inbox test message', 'DateSent': '2026-10-25', 'Unread': true, 'CanReply': true, 'CanDelete': employee};
  @override
  Future<Map<String, dynamic>> call(String endpoint, {Map<String, dynamic>? body, Map<String, String>? query}) async {
    calls.add(endpoint);
    if (endpoint == 'GetMessages') return {'Code': 300, 'Data': [row], 'HasMore': false};
    if (endpoint == 'ReadPortalMessage') return {'Code': 300, 'Data': {...row, 'Unread': false}};
    return {'Code': 300};
  }
  @override
  Future<List<String>> groups() async => ['LIMS Support Group', 'QA Group: Development'];
}

void main() {
  for (final size in [const Size(1440, 900), const Size(390, 844)]) {
    testWidgets('Inbox and customer reply at $size', (tester) async {
      tester.view.physicalSize = size; tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      Constants.userType = 'CUSTOMER';
      final api = FakeMessages(false);
      await tester.pumpWidget(MaterialApp(home: MessagesScreen(api: api))); await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('Muru')).style?.fontWeight, FontWeight.bold);
      await tester.tap(find.text('Muru')); await tester.pumpAndSettle();
      expect(api.calls, contains('ReadPortalMessage')); expect(find.text('Delete'), findsNothing);
      await tester.tap(find.text('Reply')); await tester.pumpAndSettle();
      expect(find.textContaining('Reply to: Muru'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Employee removal requires confirmation', (tester) async {
    Constants.userType = 'EMPLOYEE'; final api = FakeMessages(true);
    await tester.pumpWidget(MaterialApp(home: MessagesScreen(api: api))); await tester.pumpAndSettle();
    await tester.tap(find.text('Muru')); await tester.pumpAndSettle();
    await tester.tap(find.text('Delete')); await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('DeletePortalMessage')));
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('DeletePortalMessage')));
    await tester.tap(find.text('Delete')); await tester.pumpAndSettle();
    await tester.tap(find.text('Remove')); await tester.pumpAndSettle();
    expect(api.calls, contains('DeletePortalMessage')); expect(find.text('No received messages.'), findsOneWidget);
  });
  testWidgets('Customer compose uses existing groups and optional ticket', (tester) async {
    Constants.userType = 'CUSTOMER';
    await tester.pumpWidget(MaterialApp(home: MessageComposeScreen(api: FakeMessages(false)))); await tester.pumpAndSettle();
    expect(find.text('Recipient type'), findsNothing); expect(find.text('Ticket number (optional)'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    expect(find.text('QA Group: Development'), findsWidgets);
  });
}
