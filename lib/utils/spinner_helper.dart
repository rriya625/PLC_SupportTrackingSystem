import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
BuildContext? _dialogContext;

/// Shows a fullscreen blocking spinner with custom message (default: "Uploading...")
void showUploadSpinner([String message = "loading..."]) {
  if (_dialogContext != null) return;

  final context = rootNavigatorKey.currentContext;
  if (context == null) {
    debugPrint("⚠️ Spinner not shown. No context.");
    return;
  }

  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (ctx, anim1, anim2) {
      _dialogContext = ctx;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.normal,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Hides the spinner dialog
void hideUploadSpinner() {
  if (_dialogContext != null) {
    Navigator.of(_dialogContext!).pop();
    _dialogContext = null;
  }
}