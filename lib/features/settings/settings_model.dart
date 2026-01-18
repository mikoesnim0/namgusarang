enum Gender {
  male,
  female,
  other,
}

enum AgeRange {
  teen,
  twenties,
  thirties,
  forties,
  fiftiesPlus,
}

class ProfileSettings {
  const ProfileSettings({
    required this.nickname,
    required this.email,
    required this.ageRange,
    required this.gender,
  });

  final String nickname;
  final String email;
  final AgeRange ageRange;
  final Gender gender;

  ProfileSettings copyWith({
    String? nickname,
    String? email,
    AgeRange? ageRange,
    Gender? gender,
  }) {
    return ProfileSettings(
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      ageRange: ageRange ?? this.ageRange,
      gender: gender ?? this.gender,
    );
  }
}

class NotificationSettings {
  const NotificationSettings({
    required this.mission,
    required this.coupon,
    required this.eventBenefit,
    required this.notice,
  });

  final bool mission;
  final bool coupon;
  final bool eventBenefit;
  final bool notice;

  NotificationSettings copyWith({
    bool? mission,
    bool? coupon,
    bool? eventBenefit,
    bool? notice,
  }) {
    return NotificationSettings(
      mission: mission ?? this.mission,
      coupon: coupon ?? this.coupon,
      eventBenefit: eventBenefit ?? this.eventBenefit,
      notice: notice ?? this.notice,
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.profile,
    required this.notifications,
  });

  final ProfileSettings profile;
  final NotificationSettings notifications;

  static AppSettings defaults() {
    return const AppSettings(
      profile: ProfileSettings(
        nickname: '닉네임',
        email: '',
        ageRange: AgeRange.forties,
        gender: Gender.female,
      ),
      notifications: NotificationSettings(
        mission: true,
        coupon: true,
        eventBenefit: true,
        notice: true,
      ),
    );
  }

  AppSettings copyWith({
    ProfileSettings? profile,
    NotificationSettings? notifications,
  }) {
    return AppSettings(
      profile: profile ?? this.profile,
      notifications: notifications ?? this.notifications,
    );
  }
}
