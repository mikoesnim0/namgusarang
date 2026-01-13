import 'package:flutter/foundation.dart';

void authDebugLog(String message, [Map<String, Object?>? data]) {
  if (!kDebugMode) return;
  final buf = StringBuffer('[AUTH] $message');
  if (data != null && data.isNotEmpty) {
    buf.write(' | ');
    buf.write(data.entries.map((e) => '${e.key}=${e.value}').join(', '));
  }
  debugPrint(buf.toString());
}

