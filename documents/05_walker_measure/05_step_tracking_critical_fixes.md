# 걸음수 측정 긴급 수정 요청서 (CTO용)

**작성일**: 2026-02-17
**우선순위**: 🔴 긴급 (프로덕션 배포 전 필수 수정)
**예상 소요**: 3-4일

---

## 📌 요약

현재 구현된 걸음수 측정 기능에서 **3가지 치명적 결함**이 발견되었습니다.
정상적인 사용 환경에서는 작동하나, **다음 상황에서 부정확한 값을 표시**합니다:

1. **iOS**: 자정 넘어갈 때 어제+오늘 걸음수가 합산됨
2. **Android**: 폰 재부팅 직후 1-2초간 잘못된 값 표시
3. **공통**: 백그라운드 장시간 유지 후 값 갱신 안 됨

모든 문제는 **실사용 환경에서 재현 가능**하며, 조기 수정이 필요합니다.

---

## 🔴 Issue #1: iOS 자정 넘김 시 걸음수 합산 (Critical)

### 재현 시나리오

```
[시나리오 A] - 사용자가 앱을 계속 켜두는 경우

1. 2월 17일 23:50 - iOS에서 앱 실행, Walker 화면 진입
2. 23:50~23:59 - 100보 걸음 → 화면에 "100보" 표시 ✅
3. 자정 경과 (00:00)
4. 2월 18일 00:00~09:00 - 추가로 3,000보 걸음
5. 화면 확인: "3,100보" 표시 ❌

예상값: 3,000보
실제값: 3,100보 (어제 100 + 오늘 3,000)
```

### 기술적 원인

