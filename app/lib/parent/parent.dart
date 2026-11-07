import 'package:flutter/material.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as mlkit;

import '../activities/calcul.dart';
import '../activities/draw.dart';
import '../app_state.dart';
import '../core/day.dart';
import '../core/events.dart';
import '../core/progress.dart';
import '../core/report.dart';
import '../core/rules.dart';
import '../ui/adaptive.dart';
import '../content/content.dart';
import '../l10n/l10n.dart';
import 'dashboard.dart';
import 'notebook_style.dart';
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
  List<SessionLog> sessions = const [];
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
      // À chaque entrée dans l'espace parent, l'app regarde seule s'il y a une nouvelle version (demande d'Antsa) :
      // le parent n'a pas à y penser. Sans réseau, rien ne s'affiche.
      _check(automatic: true);
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
      this.sessions = sessions;
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
    setState(() => voiceTest = t('Écoutez…'));
    final (signalled, took, error) = await app.voice.test();
    if (!mounted) return;
    setState(() => voiceTest = error != null
        ? tf('Le moteur signale une erreur (« {error} ») : la voix française n’est sans doute pas installée. Dans les '
            'réglages du téléphone, « Synthèse vocale » : installez les données vocales en français, ou choisissez un '
            'autre moteur ci-dessus. Le texte reste toujours écrit à l’écran.', {'error': error})
        : signalled
            ? tf('Phrase dite en {s} s : le moteur prévient bien quand il a fini.', {'s': (took.inMilliseconds / 1000).toStringAsFixed(1)})
            : t('Le moteur n’a pas prévenu la fin de la phrase : les phrases peuvent être coupées ou espacées. '
                'Essayez un autre moteur ci-dessus (par exemple « com.google.android.tts », Synthèse vocale Google).'));
  }

  Future<void> _chooseEngine(String e) async {
    await app.voice.useEngine(e);
    await app.store.set('moteur_voix', e);
    await _loadVoice();
    if (mounted) setState(() => voiceTest = null);
  }

  /// Les 5 explications données le plus souvent ces 7 derniers jours, avec la compétence.
  Future<void> _downloadInk() async {
    setState(() => inkStatus = t('Téléchargement…'));
    var ok = false;
    try {
      final m = mlkit.DigitalInkRecognizerModelManager();
      ok = await m.downloadModel(inkLanguage, isWifiRequired: false) && await m.downloadModel(drawModel, isWifiRequired: false);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      inkModel = ok;
      inkStatus = ok
          ? t('Modèles installés : l’enfant peut écrire ses réponses, et ses dessins sont reconnus.')
          : t('Échec : vérifiez la connexion.');
    });
  }

  /// [automatic] : la recherche faite à l'entrée ; elle ne dit rien quand il n'y a rien de nouveau.
  Future<void> _check({bool automatic = false}) async {
    setState(() => updateStatus = automatic ? null : t('Recherche…'));
    final r = await updater.check();
    if (!mounted) return;
    setState(() {
      release = r;
      updateStatus = r != null
          ? tf('Version {v} disponible.', {'v': r.version})
          : automatic
              ? null
              : t('Pas de nouvelle version (ou pas de réseau).');
    });
  }

  /// En haut de l'espace parent, dès qu'une nouvelle version est trouvée : le bouton pour l'installer, sans chercher plus bas.
  Widget _updateBanner() => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.system_update_rounded, size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text(tf('Nouvelle version {v} disponible', {'v': release!.version}), style: notebookTitle)),
            ]),
            const SizedBox(height: 8),
            Text(release!.notes),
            const SizedBox(height: 12),
            if (progress != null)
              LinearProgressIndicator(value: progress)
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
                onPressed: _install,
                icon: const Icon(Icons.download_rounded),
                label: Text(t('Mettre à jour')),
              ),
            if (updateStatus != null && updateStatus!.startsWith(t('Installation'))) Padding(padding: const EdgeInsets.only(top: 8), child: Text(updateStatus!)),
          ]),
        ),
      );

  Future<void> _install() async {
    final ok = await updater.install(
      release!,
      (v) => setState(() => progress = v),
    );
    if (!mounted) return;
    setState(() {
      progress = null;
      updateStatus = ok ? t('Installation lancée.') : t('Installation non lancée : autorisez « installer des applis inconnues » pour Zanak’i Antsa, puis réessayez.');
    });
  }

  Future<void> _rename(ChildProfile p) async {
    final field = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Prénom')),
        content: TextField(controller: field, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, field.text), child: Text(t('Enregistrer'))),
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
          title: Text(t('Ajouter un enfant')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: field, autofocus: true, decoration: InputDecoration(labelText: t('Prénom (facultatif)')), textCapitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              Text(t('Âge')),
              Wrap(spacing: 6, children: [
                ValueStepper(
                  label: t('Âge'),
                  value: tf('{n} ans', {'n': years}),
                  minusLabel: t('Un an de moins'),
                  plusLabel: t('Un an de plus'),
                  onMinus: years <= 4 ? null : () => set(() => years--),
                  onPlus: years >= 99 ? null : () => set(() => years++),
                ),
              ]),
              const SizedBox(height: 12),
              Text(t('C’est')),
              Wrap(spacing: 6, children: [
                for (final (b, l) in [(true, t('un garçon')), (false, t('une fille'))]) ChoiceChip(label: Text(l), selected: boy == b, onSelected: (_) => set(() => boy = b)),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Annuler'))),
            FilledButton(onPressed: boy == null ? null : () => Navigator.pop(ctx, true), child: Text(t('Ajouter'))),
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
    final r = report;
    // Écran adulte : boutons de taille normale (le thème enfant les agrandit), marge sous la barre de navigation.
    final base = Theme.of(context);
    return Theme(
      // Le visuel du site (ADR 0059), quel que soit l'univers de l'enfant.
      data: notebookTheme(base),
      child: Scaffold(
        appBar: AppBar(title: Text(t('Espace parent'))),
        body: SeyesPaper(
          child: SafeArea(
          child: ListView(
            padding: readablePadding(context, side: 36, bottom: 48),
            children: [
              if (release != null) _updateBanner(),
              _LanguageSwitch(app: app),
              const Divider(height: 32),
              // Enfants de la famille (ADR 0034) : chacun a ses réglages, ses mondes, sa progression et ses livres.
              Text(t('Enfants'), style: notebookTitle),
              Text(t('Les réglages ci-dessous concernent l’enfant choisi. À plusieurs, l’app demande « Qui joue ? » au lancement.')),
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
                    deleteButtonTooltipMessage: t('Renommer'),
                  ),
                ActionChip(avatar: const Icon(Icons.person_add_alt_1_rounded), label: Text(t('Ajouter un enfant')), onPressed: _addChild),
              ]),
              const Divider(height: 32),
              Text(tf('{name} est', {'name': app.current.label}), style: notebookTitle),
              Text(t('Choisit les mondes proposés : robots, voitures, espace ; ou fées, poupées et mode, princesses.')),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final (boy, label) in [(true, t('un garçon')), (false, t('une fille'))])
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
              _AgeAndClass(app: app),
              const Divider(height: 32),
              Text(t('Temps de jeu proposé par jour'), style: notebookTitle),
              Text(
                t('Partagé en trois activités qui changent chaque jour (nombres, vivant, dessin ; suites, sons, échecs ; '
                'anglais, code, explorer), avec une pause proposée entre deux. Repère : l’OMS recommande au plus 1 h d’écran sédentaire '
                'par jour avant 5 ans, « moins, c’est mieux ».'),
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
              // Tableau de bord (ADR 0061) : temps, réussite du premier coup, progrès par domaine, à revoir.
              Text(t('En un coup d’œil'), style: notebookTitle),
              if (r == null) const LinearProgressIndicator() else Dashboard(app: app, sessions: sessions),
              const Divider(height: 32),
              Text(t('La voix'), style: notebookTitle),
              Text(
                t('La voix vient du moteur de synthèse vocale du téléphone. Si elle est coupée, hachée ou à l’accent '
                'étrange, essayez-la, puis choisissez un autre moteur.'),
              ),
              const SizedBox(height: 8),
              if (voiceInfo == null)
                const LinearProgressIndicator()
              else ...[
                Text(tf('Moteur utilisé : {engine} · français : {fr}', {'engine': voiceInfo!.$2 ?? t('inconnu'), 'fr': voiceInfo!.$3 ? t('disponible') : t('non disponible')})),
                if (voiceInfo!.$1.length > 1)
                  Wrap(spacing: 8, children: [
                    for (final e in voiceInfo!.$1)
                      ChoiceChip(label: Text(e), selected: e == voiceInfo!.$2, onSelected: (_) => _chooseEngine(e)),
                  ]),
              ],
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: voiceTest == t('Écoutez…') ? null : _testVoice, child: Text(t('Tester la voix'))),
              if (voiceTest != null) Text(voiceTest!),
              const Divider(height: 32),
              Text(
                t('Écriture et dessins au doigt'),
                style: notebookTitle,
              ),
              Text(
                t('Un téléchargement unique (connexion nécessaire) ; ensuite tout fonctionne hors ligne. Sans le modèle '
                'des dessins, un dessin est rangé sans être vérifié. '
                'ML Kit envoie à Google des statistiques techniques d’usage, jamais les tracés.'),
              ),
              const SizedBox(height: 8),
              if (inkModel == true)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(t('Modèles installés')),
                )
              else
                FilledButton.tonal(
                  onPressed: inkStatus == t('Téléchargement…')
                      ? null
                      : _downloadInk,
                  child: Text(t('Télécharger les modèles')),
                ),
              if (inkStatus != null) Text(inkStatus!),
              const Divider(height: 32),
              Text(
                t('Mises à jour'),
                style: notebookTitle,
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _check,
                child: Text(t('Rechercher une mise à jour')),
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
                    child: Text(t('Installer')),
                  ),
              ],
              const Divider(height: 32),
              // À propos : une question, un souci d'installation (demande d'Antsa, vidéo d'aide).
              Text(t('À propos'), style: notebookTitle),
              const SizedBox(height: 4),
              const SizedBox(height: 4),
              const AboutCard(),
              const Divider(height: 32),
              Text(t('Crédits'), style: notebookTitle),
              Text(
                t('Illustrations : Twemoji v17.0.3 (CC BY 4.0, github.com/jdecked/twemoji). '
                'Polices : Andika 7.000 et Fredoka (SIL Open Font License). '
                'Pièces d’échecs : Cburnett, Wikimedia Commons (CC BY-SA 3.0). '
                'Livres : African Storybook Initiative et leurs auteurs, illustrateurs et traducteurs, cités à la fin de '
                'chaque livre (CC BY 4.0, africanstorybook.org). '
                'Code : Apache-2.0, github.com/raantss18/zanakiantsa. '
                'Robot « Maia » : le programme lc0 v0.32.1 (Leela Chess Zero) et les poids Maia-1 (équipe CSSLab), tous '
                'deux sous licence GNU GPL v3. Ce sont des programmes séparés de l’appli, qui lui parlent par le protocole '
                'UCI. Sources : github.com/LeelaChessZero/lc0 (étiquette v0.32.1) et github.com/CSSLab/maia-chess ; '
                'recette de compilation : tool/build_lc0.sh dans github.com/raantss18/zanakiantsa. '
                'Analyse fine des parties : le programme Stockfish 11, sous licence GNU GPL v3, séparé de l’appli lui aussi. '
                'Sources : github.com/official-stockfish/Stockfish (étiquette sf_11) ; recette : tool/build_stockfish.sh.'),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// Un nombre ou une classe qu'on règle avec − et + : grands boutons, valeur au milieu, sans limite visible.
class ValueStepper extends StatelessWidget {
  const ValueStepper({super.key, required this.label, required this.value, required this.onMinus, required this.onPlus, this.minusLabel = 'Moins', this.plusLabel = 'Plus'});
  final String label, value, minusLabel, plusLabel;
  final VoidCallback? onMinus, onPlus;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton.filledTonal(tooltip: minusLabel, iconSize: 28, onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 112),
            child: Text(value, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Fredoka', fontSize: 26, fontWeight: FontWeight.w700)),
          ),
          IconButton.filledTonal(tooltip: plusLabel, iconSize: 28, onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
        ]),
      ]);
}

/// Âge et classe (ADR 0057) : deux réglages côte à côte. La classe suit l'âge tant que le parent n'y touche pas, et une
/// phrase dit ce que cela change, sans jargon.
class _AgeAndClass extends StatelessWidget {
  const _AgeAndClass({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final name = app.current.label;
    final classe = app.schoolClass;
    final start = schoolLevels[startLevelForClass(classe)];
    final top = app.highestLevel;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('Âge et classe'), style: notebookTitle),
      const SizedBox(height: 12),
      Wrap(spacing: 32, runSpacing: 16, children: [
        ValueStepper(
          label: t('Âge'),
          value: tf('{n} ans', {'n': app.age}),
          minusLabel: t('Un an de moins'),
          plusLabel: t('Un an de plus'),
          onMinus: app.age <= 4 ? null : () => app.setAge(app.age - 1),
          onPlus: app.age >= 99 ? null : () => app.setAge(app.age + 1),
        ),
        ValueStepper(
          label: app.chosenClass == null ? t('Classe, d’après son âge') : t('Classe, choisie par vous'),
          value: t(schoolLevels[classe]),
          minusLabel: t('Classe plus facile'),
          plusLabel: t('Classe plus avancée'),
          onMinus: classe <= 0 ? null : () => app.chooseClass(classe - 1),
          onPlus: classe >= schoolLevels.length - 1 ? null : () => app.chooseClass(classe + 1),
        ),
      ]),
      if (app.chosenClass != null)
        TextButton(onPressed: () => app.chooseClass(null), child: Text(t('Revenir à la classe de son âge'))),
      const SizedBox(height: 8),
      Text(
        classe - 1 > top
            ? tf('Les leçons vont pour l’instant jusqu’à la classe de {level} : {name} commence par les plus avancées. D’autres arrivent à chaque mise à jour.', {'level': t(schoolLevels[top]), 'name': name})
            : tf('Les leçons commencent au niveau {start}. Celles d’avant restent ouvertes, et « Je sais déjà » permet de sauter ce que {name} connaît.', {'start': t(start), 'name': name}),
      ),
      const SizedBox(height: 4),
      Text(
        afterLastMiss(app.age) == AfterLastMiss.demonstration
            ? t('Après trois essais, l’app montre la réponse.')
            : t('Après trois essais, l’app donne un dernier indice plutôt que la réponse.'),
      ),
    ]);
  }
}

