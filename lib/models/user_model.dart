class UserModel {
  final String uid;
  final String email;
  final String? name;
  final String? avatarUrl;
  final DateTime? dateOfBirth;
  final String? mobileNumber;
  final String? rollNo;
  final bool isProfileComplete;

  UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.avatarUrl,
    this.dateOfBirth,
    this.mobileNumber,
    this.rollNo,
    this.isProfileComplete = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'],
      avatarUrl: map['avatarUrl'],
      dateOfBirth: map['dateOfBirth'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['dateOfBirth']) 
          : null,
      mobileNumber: map['mobileNumber'],
      rollNo: map['rollNo'],
      isProfileComplete: map['isProfileComplete'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'dateOfBirth': dateOfBirth?.millisecondsSinceEpoch,
      'mobileNumber': mobileNumber,
      'rollNo': rollNo,
      'isProfileComplete': isProfileComplete,
    };
  }
}