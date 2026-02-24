import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';

class SubscriptionTermsScreen extends StatelessWidget {
  const SubscriptionTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프리미엄 구독 이용약관'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Walker홀릭 프리미엄 구독 이용약관',
                style: AppTypography.h4.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '시행일: 2026년 2월 16일',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 28),
            _article(
              '제1조 (목적)',
              '본 약관은 주식회사 도약민(이하 "회사")이 제공하는 Walker홀릭 프리미엄 구독 서비스(이하 "본 서비스")의 이용에 관련하여 회사와 회원 간의 권리, 의무, 책임사항 및 기타 필요한 사항을 규정함을 목적으로 합니다.',
            ),
            _article('제2조 (정의)', null, items: const [
              '"회원"이란 Walker홀릭 앱에 가입하고 본 서비스에 동의한 자를 말합니다.',
              '"프리미엄 구독"이란 월 정기결제를 통해 추가 미션 회차 및 상향된 쿠폰 혜택을 제공받는 유료 멤버십 서비스를 의미합니다.',
              '"정기결제"란 회원이 선택한 결제수단을 통해 일정 주기마다 자동으로 이용요금이 결제되는 방식을 의미합니다.',
              '"구독 기간"이란 최초 결제 승인일을 기준으로 1개월(앱 마켓 정책 기준) 동안 본 서비스 이용이 가능한 기간을 의미합니다.',
              '"쿠폰"이란 특정 상점에서 할인 혜택을 제공받을 수 있는 전자적 권리를 의미합니다.',
              '"제휴 상점"이란 회사와 별도 계약을 통해 쿠폰 사용이 가능하도록 한 사업자를 의미합니다.',
            ]),
            _article('제3조 (약관의 효력 및 변경)', null, items: const [
              '본 약관은 회원이 구독 신청 시 동의함으로써 효력이 발생합니다.',
              '회사는 관련 법령에 위배되지 않는 범위에서 본 약관을 개정할 수 있습니다.',
              '약관 변경 시 적용일 7일 전(회원에게 불리한 변경은 30일 전) 앱 내 공지합니다.',
              '회원이 변경 약관에 동의하지 않는 경우 구독을 해지할 수 있습니다.',
            ]),
            _article('제4조 (구독의 성립)', null, items: const [
              '구독은 앱 마켓 결제 승인 완료 시 성립합니다.',
              '회원은 구독 신청 전 본 약관 및 결제 내용을 확인해야 합니다.',
              '미성년자의 구독은 법정대리인의 동의가 필요합니다.',
            ]),
            _article('제5조 (구독 혜택)', null, items: const [
              '프리미엄 구독 회원에게는 다음 혜택이 제공됩니다:\n  a) 10일 미션 완료 시 쿠폰 금액 3배 상향 (500원 → 1,500원)\n  b) 매달 최대 3회차 미션 참여 가능\n  c) 구독 기간 동안 혜택 자동 적용',
              '혜택 내용은 회사 정책에 따라 변경될 수 있으며, 변경 시 사전 공지합니다.',
            ]),
            _article('제6조 (결제 및 갱신)', null, items: const [
              '구독료는 월 990원(결제일 기준)이며, 앱 마켓을 통해 결제됩니다.',
              '구독은 해지하지 않는 한 매월 자동 갱신됩니다.',
              '결제 실패 시 앱 마켓 정책에 따라 재시도되며, 최종 실패 시 구독이 해지됩니다.',
            ]),
            _article('제7조 (구독 해지 및 환불)', null, items: const [
              '회원은 언제든지 앱 마켓을 통해 구독을 해지할 수 있습니다.',
              '해지 시 현재 구독 기간 종료일까지 서비스를 이용할 수 있습니다.',
              '환불은 각 앱 마켓의 환불 정책에 따릅니다.',
              '구독 기간 중 발급된 쿠폰은 쿠폰의 유효기간까지 사용 가능합니다.',
            ]),
            _article('제8조 (서비스 중단)', null, items: const [
              '회사는 다음 경우 서비스를 일시 중단할 수 있습니다:\n  a) 시스템 점검 및 유지보수\n  b) 천재지변 등 불가항력\n  c) 기타 회사가 서비스 제공이 어렵다고 판단하는 경우',
              '서비스 중단 시 가능한 한 사전 공지하며, 중단 기간에 대한 보상은 별도 정합니다.',
            ]),
            _article('제9조 (개인정보 보호)', null, items: const [
              '회사는 회원의 개인정보를 관련 법령에 따라 보호합니다.',
              '결제 정보는 앱 마켓에서 관리하며, 회사는 결제 카드 정보 등을 직접 저장하지 않습니다.',
              '자세한 내용은 개인정보처리방침을 참조하시기 바랍니다.',
            ]),
            _article('제10조 (면책)', null, items: const [
              '제휴 상점의 서비스 품질 및 쿠폰 사용 관련 분쟁은 해당 상점과 회원 간 해결을 원칙으로 합니다.',
              '회사는 천재지변 등 불가항력으로 인한 서비스 중단에 대해 책임을 지지 않습니다.',
            ]),
            _article(
              '제11조 (분쟁 해결)',
              '본 약관과 관련된 분쟁은 대한민국 법률에 따르며, 관할 법원은 회사 소재지 관할 법원으로 합니다.',
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '부칙\n본 약관은 2026년 2월 16일부터 시행합니다.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _article(String title, String? body, {List<String>? items}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (body != null)
            Text(
              body,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.7,
              ),
            ),
          if (items != null)
            ...items.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${e.key + 1}.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
