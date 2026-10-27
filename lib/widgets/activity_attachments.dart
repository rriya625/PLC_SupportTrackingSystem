import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../utils/activity_fields.dart';
import '../utils/api_helper.dart';

class ActivityAttachments extends ChangeNotifier {
  final List<PlatformFile> files = [];
  bool busy = false;
  bool activitySaved = false;
  int historyNumber = 0;
  String? message;
  bool _disposed = false;

  void changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> save(
    int ticketKey,
    Future<Map<String, dynamic>> Function() create, {
    Future<void> Function(int, int, PlatformFile)? upload,
  }) async {
    if (busy) return;
    busy = true;
    message = null;
    notifyListeners();
    try {
      if (!activitySaved) {
        final result = await create();
        if (result['Code'] != null && result['Code'].toString() != '300') {
          throw Exception(result['Message'] ?? 'Activity could not be saved.');
        }
        activitySaved = true;
        historyNumber = activityNumber(result);
      }
      if (files.isNotEmpty && historyNumber <= 0) {
        throw Exception(
          'Activity saved, but the server did not return its number. Close and refresh before attaching documents.',
        );
      }
      while (files.isNotEmpty) {
        final file = files.first;
        await (upload ??
            ((t, n, f) => APIHelper.uploadActivityDocument(
              ticketKey: t,
              historyNumber: n,
              fileName: f.name,
              bytes: f.bytes!,
            )))(ticketKey, historyNumber, file);
        files.removeAt(0);
        notifyListeners();
      }
    } catch (error) {
      message = activitySaved
          ? 'Activity saved. Some documents were not uploaded. Retry uploads; the activity will not be created again. $error'
          : error.toString();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

class ActivityAttachmentPicker extends StatelessWidget {
  final ActivityAttachments draft;
  const ActivityAttachmentPicker({super.key, required this.draft});

  Future<void> _pick(BuildContext context) async {
    try {
      final selected = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (!context.mounted || selected == null) return;
      for (final file in selected.files) {
        if (file.bytes == null ||
            file.size == 0 ||
            file.size > 10 * 1024 * 1024) {
          throw Exception(
            '${file.name}: choose a file between 1 byte and 10 MB.',
          );
        }
        if (draft.files.any(
          (f) => f.name.toLowerCase() == file.name.toLowerCase(),
        )) {
          throw Exception('${file.name} is already attached.');
        }
        draft.files.add(file);
      }
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      draft.changed();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: draft,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (draft.message != null)
          Text(draft.message!, style: const TextStyle(color: Colors.red)),
        OutlinedButton.icon(
          onPressed: draft.busy ? null : () => _pick(context),
          icon: const Icon(Icons.attach_file),
          label: const Text('Attach Documents'),
        ),
        const Text('Up to 10 MB per file. Files upload when you save.'),
        for (final file in draft.files.toList())
          ListTile(
            title: Text(file.name),
            trailing: IconButton(
              tooltip: 'Remove attachment',
              icon: const Icon(Icons.close),
              onPressed: draft.busy
                  ? null
                  : () async {
                      final remove = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Remove attachment?'),
                          content: Text(file.name),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (remove == true) {
                        draft.files.remove(file);
                        draft.changed();
                      }
                    },
            ),
          ),
      ],
    ),
  );
}
