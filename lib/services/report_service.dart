import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'reports';

  Future<void> reportContent({
    required String reporterId,
    required String targetId,
    required String targetType, // 'post', 'rumor', 'user'
    String? targetOwnerId,
    String? reason,
    String? details,
  }) async {
    try {
      await _firestore.collection(_collection).add({
        'reporterId': reporterId,
        'targetId': targetId,
        'targetType': targetType,
        'targetOwnerId': targetOwnerId,
        'reason': reason ?? 'Other',
        'details': details?.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'open',
      });
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }
}
