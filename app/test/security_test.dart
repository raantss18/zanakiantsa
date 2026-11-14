import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/parent/gate.dart';
import 'package:zanakiantsa/update/updater.dart';
import 'package:zanakiantsa/videos/catalog.dart';

// Durcissements de l'audit de sécurité du 2026-11-14 (ADR 0072).
void main() {
  test('porte parentale : trois essais, puis une attente qui double, remise à zéro par la bonne réponse', () {
    final lock = GateLock();
    final t0 = DateTime(2026, 11, 14, 10);
    lock.answered(false, t0);
    lock.answered(false, t0);
    expect(lock.waitSeconds(t0), 0);
    lock.answered(false, t0);
    expect(lock.waitSeconds(t0), 30);
    expect(lock.waitSeconds(t0.add(const Duration(seconds: 29))), 1);
    expect(lock.waitSeconds(t0.add(const Duration(seconds: 30))), 0);
    lock.answered(false, t0);
    expect(lock.waitSeconds(t0), 60);
    for (var i = 0; i < 10; i++) {
      lock.answered(false, t0);
    }
    expect(lock.waitSeconds(t0), 300);
    lock.answered(true, t0);
    expect((lock.failures, lock.waitSeconds(t0)), (0, 0));
  });

  test('mise à jour : seulement en HTTPS depuis github.com', () {
    expect(trustedDownload('https://github.com/raantss18/zanakiantsa/releases/download/app-v1.1.0/a.apk'), isTrue);
    expect(trustedDownload('http://github.com/raantss18/zanakiantsa/a.apk'), isFalse);
    expect(trustedDownload('https://github.com.exemple.net/a.apk'), isFalse);
    expect(trustedDownload('https://exemple.net/github.com/a.apk'), isFalse);
    expect(trustedDownload('file:///sdcard/a.apk'), isFalse);
  });

  test('vidéos : un identifiant qui ne ressemble pas à un identifiant YouTube est ignoré', () {
    expect(Video.validId('dQw4w9WgXcQ'), isTrue);
    expect(Video.validId('abc'), isFalse);
    expect(Video.validId('abc?autoplay=1'), isFalse);
    expect(Video.validId('../../../etc'), isFalse);
    expect(Video.validId(42), isFalse);
  });
}
