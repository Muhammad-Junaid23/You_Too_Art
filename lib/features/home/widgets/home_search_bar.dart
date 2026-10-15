import 'package:flutter/material.dart';

/// Search input bar matching the Figma Home Screen design.
/// Uses OutlineInputBorder to completely prevent double borders and black focus rings.
class HomeSearchBar extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final String hintText;
  final bool readOnly;
  final bool autoFocus;

  const HomeSearchBar({
    super.key,
    this.onChanged,
    this.onTap,
    this.controller,
    this.hintText = 'Search',
    this.readOnly = false,
    this.autoFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          onTap: onTap,
          readOnly: readOnly,
          autofocus: autoFocus,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF000000),
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hoverColor: Colors.transparent,
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9B9B9B),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF9B9B9B),
              size: 20,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFE6E7E8),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFE6E7E8),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFE6E7E8),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
