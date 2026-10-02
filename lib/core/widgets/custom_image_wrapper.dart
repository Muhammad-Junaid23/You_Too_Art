import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Builds an image widget that smartly picks the source:
/// 1. Asset path (starts with `assets/`)
/// 2. Network URL (starts with `http`, `https`, or `blob`)
/// 3. Fallback icon
///
/// Does NOT use `existsSync` (blocking I/O) — uses string prefix detection only.
Widget buildSmartImage({
  required String? imageUrl,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? fallback,
  BorderRadius? borderRadius,
}) {
  final effectiveFallback = fallback ??
      Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_outlined, color: Colors.grey, size: 40),
      );

  if (imageUrl == null || imageUrl.isEmpty) {
    return _wrapWithBorderRadius(effectiveFallback, borderRadius);
  }

  Widget imageWidget;

  // 1. Asset image
  if (imageUrl.startsWith('assets/')) {
    imageWidget = Image.asset(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, error, stackTrace) {
        if (kDebugMode) debugPrint('Asset image error: $error');
        return effectiveFallback;
      },
    );
  }
  // 2. Network image
  else if (imageUrl.startsWith('http') || imageUrl.startsWith('blob')) {
    imageWidget = Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          width: width,
          height: height,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (_, error, stackTrace) {
        if (kDebugMode) debugPrint('Network image error: $error');
        return effectiveFallback;
      },
    );
  }
  // 3. Fallback
  else {
    imageWidget = effectiveFallback;
  }

  return _wrapWithBorderRadius(imageWidget, borderRadius);
}

Widget _wrapWithBorderRadius(Widget child, BorderRadius? borderRadius) {
  if (borderRadius == null) return child;
  return ClipRRect(borderRadius: borderRadius, child: child);
}