/// Français ou anglais pour toute l'app (ADR 0064). Le changement coupe la voix en cours ; ensuite chaque phrase est dite
/// dans la nouvelle langue, et les mots étudiés (l'anglais, ou le français quand l'app est en anglais) par leur propre voix.
class _LanguageSwitch extends StatefulWidget {
  const _LanguageSwitch({required this.app});
  final AppState app;
  @override
  State<_LanguageSwitch> createState() => _LanguageSwitchState();
}

class _LanguageSwitchState extends State<_LanguageSwitch> {
  (List<String>, int)? ready;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    translatedTopics().then((l) {
      if (mounted) setState(() => ready = l);
    });
  }

  Future<void> _set(String lang) async {
    setState(() => busy = true);
    await widget.app.setLanguage(lang);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = ready;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('Langue de l’application'), style: notebookTitle),
      const SizedBox(height: 4),
      Wrap(spacing: 10, children: [
        for (final (code, label) in [('fr', 'Français'), ('en', 'English')])
          ChoiceChip(label: Text(label), selected: appLang == code, onSelected: busy ? null : (_) => _set(code)),
      ]),
      const SizedBox(height: 6),
      Text(
        r == null
            ? ''
            : tf('En anglais : {n} domaines sur {total} sont traduits ; les autres apparaîtront à chaque mise à jour. La voix parle la langue choisie ; les mots étudiés en langue étrangère gardent leur propre voix.',
                {'n': r.$1.length, 'total': r.$2}),
      ),
    ]);
  }
}
