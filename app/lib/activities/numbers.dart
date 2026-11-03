import 'dart:math';

import 'package:flutter/material.dart';

import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';

/// Activités de numération et de calcul du cycle 2 (ADR 0021) : bâtonnets (dizaines et unités), groupes égaux
/// (multiplication, doubles), tables, partage équitable (division, moitiés). Le matériel est celui que cite le
/// programme : bâtonnets assemblés en paquets de dix, objets distribués un à un.

/// Trois réponses : la bonne et deux nombres proches et plausibles (jamais négatifs, toujours différents).
/// Les erreurs typiques de [near] (chiffres inversés, addition au lieu de multiplication…) passent en premier : ce
/// sont elles qu'on veut voir et expliquer (ADR 0029).
List<int> numberChoices(int right, int seed, {List<int> near = const []}) {
  final r = Random(seed);
  bool ok(int v) => v >= 0 && v != right;
  final first = {for (final v in near) if (ok(v)) v}.toList();
  final rest = ({right + 1, right - 1, right + 10, right - 10, right + 2}..removeWhere((v) => !ok(v) || first.contains(v))).toList()..shuffle(r);
  return [right, ...[...first, ...rest].take(2)]..shuffle(r);
}

/// Ce que montre une réponse-nombre fausse (ADR 0029) : l'erreur probable, dite simplement, sans « faux ». null si on
/// ne sait pas l'expliquer (l'aide habituelle suffit alors).
String? explainNumber(String activity, String? mode, int n, int a, int b, int right, int v) {
  String plural(int k, String one, String many) => k <= 1 ? '$k $one' : '$k $many';
  switch (activity) {
    case 'batonnets' when mode == 'casser':
      if (v == right + 10 || v == right - 10) return 'Regarde bien les paquets de dix qui restent.';
      if (v == n + b) return "Tu as ajouté $b. Ici, on en enlève $b.";
    case 'batonnets':
      if (b > 0 && v == b * 10 + a && v != n) {
        return '$v, ce serait ${plural(b, 'paquet', 'paquets')} de dix et ${plural(a, 'bâtonnet seul', 'bâtonnets seuls')}.';
      }
      if ((v - n).abs() == 10) return 'Recompte les paquets : chacun vaut dix.';
      if ((v - n).abs() <= 2) return 'Presque ! Recompte les bâtonnets seuls.';
    case 'groupes' || 'tables':
      if (v == a + b && v != n) return "Tu as ajouté $a et $b. Mais il y a $a fois $b : compte tous les objets.";
      if (v == n + b || v == n - b) return 'Il y a une rangée de ${v > n ? 'trop' : 'moins'} : recompte les paquets.';
      if ((v - n).abs() <= 2) return 'Presque ! Compte encore, un par un.';
    case 'paquets':
      if (v == b) return "$b, c'est ce qu'il y a dans chaque paquet. On cherche combien de paquets.";
      if ((v - a).abs() == 1) return 'Presque ! Touche chaque paquet en comptant.';
  }
  if ((v - right).abs() == 1) return 'Presque ! Compte encore une fois.';
  return null;
}

/// Rangée de trois boutons-nombres ; la bonne réponse est montrée en démonstration ou une fois trouvée.
class NumberChoices extends StatefulWidget {
  const NumberChoices({super.key, required this.attempt, required this.right, required this.values});
  final Attempt attempt;
  final int right;
  final List<int> values;
  @override
  State<NumberChoices> createState() => _NumberChoicesState();
}

class _NumberChoicesState extends State<NumberChoices> {
  final tried = <int>{};

  @override
  Widget build(BuildContext context) {
    final a = widget.attempt;
    return ListenableBuilder(
      listenable: a,
      builder: (_, _) => Wrap(spacing: 24, runSpacing: 16, alignment: WrapAlignment.center, children: [
        for (final v in widget.values)
          NumberButton(
            value: v,
            highlight: (a.demonstrate || a.solved) && v == widget.right,
            onPressed: a.busy || a.finished || tried.contains(v)
                ? null
                : () {
                    if (v != widget.right) setState(() => tried.add(v));
                    final q = a.question;
                    a.submit(v == widget.right,
                        why: v == widget.right ? null : explainNumber(a.skill.activity, a.skill.params['mode'] as String?, q.n, q.a, q.b, widget.right, v));
                  },
          ),
      ]),
    );
  }
}

