import 'dart:convert';
import 'package:xml/xml.dart' as xml;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

/// A utility class that holds constant values used throughout the application,
/// including API URLs, authentication credentials, and global session-related data.
class Constants {
  // --- API URLs assigned at build time using --dart-define ---
  static final String baseUrlAuth = const String.fromEnvironment(
    'BASE_URL_AUTH',
    defaultValue: 'https://support.porterlee.com/plc/intf/prospect/Auth0001/DEV/LoginAuth0001Service/',
  );

  static final String baseUrlData = const String.fromEnvironment(
    'BASE_URL_DATA',
    defaultValue: 'https://support.porterlee.com/plc/intf/prospect/intf4010/DEV/BEASTProspectIntf4010APIService/',
  );

  // --- Optional external config values ---
  static String? logUploadUrl; // from config.json["LOG_UPLOAD_URL"]
  static String? hostEnv;      // from config.json["HOST_ENV"]

  // --- Session & User Info ---
  static const int timeoutSeconds = 20;
  static String? accessToken;
  static int tokenExpiration = 0;
  static int userID = 0;
  static String userPassword = '';
  static String departmentName = '';
  static String contactName = '';
  static String qbLinkKey = '';
  static String emailAddress = '';
  static List<dynamic> ticketData = [];
  static Map<String, dynamic>? selectedTicketDetails;

  /// Loads optional configuration values from config.json (web only).
  static Future<void> loadConfig() async {
    if (!kIsWeb) {
      print('[Constants] Not web — skipping config load');
      return;
    }

    try {
      print('[Constants] Trying to load config.json...');
      final respJson = await http.get(
        Uri.parse('config.json?v=${DateTime.now().millisecondsSinceEpoch}'),
      );

      print('--- HTTP Response CONFIG.JSON ---');
      print('URL: ${respJson.request?.url}');
      print('Status: ${respJson.statusCode}');
      print('Headers: ${respJson.headers}');
      print('Body:\n${respJson.body}');
      print('----------------------');

      if (respJson.statusCode == 200 && respJson.body.isNotEmpty) {
        final map = json.decode(respJson.body);

        // Log values, but don't overwrite dart-define values
        final auth = map['AUTH_BASE_URL']?.toString();
        final data = map['INTERFACE_BASE_URL']?.toString();

        if (auth != null && auth.isNotEmpty) {
          print('[Constants] AUTH_BASE_URL from config.json: $auth');
        }
        if (data != null && data.isNotEmpty) {
          print('[Constants] INTERFACE_BASE_URL from config.json: $data');
        }

        final logUrl = map['LOG_UPLOAD_URL']?.toString();
        if (logUrl != null && logUrl.isNotEmpty) {
          logUploadUrl = logUrl;
          print('[Constants] logUploadUrl set from config.json: $logUploadUrl');
        }

        final env = map['HOST_ENV']?.toString();
        if (env != null && env.isNotEmpty) {
          hostEnv = env;
          print('[Constants] hostEnv set from config.json: $hostEnv');
        }

        return;
      } else {
        print('[Constants] config.json not found or empty');
      }
    } catch (e) {
      print('[Constants] Error loading config.json: $e');
    }

    // Fallback
    print('[Constants] Using default API base URLs');
  }
}