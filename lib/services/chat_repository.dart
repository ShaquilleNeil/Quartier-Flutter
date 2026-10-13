import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat.dart';
import '../utils/firestore_utils.dart';

/// Port of `ChatViewModel.swift`.
class ChatRepository {
  ChatRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');

  /// Uses the same composite index as iOS
  /// (`landlordId|tenantId` + `lastMessageAt desc`).
  Stream<List<Conversation>> conversations(String uid,
          {required bool isLandlord}) =>
      _conversations
          .where(isLandlord ? 'landlordId' : 'tenantId', isEqualTo: uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(Conversation.fromFirestore).toList());

  Stream<List<ChatMessage>> messages(String conversationId) => _conversations
      .doc(conversationId)
      .collection('messages')
      .orderBy('sentAt')
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromFirestore).toList());

  /// "Contact Landlord". The iOS app kept conversation ids only in its local
  /// Core Data store; here we look the thread up in Firestore so every device
  /// (and the iOS app's existing threads) land in the same conversation.
  /// Nothing is written until the first message is sent, as on iOS.
  Future<Conversation> openOrCreate({
    required String tenantId,
    required String tenantName,
    required String landlordId,
    required String listingId,
    required String listingAddress,
  }) async {
    final existing = await _conversations
        .where('tenantId', isEqualTo: tenantId)
        .where('listingId', isEqualTo: listingId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return Conversation.fromFirestore(existing.docs.first);
    }
    return Conversation(
      id: newUuid(),
      listingId: listingId,
      listingAddress: listingAddress,
      tenantId: tenantId,
      landlordId: landlordId,
      tenantName: tenantName,
      lastMessageText: '',
      lastMessageAt: DateTime.now(),
    );
  }

  /// Port of `sendMessage`: one batch updating the conversation summary and
  /// adding the message.
  Future<void> sendMessage({
    required Conversation conversation,
    required String senderId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final convRef = _conversations.doc(conversation.id);
    final msgRef = convRef.collection('messages').doc();
    final isLandlordSender = senderId == conversation.landlordId;

    final batch = _db.batch()
      ..set(
          convRef,
          {
            'listingId': conversation.listingId,
            'listingAddress': conversation.listingAddress,
            'tenantId': conversation.tenantId,
            'landlordId': conversation.landlordId,
            'tenantName': conversation.tenantName,
            'lastMessageText': trimmed,
            'lastMessageAt': FieldValue.serverTimestamp(),
            'landlordUnreadCount':
                isLandlordSender ? 0 : FieldValue.increment(1),
            'tenantUnreadCount':
                isLandlordSender ? FieldValue.increment(1) : 0,
          },
          SetOptions(merge: true))
      ..set(msgRef, {
        'conversationId': conversation.id,
        'senderId': senderId,
        'text': trimmed,
        'sentAt': FieldValue.serverTimestamp(),
      });
    await batch.commit();
  }

  /// Clears this side's unread badge. Skipped for a conversation that hasn't
  /// been written yet (`update` on a missing doc would throw).
  Future<void> markAsRead(String conversationId, {required bool isLandlord}) async {
    try {
      await _conversations.doc(conversationId).update(
          {isLandlord ? 'landlordUnreadCount' : 'tenantUnreadCount': 0});
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') rethrow;
    }
  }

  Future<void> deleteConversation(String id) => _conversations.doc(id).delete();
}
