import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/screens/home_screen.dart';
import 'package:ticket_tracker_app/utils/api_helper.dart';
import 'package:ticket_tracker_app/widgets/build_version_label.dart';

class LoginScreen extends StatefulWidget {
  final TextEditingController userIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _invalidLoginMessage =
      'Invalid login, please check your user id and password and try again. '
      'If you are still experiencing issues, please contact the Porter Lee '
      'Support line to reset your password.';

  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);
  final FocusNode userIdFocusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    Constants.userID = 0;
    Constants.userType = '';
    Constants.accessLevel = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      userIdFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    userIdFocusNode.dispose();
    widget.userIdController.dispose();
    widget.passwordController.dispose();
    super.dispose();
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
                child: AutofillGroup(
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
                        padding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 20,
                        ),
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
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                      ),
                      SizedBox(height: 10),

                      // Password
                      buildTextField(
                        'Password:',
                        widget.passwordController,
                        obscure: true,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleLogin(),
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 12,
                          ),
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
          ),

          // ✅ Watermark for dev builds
          if (Constants.isDev)
            IgnorePointer(
              child: Stack(
                children: [
                  Center(
                    child: Transform.rotate(
                      angle: -0.7,
                      child: Text(
                        "DEVELOPMENT",
                        style: TextStyle(
                          fontSize: Constants.isMobileWeb ? 40 : 80,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.withOpacity(0.12),
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Transform.translate(
                      offset: const Offset(0, -200),
                      child: Transform.rotate(
                        angle: -0.7,
                        child: Text(
                          "DEVELOPMENT",
                          style: TextStyle(
                            fontSize: Constants.isMobileWeb ? 40 : 80,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.withOpacity(0.12),
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Align(
            alignment: Alignment.bottomLeft,
            child: BuildVersionLabel(),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
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
    } else if (int.tryParse(userId) == null) {
      errorNotifier.value = _invalidLoginMessage;
      return;
    } else {
      errorNotifier.value = null;
    }

    try {
      final dynamic response = await APIHelper.loginUser(userId, password);

      if (response is Map &&
          response.containsKey('method') &&
          response['method'] == 'OPTIONS') {
        errorNotifier.value =
            'API Error: Expected POST but received an OPTIONS preflight (CORS).';
        return;
      }

      if (response == null) {
        TextInput.finishAutofillContext();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
        return;
      }

      if (response is String) {
        errorNotifier.value = _invalidLoginMessage;
      } else if (response is Map &&
          response.containsKey('Code') &&
          response.containsKey('Message')) {
        errorNotifier.value =
            'Error ${response['Code']}: ${response['Message']}';
      } else {
        errorNotifier.value = 'Unexpected error. Please try again.';
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('XMLHttpRequest error') ||
          msg.contains('CORS') ||
          msg.contains('Failed to fetch')) {
        errorNotifier.value =
            'API Error: CORS issue. Ask server to allow POST requests.';
      } else {
        errorNotifier.value = 'Network error: $msg';
      }
    }
  }

  /// Builds a labeled TextField
  Widget buildTextField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    FocusNode? focusNode,
    Iterable<String>? autofillHints,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16)),
        TextField(
          controller: controller,
          obscureText: obscure,
          focusNode: focusNode,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autocorrect: false,
          enableSuggestions: !obscure,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }
}
