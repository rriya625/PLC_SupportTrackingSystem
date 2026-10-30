import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ticket_tracker_app/constants.dart';
import '../widgets/portal_loading.dart';
import 'manual_download.dart';

class FileDownloadHelper {
  static bool _busy = false;
  static Future<void> downloadUserManual(BuildContext context) async {
    if (_busy) return;
    _busy = true;
    try {
      final manual = manualForRole(Constants.isEmployee);
      final uri = Uri.base.resolve('manuals/${manual.fileName}');
      final response = await withPortalLoading(context, 'Preparing manuals...',
        () => http.get(uri).timeout(const Duration(seconds: 60)));
      if (response.statusCode != 200 || !manual.matches(response.bodyBytes)) {
        throw Exception('The manual could not be downloaded (HTTP ${response.statusCode}). Please contact Support at (847) 985-2060.');
      }
      final blob = html.Blob([response.bodyBytes], manual.contentType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = manual.fileName
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      // Give mobile browsers time to hand the file to their download manager.
      Timer(const Duration(minutes: 1), () => html.Url.revokeObjectUrl(url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          Constants.isEmployee
          ? 'Download started. Extract EmployeeManuals.zip to open both PDF manuals.'
          : 'Download started. Look for UserManual.pdf in your browser downloads.')));
      }
    } catch (error) {
      if (!context.mounted) return;
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('Manual download'),
        content: Text(error is TimeoutException
          ? 'The manual download timed out. Check your connection and try again.'
          : error.toString().replaceFirst('Exception: ', '')),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
      ));
    } finally { _busy = false; }
  }
}
