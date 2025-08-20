import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;

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
      'ProspectKey': Constants.userID, // <- Automatically pulled
      'FileList': fileData,
    };

    final uri = Uri.parse('${Constants.baseUrlData}UploadFiles');
    print("📤 Uploading to: $uri");

    try {
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
    }
  });
}