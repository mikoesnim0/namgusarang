# Apple App Store 구독 결제 — 종합 레퍼런스

> 연구일: 2026-02-20

---

## 1. StoreKit 2 구매 흐름

### 단계별 흐름

```
[1] 사용자가 "프리미엄 구독하기" 탭
[2] Product.purchase() 호출 (StoreKit 2)
    - Flutter에서는 in_app_purchase 플러그인이 처리
[3] Apple 결제 시트 표시 (Face ID/Touch ID 인증)
[4] Apple 서버에서 결제 처리
[5] Transaction 반환 (JWS 서명됨)
    - originalTransactionId, transactionId, expiresDate 등
[6] Cloud Function 'activateSubscriptionIOS'에 전송
[7] 서버에서 JWS 검증 후 Firestore 기록
[8] Transaction.finish() 호출 (completePurchase)
```

### Google Play와의 핵심 차이

| 항목 | Google Play | Apple |
|------|-----------|-------|
| 검증 데이터 | purchaseToken (짧은 문자열) | JWS 서명 트랜잭션 (긴 Base64) |
| 유저 식별 키 | purchaseToken | originalTransactionId |
| 서버 인증 | Service Account (ADC) | .p8 키 + JWT 생성 |
| 서버 알림 | Pub/Sub (메시지 큐) | HTTPS Webhook (직접 POST) |
| Acknowledge | 48시간 이내 필수 | Transaction.finish() 필수 |

---

## 2. 서버사이드 검증

### App Store Server API

**Base URL**:
- Production: `https://api.storekit.itunes.apple.com`
- Sandbox: `https://api.storekit-sandbox.itunes.apple.com`

### 핵심 엔드포인트

| 엔드포인트 | 용도 | Google 대응 |
|----------|------|-----------|
| `GET /inApps/v1/subscriptions/{originalTransactionId}` | 구독 상태 조회 | `subscriptionsv2.get()` |
| `GET /inApps/v1/history/{originalTransactionId}` | 트랜잭션 이력 | 없음 |
| `GET /inApps/v1/lookup/{orderId}` | 주문 ID로 조회 | 없음 |

### 인증 방법 (.p8 키 + JWT)

1. App Store Connect → Keys → In-App Purchase에서 .p8 키 생성/다운로드
2. Key ID, Issuer ID 기록
3. JWT 토큰 생성:

```typescript
const token = jwt.sign({
  iss: issuerId,
  iat: now,
  exp: now + 3600,
  aud: "appstoreconnect-v1",
  bid: bundleId,
}, privateKey, {
  algorithm: "ES256",
  keyid: keyId,
});
```

### 구독 상태 (status) 값

| status | 의미 | Google 대응 |
|--------|------|-----------|
| 1 | Active | SUBSCRIPTION_STATE_ACTIVE |
| 2 | Expired | SUBSCRIPTION_STATE_EXPIRED |
| 3 | Billing retry | (결제 재시도 중) |
| 4 | Grace period | IN_GRACE_PERIOD |
| 5 | Revoked (환불) | REVOKED |

### JWS 서명 검증

Apple이 반환하는 signedTransactionInfo는 JWS 형식:
1. JWS를 `.`으로 분리 (header.payload.signature)
2. Header에서 `x5c` (X.509 인증서 체인) 추출
3. 인증서 체인을 Apple Root CA까지 검증
4. Leaf 인증서의 공개키로 서명 검증
5. Payload를 디코딩하여 트랜잭션 데이터 획득

---

## 3. App Store Server Notifications V2

### Google RTDN vs Apple Server Notifications

```
Google Play RTDN:
  Google Play → Cloud Pub/Sub Topic → Cloud Function (pubsub 트리거)
  특징: 비동기, 재시도 자동, 순서 보장 안됨

Apple Server Notifications V2:
  Apple → HTTPS POST (webhook) → Cloud Function (http 트리거)
  특징: 동기, 200 응답 필수, 재시도 최대 5회
```

