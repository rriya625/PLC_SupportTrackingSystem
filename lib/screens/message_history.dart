import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:test_project/constants.dart'; // Assuming Constants.baseUrlData is defined here

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
    // Show loading dialog before making the API call
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Loading messages...', style: TextStyle(fontSize: 16)),
            ],
          ),
        );
      },
    );
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
      // Dismiss the loading dialog
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF1565C0), // Darker blue
        title: const Text(
          'Message History',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: messages.map((msg) {
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
            Text(
              'From: ${(msg['Message'] as String?)?.replaceFirstMapped(
                RegExp(r'^\*\([^)]*\)([^:]+):.*'),
                (match) => match.group(1)?.trim() ?? 'Unknown'
              ) ?? 'Unknown'}',
            ),
            const SizedBox(height: 4),
            Text(
              'Message: ${(msg['Message'] as String?)?.replaceFirst(RegExp(r'^\*\([^)]*\)[^:]*:\s*'), '')?.trim() ?? 'No message'}',
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
        ),
      ),
    );
  }
}