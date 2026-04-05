import 'package:flutter/material.dart';

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  final List<Map<String, dynamic>> tracks = const [
    {
      'number': '01',
      'title': 'Feel the Love (feat. Pusha T)',
      'duration': '2:45',
      'artColor': Color(0xFF7B9EA8),
    },
    {
      'number': '02',
      'title': 'Fire',
      'duration': '2:20',
      'artColor': Color(0xFF5B8A9E),
    },
    {
      'number': '03',
      'title': '4th Dimension (feat. Louis ...',
      'duration': '2:33',
      'artColor': Color(0xFF6B9AAE),
      'isPlaying': true,
    },
    {
      'number': '04',
      'title': 'Freeee (Ghost Town, Pt. 2) ...',
      'duration': '3:26',
      'artColor': Color(0xFF8BA8B5),
    },
    {
      'number': '05',
      'title': 'Reborn',
      'duration': '5:24',
      'artColor': Color(0xFF7090A0),
    },
    {
      'number': '06',
      'title': 'Kids See Ghosts (feat. Yas...',
      'duration': '4:05',
      'artColor': Color(0xFF6B9AAE),
    },
    {
      'number': '07',
      'title': 'Cudi Montage',
      'duration': '4:43',
      'artColor': Color(0xFF5A8A9E),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'ALBUM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.more_vert,
                    size: 22,
                    color: Color(0xFF1A1A1A),
                  ),
                ],
              ),
            ),

            // Album Header Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Album art
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7B9EA8).withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      gradient: const RadialGradient(
                        center: Alignment(-0.3, -0.3),
                        radius: 1.1,
                        colors: [
                          Color(0xFF9BC8D8),
                          Color(0xFF6BA3BE),
                          Color(0xFFD4884A),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.face,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Album details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kids See\nGhosts',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Kids See Ghosts',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '2018 • Hip-Hop, Rap',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Track count + Play All button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.sensors, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    '7 Tracks • 23 Minutes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // Play All button
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
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
                      child: const Text(
                        'Play All',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.grey.shade200, height: 20),
            ),

            // Track list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  return _buildTrackTile(tracks[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackTile(Map<String, dynamic> track) {
    final bool isPlaying = track['isPlaying'] == true;
    final Color artColor = track['artColor'] as Color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          // Track number or playing indicator
          SizedBox(
            width: 28,
            child: isPlaying
                ? const Icon(
                    Icons.equalizer,
                    color: Color(0xFFFF6B35),
                    size: 18,
                  )
                : Text(
                    track['number'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // Album art thumbnail
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: artColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: artColor.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          artColor.withOpacity(0.6),
                          artColor,
                        ],
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(Icons.music_note, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Track title + duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track['title'] as String,
                  style: TextStyle(
                    fontSize: 14,
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
                  track['duration'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          // More options
          Icon(
            Icons.more_vert,
            color: Colors.grey.shade400,
            size: 20,
          ),
        ],
      ),
    );
  }
}
