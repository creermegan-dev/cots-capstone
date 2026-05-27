import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `users/{uid}` profile for COTS Monitor.
///
/// [role] stores the user's job title from signup (Position / Role).
/// [accountRole] is app-wide RBAC: `user` for self-signup accounts; `admin` for the
/// provisioned administrator (set only in Firebase Console, not via the app).
class UserModel {
  const UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.organization,
    required this.createdAt,
    required this.profileImage,
    required this.isActive,
    this.accountRole = defaultAccountRole,
  });

  static const String defaultAccountRole = 'user';

  /// Application admin (admin dashboard). Stored in Firestore as `accountRole`.
  static const String adminAccountRole = 'admin';

  bool get isAdmin =>
      accountRole.trim().toLowerCase() == adminAccountRole.toLowerCase();

  final String uid;
  final String fullName;
  final String email;
  final String phoneNumber;
  /// Position / role chosen at registration (e.g. Field Monitor).
  final String role;
  /// Application-level role for future admin features (`user`, `admin`, …).
  final String accountRole;
  final String organization;
  final DateTime? createdAt;
  final String profileImage;
  final bool isActive;

  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Missing user document ${snapshot.id}');
    }
    return UserModel.fromMap(data, uid: snapshot.id);
  }

  /// Reads `accountRole` from Firestore (accepts `accountRole` or `AccountRole`, coerces to string).
  static String accountRoleFromMap(Map<String, dynamic> map) {
    final dynamic v = map['accountRole'] ?? map['AccountRole'];
    if (v == null) return defaultAccountRole;
    if (v is String) return v.trim();
    return v.toString().trim();
  }

  /// Parses a Firestore REST API document (`fields` map).
  factory UserModel.fromRestDocument(Map<String, dynamic> doc) {
    final name = doc['name'] as String? ?? '';
    final uid = name.split('/').isNotEmpty ? name.split('/').last : '';
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    return UserModel.fromRestFields(fields, uid: uid);
  }

  factory UserModel.fromRestFields(
    Map<String, dynamic> fields, {
    required String uid,
  }) {
    String readString(String key) {
      final v = fields[key];
      if (v is Map && v['stringValue'] != null) {
        return v['stringValue'].toString();
      }
      return '';
    }

    bool readBool(String key) {
      final v = fields[key];
      if (v is Map && v['booleanValue'] is bool) {
        return v['booleanValue'] as bool;
      }
      return true;
    }

    DateTime? readTimestamp(String key) {
      final v = fields[key];
      if (v is Map && v['timestampValue'] is String) {
        return DateTime.tryParse(v['timestampValue'] as String);
      }
      return null;
    }

    final map = <String, dynamic>{
      'uid': readString('uid').isEmpty ? uid : readString('uid'),
      'fullName': readString('fullName'),
      'email': readString('email'),
      'phoneNumber': readString('phoneNumber'),
      'role': readString('role'),
      'accountRole': readString('accountRole'),
      'organization': readString('organization'),
      'profileImage': readString('profileImage'),
      'isActive': readBool('isActive'),
      'createdAt': readTimestamp('createdAt'),
    };
    return UserModel.fromMap(map, uid: uid);
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {required String uid}) {
    final created = map['createdAt'];
    DateTime? createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is DateTime) {
      createdAt = created;
    }

    return UserModel(
      uid: map['uid'] as String? ?? uid,
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      role: map['role'] as String? ?? '',
      accountRole: accountRoleFromMap(map),
      organization: map['organization'] as String? ?? '',
      createdAt: createdAt,
      profileImage: map['profileImage'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role,
      'accountRole': accountRole,
      'organization': organization,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'profileImage': profileImage,
      'isActive': isActive,
    };
  }

  /// Fields written on signup (`createdAt` uses server timestamp on write).
  Map<String, dynamic> toFirestoreCreateMap() {
    return {
      ...toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? role,
    String? accountRole,
    String? organization,
    DateTime? createdAt,
    String? profileImage,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      accountRole: accountRole ?? this.accountRole,
      organization: organization ?? this.organization,
      createdAt: createdAt ?? this.createdAt,
      profileImage: profileImage ?? this.profileImage,
      isActive: isActive ?? this.isActive,
    );
  }
}
