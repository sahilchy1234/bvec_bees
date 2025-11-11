import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register a user document with provided data
  Future<void> registerUser(UserModel user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      await docRef.set(user.toMap(), SetOptions(merge: true));
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

      if ((user.password ?? '') != password) {
        throw Exception('Invalid credentials');
      }

      return user;
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
}