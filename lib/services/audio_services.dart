import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  AudioService._internal() {
    _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        _isPlaying = false;
        _currentlyPlayingId = null;
      } else if (state == PlayerState.playing) {
        _isPlaying = true;
      } else if (state == PlayerState.paused ||
          state == PlayerState.stopped) {
        _isPlaying = false;
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  String? _currentlyPlayingId;
  bool _isPlaying = false;

  String? get currentlyPlayingId => _currentlyPlayingId;
  bool get isPlaying => _isPlaying;

  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;
  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;

  Future<void> togglePlay({
    required String ringtoneId,
    required String previewUrl,
  }) async {
    if (_currentlyPlayingId == ringtoneId && _isPlaying) {
      await pause();
      return;
    }
    if (_isPlaying) await stop();
    _currentlyPlayingId = ringtoneId;
    await _player.play(UrlSource(previewUrl));
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> pause() async => await _player.pause();

  Future<void> stop() async {
    await _player.stop();
    _currentlyPlayingId = null;
  }

  Future<void> disposePlayer() async => await _player.dispose();
}