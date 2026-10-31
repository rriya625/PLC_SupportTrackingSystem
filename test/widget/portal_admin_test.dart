import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/screens/portal_admin_screen.dart';
import 'package:ticket_tracker_app/utils/messages_api.dart';

class FakeAdminApi extends MessagesApi {
  final String? userAccess;
  FakeAdminApi({this.userAccess = '2'});
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
            'ACCESS_LEVEL': userAccess,
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
  testWidgets('User Flags selects the signed-in account and loads its flags', (tester) async {
    Constants.accessLevel = '2';
    Constants.userID = 12819;
    Constants.qbLinkKey = 'QBPLC';
    final api = FakeAdminApi();
    await tester.pumpWidget(MaterialApp(home: PortalAdminScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('12819 - Muru - PLC'), findsOneWidget);
    expect(api.calls, contains('GetPortalContacts'));
    expect(api.saved, isNull);
    Constants.qbLinkKey = '';
  });
  for (final level in <String?>[null, '', '0', '1']) {
    testWidgets('Portal User is selected for access $level', (tester) async {
      Constants.accessLevel = '2';
      Constants.userID = 12819;
      Constants.qbLinkKey = 'QBPLC';
      final api = FakeAdminApi(userAccess: level);
      await tester.pumpWidget(MaterialApp(home: PortalAdminScreen(api: api)));
      await tester.pumpAndSettle();
      final field = tester.widget<DropdownButtonFormField<int>>(find.byType(DropdownButtonFormField<int>));
      expect(field.initialValue, 1);
      expect(find.text('Portal User'), findsWidgets);
      expect(find.text('0'), findsNothing);
      expect(api.saved, isNull);
      Constants.qbLinkKey = '';
    });
  }
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
    expect(api.calls, contains('GetPortalCustomers'));
    await tester.tap(find.byKey(const ValueKey('customerLookup')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('GetPortalCustomers'));
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'QBPLC',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('QBPLC - Porter Lee'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('GetPortalContacts'));
    await tester.tap(find.byKey(const ValueKey('contactLookup')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '12819',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('12819 - Muru - PLC'));
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
      Constants.qbLinkKey = 'QBPLC';
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
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('customerLookup')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('All customers'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('contactLookup')))
            .onPressed,
        isNotNull,
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
    await tester.tap(find.byKey(const ValueKey('activityLookup')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('GetPortalAuditTypes'));
    await tester.tap(find.text('All activities').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('All customers'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customerLookup')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'QBPLC',
    );
    await tester.pumpAndSettle();
    expect(find.text('QBPLC - Porter Lee'), findsOneWidget);
    await tester.tap(find.text('QBPLC - Porter Lee'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customerLookup')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'no match',
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('QBPLC - Porter Lee'),
      ),
      findsNothing,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Close'),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('GetPortalCustomerAudit')));
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('GetPortalCustomerAudit'));
  });
}
