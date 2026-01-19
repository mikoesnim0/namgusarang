class Friend {
  const Friend({
    required this.nickname,
    required this.rewardWon,
    required this.joinedAt,
    this.totalSteps = 13040,
    this.dailySteps = 1340,
  });

  final String nickname;
  final int rewardWon;
  final DateTime joinedAt;
  final int totalSteps;
  final int dailySteps;
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.nickname,
    required this.requestedAt,
  });

  final String id;
  final String nickname;
  final DateTime requestedAt;
}

class FriendRequestsState {
  const FriendRequestsState({
    required this.sent,
    required this.received,
  });

  final List<FriendRequest> sent;
  final List<FriendRequest> received;

  FriendRequestsState copyWith({
    List<FriendRequest>? sent,
    List<FriendRequest>? received,
  }) {
    return FriendRequestsState(
      sent: sent ?? this.sent,
      received: received ?? this.received,
    );
  }
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
