import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/match_model.dart';
import '../models/user_model.dart';
import 'chat_service.dart';
import 'notification_service.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();
  static const uuid = Uuid();

  // Cast a vote (hot or not)
  Future<void> castVote({
    required String voterId,
    required String targetId,
    required bool isHot,
  }) async {
    try {
      final voteId = '${voterId}_$targetId';
      final vote = Vote(
        id: voteId,
        voterId: voterId,
        targetId: targetId,
        isHot: isHot,
        timestamp: DateTime.now(),
      );

      await _firestore.collection('votes').doc(voteId).set(vote.toMap());

      // Check if there's a mutual match
      if (isHot) {
        await _checkAndCreateMatch(voterId, targetId);
      }
    } catch (e) {
      throw Exception('Failed to cast vote: $e');
    }
  }

  // Check if both users voted hot for each other
  Future<void> _checkAndCreateMatch(String user1Id, String user2Id) async {
    try {
      // Check if user2 also voted hot for user1
      final reverseVoteId = '${user2Id}_$user1Id';
      final reverseVoteDoc = await _firestore.collection('votes').doc(reverseVoteId).get();

      if (reverseVoteDoc.exists) {
        final reverseVote = Vote.fromMap(reverseVoteDoc.data()!, reverseVoteDoc.id);
        
        if (reverseVote.isHot) {
          // It's a match! Check if match already exists
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

            // Get user info for notifications
            final user1Doc = await _firestore.collection('users').doc(user1Id).get();
            final user2Doc = await _firestore.collection('users').doc(user2Id).get();

            final user1Name = user1Doc['name'] as String? ?? 'Someone';
            final user1Image = user1Doc['avatarUrl'] as String? ?? '';
            final user2Name = user2Doc['name'] as String? ?? 'Someone';
            final user2Image = user2Doc['avatarUrl'] as String? ?? '';

            // Send match notifications to both users
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

  // Get potential matches (users not yet voted on)
  Future<List<UserModel>> getPotentialMatches(String currentUserId) async {
    try {
      // Get all users
      final usersSnapshot = await _firestore
          .collection('users')
          .where('isVerified', isEqualTo: true)
          .limit(50)
          .get();

      // Get votes by current user
      final votesSnapshot = await _firestore
          .collection('votes')
          .where('voterId', isEqualTo: currentUserId)
          .get();

      final votedUserIds = votesSnapshot.docs
          .map((doc) => Vote.fromMap(doc.data(), doc.id).targetId)
          .toSet();

      // Filter out current user and already voted users
      final potentialMatches = <UserModel>[];
      for (final doc in usersSnapshot.docs) {
        final user = UserModel.fromMap(doc.data());
        if (user.uid != currentUserId && !votedUserIds.contains(user.uid)) {
          potentialMatches.add(user);
        }
      }

      return potentialMatches;
    } catch (e) {
      throw Exception('Failed to get potential matches: $e');
    }
  }

  // Get all matches for a user (optimized with compound query)
  Stream<List<Match>> streamMatches(String userId) {
    return _firestore
        .collection('matches')
        .where('user1Id', isEqualTo: userId)
        .orderBy('matchedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot1) async {
      final matches1 = snapshot1.docs
          .map((doc) => Match.fromMap(doc.data(), doc.id))
          .toList();

      // Only fetch user2 matches if needed (limit to avoid excessive reads)
      final snapshot2 = await _firestore
          .collection('matches')
          .where('user2Id', isEqualTo: userId)
          .orderBy('matchedAt', descending: true)
          .limit(100) // Cap to prevent excessive reads
          .get();

      final matches2 = snapshot2.docs
          .map((doc) => Match.fromMap(doc.data(), doc.id))
          .toList();

      return [...matches1, ...matches2]
        ..sort((a, b) => b.matchedAt.compareTo(a.matchedAt));
    });
  }

  // Create conversation for a match
  Future<String> createMatchConversation({
    required String matchId,
    required String user1Id,
    required String user1Name,
    required String user1Image,
    required String user2Id,
    required String user2Name,
    required String user2Image,
  }) async {
    try {
      final conversationId = await _chatService.getOrCreateConversation(
        user1Id: user1Id,
        user1Name: user1Name,
        user1Image: user1Image,
        user2Id: user2Id,
        user2Name: user2Name,
        user2Image: user2Image,
      );

      // Update match with conversation ID
      await _firestore.collection('matches').doc(matchId).update({
        'conversationId': conversationId,
      });

      return conversationId;
    } catch (e) {
      throw Exception('Failed to create match conversation: $e');
    }
  }

  // Check if user has voted on target
  Future<bool> hasVoted(String voterId, String targetId) async {
    try {
      final voteId = '${voterId}_$targetId';
      final doc = await _firestore.collection('votes').doc(voteId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get vote if exists
  Future<Vote?> getVote(String voterId, String targetId) async {
    try {
      final voteId = '${voterId}_$targetId';
      final doc = await _firestore.collection('votes').doc(voteId).get();
      if (doc.exists) {
        return Vote.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
