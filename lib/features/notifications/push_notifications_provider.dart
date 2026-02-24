import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_notifications_service.dart';

final pushNotificationsServiceProvider = Provider<PushNotificationsService>((ref) {
  return PushNotificationsService();
});