/// Un bâtonnet, ou un paquet de dix tenu par un élastique rouge.
class Sticks extends StatelessWidget {
  const Sticks({super.key, this.bundle = false, this.height = 72});
  final bool bundle;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(bundle ? height * 0.62 : height * 0.16, height),
        painter: _SticksPainter(bundle),
      );
}

class _SticksPainter extends CustomPainter {
  _SticksPainter(this.bundle);
  final bool bundle;

  @override
  void paint(Canvas canvas, Size size) {
    final wood = Paint()..color = const Color(0xFFC8873A);
    final edge = Paint()
      ..color = const Color(0xFF7A4B17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final w = bundle ? size.width / 10 : size.width;
    for (var i = 0; i < (bundle ? 10 : 1); i++) {
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(i * w + w * 0.08, 0, w * 0.84, size.height), Radius.circular(w * 0.4));
      canvas
        ..drawRRect(rect, wood)
        ..drawRRect(rect, edge);
    }
    if (bundle) {
      final band = Rect.fromLTWH(-2, size.height * 0.44, size.width + 4, size.height * 0.12);
      canvas.drawRRect(RRect.fromRectAndRadius(band, const Radius.circular(4)), Paint()..color = const Color(0xFFD62828));
    }
  }

  @override
  bool shouldRepaint(_SticksPainter old) => old.bundle != bundle;
}

/// Bâtonnets : `lire` (combien y en a-t-il ?) ou `construire` (fabrique le nombre avec des paquets et des bâtonnets).
class SticksActivity extends StatefulWidget {
  const SticksActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<SticksActivity> createState() => _SticksActivityState();
}

class _SticksActivityState extends State<SticksActivity> {
  Attempt get a => widget.attempt;
  late final bool making = a.skill.params['mode'] == 'construire';
  int tens = 0, units = 0;

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

  void _changed() {
    if (a.demonstrate && making) {
      tens = a.question.a;
      units = a.question.b;
    }
    setState(() {});
  }

  Widget _collection(int t, int u) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
        child: Wrap(spacing: 14, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < t; i++) const Sticks(bundle: true),
          if (t > 0 && u > 0) const SizedBox(width: 18),
          for (var i = 0; i < u; i++) const Sticks(),
        ]),
      );

  Widget _stepper(String label, Widget picture, int value, ValueChanged<int> set, {int max = 9}) {
    final locked = a.busy || a.finished;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(height: 80, child: Center(child: picture)),
      Text('$value', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: ink)),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF5F6B63))),
      const SizedBox(height: 6),
      Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton.filledTonal(iconSize: 36, tooltip: 'Enlever', onPressed: locked || value == 0 ? null : () => setState(() => set(value - 1)), icon: const Icon(Icons.remove_rounded)),
        const SizedBox(width: 4),
        IconButton.filled(iconSize: 36, tooltip: 'Ajouter', onPressed: locked || value >= max ? null : () => setState(() => set(value + 1)), icon: const Icon(Icons.add_rounded)),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final q = a.question;
    if (!making) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _collection(q.a, q.b),
          const SizedBox(height: 28),
          NumberChoices(attempt: a, right: q.n, values: numberChoices(q.n, q.n * 31 + q.a, near: [if (q.b > 0 && q.b != q.a) q.b * 10 + q.a])),
        ]),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Le nombre demandé, écrit en grand sur sa carte.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24), boxShadow: cardShadow, border: Border.all(color: a.app.universe.onCard, width: 4)),
          child: Text('${q.n}', style: Theme.of(context).textTheme.displayLarge),
        ),
        const SizedBox(height: 12),
        _collection(tens, units),
        const SizedBox(height: 12),
        // Les deux compteurs et le bouton vert sur une seule rangée : rien à faire défiler.
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: _stepper('paquets de dix', const Sticks(bundle: true, height: 64), tens, (v) => tens = v)),
          Expanded(child: _stepper('bâtonnets', const Sticks(height: 64), units, (v) => units = v, max: 19)),
          SizedBox(
            width: 104,
            height: 104,
            child: FilledButton(
              style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero, backgroundColor: green, disabledBackgroundColor: const Color(0xFFBFC7C1)),
              onPressed: a.busy || a.finished || tens + units == 0 ? null : () => a.submit(tens * 10 + units == q.n),
              child: const Icon(Icons.check_rounded, size: 56, color: Colors.white, semanticLabel: "C'est fait"),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Groupes égaux : [a] paquets de [b] objets du monde (multiplication, doubles), ou une table en quadrillage.
class GroupsActivity extends StatefulWidget {
  const GroupsActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<GroupsActivity> createState() => _GroupsActivityState();
}

class _GroupsActivityState extends State<GroupsActivity> {
  Attempt get a => widget.attempt;

  @override
  void initState() {
    super.initState();
    a.show('question').then((_) => a.say('consigne'));
  }

  @override
  Widget build(BuildContext context) {
    final q = a.question;
    final art = a.app.objectArt(a.skill);
    final table = a.skill.activity == 'tables';
    final size = q.b > 6 ? 26.0 : 34.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        if (table)
          // Quadrillage : [a] rangées de [b] ; couché quand il serait trop haut (l'ordre des facteurs ne change pas le
          // résultat, programme de CE1).
          Builder(builder: (_) {
            final rows = q.a > 5 && q.b < q.a ? q.b : q.a, cols = rows == q.a ? q.b : q.a;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24), boxShadow: cardShadow),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < rows; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [for (var j = 0; j < cols; j++) Padding(padding: const EdgeInsets.all(2), child: Art(art, size: cols > 8 ? 28 : 32))]),
                  ),
              ]),
            );
          })
        else
          Wrap(spacing: 14, runSpacing: 14, alignment: WrapAlignment.center, children: [
            for (var i = 0; i < q.a; i++)
              Container(
                width: 3 * (size + 6) + 24,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow, border: Border.all(color: a.app.universe.onCard, width: 3)),
                child: Wrap(alignment: WrapAlignment.center, children: [for (var j = 0; j < q.b; j++) Padding(padding: const EdgeInsets.all(3), child: Art(art, size: size))]),
              ),
          ]),
        const SizedBox(height: 28),
        NumberChoices(attempt: a, right: q.n, values: numberChoices(q.n, q.n * 7 + q.a, near: [q.a + q.b, q.n + q.b, if (q.n > q.b) q.n - q.b])),
      ]),
    );
  }
}

