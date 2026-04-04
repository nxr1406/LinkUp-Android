import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const Map<String, dynamic> _serviceAccountJson = {
  "type": "service_account",
  "project_id": "linkup-c22fa",
  "private_key_id": "744bb32c3447d8dc7aeae3077a32412edc034566",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCvN8/Mmq9m/B2F\nQpCtvozrGxiZW8gI76aFAtg/AMlnC+ZJ/r5OGbC7EoUkGWcPGqxdyyivvJR2wjkf\n8NszSEsthPfWmFOEc/mMpunrDDdPi+/Rjq1ey7sNWxrvB6hxYB2pwZkVa+ocAREF\nFt0fQ0aaIGbP7ia4lMMGdBcnKUODwNHb7YHR9ZHDbW7+96Aq/fljzUH9lAvbzqQT\nYAj+ObT/JdyRlk5fVdqfHs0RPSPMLJgu2LE5fyHfKGzSs40PDHlctIPoPFE4KFVk\nRoC2YYJzFFzSGcbtc9ELgcZVt7butvztLH8ONZ+TXvn1iExwdUlu7Pm5boCqvfHZ\nBNMoRyZpAgMBAAECggEAA1bXF/99dRh0+spAm1PyFEn0YTK24+jt9oN4q7dgCeTJ\nolRRQxZGFZlFOq/AsSJ4eKMEgbvEAR2BoHi73giUQYgS8Wl+s4ZtSuE5yrxgALJz\nRrcHPU9x0SxCndaeG1HrBs1fznZYAL7KWMYfML5q9BAqaBngX8H+PkXvuD6W/VQG\nrLJtRCcbAfiionqsBar82PuTDdKmDy6XYqME3I91DNT44iEhXQb3wfZGEA87bYX5\nBjhsn8zk6Q12BGVjvWJTR/XqO5f7sdMBizOzavx4R+eYsEZpbeMNoYZoYZS/XJVi\n0ziGDJswlXdxXFxSUtFrWI7pDACqApY75XbYpINo3QKBgQDgyvHRTZ9XMbdc8NQr\ns52f/YZY3UrMgKrFIxbl9ALwIyET1muwb1jnebE/ZiTfqCiH6JMnNGbj41+RvPo5\nSMalLoRAiTTMNIv782I8noCYYIZf5WBT1tamYctts0lFV1U/QkIGSsV76cecdw5B\nXeF0CNRwsO3wbwczZY676YdOVQKBgQDHiv+Uf+knE2SP/CQRz/6pVPkfjg/qJBHK\nlq1YE4mMRMr6jUMZzBikUOc/ljUPp/8CYehJm6hKs9aqXaWrADba5Dei9XL3a5o/\nPfmkv7PVuI2U6wqTQiaLC3OaRyjuaAAZCfeHV0BGPGZz9hht2aSrhvaqW8L3BOLP\nV9ODA2ljxQKBgQDDNzt9ut1PybslmXeIZDnVAUS006jrpCmpfema1affh4JoSePH\nm0sn6oTFPB11pgFc1dtFRrq72W/bjrP3H35zYMw1h3I0jMWsjhaX8kZXDixkBzz6\nUi6i23bg07wj3c4IW7Ae6rxJ+iIBfVsB5VevfyOOofhgvusP9XhZNFru6QKBgDxu\nlEjdFDeJYANbUXEzlOSjn283DwrSMbExQP5TrGyWyQJoldHSRgQ9nEtdqmQ7dLe7\n/yWLxsQZAwJFqk7HmdVhGJh5zX+xTt2oX1rN1CD966MWK/W9Kv8hULmAo5zQUndC\n1XxfqE+dK0ojVfKu33gzP7EIaVt2V1qENsKO3fQhAoGADonvV/U/1BRYPuQJu/5U\nFw7uLomFzFJbwzUqWwB5/OdGYTZcYvnro58sn4WQx/AObQBkGNQvuA+FuFpTRP7O\ntMwW8BO7J0IFFPrGfc+zU8i2yzOseDCj9m5xf6gS/jiObrkJNHOzi1atk0QB21iR\nJ5/860GgvaIryhiZKm/rb4Y=\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-fbsvc@linkup-c22fa.iam.gserviceaccount.com",
  "client_id": "106488163270101994881",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
};

const String _projectId = 'linkup-c22fa';
const AndroidNotificationChannel linkUpChannel = AndroidNotificationChannel(
  'linkup_messages',
  'LinkUp Messages',
  description: 'New message notifications from LinkUp',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

final FlutterLocalNotificationsPlugin _localPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM notification payload দিয়ে Android OS নিজেই দেখায়
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;
  static String? _cachedAccessToken;
  static DateTime? _tokenExpiry;

  static Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, sound: true, badge: true);

    await _localPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(linkUpChannel);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localPlugin.initialize(
      const InitializationSettings(android: androidSettings),
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n == null) return;
      _localPlugin.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            linkUpChannel.id,
            linkUpChannel.name,
            channelDescription: linkUpChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });

    await _saveTokenToFirestore();
    _messaging.onTokenRefresh.listen((_) => _saveTokenToFirestore());
  }

  static Future<void> clearToken() async {
    try {
      await _messaging.deleteToken();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _db.collection('users').doc(uid).update({'fcmToken': FieldValue.delete()});
      }
    } catch (_) {}
  }

  static Future<void> saveToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).set(
          {'fcmToken': token, 'fcmUpdatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      }
    } catch (_) {}
  }

  static Future<void> _saveTokenToFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await saveToken(uid);
  }

  static Future<String?> _getAccessToken() async {
    if (_cachedAccessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
      return _cachedAccessToken;
    }
    try {
      final credentials = ServiceAccountCredentials.fromJson(_serviceAccountJson);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(credentials, scopes);
      final token = client.credentials.accessToken;
      _cachedAccessToken = token.data;
      _tokenExpiry = token.expiry;
      client.close();
      return _cachedAccessToken;
    } catch (_) {
      return null;
    }
  }

  static Future<void> sendMessageNotification({
    required String recipientFcmToken,
    required String senderName,
    required String messageText,
    required String chatId,
  }) async {
    if (recipientFcmToken.isEmpty) return;
    final accessToken = await _getAccessToken();
    if (accessToken == null) return;

    final body = messageText.length > 100
        ? '${messageText.substring(0, 97)}...'
        : messageText;

    try {
      await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$_projectId/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': recipientFcmToken,
            'notification': {'title': senderName, 'body': body},
            'android': {
              'priority': 'HIGH',
              'notification': {
                'channel_id': linkUpChannel.id,
                'sound': 'default',
                'default_vibrate_timings': true,
                'notification_priority': 'PRIORITY_MAX',
                'visibility': 'PRIVATE',
              },
            },
            'data': {
              'type': 'new_message',
              'chatId': chatId,
              'senderName': senderName,
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
        }),
      );
    } catch (_) {}
  }
}
