import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register a user document with provided data
  Future<void> registerUser(UserModel user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);

      // Start from the user model map
      final data = user.toMap();

      // Hash password before storing (if provided)
      if (user.rollNo != null &&
          user.rollNo!.isNotEmpty &&
          user.password != null &&
          user.password!.isNotEmpty) {
        data['password'] = _hashPassword(user.rollNo!, user.password!);
      }

      // Ensure notification preference fields exist for new users
      data['chatNotificationsEnabled'] ??= true;
      data['likeNotificationsEnabled'] ??= true;
      data['tagNotificationsEnabled'] ??= true;
      data['commentNotificationsEnabled'] ??= true;
      data['matchNotificationsEnabled'] ??= true;
      data['notificationFrequency'] ??= 'medium';

      await docRef.set(data, SetOptions(merge: true));
    } on PlatformException catch (e) {
      throw Exception('Platform error during register: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  // Login with roll number (case-insensitive) and password
  Future<UserModel> loginWithRollNo(String rollNo, String password) async {
    try {
      final normalized = rollNo.trim().toLowerCase();
      final query = await _firestore
          .collection('users')
          .where('rollNo', isEqualTo: normalized)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('User not found');
      }

      final data = query.docs.first.data();
      final user = UserModel.fromMap({...data, 'uid': query.docs.first.id});

      final storedPassword = user.password ?? '';
      if (storedPassword.isEmpty) {
        throw Exception('Invalid credentials');
      }

      // First try hashed comparison
      final hashedInput = _hashPassword(normalized, password);
      if (storedPassword == hashedInput) {
        return user;
      }

      // Backward compatibility: if stored value matches raw password,
      // treat as valid once and upgrade to hashed.
      if (storedPassword == password) {
        try {
          final newHash = hashedInput;
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'password': newHash});
        } catch (_) {}
        return user;
      }

      throw Exception('Invalid credentials');
    } catch (e) {
      rethrow;
    }
  }

  // Create or update user profile
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(
        user.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      rethrow;
    }
  }

  // Get user profile
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final map = doc.data();
        if (map == null) return null;
        map['uid'] = uid;
        return UserModel.fromMap(map);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  String _hashPassword(String rollNo, String password) {
    final normalizedRoll = rollNo.trim().toLowerCase();
    final bytes = utf8.encode('$normalizedRoll::$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}