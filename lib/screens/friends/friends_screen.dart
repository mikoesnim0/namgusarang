import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/friends/friends_model.dart';
import '../../features/friends/friends_provider.dart';
import '../../features/friends/friends_repository.dart';
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
  final _friendSearchController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  String _friendQuery = '';
  _AddMode _addMode = _AddMode.nickname;

  @override
  void dispose() {
    _controller.dispose();
    _friendSearchController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  String _friendlyFunctionsError(Object e) {
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'not-found':
          return '사용자를 찾을 수 없습니다.';
        case 'already-exists':
          return '이미 친구이거나 요청이 진행중입니다.';
        case 'invalid-argument':
          return '입력값을 확인해주세요.';
        case 'unauthenticated':
          return '로그인이 필요합니다.';
        default:
          return '오류가 발생했습니다. (${e.code})';
      }
    }
    return '오류가 발생했습니다.';
  }

  Future<void> _submitAdd() async {
    final repo = ref.read(friendsRepositoryProvider);
    try {
      await repo.ensurePublicProfile();
      if (_addMode == _AddMode.nickname) {
        final nickname = _controller.text.trim();
        await repo.sendRequestByNickname(nickname);
        _controller.clear();
        ref.read(friendUserSearchQueryProvider.notifier).state = '';
      } else {
        final code = _inviteCodeController.text.trim();
        await repo.sendRequestByInviteCode(code);
        _inviteCodeController.clear();
      }

      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('친구 요청을 보냈습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyFunctionsError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsStreamProvider);
    final incomingCount = ref.watch(incomingFriendRequestsCountProvider);
    final inviteInfo = ref.watch(inviteInfoProvider);
    final authUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final searchAsync = ref.watch(publicUserSearchProvider);

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
                        child: Icon(
                          Icons.person,
                          color: AppColors.textSecondary,
                        ),
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
              const Align(alignment: Alignment.center, child: Text('친구목록')),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/friends/requests'),
                  child: Text(
                    incomingCount > 0 ? '대기 $incomingCount' : '대기',
                    style: AppTypography.bodySmall.copyWith(
                      color: incomingCount > 0
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
      body: friendsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.paddingMD),
            child: Text('친구 로드 실패: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (friends) {
          final visibleFriends = _friendQuery.trim().isEmpty
              ? friends
              : friends
                    .where(
                      (f) => f.nickname.toLowerCase().contains(
                        _friendQuery.toLowerCase(),
                      ),
                    )
                    .toList();

          return ListView.separated(
            padding: AppTheme.screenPadding.copyWith(bottom: 120),
            itemCount: visibleFriends.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              if (idx == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InviteCard(info: inviteInfo),
                    const SizedBox(height: 12),
                    _AddFriendCard(
                      mode: _addMode,
                      nicknameController: _controller,
                      inviteCodeController: _inviteCodeController,
                      onModeChanged: (m) => setState(() => _addMode = m),
                      onSubmit: _submitAdd,
                      searchAsync: searchAsync,
                      currentUid: authUid,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMD,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _friendSearchController,
                              decoration: InputDecoration(
                                hintText: '친구 검색',
                                hintStyle: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textHint,
                                ),
                                border: InputBorder.none,
                              ),
                              onChanged: (v) =>
                                  setState(() => _friendQuery = v.trim()),
                            ),
                          ),
                          if (_friendQuery.trim().isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _friendSearchController.clear();
                                setState(() => _friendQuery = '');
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Spacer(),
                        Text(
                          '${visibleFriends.length}명',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              final friend = visibleFriends[idx - 1];
              return _FriendCard(friend: friend);
            },
          );
        },
      ),
    );
  }
}

enum _AddMode { nickname, inviteCode }

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.info});

  final InviteInfo info;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('초대코드', style: AppTypography.labelLarge),
                const SizedBox(height: 6),
                Text(
                  info.code.isEmpty ? '생성중...' : info.code,
                  style: AppTypography.h4,
                ),
                const SizedBox(height: 6),
                Text(
                  '친구가 앱에서 초대코드를 입력하면 요청을 보낼 수 있어요.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: info.code.isEmpty
                ? null
                : () => Share.share(info.shareText),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('공유'),
          ),
        ],
      ),
    );
  }
}

class _AddFriendCard extends StatelessWidget {
  const _AddFriendCard({
    required this.mode,
    required this.nicknameController,
    required this.inviteCodeController,
    required this.onModeChanged,
    required this.onSubmit,
    required this.searchAsync,
    required this.currentUid,
  });

  final _AddMode mode;
  final TextEditingController nicknameController;
  final TextEditingController inviteCodeController;
  final ValueChanged<_AddMode> onModeChanged;
  final VoidCallback onSubmit;
  final AsyncValue<List<PublicUser>> searchAsync;
  final String? currentUid;

  @override
  Widget build(BuildContext context) {
    // NOTE: This widget needs Provider access for the search query provider.
    // It is wrapped as a Consumer below.
    return Consumer(builder: (context, ref, _) => _build(context, ref));
  }

  Widget _build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: '닉네임',
                  selected: mode == _AddMode.nickname,
                  onTap: () => onModeChanged(_AddMode.nickname),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeChip(
                  label: '초대코드',
                  selected: mode == _AddMode.inviteCode,
                  onTap: () => onModeChanged(_AddMode.inviteCode),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (mode == _AddMode.nickname)
            _InputRow(
              controller: nicknameController,
              hintText: '닉네임으로 친구 요청',
              onSubmit: onSubmit,
              onChanged: (v) {
                ref.read(friendUserSearchQueryProvider.notifier).state = v;
              },
            )
          else
            _InputRow(
              controller: inviteCodeController,
              hintText: '초대코드(6자리)로 친구 요청',
              onSubmit: onSubmit,
            ),
          if (mode == _AddMode.nickname)
            _SearchSuggestions(
              searchAsync: searchAsync,
              currentUid: currentUid,
            ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary100 : AppColors.gray100,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: selected ? AppColors.primary900 : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.hintText,
    required this.onSubmit,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSubmit;
  final ValueChanged<String>? onChanged;

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
                hintText: hintText,
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onSubmitted: (_) => onSubmit(),
              onChanged: onChanged,
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
                  child: Icon(Icons.send, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSuggestions extends ConsumerWidget {
  const _SearchSuggestions({
    required this.searchAsync,
    required this.currentUid,
  });

  final AsyncValue<List<PublicUser>> searchAsync;
  final String? currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return searchAsync.when(
      loading: () => const SizedBox(height: 0),
      error: (_, __) => const SizedBox(height: 0),
      data: (items) {
        final q = ref.watch(friendUserSearchQueryProvider).trim();
        if (q.isEmpty) return const SizedBox(height: 0);
        final filtered = items.where((u) => u.uid != currentUid).toList();
        if (filtered.isEmpty) return const SizedBox(height: 0);

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '검색 결과',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ...filtered
                  .take(6)
                  .map(
                    (u) => AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.paddingMD,
                        vertical: AppSpacing.paddingSM,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      onTap: () async {
                        final repo = ref.read(friendsRepositoryProvider);
                        try {
                          await repo.ensurePublicProfile();
                          await repo.sendRequestByUid(u.uid);
                          ref
                                  .read(friendUserSearchQueryProvider.notifier)
                                  .state =
                              '';
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${u.nickname}님에게 요청을 보냈습니다.'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('요청 실패: $e')),
                            );
                          }
                        }
                      },
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.gray200,
                            child: Icon(
                              Icons.person,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              u.nickname,
                              style: AppTypography.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '요청',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary700,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
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
          const SizedBox(width: 8),
          Text(
            '친구',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
