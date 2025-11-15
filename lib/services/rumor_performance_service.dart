import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'rumor_cache_service.dart';
import '../models/rumor_model.dart';

class RumorPerformanceService {
  static RumorPerformanceService? _instance;
  RumorPerformanceService._();
  
  static RumorPerformanceService get instance {
    _instance ??= RumorPerformanceService._();
    return _instance!;
  }

  // Connection pool for Firestore
  static const int _maxConcurrentOperations = 5;
  int _activeOperations = 0;
  final Queue<Completer<void>> _operationQueue = Queue();
  
  // Image cache management
  static const int _maxImageCacheSize = 100 * 1024 * 1024; // 100MB
  static const int _maxImageCacheObjects = 500;
  
  // Background update timer
  Timer? _backgroundUpdateTimer;
  static const Duration _backgroundUpdateInterval = Duration(minutes: 5);
  
  // Performance metrics
  final Map<String, DateTime> _lastAccessTimes = {};
  final Map<String, int> _accessCounts = {};
  
  void initialize() {
    _setupImageCache();
    _startBackgroundUpdates();
    _monitorConnectivity();
  }
  
  void dispose() {
    _backgroundUpdateTimer?.cancel();
    PaintingBinding.instance.imageCache.clear();
  }
  
  // Setup optimized image cache
  void _setupImageCache() {
    PaintingBinding.instance.imageCache.maximumSize = _maxImageCacheObjects;
    PaintingBinding.instance.imageCache.maximumSizeBytes = _maxImageCacheSize;
    
    // Configure CachedNetworkImage
    CachedNetworkImage.logLevel = CacheManagerLogLevel.none; // Reduce logs in production
  }
  
  // Connection pool management
  Future<T> executeWithConnectionPool<T>(
    Future<T> Function() operation,
  ) async {
    if (_activeOperations >= _maxConcurrentOperations) {
      final completer = Completer<T>();
      _operationQueue.add(completer);
      await completer.future;
    }
    
    _activeOperations++;
    try {
      return await operation();
    } finally {
      _activeOperations--;
      if (_operationQueue.isNotEmpty) {
        final next = _operationQueue.removeFirst();
        if (!next.isCompleted) {
          next.complete();
        }
      }
    }
  }
  
  // Background updates
  void _startBackgroundUpdates() {
    _backgroundUpdateTimer = Timer.periodic(
      _backgroundUpdateInterval,
      (_) => _performBackgroundUpdate(),
    );
  }
  
  Future<void> _performBackgroundUpdate() async {
    try {
      final hasInternet = await RumorCacheService.instance.hasInternetConnection();
      if (!hasInternet) return;
      
      // Check if cache needs refresh
      final shouldRefresh = await RumorCacheService.instance.shouldRefresh();
      if (shouldRefresh) {
        // Trigger background refresh
        unawaited(_refreshCacheInBackground());
      }
      
      // Clean up old cache entries
      await _cleanupOldCache();
    } catch (e) {
      print('Background update error: $e');
    }
  }
  
  Future<void> _refreshCacheInBackground() async {
    // This would be implemented to refresh cache without blocking UI
    // For now, it's a placeholder
  }
  
  Future<void> _cleanupOldCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    for (final key in keys) {
      if (key.startsWith('rumor_') && key.contains('_timestamp')) {
        final timestamp = prefs.getInt(key) ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        
        // Remove entries older than 1 hour
        if (age > Duration(hours: 1).inMilliseconds) {
          final baseKey = key.replaceAll('_timestamp', '');
          await prefs.remove(baseKey);
          await prefs.remove(key);
        }
      }
    }
  }
  
  // Connectivity monitoring
  void _monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        // We're back online, consider refreshing
        unawaited(_handleConnectivityRestored());
      }
    });
  }
  
  Future<void> _handleConnectivityRestored() async {
    try {
      final cacheStats = await RumorCacheService.instance.getCacheStats();
      if (cacheStats['isFresh'] != true) {
        // Cache is stale, refresh it
        await _refreshCacheInBackground();
      }
    } catch (e) {
      print('Error handling connectivity restored: $e');
    }
  }
  
  // Performance tracking
  void trackRumorAccess(String rumorId) {
    _lastAccessTimes[rumorId] = DateTime.now();
    _accessCounts[rumorId] = (_accessCounts[rumorId] ?? 0) + 1;
  }
  
  // Preload popular rumors
  Future<void> preloadPopularRumors() async {
    try {
      final hasInternet = await RumorCacheService.instance.hasInternetConnection();
      if (!hasInternet) return;
      
      // Get most accessed rumors
      final sortedRumors = _accessCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final topRumors = sortedRumors.take(10).map((e) => e.key).toList();
      
      // Preload images for these rumors
      for (final rumorId in topRumors) {
        unawaited(_preloadRumorImages(rumorId));
      }
    } catch (e) {
      print('Error preloading popular rumors: $e');
    }
  }
  
  Future<void> _preloadRumorImages(String rumorId) async {
    // This would preload images associated with a rumor
    // Implementation depends on how images are stored/linked
  }
  
  // Memory optimization
  void optimizeMemoryUsage() {
    // Clear image cache if it's getting too large
    final imageCache = PaintingBinding.instance.imageCache;
    if (imageCache.currentSizeBytes > (_maxImageCacheSize * 0.8)) {
      imageCache.clear();
    }
    
    // Clear old access records
    final now = DateTime.now();
    _lastAccessTimes.removeWhere((_, time) => 
      now.difference(time) > Duration(hours: 1));
    _accessCounts.removeWhere((_, count) => count < 2);
  }
  
  // Performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'activeOperations': _activeOperations,
      'queuedOperations': _operationQueue.length,
      'trackedRumors': _lastAccessTimes.length,
      'imageCacheSize': PaintingBinding.instance.imageCache.currentSize,
      'imageCacheBytes': PaintingBinding.instance.imageCache.currentSizeBytes,
      'mostAccessed': _accessCounts.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..take(5)
          .map((e) => {'id': e.key, 'count': e.value})
          .toList(),
    };
  }
  
  // Optimized scroll performance
  void optimizeScrollPerformance(ScrollController controller) {
    // Add scroll listener for performance optimization
    controller.addListener(() {
      // Preload content when scrolling
      if (controller.position.pixels > 
          controller.position.maxScrollExtent * 0.8) {
        unawaited(preloadPopularRumors());
      }
      
      // Optimize memory during fast scrolling
      if (controller.position.activity?.velocity != null &&
          controller.position.activity!.velocity.abs() > 1000) {
        optimizeMemoryUsage();
      }
    });
  }
  
  // Batch operations
  Future<void> executeBatchedOperations(
    List<Future<void> Function()> operations,
  ) async {
    const batchSize = 3;
    for (int i = 0; i < operations.length; i += batchSize) {
      final batch = operations.skip(i).take(batchSize).toList();
      await Future.wait(batch.map((op) => executeWithConnectionPool(op)));
      
      // Small delay between batches to prevent overwhelming
      if (i + batchSize < operations.length) {
        await Future.delayed(Duration(milliseconds: 100));
      }
    }
  }
}

// Helper for unawaited futures
void unawaited(Future<void> future) {
  // Intentionally not awaiting the future
}
