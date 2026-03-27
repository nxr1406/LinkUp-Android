import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart' as ap;
import '../models/user_model.dart';
import '../utils/theme.dart';
import '../widgets/user_avatar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<UserModel> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  void _onChanged() {
    final q = _ctrl.text.trim();
    if (q.length >= 2) {
      _search(q);
    } else {
      setState(() => _results = []);
    }
  }

  Future<void> _search(String text) async {
    final authProvider = Provider.of<ap.AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final userData = authProvider.userData;
    if (currentUser == null) return;

    setState(() => _loading = true);
    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: text.toLowerCase())
          .where('username', isLessThanOrEqualTo: '${text.toLowerCase()}\uf8ff')
          .get();

      final users = q.docs
          .map((d) => UserModel.fromDoc(d))
          .where((u) =>
              u.id != currentUser.uid &&
              !(userData?.blockedUsers.contains(u.id) ?? false))
          .toList();

      if (mounted) setState(() => _results = users);
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openOrCreateChat(String otherUserId) async {
    final authProvider = Provider.of<ap.AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return;

    try {
      // Check if chat already exists
      final existing = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      String? chatId;
      for (final doc in existing.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(otherUserId)) {
          chatId = doc.id;
          break;
        }
      }

      // Create new chat if not found
      chatId ??= (await FirebaseFirestore.instance.collection('chats').add({
        'participants': [currentUser.uid, otherUserId],
        'lastMessage': '',
        'lastMessageSenderId': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {currentUser.uid: 0, otherUserId: 0},
        'typing': [],
        'createdAt': FieldValue.serverTimestamp(),
      }))
          .id;

      if (mounted) context.go('/chat/$chatId');
    } catch (e) {
      debugPrint('Error opening chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 32),
                  const Expanded(
                    child: Center(
                      child: Text('Search',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/app'),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    const Icon(Icons.search, color: AppColors.subText, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(
                              color: AppColors.subText, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.text),
                      ),
                    ),
                    if (_ctrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _ctrl.clear();
                          setState(() => _results = []);
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(Icons.cancel,
                              color: AppColors.subText, size: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Results
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _ctrl.text.isEmpty
                      ? _emptyState()
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                "No results for '${_ctrl.text}'",
                                style: const TextStyle(
                                    color: AppColors.subText, fontSize: 14),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (_, i) {
                                final user = _results[i];
                                return ListTile(
                                  leading: UserAvatar(
                                    avatarUrl: user.avatarUrl,
                                    name: user.fullName,
                                    size: 44,
                                  ),
                                  title: Text(user.fullName,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text)),
                                  subtitle: Text(user.username,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.subText)),
                                  onTap: () =>
                                      context.go('/app/user/${user.id}'),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined,
              size: 64, color: AppColors.border),
          SizedBox(height: 12),
          Text('Search for people',
              style: TextStyle(fontSize: 14, color: AppColors.subText)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }
}
