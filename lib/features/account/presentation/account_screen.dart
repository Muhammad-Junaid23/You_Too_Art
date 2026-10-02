import 'package:flutter/material.dart';

/// Placeholder account / profile screen.
/// Replace with Figma design.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Account')),
      body: const Center(
        child: Text('Account Screen'),
      ),
    );
  }
}
