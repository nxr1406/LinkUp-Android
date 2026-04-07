import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../utils/app_colors.dart';
import '../widgets/avatar_widget.dart';
import 'chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _userService = UserService();
  final _chatService = ChatService();
  List<UserModel> _results = [];
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() { _results = []; _hasSearched = false; });
      return;
    }
    setState(() => _loading = true);
    try {
      final me = FirebaseAuth.instance.currentUser!.uid;
      final results = await _userService.searchUsers(q.trim());
      setState(() {
        _results = results.where((u) => u.uid != me).toList();
        _hasSearched = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final me = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Search',
            style: TextStyle(
                color: AppColors.textPrimary(dark),
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () {
              _searchCtrl.clear();
              setState(() { _results = []; _hasSearched = false; });
              FocusScope.of(context).unfocus();
            },
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.primary, fontSize: 15)),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.inputFill(dark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider(dark)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _search,
              style: TextStyle(color: AppColors.textPrimary(dark)),
              decoration: InputDecoration(
                hintText: 'Search by username',
                hintStyle: TextStyle(color: AppColors.textSecondary(dark)),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary(dark)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : !_hasSearched
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.person_search,
                            size: 64,
                            color: AppColors.textSecondary(dark).withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text('Search for people',
                            style: TextStyle(
                                color: AppColors.textSecondary(dark),
                                fontSize: 15)),
                      ]))
                  : _results.isEmpty
                      ? Center(
                          child: Text('No users found',
                              style: TextStyle(
                                  color: AppColors.textSecondary(dark),
                                  fontSize: 15)))
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final user = _results[index];
                            return ListTile(
                              leading: AvatarWidget(user: user, radius: 24),
                              title: Row(children: [
                                Text(user.username,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary(dark))),
                                if (user.isVerified) ...[
                                  const SizedBox(width: 3),
                                  const Icon(Icons.verified,
                                      color: AppColors.verified, size: 14),
                                ],
                              ]),
                              subtitle: Text(user.displayName,
                                  style: TextStyle(
                                      color: AppColors.textSecondary(dark),
                                      fontSize: 13)),
                              onTap: () {
                                final chatId =
                                    _chatService.getChatId(me.uid, user.uid);
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    chatId: chatId,
                                    otherUser: user,
                                    currentUid: me.uid,
                                  ),
                                ));
                              },
                            );
                          }),
        ),
      ]),
    );
  }
}
