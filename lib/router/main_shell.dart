import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/steps/steps_sync_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/widgets.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  DateTime? _lastBackPressed;

  void _onTap(BuildContext context, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _handleBack() async {
    // 1) If there's anything to pop in the current route stack, pop it first.
    if (mounted && GoRouter.of(context).canPop()) {
      context.pop();
      return;
    }

    // 2) If user is not on Home tab, go back to Home tab.
    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0, initialLocation: false);
      _lastBackPressed = null;
      return;
    }

    // 3) Home tab root: double-back to exit.
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      if (mounted) {
        context.showAppSnackBar(
          '앱을 종료하려면 한 번 더 눌러주세요',
          duration: const Duration(milliseconds: 1600),
        );
      }
      return;
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Keep steps→Firestore syncing alive even when the user is not on Home.
    ref.watch(stepsSyncControllerProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.gray50,
        body: widget.navigationShell,
        bottomNavigationBar: AppBottomNav(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: (idx) => _onTap(context, idx),
        ),
      ),
    );
  }
}
