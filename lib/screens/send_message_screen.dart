import '../widgets/portal_app_bar.dart';
import 'package:ticket_tracker_app/utils/diagnostic_http_client.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/utils/api_helper.dart';
import 'package:ticket_tracker_app/utils/dialogs.dart';
import 'package:ticket_tracker_app/widgets/portal_loading.dart';

class SendMessageScreen extends StatefulWidget {
  const SendMessageScreen({Key? key}) : super(key: key);

  @override
  State<SendMessageScreen> createState() => _SendMessageScreenState();
}

class _SendMessageScreenState extends State<SendMessageScreen> {
  static const String _urgentSupportReminder =
      'For urgent issues, please call the Porter Lee support line at '
      '(847) 985-2060. A portal message alone may not receive an immediate response.';
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  String _name = '';
  List<String> _messageToOptions = [];
  String? _selectedMessageTo;
  String? _ticketKey;
  List<Map<String, dynamic>> _employeeRecipients = [];
  String? _selectedEmployeeId;
  bool _sendToEmployee = false;
  bool _loadingGroups = true;
  bool _loadingEmployees = false;
  bool _employeesLoaded = false;

  bool get _isUrgentSelection =>
      !_sendToEmployee &&
      (_selectedMessageTo ?? '').toLowerCase().contains('urgent');

  Future<void> _showUrgentSupportReminder() async {
    if (!mounted) return;
    await showMessageDialog(context, _urgentSupportReminder);
  }

  @override
  void initState() {
    super.initState();
    _name = Constants.contactName;
    _fetchMessageToList();

    // ✅ Autofocus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _messageFocusNode.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ticketKey ??= ModalRoute.of(context)?.settings.arguments as String?;
    debugPrint('Send message screen opened for ticket $_ticketKey');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose(); // ✅ Dispose focus node
    super.dispose();
  }

