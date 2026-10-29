/// Student XP (mirrors d30mode's test): an E-tier book gives `study.expPerStudy`
/// and each tier above adds `study.expPerTier`.
library;

import 'dart:convert';

import 'package:d30_engine/d30_engine.dart';
import 'package:test/test.dart';

import 'stamina_defaults_test.dart' show action, gameWith;

Map<String, String> booksOfEveryTier() => {
  'books.json': jsonEncode({
    'books': [
      for (var rank = 1; rank <= 6; rank++)
        {'id': rank, 'name': 'Book $rank', 'subject': 'craft', 'power': rank, 'doneCount': 99, 'bookRank': '$rank'},
    ],
  }),
};

num xpOf(Game game, int id) {
  game.state.hp = game.pack.rules.hpMax;
  final before = game.state.studyExp;
  game.act(game.pack.locations[801]!.actions.first, book: game.pack.books[id]);
  return game.state.studyExp - before;
}

void main() {
  test('the default is 100 for an E book and 100 more for each tier above', () {
    final game = gameWith([action('study')], extraFiles: booksOfEveryTier());
    expect(game.pack.rules.studyExp, 100);
    expect(game.pack.rules.studyExpPerTier, 100);
    expect([for (var id = 1; id <= 6; id++) xpOf(game, id)], [100, 200, 300, 400, 500, 600]);
  });

  test("a pack's own numbers rule", () {
    final game = gameWith(
      [action('study')],
      extraFiles: booksOfEveryTier(),
      rules: {
        'study': {'expPerStudy': 25, 'expPerTier': 10},
      },
    );
    expect([for (var id = 1; id <= 6; id++) xpOf(game, id)], [25, 35, 45, 55, 65, 75]);
  });
}
