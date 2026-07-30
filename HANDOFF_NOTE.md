# Walker홀릭 앱 (namgusarang) — 인수인계 노트

작성일: 2026-07-27

> **상세 인수인계 문서는 Admin 레포에 있습니다** → `doyakmininc/walkerholic-admin` 의 `HANDOFF.md`
> 이 노트는 앱 레포의 **현재 상태와 주의사항만** 짧게 적은 것입니다.

---

## ⚠️ 브랜치 상태 — 먼저 확인할 것

브랜치가 정리되지 않은 상태로 인계됩니다. **`main`이 최신이 아닙니다.**

| 브랜치 | 최종 작업일 | 상태 |
|---|---|---|
| `ui/subscription-refinement` | 2026-07-27 | ✅ **최신. 실제 작업 브랜치** |
| `main` | 2026-02-24 | ⚠️ 뒤처짐 (`ui/subscription-refinement`의 조상) |
| `feature/email-verify-banner` | 2026-01-17 | 미병합 (`feat(ui): show email verification banner` 1커밋) |

**작업을 이어받을 때는 `ui/subscription-refinement`에서 시작하십시오.**
`main`을 최신으로 올리는 병합은 의도적으로 하지 않았습니다 — 브랜치 전략은 인수자가 정할 사항입니다.

```bash
git checkout ui/subscription-refinement
```

---

## 기본 정보

| 항목 | 값 |
|---|---|
| 프레임워크 | Flutter (FVM 사용 — `.fvmrc` 참조) |
| 패키지명 | `com.doyakmin.hangookji.namgu` |
| 버전 | `1.0.1+20` |
| Firebase | `hankookji-namgu` (asia-northeast3) — **Admin 사이트와 같은 프로젝트** |
| Cloud Functions | 19개 (TypeScript, `functions/src/index.ts`) |
| 커밋 수 | 94 |

---

## 반드시 알아야 할 것 5가지

**1. 버전 두 곳을 항상 함께 올려야 합니다**
```
pubspec.yaml       version: 1.0.1+20
lib/app_info.dart  buildNumber = 20
```
둘이 어긋나면 앱 내 버전 표시와 스토어 빌드번호가 불일치합니다.

**2. iOS 빌드는 반드시 dart-define을 거쳐야 합니다**
```bash
flutter build ios --release --no-codesign --dart-define-from-file=dart_defines.env
open ios/Runner.xcworkspace   # → Product → Archive
```
1단계를 건너뛰고 Xcode에서 바로 Archive하면 **카카오 키가 `Generated.xcconfig`에 안 들어가** 카카오 로그인 버튼이 죽습니다. 과거 App Store 심사 리젝(guideline 2.1)의 원인이었습니다.
빌드 스크립트: `scripts/build_ios.sh`

**3. iOS 걸음수는 CoreMotion입니다 (HealthKit 아님)**
HealthKit이 바이너리에 포함되면 심사에서 리젝됩니다(guideline 2.5.1). `ios/HealthStub/`에 스텁 pod을 두고 Podfile에서 심볼릭 링크를 교체하는 방식으로 제거했습니다. **이 구조를 건드리지 마십시오.**

**4. iOS 빌드에 "Google Play" 문자열이 들어가면 리젝됩니다** (guideline 2.3.10)
`Platform.isIOS` 분기를 쓰거나 "앱 스토어"처럼 중립적인 표현을 쓰십시오.

**5. 구독 관련 Firestore 필드는 클라이언트가 쓸 수 없습니다**
`firestore.rules`의 `affectedKeys()`로 차단되어 있고, `payment_history` / `entitlements` 서브컬렉션은 `allow write: if false`입니다. Cloud Functions(Admin SDK)만 씁니다. **보안 구조이니 풀지 마십시오.**

---

## 과거 App Store 리젝 이력 (전부 해결됨)

| Guideline | 문제 | 해결 |
|---|---|---|
| 2.1 | 카카오 버튼 무반응 | `--dart-define-from-file` |
| 2.3.10 | iOS 바이너리에 "Google Play" 문자열 | `Platform.isIOS` 분기 |
| 2.5.1 | HealthKit 포함 | iOS 스텁 pod + Podfile 심볼릭 링크 교체 |
| 3.1.2 | EULA 누락 | Apple 표준 EULA 링크 추가 |
| 3.1.5 | 구독 규정 미준수 | 복원 버튼, 자동갱신 문구, 법적 링크 추가 |
| 5.1.1 | 온보딩 강제 | 건너뛰기 버튼 추가 |

구독 화면에는 **복원 버튼 / 자동갱신 안내 문구 / 개인정보처리방침 링크 / EULA 링크**가 반드시 있어야 합니다. 제거하면 다시 리젝됩니다.
IAP 상품: `premium_monthly` (월 990원)

---

## 레포에 없는 것 (별도 전달 필요)

`.gitignore` 처리되어 있어 클론만으로는 빌드가 안 됩니다.

- `dart_defines.env` — 카카오 네이티브 앱 키
- `10_admin/firestore_seed/serviceAccountKey.json` — Firestore 시드 스크립트용 서비스 계정 키
- Firebase 콘솔 / App Store Connect / Play Console 접근 권한
- 심사용 테스트 계정

> 두 파일 모두 git 히스토리에 없음을 확인했습니다. 유출 이력 없으니 전달만 하면 됩니다.

---

## 참고 문서

- `README.md` — 앱 전체 설명 (14KB, 상세)
- `documents/` — 기획·설계 문서 46개
  - `planning/` — 추진계획서, 작업로그, 심사 트래커
  - `tech-spec/`, `data-model/`, `prd/`
  - `05_walker_measure/` — 걸음수 측정 (QA 가이드, 중요 수정사항)
  - `06_subscription/` — 구독
  - `07_playstore/` — 스토어 등록
- `firestore.rules` — **권한 규칙 정본.** Admin 사이트 수정 시에도 이 파일을 봐야 합니다
- `functions/src/index.ts` — Cloud Functions 19개
- `.cursor/rules/project-overview.md` — 프로젝트 개요

**한국지(Unity 게임)와의 연동 검토**: Admin 레포의 `한국지_연동_조사의뢰서.md` 참조.
