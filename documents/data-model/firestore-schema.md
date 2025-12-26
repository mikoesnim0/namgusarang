# Firestore 데이터모델 스키마

**프로젝트**: 남구이야기  
**Firebase Project ID**: `hankookji-namgu`  
**작성일**: 2024년 12월 22일  
**버전**: 1.0

---

## 목차
1. [컬렉션 구조 개요](#1-컬렉션-구조-개요)
2. [users (사용자)](#2-users-사용자)
3. [coupons (쿠폰 템플릿)](#3-coupons-쿠폰-템플릿)
4. [missions (미션 템플릿)](#4-missions-미션-템플릿)
5. [places (매장)](#5-places-매장)
6. [events (이벤트 로그)](#6-events-이벤트-로그)
7. [notifications (공지사항)](#7-notifications-공지사항)
8. [인덱스 설정](#8-인덱스-설정)

---

## 1. 컬렉션 구조 개요

```
firestore
├── users/                     # 사용자 정보
│   └── {uid}/
│       ├── (document fields)
│       ├── myCoupons/         # 내 쿠폰
│       ├── myMissions/        # 내 미션 진행도
│       ├── history/           # 활동 내역
│       └── notifications/     # 개인 알림
├── coupons/                   # 쿠폰 템플릿 (마스터)
├── missions/                  # 미션 템플릿 (마스터)
├── places/                    # 매장 정보
├── events/                    # 전체 이벤트 로그
└── notifications/             # 전체 공지사항
```

---

## 2. users (사용자)

### 2.1 users/{uid}

**경로**: `/users/{uid}`  
**설명**: 사용자 기본 정보

#### 필드

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| uid | string | ✅ | - | Firebase Auth UID |
| email | string | ✅ | - | 이메일 |
| nickname | string | ❌ | null | 닉네임 (회원가입 후 설정) |
| birthdate | string | ❌ | null | 생년월일 (YYYY-MM-DD) |
| gender | string | ❌ | null | 성별 (male/female/other) |
| profilePic | string | ❌ | null | Storage URL |
| createdAt | timestamp | ✅ | serverTimestamp() | 가입일 |
| lastLogin | timestamp | ✅ | serverTimestamp() | 마지막 로그인 |
| totalSteps | number | ✅ | 0 | 누적 걸음수 |
| todaySteps | number | ✅ | 0 | 오늘 걸음수 |
| lastStepUpdateAt | timestamp | ❌ | null | 마지막 걸음수 업데이트 |
| subscriptionType | string | ❌ | 'free' | 구독 타입 (free/premium) |
| subscriptionEndAt | timestamp | ❌ | null | 구독 만료일 |
| friendInviteCode | string | ✅ | auto | 초대 코드 (6자리) |
| invitedBy | string | ❌ | null | 초대한 사람 uid |

#### 예시

```json
{
  "uid": "abc123",
  "email": "user@example.com",
  "nickname": "남구댁",
  "birthdate": "1985-03-15",
  "gender": "female",
  "profilePic": "gs://hankookji-namgu.appspot.com/profiles/abc123/profile.jpg",
  "createdAt": "2024-12-22T00:00:00Z",
  "lastLogin": "2024-12-22T09:30:00Z",
  "totalSteps": 125000,
  "todaySteps": 3500,
  "lastStepUpdateAt": "2024-12-22T09:29:00Z",
  "subscriptionType": "premium",
  "subscriptionEndAt": "2025-01-22T00:00:00Z",
  "friendInviteCode": "A1B2C3",
  "invitedBy": null
}
```

---

### 2.2 users/{uid}/myCoupons/{couponId}

**경로**: `/users/{uid}/myCoupons/{couponId}`  
**설명**: 사용자가 보유한 쿠폰

#### 필드

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| couponId | string | ✅ | - | 쿠폰 템플릿 ID (coupons 컬렉션 참조) |
| title | string | ✅ | - | 쿠폰명 |
| description | string | ✅ | - | 쿠폰 설명 |
| type | string | ✅ | - | 할인 타입 (amount/percent/free) |
| discount | number | ✅ | - | 할인 금액 또는 퍼센트 |
| validUntil | timestamp | ✅ | - | 유효기간 |
| usableStores | array | ✅ | [] | 사용 가능 매장 ID 배열 |
| status | string | ✅ | 'active' | 상태 (active/used/expired) |
| issuedAt | timestamp | ✅ | serverTimestamp() | 발급일 |
| usedAt | timestamp | ❌ | null | 사용일 |
| usedPlaceId | string | ❌ | null | 사용 매장 ID |
| verificationCode | string | ✅ | auto | 4자리 인증 코드 |

#### 예시

```json
{
  "couponId": "coupon_cafe_americano",
  "title": "아메리카노 1잔 무료",
  "description": "시원한 아메리카노 무료 제공",
  "type": "free",
  "discount": 0,
  "validUntil": "2025-01-31T23:59:59Z",
  "usableStores": ["place_001", "place_002"],
  "status": "active",
  "issuedAt": "2024-12-22T10:00:00Z",
  "usedAt": null,
  "usedPlaceId": null,
  "verificationCode": "1234"
}
```

---

### 2.3 users/{uid}/myMissions/{missionId}

**경로**: `/users/{uid}/myMissions/{missionId}`  
**설명**: 사용자 미션 진행도

#### 필드

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| missionId | string | ✅ | - | 미션 템플릿 ID |
| title | string | ✅ | - | 미션명 |
| type | string | ✅ | - | 미션 유형 (steps/visit/review/invite) |
| goal | number | ✅ | - | 목표치 |
| progress | number | ✅ | 0 | 현재 진행도 |
| status | string | ✅ | 'pending' | 상태 (pending/in-progress/completed/failed) |
| reward | map | ✅ | - | 보상 정보 ({ type: 'coupon', id: '...' }) |
| startedAt | timestamp | ❌ | null | 시작일 |
| completedAt | timestamp | ❌ | null | 완료일 |
| expiresAt | timestamp | ✅ | - | 만료일 |

#### 예시

```json
{
  "missionId": "mission_daily_steps_5000",
  "title": "오늘 5,000보 걷기",
  "type": "steps",
  "goal": 5000,
  "progress": 3500,
  "status": "in-progress",
  "reward": {
    "type": "coupon",
    "id": "coupon_cafe_americano"
  },
  "startedAt": "2024-12-22T00:00:00Z",
  "completedAt": null,
  "expiresAt": "2024-12-22T23:59:59Z"
}
```

---

### 2.4 users/{uid}/history/{historyId}

**경로**: `/users/{uid}/history/{historyId}`  
**설명**: 사용자 활동 내역 (1년 보관)

#### 필드

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| type | string | ✅ | - | 활동 유형 (coupon_used/mission_completed/place_visited) |
| title | string | ✅ | - | 제목 |
| description | string | ✅ | - | 설명 |
| relatedId | string | ❌ | null | 관련 문서 ID (쿠폰/미션/매장) |
| timestamp | timestamp | ✅ | serverTimestamp() | 발생 시각 |

---

### 2.5 users/{uid}/notifications/{notificationId}

**경로**: `/users/{uid}/notifications/{notificationId}`  
**설명**: 개인 알림 (푸시 히스토리)

#### 필드

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| title | string | ✅ | - | 알림 제목 |
| body | string | ✅ | - | 알림 본문 |
| type | string | ✅ | - | 알림 유형 (coupon/mission/event/notice) |
| isRead | boolean | ✅ | false | 읽음 여부 |
| data | map | ❌ | null | 추가 데이터 (딥링크 등) |
| createdAt | timestamp | ✅ | serverTimestamp() | 생성일 |

---

## 3. coupons (쿠폰 템플릿)

**경로**: `/coupons/{couponId}`  
**설명**: 쿠폰 마스터 데이터 (관리자 생성)

### 필드

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| couponId | string | ✅ | - | 쿠폰 ID |
| title | string | ✅ | - | 쿠폰명 |
| description | string | ✅ | - | 쿠폰 설명 |
| type | string | ✅ | - | 할인 타입 (amount/percent/free) |
| discount | number | ✅ | - | 할인 금액 또는 퍼센트 |
| image | string | ❌ | null | 쿠폰 이미지 URL |
| usableStores | array | ✅ | [] | 사용 가능 매장 ID 배열 (빈 배열 = 모든 매장) |
| validDays | number | ✅ | 30 | 발급 후 유효일수 |
| minPurchase | number | ❌ | 0 | 최소 구매 금액 |
| category | string | ✅ | - | 카테고리 (food/cafe/convenience) |
| isActive | boolean | ✅ | true | 활성화 여부 |
| createdAt | timestamp | ✅ | serverTimestamp() | 생성일 |

### 예시

```json
{
  "couponId": "coupon_cafe_americano",
  "title": "아메리카노 1잔 무료",
  "description": "시원한 아메리카노 무료 제공",
  "type": "free",
  "discount": 0,
  "image": "gs://.../coupons/americano.jpg",
  "usableStores": ["place_001", "place_002"],
  "validDays": 30,
  "minPurchase": 0,
  "category": "cafe",
  "isActive": true,
  "createdAt": "2024-12-01T00:00:00Z"
}
```

---

## 4. missions (미션 템플릿)

**경로**: `/missions/{missionId}`  
**설명**: 미션 마스터 데이터 (관리자 생성)

### 필드

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| missionId | string | ✅ | - | 미션 ID |
| title | string | ✅ | - | 미션명 |
| description | string | ✅ | - | 미션 설명 |
| type | string | ✅ | - | 미션 유형 (steps/visit/review/invite/attendance) |
| goal | number | ✅ | - | 목표치 |
| difficulty | string | ✅ | 'normal' | 난이도 (easy/normal/hard) |
| reward | map | ✅ | - | 보상 ({ type: 'coupon', id: '...', count: 1 }) |
| frequency | string | ✅ | 'daily' | 주기 (daily/weekly/monthly/once) |
| startDate | timestamp | ❌ | null | 시작일 (null = 즉시) |
| endDate | timestamp | ❌ | null | 종료일 (null = 무제한) |
| isActive | boolean | ✅ | true | 활성화 여부 |
| createdAt | timestamp | ✅ | serverTimestamp() | 생성일 |

### 예시

```json
{
  "missionId": "mission_daily_steps_5000",
  "title": "오늘 5,000보 걷기",
  "description": "오늘 하루 5,000보를 걸어보세요!",
  "type": "steps",
  "goal": 5000,
  "difficulty": "normal",
  "reward": {
    "type": "coupon",
    "id": "coupon_cafe_americano",
    "count": 1
  },
  "frequency": "daily",
  "startDate": null,
  "endDate": null,
  "isActive": true,
  "createdAt": "2024-12-01T00:00:00Z"
}
```

---

## 5. places (매장)

**경로**: `/places/{placeId}`  
**설명**: 가맹점 정보 (관리자 등록)

### 필드

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| placeId | string | ✅ | - | 매장 ID |
| name | string | ✅ | - | 매장명 |
| address | string | ✅ | - | 주소 |
| lat | number | ✅ | - | 위도 |
| lng | number | ✅ | - | 경도 |
| category | string | ✅ | - | 카테고리 (food/cafe/convenience) |
| phone | string | ❌ | null | 전화번호 |
| hours | string | ❌ | null | 영업시간 |
| photos | array | ✅ | [] | 사진 URL 배열 |
| logo | string | ❌ | null | 로고 URL |
| availableCoupons | array | ✅ | [] | 사용 가능 쿠폰 ID 배열 |
| rating | number | ✅ | 0 | 평점 (0-5) |
| reviewCount | number | ✅ | 0 | 리뷰 개수 |
| isActive | boolean | ✅ | true | 활성화 여부 |
| createdAt | timestamp | ✅ | serverTimestamp() | 등록일 |

### 예시

```json
{
  "placeId": "place_001",
  "name": "남구카페",
  "address": "부산 남구 문현동 123-45",
  "lat": 35.1357,
  "lng": 129.0828,
  "category": "cafe",
  "phone": "051-123-4567",
  "hours": "09:00-22:00",
  "photos": ["gs://.../places/place_001/1.jpg"],
  "logo": "gs://.../places/place_001/logo.jpg",
  "availableCoupons": ["coupon_cafe_americano"],
  "rating": 4.5,
  "reviewCount": 128,
  "isActive": true,
  "createdAt": "2024-12-01T00:00:00Z"
}
```

---

## 6. events (이벤트 로그)

**경로**: `/events/{eventId}`  
**설명**: 모든 사용자 행동 로그 (분석용, 클라이언트 접근 불가)

### 필드

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| eventId | string | ✅ | auto | 이벤트 ID |
| userId | string | ✅ | - | 사용자 UID |
| eventType | string | ✅ | - | 이벤트 유형 (coupon_issued/coupon_used/mission_completed 등) |
| eventData | map | ✅ | - | 이벤트 세부 데이터 |
| timestamp | timestamp | ✅ | serverTimestamp() | 발생 시각 |

### 예시

```json
{
  "eventId": "evt_20241222_001",
  "userId": "abc123",
  "eventType": "coupon_used",
  "eventData": {
    "couponId": "coupon_cafe_americano",
    "placeId": "place_001",
    "discount": 0,
    "verificationCode": "1234"
  },
  "timestamp": "2024-12-22T10:30:00Z"
}
```

---

## 7. notifications (공지사항)

**경로**: `/notifications/{notificationId}`  
**설명**: 전체 공지사항 (관리자 작성)

### 필드

| 필드명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| notificationId | string | ✅ | auto | 공지 ID |
| title | string | ✅ | - | 제목 |
| body | string | ✅ | - | 본문 |
| type | string | ✅ | 'notice' | 유형 (notice/event/maintenance) |
| imageUrl | string | ❌ | null | 이미지 URL |
| linkUrl | string | ❌ | null | 링크 URL |
| startDate | timestamp | ❌ | null | 게시 시작일 |
| endDate | timestamp | ❌ | null | 게시 종료일 |
| isActive | boolean | ✅ | true | 활성화 여부 |
| createdAt | timestamp | ✅ | serverTimestamp() | 작성일 |

---

## 8. 인덱스 설정

### 8.1 복합 인덱스

Firebase 콘솔 또는 CLI로 다음 인덱스 생성:

```javascript
// users/{uid}/myCoupons
// 쿠폰 목록 조회 (상태별 정렬)
{
  collectionGroup: "myCoupons",
  fields: [
    { fieldPath: "status", order: "ASCENDING" },
    { fieldPath: "validUntil", order: "ASCENDING" }
  ]
}

// users/{uid}/myMissions
// 미션 목록 조회 (상태별 정렬)
{
  collectionGroup: "myMissions",
  fields: [
    { fieldPath: "status", order: "ASCENDING" },
    { fieldPath: "expiresAt", order: "ASCENDING" }
  ]
}

// places
// 지도 반경 검색 (카테고리별)
{
  collection: "places",
  fields: [
    { fieldPath: "category", order: "ASCENDING" },
    { fieldPath: "lat", order: "ASCENDING" },
    { fieldPath: "lng", order: "ASCENDING" }
  ]
}

// events
// 사용자별 이벤트 로그 조회
{
  collection: "events",
  fields: [
    { fieldPath: "userId", order: "ASCENDING" },
    { fieldPath: "timestamp", order: "DESCENDING" }
  ]
}
```

### 8.2 단일 필드 인덱스

Firestore는 자동으로 생성하지만, 명시적으로 생성 권장:

- `users.nickname` (중복 체크)
- `users.friendInviteCode` (초대 코드 조회)
- `coupons.isActive` (활성 쿠폰)
- `missions.isActive` (활성 미션)
- `places.isActive` (활성 매장)

---

## 9. 데이터 흐름 예시

### 9.1 쿠폰 발급 및 사용 플로우

```
1. 미션 완료
   → completeMission Cloud Function 트리거
   → users/{uid}/myMissions/{id} 상태 'completed'로 변경
   
2. 쿠폰 자동 발급
   → issueCoupon Cloud Function 호출
   → coupons/{couponId} 템플릿 조회
   → users/{uid}/myCoupons/{newId} 생성
   → verificationCode 자동 생성 (4자리)
   → 푸시 알림 발송
   
3. 쿠폰 사용
   → 사용자가 "사용하기" 버튼 클릭
   → 4자리 코드 표시
   → 매장 직원이 코드 입력
   → useCoupon Cloud Function 호출
   → 트랜잭션으로 쿠폰 상태 'used'로 변경
   → events 로그 기록
   → 푸시 알림 발송
```

---

## 10. 마이그레이션 계획

### 10.1 기존 Unity 앱(한국지) 데이터 참고

기존 `hankookji-demo` 프로젝트의 `users`, `places` 구조 참고:

```javascript
// 기존 users 구조 재사용 가능
// - uid, email, nickname, createdAt, lastLogin
// - totalSteps, todaySteps (추가)

// 기존 places 구조 재사용
// - name, address, lat, lng, category
// - availableCoupons[] (추가)

// 신규 컬렉션
// - coupons (템플릿)
// - missions (템플릿)
// - users/{uid}/myCoupons (서브컬렉션)
// - users/{uid}/myMissions (서브컬렉션)
```

---

## 11. 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 1.0 | 2024-12-22 | 초안 작성 |

---

**문서 끝**

