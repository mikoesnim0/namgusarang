import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'friends_model.dart';

final friendsControllerProvider =
    NotifierProvider<FriendsController, List<Friend>>(FriendsController.new);

final friendRequestsControllerProvider =
    NotifierProvider<FriendRequestsController, FriendRequestsState>(
  FriendRequestsController.new,
);

final inviteInfoProvider = Provider<InviteInfo>((ref) {
  // TODO: server-issued invite code once Auth is real
  return const InviteInfo(
    code: 'ABC123',
    link: 'https://namgusarang.app/invite/ABC123',
    rewardWon: 3000,
  );
});

final totalFriendRewardProvider = Provider<int>((ref) {
  final friends = ref.watch(friendsControllerProvider);
  return friends.fold<int>(0, (sum, f) => sum + f.rewardWon);
});

final friendRankingProvider = Provider<List<Friend>>((ref) {
  final friends = [...ref.watch(friendsControllerProvider)];
  friends.sort((a, b) => b.rewardWon.compareTo(a.rewardWon));
  return friends;
});

class FriendsController extends Notifier<List<Friend>> {
  @override
  List<Friend> build() {
    final now = DateTime.now();
    return [
      Friend(
        nickname: '나혜영',
        rewardWon: 3000,
        totalSteps: 13040,
        dailySteps: 2100,
        joinedAt: now,
      ),
      Friend(
        nickname: '민서',
        rewardWon: 3000,
        totalSteps: 12240,
        dailySteps: 1800,
        joinedAt: now.subtract(const Duration(days: 1)),
      ),
      Friend(
        nickname: '지훈',
        rewardWon: 9000,
        totalSteps: 17820,
        dailySteps: 3560,
        joinedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  void addFriend(Friend friend) {
    state = [friend, ...state];
  }

  bool addFriendByInviteCode(String code) {
    final trimmed = code.trim();
    if (trimmed.length < 4) return false;

    final next = [
      Friend(nickname: '초대친구', rewardWon: 3000, joinedAt: DateTime.now()),
      ...state,
    ];
    state = next;
    return true;
  }
}

class FriendRequestsController extends Notifier<FriendRequestsState> {
  static final _nicknamePattern = RegExp(r'^[0-9A-Za-z가-힣]{2,12}$');

  @override
  FriendRequestsState build() {
    final now = DateTime.now();
    return FriendRequestsState(
      sent: [
        FriendRequest(
          id: 'sent_1',
          nickname: '홍길동',
          requestedAt: now.subtract(const Duration(days: 2)),
        ),
      ],
      received: [
        FriendRequest(
          id: 'received_1',
          nickname: '새친구',
          requestedAt: now.subtract(const Duration(hours: 6)),
        ),
      ],
    );
  }

  bool sendRequestByNickname(String nickname) {
    final trimmed = nickname.trim();
    if (!_nicknamePattern.hasMatch(trimmed)) return false;

    final already = state.sent.any((r) => r.nickname == trimmed) ||
        state.received.any((r) => r.nickname == trimmed);
    if (already) return false;

    final req = FriendRequest(
      id: 'sent_${DateTime.now().microsecondsSinceEpoch}',
      nickname: trimmed,
      requestedAt: DateTime.now(),
    );

    state = state.copyWith(sent: [req, ...state.sent]);
    return true;
  }

  void cancelSent(String requestId) {
    state = state.copyWith(
      sent: state.sent.where((r) => r.id != requestId).toList(),
    );
  }

  void declineReceived(String requestId) {
    state = state.copyWith(
      received: state.received.where((r) => r.id != requestId).toList(),
    );
  }

  void acceptReceived(String requestId) {
    final idx = state.received.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;
    final req = state.received[idx];

    ref.read(friendsControllerProvider.notifier).addFriend(
          Friend(
            nickname: req.nickname,
            rewardWon: 3000,
            joinedAt: DateTime.now(),
          ),
        );

    state = state.copyWith(
      received: state.received.where((r) => r.id != requestId).toList(),
    );
  }
}
