import 'dart:math';

import 'package:flutter/material.dart';

import 'parent.dart';

/// Porte de l'espace parent : une multiplication qu'un enfant de 5–7 ans ne sait pas encore faire.
Future<void> openParentSpace(BuildContext context) async {
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
        FilledButton(onPressed: () => Navigator.pop(ctx, field.text.trim() == '${a * b}'), child: const Text('Entrer')),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParentPage()));
  }
}
