import 'dart:convert';

/// Formats decoded service diagnostics as readable text; never serialize SQL
/// back into JSON before writing it into the downloaded log.
class DiagnosticFormatter {
  static final _sensitive = RegExp(
    r'password|token|authorization|cookie|secret|base64|filecontent|filedata|filebytes|longdesc|messagetext|expected|^body$|^smessage$',
    caseSensitive: false,
  );

  static dynamic sanitize(dynamic value, [String key = '']) {
    if (_sensitive.hasMatch(key)) return '[REDACTED]';
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(k.toString(), sanitize(v, k.toString())),
      );
    }
    if (value is List) {
      return value.take(100).map((v) => sanitize(v)).toList();
    }
    if (value is String && value.length > 16000) {
      return '${value.substring(0, 16000)} [TRUNCATED]';
    }
    return value;
  }

  static String format({
    required String environment,
    required String endpoint,
    required String method,
    required int httpStatus,
    required int elapsedMs,
    required Map<String, dynamic> inputs,
    dynamic response,
    Map<String, dynamic>? diagnostics,
    String? failure,
  }) {
    final out = StringBuffer()
      ..writeln('Environment: $environment')
      ..writeln('Endpoint: $method $endpoint')
      ..writeln('HTTP status: $httpStatus')
      ..writeln('Client elapsed ms: $elapsedMs')
      ..writeln('Request: ${jsonEncode(sanitize(inputs))}');
    if (failure != null) out.writeln('Diagnostic status: $failure');
    if (diagnostics != null) {
      for (final key in [
        'RequestID',
        'ServiceVersion',
        'AuthenticatedUserID',
        'StartedAtUTC',
        'ElapsedMs',
        'ApplicationCode',
        'RecordCount',
        'ResultCounts',
        'ErrorClass',
      ]) {
        if (diagnostics.containsKey(key)) {
          out.writeln('$key: ${diagnostics[key]}');
        }
      }
      out.writeln(
        'Effective inputs: ${jsonEncode(sanitize(diagnostics['Inputs']))}',
      );
      final queries = diagnostics['Queries'];
      if (queries is List) {
        for (var i = 0; i < queries.length; i++) {
          final q = queries[i];
          if (q is! Map) continue;
          out.writeln('\nQuery ${i + 1}: ${q['Operation']}');
          out.writeln(
            'Succeeded: ${q['Succeeded']}; RowsAffected: ${q['RowsAffected']}; ElapsedMs: ${q['ElapsedMs']}',
          );
          out.writeln('Parameters: ${jsonEncode(sanitize(q['Parameters']))}');
          if (q['ErrorClass'] != null) out.writeln('Error: ${q['ErrorClass']}; Database code: ${q['DatabaseErrorCode']}');
          final sql = q['RunnableSQL'] ?? q['SQL'];
          if (sql is String) {
            out.writeln(
              q['RunnableSQL'] != null
                  ? 'SQL Developer (F5):\nSET DEFINE OFF'
                  : 'SQL template (may contain binds; do not replay writes):',
            );
            out.writeln(sql);
          }
        }
      }
    } else if (response is Map && response['DebugQuery'] is Map) {
      final q = response['DebugQuery'] as Map;
      out.writeln('Parameters: ${jsonEncode(sanitize(q['Parameters']))}');
      out.writeln(q['RunnableSQL'] != null
          ? 'SQL Developer (F5):\nSET DEFINE OFF'
          : 'SQL template (bind values listed above; older service has no RunnableSQL):');
      out.writeln(q['RunnableSQL'] ?? q['SQL'] ?? '');
    }
    // Keep GetUserInfo and business responses, excluding diagnostic SQL already
    // rendered above and large file payloads.
    final summary = response is Map
        ? Map<String, dynamic>.from(response)
        : response;
    if (summary is Map) {
      summary.remove('Diagnostics');
      summary.remove('DebugQuery');
    }
    out.writeln(
      '\nResponse: ${const JsonEncoder.withIndent('  ').convert(sanitize(summary))}',
    );
    return out.toString();
  }
}
