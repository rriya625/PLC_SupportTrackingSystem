// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: deprecated_member_use
import 'dart:js_util' as js_util;

Future<void> saveDiagnosticFile(
  List<int> contents,
  String filename,
  String mimeType,
) async {
  final bytes = html.Blob([contents], mimeType);

  if (js_util.hasProperty(html.window, 'showSaveFilePicker')) {
    final options = js_util.jsify({
      'suggestedName': filename,
      'types': [
        {
          'description': 'ZIP archive',
          'accept': {
            'application/zip': ['.zip'],
          },
        },
      ],
    });
    final handle = await js_util.promiseToFuture<Object?>(
      js_util.callMethod(html.window, 'showSaveFilePicker', [options]),
    );
    final writable = await js_util.promiseToFuture<Object?>(
      js_util.callMethod(handle!, 'createWritable', const []),
    );
    await js_util.promiseToFuture<Object?>(
      js_util.callMethod(writable!, 'write', [bytes]),
    );
    await js_util.promiseToFuture<Object?>(
      js_util.callMethod(writable, 'close', const []),
    );
    return;
  }

  final url = html.Url.createObjectUrlFromBlob(bytes);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}
