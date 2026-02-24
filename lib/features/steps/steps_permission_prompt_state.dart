import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for SharedPreferences
/// Add this to your existing shared_preferences provider file if you have one
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

/// Provider to track if the steps permission prompt has been dismissed
/// Usage in home_screen.dart:
/// ```dart
/// final dismissed = ref.watch(stepsPermissionPromptDismissedProvider);
/// if (dismissed) return; // Don't show prompt
/// ```
final stepsPermissionPromptDismissedProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('steps_permission_prompt_dismissed') ?? false;
});

/// Controller to dismiss the permission prompt permanently
class StepsPermissionPromptController extends Notifier<void> {
  @override
  void build() {}

  Future<void> dismissPermanently() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('steps_permission_prompt_dismissed', true);
    ref.invalidate(stepsPermissionPromptDismissedProvider);
  }

  Future<void> reset() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('steps_permission_prompt_dismissed');
    ref.invalidate(stepsPermissionPromptDismissedProvider);
  }
}

final stepsPermissionPromptControllerProvider =
    NotifierProvider<StepsPermissionPromptController, void>(
  StepsPermissionPromptController.new,
);

/*
=== Integration Guide for home_screen.dart ===

1. Add to the permission prompt check:
   ```dart
   final dismissed = ref.watch(stepsPermissionPromptDismissedProvider);

   if (authUid != null &&
       needsStepsPermission &&
       !dismissed &&  // NEW: Check if dismissed
       !_didScheduleStepsPermissionPrompt) {
     // ... show dialog
   }
   ```

2. Update dialog actions to include "다시 보지 않기":
   ```dart
   actions: [
     TextButton(
       onPressed: () {
         // NEW: Dismiss permanently
         ref.read(stepsPermissionPromptControllerProvider.notifier)
           .dismissPermanently();
         Navigator.of(context).pop(false);
       },
       child: const Text('다시 보지 않기'),
     ),
     TextButton(
       onPressed: () => Navigator.of(context).pop(false),
       child: const Text('나중에'),
     ),
     FilledButton(
       onPressed: () => Navigator.of(context).pop(true),
       child: const Text('허용하기'),
     ),
   ],
   ```

3. Initialize SharedPreferences in main.dart:
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     final sharedPreferences = await SharedPreferences.getInstance();

     runApp(
       ProviderScope(
         overrides: [
           sharedPreferencesProvider.overrideWithValue(sharedPreferences),
         ],
         child: MyApp(),
       ),
     );
   }
   ```

=== Testing ===

To reset the "dismissed" state for testing:
```dart
ref.read(stepsPermissionPromptControllerProvider.notifier).reset();
```
*/
