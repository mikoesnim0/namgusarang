# Firebase(Firestore) + Flutter 친구 시스템 계획서 (uid 기반 / 양방향 / 닉네임 변경 가능)

> 목표: 현재 앱의 “더미 친구 기능”을 **프로덕션 운영 가능한 구조**로 교체합니다.  
> 전제: 닉네임 변경 가능 / 친구는 양방향 / 프로필 최신은 **하루 1회 캐시 갱신**이면 충분.

---

## 0) 사용자 UX (고정 6개)

1. 친구 요청 보내기
2. 받은 요청 목록 보기(실시간)
3. 보낸 요청 목록 보기(실시간)
4. 요청 수락
5. 요청 거절/취소
6. 친구 삭제

추가(운영 필수)
- 닉네임 검색(유니크, 변경 가능)
- 배지: 받은 요청 1개 이상이면 빨간 점

---

## 1) 데이터 구조 (uid 기반 / docId는 uid로 고정)

### 1.1 users (내 프로필, 민감정보 포함 가능)

`users/{uid}`
- `nickname` (string, required)
- `nicknameLower` (string, required)  // 검색용 정규화
- `photoUrl` (string, optional)
- `level` (number, optional)
- `profileIndex` (number, optional)
- `createdAt` (timestamp, server)
- `updatedAt` (timestamp, server)

### 1.2 public_users (검색/친구 UI용 공개 프로필)

`public_users/{uid}`
- `uid` (string, required)
- `nickname` (string, required)
- `nicknameLower` (string, required)
- `photoUrl` (string, optional)
- `level` (number, optional)
- `profileIndex` (number, optional)
- `updatedAt` (timestamp, server)

> 의도: 친구/검색에 필요한 필드만 공개. `users/{uid}`는 “본인만 읽기”로 유지 가능.

### 1.3 usernames (닉네임 유니크 + nickname→uid 조회)

`usernames/{nicknameLower}`
- docId = `nicknameLower`
- `uid` (string, required)
- `createdAt` (timestamp, server)
- `updatedAt` (timestamp, server)

### 1.4 받은 요청(incoming)

`users/{uid}/friend_requests_in/{fromUid}`
- docId = `fromUid`
- `fromUid` (string, required)
- `fromNickname` (string, required)   // 표시용 스냅샷(캐시)
- `fromPhotoUrl` (string, optional)
- `fromLevel` (number, optional)
- `fromProfileIndex` (number, optional)
- `createdAt` (timestamp, server)

### 1.5 보낸 요청(outgoing)

`users/{uid}/friend_requests_out/{toUid}`
- docId = `toUid`
- `toUid` (string, required)
- `toNickname` (string, required)     // 표시용 스냅샷(캐시)
- `toPhotoUrl` (string, optional)
- `createdAt` (timestamp, server)

### 1.6 친구 목록(friends)

`users/{uid}/friends/{friendUid}`
- docId = `friendUid`
- `friendUid` (string, required)
- `friendNickname` (string, required) // 표시용 캐시
- `friendPhotoUrl` (string, optional)
- `friendLevel` (number, optional)
- `friendProfileIndex` (number, optional)
- `createdAt` (timestamp, server)
- `snapshotAt` (timestamp, server)    // 캐시 생성/갱신 시각(24h 기준)

---

## 2) 상태 전이(정합성) 규칙

### 2.1 친구 요청 보내기 (Send)

필수 체크:
- `fromUid != toUid`
- 이미 친구면 불가: `users/{fromUid}/friends/{toUid}` 존재 → reject
- 이미 pending이면 불가:
  - `users/{toUid}/friend_requests_in/{fromUid}` 존재 → reject
  - `users/{fromUid}/friend_requests_out/{toUid}` 존재 → reject

원자적 쓰기(2개 생성):
- `users/{toUid}/friend_requests_in/{fromUid}`
- `users/{fromUid}/friend_requests_out/{toUid}`

### 2.2 수락(Accept)

원자적 쓰기(4개):
- friends 2개 생성
  - `users/{fromUid}/friends/{toUid}`
  - `users/{toUid}/friends/{fromUid}`
- request 2개 삭제
  - `users/{toUid}/friend_requests_in/{fromUid}`
  - `users/{fromUid}/friend_requests_out/{toUid}`

### 2.3 거절/취소(Decline/Cancel)

원자적 삭제(2개):
- `users/{toUid}/friend_requests_in/{fromUid}`
- `users/{fromUid}/friend_requests_out/{toUid}`

### 2.4 친구 삭제(Remove)

원자적 삭제(2개):
- `users/{uid}/friends/{friendUid}`
- `users/{friendUid}/friends/{uid}`

---

## 3) 구현 방식 (권장: Cloud Functions + Rules)

