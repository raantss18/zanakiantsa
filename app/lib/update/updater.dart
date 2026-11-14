/// Mise à jour faite par l'app elle-même (ADR 0011), sur le modèle de COMIMa :
///   1. `release.json` est signé (Ed25519, `release.json.sig` en base64) : la clé publique est dans l'app ;
///   2. l'APK téléchargé doit avoir l'empreinte SHA-256 annoncée par ce fichier signé ;
///   3. l'installateur Android exige la même clé de signature que l'app installée.
/// Le format de `release.json` ne change jamais : `{"format":1,"latest":{"build","version","notes","apk":{"url",
/// "sha256","bytes"}}}`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Adresse de publication ; remplaçable pour les essais (`--dart-define=UPDATE_URL=http://127.0.0.1:8000`).
const updateBase = String.fromEnvironment(
  'UPDATE_URL',
  defaultValue: 'https://github.com/raantss18/zanakiantsa/releases/latest/download',
);

/// Clé publique Ed25519 (32 octets, base64) ; la clé privée est dans `release-keys/`, hors de Git.
const publicKeyB64 = '4hwX0mgjpWFoB3CfAkpdCKGjdhDKgOavolordghx6w0=';

class Release {
  Release(Map<String, dynamic> j)
      : build = j['build'] as int,
        version = j['version'] as String,
        notes = j['notes'] as String,
        url = (j['apk'] as Map)['url'] as String,
        sha256 = (j['apk'] as Map)['sha256'] as String,
        bytes = (j['apk'] as Map)['bytes'] as int;
  final int build, bytes;
  final String version, notes, url, sha256;
}

/// Vérifie la signature d'un `release.json` ; renvoie la version annoncée, ou null si la signature est fausse.
Future<Release?> parseSigned(List<int> body, String sigB64, {String publicKey = publicKeyB64}) async {
  try {
    final ok = await Ed25519().verify(
      body,
      signature: Signature(base64.decode(sigB64.trim()),
          publicKey: SimplePublicKey(base64.decode(publicKey), type: KeyPairType.ed25519)),
    );
    if (!ok) return null;
    final j = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
    if (j['format'] != 1) return null;
    return Release(Map<String, dynamic>.from(j['latest'] as Map));
  } catch (_) {
    return null;
  }
}

/// L'APK ne se télécharge qu'en HTTPS depuis github.com, même si l'adresse est signée (audit du 2026-11-14) : une
/// erreur dans release.json ne peut pas envoyer l'app ailleurs. Les redirections de GitHub vers son CDN sont suivies ;
/// l'empreinte SHA-256 signée reste la preuve du contenu.
bool trustedDownload(String url) {
  final u = Uri.tryParse(url);
  // Essais seulement : avec `--dart-define=UPDATE_URL=…` (jamais dans une version publiée), l'adresse d'essai est acceptée.
  if (const bool.hasEnvironment('UPDATE_URL')) return u != null;
  return u != null && u.scheme == 'https' && u.host == 'github.com';
}

class Updater {
  static const _channel = MethodChannel('zanakiantsa/system');

  Future<int> installedBuild() async => (await _channel.invokeMethod<int>('build')) ?? 0;

  /// La version publiée si elle est plus récente que celle installée, sinon null (aussi sans réseau).
  Future<Release?> check() async {
    try {
      final res = await http.get(Uri.parse('$updateBase/release.json')).timeout(const Duration(seconds: 15));
      final sig = await http.get(Uri.parse('$updateBase/release.json.sig')).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 || sig.statusCode != 200) return null;
      final r = await parseSigned(res.bodyBytes, sig.body);
      if (r == null || r.build <= await installedBuild()) return null;
      return r;
    } catch (_) {
      return null;
    }
  }

  /// Télécharge, vérifie l'empreinte, puis ouvre l'installateur Android. Faux si quelque chose échoue.
  Future<bool> install(Release r, void Function(double) progress) async {
    try {
      if (!trustedDownload(r.url)) return false;
      final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
      // Les anciens téléchargements (environ 40 Mo par version) ne restent pas dans le cache.
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      final file = File('${dir.path}/zanakiantsa-${r.build}.apk');
      final client = http.Client();
      final req = await client.send(http.Request('GET', Uri.parse(r.url))).timeout(const Duration(seconds: 30));
      if (req.statusCode != 200) {
        client.close();
        return false;
      }
      final sink = file.openWrite();
      var got = 0;
      final hasher = Sha256().newHashSink();
      // Un flux qui s'arrête plus d'une minute, ou plus gros que la taille signée, est abandonné.
      await for (final chunk in req.stream.timeout(const Duration(seconds: 60))) {
        got += chunk.length;
        if (r.bytes > 0 && got > r.bytes) break;
        sink.add(chunk);
        hasher.add(chunk);
        progress(r.bytes > 0 ? got / r.bytes : 0);
      }
      await sink.close();
      client.close();
      hasher.close();
      final hex = (await hasher.hash()).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (hex != r.sha256.toLowerCase() || (r.bytes > 0 && got != r.bytes)) {
        await file.delete();
        return false;
      }
      return (await _channel.invokeMethod<bool>('install', {'path': file.path})) ?? false;
    } catch (_) {
      return false;
    }
  }
}
