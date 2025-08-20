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

    // ⬇️ Show Uploading Dialog FIRST — before processing files
    final loadingDiv = html.DivElement()
      ..id = 'upload-loading'
      ..style.position = 'fixed'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = 'rgba(0, 0, 0, 0.6)'
      ..style.display = 'flex'
      ..style.flexDirection = 'column'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.zIndex = '10000';

    final spinner = html.DivElement()
      ..style.width = '48px'
      ..style.height = '48px'
      ..style.border = '5px solid #f3f3f3'
      ..style.borderTop = '5px solid #2196f3' // Blue spinner
      ..style.borderRadius = '50%'
      ..style.animation = 'spin 1s linear infinite';

    final styleSheet = html.StyleElement()
      ..innerHtml = '''
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
      ''';
    html.document.head?.append(styleSheet);

    final message = html.DivElement()
      ..text = 'Uploading...'
      ..style.color = 'white'
      ..style.fontSize = '16px'
      ..style.marginTop = '16px'
      ..style.textDecoration = 'none';

    loadingDiv.append(spinner);
    loadingDiv.append(message);
    html.document.body?.append(loadingDiv);

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
      // ⬇️ Remove Uploading Dialog
      loadingDiv.remove();
    }
  });
}