import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// One-time helper to backfill notification preference fields
  /// for all existing users. Call this from an admin/debug flow,
  /// then you can remove or ignore it afterwards.
  Future<void> backfillNotificationPrefs() async {
    try {
      final usersSnap = await _firestore.collection('users').get();

      for (final doc in usersSnap.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
        final updates = <String, dynamic>{};

        if (!data.containsKey('chatNotificationsEnabled')) {
          updates['chatNotificationsEnabled'] = true;
        }
        if (!data.containsKey('likeNotificationsEnabled')) {
          updates['likeNotificationsEnabled'] = true;
        }
        if (!data.containsKey('tagNotificationsEnabled')) {
          updates['tagNotificationsEnabled'] = true;
        }
        if (!data.containsKey('commentNotificationsEnabled')) {
          updates['commentNotificationsEnabled'] = true;
        }
        if (!data.containsKey('matchNotificationsEnabled')) {
          updates['matchNotificationsEnabled'] = true;
        }
        if (!data.containsKey('notificationFrequency')) {
          updates['notificationFrequency'] = 'medium';
        }

        if (updates.isNotEmpty) {
          await doc.reference.update(updates);
        }
      }
    } catch (e) {
      print('Error backfilling notification preferences: $e');
    }
  }

  /// Send notification for chat messages
  Future<void> sendChatNotification({
    required String recipientId,
    required String senderId,
    required String senderName,
    required String senderImage,
    required String messageContent,
    required String conversationId,
  }) async {
    try {
      // Check if recipient has notifications enabled for chats
      final recipientDoc =
          await _firestore.collection('users').doc(recipientId).get();
      final recipientData =
          recipientDoc.data() ?? <String, dynamic>{};
      final chatNotificationsEnabled =
          (recipientData['chatNotificationsEnabled'] as bool?) ?? true;

      if (!chatNotificationsEnabled) return;

      await _fcmService.sendNotification(
        userId: recipientId,
        type: 'chat',
        title: senderName,
        body: messageContent.length > 50
            ? '${messageContent.substring(0, 50)}...'
            : messageContent,
        senderId: senderId,
        senderName: senderName,
        senderImage: senderImage,
        relatedId: conversationId,
        data: {
          'type': 'chat',
          'conversationId': conversationId,
          'senderId': senderId,
        },
      );
    } catch (e) {
      print('Error sending chat notification: $e');
    }
  }

  /// Send notification for post likes
  Future<void> sendPostLikeNotification({
    required String postOwnerId,
    required String likerId,
    required String likerName,
    required String likerImage,
    required String postId,
    required String reactionType,
  }) async {
    try {
      // Check if post owner has notifications enabled
      final ownerDoc =
          await _firestore.collection('users').doc(postOwnerId).get();
      final ownerData =
          ownerDoc.data() ?? <String, dynamic>{};
      final likeNotificationsEnabled =
          (ownerData['likeNotificationsEnabled'] as bool?) ?? true;

      if (!likeNotificationsEnabled) return;

      // Don't notify if user liked their own post
      if (postOwnerId == likerId) return;

      final reactionEmoji = _getReactionEmoji(reactionType);

      await _fcmService.sendNotification(
        userId: postOwnerId,
        type: 'post_like',
        title: '$likerName reacted to your post $reactionEmoji',
        body: 'Check out who\'s engaging with your content!',
        senderId: likerId,
        senderName: likerName,
        senderImage: likerImage,
        relatedId: postId,
        data: {
          'type': 'post_like',
          'postId': postId,
          'likerId': likerId,
          'reactionType': reactionType,
        },
      );
    } catch (e) {
      print('Error sending post like notification: $e');
    }
  }

  /// Send notification when user is tagged in a post
  Future<void> sendTagNotification({
    required String taggedUserId,
    required String taggerId,
    required String taggerName,
    required String taggerImage,
    required String postId,
    required String postPreview,
  }) async {
    try {
      // Check if tagged user has notifications enabled
      final taggedUserDoc =
          await _firestore.collection('users').doc(taggedUserId).get();
      final taggedUserData = taggedUserDoc.data() ??
          <String, dynamic>{};
      final tagNotificationsEnabled =
          (taggedUserData['tagNotificationsEnabled'] as bool?) ?? true;

      if (!tagNotificationsEnabled) return;

      // Don't notify if user tagged themselves
      if (taggedUserId == taggerId) return;

      await _fcmService.sendNotification(
        userId: taggedUserId,
        type: 'tag',
        title: '$taggerName tagged you 🏷️',
        body: postPreview.length > 50
            ? '${postPreview.substring(0, 50)}...'
            : postPreview,
        senderId: taggerId,
        senderName: taggerName,
        senderImage: taggerImage,
        relatedId: postId,
        data: {
          'type': 'tag',
          'postId': postId,
          'taggerId': taggerId,
        },
      );
    } catch (e) {
      print('Error sending tag notification: $e');
    }
  }

  /// Send notification for comments on user's post
  Future<void> sendCommentNotification({
    required String postOwnerId,
    required String commenterId,
    required String commenterName,
    required String commenterImage,
    required String postId,
    required String commentContent,
  }) async {
    try {
      // Check if post owner has notifications enabled
      final ownerDoc =
          await _firestore.collection('users').doc(postOwnerId).get();
      final ownerData =
          ownerDoc.data() ?? <String, dynamic>{};
      final commentNotificationsEnabled =
          (ownerData['commentNotificationsEnabled'] as bool?) ?? true;

      if (!commentNotificationsEnabled) return;

      // Don't notify if user commented on their own post
      if (postOwnerId == commenterId) return;

      await _fcmService.sendNotification(
        userId: postOwnerId,
        type: 'comment',
        title: '$commenterName commented on your post 💬',
        body: commentContent.length > 50
            ? '${commentContent.substring(0, 50)}...'
            : commentContent,
        senderId: commenterId,
        senderName: commenterName,
        senderImage: commenterImage,
        relatedId: postId,
        data: {
          'type': 'comment',
          'postId': postId,
          'commenterId': commenterId,
        },
      );
    } catch (e) {
      print('Error sending comment notification: $e');
    }
  }

  /// Send notification for new matches
  Future<void> sendMatchNotification({
    required String userId1,
    required String userId2,
    required String user2Name,
    required String user2Image,
    required String matchId,
  }) async {
    try {
      // Check if user has notifications enabled for matches
      final userDoc = await _firestore.collection('users').doc(userId1).get();
      final userData =
          userDoc.data() ?? <String, dynamic>{};
      final matchNotificationsEnabled =
          (userData['matchNotificationsEnabled'] as bool?) ?? true;

      if (!matchNotificationsEnabled) return;

      await _fcmService.sendNotification(
        userId: userId1,
        type: 'match',
        title: 'It\'s a match! 🎉',
        body: 'You and $user2Name liked each other!',
        senderId: userId2,
        senderName: user2Name,
        senderImage: user2Image,
        relatedId: matchId,
        data: {
          'type': 'match',
          'matchId': matchId,
          'userId2': userId2,
        },
      );
    } catch (e) {
      print('Error sending match notification: $e');
    }
  }

  /// Get emoji for reaction type
  String _getReactionEmoji(String reactionType) {
    const reactionEmojis = {
      'like': '👍',
      'love': '❤️',
      'care': '🤗',
      'haha': '😂',
      'wow': '😮',
      'sad': '😢',
      'angry': '😠',
    };
    return reactionEmojis[reactionType] ?? '👍';
  }

  /// Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _fcmService.markNotificationAsRead(userId, notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Get user notifications stream
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _fcmService.getNotifications(userId);
  }

  /// Delete notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _fcmService.deleteNotification(userId, notificationId);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Update notification preferences
  Future<void> updateNotificationPreferences(
    String userId, {
    bool? chatNotificationsEnabled,
    bool? likeNotificationsEnabled,
    bool? tagNotificationsEnabled,
    bool? commentNotificationsEnabled,
    bool? matchNotificationsEnabled,
    String? notificationFrequency,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (chatNotificationsEnabled != null) {
        updates['chatNotificationsEnabled'] = chatNotificationsEnabled;
      }
      if (likeNotificationsEnabled != null) {
        updates['likeNotificationsEnabled'] = likeNotificationsEnabled;
      }
      if (tagNotificationsEnabled != null) {
        updates['tagNotificationsEnabled'] = tagNotificationsEnabled;
      }
      if (commentNotificationsEnabled != null) {
        updates['commentNotificationsEnabled'] = commentNotificationsEnabled;
      }
      if (matchNotificationsEnabled != null) {
        updates['matchNotificationsEnabled'] = matchNotificationsEnabled;
      }
      if (notificationFrequency != null) {
        updates['notificationFrequency'] = notificationFrequency;
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updates);
      }
    } catch (e) {
      print('Error updating notification preferences: $e');
    }
  }
}
