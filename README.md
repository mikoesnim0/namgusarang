# 남구이야기 (Namgu Story)

**걸으며 쿠폰을 얻고 사용해요** 🚶‍♀️💚

부산 남구 지역 기반 쿠폰 & 미션 앱

---

## 📱 프로젝트 정보

- **앱 이름**: 남구이야기 (Namgu Story)
- **패키지명**: `com.doyakmin.hangookji.namgu`
- **타겟**: 30~40대 여성, 부산시 남구
- **출시 목표**: 2026년 2월 20일
- **기술 스택**: Flutter + Firebase
- **Repository**: https://github.com/mikoesnim0/namgusarang

## 🎯 핵심 기능

1. **쿠폰 시스템**: 할인/무료 쿠폰 발급 및 4자리 코드로 매장 사용
2. **미션 시스템**: 걸음수, 장소 방문, 친구 초대 등 미션 완료 시 쿠폰 자동 발급
3. **지도**: 주변 가맹점 표시 및 검색
4. **알림**: 쿠폰 발급/만료, 미션 완료 등 푸시 알림
5. **인증**: 이메일/비밀번호, 카카오 로그인

## 🛠️ 기술 스택

### Frontend
- **Framework**: Flutter 3.x (Dart)
- **UI**: Material 3 Design
- **상태관리**: Riverpod
- **네비게이션**: GoRouter

### Backend
- **Firebase Project**: `hankookji-namgu`
- **Auth**: Firebase Authentication
- **Database**: Cloud Firestore (Native mode)
- **Storage**: Firebase Storage
- **Push**: Firebase Cloud Messaging
- **Functions**: Cloud Functions (asia-northeast3)

### 지도
- Kakao Map 또는 Naver Map API

## 📁 프로젝트 구조

```
hangookji_namgu/
├── lib/
│   ├── main.dart                 # 앱 진입점
│   ├── theme/                    # 디자인 시스템
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   ├── app_spacing.dart
│   │   └── app_theme.dart
│   ├── widgets/                  # 공통 컴포넌트
│   │   ├── app_button.dart
│   │   ├── app_input.dart
│   │   ├── app_card.dart
│   │   └── app_loading.dart
│   ├── screens/                  # 화면
│   │   └── auth/
│   │       ├── splash_screen.dart
│   │       ├── login_screen.dart
│   │       └── signup_screen.dart
│   ├── services/                 # 서비스 레이어
│   ├── models/                   # 데이터 모델
│   ├── providers/                # Riverpod 프로바이더
│   └── utils/                    # 유틸리티
├── documents/                    # 📚 프로젝트 문서
│   ├── prd/                      # 제품 요구사항 명세서
│   ├── tech-spec/                # 기술 명세서
│   ├── data-model/               # 데이터 모델 스키마
│   └── planning/                 # 개발 일정 및 로그
├── .cursor/                      # 🤖 Cursor AI 설정
│   └── rules/                    # AI 코딩 가이드
├── android/                      # Android 설정
└── ios/                          # iOS 설정
```

## 📚 문서

프로젝트의 모든 상세 문서는 `documents/` 폴더에 있습니다:

### 필수 문서
1. **[PRD (제품 요구사항)](documents/prd/남구이야기_PRD_v1.0.md)**
   - 핵심 기능/범위 요약
   - MVP 범위 정의

2. **[기술명세서](documents/tech-spec/기술명세서_v1.0.md)**
   - Flutter/Firebase 기준 기술 스택
   - 인증/데이터 구조 요약

3. **[데이터 모델](documents/data-model/firestore-schema.md)**
   - Firestore 컬렉션 구조
   - 필드 타입 및 설명

4. **[개발 일정](documents/planning/)**
   - 프로젝트_추진계획서_v1.0.md
   - 추진일정_W1-W6.md
   - 달력형_일정표_v1.0_revised.md
   - 개발일정표_v1.0.md
   - 상세일정표_Gantt_v1.0.md
   - 상세작업일정표_Task_Based.md
   - Day1-2_완료보고서.md
   - 작업로그.md

