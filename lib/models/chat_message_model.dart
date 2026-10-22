import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String text;
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.text,
    this.createdAt,
  });

  factory ChatMessage.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final timestamp = map['createdAt'];

    return ChatMessage(
      id: id,
      senderUid: map['senderUid'] ?? '',
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
      createdAt: timestamp is Timestamp
          ? timestamp.toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderUid': senderUid,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}