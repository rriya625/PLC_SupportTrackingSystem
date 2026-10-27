import '../widgets/portal_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:ticket_tracker_app/widgets/message_popup.dart';
import 'package:ticket_tracker_app/widgets/portal_loading.dart';
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
  String customer = '', sender = '';
  String messageStatus = 'CURRENT';
  static const statusLabels = {
    'CURRENT': 'Current messages',
    'DELETED': 'Deleted messages',
    'ALL': 'All messages',
  };

  Future<void> chooseStatus() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Message status'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: statusLabels.entries
                .map(
                  (entry) => ListTile(
                    title: Text(entry.value),
                    trailing: entry.key == messageStatus
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () => Navigator.pop(c, entry.key),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (selected != null && mounted && selected != messageStatus) {
      setState(() => messageStatus = selected);
      await searchMessages();
    }
  }

  DateTime? fromDate, toDate;
  List<Map<String, dynamic>>? customerOptions, senderOptions;
  Map<String, String> appliedFilters = {};
  bool pickingFilter = false;

  @override
  void initState() {
    super.initState();
    if (!Constants.isEmployee) {
      customer = Constants.qbLinkKey;
      customerOptions = [
        {
          'Code': customer,
          'Name': Constants.departmentName.isEmpty
              ? customer
              : Constants.departmentName,
        },
      ];
    }
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
        appliedFilters.isEmpty ? 'GetMessages' : 'GetMessagesByStatus',
        query: {
          ...appliedFilters,
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

  String dateText(DateTime? date) =>
      date == null ? 'Any date' : date.toIso8601String().substring(0, 10);
  String filterLabel(bool isCustomer) {
    final value = isCustomer ? customer : sender;
    final options = isCustomer ? customerOptions : senderOptions;
    if (value.isEmpty) return isCustomer ? 'All customers' : 'Anyone';
    final found = options?.where((o) => o['Code'] == value);
    return found != null && found.isNotEmpty
        ? found.first['Name'].toString()
        : value;
  }

  Future<void> chooseFilter(bool isCustomer) async {
    if (isCustomer && !Constants.isEmployee) return;
    if (pickingFilter || busy) return;
    pickingFilter = true;
    try {
      var options = isCustomer ? customerOptions : senderOptions;
      if (options == null) {
        final result = await withPortalLoading(
          context,
          isCustomer ? 'Loading customers...' : 'Loading senders...',
          () => api.call(
            'GetMessageFilterOptions',
            query: {
              'FilterType': isCustomer ? 'CUSTOMER' : 'SENDER',
              'QBLinkKey': customer,
            },
          ),
        );
        options = List<Map<String, dynamic>>.from(result['Data'] ?? []);
        if (isCustomer) {
          customerOptions = options;
        } else {
          senderOptions = options;
        }
      }
      if (!mounted) return;
      final choices = options;
      var search = '';
      final selected = await showDialog<String>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, update) {
            final filtered = choices!
                .where(
                  (o) => '${o['Code']} ${o['Name']}'.toLowerCase().contains(
                    search.toLowerCase(),
                  ),
                )
                .toList();
            return AlertDialog(
              title: Text(isCustomer ? 'Customer' : 'From'),
              content: SizedBox(
                width: 520,
                height: MediaQuery.sizeOf(c).height * 0.45,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Search'),
                      onChanged: (v) => update(() => search = v),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length + 1,
                        itemBuilder: (c, i) => ListTile(
                          title: Text(
                            i == 0
                                ? (isCustomer ? 'All customers' : 'Anyone')
                                : filtered[i - 1]['Name'].toString(),
                          ),
                          subtitle: i > 0 && isCustomer
                              ? Text(filtered[i - 1]['Code'].toString())
                              : null,
                          onTap: () => Navigator.pop(
                            c,
                            i == 0 ? '' : filtered[i - 1]['Code'].toString(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        ),
      );
      if (selected != null && mounted)
        setState(() {
          if (isCustomer) {
            customer = selected;
            sender = '';
            senderOptions = null;
          } else {
            sender = selected;
          }
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      pickingFilter = false;
    }
  }

  Future<void> chooseDate(bool first) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (first ? fromDate : toDate) ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected != null && mounted)
      setState(() {
        if (first) {
          fromDate = selected;
        } else {
          toDate = selected;
        }
      });
  }

  Future<void> searchMessages() async {
    if (fromDate != null && toDate != null && toDate!.isBefore(fromDate!)) {
      setState(() => error = 'To date must not be before From date.');
      return;
    }
    appliedFilters = {
      'Status': messageStatus,
      'QBLinkKey': customer,
      'SenderID': sender,
      'DateFrom': fromDate == null ? '' : dateText(fromDate),
      'DateTo': toDate == null ? '' : dateText(toDate),
    };
    await load();
  }

  Future<void> clearFilters() async {
    setState(() {
      customer = Constants.isEmployee ? '' : Constants.qbLinkKey;
      messageStatus = 'CURRENT';
      sender = '';
      fromDate = null;
      toDate = null;
      senderOptions = null;
      appliedFilters = {};
      error = null;
    });
    await load();
  }

  Widget filters() => ExpansionTile(
    title: const Text('Message filters'),
    initiallyExpanded: true,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: LayoutBuilder(
          builder: (context, size) {
            final width = size.maxWidth >= 650
                ? (size.maxWidth - 12) / 2
                : size.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: width,
                  child: OutlinedButton(
                    onPressed: busy || !Constants.isEmployee
                        ? null
                        : () => chooseFilter(true),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Customer: ${filterLabel(true)}',
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                          ),
                        ),
                        Icon(
                          Constants.isEmployee
                              ? Icons.arrow_drop_down
                              : Icons.lock_outline,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: OutlinedButton(
                    onPressed: busy ? null : () => chooseFilter(false),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'From: ${filterLabel(false)}',
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => chooseDate(true),
                  child: Text('From date: ${dateText(fromDate)}'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => chooseDate(false),
                  child: Text('To date: ${dateText(toDate)}'),
                ),
                SizedBox(
                  width: size.maxWidth < 270 ? size.maxWidth : 270,
                  child: OutlinedButton(
                    onPressed: busy ? null : chooseStatus,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Status: ${statusLabels[messageStatus]}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: busy ? null : searchMessages,
                  child: const Text('Search'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : clearFilters,
                  child: const Text('Clear'),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
  Future<void> deleteRow(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'Move this message to Deleted in your queue? The database record and other recipients’ copies are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await withPortalLoading(
        context,
        'Deleting message...',
        () => api.call(
          'DeletePortalMessage',
          body: {'MessageKey': row['MessageKey'], 'Confirmed': true},
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

  Future<void> open(Map<String, dynamic> row) async {
    try {
      final result = await withPortalLoading(
        context,
        'Loading message...',
        () => api.call(
          'ReadPortalMessage',
          body: {'MessageKey': row['MessageKey']},
        ),
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
    appBar: PortalAppBar(
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
        await showMessagePopup(
          context,
          tall: true,
          builder: (_) => MessageComposeScreen(
            api: api,
            initialCustomer: customer,
            initialSender: sender,
          ),
        );
        if (mounted) await load();
      },
      icon: const Icon(Icons.add),
      label: const Text('New message'),
    ),
    body: Column(
      children: [
        filters(),
        if (busy)
          const Center(child: PortalLoading(message: 'Loading messages...')),
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
                trailing: row['CanDelete'] == true && row['Deleted'] != true
                    ? IconButton(
                        tooltip: 'Delete message',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: busy ? null : () => deleteRow(row),
                      )
                    : null,
                leading: Icon(
                  row['Deleted'] == true
                      ? Icons.delete_outline
                      : row['Unread'] == true
                      ? Icons.mark_email_unread
                      : Icons.drafts_outlined,
                ),
                title: Text(
                  row['MsgFrom']?.toString() ?? '',
                  style: TextStyle(fontWeight: weight),
                ),
                subtitle: Text(
                  '${row['Deleted'] == true ? 'Deleted • ' : ''}${row['DateSent']} ${_ticketLabel(row)}\n${row['Message']}',
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
      appBar: PortalAppBar(
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
              if (m['Deleted'] == true)
                const Text('Deleted message — kept for reference.'),
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
                          : () => showMessagePopup(
                              context,
                              builder: (_) => MessageComposeScreen(
                                api: widget.api,
                                reply: m,
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
                  if (m['CanDelete'] == true)
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
  const MessageComposeScreen({
    super.key,
    required this.api,
    this.reply,
    this.initialCustomer = '',
    this.initialSender = '',
  });
  final String initialCustomer, initialSender;
  final MessagesApi api;
  final Map<String, dynamic>? reply;
  @override
  State<MessageComposeScreen> createState() => _MessageComposeScreenState();
}

class _MessageComposeScreenState extends State<MessageComposeScreen> {
  Timer? ticketDebounce;
  final customerSearch = TextEditingController();
  String? selectedCustomer, ticketDescription;
  List<Map<String, String>> customers = [];
  bool ticketLoading = false;
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
      if (kind == 'CUSTOMER' &&
          recipient != null &&
          !options.any(
            (o) => o['ID'] == recipient && o['Name'] == search.text,
          )) {
        setState(() => recipient = null);
      }
    });
    customerSearch.addListener(() {
      if (selectedCustomer != null &&
          !customers.any(
            (c) =>
                c['ID'] == selectedCustomer && c['Name'] == customerSearch.text,
          )) {
        setState(() {
          selectedCustomer = null;
          recipient = null;
          options = [];
          search.clear();
        });
      }
    });
    ticket.addListener(() {
      ticketDebounce?.cancel();
      setState(() {
        ticketDescription = null;
        ticketLoading = false;
      });
      ticketDebounce = Timer(const Duration(milliseconds: 600), loadTicket);
    });
    final linkedTicket = widget.reply?['TicketKey']?.toString() ?? '';
    if (linkedTicket.isNotEmpty && linkedTicket != '0')
      ticket.text = linkedTicket;
    if (widget.reply == null) initializeRecipient();
  }

  Future<void> initializeRecipient() async {
    if (!Constants.isEmployee || widget.initialCustomer.isEmpty) {
      await loadGroups();
      return;
    }
    kind = 'CUSTOMER';
    await loadCustomers();
    if (!mounted || kind != 'CUSTOMER') return;
    final matches = customers.where((c) => c['ID'] == widget.initialCustomer);
    if (matches.isEmpty) return;
    customerSearch.text = matches.first['Name']!;
    await chooseCustomer(widget.initialCustomer);
    if (!mounted ||
        kind != 'CUSTOMER' ||
        selectedCustomer != widget.initialCustomer)
      return;
    final id = widget.initialSender.startsWith('P:')
        ? widget.initialSender.substring(2)
        : '';
    final contacts = options.where((c) => c['ID'] == id);
    if (contacts.isNotEmpty) {
      search.text = contacts.first['Name']!;
      setState(() => recipient = id);
    }
  }

  @override
  void dispose() {
    ticketDebounce?.cancel();
    customerSearch.dispose();
    text.dispose();
    ticket.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> loadTicket() async {
    final key = ticket.text.trim();
    if (int.tryParse(key) == null || int.parse(key) <= 0) return;
    setState(() => ticketLoading = true);
    try {
      final details = await widget.api.ticketDetails(key);
      if (mounted && ticket.text.trim() == key)
        setState(
          () => ticketDescription =
              details?['ShortDesc']?.toString() ?? 'Ticket unavailable',
        );
    } catch (_) {
      if (mounted && ticket.text.trim() == key)
        setState(() => ticketDescription = 'Ticket unavailable');
    } finally {
      if (mounted && ticket.text.trim() == key)
        setState(() => ticketLoading = false);
    }
  }

  Future<void> loadCustomers() async {
    final generation = ++searchGeneration;
    setState(() {
      searching = true;
      options = [];
      recipient = null;
    });
    try {
      final result = await widget.api.call(
        'GetMessageRecipients',
        query: {'RecipientType': 'CUSTOMER_LIST', 'Search': ''},
      );
      if (!mounted || generation != searchGeneration) return;
      setState(
        () => customers = (result['Data'] as List)
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

  Future<void> chooseCustomer(String? code) async {
    setState(() {
      selectedCustomer = code;
      recipient = null;
      options = [];
      search.clear();
    });
    if (code != null) await find();
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
        query: {
          'RecipientType': kind == 'CUSTOMER' ? 'CUSTOMER_CONTACT' : kind,
          'Search': kind == 'CUSTOMER'
              ? (selectedCustomer ?? '')
              : search.text.trim(),
        },
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
    appBar: PortalAppBar(
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
                LayoutBuilder(
                  builder: (context, constraints) => SegmentedButton<String>(
                    direction: constraints.maxWidth < 340
                        ? Axis.vertical
                        : Axis.horizontal,
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
                            } else if (kind == 'CUSTOMER') {
                              selectedCustomer = null;
                              customerSearch.clear();
                              loadCustomers();
                            } else {
                              find();
                            }
                          },
                  ),
                ),
              const SizedBox(height: 12),
              if (searching && kind != 'GROUP')
                const PortalLoading(message: 'Loading recipients...'),
              if (kind == 'CUSTOMER') ...[
                LayoutBuilder(
                  builder: (context, constraints) => DropdownMenu<String>(
                    controller: customerSearch,
                    width: constraints.maxWidth,
                    menuHeight: 280,
                    requestFocusOnTap: true,
                    enableFilter: true,
                    enableSearch: true,
                    label: const Text('Select customer'),
                    enabled: !busy && !searching,
                    dropdownMenuEntries: customers
                        .map(
                          (c) => DropdownMenuEntry(
                            value: c['ID']!,
                            label: c['Name']!,
                          ),
                        )
                        .toList(),
                    onSelected: chooseCustomer,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              LayoutBuilder(
                builder: (context, constraints) => DropdownMenu<String>(
                  key: ValueKey(kind),
                  controller: kind == 'CUSTOMER' ? search : null,
                  width: constraints.maxWidth,
                  initialSelection: recipient,
                  enabled:
                      !busy &&
                      !searching &&
                      (kind != 'CUSTOMER' || selectedCustomer != null),
                  enableFilter: true,
                  enableSearch: true,
                  requestFocusOnTap: true,
                  label: Text(kind == 'CUSTOMER' ? 'Select contact' : 'To'),
                  helperText: kind == 'CUSTOMER'
                      ? 'Search contacts for the selected customer.'
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
            if (ticketLoading)
              const PortalLoading(message: 'Loading ticket...'),
            if (ticketDescription != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Ticket #${ticket.text.trim()} - $ticketDescription',
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: text,
              autofocus: widget.reply != null,
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
