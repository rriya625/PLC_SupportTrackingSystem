import 'package:flutter/services.dart';
import 'package:ticket_tracker_app/utils/messages_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:ticket_tracker_app/screens/report_issue_screen.dart';
import 'package:ticket_tracker_app/screens/view_tickets_screen.dart';
import 'messages_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/utils/api_helper.dart';
import 'package:flutter/foundation.dart'; // already present
import 'dart:io' show Platform;
import 'package:ticket_tracker_app/utils/dialogs.dart';
import 'dart:math' as math;
import 'package:ticket_tracker_app/screens/login_screen.dart';
import 'package:ticket_tracker_app/utils/file_download_helper.dart';
import 'package:ticket_tracker_app/utils/web_log_helper.dart';
import 'package:ticket_tracker_app/widgets/build_version_label.dart';

/// Home screen shown after successful login.
/// Displays navigation buttons and support contact info with branding.
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key, this.messagesApi}) : super(key: key);
  final MessagesApi? messagesApi;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = "User";
  bool unreadMessages = false;
  Future<void> _refreshMessages() async {
    try {
      final result = await (widget.messagesApi ?? MessagesApi()).call(
        "GetMessages",
        query: {"BeforeKey": "0", "PageSize": "1"},
      );
      if (mounted)
        setState(
          () => unreadMessages =
              (int.tryParse(result["UnreadCount"]?.toString() ?? "") ?? 0) > 0,
        );
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {});
    _loadUserInfo();
    _refreshMessages();
  }

  void _loadUserInfo() async {
    await Future.delayed(
      Duration(milliseconds: 100),
    ); // wait for nav to complete
    if (!mounted) return;
    setState(() {
      print("Loaded contact name from Constants: '${Constants.contactName}'");
      userName = (Constants.contactName.trim().isNotEmpty)
          ? Constants.contactName
          : "User";
    });
  }

  bool isMobile() {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
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
                          MaterialPageRoute(
                            builder: (context) => ViewTicketsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildMainButton(
                      icon: Icons.report_problem_outlined,
                      label: 'Create New Ticket',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReportIssueScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildMainButton(
                      icon: Icons.mail_outline,
                      label: 'Messages',
                      attention: unreadMessages,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MessagesScreen(),
                          ),
                        );
                        if (mounted) await _refreshMessages();
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

                    if (Constants.isDebugModeEnabled) ...[
                      _buildMainButton(
                        icon: Icons.download_for_offline_outlined,
                        label: 'Download Diagnostic Log',
                        onTap: _downloadDiagnosticLog,
                      ),
                      const SizedBox(height: 20),
                    ],

                    _buildMainButton(
                      icon: Icons.menu_book,
                      label: 'Download User Manual',
                      onTap: () async {
                        await FileDownloadHelper.downloadUserManual(context);
                        await WebLogHelper.log(
                          "User attempted manual download",
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildMainButton(
                      icon: Icons.logout,
                      label: 'Logout',
                      onTap: () {
                        // Optionally clear user session variables
                        Constants.userID = 0;
                        Constants.contactName = '';
                        Constants.debugMode = 'N';
                        WebLogHelper.clear();

                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            !isMobile()
                ? Image.asset(
                    'assets/beast.png',
                    height: 140,
                    fit: BoxFit.contain,
                  )
                : const SizedBox.shrink(),
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

      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: content,
            ),
          ),

          // ✅ Show "DEVELOPMENT" ribbon if buildEnv is dev
          if (Constants.isDev)
            IgnorePointer(
              child: Transform.translate(
                offset: const Offset(
                  0,
                  -50,
                ), // ✅ shift entire watermark group upward
                child: Stack(
                  children: [
                    // Center watermark (now higher)
                    Center(
                      child: Transform.rotate(
                        angle: -0.7, // ~ -40 degrees
                        child: Text(
                          "DEVELOPMENT",
                          style: TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.withOpacity(0.12),
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                    // Second watermark (even higher)
                    Center(
                      child: Transform.translate(
                        offset: const Offset(
                          0,
                          -200,
                        ), // extra shift above the first one
                        child: Transform.rotate(
                          angle: -0.7,
                          child: Text(
                            "DEVELOPMENT",
                            style: TextStyle(
                              fontSize: 80,
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
            ),
          const Align(
            alignment: Alignment.bottomLeft,
            child: BuildVersionLabel(),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadDiagnosticLog() async {
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Download Diagnostic Log'),
          content: const Text(
            'Download the most recent log file or all log files for a specific day?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'day'),
              child: const Text('Choose Day'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'latest'),
              child: const Text('Most Recent'),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;

      String? date;
      if (choice == 'day') {
        final selected = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (selected == null) return;
        date =
            '${selected.year.toString().padLeft(4, '0')}-'
            '${selected.month.toString().padLeft(2, '0')}-'
            '${selected.day.toString().padLeft(2, '0')}';
      }

      await WebLogHelper.downloadServerLog(date: date);
    } catch (error) {
      debugPrint('Diagnostic log save was cancelled or failed: $error');
      if (mounted) {
        await showMessageDialog(
          context,
          'Unable to download the diagnostic log. $error',
        );
      }
    }
  }

  /// Builds a large rounded button with icon and label.
  Widget _buildMainButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool attention = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            color: attention ? Colors.red[900] : Colors.black,
            fontWeight: attention ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlueAccent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
      ),
    );
  }

  /// Launches phone dialer
  void _launchCall() async {
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (mobile) {
      try {
        if (await launchUrl(Uri.parse('tel:8479852060'))) return;
      } catch (_) {}
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Call Porter Lee Support'),
        content: const SelectableText(
          'Please call us at (847) 985-2060. We’re happy to help.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: '8479852060'));
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Copy number'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Launches email client
  void _launchEmail() async {
    final Uri url = Uri.parse('mailto:support@porterlee.com');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showUpdatePasswordDialog() {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    final FocusNode newPasswordFocusNode = FocusNode(); // ✅ Focus node added

    showDialog(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            // ✅ Autofocus after dialog builds
            WidgetsBinding.instance.addPostFrameCallback((_) {
              newPasswordFocusNode.requestFocus();
            });

            return AlertDialog(
              title: const Text('Change Password'),
              constraints: BoxConstraints(
                minWidth: math.min(
                  500.0,
                  MediaQuery.of(context).size.width * 0.6,
                ),
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              content: kIsWeb
                  ? SizedBox(
                      width: 400,
                      height:
                          MediaQuery.of(context).size.height *
                          0.4, // ✅ 40% screen height on web
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: currentPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Current Password',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'Password must be at least 8 characters,\ninclude an uppercase letter, a lowercase letter,\nand one special character (! @ # \$ & * ~).',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            TextField(
                              controller: newPasswordController,
                              focusNode: newPasswordFocusNode,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'New Password',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Confirm New Password',
                              ),
                            ),
                            if (errorText != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: Text(
                                  errorText!,
                                  style: TextStyle(
                                    color:
                                        errorText!.toLowerCase().contains(
                                          'success',
                                        )
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : Center(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: currentPasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Current Password',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  'Password must be at least 8 characters,\ninclude an uppercase letter, a lowercase letter,\nand one special character (! @ # \$ & * ~).',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              TextField(
                                controller: newPasswordController,
                                focusNode: newPasswordFocusNode,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'New Password',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: confirmPasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm New Password',
                                ),
                              ),
                              if (errorText != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Text(
                                    errorText!,
                                    style: TextStyle(
                                      color:
                                          errorText!.toLowerCase().contains(
                                            'success',
                                          )
                                          ? Colors.green
                                          : Colors.red,
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
                    final currentPassword = currentPasswordController.text
                        .trim();
                    final newPassword = newPasswordController.text.trim();
                    final confirmPassword = confirmPasswordController.text
                        .trim();

                    if (currentPassword.isEmpty ||
                        newPassword.isEmpty ||
                        confirmPassword.isEmpty) {
                      setState(
                        () => errorText =
                            'Enter your current password, new password, and confirmation.',
                      );
                      return;
                    }

                    if (newPassword == currentPassword) {
                      setState(
                        () => errorText =
                            'New password cannot be the same as your current password.',
                      );
                      return;
                    }

                    final passwordPattern = RegExp(
                      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*[!@#\$&*~]).{8,}$',
                    );
                    if (!passwordPattern.hasMatch(newPassword)) {
                      setState(
                        () =>
                            errorText = 'Password does not meet requirements.',
                      );
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

                      if (result.toLowerCase().contains('success') ||
                          result.toLowerCase().contains('password updated')) {
                        await showMessageDialog(
                          context,
                          'Password changed successfully.',
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      } else {
                        setState(() => errorText = result);
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      setState(
                        () => errorText = 'Failed to update password: $e',
                      );
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
