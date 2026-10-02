import 'package:flutter/material.dart';

/// Placeholder onboarding screen.
/// Replace with Figma design.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding')),
      body: const Center(
        child: Text('Onboarding Screen'),
      ),
    );
  }
}