/// Partage équitable : on distribue les objets un à un en touchant les parts ; quand il n'en reste plus, les parts
/// doivent être égales (sinon c'est un essai manqué et on recommence la distribution).
class ShareActivity extends StatefulWidget {
  const ShareActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<ShareActivity> createState() => _ShareActivityState();
}

class _ShareActivityState extends State<ShareActivity> {
  Attempt get a => widget.attempt;
  late final List<int> parts = List.filled(a.question.a, 0);
  late int pile = a.question.n;

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

  Future<void> _changed() async {
    if (a.demonstrate && pile > 0) {
      // Démonstration : distribuer un par un, chacun son tour.
      for (var i = 0; pile > 0; i = (i + 1) % parts.length) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        setState(() {
          parts[i]++;
          pile--;
        });
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _give(int i) async {
    if (a.busy || a.finished || pile == 0) return;
    setState(() {
      parts[i]++;
      pile--;
    });
    if (pile > 0) return;
    final equal = parts.every((p) => p == parts.first);
    if (!equal) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() {
        parts.fillRange(0, parts.length, 0);
        pile = a.question.n;
      });
    }
    a.submit(equal);
  }

  @override
  Widget build(BuildContext context) {
    final art = a.app.objectArt(a.skill);
    final u = a.app.universe;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Le tas à partager.
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF1F3F2), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFD5DBD7), width: 2)),
          child: Wrap(alignment: WrapAlignment.center, children: [for (var i = 0; i < pile; i++) Padding(padding: const EdgeInsets.all(2), child: Art(art, size: 30))]),
        ),
        const SizedBox(height: 20),
        Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < parts.length; i++)
            Semantics(
              button: true,
              label: 'Part ${i + 1} : ${parts[i]}',
              child: Material(
                color: surface,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: u.onCard, width: 4)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _give(i),
                  child: SizedBox(
                    width: 150,
                    height: parts.length > 2 ? 150 : 200,
                    child: Column(children: [
                      const SizedBox(height: 6),
                      const Art('1f9d2', size: 40),
                      Text('${parts[i]}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ink)),
                      Expanded(
                        child: Wrap(alignment: WrapAlignment.center, children: [for (var j = 0; j < parts[i]; j++) Padding(padding: const EdgeInsets.all(1), child: Art(art, size: 20))]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// Soustraire en cassant une dizaine (CP) : on touche un paquet pour le défaire en dix bâtonnets, puis on enlève les
/// bâtonnets demandés un par un ; enfin on dit combien il en reste.
class BreakTenActivity extends StatefulWidget {
  const BreakTenActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<BreakTenActivity> createState() => _BreakTenActivityState();
}

class _BreakTenActivityState extends State<BreakTenActivity> {
  Attempt get a => widget.attempt;
  late int bundles = a.question.a;
  int loose = 0, removed = 0;

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

  Future<void> _changed() async {
    if (a.demonstrate && removed < a.question.b) {
      if (loose < a.question.b - removed && bundles > 0) _break();
      while (removed < a.question.b && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        _take();
      }
    }
    if (mounted) setState(() {});
  }

  bool get locked => a.busy || a.finished;

  void _break() {
    if (locked && !a.demonstrate || bundles == 0) return;
    setState(() {
      bundles--;
      loose += 10;
    });
  }

  void _take() {
    if ((locked && !a.demonstrate) || loose == 0 || removed >= a.question.b) return;
    setState(() {
      loose--;
      removed++;
    });
    a.app.voice.say('$removed');
  }

  @override
  Widget build(BuildContext context) {
    final q = a.question;
    final done = removed >= q.b;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
          child: Wrap(spacing: 14, runSpacing: 14, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (var i = 0; i < bundles; i++)
              Semantics(
                button: true,
                label: 'Défaire un paquet de dix',
                child: GestureDetector(onTap: _break, child: const Sticks(bundle: true)),
              ),
            if (bundles > 0 && loose > 0) const SizedBox(width: 18),
            for (var i = 0; i < loose; i++)
              Semantics(
                button: true,
                label: 'Enlever un bâtonnet',
                // Zone de toucher plus large que le bâtonnet (48 dp).
                child: GestureDetector(onTap: _take, child: Container(width: 30, height: 80, alignment: Alignment.center, color: Colors.transparent, child: const Sticks())),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        // Les bâtonnets enlevés, à part et grisés : on voit ce qu'on a retiré.
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Enlevés : $removed / ${q.b}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink)),
          const SizedBox(width: 12),
          for (var i = 0; i < removed; i++) const Opacity(opacity: 0.35, child: Padding(padding: EdgeInsets.all(2), child: Sticks(height: 48))),
        ]),
        const SizedBox(height: 24),
        if (done)
          NumberChoices(attempt: a, right: q.n - q.b, values: numberChoices(q.n - q.b, q.n * 13 + q.b, near: [q.n - 10 + q.b, q.n - q.b + 10]))
        else
          Text(bundles == q.a ? 'Touche un paquet pour le défaire.' : 'Touche les bâtonnets pour les enlever.',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF5F6B63))),
      ]),
    );
  }
}

