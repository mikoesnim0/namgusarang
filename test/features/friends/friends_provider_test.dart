import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hangookji_namgu/features/friends/friends_provider.dart';
import 'package:hangookji_namgu/features/friends/friends_model.dart';
import 'package:hangookji_namgu/features/auth/auth_providers.dart';

void main() {
  test('inviteInfoProvider uses friendInviteCode from user doc', () async {
    final container = ProviderContainer(
      overrides: [
        currentUserDocProvider.overrideWith((ref) {
          return Stream.value(<String, dynamic>{'friendInviteCode': 'ABC123'});
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(currentUserDocProvider.future);
    final info = container.read(inviteInfoProvider);
    expect(info.code, 'ABC123');
    expect(info.shareText, contains('ABC123'));
  });

  test('incomingFriendRequestsCountProvider reflects incoming stream length', () async {
    final container = ProviderContainer(
      overrides: [
        incomingFriendRequestsStreamProvider.overrideWith((ref) {
          return Stream.value(
            [
              FriendRequestIn(fromUid: 'u1', nickname: 'A', createdAt: DateTime(2026, 1, 1)),
              FriendRequestIn(fromUid: 'u2', nickname: 'B', createdAt: DateTime(2026, 1, 1)),
            ],
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    // Flush provider.
    await container.read(incomingFriendRequestsStreamProvider.future);
    expect(container.read(incomingFriendRequestsCountProvider), 2);
  });
}
