# 2026-02-20 작업 재개 프롬프트

아래 내용을 새 세션에서 붙여넣기하면 됩니다.

---

## 프롬프트

Walker홀릭 앱 (Flutter + Firebase) 개발을 이어서 진행합니다.

### 오늘 완료된 작업

1. **구독 시스템 아키텍처 배포 완료**
   - Firestore Rules: 구독 필드 클라이언트 변경 차단 (affectedKeys 기반)
   - Cloud Functions 배포: `activateSubscription` (Google Play API 서버 검증), `handlePlayBillingEvent` (RTDN Pub/Sub 핸들러), `reconcileVoidedPurchases` (일일 환불 정리), `applyReferralOnSignup` (초대코드 + payment_history 기록)
   - Flutter 클라이언트: entitlements 서브컬렉션 듀얼소스 읽기, payment_history 화면 구현 완료

2. **Google Cloud / Play Console 수동 설정 완료**
   - Google Play Android Developer API 활성화 (GCP)
   - 서비스 계정 `hankookji-namgu@appspot.gserviceaccount.com` Play Console 권한 부여 (재무 데이터 보기 + 주문 및 구독 관리)
   - Pub/Sub 토픽 `play-billing-events` 생성
   - Play Console RTDN 토픽 연결 완료
   - `firebase deploy --only firestore:rules` 완료
   - `firebase deploy --only functions` 완료

3. **App Store Connect 설정 진행 중**
   - Apple Developer 계정 가입 완료, 앱 생성 완료, Bundle ID 등록 완료
   - 연령 등급: 9+ 설정 완료
   - App Privacy: 데이터 수집 10개 항목 설정 + Publish 완료
   - Pricing: Free, 175개국 전체 공개 설정 완료

### 다음에 할 작업 (순서대로)

1. **Google/Apple 구독 연구 결과 확인** — `documents/planning/` 에 연구 결과 파일 확인
2. **iOS 빌드 테스트** — `flutter build ios` 실행, 에러 해결
3. **TestFlight 업로드** — Xcode에서 Archive → App Store Connect 업로드
4. **App Store 등록정보 작성** — Description, Keywords, Screenshots (알파채널 제거 필요), Subtitle
5. **iOS Subscriptions 상품 등록** — App Store Connect에서 구독 그룹 + 상품 생성
6. **App Review 정보 입력** — 테스트 계정, 심사 노트 (templates: `documents/planning/appstore_review_notes_template.md`)

### 주요 파일 위치
- 프로젝트: `/Users/mikoesnim/Projects/Doyak/11_namgu/namgusarang/`
- 계획 문서: `documents/planning/nested-popping-rose.md` (전체 아키텍처 계획)
- App Store 트래커: `documents/planning/appstore_connect_tracker.md`
- 작업 로그: `documents/planning/작업로그.md`
- Cloud Functions: `functions/src/index.ts`
- Firestore Rules: `firestore.rules`
- 구독 모델: `lib/features/subscription/subscription_model.dart`
- 구독 프로바이더: `lib/features/subscription/subscription_provider.dart`
- 결제 내역 화면: `lib/screens/subscription/payment_history_screen.dart`
- 스크린샷: `assets/screenshots/` (5인치 6장 + 6인치 6장)
- 앱 아이콘: `assets/icons/Walkerholic_icon.png` (1024x1024)

### 주의사항
- 스크린샷/아이콘 알파채널 에러: App Store는 투명도 있는 PNG 거부 → 알파채널 제거 필요
- 서비스 계정 권한 반영까지 최대 24시간 걸릴 수 있음
- Apple Sign In이 iOS에서 구현되어 있는지 확인 필요 (App Store 심사 필수)
- HealthKit entitlement가 Xcode에서 활성화되어 있는지 확인 필요

### 참고 URL
- Firebase Console: https://console.firebase.google.com/project/hankookji-namgu/overview
- Google Play Console: Walker홀릭 (com.doyakmin.hangookji.namgu)
- 개인정보 처리방침: https://doyakmin.com/news/privacy-policy
- 이용약관: https://doyakmin.com/news/terms-of-service
- 계정 삭제: https://doyakmin.com/delete-account
