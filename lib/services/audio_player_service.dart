import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:audio_session/audio_session.dart';

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  List<SongModel> _songs = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;

  // Sleep timer
  Timer? _sleepTimer;
  Duration? _sleepTimerRemaining;
  Timer? _sleepCountdown;

  List<SongModel> get songs => _songs;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get shuffle => _shuffle;
  LoopMode get loopMode => _loopMode;
  Duration? get sleepTimerRemaining => _sleepTimerRemaining;
  bool get sleepTimerActive => _sleepTimer != null;

  SongModel? get currentSong =>
      _songs.isNotEmpty ? _songs[_currentIndex] : null;

  AudioPlayerService() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });

    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && index != _currentIndex) {
        _currentIndex = index;
        notifyListeners();
      }
    });
  }

  Future<void> loadSongs(List<SongModel> songs) async {
    _songs = songs;
    notifyListeners();

    final playlist = ConcatenatingAudioSource(
      children: songs.map((song) {
        return AudioSource.uri(
          Uri.parse(song.data ?? ''),
          tag: MediaItem(
            id: song.id.toString(),
            title: song.title,
            artist: song.artist,
            album: song.album,
          ),
        );
      }).toList(),
    );

    await _player.setAudioSource(playlist, preload: false);
  }

  Future<void> playSongAt(int index) async {
    if (index < 0 || index >= _songs.length) return;
    _currentIndex = index;
    await _player.seek(Duration.zero, index: index);
    await _player.play();
    notifyListeners();
  }

  Future<void> togglePlay() async {
    _player.playing ? await _player.pause() : await _player.play();
  }

  Future<void> next() async {
    if (_currentIndex < _songs.length - 1) {
      await _player.seekToNext();
    } else {
      await _player.seek(Duration.zero, index: 0);
      await _player.play();
    }
  }

  Future<void> previous() async {
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    await _player.setShuffleModeEnabled(_shuffle);
    notifyListeners();
  }

  Future<void> toggleLoop() async {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.all;
    } else if (_loopMode == LoopMode.all) {
      _loopMode = LoopMode.one;
    } else {
      _loopMode = LoopMode.off;
    }
    await _player.setLoopMode(_loopMode);
    notifyListeners();
  }

  // ─── Sleep Timer ───────────────────────────────────────────
  void setSleepTimer(Duration duration) {
    cancelSleepTimer();

    _sleepTimerRemaining = duration;
    notifyListeners();

    // Countdown every second
    _sleepCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sleepTimerRemaining == null) return;
      _sleepTimerRemaining = _sleepTimerRemaining! - const Duration(seconds: 1);
      if (_sleepTimerRemaining!.inSeconds <= 0) {
        _sleepTimerRemaining = Duration.zero;
        cancelSleepTimer();
        _player.pause();
      }
      notifyListeners();
    });

    _sleepTimer = Timer(duration, () {
      _player.pause();
      cancelSleepTimer();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
    _sleepTimer = null;
    _sleepCountdown = null;
    _sleepTimerRemaining = null;
    notifyListeners();
  }

  String get sleepTimerDisplay {
    if (_sleepTimerRemaining == null) return '';
    final m = _sleepTimerRemaining!.inMinutes;
    final s = _sleepTimerRemaining!.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    cancelSleepTimer();
    _player.dispose();
    super.dispose();
  }
}
