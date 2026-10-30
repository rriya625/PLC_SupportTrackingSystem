class ManualDownload {
  final String fileName;
  final String contentType;
  final List<int> signature;
  const ManualDownload(this.fileName, this.contentType, this.signature);
  bool matches(List<int> bytes) => bytes.length >= signature.length &&
      List.generate(signature.length, (i) => bytes[i] == signature[i]).every((x) => x);
}
ManualDownload manualForRole(bool employee) => employee
    ? const ManualDownload('EmployeeManuals.zip', 'application/zip', [0x50,0x4b,0x03,0x04])
    : const ManualDownload('UserManual.pdf', 'application/pdf', [0x25,0x50,0x44,0x46,0x2d]);
