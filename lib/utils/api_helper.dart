import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:ticket_tracker_app/constants.dart';
import 'package:flutter/foundation.dart';


/// APIHelper
///
/// Centralizes all HTTP-based service calls for the application, including:
/// - Authentication (token management, login, password update)
/// - Ticket operations (fetch, create, details)
/// - File handling (upload, download, customer docs)
/// - Activity logging (fetch activity, log button clicks)
/// - Utility APIs (code tables, user info)
///
/// This class provides static methods for interacting with backend APIs and
/// manages authentication tokens and user session information.
class APIHelper {

  /// 1. Authentication & Token Handling

  /// Ensures the access token is valid.
  /// If expired, it will attempt re-authentication using stored credentials.
  ///
  /// Returns `true` if a valid token is available after the check.
  static Future<bool> ensureValidToken() async {
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (Constants.accessToken != null && Constants.tokenExpiration > currentTime) {
      return true;
    }

    // Attempt re-authentication using saved credentials
    final userId = Constants.userID;
    final password = Constants.userPassword;

    if (userId != 0 && password.isNotEmpty) {
      final result = await loginUser(userId.toString(), password);
      return Constants.accessToken != null &&
          Constants.tokenExpiration > DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }

    return false;
  }

  /// Authenticates the user and retrieves an access token.
  ///
  /// Parameters:
  /// - [userId]: The user's ID as a string.
  /// - [password]: The user's password.
  ///
  /// Returns error message string if failed, or fetchUserInfo() result on success.
  static Future<dynamic> loginUser(String userId, String password) async {

    print("Auth URL: " + Constants.baseUrlAuth);
    print("Interface URL: " + Constants.baseUrlData);

    final loginUri = Uri.parse('${Constants.baseUrlAuth}GetAccessToken');

    final response = await http.post(
      loginUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'UserID': int.parse(userId), 'Password': password}),
    );

    final rawBody = response.body;
    dynamic jsonBody;

    try {
      jsonBody = jsonDecode(rawBody);
    } catch (_) {
      jsonBody = null;
    }

    if (response.statusCode == 200 &&
        jsonBody is Map &&
        jsonBody.containsKey('AccessToken')) {
      Constants.accessToken = jsonBody['AccessToken'];
      final adjustedExpiration = ((DateTime.now().millisecondsSinceEpoch ~/ 1000) +
          (jsonBody['AccessExpiresIn'] * 0.95)).toInt();
      Constants.tokenExpiration = adjustedExpiration;
      Constants.userID = int.parse(userId);
      Constants.userPassword = password;

      return await fetchUserInfo();
    }

    if (jsonBody is Map && jsonBody.containsKey('Message')) {
      return jsonBody['Message'].toString();
    }

    // Try to extract the message from the rawBody if possible, otherwise extract nested error message or return fallback.
    try {
      final parsed = jsonDecode(rawBody);
      if (parsed is Map && parsed.containsKey('error') && parsed['error'] is Map) {
        final error = parsed['error'];
        if (error.containsKey('message')) {
          return error['message'].toString();
        }
      }
    } catch (_) {}
    return 'Login failed. Please try again.';
  }

  /// Fetches user information after successful authentication.
  ///
  /// Returns `null` on success, or error message string on failure.
  static Future<String?> fetchUserInfo() async {
    await ensureValidToken();
    final userInfoUri = Uri.parse(
        '${Constants.baseUrlData}GetUserInfo?UserID=${Constants.userID}');
    final response = await http.get(userInfoUri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${Constants.accessToken}',
    });

    if (response.statusCode == 200) {
      final userData = jsonDecode(response.body);
      Constants.contactName = userData['Contact Name']?.toString() ?? '';
      Constants.departmentName = userData['Department Name']?.toString() ?? '';
      Constants.emailAddress = userData['EMail']?.toString() ?? '';
      Constants.qbLinkKey = userData['QB Link Key']?.toString() ?? '';
      return null; // Success
    } else {
      return 'Failed to fetch user info.';
    }
  }

  /// Updates the user's password by submitting current and new passwords.
  ///
  /// Parameters:
  /// - [userId]: The user's ID.
  /// - [currentPassword]: The user's current password.
  /// - [newPassword]: The new password to set.
  ///
  /// Returns API response as a string, or throws on failure.
  static Future<String> updatePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse('${Constants.baseUrlAuth}UpdatePassword');

    final requestBody = jsonEncode({
      'UserID': userId,
      'CurrentPassword': currentPassword,
      'NewPassword': newPassword,
    });

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${Constants.accessToken}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: requestBody,
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData.toString(); // or adjust as needed
    } else {
      throw Exception('Failed to update password: ${response.reasonPhrase}');
    }
  }

  /// 2. Ticket Handling

  /// Fetches tickets from the API based on provided filters.
  ///
  /// Parameters:
  /// - [ticketType]: "Yours" or other.
  /// - [status]: Ticket status filter ("Open", "Deliverable", "Closed").
  /// - [searchBy]: Search field ("Ticket #", "Description", etc.).
  /// - [sortBy]: Sort order.
  /// - [searchValue]: Search string.
  ///
  /// Returns a list of ticket maps.
  static Future<List<Map<String, dynamic>>> fetchTickets({
    required String ticketType,
    required String status,
    required String searchBy,
    required String sortBy,
    required String searchValue,
    required String fromDate,
    required String toDate,
    required String ticketGroupCode,
  }) async {
    await ensureValidToken();

    final searchType = ticketType == 'Yours' ? 'USER' : 'DEPT';
    final userId = searchType == 'USER' ? Constants.userID.toString() : '-1';
    final deptId = Constants.qbLinkKey;

    String statusCode = '';
    switch (status) {
      case 'Open':
        statusCode = 'O';
        break;
      case 'Deliverable':
        statusCode = 'D';
        break;
      case 'Closed':
        statusCode = 'C';
        break;
    }

    String searchByMapped;
    if (searchBy == 'Ticket #') {
      searchByMapped = 'Ticket Key';
    } else if (searchBy == 'Description') {
      searchByMapped = 'Short Desc';
    } else {
      searchByMapped = '';
    }

    final sortByMapped = sortBy;

    // Validate date format and logic
    try {
      final from = DateTime.parse(fromDate);
      final to = DateTime.parse(toDate);
      if (from.isAfter(to)) {
        throw Exception('From Date must not be after To Date');
      }
    } catch (e) {
      throw Exception('Invalid From/To Date: $e');
    }

    final uri = Uri.parse(
      '${Constants.baseUrlData}GetTickets'
          '?SearchType=${Uri.encodeComponent(searchType)}'
          '&UserID=${Uri.encodeComponent(userId)}'
          '&DeptID=${Uri.encodeComponent(deptId)}'
          '&Status=${Uri.encodeComponent(statusCode)}'
          '&SortBy=${Uri.encodeComponent(sortByMapped)}'
          '&SearchBy=${Uri.encodeComponent(searchByMapped.trim())}'
          '&SearchValue=${Uri.encodeComponent(searchValue.trim())}'
          '&DateFrom=${Uri.encodeComponent(fromDate)}'
          '&DateTo=${Uri.encodeComponent(toDate)}'
          '&TicketGroup=${Uri.encodeComponent(ticketGroupCode)}',
    );

    try {
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer ${Constants.accessToken}',
        'Accept': 'application/json',
      });

      final jsonResponse = jsonDecode(response.body);

      if (jsonResponse['Code'] == 300) {
        final data = List<Map<String, dynamic>>.from(jsonResponse['Data']);
        Constants.ticketData = data;
        return data;
      } else {
        throw Exception(jsonResponse['Message']?.toString() ?? 'Unknown error');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches detailed information for a specific ticket.
  ///
  /// Parameters:
  /// - [ticketKey]: The unique key for the ticket.
  ///
  /// Returns ticket details as a map, or null if not found.
  static Future<Map<String, dynamic>?> fetchTicketDetails(String ticketKey) async {
    await ensureValidToken();
    final uri = Uri.parse('${Constants.baseUrlData}GetTicketDetails?TicketKey=$ticketKey');
    print('Calling API for ticket details: $uri');
    print('Using token: ${Constants.accessToken}');

    try {
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer ${Constants.accessToken}',
        'Accept': 'application/json',
      });

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Fetched ticket data: $data');
        return data;
      } else {
        print('Error fetching ticket details: ${response.reasonPhrase}');
        return null;
      }
    } catch (e) {
      print('Exception during fetchTicketDetails: $e');
      return null;
    }
  }

  /// Creates a new ticket with the specified details.
  ///
  /// Parameters:
  /// - [prospectKey]: Prospect key for the ticket.
  /// - [priority]: Ticket priority.
  /// - [shortDesc]: Short description.
  /// - [qbLinkKey]: QuickBooks link key.
  /// - [customerReference]: Customer reference string.
  /// - [longDesc]: Detailed description.
  /// - [confirmationEmail]: Email for confirmation.
  ///
  /// Returns a map containing the API response.
  static Future<Map<String, dynamic>> createTicket({
    required int prospectKey,
    required String priority,
    required String shortDesc,
    required String qbLinkKey,
    required String customerReference,
    required String longDesc,
    required String confirmationEmail,
    required String SharepointLink,
  }) async {
    await ensureValidToken();
    final uri = Uri.parse('${Constants.baseUrlData}CreateTicket');

    final requestBody = jsonEncode({
      'ProspectKey': prospectKey,
      'Priority': priority,
      'ShortDesc': shortDesc,
      'QBLinkKey': qbLinkKey,
      'CustomerReference': customerReference,
      'LongDesc': longDesc,
      'ConfirmationEMailTo': confirmationEmail,
      'SharepointLink': SharepointLink,
    });

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${Constants.accessToken}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: requestBody,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      } else {
        throw Exception('Invalid response format');
      }
    } else {
      throw Exception('Failed to create ticket: ${response.reasonPhrase}');
    }
  }

  /// 3. File Handling

  /// Uploads files to the API for a specific ticket and prospect.
  ///
  /// Parameters:
  /// - [ticketKey]: The ticket key to associate files with.
  /// - [prospectKey]: The prospect key.
  /// - [fileList]: List of files to upload.
  ///
  /// Returns the HTTP response from the API.
  static Future<http.Response> uploadFiles({
    required int ticketKey,
    required int prospectKey,
    required List<File> fileList,
  }) async {
    await ensureValidToken();
    final List<Map<String, dynamic>> fileData = [];

    for (final file in fileList) {
      final fileName = file.path.split('/').last;
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);

      fileData.add({
        'sFileName': fileName,
        'Base64Content': base64String,
      });
    }

    final requestBody = {
      'TicketKey': ticketKey,
      'ProspectKey': prospectKey,
      'FileList': fileData,
    };

    // Debug print before making the request
    print('📤 Uploading to API: ${Uri.parse('${Constants.baseUrlData}UploadFiles')}');
    print('📦 Request payload: ${jsonEncode(requestBody)}');

    final response = await http.post(
      Uri.parse('${Constants.baseUrlData}UploadFiles'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Constants.accessToken}',
      },
      body: jsonEncode(requestBody),
    );

    // Debug print after receiving the response
    print('✅ Upload response status: ${response.statusCode}');
    print('📨 Upload response body: ${response.body}');

    return response;
  }

  /// Uploads files to the API using base64 encoding (Web only).
  ///
  /// Parameters:
  /// - [ticketKey]: Ticket key to associate the files.
  /// - [prospectKey]: Prospect key.
  /// - [fileList]: List of maps with 'name' and 'bytes' keys.
  ///
  /// Each file map should contain:
  /// - 'name': The file name
  /// - 'bytes': The file content as Uint8List
  ///
  /// Returns the HTTP response from the API.
  static Future<http.Response> uploadFilesWeb({
    required int ticketKey,
    required int prospectKey,
    required List<Map<String, dynamic>> fileList,
  }) async {
    await ensureValidToken();

    final List<Map<String, dynamic>> fileData = fileList.map((file) {
      final fileName = file['name'] ?? 'file.bin';
      final base64String = base64Encode(file['bytes'] as List<int>);
      return {
        'sFileName': fileName,
        'Base64Content': base64String,
      };
    }).toList();

    final requestBody = {
      'TicketKey': ticketKey,
      'ProspectKey': prospectKey,
      'FileList': fileData,
    };

    final response = await http.post(
      Uri.parse('${Constants.baseUrlData}UploadFiles'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Constants.accessToken}',
      },
      body: jsonEncode(requestBody),
    );

    return response;
  }


  /// Downloads image files attached to a ticket.
  ///
  /// Parameters:
  /// - [ticketKey]: The ticket key whose images to download.
  ///
  /// Returns a list of maps with 'FileName' and decoded 'Base64Content'.
  static Future<List<Map<String, dynamic>>> getDownloadedImages(String ticketKey) async {
    await ensureValidToken();
    final response = await http.get(
      Uri.parse('${Constants.baseUrlData}DownloadFiles?TicketKey=$ticketKey'),
      headers: {
        'Authorization': 'Bearer ${Constants.accessToken}',
        'accept': 'application/json',
      },
    );

    // Debug print the full API response body
    print('📥 DownloadFiles API response: ${response.body}');

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      // Try common response shapes: FileList, value, Data
      final List files = (jsonData['FileList'] ??
                          jsonData['value'] ??
                          jsonData['Data'] ??
                          []) as List;

      return files.map<Map<String, dynamic>>((file) {
        final base64Str = file['Base64Content'] ?? '';
        Uint8List? decoded;
        try {
          final cleaned = base64Str.replaceAll(RegExp(r'\s+'), '');
          decoded = base64Decode(cleaned);
        } catch (e) {
          print("❌ Error decoding base64 image: $e"); // If decoding fails, return null for content
          decoded = null;
        }
        return {
          'FileName': file['sFileName'] ?? file['FileName'] ?? '',
          'Base64Content': decoded,
        };
      }).toList();
    } else {
      throw Exception('Failed to load images: ${response.statusCode}');
    }
  }

  /// Downloads image files for a ticket and prospect.
  ///
  /// Parameters:
  /// - [ticketKey]: The ticket key.
  ///
  /// Returns a list of maps with 'sFileName' and 'Base64Content' (as string).
  static Future<List<Map<String, String>>> getImagesForTicket(String ticketKey) async {
    await ensureValidToken();
    final url = Uri.parse('${Constants.baseUrlData}/DownloadFiles?TicketKey=$ticketKey&ProspectKey=${Constants.userID}');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer ${Constants.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List files = body['value'] ?? [];

      return files.map<Map<String, String>>((file) {
        return {
          'sFileName': file['sFileName'] ?? '',
          'Base64Content': file['Base64Content'] ?? '',
        };
      }).toList();
    } else {
      debugPrint('Failed to fetch images: ${response.statusCode}');
      return [];
    }
  }

  /// Gets the list of customer document file info (date and name) for a ticket.
  ///
  /// Parameters:
  /// - [ticketKey]: The ticket key for which to fetch document list.
  ///
  /// Returns a list of maps with 'date' and 'fileName' keys.
  ///
  /// Calls: GET {Constants.baseUrlData}GetCustomerDocsList?TicketKey={ticketKey}
  static Future<List<Map<String, String>>> getCustomerDocsList(String ticketKey) async {
    await ensureValidToken();

    final uri = Uri.parse(
      '${Constants.baseUrlData}GetCustomerDocsList',
    ).replace(queryParameters: {
      'TicketKey': ticketKey,
    });

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if ((Constants.accessToken ?? '').isNotEmpty)
        'Authorization': 'Bearer ${Constants.accessToken}',
    };

    final resp = await http
        .get(uri, headers: headers)
        .timeout(Duration(seconds: Constants.timeoutSeconds));

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final raw = resp.body.trim();
    if (raw.isEmpty) return <Map<String, String>>[];

    final decoded = json.decode(raw);

    // Expected shape (from logs):
    // { "Code": 300, "Message": "Success", "Data": [ { "DocumentName": "...", "DateUploaded": "..." }, ... ] }
    if (decoded is Map && decoded['Data'] is List) {
      final List data = decoded['Data'];
      return data.map<Map<String, String>>((e) {
        if (e is Map) {
          final date = (e['DateUploaded'] ?? e['Date'] ?? '').toString();
          final name = (e['DocumentName'] ?? e['sFileName'] ?? e['FileName'] ?? '').toString();
          return {
            'date': date,
            'fileName': name,
          };
        }
        // If an element is a string, treat it as a filename with no date
        if (e is String) {
          return {
            'date': '',
            'fileName': e,
          };
        }
        return {
          'date': '',
          'fileName': e.toString(),
        };
      }).toList();
    }

    // Fallbacks for other shapes
    if (decoded is List) {
      return decoded.map<Map<String, String>>((e) {
        if (e is Map) {
          return {
            'date': (e['DateUploaded'] ?? e['Date'] ?? '').toString(),
            'fileName': (e['DocumentName'] ?? e['sFileName'] ?? e['FileName'] ?? e['name'] ?? '').toString(),
          };
        }
        if (e is String) return {'date': '', 'fileName': e};
        return {'date': '', 'fileName': e.toString()};
      }).toList();
    }
    if (decoded is String) {
      return [ {'date': '', 'fileName': decoded} ];
    }

    return [ {'date': '', 'fileName': raw} ];
  }

  /// 4. Activity & Logging

  /// Fetches activity messages for a given ticket.
  ///
  /// Parameters:
  /// - [ticketNumber]: The ticket number or key.
  ///
  /// Returns a list of activity message maps.
  static Future<List<Map<String, dynamic>>> getActivityMessages(String ticketNumber) async {
    await ensureValidToken();
    final url = Uri.parse('${Constants.baseUrlData}GetWebActivities?TicketKey=$ticketNumber');
    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer ${Constants.accessToken}',
    };

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);
        if (jsonBody['Code'] == 300 && jsonBody['Data'] != null) {
          final List data = jsonBody['Data'];
          return data.cast<Map<String, dynamic>>();
        } else {
          throw Exception('API error: ${jsonBody['Message']}');
        }
      } else {
        throw Exception('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching activity messages: $e');
    }
  }

  /// Logs a button click to a Windows text file.
  ///
  /// File path pattern: C:\\labsave\\prospect\\Prospect_<QBLinkKey>_<YYYY-MM-DD>.txt
  /// Safe no-op on non-Windows platforms.
  ///
  /// Parameters:
  /// - [buttonName]: The name of the button clicked.
  static Future<void> logButtonClickWindows(String buttonName) async {
    if (!Platform.isWindows) return; // Only for Windows build

    try {
      final qb = (Constants.qbLinkKey.isNotEmpty ? Constants.qbLinkKey : 'UNKNOWN');
      final safeQb = qb.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      final dateStr = '$y-$m-$d';

      const dirPath = r'C:\\labsave\\prospect';
      final filePath = '$dirPath\\Prospect_${safeQb}_$dateStr.txt';

      // Ensure directory exists
      await Directory(dirPath).create(recursive: true);

      final iso = now.toIso8601String();
      final line = '[$iso] $buttonName clicked (QBLinkKey=$qb)\r\n';
      await File(filePath).writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // Swallow errors: logging must never break UI
    }
  }

  /// 5. Utilities

  /// Retrieves a list of codes and their descriptions for a given code table.
  ///
  /// Parameters:
  /// - [codeTable]: The code table name to fetch.
  ///
  /// Returns a list of maps with 'Code' and 'Description' keys.
  static Future<List<Map<String, String>>> getCodeList(String codeTable) async {
    await ensureValidToken();
    final url = Uri.parse('${Constants.baseUrlData}GetCodeList?CodeTable=$codeTable');

    final response = await http.get(url, headers: {
      'Authorization': 'Bearer ${Constants.accessToken}',
      'Accept': 'application/json',
    });

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((e) {
        return {
          'Code': e['Code'].toString(),
          'Description': e['Description'].toString(),
        };
      }).toList();
    } else {
      throw Exception('Failed to load $codeTable list');
    }
  }

  static Future<List<Map<String, String>>> getTicketGroupList({
    required String prospectKey,
    required String qbLinkKey,
    required bool useActiveOnly,
  }) async {
    await ensureValidToken();

    final useActive = useActiveOnly ? 'Y' : 'N';
    final url = Uri.parse(
      '${Constants.baseUrlData}GetTicketGroup'
          '?ProspectKey=$prospectKey'
          '&QBLinkKey=$qbLinkKey'
          '&UseActiveOnly=$useActive',
    );

    final response = await http.get(url, headers: {
      'Authorization': 'Bearer ${Constants.accessToken}',
      'Accept': 'application/json',
    });

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((e) {
        return {
          'Code': e['Code'].toString(),
          'Description': e['Description']?.toString() ?? '',
        };
      }).toList();
    } else {
      throw Exception('Failed to load ticket groups: ${response.statusCode}');
    }
  }

  static Future<http.Response> exportTicketsCSV({
    required String ticketType,
    required String status,
    required String searchBy,
    required String sortBy,
    required String searchValue,
    required String fromDate,
    required String toDate,
    required String ticketGroupCode,
  }) async {
    await ensureValidToken();

    final searchType = ticketType == 'Yours' ? 'USER' : 'DEPT';
    final userId = searchType == 'USER' ? Constants.userID.toString() : '-1';
    final deptId = Constants.qbLinkKey;

    String statusCode = '';
    switch (status) {
      case 'Open':
        statusCode = 'O';
        break;
      case 'Deliverable':
        statusCode = 'D';
        break;
      case 'Closed':
        statusCode = 'C';
        break;
    }

    String searchByMapped;
    if (searchBy == 'Ticket #') {
      searchByMapped = 'Ticket Key';
    } else if (searchBy == 'Description') {
      searchByMapped = 'Short Desc';
    } else {
      searchByMapped = '';
    }

    final sortByMapped = sortBy;

    final uri = Uri.parse(
      '${Constants.baseUrlData}ExportTicketsCSV'
          '?SearchType=${Uri.encodeComponent(searchType)}'
          '&UserID=${Uri.encodeComponent(userId)}'
          '&DeptID=${Uri.encodeComponent(deptId)}'
          '&Status=${Uri.encodeComponent(statusCode)}'
          '&SortBy=${Uri.encodeComponent(sortByMapped)}'
          '&SearchBy=${Uri.encodeComponent(searchByMapped.trim())}'
          '&SearchValue=${Uri.encodeComponent(searchValue.trim())}'
          '&DateFrom=${Uri.encodeComponent(fromDate)}'
          '&DateTo=${Uri.encodeComponent(toDate)}'
          '&TicketGroup=${Uri.encodeComponent(ticketGroupCode)}',
    );

    return await http.get(uri, headers: {
      'Authorization': 'Bearer ${Constants.accessToken}',
      'Accept': 'application/json',
    });
  }

  static Future<Map<String, dynamic>> updateTicket(
      int ticketKey,
      String customerReference,
      String sharepointLink,
      String sendConfirmationTo, // 🔹 positional
      ) async {
    final url = Uri.parse('${Constants.baseUrlData}UpdateTicket');

    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer ${Constants.accessToken}',
      'Content-Type': 'application/json',
    };

    final payload = {
      'TicketKey': ticketKey,
      'CustomerReference': customerReference,
      'SharepointLink': sharepointLink,
      'ConfirmationEmailTo': sendConfirmationTo,
    };

    final body = jsonEncode(payload);

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update ticket: ${response.statusCode} → ${response.body}');
    }
  }
}
