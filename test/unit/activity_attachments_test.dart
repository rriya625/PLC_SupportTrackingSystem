import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/widgets/activity_attachments.dart';

void main() {
  test('Partial failure retries only remaining files against the same saved activity', () async {
    final draft = ActivityAttachments();
    for (final name in ['one.png', 'two.pdf']) {
      draft.files.add(PlatformFile(name: name, size: 1, bytes: Uint8List.fromList([1])));
    }
    var creates = 0;
    var fail = true;
    final uploaded = <String>[];
    Future<Map<String, dynamic>> create() async { creates++; return {'Code': 300, 'HistoryNumber': 7}; }
    Future<void> upload(int ticket, int number, PlatformFile file) async {
      expect(ticket, 100); expect(number, 7);
      if (file.name == 'two.pdf' && fail) throw Exception('Disconnected');
      uploaded.add(file.name);
    }
    await expectLater(draft.save(100, create, upload: upload), throwsException);
    expect(draft.activitySaved, true);
    expect(draft.files.map((f) => f.name), ['two.pdf']);
    fail = false;
    await draft.save(100, create, upload: upload);
    expect(creates, 1);
    expect(uploaded, ['one.png', 'two.pdf']);
    expect(draft.files, isEmpty);
    draft.dispose();
  });
  test('Failed activity creation never uploads attachments', () async {
    final draft = ActivityAttachments();
    draft.files.add(PlatformFile(name: 'one.txt', size: 1, bytes: Uint8List(1)));
    await expectLater(draft.save(100, () async => {'Code': 320, 'Message': 'Rejected'},
      upload: (_, _, _) async => fail('Must not upload')), throwsException);
    expect(draft.activitySaved, false);
    expect(draft.files.length, 1);
    draft.dispose();
  });
  test('Missing returned number does not duplicate a successfully saved activity', () async {
    final draft = ActivityAttachments();
    draft.files.add(PlatformFile(name: 'one.txt', size: 1, bytes: Uint8List(1)));
    var creates = 0;
    Future<Map<String, dynamic>> create() async { creates++; return {'Code': 300}; }
    await expectLater(draft.save(100, create), throwsException);
    await expectLater(draft.save(100, create), throwsException);
    expect(creates, 1);
    draft.dispose();
  });
}
