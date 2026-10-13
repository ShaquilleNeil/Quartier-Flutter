import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat.dart';
import '../../providers.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../landlord/landlord_profile.dart';
import '../tenant/tenant_profile_public.dart';

/// Shared body of `LandlordMessages.swift` and `TenantMessages.swift`.
class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key, required this.isLandlord});
  final bool isLandlord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: asyncBody(ref.watch(conversationsProvider), (convs) {
        if (convs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.message_outlined,
                    size: 48, color: QColors.blue.withValues(alpha: .5)),
                const SizedBox(height: 12),
                const Text('No conversations yet',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  isLandlord
                      ? 'Conversations appear when tenants reach out about a listing.'
                      : 'Tap Contact Landlord on a listing to start chatting.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ]),
            ),
          );
        }
        return ListView.separated(
          itemCount: convs.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
          itemBuilder: (context, i) {
            final c = convs[i];
            return Dismissible(
              key: ValueKey(c.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) =>
                  ref.read(chatRepoProvider).deleteConversation(c.id),
              child: _ConversationRow(conversation: c, isLandlord: isLandlord),
            );
          },
        );
      }),
    );
  }
}

/// Port of `ConversationRow`. Looks up the other party's name and photo.
class _ConversationRow extends ConsumerWidget {
  const _ConversationRow({required this.conversation, required this.isLandlord});
  final Conversation conversation;
  final bool isLandlord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = conversation;
    final other = ref
        .watch(userProfileProvider(isLandlord ? c.tenantId : c.landlordId))
        .value;
    final name = isLandlord
        ? (c.tenantName.isNotEmpty ? c.tenantName : null)
        : (other == null
            ? null
            : (other.name.isNotEmpty ? other.name : other.email));
    final title = name != null
        ? '$name · ${c.listingAddress}'
        : (c.listingAddress.isEmpty ? 'Listing' : c.listingAddress);
    final unread = isLandlord ? c.landlordUnreadCount : c.tenantUnreadCount;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Avatar(url: other?.profilePic),
      title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(c.lastMessageText, maxLines: 2),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(relativeTime(c.lastMessageAt),
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Badge(label: Text('$unread')),
          ],
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ChatScreen(conversation: c, isLandlord: isLandlord))),
    );
  }
}

/// Port of `LandlordChatView` and `TenantChatView`.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen(
      {super.key, required this.conversation, required this.isLandlord});
  final Conversation conversation;
  final bool isLandlord;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  /// Scroll to the newest message only when the count changes, not on
  /// every rebuild (the text field rebuilds on each keystroke).
  int _shownCount = 0;

  Conversation get c => widget.conversation;

  @override
  void initState() {
    super.initState();
    ref
        .read(chatRepoProvider)
        .markAsRead(c.id, isLandlord: widget.isLandlord);
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = ref.read(currentUidProvider);
    final text = _text.text;
    if (uid == null || text.trim().isEmpty) return;
    _text.clear();
    try {
      await ref
          .read(chatRepoProvider)
          .sendMessage(conversation: c, senderId: uid, text: text);
    } catch (e) {
      if (mounted) showSnack(context, 'Message not sent: $e');
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final otherId = widget.isLandlord ? c.tenantId : c.landlordId;
    final other = ref.watch(userProfileProvider(otherId)).value;

    final title = widget.isLandlord
        ? (c.tenantName.isEmpty ? 'Tenant' : c.tenantName)
        : (c.listingAddress.isEmpty ? 'Chat' : c.listingAddress);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 16)),
        actions: [
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => widget.isLandlord
                    ? TenantProfilePublicScreen(tenantId: c.tenantId)
                    : LandlordProfile(publicId: c.landlordId))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                if (other != null)
                  Text(other.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Avatar(url: other?.profilePic, size: 34),
              ]),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: asyncBody(ref.watch(messagesProvider(c.id)), (msgs) {
            if (msgs.length != _shownCount) {
              _shownCount = msgs.length;
              _scrollToEnd();
            }
            return ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i];
                final out = m.senderId == uid;
                return Align(
                  alignment: out ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(
                        top: 4, bottom: 4, left: out ? 40 : 0, right: out ? 0 : 40),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: out ? QColors.blue : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(m.text,
                        style: TextStyle(
                            fontSize: 14,
                            color: out ? Colors.white : Colors.black87)),
                  ),
                );
              },
            );
          }),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    filled: true,
                    fillColor: const Color(0xFFF2F2F7),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _text.text.trim().isEmpty ? null : _send,
                icon: const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
