import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/engine.dart';
import 'package:zanakiantsa/core/game.dart';

// Comptages de référence du générateur de coups (« perft »), publiés par la communauté des programmeurs d'échecs :
// https://www.chessprogramming.org/Perft_Results (position de départ, « Kiwipete », position 3).
void main() {
  test('perft position de départ : 20, 400, 8902', () {
    final p = Position.start();
    expect([1, 2, 3].map((d) => perft(p, d)), [20, 400, 8902]);
  });
  test('perft Kiwipete (roques, prises en passant, promotions) : 48, 2039', () {
    final p = Position.fen('r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
    expect([1, 2].map((d) => perft(p, d)), [48, 2039]);
  });
  test('perft position 3 (pions, en passant, échecs à la découverte) : 14, 191, 2812', () {
    final p = Position.fen('8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1');
    expect([1, 2, 3].map((d) => perft(p, d)), [14, 191, 2812]);
  });
  test('perft position 4 (promotions, roques perdus) : 6, 264', () {
    final p = Position.fen('r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1');
    expect([1, 2].map((d) => perft(p, d)), [6, 264]);
  });

  test('mat du berger, pat, matériel insuffisant, notation', () {
    final g = Game();
    for (final m in ['e2e4', 'e7e5', 'f1c4', 'b8c6', 'd1h5', 'g8f6']) {
      g.play(Move.parse(m));
    }
    expect(g.position.san(Move.parse('h5f7')), 'Dxf7#');
    g.play(Move.parse('h5f7'));
    expect(g.end, GameEnd.checkmate);
    expect(g.result, '1-0');
    expect(Game(start: Position.fen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1')).end, GameEnd.stalemate);
    expect(Game(start: Position.fen('7k/8/6K1/8/8/8/8/5B2 w - - 0 1')).end, GameEnd.insufficient);
    expect(Position.start().san(Move.parse('g1f3')), 'Cf3');
    expect(Position.fen('4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1').san(Move.parse('e1g1')), 'O-O');
  });

  test('triple répétition', () {
    final g = Game();
    for (var i = 0; i < 2; i++) {
      for (final m in ['g1f3', 'g8f6', 'f3g1', 'f6g8']) {
        g.play(Move.parse(m));
      }
    }
    expect(g.end, GameEnd.repetition);
  });

  group('Robot et analyse (ADR 0040)', () {
    test('le robot (niveaux 2 et 3) prend une dame offerte et fait mat en un', () {
      final free = Position.fen('4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1').fen;
      for (final level in [2, 3]) {
        expect(robotMove((free, level, 1)), 'd1d5');
      }
      final mate = Position.fen('6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1').fen;
      expect(robotMove((mate, 3, 1)), 'a1a8');
    });
    test('le robot joue toujours un coup permis, à tous les niveaux', () {
      final g = Game();
      for (var i = 0; i < 16 && g.end == null; i++) {
        final u = robotMove((g.position.fen, 1 + i % 3, i));
        expect(g.position.isLegal(Move.parse(u)), isTrue);
        g.play(Move.parse(u));
      }
    });
    test('l\'analyse voit le mat manqué, la pièce laissée en prise et la prise gratuite manquée', () {
      // Les Blancs ont Ta8# mais jouent Ta2.
      var n = analyseGame(('6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1', ['a1a2'], true));
      expect(n.single['kind'], 'mat_manque');
      expect(n.single['better'], 'a1a8');
      // La dame va en d5, où le pion e6 la prend.
      n = analyseGame(('4k3/8/4p3/8/8/8/8/3QK3 w - - 0 1', ['d1d5'], true));
      expect(n.single['kind'], 'gaffe');
      expect(n.single['text'], contains('la dame'));
      // Une tour noire non protégée en a4, la dame blanche ne la prend pas.
      n = analyseGame(('4k3/8/8/8/r7/8/8/3QK3 w - - 0 1', ['e1e2'], true));
      expect(n.single['kind'], 'prise_manquee');
      expect(n.single['better'], 'd1a4');
    });
  });
}
