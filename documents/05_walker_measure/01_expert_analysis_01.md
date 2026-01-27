모바일 헬스케어 애플리케이션의 걸음 수 측정 시스템 구축을 위한 기술적 아키텍처 및 구현 전략에 관한 종합 보고서
1. 서론: 디지털 헬스케어와 보행 데이터의 진화
현대 모바일 컴퓨팅 환경에서 사용자의 신체 활동 데이터, 그중에서도 '걸음 수(Step Count)'는 가장 기본적이면서도 핵심적인 바이오마커(Biomarker)로 자리 잡았습니다. 초기 단순한 만보계(Pedometer) 수준에 머물렀던 걸음 수 측정 기술은 이제 스마트폰의 고정밀 관성 측정 장치(IMU: Inertial Measurement Unit)와 결합하여 고도화된 신호 처리 알고리즘의 영역으로 진입했습니다. 특히 2024년을 기점으로 안드로이드 생태계는 Google Fit API의 지원 중단 및 Health Connect(헬스 커넥트)로의 강제적인 플랫폼 이동이라는 거대한 전환점을 맞이하고 있으며1, 이는 개발자들에게 새로운 아키텍처 설계를 요구하고 있습니다.
또한, 캐시워크(CashWalk), 스웨트코인(Sweatcoin)과 같은 M2E(Move-to-Earn) 비즈니스 모델의 부상은 단순한 데이터 측정을 넘어, 기계적 조작(Shaker)이나 데이터 위변조를 방지해야 하는 보안 엔지니어링의 중요성을 부각시켰습니다. 본 보고서는 이러한 기술적, 시장적 요구사항을 충족하기 위해 필요한 센서 하드웨어의 이해, OS별 프레임워크 분석, 오픈소스 라이브러리 활용 전략, 그리고 실제 서비스 레벨에서의 부정 방지(Anti-Fraud) 알고리즘 및 백그라운드 프로세스 유지 전략을 15,000단어 분량으로 심층 분석합니다.
 2. 하드웨어 센서 및 운영체제 프레임워크 심층 분석
