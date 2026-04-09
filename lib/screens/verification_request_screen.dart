import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../utils/app_colors.dart';

class VerificationRequestScreen extends StatefulWidget {
  final UserModel me;
  const VerificationRequestScreen({super.key, required this.me});

  @override
  State<VerificationRequestScreen> createState() =>
      _VerificationRequestScreenState();
}

class _VerificationRequestScreenState
    extends State<VerificationRequestScreen> {
  final _reasonCtrl = TextEditingController();
  bool _loading = false;
  final _userService = UserService();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reasonCtrl.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please provide a detailed reason (min 20 chars)')));
      return;
    }
    setState(() => _loading = true);
    try {
      await _userService.requestVerification(
        userId: widget.me.uid,
        username: widget.me.username,
        displayName: widget.me.displayName,
        reason: _reasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Verification request submitted!'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Already verified → "You are verified" screen ───────────
    if (widget.me.isVerified) {
      return Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.black, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Request Verification',
            style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(Icons.check,
                  color: AppColors.primary.withOpacity(0.6), size: 22),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pink seal badge
              SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: _SealBadgePainter(color: AppColors.primary),
                  child: const Center(
                    child: Icon(Icons.check, color: Colors.white, size: 36),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'You are verified',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your account has a verified badge.',
                style: TextStyle(fontSize: 14, color: AppColors.textMedium),
              ),
            ],
          ),
        ),
      );
    }

    // ── Not yet verified → request form ────────────────────────
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Request Verification',
          style: TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified, color: AppColors.primary, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Get Verified',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tell us why you should be verified. Verification is given to notable public figures, creators, and organizations.',
              style: TextStyle(color: AppColors.textMedium, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _reasonCtrl,
                maxLines: 6,
                style: const TextStyle(color: AppColors.textDark),
                decoration: const InputDecoration(
                  hintText:
                      'Why do you deserve verification? (min 20 characters)',
                  hintStyle: TextStyle(color: AppColors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : const Text(
                        'Submit Request',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 8-point seal badge painter ─────────────────────────────────────────────────
class _SealBadgePainter extends CustomPainter {
  final Color color;
  const _SealBadgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cx = size.width / 2;
    final cy = size.height / 2;
    const numPoints = 8;
    final outerR = size.width / 2;
    final innerR = outerR * 0.80;

    final path = Path();
    for (int i = 0; i < numPoints * 2; i++) {
      final angle = (i * math.pi / numPoints) - math.pi / 2;
      final r = i.isEven ? outerR : innerR;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SealBadgePainter old) => old.color != color;
}
