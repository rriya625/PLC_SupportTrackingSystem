import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../utils/messages_api.dart';
import '../utils/file_download_helper.dart';
import '../utils/document_download_helper.dart';
import '../widgets/portal_app_bar.dart';
import '../widgets/portal_loading.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key, required this.diagnostics});
  final VoidCallback diagnostics;
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final counts = <String, int>{};
  final failed = <String>{};
  final api = MessagesApi();
  static const categories = [
    ('ADMIN', 'Admin Documents', Icons.folder_shared_outlined),
    ('AGENCY', 'For Your Agency', Icons.business_outlined),
    ('PERSONAL', 'For you', Icons.person_outline),
  ];
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      counts.clear();
      failed.clear();
    });
    await Future.wait(
      categories.map((item) async {
        try {
          final r = await api.call(
            'GetPublishedDocuments',
            query: {'Category': item.$1},
          );
          if (mounted)
            setState(
              () => counts[item.$1] = (r['Data'] as List)
                  .where((f) => f['Downloadable'] == true)
                  .length,
            );
        } catch (_) {
          if (mounted) setState(() => failed.add(item.$1));
        }
      }),
    );
  }

  Widget downloadCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? action, {
    bool loading = false,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    color: action == null && !loading
        ? Colors.grey.shade100
        : Colors.blue.shade50,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: action == null ? Colors.grey.shade300 : Colors.blue.shade200,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      enabled: action != null,
      leading: CircleAvatar(
        backgroundColor: action == null
            ? Colors.grey.shade200
            : Colors.blue.shade100,
        child: Icon(
          icon,
          color: action == null ? Colors.grey : Colors.blue.shade800,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue,
              ),
            )
          : Icon(
              action == null ? Icons.folder_off_outlined : Icons.chevron_right,
              color: action == null ? Colors.grey : Colors.blue.shade800,
            ),
      onTap: action,
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: PortalAppBar(
      backgroundColor: Colors.blue[800],
      foregroundColor: Colors.white,
      title: const Text('Downloads'),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (Constants.canDownloadDiagnosticLogs)
              downloadCard(
                'Download Diagnostic Log',
                'Review portal diagnostic files.',
                Icons.bug_report_outlined,
                widget.diagnostics,
              ),
            downloadCard(
              Constants.isEmployee
                  ? 'Download User and Employee Manuals'
                  : 'Download User Manual',
              'Instructions for using the support portal.',
              Icons.menu_book_outlined,
              () => FileDownloadHelper.downloadUserManual(context),
            ),
            for (final item in categories)
              downloadCard(
                item.$2,
                failed.contains(item.$1)
                    ? 'Unable to check documents. Click to retry.'
                    : !counts.containsKey(item.$1)
                    ? 'Checking available documents...'
                    : counts[item.$1] == 0
                    ? 'No documents available to download.'
                    : '${counts[item.$1]} document(s) available',
                item.$3,
                failed.contains(item.$1)
                    ? refresh
                    : (counts[item.$1] ?? 0) == 0
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PublishedDocumentsScreen(
                              category: item.$1,
                              title: item.$2,
                            ),
                          ),
                        );
                        if (mounted) refresh();
                      },
                loading:
                    !counts.containsKey(item.$1) && !failed.contains(item.$1),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh documents'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PublishedDocumentsScreen extends StatefulWidget {
  const PublishedDocumentsScreen({
    super.key,
    required this.category,
    required this.title,
  });
  final String category, title;
  @override
  State<PublishedDocumentsScreen> createState() => _PublishedDocumentsState();
}