### 3.1 원칙
- Flutter는 **읽기(Stream)**만 Firestore에서 직접 수행
- 모든 상태변경(요청/수락/삭제/닉네임 변경)은 **Callable Functions**로만 수행
- Firestore Rules는 “클라 쓰기 차단”을 기본값으로 둬서 치팅/정합성 문제를 줄임

### 3.2 Callable Functions API (제안)

#### 친구
- `sendFriendRequestByUid({ toUid })`
- `sendFriendRequestByNickname({ nickname })`
- `acceptFriendRequest({ fromUid })`
- `declineFriendRequest({ fromUid })`
- `cancelFriendRequest({ toUid })`
- `removeFriend({ friendUid })`

#### 닉네임 변경(필수)
- `changeNickname({ nickname })`
  - `usernames/{newLower}` 선점 + `public_users/{uid}`/`users/{uid}` 업데이트

#### (선택) 캐시 갱신(하루 1회)
- `refreshFriendCache({ friendUid })`
  - `public_users/{friendUid}` 읽어서
  - `users/{uid}/friends/{friendUid}`의 표시 캐시와 `snapshotAt` 갱신

> “하루 1회 정도” 요구사항이면, Flutter에서 `public_users/{friendUid}`를 필요 시 1회 get() 해서 화면에만 반영하는 방식도 가능(서버 쓰기 없이).

---

## 4) Firestore Rules (권장안: 쓰기 = Functions만)

핵심 아이디어:
- `users/{uid}` 및 하위컬렉션은 **본인만 read**
- `public_users/{uid}`는 **로그인 사용자 전체 read**(간단) 또는 **친구만 read**(더 엄격)
- `usernames/{nicknameLower}`는 검색을 위해 signed-in read 허용
- write는 모두 false (Admin SDK만 작성)

> 실제 Rules 파일은 `firestore.rules` 기준으로 추가/반영하며, 운영 단계에서 더 엄격하게 조정합니다.

---

## 5) Flutter 구조(권장 레이어)

### 5.1 모델
- `Friend`
- `FriendRequestIn`
- `FriendRequestOut`
- `PublicUser` (검색/표시)

### 5.2 Repository

Streams:
- `watchFriends(uid)`
- `watchIncomingRequests(uid)`
- `watchOutgoingRequests(uid)`
- `watchIncomingCount(uid)` (배지용)

Commands(Functions 호출):
- `sendRequestByUid(toUid)`
- `sendRequestByNickname(nickname)`
- `accept(fromUid)`
- `decline(fromUid)`
- `cancel(toUid)`
- `removeFriend(friendUid)`
- `changeNickname(newNickname)`

### 5.3 Riverpod Provider 설계(예)
- `friendsStreamProvider`
- `incomingRequestsStreamProvider`
- `outgoingRequestsStreamProvider`
- `incomingBadgeCountProvider`
- `friendsCommandControllerProvider` (AsyncNotifier)

### 5.4 UI 매핑
- FriendsScreen: 친구 목록 + 검색/초대(닉네임) + 배지(받은 요청 수)
- RequestsScreen: Incoming/Outgoing 탭 + 수락/거절/취소

---

## 6) 닉네임 정규화 규칙(필수로 고정)

권장 정책(간단/안전):
- trim
- 모든 공백 제거(또는 단일 공백으로 축약) 중 택1
- 소문자(lowercase)
- 허용문자: `[0-9A-Za-z가-힣]` (2~12자)  // 이미 앱에서 쓰는 패턴과 정합

정규화 함수 결과 = `nicknameLower`

---

## 7) 단계별 구현 플랜 (MVP → 운영)

### Phase 0 (준비)
- `public_users`, `usernames` 컬렉션 도입
- 회원가입/로그인 시 프로필 문서 생성/업데이트 흐름 정리

### Phase 1 (읽기/화면)
- Firestore에 “내 friends / in / out” 구조로 샘플 데이터 시드
- Flutter에서 Stream으로 목록/배지 표시(더미 제거)

### Phase 2 (쓰기/정합성)
- Functions 6개 구현 + 에러코드(이미 친구/중복요청/없는유저)
- Flutter Commands 연결(버튼/다이얼로그)

### Phase 3 (닉네임 변경)
- `changeNickname` Functions + usernames 유니크 보장

### Phase 4 (캐시 최적화)
- “하루 1회 캐시 갱신” 로직 적용(클라 get 또는 refreshFriendCache)

---

## 8) 완료 기준(완성도 체크)

- [ ] 친구 요청/수락/거절/취소/삭제가 **양쪽 문서 정합성 100%**로 유지
- [ ] 닉네임 변경 후에도 기존 관계/요청이 깨지지 않음(문서 id는 uid 기반)
- [ ] 받은 요청 배지(카운트) 표시
- [ ] 권한/보안: 클라이언트에서 상대 문서 임의 쓰기 불가