/// Faire des paquets (CP, « chercher le nombre de parts ») : on fait des paquets de [b] avec le tas, puis on dit
/// combien de paquets on a faits.
class PacketsActivity extends StatefulWidget {
  const PacketsActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<PacketsActivity> createState() => _PacketsActivityState();
}

class _PacketsActivityState extends State<PacketsActivity> {
  Attempt get a => widget.attempt;
  late int pile = a.question.n;
  int packets = 0;

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

  Future<void> _changed() async {
    while (a.demonstrate && pile > 0 && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      _pack(force: true);
    }
    if (mounted) setState(() {});
  }

  void _pack({bool force = false}) {
    if ((!force && (a.busy || a.finished)) || pile < a.question.b) return;
    setState(() {
      pile -= a.question.b;
      packets++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = a.question;
    final art = a.app.objectArt(a.skill);
    final u = a.app.universe;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF1F3F2), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFD5DBD7), width: 2)),
          child: Wrap(alignment: WrapAlignment.center, children: [for (var i = 0; i < pile; i++) Padding(padding: const EdgeInsets.all(2), child: Art(art, size: 28))]),
        ),
        const SizedBox(height: 12),
        if (pile > 0)
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(240, 72), textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 24, fontWeight: FontWeight.w700)),
            onPressed: a.busy || a.finished ? null : _pack,
            icon: const Icon(Icons.inventory_2_rounded, size: 36),
            label: Text('Un paquet de ${q.b}'),
          ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < packets; i++)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), boxShadow: cardShadow, border: Border.all(color: u.onCard, width: 3)),
              // Pas de numéro sur les paquets : les compter, c'est la question.
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 3 * 22.0 + 6,
                  child: Wrap(alignment: WrapAlignment.center, children: [for (var j = 0; j < q.b; j++) Padding(padding: const EdgeInsets.all(1), child: Art(art, size: 20))]),
                ),
              ]),
            ),
        ]),
        const SizedBox(height: 20),
        if (pile == 0) NumberChoices(attempt: a, right: q.a, values: numberChoices(q.a, q.n * 3 + q.b, near: [q.b, q.a + 2])),
      ]),
    );
  }
}
