import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/post_model.dart';

class FeedCacheService {
  static const String _feedCacheKey = 'cached_feed_posts';
  static const String _userCachePrefix = 'cached_user_';
  static const String _lastFetchKey = 'last_feed_fetch';
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const int _maxCachedPosts = 50;

  static FeedCacheService? _instance;
  FeedCacheService._();
  
  static FeedCacheService get instance {
    _instance ??= FeedCacheService._();
    return _instance!;
  }

  // Cache posts
  Future<void> cachePosts(List<Post> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      dynamic _convertDateTimes(dynamic value) {
        if (value is DateTime) {
          return value.toIso8601String();
        } else if (value is Map) {
          return value.map((k, v) => MapEntry(k, _convertDateTimes(v)));
        } else if (value is List) {
          return value.map(_convertDateTimes).toList();
        }
        return value;
      }
      final postsJson = posts.take(_maxCachedPosts).map((post) {
        final map = post.toMap();
        return _convertDateTimes(map);
      }).toList();
      await prefs.setString(_feedCacheKey, jsonEncode(postsJson));
      await prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error caching posts: $e');
    }
  }

  // Get cached posts
  Future<List<Post>?> getCachedPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_feedCacheKey);
      final lastFetch = prefs.getInt(_lastFetchKey) ?? 0;
      
      if (cachedJson == null) return null;
      
      // Check if cache has expired
      final cacheAge = DateTime.now().millisecondsSinceEpoch - lastFetch;
      if (cacheAge > _cacheExpiry.inMilliseconds) {
        return null;
      }
      
      final List<dynamic> postsData = jsonDecode(cachedJson);
      return postsData.map((data) {
        if (data['timestamp'] is String) {
          data['timestamp'] = DateTime.parse(data['timestamp']);
        }
        return Post.fromMap(data, data['id']);
      }).toList();
    } catch (e) {
      print('Error getting cached posts: $e');
      return null;
    }
  }

  // Cache user data
  Future<void> cacheUser(String userId, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userData['cached_at'] = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString('$_userCachePrefix$userId', jsonEncode(userData));
    } catch (e) {
      print('Error caching user: $e');
    }
  }

  // Get cached user data
  Future<Map<String, dynamic>?> getCachedUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('$_userCachePrefix$userId');
      
      if (cachedJson == null) return null;
      
      final userData = jsonDecode(cachedJson) as Map<String, dynamic>;
      final cachedAt = userData['cached_at'] as int? ?? 0;
      
      // Check if cache has expired (user data expires after 30 minutes)
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (cacheAge > const Duration(minutes: 30).inMilliseconds) {
        return null;
      }
      
      userData.remove('cached_at');
      return userData;
    } catch (e) {
      print('Error getting cached user: $e');
      return null;
    }
  }

  // Check network connectivity
  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  // Clear all cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => 
        key.startsWith(_userCachePrefix) || 
        key == _feedCacheKey || 
        key == _lastFetchKey
      ).toList();
      
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Cache image metadata for faster loading
  Future<void> cacheImageMetadata(String imageUrl, Map<String, dynamic> metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'image_meta_${imageUrl.hashCode}';
      metadata['cached_at'] = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(cacheKey, jsonEncode(metadata));
    } catch (e) {
      print('Error caching image metadata: $e');
    }
  }

  // Get cached image metadata
  Future<Map<String, dynamic>?> getCachedImageMetadata(String imageUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'image_meta_${imageUrl.hashCode}';
      final cachedJson = prefs.getString(cacheKey);
      
      if (cachedJson == null) return null;
      
      final metadata = jsonDecode(cachedJson) as Map<String, dynamic>;
      final cachedAt = metadata['cached_at'] as int? ?? 0;
      
      // Image metadata expires after 1 hour
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (cacheAge > const Duration(hours: 1).inMilliseconds) {
        return null;
      }
      
      metadata.remove('cached_at');
      return metadata;
    } catch (e) {
      print('Error getting cached image metadata: $e');
      return null;
    }
  }

  // Preload strategy - cache next batch of posts
  Future<void> preloadNextBatch(String lastPostId, Future<List<Post>> Function() fetchFunction) async {
    try {
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) return;
      
      // Fetch in background
      final posts = await fetchFunction();
      if (posts.isNotEmpty) {
        await cachePosts(posts);
      }
    } catch (e) {
      print('Error preloading posts: $e');
    }
  }
}
