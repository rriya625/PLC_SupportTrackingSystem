import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/screens/api_helper.dart';
import 'package:ticket_tracker_app/utils/dialogs.dart';

class SendMessageScreen extends StatefulWidget {
  const SendMessageScreen({Key? key}) : super(key: key);


  @override
  State<SendMessageScreen> createState() => _SendMessageScreenState();
}


class _SendMessageScreenState extends State<SendMessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  String _name = '';
  List<String> _messageToOptions = [];
  String? _selectedMessageTo;
  String? _ticketKey;


  @override
  void initState() {
    super.initState();
    _name = Constants.contactName;
    // _ticketKey must be set in didChangeDependencies because ModalRoute.of(context) can't be called in initState.
    // So we leave it here and assign in didChangeDependencies.
    _fetchMessageToList();
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ticketKey ??= ModalRoute.of(context)?.settings.arguments as String?;
    print('TicketKey passed: $_ticketKey');
  }


  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }


  Future<void> _fetchMessageToList() async {
    final url = Uri.parse('${Constants.baseUrlData}GetMessageToList?QBLinkKey=${Constants.qbLinkKey}');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer ${Constants.accessToken}',
      'Accept': 'application/json',
    });


    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      print('Response body: ${response.body}');
      setState(() {
        _messageToOptions = jsonList
            .map((e) => e['Option'].toString())
            .where((option) => option != 'O' && option != '-- No Selection --')
            .toList();
        _selectedMessageTo = _messageToOptions.isNotEmpty ? _messageToOptions.first : null;
        print('Dropdown options: $_messageToOptions');
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load recipient list')),
      );
    }
  }




  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (_ticketKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket key is missing')),
      );
      return;
    }


    if (_selectedMessageTo == null || _selectedMessageTo == 'None') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a recipient')),
      );
      return;
    }


    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message cannot be empty')),
      );
      return;
    }


    final body = json.encode({
      'TicketKey': int.parse(_ticketKey!),
      'MessageTo': _selectedMessageTo,
      'sMessage': message,
      'UserID': Constants.userID.toString(),
      'UserName': _name,
    });


    print('Sending message body: $body');
    print('Using token: ${Constants.accessToken}');


    final response = await http.post(
      Uri.parse('${Constants.baseUrlData}SendMessage'),
      headers: {
        'Authorization': 'Bearer ${Constants.accessToken}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: body,
    );


    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent successfully')),
      );
      setState(() {
        _messageController.clear();
        _selectedMessageTo = _messageToOptions.isNotEmpty ? _messageToOptions.first : null;
      });
      FocusScope.of(context).unfocus();
      // Wait for the dialog to complete before popping the screen
      await showMessageDialog(context, 'Your message has been successfully sent to Porter Lee Corporation.');
      // Go back to the previous screen
      Navigator.of(context).pop();
    } else {
      print('Failed status: ${response.statusCode}');
      print('Response body: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Message'),
        backgroundColor: Colors.blue[800], // updated to blue
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
                const Text('Agency: Porter Lee', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Text('Name: $_name', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                const Text('Send your message to:', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedMessageTo,
                  items: _messageToOptions
                      .map((target) => DropdownMenuItem(value: target, child: Text(target)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMessageTo = value;
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Enter your message here:', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                TextField(
                  controller: _messageController,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Type your message here...',
                  ),
                ),
                const SizedBox(height: 24),
                // const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                    label: const Text('Submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlueAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                Center(
                  //child: Icon(Icons.message, size: 80, color: Colors.green),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
