import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ticket_tracker_app/utils/document_bytes.dart';
import 'package:ticket_tracker_app/utils/document_download_helper.dart';

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

  const _DocumentPreview({
    super.key,
    required this.document,
    required this.loadDocument,
    required this.saveDocument,
  });

  @override
  State<_DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends State<_DocumentPreview>
    with AutomaticKeepAliveClientMixin {
  late Future<Uint8List> bytes = _load();
  bool saving = false;
  String get name => widget.document['FileName']?.toString() ?? 'Unnamed file';

  @override
  bool get wantKeepAlive => true;

  Future<Uint8List> _load() async {
    final data = await widget.loadDocument(widget.document);
    return decodeDocumentBytes(data['Base64Content']?.toString() ?? '');
  }

  Future<void> _save(Uint8List data) async {
    setState(() => saving = true);
    try {
      final message = await widget.saveDocument(data, name);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $error')));
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
    final source = widget.document['Source']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          if (source == 'ACTIVITY')
            Text('Activity #${widget.document['HistoryNumber']}'),
          const SizedBox(height: 8),
          FutureBuilder<Uint8List>(
            future: bytes,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Unable to load this document.'),
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
                      child: Image.memory(
                        data,
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => _unsupported(),
                      ),
                    )
                  else
                    _unsupported(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : () => _save(data),
                      icon: const Icon(Icons.download),
                      label: Text(saving ? 'Downloading...' : 'Download'),
                    ),
                  ),
                ],
              );
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
