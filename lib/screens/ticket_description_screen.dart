import 'package:test_project/screens/view_activity.dart';
import 'package:test_project/screens/message_history.dart';
import 'send_message_screen.dart';
import 'package:flutter/material.dart';
import 'package:test_project/constants.dart';
import 'package:test_project/screens/api_helper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';


class TicketDescriptionScreenStateful extends StatefulWidget {
  const TicketDescriptionScreenStateful({Key? key}) : super(key: key);

  @override
  _TicketDescriptionScreenState createState() => _TicketDescriptionScreenState();
}

class _TicketDescriptionScreenState extends State<TicketDescriptionScreenStateful> {
  String ticketKey = '';
  String ticketNumber = '';
  String dateCreated = '';
  String assignedTo = '';
  String currentStatus = '';
  String shortDescription = '';
  String longDescription = '';

  final ImagePicker _picker = ImagePicker();
  final List<dynamic> _attachedImages = [];


  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final route = ModalRoute.of(context);
      final args = route?.settings.arguments;
      ticketKey = args?.toString() ?? '';
      print('Ticket key received: $ticketKey');
      if (ticketKey.isNotEmpty) {
        APIHelper.fetchTicketDetails(ticketKey).then((data) {
          if (data != null) {
            setState(() {
              ticketNumber = data['TicketKey'] ?? '';
              dateCreated = data['StartDate'] ?? '';
              assignedTo = data['EmployeeName'] ?? 'N/A';
              currentStatus = (data['Status'] == 'O') ? 'Open' : data['Status'] ?? '';
              shortDescription = data['ShortDesc'] ?? '';
              longDescription = _parseRtf(data['LongDesc'] ?? '');
            });
          } else {
            setState(() {
              assignedTo = 'Error loading data';
            });
          }
        });
      } else {
        print('No ticket key found in route arguments.');
      }
    });
  }

  String _parseRtf(String rtfText) {
    return rtfText
        .replaceAll(RegExp(r'\\[a-z]+\d*'), '')
        .replaceAll(RegExp(r'[{}]'), '')
        .replaceAll(r'\n', '\n')
        .trim();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: [],
        title: const Text('Ticket Description'),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField('Ticket Number:', ticketNumber),
            _buildField('Date Created:', dateCreated),
            _buildField('Assigned to:', assignedTo),
            _buildField('Current Status:', currentStatus),
            const SizedBox(height: 16),
            // New description section with larger box and row header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Description:', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(shortDescription, style: const TextStyle(fontSize: 16))),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 400,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Text(
                  longDescription,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
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
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final key = (ticketNumber.isNotEmpty ? ticketNumber : ticketKey).trim();
                            if (key.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ticket key is missing')),
                              );
                              return;
                            }

                            // Show loading dialog before API call
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            // Await API call to get file list
                            final files = await APIHelper.getCustomerDocsList(key);

                            // Dismiss loading dialog after API response
                            if (mounted) {
                              Navigator.of(context, rootNavigator: true).pop();
                            }

                            if (!mounted) return;

                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Colors.black, width: 1),
                                  ),
                                  titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                  actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                  title: Row(
                                    children: [
                                      Icon(Icons.insert_drive_file, color: Colors.blue[800]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'File Names',
                                        style: TextStyle(
                                          color: Colors.blue[800],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    child: files.isEmpty
                                        ? const Text('No files found.', style: TextStyle(fontSize: 14))
                                        : ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: files.length,
                                            itemBuilder: (context, index) {
                                              final file = files[index];
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 12.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'File ${index + 1}: ${file['date'] ?? ''}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      file['fileName'] ?? '',
                                                      style: const TextStyle(fontSize: 14),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    const Divider(height: 1, color: Colors.black12),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                  actions: [
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.black,
                                        backgroundColor: Colors.lightBlueAccent,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.black,
                                        backgroundColor: Colors.lightBlueAccent,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () async {
                                        Navigator.of(context).pop(); // Close the current dialog first
                                        final parentContext = this.context;
                                        await _showImagePreviewDialogOnly(parentContext, ticketKey); // Show the image preview popup
                                      },
                                      child: const Text('View Images'),
                                    ),
                                  ],
                                );
                              },
                            );
                          } catch (e) {
                            if (mounted) {
                              Navigator.of(context, rootNavigator: true).pop();
                            }
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error loading file names: $e')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('View File Names'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SendMessageScreen(),
                              settings: RouteSettings(arguments: ticketKey),
                            ),
                          );
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Send Message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MessageHistoryScreen(),
                              settings: RouteSettings(arguments: ticketNumber),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history),
                        label: const Text('Message History'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      print('Navigating to ViewActivityScreen with ticketNumber: $ticketNumber');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewActivityScreen(ticketNumber: ticketNumber),
                          settings: RouteSettings(arguments: ticketNumber),
                        ),
                      );
                    },
                    icon: const Icon(Icons.timeline),
                    label: const Text('View Activity'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlueAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Center(child: Icon(Icons.assignment_turned_in, size: 100, color: Colors.green)),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 16))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
  // All image/video/file picking and preview methods removed.

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
        _showMediaPreviewDialog();
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
        _showMediaPreviewDialog();
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

  Future<void> _pickVideoFromCamera() async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.camera);
    if (pickedFile != null) {
      print('Video recorded: ${pickedFile.path}');
      setState(() {
        _attachedImages.add(File(pickedFile.path));
      });
      _showMediaPreviewDialog();
    } else {
      print('No video recorded.');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      print('Video selected from gallery: ${pickedFile.path}');
      setState(() {
        _attachedImages.add(File(pickedFile.path));
      });
      _showMediaPreviewDialog();
    } else {
      print('No video selected.');
    }
  }
  void _showMediaPreviewDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Build the media widgets for preview
        final List<Widget> mediaWidgets = _attachedImages.isEmpty
            ? [const Text('No media attached.')]
            : List.generate(_attachedImages.length, (index) {
                final item = _attachedImages[index];
                if (item is File) {
                  final isVideo = item.path.toLowerCase().endsWith('.mp4') || item.path.toLowerCase().endsWith('.mov');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: isVideo
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Video Preview'),
                              const SizedBox(height: 8),
                              Container(
                                height: 200,
                                color: Colors.black12,
                                child: Center(child: Icon(Icons.videocam, size: 50, color: Colors.grey)),
                              ),
                              Text(item.path.split('/').last, style: const TextStyle(fontSize: 12)),
                            ],
                          )
                        : Image.file(item, height: 200),
                  );
                } else if (item is Uint8List) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Image.memory(item, height: 200),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              });
        return AlertDialog(
          title: const Text('Media Preview'),
          content: SingleChildScrollView(
            child: Column(children: mediaWidgets),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.lightBlueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  builder: (BuildContext context) {
                    return Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_camera),
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
              child: const Text('Add Another File'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.lightBlueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.of(context).pop(); // Close preview dialog

                await Future.delayed(const Duration(milliseconds: 100));

                late BuildContext dialogContext;

                // Show loading using captured dialog context
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  useRootNavigator: true,
                  builder: (BuildContext ctx) {
                    dialogContext = ctx;
                    return const Center(child: CircularProgressIndicator());
                  },
                );

                try {
                  final response = await APIHelper.uploadFiles(
                    ticketKey: int.tryParse(ticketKey) ?? 0,
                    prospectKey: int.tryParse(Constants.userID.toString()) ?? 0,
                    fileList: _attachedImages.whereType<File>().toList(),
                  );

                  print("📦 Upload done with status ${response.statusCode}");

                  Navigator.of(dialogContext).pop(); // ✅ Guaranteed to close the dialog

                  if (!context.mounted) return;

                  if (response.statusCode == 200) {
                    // --- BEGIN REPLACEMENT LOGIC ---
                    _attachedImages.clear();

                    await showGeneralDialog(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: 'Upload success',
                      barrierColor: Colors.black54,
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return SafeArea(
                          child: Builder(
                            builder: (context) => Center(
                              child: Material(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green, size: 60),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Upload Successful!',
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 20),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('OK'),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                    // --- END REPLACEMENT LOGIC ---
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Upload failed: ${response.statusCode}')),
                    );
                  }
                } catch (e) {
                  print("❌ Upload error: $e");
                  Navigator.of(dialogContext).pop(); // ✅ Also close on error
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Upload failed: $e')),
                  );
                }
              },
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
  }
  Future<void> _uploadAttachedImages(BuildContext context) async {
    if (_attachedImages.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images or videos to upload.')),
      );
      return;
    }

    final List<File> filesToUpload = _attachedImages.whereType<File>().toList();
    final int ticketKeyInt = int.tryParse(ticketKey) ?? 0;
    final int prospectKeyInt = int.tryParse(Constants.userID.toString()) ?? 0;

    if (ticketKeyInt == 0 || prospectKeyInt == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket or user ID is invalid.')),
      );
      return;
    }

    // Loading dialog is now handled externally
    try {
      final response = await APIHelper.uploadFiles(
        ticketKey: ticketKeyInt,
        prospectKey: prospectKeyInt,
        fileList: filesToUpload,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Files uploaded successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }
  // Shows a simple image preview dialog with just a close button, fetching images from API.
  Future<void> _showImagePreviewDialogOnly(BuildContext context, String ticketKey) async {
    final keyToUse = ticketKey;
    try {
      if (keyToUse.isEmpty) {
        // Don't show snackbar here; handle error after modal is dismissed or by returning a value.
        return;
      }

      print('📸 Fetching images for ticketKey: $keyToUse');
      final imageDataList = await APIHelper.getDownloadedImages(keyToUse);
      print("📦 Total images received from API: ${imageDataList.length}");
      print('🖼️ Retrieved ${imageDataList.length} images');

      if (!mounted) return; // Ensure widget is still mounted

      // Show an AlertDialog with custom blue header for title
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Theme.of(context).dialogBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            // Custom solid blue header for title
            title: Container(
              color: Colors.blue,
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                child: Text(
                  'Downloaded Images',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: imageDataList.isEmpty
                      ? [
                          Text(
                            'No valid images to display.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        ]
                      : imageDataList.map<Widget>((imageData) {
                          final fileName = imageData['FileName'] ?? 'Unnamed';
                          final imageBytes = imageData['Base64Content'];
                          if (imageBytes is! Uint8List || imageBytes.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fileName, style: Theme.of(context).textTheme.bodyLarge),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(imageBytes, height: 200, fit: BoxFit.cover),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // Don't show snackbar here; handle error after modal is dismissed or by returning a value.
      return;
    }
  }
}