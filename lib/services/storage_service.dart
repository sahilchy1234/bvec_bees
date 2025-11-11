import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Map<String, String> _urlCache = {};
  
  // Set storage settings for better performance
  StorageService() {
    _storage.setMaxDownloadRetryTime(const Duration(seconds: 30));
    _storage.setMaxUploadRetryTime(const Duration(seconds: 30));
  }

  Future<String> uploadIdCard(String userId, File imageFile) async {
    try {
      if (!imageFile.existsSync()) {
        throw Exception('Image file does not exist');
      }

      final File compressedFile = await _compressImage(imageFile);
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(compressedFile.path)}';
      final String filePath = 'id_cards/$fileName';

      final ref = _storage.ref().child(filePath);
      final metadata = SettableMetadata(
        contentType: 'image/${path.extension(compressedFile.path).replaceFirst('.', '')}',
        customMetadata: {'userId': userId},
        cacheControl: 'public, max-age=31536000',
      );

      final uploadTask = ref.putFile(compressedFile, metadata);
      final snapshot = await uploadTask.whenComplete(() {});
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await snapshot.ref.getDownloadURL();
        _urlCache[filePath] = downloadUrl;
        if (compressedFile.path != imageFile.path) {
          await compressedFile.delete();
        }
        return downloadUrl;
      } else {
        throw Exception('Upload failed: ${snapshot.state}');
      }
    } catch (e) {
      debugPrint('Error in uploadIdCard for $userId: $e');
      throw Exception('Failed to upload ID card: $e');
    }
  }

  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      if (!imageFile.existsSync()) {
        throw Exception('Image file does not exist');
      }

      // Compress and resize image before upload
      final File compressedFile = await _compressImage(imageFile);
      
      // Create a unique file name using the user ID and timestamp
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(compressedFile.path)}';
      final String filePath = 'profile_images/$fileName';
      
      // Create a reference to the file location
      final ref = _storage.ref().child(filePath);
      
      // Upload the file with metadata and caching headers
      final metadata = SettableMetadata(
        contentType: 'image/${path.extension(compressedFile.path).replaceFirst('.', '')}',
        customMetadata: {'userId': userId},
        cacheControl: 'public, max-age=31536000', // Cache for 1 year
      );
      
      // Create the upload task
      final uploadTask = ref.putFile(compressedFile, metadata);
      
      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        debugPrint('Upload progress for $userId: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100}%');
      }, onError: (error) {
        debugPrint('Upload error for $userId: $error');
      });

      // Wait for the upload to complete
      final snapshot = await uploadTask.whenComplete(() => debugPrint('Upload completed for $userId'));
      
      if (snapshot.state == TaskState.success) {
        // Get the download URL
        final downloadUrl = await snapshot.ref.getDownloadURL();
        debugPrint('Download URL obtained for $userId: $downloadUrl');
        
        // Cache the URL
        _urlCache[filePath] = downloadUrl;
        
        // Clean up compressed file
        if (compressedFile.path != imageFile.path) {
          await compressedFile.delete();
        }
        
        return downloadUrl;
      } else {
        throw Exception('Upload failed: ${snapshot.state}');
      }
    } catch (e) {
      debugPrint('Error in uploadProfileImage for $userId: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      // Read the image
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) throw Exception('Could not decode image');

      // Calculate new dimensions while maintaining aspect ratio
      int width = image.width;
      int height = image.height;
      
      // Target width for profile images
      const targetWidth = 512;
      
      if (width > targetWidth) {
        height = (height * targetWidth / width).round();
        width = targetWidth;
      }

      // Resize the image
      final resized = img.copyResize(
        image,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );

      // Compress the image
      final compressed = img.encodeJpg(resized, quality: 85);

      // Create a temporary file
      final tempPath = file.path + '_compressed.jpg';
      final compressedFile = File(tempPath);
      await compressedFile.writeAsBytes(compressed);

      return compressedFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      // Return original file if compression fails
      return file;
    }
  }
  
  Future<void> deleteProfileImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }
}