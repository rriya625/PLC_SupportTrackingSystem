import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/utils/messages_api.dart';
import 'package:ticket_tracker_app/screens/work_tickets_screen.dart';

class TestApi extends MessagesApi {
  final response = Completer<Map<String, dynamic>>();
  Map<String, String>? sent;
  @override
  Future<Map<String, dynamic>> call(String endpoint, {Map<String, dynamic>? body, Map<String, String>? query}) {
    expect(endpoint, 'GetWorkTickets');
    sent = query;
    return response.future;
  }
}
void main() {
  const query = {'FromDate':'2026-11-02','ToDate':'2026-11-08','GroupName':'ADMIN','Scope':'CELL','ActivityType':'CORR','EmployeeID':'MURU'};
  testWidgets('Loading, matching tickets and selection filters', (tester) async {
    final api = TestApi();
    await tester.pumpWidget(MaterialApp(home: WorkTicketsScreen(query: query, api: api)));
    expect(find.text('Loading matching tickets...'), findsOneWidget);
    expect(api.sent, query);
    api.response.complete({'Data':[
      {'TicketKey':'111','ShortDesc':'First ticket','QBLinkKey':'QB879','ActivityCount':3},
      {'TicketKey':'112','ShortDesc':'Second ticket','QBLinkKey':'QB879','ActivityCount':1},
    ]});
    await tester.pumpAndSettle();
    expect(find.text('#111 · First ticket'), findsOneWidget);
    expect(find.text('QB879 · 3 matching activities'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('No authorized tickets explains why', (tester) async {
    final api = TestApi();
    await tester.pumpWidget(MaterialApp(home: WorkTicketsScreen(query: query, api: api)));
    api.response.complete({'Data':[]});
    await tester.pumpAndSettle();
    expect(find.text('No matching tickets are available with your ticket permissions.'), findsOneWidget);
    expect(tester.getTopLeft(find.text('No matching tickets are available with your ticket permissions.')).dy, lessThan(140));
  });
}
