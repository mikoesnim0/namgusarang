# Firestore Rules 패치 가이드 (친구 시스템용)

> 주의: 현재 프로젝트의 기존 Rules(쿠폰/places/users 등)를 **그대로 유지**하면서,  
> 친구 시스템에 필요한 **read 권한**만 최소로 추가하는 용도입니다.  
> 친구 요청/수락/삭제/닉네임 변경 등의 **write는 Cloud Functions(Admin SDK)**가 수행하므로, 클라이언트 write는 막는 것을 권장합니다.

## 목표
- `public_users/{uid}`: 로그인 사용자라면 읽기 가능(닉네임 검색/표시)
- `usernames/{nicknameLower}`: 로그인 사용자라면 읽기 가능(닉네임 → uid lookup)
- `users/{uid}/friends`, `friend_requests_in`, `friend_requests_out`: 본인만 읽기 가능(스트림)
- 위 컬렉션들은 클라이언트 write 금지(Functions만)

## Rules에 추가할 블록(예시)

이미 `rules_version = '2'; service cloud.firestore { ... }` 구조가 있다고 가정합니다.

```rules
function signedIn() { return request.auth != null; }
function isOwner(uid) { return signedIn() && request.auth.uid == uid; }

match /public_users/{uid} {
  // MVP: 로그인 사용자 전체에게 공개(검색/표시)
  allow read: if signedIn();
  allow write: if false; // Functions only
}

match /usernames/{nicknameLower} {
  allow read: if signedIn(); // 닉네임 검색(정확 일치) 지원
  allow write: if false; // Functions only
}

match /users/{uid} {
  // 기존 프로젝트에서 users/{uid} read/write 정책이 이미 있으면 그대로 두고,
  // 아래 subcollection read만 추가해도 됩니다.

  match /friends/{docId} {
    allow read: if isOwner(uid);
    allow write: if false; // Functions only
  }

  match /friend_requests_in/{docId} {
    allow read: if isOwner(uid);
    allow write: if false; // Functions only
  }

  match /friend_requests_out/{docId} {
    allow read: if isOwner(uid);
    allow write: if false; // Functions only
  }
}
```

## 체크 방법
1) 앱 로그인 후 “친구목록” 탭 진입
2) 보낸/받은 요청이 permission-denied 없이 로드되는지 확인
3) 친구 요청 보내기(닉네임/초대코드) → Functions 호출이 성공하는지 확인

