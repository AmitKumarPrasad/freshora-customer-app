import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Background message handler must be retained in release builds.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService._showNotification(
    message.notification?.title ?? 'New Notification',
    message.notification?.body ?? '',
    message.data,
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // External callback to upload FCM token to backend
  static Function(String)? onFcmTokenReady;

  factory NotificationService() => _instance;

  NotificationService._internal();

  // Initialize notification service
  Future<void> initialize() async {
    // Request permissions for iOS
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      provisional: false,
      sound: true,
    );

    // Initialize local notifications
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    // Setup message handlers
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Get and store FCM token
    await _storeFcmToken();
    
    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);
  }

  // Handle FCM token refresh
  Future<void> _onTokenRefresh(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    
    // Notify listener to upload new token to backend
    if (onFcmTokenReady != null) {
      onFcmTokenReady!(token);
    }
  }

  // Get FCM token and store it
  Future<void> _storeFcmToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
        
        // Notify listener to upload token to backend
        if (onFcmTokenReady != null) {
          onFcmTokenReady!(token);
        }
      }
    } catch (e) {
      debugPrint('FCM token retrieval failed: $e');
    }
  }

  // Retry token acquisition when an authenticated session is available.
  Future<String?> fetchFcmToken() async {
    if (Firebase.apps.isEmpty) return null;
    await _storeFcmToken();
    return getFcmToken();
  }

  // Retrieve stored FCM token
  Future<String?> getFcmToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('fcm_token');
    } catch (e) {
      return null;
    }
  }

  // Refresh FCM token (call this after user login)
  Future<void> refreshFcmToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      await Future.delayed(const Duration(milliseconds: 500));
      await _storeFcmToken();
    } catch (e) {
      // Silently skip if token refresh fails
    }
  }

  // Handle foreground messages (app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _showNotification(notification.title ?? '', notification.body ?? '', message.data);
    }
  }

  // Handle message when app is opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    // Handle navigation based on message data
    _handleNotificationAction(message.data);
  }

  // Handle local notification tap
  void _handleNotificationTap(NotificationResponse response) {
    // Handle navigation based on payload
    if (response.payload != null) {
      _handleNotificationAction({'order_id': response.payload});
    }
  }

  // Show local notification
  static Future<void> _showNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'order_channel_id',
      'Order Notifications',
      channelDescription: 'Notifications for order updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final orderId = data['order_id']?.toString() ?? '';
    await _localNotifications.show(
      orderId.hashCode,
      title,
      body,
      notificationDetails,
      payload: orderId,
    );
  }

  // Handle notification action
  void _handleNotificationAction(Map<String, dynamic> data) {
    final orderId = data['order_id'];
    if (orderId != null) {
      // Navigation will be handled by the app's navigation system
      // based on app state and routing
    }
  }

  // Send test notification (for testing)
  Future<void> sendTestNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'test_channel_id',
      'Test Notifications',
      channelDescription: 'Test notification channel',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      0,
      'Test Notification',
      'This is a test notification from FRESHORA',
      notificationDetails,
    );
  }
}
