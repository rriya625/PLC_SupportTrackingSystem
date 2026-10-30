import 'dart:convert';

void validateUploadResponse(int status, String body) {
  dynamic result;
  try {
    result = jsonDecode(body.replaceFirst('\uFEFF', ''));
  } catch (_) {}
  final message = result is Map
      ? (result['Message'] ?? result['message'] ?? (result['error'] is Map ? result['error']['message'] : result['error']))
      : null;
  if (status == 200 && result is Map && result['Code'].toString() == '300')
    return;
  if (message is String && message.trim().isNotEmpty) {
    throw Exception('Upload failed (HTTP $status): $message');
  }
  if (status == 413)
    throw Exception(
      'The upload is larger than the server allows. Choose a smaller file or upload fewer files at a time.',
    );
  if (status == 401 || status == 403)
    throw Exception('Upload was not authorized. Sign in again and retry.');
  throw Exception(
    'Upload failed (HTTP $status). The server did not confirm that the files were saved. Please try again.',
  );
}

