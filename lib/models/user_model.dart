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
      birthdate: map['birthdate'] != null ? DateTime.parse(map['birthdate']) : null,
      gender: map['gender'],
      lookingFor: map['lookingFor'],
      isVerified: map['isVerified'] ?? false,
      password: map['password'],
      boostUntil: map['boostUntil'] != null ? DateTime.parse(map['boostUntil']) : null,
      hotCount: map['hotCount'] ?? 0,
      leaderboardRank: map['leaderboardRank'],
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
    };
  }
}