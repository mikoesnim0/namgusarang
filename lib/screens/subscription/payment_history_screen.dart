import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/subscription/payment_history_model.dart';
import '../../features/subscription/payment_history_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(paymentHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2FBF9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('결제 내역'),
        leading: const BackButton(),
      ),
      body: historyAsync.when(
        data: (events) => events.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(paymentHistoryProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) =>
                      _PaymentEventCard(event: events[index]),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '결제 내역을 불러올 수 없습니다.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: AppColors.gray300),
          const SizedBox(height: 16),
          Text(
            '결제 내역이 없습니다',
            style: AppTypography.bodyLarge
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PaymentEventCard extends StatelessWidget {
  const _PaymentEventCard({required this.event});

  final PaymentHistoryEvent event;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy.MM.dd').format(event.createdAt);
    final isRefund = event.type == PaymentEventType.subscriptionRevoked ||
        event.type == PaymentEventType.voidedPurchase;
    final amountStr = event.amount == 0
        ? '무료'
        : '${isRefund ? '-' : ''}${_comma(event.amount)}원';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _EventTypeIcon(type: event.type),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.type.label,
                  style: AppTypography.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                if (event.orderId != null && event.orderId!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: event.orderId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('주문번호가 복사되었습니다'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Text(
                      '주문번호: ${_truncateOrderId(event.orderId!)}',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textHint),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            amountStr,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: isRefund ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  static String _comma(int n) {
    return NumberFormat('#,###').format(n);
  }

  static String _truncateOrderId(String id) {
    if (id.length <= 16) return id;
    return '${id.substring(0, 12)}...';
  }
}

class _EventTypeIcon extends StatelessWidget {
  const _EventTypeIcon({required this.type});

  final PaymentEventType type;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (type) {
      PaymentEventType.subscriptionNew => (Icons.add_circle_outline, AppColors.brandTeal),
      PaymentEventType.subscriptionRenewed => (Icons.refresh, AppColors.brandTeal),
      PaymentEventType.subscriptionCanceled => (Icons.cancel_outlined, AppColors.textSecondary),
      PaymentEventType.subscriptionExpired => (Icons.timer_off_outlined, AppColors.textSecondary),
      PaymentEventType.subscriptionRecovered => (Icons.restore, AppColors.brandTeal),
      PaymentEventType.subscriptionOnHold => (Icons.pause_circle_outline, Colors.orange),
      PaymentEventType.subscriptionGracePeriod => (Icons.hourglass_bottom, Colors.orange),
      PaymentEventType.subscriptionRevoked => (Icons.remove_circle_outline, AppColors.error),
      PaymentEventType.referralGrant => (Icons.card_giftcard, AppColors.brandTeal),
      PaymentEventType.voidedPurchase => (Icons.block, AppColors.error),
      PaymentEventType.unknown => (Icons.help_outline, AppColors.textHint),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
