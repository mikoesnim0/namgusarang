# 걸음 수 측정 인수인계 문서

**최초 작성**: 2026-02-16
**최종 업데이트**: 2026-02-17 (치명적 버그 발견 및 긴급 수정 계획 추가)

## 1. 목적
- 현재 앱의 걸음 수 측정 구현 상태를 다음 담당자가 바로 이어받아 운영/개선할 수 있도록 정리한다.
- 범위: 실시간 걸음 수, Health Connect 폴백, Android 백그라운드(포그라운드 서비스 + 알림) 표시.

## 2. 현재 구현 요약
- 앱 레벨 걸음 수 데이터는 `todayStepsProvider`에서 센서 값 + Health Connect 값을 병합해 사용한다.
- Android는 네이티브 `TYPE_STEP_COUNTER` 기반으로 오늘 걸음 수를 계산한다(일자별 baseline 방식).
- iOS는 `CMPedometer`로 당일 걸음 수를 조회/스트리밍한다.
- Android에서는 포그라운드 서비스(`StepsForegroundService`)를 켜면 앱이 백그라운드여도 알림에 오늘 걸음 수가 표시된다.

## 3. 주요 파일(핵심 진입점)
- Flutter 저장소/채널: `lib/features/steps/steps_repository.dart`
- 걸음수 병합 Provider: `lib/features/steps/steps_provider.dart`
- 백그라운드 토글 상태 관리: `lib/features/steps/background_steps_controller.dart`
- 워커 화면 토글 UI: `lib/screens/walker/walker_tracking_screen.dart`
- Android 채널/권한/센서 브리지: `android/app/src/main/kotlin/com/doyakmin/hangookji/namgu/StepsApi.kt`
- Android 백그라운드 서비스: `android/app/src/main/kotlin/com/doyakmin/hangookji/namgu/StepsForegroundService.kt`
- Android 권한/서비스 선언: `android/app/src/main/AndroidManifest.xml`
- iOS 채널 핸들러(백그라운드 메서드 no-op): `ios/Runner/AppDelegate.swift`

## 4. 동작 플로우
1. Flutter `todayStepsProvider`가 센서 스트림(`watchTodaySteps`)과 Health Connect 폴링을 구독.
2. 두 값 중 큰 값을 선택하고, 단조 증가(monotonic) 보정 후 UI에 반영.
3. Android에서 사용자가 `Walker 측정 모니터` 화면의 `백그라운드 측정` 스위치를 켜면:
   - MethodChannel `startBackgroundSteps` 호출
   - `StepsForegroundService` 시작
   - 상시 알림에 `오늘 걸음수: N보` 표시 및 갱신
4. 알림의 `중지` 액션 또는 앱 스위치 OFF 시 서비스 종료.

## 5. 권한/플랫폼 조건
- Android 필수:
  - `ACTIVITY_RECOGNITION`
  - `FOREGROUND_SERVICE`
  - `FOREGROUND_SERVICE_HEALTH`
  - Android 13+는 알림 권한(`POST_NOTIFICATIONS`)이 있어야 포그라운드 알림 표시 가능
- iOS:
  - 현재 백그라운드 알림형 걸음수 표시 미지원(토글 비활성/false 처리)

## 6. 검증 체크리스트
- 공통
  - `Walker 측정 모니터`에서 걸음 수가 증가하는지 확인.
  - 권한 거부/허용 시 상태가 정상 반영되는지 확인.
- Android 실기기
  - 백그라운드 측정 ON 시 상단 알림에 오늘 걸음 수가 노출되는지 확인.
  - 앱을 홈으로 보내고 실제 걸음 후 알림 숫자 갱신 확인.
  - 알림 `중지` 탭 시 서비스 종료 및 토글 상태가 OFF로 복귀하는지 확인.
  - 자정 이후 첫 걸음에서 오늘 카운트가 0부터 정상 시작하는지 확인.
- iOS 실기기
  - 걸음 수 조회/스트리밍만 정상 동작하는지 확인(백그라운드 토글은 비활성 안내 문구 확인).

## 7. 현재 알려진 한계/주의사항

### 🔴 치명적 버그 (2026-02-17 발견, 즉시 수정 필요)

**상세 분석**: [05_step_tracking_critical_fixes.md](./05_step_tracking_critical_fixes.md), [EXECUTIVE_SUMMARY.md](./EXECUTIVE_SUMMARY.md)

