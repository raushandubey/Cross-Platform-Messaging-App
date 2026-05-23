import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageTimestamp;
  final Map<String, int> unreadCounts; // Map of uid -> unreadCount

  ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageTimestamp,
    this.unreadCounts = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTimestamp': lastMessageTimestamp != null
          ? Timestamp.fromDate(lastMessageTimestamp!)
          : null,
      'unreadCounts': unreadCounts,
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    // Convert Firestore Map<String, dynamic> to Map<String, int> safely
    final rawUnreads = map['unreadCounts'] as Map<dynamic, dynamic>? ?? {};
    final parsedUnreads = rawUnreads.map<String, int>(
      (key, value) => MapEntry(key.toString(), (value as num).toInt()),
    );

    return ChatModel(
      id: map['id'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'],
      lastMessageSenderId: map['lastMessageSenderId'],
      lastMessageTimestamp: parseDate(map['lastMessageTimestamp']),
      unreadCounts: parsedUnreads,
    );
  }

  /// Helper to get the unread count for a specific user ID
  int getUnreadCountFor(String uid) {
    return unreadCounts[uid] ?? 0;
  }

  ChatModel copyWith({
    String? id,
    List<String>? participants,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastMessageTimestamp,
    Map<String, int>? unreadCounts,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      unreadCounts: unreadCounts ?? this.unreadCounts,
    );
  }
}
