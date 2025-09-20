import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/utils/api_helper.dart';
import 'package:ticket_tracker_app/screens/ticket_description_screen.dart';
import 'package:ticket_tracker_app/utils/spinner_helper.dart';

class ViewActivityScreen extends StatefulWidget {
  final String ticketNumber;
  final String shortDescription;

  const ViewActivityScreen({
    super.key,
    required this.ticketNumber,
    required this.shortDescription,
  });

  @override
  State<ViewActivityScreen> createState() => _ViewActivityScreenState();
}

class _ViewActivityScreenState extends State<ViewActivityScreen> {
  List<Map<String, dynamic>> activityData = [];

  @override
  void initState() {
    super.initState();
    fetchActivityData();
  }

  Future<void> fetchActivityData() async {
    try {
      final data = await APIHelper.getActivityMessages(widget.ticketNumber);
      setState(() {
        activityData = data;
      });
    } catch (e) {
      debugPrint('Error fetching activity messages: $e');
    }
  }

  void _showCreateActivityDialog() {
    String? selectedPriorityCode = '5';
    TextEditingController messageController = TextEditingController();
    FocusNode messageFocusNode = FocusNode();
    bool isCritical = false;
    bool showPriorityError = false;
    bool showMessageError = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              messageFocusNode.requestFocus();
            });
            return AlertDialog(
              title: const Text('Create Activity'),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Priority'),
                      FutureBuilder<List<Map<String, String>>>(
                        future: APIHelper.getCodeList('PRIORITY'),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator();
                          }
                          final options = snapshot.data!;
                          return DropdownButton<String>(
                            isExpanded: true,
                            value: selectedPriorityCode,
                            hint: const Text('Select...'),
                            onChanged: (value) {
                              setState(() {
                                selectedPriorityCode = value;
                              });
                            },
                            items: options.map((option) {
                              return DropdownMenuItem<String>(
                                value: option['Code'],
                                child: Text('${option['Code']} - ${option['Description']}'),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      if (showPriorityError)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Please select a priority',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Text('Message'),
                      TextField(
                        controller: messageController,
                        focusNode: messageFocusNode,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (showMessageError)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Message is required',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: isCritical,
                            onChanged: (value) {
                              setState(() {
                                isCritical = value ?? false;
                              });
                            },
                          ),
                          const Text('Critical'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    setState(() {
                      showPriorityError = selectedPriorityCode == null;
                      showMessageError = messageController.text.trim().isEmpty;
                    });

                    if (showPriorityError || showMessageError) return;

                    showUploadSpinner('Creating activity...');

                    final payload = {
                      "TicketKey": int.tryParse(widget.ticketNumber) ?? 0,
                      "ProspectKey": Constants.userID,
                      "LongDesc": messageController.text.trim(),
                      "Priority": selectedPriorityCode!,
                      "Critical": isCritical ? "Y" : "N",
                    };

                    final url = Uri.parse('${Constants.baseUrlData}CreateActivity');

                    try {
                      final response = await http.post(
                        url,
                        headers: {
                          'Authorization': 'Bearer ${Constants.accessToken}',
                          'Content-Type': 'application/json',
                        },
                        body: jsonEncode(payload),
                      );

                      if (response.statusCode == 200) {
                        if (!context.mounted) return;
                        hideUploadSpinner();
                        Navigator.pop(context);
                        fetchActivityData(); // ✅ Refresh list
                      } else {
                        debugPrint('❌ Failed to create activity: ${response.statusCode}');
                        debugPrint('Body: ${response.body}');
                        debugPrint('Payload: ${jsonEncode(payload)}');
                        debugPrint('URL: ${url.toString()}');
                        if (context.mounted) {
                          hideUploadSpinner();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to create activity.')),
                          );
                        }
                      }
                    } catch (e) {
                      debugPrint('❌ Error posting activity: $e');
                      if (context.mounted) {
                        hideUploadSpinner();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error posting activity: $e')),
                        );
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Activity'),
        //title: Text('Activity Records for Ticket #${widget.ticketNumber} - ${widget.shortDescription}'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activity Records for Ticket #${widget.ticketNumber} - ${widget.shortDescription}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: _showCreateActivityDialog,
                  child: const Text('Create Activity'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: activityData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return SizedBox(
                    width: double.infinity,
                    child: Card(
                      color: index % 2 == 0 ? Colors.grey[200] : Colors.blue[50],
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 14, color: Colors.black),
                                children: [
                                  const TextSpan(text: 'Entry Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: '${item['EntryDate'] ?? ''}'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 14, color: Colors.black),
                                children: [
                                  const TextSpan(text: 'Activity Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: '${item['ActivityType'] ?? ''}'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 14, color: Colors.black),
                                children: [
                                  const TextSpan(text: 'Entered By: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: '${item['EnteredBy'] ?? ''}'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 14, color: Colors.black),
                                children: [
                                  const TextSpan(text: 'Description: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: '${item['LongDesc'] ?? ''}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
