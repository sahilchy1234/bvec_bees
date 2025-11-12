import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String> participantImages;
  final String lastMessage;
  final String lastSenderId;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts;

  Conversation({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantImages,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastMessageTime,
    required this.unreadCounts,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'participantImages': participantImages,
      'lastMessage': lastMessage,
      'lastSenderId': lastSenderId,
      'lastMessageTime': lastMessageTime,
      'unreadCounts': unreadCounts,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map, String docId) {
    return Conversation(
      id: docId,
      participantIds: List<String>.from(map['participantIds'] ?? []),
      participantNames: Map<String, String>.from(map['participantNames'] ?? {}),
      participantImages: Map<String, String>.from(map['participantImages'] ?? {}),
      lastMessage: map['lastMessage'] ?? '',
      lastSenderId: map['lastSenderId'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCounts: Map<String, int>.from(map['unreadCounts'] ?? {}),
    );
  }

  String getOtherParticipantName(String currentUserId) {
    return participantNames.entries
        .firstWhere(
          (entry) => entry.key != currentUserId,
          orElse: () => const MapEntry('', 'Unknown'),
        )
        .value;
  }

  String getOtherParticipantImage(String currentUserId) {
    return participantImages.entries
        .firstWhere(
          (entry) => entry.key != currentUserId,
          orElse: () => const MapEntry('', ''),
        )
        .value;
  }

  String getOtherParticipantId(String currentUserId) {
    return participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }
}
