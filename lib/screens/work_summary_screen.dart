import 'package:flutter/material.dart';
import '../constants.dart';
import '../utils/messages_api.dart';
import '../widgets/portal_app_bar.dart';
import '../widgets/portal_loading.dart';
import '../widgets/work_summary_grid.dart';
import 'work_tickets_screen.dart';

class WorkSummaryScreen extends StatefulWidget {
  const WorkSummaryScreen({super.key});
  @override
  State<WorkSummaryScreen> createState() => _WorkSummaryState();
}

class _WorkSummaryState extends State<WorkSummaryScreen> {
  final api = MessagesApi();
  DateTime from = DateTime.now().subtract(const Duration(days: 7)),
      to = DateTime.now();
  String group = '', error = '';
  int range = 0;
  bool loadingGroups = false;
  final groupController = TextEditingController(text: 'All groups');
  final rangeController = TextEditingController();
  bool busy = false, searched = false;
  List<Map<String, dynamic>> rows = [];
  Map<String, String> resultQuery = {};
  List<Map<String, String>>? groups;
  String date(DateTime d) => d.toIso8601String().split('T').first;
  Future<void> pickDate(bool start) async {
    final d = await showDatePicker(
      context: context,
      initialDate: start ? from : to,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (d != null && mounted)
      setState(() {
        range = -1;
        rangeController.text = 'Custom dates';
        if (start)
          from = d;
        else
          to = d;
      });
  }

  DateTime get monday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - now.weekday + 1);
  }

  String weekLabel(int n) {
    final start = monday.subtract(Duration(days: 7 * n));
    return '${date(start)} - ${date(start.add(const Duration(days: 6)))}';
  }

  void selectRange(int n) {
    setState(() {
      range = n;
      if (n >= 0) {
        from = monday.subtract(Duration(days: 7 * n));
        to = from.add(const Duration(days: 6));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    from = monday;
    to = from.add(const Duration(days: 6));
    rangeController.text = weekLabel(0);
    if (Constants.isEmployee) loadGroups();
  }

  @override
  void dispose() {
    groupController.dispose();
    rangeController.dispose();
    super.dispose();
  }

  Future<void> loadGroups() async {
    setState(() => loadingGroups = true);
    try {
      final r = await api.call('GetWorkGroups');
      if (!mounted) return;
      setState(
        () => groups = [
          {'Code': '', 'Description': 'All groups'},
          ...(r['Data'] as List).map(
            (e) => {'Code': e.toString(), 'Description': e.toString()},
          ),
        ],
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loadingGroups = false);
    }
  }

  Future<void> search() async {
    if (from.isAfter(to)) {
      setState(() => error = 'From date must be on or before To date.');
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final query = {
        'FromDate': date(from), 'ToDate': date(to),
        'GroupName': Constants.isEmployee ? group : '',
      };
      final r = await api.call(
        'GetWorkSummary',
        query: query,
      );
      if (mounted)
        setState(() {
          rows = (r['Data'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          searched = true;
          resultQuery = query;
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: PortalAppBar(
      backgroundColor: Colors.blue[800],
      foregroundColor: Colors.white,
      title: Text('Activity Summary'),
    ),
    body: Column(
      children: [
        if (rows.any((r) => (r['InvalidTimeCount'] as num? ?? 0) > 0))
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Some older activities have invalid recorded time. They are included in the counts, but their hours are unavailable. Contact support.',
              style: TextStyle(color: Colors.deepOrange),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (Constants.isEmployee)
                DropdownMenu<String>(
                  width: 260,
                  controller: groupController,
                  label: Text(
                    loadingGroups ? 'Loading groups...' : 'Employee group',
                  ),
                  enabled: !busy && !loadingGroups,
                  enableFilter: true,
                  requestFocusOnTap: true,
                  menuHeight: 300,
                  onSelected: (v) {
                    if (v != null) setState(() => group = v);
                  },
                  dropdownMenuEntries: (groups ?? [])
                      .map(
                        (g) => DropdownMenuEntry(
                          value: g['Code']!,
                          label: g['Description']!,
                        ),
                      )
                      .toList(),
                ),
              DropdownMenu<int>(
                width: 290,
                controller: rangeController,
                label: const Text('Date range'),
                enabled: !busy,
                menuHeight: 300,
                enableFilter: true,
                requestFocusOnTap: true,
                onSelected: (v) {
                  if (v != null) selectRange(v);
                },
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: -1, label: 'Custom dates'),
                  for (var n = 0; n < 52; n++)
                    DropdownMenuEntry(value: n, label: weekLabel(n)),
                ],
              ),
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
        ),
        if (!Constants.isEmployee)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(Constants.departmentName),
          ),
        if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Colors.red)),
        if (busy) const PortalLoading(message: 'Loading activity summary...'),
        Expanded(
          child: busy
              ? const SizedBox.shrink()
              : rows.isNotEmpty
              ? WorkSummaryGrid(rows: rows, employee: Constants.isEmployee,
                  onCount: (scope, type, employee) => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => WorkTicketsScreen(query: {
                      ...resultQuery, 'Scope': scope,
                      'ActivityType': type, 'EmployeeID': employee,
                    }))))
              : Center(
                  child: Text(
                    searched && error.isEmpty
                        ? 'No activities in this date range.'
                        : 'Choose a group and date range, then click Search.',
                  ),
                ),
        ),
      ],
    ),
  );
}
