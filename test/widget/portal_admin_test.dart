import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/screens/portal_admin_screen.dart';
import 'package:ticket_tracker_app/utils/messages_api.dart';

class FakeAdminApi extends MessagesApi {
  final calls = <String>[];
  Map<String, dynamic>? saved;
  @override
  Future<Map<String, dynamic>> call(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    calls.add(endpoint);
    if (endpoint == 'GetPortalCustomers')
      return {
        'Code': 300,
        'Data': [
          {'CODE': 'QBPLC', 'NAME': 'Porter Lee'},
        ],
      };
    if (endpoint == 'GetPortalUsers' || endpoint == 'GetPortalContacts')
      return {
        'Code': 300,
        'Data': [
          {
            'ID': '12819',
            'NAME': 'Muru',
            'DEPARTMENT': 'PLC',
            'USER_TYPE': 'EMPLOYEE',
            'ALLOW_DOCUMENT_DELETE': 'T',
            'ACCESS_LEVEL': '2',
            'ACCOUNT_DISABLED': 'F',
            'WEB_VIEW_ALL_DEPT_TICKETS': 'F',
            'DEBUG_MODE': 'T',
            'DO_NOT_LOAD_TICKETS_ON_LOAD': 'F',
          },
        ],
      };
    if (endpoint == 'UpdatePortalSettings') saved = body;
    return {'Code': 300, 'Data': []};
  }
}

void main() {
  setUp(() => Constants.userType = "EMPLOYEE");
  tearDown(() => Constants.accessLevel = '');
  testWidgets('Non-admin cannot load user flags', (tester) async {
    Constants.accessLevel = '0';
    final api = FakeAdminApi();
    await tester.pumpWidget(MaterialApp(home: PortalAdminScreen(api: api)));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    expect(find.text('Access Level 2 is required.'), findsOneWidget);
  });
  testWidgets('Searchable user selector saves only flags for selected user', (
    tester,
  ) async {
    Constants.accessLevel = '2';
    Constants.userID = 12819;
    final api = FakeAdminApi();
    await tester.pumpWidget(MaterialApp(home: PortalAdminScreen(api: api)));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('GetPortalContacts')));
    expect(api.calls, isEmpty);
    await tester.tap(find.byType(DropdownMenu<String>).first);
    await tester.pumpAndSettle();
    expect(api.calls, contains('GetPortalCustomers'));
    final customer = tester.widget<DropdownMenu<String>>(
      find.byType(DropdownMenu<String>).first,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    customer.onSelected!('QBPLC');
    await tester.pumpAndSettle();
    expect(api.calls, contains('GetPortalContacts'));
    final selector = tester.widget<DropdownMenu<String>>(
      find.byType(DropdownMenu<String>).last,
    );
    expect(selector.enableFilter, isTrue);
    selector.onSelected!('12819');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Wait for Search before loading tickets'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Wait for Search before loading tickets'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.saved, {
      'TargetUserID': 12819,
      'AccessLevel': 2,
      'AllowDocumentDelete': 'T',
      'WebViewAllDeptTickets': 'F',
      'AccountDisabled': 'F',
      'DebugMode': 'T',
      'DoNotLoadTicketsOnLoad': 'T',
    });
    expect(Constants.skipInitialTicketLoad, isTrue);
    Constants.doNotLoadTicketsOnLoad = 'F';
  });
  for (final audit in [false, true]) {
    testWidgets('Customer is locked on ${audit ? "audit" : "flags"}', (
      tester,
    ) async {
      Constants.userType = 'CUSTOMER';
      Constants.accessLevel = '2';
      final api = FakeAdminApi();
      await tester.pumpWidget(
        MaterialApp(
          home: PortalAdminScreen(api: api, audit: audit),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        api.calls,
        containsAll(['GetPortalCustomers', 'GetPortalContacts']),
      );
      final picker = tester.widget<DropdownMenu<String>>(
        find.byType(DropdownMenu<String>).first,
      );
      expect(picker.enabled, isFalse);
      expect(find.text('All customers'), findsNothing);
      expect(
        tester
            .widget<DropdownMenu<String>>(
              find.byType(DropdownMenu<String>).at(1),
            )
            .enabled,
        isTrue,
      );
    });
  }
  testWidgets('Audit view loads lookups and waits for Search', (tester) async {
    Constants.accessLevel = '2';
    final api = FakeAdminApi();
    await tester.pumpWidget(
      MaterialApp(home: PortalAdminScreen(api: api, audit: true)),
    );
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    await tester.tap(find.byType(DropdownMenu<String>).last);
    await tester.pumpAndSettle();
    expect(api.calls, contains('GetPortalAuditTypes'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All customers'));
    await tester.pumpAndSettle();
    final customerField = find.descendant(
      of: find.byType(DropdownMenu<String>).first,
      matching: find.byType(TextField),
    );
    await tester.tap(customerField);
    await tester.enterText(customerField, 'QBPLC');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(customerField).controller!.text, 'QBPLC');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(api.calls, isNot(contains('GetPortalCustomerAudit')));
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('GetPortalCustomerAudit'));
  });
}
