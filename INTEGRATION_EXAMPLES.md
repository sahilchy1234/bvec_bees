# FCM Integration Examples

## Complete Integration Examples

### 1. Chat Message Notification

**Location:** `lib/services/chat_service.dart`

The `sendMessage` method now automatically sends notifications:

```dart
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

    // Add message to Firestore
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

    // ✅ NEW: Send chat notification
    await NotificationService().sendChatNotification(
      recipientId: recipientId,
      senderId: senderId,
      senderName: senderName,
      senderImage: senderImage,
      messageContent: content,
      conversationId: conversationId,
    );
  } catch (e) {
    throw Exception('Failed to send message: $e');
  }
}
```

### 2. Post Like Notification

**Location:** `lib/services/post_service.dart`

The `setReaction` method now sends notifications when a user reacts:

```dart
Future<void> setReaction(
  String postId,
  String userId,
  String reactionKey,
) async {
  if (!supportedReactions.contains(reactionKey)) {
    throw Exception('Unsupported reaction: $reactionKey');
  }

  final postRef = _firestore.collection('posts').doc(postId);

  try {
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) {
        throw Exception('Post not found');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final reactions = Map<String, String>.from(data['reactions'] ?? {});
      final postOwnerId = data['authorId'] as String?;

      // ... reaction logic ...

      transaction.update(postRef, {
        'reactionCounts': reactionCounts,
        'reactions': reactions,
        'likes': totalReactions,
        'likedBy': likedBy,
      });

      // ✅ NEW: Send notification after transaction
      if (postOwnerId != null && postOwnerId != userId) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userName = userDoc['name'] as String? ?? 'Someone';
        final userImage = userDoc['avatarUrl'] as String?;

        await NotificationService().sendPostLikeNotification(
          postOwnerId: postOwnerId,
          likerId: userId,
          likerName: userName,
          likerImage: userImage ?? '',
          postId: postId,
          reactionType: reactionKey,
        );
      }
    });
  } catch (e) {
    throw Exception('Failed to set reaction: $e');
  }
}
```

### 3. Comment Notification

**Location:** `lib/services/comment_service.dart`

The `addComment` method now sends notifications:

```dart
Future<String> addComment({
  required String postId,
  required String authorId,
  required String authorName,
  required String authorImage,
  required String content,
}) async {
  try {
    final commentId = uuid.v4();
    final comment = Comment(
      id: commentId,
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      authorImage: authorImage,
      content: content,
      timestamp: DateTime.now(),
      likes: 0,
      likedBy: [],
    );

    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .set(comment.toMap());

    // Increment comment count
    await _firestore.collection('posts').doc(postId).update({
      'comments': FieldValue.increment(1),
    });

    // ✅ NEW: Send comment notification
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    final postOwnerId = postDoc['authorId'] as String?;

    if (postOwnerId != null && postOwnerId != authorId) {
      await NotificationService().sendCommentNotification(
        postOwnerId: postOwnerId,
        commenterId: authorId,
        commenterName: authorName,
        commenterImage: authorImage,
        postId: postId,
        commentContent: content,
      );
    }

    return commentId;
  } catch (e) {
    throw Exception('Failed to add comment: $e');
  }
}
```

### 4. Match Notification

**Location:** `lib/services/match_service.dart`

The `_checkAndCreateMatch` method now sends notifications:

