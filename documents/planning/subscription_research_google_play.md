# Google Play 구독 결제 — 종합 레퍼런스

> 연구일: 2026-02-20

---

## 1. 구매 흐름 (Purchase Flow)

사용자가 "프리미엄 구독하기" 버튼을 탭하면:

```
[1] SubscriptionPurchaseNotifier.subscribe() 호출
[2] SubscriptionRepository.loadProduct() → Google Play에서 상품 정보 로드
[3] SubscriptionRepository.buySubscription(product) → Google Play 결제 시트 표시
[4] Google Play 결제 시트 (네이티브 Android UI)
    - 상품명, 가격 (₩990/월), 결제 수단 표시
    - 사용자 인증 (지문/비밀번호)
    - "정기결제" 탭
[5] Google Play 결제 처리
[6] PurchaseDetails가 purchaseStream으로 도착
    - status: PurchaseStatus.purchased
    - purchaseID (orderId), verificationData (purchaseToken), productID
[7] _handleSuccess(purchase) → activateOnServer(purchase) 호출
[8] Cloud Function 'activateSubscription'에 전송:
    {purchaseToken, productId, orderId}
[9] 서버에서 Google Play API로 검증
[10] Firestore에 기록 (users/{uid} + entitlements + payment_history)
[11] 클라이언트의 subscriptionEntitlementProvider가 실시간 업데이트
[12] completePurchase(purchase) 호출
```

### purchaseToken이란?

- **형태**: 긴 알파뉴메릭 문자열 (base64와 유사)
- **길이**: 보통 100-200+ 글자
- **예시**: `"oghJiPlcFKFPemBBjkOgHASt.AO-J1OxEGKJfPnLBk_uH7..."`
- **지속성**: 같은 구독 계보에서 갱신 시에도 동일한 토큰 유지. 취소 후 재구독하면 새 토큰 발급
- **고유성**: 모든 앱, 모든 유저에 대해 글로벌 유일
- **내용**: 파싱 불가한 불투명 참조값. Google 서버에서 내부적으로 구매를 조회하는 데 사용

### orderId 형식

```
초기 구매:   GPA.3375-1234-5678-12345
첫 번째 갱신: GPA.3375-1234-5678-12345..0
두 번째 갱신: GPA.3375-1234-5678-12345..1
세 번째 갱신: GPA.3375-1234-5678-12345..2
```

---

## 2. 서버사이드 검증 (Server-Side Verification)

### purchases.subscriptionsv2.get 호출

```typescript
const res = await androidPublisher.purchases.subscriptionsv2.get({
  packageName: "com.doyakmin.hangookji.namgu",
  token: purchaseToken,
});
```

v1 API와 달리 v2는 `subscriptionId`가 불필요. `packageName`과 `token`만 필요.

### Google 응답 구조

```json
{
  "kind": "androidpublisher#subscriptionPurchaseV2",
  "regionCode": "KR",
  "latestOrderId": "GPA.3375-1234-5678-12345..0",
  "lineItems": [{
    "productId": "premium_monthly",
    "expiryTime": "2025-03-20T14:30:00.000Z",
    "autoRenewingPlan": { "autoRenewEnabled": true }
  }],
  "startTime": "2025-02-20T14:30:00.000Z",
  "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
  "acknowledgementState": "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"
}
```

### subscriptionState 상태값

| 상태 | 의미 | 프리미엄 유지? |
|------|------|--------------|
| `SUBSCRIPTION_STATE_ACTIVE` | 활성 구독 | Yes |
| `SUBSCRIPTION_STATE_CANCELED` | 자동갱신 OFF, 만료일까지 유효 | Yes (만료일까지) |
| `SUBSCRIPTION_STATE_IN_GRACE_PERIOD` | 결제 실패, Google 재시도 중 | Yes |
| `SUBSCRIPTION_STATE_ON_HOLD` | 유예 기간 종료, 결제 보류 | No |
| `SUBSCRIPTION_STATE_EXPIRED` | 완전 만료 | No |
| `SUBSCRIPTION_STATE_PAUSED` | 일시중지 | No |
| `SUBSCRIPTION_STATE_PENDING` | 결제 대기 중 | No |

### Acknowledge (구매 확인)

- **목적**: 서버가 구매를 처리했음을 Google에 확인
- **기한**: 구매 후 **48시간** 이내
- **미확인 시**: Google이 **자동 환불** + 구독 취소
- **중복 호출**: 안전 (이미 확인된 건은 성공 반환)

---

## 3. 영수증/인보이스 (Receipt)

### Google Play 자동 영수증 발행

- **이메일 영수증**: 구매 즉시 사용자 Google 계정 이메일로 발송
- **앱 내 알림**: Play Store 앱에서 알림 표시
- **주문 내역**: Play Store 앱 → 설정 → 결제 및 구독 → 예산 및 내역

### 사용자 영수증 확인 경로

1. Play Store 앱: 설정 → 결제 및 구독 → 예산 및 내역
2. 웹: https://play.google.com/store/account/orderhistory
3. 이메일: "Google Play 주문 확인" 검색
4. 구독 관리: Play Store → 프로필 → 결제 및 구독 → 구독

### 환불 프로세스

1. **48시간 이내**: Play Store → 계정 → 주문 내역 → 환불 요청
2. **48시간 이후**: Google Play 고객지원 문의 (1-4 영업일)
3. **개발자 환불**: Play Console → 주문 관리에서 직접 환불 가능

