import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheService {
  ImageCacheService._();

  static final ImageCacheService instance = ImageCacheService._();

  // Cache manager for network images with a 3-day stale period
  final BaseCacheManager imageCacheManager = CacheManager(
    Config(
      'beezyImageCache',
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 500,
    ),
  );
}
