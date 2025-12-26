# Flutter 개발 컨벤션

## 📋 일반 규칙

### 1. 파일 구조
```dart
// ✅ DO: 임포트 순서 지키기
import 'dart:async';           // Dart SDK
import 'dart:io';

import 'package:flutter/material.dart';  // Flutter
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';  // 외부 패키지
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user.dart';   // 프로젝트 내부
import '../theme/app_colors.dart';
import '../widgets/app_button.dart';
```

### 2. 클래스 명명
```dart
// ✅ DO: PascalCase for classes
class UserProfile extends StatelessWidget {}
class AuthService {}
class CouponModel {}

// ❌ DON'T
class userProfile {}  // 소문자 시작
class auth_service {}  // 언더스코어
```

### 3. 변수 & 함수 명명
```dart
// ✅ DO: camelCase for variables and functions
final String userName = 'John';
int getUserAge() => 25;
bool isLoggedIn = false;

// ✅ DO: 상수는 lowerCamelCase (k prefix 또는 그냥 camelCase)
const double kDefaultPadding = 16.0;
const int maxRetries = 3;

// ❌ DON'T
final String UserName = 'John';  // PascalCase
final String user_name = 'John';  // snake_case
```

## 🎨 위젯 개발

### 1. StatelessWidget vs StatefulWidget
```dart
// ✅ DO: 상태가 없으면 StatelessWidget
class CouponCard extends StatelessWidget {
  const CouponCard({
    Key? key,
    required this.title,
    this.onTap,
  }) : super(key: key);

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}

// ✅ DO: 상태가 있으면 StatefulWidget
class MissionProgress extends StatefulWidget {
  const MissionProgress({Key? key}) : super(key: key);

  @override
  State<MissionProgress> createState() => _MissionProgressState();
}

class _MissionProgressState extends State<MissionProgress> {
  double _progress = 0.0;

  void _updateProgress(double value) {
    setState(() {
      _progress = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(value: _progress);
  }
}
```

### 2. const 생성자 사용
```dart
// ✅ DO: 변경 불가능한 위젯은 const 사용
const SizedBox(height: 16);
const Divider();
const Icon(Icons.check);

// ✅ DO: const 생성자 제공
class MyWidget extends StatelessWidget {
  const MyWidget({Key? key}) : super(key: key);  // const 생성자
}

// ❌ DON'T: const를 쓸 수 있는데 안 쓰기
SizedBox(height: 16);  // const 누락
```

### 3. BuildContext 사용
```dart
// ✅ DO: Theme, MediaQuery는 BuildContext에서
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final screenWidth = MediaQuery.of(context).size.width;
  
  return Container(
    color: colors.primary,
    width: screenWidth * 0.8,
  );
}

// ❌ DON'T: 하드코딩
Widget build(BuildContext context) {
  return Container(
    color: Color(0xFF4CAF50),  // 하드코딩된 색상
    width: 300,  // 하드코딩된 크기
  );
}
```

## 🎨 디자인 시스템 사용

### 1. 색상
```dart
import '../theme/app_colors.dart';

// ✅ DO: AppColors 사용
Container(
  color: AppColors.primary500,
  child: Text(
    'Hello',
    style: TextStyle(color: AppColors.neutral0),
  ),
)

// ❌ DON'T: 직접 색상 코드 사용
Container(
  color: Color(0xFF4CAF50),  // ❌
  child: Text(
    'Hello',
    style: TextStyle(color: Colors.white),  // ❌
  ),
)
```

### 2. 타이포그래피
```dart
import '../theme/app_typography.dart';

// ✅ DO: AppTypography 사용
Text(
  '남구이야기',
  style: AppTypography.heading1,
)

Text(
  '설명 텍스트',
  style: AppTypography.bodyMedium,
)

// ❌ DON'T: 직접 TextStyle 정의
Text(
  '남구이야기',
  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),  // ❌
)
```

