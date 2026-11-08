import 'package:flutter/material.dart';

import '../content/content.dart';
import '../ui/session.dart';
import '../ui/theme.dart';

/// Question écrite à réponses écrites (ADR 0057), pour les plus grands : la même séance, le même narrateur, les mêmes
/// aides. Chaque mauvaise réponse dit ce qu'elle montre. Une nouvelle leçon s'écrit dans le contenu, sans code.
class QuizActivity extends StatefulWidget {
  const QuizActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<QuizActivity> createState() => _QuizActivityState();
}

class _QuizActivityState extends State<QuizActivity> {
  Attempt get a => widget.attempt;
  late final Item item = a.skill.items[a.question.n];
  late final List<String> answers = [item.name!, for (final t in item.traps) t.text]..shuffle();
  final tried = <String>{};

  @override
  void initState() {
    super.initState();
    a.addListener(_changed);
    a.show('question').then((_) => a.say('consigne'));
  }

  @override
  void dispose() {
    a.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  void _tap(String answer) {
    if (a.busy || a.finished || tried.contains(answer)) return;
    final ok = answer == item.name;
    if (!ok) setState(() => tried.add(answer));
    a.submit(ok, why: ok ? null : item.traps.firstWhere((t) => t.text == answer).why);
  }

  @override
  Widget build(BuildContext context) {
    final shown = a.demonstrate || a.solved;
    return PlayScroll(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // L'énoncé reste sous les yeux quand l'aide prend la place du narrateur.
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
              child: QuestionText(item.text),
            ),
            for (final answer in answers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RevealWhen(
                  show: shown && answer == item.name,
                  child: _Answer(
                    text: answer,
                    tried: tried.contains(answer),
                    highlight: shown && answer == item.name,
                    onTap: a.busy || a.finished ? null : () => _tap(answer),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.text, required this.tried, required this.highlight, required this.onTap});
  final String text;
  final bool tried, highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: tried ? const Color(0xFFE3E7E4) : surface,
        elevation: tried ? 0 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: highlight ? gold : const Color(0xFFD5DBD7), width: highlight ? 6 : 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                Expanded(child: Text(keepTogether(text), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ink))),
                // La forme en plus de la couleur (docs/design.md).
                if (tried) const Icon(Icons.close_rounded, size: 28, color: ink),
                if (highlight) const Icon(Icons.check_circle_rounded, size: 32, color: gold),
              ]),
            ),
          ),
        ),
      );
}


/// Énoncé d'un quiz. Sur plusieurs lignes (programme, requête SQL, table), les lignes de texte (« Que renvoie cette
/// requête ? », « Table eleves (nom, classe) : ») restent en police normale, centrées ; les autres forment des blocs de code
/// alignés à gauche, en chasse fixe, sans retour à la ligne au milieu d'une instruction : un bloc trop large rétrécit au lieu
/// d'être coupé. Avant, le code était centré et coupé n'importe où (SM-X135G, texte à 150 %, 2026-11-08).
class QuestionText extends StatelessWidget {
  const QuestionText(this.text, {super.key});
  final String text;

  static const _prose = TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ink, height: 1.2);
  static const _code = TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.w600, color: ink, height: 1.35);

  /// Une ligne de texte : elle finit par « ? », ou par « : » précédé d'une espace (typographie française) ; en Python,
  /// « else: » ou « if x > 3: » n'ont pas d'espace avant les deux-points.
  static bool isProse(String line) => RegExp(r'(\?| :)\s*$').hasMatch(line.trimRight());

  /// La première ligne est une consigne si elle ressemble à une phrase (« Voici… », « Le lutin… ») ; une ligne de code
  /// (« mettre x à 10 », « x = 3 », « SELECT … ») reste dans le bloc de code. Vu sur la tablette le 2026-11-08 : la première
  /// instruction d'un programme s'affichait comme une consigne.
  static bool leads(String line) =>
      isProse(line) || line.trimRight().endsWith('.') || RegExp(r"^[«“]?\s*[A-ZÀ-ÖØ-Ý][a-zà-öø-ÿ']").hasMatch(line.trimLeft());

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    if (lines.length < 2) return Text(keepTogether(text), textAlign: TextAlign.center, style: _prose);
    // Regroupe les lignes : texte d'un côté, suites de lignes de code de l'autre.
    final parts = <(bool, List<String>)>[];
    for (final (i, l) in lines.indexed) {
      final prose = i == 0 ? leads(l) : isProse(l);
      if (parts.isNotEmpty && !prose && !parts.last.$1) {
        parts.last.$2.add(l);
      } else {
        parts.add((prose, [l]));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (prose, block) in parts)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: prose
              ? Text(keepTogether(block.join('\n')), textAlign: TextAlign.center, style: _prose)
              : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF1F3F2), borderRadius: BorderRadius.circular(12)),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(block.join('\n'), softWrap: false, style: _code),
                  ),
                ),
        ),
    ]);
  }
}
