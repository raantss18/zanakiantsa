import 'package:flutter/material.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;

import '../activities/calcul.dart';
import '../app_state.dart';
import '../core/report.dart';
import '../update/updater.dart';

/// Espace parent : âge de l'enfant, rapport de la semaine, modèle d'écriture, mises à jour.
class ParentPage extends StatefulWidget {
  const ParentPage({super.key});
  @override
  State<ParentPage> createState() => _ParentPageState();
}

class _ParentPageState extends State<ParentPage> {
  late final AppState app = AppScope.of(context);
  WeekReport? report;
  bool? inkModel;
  String? inkStatus;
  final updater = Updater();
  String? updateStatus;
  Release? release;
  double? progress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (report == null) _load();
  }

  Future<void> _load() async {
    final sessions = await app.store.sessions();
    bool ink = false;
    try {
      ink = await mlkit.DigitalInkRecognizerModelManager().isModelDownloaded(inkLanguage);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      report = weekReport([for (final s in app.theme.skills) s.id], app.journal, sessions, DateTime.now());
      inkModel = ink;
    });
  }

  Future<void> _downloadInk() async {
    setState(() => inkStatus = 'Téléchargement…');
    var ok = false;
    try {
      ok = await mlkit.DigitalInkRecognizerModelManager().downloadModel(inkLanguage, isWifiRequired: false);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      inkModel = ok;
      inkStatus = ok ? 'Modèle installé : l’enfant peut écrire ses réponses.' : 'Échec : vérifiez la connexion.';
    });
  }

  Future<void> _check() async {
    setState(() => updateStatus = 'Recherche…');
    final r = await updater.check();
    if (!mounted) return;
    setState(() {
      release = r;
      updateStatus = r == null ? 'Pas de nouvelle version (ou pas de réseau).' : 'Version ${r.version} disponible.';
    });
  }

  Future<void> _install() async {
    final ok = await updater.install(release!, (v) => setState(() => progress = v));
    if (!mounted) return;
    setState(() {
      progress = null;
      updateStatus = ok
          ? 'Installation lancée.'
          : 'Installation non lancée : autorisez « installer des applis inconnues » pour Zanak’i Antsa, puis réessayez.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final titles = {for (final s in app.theme.skills) s.id: s.title};
    final r = report;
    return Scaffold(
      appBar: AppBar(title: const Text('Espace parent')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Âge de l’enfant', style: Theme.of(context).textTheme.titleLarge),
        const Text('Avant 6 ans, après trois essais, l’app montre la réponse ; à partir de 6 ans, seulement un indice.'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (var y = 5; y <= 10; y++)
            ChoiceChip(label: Text('$y ans'), selected: app.age == y, onSelected: (_) async {
              await app.setAge(y);
              setState(() {});
            }),
        ]),
        const Divider(height: 32),
        Text('Les 7 derniers jours', style: Theme.of(context).textTheme.titleLarge),
        if (r == null)
          const LinearProgressIndicator()
        else ...[
          Text('${r.sessions} séance(s), ${r.minutes} min'),
          const SizedBox(height: 8),
          if (r.lines.isEmpty) const Text('Aucune activité cette semaine.'),
          for (final l in r.lines)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(l.mastered ? Icons.verified_rounded : Icons.timelapse_rounded,
                  color: l.mastered ? Colors.green : Colors.orange),
              title: Text(titles[l.skill] ?? l.skill),
              subtitle: Text('${l.successes} réussies sur ${l.answers} · ${l.helped} avec aide'
                  '${l.mastered ? ' · maîtrisée' : ''}'),
            ),
        ],
        const Divider(height: 32),
        Text('Écriture au doigt', style: Theme.of(context).textTheme.titleLarge),
        const Text('Un téléchargement unique (connexion nécessaire) ; ensuite tout fonctionne hors ligne. '
            'ML Kit envoie à Google des statistiques techniques d’usage, jamais les tracés.'),
        const SizedBox(height: 8),
        if (inkModel == true)
          const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.check_circle, color: Colors.green), title: Text('Modèle installé'))
        else
          FilledButton.tonal(onPressed: inkStatus == 'Téléchargement…' ? null : _downloadInk, child: const Text('Télécharger le modèle')),
        if (inkStatus != null) Text(inkStatus!),
        const Divider(height: 32),
        Text('Mises à jour', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        FilledButton.tonal(onPressed: _check, child: const Text('Rechercher une mise à jour')),
        if (updateStatus != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(updateStatus!)),
        if (release != null) ...[
          const SizedBox(height: 8),
          Text(release!.notes),
          const SizedBox(height: 8),
          if (progress != null) LinearProgressIndicator(value: progress) else FilledButton(onPressed: _install, child: const Text('Installer')),
        ],
      ]),
    );
  }
}
