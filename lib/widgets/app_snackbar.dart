import 'package:flutter/material.dart';

extension AppSnackbars on BuildContext {
  void showAppSnackBar(
    String message, {
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    final messenger = ScaffoldMessenger.of(this);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
      ),
    );
  }
}