걸음 수 측정의 정확도와 배터리 효율성은 근본적으로 애플리케이션이 하드웨어 센서와 어떻게 상호작용하느냐에 달려 있습니다. 개발자는 OS가 제공하는 추상화된 API 이면에 존재하는 하드웨어의 동작 원리를 이해해야 합니다.
2.1 안드로이드 센서 아키텍처와 전력 관리
안드로이드 운영체제는 센서 데이터를 처리하기 위해 하드웨어 추상화 계층(HAL)을 통해 센서 허브(Sensor Hub)와 통신합니다. 센서 허브는 메인 애플리케이션 프로세서(AP)가 절전 모드(Deep Sleep)에 진입한 상태에서도 독립적으로 작동하여 전력 소모를 최소화하는 핵심적인 역할을 수행합니다.
2.1.1 Sensor.TYPE_STEP_COUNTER의 메커니즘
이 센서는 배터리 효율성을 최우선으로 고려한 걸음 수 측정의 '골드 스탠다드'입니다. 가속도계 데이터 스트림을 실시간으로 분석하는 대신, 하드웨어 레벨에서 감지된 걸음 이벤트만을 카운팅하여 내부 레지스터에 저장합니다.3
●	지연 처리(Latency)와 배터리: 이 센서는 이벤트 발생 즉시 AP를 깨우지 않습니다. 대신 하드웨어 FIFO(First-In, First-Out) 버퍼에 데이터를 일정량 쌓아두었다가 버퍼가 가득 차거나 지정된 지연 시간(Max Report Latency)이 초과될 때 비로소 AP에 인터럽트를 발생시킵니다.4 이는 CPU가 저전력 상태를 더 오래 유지할 수 있게 합니다.
●	데이터 특성: 마지막 장치 부팅(Reboot) 이후 누적된 총 걸음 수를 반환합니다. 따라서 앱은 부팅 시점의 값을 오프셋으로 저장하고, 현재 값과의 차이를 계산하여 '오늘의 걸음 수'를 산출해야 하는 로직이 필수적입니다.
2.1.2 Sensor.TYPE_STEP_DETECTOR와 실시간성
STEP_COUNTER와 달리 STEP_DETECTOR는 사용자가 발을 딛는 순간마다 이벤트를 발생시킵니다.3
●	활용 시나리오: 게임 캐릭터가 사용자의 걸음에 맞춰 이동하거나, UI 상에서 걸음 수가 실시간으로 올라가는 시각적 피드백을 주어야 할 때 사용됩니다.
●	트레이드오프: 잦은 인터럽트로 인해 STEP_COUNTER 대비 배터리 소모가 높습니다. 따라서 백그라운드에서의 장시간 추적용으로는 부적합하며, 포그라운드(Foreground) 세션에서만 제한적으로 사용해야 합니다.
2.1.3 원시 가속도계(Sensor.TYPE_ACCELEROMETER)
가속도계는 X, Y, Z 3축에 대한 중력 가속도 포함 데이터를 초당 수십 회(예: 50Hz) 샘플링하여 제공합니다.5
●	필요성: 시스템 제공 스텝 카운터는 단순한 패턴의 기계적 진동(예: 선풍기에 매달린 폰, 자동 흔들기 기계)을 실제 걸음으로 오인할 수 있습니다. 이를 방지하기 위한 부정 감지(Anti-Fraud) 로직을 구현하려면 원시 데이터의 주파수 분석이 필수적입니다.
●	비용: 가장 높은 배터리 소모와 CPU 점유율을 가집니다.
2.2 iOS Core Motion과 M-시리즈 코프로세서
애플은 iPhone 5s부터 M-시리즈 모션 코프로세서를 도입하여 메인 CPU의 부하 없이 센서 데이터를 수집합니다.
2.2.1 Core Motion 프레임워크 (CMPedometer)
CMPedometer 클래스는 가속도계, 자이로스코프, 그리고 기압계 데이터를 융합(Sensor Fusion)하여 보행 데이터를 제공합니다.6
●	이력 조회 기능: 안드로이드의 Sensor.TYPE_STEP_COUNTER가 실시간 스트림에 의존하는 것과 달리, CMPedometer는 queryPedometerData(from:to:) 메서드를 통해 지난 7일간의 데이터를 조회할 수 있는 내부 데이터베이스를 갖추고 있습니다.6 이는 앱이 종료되었다가 다시 실행되더라도 공백 기간의 데이터를 손실 없이 복구할 수 있게 해주는 강력한 이점입니다.
●	컨텍스트 인식: 단순 걸음 수뿐만 아니라 거리, 올라간 층수(Floors Ascended), 현재 페이스(Current Pace) 등의 메타 데이터를 함께 제공합니다.
2.2.2 HealthKit 중앙 저장소
Core Motion이 '디바이스 종속적'인 데이터라면, HealthKit은 '사용자 중심'의 데이터 저장소입니다.8
●	데이터 병합 및 우선순위: 사용자가 아이폰과 애플워치를 동시에 착용하고 걷는 경우, 두 기기 모두 걸음을 측정합니다. HealthKit은 내부 알고리즘을 통해 애플워치(손목 착용으로 더 정밀한 활동 감지 가능)의 데이터를 우선시하거나 중복을 제거하여 단일화된 '총 걸음 수'를 제공합니다.6
●	백그라운드 전달(Background Delivery): iOS 개발의 핵심은 enableBackgroundDelivery API입니다. 이를 통해 앱이 종료된 상태에서도 HealthKit에 새로운 걸음 데이터가 기록되면 시스템이 앱을 잠시 깨워(Wake up) 데이터를 처리할 기회를 제공합니다.9
2.3 구글의 전략적 전환: Health Connect
안드로이드 생태계에서 가장 중요한 변화는 2024-2025년에 걸쳐 진행되는 Google Fit API의 종료와 Health Connect로의 완전한 전환입니다.1
●	아키텍처 변화: 기존 Google Fit이 클라우드 동기화 중심의 무거운 API였다면, Health Connect는 기기 내(On-Device) 저장소를 중심으로 하여 프라이버시를 강화하고 지연 시간을 없앴습니다. 안드로이드 14부터는 별도의 앱 설치 없이 OS의 일부로 통합되었습니다.10
●	개발자의 역할: 개발자는 이제 두 가지 모드를 선택해야 합니다.
1.	공급자(Provider): 직접 센서(TYPE_STEP_COUNTER)를 통해 걸음을 측정하고, 이를 Health Connect 저장소에 WRITE 합니다.
2.	소비자(Consumer): 삼성 헬스, 구글 픽셀 등이 기록한 데이터를 READ 하여 보여주기만 합니다.
○	M2E 앱과 같이 자체적인 보상이 걸린 서비스는 데이터의 무결성을 위해 '공급자' 역할을 수행하며 자체 검증 로직을 거친 데이터만을 인정하는 경우가 많습니다.
 3. GitHub 라이브러리 및 API 활용 전략 (Flutter/Native)
