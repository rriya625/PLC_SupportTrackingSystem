import 'package:flutter/material.dart';
import '../utils/messages_api.dart';
import '../widgets/portal_app_bar.dart';
import '../widgets/portal_loading.dart';
import 'ticket_description_screen.dart';

class WorkTicketsScreen extends StatefulWidget {
  const WorkTicketsScreen({super.key, required this.query, this.api});
  final Map<String, String> query;
  final MessagesApi? api;
  @override
  State<WorkTicketsScreen> createState() => _WorkTicketsState();
}

class _WorkTicketsState extends State<WorkTicketsScreen> {
  bool busy = true;
  String error = '';
  List<Map<String, dynamic>> rows = [];
  @override
  void initState() { super.initState(); load(); }

  Future<void> openTicket(String key, {bool replace = false}) async {
    final route = MaterialPageRoute<void>(
      builder: (_) => const TicketDescriptionScreenStateful(),
      settings: RouteSettings(arguments: key));
    if (replace) {
      await Navigator.pushReplacement(context, route);
    } else {
      await Navigator.push(context, route);
    }
  }

  Future<void> load() async {
    setState(() { busy = true; error = ''; });
    try {
      final result = await (widget.api ?? MessagesApi()).call('GetWorkTickets', query: widget.query);
      if (!mounted) return;
      rows = (result['Data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (rows.length == 1) {
        await openTicket('${rows.single['TicketKey']}', replace: true);
      }
    } catch (e) {
      if (mounted) error = '$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: PortalAppBar(title: const Text('Matching Tickets'),
      backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
    body: busy ? const Align(alignment: Alignment.topCenter,
        child: PortalLoading(message: 'Loading matching tickets...'))
      : error.isNotEmpty ? Align(alignment: Alignment.topCenter, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error), TextButton(onPressed: load, child: const Text('Retry'))]))
      : rows.isEmpty ? const Align(alignment: Alignment.topCenter,
          child: Padding(padding: EdgeInsets.all(20), child: Text(
            'No matching tickets are available with your ticket permissions.', textAlign: TextAlign.center)))
      : Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: Text(
            '${widget.query['FromDate']} – ${widget.query['ToDate']} · ${rows.length} tickets\n'
            'Only tickets you have permission to view are listed.')),
          Expanded(child: ListView.builder(itemCount: rows.length, itemBuilder: (context, index) {
            final row = rows[index];
            return ListTile(
              title: Text('#${row['TicketKey']} · ${row['ShortDesc']}'),
              subtitle: Text('${row['QBLinkKey']} · ${row['ActivityCount']} matching activities'),
              trailing: const Icon(Icons.chevron_right, color: Colors.blue),
              onTap: () => openTicket('${row['TicketKey']}'));
          })),
        ]),
  );
}
