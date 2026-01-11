import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hangookji_namgu/features/settings/settings_model.dart';
import 'package:hangookji_namgu/features/settings/settings_provider.dart';
import 'package:hangookji_namgu/features/settings/settings_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SettingsController loads defaults and persists updates', () async {
    final repo = SettingsRepository(prefs: SharedPreferences.getInstance());
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final initial = await container.read(settingsControllerProvider.future);
    expect(initial.profile.nickname, AppSettings.defaults().profile.nickname);

    await container
        .read(settingsControllerProvider.notifier)
        .updateProfile(initial.profile.copyWith(nickname: '정민영'));

    final updated = container.read(settingsControllerProvider).value!;
    expect(updated.profile.nickname, '정민영');

    // New container should load the persisted value.
    final container2 = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container2.dispose);

    final loaded = await container2.read(settingsControllerProvider.future);
    expect(loaded.profile.nickname, '정민영');
  });
}

