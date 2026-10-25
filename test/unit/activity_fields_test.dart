import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/utils/activity_fields.dart';
import 'package:ticket_tracker_app/constants.dart';

void main() {
  test(
    'actual API Number survives edit/delete without changing the record',
    () {
      final record = <String, dynamic>{'Number': '17', 'RawLongDesc': 'before'};
      final original = Map<String, dynamic>.from(record);
      expect(activityNumber(record), 17);
      expect(record, original);
      expect(activityNumber({'Number': 17}), 17);
      expect(activityNumber({'Number': '17', 'HistoryNumber': 0}), 17);
    },
  );
  test('legacy identity aliases and missing identity are safe', () {
    expect(activityNumber({'HistoryNumber': '9'}), 9);
    expect(activityNumber({'Number': '', 'HistoryNo': 9}), 9);
    expect(activityNumber({'Number': 0}), 0);
    expect(activityNumber({'Number': -1}), 0);
    expect(activityNumber({'Number': 'bad'}), 0);
  });
  test('T and Y are both true; false flags never grant actions', () {
    for (final value in [true, 'T', 'Y', 't', ' y ']) {
      expect(portalFlag(value), isTrue);
    }
    for (final value in [false, 'F', 'N', '', null]) {
      expect(portalFlag(value), isFalse);
    }
    Constants.debugMode = 'Y';
    expect(Constants.isDebugModeEnabled, isTrue);
    Constants.debugMode = 'T';
    expect(Constants.isDebugModeEnabled, isTrue);
    Constants.debugMode = 'N';
    expect(Constants.isDebugModeEnabled, isFalse);
  });
}
