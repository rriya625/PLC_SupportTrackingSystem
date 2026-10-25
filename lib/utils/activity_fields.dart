/// Keep the service's existing activity identity for edit/delete/email requests.
int activityNumber(Map<String, dynamic> item) {
  for (final key in const [
    'Number',
    'HistoryNumber',
    'History Number',
    'HistoryNo',
  ]) {
    final number = int.tryParse(item[key]?.toString() ?? '');
    if (number != null && number > 0) return number;
  }
  return 0;
}

bool portalFlag(dynamic value) =>
    value == true ||
    const ['T', 'Y'].contains(value?.toString().trim().toUpperCase());
