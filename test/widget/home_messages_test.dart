import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/screens/home_screen.dart';
import 'package:ticket_tracker_app/utils/messages_api.dart';

class UnreadApi extends MessagesApi {
  @override
  Future<Map<String, dynamic>> call(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async => {'Code': 300, 'Data': [], 'UnreadCount': 3};
}

void main() {
  testWidgets('Messages follows create ticket and highlights unread messages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(messagesApi: UnreadApi())),
    );
    await tester.pumpAndSettle();
    final message = find.text('Messages');
    expect(
      tester.getTopLeft(message).dy,
      greaterThan(tester.getTopLeft(find.text('Create New Ticket')).dy),
    );
    expect(tester.widget<Text>(message).style?.fontWeight, FontWeight.bold);
    expect(tester.widget<Text>(message).style?.color, Colors.red[900]);
  });
  testWidgets('Desktop support call displays phone number', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(messagesApi: UnreadApi())),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Call Support'));
    await tester.tap(find.text('Call Support'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(847) 985-2060'), findsOneWidget);
    expect(find.text('Copy number'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
