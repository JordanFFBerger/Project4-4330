import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project4/ar/focus_cry.dart';

void main() {
  test('focus needs dwell, does not repeat while held, and rearms after looking away', () {
    final gate = FocusCryGate();
    Duration t(int ms) => Duration(milliseconds: ms);
    expect(gate.update(25, t(0)), isNull);
    expect(gate.update(25, t(700)), isNull);
    expect(gate.update(25, t(800)), 25);
    expect(gate.update(25, t(10000)), isNull);
    gate.update(null, t(10100));
    gate.update(null, t(10700));
    expect(gate.update(25, t(11000)), isNull);
    expect(gate.update(25, t(11800)), 25);
  });
  test('jitter and switching targets respect each Pokemon cooldown', () {
    final gate = FocusCryGate();
    Duration t(int ms) => Duration(milliseconds: ms);
    gate.update(6, t(0));
    gate.update(null, t(600));
    gate.update(6, t(700));
    expect(gate.update(6, t(900)), isNull);
    expect(gate.update(6, t(1500)), 6);
    gate.update(25, t(1600));
    expect(gate.update(25, t(2400)), 25);
    gate.update(6, t(2500));
    expect(gate.update(6, t(3300)), isNull);
    expect(gate.update(6, t(9500)), 6);
    gate.reset();
    expect(gate.update(6, t(10000)), isNull);
  });
  test(
    'every bundled Pokemon has a game cry with the correct audio container',
    () {
      final models =
          jsonDecode(
                File('assets/pokemon/manifest.json').readAsStringSync(),
              )['models']
              as List;
      for (final model in models) {
        final extension = model['id'] == 25 ? 'mp3' : 'ogg';
        final bytes = File('assets/audio/${model['id']}.$extension')
            .readAsBytesSync();
        if (model['id'] == 25) {
          expect(bytes[0], 0xff);
          expect(bytes[1] & 0xe0, 0xe0); // MPEG audio frame sync.
        } else {
          expect(ascii.decode(bytes.take(4).toList()), 'OggS');
        }
        expect(bytes.length, greaterThan(1000));
      }
    },
  );
}