class _PublishedDocumentsState extends State<PublishedDocumentsScreen> {
  final api = MessagesApi();
  List<Map<String, dynamic>> files = [];
  final selected = <String>{};
  bool loading = true, downloading = false;
  String? error;
  int batchBytes = 50 * 1024 * 1024;
  String progress = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await api.call(
        'GetPublishedDocuments',
        query: {'Category': widget.category},
      );
      if (!mounted) return;
      setState(() {
        files =
            (result['Data'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
              ..sort(
                (a, b) => a['Path'].toString().compareTo(b['Path'].toString()),
              );
        batchBytes = (result['BatchBytes'] as num).toInt();
        selected.clear();
        selected.addAll(
          files
              .where((f) => f['Downloadable'] == true)
              .map((f) => f['Path'].toString()),
        );
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> download() async {
    setState(() {
      downloading = true;
      error = null;
    });
    try {
      final batches = <List<String>>[];
      var batch = <String>[];
      var size = 0;
      for (final f in files.where((f) => selected.contains(f['Path']))) {
        final bytes = (f['Size'] as num).toInt();
        if (batch.isNotEmpty &&
            (size + bytes > batchBytes || batch.length == 100)) {
          batches.add(batch);
          batch = [];
          size = 0;
        }
        batch.add(f['Path'].toString());
        size += bytes;
      }
      if (batch.isNotEmpty) batches.add(batch);
      for (var i = 0; i < batches.length; i++) {
        if (!mounted) return;
        setState(
          () =>
              progress = 'Preparing download ${i + 1} of ${batches.length}...',
        );
        final archive = Archive();
        for (final path in batches[i]) {
          final file = files.firstWhere((f) => f['Path'] == path);
          final total = (file['Size'] as num).toInt();
          if (total > 50 * 1024 * 1024) throw Exception('File exceeds 50 MB');
          final buffer = BytesBuilder(copy: false);
          var offset = 0;
          do {
            if (!mounted) return;
            setState(() => progress = '$path  -  ${total == 0 ? 100 : (100 * offset / total).floor()}% (ZIP ${i + 1}/${batches.length})');
            final result = await api.call('DownloadPublishedDocuments', body: {
              'Category': widget.category,
              'FilesJSON': jsonEncode({'Path': path, 'Offset': offset, 'Version': file['Version']}),
            });
            final bytes = base64Decode(result['Base64Content'].toString());
            final next = (result['NextOffset'] as num).toInt();
            if (result['Version'] != file['Version'] || result['Offset'] != offset ||
                result['TotalBytes'] != total || next != offset + bytes.length ||
                next > total || bytes.length > 1024 * 1024 || (next == offset && offset < total)) {
              throw Exception('Incomplete download. Refresh and try again.');
            }
            buffer.add(bytes);
            offset = next;
          } while (offset < total);
          archive.addFile(ArchiveFile(path, total, buffer.takeBytes()));
        }
        if (!mounted) return;
        setState(() => progress = 'Saving ZIP ${i + 1} of ${batches.length}...');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await saveDownloadedDocument(
          Uint8List.fromList(ZipEncoder().encode(archive, level: 0)),
          '${widget.category.toLowerCase()}-documents-${i + 1}.zip',
        );
      }
      if (mounted)
        setState(
          () => progress =
              '${batches.length} ZIP download(s) started. Check your browser’s Downloads.',
        );
    } catch (e) {
      if (mounted) setState(() => error = 'Download failed: $e');
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  Widget folderCheckbox(String prefix) {
    final paths = files
        .where(
          (f) =>
              f['Downloadable'] == true &&
              f['Path'].toString().startsWith(prefix),
        )
        .map((f) => f['Path'].toString())
        .toSet();
    final count = paths.where(selected.contains).length;
    return Tooltip(
      message: 'Select all documents in $prefix',
      child: Checkbox(
        tristate: true,
        value: count == 0
            ? false
            : count == paths.length
            ? true
            : null,
        onChanged: downloading || paths.isEmpty
            ? null
            : (_) => setState(() {
                if (count == paths.length) {
                  selected.removeAll(paths);
                } else {
                  selected.addAll(paths);
                }
              }),
      ),
    );
  }

  List<Widget> tree(String prefix) {
    final children = <String>{};
    final result = <Widget>[];
    for (final f in files) {
      final path = f['Path'].toString();
      if (!path.startsWith(prefix)) continue;
      final rest = path.substring(prefix.length);
      if (rest.contains('/')) {
        final folder = rest.split('/').first;
        if (children.add(folder))
          result.add(
            ExpansionTile(
              key: PageStorageKey(prefix + folder),
              initiallyExpanded: true,
              leading: folderCheckbox('$prefix$folder/'),
              title: Row(
                children: [
                  const Icon(Icons.folder, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(child: Text(folder)),
                ],
              ),
              children: tree('$prefix$folder/'),
            ),
          );
      } else {
        final allowed = f['Downloadable'] == true;
        result.add(
          CheckboxListTile(
            value: selected.contains(path),
            title: Text(rest),
            subtitle: Text(
              allowed
                  ? '${((f['Size'] as num) / 1024).toStringAsFixed(1)} KB'
                  : 'Exceeds the 50 MB per-file download limit. Contact support.',
            ),
            onChanged: !allowed || downloading
                ? null
                : (v) => setState(() {
                    if (v == true)
                      selected.add(path);
                    else
                      selected.remove(path);
                  }),
          ),
        );
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: PortalAppBar(
      backgroundColor: Colors.blue[800],
      foregroundColor: Colors.white,
      title: Text(widget.title),
    ),
    body: loading
        ? const Center(child: PortalLoading(message: 'Loading documents...'))
        : Column(
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (error == null && files.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No documents are available.'),
                ),
              if (files.isNotEmpty)
                CheckboxListTile(
                  title: const Text('Select all folders and documents'),
                  subtitle: const Text(
                    'Choose documents from any folders. Selections are kept when folders are collapsed.',
                  ),
                  value:
                      selected.length ==
                      files.where((f) => f['Downloadable'] == true).length,
                  onChanged: downloading
                      ? null
                      : (v) => setState(() {
                          selected.clear();
                          if (v == true)
                            selected.addAll(
                              files
                                  .where((f) => f['Downloadable'] == true)
                                  .map((f) => f['Path'].toString()),
                            );
                        }),
                ),
              Expanded(child: ListView(children: tree(''))),
              if (downloading)
                PortalLoading(message: progress)
              else if (progress.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(progress),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: downloading || selected.isEmpty
                          ? null
                          : download,
                      icon: const Icon(Icons.download),
                      label: Text('Download selected (${selected.length})'),
                    ),
                    TextButton(
                      onPressed: downloading ? null : load,
                      child: const Text('Refresh'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
  );
}
