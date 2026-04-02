import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class SuspendedScreen extends StatefulWidget {
  const SuspendedScreen({super.key});

  @override
  State<SuspendedScreen> createState() => _SuspendedScreenState();
}

class _SuspendedScreenState extends State<SuspendedScreen> {
  final _messageCtrl = TextEditingController();
  bool _submitting = false;

  Future<void> _submitAppeal() async {
    final auth = Provider.of<LinkUpAuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    final userData = auth.userData;
    if (uid == null || _messageCtrl.text.trim().isEmpty) return;

    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('appeals').add({
        'userId': uid,
        'username': userData?['username'],
        'fullName': userData?['fullName'],
        'avatarUrl': userData?['avatarUrl'],
        'message': _messageCtrl.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'appealStatus': 'pending'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appeal submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit appeal'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<LinkUpAuthProvider>();
    final status = auth.userData?['appealStatus'] ?? 'none';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Account Suspended',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF262626),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your account has been suspended by an administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF8E8E8E)),
              ),
              const SizedBox(height: 32),

              if (status == 'none') ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Submit an Appeal (Max 300 characters)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageCtrl,
                  maxLength: 300,
                  maxLines: 5,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText:
                        'Explain why your account should be unsuspended...',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: Color(0xFF8E8E8E)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFDBDBDB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFDBDBDB)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _messageCtrl.text.trim().isNotEmpty &&
                            !_submitting
                        ? _submitAppeal
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0095F6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Submit Appeal',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],

              if (status == 'pending')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.yellow.shade200),
                  ),
                  child: const Text(
                    'Your appeal is currently under review by our team.',
                    style: TextStyle(
                        color: Color(0xFF92400E), fontSize: 14),
                  ),
                ),

              if (status == 'rejected')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Text(
                    'Your appeal was reviewed and rejected. This decision is final.',
                    style: TextStyle(
                        color: Color(0xFF991B1B), fontSize: 14),
                  ),
                ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await auth.signOut();
                    if (mounted) context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF262626),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Log Out',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }
}
