String ticketEmailSubject(
  String acronym,
  String ticketNumber,
  String description,
) {
  final prefix = acronym.trim().isEmpty ? 'PLC' : acronym.trim();
  return '$prefix Ticket #$ticketNumber - ${description.trim()}';
}
