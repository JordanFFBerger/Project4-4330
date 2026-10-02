import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class MusicController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  bool _muted = false;
  bool _started = false;

  bool get muted => _muted;

  Future<void> start() async {
    if (_started) return;

    _started = true;

    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(0.30);

    await _player.play(
      AssetSource('audio/background_music.mp3'),
    );
  }

  Future<void> toggleMute() async {
    _muted = !_muted;

    await _player.setVolume(
      _muted ? 0.0 : 0.30,
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}