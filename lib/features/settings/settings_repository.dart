import 'package:shared_preferences/shared_preferences.dart';

import 'settings_model.dart';

class SettingsRepository {
  SettingsRepository({required Future<SharedPreferences> prefs})
      : _prefs = prefs;

  final Future<SharedPreferences> _prefs;

  static const _kNickname = 'settings.profile.nickname';
  static const _kEmail = 'settings.profile.email';
  static const _kAgeRange = 'settings.profile.ageRange';
  static const _kGender = 'settings.profile.gender';

  static const _kNotifMission = 'settings.notifications.mission';
  static const _kNotifCoupon = 'settings.notifications.coupon';
  static const _kNotifEventBenefit = 'settings.notifications.eventBenefit';
  static const _kNotifNotice = 'settings.notifications.notice';

  Future<AppSettings> load() async {
    final prefs = await _prefs;

    final defaults = AppSettings.defaults();

    return AppSettings(
      profile: defaults.profile.copyWith(
        nickname: prefs.getString(_kNickname),
        email: prefs.getString(_kEmail),
        ageRange: _decodeAgeRange(prefs.getString(_kAgeRange)),
        gender: _decodeGender(prefs.getString(_kGender)),
      ),
      notifications: defaults.notifications.copyWith(
        mission: prefs.getBool(_kNotifMission),
        coupon: prefs.getBool(_kNotifCoupon),
        eventBenefit: prefs.getBool(_kNotifEventBenefit),
        notice: prefs.getBool(_kNotifNotice),
      ),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await _prefs;

    await prefs.setString(_kNickname, settings.profile.nickname);
    await prefs.setString(_kEmail, settings.profile.email);
    await prefs.setString(_kAgeRange, settings.profile.ageRange.name);
    await prefs.setString(_kGender, settings.profile.gender.name);

    await prefs.setBool(_kNotifMission, settings.notifications.mission);
    await prefs.setBool(_kNotifCoupon, settings.notifications.coupon);
    await prefs.setBool(
      _kNotifEventBenefit,
      settings.notifications.eventBenefit,
    );
    await prefs.setBool(_kNotifNotice, settings.notifications.notice);
  }

  AgeRange? _decodeAgeRange(String? raw) {
    if (raw == null) return null;
    for (final v in AgeRange.values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  Gender? _decodeGender(String? raw) {
    if (raw == null) return null;
    for (final v in Gender.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

