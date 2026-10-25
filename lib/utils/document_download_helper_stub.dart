import 'dart:typed_data';

Future<String> saveDownloadedDocument(Uint8List bytes, String fileName) async {
  throw UnsupportedError(
    'Document download is not supported on this platform.',
  );
}
