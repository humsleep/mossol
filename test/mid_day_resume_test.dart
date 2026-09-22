// 하루 도중 앱을 다시 켜도 하트를 다시 쓰지 않고 남은 이벤트부터 이어 간다(통합 테스트에서 찾은 버그).
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget/helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('행동 후 첫 이벤트 도중 재시작 → 같은 이벤트부터, 하트·스탯 그대로', () async {
    final bundle = testBundle();
    final c1 = GameController(bundle: bundle, save: SaveService());
    await c1.init();
    await c1.newGame();
    final s1 = c1.state!;
    expect(await c1.startDay(bundle.config.actions.first), isTrue);
    final heartsAfter = s1.hearts;
    final stats = Map.of(s1.stats);
    final first = c1.current!.id;
    final rest = c1.queuedEventIds;

    // 앱을 끄고 다시 켠다.
    final c2 = GameController(bundle: bundle, save: SaveService());
    await c2.init();
    expect(c2.hasSave, isTrue);
    expect(await c2.continueGame(), isTrue);
    expect(c2.phase, Phase.event);
    expect(c2.current!.id, first);
    expect(c2.queuedEventIds, rest);
    expect(c2.state!.hearts, heartsAfter);
    expect(c2.state!.stats, stats);
  });

  test('선택을 끝낸 이벤트는 다시 나오지 않는다', () async {
    final bundle = testBundle();
    final c1 = GameController(bundle: bundle, save: SaveService());
    await c1.init();
    await c1.newGame();
    await c1.startDay(bundle.config.actions.first);
    final done = c1.current!.id;
    final open = [
      for (var i = 0; i < c1.choices.length; i++)
        if (!c1.choices[i].locked) c1.choices[i].index,
    ];
    c1.choose(open.first, minigameSuccess: true);
    await Future<void>.delayed(Duration.zero);

    final c2 = GameController(bundle: bundle, save: SaveService());
    await c2.init();
    await c2.continueGame();
    expect(c2.current?.id, isNot(done));
    expect(c2.phase, anyOf(Phase.event, Phase.summary));
  });
}
