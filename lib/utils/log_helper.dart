import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

/// Platform-specific imports (dart:io is NOT supported on web!)
/// We use conditional guards to avoid calling this on the web.
import 'dart:io' show File, FileMode, Platform, IOSink, Directory;

import 'package:intl/intl.dart';

class LogHelper {
  static String? _labSaveDir;
  static DateTime? _lastWriteTime;
  static IOSink? _logSink;

  /// Initialize log config from web.config or fallback to C:\LABSAVE\
  static Future<void> init() async {
    print("[LogHelper] init() called");
    print("[LogHelper] kIsWeb: $kIsWeb");

    if (kIsWeb) {
      print("[LogHelper] Skipping init: running on web");
      return;
    }

    if (!Platform.isWindows) {
      print("[LogHelper] Skipping init: not running on Windows (Platform: ${Platform.operatingSystem})");
      return;
    }

    try {
      final configFile = File('web.config');
      if (await configFile.exists()) {
        final xml = await configFile.readAsString();
        final regex = RegExp(r'<add key="LABSAVEDIR" value="(.*?)"');
        final match = regex.firstMatch(xml);
        if (match != null) {
          _labSaveDir = match.group(1);
          if (_labSaveDir != null && !_labSaveDir!.endsWith(r'\')) {
            _labSaveDir = '$_labSaveDir\\';
          }
          print("[LogHelper] LABSAVEDIR from web.config: $_labSaveDir");
        } else {
          print("[LogHelper] LABSAVEDIR not found in web.config");
        }
      } else {
        print("[LogHelper] web.config not found");
      }

      if (_labSaveDir == null) {
        _labSaveDir = r'C:\LABSAVE\';
        print("[LogHelper] Using default LABSAVEDIR: $_labSaveDir");
      }
    } catch (e) {
      print("[LogHelper] Exception during init: $e");
      _labSaveDir = r'C:\LABSAVE\';
    }
  }

  /// Log a message - writes to file on Windows, to console on web
  static Future<void> log(String message) async {
    if (kIsWeb) {
      print("[WebLog] $message"); // show in browser console
      return;
    }

    if (!Platform.isWindows) {
      print("[LogHelper] Skipping log: not Windows platform");
      return;
    }

    if (_labSaveDir == null) {
      print("[LogHelper] Skipping log: LABSAVEDIR is null");
      return;
    }

    try {
      final now = DateTime.now();
      final hourKey = DateFormat('yyyy-MM-dd_HH').format(now);
      final fileName = 'support_web_$hourKey.log';
      final logPath = '$_labSaveDir$fileName';

      final dir = Directory(_labSaveDir!);
      if (!(await dir.exists())) {
        print("[LogHelper] Creating missing LABSAVEDIR: $_labSaveDir");
        await dir.create(recursive: true);
      }

      if (_lastWriteTime == null || _lastWriteTime!.hour != now.hour) {
        await _logSink?.flush();
        await _logSink?.close();
        final file = File(logPath);
        _logSink = file.openWrite(mode: FileMode.append);
        _lastWriteTime = now;
        print("[LogHelper] New log file created: $logPath");
      }

      final timestamp = DateFormat('HH:mm:ss').format(now);
      final logLine = "[$timestamp] $message";
      _logSink?.writeln(logLine);
      print("[LogHelper] Log written: $logLine");
    } catch (e) {
      print("[LogHelper] Error writing log: $e");
    }
  }

  /// Optional cleanup on app shutdown
  static Future<void> dispose() async {
    try {
      await _logSink?.flush();
      await _logSink?.close();
      _logSink = null;
      print("[LogHelper] Log sink closed");
    } catch (_) {}
  }
}