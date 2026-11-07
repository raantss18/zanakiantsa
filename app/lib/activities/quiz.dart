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
              child: Text(item.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ink, height: 1.2)),
            ),
            for (final answer in answers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Answer(
                  text: answer,
                  tried: tried.contains(answer),
                  highlight: shown && answer == item.name,
                  onTap: a.busy || a.finished ? null : () => _tap(answer),
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
                Expanded(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ink))),
                // La forme en plus de la couleur (docs/design.md).
                if (tried) const Icon(Icons.close_rounded, size: 28, color: ink),
                if (highlight) const Icon(Icons.check_circle_rounded, size: 32, color: gold),
              ]),
            ),
          ),
        ),
      );
}
