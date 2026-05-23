import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String status; // 'online' | 'offline'
  final DateTime lastSeen;
  final String? fcmToken;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.status = 'offline',
    required this.lastSeen,
    this.fcmToken,
  });

  /// Get initials (e.g. "Arla Chen" -> "AC", "Nora" -> "NO")
  String get initials {
    if (displayName.isEmpty) return 'ME';
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return displayName
        .substring(0, displayName.length >= 2 ? 2 : 1)
        .toUpperCase();
  }

  /// JSON-safe map for SharedPreferences (no Timestamp objects)
  Map<String, dynamic> toJsonMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'status': status,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'fcmToken': fcmToken,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'status': status,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'fcmToken': fcmToken,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'],
      status: map['status'] ?? 'offline',
      lastSeen: parseDate(map['lastSeen']),
      fcmToken: map['fcmToken'],
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? status,
    DateTime? lastSeen,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
