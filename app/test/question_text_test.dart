import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/activities/quiz.dart';

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
}
