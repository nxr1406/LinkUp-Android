import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/audio_player_service.dart';
import 'now_playing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayerService _playerService = AudioPlayerService();
  List<SongModel> _songs = [];
  bool _loading = true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
  }

  Future<void> _requestPermissionAndLoad() async {
    // Android 13+ (API 33+) uses READ_MEDIA_AUDIO, older uses READ_EXTERNAL_STORAGE
    // Permission.audio.isSupported doesn't exist — request directly and fallback
    PermissionStatus status = await Permission.audio.request();
    if (status == PermissionStatus.denied ||
        status == PermissionStatus.permanentlyDenied) {
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      await _loadSongs();
    } else {
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
    }
  }

  Future<void> _loadSongs() async {
    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    // Filter: only real audio files, min 30 seconds
    final filtered = songs
        .where((s) =>
            s.duration != null &&
            s.duration! > 30000 &&
            s.data != null &&
            (s.data!.endsWith('.mp3') ||
                s.data!.endsWith('.m4a') ||
                s.data!.endsWith('.flac') ||
                s.data!.endsWith('.wav') ||
                s.data!.endsWith('.aac') ||
                s.data!.endsWith('.ogg')))
        .toList();

    await _playerService.loadSongs(filtered);

    setState(() {
      _songs = filtered;
      _loading = false;
    });
  }

  String _formatDuration(int? ms) {
    if (ms == null) return '0:00';
    final mins = ms ~/ 60000;
    final secs = (ms % 60000) ~/ 1000;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Stack(
              children: [
                Container(
                  height: 110,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF6BA3BE),
                        Color(0xFF8BBDD4),
                        Color(0xFFB5D4E2),
                        Color(0xFFD4884A),
                      ],
                    ),
                  ),
                  child: Stack(children: [
                    Positioned(
                      top: -20, left: 30,
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ]),
                ),
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'MY MUSIC',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _loadSongs,
                          child: const Icon(Icons.refresh, color: Colors.white, size: 22),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Song count
            if (!_loading && !_permissionDenied)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '${_songs.length} Songs',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        if (_songs.isNotEmpty) {
                          _playerService.toggleShuffle();
                          _playerService.playSongAt(
                            (DateTime.now().millisecond % _songs.length),
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NowPlayingScreen(
                                playerService: _playerService,
                                audioQuery: _audioQuery,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8A50), Color(0xFFFF5722)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shuffle, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text('Shuffle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                    )
                  : _permissionDenied
                      ? _buildPermissionDenied()
                      : _songs.isEmpty
                          ? _buildEmpty()
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: _songs.length,
                              itemBuilder: (context, index) {
                                final song = _songs[index];
                                return _buildSongTile(song, index);
                              },
                            ),
            ),
          ],
        ),
      ),

      // Mini player at bottom
      bottomNavigationBar: ListenableBuilder(
        listenable: _playerService,
        builder: (context, _) {
          if (_playerService.currentSong == null) return const SizedBox.shrink();
          return _buildMiniPlayer();
        },
      ),
    );
  }

  Widget _buildSongTile(SongModel song, int index) {
    return ListenableBuilder(
      listenable: _playerService,
      builder: (context, _) {
        final isPlaying = _playerService.currentIndex == index && _playerService.isPlaying;
        final isCurrent = _playerService.currentIndex == index;

        return GestureDetector(
          onTap: () async {
            await _playerService.playSongAt(index);
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NowPlayingScreen(
                    playerService: _playerService,
                    audioQuery: _audioQuery,
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            color: Colors.transparent,
            child: Row(
              children: [
                // Album art
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    artworkWidth: 52,
                    artworkHeight: 52,
                    artworkBorder: BorderRadius.circular(8),
                    nullArtworkWidget: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.primaries[index % Colors.primaries.length].withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.white, size: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isCurrent ? const Color(0xFFFF6B35) : const Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song.artist ?? 'Unknown Artist',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDuration(song.duration),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(width: 10),
                if (isPlaying)
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.equalizer, color: Colors.white, size: 16),
                  )
                else
                  Icon(Icons.more_vert, color: Colors.grey.shade400, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniPlayer() {
    final song = _playerService.currentSong!;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NowPlayingScreen(
              playerService: _playerService,
              audioQuery: _audioQuery,
            ),
          ),
        );
      },
      child: Container(
        height: 68,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                artworkWidth: 44,
                artworkHeight: 44,
                artworkBorder: BorderRadius.circular(8),
                nullArtworkWidget: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist ?? 'Unknown',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _playerService.previous,
              icon: const Icon(Icons.skip_previous, color: Colors.white, size: 24),
            ),
            GestureDetector(
              onTap: _playerService.togglePlay,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B35),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _playerService.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            IconButton(
              onPressed: _playerService.next,
              icon: const Icon(Icons.skip_next, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Storage Permission Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Please allow storage access to load your music.',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No songs found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('Add audio files to your device storage.',
              style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
