import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/utils/ticket_email.dart';

void main() {
  test('Uses customer acronym and ticket description for manual email', () {
    expect(
      ticketEmailSubject(
        'ISP',
        '118596',
        'Support Website - saved credentials',
      ),
      'ISP Ticket #118596 - Support Website - saved credentials',
    );
    expect(ticketEmailSubject('', '10', 'Example'), 'PLC Ticket #10 - Example');
  });
}
