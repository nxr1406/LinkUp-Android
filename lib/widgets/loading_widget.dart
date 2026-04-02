import 'package:flutter/material.dart';

class LoadingSpinner extends StatelessWidget {
  final double size;
  const LoadingSpinner({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(
          color: Color(0xFF0095F6),
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class FullScreenLoader extends StatelessWidget {
  const FullScreenLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Color(0xFFDBDBDB),
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

void showToast(BuildContext context, String msg,
    {bool isSuccess = false, bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess
          ? Colors.green
          : isError
              ? Colors.red
              : const Color(0xFF262626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );
}
