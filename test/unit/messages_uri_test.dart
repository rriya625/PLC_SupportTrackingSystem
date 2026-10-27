import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/utils/messages_api.dart';

void main() {
  test('Delphi lookup receives explicit empty Search and escaped values', () {
    Constants.baseUrlData = 'https://example.test/api/';
    final empty = MessagesApi.requestUri('GetMessageRecipients', {
      'RecipientType': 'CUSTOMER',
      'Search': '',
    });
    expect(empty.query, 'RecipientType=CUSTOMER&Search=');
    final value = MessagesApi.requestUri('GetMessageRecipients', {
      'Search': 'A&B + test',
    });
    expect(value.queryParameters['Search'], 'A&B + test');
    expect(value.queryParameters.length, 1);
  });
}
