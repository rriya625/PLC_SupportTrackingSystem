import 'package:ticket_tracker_app/utils/diagnostic_http_client.dart';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/utils/api_helper.dart';

class ViewActivityScreen extends StatefulWidget {
  final String ticketNumber;
  final String shortDescription;
  final String confirmationEmailTo;

  const ViewActivityScreen({
    super.key,
    required this.ticketNumber,
    required this.shortDescription,
    this.confirmationEmailTo = '',
  });

  @override
  State<ViewActivityScreen> createState() => _ViewActivityScreenState();
}

class _ViewActivityScreenState extends State<ViewActivityScreen> {
  List<Map<String, dynamic>> activityData = [];
  Map<String, List<Map<String, dynamic>>> activityOptions = const {};
  bool loading = true;

  int get _ticketKey => int.tryParse(widget.ticketNumber) ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final results = await Future.wait<dynamic>([
        APIHelper.getActivityMessages(widget.ticketNumber),
        if (Constants.isEmployee) APIHelper.getActivityOptions(),
      ]);
      if (!mounted) return;
      setState(() {
        activityData = results.first as List<Map<String, dynamic>>;
        if (Constants.isEmployee && results.length > 1) {
          activityOptions =
              results[1] as Map<String, List<Map<String, dynamic>>>;
        }
      });
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _value(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null) return value.toString();
    }
    return '';
  }

  bool _flag(Map<String, dynamic> item, String key) {
    final value = item[key];
    return value == true || value?.toString().toUpperCase() == 'Y';
  }

  String _rawDescription(Map<String, dynamic> item) =>
      _value(item, const ['RawLongDesc', 'LongDesc']);

  int _historyNumber(Map<String, dynamic> item) =>
      int.tryParse(
        _value(item, const ['HistoryNumber', 'History Number', 'HistoryNo']),
      ) ??
      0;

  String _code(Map<String, dynamic> option) =>
      _value(option, const ['Code', 'code']);

  String _description(Map<String, dynamic> option) =>
      _value(option, const ['Description', 'description', 'Code']);

  void _showError(Object error) {
    final message = error is ApiException
        ? switch (error.statusCode) {
            403 => 'Access denied.',
            404 => 'The requested record was not found.',
            409 =>
              'This record changed after you opened it. Your draft was preserved.',
            503 => 'This feature is not enabled on the server.',
            _ => error.message,
          }
        : error.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCreateActivityDialog() async {
    if (!Constants.isEmployee) {
      await _showLegacyCreateDialog();
      return;
    }
    final types = activityOptions['ActivityTypes'] ?? const [];
    final statuses = activityOptions['Statuses'] ?? const [];
    final priorities = activityOptions['Priorities'] ?? const [];
    String? type = types.isEmpty ? null : _code(types.first);
    String? status = statuses.isEmpty ? null : _code(statuses.first);
    String? priority = priorities.any((e) => _code(e) == '5')
        ? '5'
        : (priorities.isEmpty ? null : _code(priorities.first));
    bool critical = false;
    bool webPosting = false;
    bool submitting = false;
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Employee Activity'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _optionDropdown('Activity Type', types, type, (value) {
                    setDialogState(() => type = value);
                  }),
                  const SizedBox(height: 12),
                  _optionDropdown('Status', statuses, status, (value) {
                    setDialogState(() => status = value);
                  }),
                  const SizedBox(height: 12),
                  _optionDropdown('Priority', priorities, priority, (value) {
                    setDialogState(() => priority = value);
                  }),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 7,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: critical,
                    onChanged: (value) =>
                        setDialogState(() => critical = value ?? false),
                    title: const Text('Critical'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: webPosting,
                    onChanged: (value) =>
                        setDialogState(() => webPosting = value ?? false),
                    title: const Text('Visible to customer'),
                    subtitle: const Text(
                      'Off keeps this activity internal. Saving never sends email.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (controller.text.trim().isEmpty ||
                          type == null ||
                          status == null ||
                          priority == null) {
                        _showError(
                          const ApiException(
                            400,
                            'Complete all required fields.',
                          ),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        await APIHelper.createEmployeeActivity(
                          ticketKey: _ticketKey,
                          longDesc: controller.text.trim(),
                          activityType: type!,
                          status: status!,
                          priority: priority!,
                          critical: critical,
                          webPosting: webPosting,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _load();
                      } catch (error) {
                        if (mounted) _showError(error);
                        setDialogState(() => submitting = false);
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Widget _optionDropdown(
    String label,
    List<Map<String, dynamic>> options,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: options.any((item) => _code(item) == value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (item) => DropdownMenuItem(
              value: _code(item),
              child: Text('${_code(item)} - ${_description(item)}'),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _showLegacyCreateDialog() async {
    final controller = TextEditingController();
    bool critical = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Activity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
              CheckboxListTile(
                value: critical,
                onChanged: (value) =>
                    setDialogState(() => critical = value ?? false),
                title: const Text('Critical'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                try {
                  final response = await diagnosticHttpClient.post(
                    Uri.parse('${Constants.baseUrlData}CreateActivity'),
                    headers: {
                      'Authorization': 'Bearer ${Constants.accessToken}',
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode({
                      'TicketKey': _ticketKey,
                      'ProspectKey': Constants.userID,
                      'LongDesc': controller.text.trim(),
                      'Priority': '5',
                      'Critical': critical ? 'Y' : 'N',
                    }),
                  );
                  if (response.statusCode < 200 || response.statusCode >= 300) {
                    throw ApiException(
                      response.statusCode,
                      'Failed to create activity.',
                    );
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await _load();
                } catch (error) {
                  if (mounted) _showError(error);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _editActivity(Map<String, dynamic> item) async {
    final original = _rawDescription(item);
    final controller = TextEditingController(
      text: _value(item, const ['LongDesc', 'RawLongDesc']),
    );
    final draft = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit activity #${_historyNumber(item)}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Saving replaces any legacy rich-text formatting with plain text.',
              ),
              const SizedBox(height: 12),
              TextField(controller: controller, maxLines: 10),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (draft == null || draft.isEmpty || draft == original) return;
    try {
      await APIHelper.updateActivity(
        ticketKey: _ticketKey,
        historyNumber: _historyNumber(item),
        longDesc: draft,
        expectedLongDesc: original,
      );
      await _load();
    } catch (error) {
      _showError(error);
      if (error is ApiException && error.statusCode == 409) await _load();
    }
  }

  Future<void> _deleteActivity(Map<String, dynamic> item) async {
    final number = _historyNumber(item);
    final preview = _value(item, const ['LongDesc']).trim();
    final isClosure = _value(item, const ['Status', 'StatusCode']) == 'C';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete activity #$number?'),
        content: Text(
          '${preview.length > 160 ? '${preview.substring(0, 160)}…' : preview}'
          '${isClosure ? '\n\nThis does not reopen the ticket. Add a new activity to change status.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await APIHelper.deleteActivity(
        ticketKey: _ticketKey,
        historyNumber: number,
        expectedLongDesc: _rawDescription(item),
      );
      await _load();
    } catch (error) {
      _showError(error);
      if (error is ApiException && error.statusCode == 409) await _load();
    }
  }

  String _newRequestId() {
    final random = Random.secure();
    String hex(int length) => List.generate(
      length,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '{${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + random.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}}';
  }

  Future<void> _sendEmail(Map<String, dynamic> item) async {
    final to = TextEditingController(text: widget.confirmationEmailTo);
    final subject = TextEditingController(
      text: 'PLC Support Ticket #${widget.ticketNumber}',
    );
    final body = TextEditingController(text: _value(item, const ['LongDesc']));
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Email activity #${_historyNumber(item)}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  'Review the plain-text email. Saving an activity never sends it automatically.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: to,
                  decoration: const InputDecoration(labelText: 'To'),
                ),
                TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                TextField(
                  controller: body,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'Body'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'to': to.text.trim(),
              'subject': subject.text.trim(),
              'body': body.text,
            }),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    to.dispose();
    subject.dispose();
    body.dispose();
    if (payload == null ||
        payload['to']!.isEmpty ||
        payload['subject']!.isEmpty)
      return;
    final requestId = _newRequestId();
    try {
      final response = await APIHelper.queueActivityEmail(
        ticketKey: _ticketKey,
        historyNumber: _historyNumber(item),
        recipients: payload['to']!,
        subject: payload['subject']!,
        body: payload['body']!,
        requestId: requestId,
      );
      if (!mounted) return;
      final status =
          (response['DeliveryStatus'] ??
                  (response['Data'] is Map
                      ? response['Data']['DeliveryStatus']
                      : ''))
              .toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'QUEUED' ? 'Email queued' : 'Email request accepted',
          ),
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Activity'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateActivityDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Activity'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Text(
                    'Activities for Ticket #${widget.ticketNumber}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(widget.shortDescription),
                  const SizedBox(height: 12),
                  if (activityData.isEmpty) const Text('No activities found.'),
                  ...activityData.map((item) {
                    final number = _historyNumber(item);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              number > 0 ? 'Activity #$number' : 'Activity',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Entry Date: ${_value(item, const ['EntryDate'])}',
                            ),
                            Text(
                              'Activity Type: ${_value(item, const ['ActivityType', 'ActivityTypeCode'])}',
                            ),
                            Text(
                              'Entered By: ${_value(item, const ['EnteredBy', 'EnteredByID'])}',
                            ),
                            if (Constants.isEmployee)
                              Text(
                                'Visibility: ${_value(item, const ['WebPosting']) == 'Y' ? 'Customer visible' : 'Internal'}',
                              ),
                            const SizedBox(height: 8),
                            SelectableText(_value(item, const ['LongDesc'])),
                            if (Constants.isEmployee)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    if (_flag(item, 'CanEdit'))
                                      TextButton.icon(
                                        onPressed: () => _editActivity(item),
                                        icon: const Icon(Icons.edit),
                                        label: const Text('Edit'),
                                      ),
                                    if (_flag(item, 'CanDelete'))
                                      TextButton.icon(
                                        onPressed: () => _deleteActivity(item),
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Delete'),
                                      ),
                                    TextButton.icon(
                                      onPressed: () => _sendEmail(item),
                                      icon: const Icon(Icons.email_outlined),
                                      label: const Text('Send email'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
