import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/utils/api_helper.dart';

void main() {
  test(
    'Document filenames preserve spaces and literal plus signs for XData',
    () {
      Constants.baseUrlData = 'https://example.com/dev/';
      const name = 'A + B & C.docx';
      final uri = APIHelper.documentDownloadUri(
        ticketKey: 123,
        historyNumber: 7,
        source: 'ACTIVITY',
        fileName: name,
      );
      expect(uri.query, contains('A%20%2B%20B%20%26%20C.docx'));
      expect(uri.query, isNot(contains('+')));
      expect(uri.queryParameters['FileName'], name);
      expect(uri.queryParameters['HistoryNumber'], '7');
    },
  );
}
