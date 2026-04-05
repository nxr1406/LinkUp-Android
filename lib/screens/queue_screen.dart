import 'package:flutter/material.dart';
import 'now_playing_screen.dart';
import 'album_screen.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  bool stationAutoplay = true;

  final List<Map<String, dynamic>> songs = [
    {
      'title': '4th Dimension',
      'artist': 'Kids See Ghosts',
      'duration': '2:46',
      'artColor': const Color(0xFF7B9EA8),
      'isPlaying': true,
    },
    {
      'title': 'Blue Orangeade',
      'artist': 'TXT',
      'duration': '3:05',
      'artColor': const Color(0xFF4DA6D9),
      'hasPlus': true,
    },
    {
      'title': 'Heavydirtysoul',
      'artist': 'Twenty One Pilots',
      'duration': '3:55',
      'artColor': const Color(0xFF2C2C2C),
    },
    {
      'title': 'One Kiss',
      'artist': 'Calvin Harris & Dua Lipa',
      'duration': '3:34',
      'artColor': const Color(0xFF3B5998),
    },
    {
      'title': 'I Love It',
      'artist': 'Lil pump',
      'duration': '2:08',
      'artColor': const Color(0xFF7B68EE),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with album art banner
            Stack(
              children: [
                // Album art banner
                Container(
                  height: 120,
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
                  child: Stack(
                    children: [
                      // Decorative circles for album art feel
                      Positioned(
                        top: -20,
                        left: 30,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 50,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Top bar overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        _buildIconButton(Icons.arrow_back_ios_new, Colors.white),
                        const Expanded(
                          child: Text(
                            'MY MUSIC LIST',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        _buildIconButton(Icons.search, Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Up Next header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Up next',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: const Color(0xFF1A1A1A),
                        size: 22,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.repeat, color: Colors.grey.shade400, size: 20),
                      const SizedBox(width: 14),
                      Icon(Icons.shuffle, color: const Color(0xFFFF6B35), size: 20),
                    ],
                  ),
                ],
              ),
            ),

            // Song List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return _buildSongTile(song, index);
                },
              ),
            ),

            // Station Autoplay footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sensors,
                        color: const Color(0xFF1A1A1A),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Station Autoplay',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const Spacer(),
                      _buildToggle(stationAutoplay, (val) {
                        setState(() => stationAutoplay = val);
                      }),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 26),
                      child: Text(
                        "New music based on what's playing",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongTile(Map<String, dynamic> song, int index) {
    final bool isPlaying = song['isPlaying'] == true;
    final bool hasPlus = song['hasPlus'] == true;
    final Color artColor = song['artColor'] as Color;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // Album art
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: artColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: hasPlus
                  ? const Center(
                      child: Icon(Icons.add, color: Colors.white, size: 24),
                    )
                  : isPlaying
                      ? _buildMiniWaveform()
                      : null,
            ),
            const SizedBox(width: 14),
            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song['title'] as String,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isPlaying
                          ? const Color(0xFFFF6B35)
                          : const Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song['artist'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
            // Duration
            Text(
              song['duration'] as String,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(width: 12),
            // Action icon
            isPlaying
                ? Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.equalizer,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
                : Icon(
                    Icons.drag_handle,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
            if (isPlaying) ...[
              const SizedBox(width: 8),
              Icon(Icons.more_vert, color: Colors.grey.shade400, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [2.0, 3.5, 2.5, 4.0, 2.0].map((h) {
        return Container(
          width: 3,
          height: h * 3,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIconButton(IconData icon, Color color) {
    return GestureDetector(
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildToggle(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: value ? const Color(0xFFFF6B35) : Colors.grey.shade300,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