### 알림 유형 전체 목록

| notificationType | subtype | 의미 | Google RTDN 대응 |
|-----------------|---------|------|----------------|
| `SUBSCRIBED` | `INITIAL_BUY` | 최초 구독 | type 4 (PURCHASED) |
| `SUBSCRIBED` | `RESUBSCRIBE` | 재구독 | type 7 (RESTARTED) |
| `DID_RENEW` | - | 자동 갱신 성공 | type 2 (RENEWED) |
| `DID_CHANGE_RENEWAL_STATUS` | `AUTO_RENEW_DISABLED` | 자동갱신 해제 | type 3 (CANCELED) |
| `DID_CHANGE_RENEWAL_STATUS` | `AUTO_RENEW_ENABLED` | 자동갱신 재활성화 | type 7 (RESTARTED) |
| `DID_FAIL_TO_RENEW` | `GRACE_PERIOD` | 유예 기간 진입 | type 6 (IN_GRACE_PERIOD) |
| `DID_FAIL_TO_RENEW` | - | 결제 실패 | type 5 (ON_HOLD) |
| `EXPIRED` | `VOLUNTARY` | 사용자 해지 만료 | type 13 (EXPIRED) |
| `EXPIRED` | `BILLING_RETRY` | 결제 실패 만료 | type 13 (EXPIRED) |
| `EXPIRED` | `PRICE_INCREASE` | 가격 인상 미동의 만료 | type 13 (EXPIRED) |
| `REFUND` | - | 환불 | type 12 (REVOKED) |
| `REVOKE` | - | 가족 공유 해제 | type 12 (REVOKED) |
| `CONSUMPTION_REQUEST` | - | 환불 심사 중 정보 요청 | 없음 |
| `DID_CHANGE_RENEWAL_PREF` | `UPGRADE`/`DOWNGRADE` | 요금제 변경 | 없음 |
| `OFFER_REDEEMED` | - | 오퍼 적용 | 없음 |
| `TEST` | - | 테스트 알림 | 없음 |

### Webhook URL 설정

App Store Connect → My Apps → 앱 선택 → App Information → App Store Server Notifications:
- **Production Server URL**: Cloud Function HTTP URL
- **Sandbox Server URL**: 동일 또는 별도 URL
- **Version**: **Version 2 Notifications** (필수!)

---

## 4. 영수증/환불

### Apple 자동 영수증 발행

- 구매 시 Apple ID 이메일로 자동 영수증 발송
- 사용자 확인 경로: 설정 → Apple ID → 구독 / reportaproblem.apple.com

### 환불 프로세스 (Google과 가장 큰 차이!)

```
Google Play: 개발자도 Play Console에서 직접 환불 가능
Apple:       Apple만 환불 결정권 보유, 개발자 개입 불가!

사용자 → reportaproblem.apple.com에서 환불 요청
      → Apple이 승인/거절 (개발자 개입 불가)
      → REFUND 알림으로 개발자에 통보
      → (선택) CONSUMPTION_REQUEST로 사용 정보 요청
```

---

## 5. App Store Connect 구독 상품 설정

### 구독 그룹 생성

1. App Store Connect → Subscriptions 탭
2. "+" → Subscription Group 생성 (예: "프리미엄 멤버십")
3. 같은 그룹 내 구독은 상호 배타적

### 구독 상품 생성

| 항목 | 값 |
|------|---|
| Reference Name | Premium Monthly |
| **Product ID** | **`premium_monthly`** (Google Play와 동일!) |
| Duration | 1 Month |
| Price | KRW 990 |
| Display Name (한국어) | 프리미엄 구독 |
| Description (한국어) | 쿠폰 금액 3배, 미션 횟수 3배 |

**핵심**: Product ID를 Google Play와 동일하게 설정하면 Flutter 코드 수정 불필요!

### 구독 오퍼 유형

