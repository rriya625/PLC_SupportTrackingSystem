import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:test_project/screens/api_helper.dart';
import 'package:test_project/screens/ticket_description_screen.dart';
import 'dart:convert';
import 'package:test_project/constants.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Report Issue screen for creating a new support ticket.
class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({Key? key}) : super(key: key);

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  List<String> _priorityOptions = [];
  String _selectedPriority = 'Normal';

  final _shortDescController = TextEditingController();
  final _detailedDescController = TextEditingController();
  final _customerRefController = TextEditingController();
  final _confirmationToController = TextEditingController();

  // For web, store images as List<Uint8List>; for mobile, List<File>
  List<dynamic> _attachedImages = [];
  final ImagePicker _picker = ImagePicker();

  String? shortDescError;
  String? detailedDescError;

  Future<void> _pickImageFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _attachedImages.add(bytes);
          });
        } else {
          setState(() {
            _attachedImages.add(File(pickedFile.path));
          });
        }
        print('Image captured: ${pickedFile.path}');
        _showMediaPreviewDialogOnly(context);
      } else {
        print('No image selected.');
      }
    } catch (e) {
      print('Camera access error: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _attachedImages.add(bytes);
          });
        } else {
          setState(() {
            _attachedImages.add(File(pickedFile.path));
          });
        }
        print('Image selected from gallery: ${pickedFile.path}');
        _showMediaPreviewDialogOnly(context);
      } else {
        print('No image selected.');
      }
    } catch (e) {
      print('Gallery access error: $e');
    }
  }

  Future<void> _pickImageFromFiles() async {
    print('Choose File tapped. Implement file picker here.');
  }

  void _showImagePreviewDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take a Picture'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam),
              title: Text('Record a Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideoFromCamera();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose Picture from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: Icon(Icons.video_library),
              title: Text('Choose Video from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickVideoFromGallery();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill the confirmation to controller with the email address.
    _confirmationToController.text = Constants.emailAddress;
    _loadPriorityOptions();
  }

  Future<void> _loadPriorityOptions() async {
    try {
      final codeList = await APIHelper.getCodeList("PRIORITY");
      print('Priority options received: $codeList');
      setState(() {
        _priorityOptions = codeList.map((e) => '${e['Code']} - ${e['Description']}').toList();
        _selectedPriority = _priorityOptions.firstWhere(
          (item) => item.startsWith("5 -"),
          orElse: () => _priorityOptions.isNotEmpty ? _priorityOptions[0] : 'Normal',
        );
      });
    } catch (e) {
      print('Failed to load priorities: $e');
      setState(() {
        _priorityOptions = ['Normal'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Ticket'),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: true,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Priority Dropdown
              _buildDropdownField(
                label: 'Priority',
                value: _selectedPriority,
                items: _priorityOptions,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPriority = val);
                },
              ),

              const SizedBox(height: 16),
              _buildTextField(label: 'Short Description', controller: _shortDescController, isRequired: true, errorText: shortDescError),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Detailed Description',
                controller: _detailedDescController,
                maxLines: 4,
                isRequired: true,
                errorText: detailedDescError,
              ),
              const SizedBox(height: 16),
              _buildTextField(label: 'Customer Ref', controller: _customerRefController),
              const SizedBox(height: 16),
              _buildTextField(label: 'Send Confirmation To', controller: _confirmationToController),

              const SizedBox(height: 24),

              // Upload File Button Only
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (BuildContext context) {
                            return Wrap(
                              children: [
                                ListTile(
                                  leading: Icon(Icons.camera_alt),
                                  title: Text('Take Photo'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickImageFromCamera();
                                  },
                                ),
                                ListTile(
                                  leading: Icon(Icons.videocam),
                                  title: Text('Record Video'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickVideoFromCamera();
                                  },
                                ),
                                ListTile(
                                  leading: Icon(Icons.photo_library),
                                  title: Text('Choose Photo from Gallery'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickImageFromGallery();
                                  },
                                ),
                                ListTile(
                                  leading: Icon(Icons.video_library),
                                  title: Text('Choose Video from Gallery'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickVideoFromGallery();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Attach File', style: TextStyle(color: Colors.black)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_attachedImages.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Images Attached: ${_attachedImages.length}'),
                ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
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
                                Text("Uploading ticket and files..."),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                    final shortDesc = _shortDescController.text.trim();
                    final longDesc = _detailedDescController.text.trim();

                    setState(() {
                      shortDescError = shortDesc.isEmpty ? 'This field is required' : null;
                      detailedDescError = longDesc.isEmpty ? 'This field is required' : null;
                    });
                    if (shortDescError != null || detailedDescError != null) {
                      Navigator.of(context, rootNavigator: true).pop();
                      return;
                    }

                    final priority = _selectedPriority.split(' - ').first;
                    final customerReference = _customerRefController.text.trim();
                    final confirmationTo = _confirmationToController.text.trim();
                    final qbLinkKey = Constants.qbLinkKey;
                    final userId = Constants.userID;

                    try {
                      final response = await APIHelper.createTicket(
                        prospectKey: userId,
                        priority: priority,
                        shortDesc: shortDesc,
                        qbLinkKey: qbLinkKey,
                        customerReference: customerReference,
                        longDesc: longDesc,
                        confirmationEmail: confirmationTo,
                      );
                      print('Create Ticket Response: $response');

                      final ticketKey = response['Ticket Key'];
                      // Upload attached images to the created ticket
                      if (_attachedImages.isNotEmpty && !kIsWeb) {
                        final filesToUpload = _attachedImages.whereType<File>().toList();
                        final response = await APIHelper.uploadFiles(
                          ticketKey: int.parse(ticketKey.toString()),
                          prospectKey: Constants.userID,
                          fileList: filesToUpload,
                        );
                        if (!context.mounted) return;

                        print('Upload Files Response: ${response.statusCode} ${response.body}');

                        Future.microtask(() async {
                          if (!context.mounted) return;
                          Navigator.of(context).pop();

                          // Minimal fallback dialog for constrained UI environments
                          if (!context.mounted) return;
                          await showDialog(
                            context: context,
                            useRootNavigator: true,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      response.statusCode == 200 ? Icons.check_circle : Icons.error,
                                      color: response.statusCode == 200 ? Colors.green : Colors.red,
                                      size: 60,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      response.statusCode == 200
                                          ? 'Upload successful'
                                          : 'Upload failed: ${response.statusCode}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                actions: [
                                  // Attach More button
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return Wrap(
                                            children: [
                                              ListTile(
                                                leading: const Icon(Icons.camera_alt),
                                                title: const Text('Take Photo'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _pickImageFromCamera();
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.videocam),
                                                title: const Text('Record Video'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _pickVideoFromCamera();
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.photo_library),
                                                title: const Text('Choose Photo from Gallery'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _pickImageFromGallery();
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.video_library),
                                                title: const Text('Choose Video from Gallery'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _pickVideoFromGallery();
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    child: const Text('Attach More'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              );
                            },
                          );
                        });
                        setState(() => _attachedImages.clear());
                      }

                      Navigator.of(context, rootNavigator: true).pop();
                      // Only show SnackBar and navigate after any image upload completes
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ticket created: #$ticketKey')),
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TicketDescriptionScreenStateful(),
                          settings: RouteSettings(arguments: ticketKey.toString()),
                        ),
                      );

                      // Clear fields after successful submission
                      setState(() {
                        _shortDescController.clear();
                        _detailedDescController.clear();
                        _customerRefController.clear();
                        _selectedPriority = _priorityOptions.firstWhere(
                          (item) => item.startsWith("5 -"),
                          orElse: () => _priorityOptions.isNotEmpty ? _priorityOptions[0] : 'Normal',
                        );
                      });
                    } catch (e) {
                      Navigator.of(context, rootNavigator: true).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to create ticket: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Submit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlueAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Bottom icon image
              const Icon(Icons.task_alt_rounded, size: 90, color: Colors.green),
            ],
          ),
        ),
      ),
    );
  }

  /// Creates a styled text input field.
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    bool isRequired = false,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: const TextStyle(fontSize: 16),
            children: isRequired
                ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
                : [],
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            errorText: errorText,
          ),
        ),
      ],
    );
  }

  /// Creates a styled dropdown field.
  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            value: value,
            underline: const SizedBox(),
            items: items.map((priority) {
              return DropdownMenuItem(
                value: priority,
                child: Text(priority.contains(' - ') ? priority.split(' - ').last : priority),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
  Future<void> _pickVideoFromCamera() async {
    try {
      final pickedFile = await _picker.pickVideo(source: ImageSource.camera);
      if (pickedFile != null) {
        if (kIsWeb) {
          // Do nothing for now; or implement as needed for web
        } else {
          setState(() {
            _attachedImages.add(File(pickedFile.path));
          });
        }
        print('Video recorded: ${pickedFile.path}');
        _showMediaPreviewDialogOnly(context);
      } else {
        print('No video recorded.');
      }
    } catch (e) {
      print('Camera access error: $e');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile != null) {
        if (kIsWeb) {
          // Do nothing for now; or implement as needed for web
        } else {
          setState(() {
            _attachedImages.add(File(pickedFile.path));
          });
        }
        print('Video selected from gallery: ${pickedFile.path}');
        _showMediaPreviewDialogOnly(context);
      } else {
        print('No video selected.');
      }
    } catch (e) {
      print('Gallery access error: $e');
    }
  }
  // Show media preview dialog similar to ticket_description_screen.dart
  Future<void> _showMediaPreviewDialogOnly(BuildContext parentContext) async {
    await showDialog(
      context: parentContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Attached Files'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _attachedImages.map<Widget>((item) {
                final isVideo = item is File && item.path.toLowerCase().endsWith('.mp4');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item is File ? item.path.split('/').last : 'Image',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isVideo
                            ? Container(
                                height: 200,
                                color: Colors.black12,
                                child: const Center(
                                  child: Icon(Icons.videocam, size: 50, color: Colors.grey),
                                ),
                              )
                            : (kIsWeb
                                ? Image.memory(item as Uint8List, height: 200, fit: BoxFit.cover)
                                : Image.file(item as File, height: 200, fit: BoxFit.cover)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  builder: (BuildContext context) {
                    return Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Take Photo'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickImageFromCamera();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.videocam),
                          title: const Text('Record Video'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickVideoFromCamera();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Choose Photo from Gallery'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickImageFromGallery();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.video_library),
                          title: const Text('Choose Video from Gallery'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickVideoFromGallery();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text('Add More'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}