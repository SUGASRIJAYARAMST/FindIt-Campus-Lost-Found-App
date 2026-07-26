import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String department;
  final String phone;
  final String role;
  final String status;
  final String profileImage;
  final int rewardPoints;
  final String badge;
  final String referralCode;
  final String referredBy;
  final int referralCount;
  final DateTime? createdAt;
  final bool notificationsEnabled;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.department = '',
    this.phone = '',
    this.role = 'student',
    this.status = 'active',
    this.profileImage = '',
    this.rewardPoints = 0,
    this.badge = 'Good Helper',
    this.referralCode = '',
    this.referredBy = '',
    this.referralCount = 0,
    this.createdAt,
    this.notificationsEnabled = true,
  });

  bool get isBlocked => status == 'blocked';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'department': department,
      'phone': phone,
      'role': role,
      'status': status,
      'profileImage': profileImage,
      'rewardPoints': rewardPoints,
      'badge': badge,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'referralCount': referralCount,
      'createdAt': FieldValue.serverTimestamp(),
      'notificationsEnabled': notificationsEnabled,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      department: map['department'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: map['role'] as String? ?? 'student',
      status: map['status'] as String? ?? 'active',
      profileImage: map['profileImage'] as String? ?? '',
      rewardPoints: (map['rewardPoints'] as num?)?.toInt() ?? 0,
      badge: map['badge'] as String? ?? 'Good Helper',
      referralCode: map['referralCode'] as String? ?? '',
      referredBy: map['referredBy'] as String? ?? '',
      referralCount: (map['referralCount'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? department,
    String? phone,
    String? role,
    String? status,
    String? profileImage,
    int? rewardPoints,
    String? badge,
    String? referralCode,
    String? referredBy,
    int? referralCount,
    DateTime? createdAt,
    bool? notificationsEnabled,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      department: department ?? this.department,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      profileImage: profileImage ?? this.profileImage,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      badge: badge ?? this.badge,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      referralCount: referralCount ?? this.referralCount,
      createdAt: createdAt ?? this.createdAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
