import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum StepsPermissionStatus {
  granted,
  denied,
  restricted,
  unknown,
  notSupported,
}

class StepsRepository {
  static const _methodChannel =
      MethodChannel('com.doyakmin.hangookji.namgu/steps');
  static const _eventChannel =
      EventChannel('com.doyakmin.hangookji.namgu/steps_stream');

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<bool> isAvailable() async {
    if (!_isSupportedPlatform) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<StepsPermissionStatus> getPermissionStatus() async {
    if (!_isSupportedPlatform) return StepsPermissionStatus.notSupported;
    try {
      final raw =
          await _methodChannel.invokeMethod<String>('getPermissionStatus');
      return _parsePermissionStatus(raw);
    } on PlatformException {
      return StepsPermissionStatus.unknown;
    }
  }

  Future<bool> requestPermission() async {
    if (!_isSupportedPlatform) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('requestPermission') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<int?> getTodaySteps() async {
    if (!_isSupportedPlatform) return 0;
    try {
      final raw = await _methodChannel.invokeMethod<dynamic>('getTodaySteps');
      if (raw == null) return null;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return null;
    } on PlatformException {
      return null;
    }
  }

  Stream<int> watchTodaySteps() {
    if (!_isSupportedPlatform) return Stream<int>.value(0);

    return Stream<int>.multi((controller) async {
      final initial = await getTodaySteps();
      controller.add(initial ?? 0);

      final sub = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          final value = switch (event) {
            int v => v,
            num v => v.toInt(),
            _ => null,
          };
          if (value != null) controller.add(value);
        },
        onError: (_) {
          controller.add(0);
        },
      );

      controller.onCancel = sub.cancel;
    }).distinct();
  }

  static StepsPermissionStatus _parsePermissionStatus(String? raw) {
    return switch (raw) {
      'granted' => StepsPermissionStatus.granted,
      'denied' => StepsPermissionStatus.denied,
      'restricted' => StepsPermissionStatus.restricted,
      'notSupported' => StepsPermissionStatus.notSupported,
      _ => StepsPermissionStatus.unknown,
    };
  }
}
