import 'package:cloud_firestore/cloud_firestore.dart';

class RumorCommentModel {
  final String id;
  final String rumorId;
  final String authorId;
  final String authorName;
  final String authorImage;
  final String content;
  final DateTime timestamp;
  final int likes;
  final List<String> likedByUsers;
  final String? parentCommentId; // For threaded replies
  final int replyCount;

  RumorCommentModel({
    required this.id,
    required this.rumorId,
    required this.authorId,
    required this.authorName,
    required this.authorImage,
    required this.content,
    required this.timestamp,
    required this.likes,
    required this.likedByUsers,
    this.parentCommentId,
    required this.replyCount,
  });

  factory RumorCommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RumorCommentModel(
      id: doc.id,
      rumorId: data['rumorId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorImage: data['authorImage'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      likedByUsers: List<String>.from(data['likedByUsers'] ?? []),
      parentCommentId: data['parentCommentId'],
      replyCount: data['replyCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'rumorId': rumorId,
      'authorId': authorId,
      'authorName': authorName,
      'authorImage': authorImage,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'likedByUsers': likedByUsers,
      'parentCommentId': parentCommentId,
      'replyCount': replyCount,
    };
  }

  RumorCommentModel copyWith({
    String? id,
    String? rumorId,
    String? authorId,
    String? authorName,
    String? authorImage,
    String? content,
    DateTime? timestamp,
    int? likes,
    List<String>? likedByUsers,
    String? parentCommentId,
    int? replyCount,
  }) {
    return RumorCommentModel(
      id: id ?? this.id,
      rumorId: rumorId ?? this.rumorId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorImage: authorImage ?? this.authorImage,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      likes: likes ?? this.likes,
      likedByUsers: likedByUsers ?? this.likedByUsers,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replyCount: replyCount ?? this.replyCount,
    );
  }
}
