// 경계·예외 케이스. 출시 전 수준의 검증.
//
// 실제 스토리 데이터(assets/story)로 100일 완주를 여러 정책·시드로 돌리고,
// 합성 번들(_mini)로 되돌리기·하트·룰렛·검증기 같은 세부 논리를 고정한다.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/conditions.dart';
import 'package:mossol/engine/effects.dart';
import 'package:mossol/engine/ending_resolver.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// 도우미
// ---------------------------------------------------------------------------

StoryBundle loadRealBundle() => StoryBundle.fromJsonStrings(
      config: File('assets/story/config.json').readAsStringSync(),
      characters: File('assets/story/characters.json').readAsStringSync(),
      events: [
        for (final f in StoryBundle.eventFiles)
          File('assets/story/$f').readAsStringSync(),
      ],
      endings: File('assets/story/endings.json').readAsStringSync(),
      knownMinigames: minigameIds,
      requireEndingHints: true,
    );

const _miniConfig = {
  'totalDays': 3,
  'maxHearts': 2,
  'heartRegenMinutes': 30,
  'initialStats': {
    'charm': 50,
    'talk': 20,
    'esteem': 15,
    'sense': 25,
    'money': 30,
    'stress': 40,
    'sincerity': 50,
    'reputation': 30,
  },
  'actions': [
    {
      'id': 'act',
      'name': '행동',
      'effects': {
        'stats': {'charm': 1}
      }
    },
  ],
};

const _miniChars = [
  {'id': 'a', 'name': 'A'},
  {'id': 'b', 'name': 'B'},
];

const _miniEvents = [
  {
    'id': 'e1',
    'layer': 'main',
    'day': 1,
    'character': 'a',
    'cliffhanger': '내일',
    'choices': [
      {
        'text': 'good',
        'effects': {
          'affection': {'*': 5},
          'trust': {'*': 3},
          'stats': {'charm': 2},
          'setFlags': ['f1'],
        },
        'next': 'e2',
      },
      {
        'text': 'always-fail',
        'chance': 0,
        'fail': {
          'affection': {'*': -5},
          'album': '흑역사',
          'setFlags': ['bad'],
        },
      },
      {
        'text': 'clamp',
        'effects': {
          'stats': {'charm': -999, 'money': 99999, 'stress': -999},
          'affection': {'*': 200, 'b': -200},
        },
      },
      {
        'text': 'locked',
        'require': {
          'stats': {'charm': 999}
        },
        'effects': {
          'stats': {'charm': 1}
        },
      },
      {
        'text': 'chance70',
        'chance': 70,
        'effects': {
          'affection': {'*': 4}
        },
        'fail': {
          'affection': {'*': -2}
        },
      },
    ],
  },
  {
    'id': 'e2',
    'layer': 'route',
    'character': 'a',
    'trigger': {
      'affection': {'*': [90, 100]}
    },
    'choices': [
      {
        'text': 'ok',
        'effects': {
          'affection': {'*': 1}
        }
      },
    ],
  },
  {
    'id': 'e3',
    'layer': 'main',
    'day': 2,
    'choices': [
      {'text': 'ok'}
    ],
  },
  {
    'id': 'e4',
    'layer': 'main',
    'day': 3,
    'choices': [
      {'text': 'ok'}
    ],
  },
  {
    'id': 'd1',
    'layer': 'daily',
    'once': false,
    'choices': [
      {
        'text': 'ok',
        'effects': {
          'stats': {'talk': 1}
        }
      }
    ],
  },
];

const _miniEndings = [
  {
    'id': 'imm',
    'name': '즉시',
    'priority': 250,
    'immediate': true,
    'when': {
      'stats': {
        'sincerity': [0, 0]
      }
    },
  },
  {
    'id': 'happy_a',
    'name': 'A',
    'priority': 200,
    'character': 'a',
    'when': {
      'affection': {'*': [80, 100]}
    },
  },
  {'id': 'def', 'name': '기본', 'priority': 0, 'default': true, 'when': {}},
];

StoryBundle miniBundle({
  Object config = _miniConfig,
  Object characters = _miniChars,
  Object events = _miniEvents,
  Object endings = _miniEndings,
  Set<String>? knownMinigames,
}) =>
    StoryBundle.fromJsonStrings(
      config: jsonEncode(config),
      characters: jsonEncode(characters),
      events: [jsonEncode(events)],
      endings: jsonEncode(endings),
      knownMinigames: knownMinigames,
    );

/// 정해진 값을 차례로 돌려주는 난수. 확률·크리티컬 판정을 정확히 고정한다.
class FixedRandom implements Random {
  final List<int> values;
  int _i = 0;
  FixedRandom(this.values);

  @override
  int nextInt(int max) => values[_i++ % values.length] % max;
  @override
  double nextDouble() => nextInt(1 << 20) / (1 << 20);
  @override
  bool nextBool() => nextInt(2) == 1;
}

enum Policy { first, last, best, random }

int _score(Choice c) {
  var s = 0;
  for (final v in c.effects.affection.values) {
    s += v * 3;
  }
  for (final v in c.effects.trust.values) {
    s += v * 2;
  }
  c.effects.stats.forEach((k, v) => s += k == Stat.stress ? -v : v);
  return s;
}

int pickIndex(Policy p, List<ChoiceView> views, Random r) {
  final open = views.where((v) => !v.locked).toList();
  final pool = open.isEmpty ? views : open;
  switch (p) {
    case Policy.first:
      return pool.first.index;
    case Policy.last:
      return pool.last.index;
    case Policy.best:
      var best = pool.first;
      for (final v in pool) {
        if (_score(v.choice) > _score(best.choice)) best = v;
      }
      return best.index;
    case Policy.random:
      return pool[r.nextInt(pool.length)].index;
  }
}

void checkBounds(GameState s, String where) {
  for (final k in Stat.all) {
    expect(s.stat(k), inInclusiveRange(0, Stat.maxOf(k)), reason: '$where $k');
  }
  for (final e in s.relations.entries) {
    expect(e.value.affection, inInclusiveRange(0, 100), reason: '$where ${e.key} 호감');
    expect(e.value.trust, inInclusiveRange(0, 100), reason: '$where ${e.key} 신뢰');
  }
}

