# Cloud Functions Template for FCM

This guide provides Cloud Functions templates for sending FCM messages server-side.

## Setup

### 1. Initialize Firebase Functions

```bash
cd functions
npm install firebase-functions firebase-admin
```

### 2. Deploy Functions

```bash
firebase deploy --only functions
```

## Cloud Functions Implementation

### Function 1: Send Notification on Firestore Write

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Sends FCM notification when a notification document is created
 */
exports.sendNotificationOnCreate = functions.firestore
  .document('users/{userId}/notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const userId = context.params.userId;

    try {
      // Get user's FCM token
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();

      const fcmToken = userDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for user ${userId}`);
        return;
      }

      // Prepare FCM message
      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: {
          type: notification.type,
          ...notification.data,
        },
        token: fcmToken,
      };

      // Send message
      const response = await admin.messaging().send(message);
      console.log('Successfully sent message:', response);

      // Update notification with sent status
      await snap.ref.update({
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        sentStatus: 'success',
      });

    } catch (error) {
      console.error('Error sending notification:', error);

      // Update notification with error status
      await snap.ref.update({
        sentStatus: 'failed',
        error: error.message,
      });
    }
  });

/**
 * Sends multicast notifications to multiple users
 */
exports.sendBulkNotifications = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { userIds, title, body, type, data: notificationData } = data;

  if (!Array.isArray(userIds) || userIds.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'userIds must be a non-empty array'
    );
  }

  try {
    const tokens = [];
    const userTokenMap = {};

    // Get FCM tokens for all users
    for (const userId of userIds) {
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();

      const token = userDoc.data()?.fcmToken;
      if (token) {
        tokens.push(token);
        userTokenMap[token] = userId;
      }
    }

    if (tokens.length === 0) {
      return {
        success: false,
        message: 'No valid FCM tokens found',
      };
    }

    // Prepare multicast message
    const message = {
      notification: {
        title,
        body,
      },
      data: {
        type,
        ...notificationData,
      },
    };

    // Send to all tokens
    const response = await admin.messaging().sendMulticast({
      ...message,
      tokens,
    });

    console.log(`Successfully sent ${response.successCount} messages`);
    console.log(`Failed to send ${response.failureCount} messages`);

    // Handle failures
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(tokens[idx]);
        }
      });

      console.log('Failed tokens:', failedTokens);
    }

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };

  } catch (error) {
    console.error('Error sending bulk notifications:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send notifications'
    );
  }
});

/**
 * Scheduled function to send engagement notifications
 */
exports.sendEngagementNotifications = functions.pubsub
  .schedule('0 10 * * *') // Daily at 10 AM
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    try {
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('isVerified', '==', true)
        .get();

      const engagementMessages = [
        { title: 'New matches waiting! 🔥', body: 'Check out who\'s interested in you today.' },
        { title: 'Your profile is hot! 🌟', body: 'People are checking you out. Come see who!' },
        { title: 'Don\'t miss out! 💬', body: 'You have new messages and interactions.' },
        { title: 'Trending posts nearby 📱', body: 'See what\'s popular in your college right now.' },
        { title: 'Someone liked your vibe! 💕', body: 'Check out their profile and say hello.' },
      ];

      let sentCount = 0;
      let skippedCount = 0;

      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const userId = userDoc.id;

        // Check if should send engagement notification
        const shouldSend = await checkEngagementNotification(userId, userData);

        if (!shouldSend) {
          skippedCount++;
          continue;
        }

        // Get random message
        const message = engagementMessages[
          Math.floor(Math.random() * engagementMessages.length)
        ];

        // Create notification document
        await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            type: 'engagement',
            title: message.title,
            body: message.body,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            data: { action: 'open_feed' },
          });

        sentCount++;
      }

      console.log(`Sent ${sentCount} engagement notifications, skipped ${skippedCount}`);
      return { sentCount, skippedCount };

    } catch (error) {
      console.error('Error sending engagement notifications:', error);
      throw error;
    }
  });

/**
 * Helper function to check if engagement notification should be sent
 */
async function checkEngagementNotification(userId, userData) {
  const lastActiveTime = userData.lastActiveTime?.toDate?.() || new Date(0);
  const notificationFrequency = userData.notificationFrequency || 'medium';
  const engagementScore = userData.engagementScore || 0;

  // Don't send if user was active in last 30 minutes
  const timeSinceActive = Date.now() - lastActiveTime.getTime();
  if (timeSinceActive < 30 * 60 * 1000) {
    return false;
  }

  // Check notification frequency preference
  if (notificationFrequency === 'low') {
    return engagementScore < 30;
  } else if (notificationFrequency === 'high') {
    return engagementScore < 70;
  } else {
    // medium
    return engagementScore < 50;
  }
}

/**
 * Update engagement score for a user
 */
exports.updateEngagementScore = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const userId = context.auth.uid;

  try {
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    const userData = userDoc.data();

    // Calculate engagement score
    const lastActiveTime = userData.lastActiveTime?.toDate?.() || new Date(0);
    const totalPosts = userData.totalPosts || 0;
    const totalComments = userData.totalComments || 0;
    const totalLikes = userData.totalLikes || 0;
    const matchesCreated = userData.matchesCreated || 0;

    let score = 0;

    // Time-based scoring
    const hoursSinceActive = (Date.now() - lastActiveTime.getTime()) / (1000 * 60 * 60);
    if (hoursSinceActive > 24) {
      score += 40;
    } else if (hoursSinceActive > 12) {
      score += 25;
    } else if (hoursSinceActive > 6) {
      score += 10;
    }

    // Activity-based scoring
    if (totalPosts === 0) score += 15;
    if (totalComments === 0) score += 15;
    if (totalLikes === 0) score += 10;
    if (matchesCreated === 0) score += 10;

    // Cap score at 100
    score = Math.min(score, 100);

    // Update user document
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        engagementScore: score,
        lastEngagementScoreUpdate: admin.firestore.FieldValue.serverTimestamp(),
      });

    return { success: true, engagementScore: score };

  } catch (error) {
    console.error('Error updating engagement score:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update engagement score'
    );
  }
});

/**
 * Handle token refresh
 */
exports.updateFCMToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { token } = data;
  const userId = context.auth.uid;

  if (!token) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'FCM token is required'
    );
  }

  try {
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        fcmToken: token,
        lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
      });

    return { success: true };

  } catch (error) {
    console.error('Error updating FCM token:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update FCM token'
    );
  }
});

/**
 * Send test notification
 */
exports.sendTestNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const userId = context.auth.uid;
  const { title, body } = data;

  try {
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
      throw new functions.https.HttpsError(
        'not-found',
        'No FCM token found for user'
      );
    }

    const message = {
      notification: { title, body },
      data: { type: 'test' },
      token: fcmToken,
    };

    const response = await admin.messaging().send(message);
    return { success: true, messageId: response };

  } catch (error) {
    console.error('Error sending test notification:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send test notification'
    );
  }
});
```

## Deployment

### 1. Deploy All Functions

```bash
firebase deploy --only functions
```

### 2. Deploy Specific Function

```bash
firebase deploy --only functions:sendNotificationOnCreate
```

### 3. View Logs

```bash
firebase functions:log
```

## Testing Cloud Functions

### Test sendNotification Trigger

```bash
# Create a test notification document
firebase firestore:set users/test-user/notifications/test-notif \
  --data '{
    "title": "Test",
    "body": "Test notification",
    "type": "test",
    "timestamp": "2024-01-01T00:00:00Z"
  }'
```

### Test Callable Functions

```javascript
// From Flutter app
final functions = FirebaseFunctions.instance;

try {
  final result = await functions.httpsCallable('sendTestNotification').call({
    'title': 'Test Notification',
    'body': 'This is a test',
  });
  print('Success: ${result.data}');
} catch (e) {
  print('Error: $e');
}
```

## Monitoring

### View Function Metrics

```bash
firebase functions:describe
```

### Monitor Logs

```bash
firebase functions:log --limit 50
```

### Set Up Alerts

In Firebase Console:
1. Go to Functions
2. Click on function name
3. Go to Logs tab
4. Set up error alerts

## Best Practices

1. **Error Handling**: Always wrap in try-catch
2. **Logging**: Log important events for debugging
3. **Rate Limiting**: Implement rate limiting for callable functions
4. **Validation**: Validate all input data
5. **Timeouts**: Set appropriate timeout values
6. **Memory**: Allocate sufficient memory for functions
7. **Costs**: Monitor function execution costs
8. **Security**: Verify authentication and authorization

## Troubleshooting

### Function Not Triggering

1. Check Firestore trigger path is correct
2. Verify function is deployed
3. Check function logs for errors
4. Ensure Firestore rules allow writes

### Messages Not Sending

1. Verify FCM token is valid
2. Check Firebase Console for errors
3. Verify notification format
4. Check user permissions

### Performance Issues

1. Optimize Firestore queries
2. Reduce function memory usage
3. Implement caching
4. Use batch operations

## Additional Resources

- [Firebase Functions Documentation](https://firebase.google.com/docs/functions)
- [Firebase Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Cloud Functions Best Practices](https://firebase.google.com/docs/functions/bestpractices/retries)
