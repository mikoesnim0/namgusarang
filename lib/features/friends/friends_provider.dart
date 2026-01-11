import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'friends_model.dart';

final friendsControllerProvider =
    NotifierProvider<FriendsController, List<Friend>>(FriendsController.new);

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
      Friend(nickname: '나혜영', rewardWon: 3000, joinedAt: now),
      Friend(nickname: '민서', rewardWon: 3000, joinedAt: now.subtract(const Duration(days: 1))),
      Friend(nickname: '나혜영', rewardWon: 3000, joinedAt: now.subtract(const Duration(days: 2))),
    ];
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

