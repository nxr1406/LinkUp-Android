import 'package:flutter/material.dart';
import 'package:linkup_chat_app/models/chat_model.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatTile extends StatelessWidget {
  final ChatModel chat;
  final String currentUserId;
  final String? otherUserName;
  final String? otherUserPhoto;
  final VoidCallback onTap;

  const ChatTile({
    Key? key,
    required this.chat,
    required this.currentUserId,
    this.otherUserName,
    this.otherUserPhoto,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = chat.type == ChatType.group
        ? (chat.groupName ?? 'Group')
        : (otherUserName ?? 'Unknown');
    final photo = chat.type == ChatType.group ? chat.groupIcon : otherUserPhoto;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: photo != null ? NetworkImage(photo) : null,
        child: photo == null ? Text(name[0].toUpperCase()) : null,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        chat.lastMessage ?? 'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: chat.lastMessageTime != null
          ? Text(timeago.format(chat.lastMessageTime!), style: const TextStyle(fontSize: 12, color: Colors.grey))
          : null,
    );
  }
}