### Cursor AI 가이드
- **[프로젝트 개요](.cursor/rules/project-overview.md)**: 프로젝트 전체 구조와 컨벤션
- **[Flutter 컨벤션](.cursor/rules/flutter-conventions.md)**: 코딩 스타일 가이드

## 🚀 시작하기

### 1. 환경 설정

**필수 요구사항:**
- Flutter SDK 3.x 이상
- Dart SDK 3.x 이상
- Android Studio (Android 개발)
- Xcode (iOS 개발, macOS만)

### 2. 설치

```bash
# 저장소 클론
git clone https://github.com/mikoesnim0/namgusarang.git
cd hangookji_namgu

# 의존성 설치
flutter pub get

# Firebase 설정 확인
# android/app/google-services.json 파일이 있는지 확인
```

### 3. 실행

```bash
# Chrome (빠른 UI 테스트)
flutter run -d chrome

# Android 실기기/에뮬레이터
flutter devices  # 연결된 기기 확인
flutter run -d <device_id>

# iOS 시뮬레이터 (macOS only)
flutter run -d ios
```

### 4. 빌드

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (macOS only)
flutter build ios --release
```

---

## 📦 Android / iOS 스토어 배포(실전 체크리스트)

### 현재 repo에서 확인된 포인트(중요)
- **Android applicationId**: `com.doyakmin.hangookji.namgu` (`android/app/build.gradle.kts`)
- **iOS Bundle ID**: `com.doyakmin.hangookji.namgu` (`ios/Runner.xcodeproj/project.pbxproj`)
- **Android 릴리즈 서명**: `android/key.properties`가 있으면 릴리즈 키로 서명, 없으면 디버그 키로 fallback

### 0) 공통: 버전 올리기
- `pubspec.yaml`의 `version: 1.0.0+1`에서
  - **1.0.1+2** 처럼 `+` 뒤 build number는 매 업로드마다 증가

### 1) Android (Google Play)

#### (A) 업로드 키 생성 (최초 1회)
```bash
cd namgusarang/android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

#### (B) `android/key.properties` 만들기 (로컬만)
- `android/key.properties.example`를 복사해서 실제 값으로 채우기
- `key.properties`/`*.jks`는 `.gitignore`됨

#### (C) AAB 빌드
```bash
cd namgusarang
fvm flutter build appbundle --release
```
출력: `build/app/outputs/bundle/release/app-release.aab`

### 2) iOS (App Store Connect)

#### (A) Xcode에서 Signing 설정 (최초 1회)
- `ios/Runner.xcworkspace` 열기
- Runner Target > **Signing & Capabilities**
  - Team 선택 (Apple Developer 계정)
  - Bundle Identifier: `com.doyakmin.hankookji.namgu`

#### (B) IPA 빌드
```bash
cd namgusarang
fvm flutter build ipa --release
```
업로드: Xcode Organizer(Archive/Distribute) 또는 Transporter 사용

---

## 🔥 Firebase 실데이터 연결: 추천 전개 순서

### 1) iOS Firebase 옵션부터 정상화(필수)
현재 `lib/firebase_options.dart`의 iOS `appId`가 placeholder라서,
**Firebase 콘솔에 iOS 앱을 등록한 뒤 FlutterFire CLI로 재생성**하는 게 안전합니다.

권장:
```bash
cd namgusarang
flutterfire configure
```

### 2) Auth 먼저(이메일/비번)
- 회원가입 성공 → `/users/{uid}` 생성
- 로그인 성공 → `/users/{uid}.lastLogin` 업데이트

### 3) Firestore Repository로 더미를 “치환”
- 예: 쿠폰/미션/친구/프로필의 더미 모델을
  - `FirestoreCouponsRepository`
  - `FirestoreMissionsRepository`
  - `FirestoreUsersRepository`
  형태로 만들고 Riverpod `AsyncNotifier`로 연결

### 4) 쿠폰 사용/발급/미션완료는 Functions 권장
문서(`documents/data-model/firestore-schema.md`)에도 써있듯이,
status 전환/검증은 클라이언트가 아니라 **Cloud Functions 트랜잭션**으로 처리하는 게 치팅 방지에 좋습니다.

---

## 🟡 카카오 로그인 + Firebase Auth 연결

