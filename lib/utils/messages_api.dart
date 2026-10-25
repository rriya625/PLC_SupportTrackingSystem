import 'dart:convert';
import 'package:ticket_tracker_app/constants.dart';
import 'diagnostic_http_client.dart';

class MessagesApi {
  Future<Map<String, dynamic>> call(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse(
      '${Constants.baseUrlData}$endpoint',
    ).replace(queryParameters: query);
    final headers = {
      'Authorization': 'Bearer ${Constants.accessToken}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final response = body == null
        ? await diagnosticHttpClient.get(uri, headers: headers)
        : await diagnosticHttpClient.post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        data is! Map ||
        data['Code'].toString() != '300') {
      throw Exception(
        data is Map
            ? (data['Message'] ?? data['message'] ?? 'Message request failed')
            : 'Message request failed',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  Future<List<String>> groups() async {
    final response = await diagnosticHttpClient.get(
      Uri.parse(
        '${Constants.baseUrlData}GetMessageToList',
      ).replace(queryParameters: {'QBLinkKey': Constants.qbLinkKey}),
      headers: {'Authorization': 'Bearer ${Constants.accessToken}'},
    );
    if (response.statusCode != 200)
      throw Exception('Unable to load support groups');
    return (jsonDecode(response.body) as List)
        .map((e) => e['Option'].toString())
        .where((s) => s != '-- No Selection --' && s != 'O')
        .toList();
  }
}
