class Friend {
  const Friend({
    required this.friendUid,
    required this.nickname,
    required this.createdAt,
    this.photoUrl,
    this.level,
    this.profileIndex,
    this.snapshotAt,
    this.rewardWon,
    this.totalSteps,
    this.dailySteps,
  });

  final String friendUid;
  final String nickname;
  final String? photoUrl;
  final int? level;
  final int? profileIndex;
  final DateTime createdAt;
  final DateTime? snapshotAt;

  // Optional legacy metrics (not required for MVP friend system).
  final int? rewardWon;
  final int? totalSteps;
  final int? dailySteps;
}

class FriendRequestIn {
  const FriendRequestIn({
    required this.fromUid,
    required this.nickname,
    required this.createdAt,
    this.photoUrl,
    this.level,
    this.profileIndex,
  });

  final String fromUid;
  final String nickname;
  final String? photoUrl;
  final int? level;
  final int? profileIndex;
  final DateTime createdAt;
}

class FriendRequestOut {
  const FriendRequestOut({
    required this.toUid,
    required this.nickname,
    required this.createdAt,
    this.photoUrl,
  });

  final String toUid;
  final String nickname;
  final String? photoUrl;
  final DateTime createdAt;
}

class InviteInfo {
  const InviteInfo({required this.code, required this.shareText});

  final String code;
  final String shareText;
}
