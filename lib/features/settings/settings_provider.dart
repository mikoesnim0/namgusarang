import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_model.dart';
import 'settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(prefs: SharedPreferences.getInstance());
});

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final repo = ref.read(settingsRepositoryProvider);
    return repo.load();
  }

  Future<void> updateProfile(ProfileSettings profile) async {
    final repo = ref.read(settingsRepositoryProvider);
    final current = state.valueOrNull ?? AppSettings.defaults();
    final next = current.copyWith(profile: profile);
    state = AsyncValue.data(next);
    await repo.save(next);
  }

  Future<void> updateNotifications(NotificationSettings notifications) async {
    final repo = ref.read(settingsRepositoryProvider);
    final current = state.valueOrNull ?? AppSettings.defaults();
    final next = current.copyWith(notifications: notifications);
    state = AsyncValue.data(next);
    await repo.save(next);
  }
}

