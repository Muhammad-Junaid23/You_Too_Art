/// Utilities for injecting Cloudinary image transformations into URLs.
///
/// These helpers work by inserting transformation segments into
/// existing `res.cloudinary.com` URLs. If the URL is not a
/// Cloudinary URL, it is returned unchanged.
library;

/// Injects a thumbnail transformation into a Cloudinary URL.
///
/// Example:
/// ```dart
/// final thumb = cloudinaryThumb(url, w: 400, h: 300);
/// ```
String cloudinaryThumb(String? url, {int w = 400, int h = 300}) {
  if (url == null || url.isEmpty) return '';
  if (!url.contains('res.cloudinary.com')) return url;

  final transform = 'c_fill,w_$w,h_$h,q_auto,f_auto';
  return _injectTransform(url, transform);
}

/// Injects an avatar (square crop + face detection) transformation.
///
/// Example:
/// ```dart
/// final avatar = cloudinaryAvatar(url, size: 200);
/// ```
String cloudinaryAvatar(String? url, {int size = 200}) {
  if (url == null || url.isEmpty) return '';
  if (!url.contains('res.cloudinary.com')) return url;

  final transform = 'c_fill,g_face,w_$size,h_$size,q_auto,f_auto';
  return _injectTransform(url, transform);
}

/// Internal helper that inserts a transformation segment
/// right after `/upload/` in a Cloudinary URL.
String _injectTransform(String url, String transform) {
  const uploadSegment = '/upload/';
  final uploadIndex = url.indexOf(uploadSegment);
  if (uploadIndex == -1) return url;

  final insertAt = uploadIndex + uploadSegment.length;
  return '${url.substring(0, insertAt)}$transform/${url.substring(insertAt)}';
}
