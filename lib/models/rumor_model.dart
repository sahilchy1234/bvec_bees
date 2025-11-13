import 'package:cloud_firestore/cloud_firestore.dart';

class RumorModel {
  final String id;
  final String content;
  final DateTime timestamp;
  final int yesVotes;
  final int noVotes;
  final int commentCount;
  final List<String> votedYesByUsers; // Track who voted yes
  final List<String> votedNoByUsers;  // Track who voted no
  final double credibilityScore; // Calculated from votes

  RumorModel({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.yesVotes,
    required this.noVotes,
    required this.commentCount,
    required this.votedYesByUsers,
    required this.votedNoByUsers,
    required this.credibilityScore,
  });

  // Calculate credibility score based on votes
  static double calculateCredibilityScore(int yesVotes, int noVotes) {
    final total = yesVotes + noVotes;
    if (total == 0) return 0.5; // Neutral if no votes
    return yesVotes / total;
  }

  // Get credibility label
  String getCredibilityLabel() {
    if (credibilityScore >= 0.75) return 'Likely True';
    if (credibilityScore >= 0.65) return 'Probably True';
    if (credibilityScore >= 0.55) return 'Slightly True';
    if (credibilityScore >= 0.45) return 'Neutral';
    if (credibilityScore >= 0.35) return 'Slightly False';
    if (credibilityScore >= 0.25) return 'Probably False';
    return 'Likely False';
  }

  // Check if rumor is controversial (close to 50/50 split)
  bool isControversial() {
    final total = yesVotes + noVotes;
    if (total < 2) return false;
    final ratio = (yesVotes / total - 0.5).abs();
    return ratio < 0.15; // Within 15% of 50/50
  }

  // Get engagement score for feed algorithm
  double getEngagementScore() {
    final voteEngagement = (yesVotes + noVotes) * 0.6;
    final commentEngagement = commentCount * 0.4;
    return voteEngagement + commentEngagement;
  }

  factory RumorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RumorModel(
      id: doc.id,
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      yesVotes: data['yesVotes'] ?? 0,
      noVotes: data['noVotes'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      votedYesByUsers: List<String>.from(data['votedYesByUsers'] ?? []),
      votedNoByUsers: List<String>.from(data['votedNoByUsers'] ?? []),
      credibilityScore: (data['credibilityScore'] as num?)?.toDouble() ?? 0.5,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'yesVotes': yesVotes,
      'noVotes': noVotes,
      'commentCount': commentCount,
      'votedYesByUsers': votedYesByUsers,
      'votedNoByUsers': votedNoByUsers,
      'credibilityScore': credibilityScore,
    };
  }

  // Create a copy with updated values
  RumorModel copyWith({
    String? id,
    String? content,
    DateTime? timestamp,
    int? yesVotes,
    int? noVotes,
    int? commentCount,
    List<String>? votedYesByUsers,
    List<String>? votedNoByUsers,
    double? credibilityScore,
  }) {
    return RumorModel(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      yesVotes: yesVotes ?? this.yesVotes,
      noVotes: noVotes ?? this.noVotes,
      commentCount: commentCount ?? this.commentCount,
      votedYesByUsers: votedYesByUsers ?? this.votedYesByUsers,
      votedNoByUsers: votedNoByUsers ?? this.votedNoByUsers,
      credibilityScore: credibilityScore ?? this.credibilityScore,
    );
  }
}
