import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart' as fcm;
import 'package:flutter/foundation.dart';

import '../settings/settings_model.dart';

class PushNotificationsService {
  static const topicMission = 'push_mission';
  static const topicCoupon = 'push_coupon';
  static const topicEvent = 'push_event';

  fcm.FirebaseMessaging get _messaging => fcm.FirebaseMessaging.instance;

  Future<fcm.AuthorizationStatus> ensurePermissionRequested() async {
    if (kIsWeb) return fcm.AuthorizationStatus.notDetermined;
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus;
  }

  Future<String?> ensureTokenStored({required String uid}) async {
    if (kIsWeb) return null;
    final token = await _messaging.getToken();
    if (token == null) return null;
    if (uid.trim().isEmpty || uid == '(unknown)') return token;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('fcm_tokens')
          .doc(token)
          .set(
        <String, Object?>{
          'token': token,
          'platform': Platform.isIOS
              ? 'ios'
              : (Platform.isAndroid ? 'android' : 'other'),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Best-effort only. Firestore rules may block token writes in some environments.
    }

    return token;
  }

  Future<void> syncTopics({
    required NotificationSettings settings,
    required String uid,
    bool requestPermission = true,
  }) async {
    if (kIsWeb) return;

    // On Android 13+ and iOS, this prompts for notification permission (if needed).
    if (requestPermission) {
      await ensurePermissionRequested();
    }
    await ensureTokenStored(uid: uid);

    await _setTopic(topicMission, settings.mission);
    await _setTopic(topicCoupon, settings.coupon);
    await _setTopic(topicEvent, settings.eventBenefit);
  }

  Future<void> _setTopic(String topic, bool enabled) async {
    try {
      if (enabled) {
        await _messaging.subscribeToTopic(topic);
      } else {
        await _messaging.unsubscribeFromTopic(topic);
      }
    } catch (_) {
      // Swallow: topic subscription failures shouldn't break the UI.
    }
  }
}
