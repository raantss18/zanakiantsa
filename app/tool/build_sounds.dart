// Écrit les bruitages synthétisés (lib/audio/sfx.dart) dans assets/audio/sfx/. À relancer après toute
// modification de sfx.dart : `dart run tool/build_sounds.dart`.
import 'dart:io';

import 'package:zanakiantsa/audio/sfx.dart';

void main() {
  final dir = Directory('assets/audio/sfx')..createSync(recursive: true);
  for (final name in sfxNames) {
    File('${dir.path}/$name.wav').writeAsBytesSync(wav(samples(name)));
    stdout.writeln('écrit ${dir.path}/$name.wav');
  }
}
