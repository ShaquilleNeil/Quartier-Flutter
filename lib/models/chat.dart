import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

/// Mirrors `Conversation` in `ChatViewModel.swift`.
/// Firestore document: `conversations/{conversationId}`.
///
/// The iOS app decodes this with Swift `Codable`, so `listingId`,
/// `listingAddress`, `tenantId`, `landlordId`, `tenantName`,
/// `lastMessageText` and `lastMessageAt` must always be present or the
/// conversation disappears from the iOS list.
class Conversation {
  Conversation({
    required this.id,
    required this.listingId,
    required this.listingAddress,
    required this.tenantId,
    required this.landlordId,
    required this.tenantName,
    required this.lastMessageText,
    required this.lastMessageAt,
    this.landlordUnreadCount = 0,
    this.tenantUnreadCount = 0,
  });

  final String id;
  final String listingId;
  final String listingAddress;
  final String tenantId;
  final String landlordId;
  final String tenantName;
  final String lastMessageText;
  final DateTime lastMessageAt;
  final int landlordUnreadCount;
  final int tenantUnreadCount;

  factory Conversation.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Conversation(
      id: doc.id,
      listingId: readString(d['listingId']),
      listingAddress: readString(d['listingAddress']),
      tenantId: readString(d['tenantId']),
      landlordId: readString(d['landlordId']),
      tenantName: readString(d['tenantName']),
      lastMessageText: readString(d['lastMessageText']),
      // serverTimestamp() is null locally until the write is acknowledged.
      lastMessageAt: readDate(d['lastMessageAt']),
      landlordUnreadCount: readInt(d['landlordUnreadCount']),
      tenantUnreadCount: readInt(d['tenantUnreadCount']),
    );
  }
}

/// Mirrors `ChatMessage` in `ChatViewModel.swift`.
/// Firestore document: `conversations/{conversationId}/messages/{messageId}`.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;

  factory ChatMessage.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ChatMessage(
      id: doc.id,
      conversationId: readString(d['conversationId']),
      senderId: readString(d['senderId']),
      text: readString(d['text']),
      sentAt: readDate(d['sentAt']),
    );
  }
}
