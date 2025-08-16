import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:test_project/screens/report_issue_screen.dart';
import 'package:test_project/screens/view_tickets_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:test_project/constants.dart';
import 'package:test_project/screens/api_helper.dart';
/// Home screen shown after successful login.
/// Displays navigation buttons and support contact info with branding.
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = "User";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {

    });
    _loadUserInfo();
  }

  void _loadUserInfo() async {
    await Future.delayed(Duration(milliseconds: 100)); // wait for nav to complete
    if (!mounted) return;
    setState(() {
      print("Loaded contact name from Constants: '${Constants.contactName}'");
      userName = (Constants.contactName.trim().isNotEmpty)
          ? Constants.contactName
          : "User";
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: kIsWeb ? 800 : double.infinity),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Welcome, $userName!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMainButton(
                      icon: Icons.search,
                      label: 'View Tickets',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ViewTicketsScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildMainButton(
                      icon: Icons.report_problem_outlined,
                      label: 'Report Issue',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ReportIssueScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildMainButton(
                      icon: Icons.phone,
                      label: 'Call Support',
                      onTap: _launchCall,
                    ),
                    const SizedBox(height: 20),
                    _buildMainButton(
                      icon: Icons.email,
                      label: 'Email Support',
                      onTap: _launchEmail,
                    ),
                    const SizedBox(height: 20),
                    _buildMainButton(
                      icon: Icons.password,
                      label: 'Update Password',
                      onTap: _showUpdatePasswordDialog,
                    ),
                    const SizedBox(height: 20),
                    _buildMainButton(
                      icon: Icons.logout,
                      label: 'Logout',
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
            Image.asset(
              'assets/beast.png',
              height: 140,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text('Porter Lee Corporation'),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, //This hides the back arrow
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: content,
        ),
      ),
    );
  }

  /// Builds a large rounded button with icon and label.
  Widget _buildMainButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 24),
        label: Text(label, style: const TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlueAccent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
      ),
    );
  }

  /// Launches phone dialer
  void _launchCall() async {
    final Uri url = Uri.parse('tel:8479852060');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  /// Launches email client
  void _launchEmail() async {
    final Uri url = Uri.parse('mailto:support@porterlee.com');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showUpdatePasswordDialog() {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 500),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: currentPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Current Password'),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'Password must be at least 8 characters,\ninclude an uppercase letter, a lowercase letter,\nand a special character.',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                        TextField(
                          controller: newPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'New Password'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Confirm New Password'),
                        ),
                        if (errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Text(
                              errorText!,
                              style: TextStyle(
                                color: errorText!.toLowerCase().contains('password') && errorText!.toLowerCase().contains('success') ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final currentPassword = currentPasswordController.text.trim();
                    final newPassword = newPasswordController.text.trim();
                    final confirmPassword = confirmPasswordController.text.trim();

                    final passwordPattern = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*[!@#\$&*~]).{8,}$');
                    if (!passwordPattern.hasMatch(newPassword)) {
                      setState(() => errorText = 'Password does not meet requirements.');
                      return;
                    }

                    if (newPassword != confirmPassword) {
                      setState(() => errorText = 'New passwords do not match.');
                      return;
                    }

                    try {
                      final result = await APIHelper.updatePassword(
                        userId: Constants.userID,
                        currentPassword: currentPassword,
                        newPassword: newPassword,
                      );
                      if (!context.mounted) return;
                      if (result.toLowerCase().contains('success')) {
                        setState(() => errorText = 'Password changed successfully.');
                      } else {
                        setState(() => errorText = result);
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      setState(() => errorText = 'Failed to update password: $e');
                    }
                  },
                  child: const Text('Submit'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}