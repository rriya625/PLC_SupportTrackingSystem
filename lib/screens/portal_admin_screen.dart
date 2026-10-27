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
  final customerFocus = FocusNode(), typeFocus = FocusNode();
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
    customerFocus.addListener(() {
      if (customerFocus.hasFocus) loadCustomers();
    });
    typeFocus.addListener(() {
      if (typeFocus.hasFocus) loadTypes();
    });
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
    customerFocus.dispose();
    typeFocus.dispose();
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
    if (Constants.isPortalAdmin && customerLocked) {
      await loadCustomers();
      if (!mounted || customers.isEmpty) return;
      final own = customers.first;
      customerSearch.text = customerLabel(own);
      await selectCustomer(own['CODE'].toString());
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
          'DebugMode': debug ? 'T' : 'F',
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
      u['DEBUG_MODE'] = debug ? 'T' : 'F';
      u['DO_NOT_LOAD_TICKETS_ON_LOAD'] = skip ? 'T' : 'F';
      if (user == Constants.userID.toString()) {
        Constants.allowDocumentDelete = selectedEmployee && deleteAllowed
            ? 'T'
            : 'F';
        Constants.accessLevel = access.toString();
        Constants.webViewAllDeptTickets = deptTickets ? 'T' : 'F';
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
                  Listener(
                    onPointerDown: (_) => loadCustomers(),
                    child: LayoutBuilder(
                      builder: (context, size) => DropdownMenu<String>(
                        key: ValueKey(customerPickerGeneration),
                        controller: customerSearch,
                        focusNode: customerFocus,
                        requestFocusOnTap: true,
                        width: size.maxWidth,
                        menuHeight: 300,
                        label: const Text('Select customer'),
                        enableFilter: true,
                        enableSearch: true,
                        enabled: !busy && !customerLocked,
                        dropdownMenuEntries: customers
                            .map(
                              (c) => DropdownMenuEntry(
                                value: c['CODE'].toString(),
                                label: customerLabel(c),
                              ),
                            )
                            .toList(),
                        onSelected: selectCustomer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (contactsLoading)
                    const PortalLoading(message: 'Loading contacts...'),
                ],

                LayoutBuilder(
                  builder: (context, size) => DropdownMenu<String>(
                    controller: userSearch,
                    width: size.maxWidth,
                    menuHeight: 300,
                    enableFilter: true,
                    enableSearch: true,
                    requestFocusOnTap: true,
                    enabled: !busy && (customer != null && !contactsLoading),
                    label: Text(
                      widget.audit
                          ? 'Contact (all contacts if empty)'
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
                    child: Text(
                      customer == null
                          ? 'All users'
                          : 'All contacts for this customer',
                    ),
                  ),
                  if (!customerLocked)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              customerFocus.unfocus();
                              customerSearch.clear();
                              customerPickerGeneration++;
                              selectCustomer(null);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) customerFocus.requestFocus();
                              });
                            },
                      child: const Text('All customers'),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: typesLoading ? 48 : 0,
                    child: typesLoading
                        ? const PortalLoading(
                            message: 'Loading activity types...',
                          )
                        : null,
                  ),
                  Listener(
                    onPointerDown: (_) => loadTypes(),
                    child: LayoutBuilder(
                      builder: (context, size) => DropdownMenu<String>(
                        width: size.maxWidth,
                        menuHeight: 300,
                        enableFilter: true,
                        enableSearch: true,
                        focusNode: typeFocus,
                        requestFocusOnTap: true,
                        label: const Text('Activity type'),
                        helperText: typesLoaded
                            ? '${types.length} activity types. Type to search or scroll for more.'
                            : 'Open to load activity types.',
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
                    value: debug,
                    onChanged: user == null || busy
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
