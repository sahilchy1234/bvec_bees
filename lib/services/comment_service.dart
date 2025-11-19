import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/comment_model.dart';
import 'notification_service.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const uuid = Uuid();

  // Add a comment to a post
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

      // Increment comment count on post
      await _firestore.collection('posts').doc(postId).update({
        'comments': FieldValue.increment(1),
      });

      // Get post owner to send notification
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

  // Get comments for a post
  Future<List<Comment>> getComments(String postId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Comment.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch comments: $e');
    }
  }

  Stream<List<Comment>> streamComments(String postId) {
    try {
      return _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Comment.fromMap(doc.data(), doc.id))
              .toList());
    } catch (e) {
      throw Exception('Failed to listen for comments: $e');
    }
  }

  // Delete a comment
  Future<void> deleteComment(String postId, String commentId) async {
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // Decrement comment count on post
      await _firestore.collection('posts').doc(postId).update({
        'comments': FieldValue.increment(-1),
      });
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  // Like a comment
  Future<void> likeComment(String postId, String commentId, String userId) async {
    try {
      final commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      final comment = await commentRef.get();
      final likedBy = List<String>.from(comment['likedBy'] ?? []);

      if (!likedBy.contains(userId)) {
        likedBy.add(userId);
        await commentRef.update({
          'likedBy': likedBy,
          'likes': FieldValue.increment(1),
        });
      }
    } catch (e) {
      throw Exception('Failed to like comment: $e');
    }
  }

  // Unlike a comment
  Future<void> unlikeComment(String postId, String commentId, String userId) async {
    try {
      final commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      final comment = await commentRef.get();
      final likedBy = List<String>.from(comment['likedBy'] ?? []);

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
        await commentRef.update({
          'likedBy': likedBy,
          'likes': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      throw Exception('Failed to unlike comment: $e');
    }
  }
}
