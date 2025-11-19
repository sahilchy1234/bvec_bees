# Firebase Cloud Messaging (FCM) & Engagement System Guide

## Overview

This guide documents the complete FCM notification system and engagement algorithm implemented for the Beezy app. The system handles real-time notifications for chat messages, post interactions, matches, and engagement-based notifications to keep users active.

## Architecture

### Core Components

1. **FCMService** (`lib/services/fcm_service.dart`)
   - Singleton service managing Firebase Cloud Messaging
   - Handles local notifications display
   - Manages FCM token storage and refresh
   - Processes foreground and background messages

2. **NotificationService** (`lib/services/notification_service.dart`)
   - High-level notification API
   - Handles specific notification types
   - Manages notification preferences
   - Sends notifications to Firestore

3. **EngagementService** (`lib/services/engagement_service.dart`)
   - Calculates user engagement scores
   - Determines when to send engagement notifications
   - Implements engagement algorithm
   - Batch sends notifications to inactive users

4. **NotificationModel** (`lib/models/notification_model.dart`)
   - Data model for notifications
   - Firestore serialization/deserialization

## Notification Types

### 1. Chat Messages
**Trigger:** When a message is sent in a conversation
**Recipient:** Message recipient
**Data:**
```dart
{
  'type': 'chat',
  'conversationId': conversationId,
  'senderId': senderId,
}
```

**Implementation:**
```dart
await NotificationService().sendChatNotification(
  recipientId: recipientId,
  senderId: senderId,
  senderName: senderName,
  senderImage: senderImage,
  messageContent: content,
  conversationId: conversationId,
);
```

### 2. Post Likes/Reactions
**Trigger:** When someone reacts to a post (like, love, care, haha, wow, sad, angry)
**Recipient:** Post owner
**Data:**
```dart
{
  'type': 'post_like',
  'postId': postId,
  'likerId': likerId,
  'reactionType': reactionType,
}
```

**Implementation:**
```dart
await NotificationService().sendPostLikeNotification(
  postOwnerId: postOwnerId,
  likerId: likerId,
  likerName: likerName,
  likerImage: likerImage,
  postId: postId,
  reactionType: reactionType,
);
```

### 3. Tag Notifications
**Trigger:** When a user is mentioned/tagged in a post
**Recipient:** Tagged user
**Data:**
```dart
{
  'type': 'tag',
  'postId': postId,
  'taggerId': taggerId,
}
```

**Implementation:**
```dart
await NotificationService().sendTagNotification(
  taggedUserId: taggedUserId,
  taggerId: taggerId,
  taggerName: taggerName,
  taggerImage: taggerImage,
  postId: postId,
  postPreview: postPreview,
);
```

### 4. Comment Notifications
**Trigger:** When someone comments on your post
**Recipient:** Post owner
**Data:**
```dart
{
  'type': 'comment',
  'postId': postId,
  'commenterId': commenterId,
}
```

**Implementation:**
```dart
await NotificationService().sendCommentNotification(
  postOwnerId: postOwnerId,
  commenterId: commenterId,
  commenterName: commenterName,
  commenterImage: commenterImage,
  postId: postId,
  commentContent: content,
);
```

### 5. Match Notifications
**Trigger:** When two users like each other (mutual match)
**Recipient:** Both matched users
**Data:**
```dart
{
  'type': 'match',
  'matchId': matchId,
  'userId2': userId2,
}
```

**Implementation:**
```dart
await NotificationService().sendMatchNotification(
  userId1: userId1,
  userId2: userId2,
  user2Name: user2Name,
  user2Image: user2Image,
  matchId: matchId,
);
```

### 6. Engagement Notifications
**Trigger:** Based on engagement algorithm (user inactivity)
**Recipient:** Inactive users
**Data:**
```dart
{
  'type': 'engagement',
  'action': 'open_feed',
}
```

**Implementation:**
```dart
await EngagementService().sendEngagementNotification(userId);
```

## Engagement Algorithm

### How It Works

The engagement algorithm keeps users active by sending timely notifications based on their activity patterns.

#### Engagement Score Calculation

```dart
int calculateEngagementScore(String userId) {
  // Returns 0-100 score
  // Higher score = more inactive user
  
  // Factors:
  // - Time since last active (0-40 points)
  // - Total posts created (0-15 points)
  // - Total comments made (0-15 points)
  // - Total likes given (0-10 points)
  // - Matches created (0-10 points)
}
```

#### Notification Frequency

Based on user's `notificationFrequency` preference:

- **Low**: Only notify if engagement score < 30 (very inactive)
- **Medium**: Notify if engagement score < 50 (moderately inactive)
- **High**: Notify if engagement score < 70 (frequently notify)

#### Conditions for Sending

1. User was NOT active in last 30 minutes
2. User's engagement score meets threshold
3. User has notifications enabled
4. User hasn't received engagement notification recently

### Engagement Messages

The system randomly selects from these messages:
- "New matches waiting! 🔥 Check out who's interested in you today."
- "Your profile is hot! 🌟 People are checking you out. Come see who!"
- "Don't miss out! 💬 You have new messages and interactions."
- "Trending posts nearby 📱 See what's popular in your college right now."
- "Someone liked your vibe! 💕 Check out their profile and say hello."

