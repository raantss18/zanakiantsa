import 'dart:math';

import 'package:flutter/material.dart';

import '../content/content.dart';
import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';

/// Choisir : une question écrite et dite, trois images ; on touche la bonne (ADR 0019). Une image essayée reste
/// grisée et barrée ; la démonstration entoure la bonne.
class ChooseActivity extends StatefulWidget {
  const ChooseActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<ChooseActivity> createState() => _ChooseActivityState();
}

class _ChooseActivityState extends State<ChooseActivity> {
  Attempt get a => widget.attempt;
  late final Item item = a.skill.items[a.question.n];
  late final List<Pic> pics = [item.right!, ...item.others]..shuffle(Random(a.question.a));
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

  void _tap(Pic p) {
    if (a.busy || a.finished || tried.contains(p.art)) return;
    final ok = p.art == item.right!.art;
    if (!ok) setState(() => tried.add(p.art));
    a.submit(ok, why: ok ? null : choiceError(a.skill, a.phrase, p));
  }

  /// Lecture (ADR 0031) : le mot est écrit en grand et jamais dit ni étiqueté sous les images — c'est à l'enfant de le lire.
  bool get reading => a.skill.params['lire'] == true;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, k) {
        // Trois cartes côte à côte (la largeur suffit en portrait comme en paysage) ; nom écrit sous chacune.
        final size = min((k.maxWidth - 32) / 3 - 16, k.maxHeight - 90).clamp(96.0, 220.0);
        final cards = [
          for (final p in pics)
            Column(mainAxisSize: MainAxisSize.min, children: [
              PicButton(
                size: size,
                label: p.name,
                tried: tried.contains(p.art),
                highlight: (a.demonstrate || a.solved) && p.art == item.right!.art,
                onPressed: a.busy || a.finished ? null : () => _tap(p),
                child: Art(p.art, size: size * 0.62),
              ),
              if (!reading) const SizedBox(height: 6),
              if (!reading) SizedBox(width: size, child: Text(p.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink))),
            ]),
        ];
        return Center(
          child: PlayScroll(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              if (reading)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
                  child: Text(item.text, style: const TextStyle(fontFamily: 'Andika', fontSize: 64, fontWeight: FontWeight.w700, color: ink)),
                ),
              Wrap(
                alignment: WrapAlignment.center,
                children: [for (final c in cards) Padding(padding: const EdgeInsets.all(8), child: c)],
              ),
            ]),
          ),
        );
      });
}

/// Ce que montre une image fausse (ADR 0048) : d'abord ce que l'enfant a touché, nommé (« Ça, c'est la vache. »),
/// puis, si la compétence le dit (phrase « erreur »), pourquoi ce n'est pas la bonne.
/// Entre guillemets, c'est le mot qu'on compare : sans son article (« tomate », pas « la tomate »).
String choiceError(Skill skill, String Function(String) phrase, Pic chosen) => skill.phrases.containsKey('erreur')
    ? phrase('erreur')
        .replaceAll('« {choisi} »', '« ${chosen.name.replaceFirst(RegExp(r"^(le |la |les |l'|un |une )"), '')} »')
        .replaceAll('{choisi}', chosen.name)
    : thatIs(chosen.name);

/// « Ça, c'est la tête. », « Ça, ce sont les bras. »
String thatIs(String name) => name.startsWith('les ') ? 'Ça, ce sont $name.' : 'Ça, c\'est $name.';
