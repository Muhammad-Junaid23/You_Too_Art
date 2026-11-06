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
            _mergeCookiesIntoMap(test);
            return jsonEncode(test);
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
            _mergeCookiesIntoMap(test);
            return jsonEncode(test);
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
      final followersCookie = cookieMap['you_too_art_cfollowers'];
      final followingCookie = cookieMap['you_too_art_cfollowing'];
      final deletedCookie = cookieMap['you_too_art_cdeleted'];

      if (callsCookie != null || followersCookie != null || followingCookie != null) {
        final fallbackState = <String, dynamic>{
          'active_persona_id': '68f958bd-015f-4d74-ab42-98c224240537',
          'personas': {},
          'portfolios': {},
          'followers_counts': followersCookie != null
              ? jsonDecode(Uri.decodeComponent(followersCookie))
              : {},
          'following_sets': followingCookie != null
              ? jsonDecode(Uri.decodeComponent(followingCookie))
              : {},
          'deleted_convs_by_user': deletedCookie != null
              ? jsonDecode(Uri.decodeComponent(deletedCookie))
              : {},
          'casting_calls': callsCookie != null
              ? jsonDecode(Uri.decodeComponent(callsCookie))
              : [],
          'casting_applications': appsCookie != null
              ? jsonDecode(Uri.decodeComponent(appsCookie))
              : [],
        };
        return jsonEncode(fallbackState);
      }
    } catch (_) {}

    return null;
  }

  static void writeRawData(String data) {
    try {
      // 1. Write to localStorage and sessionStorage
      html.window.localStorage[_key] = data;
      html.window.sessionStorage[_key] = data;

      // Extract casting calls, applications, followers, following & deleted convs for isolated backup
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
        if (decoded.containsKey('followers_counts')) {
          final folJson = jsonEncode(decoded['followers_counts']);
          html.window.localStorage['you_too_art_followers_counts_v1'] = folJson;
          final encodedFol = Uri.encodeComponent(folJson);
          if (encodedFol.length <= 3800) {
            html.document.cookie =
                'you_too_art_cfollowers=$encodedFol; path=/; max-age=31536000; SameSite=Lax';
          }
        }
        if (decoded.containsKey('following_sets')) {
          final setJson = jsonEncode(decoded['following_sets']);
          html.window.localStorage['you_too_art_following_sets_v1'] = setJson;
          final encodedSet = Uri.encodeComponent(setJson);
          if (encodedSet.length <= 3800) {
            html.document.cookie =
                'you_too_art_cfollowing=$encodedSet; path=/; max-age=31536000; SameSite=Lax';
          }
        }
        if (decoded.containsKey('deleted_convs_by_user')) {
          final delJson = jsonEncode(decoded['deleted_convs_by_user']);
          html.window.localStorage['you_too_art_deleted_convs_v1'] = delJson;
          final encodedDel = Uri.encodeComponent(delJson);
          if (encodedDel.length <= 3800) {
            html.document.cookie =
                'you_too_art_cdeleted=$encodedDel; path=/; max-age=31536000; SameSite=Lax';
          }
        }
      } catch (_) {}
    } catch (_) {}

    try {
      // 2. Write to chunked cookies up to 8 chunks (approx 9.6KB)
      final encoded = Uri.encodeComponent(data);
      if (encoded.length <= 9600) {
        final totalChunks = (encoded.length / _chunkSize).ceil().clamp(1, 8);

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

  static void _mergeCookiesIntoMap(Map<String, dynamic> map) {
    try {
      final cookieHeader = html.document.cookie ?? '';
      final cookieMap = <String, String>{};
      for (final cookie in cookieHeader.split(';')) {
        final parts = cookie.trim().split('=');
        if (parts.length >= 2) {
          cookieMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
        }
      }
      final followersCookie = cookieMap['you_too_art_cfollowers'];
      if (followersCookie != null && followersCookie.isNotEmpty) {
        final fMap = jsonDecode(Uri.decodeComponent(followersCookie));
        if (fMap is Map) {
          final existing = map['followers_counts'] is Map
              ? Map<String, dynamic>.from(map['followers_counts'] as Map)
              : <String, dynamic>{};
          existing.addAll(fMap.cast<String, dynamic>());
          map['followers_counts'] = existing;
        }
      }
      final followingCookie = cookieMap['you_too_art_cfollowing'];
      if (followingCookie != null && followingCookie.isNotEmpty) {
        final sMap = jsonDecode(Uri.decodeComponent(followingCookie));
        if (sMap is Map) {
          final existing = map['following_sets'] is Map
              ? Map<String, dynamic>.from(map['following_sets'] as Map)
              : <String, dynamic>{};
          existing.addAll(sMap.cast<String, dynamic>());
          map['following_sets'] = existing;
        }
      }
      final deletedCookie = cookieMap['you_too_art_cdeleted'];
      if (deletedCookie != null && deletedCookie.isNotEmpty) {
        final dMap = jsonDecode(Uri.decodeComponent(deletedCookie));
        if (dMap is Map) {
          final existing = map['deleted_convs_by_user'] is Map
              ? Map<String, dynamic>.from(map['deleted_convs_by_user'] as Map)
              : <String, dynamic>{};
          existing.addAll(dMap.cast<String, dynamic>());
          map['deleted_convs_by_user'] = existing;
        }
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
