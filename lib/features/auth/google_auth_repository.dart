import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthRepository {
  GoogleSignIn _googleSignIn() => GoogleSignIn(
        scopes: const <String>[
          'email',
          'profile',
        ],
      );

  /// Returns a Firebase AuthCredential for Google sign-in.
  /// NOTE: google_sign_in does not support macOS; disable in UI for macOS.
  Future<AuthCredential> getFirebaseCredential() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      throw UnsupportedError('Google login is not supported on macOS in this app.');
    }

    final googleUser = await _googleSignIn().signIn();
    if (googleUser == null) {
      throw StateError('Google sign-in was cancelled.');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google sign-in failed: idToken missing.');
    }
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Google sign-in failed: accessToken missing.');
    }

    return GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );
  }
}

