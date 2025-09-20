import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:ticket_tracker_app/constants.dart';

class WebLogHelper {
  /// Sends a structured log message to the server if running on Flutter Web + Windows host.
  /// Includes timestamp and user ID for traceability.
  static Future<void> log(String message) async {
    // Only applies to Flutter Web
    if (!kIsWeb) return;

    // Optionally restrict to Windows IIS-hosted environments
    if (Constants.hostEnv?.toLowerCase() != 'windows') {
      print('[WebLogHelper] Skipping log: HOST_ENV is not "windows".');
      return;
    }

    final url = Constants.logUploadUrl;
    if (url == null || url.isEmpty) {
      print('[WebLogHelper] Skipping log: LOG_UPLOAD_URL is not defined.');
      return;
    }

    final payload = {
      "timestamp": DateTime.now().toIso8601String(),
      "userID": Constants.userID != 0 ? Constants.userID.toString() : "Unknown",
      "message": message,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('[WebLogHelper] Log uploaded successfully.');
      } else {
        print('[WebLogHelper] Failed to upload log (HTTP ${response.statusCode}).');
      }
    } catch (e) {
      print('[WebLogHelper] Error sending log: $e');
    }
  }
}