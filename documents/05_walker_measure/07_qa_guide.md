# 걸음수 측정 QA 가이드

**작성일**: 2026-02-17
**대상**: QA 엔지니어, 개발 팀 리더
**범위**: Critical + High Priority 개선사항 검증

---

## 🎯 QA 목표

모든 개선사항이 **실제로 문제를 해결했는지** 검증합니다.

---

## ✅ QA 체크리스트 요약

| # | 항목 | 우선순위 | 예상 시간 |
|---|------|----------|----------|
| 1 | 센서 메모리 누수 해결 | 🔴 Critical | 30분 |
| 2 | Firestore 동기화 로깅 | 🔴 Critical | 15분 |
| 3 | Health Connect 에러 상태 | 🔴 Critical | 20분 |
| 4 | 단위 테스트 실행 | 🟡 High | 10분 |
| 5 | Firestore Security Rules | 🟡 High | 20분 |
| 6 | 권한 프롬프트 중복 방지 | 🟡 High | 15분 |

**총 예상 시간**: 약 2시간

---

## 🔴 Critical #1: 센서 메모리 누수 해결

### ✅ 수정 내용
**파일**: `android/.../StepsApi.kt:57-75`

```kotlin
// AS-IS (버그)
override fun onCancel(arguments: Any?) {
  eventSink = null
  if (pendingGetStepsResult == null) {  // 조건부 해제
    stopSensor()
  }
}

// TO-BE (수정)
override fun onCancel(arguments: Any?) {
  eventSink = null
  stopSensor()  // 무조건 해제
  mainHandler.removeCallbacksAndMessages(null)  // 타임아웃 취소
  if (pendingGetStepsResult != null) {
    pendingGetStepsResult?.success(null)
    pendingGetStepsResult = null
  }
}
```

### 📋 테스트 시나리오

#### 시나리오 A: 화면 전환 반복 테스트

**목적**: 센서가 제대로 해제되는지 확인

**절차**:
1. Android 실기기 연결
2. 앱 실행 → Walker 화면 진입
3. 홈 버튼 눌러 백그라운드 전환
4. 앱 다시 진입 → Walker 화면
5. **2-4단계를 10회 반복**
6. 다음 명령어로 센서 리스너 확인:
   ```bash
   adb shell dumpsys sensorservice
   ```

**예상 결과**:
```
✅ PASS: Step Counter 섹션에 1개의 listener만 등록됨
❌ FAIL: Step Counter 섹션에 여러 개의 listener 등록됨 (누수)
```

**검증 포인트**:
- [ ] 화면 전환 10회 후에도 센서 리스너가 1개만 등록됨
- [ ] 앱 종료 후 센서 리스너가 0개가 됨
- [ ] 배터리 소모가 정상 수준임 (Settings → Battery → App usage)

#### 시나리오 B: 장시간 사용 테스트

**목적**: 메모리 누수가 없는지 확인

**절차**:
1. Android Studio Profiler 실행
2. Memory 탭 선택
3. Walker 화면 진입/나가기를 30회 반복
4. 각 반복 후 Heap Dump 수집
5. Analyzer에서 SensorEventListener 검색

**예상 결과**:
```
✅ PASS: SensorEventListener 인스턴스가 1개 이하 유지
❌ FAIL: SensorEventListener 인스턴스가 계속 증가
```

---

## 🔴 Critical #2: Firestore 동기화 로깅

### ✅ 수정 내용
**파일**: `lib/features/steps/steps_sync_provider.dart:69-81`

```dart
// AS-IS (버그)
catch (_) {
  // Best-effort sync only.  // 에러 무시
}

// TO-BE (수정)
catch (e) {
  debugPrint('[StepsSync] Failed to sync $steps steps for ${user.uid}: $e');
  // Best-effort sync only - will retry on next heartbeat
}
```

### 📋 테스트 시나리오

#### 시나리오 A: 네트워크 오프라인 테스트

