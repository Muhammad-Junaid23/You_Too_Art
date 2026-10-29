import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web storage driver using localStorage and cross-port chunked cookies.
/// Cookies on localhost are shared across all port allocations,
/// preventing data wipes when flutter run chooses a new port.
class PlatformStorageDriver {
  static const String _key = 'you_too_art_local_state_v4';
  static const int _chunkSize = 1200;

  static String? readRawData() {
    try {
      // 1. Check window.localStorage
      final local = html.window.localStorage[_key];
      if (local != null && local.trim().isNotEmpty) {
        try {
          final test = jsonDecode(local);
          if (test is Map<String, dynamic>) {
            return local;
          }
        } catch (_) {}
      }
    } catch (_) {}

    try {
      // 2. Check window.sessionStorage
      final session = html.window.sessionStorage[_key];
      if (session != null && session.trim().isNotEmpty) {
        try {
          final test = jsonDecode(session);
          if (test is Map<String, dynamic>) {
            return session;
          }
        } catch (_) {}
      }
    } catch (_) {}

    try {
      // 3. Check chunked cookies (shared across localhost ports)
      final cookieHeader = html.document.cookie ?? '';
      final cookieMap = <String, String>{};
      for (final cookie in cookieHeader.split(';')) {
        final parts = cookie.trim().split('=');
        if (parts.length >= 2) {
          cookieMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
        }
      }

      final countStr = cookieMap['you_too_art_ccount'];
      if (countStr != null) {
        final count = int.tryParse(countStr) ?? 0;
        if (count > 0 && count < 30) {
          final buffer = StringBuffer();
          bool allFound = true;
          for (int i = 0; i < count; i++) {
            final chunk = cookieMap['you_too_art_c$i'];
            if (chunk != null) {
              buffer.write(chunk);
            } else {
              allFound = false;
              break;
            }
          }
          if (allFound) {
            final combined = buffer.toString();
            if (combined.isNotEmpty) {
              final decoded = Uri.decodeComponent(combined);
              if (decoded.trim().isNotEmpty) {
                try {
                  final test = jsonDecode(decoded);
                  if (test is Map<String, dynamic>) {
                    html.window.localStorage[_key] = decoded;
                    return decoded;
                  }
                } catch (_) {}
              }
            }
          }
        }
      }
    } catch (_) {}

    // 4. Check dedicated casting calls cookie if raw data wasn't found or was incomplete
    try {
      final cookieHeader = html.document.cookie ?? '';
      final cookieMap = <String, String>{};
      for (final cookie in cookieHeader.split(';')) {
        final parts = cookie.trim().split('=');
        if (parts.length >= 2) {
          cookieMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
        }
      }

      final callsCookie = cookieMap['you_too_art_ccalls'];
      final appsCookie = cookieMap['you_too_art_capps'];

      if (callsCookie != null && callsCookie.isNotEmpty) {
        final decodedCalls = Uri.decodeComponent(callsCookie);
        final callsList = jsonDecode(decodedCalls);
        if (callsList is List && callsList.isNotEmpty) {
          final fallbackState = {
            'active_persona_id': '00000000-0000-0000-0000-000000000001',
            'personas': {},
            'portfolios': {},
            'casting_calls': callsList,
            'casting_applications': appsCookie != null
                ? jsonDecode(Uri.decodeComponent(appsCookie))
                : [],
          };
          return jsonEncode(fallbackState);
        }
      }
    } catch (_) {}

    return null;
  }

  static void writeRawData(String data) {
    try {
      // 1. Write to localStorage and sessionStorage
      html.window.localStorage[_key] = data;
      html.window.sessionStorage[_key] = data;

      // Extract casting calls & applications for isolated backup
      try {
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        if (decoded.containsKey('casting_calls')) {
          final callsJson = jsonEncode(decoded['casting_calls']);
          html.window.localStorage['you_too_art_casting_calls_v2'] = callsJson;
          final encodedCalls = Uri.encodeComponent(callsJson);
          if (encodedCalls.length <= 3800) {
            html.document.cookie =
                'you_too_art_ccalls=$encodedCalls; path=/; max-age=31536000; SameSite=Lax';
          }
        }
        if (decoded.containsKey('casting_applications')) {
          final appsJson = jsonEncode(decoded['casting_applications']);
          html.window.localStorage['you_too_art_casting_apps_v2'] = appsJson;
          final encodedApps = Uri.encodeComponent(appsJson);
          if (encodedApps.length <= 3800) {
            html.document.cookie =
                'you_too_art_capps=$encodedApps; path=/; max-age=31536000; SameSite=Lax';
          }
        }
      } catch (_) {}
    } catch (_) {}

    try {
      // 2. Write to chunked cookies only if within safe browser cookie budget (< 3800 bytes)
      final encoded = Uri.encodeComponent(data);
      if (encoded.length <= 3800) {
        final totalChunks = (encoded.length / _chunkSize).ceil();

        for (int i = 0; i < totalChunks; i++) {
          final start = i * _chunkSize;
          final end = (start + _chunkSize < encoded.length)
              ? start + _chunkSize
              : encoded.length;
          final chunk = encoded.substring(start, end);
          html.document.cookie =
              'you_too_art_c$i=$chunk; path=/; max-age=31536000; SameSite=Lax';
        }

        // Clear any older excess chunks
        for (int i = totalChunks; i < totalChunks + 10; i++) {
          html.document.cookie =
              'you_too_art_c$i=; path=/; max-age=0; SameSite=Lax';
        }

        html.document.cookie =
            'you_too_art_ccount=$totalChunks; path=/; max-age=31536000; SameSite=Lax';
      }
    } catch (_) {}
  }

  static void clearRawData() {
    try {
      html.window.localStorage.remove(_key);
      html.window.localStorage.remove('you_too_art_local_state_v3');
      html.window.localStorage.remove('you_too_art_master_state_v4');
      html.window.localStorage.remove('you_too_art_master_state_v3');
      html.window.localStorage.remove('you_too_art_casting_calls_v2');
      html.window.localStorage.remove('you_too_art_casting_apps_v2');
      html.window.sessionStorage.remove(_key);
      html.window.sessionStorage.remove('you_too_art_local_state_v3');
      html.window.sessionStorage.remove('you_too_art_master_state_v4');

      for (int i = 0; i < 30; i++) {
        html.document.cookie = 'you_too_art_c$i=; path=/; max-age=0; SameSite=Lax';
      }
      html.document.cookie = 'you_too_art_ccount=; path=/; max-age=0; SameSite=Lax';
      html.document.cookie = 'you_too_art_ccalls=; path=/; max-age=0; SameSite=Lax';
      html.document.cookie = 'you_too_art_capps=; path=/; max-age=0; SameSite=Lax';
    } catch (_) {}
  }
}
