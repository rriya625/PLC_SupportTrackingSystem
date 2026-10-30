import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/constants.dart';
void main() {
  test('diagnostic download needs employee role and debug permission', () {
    for (final role in ['CUSTOMER', 'EMPLOYEE', '']) {
      for (final mode in ['T', 'Y', 'F', '']) {
        Constants.userType = role; Constants.debugMode = mode;
        expect(Constants.canDownloadDiagnosticLogs,
          role == 'EMPLOYEE' && ['T', 'Y'].contains(mode));
      }
    }
  });
}
