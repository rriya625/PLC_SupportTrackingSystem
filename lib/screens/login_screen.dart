import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test_project/constants.dart';
import 'package:test_project/screens/home_screen.dart';
import 'package:test_project/screens/api_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';


/// A stateful widget that represents the login screen for the Porter Lee Corporationcustomer support system. It includes:
/// - Title and subtitle branding
/// - Input fields for User ID and Password
/// - A Login button (with placeholder logic)
/// - A logo image at the bottom ("Unleash the Beast")
class LoginScreen extends StatefulWidget {
  /// Controller for the User ID input field
  final TextEditingController userIdController = TextEditingController(text: '12819');

  /// Controller for the Password input field
  final TextEditingController passwordController = TextEditingController(text: '6779');

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version}+${info.buildNumber}';
    });
  }

  /// Builds the UI of the login screen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // SafeArea ensures content avoids system status bar areas
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 500),
                child: Column(
                  children: [
                  // App title
                  Text(
                    'Porter Lee Corporation',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Comic Sans MS',
                      color: Colors.blue[800],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 20),

                  // Subtitle banner
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.lightBlueAccent.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Customer Support System',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),

                  SizedBox(height: 30),

                  // User ID input field
                  buildTextField('User ID:', widget.userIdController),

                  SizedBox(height: 10),

                  // Password input field (obscured text)
                  buildTextField('Password:', widget.passwordController, obscure: true),

                  SizedBox(height: 20),

                  ValueListenableBuilder<String?>(
                    valueListenable: errorNotifier,
                    builder: (context, errorText, child) {
                      if (errorText == null) return SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          errorText,
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      );
                    },
                  ),

                  // Login button with authentication logic
                  ElevatedButton(
                    onPressed: () async {
                      String userId = widget.userIdController.text.trim();
                      String password = widget.passwordController.text;

                      if (userId.isEmpty && password.isEmpty) {
                        errorNotifier.value = 'Please enter both User ID and Password.';
                        return;
                      } else if (userId.isEmpty) {
                        errorNotifier.value = 'Please enter your User ID.';
                        return;
                      } else if (password.isEmpty) {
                        errorNotifier.value = 'Please enter your Password.';
                        return;
                      } else {
                        errorNotifier.value = null;
                      }

                      try {
                        final dynamic response = await APIHelper.loginUser(userId, password);
                        try {
                          // Handle case where web responds with OPTIONS (CORS preflight) instead of POST
                          if (response is Map && response.containsKey('method') && response['method'] == 'OPTIONS') {
                            errorNotifier.value = 'API Error: Expected POST but received an OPTIONS preflight (CORS).';
                            return;
                          }

                          // Success path: APIHelper returns null on success
                          if (response == null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => HomeScreen()),
                            );
                            return;
                          }

                          // API returned an error payload
                          if (response is String) {
                            errorNotifier.value = response;
                          } else if (response is Map && response.containsKey('Code') && response.containsKey('Message')) {
                            errorNotifier.value = 'Error ' + response['Code'].toString() + ': ' + response['Message'].toString();
                          } else {
                            errorNotifier.value = 'Unexpected error. Please try again.';
                          }
                        } finally {
                          // No dialog to pop here
                        }
                      } on Exception catch (e) {
                        final msg = e.toString();
                        if (msg.contains('XMLHttpRequest error') || msg.contains('CORS') || msg.contains('Failed to fetch')) {
                          errorNotifier.value = 'API Error: Browser sent OPTIONS (CORS preflight) or CORS blocked the POST. Ask server to allow CORS for POST /login.';
                        } else {
                          errorNotifier.value = 'Network error: ' + msg;
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlueAccent,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    ),
                    child: Text('Login', style: TextStyle(fontSize: 16)),
                  ),


                  SizedBox(height: 30),

                  // "Unleash the Beast" image/logo
                  Image.asset('assets/beast.png', height: 220),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Version: $_version',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          )
        ],
      ),
    );
  }


  /// Helper method to build a labeled text field.
  ///
  /// [label] is the field label (e.g., "User ID:")
  /// [controller] is the TextEditingController for the field
  /// [obscure] determines whether the text should be hidden (used for passwords)
  Widget buildTextField(String label, TextEditingController controller, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16)),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }
}