```dart
Future<void> _checkAndCreateMatch(String user1Id, String user2Id) async {
  try {
    final reverseVoteId = '${user2Id}_$user1Id';
    final reverseVoteDoc = await _firestore.collection('votes').doc(reverseVoteId).get();

    if (reverseVoteDoc.exists) {
      final reverseVote = Vote.fromMap(reverseVoteDoc.data()!, reverseVoteDoc.id);
      
      if (reverseVote.isHot) {
        // Check if match already exists
        final existingMatches = await _firestore
            .collection('matches')
            .where('user1Id', whereIn: [user1Id, user2Id])
            .get();

        bool matchExists = false;
        for (final doc in existingMatches.docs) {
          final match = Match.fromMap(doc.data(), doc.id);
          if ((match.user1Id == user1Id && match.user2Id == user2Id) ||
              (match.user1Id == user2Id && match.user2Id == user1Id)) {
            matchExists = true;
            break;
          }
        }

        if (!matchExists) {
          // Create match
          final matchId = uuid.v4();
          final match = Match(
            id: matchId,
            user1Id: user1Id,
            user2Id: user2Id,
            matchedAt: DateTime.now(),
          );

          await _firestore.collection('matches').doc(matchId).set(match.toMap());

          // ✅ NEW: Get user info and send notifications
          final user1Doc = await _firestore.collection('users').doc(user1Id).get();
          final user2Doc = await _firestore.collection('users').doc(user2Id).get();

          final user1Name = user1Doc['name'] as String? ?? 'Someone';
          final user1Image = user1Doc['avatarUrl'] as String? ?? '';
          final user2Name = user2Doc['name'] as String? ?? 'Someone';
          final user2Image = user2Doc['avatarUrl'] as String? ?? '';

          // Send to both users
          await NotificationService().sendMatchNotification(
            userId1: user1Id,
            userId2: user2Id,
            user2Name: user2Name,
            user2Image: user2Image,
            matchId: matchId,
          );

          await NotificationService().sendMatchNotification(
            userId1: user2Id,
            userId2: user1Id,
            user2Name: user1Name,
            user2Image: user1Image,
            matchId: matchId,
          );
        }
      }
    }
  } catch (e) {
    throw Exception('Failed to check match: $e');
  }
}
```

## Usage in UI Pages

### Example 1: Sending a Chat Message

