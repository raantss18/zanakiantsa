import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/activities/quiz.dart';
import 'package:zanakiantsa/ui/theme.dart';

// Énoncés de code (2026-11-08) : les lignes de consigne ne doivent pas tomber dans le bloc de code.
void main() {
  test('lignes de texte et lignes de code', () {
    expect(QuestionText.isProse('Que renvoie cette requête ?'), isTrue);
    expect(QuestionText.isProse('Table eleves (nom, classe, note) :'), isTrue);
    expect(QuestionText.isProse('Que va afficher ce programme ?'), isTrue);
    expect(QuestionText.isProse("SELECT COUNT(*) FROM eleves WHERE classe = '1A';"), isFalse);
    expect(QuestionText.isProse('for i in range(3): print(i)'), isFalse);
    expect(QuestionText.isProse('def f(x):'), isFalse);
    expect(QuestionText.isProse('Rado | 1A | 14'), isFalse);
    expect(QuestionText.isProse('else:'), isFalse);
    expect(QuestionText.isProse('if x > 3:'), isFalse);
  });

  test('la première ligne : consigne si c\'est une phrase, code sinon', () {
    expect(QuestionText.leads('Voici un programme.'), isTrue);
    expect(QuestionText.leads('Le lutin exécute :'), isTrue);
    expect(QuestionText.leads('mettre x à 10'), isFalse, reason: 'vu sur la tablette : une instruction, pas une consigne');
    expect(QuestionText.leads('x = 3'), isFalse);
    expect(QuestionText.leads('x vaut 0.'), isTrue, reason: 'une phrase, même sans majuscule');
    expect(QuestionText.leads("SELECT nom FROM eleves;"), isFalse);
    expect(QuestionText.leads('def f(x):'), isFalse);
  });

  test('le « ? » ne se retrouve jamais seul sur une ligne', () {
    expect(keepTogether('Où va Léa ?'), 'Où va Léa\u00A0?');
    expect(keepTogether('« Quelle belle surprise » !'), '«\u00A0Quelle belle surprise\u00A0»\u00A0!');
    expect(keepTogether('if x > 3:'), 'if x > 3:', reason: 'le code ne change pas');
  });

  test('un mot n\'est jamais coupé sous une image : la police rétrécit', () {
    const style = TextStyle(fontSize: 22);
    expect(WholeWords.fit('le chat', style, 400), 22);
    final small = WholeWords.fit("l'escargot", style, 180);
    expect(small, lessThan(22));
    final tp = TextPainter(text: TextSpan(text: "l'escargot", style: style.copyWith(fontSize: small)), textDirection: TextDirection.ltr)..layout();
    expect(tp.width, lessThanOrEqualTo(180));
  });
}