이 프로젝트에서 카카오 로그인은 Firebase 기본 OAuth provider로 바로 붙기 어렵기 때문에,
**Callable Functions로 Kakao access token을 검증 → Firebase Custom Token을 발급**하는 패턴을 사용합니다.

- 문서: `documents/tech-spec/firebase-kakao-auth.md`
- Flutter 설정:
  - `--dart-define=KAKAO_NATIVE_APP_KEY=...`
  - Android: `android/local.properties`에 `kakao.native_app_key=...`
  - iOS: `ios/Flutter/Local.xcconfig` 생성 후 `KAKAO_NATIVE_APP_KEY=...`

### Firebase Functions 배포(가장 빠른 방법: npm + firebase-tools)

```bash
cd namgusarang
npm i -g firebase-tools
firebase login
firebase use hankookji-namgu
cd functions
npm i
npm run deploy
```

배포 후 앱에서 카카오 로그인 버튼을 누르면,
Callable `authWithKakao`가 실행되고 Firebase Custom Token으로 로그인됩니다.

---

## 🔵 Google / 🍎 Apple 로그인

Google/Apple은 **Firebase Authentication의 기본 OAuth Provider**를 사용합니다.  
로그인 성공 후에는 앱에서 공통 로직으로 `users/{uid}` 문서를 upsert 해서 유저 정보를 통합 관리합니다.

### 1) Firebase Console 설정
- Firebase Console → **Authentication → 로그인 방법**
  - **Google** 활성화
  - **Apple** 활성화

### 2) iOS 설정

#### (A) Google 로그인 (URL scheme)
- `flutterfire configure`로 `ios/Runner/GoogleService-Info.plist`가 최신인지 확인
- `ios/Runner/Info.plist`의 `CFBundleURLTypes`에 **Google URL scheme** 추가 필요
  - `GoogleService-Info.plist` 안의 `REVERSED_CLIENT_ID` 값을 URL scheme으로 넣습니다.

#### (B) Apple 로그인 (Capability)
- Xcode에서 `ios/Runner.xcworkspace` 열기
- Runner Target → **Signing & Capabilities**
  - **Sign In with Apple** capability 추가

> Apple Provider가 동작하려면 Apple Developer 설정(Team ID / Key / Services ID 등)이 필요할 수 있습니다.
> iOS-only 플로우로 시작하고, 필요 시 웹 플로우(Services ID)로 확장하는 걸 추천합니다.

### 3) Android 설정 (Google)
- Firebase Android App 설정에 **SHA-1 / SHA-256** 지문 추가(디버그/릴리즈 모두)
- `google-services.json`이 현재 `applicationId`와 일치하는지 확인(변경했으면 재다운로드/재생성)

### 4) 앱 코드 반영
- 로그인 화면에 **Google / Apple 버튼**이 추가되어 있습니다.
- 성공 시 `users.upsertOnAuth(...)` + `users.updateProfile(nickname/photoUrl)`로 Firestore 프로필을 동기화합니다.

---

## 🍎 macOS에서 Firebase 로그인까지 동작시키기

현재 앱은 macOS에서도 `Firebase.initializeApp()`을 시도하지만,
**macOS 프로젝트에 Firebase 설정(plist)이 없으면 로그인 기능이 동작하지 않습니다.**

### 1) `flutterfire configure`로 macOS 설정 동기화(권장)

Firebase 콘솔 UI에서 macOS 앱 추가가 명확히 안 보이는 경우가 있어,
가장 확실한 방법은 FlutterFire CLI로 **macOS 앱 등록/설정 파일 생성**을 자동화하는 것입니다.

```bash
cd namgusarang
flutterfire configure
```

### 2) `GoogleService-Info.plist` 확인
- `flutterfire configure`가 완료되면 `macos/Runner/GoogleService-Info.plist`가 생성/갱신되어야 합니다.

### 3) 실행
```bash
cd namgusarang
fvm flutter run -d macos
```

## 🎨 디자인 시스템

### 색상 팔레트
```dart
import 'package:hangookji_namgu/theme/app_colors.dart';

AppColors.primary500    // 메인 그린
AppColors.secondary500  // 세컨더리 틸
AppColors.accent500     // 액센트 오렌지
AppColors.success       // 성공 (그린)
AppColors.error         // 에러 (레드)
AppColors.warning       // 경고 (오렌지)
AppColors.info          // 정보 (블루)
```