크로스 플랫폼 프레임워크인 Flutter를 사용하여 개발할 때, 네이티브 센서 API에 접근하기 위한 라이브러리 선정은 프로젝트의 성패를 가르는 중요한 요소입니다. 연구 자료를 바탕으로 최적의 라이브러리 조합을 분석합니다.
3.1 핵심 걸음 측정 라이브러리 비교 및 선정
3.1.1 pedometer (Repository: kansmama/pedometer)
이 라이브러리는 가장 직관적이고 가벼운 구현을 제공합니다.12
●	동작 방식:
○	Android: Sensor.TYPE_STEP_COUNTER 스트림을 구독합니다. 권한으로는 ACTIVITY_RECOGNITION을 요구합니다.
○	iOS: CMPedometer의 startPedometerUpdates를 래핑합니다. NSMotionUsageDescription 설정이 필요합니다.
●	장점: 구현이 매우 간단하며, 하드웨어 센서를 직접 사용하므로 배터리 효율이 높습니다.
●	치명적 단점: 안드로이드에서 앱이 백그라운드로 전환되고 OS에 의해 프로세스가 종료(Kill)되면 스트림이 끊깁니다. 또한, 기기 재부팅 시 카운트가 0으로 초기화되는 하드웨어 특성을 개발자가 직접 로직으로 처리해야 합니다.
3.1.2 sensors_plus (Repository: fluttercommunity/plus_plugins)
단순 걸음 수가 아닌, '걸음의 질'을 분석하거나 부정을 감지하기 위해 필수적인 라이브러리입니다.13
●	기능: 가속도계(Accelerometer), 자이로스코프(Gyroscope), 자력계(Magnetometer)의 원시(Raw) 데이터를 높은 주파수로 스트리밍합니다.
●	활용 전략: UserAccelerometer 이벤트를 사용하여 중력을 제외한 순수 사용자의 움직임 가속도를 측정할 수 있습니다. 이는 후술할 FFT 기반의 부정 감지 알고리즘에 입력 데이터로 사용됩니다.
3.1.3 health (Repository: cph-cachet/flutter_health)
장기적인 데이터 동기화와 Health Connect/HealthKit 통합을 위한 사실상의 표준 라이브러리입니다.14
●	Health Connect 통합: 안드로이드에서 복잡한 권한 요청 흐름과 데이터 읽기/쓰기를 추상화하여 제공합니다. 특히 getHealthDataFromTypes 메서드를 통해 과거 30일간의 데이터를 한 번에 가져올 수 있어, 앱 설치 이전의 활동 기록을 보여주는 데 유용합니다.
●	한계: 실시간성(Real-time)이 부족합니다. Health Connect의 데이터는 다른 앱이 데이터를 쓸 때까지 갱신되지 않을 수 있으므로, 실시간 만보계 UI에는 부적합하며 '데이터 백업' 및 '타 앱과의 연동' 용도로 사용해야 합니다.
3.2 백그라운드 프로세싱 및 지속성 유지를 위한 라이브러리
M2E 앱의 핵심은 사용자가 앱을 켜두지 않아도 걸음이 측정되어야 한다는 것입니다. 이를 위해 다음과 같은 백그라운드 처리 라이브러리가 필수적입니다.
3.2.1 flutter_background_service (Android 중심)
안드로이드의 '포그라운드 서비스(Foreground Service)'를 구현하여 앱의 생명주기를 연장합니다.16
●	원리: 사용자에게 "걸음 수 측정 중"이라는 지속적인 알림(Notification)을 상단바에 노출시킵니다. 안드로이드 시스템은 이러한 알림이 있는 서비스를 '사용자가 인지하고 있는 작업'으로 간주하여, 메모리가 부족해도 강제 종료(OOM Kill) 순위를 낮춥니다.18
●	구성: IosConfiguration에서 onBackground를 설정하여 iOS의 백그라운드 페치(Fetch)를 지원하지만, 안드로이드만큼 강력한 지속성을 보장하지는 않습니다.
3.2.2 workmanager (주기적 동기화)
실시간 측정보다는 주기적인 데이터 서버 전송(Sync)에 최적화된 라이브러리입니다.19
●	제약 사항: 안드로이드는 배터리 보호를 위해 백그라운드 작업의 최소 주기를 15분으로 제한합니다. 따라서 15분마다 깨어나 로컬 DB에 저장된 걸음 수를 서버로 전송하는 로직에 적합합니다.
●	iOS: BGTaskScheduler를 활용하지만, 실행 시점은 OS가 배터리 상태와 사용자의 앱 사용 패턴을 학습하여 결정하므로 실행을 보장할 수 없습니다.
3.2.3 flutter_ignorebatteryoptimization (제조사 대응)
샤오미(Xiaomi), 삼성(Samsung) 등의 제조사는 순정 안드로이드보다 훨씬 공격적인 배터리 최적화 정책을 사용하여 백그라운드 앱을 강제로 종료시킵니다.
●	기능: 현재 앱이 배터리 최적화 예외 리스트(Whitelist)에 포함되어 있는지 확인하고, 포함되어 있지 않다면 사용자에게 권한 요청 팝업을 띄우거나 해당 설정 화면으로 이동시키는 인텐트(Intent)를 실행합니다.21
3.3 라이브러리 통합 아키텍처 제안
기능	권장 라이브러리/API	역할 및 설명
실시간 걸음 감지	pedometer	하드웨어 센서 리스너 등록. UI 갱신용 스트림 제공.
데이터 검증	sensors_plus	10초 주기 또는 특정 트리거 시 원시 가속도 데이터 샘플링하여 패턴 분석.
장기 저장소	health	Health Connect/HealthKit에 '검증된' 걸음 수 기록 및 과거 데이터 조회.
백그라운드 유지	flutter_background_service	안드로이드 포그라운드 서비스 실행, 센서 리스너 생존 보장.
서버 동기화	workmanager	15분~1시간 주기로 로컬 DB 데이터를 서버로 전송.
OS 최적화 회피	disable_battery_optimization	제조사별 배터리 절전 모드 해제 요청.
 4. 실제 도입을 위한 심층 기술 가이드: 아키텍처와 구현
