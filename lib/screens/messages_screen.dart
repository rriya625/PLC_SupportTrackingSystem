import 'package:flutter/material.dart';
import 'dart:async';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/utils/messages_api.dart';
import 'ticket_description_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.api});
  final MessagesApi? api;
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late final MessagesApi api = widget.api ?? MessagesApi();
  final List<Map<String, dynamic>> rows = [];
  bool busy = false, more = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool next = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await api.call(
        'GetMessages',
        query: {
          'BeforeKey': next && rows.isNotEmpty
              ? rows.last['MessageKey'].toString()
              : '0',
          'PageSize': '50',
        },
      );
      if (!mounted) return;
      setState(() {
        if (!next) rows.clear();
        rows.addAll(
          (result['Data'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
        more = result['HasMore'] == true;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(Map<String, dynamic> row) async {
    try {
      final result = await api.call(
        'ReadPortalMessage',
        body: {'MessageKey': row['MessageKey']},
      );
      if (!mounted) return;
      setState(() => row['Unread'] = false);
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _MessageDetail(
            message: Map<String, dynamic>.from(result['Data']),
            api: api,
          ),
        ),
      );
      if (mounted) await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Messages'),
      backgroundColor: Colors.blue[800],
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: busy ? null : () => load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MessageComposeScreen(api: api)),
        );
        if (mounted) await load();
      },
      icon: const Icon(Icons.add),
      label: const Text('New message'),
    ),
    body: Column(
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        if (!busy && rows.isEmpty && error == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No received messages.'),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 90),
            itemCount: rows.length + (more ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == rows.length)
                return TextButton(
                  onPressed: busy ? null : () => load(next: true),
                  child: const Text('Load more'),
                );
              final row = rows[i];
              final weight = row['Unread'] == true
                  ? FontWeight.bold
                  : FontWeight.normal;
              return ListTile(
                leading: Icon(
                  row['Unread'] == true
                      ? Icons.mark_email_unread
                      : Icons.drafts_outlined,
                ),
                title: Text(
                  row['MsgFrom']?.toString() ?? '',
                  style: TextStyle(fontWeight: weight),
                ),
                subtitle: Text(
                  '${row['DateSent']} ${_ticketLabel(row)}\n${row['Message']}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: weight),
                ),
                onTap: () => open(row),
              );
            },
          ),
        ),
      ],
    ),
  );
}

