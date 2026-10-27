import 'portal_loading.dart';
import '../utils/api_helper.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../screens/login_screen.dart';
import '../utils/web_log_helper.dart';

bool _loggingOut = false;
Future<void> logoutFromPortal(BuildContext context) async {
  if (_loggingOut) return;
  _loggingOut = true;
  try {
    await withPortalLoading(
      context,
      'Logging out...',
      () => APIHelper.recordSessionEvent('LOGOUT'),
    );
  } catch (_) {
    // Sign-out must still clear the local session if the server is unavailable.
  }
  _loggingOut = false;
  if (!context.mounted) return;
  Constants.accessToken = null;
  Constants.tokenExpiration = 0;
  Constants.userID = 0;
  Constants.userPassword = '';
  Constants.departmentName = '';
  Constants.userType = '';
  Constants.accessLevel = '';
  Constants.debugMode = 'N';
  Constants.doNotLoadTicketsOnLoad = 'F';
  Constants.webViewAllDeptTickets = 'F';
  Constants.allowDocumentDelete = 'F';
  Constants.contactName = '';
  Constants.qbLinkKey = '';
  Constants.emailAddress = '';
  Constants.ticketData = [];
  Constants.selectedTicketDetails = null;
  WebLogHelper.clear();
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => LoginScreen()),
    (_) => false,
  );
}

/// Full pages show Logout last; dialogs keep their own close actions.
class PortalAppBar extends AppBar {
  PortalAppBar({
    super.key,
    super.title,
    super.leading,
    super.automaticallyImplyLeading,
    super.centerTitle,
    super.backgroundColor,
    super.foregroundColor,
    super.iconTheme,
    List<Widget>? actions,
  }) : super(
         actions: [
           ...?actions,
           Builder(
             builder: (context) => ModalRoute.of(context) is PopupRoute
                 ? const SizedBox.shrink()
                 : IconButton(
                     tooltip: 'Logout',
                     icon: const Icon(Icons.logout),
                     onPressed: () => logoutFromPortal(context),
                   ),
           ),
         ],
       );
}
