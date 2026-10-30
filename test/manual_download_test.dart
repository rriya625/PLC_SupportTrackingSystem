import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/utils/manual_download.dart';
void main() {
 test('customer gets only the customer PDF', () {
  final m=manualForRole(false);
  expect(m.fileName,'UserManual.pdf');
  expect(m.matches('%PDF-1.7'.codeUnits),isTrue);
  expect(m.matches('<html>error</html>'.codeUnits),isFalse);
 });
 test('employee gets the bundle of both manuals', () {
  final m=manualForRole(true);
  expect(m.fileName,'EmployeeManuals.zip');
  expect(m.matches([80,75,3,4,0]),isTrue);
  expect(m.matches('%PDF-1.7'.codeUnits),isFalse);
 });
}
