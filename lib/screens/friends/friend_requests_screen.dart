import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/friends/friends_model.dart';
import '../../features/friends/friends_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(friendRequestsControllerProvider);
    final sent = state.sent;
    final received = state.received;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.gray50,
        appBar: AppBar(
          title: const Text('친구 수락 대기'),
          bottom: TabBar(
            indicatorColor: AppColors.primary500,
            labelStyle: AppTypography.labelLarge,
            unselectedLabelStyle: AppTypography.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            tabs: [
              Tab(text: '받은 요청 (${received.length})'),
              Tab(text: '보낸 요청 (${sent.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ReceivedList(items: received),
            _SentList(items: sent),
          ],
        ),
      ),
    );
  }
}

class _ReceivedList extends ConsumerWidget {
  const _ReceivedList({required this.items});

  final List<FriendRequest> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const _EmptyState(
        title: '받은 친구 요청이 없습니다',
        subtitle: '친구가 요청을 보내면 이곳에 표시됩니다.',
      );
    }

    final controller = ref.read(friendRequestsControllerProvider.notifier);

    return ListView.separated(
      padding: AppTheme.screenPadding.copyWith(bottom: 120),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final r = items[idx];
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RequestHeader(
                nickname: r.nickname,
                subtitle: '${_timeAgo(r.requestedAt)} · 받은 요청',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: '거절',
                      size: ButtonSize.small,
                      variant: ButtonVariant.outline,
                      onPressed: () => controller.declineReceived(r.id),
                      isFullWidth: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      text: '수락',
                      size: ButtonSize.small,
                      variant: ButtonVariant.primary,
                      onPressed: () => controller.acceptReceived(r.id),
                      isFullWidth: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SentList extends ConsumerWidget {
  const _SentList({required this.items});

  final List<FriendRequest> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const _EmptyState(
        title: '보낸 친구 요청이 없습니다',
        subtitle: '초대 링크를 공유하거나 친구를 추가해보세요.',
      );
    }

    final controller = ref.read(friendRequestsControllerProvider.notifier);

    return ListView.separated(
      padding: AppTheme.screenPadding.copyWith(bottom: 120),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final r = items[idx];
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RequestHeader(
                nickname: r.nickname,
                subtitle: '${_timeAgo(r.requestedAt)} · 보낸 요청',
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '대기중',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                text: '요청 취소',
                size: ButtonSize.small,
                variant: ButtonVariant.outline,
                onPressed: () => controller.cancelSent(r.id),
                isFullWidth: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RequestHeader extends StatelessWidget {
  const _RequestHeader({
    required this.nickname,
    required this.subtitle,
    this.trailing,
  });

  final String nickname;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              Text(nickname, style: AppTypography.bodyLarge),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppTheme.screenPadding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppTypography.labelLarge),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  return '${diff.inDays}일 전';
}
