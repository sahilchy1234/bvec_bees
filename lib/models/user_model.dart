import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? name;
  final String? avatarUrl;
  final String? idCardUrl;
  final String? rollNo;
  final String? semester;
  final String? branch;
  final DateTime? birthdate;
  final String? gender;
  final String? lookingFor; // 'opposite', 'same', 'both'
  final bool isVerified;
  final String? password;
  final DateTime? boostUntil; // New user visibility boost
  final int hotCount; // Total times voted "hot"
  final int? leaderboardRank;
  final DateTime? suspendedUntil;
  final String? suspensionNote;
  final DateTime? suspensionSetAt;
  final String? hometown;
  final String? bio;
  final String? interests;

  UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.avatarUrl,
    this.idCardUrl,
    this.rollNo,
    this.semester,
    this.branch,
    this.birthdate,
    this.gender,
    this.lookingFor,
    this.isVerified = false,
    this.password,
    this.boostUntil,
    this.hotCount = 0,
    this.leaderboardRank,
    this.suspendedUntil,
    this.suspensionNote,
    this.suspensionSetAt,
    this.hometown,
    this.bio,
    this.interests,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'],
      avatarUrl: map['avatarUrl'],
      idCardUrl: map['idCardUrl'],
      rollNo: map['rollNo'],
      semester: map['semester'],
      branch: map['branch'],
      birthdate: _parseDate(map['birthdate']),
      gender: map['gender'],
      lookingFor: map['lookingFor'],
      isVerified: map['isVerified'] ?? false,
      password: map['password'],
      boostUntil: _parseDate(map['boostUntil']),
      hotCount: map['hotCount'] ?? 0,
      leaderboardRank: map['leaderboardRank'],
      suspendedUntil: _parseDate(map['suspendedUntil']),
      suspensionNote: map['suspensionNote'],
      suspensionSetAt: _parseDate(map['suspensionSetAt']),
      hometown: map['hometown'],
      bio: map['bio'],
      interests: map['interests'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'idCardUrl': idCardUrl,
      'rollNo': rollNo,
      'semester': semester,
      'branch': branch,
      'birthdate': birthdate?.toIso8601String(),
      'gender': gender,
      'lookingFor': lookingFor,
      'isVerified': isVerified,
      'password': password,
      'boostUntil': boostUntil?.toIso8601String(),
      'hotCount': hotCount,
      'leaderboardRank': leaderboardRank,
      'suspendedUntil': suspendedUntil?.toIso8601String(),
      'suspensionNote': suspensionNote,
      'suspensionSetAt': suspensionSetAt?.toIso8601String(),
      'hometown': hometown,
      'bio': bio,
      'interests': interests,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }
}