1. **iOS 자정 넘김 시 걸음수 합산** (긴급)
   - 증상: 23:50에 앱 켜고 자정 넘기면 어제+오늘 걸음수가 합산됨
   - 원인: `StepsStreamHandler.swift:14` - `startOfDay`를 스트림 시작 시점에만 계산
   - 영향: 100% 재현, 야간 운동 사용자에게 치명적
   - 해결: 자정 감지 타이머 추가 필요

2. **Android 재부팅 후 잘못된 캐시 표시** (높음)
   - 증상: 폰 재부팅 후 앱 실행 시 1-2초간 이전 걸음수 표시
   - 원인: `StepsApi.kt:145`, `StepsForegroundService.kt:177` - 캐시 검증 시 센서 리셋 미감지
   - 영향: 재부팅 시마다 발생, UX 저하
   - 해결: 캐시 읽을 때 센서 값 비교 추가 필요

3. **Flutter monotonic 보정의 역효과** (중간)
   - 증상: 백그라운드에서 날짜 변경 시 걸음수 리셋 안 됨
   - 원인: `steps_provider.dart:84` - 값 감소 방지 로직이 정상 리셋도 차단
   - 영향: 낮음 (autoDispose로 대부분 해결), 특정 조건에서만 발생
   - 해결: 날짜 변경 감지 시 리셋 허용 필요

### ⚠️ 기타 제약사항

- Android에서 백그라운드 시작 실패(예: 알림 권한 미허용) 시 UI에 상세 실패 사유를 노출하지 않는다.
- 개발 환경에서 Java Runtime 미설치 시 `./gradlew` Kotlin 컴파일 검증이 불가능하다.
- 워커 화면 토글은 존재하지만, 홈 화면 등 다른 위치에서는 백그라운드 상태 제어 UI가 없다.
- `StepsApi.kt`와 `StepsForegroundService.kt`에 동일한 baseline 로직이 중복됨 (리팩토링 필요)

## 8. 다음 담당자 우선 작업 (추천 순서)

### 🔴 Phase 1: 긴급 수정 (3일, 프로덕션 배포 전 필수)

**상세 가이드**: [05_step_tracking_critical_fixes.md](./05_step_tracking_critical_fixes.md)
**테스트 스크립트**: `./test_scenarios.sh` (실행 가능)

1. **iOS 자정 처리 수정** (1일)
   - `ios/Runner/StepsStreamHandler.swift` 수정
   - 자정 감지 타이머 추가
   - 테스트: 시뮬레이터 시간 23:55 설정 → 5분 대기 → 검증

2. **Android 재부팅 캐시 검증 강화** (0.5일)
   - `android/.../StepsApi.kt:145` 및 `StepsForegroundService.kt:177` 수정
   - 캐시 읽을 때 센서 리셋 감지 로직 추가
   - 테스트: `adb reboot` → 즉시 앱 실행 → 초기값 확인

3. **Flutter monotonic 보정 개선** (0.5일)
   - `lib/features/steps/steps_provider.dart:84` 수정
   - 날짜 변경 감지 시 리셋 허용
   - 테스트: 백그라운드 상태로 날짜 변경 재현

### 🟡 Phase 2: 품질 개선 (2일, Optional)

4. 코드 중복 제거 - `StepsPreferences.kt` 분리
5. Android 시작 실패 사유를 사용자에게 명확히 표시 (알림 권한 미허용, 센서 미지원 등)
6. QA 기기 매트릭스 확정 (삼성/샤오미/픽셀) 후 배터리 최적화 정책별 장시간 측정 검증
7. 자정/재부팅/앱 강제종료 시나리오 자동화 테스트 케이스 정리
8. 필요 시 홈 화면에 백그라운드 측정 상태/진입 버튼 추가

## 9. 빠른 점검 명령어
```bash
flutter analyze
```

```bash
cd android && ./gradlew :app:compileDebugKotlin
```

## 10. 인수인계 메모
- 이번 구현은 "Android에서 백그라운드 걸음 수를 실시간에 가깝게 유지/표시"를 우선 해결했다.
- iOS는 정책/플랫폼 제약으로 동일한 알림형 백그라운드 모델을 아직 적용하지 않았다.
