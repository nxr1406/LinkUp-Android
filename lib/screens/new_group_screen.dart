import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../utils/app_colors.dart';
import '../widgets/avatar_widget.dart';
import 'chat_screen.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  // Step 1: select members  |  Step 2: set group name
  bool _namingStep = false;

  final _searchCtrl = TextEditingController();
  final _groupNameCtrl = TextEditingController();
  final _userService = UserService();
  final _currentUser = FirebaseAuth.instance.currentUser!;

  List<UserModel> _results = [];
  final List<UserModel> _selected = [];
  bool _loading = false;
  bool _creating = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await _userService.searchUsers(q.trim());
      setState(() =>
          _results = results.where((u) => u.uid != _currentUser.uid).toList());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleUser(UserModel user) {
    setState(() {
      final idx = _selected.indexWhere((u) => u.uid == user.uid);
      if (idx >= 0) {
        _selected.removeAt(idx);
      } else {
        _selected.add(user);
      }
    });
  }

  bool _isSelected(UserModel u) => _selected.any((s) => s.uid == u.uid);

  Future<void> _createGroup() async {
    final name = _groupNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a group name'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final participants = [
        _currentUser.uid,
        ..._selected.map((u) => u.uid),
      ];

      // Create group chat document
      final chatRef = FirebaseFirestore.instance.collection('chats').doc();
      await chatRef.set({
        'participants': participants,
        'isGroup': true,
        'groupName': name,
        'createdBy': _currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '${_currentUser.displayName ?? 'You'} created this group',
        'lastMessageSenderId': _currentUser.uid,
        'lastMessageStatus': 'sent',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {
          for (final uid in participants) uid: 0,
        },
        'deletedFor': {},
        'nicknames': {},
      });

      if (!mounted) return;

      // Navigate to the group chat
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatRef.id,
            otherUser: null,
            currentUid: _currentUser.uid,
            groupName: name,
            groupParticipants: _selected,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to create group: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
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
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF111111), size: 20),
          onPressed: () {
            if (_namingStep) {
              setState(() => _namingStep = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _namingStep ? 'New Group' : 'Add Participants',
            style: const TextStyle(
              color: Color(0xFF111111),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          if (!_namingStep)
            Text(
              '${_selected.length} of 256 selected',
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
        ]),
        actions: [
          if (!_namingStep && _selected.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _namingStep = true),
              child: const Text(
                'Next',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: _namingStep ? _buildNamingStep() : _buildSelectionStep(),
    );
  }

  // ── Step 1: Select members ─────────────────────────────────────────────────
  Widget _buildSelectionStep() {
    return Column(children: [
      // Selected chips row
      if (_selected.isNotEmpty)
        Container(
          height: 80,
          color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: _selected.length,
            itemBuilder: (_, i) {
              final u = _selected[i];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => _toggleUser(u),
                  child: Column(children: [
                    Stack(children: [
                      AvatarWidget(user: u, radius: 22),
                      Positioned(
                        top: 0, right: 0,
                        child: Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 10),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      u.username,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF444444)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ),
              );
            },
          ),
        ),

      if (_selected.isNotEmpty)
        const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),

      // Search field
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _search,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: Color(0xFF888888)),
              prefixIcon: Icon(Icons.search, color: Color(0xFF888888), size: 20),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            ),
          ),
        ),
      ),

      // Results
      Expanded(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _results.isEmpty
                ? Center(
                    child: Text(
                      _searchCtrl.text.isEmpty
                          ? 'Search for people to add'
                          : 'No users found',
                      style: const TextStyle(
                          color: Color(0xFF9E9E9E), fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final user = _results[i];
                      final sel = _isSelected(user);
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        leading: AvatarWidget(user: user, radius: 24),
                        title: Row(children: [
                          Text(user.username,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Color(0xFF111111))),
                          if (user.isVerified) ...[
                            const SizedBox(width: 3),
                            const Icon(Icons.verified,
                                color: AppColors.verified, size: 14),
                          ],
                        ]),
                        subtitle: Text(user.displayName,
                            style: const TextStyle(
                                color: Color(0xFF888888), fontSize: 13)),
                        trailing: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sel ? AppColors.primary : Colors.transparent,
                            border: Border.all(
                              color: sel
                                  ? AppColors.primary
                                  : const Color(0xFFCCCCCC),
                              width: 2,
                            ),
                          ),
                          child: sel
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 16)
                              : null,
                        ),
                        onTap: () => _toggleUser(user),
                      );
                    },
                  ),
      ),
    ]);
  }

  // ── Step 2: Name the group ─────────────────────────────────────────────────
  Widget _buildNamingStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Group icon placeholder
        Center(
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group, color: Color(0xFF9E9E9E), size: 40),
          ),
        ),
        const SizedBox(height: 28),

        const Text('Group name',
            style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),

        TextField(
          controller: _groupNameCtrl,
          autofocus: true,
          maxLength: 50,
          style: const TextStyle(
              fontSize: 16, color: Color(0xFF111111), fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Enter group name',
            hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
            filled: true,
            fillColor: const Color(0xFFF0F2F5),
            counterStyle: const TextStyle(color: Color(0xFF9E9E9E)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 20),

        // Participants preview
        Text(
          '${_selected.length} participants',
          style: const TextStyle(
              color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _selected.map((u) => Chip(
            avatar: AvatarWidget(user: u, radius: 12),
            label: Text(u.username,
                style: const TextStyle(fontSize: 12, color: Color(0xFF333333))),
            backgroundColor: const Color(0xFFF0F2F5),
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          )).toList(),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _creating ? null : _createGroup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _creating
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Create Group',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}
