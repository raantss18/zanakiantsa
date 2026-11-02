import 'package:flutter/material.dart';

import '../ui/session.dart';
import '../ui/theme.dart';

/// Composer : mettre des jetons dans le panier pour avoir le nombre demandé. Les jetons déjà là (départ) sont des
/// carrés, ceux que l'enfant ajoute sont des ronds : la forme distingue, pas seulement la couleur.
class ComposeActivity extends StatefulWidget {
  const ComposeActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<ComposeActivity> createState() => _ComposeActivityState();
}

class _ComposeActivityState extends State<ComposeActivity> {
  Attempt get a => widget.attempt;
  late final int n = a.question.n, start = a.question.a;
  static const maxTokens = 12;
  int added = 0;

  @override
  void initState() {
    super.initState();
    a.addListener(_onAttempt);
    a.say('consigne');
  }

  @override
  void dispose() {
    a.removeListener(_onAttempt);
    super.dispose();
  }

  bool _demo = false;

  Future<void> _onAttempt() async {
    if (a.demonstrate && !_demo) {
      _demo = true;
      setState(() => added = 0);
      for (var i = 0; i < n - start; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        setState(() => added++);
      }
    } else {
      setState(() {});
    }
  }

  bool get locked => a.busy || a.finished;

  void _add() {
    if (locked || start + added >= maxTokens) return;
    setState(() => added++);
    a.app.voice.say('${start + added}');
  }

  void _remove() {
    if (locked || added == 0) return;
    setState(() => added--);
    a.app.voice.say('${start + added}');
  }

  @override
  Widget build(BuildContext context) {
    final total = start + added;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, helpBand, 16, 8),
      child: split(
        main: Column(children: [
          Text('$n', style: Theme.of(context).textTheme.displayLarge, semanticsLabel: 'Il en faut $n'),
          const SizedBox(height: 8),
          // Le panier.
          Expanded(
            child: GestureDetector(
              onTap: _remove,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E7D3),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0xFFB98B4E), width: 6),
                ),
                child: Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                  for (var i = 0; i < start; i++) const _Token(square: true),
                  for (var i = 0; i < added; i++) const _Token(square: false),
                ]),
              ),
            ),
          ),
        ]),
        side: (axis) => Flex(direction: axis, mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          // La réserve : un jeton à toucher pour l'ajouter.
          Semantics(
            button: true,
            label: 'Ajouter un jeton',
            child: GestureDetector(
              onTap: _add,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: const Color(0xFFE6F3E9), borderRadius: BorderRadius.circular(28)),
                child: const Center(child: _Token(square: false, size: 64)),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            height: 120,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: green, padding: EdgeInsets.zero),
              onPressed: locked ? null : () => a.submit(total == n),
              child: const Icon(Icons.check_rounded, size: 80, color: Colors.white, semanticLabel: "J'ai fini"),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Token extends StatelessWidget {
  const _Token({required this.square, this.size = 48});
  final bool square;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: square ? const Color(0xFF3F51B5) : red,
          borderRadius: BorderRadius.circular(square ? 8 : size / 2),
        ),
      );
}
