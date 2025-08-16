/// A utility class that holds constant values used throughout the application,including API URLs, authentication credentials, and global session-related data.

import 'dart:convert';
import 'package:xml/xml.dart' as xml;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class Constants {
  /// Base URL for the authentication service endpoint (LoginAuth0001Service).
  static String baseUrlAuth = 'https://support.porterlee.com/plc/intf/prospect/Auth0001/DEV/LoginAuth0001Service/';

  /// Base URL for all other data-related API endpoints (e.g., ticket management).
  static String baseUrlData = 'https://support.porterlee.com/plc/intf/prospect/intf4010/DEV/BEASTProspectIntf4010APIService/';

  /// Default network request timeout in seconds.
  static const int timeoutSeconds = 20;

  /// JWT access token used for API authorization.
  static String? accessToken;

  /// Expiration timestamp of the JWT access token in seconds (Unix time).
  static int tokenExpiration = 0;

  /// The user ID of the currently logged-in user.
  static int userID = 0;

  /// The password of the currently logged-in user.
  static String userPassword = '';

  /// The department name associated with the user.
  /// This is retrieved from the API during login and may be used for
  /// display in the UI or for filtering tickets and other data
  /// based on the user's department context.
  static String departmentName = '';

  /// The contact name associated with the user, retrieved during login.
  static String contactName = '';

  /// The department or group identifier used in ticket filtering and submission.
  static String qbLinkKey = '';

  /// The email address of the currently logged-in user.
  static String emailAddress = '';

  /// A shared JSON string that holds ticket data returned from the GetTickets API.
  static List<dynamic> ticketData = [];

  /// Stores the details of the selected ticket when viewing or editing.
  static Map<String, dynamic>? selectedTicketDetails;

  /// Load configuration for web from web.config (IIS) if available.
  /// If web.config is not readable by the browser (common on IIS), try /config.json.
  /// On failure, keep the existing defaults.
  static Future<void> loadConfig() async {
    if (!kIsWeb) {
      // Non-web: use defaults already assigned above.
      return;
    }
    // --- Try web.config (XML) ---
    try {
      final resp = await http.get(Uri.parse('web.config'), headers: {'Accept': 'application/xml'});
      final body = resp.body;
      final isHtml = body.trimLeft().toLowerCase().startsWith('<!doctype html') ||
          body.toLowerCase().contains('<html') ||
          resp.headers['content-type']?.toLowerCase().contains('text/html') == true;
      if (resp.statusCode == 200 && !isHtml && body.isNotEmpty) {
        final doc = xml.XmlDocument.parse(body);
        final settings = doc.findAllElements('add');
        for (var setting in settings) {
          final key = setting.getAttribute('key');
          final value = setting.getAttribute('value');
          if (key == 'baseUrlAuth' && value != null && value.isNotEmpty) {
            baseUrlAuth = value;
          } else if (key == 'baseUrlData' && value != null && value.isNotEmpty) {
            baseUrlData = value;
          }
        }
        return; // success
      }
    } catch (_) {
      // ignore, try JSON below
    }
    // --- Fallback: try /config.json (JSON) ---
    try {
      final respJson = await http.get(Uri.parse('config.json'), headers: {'Accept': 'application/json'});
      if (respJson.statusCode == 200 && respJson.body.isNotEmpty) {
        final map = json.decode(respJson.body);
        final auth = map['baseUrlAuth']?.toString();
        final data = map['baseUrlData']?.toString();
        if (auth != null && auth.isNotEmpty) baseUrlAuth = auth;
        if (data != null && data.isNotEmpty) baseUrlData = data;
        return; // success
      }
    } catch (_) {
      // ignore, leave defaults
    }
    // If both attempts fail, keep defaults already set.
  }
}