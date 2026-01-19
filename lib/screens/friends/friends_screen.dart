import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/friends/friends_model.dart';
import '../../features/friends/friends_provider.dart';
import '../../features/settings/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitNickname() {
    final nickname = _controller.text.trim();
    final ok = ref
        .read(friendRequestsControllerProvider.notifier)
        .sendRequestByNickname(nickname);
    if (ok) {
      _controller.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구 요청을 보냈습니다.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('2~12자 한글/영문/숫자 닉네임을 입력하세요')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsControllerProvider);
    final requests = ref.watch(friendRequestsControllerProvider);
    final pendingCount = requests.sent.length + requests.received.length;

    final settingsAsync = ref.watch(settingsControllerProvider);
    final userDoc = ref.watch(currentUserDocProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final settingsNickname = settingsAsync.valueOrNull?.profile.nickname;
    final docNickname = (userDoc?['nickname'] as String?)?.trim();
    final authNickname = authUser?.displayName?.trim();
    final nickname = (docNickname?.isNotEmpty == true)
        ? docNickname!
        : (authNickname?.isNotEmpty == true)
            ? authNickname!
            : (settingsNickname?.trim().isNotEmpty == true)
                ? settingsNickname!.trim()
                : '닉네임';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  onTap: () => context.push('/my/info'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.gray200,
                        child:
                            Icon(Icons.person, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.center,
                child: Text('친구목록'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/friends/requests'),
                  child: Text(
                    pendingCount > 0 ? '대기 $pendingCount' : '대기',
                    style: AppTypography.bodySmall.copyWith(
                      color: pendingCount > 0
                          ? AppColors.primary500
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView.separated(
        padding: AppTheme.screenPadding.copyWith(bottom: 120),
        itemCount: friends.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, idx) {
          if (idx == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchBar(
                  controller: _controller,
                  onSubmit: _submitNickname,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Spacer(),
                    Text(
                      '${friends.length}명',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          final friend = friends[idx - 1];
          return _FriendCard(friend: friend);
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.gray200,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '닉네임으로 친구 추가',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                onTap: onSubmit,
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      margin: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.gray200,
            child: Icon(Icons.person, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              friend.nickname,
              style: AppTypography.bodyLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Metric(
                label: '쿠폰으로 아낀 금액',
                value: '${_comma(friend.rewardWon)}원',
              ),
              const SizedBox(height: 4),
              _Metric(
                label: '총 걸음 수',
                value: '${_comma(friend.totalSteps)}보',
              ),
              const SizedBox(height: 4),
              _Metric(
                label: '일일 걸음수',
                value: '${_comma(friend.dailySteps)}보',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _comma(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final idx = s.length - i;
    buf.write(s[i]);
    if (idx > 1 && idx % 3 == 1) buf.write(',');
  }
  return buf.toString();
}

