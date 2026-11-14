/// Votre avis (ADR 0074) : la note de l'app, ce sont les étoiles du dépôt GitHub. Le nombre est lu sur le site de l'app
/// (avis.json, mis à jour à chaque nouvelle étoile), jamais directement chez GitHub ; donner une étoile se fait sur GitHub,
/// dans le navigateur, avec le compte du parent. Rien sur l'enfant ne part.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../l10n/l10n.dart';
import 'notebook_style.dart';

const repoUrl = 'https://github.com/raantss18/zanakiantsa';
const ratingUrl = String.fromEnvironment('AVIS_URL', defaultValue: 'https://raantss18.github.io/zanakiantsa/avis.json');

/// Le nombre d'étoiles écrit dans avis.json ; null si le fichier est absent, abîmé ou sans nombre.
int? starsFrom(String body) {
  try {
    final n = (jsonDecode(body) as Map<String, dynamic>)['etoiles'];
    return n is int && n >= 0 ? n : null;
  } catch (_) {
    return null;
  }
}

Future<int?> fetchStars() async {
  try {
    final r = await http.get(Uri.parse(ratingUrl)).timeout(const Duration(seconds: 10));
    return r.statusCode == 200 ? starsFrom(r.body) : null;
  } catch (_) {
    return null;
  }
}

/// Ouvre une page du projet dans le navigateur ; faux s'il n'y en a pas (ou si le contrôle parental l'interdit).
Future<bool> openProjectPage(String url) async {
  try {
    return await const MethodChannel('zanakiantsa/system').invokeMethod<bool>('open', {'url': url}) ?? false;
  } catch (_) {
    return false;
  }
}

class RatingCard extends StatefulWidget {
  const RatingCard({super.key});
  @override
  State<RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<RatingCard> {
  int? stars;
  bool loaded = false;
  String? problem;

  @override
  void initState() {
    super.initState();
    fetchStars().then((n) {
      if (!mounted) return;
      setState(() {
        stars = n;
        loaded = true;
      });
    });
  }

  Future<void> _open(String url) async {
    final ok = await openProjectPage(url);
    if (!mounted) return;
    setState(() => problem = ok ? null : tf('Pas de navigateur disponible. L’adresse : {url}', {'url': url}));
  }

  @override
  Widget build(BuildContext context) {
    final n = stars;
    final count = !loaded
        ? t('…')
        : n == null
            ? t('Nombre d’étoiles indisponible (pas de réseau).')
            : n == 0
                ? t('Pas encore d’étoile : la première peut être la vôtre.')
                : n == 1
                    ? t('1 étoile sur GitHub')
                    : tf('{n} étoiles sur GitHub', {'n': n});
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        liveRegion: true,
        child: Row(children: [
          const Icon(Icons.star_rounded, color: Color(0xFFF7B42C), size: 44),
          const SizedBox(width: 8),
          Expanded(child: Text(count, style: const TextStyle(fontFamily: 'Andika', fontSize: 20, fontWeight: FontWeight.w700, color: encre))),
        ]),
      ),
      const SizedBox(height: 6),
      Text(t('L’application vous plaît ? Donnez une étoile au projet sur GitHub : c’est sa note, la même que sur le site. Elle aide d’autres familles à le trouver. Il faut un compte GitHub, gratuit.')),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 8, children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 52), textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 18, fontWeight: FontWeight.w700)),
          onPressed: () => _open('$repoUrl/stargazers'),
          icon: const Icon(Icons.star_rounded),
          label: Text(t('Donner une étoile')),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52), textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 18, fontWeight: FontWeight.w700)),
          onPressed: () => _open('$repoUrl/issues/new?title=Mon%20avis&labels=avis'),
          icon: const Icon(Icons.rate_review_rounded),
          label: Text(t('Écrire un avis')),
        ),
      ]),
      if (problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: SelectableText(problem!)),
    ]);
  }
}
