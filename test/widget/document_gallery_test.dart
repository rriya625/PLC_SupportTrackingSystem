import 'dart:convert';
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
      expect(find.text('Activity #7'), findsOneWidget);
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
              {'Source': 'CUSTOMER', 'FileName': 'retry.txt'},
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
    expect(find.text('Unable to load this document.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Unable to load this document.'), findsNothing);
    expect(attempts, 2);
  });
}