int _number(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
String _ticketLabel(Map<String, dynamic> m) =>
    _number(m['TicketKey']) > 0 ? '• Ticket #${m['TicketKey']}' : '';

class _MessageDetail extends StatefulWidget {
  const _MessageDetail({required this.message, required this.api});
  final Map<String, dynamic> message;
  final MessagesApi api;
  @override
  State<_MessageDetail> createState() => _MessageDetailState();
}

class _MessageDetailState extends State<_MessageDetail> {
  bool busy = false;
  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove message?'),
        content: const Text(
          'This removes the message from your portal inbox only. Other recipients keep their copies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.api.call(
        'DeletePortalMessage',
        body: {'MessageKey': widget.message['MessageKey'], 'Confirmed': true},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Details'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                m['MsgFrom']?.toString() ?? '',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(m['DateSent']?.toString() ?? ''),
              const SizedBox(height: 20),
              SelectableText(m['Message']?.toString() ?? ''),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (m['CanReply'] == true)
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MessageComposeScreen(
                                  api: widget.api,
                                  reply: m,
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.reply),
                      label: const Text('Reply'),
                    ),
                  if (_number(m['TicketKey']) > 0)
                    OutlinedButton.icon(
                      onPressed: () async {
                        // Return through the detail route so the inbox refresh waits for ticket closure.
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const TicketDescriptionScreenStateful(),
                            settings: RouteSettings(
                              arguments: m['TicketKey'].toString(),
                            ),
                          ),
                        );
                        if (mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.confirmation_number_outlined),
                      label: Text('Open ticket #${m['TicketKey']}'),
                    ),
                  if (Constants.isEmployee && m['CanDelete'] == true)
                    OutlinedButton.icon(
                      onPressed: busy ? null : remove,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageComposeScreen extends StatefulWidget {
  const MessageComposeScreen({super.key, required this.api, this.reply});
  final MessagesApi api;
  final Map<String, dynamic>? reply;
  @override
  State<MessageComposeScreen> createState() => _MessageComposeScreenState();
}

class _MessageComposeScreenState extends State<MessageComposeScreen> {
  Timer? recipientDebounce;
  final text = TextEditingController(),
      ticket = TextEditingController(),
      search = TextEditingController();
  String kind = 'GROUP';
  String? recipient, error;
  List<Map<String, String>> options = [];
  bool busy = false, searching = false;
  int searchGeneration = 0;
  @override
  void initState() {
    super.initState();
    search.addListener(() {
      if (kind != 'CUSTOMER') return;
      recipientDebounce?.cancel();
      recipientDebounce = Timer(const Duration(milliseconds: 300), () {
        if (!mounted || kind != 'CUSTOMER') return;
        if (recipient != null &&
            options.any(
              (o) => o['ID'] == recipient && o['Name'] == search.text,
            ))
          return;
        find();
      });
    });
    if (widget.reply == null) loadGroups();
  }

  @override
  void dispose() {
    recipientDebounce?.cancel();
    text.dispose();
    ticket.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> loadGroups() async {
    final generation = ++searchGeneration;
    setState(() => searching = true);
    try {
      final groups = await widget.api.groups();
      if (!mounted || generation != searchGeneration) return;
      setState(() {
        options = groups.map((s) => {'ID': s, 'Name': s}).toList();
        recipient = options.isEmpty ? null : options.first['ID'];
      });
    } catch (e) {
      if (mounted && generation == searchGeneration)
        setState(() => error = e.toString());
    } finally {
      if (mounted && generation == searchGeneration)
        setState(() => searching = false);
    }
  }

  Future<void> find() async {
    final generation = ++searchGeneration;
    setState(() {
      searching = true;
      error = null;
      recipient = null;
    });
    try {
      final result = await widget.api.call(
        'GetMessageRecipients',
        query: {'RecipientType': kind, 'Search': search.text.trim()},
      );
      if (!mounted || generation != searchGeneration) return;
      setState(
        () => options = (result['Data'] as List)
            .map(
              (e) => {'ID': e['ID'].toString(), 'Name': e['Name'].toString()},
            )
            .toList(),
      );
    } catch (e) {
      if (mounted && generation == searchGeneration)
        setState(() => error = e.toString());
    } finally {
      if (mounted && generation == searchGeneration)
        setState(() => searching = false);
    }
  }

  Future<void> send() async {
    if (busy) return;
    final ticketKey = ticket.text.trim().isEmpty
        ? 0
        : int.tryParse(ticket.text.trim());
    if (text.text.trim().isEmpty ||
        (widget.reply == null && recipient == null) ||
        ticketKey == null ||
        ticketKey < 0) {
      setState(
        () => error =
            'Enter a message, choose a recipient, and use a valid optional ticket number.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.call(
        'SendPortalMessage',
        body: {
          'TicketKey': ticketKey,
          'RecipientType': kind,
          'RecipientID': recipient ?? '',
          'MessageText': text.text.trim(),
          'ReplyToMessageKey': widget.reply?['MessageKey'] ?? 0,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message sent.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.reply == null ? 'Send Message' : 'Reply to Message'),
      backgroundColor: Colors.blue[800],
      foregroundColor: Colors.white,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.reply != null)
              Text(
                'Reply to: ${widget.reply!['MsgFrom']} ${_ticketLabel(widget.reply!)}',
              ),
            if (widget.reply == null) ...[
              const Text('Agency: Porter Lee'),
              const SizedBox(height: 12),
              Text('Name: ${Constants.contactName}'),
              const SizedBox(height: 24),
              const Text('Send your message to:'),
              if (Constants.isEmployee)
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'GROUP', label: Text('Group')),
                    ButtonSegment(value: 'EMPLOYEE', label: Text('Employee')),
                    ButtonSegment(value: 'CUSTOMER', label: Text('Customer')),
                  ],
                  selected: {kind},
                  onSelectionChanged: busy
                      ? null
                      : (values) {
                          setState(() {
                            kind = values.first;
                            recipient = null;
                            options = [];
                            error = null;
                            search.clear();
                          });
                          if (kind == 'GROUP') {
                            loadGroups();
                          } else {
                            find();
                          }
                        },
                ),
              const SizedBox(height: 12),
              if (searching) const LinearProgressIndicator(),
              LayoutBuilder(
                builder: (context, constraints) => DropdownMenu<String>(
                  key: ValueKey(kind),
                  controller: kind == 'CUSTOMER' ? search : null,
                  width: constraints.maxWidth,
                  initialSelection: recipient,
                  enabled: !busy,
                  enableFilter: kind != 'CUSTOMER',
                  enableSearch: true,
                  requestFocusOnTap: true,
                  label: const Text('To'),
                  helperText: kind == 'CUSTOMER'
                      ? 'Type to search customers by name, ID or department.'
                      : null,
                  dropdownMenuEntries: options
                      .map(
                        (o) => DropdownMenuEntry(
                          value: o['ID']!,
                          label: o['Name']!,
                        ),
                      )
                      .toList(),
                  onSelected: (v) => setState(() => recipient = v),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ticket,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ticket number (optional)',
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: text,
              autofocus: true,
              minLines: 10,
              maxLines: 12,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: 'Enter your message here',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy || searching ? null : send,
                    icon: const Icon(Icons.send),
                    label: Text(busy ? 'Sending…' : 'Submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlueAccent,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
