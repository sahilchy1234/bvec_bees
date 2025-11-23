import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorImage;
  final String content;
  final List<String>? imageUrls;
  final double imageAlignmentY;
  final List<String> hashtags;
  final List<String> mentions;
  final DateTime timestamp;
  final int likes;
  final int comments;
  final int shares;
  final List<String> likedBy;
  final Map<String, int> reactionCounts;
  final Map<String, String> reactions; // userId -> reaction type
  final bool isEdited;
  final DateTime? editedAt;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorImage,
    required this.content,
    this.imageUrls,
    this.imageAlignmentY = 0.0,
    required this.hashtags,
    required this.mentions,
    required this.timestamp,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.likedBy,
    required this.reactionCounts,
    required this.reactions,
    this.isEdited = false,
    this.editedAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorImage': authorImage,
      'content': content,
      'imageUrls': imageUrls ?? [],
      'imageAlignmentY': imageAlignmentY,
      'hashtags': hashtags,
      'mentions': mentions,
      'timestamp': timestamp,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'likedBy': likedBy,
      'reactionCounts': reactionCounts,
      'reactions': reactions,
      'isEdited': isEdited,
      'editedAt': editedAt,
    };
  }

  // Create from Firestore document
  factory Post.fromMap(Map<String, dynamic> map, String docId) {
    return Post(
      id: docId,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorImage: map['authorImage'] ?? '',
      content: map['content'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      imageAlignmentY: (map['imageAlignmentY'] as num?)?.toDouble() ?? 0.0,
      hashtags: List<String>.from(map['hashtags'] ?? []),
      mentions: List<String>.from(map['mentions'] ?? []),
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : map['timestamp'] is String
              ? DateTime.parse(map['timestamp'])
              : map['timestamp'] is DateTime
                  ? map['timestamp'] as DateTime
                  : DateTime.now(),
      likes: map['likes'] ?? 0,
      comments: map['comments'] ?? 0,
      shares: map['shares'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      reactionCounts: _parseReactionCounts(map['reactionCounts']),
      reactions: Map<String, String>.from(map['reactions'] ?? {}),
      isEdited: map['isEdited'] ?? false,
      editedAt: _parseEditedAt(map['editedAt']),
    );
  }

  // Calculate feed score based on algorithm
  double calculateFeedScore() {
    const maxLikes = 50.0;
    const maxComments = 20.0;
    const maxShares = 10.0;
    const maxHours = 24.0;

    // Recency score
    final hoursSincePosted = DateTime.now().difference(timestamp).inHours;
    final recencyScore = (1 - (hoursSincePosted / maxHours)).clamp(0.0, 1.0);

    // Engagement score
    final engagementScore = (likes / maxLikes) * 0.6 +
        (comments / maxComments) * 0.3 +
        (shares / maxShares) * 0.1;

    // Trending boost
    final trendingBoost = engagementScore * recencyScore;

    // Final feed score
    final feedScore =
        (recencyScore * 0.5) + (engagementScore * 0.3) + (trendingBoost * 0.2);

    return feedScore.clamp(0.0, 1.0);
  }

  Post copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorImage,
    String? content,
    List<String>? imageUrls,
    double? imageAlignmentY,
    List<String>? hashtags,
    List<String>? mentions,
    DateTime? timestamp,
    int? likes,
    int? comments,
    int? shares,
    List<String>? likedBy,
    bool? isEdited,
    DateTime? editedAt,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorImage: authorImage ?? this.authorImage,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      imageAlignmentY: imageAlignmentY ?? this.imageAlignmentY,
      hashtags: hashtags ?? this.hashtags,
      mentions: mentions ?? this.mentions,
      timestamp: timestamp ?? this.timestamp,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      likedBy: likedBy ?? this.likedBy,
      reactionCounts: reactionCounts,
      reactions: reactions,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  static Map<String, int> _parseReactionCounts(dynamic raw) {
    if (raw == null) {
      return <String, int>{};
    }

    final result = <String, int>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (key is String) {
          if (value is int) {
            result[key] = value;
          } else if (value is num) {
            result[key] = value.toInt();
          } else if (value is String) {
            final parsed = int.tryParse(value);
            if (parsed != null) {
              result[key] = parsed;
            }
          }
        }
      });
    }

    return result;
  }

  static DateTime? _parseEditedAt(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