**목적**: 동기화 실패 시 로그가 출력되는지 확인

**절차**:
1. 앱 실행 → 로그캣 확인 (필터: `StepsSync`)
   ```bash
   adb logcat | grep StepsSync
   ```
2. Walker 화면에서 걸음수 측정 시작
3. **비행기 모드 ON** (네트워크 차단)
4. 100보 정도 걸음
5. 15초 대기 (디바운스 시간)
6. 로그 확인

**예상 결과**:
```bash
✅ PASS:
D/FlutterApplication(12345): [StepsSync] Failed to sync 100 steps for user_abc123: ...
(에러 메시지 출력됨)

❌ FAIL: 로그 없음
```

**검증 포인트**:
- [ ] 로그에 `[StepsSync] Failed to sync` 메시지 출력됨
- [ ] 걸음수와 사용자 ID가 로그에 포함됨
- [ ] 에러 원인이 명시됨 (network, permission 등)

#### 시나리오 B: 정상 동기화 확인

**목적**: 정상 상황에서는 로그가 없는지 확인

**절차**:
1. 비행기 모드 OFF (네트워크 복구)
2. 앱 재시작
3. 100보 걸음
4. 로그 확인

**예상 결과**:
```
✅ PASS: 에러 로그 없음 (동기화 성공)
```

**Firestore 검증**:
```bash
# Firebase Console에서 확인
# Firestore → users/{uid}/daily_steps/{date}
# updatedAt 타임스탬프가 최근인지 확인
```

---

## 🔴 Critical #3: Health Connect 에러 상태 구분

### ✅ 수정 내용
**파일**: `lib/features/steps/steps_provider.dart:43-67`

```dart
// AS-IS (버그)
if (!available || !permitted) {
  controller.add(0);  // 권한 없음 = 0보
  return;
}

// TO-BE (수정)
if (!available || !permitted) {
  controller.add(null);  // 권한 없음 = null
  return;
}

// todayStepsProvider에서 null을 0으로 변환
hcSub = hcStream.listen((v) {
  latestHc = v ?? 0;  // null이면 0 (센서로 fallback)
  emit();
});
```

### 📋 테스트 시나리오

#### 시나리오 A: Health Connect 권한 거부 테스트

**목적**: 권한 없음과 걸음수 0을 구분할 수 있는지 확인

**전제 조건**: Android 실기기 (Health Connect 지원)

**절차**:
1. 앱 설정에서 Health Connect 권한 거부
   - Settings → Apps → 앱 → Permissions → Physical activity → Deny
2. 앱 재시작
3. Walker 화면 진입
4. Debug 출력 확인 (또는 로그)

**예상 결과**:
```dart
✅ PASS:
// healthConnectTodayStepsProvider는 null 리턴
// todayStepsProvider는 센서 값만 사용 (0 또는 센서 값)
```

**검증 포인트**:
- [ ] Health Connect 권한 없어도 앱이 정상 작동 (센서 fallback)
- [ ] Walker 화면에 "권한이 필요합니다" 메시지 없음 (센서로 대체)
- [ ] 실제 걸음을 걸으면 센서 값이 증가함

#### 시나리오 B: Health Connect 권한 허용 테스트

**목적**: 권한이 있을 때 정상 작동하는지 확인

**절차**:
1. Health Connect 권한 허용
2. 앱 재시작
3. 100보 걸음
4. 앱 종료 후 10분 대기
5. 앱 재시작 → Walker 화면

**예상 결과**:
```
✅ PASS: 앱 재시작 후에도 걸음수 유지 (Health Connect가 값 제공)
```

---

## 🟡 High #4: 단위 테스트 실행

### ✅ 추가 내용
**파일**: `android/app/src/test/.../StepsBaselineTest.kt`

### 📋 테스트 실행

**전제 조건**: `android/app/build.gradle`에 테스트 의존성 추가 필요

