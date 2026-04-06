class SongModel {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String duration;
  final int durationMs;
  final String? data; // file path
  final String? albumArtUri;

  const SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.durationMs,
    this.data,
    this.albumArtUri,
  });

  String get formattedDuration {
    final mins = durationMs ~/ 60000;
    final secs = (durationMs % 60000) ~/ 1000;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