단순히 라이브러리를 연결하는 것을 넘어, 유지보수성과 확장성을 고려한 '클린 아키텍처(Clean Architecture)' 기반의 구현 방법을 상세히 기술합니다.
4.1 클린 아키텍처(Clean Architecture) 폴더 구조 및 계층 설계
플러터 앱의 확장성을 위해 Domain, Data, Presentation 세 계층으로 엄격히 분리하는 전략을 사용합니다.23
4.1.1 Domain Layer (비즈니스 로직의 핵심)
이 계층은 플러터나 특정 라이브러리에 의존하지 않는 순수 Dart 코드로 작성됩니다.
●	Entities: StepSession(걸음 세션), FraudAlert(부정 감지 경보)와 같은 핵심 데이터 모델.
●	Repositories (Interfaces): IStepRepository, IFraudDetectionService와 같이 데이터 소스가 무엇인지(Local DB인지, Sensor인지, Health Connect인지) 몰라도 기능을 정의하는 인터페이스.
●	Use Cases:
○	TrackRealtimeStepsUseCase: 센서 데이터를 구독하고 유효성을 검증하는 로직.
○	SyncStepsToCloudUseCase: 로컬 데이터를 서버와 동기화하는 로직.
○	DetectMechanicalShakerUseCase: 가속도 데이터를 분석하여 기계적 조작을 탐지하는 로직.
4.1.2 Data Layer (구현체)
●	Data Sources:
○	LocalDataSource: SQLite(sqflite 사용) 또는 Hive를 사용하여 인터넷 연결 없이도 걸음 데이터를 저장.
○	SensorDataSource: pedometer와 sensors_plus를 사용하여 실제 하드웨어 데이터 수집.
○	HealthPlatformDataSource: health 패키지를 이용한 Health Connect 연동.
●	Repository Implementation: Domain 계층의 인터페이스를 실제로 구현하며, 센서에서 온 데이터를 로컬 DB에 캐싱하고 서버로 보내는 조율 역할을 수행합니다.
4.1.3 Presentation Layer (UI 및 상태 관리)
●	BLoC (Business Logic Component): 걸음 수 측정은 스트림(Stream) 데이터이므로 BLoC 패턴이 가장 적합합니다.25
○	StepBloc: StepCountUpdated 이벤트를 받아 StepsLoaded 상태를 방출(Emit)합니다.
○	FraudBloc: 부정 행위가 감지되면 붉은 경고 화면을 띄우는 상태를 관리합니다.
4.2 안드로이드 14 대응 포그라운드 서비스 구현
안드로이드 14(API 34)부터는 포그라운드 서비스의 타입(Type)을 명시해야 하며, 헬스 데이터 처리를 위해서는 health 또는 dataSync 타입을 선언해야 합니다.26
AndroidManifest.xml 설정:

XML


<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH" /> <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <application>
        <service
            android:name=".services.StepCountingService"
            android:foregroundServiceType="health"
            android:exported="false" />
    </application>
</manifest>

