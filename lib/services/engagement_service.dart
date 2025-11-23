import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';

class EngagementService {
  static final EngagementService _instance = EngagementService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();

  factory EngagementService() {
    return _instance;
  }

  EngagementService._internal();

  /// Algorithm to determine if user should receive engagement notification
  /// Based on user activity patterns and app engagement metrics
  Future<bool> shouldSendEngagementNotification(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final lastActiveTime = userDoc['lastActiveTime'] as Timestamp?;
      final notificationFrequency = userDoc['notificationFrequency'] ?? 'medium';
      final engagementScore = userDoc['engagementScore'] ?? 0;

      // Don't send if user was active in last 30 minutes
      if (lastActiveTime != null) {
        final timeSinceActive = DateTime.now().difference(lastActiveTime.toDate());
        if (timeSinceActive.inMinutes < 30) {
          return false;
        }
      }

      // Check notification frequency preference
      if (notificationFrequency == 'low') {
        return engagementScore < 30; // Only send if engagement is very low
      } else if (notificationFrequency == 'high') {
        return engagementScore < 70; // Send more frequently
      } else {
        // medium frequency
        return engagementScore < 50;
      }
    } catch (e) {
      print('Error checking engagement notification: $e');
      return false;
    }
  }

  /// Calculate engagement score based on user activity
  Future<int> calculateEngagementScore(String userId) async {
    try {
      int score = 0;

      // Get user activity data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final lastActiveTime = userDoc['lastActiveTime'] as Timestamp?;
      final totalPosts = userDoc['totalPosts'] ?? 0;
      final totalComments = userDoc['totalComments'] ?? 0;
      final totalLikes = userDoc['totalLikes'] ?? 0;
      final matchesCreated = userDoc['matchesCreated'] ?? 0;

      // Time-based scoring (higher score if inactive)
      if (lastActiveTime != null) {
        final hoursSinceActive =
            DateTime.now().difference(lastActiveTime.toDate()).inHours;
        if (hoursSinceActive > 24) {
          score += 40; // Very inactive
        } else if (hoursSinceActive > 12) {
          score += 25; // Moderately inactive
        } else if (hoursSinceActive > 6) {
          score += 10; // Somewhat inactive
        }
      } else {
        score += 50; // Never active
      }

      // Activity-based scoring (lower score for active users)
      if (totalPosts == 0) score += 15;
      if (totalComments == 0) score += 15;
      if (totalLikes == 0) score += 10;
      if (matchesCreated == 0) score += 10;

      // Cap score at 100
      return score.clamp(0, 100);
    } catch (e) {
      print('Error calculating engagement score: $e');
      return 50; // Default medium score
    }
  }

  /// Send engagement notification to keep user active
  Future<void> sendEngagementNotification(String userId) async {
    try {
      final shouldSend = await shouldSendEngagementNotification(userId);
      if (!shouldSend) return;

      final engagementMessages = [
        {
          'title': 'New matches waiting! 🔥',
          'body': 'Check out who\'s interested in you today.',
        },
        {
          'title': 'Your profile is hot! 🌟',
          'body': 'People are checking you out. Come see who!',
        },
        {
          'title': 'Don\'t miss out! 💬',
          'body': 'You have new messages and interactions.',
        },
        {
          'title': 'Trending posts nearby 📱',
          'body': 'See what\'s popular in your college right now.',
        },
        {
          'title': 'Someone liked your vibe! 💕',
          'body': 'Check out their profile and say hello.',
        },
      ];

      final randomMessage =
          engagementMessages[DateTime.now().millisecond % engagementMessages.length];

      await _fcmService.sendNotification(
        userId: userId,
        type: 'engagement',
        title: randomMessage['title'] as String,
        body: randomMessage['body'] as String,
        data: {'action': 'open_feed'},
      );

      // Update last engagement notification time
      await _firestore.collection('users').doc(userId).update({
        'lastEngagementNotification': DateTime.now(),
      });
    } catch (e) {
      print('Error sending engagement notification: $e');
    }
  }

  /// Update user engagement metrics
  Future<void> updateEngagementMetrics(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastActiveTime': DateTime.now(),
      });
    } catch (e) {
      print('Error updating engagement metrics: $e');
    }
  }

  /// Batch send engagement notifications to inactive users (optimized)
  Future<void> sendBatchEngagementNotifications() async {
    try {
      // OPTIMIZATION: Only fetch inactive users instead of all users
      final now = DateTime.now();
      final thirtyMinutesAgo = now.subtract(const Duration(minutes: 30));
      
      final usersSnapshot = await _firestore
          .collection('users')
          .where('isVerified', isEqualTo: true)
          .where('lastActiveTime', isLessThan: Timestamp.fromDate(thirtyMinutesAgo))
          .limit(100) // Batch in chunks to avoid excessive reads
          .get();

      for (final userDoc in usersSnapshot.docs) {
        await sendEngagementNotification(userDoc.id);
      }
    } catch (e) {
      print('Error sending batch engagement notifications: $e');
    }
  }
}
