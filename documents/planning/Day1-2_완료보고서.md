# 남구이야기 앱 개발 Day 1-2 완료 보고서

**기준일**: 2025-12-22  
**범위**: Phase 0(기획/설계) + Phase 1(프로젝트 세팅)  
**출시 목표**: 2026-02-20 (MVP)

---

## 1. 요약

- 기획/기술/데이터 기준 문서 작성 및 일정/로그 체계 정리
- Flutter 프로젝트(`namgusarang/`) 기반 환경 구성 및 Firebase 기본 연동(FlutterFire)
- 이후 개발이 흔들리지 않도록 “범위/일정/검수 기준”을 문서로 고정

---

## 2. 완료 산출물

### 2.1 문서

- 추진계획서: `./프로젝트_추진계획서_v1.0.md`
- PRD: `../prd/남구이야기_PRD_v1.0.md`
- 기술명세서: `../tech-spec/기술명세서_v1.0.md`
- Firebase+Kakao 인증: `../tech-spec/firebase-kakao-auth.md`
- Firestore 스키마: `../data-model/firestore-schema.md`
- 개발 일정(9주 원안): `./개발일정표_v1.0.md`
- 달력형 일정(집중 6주): `./달력형_일정표_v1.0_revised.md`
- 작업 로그: `./작업로그.md`

### 2.2 코드/환경

- Flutter 앱: `../../` (프로젝트 루트: `namgusarang/`)
- 패키지명: `com.doyakmin.hangookji.namgu`
- Firebase Project ID: `hankookji-namgu`
- Firebase 연동 산출물(예):
  - Android: `../../android/app/google-services.json`
  - iOS: `../../ios/Runner/GoogleService-Info.plist`
  - FlutterFire: `../../lib/firebase_options.dart`
- Cloud Functions(예): `../../functions/`

---

## 3. 주요 결정 사항(요약)

- **기술 스택**: Flutter + Firebase(Auth/Firestore/Functions/Storage/FCM)
- **인증 정책**: 카카오 로그인은 Custom Token 방식(서버에서 토큰 검증 후 세션 확립)
- **검증 원칙**: 쿠폰 사용/발급, 미션 완료 같은 “치팅 방지/중복 방지” 로직은 Functions 중심
- **일정 운영**: 주차(W1~W6) 기준 마일스톤 + 검토 게이트(분석검토/설계검토/최종검수)

---

## 4. 다음 단계(Day 3~)

우선순위는 “출시 필수 플로우”를 먼저 완결합니다.

1. 인증 완결
   - 이메일/비밀번호, 카카오 로그인
   - `/users/{uid}` 생성/갱신 및 최소 프로필 흐름 확정
2. 쿠폰 기능 1차 완결
   - 목록/상세/사용(4자리 코드) + 서버 검증
3. 미션 기능 1차 완결
   - 걸음 수 연동 → 진행률/완료 → 보상(쿠폰) 지급
4. 지도/알림
   - 매장 표시/검색(최소) + FCM 푸시
5. QA/배포/검수 준비
   - 테스트 체크리스트, 빌드/심사 제출, 운영/기술이전 문서

---

## 5. 참고

- 프로젝트 README: `../../README.md`

