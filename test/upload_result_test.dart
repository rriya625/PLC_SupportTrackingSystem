import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/utils/upload_result.dart';
void main() {
 test('requires service confirmation', () {
  expect(() => validateUploadResponse(200, '{"Code":300}'), returnsNormally);
  expect(() => validateUploadResponse(200, '{"Code":500,"Message":"Storage unavailable"}'), throwsA(predicate((e) => e.toString().contains('Storage unavailable'))));
  expect(() => validateUploadResponse(200, '<html>proxy error</html>'), throwsException);
 });
 test('shows size authorization and server failures', () {
  expect(() => validateUploadResponse(500, '{"error":"Storage failure"}'), throwsA(predicate((e) => e.toString().contains('Storage failure'))));
  expect(() => validateUploadResponse(413, ''), throwsA(predicate((e) => e.toString().contains('larger'))));
  expect(() => validateUploadResponse(401, ''), throwsA(predicate((e) => e.toString().contains('Sign in'))));
  expect(() => validateUploadResponse(503, '{"Message":"Upload service unavailable"}'), throwsA(predicate((e) => e.toString().contains('Upload service unavailable'))));
 });
}