```gradle
// android/app/build.gradle
dependencies {
    testImplementation 'junit:junit:4.13.2'
    testImplementation 'org.mockito:mockito-core:4.0.0'
    testImplementation 'org.robolectric:robolectric:4.9'
    testImplementation 'org.jetbrains.kotlin:kotlin-test'
}
```

**실행**:
```bash
cd android
./gradlew test

# 특정 테스트만 실행
./gradlew test --tests StepsBaselineTest
```

**예상 결과**:
```
✅ PASS: BUILD SUCCESSFUL in 15s
       8 tests completed (모두 성공)

❌ FAIL: 테스트 실패 또는 컴파일 에러
```

**검증 포인트**:
- [ ] 날짜 변경 시 베이스라인 리셋 테스트 통과
- [ ] 재부팅 시 베이스라인 갱신 테스트 통과
- [ ] 캐시 무효화 테스트 통과
- [ ] 정상 증가 시 베이스라인 유지 테스트 통과

---

## 🟡 High #5: Firestore Security Rules 검증

### ✅ 추가 내용
**파일**: `firestore.rules`

### 📋 테스트 시나리오

#### 시나리오 A: 정상 쓰기 테스트

**목적**: 유효한 데이터는 쓸 수 있는지 확인

**절차**:
```bash
# Firebase Console → Firestore → Rules
# 1. firestore.rules 내용을 복사하여 Rules 탭에 붙여넣기
# 2. "게시" 버튼 클릭
# 3. Firestore Emulator로 테스트 (선택)

firebase emulators:start --only firestore
```

**앱에서 테스트**:
1. 앱 실행
2. 100보 걸음
3. Firestore Console 확인
   - `users/{uid}/daily_steps/2026-02-17` 문서 생성 확인
   - `steps` 필드가 100인지 확인

**예상 결과**:
```
✅ PASS: 문서 생성 성공, steps = 100
```

#### 시나리오 B: 부정 데이터 차단 테스트

**목적**: 비정상적인 데이터가 차단되는지 확인

**테스트 케이스**:
```javascript
// Firebase Console → Firestore → Rules Playground

// 테스트 1: 100만 보 쓰기 (초과)
PUT /databases/(default)/documents/users/test_uid/daily_steps/2026-02-17
{
  "date": "2026-02-17",
  "steps": 1000000,  // MAX 초과
  "updatedAt": <timestamp>
}
// 예상: ❌ Permission denied

// 테스트 2: 음수 걸음수 (부정)
PUT /databases/(default)/documents/users/test_uid/daily_steps/2026-02-17
{
  "date": "2026-02-17",
  "steps": -100,  // 음수
  "updatedAt": <timestamp>
}
// 예상: ❌ Permission denied

// 테스트 3: 미래 날짜 쓰기 (부정)
PUT /databases/(default)/documents/users/test_uid/daily_steps/2030-12-31
{
  "date": "2030-12-31",
  "steps": 1000,
  "updatedAt": <timestamp>
}
// 예상: ❌ Permission denied

// 테스트 4: 정상 데이터
PUT /databases/(default)/documents/users/test_uid/daily_steps/2026-02-17
{
  "date": "2026-02-17",
  "steps": 5000,
  "updatedAt": <timestamp>
}
// 예상: ✅ Permission allowed
```

**검증 포인트**:
- [ ] 100,000보 초과 값 차단됨
- [ ] 음수 값 차단됨
- [ ] 미래 날짜 차단됨
- [ ] 7일 이전 날짜 차단됨
- [ ] 정상 값은 허용됨

---

## 🟡 High #6: 권한 프롬프트 중복 방지

### ✅ 추가 내용
**파일**: `lib/features/steps/steps_permission_prompt_state.dart`

**추가 작업 필요**:
1. `main.dart`에 SharedPreferences 초기화
2. `home_screen.dart`에 provider 통합

### 📋 테스트 시나리오

#### 시나리오 A: "다시 보지 않기" 기능 테스트

**목적**: 다시 보지 않기 선택 시 프롬프트가 다시 안 뜨는지 확인

