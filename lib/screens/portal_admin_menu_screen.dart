import 'package:flutter/material.dart';
import '../constants.dart';
import '../widgets/portal_app_bar.dart';
import '../widgets/message_popup.dart';
import 'portal_admin_screen.dart';

class PortalAdminMenuScreen extends StatelessWidget {
  const PortalAdminMenuScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: PortalAppBar(
      title: const Text('Portal Admin'),
      backgroundColor: Colors.blue[800],
      foregroundColor: Colors.white,
    ),
    body: !Constants.isPortalAdmin
        ? const Center(child: Text('Portal administrator access is required.'))
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.manage_accounts),
                    label: const Text('User Flags'),
                    onPressed: () => showMessagePopup(
                      context,
                      builder: (_) => const PortalAdminScreen(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.history),
                    label: const Text('Activity Audit'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PortalAdminScreen(audit: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
  );
}
