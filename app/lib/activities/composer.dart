import 'package:flutter/material.dart';

import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';

/// Composer : mettre des objets de l'univers dans le contenant pour avoir le nombre demandé. Les objets déjà là au
/// départ sont posés sur une tuile carrée, ceux que l'enfant ajoute non : la forme distingue, pas seulement la couleur.
class ComposeActivity extends StatefulWidget {
  const ComposeActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<ComposeActivity> createState() => _ComposeActivityState();
}

class _ComposeActivityState extends State<ComposeActivity> {
  Attempt get a => widget.attempt;
  late final int n = a.question.n, start = a.question.a;
  late final String art = a.app.objectArt(a.skill);
  static const maxItems = 12;
  int added = 0;
  bool _demo = false;

  @override
  void initState() {
    super.initState();
    a.addListener(_onAttempt);
    a.show('consigne');
  }

  @override
  void dispose() {
    a.removeListener(_onAttempt);
    super.dispose();
  }

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
    if (locked || start + added >= maxItems) return;
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
    final u = a.app.universe;
    final total = start + added;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: split(
        main: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: u.onCard, width: 5),
            boxShadow: cardShadow,
          ),
          child: Column(children: [
            // En-tête du contenant : son dessin, le compte actuel et le nombre visé (écrits).
            Row(children: [
              Art(u.container, size: 52),
              const Spacer(),
              Text('$total', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: u.onCard), semanticsLabel: 'Il y en a $total'),
              Text(' / $n', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ink), semanticsLabel: 'Il en faut $n'),
            ]),
            const Divider(height: 16),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Enlever un objet',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _remove,
                  child: LayoutBuilder(
                    builder: (_, k) {
                      // Taille des objets : les 12 au maximum tiennent dans le contenant, sans se chevaucher.
                      final perRow = (k.maxWidth / 72).floor().clamp(3, 6);
                      final size = ((k.maxWidth - (perRow - 1) * 10) / perRow).clamp(36.0, 64.0);
                      return Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                        for (var i = 0; i < start; i++) _Item(art: art, size: size, preset: true),
                        for (var i = 0; i < added; i++) _Item(art: art, size: size, preset: false),
                      ]);
                    },
                  ),
                ),
              ),
            ),
          ]),
        ),
        side: (axis) => Flex(direction: axis, mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          // La réserve : toucher pour ajouter un objet.
          Semantics(
            button: true,
            label: 'Ajouter un objet',
            child: Material(
              color: surface,
              borderRadius: BorderRadius.circular(28),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _add,
                child: SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(alignment: Alignment.center, children: [
                    Art(art, size: 64),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: CircleAvatar(radius: 16, backgroundColor: u.onCard, child: const Icon(Icons.add, color: Colors.white, size: 22)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 112,
            height: 112,
            child: FilledButton(
              style: FilledButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: locked ? null : () => a.submit(total == n),
              child: const Icon(Icons.check_rounded, size: 72, semanticLabel: "J'ai fini"),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.art, required this.size, required this.preset});
  final String art;
  final double size;

  /// Déjà là au départ : posé sur une tuile carrée grise.
  final bool preset;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.08),
        decoration: preset ? BoxDecoration(color: const Color(0xFFE4E7E5), borderRadius: BorderRadius.circular(10)) : null,
        child: Art(art, size: size * 0.84),
      );
}
