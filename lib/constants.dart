import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show TargetPlatform;

class Constants {
  // --- Fallback values from build-time dart-define ---
  static final String _baseUrlAuthDefine = const String.fromEnvironment(
    'BASE_URL_AUTH',
    defaultValue:
    'https://support.porterlee.com/plc/intf/prospect/Auth0001/DEV/LoginAuth0001Service/',
  );

  static final String _baseUrlDataDefine = const String.fromEnvironment(
    'BASE_URL_DATA',
    defaultValue:
    'https://support.porterlee.com/plc/intf/prospect/intf4010/DEV/BEASTProspectIntf4010APIService/',
  );

  static bool get isMobileWeb =>
      kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android);

  static final String _buildEnvDefine = const String.fromEnvironment(
    'BUILD_ENV',
    defaultValue: 'dev',
  );

  // --- Effective values (can be overridden by config.json) ---
  static String baseUrlAuth = _baseUrlAuthDefine;
  static String baseUrlData = _baseUrlDataDefine;
  static String buildEnv = _buildEnvDefine;

  static String? logUploadUrl;
  static String? hostEnv;
  static String? manualDownloadUrl;

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

  static bool get isDev => buildEnv.toLowerCase() == 'dev';
  static bool get isProd => buildEnv.toLowerCase() == 'prod';

  /// Normalize a base URL so it always ends with `/`
  static String _normalizeUrl(String url) {
    if (!url.endsWith('/')) return '$url/';
    return url;
  }

  /// Loads configuration values from config.json (web only).
  static Future<void> loadConfig() async {
    if (!kIsWeb) {
      print('[Constants] Not web — skipping config.json load');
      return;
    }

    try {
      print('[Constants] Trying to load config.json...');
      final respJson = await http.get(
        Uri.parse('config.json?v=${DateTime.now().millisecondsSinceEpoch}'),
      );

      if (respJson.statusCode == 200 && respJson.body.isNotEmpty) {
        final map = json.decode(respJson.body);

        // Normalize and override if present
        if (map['AUTH_BASE_URL'] != null &&
            map['AUTH_BASE_URL'].toString().isNotEmpty) {
          baseUrlAuth = _normalizeUrl(map['AUTH_BASE_URL'].toString());
          print('[Constants] baseUrlAuth set from config.json: $baseUrlAuth');
        }

        if (map['INTERFACE_BASE_URL'] != null &&
            map['INTERFACE_BASE_URL'].toString().isNotEmpty) {
          baseUrlData = _normalizeUrl(map['INTERFACE_BASE_URL'].toString());
          print('[Constants] baseUrlData set from config.json: $baseUrlData');
        }

        if (map['APP_ENV'] != null && map['APP_ENV'].toString().isNotEmpty) {
          buildEnv = map['APP_ENV'].toString();
          print('[Constants] buildEnv set from config.json: $buildEnv');
        }

        logUploadUrl = map['LOG_UPLOAD_URL']?.toString();
        hostEnv = map['HOST_ENV']?.toString();
        manualDownloadUrl = map['MANUAL_DOWNLOAD_URL']?.toString();

        print('logUploadUrl: $logUploadUrl');
        print('hostEnv: $hostEnv');
        print('manualDownloadUrl: $manualDownloadUrl');

      } else {
        print('[Constants] config.json not found or empty, using dart-define defaults');
      }
    } catch (e) {
      print('[Constants] Error loading config.json: $e — using dart-define defaults');
    }
  }
}