구현 로직:
1.	서비스 시작: 앱 실행 시 FlutterBackgroundService.start()를 호출합니다.
2.	알림 채널 생성: NotificationChannel을 생성할 때 IMPORTANCE_LOW로 설정하여 사용자의 시각적 방해를 최소화하면서도 시스템에 서비스의 존재를 알립니다.
3.	센서 리스너 등록: 서비스의 onStart 메서드 내부에서 pedometer 스트림을 구독(Listen)합니다.
4.	부팅 감지: BOOT_COMPLETED 리시버를 등록하여 폰이 재부팅되자마자 서비스가 자동으로 다시 시작되도록 구현합니다. 이때, Sensor.TYPE_STEP_COUNTER가 0으로 초기화되므로, 재부팅 직전의 마지막 저장된 걸음 수를 로컬 DB에서 불러와 오프셋(Offset) 보정 로직을 실행해야 합니다.3
4.3 데이터 동기화와 충돌 해결 전략
여러 소스(자체 센서, Health Connect, 서버)의 데이터가 충돌할 때의 해결 전략(Conflict Resolution)이 필요합니다.
●	단일 진실 공급원(SSOT): 사용자가 앱을 켜고 걷는 동안은 '자체 센서' 값을 UI에 우선 표시하여 반응성을 높입니다.
●	백그라운드 병합: 1시간마다 Health Connect의 데이터를 조회하여, 자체 센서가 놓친 걸음(예: 앱이 잠시 죽었을 때 워치가 측정한 걸음)이 있는지 확인하고 더 큰 값(MAX)을 기준으로 보정합니다.
 5. 참고할 만한 앱 분석: 성공 요인과 기술적 특이점
시장 선도 앱들은 단순히 걸음을 세는 것을 넘어, 기술적인 장벽을 통해 비즈니스 모델을 보호하고 사용자 참여를 유도하고 있습니다.
5.1 캐시워크(CashWalk): 지속성(Persistence)의 극대화
캐시워크의 가장 큰 기술적 특징은 잠금 화면(Lockscreen) 오버레이를 활용한 프로세스 생존 전략입니다.
●	기술적 구현: 안드로이드의 SYSTEM_ALERT_WINDOW 권한(다른 앱 위에 그리기)을 사용하여 시스템 잠금 화면 위에 커스텀 뷰를 렌더링합니다.28
●	생존 원리: 화면을 켤 때마다 앱의 UI가 렌더링되므로, 안드로이드 OOM(Out of Memory) 킬러는 이 앱을 '사용자가 현재 상호작용 중인 앱(Perceptible)'으로 분류합니다.18 이는 백그라운드 서비스만 돌리는 앱보다 훨씬 높은 우선순위를 보장받아 프로세스 종료를 방지합니다.
●	보물상자 UX: 사용자가 걸음으로 얻은 포인트를 수동으로 탭(Tap)하여 수거하게 만드는 UX는 단순한 게임화(Gamification)가 아니라, '봇(Bot) 방지' 및 '사용자 생존 신호(Heartbeat)' 역할을 합니다.30 10,000보를 걷고도 앱을 켜지 않으면 보상을 주지 않음으로써, 사용자가 반드시 앱을 포그라운드로 올리도록 강제합니다.
5.2 스웨트코인(Sweatcoin): 데이터 검증 알고리즘
스웨트코인은 "검증된 걸음(Verified Steps)"이라는 개념을 도입하여 기술적 차별화를 꾀했습니다.
●	전환율(Conversion Rate): 스웨트코인은 하드웨어가 보고한 걸음 수의 약 65%만을 실제 코인으로 전환해줍니다.31 이는 실내에서의 미세한 움직임이나 '쉐이커'에 의한 진동을 걸러낸 결과입니다.
●	서버 사이드 검증: 걸음 데이터 패킷에 타임스탬프, 걸음 간격(Cadence), GPS 위치 변화 데이터를 포함하여 서버로 전송합니다. 서버는 사용자의 이동 속도가 시속 20km를 넘는 경우(차량 이동), 걸음 패턴이 너무 규칙적인 경우(기계적 흔들기)를 분석하여 해당 구간의 걸음을 무효화합니다.33
 6. 부정 방지(Anti-Fraud) 엔지니어링: 수학적 접근
