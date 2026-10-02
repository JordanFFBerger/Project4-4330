import 'package:flutter/services.dart';

/// A steady focus speaks once; looking away rearms it without rapid chatter.
class FocusCryGate {
  int? _candidate;
  Duration _since = Duration.zero;
  Duration? _awaySince;
  int? _spoken;
  final Map<int, Duration> _lastCry = {};
  int? update(int? id, Duration now) {
    if (id == null) {
      _awaySince ??= now;
      _candidate = null;
      if (now - _awaySince! >= const Duration(milliseconds: 500)) {
        _spoken = null;
      }
      return null;
    }
    _awaySince = null;
    if (id != _candidate) {
      _candidate = id;
      _since = now;
    }
    if (id == _spoken || now - _since < const Duration(milliseconds: 800)) {
      return null;
    }
    final last = _lastCry[id];
    if (last != null && now - last < const Duration(seconds: 8)) return null;
    _spoken = id;
    _lastCry[id] = now;
    return id;
  }

  void reset() {
    _candidate = null;
    _spoken = null;
    _awaySince = null;
  }
}

class PokemonAudio {
  static const channel = MethodChannel('pft/media');
  Future<void> play(int id) =>
      channel.invokeMethod<void>('playCry', {'id': id});
  Future<void> stop() async {
    try {
      await channel.invokeMethod<void>('stopCry');
    } on PlatformException {
      /* Activity may be closing. */
    } on MissingPluginException {
      /* Unsupported platform. */
    }
  }
}
