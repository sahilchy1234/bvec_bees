import 'package:cloud_firestore/cloud_firestore.dart';

class Match {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime matchedAt;
  final String? conversationId;
  final bool isActive; // false if one user unhots
  final DateTime? lastMessageAt; // for sorting matches

  Match({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.matchedAt,
    this.conversationId,
    this.isActive = true,
    this.lastMessageAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user1Id': user1Id,
      'user2Id': user2Id,
      'matchedAt': matchedAt,
      'conversationId': conversationId,
      'isActive': isActive,
      'lastMessageAt': lastMessageAt,
    };
  }

  factory Match.fromMap(Map<String, dynamic> map, String docId) {
    return Match(
      id: docId,
      user1Id: map['user1Id'] ?? '',
      user2Id: map['user2Id'] ?? '',
      matchedAt: (map['matchedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      conversationId: map['conversationId'],
      isActive: map['isActive'] ?? true,
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }
}

class Vote {
  final String id;
  final String voterId;
  final String targetId;
  final bool isHot;
  final DateTime timestamp;

  Vote({
    required this.id,
    required this.voterId,
    required this.targetId,
    required this.isHot,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'voterId': voterId,
      'targetId': targetId,
      'isHot': isHot,
      'timestamp': timestamp,
    };
  }

  factory Vote.fromMap(Map<String, dynamic> map, String docId) {
    return Vote(
      id: docId,
      voterId: map['voterId'] ?? '',
      targetId: map['targetId'] ?? '',
      isHot: map['isHot'] ?? false,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
