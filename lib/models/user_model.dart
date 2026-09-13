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
    required this.assignedArea,
    required this.createdAt,
    required this.profileImage,
    required this.isActive,
    this.accountRole = defaultAccountRole,
    this.fieldPersonnelVerified = false,
    this.personnelVerifiedBy = '',
    this.personnelVerifiedAt,
  });

  static const String defaultAccountRole = 'user';

  /// Application admin (admin dashboard). Stored in Firestore as `accountRole`.
  static const String adminAccountRole = 'admin';

  /// Expert verifier — reviews low-confidence captures (`accountRole` in Firestore).
  static const String expertAccountRole = 'expert';

  bool get isAdmin =>
      accountRole.trim().toLowerCase() == adminAccountRole.toLowerCase();

  bool get isExpert =>
      accountRole.trim().toLowerCase() == expertAccountRole.toLowerCase();

  final String uid;
  final String fullName;
  final String email;
  final String phoneNumber;

  /// Position / role chosen at registration (e.g. Field Monitor).
  final String role;

  /// Application-level role for future admin features (`user`, `admin`, …).
  final String accountRole;
  final String organization;
  final String assignedArea;
  final DateTime? createdAt;
  final String profileImage;
  final bool isActive;

  /// Admin-controlled eligibility for field intervention assignments.
  final bool fieldPersonnelVerified;
  final String personnelVerifiedBy;
  final DateTime? personnelVerifiedAt;

  bool get isVerifiedFieldPersonnel =>
      fieldPersonnelVerified && isActive && !isAdmin && !isExpert;

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

    bool readBool(String key, {bool fallback = true}) {
      final v = fields[key];
      if (v is Map && v['booleanValue'] is bool) {
        return v['booleanValue'] as bool;
      }
      return fallback;
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
      'assignedArea': readString('assignedArea'),
      'profileImage': readString('profileImage'),
      'isActive': readBool('isActive'),
      'createdAt': readTimestamp('createdAt'),
      'fieldPersonnelVerified': readBool(
        'fieldPersonnelVerified',
        fallback: false,
      ),
      'personnelVerifiedBy': readString('personnelVerifiedBy'),
      'personnelVerifiedAt': readTimestamp('personnelVerifiedAt'),
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
      assignedArea: map['assignedArea'] as String? ?? '',
      createdAt: createdAt,
      profileImage: map['profileImage'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      fieldPersonnelVerified: map['fieldPersonnelVerified'] as bool? ?? false,
      personnelVerifiedBy: map['personnelVerifiedBy'] as String? ?? '',
      personnelVerifiedAt: _dateTimeFromDynamic(map['personnelVerifiedAt']),
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
      'assignedArea': assignedArea,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'profileImage': profileImage,
      'isActive': isActive,
      'fieldPersonnelVerified': fieldPersonnelVerified,
      'personnelVerifiedBy': personnelVerifiedBy,
      if (personnelVerifiedAt != null)
        'personnelVerifiedAt': Timestamp.fromDate(personnelVerifiedAt!),
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
    String? assignedArea,
    DateTime? createdAt,
    String? profileImage,
    bool? isActive,
    bool? fieldPersonnelVerified,
    String? personnelVerifiedBy,
    DateTime? personnelVerifiedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      accountRole: accountRole ?? this.accountRole,
      organization: organization ?? this.organization,
      assignedArea: assignedArea ?? this.assignedArea,
      createdAt: createdAt ?? this.createdAt,
      profileImage: profileImage ?? this.profileImage,
      isActive: isActive ?? this.isActive,
      fieldPersonnelVerified:
          fieldPersonnelVerified ?? this.fieldPersonnelVerified,
      personnelVerifiedBy: personnelVerifiedBy ?? this.personnelVerifiedBy,
      personnelVerifiedAt: personnelVerifiedAt ?? this.personnelVerifiedAt,
    );
  }

  static DateTime? _dateTimeFromDynamic(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
