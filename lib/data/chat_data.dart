import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message_model.dart';

class ChatData {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static final CollectionReference<Map<String, dynamic>> _chats =
      _firestore.collection('chats');

  /// Creates a consistent conversation ID for a ride and passenger.
  static String getChatId({
    required String rideId,
    required String studentUid,
  }) {
    return '${rideId}_$studentUid';
  }

  /// Creates or retrieves the conversation between a ride creator
  /// and one passenger.
  static Future<String> createOrGetChat({
    required String rideId,
    required String bookingId,
    required String rideCreatorUid,
    required String rideCreatorName,
    required String studentUid,
    required String studentName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in to open the chat.');
    }

    if (user.uid != rideCreatorUid &&
        user.uid != studentUid) {
      throw Exception('You are not a participant in this chat.');
    }

    final chatId = getChatId(
      rideId: rideId,
      studentUid: studentUid,
    );

    final chatRef = _chats.doc(chatId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(chatRef);

      if (!snapshot.exists) {
        transaction.set(chatRef, {
          'rideId': rideId,
          'bookingId': bookingId,
          'rideCreatorUid': rideCreatorUid,
          'rideCreatorName': rideCreatorName,
          'studentUid': studentUid,
          'studentName': studentName,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = snapshot.data()!;

        if (data['rideId'] != rideId ||
            data['bookingId'] != bookingId ||
            data['rideCreatorUid'] != rideCreatorUid ||
            data['studentUid'] != studentUid) {
          throw Exception('The conversation details do not match.');
        }
      }
    });

    return chatId;
  }

  /// Streams messages in chronological order.
  static Stream<List<ChatMessage>> watchMessages(
    String chatId,
  ) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatMessage.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  /// Sends a message and updates the conversation preview.
  static Future<void> sendMessage({
    required String chatId,
    required String text,
    required String senderName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in to send messages.');
    }

    final messageText = text.trim();

    if (messageText.isEmpty) {
      throw Exception('Message cannot be empty.');
    }

    if (messageText.length > 2000) {
      throw Exception('Message must be 2000 characters or fewer.');
    }

    final chatRef = _chats.doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    await _firestore.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatRef);

      if (!chatSnapshot.exists) {
        throw Exception('This conversation does not exist.');
      }

      final chat = chatSnapshot.data()!;

      if (user.uid != chat['rideCreatorUid'] &&
          user.uid != chat['studentUid']) {
        throw Exception('You cannot send messages in this chat.');
      }

      transaction.set(
        messageRef,
        ChatMessage(
          id: messageRef.id,
          senderUid: user.uid,
          senderName: senderName,
          text: messageText,
        ).toMap(),
      );

      transaction.update(chatRef, {
        'lastMessage': messageText,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    });
  }
}