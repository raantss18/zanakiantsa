import 'dart:math';

import 'package:flutter/material.dart';

import 'parent.dart';

/// Porte de l'espace parent : une multiplication qu'un enfant de 5–7 ans ne sait pas encore faire.
///
/// Le navigateur est pris avant d'ouvrir la fenêtre : le clavier fait réorganiser l'accueil (ADR 0052), et le bouton qui a
/// ouvert la porte peut ne plus exister à la bonne réponse. On vérifiait `context.mounted` : la page ne s'ouvrait alors
/// jamais, et les mises à jour, qui passent par elle, devenaient inaccessibles.
Future<void> openParentSpace(BuildContext context, {WidgetBuilder? page}) async {
  final navigator = Navigator.of(context);
  final r = Random();
  final a = 6 + r.nextInt(4), b = 6 + r.nextInt(4);
  final field = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Espace parent'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Combien font $a × $b ?', style: const TextStyle(fontSize: 22)),
        TextField(
          controller: field,
          autofocus: true,
          keyboardType: TextInputType.number,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim() == '${a * b}'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(112, 52), textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 20, fontWeight: FontWeight.w700)),
          onPressed: () => Navigator.pop(ctx, field.text.trim() == '${a * b}'),
          child: const Text('Entrer'),
        ),
      ],
    ),
  );
  if (ok == true && navigator.mounted) {
    await navigator.push(MaterialPageRoute(builder: page ?? (_) => const ParentPage()));
  }
}
