import 'package:flutter/material.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as mlkit;

import '../activities/calcul.dart';
import '../activities/draw.dart';
import '../app_state.dart';
import '../core/day.dart';
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

  /// La voix (moteurs du téléphone, celui utilisé, français disponible) et le résultat de l'essai.
  (List<String>, String?, bool)? voiceInfo;
  String? voiceTest;
  final updater = Updater();
  String? updateStatus;
  Release? release;
  double? progress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (report == null) {
      _load();
      _loadVoice();
    }
  }

  Future<void> _load() async {
    final sessions = await app.store.sessions();
    bool ink = false;
    try {
      // Les deux modèles : chiffres écrits (calcul) et dessins (ADR 0038).
      final m = mlkit.DigitalInkRecognizerModelManager();
      ink = await m.isModelDownloaded(inkLanguage) && await m.isModelDownloaded(drawModel);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      report = weekReport(
        [for (final t in app.topics) for (final s in t.skills) s.id],
        app.journal,
        sessions,
        DateTime.now(),
      );
      inkModel = ink;
    });
  }

  Future<void> _loadVoice() async {
    final i = await app.voice.info();
    if (mounted) setState(() => voiceInfo = i);
  }

  Future<void> _testVoice() async {
    setState(() => voiceTest = 'Écoutez…');
    final (signalled, took, error) = await app.voice.test();
    if (!mounted) return;
    setState(() => voiceTest = error != null
        ? 'Le moteur signale une erreur (« $error ») : la voix française n’est sans doute pas installée. Dans les '
            'réglages du téléphone, « Synthèse vocale » : installez les données vocales en français, ou choisissez un '
            'autre moteur ci-dessus. Le texte reste toujours écrit à l’écran.'
        : signalled
            ? 'Phrase dite en ${(took.inMilliseconds / 1000).toStringAsFixed(1)} s : le moteur prévient bien quand il a fini.'
            : 'Le moteur n’a pas prévenu la fin de la phrase : les phrases peuvent être coupées ou espacées. '
                'Essayez un autre moteur ci-dessus (par exemple « com.google.android.tts », Synthèse vocale Google).');
  }

  Future<void> _chooseEngine(String e) async {
    await app.voice.useEngine(e);
    await app.store.set('moteur_voix', e);
    await _loadVoice();
    if (mounted) setState(() => voiceTest = null);
  }

  /// Les 5 explications données le plus souvent ces 7 derniers jours, avec la compétence.
  List<Widget> _frequentErrors(Map<String, String> titles) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final counts = <(String, String), int>{};
    for (final a in app.journal.where((a) => a.at.isAfter(since))) {
      for (final e in a.errors) {
        counts[(a.skill, e)] = (counts[(a.skill, e)] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return [const Text('Aucune erreur notée cette semaine.')];
    final top = (counts.entries.toList()..sort((a, b) => b.value - a.value)).take(5);
    return [
      for (final e in top)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Text('× ${e.value}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          title: Text(e.key.$2),
          subtitle: Text(titles[e.key.$1] ?? e.key.$1),
        ),
    ];
  }

  Future<void> _downloadInk() async {
    setState(() => inkStatus = 'Téléchargement…');
    var ok = false;
    try {
      final m = mlkit.DigitalInkRecognizerModelManager();
      ok = await m.downloadModel(inkLanguage, isWifiRequired: false) && await m.downloadModel(drawModel, isWifiRequired: false);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      inkModel = ok;
      inkStatus = ok
          ? 'Modèles installés : l’enfant peut écrire ses réponses, et ses dessins sont reconnus.'
          : 'Échec : vérifiez la connexion.';
    });
  }

  Future<void> _check() async {
    setState(() => updateStatus = 'Recherche…');
    final r = await updater.check();
    if (!mounted) return;
    setState(() {
      release = r;
      updateStatus = r == null
          ? 'Pas de nouvelle version (ou pas de réseau).'
          : 'Version ${r.version} disponible.';
    });
  }

  Future<void> _install() async {
    final ok = await updater.install(
      release!,
      (v) => setState(() => progress = v),
    );
    if (!mounted) return;
    setState(() {
      progress = null;
      updateStatus = ok ? 'Installation lancée.' : 'Installation non lancée : autorisez « installer des applis inconnues » pour Zanak’i Antsa, puis réessayez.';
    });
  }

  Future<void> _rename(ChildProfile p) async {
    final field = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prénom'),
        content: TextField(controller: field, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, field.text), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (name != null) await app.renameChild(p.id, name);
    if (mounted) setState(() {});
  }

  Future<void> _addChild() async {
    final field = TextEditingController();
    var years = 7;
    bool? boy;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Ajouter un enfant'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: field, autofocus: true, decoration: const InputDecoration(labelText: 'Prénom (facultatif)'), textCapitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              const Text('Âge'),
              Wrap(spacing: 6, children: [
                for (var y = 5; y <= 10; y++) ChoiceChip(label: Text('$y ans'), selected: years == y, onSelected: (_) => set(() => years = y)),
              ]),
              const SizedBox(height: 12),
              const Text('C’est'),
              Wrap(spacing: 6, children: [
                for (final (b, l) in [(true, 'un garçon'), (false, 'une fille')]) ChoiceChip(label: Text(l), selected: boy == b, onSelected: (_) => set(() => boy = b)),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: boy == null ? null : () => Navigator.pop(ctx, true), child: const Text('Ajouter')),
          ],
        ),
      ),
    );
    if (ok == true && boy != null) {
      await app.addChild(field.text, years, boy!);
      setState(() => report = null);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = {for (final t in app.topics) for (final s in t.skills) s.id: '${t.name} — ${s.title}'};
    final r = report;
    // Écran adulte : boutons de taille normale (le thème enfant les agrandit), marge sous la barre de navigation.
    final base = Theme.of(context);
    return Theme(
      // Fond clair neutre quel que soit l'univers (l'univers « espace » est sombre).
      data: base.copyWith(
        filledButtonTheme: const FilledButtonThemeData(),
        scaffoldBackgroundColor: const Color(0xFFF7F8F6),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF7F8F6), foregroundColor: Color(0xFF1B211D)),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Espace parent')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
            children: [
              // Enfants de la famille (ADR 0034) : chacun a ses réglages, ses mondes, sa progression et ses livres.
              Text('Enfants', style: Theme.of(context).textTheme.titleLarge),
              const Text('Les réglages ci-dessous concernent l’enfant choisi. À plusieurs, l’app demande « Qui joue ? » au lancement.'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in app.profiles)
                  InputChip(
                    label: Text(p.label),
                    selected: p.id == app.current.id,
                    onSelected: (_) async {
                      await app.switchChild(p.id);
                      setState(() => report = null);
                      _load();
                    },
                    onDeleted: () => _rename(p),
                    deleteIcon: const Icon(Icons.edit_rounded, size: 18),
                    deleteButtonTooltipMessage: 'Renommer',
                  ),
                ActionChip(avatar: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Ajouter un enfant'), onPressed: _addChild),
              ]),
              const Divider(height: 32),
              Text('${app.current.label} est', style: Theme.of(context).textTheme.titleLarge),
              const Text('Choisit les mondes proposés : robots, voitures, espace ; ou fées, poupées et mode, princesses.'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final (boy, label) in [(true, 'un garçon'), (false, 'une fille')])
                  ChoiceChip(
                    label: Text(label),
                    selected: app.boy == boy,
                    onSelected: (_) async {
                      await app.setGender(boy);
                      setState(() {});
                    },
                  ),
              ]),
              const Divider(height: 32),
              Text(
                'Âge de l’enfant',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Avant 6 ans, après trois essais, l’app montre la réponse ; à partir de 6 ans, seulement un indice.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (var y = 5; y <= 10; y++)
                    ChoiceChip(
                      label: Text('$y ans'),
                      selected: app.age == y,
                      onSelected: (_) async {
                        await app.setAge(y);
                        setState(() {});
                      },
                    ),
                ],
              ),
              const Divider(height: 32),
              Text('Temps de jeu proposé par jour', style: Theme.of(context).textTheme.titleLarge),
              const Text(
                'Partagé en trois activités qui changent chaque jour (nombres, vivant, dessin ; suites, sons, échecs ; '
                'anglais, code, explorer), avec une pause proposée entre deux. Repère : l’OMS recommande au plus 1 h d’écran sédentaire '
                'par jour avant 5 ans, « moins, c’est mieux ».',
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final m in dailyMinuteChoices)
                  ChoiceChip(
                    label: Text(m < 60 ? '$m min' : '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60}'}'),
                    selected: app.dailyMinutes == m,
                    onSelected: (_) async {
                      await app.setDailyMinutes(m);
                      setState(() {});
                    },
                  ),
              ]),
              const Divider(height: 32),
              Text(
                'Les 7 derniers jours',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (r == null)
                const LinearProgressIndicator()
              else ...[
                Text('${r.sessions} séance(s), ${r.minutes} min'),
                const SizedBox(height: 8),
                if (r.lines.isEmpty)
                  const Text('Aucune activité cette semaine.'),
                for (final l in r.lines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      l.mastered
                          ? Icons.verified_rounded
                          : Icons.timelapse_rounded,
                      color: l.mastered ? Colors.green : Colors.orange,
                    ),
                    title: Text(titles[l.skill] ?? l.skill),
                    subtitle: Text(
                      '${l.successes} réussies sur ${l.answers} · ${l.helped} avec aide'
                      '${l.mastered ? ' · maîtrisée' : ''}',
                    ),
                  ),
                // ADR 0042 : ce que l'app a expliqué le plus souvent cette semaine (erreurs typiques ou conseils).
                const SizedBox(height: 8),
                Text('Les erreurs qui reviennent', style: Theme.of(context).textTheme.titleMedium),
                ..._frequentErrors(titles),
              ],
              const Divider(height: 32),
              Text('La voix', style: Theme.of(context).textTheme.titleLarge),
              const Text(
                'La voix vient du moteur de synthèse vocale du téléphone. Si elle est coupée, hachée ou à l’accent '
                'étrange, essayez-la, puis choisissez un autre moteur.',
              ),
              const SizedBox(height: 8),
              if (voiceInfo == null)
                const LinearProgressIndicator()
              else ...[
                Text('Moteur utilisé : ${voiceInfo!.$2 ?? 'inconnu'} · français : ${voiceInfo!.$3 ? 'disponible' : 'non disponible'}'),
                if (voiceInfo!.$1.length > 1)
                  Wrap(spacing: 8, children: [
                    for (final e in voiceInfo!.$1)
                      ChoiceChip(label: Text(e), selected: e == voiceInfo!.$2, onSelected: (_) => _chooseEngine(e)),
                  ]),
              ],
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: voiceTest == 'Écoutez…' ? null : _testVoice, child: const Text('Tester la voix')),
              if (voiceTest != null) Text(voiceTest!),
              const Divider(height: 32),
              Text(
                'Écriture et dessins au doigt',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Un téléchargement unique (connexion nécessaire) ; ensuite tout fonctionne hors ligne. Sans le modèle '
                'des dessins, un dessin est rangé sans être vérifié. '
                'ML Kit envoie à Google des statistiques techniques d’usage, jamais les tracés.',
              ),
              const SizedBox(height: 8),
              if (inkModel == true)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Modèles installés'),
                )
              else
                FilledButton.tonal(
                  onPressed: inkStatus == 'Téléchargement…'
                      ? null
                      : _downloadInk,
                  child: const Text('Télécharger les modèles'),
                ),
              if (inkStatus != null) Text(inkStatus!),
              const Divider(height: 32),
              Text(
                'Mises à jour',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _check,
                child: const Text('Rechercher une mise à jour'),
              ),
              if (updateStatus != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(updateStatus!),
                ),
              if (release != null) ...[
                const SizedBox(height: 8),
                Text(release!.notes),
                const SizedBox(height: 8),
                if (progress != null)
                  LinearProgressIndicator(value: progress)
                else
                  FilledButton(
                    onPressed: _install,
                    child: const Text('Installer'),
                  ),
              ],
              const Divider(height: 32),
              Text('Crédits', style: Theme.of(context).textTheme.titleLarge),
              const Text(
                'Illustrations : Twemoji v17.0.3 (CC BY 4.0, github.com/jdecked/twemoji). '
                'Polices : Andika 7.000 et Fredoka (SIL Open Font License). '
                'Pièces d’échecs : Cburnett, Wikimedia Commons (CC BY-SA 3.0). '
                'Livres : African Storybook Initiative et leurs auteurs, illustrateurs et traducteurs, cités à la fin de '
                'chaque livre (CC BY 4.0, africanstorybook.org). '
                'Code : Apache-2.0, github.com/raantss18/zanakiantsa. '
                'Robot « Maia » : le programme lc0 v0.32.1 (Leela Chess Zero) et les poids Maia-1 (équipe CSSLab), tous '
                'deux sous licence GNU GPL v3. Ce sont des programmes séparés de l’appli, qui lui parlent par le protocole '
                'UCI. Sources : github.com/LeelaChessZero/lc0 (étiquette v0.32.1) et github.com/CSSLab/maia-chess ; '
                'recette de compilation : tool/build_lc0.sh dans github.com/raantss18/zanakiantsa.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
