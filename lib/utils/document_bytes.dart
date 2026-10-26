import 'dart:convert';
import 'dart:typed_data';

/// Accept legacy MIME-wrapped Base64 and the current unwrapped API response.
Uint8List decodeDocumentBytes(String value) =>
    base64Decode(value.replaceAll(RegExp(r'\s+'), ''));
