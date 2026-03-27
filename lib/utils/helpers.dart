import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

String formatTimeAgo(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final date = timestamp.toDate();
  final diff = DateTime.now().difference(date);

  if (diff.inSeconds < 60) return '${diff.inSeconds}s';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat('MMM d').format(date);
}

String formatMessageTime(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final date = timestamp.toDate();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final msgDay = DateTime(date.year, date.month, date.day);

  if (msgDay == today) return DateFormat('h:mm a').format(date);
  if (msgDay == yesterday) return 'Yesterday';
  return DateFormat('MMM d').format(date);
}

String formatDateHeader(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final day = DateTime(date.year, date.month, date.day);

  if (day == today) return 'Today';
  if (day == yesterday) return 'Yesterday';
  return DateFormat('MMMM d, y').format(date);
}
