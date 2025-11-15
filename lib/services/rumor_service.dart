import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/rumor_model.dart';
import '../models/rumor_comment_model.dart';
import 'rumor_cache_service.dart';

class RumorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RumorCacheService _cacheService = RumorCacheService.instance;
  static const String _rumorsCollection = 'rumors';
  static const String _commentsCollection = 'comments';
  static const int _defaultPageSize = 20;
  static const int _maxConcurrentRequests = 3;
  
  // Stream controller for debounced updates
  StreamController<List<RumorModel>>? _streamController;
  Timer? _debounceTimer;
  List<RumorModel>? _lastData;
  
  // Pagination state
  int _activeRequests = 0;
  final Map<String, Completer<List<RumorModel>>> _pendingRequests = {};

  // Get paginated rumors with caching
  Future<RumorCacheResult> getRumorsPaginated({
    int limit = _defaultPageSize,
    String? startAfterId,
    bool forceRefresh = false,
  }) async {
    // Check if we should use cache
    if (!forceRefresh) {
      final isFresh = await _cacheService.isCacheFresh();
      if (isFresh) {
        final cached = await _cacheService.getCachedRumors(
          limit: limit,
          startAfterId: startAfterId,
        );
        if (cached != null) {
          return cached;
        }
      }
    }
    
    // Check network connectivity
    final hasInternet = await _cacheService.hasInternetConnection();
    if (!hasInternet && !forceRefresh) {
      final cached = await _cacheService.getCachedRumors(
        limit: limit,
        startAfterId: startAfterId,
      );
      if (cached != null) {
        return cached;
      }
      throw Exception('No internet connection and no cached data available');
    }
    
    // Implement request throttling
    if (_activeRequests >= _maxConcurrentRequests) {
      throw Exception('Too many concurrent requests. Please try again.');
    }
    
    _activeRequests++;
    try {
      // Build query with pagination
      Query query = _firestore
          .collection(_rumorsCollection)
          .orderBy('timestamp', descending: true);
      
      if (startAfterId != null) {
        final startAfterDoc = await _firestore
            .collection(_rumorsCollection)
            .doc(startAfterId)
            .get();
        if (startAfterDoc.exists) {
          query = query.startAfterDocument(startAfterDoc);
        }
      }
      
      final snapshot = await query.limit(limit + 5).get(); // Fetch extra for algorithm
      
      final rumors = snapshot.docs
          .map((doc) => RumorModel.fromFirestore(doc))
          .toList();
      
      // Apply feed algorithm
      final processedRumors = _applyFeedAlgorithm(rumors);
      final limitedRumors = processedRumors.take(limit).toList();
      
      final hasMore = rumors.length > limit;
      final lastRumorId = limitedRumors.isNotEmpty ? limitedRumors.last.id : null;
      
      // Cache the results
      await _cacheService.cacheRumors(
        limitedRumors,
        isAppend: startAfterId != null,
        lastRumorId: lastRumorId,
        hasMore: hasMore,
      );
      
      return RumorCacheResult(
        rumors: limitedRumors,
        hasMore: hasMore,
        lastRumorId: lastRumorId,
        fromCache: false,
      );
    } finally {
      _activeRequests--;
    }
  }
  
  // Get all rumors with real-time updates (optimized)
  Stream<List<RumorModel>> getRumorsStream() {
    if (_streamController == null) {
      _streamController = StreamController<List<RumorModel>>.broadcast();
      
      // Use cached data initially if available
      _initializeStreamWithCache();
      
      // Listen for real-time updates
      _firestore
          .collection(_rumorsCollection)
          .orderBy('timestamp', descending: true)
          .limit(50) // Limit stream to recent data for performance
          .snapshots()
          .listen((snapshot) {
        final rumors = snapshot.docs
            .map((doc) => RumorModel.fromFirestore(doc))
            .toList();
        final processedRumors = _applyFeedAlgorithm(rumors);
        
        // Debounce updates to prevent excessive rebuilds
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          if (_lastData == null || !_listsEqual(_lastData!, processedRumors)) {
            _lastData = processedRumors;
            _streamController?.add(processedRumors);
            
            // Update cache with latest data
            _cacheService.cacheRumors(processedRumors.take(20).toList());
          }
        });
      });
    }
    
    return _streamController!.stream;
  }
  
  void _initializeStreamWithCache() async {
    try {
      final cached = await _cacheService.getCachedRumors(limit: 20);
      if (cached != null && cached.rumors.isNotEmpty) {
        _streamController?.add(cached.rumors);
        _lastData = cached.rumors;
      }
    } catch (e) {
      print('Error initializing stream with cache: $e');
    }
  }
  
  bool _listsEqual(List<RumorModel> a, List<RumorModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || 
          a[i].yesVotes != b[i].yesVotes || 
          a[i].noVotes != b[i].noVotes ||
          a[i].votedYesByUsers.length != b[i].votedYesByUsers.length ||
          a[i].votedNoByUsers.length != b[i].votedNoByUsers.length) {
        return false;
      }
    }
    return true;
  }
  
  void dispose() {
    _debounceTimer?.cancel();
    _streamController?.close();
    _streamController = null;
    _pendingRequests.clear();
  }
  
  // Performance monitoring
  Future<Map<String, dynamic>> getPerformanceStats() async {
    final cacheStats = await _cacheService.getCacheStats();
    return {
      'cache': cacheStats,
      'activeRequests': _activeRequests,
      'pendingRequests': _pendingRequests.length,
      'streamControllerActive': _streamController != null,
      'lastDataCount': _lastData?.length ?? 0,
    };
  }
  
  // Force refresh cache
  Future<void> refreshCache() async {
    await _cacheService.clearCache();
    _lastData = null;
  }

  // Create a new rumor
  Future<String> createRumor(String content) async {
    try {
      final docRef = await _firestore.collection(_rumorsCollection).add({
        'content': content,
        'timestamp': Timestamp.now(),
        'yesVotes': 0,
        'noVotes': 0,
        'commentCount': 0,
        'votedYesByUsers': [],
        'votedNoByUsers': [],
        'credibilityScore': 0.5,
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create rumor: $e');
    }
  }

  // Get all rumors once (optimized with cache)
  Future<List<RumorModel>> getRumorsOnce({int limit = 50}) async {
    try {
      // Try cache first
      final cached = await _cacheService.getCachedRumors(limit: limit);
      if (cached != null && cached.fromCache) {
        return cached.rumors;
      }
      
      final snapshot = await _firestore
          .collection(_rumorsCollection)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      final rumors = snapshot.docs
          .map((doc) => RumorModel.fromFirestore(doc))
          .toList();
      final processedRumors = _applyFeedAlgorithm(rumors);
      
      // Cache results
      await _cacheService.cacheRumors(processedRumors);
      
      return processedRumors;
    } catch (e) {
      throw Exception('Failed to fetch rumors: $e');
    }
  }

  // Get a single rumor
  Future<RumorModel?> getRumor(String rumorId) async {
    try {
      final doc = await _firestore
          .collection(_rumorsCollection)
          .doc(rumorId)
          .get();
      if (doc.exists) {
        return RumorModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get rumor: $e');
    }
  }

  // Vote on a rumor
  Future<void> voteOnRumor(
    String rumorId,
    String userId,
    bool isYesVote,
  ) async {
    try {
      final rumorRef = _firestore.collection(_rumorsCollection).doc(rumorId);
      final rumor = await getRumor(rumorId);

      if (rumor == null) throw Exception('Rumor not found');

      // Check if user already voted
      final hasVotedYes = rumor.votedYesByUsers.contains(userId);
      final hasVotedNo = rumor.votedNoByUsers.contains(userId);

      int newYesVotes = rumor.yesVotes;
      int newNoVotes = rumor.noVotes;
      List<String> newYesUsers = List.from(rumor.votedYesByUsers);
      List<String> newNoUsers = List.from(rumor.votedNoByUsers);

      // Handle vote changes
      if (isYesVote) {
        if (hasVotedYes) {
          // Remove yes vote
          newYesVotes--;
          newYesUsers.remove(userId);
        } else {
          // Add yes vote
          newYesVotes++;
          newYesUsers.add(userId);
          // Remove no vote if exists
          if (hasVotedNo) {
            newNoVotes--;
            newNoUsers.remove(userId);
          }
        }
      } else {
        if (hasVotedNo) {
          // Remove no vote
          newNoVotes--;
          newNoUsers.remove(userId);
        } else {
          // Add no vote
          newNoVotes++;
          newNoUsers.add(userId);
          // Remove yes vote if exists
          if (hasVotedYes) {
            newYesVotes--;
            newYesUsers.remove(userId);
          }
        }
      }

      final credibilityScore =
          RumorModel.calculateCredibilityScore(newYesVotes, newNoVotes);

      await rumorRef.update({
        'yesVotes': newYesVotes,
        'noVotes': newNoVotes,
        'votedYesByUsers': newYesUsers,
        'votedNoByUsers': newNoUsers,
        'credibilityScore': credibilityScore,
      });
    } catch (e) {
      throw Exception('Failed to vote on rumor: $e');
    }
  }

  // Add a comment to a rumor
  Future<String> addComment(
    String rumorId,
    String content, {
    String? parentCommentId,
  }) async {
    try {
      final rumorRef = _firestore.collection(_rumorsCollection).doc(rumorId);

      // Add comment
      final commentRef = await rumorRef
          .collection(_commentsCollection)
          .add({
        'rumorId': rumorId,
        'content': content,
        'timestamp': Timestamp.now(),
        'likes': 0,
        'likedByUsers': [],
        'parentCommentId': parentCommentId,
        'replyCount': 0,
      });

      // Update comment count
      if (parentCommentId == null) {
        // Only increment for top-level comments
        await rumorRef.update({
          'commentCount': FieldValue.increment(1),
        });
      } else {
        // Increment reply count on parent comment
        await rumorRef
            .collection(_commentsCollection)
            .doc(parentCommentId)
            .update({
          'replyCount': FieldValue.increment(1),
        });
      }

      return commentRef.id;
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  // Get comments for a rumor
  Stream<List<RumorCommentModel>> getCommentsStream(String rumorId) {
    return _firestore
        .collection(_rumorsCollection)
        .doc(rumorId)
        .collection(_commentsCollection)
        .where('parentCommentId', isNull: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RumorCommentModel.fromFirestore(doc))
            .toList());
  }

  // Get replies to a comment
  Stream<List<RumorCommentModel>> getRepliesStream(
    String rumorId,
    String parentCommentId,
  ) {
    return _firestore
        .collection(_rumorsCollection)
        .doc(rumorId)
        .collection(_commentsCollection)
        .where('parentCommentId', isEqualTo: parentCommentId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RumorCommentModel.fromFirestore(doc))
            .toList());
  }

  // Like a comment
  Future<void> likeComment(
    String rumorId,
    String commentId,
    String userId,
  ) async {
    try {
      final commentRef = _firestore
          .collection(_rumorsCollection)
          .doc(rumorId)
          .collection(_commentsCollection)
          .doc(commentId);

      final comment = await commentRef.get();
      if (!comment.exists) throw Exception('Comment not found');

      final data = comment.data() as Map<String, dynamic>;
      final likedByUsers = List<String>.from(data['likedByUsers'] ?? []);
      final likes = data['likes'] ?? 0;

      if (likedByUsers.contains(userId)) {
        likedByUsers.remove(userId);
        await commentRef.update({
          'likes': likes - 1,
          'likedByUsers': likedByUsers,
        });
      } else {
        likedByUsers.add(userId);
        await commentRef.update({
          'likes': likes + 1,
          'likedByUsers': likedByUsers,
        });
      }
    } catch (e) {
      throw Exception('Failed to like comment: $e');
    }
  }

  // Delete a comment
  Future<void> deleteComment(String rumorId, String commentId) async {
    try {
      final commentRef = _firestore
          .collection(_rumorsCollection)
          .doc(rumorId)
          .collection(_commentsCollection)
          .doc(commentId);

      final comment = await commentRef.get();
      if (!comment.exists) throw Exception('Comment not found');

      final data = comment.data() as Map<String, dynamic>;
      final parentCommentId = data['parentCommentId'];

      // Delete comment
      await commentRef.delete();

      // Update counts
      if (parentCommentId == null) {
        // Decrement comment count
        await _firestore
            .collection(_rumorsCollection)
            .doc(rumorId)
            .update({
          'commentCount': FieldValue.increment(-1),
        });
      } else {
        // Decrement reply count
        await _firestore
            .collection(_rumorsCollection)
            .doc(rumorId)
            .collection(_commentsCollection)
            .doc(parentCommentId)
            .update({
          'replyCount': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  // Apply feed algorithm to sort rumors
  List<RumorModel> _applyFeedAlgorithm(List<RumorModel> rumors) {
    final now = DateTime.now();

    // Calculate spicy score for each rumor
    final scoredRumors = rumors.map((rumor) {
      double score = 0;

      // 1. Engagement Score (votes + comments)
      final engagementScore = rumor.getEngagementScore();
      score += engagementScore * 0.4;

      // 2. Controversy Score (close to 50/50 split)
      if (rumor.isControversial()) {
        score += 50; // High boost for controversial rumors
      }

      // 3. Recency Score (newer rumors rank higher, fades after 24 hours)
      final ageInHours = now.difference(rumor.timestamp).inHours;
      if (ageInHours <= 24) {
        final recencyScore = (24 - ageInHours) / 24 * 100;
        score += recencyScore * 0.3;
      }

      // 4. Trending Boost (high engagement + recent)
      if (engagementScore > 10 && ageInHours <= 12) {
        score += 30;
      }

      // 5. Randomness (keep feed dynamic)
      // Add some randomness to prevent same rumors always being on top
      score += (DateTime.now().millisecond % 20).toDouble();

      return MapEntry(rumor, score);
    }).toList();

    // Sort by score descending
    scoredRumors.sort((a, b) => b.value.compareTo(a.value));

    // Apply diversity boost: max 3 consecutive rumors with high engagement
    final result = <RumorModel>[];
    int highEngagementCount = 0;

    for (final entry in scoredRumors) {
      if (entry.key.getEngagementScore() > 15) {
        if (highEngagementCount >= 3) {
          // Skip this high engagement rumor and add it later
          continue;
        }
        highEngagementCount++;
      } else {
        highEngagementCount = 0;
      }
      result.add(entry.key);
    }

    // Add skipped high engagement rumors at the end
    for (final entry in scoredRumors) {
      if (!result.contains(entry.key)) {
        result.add(entry.key);
      }
    }

    return result;
  }

  // Delete a rumor (admin only)
  Future<void> deleteRumor(String rumorId) async {
    try {
      await _firestore.collection(_rumorsCollection).doc(rumorId).delete();
    } catch (e) {
      throw Exception('Failed to delete rumor: $e');
    }
  }
}
