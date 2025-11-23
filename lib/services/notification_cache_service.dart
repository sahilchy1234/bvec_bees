import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NotificationCacheService {
  static NotificationCacheService? _instance;
  static const Duration _cacheExpiry = Duration(minutes: 10);

  NotificationCacheService._();

  static NotificationCacheService get instance {
    _instance ??= NotificationCacheService._();
    return _instance!;
  }

  String _dataKey(String userId) => 'cached_notifications_$userId';
  String _timeKey(String userId) => 'cached_notifications_last_fetch_$userId';

  Future<void> cacheNotifications(
    String userId,
    List<Map<String, dynamic>> notifications,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dataKey(userId), jsonEncode(notifications));
      await prefs.setInt(
        _timeKey(userId),
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Best-effort cache; ignore failures
    }
  }

  Future<List<Map<String, dynamic>>?> getCachedNotifications(
    String userId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_dataKey(userId));
      final last = prefs.getInt(_timeKey(userId)) ?? 0;
      if (json == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - last;
      if (age > _cacheExpiry.inMilliseconds) {
        return null;
      }

      final List<dynamic> raw = jsonDecode(json);
      return raw
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return null;
    }
  }
}
