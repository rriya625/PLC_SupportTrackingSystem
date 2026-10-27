import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ticket_tracker_app/utils/document_bytes.dart';
import 'package:ticket_tracker_app/utils/document_download_helper.dart';
import 'package:ticket_tracker_app/utils/api_helper.dart';

const documentBusyIndicator = SizedBox(
  width: 20,
  height: 20,
  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1565C0)),
);

class DocumentDownloadButton extends StatefulWidget {
  final Future<void> Function() onDownload;
  const DocumentDownloadButton({super.key, required this.onDownload});
  @override
  State<DocumentDownloadButton> createState() => _DocumentDownloadButtonState();
}

class _DocumentDownloadButtonState extends State<DocumentDownloadButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: busy ? 'Downloading...' : 'Download',
    icon: busy ? documentBusyIndicator : const Icon(Icons.download),
    onPressed: busy
        ? null
        : () async {
            setState(() => busy = true);
            try {
              await widget.onDownload();
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
  );
}

Future<void> showDocumentPreview(
  BuildContext context,
  Map<String, dynamic> document,
  Future<Map<String, dynamic>> Function(Map<String, dynamic>) loader,
) => showDialog<void>(
  context: context,
  builder: (_) => DocumentGallery(documents: [document], loadDocument: loader),
);

Future<void> downloadDocumentFile(
  BuildContext context,
  Map<String, dynamic> document,
  Future<Map<String, dynamic>> Function(Map<String, dynamic>) loader,
) async {
  try {
    final data = await loader(document);
    final encoded = data['Base64Content'];
    if (encoded is! String)
      throw const FormatException('No file content returned.');
    final message = await saveDownloadedDocument(
      decodeDocumentBytes(encoded),
      data['FileName']?.toString() ?? document['FileName'].toString(),
    );
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
  } catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(documentError(error))));
  }
}

String documentError(Object error) {
  if (error is ApiException && error.statusCode == 404)
    return 'File could not be found. Please refresh the document list or contact support.';
  if (error is ApiException && error.statusCode == 403)
    return 'You do not have access to this document.';
  return 'Unable to download this document. Please retry.';
}

/// Receives only the documents returned for the current user's ticket access.
class DocumentGallery extends StatelessWidget {
  final List<Map<String, dynamic>> documents;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)
  loadDocument;
  final Future<String> Function(Uint8List, String) saveDocument;

  const DocumentGallery({
    super.key,
    required this.documents,
    required this.loadDocument,
    this.saveDocument = saveDownloadedDocument,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: SizedBox(
      width: 1100,
      height: MediaQuery.sizeOf(context).height * .85,
      child: Column(
        children: [
          AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              tooltip: 'Back to documents',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('View and Download Documents'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          Expanded(
            child: documents.isEmpty
                ? const Center(child: Text('No documents available.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: documents.length,
                    itemBuilder: (context, index) => _DocumentPreview(
                      key: ValueKey(index),
                      document: documents[index],
                      loadDocument: loadDocument,
                      saveDocument: saveDocument,
                      previewHeight: documents.length == 1 ? 400 : 200,
                    ),
                  ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DocumentPreview extends StatefulWidget {
  final Map<String, dynamic> document;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)
  loadDocument;
  final Future<String> Function(Uint8List, String) saveDocument;
  final double previewHeight;

  const _DocumentPreview({
    super.key,
    required this.document,
    required this.loadDocument,
    required this.saveDocument,
    required this.previewHeight,
  });

  @override
  State<_DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends State<_DocumentPreview>
    with AutomaticKeepAliveClientMixin {
  late Future<Uint8List>? bytes = supportsPreview ? _load() : null;
  bool saving = false;
  String? downloadError;
  String get name => widget.document['FileName']?.toString() ?? 'Unnamed file';
  bool get supportsPreview => RegExp(
    r'\.(png|jpe?g|gif|webp|bmp)$',
    caseSensitive: false,
  ).hasMatch(name);

  @override
  bool get wantKeepAlive => true;

  Future<Uint8List> _load() async {
    final data = await widget.loadDocument(widget.document);
    final encoded = data['Base64Content'];
    if (encoded is! String)
      throw const FormatException('No file content returned.');
    return decodeDocumentBytes(encoded);
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      downloadError = null;
    });
    try {
      final data = await (bytes ??= _load());
      final message = await widget.saveDocument(data, name);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted)
        setState(() {
          downloadError = documentError(error);
          bytes = null;
        });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _unsupported() => const SizedBox(
    height: 160,
    width: 200,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.insert_drive_file_outlined, size: 64),
        SizedBox(height: 8),
        Text('Preview not supported'),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (!supportsPreview)
            _unsupported()
          else
            FutureBuilder<Uint8List>(
              future: bytes,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(documentError(snapshot.error!)),
                      TextButton(
                        onPressed: () => setState(() {
                          bytes = _load();
                        }),
                        child: const Text('Retry'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData)
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                final data = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (RegExp(
                      r'\.(png|jpe?g|gif|webp|bmp)$',
                      caseSensitive: false,
                    ).hasMatch(name))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: InteractiveViewer(
                          child: Image.memory(
                            data,
                            height: widget.previewHeight,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => _unsupported(),
                          ),
                        ),
                      )
                    else
                      _unsupported(),
                  ],
                );
              },
            ),
          if (downloadError != null)
            Text(downloadError!, style: const TextStyle(color: Colors.red)),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: saving ? null : _save,
              icon: saving ? documentBusyIndicator : const Icon(Icons.download),
              label: Text(saving ? 'Downloading...' : 'Download'),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
