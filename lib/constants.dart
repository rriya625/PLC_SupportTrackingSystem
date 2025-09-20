import 'dart:convert';
import 'package:xml/xml.dart' as xml;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

/// A utility class that holds constant values used throughout the application,
/// including API URLs, authentication credentials, and global session-related data.
class Constants {
  // --- API URLs ---
  static String baseUrlAuth = 'https://support.porterlee.com/plc/intf/prospect/Auth0001/DEV/LoginAuth0001Service/';
  static String baseUrlData = 'https://support.porterlee.com/plc/intf/prospect/intf4010/DEV/BEASTProspectIntf4010APIService/';

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

  /// Loads configuration from config.json for web builds.
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

        final auth = map['AUTH_BASE_URL']?.toString();
        final data = map['INTERFACE_BASE_URL']?.toString();
        final logUrl = map['LOG_UPLOAD_URL']?.toString();
        final env = map['HOST_ENV']?.toString();

        if (auth != null && auth.isNotEmpty) {
          final cleanedAuth = auth.endsWith('/') ? auth : '$auth/';
          baseUrlAuth = '${cleanedAuth}LoginAuth0001Service/';
          print('[Constants] baseUrlAuth set from config.json: $baseUrlAuth');
        }

        if (data != null && data.isNotEmpty) {
          final cleanedData = data.endsWith('/') ? data : '$data/';
          baseUrlData = '${cleanedData}BEASTProspectIntf4010APIService/';
          print('[Constants] baseUrlData set from config.json: $baseUrlData');
        }

        if (logUrl != null && logUrl.isNotEmpty) {
          logUploadUrl = logUrl;
          print('[Constants] logUploadUrl set from config.json: $logUploadUrl');
        }

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

    // Fallback to default if config.json fails
    print('[Constants] Using default API base URLs');
  }
}