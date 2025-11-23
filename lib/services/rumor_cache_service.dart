import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/rumor_model.dart';

class RumorCacheResult {
  final List<RumorModel> rumors;
  final bool hasMore;
  final String? lastRumorId;
  final bool fromCache;

  RumorCacheResult({
    required this.rumors,
    required this.hasMore,
    this.lastRumorId,
    this.fromCache = false,
  });
}

class RumorCacheService {
  static const String _rumorsCacheKey = 'cached_rumors';
  static const String _paginationCacheKey = 'rumor_pagination_meta';
  static const String _lastFetchKey = 'last_rumor_fetch';
  // OPTIMIZATION: Increased from 10 minutes to 20 minutes to reduce reads
  static const Duration _cacheExpiry = Duration(minutes: 20);
  // OPTIMIZATION: Increased from 2 minutes to 5 minutes for short cache
  static const Duration _shortCacheExpiry = Duration(minutes: 5);
  static const int _maxCachedRumors = 100;
  static const int _pageSize = 20;

  static RumorCacheService? _instance;
  RumorCacheService._();
  
  static RumorCacheService get instance {
    _instance ??= RumorCacheService._();
    return _instance!;
  }

  // Cache rumors with pagination metadata
  Future<void> cacheRumors(List<RumorModel> rumors, {
    bool isAppend = false,
    String? lastRumorId,
    bool hasMore = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      List<RumorModel> existingRumors = [];
      if (isAppend) {
        final cachedResult = await getCachedRumors();
        existingRumors = cachedResult?.rumors ?? [];
      }
      
      // Remove duplicates and merge
      final Map<String, RumorModel> rumorMap = {
        for (var rumor in existingRumors) rumor.id: rumor,
        for (var rumor in rumors) rumor.id: rumor,
      };
      
      final mergedRumors = rumorMap.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Limit cache size
      final limitedRumors = mergedRumors.take(_maxCachedRumors).toList();
      
      // Convert to cache format
      final rumorsJson = limitedRumors.map((rumor) => rumor.toCacheMap()).toList();
      
      await Future.wait([
        prefs.setString(_rumorsCacheKey, jsonEncode(rumorsJson)),
        prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch),
        if (lastRumorId != null)
          prefs.setString('${_paginationCacheKey}_last', lastRumorId),
        prefs.setBool('${_paginationCacheKey}_has_more', hasMore),
      ]);
    } catch (e) {
      print('Error caching rumors: $e');
    }
  }

  // Get cached rumors with pagination info
  Future<RumorCacheResult?> getCachedRumors({
    int limit = _pageSize,
    String? startAfterId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_rumorsCacheKey);
      final lastFetch = prefs.getInt(_lastFetchKey) ?? 0;
      
      if (cachedJson == null) return null;
      
      // Check cache expiry
      final cacheAge = DateTime.now().millisecondsSinceEpoch - lastFetch;
      final isExpired = cacheAge > _cacheExpiry.inMilliseconds;
      
      if (isExpired) return null;
      
      final List<dynamic> rumorsData = jsonDecode(cachedJson);
      final allRumors = rumorsData
          .map((data) => RumorModel.fromCacheMap(data))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Apply pagination
      List<RumorModel> paginatedRumors;
      String? newLastId;
      bool hasMore = false;
      
      if (startAfterId != null) {
        final startIndex = allRumors.indexWhere((r) => r.id == startAfterId);
        if (startIndex == -1) return null;
        
        paginatedRumors = allRumors.skip(startIndex + 1).take(limit).toList();
        newLastId = paginatedRumors.isNotEmpty ? paginatedRumors.last.id : null;
        hasMore = startIndex + 1 + limit < allRumors.length;
      } else {
        paginatedRumors = allRumors.take(limit).toList();
        newLastId = paginatedRumors.isNotEmpty ? paginatedRumors.last.id : null;
        hasMore = allRumors.length > limit;
      }
      
      return RumorCacheResult(
        rumors: paginatedRumors,
        hasMore: hasMore,
        lastRumorId: newLastId,
        fromCache: true,
      );
    } catch (e) {
      print('Error getting cached rumors: $e');
      return null;
    }
  }

  // Get pagination metadata
  Future<Map<String, dynamic>?> getPaginationMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'lastRumorId': prefs.getString('${_paginationCacheKey}_last'),
        'hasMore': prefs.getBool('${_paginationCacheKey}_has_more') ?? true,
        'lastFetch': prefs.getInt(_lastFetchKey) ?? 0,
      };
    } catch (e) {
      print('Error getting pagination metadata: $e');
      return null;
    }
  }

  // Check if cache is fresh
  Future<bool> isCacheFresh({Duration maxAge = _shortCacheExpiry}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetch = prefs.getInt(_lastFetchKey) ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - lastFetch;
      return cacheAge < maxAge.inMilliseconds && prefs.containsKey(_rumorsCacheKey);
    } catch (e) {
      return false;
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
        key.startsWith('rumor_') || 
        key == _rumorsCacheKey || 
        key == _lastFetchKey
      ).toList();
      
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Preload next batch in background
  Future<void> preloadNextBatch(String lastRumorId, Future<List<RumorModel>> Function() fetchFunction) async {
    try {
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) return;
      
      // Fetch in background without blocking UI
      unawaited(fetchFunction().then((rumors) async {
        if (rumors.isNotEmpty) {
          await cacheRumors(rumors, isAppend: true, lastRumorId: rumors.last.id);
        }
      }));
    } catch (e) {
      print('Error preloading rumors: $e');
    }
  }

  // Cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_rumorsCacheKey);
      final lastFetch = prefs.getInt(_lastFetchKey) ?? 0;
      
      int rumorCount = 0;
      if (cachedJson != null) {
        final List<dynamic> rumorsData = jsonDecode(cachedJson);
        rumorCount = rumorsData.length;
      }
      
      return {
        'rumorCount': rumorCount,
        'lastFetch': DateTime.fromMillisecondsSinceEpoch(lastFetch),
        'cacheAge': DateTime.now().millisecondsSinceEpoch - lastFetch,
        'isFresh': await isCacheFresh(),
        'hasInternet': await hasInternetConnection(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Smart cache refresh - only refresh if needed
  Future<bool> shouldRefresh() async {
    try {
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) return false;
      
      final isFresh = await isCacheFresh();
      return !isFresh;
    } catch (e) {
      return true; // Err on the side of refreshing
    }
  }
}

// Helper for unawaited futures
void unawaited(Future<void> future) {
  // Intentionally not awaiting the future
}
