import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../utils/app_colors.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/user_badges.dart';
import 'new_chat_screen.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String chatId;
  const GroupSettingsScreen({super.key, required this.chatId});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final _currentUid = FirebaseAuth.instance.currentUser!.uid;
  final _chatService = ChatService();
  final _userService = UserService();

  bool _uploadingPhoto = false;

  // ── Role helpers ─────────────────────────────────────────────────────────
  String _role(ChatModel chat) =>
      chat.memberRoles[_currentUid] ??
      (chat.createdBy == _currentUid ? 'owner' : 'member');

  bool _isOwner(ChatModel chat) => _role(chat) == 'owner';
  bool _canManage(ChatModel chat) =>
      ['owner', 'admin', 'moderator'].contains(_role(chat));

  bool _canKick(ChatModel chat, String targetUid) {
    if (targetUid == _currentUid) return false;
    if (chat.createdBy == targetUid) return false; // can't kick owner
    final myRole = _role(chat);
    final targetRole = chat.memberRoles[targetUid] ?? 'member';
    if (myRole == 'owner' || myRole == 'admin') return true;
    if (myRole == 'moderator' && targetRole == 'member') return true;
    return false;
  }

  bool _canPromote(ChatModel chat, String targetUid) {
    if (targetUid == _currentUid) return false;
    return _isOwner(chat) ||
        (chat.memberRoles[_currentUid] == 'admin');
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final chat = ChatModel.fromMap(data, widget.chatId);
        final myRole = _role(chat);

        return Scaffold(
          backgroundColor: Colors.white,
          body: CustomScrollView(slivers: [
            // ── Sliver AppBar with group photo ────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF111111), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: GestureDetector(
                  onTap: _isOwner(chat) ? () => _changeGroupPhoto(chat) : null,
                  child: Stack(fit: StackFit.expand, children: [
                    chat.groupPhotoUrl?.isNotEmpty == true
                        ? _GroupPhoto(base64: chat.groupPhotoUrl!)
                        : Container(
                            color: AppColors.primary.withOpacity(0.1),
                            child: const Icon(Icons.group_rounded,
                                size: 80, color: AppColors.primary),
                          ),
                    // Edit overlay
                    if (_isOwner(chat))
                      Container(
                        color: Colors.black.withOpacity(0.25),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 40),
                            Icon(Icons.photo_camera_outlined,
                                color: Colors.white70, size: 28),
                            SizedBox(height: 6),
                            Text('Change photo',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    if (_uploadingPhoto)
                      const Center(
                          child: CircularProgressIndicator(color: Colors.white)),
                  ]),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(children: [
                // ── Group name ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        chat.groupName ?? 'Group',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ),
                    if (_isOwner(chat))
                      IconButton(
                        icon: const Icon(Icons.edit_rounded,
                            color: AppColors.primary, size: 20),
                        onPressed: () => _editGroupName(chat),
                      ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    _RoleBadge(role: myRole),
                    const SizedBox(width: 8),
                    Text('${chat.participants.length}/255 members',
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 13)),
                  ]),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),

                // ── Add member ────────────────────────────────────────────
                if (_canManage(chat))
                  _SectionTile(
                    icon: Icons.person_add_outlined,
                    label: 'Add member',
                    color: AppColors.primary,
                    onTap: chat.participants.length >= 255
                        ? null
                        : () => _addMember(chat),
                    subtitle: chat.participants.length >= 255
                        ? 'Group is full (255/255)' : null,
                  ),

                // ── Members list ──────────────────────────────────────────
                const _SectionHeader(label: 'MEMBERS'),

                ...chat.participants.map((uid) => _MemberTile(
                      uid: uid,
                      chat: chat,
                      currentUid: _currentUid,
                      canKick: _canKick(chat, uid),
                      canPromote: _canPromote(chat, uid),
                      userService: _userService,
                      onKick: () => _kickMember(chat, uid),
                      onSetRole: (role) => _setRole(chat, uid, role),
                      onMute: (muted) => _toggleMute(chat, uid, muted),
                      onSetNickname: () => _setNickname(chat, uid),
                    )),

                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 8),

                // ── Delete group (owner only) ─────────────────────────────
                if (_isOwner(chat))
                  _SectionTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete Group',
                    color: Colors.red,
                    onTap: () => _deleteGroup(chat),
                  ),

                // ── Leave group (non-owner) ───────────────────────────────
                if (!_isOwner(chat))
                  _SectionTile(
                    icon: Icons.exit_to_app_rounded,
                    label: 'Leave Group',
                    color: Colors.red,
                    onTap: () => _leaveGroup(chat),
                  ),

                const SizedBox(height: 32),
              ]),
            ),
          ]),
        );
      },
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _editGroupName(ChatModel chat) async {
    final ctrl = TextEditingController(text: chat.groupName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Group Name'),
        content: TextField(
          controller: ctrl,
          maxLength: 50,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter group name',
            filled: true,
            fillColor: const Color(0xFFF0F2F5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _chatService.updateGroupName(chatId: widget.chatId, name: result);
    }
  }

  Future<void> _changeGroupPhoto(ChatModel chat) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      // Decode, resize, compress — same as profile photo
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Could not decode image');
      decoded = img.copyResize(decoded, width: 256, height: 256);
      final compressed = img.encodeJpg(decoded, quality: 60);
      final base64Str = base64Encode(compressed);
      await _chatService.updateGroupPhoto(
          chatId: widget.chatId, photoUrl: base64Str);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _addMember(ChatModel chat) async {
    final user = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(
        builder: (_) => _UserPickerScreen(
            excludeUids: chat.participants),
      ),
    );
    if (user == null) return;
    await _chatService.addGroupMember(
        chatId: widget.chatId,
        uid: user.uid,
        addedByUid: _currentUid);
  }

  Future<void> _kickMember(ChatModel chat, String uid) async {
    final confirm = await _confirmDialog(
      'Remove Member?',
      'This member will be removed from the group.',
      confirmLabel: 'Remove',
      danger: true,
    );
    if (confirm == true) {
      await _chatService.removeGroupMember(
          chatId: widget.chatId, uid: uid);
    }
  }

  Future<void> _setRole(ChatModel chat, String uid, String role) async {
    await _chatService.setMemberRole(
        chatId: widget.chatId, uid: uid, role: role);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Role updated to $role'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ));
    }
  }

  Future<void> _toggleMute(ChatModel chat, String uid, bool muted) async {
    await _chatService.setMemberMuted(
        chatId: widget.chatId, uid: uid, muted: muted);
  }

  Future<void> _setNickname(ChatModel chat, String targetUid) async {
    final current = chat.nicknames[targetUid] ?? '';
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Set Nickname'),
        content: TextField(
          controller: ctrl,
          maxLength: 30,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter nickname (leave empty to clear)',
            filled: true,
            fillColor: const Color(0xFFF0F2F5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null) {
      await _chatService.setGroupNickname(
          chatId: widget.chatId,
          targetUid: targetUid,
          nickname: result);
    }
  }

  Future<void> _deleteGroup(ChatModel chat) async {
    final confirm = await _confirmDialog(
      'Delete Group?',
      'This will permanently delete the group and all messages for everyone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (confirm == true) {
      await _chatService.deleteGroup(chatId: widget.chatId);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _leaveGroup(ChatModel chat) async {
    final confirm = await _confirmDialog(
      'Leave Group?',
      'You will no longer receive messages from this group.',
      confirmLabel: 'Leave',
      danger: true,
    );
    if (confirm == true) {
      await _chatService.removeGroupMember(
          chatId: widget.chatId, uid: _currentUid);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<bool?> _confirmDialog(String title, String content,
      {required String confirmLabel, bool danger = false}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content,
            style: const TextStyle(color: Color(0xFF666666))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? Colors.red : AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Member Tile ───────────────────────────────────────────────────────────────
class _MemberTile extends StatelessWidget {
  final String uid;
  final String currentUid;
  final ChatModel chat;
  final bool canKick, canPromote;
  final UserService userService;
  final VoidCallback onKick, onSetNickname;
  final void Function(String role) onSetRole;
  final void Function(bool muted) onMute;

  const _MemberTile({
    required this.uid,
    required this.currentUid,
    required this.chat,
    required this.canKick,
    required this.canPromote,
    required this.userService,
    required this.onKick,
    required this.onSetRole,
    required this.onMute,
    required this.onSetNickname,
  });

  @override
  Widget build(BuildContext context) {
    final role = chat.memberRoles[uid] ??
        (chat.createdBy == uid ? 'owner' : 'member');
    final isMuted = chat.mutedMembers[uid] == true;
    final nickname = chat.nicknames[uid];

    return FutureBuilder<UserModel?>(
      future: userService.getUser(uid),
      builder: (context, snap) {
        final user = snap.data;
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: Stack(children: [
            AvatarWidget(user: user, radius: 22),
            if (isMuted)
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 14, height: 14,
                  decoration: const BoxDecoration(
                      color: Colors.orange, shape: BoxShape.circle),
                  child: const Icon(Icons.mic_off_rounded,
                      color: Colors.white, size: 8),
                ),
              ),
          ]),
          title: Row(children: [
            Flexible(
              child: Text(
                nickname?.isNotEmpty == true
                    ? nickname!
                    : (user?.username ?? uid),
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF111111)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (nickname?.isNotEmpty == true) ...[
              const SizedBox(width: 4),
              Text('(${user?.username ?? ''})',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9E9E9E))),
            ],
            if (uid != currentUid) UserBadges(user: user, size: 12),
            const SizedBox(width: 6),
            _RoleBadge(role: role, small: true),
          ]),
          subtitle: uid == currentUid
              ? const Text('You',
                  style:
                      TextStyle(color: Color(0xFF888888), fontSize: 12))
              : Text(user?.displayName ?? '',
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12)),
          trailing: uid == currentUid
              ? null
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: Color(0xFF888888), size: 18),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    switch (val) {
                      case 'nickname':
                        onSetNickname();
                        break;
                      case 'make_moderator':
                        onSetRole('moderator');
                        break;
                      case 'make_admin':
                        onSetRole('admin');
                        break;
                      case 'make_member':
                        onSetRole('member');
                        break;
                      case 'mute':
                        onMute(true);
                        break;
                      case 'unmute':
                        onMute(false);
                        break;
                      case 'kick':
                        onKick();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'nickname',
                      child: Row(children: [
                        Icon(Icons.edit_rounded,
                            size: 16, color: Color(0xFF444444)),
                        SizedBox(width: 10),
                        Text('Set Nickname'),
                      ]),
                    ),
                    if (canPromote && role == 'member') ...[
                      const PopupMenuItem(
                        value: 'make_moderator',
                        child: Row(children: [
                          Icon(Icons.shield_outlined,
                              size: 16, color: AppColors.primary),
                          SizedBox(width: 10),
                          Text('Make Moderator'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'make_admin',
                        child: Row(children: [
                          Icon(Icons.admin_panel_settings_rounded,
                              size: 16, color: AppColors.primary),
                          SizedBox(width: 10),
                          Text('Make Admin'),
                        ]),
                      ),
                    ],
                    if (canPromote &&
                        (role == 'moderator' || role == 'admin'))
                      const PopupMenuItem(
                        value: 'make_member',
                        child: Row(children: [
                          Icon(Icons.person_rounded,
                              size: 16, color: Color(0xFF888888)),
                          SizedBox(width: 10),
                          Text('Remove Role'),
                        ]),
                      ),
                    if (canKick)
                      PopupMenuItem(
                        value: isMuted ? 'unmute' : 'mute',
                        child: Row(children: [
                          Icon(
                            isMuted
                                ? Icons.mic_rounded
                                : Icons.mic_off_rounded,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 10),
                          Text(isMuted ? 'Unmute' : 'Mute'),
                        ]),
                      ),
                    if (canKick)
                      const PopupMenuItem(
                        value: 'kick',
                        child: Row(children: [
                          Icon(Icons.person_remove_outlined,
                              size: 16, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Remove',
                              style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

// ── Role Badge ────────────────────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  final String role;
  final bool small;
  const _RoleBadge({required this.role, this.small = false});

  @override
  Widget build(BuildContext context) {
    if (role == 'member') return const SizedBox.shrink();
    Color bg;
    String label;
    switch (role) {
      case 'owner':
        bg = const Color(0xFFFFB300);
        label = 'Owner';
        break;
      case 'admin':
        bg = AppColors.primary;
        label = 'Admin';
        break;
      case 'moderator':
        bg = const Color(0xFF7C3AED);
        label = 'Mod';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 5 : 7, vertical: small ? 1 : 2),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bg.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: bg,
          fontSize: small ? 9 : 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9E9E9E),
              letterSpacing: 0.8)),
    );
  }
}

// ── Section Tile ──────────────────────────────────────────────────────────────
class _SectionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String? subtitle;
  const _SectionTile(
      {required this.icon,
      required this.label,
      required this.color,
      this.onTap,
      this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(
                  color: Color(0xFF9E9E9E), fontSize: 12))
          : null,
      onTap: onTap,
    );
  }
}

// ── User Picker for add member ─────────────────────────────────────────────────
class _UserPickerScreen extends StatefulWidget {
  final List<String> excludeUids;
  const _UserPickerScreen({required this.excludeUids});

  @override
  State<_UserPickerScreen> createState() => _UserPickerScreenState();
}

class _UserPickerScreenState extends State<_UserPickerScreen> {
  final _ctrl = TextEditingController();
  final _userService = UserService();
  List<UserModel> _results = [];
  bool _loading = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await _userService.searchUsers(q.trim());
      setState(() => _results =
          r.where((u) => !widget.excludeUids.contains(u.uid)).toList());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF111111)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add Member',
            style: TextStyle(
                color: Color(0xFF111111), fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _ctrl,
              onChanged: _search,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(color: Color(0xFF888888)),
                prefixIcon:
                    Icon(Icons.search_rounded, color: Color(0xFF888888)),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final u = _results[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 2),
                      leading: AvatarWidget(user: u, radius: 22),
                      title: Row(children: [
                        Text(u.username,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        UserBadges(user: u, size: 13),
                      ]),
                      subtitle: Text(u.displayName,
                          style: const TextStyle(
                              color: Color(0xFF888888), fontSize: 13)),
                      onTap: () => Navigator.pop(context, u),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ── Group Photo (base64 decode) ───────────────────────────────────────────────
class _GroupPhoto extends StatelessWidget {
  final String base64;
  const _GroupPhoto({required this.base64});

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(base64);
      return Image.memory(bytes, fit: BoxFit.cover);
    } catch (_) {
      return Container(
        color: AppColors.primary.withOpacity(0.1),
        child: const Icon(Icons.group_rounded,
            size: 80, color: AppColors.primary),
      );
    }
  }
}
