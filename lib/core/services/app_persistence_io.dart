import 'dart:io';

/// Native disk storage driver for Windows, macOS, Linux, Android, and iOS.
/// Persists app state to a JSON file on disk that survives process termination,
/// restarts, and rebuilds.
class PlatformStorageDriver {
  static const String _fileName = 'you_too_art_local_state.json';

  static String? readRawData() {
    try {
      // 1. Try local project / working directory file
      final localFile = File(_fileName);
      if (localFile.existsSync()) {
        final content = localFile.readAsStringSync();
        if (content.trim().isNotEmpty) return content;
      }

      // 2. Try UserProfile / AppData / HOME directory
      final homeDir = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Platform.environment['APPDATA'];
      if (homeDir != null) {
        final homeFile = File('$homeDir${Platform.pathSeparator}.$_fileName');
        if (homeFile.existsSync()) {
          final content = homeFile.readAsStringSync();
          if (content.trim().isNotEmpty) return content;
        }
      }

      // 3. Try system temp
      final tempFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}$_fileName');
      if (tempFile.existsSync()) {
        final content = tempFile.readAsStringSync();
        if (content.trim().isNotEmpty) return content;
      }
    } catch (_) {}
    return null;
  }

  static void writeRawData(String data) {
    try {
      // 1. Write to local directory
      final localFile = File(_fileName);
      localFile.writeAsStringSync(data, flush: true);
    } catch (_) {}

    try {
      // 2. Write to user home directory for permanent desktop persistence
      final homeDir = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Platform.environment['APPDATA'];
      if (homeDir != null) {
        final homeFile = File('$homeDir${Platform.pathSeparator}.$_fileName');
        homeFile.writeAsStringSync(data, flush: true);
      }
    } catch (_) {}

    try {
      // 3. Write to system temp
      final tempFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}$_fileName');
      tempFile.writeAsStringSync(data, flush: true);
    } catch (_) {}
  }
}
