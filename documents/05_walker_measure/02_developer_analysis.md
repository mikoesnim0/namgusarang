## Walker 걸음 수 측정 기능 개발 계획

본 문서는 [`01_expert_analysis_01.md`](namgusarang/documents/05_walker_measure/01_expert_analysis_01.md)의 기술적 인사이트를 기반으로, 실제 Flutter/Native 구현을 어떤 구조로 끌고 갈지 단계별로 정리합니다.

### 1. 아키텍처 및 데이터 층 구성
- **Domain → Data → Presentation** 3계층을 유지하면서 센서 수집/동기화/부정탐지 책임을 나눕니다(01파일 4.1 참조).  
  - Domain에는 `StepSession`, `StepRepository`, `FraudDetectionService` 같은 순수 Dart 인터페이스를 두고, 구현체는 Data Layer에서 센서와 통신합니다.
  - Data Layer는 `SensorDataSource`, `HealthPlatformDataSource`, `LocalDataSource`를 만들어 `pedometer`, `sensors_plus`, `health` 패키지를 각각 담당시키고, 이들이 `StepRepository`를 통해 Presentation 계층(Bloc/Provider)으로 스트리밍합니다.
  - Presentation은 `homeProvider`/`stepsProvider`와 유사한 구조로 `StepBloc`을 구현해 실시간 걸음수, 이상탐지 상태, 배터리/권한 상태를 전파합니다.

### 2. 센서/라이브러리 통합 순서
1. **센서 스트림 확보** (`pedometer` 사용, 01파일 3.1.1 참고)
   - Android: `Sensor.TYPE_STEP_COUNTER`, iOS: `CMPedometer.startPedometerUpdates`.
   - 앱이 백그라운드에 들어갈 때에도 포그라운드 서비스(Android) / Background Fetch(iOS)를 유지하며 최소한의 데이터 손실을 방지.
2. **원시 가속도/타임스탬프 수집** (`sensors_plus`)  
   - 10초/50Hz 샘플을 물리적으로 모아 FFT/Zero-Crossing 로직에 투입하여 기계/쉐이커 탐지에 필요한 feature를 생성(01파일 3.1.2, 6.1~6.2).
3. **Health Connect / HealthKit 동기화** (`health` 패키지)  
   - 자체 센서 스트림을 '공급자'로 취급하고, 정기적으로(예: 1시간) Health Connect/HealthKit을 읽어 데이터를 검증하는 백엔드 Job.
4. **Anti-Fraud 로직**  
   - FFT 주파수 분석 + Zero Crossing 분산 + Isolation Forest(01파일 6.1~6.3)의 점수화된 지표를 `FraudBloc`/`Repository` 수준에서 평가하고, 위험 임계치를 넘으면 UI/서버에 플래그를 보냅니다.

### 3. 백그라운드/지속성 전략
- Android 포그라운드 서비스(`flutter_background_service`)에서 센서 구독을 유지하고, `POST_NOTIFICATIONS`, `ACTIVITY_RECOGNITION`, `FOREGROUND_SERVICE_HEALTH` 권한을 명시적으로 요청(01파일 4.2).
- BOOT_COMPLETED 리시버를 붙여 재부팅 후에도 `Sensor.TYPE_STEP_COUNTER` 기준 오프셋을 다시 계산하여 누적값 복원.
- 배터리 최적화 감지(`flutter_ignorebattery_optimization` 또는 `disable_battery_optimization`)를 통해 사용자를 설정 화면으로 이동시키는 UX를 추가(01파일 3.2.3, 7.1~7.2).

### 4. 서버/동기화 마무리
- `workmanager` 등을 이용해 15분~1시간 주기로 로컬에서 확인한 걸음 데이터를 서버에 전송하고, Health Connect와 비교해 둘 중 큰 값으로 누적(01파일 3.2.2, 4.3).
- 서버로 보낼 데이터 패킷에 타임스탬프, 위치 변화, 가속도 표준편차를 붙여 부정 탐지 후처리를 보조(01파일 5.2).

### 5. 우선순위 및 추진 일정 연계
- **2월 목표 이전**: 먼저 `pedometer` 기반 UI/스토어찬 구현, 이후 FFT/Anti-Fraud, 마지막으로 Health Connect/서버 동기화를 단계적으로 올립니다.  
- 개발 일정표(전사 `documents/planning/개발일정표_v1.0.md` Week 3~6)에서 현재 단계는 **Week 3 미션/걸음수 연동**과 **Week 4 미션 안정화** 사이이며, Walker 측정은 이 시점부터 본격적으로 다뤄야 할 핵심 항목입니다. 후속 주에는 백그라운드 서비스와 정합성 보장 로직이 병행됩니다.