/// 엔진만으로 100일을 완주하고 엔딩 id 를 돌려준다.
String simulate(StoryBundle bundle, int seed, Policy policy, {int run = 1}) {
  final engine = EventEngine(bundle);
  final resolver = EndingResolver(bundle.endings);
  final s = GameState.fresh(bundle.config, bundle.characters, seed: seed, run: run);
  final pr = Random(seed * 31 + policy.index);
  final onceSeen = <String>{};
  while (!engine.isFinished(s)) {
    final where = 'seed $seed ${policy.name} ${s.day}일';
    final plan = engine.planDay(s);
    final ids = plan.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length, reason: '$where 계획 중복: $ids');
    for (final ev in plan) {
      if (ev.once) {
        expect(onceSeen.add(ev.id), isTrue, reason: '$where once 이벤트 재등장: ${ev.id}');
        expect(s.seen, isNot(contains(ev.id)), reason: '$where seen 인데 또 계획됨: ${ev.id}');
      }
      final views = engine.choicesFor(s, ev);
      final idx = pickIndex(policy, views, pr);
      final c = ev.choices[idx];
      final forced = c.minigame == null ? null : pr.nextInt(100) < 70;
      final out = engine.applyChoice(s, ev, c, forcedSuccess: forced);
      expect(out.combo, greaterThanOrEqualTo(0));
      checkBounds(s, '$where ${ev.id}');
    }
    engine.endDay(s);
    checkBounds(s, '$where 마감');
    final imm = resolver.immediate(s);
    if (imm != null) {
      expect(bundle.endings, contains(imm));
      return imm.id;
    }
  }
  final e = resolver.resolve(s);
  expect(bundle.endings, contains(e));
  return e.id;
}

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StoryBundle real;
  late EventEngine engine;
  late EndingResolver resolver;

  setUpAll(() {
    registerMinigames();
    real = loadRealBundle();
    engine = EventEngine(real);
    resolver = EndingResolver(real.endings);
  });

  GameState fresh({int seed = 1, int run = 1, int day = 1}) =>
      GameState.fresh(real.config, real.characters, seed: seed, run: run)..day = day;

  // -------------------------------------------------------------------------
  group('스탯 클램프', () {
    test('상한: money 9999, 나머지 100. 하한 0. 실제 변화량만 기록', () {
      final s = fresh();
      s.stats[Stat.charm] = 98;
      s.stats[Stat.money] = 9990;
      s.stats[Stat.stress] = 1;
      final d = applyEffects(
        s,
        const Effects(stats: {
          Stat.charm: 50,
          Stat.money: 1000,
          Stat.stress: -50,
          Stat.talk: -1000,
        }),
      );
      expect(s.stat(Stat.charm), 100);
      expect(s.stat(Stat.money), 9999);
      expect(s.stat(Stat.stress), 0);
      expect(s.stat(Stat.talk), 0);
      expect(d.stats, {Stat.charm: 2, Stat.money: 9, Stat.stress: -1, Stat.talk: -20});
    });

    test('호감·신뢰 0~100, 크리티컬 배수는 상승에만', () {
      final s = fresh();
      s.rel('seoyeon')
        ..affection = 99
        ..trust = 1;
      final d = applyEffects(
        s,
        const Effects(affection: {'seoyeon': 5, 'haneul': -5}, trust: {'seoyeon': -50}),
        affectionMultiplier: 2,
      );
      expect(s.affectionOf('seoyeon'), 100);
      expect(s.trustOf('seoyeon'), 0);
      expect(s.affectionOf('haneul'), 0);
      expect(d.affection, {'seoyeon': 1});
      expect(d.trust, {'seoyeon': -1});
    });

    test('변화가 없으면 delta 가 비어 있다', () {
      final s = fresh();
      final d = applyEffects(s, const Effects(affection: {'seoyeon': -3}, stats: {Stat.talk: 0}));
      expect(d.isEmpty, isTrue);
    });

    test('아침 행동과 룰렛도 음수로 못 내려간다', () {
      final s = fresh();
      s.stats[Stat.money] = 3;
      final style = real.config.actions.firstWhere((a) => a.id == 'style');
      engine.applyAction(s, style);
      expect(s.stat(Stat.money), 0);
      s.stats[Stat.stress] = 0;
      final rest = EventEngine.rouletteSlots.indexWhere((e) => e.$2.containsKey(Stat.stress) && e.$2[Stat.stress]! < 0);
      engine.applyRoulette(s, rest);
      expect(s.stat(Stat.stress), 0);
    });

    test('앨범 10·20 에서 플래그가 선다', () {
      final s = fresh();
      for (var i = 0; i < 20; i++) {
        applyEffects(s, Effects(album: '실패 $i'));
        if (i == 8) expect(s.flags, isNot(contains('album_10')));
        if (i == 9) expect(s.flags, contains('album_10'));
      }
      expect(s.flags, contains('album_20'));
      expect(s.album.length, 20);
    });
  });

  // -------------------------------------------------------------------------
  group('100일 완주', () {
    const seeds = 32;

    for (final policy in Policy.values) {
      test('${policy.name} 정책 · 시드 $seeds개: 예외 없음, 계획 중복 없음, once 재등장 없음, 엔딩 유효', () {
        final tally = <String, int>{};
        for (var seed = 1; seed <= seeds; seed++) {
          final id = simulate(real, seed, policy);
          tally[id] = (tally[id] ?? 0) + 1;
        }
        // 분포는 참고용. 여기서 특정 엔딩을 강제하지 않는다.
        // ignore: avoid_print
        print('[${policy.name}] $tally');
      });
    }

    test('2회차·3회차에서도 완주한다(히든 이벤트 경로)', () {
      for (var seed = 1; seed <= 8; seed++) {
        simulate(real, seed, Policy.best, run: 2);
        simulate(real, seed, Policy.random, run: 3);
      }
    });

    test('같은 시드·같은 정책이면 결과가 완전히 같다(결정성)', () {
      for (var seed = 1; seed <= 5; seed++) {
        expect(simulate(real, seed, Policy.best), simulate(real, seed, Policy.best));
      }
    });

    test('컨트롤러 흐름으로도 완주한다', () async {
      SharedPreferences.setMockInitialValues({});
      for (var seed = 1; seed <= 4; seed++) {
        final c = GameController(bundle: real, save: SaveService());
        await c.newGame(seed: seed);
        final pr = Random(seed);
        var guard = 0;
        while (c.phase != Phase.ending) {
          expect(++guard, lessThan(5000), reason: '무한 루프');
          switch (c.phase) {
            case Phase.action:
              if (c.canSpinRoulette) c.spinRoulette();
              if (c.hearts == 0) c.state!.hearts = 1;
              final ok = await c.startDay(real.config.actions[pr.nextInt(real.config.actions.length)]);
              expect(ok, isTrue);
            case Phase.event:
              while (!c.linesDone) {
                c.revealNext();
              }
              final idx = pickIndex(Policy.random, c.choices, pr);
              final mg = c.current!.choices[idx].minigame;
              c.choose(idx, minigameSuccess: mg == null ? null : pr.nextBool());
              if (c.canOfferUndo && pr.nextInt(4) == 0) c.undoChoice();
              if (c.lastOutcome == null) {
                // 되돌린 뒤엔 다시 고른다.
                c.choose(pickIndex(Policy.random, c.choices, pr),
                    minigameSuccess: c.current!.choices.any((x) => x.minigame != null) ? true : null);
              }
              c.continueAfterChoice();
            case Phase.summary:
              await c.endDay();
            case Phase.home:
            case Phase.ending:
              break;
          }
        }
        expect(c.ending, isNotNull);
        expect(real.endings, contains(c.ending));
        expect(c.hasSave, isFalse);
        expect(c.endingAlbum, contains(c.ending!.id));
      }
    });
  });

  // -------------------------------------------------------------------------
  group('엔딩 30개 도달성', () {
    /// 엔딩 조건만 딱 맞춘 상태를 만든다. 범위 조건은 상한 쪽(100 미만이면) 아니면 하한.
    GameState stateFor(Ending e) {
      final s = fresh(day: 101);
      final w = e.when;
      if (w.run != null) s.run = w.run!.min;
      int pick(Range r, int cap) => r.max < cap ? r.max : r.min;
      w.stats.forEach((k, r) => s.stats[k] = pick(r, Stat.maxOf(k)));
      w.affection.forEach((k, r) => s.rel(k == '*' ? e.character! : k).affection = pick(r, 100));
      w.trust.forEach((k, r) => s.rel(k == '*' ? e.character! : k).trust = pick(r, 100));
      s.flags.addAll(w.flags);
      final any = w.anyAffection;
      if (any != null) {
        final ids = real.characters.where((c) => !c.hidden).map((c) => c.id).take(any.count);
        for (final id in ids) {
          s.rel(id).affection = max(s.affectionOf(id), any.min);
        }
      }
      return s;
    }

    test('모든 엔딩이 조건을 맞추면 실제로 선택된다(우선순위에 가려지지 않음)', () {
      expect(real.endings.length, 30);
      final shadowed = <String>[];
      for (final e in real.endings) {
        final s = stateFor(e);
        expect(e.when.matches(s, self: e.character), isTrue, reason: '${e.id} 조건 구성 실패');
        final got = resolver.resolve(s);
        if (got.id != e.id) shadowed.add('${e.id} → ${got.id}');
      }
      expect(shadowed, isEmpty, reason: '가려진 엔딩');
    });

    test('immediate 엔딩은 immediate() 로도 잡힌다', () {
      for (final e in real.endings.where((e) => e.immediate)) {
        expect(resolver.immediate(stateFor(e))?.id, e.id);
      }
      expect(real.endings.where((e) => e.immediate).map((e) => e.id), unorderedEquals(['pickup_fall', 'burnout']));
    });

    test('happy 는 트러스트가 모자라면 friend/some 으로 내려간다', () {
      final s = fresh(day: 101);
      s.rel('haneul')
        ..affection = 85
        ..trust = 69;
      s.stats[Stat.sincerity] = 60;
      expect(resolver.resolve(s).id, isNot('haneul_happy'));
    });
  });

  // -------------------------------------------------------------------------
  group('immediate 엔딩 · endDay 흐름', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('진정성 0 이면 픽업 몰락으로 즉시 종료, 세이브 삭제', () async {
      final c = GameController(bundle: real, save: SaveService());
      await c.newGame(seed: 1);
      c.state!.stats[Stat.sincerity] = 0;
      await c.endDay();
      expect(c.phase, Phase.ending);
      expect(c.ending?.id, 'pickup_fall');
      expect(c.hasSave, isFalse);
      expect(await c.save.exists(), isFalse);
      expect(c.endingAlbum, ['pickup_fall']);
    });

    test('번아웃 3번째 마감에서 종료, 2번째까지는 계속', () async {
      final c = GameController(bundle: real, save: SaveService());
      await c.newGame(seed: 1);
      final s = c.state!;
      for (var i = 1; i <= 3; i++) {
        s.flags.add('burnout');
        await c.endDay();
        if (i < 3) {
          expect(c.phase, Phase.action, reason: '$i번째');
          expect(s.flags, contains('burnout_$i'));
          expect(s.flags, isNot(contains('burnout_x3')));
        }
      }
      expect(c.ending?.id, 'burnout');
      expect(c.phase, Phase.ending);
    });

    test('100일 마감에서 immediate 가 일반 엔딩보다 먼저', () async {
      final c = GameController(bundle: real, save: SaveService());
      await c.newGame(seed: 1);
      c.state!
        ..day = 100
        ..stats[Stat.sincerity] = 0;
      c.state!.rel('haneul')
        ..affection = 90
        ..trust = 90;
      await c.endDay();
      expect(c.ending?.id, 'pickup_fall');
    });

    test('100일이 지나면 resolve 로 끝난다', () async {
      final c = GameController(bundle: real, save: SaveService());
      await c.newGame(seed: 1);
      c.state!.day = 100;
      await c.endDay();
      expect(c.phase, Phase.ending);
      expect(c.ending?.id, 'forever_solo');
    });
  });

  // -------------------------------------------------------------------------
  group('되돌리기', () {
    late StoryBundle mini;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mini = miniBundle();
    });

    Future<GameController> startedDay() async {
      final c = GameController(bundle: mini, save: SaveService());
      await c.newGame(seed: 1);
      c.state!.rel('a').affection = 20;
      c.state!.combo = 3;
      expect(await c.startDay(mini.config.actions.first), isTrue);
      expect(c.current?.id, 'e1');
      return c;
    }

    test('실패 선택 → 되돌리기: stats/relations/flags/seen/album/combo/dayDelta 완전 원복', () async {
      final c = await startedDay();
      final s = c.state!;
      final before = jsonEncode(s.toJson());
      final dayBefore = jsonEncode(c.dayDelta.stats);
      c.choose(1);
      expect(c.lastOutcome!.success, isFalse);
      expect(s.affectionOf('a'), 15);
      expect(s.album, ['흑역사']);
      expect(s.flags, contains('bad'));
      expect(s.seen, contains('e1'));
      expect(s.combo, 0);
      expect(c.dayDelta.affection['a'], -5);
      expect(c.dayDelta.album, '흑역사');
      expect(c.canOfferUndo, isTrue);

      c.undoChoice();
      expect(jsonEncode(s.toJson()), before, reason: '상태 전체가 선택 직전과 같아야');
      expect(s.combo, 3);
      expect(jsonEncode(c.dayDelta.stats), dayBefore);
      expect(c.dayDelta.affection, isEmpty);
      expect(c.dayDelta.album, isNull);
      expect(c.dayDelta.flags, isEmpty);
      expect(c.lastOutcome, isNull);
      expect(c.undoUsedThisEvent, isTrue);
      expect(c.canOfferUndo, isFalse);
    });

    test('성공 선택의 스탯·앨범 스냅샷이 live 컬렉션과 분리돼 있다', () async {
      final c = await startedDay();
      final s = c.state!;
      c.choose(0);
      expect(s.stat(Stat.charm), 53); // 50 + 행동 1 + 선택 2
      expect(s.flags, contains('f1'));
      c.undoChoice();
      expect(s.stat(Stat.charm), 51);
      expect(s.affectionOf('a'), 20);
      expect(s.trustOf('a'), 0);
      expect(s.flags, isNot(contains('f1')));
      expect(s.seen, isNot(contains('e1')));
    });

    test('next 이벤트는 되돌리면 큐에서 빠진다', () async {
      final c = await startedDay();
      c.choose(0);
      expect(c.queuedEventIds.first, 'e2');
      c.undoChoice();
      expect(c.queuedEventIds, isNot(contains('e2')));
      // 다시 고르면 다시 들어간다. 그리고 큐에 같은 id 가 둘이 되지 않는다.
      c.choose(0);
      expect(c.queuedEventIds.where((id) => id == 'e2').length, 1);
      c.continueAfterChoice();
      expect(c.current?.id, 'e2');
    });

    test('한 이벤트에 두 번 못 쓴다', () async {
      final c = await startedDay();
      final s = c.state!;
      c.choose(1);
      c.undoChoice();
      c.choose(1);
      expect(s.album.length, 1);
      expect(c.canOfferUndo, isFalse);
      c.undoChoice(); // 무시돼야 한다
      expect(s.album.length, 1);
      expect(s.affectionOf('a'), 15);
      expect(c.lastOutcome, isNotNull);
    });

    test('다음 이벤트로 넘어가면 되돌리기가 다시 열린다', () async {
      final c = await startedDay();
      c.choose(1);
      c.undoChoice();
      c.choose(0);
      c.continueAfterChoice();
      expect(c.current?.id, 'e2');
      expect(c.undoUsedThisEvent, isFalse);
      c.choose(0);
      expect(c.canOfferUndo, isFalse, reason: '좋은 결과엔 제안하지 않는다');
      expect(c.state!.affectionOf('a'), 26);
    });

    test('선택 전엔 되돌릴 게 없고, 잘못된 인덱스는 예외', () async {
      final c = await startedDay();
      final before = jsonEncode(c.state!.toJson());
      c.undoChoice();
      expect(jsonEncode(c.state!.toJson()), before);
      expect(() => c.choose(99), throwsRangeError);
      expect(() => c.choose(-1), throwsRangeError);
    });
  });

  // -------------------------------------------------------------------------
  group('하트', () {
    late StoryBundle mini;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mini = miniBundle();
    });
    const per = 30 * 60 * 1000;

    test('회복 계산 경계: 정확히 주기에서 1개, 1ms 모자라면 0개', () {
      final e = EventEngine(mini);
      final s = GameState.fresh(mini.config, mini.characters, seed: 1, nowMs: 1000)..hearts = 0;
      expect(e.regenHearts(s, nowMs: 1000 + per - 1), 0);
      expect(s.hearts, 0);
      expect(s.lastHeartMs, 1000);
      expect(e.regenHearts(s, nowMs: 1000 + per), 1);
      expect(s.hearts, 1);
      expect(s.lastHeartMs, 1000 + per, reason: '남은 시간이 이어져야 한다');
      expect(e.nextHeartInMs(s, nowMs: 1000 + per + 10), per - 10);
    });

    test('최대치를 넘지 않고, 가득 차면 타이머가 지금으로 맞춰진다', () {
      final e = EventEngine(mini);
      final s = GameState.fresh(mini.config, mini.characters, seed: 1, nowMs: 0)..hearts = 0;
      expect(e.regenHearts(s, nowMs: per * 10), 2);
      expect(s.hearts, 2);
      expect(s.lastHeartMs, per * 10);
      expect(e.nextHeartInMs(s, nowMs: per * 10), 0);
      // 가득 찬 상태에서 부르면 타이머만 갱신.
      expect(e.regenHearts(s, nowMs: per * 11), 0);
      expect(s.lastHeartMs, per * 11);
    });

    test('시계가 뒤로 가도 하트가 영원히 막히지 않는다', () {
      final e = EventEngine(mini);
      final s = GameState.fresh(mini.config, mini.characters, seed: 1, nowMs: per * 100)..hearts = 1;
      expect(e.regenHearts(s, nowMs: per * 50), 0);
      expect(s.lastHeartMs, per * 50);
      expect(e.regenHearts(s, nowMs: per * 51), 1);
    });

    test('컨트롤러: 0개면 startDay 가 false, 시간이 지나면 다시 true, grantHeart 는 상한까지', () async {
      var now = 1_000_000;
      final c = GameController(bundle: mini, save: SaveService(), clock: () => now);
      await c.newGame(seed: 1);
      expect(c.hearts, 2);
      expect(await c.startDay(mini.config.actions.first), isTrue);
      expect(c.hearts, 1);
      expect(c.state!.lastHeartMs, now, reason: '가득 찬 상태에서 쓰기 시작한 순간부터 센다');
      await c.endDay();
      expect(await c.startDay(mini.config.actions.first), isTrue);
      expect(c.hearts, 0);
      await c.endDay();
      expect(await c.startDay(mini.config.actions.first), isFalse);
      expect(c.hearts, 0);
      expect(c.nextHeartIn, const Duration(minutes: 30));
      now += per - 1;
      expect(await c.startDay(mini.config.actions.first), isFalse);
      expect(c.nextHeartIn, const Duration(milliseconds: 1));
      now += 1;
      expect(await c.startDay(mini.config.actions.first), isTrue);
      expect(c.hearts, 0);
      await c.grantHeart();
      await c.grantHeart();
      await c.grantHeart();
      expect(c.hearts, 2);
      expect(c.nextHeartIn, Duration.zero);
    });

    test('continueGame 이 오프라인 동안의 회복을 반영한다', () async {
      var now = 5_000_000;
      final c = GameController(bundle: mini, save: SaveService(), clock: () => now);
      await c.newGame(seed: 1);
      await c.startDay(mini.config.actions.first);
      await c.startDay(mini.config.actions.first);
      c.state!.hearts = 0;
      await c.save.save(c.state!);
      now += per * 5;
      final c2 = GameController(bundle: mini, save: SaveService(), clock: () => now);
      expect(await c2.continueGame(), isTrue);
      expect(c2.hearts, 2);
    });
  });

  // -------------------------------------------------------------------------
  group('세이브', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('모든 필드 왕복 보존', () async {
      final s = fresh(seed: 777, run: 3, day: 42);
      s.rel('minjae')
        ..affection = 61
        ..trust = 33
        ..contactedToday = true;
      s.flags.addAll(['a', 'b']);
      s.seen.addAll(['m01', 'd_kakao_01']);
      s.album.addAll(['x', 'y']);
      s.endings.addAll(['forever_solo']);
      s.hearts = 3;
      s.lastHeartMs = 1234567890123;
      s.lastCliffhanger = '내일 뭔가';
      s.combo = 5;
      s.rouletteDay = 42;
      s.stats[Stat.money] = 9999;
      final svc = SaveService();
      await svc.save(s);
      expect(await svc.exists(), isTrue);
      final r = (await svc.load())!;
      expect(r.toJson(), s.toJson());
      expect(r.rel('minjae').contactedToday, isTrue);
      expect(r.lastHeartMs, 1234567890123);
      expect(r.lastCliffhanger, '내일 뭔가');
      expect(r.endings, ['forever_solo']);
      expect(r.run, 3);
    });

    test('손상된 JSON 이면 null 을 돌려주고 세이브를 지운다', () async {
      for (final raw in ['{not json', '[1,2]', '{"foo":1}', '{"day":"x","seed":1}', '']) {
        SharedPreferences.setMockInitialValues({'mossol_save_v1': raw});
        final svc = SaveService();
        expect(await svc.load(), isNull, reason: raw);
        expect(await svc.exists(), isFalse, reason: raw);
      }
    });

    test('구버전 세이브(필드 누락)도 기본값으로 읽힌다', () {
      final r = GameState.fromJson({'day': 5, 'seed': 9});
      expect(r.run, 1);
      expect(r.hearts, 5);
      expect(r.combo, 0);
      expect(r.rouletteDay, 0);
      expect(r.relations, isEmpty);
      expect(r.stat(Stat.charm), 0);
    });

    test('엔딩 앨범은 중복 없이 누적', () async {
      final svc = SaveService();
      await svc.addEnding('a');
      await svc.addEnding('a');
      await svc.addEnding('b');
      expect(await svc.loadEndings(), ['a', 'b']);
    });

    test('toJson 은 live 컬렉션을 공유하지 않는다', () {
      final s = fresh();
      final j = s.toJson();
      s.stats[Stat.charm] = 1;
      s.album.add('z');
      s.flags.add('q');
      expect((j['stats'] as Map)[Stat.charm], real.config.initialStats[Stat.charm]);
      expect(j['album'], isEmpty);
      expect(j['flags'], isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('룰렛', () {
    late StoryBundle mini;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mini = miniBundle();
    });

    test('같은 날 두 번 spin 불가, reroll 은 한 번만, 다음 날 초기화', () async {
      final c = GameController(bundle: mini, save: SaveService());
      await c.newGame(seed: 3);
      final s = c.state!;
      expect(c.canSpinRoulette, isTrue);
      expect(c.canRerollRoulette, isFalse);
      expect(() => c.rerollRoulette(), throwsStateError, reason: '돌리기 전 reroll');

      final slot = c.spinRoulette();
      expect(s.rouletteDay, s.day);
      expect(c.canSpinRoulette, isFalse);
      expect(c.canRerollRoulette, isTrue);
      final afterSpin = jsonEncode(s.stats);
      expect(c.spinRoulette(), slot, reason: '두 번째 spin 은 같은 결과, 효과 없음');
      expect(jsonEncode(s.stats), afterSpin);

      final re = c.rerollRoulette();
      expect(c.rouletteSlot, re);
      expect(c.canRerollRoulette, isFalse);
      final afterRe = jsonEncode(s.stats);
      expect(c.rerollRoulette(), re, reason: '두 번째 reroll 은 무시');
      expect(jsonEncode(s.stats), afterRe);

      await c.endDay();
      expect(c.canSpinRoulette, isTrue);
      expect(c.canRerollRoulette, isFalse);
      expect(c.rouletteSlot, isNull);
    });

    test('룰렛 효과가 그날 정산(dayDelta)에 남는다', () async {
      final c = GameController(bundle: mini, save: SaveService());
      await c.newGame(seed: 5);
      final s = c.state!;
      final before = Map.of(s.stats);
      c.spinRoulette();
      final diff = {
        for (final k in Stat.all)
          if (s.stat(k) != before[k]) k: s.stat(k) - before[k]!,
      };
      expect(diff, isNotEmpty);
      await c.startDay(mini.config.actions.first);
      final expected = Map.of(diff);
      expected[Stat.charm] = (expected[Stat.charm] ?? 0) + 1;
      expect(c.dayDelta.stats, expected);
    });

    test('세이브 복원 뒤에도 같은 날엔 다시 못 돌린다', () async {
      final c = GameController(bundle: mini, save: SaveService());
      await c.newGame(seed: 3);
      c.spinRoulette();
      final c2 = GameController(bundle: mini, save: SaveService());
      expect(await c2.continueGame(), isTrue);
      expect(c2.canSpinRoulette, isFalse);
      expect(c2.canRerollRoulette, isFalse);
      expect(() => c2.spinRoulette(), throwsStateError);
    });

    test('7일마다 대박 칸이 넓어지고 결과는 범위 안', () {
      final n = EventEngine.rouletteSlots.length;
      var lucky7 = 0, lucky8 = 0;
      for (var seed = 0; seed < 400; seed++) {
        final s7 = fresh(seed: seed, day: 7);
        final s8 = fresh(seed: seed, day: 8);
        final a = engine.spinRoulette(s7), b = engine.spinRoulette(s8);
        expect(a, inInclusiveRange(0, n - 1));
        expect(b, inInclusiveRange(0, n - 1));
        if (a == n - 1) lucky7++;
        if (b == n - 1) lucky8++;
      }
      expect(lucky7, greaterThan(lucky8));
    });
  });

  // -------------------------------------------------------------------------
  group('콤보', () {
    late StoryBundle mini;
    late EventEngine e;
    setUp(() {
      mini = miniBundle();
      e = EventEngine(mini);
    });

    GameState ms() => GameState.fresh(mini.config, mini.characters, seed: 1);
    StoryEvent ev() => mini.eventById['e1']!;
    Choice chance70() => ev().choices[4];

    test('크리티컬 확률: 5 + 눈치/20, 물오름 두 배', () {
      final s = ms();
      s.stats[Stat.sense] = 0;
      expect(e.critChance(s), 5);
      s.stats[Stat.sense] = 19;
      expect(e.critChance(s), 5);
      s.stats[Stat.sense] = 20;
      expect(e.critChance(s), 6);
      s.stats[Stat.sense] = 100;
      expect(e.critChance(s), 10);
      s.combo = 3;
      expect(e.critChance(s), 20);
      s.combo = 2;
      expect(e.critChance(s), 10);
    });

    test('물오름 +20%p 가 확률 판정에 실제로 붙는다', () {
      final a = ms();
      final out1 = e.applyChoice(a, ev(), chance70(), random: FixedRandom([85, 99]));
      expect(out1.success, isFalse);
      final b = ms()..combo = 3;
      final out2 = e.applyChoice(b, ev(), chance70(), random: FixedRandom([85, 99]));
      expect(out2.success, isTrue);
      expect(out2.critical, isFalse);
      expect(b.combo, 4);
    });

    test('보정 뒤에도 임계를 넘는 난수는 실패 (70+20=90, 난수 99)', () {
      final s = ms()..combo = 3;
      final out = e.applyChoice(s, ev(), chance70(), random: FixedRandom([99, 99]));
      expect(out.success, isFalse);
      expect(s.combo, 0, reason: '실패는 콤보를 끊는다');
      expect(out.comboBroken, isTrue);
    });

    test('보정 뒤에도 100 을 넘는 값은 clamp (chance 90 + 20 → 100)', () {
      final ev2 = StoryEvent(
        id: 'x',
        layer: EventLayer.daily,
        character: 'a',
        choices: const [
          Choice(text: 't', chance: 90, effects: Effects(affection: {'*': 1})),
        ],
      );
      final s = ms()..combo = 3;
      final out = e.applyChoice(s, ev2, ev2.choices[0], random: FixedRandom([99, 99]));
      expect(out.success, isTrue);
    });

    test('크리티컬은 호감을 두 배, 물오름이면 임계가 두 배', () {
      // choices[0] 은 chance 가 없어 첫 난수가 그대로 크리티컬 판정에 쓰인다.
      // 7 은 기본 임계 5 보다 크고 물오름 임계 10 보다 작아 두 경우를 가른다.
      final a = ms();
      a.stats[Stat.sense] = 0;
      final out1 = e.applyChoice(a, ev(), ev().choices[0], random: FixedRandom([7]));
      expect(out1.critical, isFalse);
      expect(a.affectionOf('a'), 5);
      final b = ms()..combo = 3;
      b.stats[Stat.sense] = 0;
      final out2 = e.applyChoice(b, ev(), ev().choices[0], random: FixedRandom([7]));
      expect(out2.critical, isTrue);
      expect(b.affectionOf('a'), 10);
      expect(b.trustOf('a'), 3, reason: '신뢰는 두 배가 아님');
    });

    test('미니게임 강제 결과: 성공·크리티컬 강제, 실패 시 콤보 끊김', () {
      final a = ms()..combo = 3;
      final out = e.applyChoice(a, ev(), chance70(), forcedSuccess: true, forcedCritical: true, random: FixedRandom([99, 99]));
      expect(out.success, isTrue);
      expect(out.critical, isTrue);
      expect(a.affectionOf('a'), 8);
      expect(a.combo, 4);

      final b = ms()..combo = 3;
      b.rel('a').affection = 10;
      final out2 = e.applyChoice(b, ev(), chance70(), forcedSuccess: false, random: FixedRandom([0, 0]));
      expect(out2.success, isFalse);
      expect(out2.comboBroken, isTrue);
      expect(b.combo, 0);
      expect(b.affectionOf('a'), 8);

      final c = ms();
      final out3 = e.applyChoice(c, ev(), ev().choices[0], forcedSuccess: true, forcedCritical: false, random: FixedRandom([0, 0]));
      expect(out3.critical, isFalse, reason: '난수가 0이어도 강제 false 가 우선');
    });

    test('콤보 시작 신호: 2 → 3 에서 comboStarted', () {
      final s = ms()..combo = 2;
      final o1 = e.applyChoice(s, ev(), ev().choices[0], random: FixedRandom([0, 99]));
      expect(o1.comboStarted, isTrue);
      expect(o1.comboBroken, isFalse);
      expect(o1.combo, 3);
      expect(s.onFire, isTrue);
    });

    test('호감이 깎이면 콤보가 끊기고 신호가 온다', () {
      final s = ms()..combo = 3;
      s.rel('b').affection = 10;
      final o = e.applyChoice(s, ev(), ev().choices[2], random: FixedRandom([0, 99]));
      expect(o.comboBroken, isTrue);
      expect(s.combo, 0);
    });
  });

  // -------------------------------------------------------------------------
  group('EndingResolver 동점·정렬', () {
    Ending mk(String id, int priority, {String? character, Trigger when = Trigger.always, bool def = false}) =>
        Ending(id: id, name: id, tier: 't', priority: priority, character: character, when: when, isDefault: def);

    test('같은 우선순위면 호감도 높은 캐릭터', () {
      final s = fresh();
      s.rel('haneul').affection = 10;
      s.rel('jiwoo').affection = 20;
      final r = EndingResolver([mk('h', 10, character: 'haneul'), mk('j', 10, character: 'jiwoo'), mk('d', 0, def: true)]);
      expect(r.resolve(s).id, 'j');
      s.rel('haneul').affection = 30;
      expect(r.resolve(s).id, 'h');
    });

    test('캐릭터 없는 엔딩끼리 동점이면 파일 순서, 캐릭터 있는 쪽이 있으면 그쪽 우선', () {
      final s = fresh();
      final r1 = EndingResolver([mk('x', 10), mk('y', 10), mk('d', 0, def: true)]);
      expect(r1.resolve(s).id, 'x');
      final r2 = EndingResolver([mk('y', 10), mk('x', 10), mk('d', 0, def: true)]);
      expect(r2.resolve(s).id, 'y');
      final r3 = EndingResolver([mk('x', 10), mk('c', 10, character: 'seoyeon'), mk('d', 0, def: true)]);
      expect(r3.resolve(s).id, 'c', reason: '호감 0 이라도 -1 인 무캐릭터보다 앞');
    });

    test('엔딩이 40개(삽입 정렬 범위 밖)여도 순서가 안정적이다', () {
      final s = fresh();
      final list = [for (var i = 0; i < 40; i++) mk('e$i', 10), mk('d', 0, def: true)];
      expect(EndingResolver(list).resolve(s).id, 'e0');
      final shuffled = List.of(list)..shuffle(Random(1));
      final firstInFile = shuffled.firstWhere((e) => e.priority == 10).id;
      expect(EndingResolver(shuffled).resolve(s).id, firstInFile);
    });

    test('아무것도 안 맞으면 default, default 없으면 마지막', () {
      final s = fresh();
      final never = const Trigger(flags: ['__never__']);
      expect(EndingResolver([mk('a', 5, when: never), mk('d', 0, def: true, when: never), mk('z', 1, when: never)]).resolve(s).id, 'd');
      expect(EndingResolver([mk('a', 5, when: never), mk('z', 1, when: never)]).resolve(s).id, 'z');
    });

    test('immediate 는 immediate 표시된 것만 본다', () {
      final s = fresh();
      final r = EndingResolver([mk('normal', 999), mk('d', 0, def: true)]);
      expect(r.immediate(s), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('StoryBundle.validate', () {
    List<Map<String, Object?>> ev(List<Map<String, Object?>> extra) => [
          {
            'id': 'm1',
            'layer': 'main',
            'day': 1,
            'choices': [
              {'text': 'ok'}
            ]
          },
          ...extra,
        ];
    const endings = [
      {'id': 'd', 'name': 'd', 'default': true, 'when': {}}
    ];

    void expectError(Object events, String fragment, {Object endingsJ = endings, Set<String>? mg}) {
      expect(
        () => miniBundle(events: events, endings: endingsJ, knownMinigames: mg),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains(fragment))),
      );
    }

    test('정상 번들은 통과하고 lint 도 비어 있다', () {
      final b = miniBundle();
      expect(b.events.length, 5);
      expect(b.lint(), isEmpty);
    });

    test('id 중복', () {
      expectError(ev([
        {
          'id': 'm1',
          'layer': 'daily',
          'choices': [
            {'text': 'x'}
          ]
        }
      ]), 'id 중복');
    });

    test('없는 next / failNext', () {
      expectError(ev([
        {
          'id': 'a',
          'layer': 'daily',
          'choices': [
            {'text': 'x', 'next': 'nope'}
          ]
        }
      ]), '없는 next');
      expectError(ev([
        {
          'id': 'a',
          'layer': 'daily',
          'choices': [
            {'text': 'x', 'failNext': 'nope'}
          ]
        }
      ]), '없는 next');
    });

    test('main day 누락 / main 날짜 중복', () {
      expectError(ev([
        {
          'id': 'a',
          'layer': 'main',
          'choices': [
            {'text': 'x'}
          ]
        }
      ]), 'day 가 필요');
      expectError(ev([
        {
          'id': 'a',
          'layer': 'main',
          'day': 1,
          'choices': [
            {'text': 'x'}
          ]
        }
      ]), 'main 날짜 중복');
    });

    test('없는 캐릭터(이벤트·엔딩·효과·조건)', () {
      expectError(ev([
        {
          'id': 'a',
          'layer': 'route',
          'character': 'zzz',
          'choices': [
            {'text': 'x'}
          ]
        }
      ]), '없는 캐릭터 참조');
      expectError(ev([]), '엔딩이 없는 캐릭터', endingsJ: [
        ...endings,
        {'id': 'e', 'name': 'e', 'character': 'zzz', 'when': {}}
      ]);
      expectError(ev([
        {
          'id': 'a',
          'layer': 'daily',
          'choices': [
            {
              'text': 'x',
              'effects': {
                'affection': {'zzz': 1}
              }
            }
          ]
        }
      ]), '없는 캐릭터 키');
      expectError(ev([
        {
          'id': 'a',
          'layer': 'daily',
          'trigger': {
            'trust': {'zzz': [0, 1]}
          },
          'choices': [
            {'text': 'x'}
          ]
        }
      ]), '없는 캐릭터 키');
    });

    test('없는 미니게임', () {
      expectError(ev([
        {
          'id': 'a',
          'layer': 'daily',
          'choices': [
            {'text': 'x', 'minigame': 'ghost'}
          ]
        }
      ]), '없는 미니게임', mg: {'reply_timing'});
    });

    test('없는 스탯 키(효과·실패·조건·require·엔딩·config)', () {
      expectError(ev([
        {
          'id': 'a',
          'layer': 'daily',
          'choices': [
            {
              'text': 'x',
              'effects': {
                'stats': {'charme': 1}
              }
            }
          ]
        }
      ]), '없는 스탯 키');
      expectError(ev([
        {
          'id': 'a',
          'layer': 'daily',
          'choices': [
            {
              'text': 'x',
              'chance': 50,
              'fail': {
                'stats': {'stres': 1}
              }
            }
          ]
        }
      ]), '없는 스탯 키');
      expectError(ev([
        {
          'id': 'a',
          'layer': 'daily',
          'trigger': {
            'stats': {'luck': [0, 1]}
          },
          'choices': [
            {'text': 'x'}
          ]
        }
      ]), '없는 스탯 키');
      expectError(ev([
        {
          'id': 'a',
          'layer': 'daily',
          'choices': [
            {
              'text': 'x',
              'require': {
                'stats': {'luck': 1}
              }
            }
          ]
        }
      ]), '없는 스탯 키');
      expectError(ev([]), '없는 스탯 키', endingsJ: [
        ...endings,
        {
          'id': 'e',
          'name': 'e',
          'when': {
            'stats': {'luck': [0, 1]}
          }
        }
      ]);
      expect(
        () => miniBundle(config: {
          'initialStats': {'luck': 1}
        }),
        throwsA(isA<StateError>()),
      );
    });

    test('선택지 없음 / hint 범위 / chance 범위 / default 없음 / 엔딩 id 중복', () {
      expectError(ev([
        {'id': 'a', 'layer': 'daily', 'choices': []}
      ]), '선택지 없는');
      expectError(ev([
        {
          'id': 'a',
          'layer': 'daily',
          'hint': 3,
          'choices': [
            {'text': 'x'}
          ]
        }
      ]), 'hint');
      expectError(ev([
        {
          'id': 'a',
          'layer': 'daily',
          'choices': [
            {'text': 'x', 'chance': 101}
          ]
        }
      ]), 'chance');
      expectError(ev([]), 'default', endingsJ: [
        {'id': 'x', 'name': 'x', 'when': {}}
      ]);
      expectError(ev([]), '엔딩 id 중복', endingsJ: [...endings, ...endings]);
    });

    test('lint: character 없는 이벤트의 * 사용을 잡는다', () {
      final b = miniBundle(events: ev([
        {
          'id': 'a',
          'layer': 'daily',
          'choices': [
            {
              'text': 'x',
              'effects': {
                'trust': {'*': 1}
              }
            }
          ]
        }
      ]));
      expect(b.lint(), ['a.choices[0].effects: character 없이 * 사용 (효과가 버려짐)']);
    });

    test('실제 데이터의 lint 결과 (알려진 것만)', () {
      // m05 는 character 가 없어서 trust {*: 0} 이 버려진다. 값이 0 이라 실해는 없음.
      expect(real.lint(), ['m05.choices[0].effects: character 없이 * 사용 (효과가 버려짐)']);
    });

    test('아예 깨진 JSON 은 FormatException', () {
      expect(() => miniBundle(events: '{'), throwsA(anything));
      expect(
        () => StoryBundle.fromJsonStrings(config: '{', characters: '[]', events: const [], endings: '[]'),
        throwsFormatException,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('난수 결정성', () {
    test('stableSeed 는 실행·플랫폼에 무관한 고정값', () {
      expect(EventEngine.stableSeed(42, 3, 'daily'), 2559847029);
      expect(EventEngine.stableSeed(0, 0, ''), 3795608245);
      expect(EventEngine.stableSeed(1, 1, 'a'), isNot(EventEngine.stableSeed(1, 1, 'b')));
      expect(EventEngine.stableSeed(1, 1, 'a'), isNot(EventEngine.stableSeed(1, 2, 'a')));
      expect(EventEngine.stableSeed(1, 1, 'a'), isNot(EventEngine.stableSeed(2, 1, 'a')));
    });

    test('세이브를 거쳐 복원한 상태도 같은 계획을 만든다', () {
      final a = fresh(seed: 11, day: 40);
      a.rel('jiwoo').affection = 40;
      final b = GameState.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
      expect(engine.planDay(a).map((e) => e.id), engine.planDay(b).map((e) => e.id));
      expect(engine.rng(a, 'x').nextInt(1 << 30), engine.rng(b, 'x').nextInt(1 << 30));
    });

    test('시드가 다르면 계획이 대체로 다르다(편향 없음)', () {
      final plans = <String>{};
      for (var seed = 0; seed < 50; seed++) {
        final s = fresh(seed: seed, day: 15);
        plans.add(engine.planDay(s).map((e) => e.id).join(','));
      }
      expect(plans.length, greaterThan(5));
    });
  });

  // -------------------------------------------------------------------------
  group('하루 계획 세부', () {
    test('레이어 인덱스가 원본과 일치한다', () {
      for (final l in EventLayer.values) {
        expect(real.eventsByLayer[l]!.length, real.countByLayer[l]);
      }
      expect(() => real.eventsByLayer[EventLayer.main]!.add(real.events.first), throwsUnsupportedError);
    });

    test('위기가 여럿이면 weight 가 가장 큰 하나만', () {
      final s = fresh(day: 60);
      s.stats[Stat.stress] = 95;
      s.stats[Stat.money] = 0;
      s.stats[Stat.esteem] = 0;
      final plan = engine.planDay(s);
      expect(plan.where((e) => e.layer == EventLayer.crisis).length, 1);
      expect(plan.where((e) => e.layer == EventLayer.daily), isEmpty);
    });

    test('호감도 동률이면 시드에 따라 캐릭터가 갈리지만 결정적이다', () {
      final chars = <String>{};
      for (var seed = 0; seed < 40; seed++) {
        final s = fresh(seed: seed, day: 30);
        final r = engine.planDay(s).firstWhere((e) => e.layer == EventLayer.route);
        chars.add(r.character!);
        final again = engine.planDay(fresh(seed: seed, day: 30)).firstWhere((e) => e.layer == EventLayer.route);
        expect(again.id, r.id);
      }
      expect(chars.length, greaterThan(1));
    });

    test('endDay 는 접촉 표시를 매일 초기화하고 lastCliffhanger 를 덮어쓴다', () {
      final s = fresh();
      s.rel('seoyeon')
        ..affection = 5
        ..contactedToday = true;
      engine.endDay(s, cliffhanger: 'a');
      expect(s.rel('seoyeon').contactedToday, isFalse);
      expect(s.lastCliffhanger, 'a');
      engine.endDay(s);
      expect(s.affectionOf('seoyeon'), 4);
      expect(s.lastCliffhanger, isNull);
    });
  });

  test('호감이 오르지 않는 선택지는 크리티컬이 나지 않는다', () {
    final b = StoryBundle.fromJsonStrings(
      config: '{"totalDays":100,"initialStats":{"charm":10},"actions":[]}',
      characters: '[{"id":"a","name":"A","role":"r"}]',
      events: [
        '[{"id":"e","layer":"daily","character":"a","title":"t","lines":[],"choices":['
            '{"text":"cold","effects":{"affection":{"*":-5}}},'
            '{"text":"warm","effects":{"affection":{"*":3}}}]}]',
      ],
      endings: '[{"id":"z","name":"z","tier":"bad","priority":1,"default":true}]',
    );
    final eng = EventEngine(b);
    final ev = b.eventById['e']!;
    final s = GameState.fresh(b.config, b.characters, seed: 1);
    final warm = eng.applyChoice(s, ev, ev.choices[1], forcedCritical: true);
    expect(warm.critical, isTrue);
    expect(warm.delta.affection['a'], 6);
    // 운으로는 몇 번을 굴려도 차가운 선택지에서 크리티컬이 나지 않는다.
    for (var i = 0; i < 300; i++) {
      s.rel('a').affection = 50;
      final cold = eng.applyChoice(s, ev, ev.choices[0], random: Random(i));
      expect(cold.critical, isFalse);
      expect(cold.delta.affection['a'], -5);
    }
  });

  test('@top 은 지금 호감이 가장 높은 한 사람에게만 적용된다', () {
    final b = StoryBundle.fromJsonStrings(
      config: '{"totalDays":100,"initialStats":{"charm":10},"actions":[]}',
      characters: '[{"id":"a","name":"A","role":"r"},{"id":"b","name":"B","role":"r"}]',
      events: [
        '[{"id":"e","layer":"daily","title":"t","lines":[],"choices":['
            '{"text":"x","effects":{"affection":{"@top":4},"trust":{"@top":-2}}}]}]',
      ],
      endings: '[{"id":"z","name":"z","tier":"bad","priority":1,"default":true}]',
    );
    final eng = EventEngine(b);
    final ev = b.eventById['e']!;
    final s = GameState.fresh(b.config, b.characters, seed: 1);

    // 아무와도 가깝지 않으면 아무에게도.
    var out = eng.applyChoice(s, ev, ev.choices[0], forcedCritical: false);
    expect(out.delta.affection, isEmpty);

    s.rel('b').affection = 10;
    s.rel('b').trust = 10;
    out = eng.applyChoice(s, ev, ev.choices[0], forcedCritical: false);
    expect(out.delta.affection, {'b': 4});
    expect(out.delta.trust, {'b': -2});
    expect(s.affectionOf('a'), 0);
  });
}