**전제 조건**: home_screen.dart 통합 완료

**절차**:
1. 앱 최초 실행 (또는 앱 데이터 삭제 후)
2. 권한 프롬프트 팝업 확인
3. **"다시 보지 않기" 선택**
4. 앱 종료
5. 앱 재시작
6. 홈 화면 확인

**예상 결과**:
```
✅ PASS: 권한 프롬프트가 다시 나타나지 않음
❌ FAIL: 권한 프롬프트가 다시 나타남
```

**SharedPreferences 확인**:
```bash
adb shell run-as com.doyakmin.hangookji.namgu cat shared_prefs/*.xml | grep steps_permission

# 예상 출력:
# <boolean name="steps_permission_prompt_dismissed" value="true" />
```

**검증 포인트**:
- [ ] "다시 보지 않기" 선택 후 앱 재시작해도 프롬프트 안 뜸
- [ ] "나중에" 선택 시에는 다음 앱 실행 시 프롬프트 다시 뜸
- [ ] SharedPreferences에 플래그 저장됨

#### 시나리오 B: 리셋 기능 테스트

**목적**: 개발/테스트 시 상태를 리셋할 수 있는지 확인

**절차**:
```dart
// 앱 코드에서 호출 (디버그 버튼 또는 개발자 메뉴)
ref.read(stepsPermissionPromptControllerProvider.notifier).reset();
```

**예상 결과**:
```
✅ PASS: reset() 호출 후 프롬프트가 다시 나타남
```

---

## 📊 종합 QA 결과 양식

```markdown
# QA 결과 보고서

**테스터**: [이름]
**날짜**: 2026-02-17
**디바이스**: [제조사 모델명, Android 버전]

## Critical Issues

### #1 센서 메모리 누수
- [ ] 시나리오 A: 화면 전환 반복 - PASS / FAIL
- [ ] 시나리오 B: 장시간 사용 - PASS / FAIL
- **비고**:

### #2 Firestore 동기화 로깅
- [ ] 시나리오 A: 네트워크 오프라인 - PASS / FAIL
- [ ] 시나리오 B: 정상 동기화 - PASS / FAIL
- **비고**:

### #3 Health Connect 에러 상태
- [ ] 시나리오 A: 권한 거부 - PASS / FAIL
- [ ] 시나리오 B: 권한 허용 - PASS / FAIL
- **비고**:

## High Priority Issues

### #4 단위 테스트
- [ ] 테스트 실행 - PASS / FAIL
- **비고**:

### #5 Firestore Security Rules
- [ ] 시나리오 A: 정상 쓰기 - PASS / FAIL
- [ ] 시나리오 B: 부정 데이터 차단 - PASS / FAIL
- **비고**:

### #6 권한 프롬프트
- [ ] 시나리오 A: "다시 보지 않기" - PASS / FAIL (통합 필요)
- [ ] 시나리오 B: 리셋 기능 - PASS / FAIL (통합 필요)
- **비고**:

## 전체 결과

- **PASS**: __/12
- **FAIL**: __/12
- **SKIP**: __/12

## 발견된 추가 이슈
1.
2.
3.

## 권장 사항
1.
2.
```

---

## 🚀 다음 단계

### QA 통과 시
1. ✅ 모든 변경사항 commit
2. ✅ PR 생성 및 코드 리뷰
3. ✅ Staging 환경 배포
4. ✅ 최종 검증 후 Production 배포

### QA 실패 시
1. ❌ 실패한 항목의 상세 로그 수집
2. ❌ 개발자에게 피드백
3. ❌ 수정 후 재테스트

---

## 📎 참고 자료

- [개선 권장사항 문서](./06_improvement_recommendations.md)
- [Phase 1 긴급 수정](./05_step_tracking_critical_fixes.md)
- [인수인계 문서](./04_step_tracking_handover.md)

---

**QA 문의**: 각 시나리오별 예상 결과와 다른 동작 발견 시 즉시 보고
