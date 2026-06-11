import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get all chats for the current user
  Stream<QuerySnapshot> getChats() {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();
  }

  // Get chat by ID
  Stream<DocumentSnapshot> getChatById(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots();
  }

  // Get messages for a specific chat
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Create a new chat or get existing chat between two users for a product
  Future<String> createOrGetChat(String otherUserId, String productId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Check if a chat already exists between these users for this product
    final querySnapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      final chatProductId = data['productId'];

      if (participants.contains(otherUserId) && chatProductId == productId) {
        // Chat already exists
        return doc.id;
      }
    }

    // Create a new chat if none exists
    final chatRef = _firestore.collection('chats').doc();
    
    // Get product details
    final productDoc = await _firestore.collection('products').doc(productId).get();
    final productData = productDoc.data();
    
    if (productData == null) {
      throw Exception('Product not found');
    }

    // Get seller details
    final sellerDoc = await _firestore.collection('users').doc(otherUserId).get();
    final sellerData = sellerDoc.data();
    
    if (sellerData == null) {
      throw Exception('Seller not found');
    }

    // Create chat document
    await chatRef.set({
      'id': chatRef.id,
      'participants': [currentUserId, otherUserId],
      'productId': productId,
      'lastMessage': 'Chat started',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUserId,
      'unreadCount': {
        otherUserId: 1,
        currentUserId: 0
      },
      'product': {
        'name': productData['name'],
        'imageUrl': productData['imageUrl'],
      }
    });

    return chatRef.id;
  }

  // Send a text message
  Future<void> sendMessage(String chatId, String text) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Get chat document to retrieve participants
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data();
    
    if (chatData == null) {
      throw Exception('Chat not found');
    }

    final participants = List<String>.from(chatData['participants'] ?? []);
    final otherParticipants = participants.where((id) => id != currentUserId).toList();

    // Create message document
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'id': messageRef.id,
      'senderId': currentUserId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'imageUrl': null,
      'chatId': chatId
    });

    // Update chat document with last message info
    final unreadCountMap = Map<String, dynamic>.from(chatData['unreadCount'] ?? {});
    
    // Increment unread count for other participants
    for (final participantId in otherParticipants) {
      unreadCountMap[participantId] = (unreadCountMap[participantId] ?? 0) + 1;
    }

    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUserId,
      'unreadCount': unreadCountMap
    });
  }

  // Send an image message
  Future<void> sendImageMessage(String chatId, File imageFile) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Upload image to Firebase Storage
    final storageRef = _storage.ref().child('chat_images/${DateTime.now().millisecondsSinceEpoch}_$currentUserId');
    final uploadTask = storageRef.putFile(imageFile);
    final snapshot = await uploadTask;
    final imageUrl = await snapshot.ref.getDownloadURL();

    // Get chat document to retrieve participants
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data();
    
    if (chatData == null) {
      throw Exception('Chat not found');
    }

    final participants = List<String>.from(chatData['participants'] ?? []);
    final otherParticipants = participants.where((id) => id != currentUserId).toList();

    // Create message document
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'id': messageRef.id,
      'senderId': currentUserId,
      'text': 'Image',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'imageUrl': imageUrl,
      'chatId': chatId
    });

    // Update chat document with last message info
    final unreadCountMap = Map<String, dynamic>.from(chatData['unreadCount'] ?? {});
    
    // Increment unread count for other participants
    for (final participantId in otherParticipants) {
      unreadCountMap[participantId] = (unreadCountMap[participantId] ?? 0) + 1;
    }

    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': 'Image',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUserId,
      'unreadCount': unreadCountMap
    });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Update unread count for current user to 0
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data();
    
    if (chatData == null) {
      return;
    }

    final unreadCountMap = Map<String, dynamic>.from(chatData['unreadCount'] ?? {});
    unreadCountMap[currentUserId!] = 0;

    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount': unreadCountMap
    });

    // Mark all messages from other users as read
    final batch = _firestore.batch();
    final messagesSnapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in messagesSnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // Delete a chat
  Future<void> deleteChat(String chatId) async {
    // Delete all messages in the chat
    final messagesSnapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (final doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    // Delete the chat document
    batch.delete(_firestore.collection('chats').doc(chatId));
    
    await batch.commit();
  }

  // Get total unread message count across all chats
  Future<int> getTotalUnreadCount() async {
    if (currentUserId == null) {
      return 0;
    }

    final querySnapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    int totalUnread = 0;
    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final unreadCountMap = Map<String, dynamic>.from(data['unreadCount'] ?? {});
      totalUnread += (unreadCountMap[currentUserId] ?? 0) as int;
    }

    return totalUnread;
  }
}
