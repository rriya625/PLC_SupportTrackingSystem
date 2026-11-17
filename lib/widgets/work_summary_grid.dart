import 'package:flutter/material.dart';

/// Prospect's Activity By Type cross-tab, retaining fractional-hour totals.
class WorkSummaryGrid extends StatefulWidget {
  const WorkSummaryGrid({
    super.key,
    required this.rows,
    required this.employee,
    this.onCount,
  });
  final List<Map<String, dynamic>> rows;
  final bool employee;
  final void Function(String scope, String type, String employee)? onCount;
  @override
  State<WorkSummaryGrid> createState() => _WorkSummaryGridState();
}

class _WorkSummaryGridState extends State<WorkSummaryGrid> {
  final horizontal = ScrollController();
  final vertical = ScrollController();
  @override
  void dispose() {
    horizontal.dispose();
    vertical.dispose();
    super.dispose();
  }

  num sum(Iterable<Map<String, dynamic>> rows, String key) =>
      rows.fold<num>(0, (total, row) => total + (row[key] as num? ?? 0));
  String hours(num minutes) => (minutes / 60).toStringAsFixed(2);
  String cell(Iterable<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '—';
    final count = sum(rows, 'Count');
    final minutes = sum(rows, 'Minutes');
    if (minutes == 0) return '$count';
    return '$count / ${minutes < 60 ? '${minutes.toStringAsFixed(0)}m' : '${hours(minutes)}h'}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    String typeKey(Map<String, dynamic> r) => '${r['TypeFilter'] ?? r['Type']}';
    final types = rows.map(typeKey).toSet().toList()..sort();
    final employees = rows.map((r) => '${r['Employee'] ?? ''}').toSet().toList()..sort();
    Iterable<Map<String, dynamic>> byType(String type) =>
        rows.where((r) => typeKey(r) == type);
    String employeeLabel(String code) {
      final name = rows.where((r) => '${r['Employee'] ?? ''}' == code)
          .map((r) => '${r['EmployeeName'] ?? ''}'.trim())
          .where((name) => name.isNotEmpty).firstOrNull;
      return name ?? (code.isEmpty ? 'Unspecified' : code);
    }
    String activityLabel(String type) {
      final description = '${byType(type).first['Description'] ?? ''}'.trim();
      final code = '${byType(type).first['Type'] ?? ''}'.trim();
      return description.isEmpty ? (code.isEmpty ? 'Unspecified' : code) : '$code - $description';
    }
    final totalStyle = const TextStyle(fontWeight: FontWeight.bold);
    DataCell countCell(String text, num count, String scope, String type, String employee) {
      final action = widget.onCount;
      return DataCell(action == null || count <= 0
          ? Text(text, style: scope == 'CELL' ? null : totalStyle)
          : TextButton(
              onPressed: () => action(scope, type, employee),
              child: Text(text),
            ));
    }
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Cells show activity count / recorded time. m = minutes, h = hours. Totals retain fractional hours.',
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: vertical,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: vertical,
              child: Scrollbar(
                controller: horizontal,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: horizontal,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 18),
                  child: DataTable(
                    headingRowHeight: 220,
                    headingRowColor: WidgetStatePropertyAll(
                      Colors.blue.shade100,
                    ),
                    border: TableBorder.all(color: Colors.blueGrey.shade100),
                    columnSpacing: 24,
                    horizontalMargin: 16,
                    columns: [
                      const DataColumn(label: Text('Activity type')),
                      for (final employee in employees)
                        DataColumn(
                          label: Tooltip(
                            message: employee,
                            child: RotatedBox(quarterTurns: 3,
                              child: SizedBox(width: 196, child: Text(employeeLabel(employee),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.left))),
                          ),
                          numeric: true,
                        ),
                      const DataColumn(label: Text('Count'), numeric: true),
                      const DataColumn(label: Text('Hours'), numeric: true),
                    ],
                    rows: [
                      for (var index = 0; index < types.length; index++)
                        DataRow(
                          color: WidgetStatePropertyAll(
                            index.isEven ? Colors.white : Colors.blue.shade50,
                          ),
                          cells: [
                            DataCell(
                              Tooltip(
                                message:
                                    '${byType(types[index]).first['Description'] ?? ''}',
                                child: Text(
                                  activityLabel(types[index]),
                                ),
                              ),
                            ),
                            for (final employee in employees)
                              countCell(
                                cell(byType(types[index]).where((r) => '${r['Employee'] ?? ''}' == employee)),
                                sum(byType(types[index]).where((r) => '${r['Employee'] ?? ''}' == employee), 'Count'),
                                'CELL', types[index], employee),
                            countCell('${sum(byType(types[index]), 'Count')}',
                              sum(byType(types[index]), 'Count'), 'TYPE', types[index], ''),
                            DataCell(
                              Text(
                                hours(sum(byType(types[index]), 'Minutes')),
                                style: totalStyle,
                              ),
                            ),
                          ],
                        ),
                      DataRow(
                        color: WidgetStatePropertyAll(Colors.blue.shade100),
                        cells: [
                          DataCell(Text('Count', style: totalStyle)),
                          for (final employee in employees)
                            countCell('${sum(rows.where((r) => '${r['Employee'] ?? ''}' == employee), 'Count')}',
                              sum(rows.where((r) => '${r['Employee'] ?? ''}' == employee), 'Count'), 'EMPLOYEE', '', employee),
                          countCell('${sum(rows, 'Count')}', sum(rows, 'Count'), 'ALL', '', ''),
                          const DataCell(Text('')),
                        ],
                      ),
                      DataRow(
                        color: WidgetStatePropertyAll(Colors.blue.shade100),
                        cells: [
                          DataCell(Text('Hours', style: totalStyle)),
                          for (final employee in employees)
                            DataCell(
                              Text(
                                hours(
                                  sum(
                                    rows.where(
                                      (r) =>
                                          '${r['Employee'] ?? ''}' == employee,
                                    ),
                                    'Minutes',
                                  ),
                                ),
                                style: totalStyle,
                              ),
                            ),
                          const DataCell(Text('')),
                          DataCell(
                            Text(
                              hours(sum(rows, 'Minutes')),
                              style: totalStyle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
