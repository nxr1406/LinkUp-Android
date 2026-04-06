import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
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
  SongModel? get currentSong => _songs.isNotEmpty ? _songs[_currentIndex] : null;

  AudioPlayerService() {
    _init();
  }

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}

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
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        next();
      }
    });
  }

  Future<void> loadSongs(List<SongModel> songs) async {
    _songs = songs;
    _currentIndex = 0;
    notifyListeners();

    try {
      final sources = songs
          .where((s) => (s.data ?? '').isNotEmpty)
          .map((s) {
            final path = s.data!;
            final uri = path.startsWith('content://') || path.startsWith('file://')
                ? Uri.parse(path)
                : Uri.file(path);
            return AudioSource.uri(uri);
          })
          .toList();

      if (sources.isEmpty) return;
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        preload: false,
      );
    } catch (e) {
      debugPrint('loadSongs error: $e');
    }
  }

  Future<void> playSongAt(int index) async {
    if (index < 0 || index >= _songs.length) return;
    _currentIndex = index;
    notifyListeners();

    try {
      await _player.seek(Duration.zero, index: index);
      await _player.play();
    } catch (e) {
      debugPrint('playSongAt seek error: $e — trying direct load');
      try {
        final path = _songs[index].data ?? '';
        if (path.isEmpty) return;
        final uri = path.startsWith('content://') || path.startsWith('file://')
            ? Uri.parse(path)
            : Uri.file(path);
        await _player.setAudioSource(AudioSource.uri(uri));
        await _player.play();
      } catch (e2) {
        debugPrint('playSongAt direct load error: $e2');
      }
    }
  }

  Future<void> togglePlay() async {
    try {
      _player.playing ? await _player.pause() : await _player.play();
    } catch (_) {}
  }

  Future<void> next() async {
    final nextIndex = _currentIndex < _songs.length - 1 ? _currentIndex + 1 : 0;
    await playSongAt(nextIndex);
  }

  Future<void> previous() async {
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      final prevIndex = _currentIndex > 0 ? _currentIndex - 1 : 0;
      await playSongAt(prevIndex);
    }
  }

  Future<void> seekTo(Duration position) async {
    try { await _player.seek(position); } catch (_) {}
  }

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    try { await _player.setShuffleModeEnabled(_shuffle); } catch (_) {}
    notifyListeners();
  }

  Future<void> toggleLoop() async {
    _loopMode = _loopMode == LoopMode.off
        ? LoopMode.all
        : _loopMode == LoopMode.all
            ? LoopMode.one
            : LoopMode.off;
    try { await _player.setLoopMode(_loopMode); } catch (_) {}
    notifyListeners();
  }

  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepTimerRemaining = duration;
    notifyListeners();

    _sleepCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sleepTimerRemaining == null) return;
      _sleepTimerRemaining = _sleepTimerRemaining! - const Duration(seconds: 1);
      if (_sleepTimerRemaining!.inSeconds <= 0) {
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
