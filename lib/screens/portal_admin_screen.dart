import 'package:flutter/material.dart';
import '../constants.dart';
import '../utils/messages_api.dart';
import '../widgets/portal_app_bar.dart';
import '../widgets/portal_loading.dart';

class PortalAdminScreen extends StatefulWidget {
  final bool audit;
  final MessagesApi? api;
  const PortalAdminScreen({super.key, this.audit = false, this.api});
  @override
  State<PortalAdminScreen> createState() => _PortalAdminScreenState();
}

class _PortalAdminScreenState extends State<PortalAdminScreen> {
  late final MessagesApi api = widget.api ?? MessagesApi();
  List<Map<String, dynamic>> users = [], types = [], rows = [];
  String? user, action;
  bool loading = true, busy = false, debug = false, skip = false;
  String? error, notice;
  DateTime from = DateTime.now().subtract(const Duration(days: 7)),
      to = DateTime.now();
  final userSearch = TextEditingController();
  @override
  void initState() {
    super.initState();
    userSearch.addListener(_filterUsers);
    load();
  }

  void _filterUsers() {
    if (!mounted) return;
    setState(() {
      if (user != null) {
        final selected = users.where((u) => u['ID'].toString() == user);
        if (selected.isNotEmpty && userSearch.text != label(selected.first)) user = null;
      }
    });
  }
  List<Map<String, dynamic>> get visibleUsers {
    final search = userSearch.text.trim().toLowerCase();
    return users.where((u) => search.isEmpty || label(u).toLowerCase().contains(search)).take(100).toList();
  }
  @override
  void dispose() {
    userSearch.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> data(Map<String, dynamic> result) =>
      List<Map<String, dynamic>>.from(result['Data'] ?? []);
  Future<void> load() async {
    if (!Constants.isPortalAdmin) {
      setState(() {
        loading = false;
        error = 'Access Level 2 is required.';
      });
      return;
    }
    try {
      final list = data(await api.call('GetPortalUsers'));
      final actions = widget.audit
          ? data(await api.call('GetPortalAuditTypes'))
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        users = list;
        types = actions;
        loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e.toString();
          loading = false;
        });
    }
  }

  String label(Map<String, dynamic> u) =>
      '${u['ID']} - ${u['NAME'] ?? ''} - ${u['DEPARTMENT'] ?? ''}';
  void selectUser(String? id) {
    setState(() {
      user = id;
      notice = null;
      if (!widget.audit && id != null) {
        final u = users.firstWhere((u) => u['ID'].toString() == id);
        debug = ['T', 'Y'].contains(u['DEBUG_MODE']?.toString().toUpperCase());
        skip =
            u['DO_NOT_LOAD_TICKETS_ON_LOAD']?.toString().toUpperCase() == 'T';
      }
    });
  }

  Future<void> save() async {
    if (user == null || busy) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await api.call(
        'UpdatePortalUserFlags',
        body: {
          'TargetUserID': int.parse(user!),
          'DebugMode': debug ? 'T' : 'F',
          'DoNotLoadTicketsOnLoad': skip ? 'T' : 'F',
        },
      );
      final u = users.firstWhere((u) => u['ID'].toString() == user);
      u['DEBUG_MODE'] = debug ? 'T' : 'F';
      u['DO_NOT_LOAD_TICKETS_ON_LOAD'] = skip ? 'T' : 'F';
      if (user == Constants.userID.toString()) {
        Constants.debugMode = debug ? 'T' : 'F';
        Constants.doNotLoadTicketsOnLoad = skip ? 'T' : 'F';
      }
      if (mounted)
        setState(
          () => notice =
              'Flags saved. Other users should log out and back in to pick up the changes.',
        );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String date(DateTime d) => d.toIso8601String().substring(0, 10);
  Future<void> search({bool more = false}) async {
    if (busy) return;
    if (to.isBefore(from)) {
      setState(() => error = 'To date must not be before From date.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      if (!more) rows = [];
    });
    try {
      final found = data(
        await api.call(
          'GetPortalAudit',
          query: {
            'UserID': user ?? '0',
            'ActionCode': action ?? '0',
            'BeforeKey': more && rows.isNotEmpty
                ? rows.last['ID'].toString()
                : '0',
            'DateFrom': date(from),
            'DateTo': date(to),
          },
        ),
      );
      if (mounted)
        setState(() {
          rows = more ? [...rows, ...found] : found;
          notice = found.isEmpty ? 'No more activity found.' : null;
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickDate(bool first) async {
    final d = await showDatePicker(
      context: context,
      initialDate: first ? from : to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null && mounted)
      setState(() {
        if (first)
          from = d;
        else
          to = d;
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: PortalAppBar(
      title: Text(widget.audit ? 'Activity Audit' : 'User Flags'),
      backgroundColor: Colors.blue[800],
      foregroundColor: Colors.white,
    ),
    body: loading
        ? const Center(child: PortalLoading(message: 'Loading users...'))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (Constants.isPortalAdmin) ...[
                LayoutBuilder(
                  builder: (context, size) => DropdownMenu<String>(
                    controller: userSearch,
                    width: size.maxWidth,
                    menuHeight: 300,
                    enableFilter: true,
                    enableSearch: true,
                    requestFocusOnTap: true,
                    enabled: !busy,
                    label: Text(
                      widget.audit
                          ? 'User (all users if empty)'
                          : 'Select user',
                    ),
                    dropdownMenuEntries: visibleUsers
                        .map(
                          (u) => DropdownMenuEntry(
                            value: u['ID'].toString(),
                            label: label(u),
                          ),
                        )
                        .toList(),
                    onSelected: selectUser,
                  ),
                ),
                if (widget.audit) ...[
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            userSearch.clear();
                            selectUser(null);
                          },
                    child: const Text('All users'),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, size) => DropdownMenu<String>(
                      width: size.maxWidth,
                      menuHeight: 300,
                      enableFilter: true,
                      enableSearch: true,
                      label: const Text('Activity type'),
                      enabled: !busy,
                      dropdownMenuEntries: [
                        const DropdownMenuEntry(
                          value: '0',
                          label: 'All activities',
                        ),
                        ...types.map(
                          (t) => DropdownMenuEntry(
                            value: t['CODE'].toString(),
                            label: t['NAME'].toString(),
                          ),
                        ),
                      ],
                      initialSelection: '0',
                      onSelected: (v) => setState(() => action = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: busy ? null : () => pickDate(true),
                        child: Text('From: ${date(from)}'),
                      ),
                      OutlinedButton(
                        onPressed: busy ? null : () => pickDate(false),
                        child: Text('To: ${date(to)}'),
                      ),
                      FilledButton(
                        onPressed: busy ? null : search,
                        child: const Text('Search'),
                      ),
                    ],
                  ),
                  const Text(
                    'Date range uses UTC. Results show the most recent activity first.',
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Debug Mode'),
                    value: debug,
                    onChanged: user == null || busy
                        ? null
                        : (v) => setState(() => debug = v),
                  ),
                  SwitchListTile(
                    title: const Text('Do Not Load Tickets On Load'),
                    subtitle: const Text(
                      'Open the filters and wait for Search.',
                    ),
                    value: skip,
                    onChanged: user == null || busy
                        ? null
                        : (v) => setState(() => skip = v),
                  ),
                ],
                if (busy) const PortalLoading(message: 'Please wait...'),
                if (notice != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(notice!),
                  ),
                if (widget.audit) ...[
                  for (final row in rows)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['TIME_UTC']}  ${row['ACTION']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${row['USER_ID']} - ${row['USER_NAME'] ?? ''}',
                            ),
                            Text(row['FAILED'] == '1' ? 'Failed' : 'Completed'),
                            if (row['TARGET_USER'] != null &&
                                row['TARGET_USER'] != '0')
                              Text('Changed user: ${row['TARGET_USER']}'),
                            if ((row['DETAILS'] ?? '').toString().isNotEmpty)
                              Text(row['DETAILS'].toString()),
                          ],
                        ),
                      ),
                    ),
                  if (rows.isNotEmpty && rows.length % 200 == 0)
                    TextButton(
                      onPressed: busy ? null : () => search(more: true),
                      child: const Text('Load more'),
                    ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!widget.audit)
                      FilledButton(
                        onPressed: user == null || busy ? null : save,
                        child: const Text('Save'),
                      ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ],
          ),
  );
}