```dart
// In a chat page
void _sendMessage(String content) async {
  try {
    await ChatService().sendMessage(
      conversationId: widget.conversationId,
      senderId: currentUserId,
      senderName: currentUserName,
      senderImage: currentUserImage,
      content: content,
      recipientId: recipientId, // ✅ Notification sent automatically
    );
    
    setState(() {
      _messageController.clear();
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Example 2: Liking a Post

```dart
// In a feed page
void _toggleLike(String postId) async {
  try {
    final postService = PostService();
    
    if (isLiked) {
      await postService.unlikePost(postId, currentUserId);
    } else {
      await postService.likePost(postId, currentUserId);
      // ✅ Notification sent automatically
    }
    
    setState(() {
      isLiked = !isLiked;
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Example 3: Adding a Comment

```dart
// In a post detail page
void _submitComment(String content) async {
  try {
    await CommentService().addComment(
      postId: widget.postId,
      authorId: currentUserId,
      authorName: currentUserName,
      authorImage: currentUserImage,
      content: content,
      // ✅ Notification sent automatically
    );
    
    setState(() {
      _commentController.clear();
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Example 4: Casting a Vote (Match)

```dart
// In a swipe page
void _castVote(String targetUserId, bool isHot) async {
  try {
    await MatchService().castVote(
      voterId: currentUserId,
      targetId: targetUserId,
      isHot: isHot,
      // ✅ Match notification sent automatically if mutual
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

## Engagement Algorithm Usage

### Example 1: Manual Engagement Notification

```dart
// Trigger manually when needed
void _checkAndSendEngagementNotification() async {
  try {
    await EngagementService().sendEngagementNotification(currentUserId);
  } catch (e) {
    print('Error sending engagement notification: $e');
  }
}
```

### Example 2: Update User Activity

```dart
// Call when user opens app or performs action
void _onUserActive() async {
  try {
    await EngagementService().updateEngagementMetrics(currentUserId);
  } catch (e) {
    print('Error updating engagement metrics: $e');
  }
}
```

### Example 3: Batch Send Engagement Notifications

```dart
// Call periodically (e.g., via Cloud Scheduler)
Future<void> sendDailyEngagementNotifications() async {
  try {
    await EngagementService().sendBatchEngagementNotifications();
    print('Batch engagement notifications sent');
  } catch (e) {
    print('Error sending batch notifications: $e');
  }
}
```

## Notification Preferences Management

### Example: Settings Page

```dart
class NotificationSettingsPage extends StatefulWidget {
  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool chatNotifications = true;
  bool likeNotifications = true;
  bool tagNotifications = true;
  bool commentNotifications = true;
  bool matchNotifications = true;
  String notificationFrequency = 'medium';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() async {
    // Load from Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    
    setState(() {
      chatNotifications = userDoc['chatNotificationsEnabled'] ?? true;
      likeNotifications = userDoc['likeNotificationsEnabled'] ?? true;
      tagNotifications = userDoc['tagNotificationsEnabled'] ?? true;
      commentNotifications = userDoc['commentNotificationsEnabled'] ?? true;
      matchNotifications = userDoc['matchNotificationsEnabled'] ?? true;
      notificationFrequency = userDoc['notificationFrequency'] ?? 'medium';
    });
  }

  void _savePreferences() async {
    await NotificationService().updateNotificationPreferences(
      currentUserId,
      chatNotificationsEnabled: chatNotifications,
      likeNotificationsEnabled: likeNotifications,
      tagNotificationsEnabled: tagNotifications,
      commentNotificationsEnabled: commentNotifications,
      matchNotificationsEnabled: matchNotifications,
      notificationFrequency: notificationFrequency,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preferences saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notification Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('Chat Notifications'),
            value: chatNotifications,
            onChanged: (value) {
              setState(() => chatNotifications = value);
              _savePreferences();
            },
          ),
          SwitchListTile(
            title: Text('Like Notifications'),
            value: likeNotifications,
            onChanged: (value) {
              setState(() => likeNotifications = value);
              _savePreferences();
            },
          ),
          SwitchListTile(
            title: Text('Tag Notifications'),
            value: tagNotifications,
            onChanged: (value) {
              setState(() => tagNotifications = value);
              _savePreferences();
            },
          ),
          SwitchListTile(
            title: Text('Comment Notifications'),
            value: commentNotifications,
            onChanged: (value) {
              setState(() => commentNotifications = value);
              _savePreferences();
            },
          ),
          SwitchListTile(
            title: Text('Match Notifications'),
            value: matchNotifications,
            onChanged: (value) {
              setState(() => matchNotifications = value);
              _savePreferences();
            },
          ),
          ListTile(
            title: Text('Notification Frequency'),
            trailing: DropdownButton<String>(
              value: notificationFrequency,
              items: ['low', 'medium', 'high']
                  .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.toUpperCase()),
                  ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => notificationFrequency = value);
                  _savePreferences();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

## Error Handling

### Best Practices

```dart
// Always wrap notification calls in try-catch
Future<void> safeNotification() async {
  try {
    await NotificationService().sendChatNotification(
      recipientId: recipientId,
      senderId: senderId,
      senderName: senderName,
      senderImage: senderImage,
      messageContent: content,
      conversationId: conversationId,
    );
  } catch (e) {
    // Log error but don't fail the main operation
    print('Notification error: $e');
    // Optionally send to error tracking service
  }
}
```

## Testing

### Unit Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('NotificationService', () {
    late NotificationService notificationService;

    setUp(() {
      notificationService = NotificationService();
    });

    test('sendChatNotification should save to Firestore', () async {
      await notificationService.sendChatNotification(
        recipientId: 'user2',
        senderId: 'user1',
        senderName: 'John',
        senderImage: 'image_url',
        messageContent: 'Hello',
        conversationId: 'conv1',
      );

      // Verify Firestore was called
      // Add your assertions here
    });
  });
}
```

## Performance Tips

1. **Batch notifications** when possible
2. **Debounce rapid notifications** (e.g., multiple likes)
3. **Cache user preferences** locally
4. **Use Firestore indexing** for queries
5. **Implement notification throttling**
6. **Monitor memory usage** with large notification queues
