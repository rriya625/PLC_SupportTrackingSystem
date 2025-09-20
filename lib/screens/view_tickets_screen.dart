import 'package:flutter/material.dart';
import 'ticket_description_screen.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/utils/api_helper.dart';
import 'package:ticket_tracker_app/utils/dialogs.dart';

class ViewTicketsScreen extends StatefulWidget {
  const ViewTicketsScreen({Key? key}) : super(key: key);

  @override
  State<ViewTicketsScreen> createState() => _ViewTicketsScreenState();
}

class _ViewTicketsScreenState extends State<ViewTicketsScreen> {
  String ticketType = 'Yours';
  String status = 'Open';
  String searchBy = 'Ticket #'; // default set
  String sortBy = 'Last Activity';
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  List<Map<String, dynamic>> tickets = [];

  DateTime? fromDate;
  DateTime? toDate;
  String? dateErrorText;

  List<Map<String, String>> ticketGroups = [];
  //List<Map<String, dynamic>> ticketGroups = [];
  String? selectedTicketGroup;
  bool useActiveGroupsOnly = true;
  bool isTicketGroupLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    fromDate = now.subtract(const Duration(days: 365));
    toDate = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      searchFocusNode.requestFocus();
    });

    _fetchTicketGroups();
    _fetchAndSetTickets();
  }

  Future<void> _fetchTicketGroups() async {
    setState(() => isTicketGroupLoading = true);
    try {
      final data = await APIHelper.getTicketGroupList(
        prospectKey: Constants.userID.toString(),
        qbLinkKey: Constants.qbLinkKey,
        useActiveOnly: useActiveGroupsOnly,
      );

      print("Raw ticket group data from API (${data.length} entries):");
      for (var group in data) {
        print(" 1 - Code: ${group['Code']}, Description: ${group['Description']}");
      }

      setState(() {
        final validGroups = data
            .where((g) => g['Code'] != null && g['Code'].toString().trim().isNotEmpty)
            .toList();

        print("Filtered valid ticket groups (${validGroups.length}):");
        for (var group in validGroups) {
          print(" - Code: ${group['Code']}, Description: ${group['Description']}");
        }

        ticketGroups = validGroups;

        selectedTicketGroup ??= validGroups.isNotEmpty
            ? validGroups.first['Code']?.toString()
            : null;

        print("Selected ticket group after filtering: $selectedTicketGroup");
      });
    } catch (e) {
      debugPrint('Error fetching ticket groups: $e');
    } finally {
      setState(() => isTicketGroupLoading = false);
    }
  }

  Future<void> _pickDate(BuildContext context, bool isFromDate) async {
    final initialDate = isFromDate ? fromDate ?? DateTime.now() : toDate ?? DateTime.now();
    final newDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (newDate != null) {
      setState(() {
        if (isFromDate) {
          fromDate = newDate;
        } else {
          toDate = newDate;
        }
      });
    }
  }

  Future<void> _fetchAndSetTickets() async {
    if (fromDate != null && toDate != null && fromDate!.isAfter(toDate!)) {
      setState(() {
        dateErrorText = 'From Date cannot be after To Date.';
      });
      return;
    }

    if (searchBy == 'Ticket #' && searchController.text.trim().isNotEmpty) {
      if (int.tryParse(searchController.text.trim()) == null) {
        setState(() {
          tickets.clear(); // Clear the list if invalid input
        });

        if (context.mounted) {
          await showMessageDialog(context, 'Please enter a valid numeric Ticket #');
          FocusScope.of(context).requestFocus(searchFocusNode);
        }
        return;
      }
    }

    setState(() {
      dateErrorText = null;
    });

    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text("Loading tickets..."),
                  ],
                ),
              ),
            );
          },
        );
      });

      final data = await APIHelper.fetchTickets(
        ticketType: ticketType,
        status: status,
        searchBy: searchBy,
        sortBy: sortBy,
        searchValue: searchController.text,
        fromDate: fromDate != null ? _formatApiDate(fromDate!) : '',
        toDate: toDate != null ? _formatApiDate(toDate!) : '',
        ticketGroupCode: selectedTicketGroup ?? '',
      );
      setState(() {
        tickets = data;
      });

      Navigator.of(context, rootNavigator: true).pop();
    }
    catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      setState(() {
        tickets.clear(); // clear ticket list on error
      });
      debugPrint('Ticket fetch error: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatApiDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Porter Lee Corporation'),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: true,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilters(),
            const SizedBox(height: 20),
            Text(
              'Total Tickets: ${tickets.length}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: tickets.length,
                itemBuilder: (context, index) {
                  final ticket = tickets[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TicketDescriptionScreenStateful(),
                          settings: RouteSettings(arguments: ticket['TicketKey']),
                        ),
                      );
                    },
                    child: _buildTicketCard(
                      ticketKey: ticket['TicketKey'] ?? '',
                      date: ticket['StartDate'] ?? '',
                      shortDesc: ticket['ShortDesc'] ?? '',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildDropdown('Ticket Type', ['Yours', 'Department'], ticketType, (val) => setState(() => ticketType = val!))),
            const SizedBox(width: 12),
            Expanded(child: _buildDropdown('Status', ['Open', 'Closed', 'Deliverable'], status, (val) => setState(() => status = val!))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDropdown('Search By', ['None', 'Ticket #', 'Description'], searchBy, (val) => setState(() => searchBy = val!))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Search', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('From Date', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _pickDate(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(fromDate != null ? _formatDate(fromDate!) : 'Select'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('To Date', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _pickDate(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(toDate != null ? _formatDate(toDate!) : 'Select'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (dateErrorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              dateErrorText!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 12),

        /// Ticket Group & Active checkbox
        StatefulBuilder(
          builder: (context, setLocalState) {
            print("Selected ticket group: $selectedTicketGroup");
            print("Available group codes:");
            for (var g in ticketGroups) {
              print(" - ${g['Code'] ?? 'null'} (${g['Description'] ?? 'no description'})");
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ticket Group', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButton<String>(
                          value: (selectedTicketGroup != null &&
                              ticketGroups.any((g) => g['Code'] == selectedTicketGroup))
                              ? selectedTicketGroup
                              : null,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const Text('Select Group'),
                          disabledHint: const Text("Loading..."),
                          items: ticketGroups.map((group) {
                            final code = group['Code']?.toString() ?? '';
                            final desc = group['Description']?.toString() ?? code;
                            return DropdownMenuItem(
                              value: code,
                              child: Text(desc),
                            );
                          }).toList(),
                          onChanged: isTicketGroupLoading
                              ? null
                              : (value) => setLocalState(() => selectedTicketGroup = value),

                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(' '),
                    Row(
                      children: [
                        Checkbox(
                          value: useActiveGroupsOnly,
                          onChanged: (value) async {
                            setLocalState(() => useActiveGroupsOnly = value ?? true);
                            await _fetchTicketGroups();
                            //setLocalState(() {}); // refreshes dropdown after fetch
                          },
                        ),
                        const Text('Active Groups Only'),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(child: _buildDropdown('Sort By', ['Last Activity', 'Start Date'], sortBy, (val) => setState(() => sortBy = val!))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(' ', style: TextStyle(fontWeight: FontWeight.w500)),
                  ElevatedButton(
                    onPressed: _fetchAndSetTickets,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlueAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Search'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> options, String selected, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<String>(
            value: selected,
            isExpanded: true,
            underline: const SizedBox(),
            items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard({
    required String ticketKey,
    required String date,
    required String shortDesc,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ticketKey, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(date, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(shortDesc),
          ],
        ),
      ),
    );
  }
}