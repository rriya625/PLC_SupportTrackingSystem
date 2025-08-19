import 'package:flutter/material.dart';
import 'ticket_description_screen.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/screens/api_helper.dart';

class ViewTicketsScreen extends StatefulWidget {
  const ViewTicketsScreen({Key? key}) : super(key: key);

  @override
  State<ViewTicketsScreen> createState() => _ViewTicketsScreenState();
}

class _ViewTicketsScreenState extends State<ViewTicketsScreen> {
  String ticketType = 'Yours';
  String status = 'Open';
  String searchBy = 'None';
  String sortBy = 'Last Activity';
  final TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> tickets = [];

  @override
  void initState() {
    super.initState();
    _fetchAndSetTickets();
  }

  Future<void> _fetchAndSetTickets() async {
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
      );
      setState(() {
        tickets = data;
      });
      Navigator.of(context, rootNavigator: true).pop();
      debugPrint('Tickets fetched: ${tickets.length}');
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      debugPrint('Ticket fetch error: $e');
    }
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
}