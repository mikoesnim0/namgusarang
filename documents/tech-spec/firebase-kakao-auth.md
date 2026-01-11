# Firebase + Kakao 로그인 연동 (Custom Token 방식)

## 목표
- Flutter에서 **카카오 로그인 성공** → Kakao `accessToken` 획득
- Firebase Cloud Functions(Callable)로 `accessToken` 전달
- Functions가 Kakao API로 토큰 검증/유저 식별 → Firebase **Custom Token 발급**
- Flutter에서 `signInWithCustomToken()`으로 **Firebase Auth 세션 확립**

## 클라이언트(Flutter) 동작
- 패키지: `kakao_flutter_sdk_user`, `cloud_functions`, `firebase_auth`
- Callable 함수: `authWithKakao`
- 요청:

```json
{ "accessToken": "kakao_access_token" }
```

- 응답:

```json
{ "firebaseToken": "firebase_custom_token" }
```

> 앱에서는 `firebaseToken`을 받아 `FirebaseAuth.instance.signInWithCustomToken(firebaseToken)` 호출

## 서버(Firebase Functions) 구현 개요
- Region: `asia-northeast3`
- Callable: `authWithKakao`
- 처리:
  - Kakao `accessToken`으로 `https://kapi.kakao.com/v2/user/me` 호출
  - 응답에서 `id`(kakao user id), `kakao_account.email` 등 추출
  - Firebase Admin SDK로 `uid = "kakao:{kakaoId}"` 형태로 Custom Token 생성
  - 반환: `{ firebaseToken }`

## 권장 UID 정책
- `uid = "kakao:{kakaoId}"` (provider prefix 강제)
  - 이메일 변경/탈퇴/재가입에도 Kakao 계정 기준으로 안정적

## 보안/운영 포인트
- **클라이언트에서 Firestore 권한을 과하게 주지 말 것**
- 쿠폰 사용/발급/미션 완료 같은 검증은 Cloud Functions 트랜잭션으로 처리(치팅 방지)
- 카카오 이메일 제공은 사용자 동의/스코프 설정에 따라 null 가능 → email은 optional 처리

