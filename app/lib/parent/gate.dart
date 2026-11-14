import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'parent.dart';

/// Porte de l'espace parent : une multiplication qu'un enfant de 5–7 ans ne sait pas encore faire.
///
/// Le navigateur est pris avant d'ouvrir la fenêtre : le clavier fait réorganiser l'accueil (ADR 0052), et le bouton qui a
/// ouvert la porte peut ne plus exister à la bonne réponse. On vérifiait `context.mounted` : la page ne s'ouvrait alors
/// jamais, et les mises à jour, qui passent par elle, devenaient inaccessibles.
Future<void> openParentSpace(
  BuildContext context, {
  WidgetBuilder? page,
}) async {
  final navigator = Navigator.of(context);
  final ok = await askParent(context);
  if (ok && navigator.mounted) {
    await navigator.push(
      MaterialPageRoute(builder: page ?? (_) => const ParentPage()),
    );
  }
}

/// Essais de la porte (audit de sécurité du 2026-11-14) : avant, dix réponses possibles et des essais sans limite — un
/// enfant pouvait toutes les essayer. Après [freeTries] erreurs de suite, la porte se ferme 30 s, puis le double à chaque
/// nouvelle erreur (5 min au plus) ; une bonne réponse remet tout à zéro. Gardé en mémoire : relancer l'app redonne trois essais.
class GateLock {
  static const freeTries = 3;
  int failures = 0;
  DateTime? until;

  /// Secondes à attendre encore ; 0 : la porte accepte une réponse.
  int waitSeconds(DateTime now) => until == null || !now.isBefore(until!) ? 0 : (until!.difference(now).inMilliseconds / 1000).ceil();

  void answered(bool ok, DateTime now) {
    if (ok) {
      failures = 0;
      until = null;
      return;
    }
    failures++;
    if (failures >= freeTries) {
      final seconds = min(300, 30 << min(failures - freeTries, 4));
      until = now.add(Duration(seconds: seconds));
    }
  }
}

final gateLock = GateLock();

/// La question de la porte parent seule : vrai si la bonne réponse est donnée (sert aussi à masquer une vidéo).
Future<bool> askParent(BuildContext context) async {
  final wait = gateLock.waitSeconds(DateTime.now());
  if (wait > 0) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Espace parent')),
        content: Text(tf('Trop d’essais. Réessayez dans {s} secondes.', {'s': wait}), style: const TextStyle(fontSize: 20)),
        actions: [TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 52)), onPressed: () => Navigator.pop(ctx), child: Text(t('Annuler')))],
      ),
    );
    return false;
  }
  final r = Random();
  // Un nombre de 12 à 19 par un nombre de 6 à 9 : 32 questions, hors des tables apprises par cœur à l'école.
  final a = 12 + r.nextInt(8), b = 6 + r.nextInt(4);
  final field = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      void submit() => Navigator.pop(ctx, field.text.trim() == '${a * b}');
      final cancel = TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(48, 52)),
        onPressed: () => Navigator.pop(ctx, false),
        child: Text(t('Annuler')),
      );
      final enter = FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(112, 52),
          textStyle: const TextStyle(
            fontFamily: 'Andika',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: submit,
        child: Text(t('Entrer')),
      );
      final input = TextField(
        controller: field,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 22),
        decoration: const InputDecoration(isDense: true),
        onSubmitted: (_) => submit(),
      );
      // En paysage, le clavier laisse environ 360 px : la fenêtre classique (titre, question, champ, boutons) écrasait la
      // question à zéro. Quand la place manque, le champ et les boutons tiennent sur une ligne.
      final compact =
          MediaQuery.sizeOf(ctx).height - MediaQuery.viewInsetsOf(ctx).bottom <
          420;
      return Dialog(
        insetPadding: compact
            ? const EdgeInsets.symmetric(horizontal: 40, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 680 : 520),
          child: SingleChildScrollView(
            padding: compact
                ? const EdgeInsets.fromLTRB(20, 10, 20, 10)
                : const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En compact, le titre cède sa ligne (il reste lu par le lecteur d'écran) : la question suffit.
                if (!compact) ...[
                  Text(
                    t('Espace parent'),
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  tf('Combien font {a} × {b} ?', {'a': a, 'b': b}),
                  semanticsLabel:
                      '${t('Espace parent')}${english ? ':' : ' :'} ${tf('Combien font {a} × {b} ?', {'a': a, 'b': b})}',
                  style: TextStyle(fontSize: compact ? 18 : 22),
                ),
                if (compact)
                  Row(
                    children: [
                      Expanded(child: input),
                      const SizedBox(width: 8),
                      cancel,
                      const SizedBox(width: 8),
                      enter,
                    ],
                  )
                else ...[
                  input,
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [cancel, const SizedBox(width: 8), enter],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
  // « Annuler » (null ou faux sans réponse saisie) ne compte pas comme un essai.
  if (ok == true || field.text.trim().isNotEmpty) gateLock.answered(ok == true, DateTime.now());
  return ok == true;
}