### 3. 간격
```dart
import '../theme/app_spacing.dart';

// ✅ DO: AppSpacing 사용
Padding(
  padding: EdgeInsets.all(AppSpacing.paddingM),
  child: Column(
    children: [
      Text('제목'),
      SizedBox(height: AppSpacing.paddingS),
      Text('내용'),
    ],
  ),
)

// ❌ DON'T: 매직 넘버 사용
Padding(
  padding: EdgeInsets.all(16),  // ❌
  child: Column(
    children: [
      Text('제목'),
      SizedBox(height: 8),  // ❌
      Text('내용'),
    ],
  ),
)
```

## 🧩 공통 컴포넌트 사용

### 1. AppButton
```dart
import '../widgets/app_button.dart';

// ✅ DO: AppButton 사용
AppButton(
  text: '로그인',
  onPressed: _handleLogin,
  variant: ButtonVariant.primary,
  size: ButtonSize.large,
)

// ❌ DON'T: 직접 ElevatedButton 생성
ElevatedButton(
  onPressed: _handleLogin,
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.green,
    // ... 매번 스타일 정의
  ),
  child: Text('로그인'),
)
```

### 2. AppInput
```dart
import '../widgets/app_input.dart';

// ✅ DO: AppInput 사용
AppInput(
  label: '이메일',
  placeholder: 'example@email.com',
  onChanged: (value) => _email = value,
  errorText: _emailError,
  prefixIcon: Icons.email,
)

// ❌ DON'T: 직접 TextField 생성
TextField(
  decoration: InputDecoration(
    labelText: '이메일',
    hintText: 'example@email.com',
    // ... 매번 decoration 정의
  ),
)
```

## 📦 상태 관리 (Riverpod)

### 1. Provider 정의
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ DO: Provider는 최상위 레벨에
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

final userProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ❌ DON'T: 클래스 내부에 Provider 정의
class MyWidget extends ConsumerWidget {
  final provider = Provider(...);  // ❌
}
```

### 2. ConsumerWidget 사용
```dart
// ✅ DO: 상태를 읽어야 할 때 ConsumerWidget
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    
    return user.when(
      data: (user) => Text(user?.displayName ?? '게스트'),
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => Text('오류: $err'),
    );
  }
}

// ✅ DO: Consumer로 부분 리빌드
class CouponList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('내 쿠폰'),  // 리빌드 안 됨
        Consumer(
          builder: (context, ref, child) {
            final coupons = ref.watch(couponProvider);  // 이 부분만 리빌드
            return ListView.builder(...);
          },
        ),
      ],
    );
  }
}
```

## 🔥 Firebase 사용

### 1. Firestore 쿼리
```dart
// ✅ DO: 타입 안전한 쿼리
Future<List<Coupon>> getCoupons(String userId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('myCoupons')
      .where('status', isEqualTo: 'active')
      .orderBy('validUntil')
      .get();

  return snapshot.docs
      .map((doc) => Coupon.fromFirestore(doc))
      .toList();
}

// ✅ DO: Stream으로 실시간 업데이트
Stream<List<Coupon>> watchCoupons(String userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('myCoupons')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Coupon.fromFirestore(doc))
          .toList());
}
```

### 2. 에러 처리
```dart
// ✅ DO: try-catch와 구체적인 에러 처리
Future<void> loginWithEmail(String email, String password) async {
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') {
      throw '등록되지 않은 이메일입니다.';
    } else if (e.code == 'wrong-password') {
      throw '비밀번호가 올바르지 않습니다.';
    } else {
      throw '로그인 실패: ${e.message}';
    }
  } catch (e) {
    throw '알 수 없는 오류: $e';
  }
}

// ❌ DON'T: 에러를 무시하거나 일반적으로만 처리
Future<void> loginWithEmail(String email, String password) async {
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  } catch (e) {
    print(e);  // ❌ 단순 print만
  }
}
```

## 🚀 비동기 처리

### 1. async/await
```dart
// ✅ DO: async/await 사용
Future<void> loadData() async {
  setState(() => _isLoading = true);
  
  try {
    final data = await apiService.fetchData();
    setState(() {
      _data = data;
      _isLoading = false;
    });
  } catch (e) {
    setState(() {
      _error = e.toString();
      _isLoading = false;
    });
  }
}

