import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:math' as math;
import '../services/audio_player_service.dart';

class NowPlayingScreen extends StatefulWidget {
  final AudioPlayerService playerService;
  final OnAudioQuery audioQuery;

  const NowPlayingScreen({
    super.key,
    required this.playerService,
    required this.audioQuery,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (widget.playerService.isPlaying) _rotateController.repeat();
    widget.playerService.addListener(_onPlayerUpdate);
  }

  void _onPlayerUpdate() {
    if (widget.playerService.isPlaying) {
      if (!_rotateController.isAnimating) _rotateController.repeat();
    } else {
      _rotateController.stop();
    }
  }

  @override
  void dispose() {
    widget.playerService.removeListener(_onPlayerUpdate);
    _rotateController.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _showSleepTimerSheet() {
    final options = [
      {'label': '5 minutes', 'duration': const Duration(minutes: 5)},
      {'label': '10 minutes', 'duration': const Duration(minutes: 10)},
      {'label': '15 minutes', 'duration': const Duration(minutes: 15)},
      {'label': '30 minutes', 'duration': const Duration(minutes: 30)},
      {'label': '45 minutes', 'duration': const Duration(minutes: 45)},
      {'label': '1 hour', 'duration': const Duration(hours: 1)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ListenableBuilder(
        listenable: widget.playerService,
        builder: (context, __) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.bedtime_outlined, color: Color(0xFF1A1A1A), size: 22),
                  const SizedBox(width: 10),
                  const Text('Sleep Timer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                  const Spacer(),
                  if (widget.playerService.sleepTimerActive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.playerService.sleepTimerDisplay,
                        style: const TextStyle(
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        widget.playerService.cancelSleepTimer();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Cancel',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              ...options.map((opt) {
                final dur = opt['duration'] as Duration;
                final label = opt['label'] as String;
                return GestureDetector(
                  onTap: () {
                    widget.playerService.setSleepTimer(dur);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sleep timer set for $label'),
                        backgroundColor: const Color(0xFF1A1A1A),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(label,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.playerService,
          builder: (context, _) {
            final song = widget.playerService.currentSong;
            if (song == null) return const SizedBox.shrink();

            final position = widget.playerService.position;
            final duration = widget.playerService.duration;
            final progress = duration.inMilliseconds > 0
                ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                : 0.0;

            return Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.keyboard_arrow_down, size: 28, color: Color(0xFF1A1A1A)),
                      ),
                      const Expanded(
                        child: Column(children: [
                          Text('NOW PLAYING',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                letterSpacing: 1.5, color: Color(0xFF1A1A1A))),
                          SizedBox(height: 2),
                          Text('My Music',
                            style: TextStyle(fontSize: 12, color: Color(0xFFFF6B35), fontWeight: FontWeight.w500)),
                        ]),
                      ),
                      // Sleep timer icon with countdown badge
                      GestureDetector(
                        onTap: _showSleepTimerSheet,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              Icons.bedtime_outlined,
                              size: 22,
                              color: widget.playerService.sleepTimerActive
                                  ? const Color(0xFFFF6B35)
                                  : const Color(0xFF1A1A1A),
                            ),
                            if (widget.playerService.sleepTimerActive)
                              Positioned(
                                top: -4, right: -4,
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF6B35),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Sleep timer countdown bar
                if (widget.playerService.sleepTimerActive)
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bedtime, size: 16, color: Color(0xFFFF6B35)),
                        const SizedBox(width: 8),
                        const Text('Stops in ', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                        Text(
                          widget.playerService.sleepTimerDisplay,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFF6B35)),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: widget.playerService.cancelSleepTimer,
                          child: const Text('Cancel',
                            style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),

                // Album Art — rotating disc
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: AnimatedBuilder(
                    animation: _rotateController,
                    builder: (_, child) => Transform.rotate(
                      angle: _rotateController.value * 2 * math.pi,
                      child: child,
                    ),
                    child: Container(
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: QueryArtworkWidget(
                          id: song.id,
                          type: ArtworkType.AUDIO,
                          artworkWidth: 250,
                          artworkHeight: 250,
                          artworkBorder: BorderRadius.circular(125),
                          artworkFit: BoxFit.cover,
                          nullArtworkWidget: Container(
                            width: 250, height: 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.primaries[song.id % Colors.primaries.length],
                                  Colors.primaries[song.id % Colors.primaries.length].withOpacity(0.5),
                                ],
                              ),
                            ),
                            child: const Icon(Icons.music_note, color: Colors.white, size: 70),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Song info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      Text(song.artist ?? 'Unknown Artist',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text(song.title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Progress slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: const Color(0xFFFF6B35),
                          inactiveTrackColor: const Color(0xFFE0E0E0),
                          thumbColor: const Color(0xFFFF6B35),
                          overlayColor: const Color(0xFFFF6B35).withOpacity(0.2),
                        ),
                        child: Slider(
                          value: progress,
                          onChanged: (val) {
                            widget.playerService.seekTo(Duration(
                              milliseconds: (val * duration.inMilliseconds).round(),
                            ));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(position),
                                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                            Text(_fmt(duration),
                                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Playback controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildRoundBtn(Icons.skip_previous, widget.playerService.previous),
                      _buildPlayBtn(),
                      _buildRoundBtn(Icons.skip_next, widget.playerService.next),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Bottom actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Repeat
                      GestureDetector(
                        onTap: widget.playerService.toggleLoop,
                        child: Icon(
                          widget.playerService.loopMode == LoopMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                          size: 22,
                          color: widget.playerService.loopMode != LoopMode.off
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFF9E9E9E),
                        ),
                      ),
                      // Queue position
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.playerService.currentIndex + 1} / ${widget.playerService.songs.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
                        ),
                      ),
                      // Sleep timer shortcut
                      GestureDetector(
                        onTap: _showSleepTimerSheet,
                        child: Icon(
                          Icons.bedtime_outlined,
                          size: 22,
                          color: widget.playerService.sleepTimerActive
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFF9E9E9E),
                        ),
                      ),
                      // Shuffle
                      GestureDetector(
                        onTap: widget.playerService.toggleShuffle,
                        child: Icon(
                          Icons.shuffle,
                          size: 22,
                          color: widget.playerService.shuffle
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayBtn() {
    return GestureDetector(
      onTap: widget.playerService.togglePlay,
      child: Container(
        width: 68, height: 68,
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
          widget.playerService.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white, size: 32,
        ),
      ),
    );
  }

  Widget _buildRoundBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
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
        child: Icon(icon, color: const Color(0xFF1A1A1A), size: 24),
      ),
    );
  }
}