## Setup Instructions

### 1. Firebase Configuration

Ensure Firebase is initialized in `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize FCM
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    await FCMService().initialize(currentUser.uid);
  }
  
  runApp(MyApp(...));
}
```

### 2. Firestore Schema

Add these fields to user documents:

```json
{
  "uid": "user_id",
  "fcmToken": "firebase_token",
  "lastTokenUpdate": "timestamp",
  "lastActiveTime": "timestamp",
  "lastEngagementNotification": "timestamp",
  "chatNotificationsEnabled": true,
  "likeNotificationsEnabled": true,
  "tagNotificationsEnabled": true,
  "commentNotificationsEnabled": true,
  "matchNotificationsEnabled": true,
  "notificationFrequency": "medium", // "low", "medium", "high"
  "engagementScore": 50,
  "totalPosts": 0,
  "totalComments": 0,
  "totalLikes": 0,
  "matchesCreated": 0
}
```

### 3. Android Configuration

Create notification channel in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### 4. iOS Configuration

Add to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>remote-notification</string>
</array>
```

## Usage Examples

### Sending Chat Notification

```dart
// In ChatService.sendMessage()
await NotificationService().sendChatNotification(
  recipientId: recipientId,
  senderId: senderId,
  senderName: senderName,
  senderImage: senderImage,
  messageContent: content,
  conversationId: conversationId,
);
```

### Sending Post Like Notification

```dart
// In PostService.setReaction()
await NotificationService().sendPostLikeNotification(
  postOwnerId: postOwnerId,
  likerId: userId,
  likerName: userName,
  likerImage: userImage,
  postId: postId,
  reactionType: reactionKey,
);
```

### Sending Comment Notification

```dart
// In CommentService.addComment()
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
```

### Sending Match Notification

```dart
// In MatchService._checkAndCreateMatch()
await NotificationService().sendMatchNotification(
  userId1: user1Id,
  userId2: user2Id,
  user2Name: user2Name,
  user2Image: user2Image,
  matchId: matchId,
);
```

### Sending Engagement Notification

```dart
// Manually trigger
await EngagementService().sendEngagementNotification(userId);

// Batch send to all inactive users
await EngagementService().sendBatchEngagementNotifications();
```

### Updating User Engagement Metrics

```dart
// Call when user opens app or performs action
await EngagementService().updateEngagementMetrics(userId);
```

## Notification Preferences

Users can customize their notification settings:

```dart
await NotificationService().updateNotificationPreferences(
  userId,
  chatNotificationsEnabled: true,
  likeNotificationsEnabled: true,
  tagNotificationsEnabled: true,
  commentNotificationsEnabled: true,
  matchNotificationsEnabled: true,
  notificationFrequency: 'medium', // 'low', 'medium', 'high'
);
```

## Cloud Functions (Backend)

For production, implement Cloud Functions to send FCM messages:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendNotification = functions.firestore
  .document('users/{userId}/notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const userId = context.params.userId;
    
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    const fcmToken = userDoc.data().fcmToken;
    
    if (!fcmToken) return;
    
    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: notification.data || {},
      token: fcmToken,
    };
    
    return admin.messaging().send(message);
  });
```

## Best Practices

1. **Always check notification preferences** before sending
2. **Don't notify on self-actions** (user liking own post, etc.)
3. **Rate limit notifications** to prevent spam
4. **Update engagement metrics** on user activity
5. **Test with Firebase Emulator** before production
6. **Monitor notification delivery** in Firebase Console
7. **Handle token refresh** automatically
8. **Gracefully handle errors** when FCM unavailable

## Troubleshooting

### Notifications Not Showing

1. Check FCM token is saved in Firestore
2. Verify notification permissions granted on device
3. Check notification channel exists (Android)
4. Verify notification preferences are enabled
5. Check Firebase Console for delivery errors

### Token Issues

1. FCM token automatically refreshes on app restart
2. Monitor `lastTokenUpdate` timestamp
3. Implement token refresh listener
4. Handle token expiration gracefully

### Performance

1. Use batch operations for multiple notifications
2. Implement notification debouncing
3. Cache user preferences locally
4. Use Firestore indexing for queries

## Files Modified

- `lib/main.dart` - Added FCM initialization
- `lib/services/chat_service.dart` - Added chat notifications
- `lib/services/comment_service.dart` - Added comment notifications
- `lib/services/post_service.dart` - Added like notifications
- `lib/services/match_service.dart` - Added match notifications

## Files Created

- `lib/services/fcm_service.dart` - Core FCM service
- `lib/services/notification_service.dart` - Notification API
- `lib/services/engagement_service.dart` - Engagement algorithm
- `lib/models/notification_model.dart` - Notification data model

## Next Steps

1. Deploy Cloud Functions for server-side FCM sending
2. Implement notification center UI
3. Add notification history page
4. Set up analytics for notification engagement
5. A/B test engagement messages
6. Implement notification scheduling
7. Add notification sounds and vibration patterns
