import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'steps_provider.dart';

final backgroundStepsControllerProvider =
    StateNotifierProvider<BackgroundStepsController, AsyncValue<bool>>((ref) {
      return BackgroundStepsController(ref);
    });

class BackgroundStepsController extends StateNotifier<AsyncValue<bool>> {
  BackgroundStepsController(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  final Ref _ref;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  Future<void> _load() async {
    if (!_isAndroid) {
      state = const AsyncValue.data(false);
      return;
    }
    final repo = _ref.read(stepsRepositoryProvider);
    final running = await repo.isBackgroundStepsRunning();
    state = AsyncValue.data(running);
  }

  Future<void> setEnabled(bool enabled) async {
    if (!_isAndroid) return;

    state = const AsyncValue.loading();
    final repo = _ref.read(stepsRepositoryProvider);
    if (enabled) {
      await repo.startBackgroundSteps();
    } else {
      await repo.stopBackgroundSteps();
    }
    await _load();
  }

  Future<void> refresh() => _load();
}
