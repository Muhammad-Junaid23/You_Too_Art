import 'package:flutter/material.dart';

/// Resilient Avatar widget that safely handles 404s and network errors
/// on Flutter Web and Mobile without throwing unhandled exceptions.
class AppAvatar extends StatelessWidget {
  static final Set<String> _failedUrls = {};

  final String? imageUrl;
  final String name;
  final double radius;
  final Color backgroundColor;
  final Color textColor;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name = 'User',
    this.radius = 20,
    this.backgroundColor = const Color(0xFFE7F3FE),
    this.textColor = const Color(0xFF3899F3),
  });

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        _getInitials(name),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.85,
        ),
      ),
    );

    final cleanUrl = imageUrl?.trim();
    if (cleanUrl == null || cleanUrl.isEmpty || _failedUrls.contains(cleanUrl)) {
      return fallback;
    }

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          cleanUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            _failedUrls.add(cleanUrl);
            return fallback;
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(width: size, height: size, color: backgroundColor);
          },
        ),
      ),
    );
  }
}
