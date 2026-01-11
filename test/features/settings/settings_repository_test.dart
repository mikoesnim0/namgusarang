import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hangookji_namgu/features/settings/settings_model.dart';
import 'package:hangookji_namgu/features/settings/settings_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns defaults when nothing saved', () async {
    final repo = SettingsRepository(prefs: SharedPreferences.getInstance());
    final settings = await repo.load();

    expect(settings.profile.nickname, AppSettings.defaults().profile.nickname);
    expect(settings.notifications.mission,
        AppSettings.defaults().notifications.mission);
  });

  test('save then load roundtrips values', () async {
    final repo = SettingsRepository(prefs: SharedPreferences.getInstance());

    final original = AppSettings.defaults().copyWith(
      profile: AppSettings.defaults().profile.copyWith(
        nickname: '민서',
        email: 'minseo@example.com',
        ageRange: AgeRange.twenties,
        gender: Gender.male,
      ),
      notifications: AppSettings.defaults().notifications.copyWith(
        mission: false,
        coupon: true,
        eventBenefit: false,
        notice: true,
      ),
    );

    await repo.save(original);
    final loaded = await repo.load();

    expect(loaded.profile.nickname, '민서');
    expect(loaded.profile.email, 'minseo@example.com');
    expect(loaded.profile.ageRange, AgeRange.twenties);
    expect(loaded.profile.gender, Gender.male);
    expect(loaded.notifications.mission, false);
    expect(loaded.notifications.coupon, true);
    expect(loaded.notifications.eventBenefit, false);
    expect(loaded.notifications.notice, true);
  });
}

