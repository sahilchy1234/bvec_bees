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
  final bool isVerified;
  final String? password;

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
    this.isVerified = false,
    this.password,
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
      isVerified: map['isVerified'] ?? false,
      password: map['password'],
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
      'isVerified': isVerified,
      'password': password,
    };
  }
}