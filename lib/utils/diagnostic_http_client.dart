import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ticket_tracker_app/constants.dart';

import 'diagnostic_formatter.dart';
import 'web_log_helper.dart';

typedef DiagnosticWriter = Future<void> Function(String message);

/// Shared REST client. The underlying client handles log retrieval without
/// recursively logging GetRequestDiagnostics or the IIS log upload.
class DiagnosticHttpClient extends http.BaseClient {
  DiagnosticHttpClient(this.inner, {DiagnosticWriter? writer})
    : writer = writer ?? WebLogHelper.log;
  final http.Client inner;
  final DiagnosticWriter writer;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final endpoint = request.url.pathSegments.last;
    final base = Uri.parse(Constants.baseUrlData);
    final isInterface =
        request.url.origin == base.origin &&
        request.url.path.startsWith(base.path) &&
        endpoint != 'GetRequestDiagnostics';
    if (!isInterface) return inner.send(request);
    final user = Constants.userID;
    final environment = Constants.buildEnv;
    final auth =
        request.headers['Authorization'] ?? request.headers['authorization'];
    final watch = Stopwatch()..start();
    try {
      final streamed = await inner.send(request);
      final response = await http.Response.fromStream(streamed);
      dynamic decoded;
      if ((response.headers['content-type'] ?? '').contains('json') ||
          endpoint == 'GetUserInfo') {
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {}
      }
      // Bootstrap flag before logging the first GetUserInfo response.
      if (endpoint == 'GetUserInfo' &&
          response.statusCode == 200 &&
          decoded is Map &&
          Constants.userID == user) {
        Constants.debugMode = decoded['DEBUG_MODE']?.toString() ?? 'N';
      }
      if (Constants.isDebugModeEnabled && Constants.userID == user) {
        final inputs = <String, dynamic>{...request.url.queryParameters};
        if (request is http.Request && request.body.isNotEmpty) {
          try {
            final body = jsonDecode(request.body);
            if (body is Map) inputs.addAll(Map<String, dynamic>.from(body));
          } catch (_) {
            inputs['body'] = '[not JSON]';
          }
        }
        Map<String, dynamic>? diagnostics;
        String? unavailable;
        if (decoded is Map && decoded['Diagnostics'] is Map) {
          diagnostics = Map<String, dynamic>.from(decoded['Diagnostics']);
        } else {
          final id = response.headers['x-prospect-debug-id'];
          if (id != null && auth != null) {
            try {
              final detail = await inner
                  .get(
                    base.resolve('GetRequestDiagnostics')
                        .replace(queryParameters: {'RequestID': id}),
                    headers: {'Authorization': auth},
                  )
                  .timeout(const Duration(seconds: 5));
              if (detail.statusCode == 200) {
                diagnostics = Map<String, dynamic>.from(
                  jsonDecode(detail.body),
                );
              } else {
                unavailable =
                    'Details unavailable (HTTP ${detail.statusCode}); request ID $id';
              }
            } catch (_) {
              unavailable = 'Diagnostic lookup failed; request ID $id';
            }
          }
        }
        if (Constants.userID == user && Constants.isDebugModeEnabled) {
          try {
            await writer(
              DiagnosticFormatter.format(
                environment: environment,
                endpoint: endpoint,
                method: request.method,
                httpStatus: response.statusCode,
                elapsedMs: watch.elapsedMilliseconds,
                inputs: inputs,
                response:
                    decoded ??
                    {
                      'contentType': response.headers['content-type'],
                      'byteCount': response.bodyBytes.length,
                    },
                diagnostics: diagnostics,
                failure: unavailable,
              ),
            ).timeout(const Duration(seconds: 5));
          } catch (_) {
            /* Diagnostics must not break REST behavior. */
          }
        }
      }
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
        request: request,
        reasonPhrase: response.reasonPhrase,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
      );
    } catch (error) {
      if (Constants.isDebugModeEnabled && Constants.userID == user) {
        try {
          await writer(
            'Endpoint: ${request.method} $endpoint\nTransport error: ${error.runtimeType}',
          ).timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  void close() => inner.close();
}

final diagnosticHttpClient = DiagnosticHttpClient(http.Client());
