import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/utils/spinner_helper.dart'; // Import the global spinner functions
import 'package:ticket_tracker_app/screens/send_message_screen.dart';

class MessageHistoryScreen extends StatefulWidget {
  const MessageHistoryScreen({super.key});

  @override
  State<MessageHistoryScreen> createState() => _MessageHistoryScreenState();
}

class _MessageHistoryScreenState extends State<MessageHistoryScreen> {
  List<dynamic> messages = [];
  String? ticketNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null) {
        ticketNumber = args.toString();
        _fetchMessages();
      }
    });
  }

  Future<void> _fetchMessages() async {
    showUploadSpinner("Loading messages...");

    try {
      final url = Uri.parse('${Constants.baseUrlData}GetMessagesForTicket?TicketKey=$ticketNumber');
      debugPrint('Calling Message History API: $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${Constants.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('Message API status: ${response.statusCode}');
      debugPrint('Message API body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('Decoded body: $decoded');

        if (decoded is List) {
          setState(() {
            messages = decoded;
          });
        } else if (decoded is Map && decoded.containsKey('Data')) {
          setState(() {
            messages = decoded['Data'];
          });
        } else {
          debugPrint('Unexpected message format');
          setState(() {
            messages = [];
          });
        }
      } else {
        setState(() {
          messages = [];
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching messages: $e');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        messages = [];
      });
    } finally {
      hideUploadSpinner();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text('Message History', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Render each message widget
            ...messages.map((msg) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: messages.indexOf(msg) % 2 == 0 ? Colors.grey[200] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To: ${msg['EmployeeName'] ?? 'Unknown'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    // Extract sender name
                    Text(
                      //'From: ${(msg['Message'] as String?)?.replaceFirstMapped(  RegExp(r'^\\*([^)]*)[^:]*:.*'),  (match) => match.group(1)?.trim() ?? 'Unknown', ) ?? 'Unknown'}',
                      'From: ${msg['MsgFrom'] ?? 'Unknown'}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Message: ${(msg['Message'] as String?)?.replaceFirst(
                        RegExp(r'^\\*([^)]*)[^:]*:\\s*'),
                        '',
                      )?.trim() ?? 'No message'}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      msg['DateSent'] ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 20), // spacing between messages and button

            // Single "Send Message" button at the end of the list
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Send Message'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.lightBlueAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                // Ensure ticketNumber is available
                if (ticketNumber == null) return;

                // Navigate to SendMessageScreen and pass the ticket number
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SendMessageScreen(),
                    settings: RouteSettings(arguments: ticketNumber),
                  ),
                );
                // Refresh messages after returning
                _fetchMessages();
              },
            ),
          ],
        ),
      ),
    );
  }
}