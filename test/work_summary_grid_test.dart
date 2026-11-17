import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_tracker_app/widgets/work_summary_grid.dart';

void main() {
  final rows = <Map<String, dynamic>>[
    {'Type':'CORR','Description':'Correspondence','Employee':'MURU','Count':15,'Minutes':0},
    {'Type':'CORR','Description':'Correspondence','Employee':'SARAH','Count':1,'Minutes':10},
    {'Type':'AINV','Description':'Approved','Employee':'MURU','Count':1,'Minutes':90},
  ];
  for (final employee in [true, false]) {
    testWidgets('Count navigation works for employee=$employee without admin checks', (tester) async {
      List<String>? selection;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkSummaryGrid(
        rows: rows, employee: employee,
        onCount: (scope, type, author) => selection = [scope, type, author]))));
      await tester.tap(find.widgetWithText(TextButton, '1 / 10m'));
      expect(selection, ['CELL', 'CORR', 'SARAH']);
      await tester.tap(find.widgetWithText(TextButton, '17'));
      expect(selection, ['ALL', '', '']);
      expect(find.widgetWithText(TextButton, '—'), findsNothing);
    });
  }
  testWidgets('Legacy codes retain exact drilldown identity', (tester) async {
    List<String>? selected;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkSummaryGrid(
      employee: true,
      rows: [{'Type':'','TypeFilter':'@HEX@00','Employee':'O','Count':1,'Minutes':0}],
      onCount: (scope, type, employee) => selected = [scope,type,employee]))));
    expect(find.text('Unspecified'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton,'1').first);
    expect(selected,['CELL','@HEX@00','O']);
  });
  testWidgets('Employee totals retain fractional hours', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkSummaryGrid(rows: rows,employee:true))));
    expect(find.text('MURU'), findsOneWidget);
    expect(find.text('1 / 10m'), findsOneWidget);
    expect(find.text('1 / 1.50h'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('1.67'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Customer totals and narrow view', (tester) async {
    tester.view.physicalSize = const Size(390,844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkSummaryGrid(rows: rows,employee:false))));
    expect(find.text('MURU'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('1.67'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
