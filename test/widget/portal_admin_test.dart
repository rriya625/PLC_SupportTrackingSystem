import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/screens/portal_admin_screen.dart';
import 'package:ticket_tracker_app/utils/messages_api.dart';
class FakeAdminApi extends MessagesApi {
 final calls=<String>[];Map<String,dynamic>? saved;
 @override Future<Map<String,dynamic>> call(String endpoint,{Map<String,dynamic>? body,Map<String,String>? query}) async {
  calls.add(endpoint);
  if(endpoint=='GetPortalUsers') return {'Code':300,'Data':[{'ID':'12819','NAME':'Muru','DEPARTMENT':'PLC','DEBUG_MODE':'T','DO_NOT_LOAD_TICKETS_ON_LOAD':'F'}]};
  if(endpoint=='UpdatePortalUserFlags')saved=body;
  return {'Code':300,'Data':[]};
 }
}
void main(){
 tearDown(()=>Constants.accessLevel='');
 testWidgets('Non-admin cannot load user flags',(tester)async{
  Constants.accessLevel='0';final api=FakeAdminApi();
  await tester.pumpWidget(MaterialApp(home:PortalAdminScreen(api:api)));
  await tester.pumpAndSettle();expect(api.calls,isEmpty);expect(find.text('Access Level 2 is required.'),findsOneWidget);
 });
 testWidgets('Searchable user selector saves only flags for selected user',(tester)async{
  Constants.accessLevel='2';Constants.userID=12819;final api=FakeAdminApi();
  await tester.pumpWidget(MaterialApp(home:PortalAdminScreen(api:api)));
  await tester.pumpAndSettle();
  final selector=tester.widget<DropdownMenu<String>>(find.byType(DropdownMenu<String>));
  expect(selector.enableFilter,isTrue);selector.onSelected!('12819');await tester.pumpAndSettle();
  await tester.tap(find.text('Do Not Load Tickets On Load'));await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Save'));await tester.tap(find.text('Save'));await tester.pumpAndSettle();
  expect(api.saved,{'TargetUserID':12819,'DebugMode':'T','DoNotLoadTicketsOnLoad':'T'});
  expect(Constants.skipInitialTicketLoad,isTrue);
  Constants.doNotLoadTicketsOnLoad='F';
 });
 testWidgets('Audit view loads lookups and waits for Search',(tester)async{
  Constants.accessLevel='2';final api=FakeAdminApi();
  await tester.pumpWidget(MaterialApp(home:PortalAdminScreen(api:api,audit:true)));
  await tester.pumpAndSettle();expect(api.calls,containsAll(['GetPortalUsers','GetPortalAuditTypes']));
  expect(api.calls, isNot(contains('GetPortalAudit')));
  await tester.tap(find.text('Search'));await tester.pumpAndSettle();expect(api.calls,contains('GetPortalAudit'));
 });
}
