import 'dart:typed_data';
import 'package:flutter/material.dart';

Future<void> pickAndUploadFilesWeb({required int ticketKey}) async {
  debugPrint('❌ pickAndUploadFilesWeb is not supported on this platform.');
}

void downloadImage(BuildContext context, String fileName, Uint8List data) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Download Unsupported'),
      content: const Text('Download is supported only for web platform.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void pickFilesForWeb({
  required List<Map<String, dynamic>> pendingFiles,
  required List<dynamic> attachedImages,
  required VoidCallback updateUI,
}) {
  print("📱 pickFilesForWeb is not supported on mobile");
}

Future<void> uploadPickedFilesWeb(int ticketKey, List<Map<String, dynamic>> files) async {
  print("📱 uploadPickedFilesWeb is not supported on mobile");
}
