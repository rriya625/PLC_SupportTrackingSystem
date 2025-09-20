import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/screens/home_screen.dart';
import 'package:ticket_tracker_app/utils/api_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
// import '../utils/log_helper.dart';
import '../utils/web_log_helper.dart';

class LoginScreen extends StatefulWidget {
  final TextEditingController userIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);
  final FocusNode userIdFocusNode = FocusNode();
  String _version = '';

  @override
  void initState() {
    super.initState();
    Constants.userID = 0;
    _loadVersion();

    // Focus the User ID field after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      userIdFocusNode.requestFocus();
    });
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version}+${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 500),
                child: Column(
                  children: [
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

                    // User ID
                    buildTextField(
                      'User ID:',
                      widget.userIdController,
                      focusNode: userIdFocusNode,
                    ),
                    SizedBox(height: 10),

                    // Password
                    buildTextField(
                      'Password:',
                      widget.passwordController,
                      obscure: true,
                    ),
                    SizedBox(height: 20),

                    // Error Message
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

                    // Login Button
                    ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlueAccent,
                        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      ),
                      child: Text('Login', style: TextStyle(fontSize: 16)),
                    ),
                    SizedBox(height: 30),

                    // Logo
                    Image.asset('assets/beast.png', height: 220),
                  ],
                ),
              ),
            ),
          ),

          // Version footer
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

  Future<void> _handleLogin() async {
    String userId = widget.userIdController.text.trim();
    String password = widget.passwordController.text;

    await WebLogHelper.log("User attempting to login with User ID: $userId");

    if (userId.isEmpty && password.isEmpty) {
      errorNotifier.value = 'Please enter both User ID and Password.';
      return;
    } else if (userId.isEmpty) {
      errorNotifier.value = 'Please enter your User ID.';
      return;
    } else if (password.isEmpty) {
      errorNotifier.value = 'Please enter your Password.';
      return;
    } else if (int.tryParse(userId) == null) {
      errorNotifier.value = 'Invalid Login';
      return;
    } else {
      errorNotifier.value = null;
    }

    try {
      final dynamic response = await APIHelper.loginUser(userId, password);

      if (response is Map && response.containsKey('method') && response['method'] == 'OPTIONS') {
        errorNotifier.value = 'API Error: Expected POST but received an OPTIONS preflight (CORS).';
        return;
      }

      if (response == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
        return;
      }

      if (response is String) {
        errorNotifier.value = response;
      } else if (response is Map && response.containsKey('Code') && response.containsKey('Message')) {
        errorNotifier.value = 'Error ${response['Code']}: ${response['Message']}';
      } else {
        errorNotifier.value = 'Unexpected error. Please try again.';
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('XMLHttpRequest error') || msg.contains('CORS') || msg.contains('Failed to fetch')) {
        errorNotifier.value = 'API Error: CORS issue. Ask server to allow POST requests.';
      } else {
        errorNotifier.value = 'Network error: $msg';
      }
    }
  }

  /// Builds a labeled TextField
  Widget buildTextField(String label, TextEditingController controller,
      {bool obscure = false, FocusNode? focusNode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16)),
        TextField(
          controller: controller,
          obscureText: obscure,
          focusNode: focusNode,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }
}