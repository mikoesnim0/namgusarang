import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hangookji_namgu/features/friends/friends_provider.dart';

void main() {
  test('addFriendByInviteCode requires min length and prepends friend', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(friendsControllerProvider);
    final ok1 = container
        .read(friendsControllerProvider.notifier)
        .addFriendByInviteCode('12');
    expect(ok1, isFalse);
    expect(container.read(friendsControllerProvider).length, before.length);

    final ok2 = container
        .read(friendsControllerProvider.notifier)
        .addFriendByInviteCode('ABCD');
    expect(ok2, isTrue);
    final after = container.read(friendsControllerProvider);
    expect(after.length, before.length + 1);
  });

  test('totalFriendRewardProvider sums rewards', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final total = container.read(totalFriendRewardProvider);
    expect(total, greaterThan(0));
  });
}

