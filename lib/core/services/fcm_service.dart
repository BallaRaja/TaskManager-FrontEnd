// lib/core/services/fcm_service.dart
//
// Real server-sent push notifications via Firebase Cloud Messaging.
//
// Flow:
//   Backend cron â†’ FCM (data-only) â†’ device
//     â€¢ App in FOREGROUND  â†’ onMessage â†’ showActionNotification()
//     â€¢ App BACKGROUND/KILLED â†’ _fcmBackgroundHandler â†’ showActionNotification()
//   User taps action button:
//     â€¢ "Mark as Done"      â†’ POST /api/notifications/mark-done/:taskId
//     â€¢ "Extend 30 Minutes" â†’ POST /api/notifications/extend/:taskId

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../utils/session_manager.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Notification action IDs (must be stable strings)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const String kActionMarkDone = 'mark_done';
const String kActionExtend30 = 'extend_30';

// Notification channel ID (must match AndroidManifest + cron data)
const String kChannelId = 'task_reminders';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// TOP-LEVEL: Background FCM message handler
// Runs in a separate Dart isolate when app is killed/background.
// Must be top-level and annotated with @pragma('vm:entry-point').
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _showActionNotification(message.data);
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// TOP-LEVEL: Background notification action response handler
// Called when user taps an action button while app is terminated/background.
// Must be top-level and annotated with @pragma('vm:entry-point').
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
@pragma('vm:entry-point')
Future<void> _onBackgroundActionResponse(NotificationResponse response) async {
  await _handleActionResponse(response);
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Shared logic: Show a local notification with action buttons.
// Works in both foreground and background isolates.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Future<void> _showActionNotification(Map<String, dynamic> data) async {
  final plugin = FlutterLocalNotificationsPlugin();

  // Initialise (safe to call multiple times)
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: _onForegroundActionResponse,
    onDidReceiveBackgroundNotificationResponse: _onBackgroundActionResponse,
  );

  // Ensure channel exists with MAX importance
  if (!kIsWeb && Platform.isAndroid) {
    final ap = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await ap?.createNotificationChannel(
      const AndroidNotificationChannel(
        kChannelId,
        'Task Reminders',
        description: 'Reminders for your upcoming tasks',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
  }

  final String title = data['title'] ?? 'Task Reminder';
  final String body = data['body'] ?? '';
  final String taskId = data['taskId'] ?? '';
  final String type = data['type'] ?? '';
  final String actions = data['actions'] ?? '';

  // Build action buttons based on the "actions" field sent by backend
  final List<AndroidNotificationAction> androidActions = [];
  final List<DarwinNotificationActionOption> iosActions = [];

  if (actions == 'extend_and_mark_done') {
    androidActions.addAll([
      const AndroidNotificationAction(
        kActionExtend30,
        'Extend 30 Minutes',
        showsUserInterface: false,
        cancelNotification: true,
      ),
      const AndroidNotificationAction(
        kActionMarkDone,
        'âœ… Mark as Done',
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ]);
  } else if (actions == 'mark_done') {
    androidActions.add(
      const AndroidNotificationAction(
        kActionMarkDone,
        'âœ… Mark as Done',
        showsUserInterface: false,
        cancelNotification: true,
      ),
    );
  }

  // Stable notification ID per task + type (so 30-min and 5-min don't collide)
  final int notifId = ('${taskId}_$type').hashCode & 0x7FFFFFFF;

  await plugin.show(
    notifId,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        kChannelId,
        'Task Reminders',
        channelDescription: 'Reminders for your upcoming tasks',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        fullScreenIntent: type == 'missed', // Wake screen for missed tasks
        autoCancel: true,
        actions: androidActions,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    ),
    payload: jsonEncode(data), // carry full data for action handler
  );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Shared logic: Handle action button taps (foreground + background)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
void _onForegroundActionResponse(NotificationResponse response) {
  _handleActionResponse(response);
}

Future<void> _handleActionResponse(NotificationResponse response) async {
  final String? actionId = response.actionId;
  final String? payload = response.payload;
  if (actionId == null || payload == null) return;

  Map<String, dynamic> data;
  try {
    data = jsonDecode(payload) as Map<String, dynamic>;
  } catch (_) {
    return;
  }

  final String taskId = data['taskId'] ?? '';
  if (taskId.isEmpty) return;

  // Read auth token from SharedPreferences directly (no BuildContext needed).
  // Key must match SessionManager._tokenKey = 'jwt_token'
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('jwt_token');
  if (token == null) return;

  try {
    if (actionId == kActionMarkDone) {
      debugPrint('âœ… [FCM] Action "Mark as Done" for task $taskId');
      await http.post(
        Uri.parse(
          '${ApiConstants.backendUrl}/api/notifications/mark-done/$taskId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    } else if (actionId == kActionExtend30) {
      debugPrint('ðŸ” [FCM] Action "Extend 30 min" for task $taskId');
      await http.post(
        Uri.parse(
          '${ApiConstants.backendUrl}/api/notifications/extend/$taskId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    }
  } catch (e) {
    debugPrint('âŒ [FCM] Action API call failed: $e');
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// FcmService â€” public API
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;

  /// Call once from main() after Firebase.initializeApp()
  Future<void> init() async {
    if (_initialized) return;

    // Register background FCM handler (must be set before any other setup)
    FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

    // Request permissions
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('ðŸ”” [FCM] Permission: ${settings.authorizationStatus}');

    // Tell FCM NOT to auto-display in foreground â€” we show our own with actions
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    // Foreground message â†’ show local notification with action buttons
    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint('ðŸ”” [FCM] Foreground: ${message.data}');
      await _showActionNotification(message.data);
    });

    // App was in background and user tapped the notification itself
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('ðŸ”” [FCM] Notification tapped (bg): ${message.data}');
    });

    // App was killed and user tapped the notification
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      debugPrint('ðŸ”” [FCM] Opened from terminated via notification');
    }

    // Initialise local notifications plugin once in the main isolate
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onForegroundActionResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundActionResponse,
    );

    // Create Android notification channel with MAX importance
    if (!kIsWeb && Platform.isAndroid) {
      final ap = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await ap?.requestNotificationsPermission();
      await ap?.requestExactAlarmsPermission();
      await ap?.createNotificationChannel(
        const AndroidNotificationChannel(
          kChannelId,
          'Task Reminders',
          description: 'Reminders for your upcoming tasks',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }

    _initialized = true;
    debugPrint('âœ… [FCM] FcmService initialized');
  }

  /// Register this device's FCM token with the backend after login.
  Future<void> registerTokenWithBackend() async {
    try {
      if (kIsWeb) return;
      if (!Platform.isAndroid && !Platform.isIOS) return;

      final token = await _fcm.getToken();
      if (token == null) {
        debugPrint('âš ï¸ [FCM] Could not get device token');
        return;
      }
      debugPrint('ðŸ“± [FCM] Device token: ${token.substring(0, 20)}â€¦');

      final authToken = await SessionManager.getToken();
      if (authToken == null) return;

      final res = await http
          .post(
            Uri.parse(
              '${ApiConstants.backendUrl}/api/notifications/register-token',
            ),
            headers: {
              'Authorization': 'Bearer $authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'fcmToken': token}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
        res.statusCode == 200
            ? 'âœ… [FCM] Token registered with backend'
            : 'âš ï¸ [FCM] Token registration failed: ${res.statusCode}',
      );

      // Refresh token listener
      _fcm.onTokenRefresh.listen((newToken) async {
        final jwt = await SessionManager.getToken();
        if (jwt == null) return;
        await http.post(
          Uri.parse(
            '${ApiConstants.backendUrl}/api/notifications/register-token',
          ),
          headers: {
            'Authorization': 'Bearer $jwt',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'fcmToken': newToken}),
        );
        debugPrint('ðŸ”„ [FCM] Refreshed token re-registered');
      });
    } catch (e) {
      debugPrint('âŒ [FCM] registerTokenWithBackend: $e');
    }
  }

  /// Call on logout to stop receiving pushes.
  Future<void> unregisterToken() async {
    try {
      final token = await _fcm.getToken();
      final authToken = await SessionManager.getToken();
      if (token == null || authToken == null) return;

      await http.delete(
        Uri.parse(
          '${ApiConstants.backendUrl}/api/notifications/unregister-token',
        ),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcmToken': token}),
      );
      debugPrint('ðŸ—‘ï¸  [FCM] Token unregistered');
    } catch (e) {
      debugPrint('âš ï¸ [FCM] unregisterToken: $e');
    }
  }
}
