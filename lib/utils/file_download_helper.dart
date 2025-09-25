import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:ticket_tracker_app/constants.dart';
import 'dart:html' as html; // only valid on Web builds

class FileDownloadHelper {
  // ✅ Single place for the error message
  static const String _supportMessage =
      'Unable to download. Please call Support @ (847) 985 2060';

  static Future<void> downloadUserManual(BuildContext context) async {
    // Only applies to Flutter Web + Windows host
    if (!kIsWeb || Constants.hostEnv?.toLowerCase() != 'windows') {
      await _showError(context, _supportMessage);
      return;
    }

    final url = Constants.manualDownloadUrl;
    if (url == null || url.isEmpty) {
      await _showError(context, _supportMessage);
      return;
    }

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // ✅ Check if server really returned a PDF
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.toLowerCase().contains('pdf')) {
          // Trigger browser download
          final blob = html.Blob([response.bodyBytes]);
          final urlBlob = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: urlBlob)
            ..setAttribute("download", "UserManual.pdf")
            ..click();
          html.Url.revokeObjectUrl(urlBlob);

          print('[FileDownloadHelper] UserManual.pdf downloaded via browser.');
        } else {
          // Server returned something else (HTML error page, etc.)
          print('[FileDownloadHelper] Invalid content type: $contentType');
          await _showError(context, _supportMessage);
        }
      } else {
        // ❌ Not 200
        await _showError(context, _supportMessage);
      }
    } catch (e) {
      // ❌ Network error / site unreachable
      print('[FileDownloadHelper] Exception: $e');
      await _showError(context, _supportMessage);
    }
  }

  static Future<void> _showError(BuildContext context, String message) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Download Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }
}