### 타이포그래피
```dart
import 'package:hangookji_namgu/theme/app_typography.dart';

AppTypography.heading1   // 24px Bold
AppTypography.heading2   // 20px Bold
AppTypography.bodyLarge  // 16px Regular
AppTypography.bodyMedium // 14px Regular
AppTypography.caption    // 12px Regular
```

### 간격
```dart
import 'package:hangookji_namgu/theme/app_spacing.dart';

AppSpacing.paddingXS   // 4px
AppSpacing.paddingS    // 8px
AppSpacing.paddingM    // 16px
AppSpacing.paddingL    // 24px
AppSpacing.paddingXL   // 32px
AppSpacing.paddingXXL  // 48px
```

### 공통 컴포넌트
```dart
import 'package:hangookji_namgu/widgets/widgets.dart';

AppButton(
  text: '로그인',
  onPressed: () {},
  variant: ButtonVariant.primary,
  size: ButtonSize.large,
)

AppInput(
  label: '이메일',
  placeholder: 'example@email.com',
  onChanged: (value) {},
)

AppCard(
  variant: CardVariant.elevated,
  child: Text('내용'),
)

AppLoading()  // 전체 화면 로딩
AppLoading.inline()  // 인라인 로딩
```

## 📝 코딩 컨벤션

### 파일 & 클래스 명명
```dart
// 파일명: snake_case.dart
user_profile_screen.dart
auth_service.dart

// 클래스명: PascalCase
class UserProfileScreen {}
class AuthService {}

// 변수/함수: camelCase
final String userName = 'John';
void fetchUserData() {}
```

### 커밋 메시지
```bash
feat: 새로운 기능 추가
fix: 버그 수정
docs: 문서 수정
style: 코드 포맷팅
refactor: 코드 리팩토링
test: 테스트 추가/수정
chore: 빌드/설정 변경
```

**예시:**
```bash
git commit -m "feat: Splash 화면 구현"
git commit -m "fix: 로그인 버튼 클릭 오류 수정"
git commit -m "docs: README에 설치 가이드 추가"
```

## 🧪 테스트

```bash
# 단위 테스트
flutter test

# 통합 테스트
flutter test integration_test

# 테스트 커버리지
flutter test --coverage
```

## 🐛 문제 해결

### Android 빌드 실패
```bash
# Gradle 캐시 클리어
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Firebase 연결 오류
1. `android/app/google-services.json` 파일 확인
2. 패키지명이 `com.doyakmin.hangookji.namgu`인지 확인
3. Firebase Console에서 SHA-1 지문 등록 (Release 빌드 시)

### 네트워크 타임아웃
- VPN 끄기
- DNS를 8.8.8.8 (Google DNS)로 변경
- Gradle 재시도: `cd android && ./gradlew build --refresh-dependencies`

## 🤖 Cursor AI로 개발하기

이 프로젝트는 **Cursor AI가 쉽게 이해할 수 있도록 구조화**되었습니다.

### AI가 참고할 문서
1. `.cursor/rules/project-overview.md` - 프로젝트 전체 개요
2. `.cursor/rules/flutter-conventions.md` - 코딩 컨벤션
3. `documents/prd/` - 제품 요구사항
4. `documents/planning/작업로그.md` - 개발 히스토리

### AI에게 요청하기
```
"Splash 화면에 앱 버전 표시 추가해줘"
"Firebase Auth로 이메일 로그인 구현해줘"
"쿠폰 리스트 화면 만들어줘 (AppCard 사용)"
```

## 📞 연락처

- **Repository**: https://github.com/mikoesnim0/namgusarang
- **Firebase Console**: https://console.firebase.google.com/project/hankookji-namgu

## 📄 라이센스

Private Project - All Rights Reserved

---

**개발 진행 상황**: Week 1 - Day 1-2 완료 ✅  
**마지막 업데이트**: 2024-12-27

💚 **남구이야기와 함께 걸으며 즐거운 하루 되세요!** 💚
