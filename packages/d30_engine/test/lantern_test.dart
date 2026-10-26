import 'package:d30_engine/d30_engine.dart';
import 'package:test/test.dart';

import 'support/load_pack.dart';

void main() {
  late ContentPack pack;
  setUp(() => pack = loadPackDirectory('../../fixtures/lantern'));

  EventRun play(Game game, int choice) {
    final run = game.beginOpeningEvent()!;
    var guard = 0;
    while (!run.current!.isEnd && guard++ < 20) {
      final beat = run.current!;
      if (beat.choices.isEmpty) {
        run.advance();
      } else {
        run.choose(beat.choices[choice]);
      }
    }
    return run;
  }

  test('taking the lantern grants the item and sets the switch', () {
    final game = Game.newRun(pack);
    play(game, 0);
    expect(game.state.inventory[601], 1);
    expect(game.state.switchValue('LANTERN_CHOICE'), 1);
    expect(game.state.eventStates[501], 2);
  });

  test('leaving it sets the other branch only', () {
    final game = Game.newRun(pack);
    play(game, 1);
    expect(game.state.inventory[601], isNull);
    expect(game.state.switchValue('LANTERN_CHOICE'), 2);
  });
}
