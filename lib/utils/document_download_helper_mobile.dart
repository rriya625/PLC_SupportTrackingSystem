import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> saveDownloadedDocument(Uint8List bytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File('${directory.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);
  return 'Saved to ${file.path}';
}
