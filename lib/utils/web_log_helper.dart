import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/utils/diagnostic_download_helper_stub.dart'
    if (dart.library.html) 'package:ticket_tracker_app/utils/diagnostic_download_helper_web.dart';

class WebLogHelper {
  /// Sends diagnostic entries to the existing IIS log handler only when the
  /// authenticated account has DEBUG_MODE=T.
  static Future<void> log(String message) async {
    if (!kIsWeb || !Constants.isDebugModeEnabled) return;
    final url = Constants.logUploadUrl;
    if (url == null || url.isEmpty) return;
    await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Constants.accessToken}',
      },
      body: jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'userID': Constants.userID.toString(),
        'message': message.length > 250000
            ? '${message.substring(0, 250000)}\n[LOG TRUNCATED]'
            : message,
      }),
    );
  }

  /// Logs a service response without including request headers or credentials.
  static Future<void> logApiResponse({
    required String endpoint,
    required int httpStatus,
    required String responseBody,
  }) async {
    if (!Constants.isDebugModeEnabled) return;
    await log(
      jsonEncode({
        'environment': Constants.buildEnv,
        'endpoint': endpoint,
        'httpStatus': httpStatus,
        'response': _decodeResponse(responseBody),
      }),
    );
  }

  static dynamic _decodeResponse(String responseBody) {
    try {
      return jsonDecode(responseBody);
    } catch (_) {
      return responseBody;
    }
  }

  static Future<void> downloadServerLog({String? date}) async {
    if (!kIsWeb || !Constants.canDownloadDiagnosticLogs) return;
    final baseUrl = Constants.logUploadUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('Diagnostic log endpoint is not configured.');
    }
    final parameters = <String, String>{
      'action': 'download',
      'UserID': Constants.userID.toString(),
      if (date == null) 'latest': 'true' else 'date': date,
    };
    final uri = Uri.parse(baseUrl).replace(queryParameters: parameters);
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer ${Constants.accessToken}'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        response.body.isEmpty
            ? 'Unable to download diagnostic log.'
            : response.body,
      );
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final match = RegExp(r'filename="?([^";]+)').firstMatch(disposition);
    final filename = match?.group(1) ?? 'Support_Web_debug.zip';
    await saveDiagnosticFile(response.bodyBytes, filename, 'application/zip');
  }

  static void clear() {}
}
