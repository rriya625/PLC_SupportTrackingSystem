import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/screens/view_tickets_screen.dart';

void main() {
  testWidgets('Ticket spinner covers lookup loading and starts on Search', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    Constants.userType = 'EMPLOYEE';
    Constants.userID = 12819;
    Constants.qbLinkKey = 'QBPLC';
    Constants.debugMode = 'N';
    Constants.doNotLoadTicketsOnLoad = 'F';
    addTearDown(() => Constants.doNotLoadTicketsOnLoad = 'F');
    Constants.baseUrlData = 'http://example.test/api/';
    Constants.accessToken = 'test-token';
    Constants.tokenExpiration =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    final lookups = Completer<void>();
    final firstSearch = Completer<void>();
    final nextSearch = Completer<void>();
    var searches = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('GetTickets')) {
        searches++;
        await (searches == 1 ? firstSearch.future : nextSearch.future);
        return http.Response(jsonEncode({'Code': 300, 'Data': []}), 200);
      }
      await lookups.future;
      return http.Response('[]', 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ViewTicketsScreen()));
      expect(find.text('Loading tickets...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(searches, 0);
      lookups.complete();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(searches, 1);
      expect(find.text('Loading tickets...'), findsOneWidget);
      firstSearch.complete();
      await tester.pumpAndSettle();
      expect(find.text('Loading tickets...'), findsNothing);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Search'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Search'));
      await tester.pump();
      expect(find.text('Loading tickets...'), findsOneWidget);
      expect(searches, 2);
      nextSearch.complete();
      await tester.pumpAndSettle();
      expect(find.text('Loading tickets...'), findsNothing);
      expect(find.text('Total Tickets: 0'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      for (final flag in ['', 'F', 'T']) {
        await tester.pumpWidget(const SizedBox());
        Constants.doNotLoadTicketsOnLoad = flag;
        searches = 0;
        await tester.pumpWidget(const MaterialApp(home: ViewTicketsScreen()));
        await tester.pumpAndSettle();
        expect(searches, flag == 'T' ? 0 : 1, reason: 'flag=$flag');
        if (flag == 'T') {
          expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
          await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Search'));
          await tester.tap(find.widgetWithText(ElevatedButton, 'Search'));
          await tester.pumpAndSettle();
          expect(searches, 1);
          expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
        }
      }
    }, () => client);
  });
}
