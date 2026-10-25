import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ticket_tracker_app/constants.dart';
import 'package:ticket_tracker_app/utils/diagnostic_http_client.dart';
import 'package:ticket_tracker_app/utils/diagnostic_formatter.dart';

void main() {
  setUp(() {
    Constants.baseUrlData = 'https://example.test/service/';
    Constants.userID = 12819;
    Constants.debugMode = 'T';
  });
  test('runnable SQL is plain text and secrets are removed', () {
    final text = DiagnosticFormatter.format(
      environment: 'dev',
      endpoint: 'GetTickets',
      method: 'GET',
      httpStatus: 200,
      elapsedMs: 5,
      inputs: {'Password': 'secret-value', 'TicketKey': 117234},
      diagnostics: {
        'Queries': [
          {
            'Operation': 'SELECT',
            'RunnableSQL':
                'SELECT "Ticket Key" FROM TICKET WHERE "Ticket Key" = 117234;',
            'Parameters': {'TicketKey': '117234'},
          },
        ],
      },
      response: {
        'Data': [],
        'Base64Content': 'file-secret',
        'AccessToken': 'jwt-secret',
      },
    );
    expect(text, contains('SELECT "Ticket Key"'));
    expect(text, isNot(contains(r'\"Ticket Key\"')));
    expect(text, isNot(contains('secret-value')));
    expect(text, isNot(contains('file-secret')));
    expect(text, isNot(contains('jwt-secret')));
  });
  test('GetUserInfo bootstraps T and logs once', () async {
    Constants.debugMode = 'N';
    final logs = <String>[];
    final client = DiagnosticHttpClient(
      MockClient(
        (r) async => http.Response(
          jsonEncode({'DEBUG_MODE': 'T', 'UserID': 12819}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      writer: (s) async {
        logs.add(s);
      },
    );
    final response = await client.get(
      Uri.parse(Constants.baseUrlData + 'GetUserInfo'),
    );
    expect(response.statusCode, 200);
    expect(Constants.debugMode, 'T');
    expect(logs.length, 1);
    expect(logs.single, contains('"DEBUG_MODE": "T"'));
  });
  test('arrays unchanged and diagnostic lookup does not recurse', () async {
    final logs = <String>[];
    var lookups = 0;
    final client = DiagnosticHttpClient(
      MockClient((r) async {
        if (r.url.path.endsWith('GetRequestDiagnostics')) {
          lookups++;
          expect(r.headers['Authorization'], 'Bearer fixture');
          return http.Response('{"RecordCount":1,"Queries":[]}', 200);
        }
        return http.Response(
          '[{"Code":"A"}]',
          200,
          headers: {
            'content-type': 'application/json',
            'x-prospect-debug-id': 'request-1',
          },
        );
      }),
      writer: (s) async {
        logs.add(s);
      },
    );
    final response = await client.get(
      Uri.parse(Constants.baseUrlData + 'GetCodeList'),
      headers: {'Authorization': 'Bearer fixture'},
    );
    expect(jsonDecode(response.body), isA<List>());
    expect(lookups, 1);
    expect(logs.length, 1);
    expect(logs.single, contains('RecordCount: 1'));
    expect(logs.single, isNot(contains('Bearer fixture')));
  });
  test('logger failure preserves successful response', () async {
    final client = DiagnosticHttpClient(
      MockClient(
        (r) async => http.Response(
          '{"Code":300}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      writer: (s) async {
        throw Exception('log offline');
      },
    );
    expect(
      (await client.get(Uri.parse(Constants.baseUrlData + 'GetTickets')))
          .statusCode,
      200,
    );
  });
  test('debug off does not fetch or log diagnostics', () async {
    Constants.debugMode = 'N';
    var calls = 0;
    var logs = 0;
    final client = DiagnosticHttpClient(
      MockClient((r) async {
        calls++;
        return http.Response('[]', 200, headers: {'x-prospect-debug-id': 'id'});
      }),
      writer: (s) async {
        logs++;
      },
    );
    await client.get(Uri.parse(Constants.baseUrlData + 'GetCodeList'));
    expect(calls, 1);
    expect(logs, 0);
  });
  test('authentication payloads never logged', () async {
    var logs = 0;
    final client = DiagnosticHttpClient(
      MockClient((r) async => http.Response('{"AccessToken":"secret"}', 200)),
      writer: (s) async {
        logs++;
      },
    );
    await client.post(
      Uri.parse('https://example.test/auth/GetAccessToken'),
      body: '{"Password":"secret"}',
    );
    expect(logs, 0);
  });
  test('HTTP failure logged with status unchanged', () async {
    final logs = <String>[];
    final client = DiagnosticHttpClient(
      MockClient(
        (r) async => http.Response(
          '{"Message":"Not permitted"}',
          403,
          headers: {'content-type': 'application/json'},
        ),
      ),
      writer: (s) async {
        logs.add(s);
      },
    );
    final response = await client.get(
      Uri.parse(Constants.baseUrlData + 'GetTicketDetails'),
    );
    expect(response.statusCode, 403);
    expect(logs.single, contains('Not permitted'));
  });
  test('file bytes preserved and not logged', () async {
    final logs = <String>[];
    final client = DiagnosticHttpClient(
      MockClient(
        (r) async => http.Response.bytes(
          [0, 1, 255, 2],
          200,
          headers: {'content-type': 'application/octet-stream'},
        ),
      ),
      writer: (s) async {
        logs.add(s);
      },
    );
    final response = await client.get(
      Uri.parse(Constants.baseUrlData + 'ExportTicketsCSV'),
    );
    expect(response.bodyBytes, [0, 1, 255, 2]);
    expect(logs.single, contains('"byteCount": 4'));
  });
}
