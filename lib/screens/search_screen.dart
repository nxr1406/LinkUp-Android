import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/verified_badge.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_searchCtrl.text.length >= 2) {
      _search(_searchCtrl.text.trim());
    } else {
      setState(() => _results = []);
    }
  }

  Future<void> _search(String text) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final authProvider = Provider.of<LinkUpAuthProvider>(context, listen: false);
    final isAdmin = authProvider.userData?['role'] == 'admin';
    setState(() => _loading = true);
    try {
      final lower = text.toLowerCase();
      final title = text[0].toUpperCase() + text.substring(1).toLowerCase();
      Future<QuerySnapshot> q(String field, String val) =>
          FirebaseFirestore.instance.collection('users')
              .where(field, isGreaterThanOrEqualTo: val)
              .where(field, isLessThanOrEqualTo: '$val\uf8ff')
              .get();
      final results = await Future.wait([q('username', lower), q('fullName', lower), q('fullName', title)]);
      final Map<String, Map<String, dynamic>> usersMap = {};
      for (final snap in results) {
        for (final doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (doc.id == currentUser?.uid) continue;
          final blocked = (authProvider.userData?['blockedUsers'] as List?) ?? [];
          if (blocked.contains(doc.id)) continue;
          if (data['isSuspended'] == true && !isAdmin) continue;
          usersMap[doc.id] = {'id': doc.id, ...data};
        }
      }
      setState(() { _results = usersMap.values.toList(); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _openChat(String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final existing = await FirebaseFirestore.instance.collection('chats')
        .where('participants', arrayContains: currentUser.uid).get();
    String? chatId;
    for (final doc in existing.docs) {
      if ((doc.data()['participants'] as List).contains(userId)) { chatId = doc.id; break; }
    }
    if (chatId == null) {
      final newChat = await FirebaseFirestore.instance.collection('chats').add({
        'participants': [currentUser.uid, userId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {currentUser.uid: 0, userId: 0},
      });
      chatId = newChat.id;
    }
    if (mounted) context.go('/chat/$chatId');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF262626);
    final inputFill = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFEFEF);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Search', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
        actions: [
          TextButton(
            onPressed: () => context.go('/app'),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF0095F6), fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: TextStyle(fontSize: 14, color: textPrimary),
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF8E8E8E)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E8E), size: 20),
              filled: true,
              fillColor: inputFill,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Color(0xFF0095F6), strokeWidth: 2))
        else if (_results.isEmpty && _searchCtrl.text.length >= 2)
          Expanded(child: Center(child: Text('No results found',
              style: TextStyle(color: isDark ? const Color(0xFF8E8E8E) : const Color(0xFF8E8E8E), fontSize: 14))))
        else
          Expanded(child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, i) {
              final user = _results[i];
              return ListTile(
                onTap: () => _openChat(user['id']),
                leading: AvatarWidget(url: getAvatarUrl(user), name: user['fullName'] ?? '', size: 44),
                title: Row(children: [
                  Text(user['username'] ?? '',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
                  if (user['isVerified'] == true) ...[const SizedBox(width: 4), const VerifiedBadge(size: 14)],
                ]),
                subtitle: Text(user['fullName'] ?? '',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
              );
            },
          )),
        if (_searchCtrl.text.isEmpty)
          Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.person_search, size: 64, color: isDark ? const Color(0xFF48484A) : const Color(0xFFDBDBDB)),
            const SizedBox(height: 12),
            Text('Search for people', style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF8E8E8E) : const Color(0xFF8E8E8E))),
          ]))),
      ]),
    );
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }
}
