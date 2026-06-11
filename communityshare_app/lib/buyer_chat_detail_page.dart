// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'constants.dart';
import 'services/chat_service.dart';
import 'utils/image_utils.dart';

class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> chatData;

  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.chatData,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Services
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream for messages
  Stream<QuerySnapshot>? _messagesStream;

  // Loading state
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    // Mark messages as read when opening the chat
    _chatService.markMessagesAsRead(widget.chatId);

    // Set up messages stream
    _messagesStream = _chatService.getMessages(widget.chatId);

    // Scroll to bottom when new messages arrive
    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _chatService.sendMessage(widget.chatId, text);
      _messageController.clear();

      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTime(DateTime timestamp) {
    return DateFormat('h:mm a').format(timestamp);
  }

  String _formatMessageDate(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(timestamp);
    }
  }

  Widget _buildMessageItem(DocumentSnapshot messageDoc) {
    final messageData = messageDoc.data() as Map<String, dynamic>;
    final senderId = messageData['senderId'] as String;
    final isMe = senderId == _auth.currentUser?.uid;
    final timestamp =
        (messageData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final text = messageData['text'] as String;
    final imageUrl = messageData['imageUrl'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FutureBuilder<String>(
                future: _fetchProfileImage(_getOtherParticipantId()),
                builder: (context, snapshot) {
                  final profileImageUrl = snapshot.data ?? _getOtherParticipantImage();
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[300],
                    child: ClipOval(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: ImageUtils.base64ToImage(
                          profileImageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.mutedTeal : AppColors.deepSlateGray,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageUrl != null)
                        GestureDetector(
                          onTap: () {
                            // Show full image in dialog
                            showDialog(
                              context: context,
                              builder:
                                  (context) => Dialog(
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.contain,
                                      placeholder:
                                          (context, url) => const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                      errorWidget:
                                          (context, url, error) =>
                                              const Icon(Icons.error),
                                    ),
                                  ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 200,
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) =>
                                      const Icon(Icons.error),
                            ),
                          ),
                        ),
                      if (text != 'Image')
                        Text(
                          text,
                          style: TextStyle(
                            color: isMe ? Colors.white : AppColors.coolGray,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 4.0,
                    left: 4.0,
                    right: 4.0,
                  ),
                  child: Text(
                    _formatTime(timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.coolGray.withAlpha(150),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (isMe)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: FutureBuilder<String>(
                future: _auth.currentUser != null ? _fetchProfileImage(_auth.currentUser!.uid) : Future.value(''),
                builder: (context, snapshot) {
                  final profileImageUrl = snapshot.data ?? 
                      _auth.currentUser?.photoURL ?? 
                      'https://i.pinimg.com/1200x/2c/47/d5/2c47d5dd5b532f83bb55c4cd6f5bd1ef.jpg';
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[300],
                    child: ClipOval(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: ImageUtils.base64ToImage(
                          profileImageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Get other participant's ID
  String _getOtherParticipantId() {
    final participants = List<String>.from(
      widget.chatData['participants'] ?? [],
    );
    return participants.firstWhere(
      (id) => id != _auth.currentUser?.uid,
      orElse: () => 'unknown',
    );
  }

  // Fetch profile image from users collection
  Future<String> _fetchProfileImage(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['profileImageUrl'] != null) {
          return userData['profileImageUrl'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile image: $e');
    }
    return 'https://i.pinimg.com/1200x/2c/47/d5/2c47d5dd5b532f83bb55c4cd6f5bd1ef.jpg';
  }

  // This method is kept for backward compatibility
  String _getOtherParticipantImage() {
    final otherParticipantId = _getOtherParticipantId();
    
    // Fallback to old method if needed
    final participantImages =
        widget.chatData['participantImages'] as Map<String, dynamic>? ?? {};
    return participantImages[otherParticipantId] ??
        'https://i.pinimg.com/1200x/2c/47/d5/2c47d5dd5b532f83bb55c4cd6f5bd1ef.jpg';
  }

  String _getOtherParticipantName() {
    final participants = List<String>.from(
      widget.chatData['participants'] ?? [],
    );
    final otherParticipantId = participants.firstWhere(
      (id) => id != _auth.currentUser?.uid,
      orElse: () => 'unknown',
    );

    final participantNames =
        widget.chatData['participantNames'] as Map<String, dynamic>? ?? {};
    return participantNames[otherParticipantId] ?? 'Unknown User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            FutureBuilder<String>(
              future: _fetchProfileImage(_getOtherParticipantId()),
              builder: (context, snapshot) {
                final profileImageUrl = snapshot.data ?? _getOtherParticipantImage();
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[300],
                  child: ClipOval(
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: ImageUtils.base64ToImage(
                        profileImageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getOtherParticipantName(),
                    style: TextStyle(fontSize: 16, color: AppColors.coolGray),
                  ),
                ],
              ),
            ),
          ],
        ),
        // No actions needed
        actions: [],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages: ${snapshot.error}',
                      style: TextStyle(color: AppColors.coolGray),
                    ),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: TextStyle(
                        color: AppColors.coolGray.withAlpha(150),
                      ),
                    ),
                  );
                }

                // Group messages by date
                final groupedMessages = <String, List<DocumentSnapshot>>{};
                for (final message in messages) {
                  final messageData = message.data() as Map<String, dynamic>;
                  final timestamp =
                      (messageData['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now();
                  final dateString = _formatMessageDate(timestamp);

                  if (!groupedMessages.containsKey(dateString)) {
                    groupedMessages[dateString] = [];
                  }

                  groupedMessages[dateString]!.add(message);
                }

                // Build the list with date headers
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: groupedMessages.length,
                  itemBuilder: (context, index) {
                    final date = groupedMessages.keys.elementAt(index);
                    final dateMessages = groupedMessages[date]!;

                    return Column(
                      children: [
                        // Date header
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.deepSlateGray,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                date,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.coolGray.withAlpha(180),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Messages for this date
                        ...dateMessages.map(
                          (message) => _buildMessageItem(message),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: AppColors.deepSlateGray,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: AppColors.coolGray),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: AppColors.coolGray.withAlpha(150),
                      ),
                      filled: true,
                      fillColor: AppColors.charcoalBlack,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.mutedTeal,
                              ),
                            ),
                          )
                          : const Icon(Icons.send),
                  color: AppColors.mutedTeal,
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