// ❌ DON'T: then 체인
Future<void> loadData() {
  setState(() => _isLoading = true);
  
  return apiService.fetchData().then((data) {
    setState(() {
      _data = data;
      _isLoading = false;
    });
  }).catchError((e) {
    setState(() {
      _error = e.toString();
      _isLoading = false;
    });
  });
}
```

### 2. FutureBuilder / StreamBuilder
```dart
// ✅ DO: FutureBuilder로 비동기 UI
class UserProfile extends StatelessWidget {
  final Future<User> userFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User>(
      future: userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppLoading();
        }
        
        if (snapshot.hasError) {
          return Text('오류: ${snapshot.error}');
        }
        
        final user = snapshot.data!;
        return Text(user.name);
      },
    );
  }
}

// ✅ DO: StreamBuilder로 실시간 업데이트
class CouponList extends StatelessWidget {
  final Stream<List<Coupon>> couponStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Coupon>>(
      stream: couponStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return AppLoading();
        }
        
        final coupons = snapshot.data!;
        return ListView.builder(
          itemCount: coupons.length,
          itemBuilder: (context, index) => CouponCard(
            coupon: coupons[index],
          ),
        );
      },
    );
  }
}
```

## 🧪 테스트 가능한 코드

### 1. 의존성 주입
```dart
// ✅ DO: 의존성을 생성자로 주입
class CouponService {
  CouponService(this._firestore);
  
  final FirebaseFirestore _firestore;
  
  Future<List<Coupon>> getCoupons(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('myCoupons')
        .get();
    return snapshot.docs.map((doc) => Coupon.fromFirestore(doc)).toList();
  }
}

// ❌ DON'T: 직접 인스턴스 생성
class CouponService {
  Future<List<Coupon>> getCoupons(String userId) async {
    final snapshot = await FirebaseFirestore.instance  // ❌ 하드코딩
        .collection('users')
        .doc(userId)
        .collection('myCoupons')
        .get();
    return snapshot.docs.map((doc) => Coupon.fromFirestore(doc)).toList();
  }
}
```

## 📝 주석

```dart
// ✅ DO: 복잡한 로직에 주석 추가
/// 사용자의 완료된 미션 수를 계산합니다.
/// 
/// [userId]: 사용자 ID
/// [startDate]: 집계 시작일 (포함)
/// [endDate]: 집계 종료일 (포함)
/// 
/// Returns: 완료된 미션 개수
Future<int> countCompletedMissions(
  String userId,
  DateTime startDate,
  DateTime endDate,
) async {
  // Firestore에서 완료된 미션만 필터링
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('missions')
      .where('status', isEqualTo: 'completed')
      .where('completedAt', isGreaterThanOrEqualTo: startDate)
      .where('completedAt', isLessThanOrEqualTo: endDate)
      .get();

  return snapshot.size;
}

// ✅ DO: TODO 주석으로 추후 작업 표시
// TODO(작성자): 쿠폰 만료 알림 기능 추가
// FIXME: 네트워크 오류 시 재시도 로직 필요
```

## ⚡ 성능 최적화

### 1. ListView.builder 사용
```dart
// ✅ DO: ListView.builder로 lazy loading
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ItemCard(item: items[index]);
  },
)

// ❌ DON'T: ListView에 모든 아이템 미리 생성
ListView(
  children: items.map((item) => ItemCard(item: item)).toList(),  // ❌
)
```

### 2. const 위젯 재사용
```dart
// ✅ DO: const로 재사용
class MyScreen extends StatelessWidget {
  static const _divider = Divider();  // 한 번만 생성
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('A'),
        _divider,  // 재사용
        Text('B'),
        _divider,  // 재사용
      ],
    );
  }
}
```

---

이 컨벤션을 따라 일관성 있고 유지보수 가능한 Flutter 코드를 작성하세요!

