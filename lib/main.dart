import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:you_too_art/app/config/routes.dart';
import 'package:you_too_art/app/theme/theme.dart';
import 'package:you_too_art/core/providers/theme_provider.dart';
import 'package:you_too_art/core/widgets/web_responsive_wrapper.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nvymirbsyzcnsphprbkc.supabase.co',
    publishableKey: 'sb_publishable_1KCWaVcKpBTNyhZOU2LhLw_vaVFLKDV',
  );

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const YouTooArtApp(),
    ),
  );
}

class YouTooArtApp extends ConsumerWidget {
  const YouTooArtApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'You Too Art',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: theme,
      routerConfig: router,
      builder: (context, child) =>
          WebResponsiveWrapper(child: child ?? const SizedBox.shrink()),
    );
  }
}
