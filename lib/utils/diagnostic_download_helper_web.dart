import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Use the browser download manager on desktop and mobile. A file picker
/// invoked after an HTTP request can lose its required user activation.
Future<void> saveDiagnosticFile(
  List<int> contents,
  String filename,
  String mimeType,
) async {
  final bytes = html.Blob([contents], mimeType);
  final url = html.Url.createObjectUrlFromBlob(bytes);
  final anchor = html.AnchorElement(href: url)..download = filename;
  html.document.body?.append(anchor);
  anchor.click();
  // Keep the blob alive long enough for mobile browsers to consume it.
  Timer(const Duration(seconds: 30), () {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  });
}