**파일**: [ios/Runner/StepsStreamHandler.swift:14-15](../../../ios/Runner/StepsStreamHandler.swift#L14-L15)

```swift
let startOfDay = Calendar.current.startOfDay(for: Date())
pedometer.startUpdates(from: startOfDay) { data, error in
```

- `startOfDay`를 스트림 시작 시점에 **단 한 번만** 계산
- 자정이 지나도 기준 시점이 갱신되지 않음
- CMPedometer는 계속 어제 00:00부터 누적 집계

### 해결 방안

**Option 1: 자정 감지 타이머** (권장)
```swift
// 매일 자정에 스트림 재시작
let now = Date()
let tomorrow = Calendar.current.startOfDay(for: now.addingTimeInterval(86400))
let timeUntilMidnight = tomorrow.timeIntervalSince(now)

Timer.scheduledTimer(withTimeInterval: timeUntilMidnight, repeats: false) { _ in
  self.restartPedometerStream()
}
```

**Option 2: 날짜 비교 방식**
```swift
// 매 업데이트마다 날짜 체크 (성능 오버헤드 있음)
pedometer.startUpdates(from: startOfDay) { data, error in
  let currentDay = Calendar.current.startOfDay(for: Date())
  if currentDay != self.streamStartDay {
    self.restartPedometerStream()
    return
  }
  // ...
}
```

### 작업 내용

1. `StepsStreamHandler.swift` 수정
   - 자정 감지 타이머 추가
   - 날짜 변경 시 스트림 재시작 로직 구현
2. 테스트 케이스 작성
   - 시뮬레이터 시간 변경으로 자정 넘김 재현
   - 23:50 시작 → 00:10 검증

### 우선순위: 🔴 P0 (긴급)

**이유**:
- 야간 운동하는 사용자에게 치명적
- 매일 자정마다 발생하는 확정적 버그
- 사용자 신뢰도 직접 영향

**예상 소요**: 1일

---

## 🟡 Issue #2: Android 재부팅 후 잘못된 캐시 표시 (High)

### 재현 시나리오

```
[시나리오 B] - 사용자가 폰을 재부팅하는 경우

1. 2월 17일 오전 - 5,000보 걸음
2. 오후 - 폰 재부팅 (TYPE_STEP_COUNTER 센서가 0으로 리셋됨)
3. 앱 실행 → getTodaySteps() 호출
4. 캐시에서 5,000 읽음 → "5,000보" 표시 ❌ (1-2초간)
5. 센서 이벤트 발생 → ensureBaseline에서 리셋 감지 → "0보"로 수정 ✅

문제: 초기 로딩 시 1-2초간 부정확한 값
```

### 기술적 원인

**파일**: [android/app/src/main/kotlin/.../StepsApi.kt:145-149](../../../android/app/src/main/kotlin/com/doyakmin/hangookji/namgu/StepsApi.kt#L145-L149)

```kotlin
val prefCached = readCachedTodaySteps()
if (prefCached != null) {
  result.success(prefCached)  // ❌ 재부팅 체크 없이 즉시 리턴
  return
}
```

- 캐시 읽을 때 센서 리셋 여부를 확인하지 않음
- `ensureBaseline`의 리셋 감지 로직(`totalCounter + 1 < storedBaseline`)을 사용하지 않음

### 해결 방안

**캐시 검증 강화**:
```kotlin
private fun readCachedTodaySteps(): Int? {
  val date = prefs.getString(KEY_LAST_TODAY_DATE, null) ?: return null
  if (date != todayKey()) return null

  // 재부팅 감지: 현재 센서 값이 baseline보다 작으면 캐시 무효화
  val storedBaseline = prefs.getFloat(KEY_BASELINE_TOTAL, -1f)
  if (storedBaseline > 0) {
    val currentCounter = getCurrentSensorValue() ?: return null
    if (currentCounter + 1 < storedBaseline) {
      return 0  // 재부팅으로 인한 리셋 감지
    }
  }

  val steps = prefs.getInt(KEY_LAST_TODAY_STEPS, 0)
  return if (steps < 0) 0 else steps
}

private fun getCurrentSensorValue(): Float? {
  // SensorManager.getSensorList로 현재 값 조회 (동기)
  // 또는 null 리턴하여 센서 이벤트 대기
}
```

**동일 수정 필요**:
- [StepsForegroundService.kt:177-180](../../../android/app/src/main/kotlin/com/doyakmin/hangookji/namgu/StepsForegroundService.kt#L177-L180)

### 작업 내용

1. `StepsApi.kt` 수정
   - `readCachedTodaySteps()`에 재부팅 감지 로직 추가
   - 또는 센서 값 조회 실패 시 캐시 무효화
2. `StepsForegroundService.kt` 동일 수정
3. 테스트
   - `adb shell reboot` 후 즉시 앱 실행
   - 초기 표시값 검증

### 우선순위: 🟡 P1 (높음)

**이유**:
- 발생 빈도 낮음 (사용자가 폰 재부팅하는 경우만)
- 1-2초 후 자동 수정됨 (UX 영향 제한적)
- 하지만 Foreground Service 알림에 부정확한 값 표시는 문제

**예상 소요**: 0.5일

---

## 🟡 Issue #3: Flutter monotonic 보정의 역효과 (Medium)

### 재현 시나리오

```
[시나리오 C] - 백그라운드에서 재부팅되는 경우

1. Android Foreground Service 실행 중 (백그라운드 측정 ON)
2. 3,000보 걸음 → 앱 메모리에 lastEmitted=3000 저장
3. 사용자가 앱을 백그라운드에 둔 채로 폰 재부팅
4. 앱 프로세스는 종료되지 않고 살아남음 (드물지만 가능)
5. 센서 리셋으로 0 전달 → monotonic 보정: max(0, 3000) = 3000 ❌
6. 계속 "3,000보" 표시 (실제로는 0)

발생 확률: 낮음 (백그라운드 프로세스 생존 시에만)
```

### 기술적 원인

**파일**: [lib/features/steps/steps_provider.dart:84](../../../lib/features/steps/steps_provider.dart#L84)

```dart
void emit() {
  final candidate = (latestSensor > latestHc) ? latestSensor : latestHc;
  final next = (candidate > lastEmitted) ? candidate : lastEmitted;  // ❌ 무조건 증가만 허용
  if (next == lastEmitted) return;
  lastEmitted = next;
  controller.add(next);
}
```

- 걸음수가 감소하는 것을 방지하기 위한 로직
- 하지만 정상적인 리셋(자정, 재부팅)도 막아버림

### 해결 방안

**날짜 기반 리셋 허용**:
```dart
final todayStepsProvider = StreamProvider.autoDispose<int>((ref) {
  var latestSensor = 0;
  var latestHc = 0;
  var lastEmitted = 0;
  var lastEmittedDate = DateTime.now();  // 추가

  void emit() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(
      lastEmittedDate.year,
      lastEmittedDate.month,
      lastEmittedDate.day,
    );

    // 날짜가 바뀌면 리셋
    if (today != lastDate) {
      lastEmitted = 0;
      lastEmittedDate = now;
    }

    final candidate = (latestSensor > latestHc) ? latestSensor : latestHc;

    // 큰 폭 감소는 리셋으로 간주 (재부팅 등)
    if (candidate + 1000 < lastEmitted) {
      lastEmitted = 0;
    }

    final next = (candidate > lastEmitted) ? candidate : lastEmitted;
    if (next == lastEmitted) return;
    lastEmitted = next;
    lastEmittedDate = now;
    controller.add(next);
  }
  // ...
});
```

### 작업 내용

1. `steps_provider.dart` 수정
   - 날짜 변경 감지 로직 추가
   - 큰 폭 감소 시 리셋 허용
2. 테스트
   - 시스템 시간 변경으로 자정 넘김 재현
   - 백그라운드 상태 유지 검증

### 우선순위: 🟢 P2 (중간)

**이유**:
- 발생 확률 매우 낮음 (autoDispose로 대부분 해결됨)
- 앱 재시작으로 우회 가능
- 하지만 완전성을 위해 수정 권장

**예상 소요**: 0.5일

---

## 🔧 추가 개선 사항 (Optional)

### Issue #4: 코드 중복 제거

**현황**:
- `StepsApi.kt`와 `StepsForegroundService.kt`에 동일한 baseline 로직 중복
- 200+ 줄의 중복 코드

**리스크**:
- 한쪽만 수정 시 동기화 문제 발생 가능

**해결**:
```kotlin
// 신규 파일: StepsPreferences.kt
class StepsPreferences(context: Context) {
  private val prefs = context.getSharedPreferences("steps_prefs", MODE_PRIVATE)

  fun calcTodaySteps(totalCounter: Float): Int { /* ... */ }
  fun ensureBaseline(totalCounter: Float): Float { /* ... */ }
  fun readCachedTodaySteps(): Int? { /* ... */ }
  // ...
}

// 사용
class StepsApi {
  private val stepsPrefs = StepsPreferences(activity)

  override fun onSensorChanged(event: SensorEvent) {
    val today = stepsPrefs.calcTodaySteps(event.values.first())
    // ...
  }
}
```

**우선순위**: 🟢 P3
**예상 소요**: 1일

---

### Issue #5: 에러 메시지 개선

**현황**:
- 백그라운드 측정 실패 시 `false`만 리턴
- 사용자는 실패 이유를 알 수 없음

**해결**:
```kotlin
sealed class BackgroundStepsResult {
  object Success : BackgroundStepsResult()
  object SensorNotSupported : BackgroundStepsResult()
  object ActivityPermissionDenied : BackgroundStepsResult()
  object NotificationPermissionDenied : BackgroundStepsResult()
  data class Error(val message: String) : BackgroundStepsResult()
}

// Flutter에서 처리
final result = await stepsRepo.startBackgroundSteps();
switch (result) {
  case 'notification_denied':
    showDialog('알림 권한이 필요합니다');
  // ...
}
```

**우선순위**: 🟢 P3
**예상 소요**: 1일

---

## 📅 제안 일정

### Phase 1: 긴급 수정 (3일)
- Day 1: Issue #1 iOS 자정 처리 수정 + 테스트
- Day 2: Issue #2 Android 재부팅 캐시 수정 + 테스트
- Day 3: Issue #3 Flutter monotonic 수정 + 통합 테스트

### Phase 2: 품질 개선 (2일, Optional)
- Day 4: 코드 중복 제거 (Issue #4)
- Day 5: 에러 메시지 개선 (Issue #5)

---

## ✅ 검증 체크리스트

각 수정 후 다음 시나리오를 필수로 테스트해야 합니다:

### iOS 테스트
```bash
# 시뮬레이터 시간 변경
Settings → General → Date & Time → Set Manually
→ 23:55로 설정 → 앱 실행 → 5분 대기 → 00:05 확인

✅ 자정 넘어가면 걸음수 0으로 리셋
✅ 어제 걸음수가 합산되지 않음
```

### Android 테스트
```bash
# 재부팅 시뮬레이션
adb shell reboot
→ 부팅 완료 후 즉시 앱 실행

✅ 초기 로딩 시 0 표시 (이전 캐시 값 X)
✅ Foreground Service 알림도 0 표시
```

### 공통 테스트
```bash
# 백그라운드 장시간 유지
1. 백그라운드 측정 ON
2. 앱 백그라운드 전환
3. 6시간 방치
4. 다시 앱 진입

✅ 실제 걸음수와 일치
✅ 비정상적인 증가/감소 없음
```

---

## 🎯 핵심 메시지

> **현재 구현은 70% 완성도입니다.**
> 정상 사용 환경에서는 작동하지만, **엣지 케이스에서 신뢰성 문제**가 있습니다.
>
> 특히 **iOS 자정 처리는 프로덕션 배포 전 필수 수정**이며,
> 나머지 이슈들도 **사용자 경험 품질을 위해 조기 해결이 필요**합니다.

**추정 총 작업량**: 3-5일
**권장 배포 시점**: Phase 1 완료 후

---

## 📎 참고 자료

- 인수인계 문서: [04_step_tracking_handover.md](./04_step_tracking_handover.md)
- 관련 파일:
  - iOS: [StepsStreamHandler.swift](../../../ios/Runner/StepsStreamHandler.swift)
  - Android: [StepsApi.kt](../../../android/app/src/main/kotlin/com/doyakmin/hangookji/namgu/StepsApi.kt)
  - Flutter: [steps_provider.dart](../../../lib/features/steps/steps_provider.dart)

---

**문의**: 각 이슈의 기술적 세부사항은 코드 주석 및 재현 시나리오를 참고해주세요.