  Future<void> _fetchMessageToList() async {
    try {
      final url = Uri.parse(
        '${Constants.baseUrlData}GetMessageToList?QBLinkKey=${Constants.qbLinkKey}',
      );
      final response = await diagnosticHttpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer ${Constants.accessToken}',
          'Accept': 'application/json',
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        setState(() {
          _messageToOptions = jsonList
              .map((e) => e['Option'].toString())
              .where(
                (option) => option != 'O' && option != '-- No Selection --',
              )
              .toList();
          _selectedMessageTo = _messageToOptions.isNotEmpty
              ? _messageToOptions.first
              : null;
          debugPrint('Loaded ${_messageToOptions.length} message recipients');
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load recipient list')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load recipients. Please reopen the message window.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  Future<void> _fetchEmployeeRecipients() async {
    if (_loadingEmployees || _employeesLoaded) return;
    setState(() => _loadingEmployees = true);
    try {
      final recipients = await APIHelper.getEmployeeRecipients();
      if (!mounted) return;
      setState(() {
        _employeeRecipients = recipients;
        _employeesLoaded = true;
        _selectedEmployeeId = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load employees: $error')),
      );
    } finally {
      if (mounted) setState(() => _loadingEmployees = false);
    }
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (_ticketKey == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ticket key is missing')));
      return;
    }

    if (_sendToEmployee && _selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee')),
      );
      return;
    }

    if (!_sendToEmployee &&
        (_selectedMessageTo == null || _selectedMessageTo == 'None')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a recipient')),
      );
      return;
    }

    if (message.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message cannot be empty')));
      return;
    }

    if (_sendToEmployee) {
      try {
        await APIHelper.sendEmployeeMessage(
          ticketKey: int.parse(_ticketKey!),
          employeeId: _selectedEmployeeId!,
          messageText: message,
        );
        if (!mounted) return;
        await showMessageDialog(context, 'Your message has been sent.');
        if (mounted) Navigator.of(context).pop();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send message: $error')),
          );
        }
      }
      return;
    }

    final submittedBy = _name.trim().isNotEmpty
        ? _name.trim()
        : 'Portal user ${Constants.userID}';
    final messageBody = Constants.isEmployee
        ? message
        : '$message\n\nSubmitted by: $submittedBy';

    final body = json.encode({
      'TicketKey': int.parse(_ticketKey!),
      'MessageTo': _selectedMessageTo,
      'sMessage': messageBody,
      'UserID': Constants.userID.toString(),
      'UserName': _name,
    });

    final response = await diagnosticHttpClient.post(
      Uri.parse('${Constants.baseUrlData}SendMessage'),
      headers: {
        'Authorization': 'Bearer ${Constants.accessToken}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: body,
    );
    if (!mounted) return;

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent successfully')),
      );
      setState(() {
        _messageController.clear();
        _selectedMessageTo = _messageToOptions.isNotEmpty
            ? _messageToOptions.first
            : null;
      });
      FocusScope.of(context).unfocus();
      await showMessageDialog(
        context,
        'Your message has been successfully sent to Porter Lee Corporation.',
      );
      if (mounted) Navigator.of(context).pop();
    } else {
      debugPrint('Send message failed with status ${response.statusCode}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send message')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PortalAppBar(
        title: const Text('Send Message'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Agency: Porter Lee',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text('Name: $_name', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                const Text(
                  'Send your message to:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 6),
                if (Constants.isEmployee) ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Group')),
                      ButtonSegment(value: true, label: Text('Employee')),
                    ],
                    selected: {_sendToEmployee},
                    onSelectionChanged: (value) {
                      setState(() => _sendToEmployee = value.first);
                      if (_sendToEmployee) _fetchEmployeeRecipients();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (_sendToEmployee && _loadingEmployees)
                  const PortalLoading(message: 'Loading employees...'),
                if (_sendToEmployee)
                  Autocomplete<Map<String, dynamic>>(
                    displayStringForOption: (employee) {
                      final id = employee['EmployeeID']?.toString() ?? '';
                      final name = employee['EmployeeName']?.toString() ?? id;
                      return '$name ($id)';
                    },
                    optionsBuilder: (text) {
                      final query = text.text.trim().toLowerCase();
                      if (query.isEmpty) return _employeeRecipients;
                      return _employeeRecipients.where((employee) {
                        final id =
                            employee['EmployeeID']?.toString().toLowerCase() ??
                            '';
                        final name =
                            employee['EmployeeName']
                                ?.toString()
                                .toLowerCase() ??
                            '';
                        return id.contains(query) || name.contains(query);
                      });
                    },
                    onSelected: (employee) => setState(
                      () => _selectedEmployeeId = employee['EmployeeID']
                          ?.toString(),
                    ),
                    fieldViewBuilder:
                        (context, controller, focusNode, onSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Search employee',
                              hintText: 'Name or employee ID',
                              border: OutlineInputBorder(),
                            ),
                          );
                        },
                  )
                else
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    hint: Text(
                      _loadingGroups ? 'Loading groups...' : 'Select group',
                    ),
                    value: _selectedMessageTo,
                    items: _messageToOptions
                        .map(
                          (target) => DropdownMenuItem(
                            value: target,
                            child: Text(target),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMessageTo = value;
                      });
                      if ((value ?? '').toLowerCase().contains('urgent')) {
                        _showUrgentSupportReminder();
                      }
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
                  ),
                if (_isUrgentSelection) ...[
                  const SizedBox(height: 12),
                  _UrgentSupportNotice(message: _urgentSupportReminder),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Enter your message here:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Type your message here...',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Cancel Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(
                            context,
                          ); // or Navigator.of(context).maybePop();
                        },
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Submit Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send),
                        label: const Text('Submit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UrgentSupportNotice extends StatelessWidget {
  final String message;

  const _UrgentSupportNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        border: Border.all(color: Colors.orange.shade700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.phone_in_talk, color: Colors.orange.shade900),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
