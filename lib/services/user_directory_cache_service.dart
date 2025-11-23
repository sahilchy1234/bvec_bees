import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

class UserDirectoryCacheService {
  static const String _usersKey = 'cached_verified_users';
  static const String _lastFetchKey = 'cached_verified_users_last_fetch';
  static const Duration _cacheExpiry = Duration(minutes: 30);

  static UserDirectoryCacheService? _instance;

  UserDirectoryCacheService._();

  static UserDirectoryCacheService get instance {
    _instance ??= UserDirectoryCacheService._();
    return _instance!;
  }

  Future<void> cacheUsers(List<UserModel> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = users
          .map((u) => u.toMap())
          .toList();
      await prefs.setString(_usersKey, jsonEncode(data));
      await prefs.setInt(
        _lastFetchKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  Future<List<UserModel>?> getCachedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_usersKey);
      final lastFetch = prefs.getInt(_lastFetchKey) ?? 0;
      if (json == null) {
        return null;
      }

      final age = DateTime.now().millisecondsSinceEpoch - lastFetch;
      if (age > _cacheExpiry.inMilliseconds) {
        return null;
      }

      final List<dynamic> data = jsonDecode(json);
      return data
          .whereType<Map<String, dynamic>>()
          .map((m) => UserModel.fromMap(m))
          .toList();
    } catch (_) {
      return null;
    }
  }
}
