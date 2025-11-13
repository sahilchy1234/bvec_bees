import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../models/match_model.dart';
import '../models/user_model.dart';
import 'chat_service.dart';

class HotNotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();
  static const uuid = Uuid();
  
  // Constants for algorithm
  static const int cooldownHours = 2;
  static const int newUserBoostHours = 24;
  static const int feedLimit = 20; // Users to show at once

  /// Get feed of potential matches with Hot & Not algorithm
  Future<List<UserModel>> getFeed({
    required String currentUserId,
    required String? currentUserGender,
    required String? lookingFor,
    String? genderFilter, // Optional gender filter from settings
  }) async {
    try {
      final now = DateTime.now();
      final cooldownTime = now.subtract(const Duration(hours: cooldownHours));
      
      // Get all verified users
      Query usersQuery = _firestore
          .collection('users')
          .where('isVerified', isEqualTo: true);
      
      final usersSnapshot = await usersQuery.get();
      
      // Get user's votes to filter out recently voted users
      final votesSnapshot = await _firestore
          .collection('votes')
          .where('voterId', isEqualTo: currentUserId)
          .where('timestamp', isGreaterThan: cooldownTime)
          .get();
      
      final recentlyVotedIds = votesSnapshot.docs
          .map((doc) => Vote.fromMap(doc.data(), doc.id).targetId)
          .toSet();
      
      // Filter users based on criteria
      final eligibleUsers = <UserModel>[];
      final boostedUsers = <UserModel>[];
      
      for (final doc in usersSnapshot.docs) {
        final user = UserModel.fromMap({...doc.data() as Map<String, dynamic>, 'uid': doc.id});
        
        // Skip current user
        if (user.uid == currentUserId) continue;
        
        // Skip recently voted users (cooldown)
        if (recentlyVotedIds.contains(user.uid)) continue;
        
        // Apply gender preference filters
        if (!_matchesGenderPreference(
          currentUserGender: currentUserGender,
          currentUserLookingFor: lookingFor,
          targetUserGender: user.gender,
          targetUserLookingFor: user.lookingFor,
          genderFilter: genderFilter,
        )) continue;
        
        // Check if user has new user boost
        if (user.boostUntil != null && user.boostUntil!.isAfter(now)) {
          boostedUsers.add(user);
        } else {
          eligibleUsers.add(user);
        }
      }
      
      // Shuffle for randomness (equal chance algorithm)
      eligibleUsers.shuffle(Random());
      boostedUsers.shuffle(Random());
      
      // Combine boosted users first, then regular users
      final feedUsers = <UserModel>[];
      feedUsers.addAll(boostedUsers);
      feedUsers.addAll(eligibleUsers);
      
      // Return limited feed
      return feedUsers.take(feedLimit).toList();
      
    } catch (e) {
      throw Exception('Failed to get feed: $e');
    }
  }
  
  /// Check if users match gender preferences
  bool _matchesGenderPreference({
    required String? currentUserGender,
    required String? currentUserLookingFor,
    required String? targetUserGender,
    required String? targetUserLookingFor,
    String? genderFilter,
  }) {
    // Apply gender filter from settings if provided
    if (genderFilter != null && genderFilter != 'all') {
      if (targetUserGender != genderFilter) return false;
    }
    
    // Check current user's preference
    if (currentUserLookingFor != null && currentUserLookingFor != 'both') {
      if (currentUserLookingFor == 'opposite') {
        if (currentUserGender == 'male' && targetUserGender != 'female') return false;
        if (currentUserGender == 'female' && targetUserGender != 'male') return false;
      } else if (currentUserLookingFor == 'same') {
        if (currentUserGender != targetUserGender) return false;
      }
    }
    
    // Check target user's preference
    if (targetUserLookingFor != null && targetUserLookingFor != 'both') {
      if (targetUserLookingFor == 'opposite') {
        if (targetUserGender == 'male' && currentUserGender != 'female') return false;
        if (targetUserGender == 'female' && currentUserGender != 'male') return false;
      } else if (targetUserLookingFor == 'same') {
        if (targetUserGender != currentUserGender) return false;
      }
    }
    
    return true;
  }
  
  /// Cast a vote (Hot or Not)
  Future<bool> castVote({
    required String voterId,
    required String targetId,
    required bool isHot,
  }) async {
    try {
      final voteId = '${voterId}_$targetId';
      final now = DateTime.now();
      
      final vote = Vote(
        id: voteId,
        voterId: voterId,
        targetId: targetId,
        isHot: isHot,
        timestamp: now,
      );

      await _firestore.collection('votes').doc(voteId).set(vote.toMap());

      // If hot vote, increment target's hot count
      if (isHot) {
        await _firestore.collection('users').doc(targetId).update({
          'hotCount': FieldValue.increment(1),
        });
        
        // Check for mutual match
        final isMatch = await _checkAndCreateMatch(voterId, targetId);
        return isMatch;
      }
      
      return false;
    } catch (e) {
      throw Exception('Failed to cast vote: $e');
    }
  }
  
  /// Remove a hot vote (unhot)
  Future<void> unhotUser({
    required String voterId,
    required String targetId,
  }) async {
    try {
      final voteId = '${voterId}_$targetId';
      
      // Check if vote exists and is hot
      final voteDoc = await _firestore.collection('votes').doc(voteId).get();
      if (voteDoc.exists) {
        final vote = Vote.fromMap(voteDoc.data()!, voteDoc.id);
        if (vote.isHot) {
          // Decrement target's hot count
          await _firestore.collection('users').doc(targetId).update({
            'hotCount': FieldValue.increment(-1),
          });
          
          // Deactivate any existing match
          await _deactivateMatch(voterId, targetId);
        }
      }
      
      // Delete the vote (will allow reappearance after cooldown)
      await _firestore.collection('votes').doc(voteId).delete();
      
    } catch (e) {
      throw Exception('Failed to unhot user: $e');
    }
  }
  
  /// Check if both users voted hot and create match
  Future<bool> _checkAndCreateMatch(String user1Id, String user2Id) async {
    try {
      // Check if user2 also voted hot for user1
      final reverseVoteId = '${user2Id}_$user1Id';
      final reverseVoteDoc = await _firestore.collection('votes').doc(reverseVoteId).get();

      if (reverseVoteDoc.exists) {
        final reverseVote = Vote.fromMap(reverseVoteDoc.data()!, reverseVoteDoc.id);
        
        if (reverseVote.isHot) {
          // Check if match already exists
          final existingMatches = await _firestore
              .collection('matches')
              .where('user1Id', whereIn: [user1Id, user2Id])
              .where('isActive', isEqualTo: true)
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
            // Create match and chat automatically
            await _createMatchWithChat(user1Id, user2Id);
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      throw Exception('Failed to check match: $e');
    }
  }
  
  /// Create match and automatically create chat
  Future<void> _createMatchWithChat(String user1Id, String user2Id) async {
    try {
      // Get user details
      final user1Doc = await _firestore.collection('users').doc(user1Id).get();
      final user2Doc = await _firestore.collection('users').doc(user2Id).get();
      
      if (!user1Doc.exists || !user2Doc.exists) return;
      
      final user1 = UserModel.fromMap({...user1Doc.data()!, 'uid': user1Id});
      final user2 = UserModel.fromMap({...user2Doc.data()!, 'uid': user2Id});
      
      // Create conversation first
      final conversationId = await _chatService.getOrCreateConversation(
        user1Id: user1Id,
        user1Name: user1.name ?? 'User',
        user1Image: user1.avatarUrl ?? '',
        user2Id: user2Id,
        user2Name: user2.name ?? 'User',
        user2Image: user2.avatarUrl ?? '',
      );
      
      // Create match with conversation ID
      final matchId = uuid.v4();
      final match = Match(
        id: matchId,
        user1Id: user1Id,
        user2Id: user2Id,
        matchedAt: DateTime.now(),
        conversationId: conversationId,
        isActive: true,
      );

      await _firestore.collection('matches').doc(matchId).set(match.toMap());
      
    } catch (e) {
      throw Exception('Failed to create match with chat: $e');
    }
  }

  /// Check if a conversation belongs to an active match for the given user
  Future<bool> isMatchConversation(String conversationId, String userId) async {
    try {
      if (conversationId.isEmpty) return false;

      final snapshot = await _firestore
          .collection('matches')
          .where('conversationId', isEqualTo: conversationId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return false;

      final match = Match.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      return match.user1Id == userId || match.user2Id == userId;
    } catch (e) {
      throw Exception('Failed to check match conversation: $e');
    }
  }

  /// Deactivate match when user unhots
  Future<void> _deactivateMatch(String user1Id, String user2Id) async {
    try {
      final matchesSnapshot = await _firestore
          .collection('matches')
          .where('user1Id', whereIn: [user1Id, user2Id])
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in matchesSnapshot.docs) {
        final match = Match.fromMap(doc.data(), doc.id);
        if ((match.user1Id == user1Id && match.user2Id == user2Id) ||
            (match.user1Id == user2Id && match.user2Id == user1Id)) {
          await _firestore.collection('matches').doc(match.id).update({
            'isActive': false,
          });
          break;
        }
      }
    } catch (e) {
      throw Exception('Failed to deactivate match: $e');
    }
  }
  
  /// Get users that current user voted "Hot" for
  Stream<List<UserModel>> streamHottedUsers(String currentUserId) {
    return _firestore
        .collection('votes')
        .where('voterId', isEqualTo: currentUserId)
        .where('isHot', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final userIds = snapshot.docs
          .map((doc) => Vote.fromMap(doc.data(), doc.id).targetId)
          .toList();
      
      if (userIds.isEmpty) return <UserModel>[];
      
      final users = <UserModel>[];
      for (final userId in userIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          users.add(UserModel.fromMap({...userDoc.data()!, 'uid': userId}));
        }
      }
      
      return users;
    });
  }
  
  /// Get active matches for user
  Stream<List<Match>> streamMatches(String userId) {
    return _firestore
        .collection('matches')
        .where('user1Id', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot1) async {
      final matches1 = snapshot1.docs
          .map((doc) => Match.fromMap(doc.data(), doc.id))
          .toList();

      final snapshot2 = await _firestore
          .collection('matches')
          .where('user2Id', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final matches2 = snapshot2.docs
          .map((doc) => Match.fromMap(doc.data(), doc.id))
          .toList();

      return [...matches1, ...matches2]
        ..sort((a, b) => (b.lastMessageAt ?? b.matchedAt).compareTo(a.lastMessageAt ?? a.matchedAt));
    });
  }
  
  /// Get leaderboard (top 10 most hotted users)
  Future<List<UserModel>> getLeaderboard() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isVerified', isEqualTo: true)
          .where('hotCount', isGreaterThan: 0)
          .orderBy('hotCount', descending: true)
          .limit(10)
          .get();
      
      return snapshot.docs
          .map((doc) => UserModel.fromMap({...doc.data(), 'uid': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to get leaderboard: $e');
    }
  }
  
  /// Set new user boost (called during registration)
  Future<void> setNewUserBoost(String userId) async {
    try {
      final boostUntil = DateTime.now().add(const Duration(hours: newUserBoostHours));
      await _firestore.collection('users').doc(userId).update({
        'boostUntil': boostUntil.toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to set new user boost: $e');
    }
  }
  
  /// Check if user has voted on target
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
