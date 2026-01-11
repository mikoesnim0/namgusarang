class Friend {
  const Friend({
    required this.nickname,
    required this.rewardWon,
    required this.joinedAt,
  });

  final String nickname;
  final int rewardWon;
  final DateTime joinedAt;
}

class InviteInfo {
  const InviteInfo({
    required this.code,
    required this.link,
    required this.rewardWon,
  });

  final String code;
  final String link;
  final int rewardWon;
}

