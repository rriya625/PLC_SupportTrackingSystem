// This file only wires up conditional exports.
// It does NOT define FileDownloadHelper itself.
export 'file_download_helper_stub.dart'
if (dart.library.html) 'file_download_helper_web.dart'
if (dart.library.io) 'file_download_helper_mobile.dart';