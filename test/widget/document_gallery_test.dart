import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/screens/document_gallery.dart';

void main() {
  testWidgets(
    'Gallery previews images and downloads other files without decoding changes',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
      final loads = <String>[];
      final saved = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentGallery(
              documents: const [
                {
                  'Source': 'ACTIVITY',
                  'HistoryNumber': 7,
                  'FileName': 'photo.png',
                },
                {'Source': 'CUSTOMER', 'FileName': 'notes.txt'},
              ],
              loadDocument: (document) async {
                loads.add(document['FileName'] as String);
                final encoded = document['FileName'] == 'photo.png'
                    ? png
                    : base64Encode(utf8.encode('test document'));
                return {
                  'Base64Content':
                      '${encoded.substring(0, 12)}\r\n${encoded.substring(12)}',
                };
              },
              saveDocument: (bytes, name) async {
                saved.add(name);
                expect(utf8.decode(bytes), 'test document');
                return 'Downloaded';
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Activity #7'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Preview not supported'), findsOneWidget);
      expect(find.text('Download'), findsNWidgets(2));
      await tester.tap(find.text('Download').last);
      await tester.pumpAndSettle();
      expect(saved, ['notes.txt']);
      expect(loads, ['photo.png', 'notes.txt']);
    },
  );

  testWidgets('A failed file offers retry without hiding the other documents', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentGallery(
            documents: const [
              {'Source': 'CUSTOMER', 'FileName': 'retry.png'},
            ],
            loadDocument: (_) async {
              if (++attempts == 1) throw Exception('Temporary error');
              return {
                'Base64Content': base64Encode([1, 2, 3]),
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to download this document. Please retry.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsOneWidget);
    expect(
      find.text('Unable to download this document. Please retry.'),
      findsNothing,
    );
    expect(attempts, 2);
  });

  testWidgets(
    'Unsupported files show placeholder before fetching and blue spinner while downloading',
    (tester) async {
      final response = Completer<Map<String, dynamic>>();
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentGallery(
              documents: const [
                {'FileName': 'A Word file.docx'},
              ],
              loadDocument: (_) {
                loads++;
                return response.future;
              },
              saveDocument: (_, _) async =>
                  'Download started. Check your browser Downloads.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, 0);
      expect(find.text('Preview not supported'), findsOneWidget);
      await tester.tap(find.text('Download'));
      await tester.pump();
      expect(loads, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color,
        const Color(0xFF1565C0),
      );
      response.complete({'Base64Content': 'YWJj'});
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('List download button stays busy and does not submit twice', (
    tester,
  ) async {
    final finished = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentDownloadButton(
            onDownload: () {
              calls++;
              return finished.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    expect(calls, 1);
    finished.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
