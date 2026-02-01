import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

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
  final _inviteCodeController = TextEditingController();
  final _nicknameFocusNode = FocusNode();
  final _nicknameLayerLink = LayerLink();
  final _nicknameBoxKey = GlobalKey();

  _AddMode _addMode = _AddMode.nickname;
  Timer? _searchDebounce;
  OverlayEntry? _searchOverlay;

  Set<String> _existingFriendUids = const {};
  Set<String> _outgoingRequestUids = const {};
  Set<String> _incomingRequestUids = const {};

  @override
  void initState() {
    super.initState();
    _nicknameFocusNode.addListener(_onNicknameFocusChanged);
  }

  void _onNicknameFocusChanged() {
    if (!_nicknameFocusNode.hasFocus) {
      _removeSearchOverlay();
    } else {
      _scheduleOverlayUpdate();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _inviteCodeController.dispose();
    _searchDebounce?.cancel();
    _removeSearchOverlay();
    _nicknameFocusNode.removeListener(_onNicknameFocusChanged);
    _nicknameFocusNode.dispose();
    super.dispose();
  }

  void _removeSearchOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  void _scheduleOverlayUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateSearchOverlay();
    });
  }

  void _updateSearchOverlay() {
    if (_addMode != _AddMode.nickname) {
      _removeSearchOverlay();
      return;
    }
    if (!_nicknameFocusNode.hasFocus) {
      _removeSearchOverlay();
      return;
    }

    final query = ref.read(friendUserSearchQueryProvider).trim();
    if (query.isEmpty) {
      _removeSearchOverlay();
      return;
    }

    final boxContext = _nicknameBoxKey.currentContext;
    final renderBox = boxContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final searchAsync = ref.read(publicUserSearchProvider);
    final items = searchAsync.valueOrNull ?? const <PublicUser>[];
    final authUid = ref.read(authStateProvider).valueOrNull?.uid;
    final filtered = items.where((u) => u.uid != authUid).toList();

    final shouldShow = searchAsync.isLoading || filtered.isNotEmpty;
    if (!shouldShow) {
      _removeSearchOverlay();
      return;
    }

    final width = renderBox.size.width;

    _searchOverlay ??= OverlayEntry(
      builder: (overlayContext) {
        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusScope.of(overlayContext).unfocus(),
                ),
              ),
              CompositedTransformFollower(
                link: _nicknameLayerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 48),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: width,
                      maxWidth: width,
                      maxHeight: 360,
                    ),
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMD,
                          ),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _FriendSearchDropdown(
                          searchAsync: searchAsync,
                          authUid: authUid,
                          existingFriendUids: _existingFriendUids,
                          outgoingRequestUids: _outgoingRequestUids,
                          incomingRequestUids: _incomingRequestUids,
                          onRequest: (u) async {
                            final repo = ref.read(friendsRepositoryProvider);
                            await repo.ensurePublicProfile();
                            await repo.sendRequestByUid(u.uid);
                            ref
                                    .read(
                                      friendUserSearchQueryProvider.notifier,
                                    )
                                    .state =
                                '';
                            _controller.clear();
                            _removeSearchOverlay();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${u.nickname}님에게 요청을 보냈습니다.'),
                              ),
                            );
                          },
                          onOpenRequests: () {
                            _removeSearchOverlay();
                            context.push('/friends/requests');
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    final overlay = Overlay.of(context);
    if (overlay != null && !_searchOverlay!.mounted) {
      overlay.insert(_searchOverlay!);
    } else {
      _searchOverlay!.markNeedsBuild();
    }
  }

  void _onNicknameSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(friendUserSearchQueryProvider.notifier).state = v;
      _scheduleOverlayUpdate();
    });
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
    ref.listen<AsyncValue<List<PublicUser>>>(publicUserSearchProvider, (_, __) {
      _scheduleOverlayUpdate();
    });

    final friendsAsync = ref.watch(friendsStreamProvider);
    final incomingCount = ref.watch(incomingFriendRequestsCountProvider);
    final inviteInfo = ref.watch(inviteInfoProvider);
    final authUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final outgoingReqs =
        ref.watch(outgoingFriendRequestsStreamProvider).valueOrNull ?? const [];
    final incomingReqs =
        ref.watch(incomingFriendRequestsStreamProvider).valueOrNull ?? const [];

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
          return ListView.separated(
            padding: AppTheme.screenPadding.copyWith(bottom: 120),
            itemCount: friends.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              if (idx == 0) {
                _existingFriendUids = friends.map((f) => f.friendUid).toSet();
                _outgoingRequestUids = outgoingReqs.map((r) => r.toUid).toSet();
                _incomingRequestUids = incomingReqs
                    .map((r) => r.fromUid)
                    .toSet();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InviteCard(info: inviteInfo),
                    const SizedBox(height: 12),
                    _AddFriendCard(
                      mode: _addMode,
                      nicknameController: _controller,
                      inviteCodeController: _inviteCodeController,
                      onModeChanged: (m) {
                        setState(() => _addMode = m);
                        if (m != _AddMode.nickname) {
                          _removeSearchOverlay();
                        } else {
                          _scheduleOverlayUpdate();
                        }
                      },
                      onSubmit: _submitAdd,
                      onNicknameChanged: _onNicknameSearchChanged,
                      nicknameFocusNode: _nicknameFocusNode,
                      nicknameLayerLink: _nicknameLayerLink,
                      nicknameBoxKey: _nicknameBoxKey,
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
    required this.onNicknameChanged,
    required this.nicknameFocusNode,
    required this.nicknameLayerLink,
    required this.nicknameBoxKey,
  });

  final _AddMode mode;
  final TextEditingController nicknameController;
  final TextEditingController inviteCodeController;
  final ValueChanged<_AddMode> onModeChanged;
  final VoidCallback onSubmit;
  final ValueChanged<String> onNicknameChanged;
  final FocusNode nicknameFocusNode;
  final LayerLink nicknameLayerLink;
  final Key nicknameBoxKey;

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
            _NicknameSearchRow(
              key: nicknameBoxKey,
              controller: nicknameController,
              focusNode: nicknameFocusNode,
              layerLink: nicknameLayerLink,
              hintText: '닉네임 검색',
              onChanged: onNicknameChanged,
              onSubmitted: (_) => onSubmit(),
            )
          else
            _InputRow(
              controller: inviteCodeController,
              hintText: '초대코드(6자리)로 친구 요청',
              onSubmit: onSubmit,
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
    super.key,
    required this.controller,
    this.focusNode,
    this.layerLink,
    required this.hintText,
    required this.onSubmit,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final LayerLink? layerLink;
  final String hintText;
  final VoidCallback onSubmit;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final row = Container(
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
              focusNode: focusNode,
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

    final link = layerLink;
    if (link == null) return row;
    return CompositedTransformTarget(link: link, child: row);
  }
}

class _NicknameSearchRow extends StatelessWidget {
  const _NicknameSearchRow({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.layerLink,
    required this.hintText,
    required this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final LayerLink layerLink;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
                border: InputBorder.none,
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.trim().isEmpty) {
                return const SizedBox(width: 36);
              }
              return IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                  FocusScope.of(context).requestFocus(focusNode);
                },
              );
            },
          ),
        ],
      ),
    );

    return CompositedTransformTarget(link: layerLink, child: row);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.uid,
    required this.existingFriendUids,
    required this.outgoingRequestUids,
    required this.incomingRequestUids,
  });

  final String uid;
  final Set<String> existingFriendUids;
  final Set<String> outgoingRequestUids;
  final Set<String> incomingRequestUids;

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color fg;

    if (existingFriendUids.contains(uid)) {
      label = '친구';
      bg = AppColors.gray100;
      fg = AppColors.textSecondary;
    } else if (outgoingRequestUids.contains(uid)) {
      label = '요청됨';
      bg = AppColors.gray100;
      fg = AppColors.textSecondary;
    } else if (incomingRequestUids.contains(uid)) {
      label = '받은요청';
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
    } else {
      label = '요청';
      bg = AppColors.primary100;
      fg = AppColors.primary700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FriendSearchDropdown extends StatelessWidget {
  const _FriendSearchDropdown({
    required this.searchAsync,
    required this.authUid,
    required this.existingFriendUids,
    required this.outgoingRequestUids,
    required this.incomingRequestUids,
    required this.onRequest,
    required this.onOpenRequests,
  });

  final AsyncValue<List<PublicUser>> searchAsync;
  final String? authUid;
  final Set<String> existingFriendUids;
  final Set<String> outgoingRequestUids;
  final Set<String> incomingRequestUids;
  final Future<void> Function(PublicUser u) onRequest;
  final VoidCallback onOpenRequests;

  static const _profileColors = <Color>[
    Color(0xFFB3E5FC),
    Color(0xFFC8E6C9),
    Color(0xFFFFF9C4),
    Color(0xFFFFCCBC),
    Color(0xFFD1C4E9),
    Color(0xFFFFE0B2),
  ];

  Color _colorForProfile(int? idx) {
    if (idx == null) return AppColors.gray200;
    return _profileColors[idx.abs() % _profileColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final items = searchAsync.valueOrNull ?? const <PublicUser>[];
    final filtered = items
        .where((u) => authUid == null || u.uid != authUid)
        .toList();
    final results = filtered.take(20).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (searchAsync.isLoading)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: results.length,
            itemBuilder: (context, i) {
              final u = results[i];

              final isFriend = existingFriendUids.contains(u.uid);
              final isOutgoing = outgoingRequestUids.contains(u.uid);
              final isIncoming = incomingRequestUids.contains(u.uid);
              final enabled = !(isFriend || isOutgoing);

              final onTap = !enabled
                  ? null
                  : isIncoming
                  ? onOpenRequests
                  : () => onRequest(u);

              return Opacity(
                opacity: enabled ? 1 : 0.55,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.paddingMD,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: _colorForProfile(u.profileIndex),
                          backgroundImage:
                              (u.photoUrl != null &&
                                  u.photoUrl!.trim().isNotEmpty)
                              ? NetworkImage(u.photoUrl!)
                              : null,
                          child:
                              (u.photoUrl == null || u.photoUrl!.trim().isEmpty)
                              ? const Icon(
                                  Icons.person,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  u.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (u.level != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.gray100,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusFull,
                                    ),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    'Lv.${u.level}',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusChip(
                          uid: u.uid,
                          existingFriendUids: existingFriendUids,
                          outgoingRequestUids: outgoingRequestUids,
                          incomingRequestUids: incomingRequestUids,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