**환불 후**: RTDN 알림 type 12 (SUBSCRIPTION_REVOKED) 수신 → Firestore 상태 업데이트

---

## 4. RTDN (Real-Time Developer Notification)

### 알림 유형 완전 목록

| Type | 이름 | 설명 | 프리미엄 유지? |
|------|------|------|--------------|
| 1 | RECOVERED | 결제 보류에서 복구 | Yes → premium |
| 2 | RENEWED | 자동 갱신 성공 | Yes → premium |
| 3 | CANCELED | 구독 취소 (자동갱신 OFF) | Yes (만료일까지) |
| 4 | PURCHASED | 신규 구독 | Yes → premium |
| 5 | ON_HOLD | 결제 보류 | No → on_hold |
| 6 | IN_GRACE_PERIOD | 유예 기간 진입 | Yes → premium |
| 7 | RESTARTED | 취소 후 재구독 | Yes → premium |
| 8 | PRICE_CHANGE_CONFIRMED | 가격 변경 수락 | - |
| 9 | DEFERRED | 무료 기간 부여 | - |
| 10 | PAUSED | 구독 일시중지 | - |
| 11 | PAUSE_SCHEDULE_CHANGED | 일시중지 일정 변경 | - |
| 12 | REVOKED | 환불/취소 | No → free |
| 13 | EXPIRED | 구독 만료 | No → free |
| 20 | PENDING_PURCHASE_CANCELED | 대기 중 구매 취소 | - |

### Pub/Sub 메시지 구조

```json
{
  "version": "1.0",
  "packageName": "com.doyakmin.hangookji.namgu",
  "eventTimeMillis": "1708123456789",
  "subscriptionNotification": {
    "version": "1.0",
    "notificationType": 2,
    "purchaseToken": "oghJiPlcFKFP...",
    "subscriptionId": "premium_monthly"
  }
}
```

### 알림 타이밍

| 이벤트 | 발송 시점 |
|--------|----------|
| 구매 (4) | 구매 완료 후 수 초 이내 |
| 갱신 (2) | 결제일에 결제 성공 시 |
| 취소 (3) | 사용자 취소 후 수 초 이내 |
| 유예 기간 (6) | 갱신 결제 실패 시 |
| 보류 (5) | 유예 기간 만료 후 |
| 만료 (13) | 정확한 만료 시점 |
| 환불 (12) | 환불 처리 후 수 분 이내 |

**주의**: "최소 1회" + "최선의 노력으로 실시간" 전달. 중복 가능, 누락 가능 (→ reconcileVoidedPurchases가 안전망)

---

## 5. 테스트 (Testing)

### 라이선스 테스터 설정

1. Play Console → 설정 → 라이선스 테스트
2. 테스터 Google 이메일 추가
3. 테스트 계정은 실제 결제 없이 구매 가능

### 테스트 구독 갱신 시간 (가속)

| 실제 기간 | 테스트 기간 |
|----------|-----------|
| 1주 | **5분** |
| 1개월 | **5분** |
| 3개월 | 10분 |
| 6개월 | 15분 |
| 1년 | 30분 |

- 최대 **6회** 갱신 후 자동 만료
- premium_monthly (월간): 5분마다 갱신, ~30분 후 자동 만료

### 흔한 테스트 문제

1. **"Item already owned"**: 이전 테스트 구독이 남아있음 → Play Store 데이터 초기화 또는 만료 대기 (~30분)
2. **테스트 구매에는 게시된 앱 필요**: 최소 내부 테스트 트랙에 업로드 필수
3. **APK 서명**: Play Console에 등록된 키로 서명된 APK만 결제 테스트 가능
4. **국가 제한**: 상품이 테스터 국가(한국)에서 이용 가능해야 함

---

## 6. 시연 준비 (Demo Preparation)

### 사전 체크리스트

- [ ] 시연 기기의 Google 계정이 라이선스 테스터 목록에 있는지 확인
- [ ] 앱이 최소 내부 테스트 트랙에 게시되어 있는지 확인
- [ ] Cloud Functions가 배포되어 있는지 확인
- [ ] 기기에 기존 테스트 구독이 없는지 확인 (있으면 만료 대기)
- [ ] Firestore에서 해당 유저의 구독 상태가 free인지 확인
- [ ] 안정적인 네트워크 연결
- [ ] 방해금지 모드 활성화

### 시연 시 사용자에게 보이는 화면

```
[구독 관리 화면 - Free 상태]
  ↓ "프리미엄 구독하기 . 월 990원" 탭
[Google Play 결제 시트 표시] (~1초)
  - 상품명, 가격, 결제수단
  - 라이선스 테스터: "TEST" 배지 표시
  ↓ "정기결제" 탭
[처리 중 로딩] (~1-3초)
  ↓
[Cloud Function 실행] (~1-2초)
  ↓
[스낵바: "프리미엄 구독이 활성화되었습니다!"]
[화면이 Premium Active 상태로 전환]
```

**총 소요 시간**: ~3-7초 (탭 → UI 업데이트)

### 대비책

- 결제 시트 안 나옴 → Play Store 앱 캐시 삭제 후 재시도
- "Item already owned" → 30분 대기 또는 Play Store에서 구독 확인
- Cloud Function 실패 → Firebase Console 로그 확인
- 안전망: 라이브 시연 실패 대비 화면 녹화 준비
