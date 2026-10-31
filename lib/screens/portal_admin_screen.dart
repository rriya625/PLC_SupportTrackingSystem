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
  List<Map<String, dynamic>> customers = [];
  String? customer;
  int customerPickerGeneration = 0;
  bool get customerLocked => !Constants.isEmployee;
  bool contactsLoading = false,
      customersLoading = false,
      customersLoaded = false,
      typesLoading = false,
      typesLoaded = false;
  final customerSearch = TextEditingController();
  String customerLabel(Map<String, dynamic> c) =>
      "${c['CODE']} - ${c['NAME'] ?? ''}";
  String? user, action;
  bool loading = true, busy = false, debug = false, skip = false;
  bool deptTickets = false,
      enabled = true,
      selectedEmployee = false,
      deleteAllowed = false;
  int access = 0, invalidCount = 0;
  String? error, notice;
  DateTime from = DateTime.now().subtract(const Duration(days: 7)),
      to = DateTime.now();
  final userSearch = TextEditingController();
  @override
  void initState() {
    super.initState();
    userSearch.addListener(_filterUsers);
    customerSearch.addListener(_filterCustomers);
    load();
  }

  void _filterUsers() {
    if (!mounted) return;
    setState(() {
      if (user != null) {
        final selected = users.where((u) => u['ID'].toString() == user);
        if (selected.isNotEmpty && userSearch.text != label(selected.first))
          user = null;
      }
    });
  }

  List<Map<String, dynamic>> get visibleUsers {
    final search = userSearch.text.trim().toLowerCase();
    return users
        .where((u) => search.isEmpty || label(u).toLowerCase().contains(search))
        .toList();
  }

  @override
  void dispose() {
    customerSearch.dispose();
    userSearch.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> data(Map<String, dynamic> result) =>
      List<Map<String, dynamic>>.from(result['Data'] ?? []);
  Future<void> load() async {
    setState(() {
      loading = false;
      if (!Constants.isPortalAdmin) error = 'Access Level 2 is required.';
    });
    if (Constants.isPortalAdmin && (!widget.audit || customerLocked)) {
      await loadCustomers();
      if (!mounted) return;
      final matches = customers.where(
        (c) => c['CODE'].toString() == Constants.qbLinkKey,
      );
      if (matches.isEmpty) return;
      final own = matches.first;
      customerSearch.text = customerLabel(own);
      await selectCustomer(own['CODE'].toString());
      if (!mounted || widget.audit) return;
      final ownUsers = users.where(
        (u) => u['ID'].toString() == Constants.userID.toString(),
      );
      if (ownUsers.isNotEmpty) selectUser(Constants.userID.toString());
    }
  }

  Future<void> loadCustomers() async {
    if (customersLoaded || customersLoading || !Constants.isPortalAdmin) return;
    setState(() {
      customersLoading = true;
      error = null;
    });
    try {
      final list = data(await api.call('GetPortalCustomers'));
      if (mounted)
        setState(() {
          customers = list;
          customersLoaded = true;
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => customersLoading = false);
    }
  }

  Future<void> loadTypes() async {
    if (typesLoaded || typesLoading || !Constants.isPortalAdmin) return;
    setState(() {
      typesLoading = true;
      error = null;
    });
    try {
      final list = data(await api.call('GetPortalAuditTypes'));
      if (mounted)
        setState(() {
          types = list;
          typesLoaded = true;
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => typesLoading = false);
    }
  }

  void _filterCustomers() {
    if (!mounted || customerLocked) return;
    setState(() {
      if (customer != null &&
          !customers.any(
            (c) =>
                c['CODE'] == customer &&
                customerLabel(c) == customerSearch.text,
          )) {
        customer = null;
        user = null;
        users = [];
        contactsLoading = false;
        rows = [];
        userSearch.clear();
      }
    });
  }

  Future<void> selectCustomer(String? code) async {
    setState(() {
      customer = code;
      rows = [];
      user = null;
      debug = false;
      skip = false;
      deptTickets = false;
      enabled = true;
      selectedEmployee = false;
      deleteAllowed = false;
      access = 0;
      invalidCount = 0;
      users = [];
      userSearch.clear();
      error = null;
      notice = null;
      contactsLoading = code != null;
    });
    if (code == null) return;
    try {
      final contacts = data(
        await api.call('GetPortalContacts', query: {'QBLinkKey': code}),
      );
      if (mounted && customer == code)
        setState(() {
          users = contacts;
          notice = contacts.isEmpty ? 'No contacts for this customer.' : null;
        });
    } catch (e) {
      if (mounted && customer == code) setState(() => error = e.toString());
    } finally {
      if (mounted && customer == code) setState(() => contactsLoading = false);
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
        selectedEmployee = u['USER_TYPE'] == 'EMPLOYEE';
        deleteAllowed =
            selectedEmployee &&
            ['T', 'Y'].contains(u['ALLOW_DOCUMENT_DELETE']?.toString());
        access = int.tryParse(u['ACCESS_LEVEL']?.toString() ?? '') ?? 0;
        invalidCount =
            int.tryParse(u['INVALID_LOGIN_COUNT']?.toString() ?? '') ?? 0;
        enabled = ![
          'T',
          'Y',
        ].contains(u['ACCOUNT_DISABLED']?.toString().toUpperCase());
        deptTickets = [
          'T',
          'Y',
        ].contains(u['WEB_VIEW_ALL_DEPT_TICKETS']?.toString().toUpperCase());
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
        'UpdatePortalSettings',
        body: {
          'TargetUserID': int.parse(user!),
          'AccessLevel': access,
          'AllowDocumentDelete': selectedEmployee && deleteAllowed ? 'T' : 'F',
          'WebViewAllDeptTickets': deptTickets ? 'T' : 'F',
          'AccountDisabled': enabled ? 'F' : 'T',
          'DebugMode': selectedEmployee && debug ? 'T' : 'F',
          'DoNotLoadTicketsOnLoad': skip ? 'T' : 'F',
        },
      );
      final u = users.firstWhere((u) => u['ID'].toString() == user);
      u['ALLOW_DOCUMENT_DELETE'] = selectedEmployee && deleteAllowed
          ? 'T'
          : 'F';
      u['ACCESS_LEVEL'] = access.toString();
      u['ACCOUNT_DISABLED'] = enabled ? 'F' : 'T';
      u['WEB_VIEW_ALL_DEPT_TICKETS'] = deptTickets ? 'T' : 'F';
      u['DEBUG_MODE'] = selectedEmployee && debug ? 'T' : 'F';
      u['DO_NOT_LOAD_TICKETS_ON_LOAD'] = skip ? 'T' : 'F';
      if (user == Constants.userID.toString()) {
        Constants.allowDocumentDelete = selectedEmployee && deleteAllowed
            ? 'T'
            : 'F';
        Constants.accessLevel = access.toString();
        Constants.webViewAllDeptTickets = deptTickets ? 'T' : 'F';
        Constants.debugMode = selectedEmployee && debug ? 'T' : 'F';
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

  Future<void> resetCount() async {
    if (user == null || busy) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await api.call(
        'ResetPortalLoginCount',
        body: {'TargetUserID': int.parse(user!)},
      );
      final u = users.firstWhere((u) => u['ID'].toString() == user);
      u['INVALID_LOGIN_COUNT'] = '0';
      if (mounted)
        setState(() {
          invalidCount = 0;
          notice =
              'Invalid login count reset. Enable the account separately if it is disabled.';
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> passwordDialog() async {
    final target = user;
    if (target == null || busy) return;
    final password = TextEditingController(), confirm = TextEditingController();
    String? problem;
    bool saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: const Text('Set / Reset Password'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('User: $target'),
                    TextField(
                      controller: password,
                      obscureText: true,
                      autofocus: true,
                      enabled: !saving,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                      ),
                    ),
                    TextField(
                      controller: confirm,
                      obscureText: true,
                      enabled: !saving,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                      ),
                    ),
                    if (problem != null)
                      Text(problem!, style: const TextStyle(color: Colors.red)),
                    if (saving)
                      const PortalLoading(message: 'Saving password...'),
                  ],
                ),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (password.text.trim().isEmpty ||
                            confirm.text.isEmpty) {
                          setDialog(
                            () =>
                                problem = 'Enter and confirm the new password.',
                          );
                          return;
                        }
                        if (password.text != confirm.text) {
                          setDialog(() => problem = 'Passwords do not match.');
                          return;
                        }
                        setDialog(() {
                          saving = true;
                          problem = null;
                        });
                        try {
                          await api.call(
                            'SetPortalPassword',
                            body: {
                              'TargetUserID': int.parse(target),
                              'NewPassword': password.text,
                              'ConfirmPassword': confirm.text,
                            },
                          );
                          if (target == Constants.userID.toString())
                            Constants.userPassword = password.text;
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext);
                          if (mounted)
                            setState(
                              () => notice =
                                  'Password saved. Account status and login count were not changed.',
                            );
                        } catch (e) {
                          if (dialogContext.mounted)
                            setDialog(() {
                              problem = e.toString();
                              saving = false;
                            });
                        }
                      },
                child: const Text('Save Password'),
              ),
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
    // Controllers remain alive until the closing dialog animation completes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    password.dispose();
    confirm.dispose();
  }

  Widget lookupButton(bool isCustomer) {
    final entries = isCustomer ? customers : users;
    final selected = isCustomer ? customer : user;
    final matches = entries.where(
      (e) => (isCustomer ? e['CODE'] : e['ID']).toString() == selected,
    );
    final title = matches.isNotEmpty
        ? (isCustomer ? customerLabel(matches.first) : label(matches.first))
        : (isCustomer
              ? 'Select customer'
              : (widget.audit
                    ? 'Contact (all contacts if empty)'
                    : 'Select user'));
    final button = OutlinedButton(
      key: ValueKey(isCustomer ? 'customerLookup' : 'contactLookup'),
      onPressed:
          busy ||
              customersLoading ||
              contactsLoading ||
              (isCustomer ? customerLocked : customer == null)
          ? null
          : () => chooseLookup(isCustomer),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
    return Row(
      children: [
        Expanded(child: button),
        if (widget.audit && (!isCustomer || !customerLocked))
          IconButton(
            tooltip: isCustomer
                ? 'All customers'
                : 'All contacts for this customer',
            onPressed: busy || contactsLoading
                ? null
                : () {
                    if (isCustomer) {
                      selectCustomer(null);
                    } else {
                      selectUser(null);
                    }
                  },
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
      ],
    );
  }

  Future<void> chooseLookup(bool isCustomer, {bool activity = false}) async {
    if (activity) {
      await loadTypes();
    } else if (isCustomer) {
      await loadCustomers();
    }
    if (!mounted || error != null) return;
    final choices = activity ? types : (isCustomer ? customers : users);
    String entryLabel(Map<String, dynamic> e) => activity
        ? e['NAME'].toString()
        : (isCustomer ? customerLabel(e) : label(e));
    var term = '';
    final result = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) {
          final filtered = choices
              .where(
                (e) => entryLabel(e).toLowerCase().contains(term.toLowerCase()),
              )
              .toList();
          final allowAll = widget.audit;
          return AlertDialog(
            title: Text(
              activity
                  ? 'Activity type'
                  : (isCustomer ? 'Customer' : 'Contact'),
            ),
            content: SizedBox(
              width: 520,
              height: MediaQuery.sizeOf(c).height * .45,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Search'),
                    onChanged: (v) => update(() => term = v),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length + (allowAll ? 1 : 0),
                      itemBuilder: (c, i) {
                        if (allowAll && i == 0)
                          return ListTile(
                            title: Text(
                              activity
                                  ? 'All activities'
                                  : isCustomer
                                  ? 'All customers'
                                  : 'All contacts for this customer',
                            ),
                            onTap: () => Navigator.pop(c, ''),
                          );
                        final entry = filtered[i - (allowAll ? 1 : 0)];
                        return ListTile(
                          title: Text(entryLabel(entry)),
                          onTap: () => Navigator.pop(
                            c,
                            (activity || isCustomer
                                    ? entry['CODE']
                                    : entry['ID'])
                                .toString(),
                          ),
                        );
                      },
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
    if (!mounted || result == null) return;
    if (activity) {
      setState(() => action = result.isEmpty ? null : result);
    } else if (isCustomer) {
      await selectCustomer(result.isEmpty ? null : result);
    } else {
      selectUser(result.isEmpty ? null : result);
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
          'GetPortalCustomerAudit',
          query: {
            'QBLinkKey': customer ?? '',
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
                ...[
                  SizedBox(
                    height: customersLoading ? 48 : 0,
                    child: customersLoading
                        ? const PortalLoading(message: 'Loading customers...')
                        : null,
                  ),
                  lookupButton(true),
                  const SizedBox(height: 12),
                  if (contactsLoading)
                    const PortalLoading(message: 'Loading contacts...'),
                ],
                lookupButton(false),
                if (widget.audit) ...[
                  const SizedBox(height: 12),
                  if (typesLoading)
                    const PortalLoading(message: 'Loading activity types...'),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const ValueKey('activityLookup'),
                      onPressed: busy || typesLoading
                          ? null
                          : () => chooseLookup(false, activity: true),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              action == null || action == '0'
                                  ? 'All activities'
                                  : types
                                        .firstWhere(
                                          (t) => t['CODE'].toString() == action,
                                        )['NAME']
                                        .toString(),
                              textAlign: TextAlign.left,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
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
                  DropdownButtonFormField<int>(
                    value: [0, 1, 2].contains(access) ? access : 0,
                    decoration: const InputDecoration(
                      labelText: 'Access Level',
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('0')),
                      DropdownMenuItem(value: 1, child: Text('1')),
                      DropdownMenuItem(
                        value: 2,
                        child: Text('2 - Portal administrator'),
                      ),
                    ],
                    onChanged:
                        user == null ||
                            busy ||
                            user == Constants.userID.toString()
                        ? null
                        : (v) => setState(() => access = v!),
                  ),
                  SwitchListTile(
                    title: const Text('Enable portal account'),
                    value: enabled,
                    onChanged:
                        user == null ||
                            busy ||
                            user == Constants.userID.toString()
                        ? null
                        : (v) => setState(() => enabled = v),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Allow viewing all tickets for this customer',
                    ),
                    subtitle: const Text(
                      'Customers can view other tickets in their own department. Yours still shows their own tickets.',
                    ),
                    value: deptTickets,
                    onChanged: user == null || busy
                        ? null
                        : (v) => setState(() => deptTickets = v),
                  ),
                  Text('Invalid login count: $invalidCount'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: user == null || busy ? null : resetCount,
                        child: const Text('Reset Invalid Login Count'),
                      ),
                      FilledButton(
                        onPressed: user == null || busy ? null : passwordDialog,
                        child: const Text('Set / Reset Password'),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Allow deleting documents'),
                    subtitle: Text(
                      selectedEmployee
                          ? 'Allow deleting documents on tickets this employee can access.'
                          : 'Employees only. Customers cannot delete documents.',
                    ),
                    value: selectedEmployee && deleteAllowed,
                    onChanged: user == null || busy || !selectedEmployee
                        ? null
                        : (v) => setState(() => deleteAllowed = v),
                  ),
                  SwitchListTile(
                    title: const Text('Review diagnostic logs'),
                    subtitle: const Text('Employees only. Diagnostic files may include multiple customers.'),
                    value: selectedEmployee && debug,
                    onChanged: user == null || busy || !selectedEmployee
                        ? null
                        : (v) => setState(() => debug = v),
                  ),
                  SwitchListTile(
                    title: const Text('Wait for Search before loading tickets'),
                    subtitle: const Text(
                      'Search Filter will be open and click Search to load tickets.',
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
