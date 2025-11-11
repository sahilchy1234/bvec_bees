import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../models/post_model.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const uuid = Uuid();
  static const List<String> supportedReactions = [
    'like',
    'love',
    'care',
    'haha',
    'wow',
    'sad',
    'angry',
  ];

  Map<String, int> _createDefaultReactionCounts() {
    return {for (final key in supportedReactions) key: 0};
  }

  // Upload image to Firebase Storage
  Future<String> uploadImage(File imageFile, String postId, int imageIndex) async {
    try {
      final fileName = 'posts/$postId/image_$imageIndex.jpg';
      final ref = _storage.ref().child(fileName);
      
      await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Create a new post
  Future<String> createPost({
    required String authorId,
    required String authorName,
    required String authorImage,
    required String content,
    List<File>? imageFiles,
    required List<String> hashtags,
    required List<String> mentions,
  }) async {
    try {
      final postId = uuid.v4();
      List<String> imageUrls = [];

      // Upload images if provided
      if (imageFiles != null && imageFiles.isNotEmpty) {
        for (int i = 0; i < imageFiles.length; i++) {
          final url = await uploadImage(imageFiles[i], postId, i);
          imageUrls.add(url);
        }
      }

      final post = Post(
        id: postId,
        authorId: authorId,
        authorName: authorName,
        authorImage: authorImage,
        content: content,
        imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
        hashtags: hashtags,
        mentions: mentions,
        timestamp: DateTime.now(),
        likes: 0,
        comments: 0,
        shares: 0,
        likedBy: [],
        reactionCounts: _createDefaultReactionCounts(),
        reactions: {},
      );

      await _firestore.collection('posts').doc(postId).set(post.toMap());
      return postId;
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  // Get feed with algorithm-based sorting
  Future<List<Post>> getFeed({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(limit * 2) // Fetch more to apply algorithm
          .get();

      List<Post> posts = snapshot.docs
          .map((doc) => Post.fromMap(doc.data(), doc.id))
          .toList();

      // Apply feed algorithm
      posts.sort((a, b) => b.calculateFeedScore().compareTo(a.calculateFeedScore()));

      // Diversity boost: reduce same author dominance
      posts = _applyDiversityBoost(posts);

      return posts.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to fetch feed: $e');
    }
  }

  // Apply diversity boost to prevent single author dominance
  List<Post> _applyDiversityBoost(List<Post> posts) {
    final result = <Post>[];
    final authorCounts = <String, int>{};

    for (final post in posts) {
      final count = authorCounts[post.authorId] ?? 0;
      if (count < 2) {
        result.add(post);
        authorCounts[post.authorId] = count + 1;
      }
    }

    return result;
  }

  // Like a post
  Future<void> likePost(String postId, String userId) async {
    await setReaction(postId, userId, 'like');
  }

  // Unlike a post
  Future<void> unlikePost(String postId, String userId) async {
    await removeReaction(postId, userId);
  }

  // Delete a post
  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  // Get user's posts
  Future<List<Post>> getUserPosts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Post.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user posts: $e');
    }
  }

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
        final reactionCountsDynamic = Map<String, dynamic>.from(data['reactionCounts'] ?? {});

        final Map<String, int> reactionCounts = {for (final key in supportedReactions) key: 0};
        reactionCountsDynamic.forEach((key, value) {
          if (reactionCounts.containsKey(key)) {
            if (value is int) {
              reactionCounts[key] = value;
            } else if (value is num) {
              reactionCounts[key] = value.toInt();
            } else if (value is String) {
              final parsed = int.tryParse(value);
              if (parsed != null) {
                reactionCounts[key] = parsed;
              }
            }
          }
        });

        final previousReaction = reactions[userId];
        if (previousReaction == reactionKey) {
          return;
        }

        if (previousReaction != null && reactionCounts.containsKey(previousReaction)) {
          reactionCounts[previousReaction] = (reactionCounts[previousReaction]! - 1).clamp(0, 1 << 20);
        }

        reactionCounts[reactionKey] = (reactionCounts[reactionKey] ?? 0) + 1;
        reactions[userId] = reactionKey;

        final likedBy = reactions.entries
            .where((entry) => entry.value == 'like')
            .map((entry) => entry.key)
            .toList();

        final totalReactions = reactionCounts.values.fold<int>(0, (sum, value) => sum + value);

        transaction.update(postRef, {
          'reactionCounts': reactionCounts,
          'reactions': reactions,
          'likes': totalReactions,
          'likedBy': likedBy,
        });
      });
    } catch (e) {
      throw Exception('Failed to set reaction: $e');
    }
  }

  Future<void> removeReaction(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);
        if (!snapshot.exists) {
          throw Exception('Post not found');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final reactions = Map<String, String>.from(data['reactions'] ?? {});
        final reactionCountsDynamic = Map<String, dynamic>.from(data['reactionCounts'] ?? {});

        final previousReaction = reactions[userId];
        if (previousReaction == null) {
          return;
        }

        final Map<String, int> reactionCounts = {for (final key in supportedReactions) key: 0};
        reactionCountsDynamic.forEach((key, value) {
          if (reactionCounts.containsKey(key)) {
            if (value is int) {
              reactionCounts[key] = value;
            } else if (value is num) {
              reactionCounts[key] = value.toInt();
            } else if (value is String) {
              final parsed = int.tryParse(value);
              if (parsed != null) {
                reactionCounts[key] = parsed;
              }
            }
          }
        });

        reactionCounts[previousReaction] = (reactionCounts[previousReaction] ?? 0) - 1;
        if (reactionCounts[previousReaction]! < 0) {
          reactionCounts[previousReaction] = 0;
        }

        reactions.remove(userId);

        final likedBy = reactions.entries
            .where((entry) => entry.value == 'like')
            .map((entry) => entry.key)
            .toList();

        final totalReactions = reactionCounts.values.fold<int>(0, (sum, value) => sum + value);

        transaction.update(postRef, {
          'reactionCounts': reactionCounts,
          'reactions': reactions,
          'likes': totalReactions,
          'likedBy': likedBy,
        });
      });
    } catch (e) {
      throw Exception('Failed to remove reaction: $e');
    }
  }

  // Share a post
  Future<void> sharePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'shares': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to share post: $e');
    }
  }

  // Stream of posts for real-time updates
  Stream<List<Post>> getFeedStream({int limit = 20}) {
    try {
      return _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(limit * 2)
          .snapshots()
          .map((snapshot) {
            List<Post> posts = snapshot.docs
                .map((doc) => Post.fromMap(doc.data(), doc.id))
                .toList();

            // Apply feed algorithm
            posts.sort((a, b) =>
                b.calculateFeedScore().compareTo(a.calculateFeedScore()));

            // Apply diversity boost
            posts = _applyDiversityBoost(posts);

            return posts.take(limit).toList();
          });
    } catch (e) {
      throw Exception('Failed to get feed stream: $e');
    }
  }

  // Search posts by hashtag
  Future<List<Post>> searchByHashtag(String hashtag) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('hashtags', arrayContains: hashtag)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Post.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to search posts: $e');
    }
  }

  // Search posts by mention
  Future<List<Post>> searchByMention(String mention) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('mentions', arrayContains: mention)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Post.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to search posts: $e');
    }
  }
}
