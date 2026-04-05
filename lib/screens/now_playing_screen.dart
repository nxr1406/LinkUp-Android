import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'album_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  bool isPlaying = true;
  double sliderValue = 0.39 / 2.46;
  late AnimationController _waveController;
  late AnimationController _albumController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _albumController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  String _formatTime(double progress) {
    final totalSeconds = (2 * 60 + 46);
    final currentSeconds = (totalSeconds * progress).round();
    final mins = currentSeconds ~/ 60;
    final secs = currentSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
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
                    child: Column(
                      children: [
                        Text(
                          'NOW PLAYING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'My music list',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

            // Album Art - Large with rotation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AlbumScreen()),
                  );
                },
                child: AnimatedBuilder(
                  animation: _albumController,
                  builder: (_, child) {
                    return Container(
                      height: 280,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7B9EA8).withOpacity(0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Gradient background mimicking album art
                            Container(
                              decoration: const BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(-0.3, -0.3),
                                  radius: 1.2,
                                  colors: [
                                    Color(0xFF9BC8D8),
                                    Color(0xFF6BA3BE),
                                    Color(0xFF4A7A94),
                                    Color(0xFFD4884A),
                                    Color(0xFFE8A060),
                                  ],
                                  stops: [0.0, 0.3, 0.5, 0.8, 1.0],
                                ),
                              ),
                            ),
                            // Ghost/character overlay
                            Positioned(
                              bottom: 40,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 80,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: const Icon(
                                    Icons.face,
                                    size: 50,
                                    color: Color(0xFF4A7A94),
                                  ),
                                ),
                              ),
                            ),
                            // Waveform at bottom of album art
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: AnimatedBuilder(
                                animation: _waveController,
                                builder: (_, __) => _buildWaveform(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Song title & artist
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Text(
                    'Kids See Ghosts',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9E9E9E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '4th Dimension (feat. Loui',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Progress Slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      activeTrackColor: const Color(0xFFFF6B35),
                      inactiveTrackColor: const Color(0xFFE0E0E0),
                      thumbColor: const Color(0xFFFF6B35),
                      overlayColor: const Color(0xFFFF6B35).withOpacity(0.2),
                    ),
                    child: Slider(
                      value: sliderValue,
                      onChanged: (val) => setState(() => sliderValue = val),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(sliderValue),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                        const Text(
                          '2:46',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Playback Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.skip_previous,
                        color: Color(0xFF1A1A1A),
                        size: 24,
                      ),
                    ),
                  ),

                  // Play/Pause - large orange button
                  GestureDetector(
                    onTap: () {
                      setState(() => isPlaying = !isPlaying);
                      if (isPlaying) {
                        _albumController.repeat();
                      } else {
                        _albumController.stop();
                      }
                    },
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF8A50), Color(0xFFFF5722)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  // Next
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.skip_next,
                        color: Color(0xFF1A1A1A),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bottom action bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBottomAction(Icons.repeat, false),
                  _buildBottomAction(Icons.favorite_border, false),
                  _buildBottomAction(Icons.keyboard_arrow_up, false),
                  _buildBottomAction(Icons.chat_bubble_outline, false),
                  _buildBottomAction(Icons.shuffle, true),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    final random = math.Random(42);
    final bars = List.generate(40, (i) {
      final progress = sliderValue * 40;
      final isPast = i < progress;
      final height = 8.0 + random.nextDouble() * 28;
      return _WaveBar(
        height: height,
        isPast: isPast,
        animation: _waveController,
        index: i,
      );
    });

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars,
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, bool isActive) {
    return GestureDetector(
      onTap: () {},
      child: Icon(
        icon,
        size: 22,
        color: isActive ? const Color(0xFFFF6B35) : const Color(0xFF9E9E9E),
      ),
    );
  }
}

class _WaveBar extends StatelessWidget {
  final double height;
  final bool isPast;
  final AnimationController animation;
  final int index;

  const _WaveBar({
    required this.height,
    required this.isPast,
    required this.animation,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final animatedHeight = isPast
            ? height * (0.8 + 0.2 * math.sin(animation.value * math.pi + index * 0.3))
            : height;
        return Container(
          width: 3,
          height: animatedHeight,
          decoration: BoxDecoration(
            color: isPast
                ? const Color(0xFFFF6B35).withOpacity(0.8)
                : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}
