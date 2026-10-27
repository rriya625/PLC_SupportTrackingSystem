import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../constants.dart';
import '../utils/api_helper.dart';
import 'activity_attachments.dart';

/// Reuse the attachment picker while saving to the ticket's customer uploads.
class TicketUpdateAttachments extends ActivityAttachments {
  Future<void> upload(
    int ticketKey, {
    Future<void> Function(PlatformFile)? send,
  }) async {
    message = null;
    try {
      while (files.isNotEmpty) {
        final file = files.first;
        if (send != null) {
          await send(file);
        } else {
          final response = await APIHelper.uploadFilesWeb(
            ticketKey: ticketKey,
            prospectKey: Constants.userID,
            fileList: [
              {'name': file.name, 'bytes': file.bytes!},
            ],
          );
          if (response.statusCode != 200)
            throw Exception('Upload failed (${response.statusCode}).');
          final result = jsonDecode(response.body);
          if (result is Map &&
              result['Code'] != null &&
              result['Code'].toString() != '300') {
            throw Exception(result['Message'] ?? 'Upload failed.');
          }
        }
        files.removeAt(0);
        changed();
      }
    } catch (e) {
      message =
          'Ticket changes were saved. Some attachments failed. Submit again to retry the remaining files. $e';
      changed();
      rethrow;
    }
  }
}
