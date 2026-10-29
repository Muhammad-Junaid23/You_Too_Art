/// Default fallback platform driver when neither dart:io nor dart:html is available.
class PlatformStorageDriver {
  static String? readRawData() => null;
  static void writeRawData(String data) {}
  static void clearRawData() {}
}
