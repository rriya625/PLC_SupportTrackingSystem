import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/widgets/ticket_update_attachments.dart';

void main() {
  test('Retry uploads only remaining Update Ticket attachments', () async {
    final draft = TicketUpdateAttachments();
    for (final name in ['first.txt', 'second.txt']) {
      draft.files.add(
        PlatformFile(name: name, size: 1, bytes: Uint8List.fromList([65])),
      );
    }
    final sent = <String>[];
    await expectLater(
      draft.upload(
        1,
        send: (file) async {
          if (file.name == 'second.txt') throw Exception('Temporary failure');
          sent.add(file.name);
        },
      ),
      throwsException,
    );
    expect(draft.files.map((f) => f.name), ['second.txt']);
    await draft.upload(1, send: (file) async => sent.add(file.name));
    expect(sent, ['first.txt', 'second.txt']);
    expect(draft.files, isEmpty);
    draft.dispose();
  });
}
