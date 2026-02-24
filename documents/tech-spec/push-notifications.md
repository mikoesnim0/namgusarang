# 푸시 알림(FCM) 설정/테스트/배포 가이드 (Walker홀릭)

## 목표
- 앱 내 “알림” 토글(미션/쿠폰/이벤트)에 따라 **토픽 구독**이 자동으로 변경된다.
  - `push_mission`
  - `push_coupon`
  - `push_event`
- 쿠폰이 발급되면(사용자 쿠폰 문서 생성) **해당 사용자에게만** 푸시가 자동 발송된다(Cloud Functions).
- iOS는 APNs 키(.p8) 연결 전까지 실기기 푸시가 도착하지 않을 수 있다.

---

## 1) 앱(Flutter) 구현 요약

### 1.1 토글 → 토픽 구독/해지
- 화면: `lib/screens/settings/notification_settings_screen.dart`
- 서비스: `lib/features/notifications/push_notifications_service.dart`

동작:
- 토글 ON → `subscribeToTopic(...)`
- 토글 OFF → `unsubscribeFromTopic(...)`

주의:
- Android 13+ / iOS는 OS 알림 권한이 필요하므로, 토글 변경 시 권한 요청이 뜰 수 있다.

### 1.2 최초 1회 권한 팝업(앱 내 설명)
- 화면: `lib/screens/home/home_screen.dart`
- “알림을 켤까요?” 다이얼로그는 **기기+유저 기준 1회만** 노출된다.
- 사용자가 “허용”을 누르면 OS 권한 요청 + 토픽 동기화가 수행된다.

### 1.3 토큰 저장(사용자 단위)
- 위치: `users/{uid}/fcm_tokens/{token}`
- 앱에서 토큰을 best-effort로 저장한다(권한/룰에 의해 실패할 수 있음).

### 1.4 (선택) 서버가 “동의한 항목”을 알 수 있게 저장
- 앱은 best-effort로 `users/{uid}.notificationPrefs`를 업데이트한다.
  - `notificationPrefs.mission`
  - `notificationPrefs.coupon`
  - `notificationPrefs.eventBenefit`
  - `notificationPrefs.updatedAt`

서버(Functions)는 이 값을 읽어서 쿠폰 알림 발송 여부를 판단한다(없으면 기본 발송).

---

## 2) Firebase 콘솔에서 토픽 푸시 보내기(테스트)

1. Firebase 콘솔 → 프로젝트 선택
2. 왼쪽 메뉴 → **Messaging(Cloud Messaging)** → **새 캠페인/새 메시지**
3. 알림 제목/텍스트 입력
4. **타겟(Target)** 단계에서 “Topic/주제/토픽” 선택
5. 토픽 이름 입력
   - 예: `push_event`
6. “지금 보내기”로 발송

Android에서 잘 오면 성공.

---

## 3) 쿠폰 발급 시 자동 푸시(Cloud Functions)

### 3.1 트리거
- 경로: `users/{uid}/coupons/{couponId}` 문서가 **생성(onCreate)** 될 때

파일:
- `functions/src/index.ts` → `export const onUserCouponIssued = ...`

동작:
1. 사용자 알림 설정(가능하면 `users/{uid}.notificationPrefs.coupon`) 확인
2. `users/{uid}/fcm_tokens`에서 토큰 목록 조회
3. 해당 토큰들에게 “쿠폰이 발급됐어요” 푸시 멀티캐스트 발송
4. invalid token은 best-effort로 삭제

### 3.2 배포
로컬에서:
```bash
cd namgusarang/functions
npm run build
cd ..
firebase deploy --only functions
```

로그 확인:
```bash
cd namgusarang
firebase functions:log
```

---

## 4) iOS(APNs) 관련 (나중에 진행)
iOS는 Firebase만으로는 푸시가 도착하지 않으며, APNs `.p8` 키를 Firebase에 업로드해야 한다.

필수 작업:
- Apple Developer에서 APNs Auth Key(.p8) 생성
- Firebase Console → Project settings → Cloud Messaging → APNs key 업로드
- Xcode에서 Push Notifications, Background Modes(Remote notifications) 활성화

---

## 5) 체크리스트(운영/출시)
- Android 13+ 알림 권한: `android.permission.POST_NOTIFICATIONS` 포함
- “알림을 켤까요?” 팝업: 1회만 노출되는지 확인
- 토글 OFF 시 토픽이 해지되는지 확인
- 쿠폰 발급 시 본인에게만 푸시가 오는지 확인(토큰 저장 필요)