| 오퍼 | 설명 |
|------|------|
| Introductory Offer | 신규 구독자 (무료 체험, 할인가) |
| Promotional Offer | 기존/이탈 구독자 (서버 서명 필요) |
| Offer Codes | 코드 기반 할인 |
| Win-back Offer | 이탈 구독자 자동 노출 (iOS 18+) |

---

## 6. 테스트

### Sandbox 환경

1. App Store Connect → Users and Access → Sandbox → Testers
2. Sandbox Apple ID 생성 (실제 Apple ID와 별도)
3. iOS 디바이스: 설정 → App Store → SANDBOX ACCOUNT에 로그인

### Sandbox 구독 갱신 시간 (가속)

| 실제 기간 | Sandbox | 자동 갱신 |
|----------|---------|----------|
| 1주 | 3분 | 최대 6회 |
| **1개월** | **5분** | **최대 6회** |
| 3개월 | 15분 | 최대 6회 |
| 6개월 | 30분 | 최대 6회 |
| 1년 | 1시간 | 최대 6회 |

premium_monthly: Sandbox에서 **5분마다 갱신**, 최대 6회 후 자동 만료

### Xcode StoreKit Testing (로컬 테스트)

서버 없이 Xcode에서 로컬 테스트 가능:
1. File → New → StoreKit Configuration File 생성
2. 구독 상품 정의
3. Scheme → Edit Scheme → Run → StoreKit Configuration 선택
4. 시뮬레이터에서 테스트!

장점: 서버 설정 없이 테스트 가능
단점: 서버 알림 테스트 불가

### 테스트 주의사항

1. Sandbox 계정은 실제 Apple ID와 분리
2. TestFlight 빌드는 **Sandbox 환경** 사용
3. 시뮬레이터에서는 실제 인앱 구매 불가 (StoreKit Testing만 가능)
4. Sandbox 갱신 타이밍은 정확하지 않을 수 있음 (1-10분 범위)
5. `Transaction.finish()` 누락 시 같은 트랜잭션 반복 전달

---

## 7. 플랫폼 비교 요약

### 어느 플랫폼이 더 쉬운가?

| 항목 | 더 쉬운 쪽 | 이유 |
|------|----------|------|
| 서버 인증 | **Google** | ADC 자동 인증, Apple은 JWT 직접 생성 |
| 서버 알림 설정 | **Apple** | URL 하나만 입력 |
| 알림 데이터 신뢰성 | **Apple** | JWS 서명으로 위변조 불가 |
| 환불 관리 | **Google** | 직접 환불 가능 |
| 테스트 | **Apple** | Xcode StoreKit Testing |
| 클라이언트 코드 | 동일 | in_app_purchase 플러그인 추상화 |

---

## 8. iOS 구현 체크리스트

### App Store Connect 설정
- [ ] 구독 그룹 생성
- [ ] `premium_monthly` 상품 생성 (KRW 990)
- [ ] In-App Purchase API Key (.p8) 생성/다운로드
- [ ] Key ID, Issuer ID 기록
- [ ] Server Notifications V2 URL 설정

### Cloud Functions
- [ ] `jose`, `jsonwebtoken` npm 패키지 추가
- [ ] Apple JWS 검증 유틸리티 작성
- [ ] `activateSubscriptionIOS` callable function 작성
- [ ] `handleAppStoreNotification` HTTP function 작성
- [ ] .p8 키를 Secret Manager에 저장

### Flutter 클라이언트
- [ ] `activateOnServer()` 플랫폼 분기 추가 (Platform.isIOS)
- [ ] `SubscriptionSource.appStore` enum 추가
- [ ] 구독 관리 URL 분기 (Apple: `https://apps.apple.com/account/subscriptions`)

### 테스트
- [ ] Xcode StoreKit Configuration 생성 → 로컬 테스트
- [ ] Sandbox Tester 계정 생성
- [ ] Sandbox에서 구매/갱신/환불 테스트
- [ ] TestFlight E2E 테스트
