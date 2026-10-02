import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget that listens to [AppLifecycleState] and triggers a reload
/// of the current user data when the app resumes from the background.
///
/// Wrap a screen or the root widget with this to keep user data fresh.
class AppLifecycleReloader extends ConsumerStatefulWidget {
  final Widget child;

  /// Callback invoked when the app resumes.
  /// Use this to refresh user data or other stale state.
  final VoidCallback? onReload;

  const AppLifecycleReloader({
    super.key,
    required this.child,
    this.onReload,
  });

  @override
  ConsumerState<AppLifecycleReloader> createState() =>
      _AppLifecycleReloaderState();
}

class _AppLifecycleReloaderState extends ConsumerState<AppLifecycleReloader>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.onReload?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
