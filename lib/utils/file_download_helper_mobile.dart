import 'package:flutter/material.dart';

class FileDownloadHelper {
  static Future<void> downloadUserManual(BuildContext context) async {
    await _showError(context, 'Download not supported on mobile yet.');
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