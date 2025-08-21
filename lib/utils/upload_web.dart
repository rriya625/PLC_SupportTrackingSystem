/// ⚠️ This file is for Flutter Web only.
/// Do NOT import this file on iOS or Android.
/// Use `kIsWeb` to conditionally call this code.

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:ticket_tracker_app/utils/spinner_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../constants.dart';

Future<void> pickAndUploadFilesWeb({
  required int ticketKey,
}) async {
  final input = html.FileUploadInputElement();
  input.multiple = true;
  input.accept = '*/*';
  input.click();

  input.onChange.listen((event) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      print("❌ No files selected");
      return;
    }

    showUploadSpinner('Uploading...'); // ✅ Use platform-safe spinner

    try {
      final List<Map<String, dynamic>> fileData = [];

      for (final file in files) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;

        final Uint8List fileBytes = reader.result as Uint8List;
        final base64String = base64Encode(fileBytes);

        fileData.add({
          'sFileName': file.name,
          'Base64Content': base64String,
        });

        print("📤 Prepared file: ${file.name}, size: ${file.size}");
      }

      final requestBody = {
        'TicketKey': ticketKey,
        'ProspectKey': Constants.userID,
        'FileList': fileData,
      };

      final uri = Uri.parse('${Constants.baseUrlData}UploadFiles');
      print("📤 Uploading to: $uri");

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Constants.accessToken}',
        },
        body: jsonEncode(requestBody),
      );

      print("✅ API Response: ${response.statusCode}");
      print("📨 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final code = json['Code'];
        final msg = json['Message'];
        print("✅ Upload Status: $code, Message: $msg");
      } else {
        print("❌ Upload failed: ${response.reasonPhrase}");
      }
    } catch (e) {
      print("❌ Exception during upload: $e");
    } finally {
      /*loadingDiv.remove();*/
      hideUploadSpinner(); // ✅ Hide spinner regardless of result
    }
  });
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
  required List<dynamic> attachedImages,
  required VoidCallback updateUI,
}) {
  final input = html.FileUploadInputElement();
  input.accept = '*/*';
  input.multiple = true;
  input.click();

  input.onChange.listen((event) async {
    final files = input.files;
    if (files == null || files.isEmpty) return;

    for (final file in files) {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final Uint8List fileBytes = reader.result as Uint8List;
      final base64 = base64Encode(fileBytes);

      pendingFiles.add({
        'sFileName': file.name,
        'Base64Content': base64,
      });

      attachedImages.add(fileBytes); // ✅ This is the key fix
    }

    updateUI(); // Trigger setState in ReportIssueScreen
  });
}

Future<void> uploadPickedFilesWeb(int ticketKey, List<Map<String, dynamic>> files) async {
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

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Constants.accessToken}', // ✅ Auth added
      },
      body: jsonEncode(requestBody),
    );

    print("✅ API Response: ${response.statusCode}");
    print("📨 Response Body: ${response.body}");

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final code = json['Code'];
      final msg = json['Message'];
      print("✅ Upload Status: $code, Message: $msg");
    } else {
      print("❌ Upload failed: ${response.reasonPhrase}");
    }
  } catch (e) {
    print("❌ Exception during upload: $e");
  } finally {
    hideUploadSpinner(); // ✅ Hide spinner regardless of success/failure
  }
}