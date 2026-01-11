import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithCustomToken(String token) {
    return _auth.signInWithCustomToken(token);
  }

  Future<void> signOut() => _auth.signOut();
}

