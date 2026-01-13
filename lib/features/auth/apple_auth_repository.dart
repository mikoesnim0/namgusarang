import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuthRepository {
  /// Returns a Firebase AuthCredential for Apple sign-in.
  Future<AuthCredential> getFirebaseCredential() async {
    if (kIsWeb) {
      throw UnsupportedError('Apple login is not implemented for web in this app.');
    }
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      throw UnsupportedError('Apple login is only supported on iOS/macOS.');
    }

    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleIDCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final idToken = appleIDCredential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Apple sign-in failed: identityToken missing.');
    }

    return OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
      // authorizationCode isn't always required, but pass when available.
      accessToken: appleIDCredential.authorizationCode,
    );
  }
}

String _sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

String _generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)])
      .join();
}

