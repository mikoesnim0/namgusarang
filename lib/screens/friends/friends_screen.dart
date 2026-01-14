import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/friends/friends_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsControllerProvider);
    final invite = ref.watch(inviteInfoProvider);
    final totalReward = ref.watch(totalFriendRewardProvider);
    final ranking = ref.watch(friendRankingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구'),
        actions: [
          IconButton(
            tooltip: '친구 추가',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _InviteSheet(),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppTheme.screenPadding.copyWith(bottom: 120),
        children: [
          AppCard(
            variant: CardVariant.elevated,
            padding: const EdgeInsets.all(AppSpacing.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('친구 초대', style: AppTypography.labelLarge),
                const SizedBox(height: 6),
                Text(
                  '친구가 가입하면 +${_comma(invite.rewardWon)}원 혜택!',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '초대코드: ${invite.code}',
                          style: AppTypography.bodyMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '복사',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: invite.code),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('초대코드를 복사했습니다')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: '초대 링크 공유',
                        variant: ButtonVariant.primary,
                        isFullWidth: true,
                        onPressed: () async {
                          try {
                            await Share.share('Walker홀릭 초대 링크: ${invite.link}');
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('공유 불가')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.ios_share, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        text: '친구 추가',
                        variant: ButtonVariant.outline,
                        isFullWidth: true,
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const _InviteSheet(),
                        ),
                        icon: const Icon(Icons.person_add_alt_1, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          AppCard(
            padding: const EdgeInsets.all(AppSpacing.paddingMD),
            child: Row(
              children: [
                Text('누적 혜택', style: AppTypography.labelLarge),
                const Spacer(),
                Text(
                  '+${_comma(totalReward)}원',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.primary700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          AppCard(
            padding: const EdgeInsets.all(AppSpacing.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('랭킹', style: AppTypography.labelLarge),
                    const Spacer(),
                    Text('${ranking.length}명', style: AppTypography.bodySmall),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < ranking.length; i++) ...[
                  _RankingRow(rank: i + 1, name: ranking[i].nickname, won: ranking[i].rewardWon),
                  if (i != ranking.length - 1) const Divider(height: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Text('친구 목록', style: AppTypography.labelLarge),
              const Spacer(),
              Text('${friends.length}명', style: AppTypography.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          ...friends.map(
            (f) => AppCard(
              padding: const EdgeInsets.all(AppSpacing.paddingMD),
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.gray200,
                    child: Icon(Icons.person, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.nickname, style: AppTypography.bodyLarge),
                        const SizedBox(height: 4),
                        Text(
                          '추천으로 ${_comma(f.rewardWon)}원 혜택',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary100,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      '+${_comma(f.rewardWon)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          AppButton(
            text: '친구 추가',
            isFullWidth: true,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _InviteSheet(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.rank, required this.name, required this.won});

  final int rank;
  final String name;
  final int won;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(color: AppColors.border),
          ),
          child: Text('$rank', style: AppTypography.labelSmall),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: AppTypography.bodyMedium)),
        Text('+${_comma(won)}', style: AppTypography.bodyMedium),
      ],
    );
  }
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet();

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final ok = ref
        .read(friendsControllerProvider.notifier)
        .addFriendByInviteCode(_controller.text);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구가 추가되었습니다')),
      );
      return;
    }
    setState(() {
      _error = '초대코드를 확인해주세요';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.paddingMD,
        right: AppSpacing.paddingMD,
        top: AppSpacing.paddingMD,
        bottom: bottom + AppSpacing.paddingMD,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('친구 추가', style: AppTypography.h4),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: '초대코드 입력',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          AppButton(text: '확인', isFullWidth: true, onPressed: _submit),
          const SizedBox(height: 8),
          AppButton(
            text: '닫기',
            variant: ButtonVariant.text,
            isFullWidth: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
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

