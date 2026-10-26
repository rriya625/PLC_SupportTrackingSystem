import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/utils/document_bytes.dart';

void main() {
  test('decodes legacy wrapped documents without changing bytes', () {
    final bytes = List<int>.generate(8192, (i) => i % 256);
    final encoded = base64Encode(bytes);
    final wrapped = RegExp(
      '.{1,76}',
    ).allMatches(encoded).map((m) => m.group(0)!).join('\r\n');
    expect(decodeDocumentBytes(wrapped), bytes);
    expect(decodeDocumentBytes(encoded), bytes);
  });
  test('invalid document payload is still rejected', () {
    expect(() => decodeDocumentBytes('not!base64'), throwsFormatException);
  });
}
