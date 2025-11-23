import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'image_compression_service.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Map<String, String> _urlCache = {};
  
  // Set storage settings for better performance
  StorageService() {
    _storage.setMaxDownloadRetryTime(const Duration(seconds: 30));
    _storage.setMaxUploadRetryTime(const Duration(seconds: 30));
  }

  Future<String> uploadIdCard(String userId, File imageFile) async {
    File? compressedFile;
    try {
      if (!imageFile.existsSync()) {
        throw Exception('Image file does not exist');
      }

      // Compress the ID card image (max 30KB)
      compressedFile = await ImageCompressionService.compressImage(
        imageFile, 
        CompressionType.idCard,
      );
      
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = 'id_cards/$fileName';

      final ref = _storage.ref().child(filePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': userId},
        cacheControl: 'public, max-age=31536000',
      );

      final uploadTask = ref.putFile(compressedFile, metadata);
      final snapshot = await uploadTask.whenComplete(() {});
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await snapshot.ref.getDownloadURL();
        _urlCache[filePath] = downloadUrl;
        return downloadUrl;
      } else {
        throw Exception('Upload failed: ${snapshot.state}');
      }
    } catch (e) {
      debugPrint('Error in uploadIdCard for $userId: $e');
      throw Exception('Failed to upload ID card: $e');
    } finally {
      // Clean up compressed file if it was created
      if (compressedFile != null && compressedFile.path != imageFile.path) {
        await ImageCompressionService.cleanupTempFile(compressedFile);
      }
    }
  }

  Future<String> uploadProfileImage(String userId, File imageFile) async {
    File? compressedFile;
    try {
      if (!imageFile.existsSync()) {
        throw Exception('Image file does not exist');
      }

      // Compress the profile image (max 30KB)
      compressedFile = await ImageCompressionService.compressImage(
        imageFile, 
        CompressionType.avatar,
      );
      
      // Create a unique file name using the user ID and timestamp
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = 'profile_images/$fileName';
      
      // Create a reference to the file location
      final ref = _storage.ref().child(filePath);
      
      // Upload the file with metadata and caching headers
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
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
        
        return downloadUrl;
      } else {
        throw Exception('Upload failed: ${snapshot.state}');
      }
    } catch (e) {
      debugPrint('Error in uploadProfileImage for $userId: $e');
      throw Exception('Failed to upload image: $e');
    } finally {
      // Clean up compressed file if it was created
      if (compressedFile != null && compressedFile.path != imageFile.path) {
        await ImageCompressionService.cleanupTempFile(compressedFile);
      }
    }
  }

  Future<String> uploadChatImage(
    String conversationId,
    String senderId,
    File imageFile,
  ) async {
    File? compressedFile;
    try {
      if (!imageFile.existsSync()) {
        throw Exception('Image file does not exist');
      }

      // Compress chat images using post settings (max ~200KB)
      compressedFile = await ImageCompressionService.compressImage(
        imageFile,
        CompressionType.post,
      );

      final fileName =
          '${senderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = 'chat_images/$conversationId/$fileName';

      final ref = _storage.ref().child(filePath);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'conversationId': conversationId,
          'senderId': senderId,
        },
        cacheControl: 'public, max-age=31536000',
      );

      final uploadTask = ref.putFile(compressedFile, metadata);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        debugPrint(
            'Chat image upload progress for $conversationId/$senderId: '
            '${(snapshot.bytesTransferred / snapshot.totalBytes) * 100}%');
      }, onError: (error) {
        debugPrint('Chat image upload error for $conversationId/$senderId: $error');
      });

      final snapshot = await uploadTask
          .whenComplete(() => debugPrint('Chat image upload completed for $conversationId/$senderId'));

      if (snapshot.state == TaskState.success) {
        final downloadUrl = await snapshot.ref.getDownloadURL();
        debugPrint('Chat image download URL for $conversationId/$senderId: $downloadUrl');
        _urlCache[filePath] = downloadUrl;
        return downloadUrl;
      } else {
        throw Exception('Chat image upload failed: ${snapshot.state}');
      }
    } catch (e) {
      debugPrint('Error in uploadChatImage for $conversationId/$senderId: $e');
      throw Exception('Failed to upload chat image: $e');
    } finally {
      if (compressedFile != null && compressedFile.path != imageFile.path) {
        await ImageCompressionService.cleanupTempFile(compressedFile);
      }
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