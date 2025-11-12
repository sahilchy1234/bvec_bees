import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const uuid = Uuid();

  // Get or create conversation between two users
  Future<String> getOrCreateConversation({
    required String user1Id,
    required String user1Name,
    required String user1Image,
    required String user2Id,
    required String user2Name,
    required String user2Image,
  }) async {
    try {
      // Check if conversation already exists
      final existingConversations = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: user1Id)
          .get();

      for (final doc in existingConversations.docs) {
        final conversation = Conversation.fromMap(doc.data(), doc.id);
        if (conversation.participantIds.contains(user2Id)) {
          return conversation.id;
        }
      }

      // Create new conversation
      final conversationId = uuid.v4();
      final conversation = Conversation(
        id: conversationId,
        participantIds: [user1Id, user2Id],
        participantNames: {
          user1Id: user1Name,
          user2Id: user2Name,
        },
        participantImages: {
          user1Id: user1Image,
          user2Id: user2Image,
        },
        lastMessage: '',
        lastSenderId: '',
        lastMessageTime: DateTime.now(),
        unreadCounts: {
          user1Id: 0,
          user2Id: 0,
        },
      );

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .set(conversation.toMap());

      return conversationId;
    } catch (e) {
      throw Exception('Failed to get or create conversation: $e');
    }
  }

  // Send a message
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderImage,
    required String content,
    required String recipientId,
  }) async {
    try {
      final messageId = uuid.v4();
      final message = Message(
        id: messageId,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderImage: senderImage,
        content: content,
        timestamp: DateTime.now(),
        isRead: false,
      );

      // Add message to subcollection
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      // Update conversation metadata
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': content,
        'lastSenderId': senderId,
        'lastMessageTime': DateTime.now(),
        'unreadCounts.$recipientId': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Stream messages for a conversation
  Stream<List<Message>> streamMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Stream conversations for a user
  Stream<List<Conversation>> streamConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Conversation.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCounts.$userId': 0,
      });
    } catch (e) {
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  // Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Delete all messages
      final messages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      for (final doc in messages.docs) {
        await doc.reference.delete();
      }

      // Delete conversation
      await _firestore.collection('conversations').doc(conversationId).delete();
    } catch (e) {
      throw Exception('Failed to delete conversation: $e');
    }
  }
}
