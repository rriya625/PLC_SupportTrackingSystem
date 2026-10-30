import 'upload_result.dart';
import 'package:ticket_tracker_app/utils/diagnostic_http_client.dart';

/// ⚠️ This file is for Flutter Web only.
/// Do NOT import this file on iOS or Android.
/// Use `kIsWeb` to conditionally call this code.

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:ticket_tracker_app/utils/spinner_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../constants.dart';
import 'package:ticket_tracker_app/utils/dialogs.dart';

Future<Uint8List> _readUploadFile(html.File file) async {
  final reader = html.FileReader();
  final done = Completer<Uint8List>();
  reader.onLoad.listen((_) {
    final value = reader.result;
    if (value is Uint8List) {
      if (!done.isCompleted) done.complete(value);
    } else if (value is ByteBuffer) {
      if (!done.isCompleted) done.complete(value.asUint8List());
    } else if (!done.isCompleted) {
      done.completeError(
        Exception('Could not read ${file.name}. Please select the file again.'),
      );
    }
  });
  reader.onError.listen((_) {
    if (!done.isCompleted)
      done.completeError(
        Exception(
          'Could not read ${file.name}. ${reader.error?.message ?? "Please select the file again."}',
        ),
      );
  });
  reader.onAbort.listen((_) {
    if (!done.isCompleted)
      done.completeError(
        Exception('Reading ${file.name} was interrupted. Please try again.'),
      );
  });
  reader.readAsArrayBuffer(file);
  try {
    final bytes = await done.future.timeout(const Duration(seconds: 90));
    if (bytes.isEmpty)
      throw Exception('${file.name} is empty and cannot be uploaded.');
    return bytes;
  } on TimeoutException {
    reader.abort();
    throw Exception(
      'Reading ${file.name} timed out. Make sure the file is downloaded to your phone, then try again.',
    );
  }
}

Future<void> pickAndUploadFilesWeb({
  required BuildContext context,
  required int ticketKey,
}) async {
  final input = html.FileUploadInputElement()
    ..multiple = true
    ..accept = '*/*';
  input.style.display = 'none';
  html.document.body?.append(input);
  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      input.remove();
      return;
    }
    String message;
    showUploadSpinner('Preparing files...');
    try {
      final data = <Map<String, dynamic>>[];
      for (final file in files) {
        final bytes = await _readUploadFile(file);
        data.add({
          'sFileName': file.name,
          'Base64Content': base64Encode(bytes),
        });
      }
      await uploadPickedFilesWeb(ticketKey, data);
      message = 'Documents uploaded successfully.';
    } catch (error) {
      message = 'Documents were not uploaded. $error';
    } finally {
      hideUploadSpinner();
      input.remove();
    }
    if (context.mounted) await showMessageDialog(context, message);
  });
  input.click();
}

void downloadImage(BuildContext context, String fileName, Uint8List data) {
  if (kIsWeb) {
    final blob = html.Blob([data]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  } else {
    print("📥 Download on mobile is not implemented yet: $fileName");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download not supported yet on this platform.')),
    );
  }
}

void pickFilesForWeb({
  required List<Map<String, dynamic>> pendingFiles,
  required VoidCallback updateUI,
}) {
  final input = html.FileUploadInputElement();
  input.accept = '*/*';
  input.multiple = true;
  input.style.display = 'none';
  html.document.body?.append(input);

  input.onChange.listen((event) async {
    final files = input.files;
    if (files == null || files.isEmpty) return;

    showUploadSpinner('Preparing preview...');

    try {
      for (final file in files) {
        final fileBytes = await _readUploadFile(file);
        final base64 = base64Encode(fileBytes);

        pendingFiles.add({
          'LocalID':
              '${DateTime.now().microsecondsSinceEpoch}-${pendingFiles.length}',
          'sFileName': file.name,
          'Base64Content': base64,
        });
      }
    } catch (e) {
      hideUploadSpinner();
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted)
        await showMessageDialog(
          context,
          'Could not attach the selected file. $e',
        );
    } finally {
      hideUploadSpinner();
      updateUI();
      input.remove();
    }
  });

  input.click();
}

Future<void> uploadPickedFilesWeb(
  int ticketKey,
  List<Map<String, dynamic>> files,
) async {
  showUploadSpinner('Uploading...'); // ✅ Show platform-safe spinner

  final uri = Uri.parse('${Constants.baseUrlData}UploadFiles');
  print("🚀 Calling uploadPickedFilesWeb...");
  print("📤 Uploading to: $uri");

  try {
    final requestBody = {
      'TicketKey': ticketKey,
      'ProspectKey': Constants.userID,
      'FileList': files,
    };

    final response = await diagnosticHttpClient
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${Constants.accessToken}', // ✅ Auth added
          },
          body: jsonEncode(requestBody),
        )
        .timeout(
          const Duration(minutes: 2),
          onTimeout: () => throw Exception(
            'Upload timed out. Check the Documents list before retrying to avoid duplicates.',
          ),
        );

    validateUploadResponse(response.statusCode, response.body);
  } finally {
    hideUploadSpinner(); // ✅ Hide spinner regardless of success/failure
  }
}
