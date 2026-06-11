import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  // Initialize notification channels and request permissions
  Future<void> initialize() async {
    // Request permission for iOS devices
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    debugPrint('User granted permission: ${settings.authorizationStatus}');
    
    // Handle incoming messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');
      
      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        // We're not showing local notifications anymore, just log the message
      }
    });
    
    // Get the token
    String? token = await _messaging.getToken();
    debugPrint('FCM Token: $token');
  }
  
  // Subscribe to a topic (e.g., for a specific chat)
  Future<void> subscribeToChat(String chatId) async {
    await _messaging.subscribeToTopic('chat_$chatId');
  }
  
  // Unsubscribe from a topic
  Future<void> unsubscribeFromChat(String chatId) async {
    await _messaging.unsubscribeFromTopic('chat_$chatId');
  }
  
  // Save the FCM token to Firestore for the current user
  Future<void> saveToken(String userId) async {
    String? token = await _messaging.getToken();
    if (token != null) {
      // Save token to Firestore
      // This would typically be implemented in a user service
      debugPrint('Saving token for user $userId: $token');
    }
  }
}