M2E 서비스에서 부정 사용자는 '자동 걷기 기계(Phone Shaker)'를 사용하여 가짜 걸음을 생성합니다. 이를 기술적으로 탐지하는 것은 서비스의 경제 시스템을 보호하는 데 필수적입니다.
6.1 기계적 쉐이커 탐지: 주파수 도메인 분석 (FFT)
기계적 쉐이커는 물리 진자 운동을 기반으로 하므로 매우 일정한 주기를 가집니다. 반면 인간의 보행은 '준주기적(Quasi-periodic)' 특성을 가집니다.34
6.1.1 알고리즘 구현 단계
1.	데이터 샘플링: sensors_plus를 사용하여 10초간 가속도 데이터(X, Y, Z)를 50Hz로 수집합니다.
2.	벡터 크기 계산: 방향성을 제거하기 위해 가속도 벡터의 크기($|A| = \sqrt{x^2 + y^2 + z^2}$)를 계산합니다.
3.	FFT(고속 푸리에 변환) 적용: 시간 도메인의 데이터를 주파수 도메인으로 변환합니다.36
4.	피크 분석(Peak Analysis):
○	기계: 주파수 스펙트럼에서 특정 주파수(예: 1.5Hz)에 에너지가 극도로 집중된 '단일 피크(Narrow Peak)'가 나타납니다. 고조파(Harmonics)가 뚜렷합니다.
○	인간: 주파수 대역이 1.0Hz ~ 2.0Hz 사이에 넓게 분포하며(Wide Bandwidth), 피크 주변에 노이즈(Jitter)가 존재합니다.
5.	판별 로직: 피크의 대역폭(Bandwidth)이나 Q-factor를 계산하여 임계치 이상으로 날카로운 피크가 지속되면 기계적 조작으로 판단합니다.34
6.2 제로 크로싱(Zero-Crossing) 분산 분석
인간의 걸음은 피로도, 지면의 경사 등에 따라 걸음 간격이 미세하게 변합니다.
●	ZCR 분산(Variance): 가속도 신호가 평균값을 교차하는 지점 간의 시간 간격($\Delta t$)을 측정합니다.
●	판별: $\Delta t$의 표준편차($\sigma$)가 0에 가까울 정도로 일정하다면(예: 모든 걸음이 정확히 0.6초 간격), 이는 기계적 운동일 확률이 99% 이상입니다.38
6.3 머신러닝 기반 이상 탐지
더 고도화된 탐지를 위해 Isolation Forest(고립 숲) 알고리즘을 적용할 수 있습니다.
●	Feature Engineering: 입력 변수로 '평균 가속도', '최대 가속도', '걸음 간격의 표준편차', '자이로스코프 회전량' 등을 사용합니다.
●	모델: 정상적인 걷기 데이터를 학습시킨 One-Class SVM이나 Isolation Forest 모델을 앱 내(TensorFlow Lite)에 탑재하여, 입력된 패턴이 정상 분포에서 벗어날 경우 '이상(Anomaly)'으로 플래그를 지정합니다.39
 7. 제조사별 배터리 최적화 대응 전략 (Don't Kill My App)
안드로이드 파편화의 가장 큰 문제는 제조사(OEM)별로 상이한 백그라운드 프로세스 정책입니다. 삼성, 샤오미 등은 순정 안드로이드보다 훨씬 공격적으로 백그라운드 앱을 종료시킵니다. 이를 해결하기 위한 기술적 대응책입니다.
7.1 인텐트(Intent)를 통한 화이트리스트 등록 유도
앱 설치 직후 온보딩 과정에서 사용자를 제조사별 설정 화면으로 직접 이동시켜야 합니다.40
제조사	문제점	해결을 위한 설정 경로 및 인텐트 액션
Samsung	'절전 모드' 앱을 강제 종료함	Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS 실행 후, "배터리 사용량 최적화 중지" 목록에 앱 추가 유도. "Deep Sleeping Apps" 리스트 확인 필요.
Xiaomi (HyperOS/MIUI)	'AutoStart' 권한 없으면 백그라운드 실행 불가	miui.intent.action.OP_AUTO_START 인텐트를 호출하여 '자동 시작' 권한 허용 유도.
OnePlus/Oppo	화면 꺼짐 시 네트워크/센서 차단	'배터리 최적화' 설정에서 'Don't Optimize' 선택 필요.
Huawei	'PowerGenie'라는 시스템 앱이 강제 종료	huawei.intent.action.POWER_USAGE_DETAILS 등으로 이동하여 '앱 실행' 수동 관리 설정 유도.
7.2 기술적 우회 기법
●	더미 알림 업데이트: 포그라운드 서비스의 알림을 주기적으로(예: 10분마다) 갱신하면, 시스템은 앱이 활발하게 동작 중인 것으로 인식하여 우선순위를 유지할 수 있습니다.
●	Wakelock 관리: PowerManager.PARTIAL_WAKE_LOCK을 획득하면 CPU가 잠드는 것을 막을 수 있으나, 구글 플레이 스토어 정책상 명확한 사유가 없으면 반려될 수 있으므로 주의가 필요합니다. 걸음 수 측정 앱은 FOREGROUND_SERVICE_HEALTH 권한과 함께 정당한 사용처로 인정받을 수 있습니다.
 8. 결론
앱 내 걸음 수 측정 기능의 구현은 표면적으로는 간단해 보이지만, 정확도(Accuracy), 지속성(Persistence), **보안(Security)**이라는 세 가지 축을 모두 만족시키기 위해서는 깊이 있는 엔지니어링이 요구됩니다.
본 보고서의 분석에 따르면, 최신 안드로이드 환경에서는 Health Connect를 장기적인 데이터 백본으로 사용하되, 실시간 사용자 경험과 M2E 비즈니스 로직을 위해서는 pedometer 및 **sensors_plus**를 결합한 하이브리드 아키텍처가 필수적입니다. 또한, 단순한 측정 로직을 넘어 FFT 기반의 신호 처리를 통한 부정 감지 시스템을 도입하고, 제조사별 배터리 최적화 정책에 대응하는 정교한 UX 설계를 포함해야만 상용화 가능한 수준의 서비스 품질을 보장할 수 있습니다.
개발팀은 본 보고서에서 제시한 클린 아키텍처 폴더 구조와 제조사 대응 인텐트 전략을 기반으로 프로토타입을 구축하고, 실제 다양한 기기에서의 필드 테스트를 통해 임계값(Threshold)을 튜닝하는 과정을 거쳐야 할 것입니다.
 보고서 종료
Works cited
1.	What is Health Connect and How is it Different from Google Fit? - MedM, accessed January 19, 2026, https://www.medm.com/company/blog/2024/what-is-health-connect-and-how-is-it-different-from-google-fit.html
2.	Fit migration guide | Android health & fitness, accessed January 19, 2026, https://developer.android.com/health-and-fitness/health-connect/migration/fit
3.	How to Correctly Count Steps on Android: A Complete Developer's Guide from Sensors to Health Connect | by Valery Vaunou | Medium, accessed January 19, 2026, https://medium.com/@vovnovvalera/how-to-correctly-count-steps-on-android-a-complete-developers-guide-from-sensors-to-health-da99e5043968
4.	Read raw data | Android health & fitness, accessed January 19, 2026, https://developer.android.com/health-and-fitness/health-connect/read-data
5.	AN-2554: Step Counting Using the ADXL367 - Analog Devices, accessed January 19, 2026, https://www.analog.com/en/resources/app-notes/an-2554.html
6.	CMPedometer's steps history is different than the Health App - Stack Overflow, accessed January 19, 2026, https://stackoverflow.com/questions/47836620/cmpedometers-steps-history-is-different-than-the-health-app
7.	Pedometer & Step Counter - App Store - Apple, accessed January 19, 2026, https://apps.apple.com/us/app/pedometer-step-counter/id1286965867
8.	Health and fitness apps - Apple Developer, accessed January 19, 2026, https://developer.apple.com/health-fitness/
9.	com.apple.developer.healthkit.background-delivery, accessed January 19, 2026, https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit.background-delivery
10.	Track steps | Android health & fitness, accessed January 19, 2026, https://developer.android.com/health-and-fitness/health-connect/features/steps
11.	Get started with Health Connect | Android health & fitness - Android Developers, accessed January 19, 2026, https://developer.android.com/health-and-fitness/health-connect/get-started
12.	Pedometer App using Flutter - GitHub, accessed January 19, 2026, https://github.com/kansmama/pedometer
13.	sensors_plus | Flutter package - Pub.dev, accessed January 19, 2026, https://pub.dev/packages/sensors_plus
14.	health | Flutter package - Pub.dev, accessed January 19, 2026, https://pub.dev/packages/health
15.	Integrating Health Connect on Android with Flutter's Health Plugin | by DIVYASREE M, accessed January 19, 2026, https://medium.com/@256divyasree/integrating-health-connect-on-android-with-flutters-health-plugin-a197ca9e0675
16.	Flutter Background Service: Complete Guide - Bugsee, accessed January 19, 2026, https://bugsee.com/flutter/flutter-background-service/
17.	Handling Background Services in Flutter: The Right Way Across Android 14 & iOS 17 | by Shubham Pawar | Medium, accessed January 19, 2026, https://medium.com/@shubhampawar99/handling-background-services-in-flutter-the-right-way-across-android-14-ios-17-b735f3b48af5
18.	Effective foreground services on Android - Android Developers Blog, accessed January 19, 2026, https://android-developers.googleblog.com/2018/12/effective-foreground-services-on-android_11.html
19.	Flutter Workmanager, accessed January 19, 2026, https://docs.page/fluttercommunity/flutter_workmanager~647
20.	WorkManager in Flutter — Running Background Tasks the Right Way | by Prathamesh Mali, accessed January 19, 2026, https://medium.com/@prathamesh.dev004/workmanager-in-flutter-running-background-tasks-the-right-way-c4c37dfbd0ea
21.	Flutter IgnoreBatteryOptimization - Dart API docs - Pub.dev, accessed January 19, 2026, https://pub.dev/documentation/flutter_ignorebatteryoptimization/latest/
22.	Bhat015/optimize_battery: Flutter plugin to check for battery optimization status, open optimization settings and disable optimization. - GitHub, accessed January 19, 2026, https://github.com/Bhat015/optimize_battery
23.	Folder Structure for Flutter with Clean Architecture: A Boss-Level Approach - Medium, accessed January 19, 2026, https://medium.com/@kelmants/folder-structure-for-flutter-with-clean-architecture-a-boss-level-approach-309b8bdfcbba
24.	Flutter Clean Architecture: Build Scalable Apps Step-by-Step - Djamware, accessed January 19, 2026, https://www.djamware.com/post/68fd9dee1157e31c6604ab8f/flutter-clean-architecture-build-scalable-apps-stepbystep
25.	Design patterns & Clean architecture in flutter [closed] - Stack Overflow, accessed January 19, 2026, https://stackoverflow.com/questions/70912569/design-patterns-clean-architecture-in-flutter
26.	Foreground services overview | Background work - Android Developers, accessed January 19, 2026, https://developer.android.com/develop/background-work/services/fgs
27.	Use Sensor Manager to measure steps from a mobile device | Android health & fitness, accessed January 19, 2026, https://developer.android.com/health-and-fitness/fitness/basic-app/read-step-count-data
28.	SYSTEM_ALERT_WINDOW - How to get this permission automatically on Android 6.0 and targetSdkVersion 23 - Stack Overflow, accessed January 19, 2026, https://stackoverflow.com/questions/36016369/system-alert-window-how-to-get-this-permission-automatically-on-android-6-0-an
29.	How to fix "Screen Overlay detected" Causing Error with all my apps even after turning overlay off all my apps - Reddit, accessed January 19, 2026, https://www.reddit.com/r/AndroidQuestions/comments/61x5os/how_to_fix_screen_overlay_detected_causing_error/
30.	Money-Making Apps: CashWalk Review - stenoodie, accessed January 19, 2026, https://stenoodie.com/2025/09/16/get-paid-to-walk/
31.	How does Sweatcoin's step counting algorithm work?, accessed January 19, 2026, https://help.sweatco.in/hc/en-us/articles/360012752551-How-does-Sweatcoin-s-step-counting-algorithm-work
32.	Sweatcoin Step Verification Algorithm, accessed January 19, 2026, https://sweatco.in/verification-algorithm
33.	Step verification and fraud detection | by Sweat Team - Medium, accessed January 19, 2026, https://medium.com/sweat-economy/step-verification-and-fraud-detection-a2f0f8947f3c
34.	A Novel Walking Detection and Step Counting Algorithm Using Unconstrained Smartphones, accessed January 19, 2026, https://www.mdpi.com/1424-8220/18/1/297
35.	Ensuring Wearable Step-Count Validity for Effective Public Health Interventions | medRxiv, accessed January 19, 2026, https://www.medrxiv.org/content/10.1101/2025.05.24.25328291v1.full-text
36.	Guide to FFT Analysis (Fast Fourier Transform) | Dewesoft, accessed January 19, 2026, https://dewesoft.com/blog/guide-to-fft-analysis
37.	Introduction to Fast Fourier Transform (FFT) Analysis - Vibration Research, accessed January 19, 2026, https://vibrationresearch.com/blog/fast-fourier-transform-fft-analysis/
38.	Step counting on smartphones using advanced zero-crossing and linear regression, accessed January 19, 2026, https://www.researchgate.net/publication/282680705_Step_counting_on_smartphones_using_advanced_zero-crossing_and_linear_regression
39.	Advanced fraud detection using machine learning models: enhancing financial transaction security - ResearchGate, accessed January 19, 2026, https://www.researchgate.net/publication/392629004_Advanced_fraud_detection_using_machine_learning_models_enhancing_financial_transaction_security
40.	Galaxy Battery - Optimization - Samsung, accessed January 19, 2026, https://www.samsung.com/us/support/galaxy-battery/optimization/
41.	How to turn off your Android's battery optimizer - Cardata Help Center, accessed January 19, 2026, https://help.cardata.co/article/175-how-to-turn-off-your-androids-battery-optimizer
42.	Xiaomi | Don't kill my app!, accessed January 19, 2026, https://dontkillmyapp.com/xiaomi
