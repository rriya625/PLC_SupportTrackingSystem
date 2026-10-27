import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/widgets/portal_scroll_behavior.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      'Persistent scrollbars have separate controllers on $platform',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            scrollBehavior: const PortalScrollBehavior(),
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    height: 150,
                    child: ListView(
                      primary: false,
                      children: List.generate(30, (i) => Text('Vertical $i')),
                    ),
                  ),
                  SizedBox(
                    height: 70,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: List.generate(
                        20,
                        (i) =>
                            SizedBox(width: 100, child: Text('Horizontal $i')),
                      ),
                    ),
                  ),
                  Builder(
                    builder: (c) => TextButton(
                      onPressed: () => showDialog<void>(
                        context: c,
                        builder: (_) => AlertDialog(
                          content: SizedBox(
                            width: 300,
                            height: 200,
                            child: ListView(
                              children: List.generate(
                                50,
                                (i) => Text('File $i'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Documents'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final bars = tester
            .widgetList<Scrollbar>(find.byType(Scrollbar))
            .toList();
        expect(bars.length, 2);
        for (final bar in bars) {
          expect(bar.thumbVisibility, true);
          expect(bar.trackVisibility, true);
          expect(bar.thickness, 10);
          expect(bar.controller, isNotNull);
        }
        expect(identical(bars.first.controller, bars.last.controller), false);
        await tester.tap(find.text('Documents'));
        await tester.pumpAndSettle();
        expect(find.byType(Scrollbar), findsNWidgets(3));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
