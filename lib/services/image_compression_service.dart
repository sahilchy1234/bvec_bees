import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum CompressionType {
  avatar,    // Max 30KB
  idCard,    // Max 30KB
  post,      // Max 200KB
}

class ImageCompressionService {
  // Maximum file sizes in bytes
  static const int _avatarMaxSize = 30 * 1024; // 30KB
  static const int _idCardMaxSize = 30 * 1024; // 30KB
  static const int _postMaxSize = 200 * 1024;   // 200KB
  
  // Quality levels for different compression passes
  static const List<int> _qualityLevels = [85, 75, 60, 50, 40, 30, 20, 15, 10];
  
  /// Compress image based on the compression type
  static Future<File> compressImage(File imageFile, CompressionType type) async {
    try {
      if (!imageFile.existsSync()) {
        throw Exception('Image file does not exist');
      }

      final bytes = await imageFile.readAsBytes();
      final originalSize = bytes.length;
      
      debugPrint('Original image size: ${(originalSize / 1024).toStringAsFixed(2)} KB');
      
      // Decode the image
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Could not decode image');
      }

      final targetSize = _getMaxSize(type);
      final targetDimensions = _getTargetDimensions(type, image.width, image.height);
      
      debugPrint('Target size: ${(targetSize / 1024).toStringAsFixed(2)} KB');
      debugPrint('Target dimensions: ${targetDimensions.width} x ${targetDimensions.height}');

      // If original is already smaller than target, resize to standard dimensions but keep quality high
      if (originalSize <= targetSize) {
        final resized = img.copyResize(
          image,
          width: targetDimensions.width,
          height: targetDimensions.height,
          interpolation: img.Interpolation.linear,
        );
        
        final compressed = img.encodeJpg(resized, quality: 85);
        
        if (compressed.length <= targetSize) {
          return _createTempFile(imageFile, compressed);
        }
      }

      // Compress with progressive quality reduction
      final compressedBytes = await _compressToTargetSize(
        image,
        targetDimensions,
        targetSize,
      );

      return _createTempFile(imageFile, compressedBytes);
    } catch (e) {
      debugPrint('Error compressing image: $e');
      rethrow;
    }
  }

  /// Get maximum file size based on compression type
  static int _getMaxSize(CompressionType type) {
    switch (type) {
      case CompressionType.avatar:
        return _avatarMaxSize;
      case CompressionType.idCard:
        return _idCardMaxSize;
      case CompressionType.post:
        return _postMaxSize;
    }
  }

  /// Get target dimensions based on compression type and original dimensions
  static ImageDimensions _getTargetDimensions(CompressionType type, int originalWidth, int originalHeight) {
    int maxWidth, maxHeight;
    
    switch (type) {
      case CompressionType.avatar:
        maxWidth = 300;
        maxHeight = 300;
        break;
      case CompressionType.idCard:
        maxWidth = 400;
        maxHeight = 600;
        break;
      case CompressionType.post:
        maxWidth = 1080;
        maxHeight = 1920;
        break;
    }

    // Maintain aspect ratio
    final aspectRatio = originalWidth / originalHeight;
    
    int targetWidth, targetHeight;
    
    if (originalWidth > originalHeight) {
      // Landscape
      targetWidth = maxWidth;
      targetHeight = (maxWidth / aspectRatio).round();
      if (targetHeight > maxHeight) {
        targetHeight = maxHeight;
        targetWidth = (maxHeight * aspectRatio).round();
      }
    } else {
      // Portrait or square
      targetHeight = maxHeight;
      targetWidth = (maxHeight * aspectRatio).round();
      if (targetWidth > maxWidth) {
        targetWidth = maxWidth;
        targetHeight = (maxWidth / aspectRatio).round();
      }
    }

    return ImageDimensions(targetWidth, targetHeight);
  }

  /// Compress image to target size using progressive quality reduction
  static Future<Uint8List> _compressToTargetSize(
    img.Image image,
    ImageDimensions dimensions,
    int targetSize,
  ) async {
    // Start with resizing
    final resized = img.copyResize(
      image,
      width: dimensions.width,
      height: dimensions.height,
      interpolation: img.Interpolation.linear,
    );

    Uint8List? compressedBytes;
    
    // Try different quality levels
    for (final quality in _qualityLevels) {
      compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      
      debugPrint('Quality $quality: ${(compressedBytes.length / 1024).toStringAsFixed(2)} KB');
      
      if (compressedBytes.length <= targetSize) {
        break;
      }
    }

    // If still too large, try reducing dimensions further
    if (compressedBytes == null || compressedBytes.length > targetSize) {
      final reductionFactor = 0.8;
      final newWidth = (dimensions.width * reductionFactor).round();
      final newHeight = (dimensions.height * reductionFactor).round();
      
      debugPrint('Reducing dimensions to: $newWidth x $newHeight');
      
      final furtherResized = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // Try compression again with reduced dimensions
      for (final quality in _qualityLevels) {
        compressedBytes = Uint8List.fromList(img.encodeJpg(furtherResized, quality: quality));
        
        debugPrint('Reduced size - Quality $quality: ${(compressedBytes.length / 1024).toStringAsFixed(2)} KB');
        
        if (compressedBytes.length <= targetSize) {
          break;
        }
      }
    }

    // If still too large, use the lowest quality available
    if (compressedBytes == null || compressedBytes.length > targetSize) {
      debugPrint('Warning: Could not compress to target size. Using lowest quality.');
      compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: _qualityLevels.last));
    }

    debugPrint('Final compressed size: ${(compressedBytes.length / 1024).toStringAsFixed(2)} KB');
    
    return compressedBytes;
  }

  /// Create temporary file with compressed bytes
  static Future<File> _createTempFile(File originalFile, Uint8List compressedBytes) async {
    final tempPath = '${originalFile.path}_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final compressedFile = File(tempPath);
    await compressedFile.writeAsBytes(compressedBytes);
    return compressedFile;
  }

  /// Check if image needs compression
  static Future<bool> needsCompression(File imageFile, CompressionType type) async {
    if (!imageFile.existsSync()) {
      return false;
    }
    
    final bytes = await imageFile.readAsBytes();
    final maxSize = _getMaxSize(type);
    
    return bytes.length > maxSize;
  }

  /// Get image dimensions without fully loading the image
  static Future<ImageDimensions?> getImageDimensions(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image != null) {
        return ImageDimensions(image.width, image.height);
      }
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
    }
    
    return null;
  }

  /// Clean up temporary compressed files
  static Future<void> cleanupTempFile(File tempFile) async {
    try {
      if (tempFile.existsSync() && tempFile.path.contains('_compressed_')) {
        await tempFile.delete();
        debugPrint('Cleaned up temp file: ${tempFile.path}');
      }
    } catch (e) {
      debugPrint('Error cleaning up temp file: $e');
    }
  }
}

/// Helper class for image dimensions
class ImageDimensions {
  final int width;
  final int height;

  const ImageDimensions(this.width, this.height);

  @override
  String toString() => '${width}x$height';
  
  double get aspectRatio => width / height;
}
