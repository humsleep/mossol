// 오프닝(1~3일차) 콘텐츠 검증.
// 첫 세션이 곧 첫인상이다. 1·2일차가 이벤트 하나로 끝나지 않는지,
// 오프닝 이벤트가 4일차 이후의 기존 풀을 잠식하지 않는지 고정한다.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';

import 'widget/helpers.dart';

StoryBundle loadBundle() => StoryBundle.fromJsonStrings(
      config: File('assets/story/config.json').readAsStringSync(),
      characters: File('assets/story/characters.json').readAsStringSync(),
      events: [
        for (final f in StoryBundle.eventFiles)
          File('assets/story/$f').readAsStringSync(),
      ],
      endings: File('assets/story/endings.json').readAsStringSync(),
      knownMinigames: minigameIds,
    );

/// 1~3일차에 단독으로 뽑히는 오프닝 일상 이벤트.
const openingDaily = [
  'd_open_bet',
  'd_open_groupchat',
  'd_open_story',
  'd_open_wrong_number',
  'd_open_app_match',
  'd_open_late_msg',
  'd_open_pfp_who',
  'd_open_outfit',
  'd_open_meme',
  'd_open_hello',
];

/// `next` 로만 이어지는 2단 이벤트. 단독으로는 절대 계획되지 않아야 한다.
const openingChained = ['d_open_bet_2', 'd_open_wrong_number_2'];

/// 루트 첫 접촉. r01(3일차~) 앞에 온다.
const openingRoute = ['seoyeon_r00', 'haneul_r00', 'minjae_r00', 'yeeun_r00'];

const openingAll = [...openingDaily, ...openingChained, ...openingRoute];

const seeds = 20;

void main() {
  late StoryBundle bundle;
  late EventEngine engine;

  setUpAll(() {
    registerMinigames();
    bundle = loadBundle();
    engine = EventEngine(bundle);
  });

  GameState fresh(int seed) =>
      GameState.fresh(bundle.config, bundle.characters, seed: seed);

  /// 잠기지 않고 확률·미니게임도 없는 첫 선택지로 하루를 소화한다.
  /// 위젯 플로우 테스트(plainChoiceIndex)와 같은 정책이라 오프닝이 그 테스트를
  /// 깨뜨리지 않는지도 함께 확인된다.
  void playPlain(GameState s, List<StoryEvent> plan) {
    final queue = List.of(plan);
    while (queue.isNotEmpty) {
      final ev = queue.removeAt(0);
      final view = engine.choicesFor(s, ev).firstWhere(
            (v) => !v.locked && v.choice.chance == null && v.choice.minigame == null,
            orElse: () => throw StateError('${ev.id}: 잠기지 않은 무판정 선택지가 없다'),
          );
      final out = engine.applyChoice(s, ev, view.choice);
      final next = out.nextEventId;
      if (next != null) {
        queue.removeWhere((e) => e.id == next);
        queue.insert(0, engine.byId(next)!);
      }
    }
  }

  group('오프닝 데이터', () {
    test('오프닝 이벤트가 전부 로드되고 검증을 통과한다', () {
      for (final id in openingAll) {
        expect(bundle.eventById[id], isNotNull, reason: '$id 없음');
      }
      for (final id in [...openingDaily, ...openingChained]) {
        final e = bundle.eventById[id]!;
        expect(e.layer, EventLayer.daily, reason: id);
        expect(e.once, isTrue, reason: '$id 는 once 여야 한다');
        expect(e.character, isNull, reason: id);
      }
      for (final id in openingRoute) {
        final e = bundle.eventById[id]!;
        expect(e.layer, EventLayer.route, reason: id);
        expect(e.once, isTrue, reason: id);
        expect(e.character, isNotNull, reason: id);
        expect(e.trigger.affection['*']?.max, lessThanOrEqualTo(15),
            reason: '$id 는 호감 15 이하에서만 나와야 r01 앞에 온다');
        expect(e.trigger.day?.min, 1, reason: id);
      }
    });

    test('일상 오프닝은 day [1, 3~4]·weight 3~5, 2단 이벤트는 단독 트리거 불가', () {
      for (final id in openingDaily) {
        final e = bundle.eventById[id]!;
        expect(e.trigger.day?.min, 1, reason: id);
        expect(e.trigger.day?.max, inInclusiveRange(3, 4), reason: id);
        expect(e.weight, inInclusiveRange(3, 5), reason: id);
      }
      for (final id in openingChained) {
        final e = bundle.eventById[id]!;
        final day = e.trigger.day;
        expect(day, isNotNull, reason: id);
        expect(day!.max, lessThan(1), reason: '$id 는 day 로 잠겨 있어야 한다');
        // 실제로 어딘가에서 next 로 참조되는지.
        final referenced = bundle.events.any(
          (ev) => ev.choices.any((c) => c.next == id || c.failNext == id),
        );
        expect(referenced, isTrue, reason: '$id 를 next 로 잇는 이벤트가 없다');
      }
    });

    test('선택지 규칙: chance/minigame 엔 fail, minigame 엔 require 없음, 무판정 선택지 하나 이상', () {
      final s = fresh(1);
      for (final id in openingAll) {
        final e = bundle.eventById[id]!;
        expect(e.choices, isNotEmpty, reason: id);
        for (var i = 0; i < e.choices.length; i++) {
          final c = e.choices[i];
          final where = '$id.choices[$i]';
          if (c.chance != null || c.minigame != null) {
            expect(c.fail, isNot(same(Effects.none)), reason: '$where: fail 필요');
          }
          if (c.minigame != null) {
            expect(c.require, isNull, reason: '$where: 미니게임 선택지엔 require 금지');
            expect(c.chance, isNull, reason: '$where: minigame 과 chance 는 함께 쓰지 않는다');
            expect(minigameIds, contains(c.minigame), reason: where);
          }
        }
        // 초기 스탯에서 잠기지 않은 무판정 선택지. 위젯 플로우 테스트가 이걸 전제한다.
        final plain = engine.choicesFor(s, e).where(
              (v) => !v.locked && v.choice.chance == null && v.choice.minigame == null,
            );
        expect(plain, isNotEmpty, reason: '$id: 초기 스탯에서 고를 수 있는 무판정 선택지가 없다');
        if (e.hint != null) {
          expect(e.hint, inInclusiveRange(0, e.choices.length - 1), reason: id);
        }
      }
    });

    test('재미 요소 분포: 미니게임 3+, 확률 3+, 클리프행어 절반 이상, 2단 분기 1+', () {
      final pool = [...openingDaily, ...openingChained].map((id) => bundle.eventById[id]!);
      final withMinigame = pool.where((e) => e.choices.any((c) => c.minigame != null)).length;
      final withChance = pool.where((e) => e.choices.any((c) => c.chance != null)).length;
      final withCliff = pool.where((e) => e.cliffhanger != null).length;
      final withNext = pool.where((e) => e.choices.any((c) => c.next != null)).length;
      final withAlbum = pool
          .where((e) => e.choices.any((c) => c.fail.album != null || c.effects.album != null))
          .length;
      expect(withMinigame, greaterThanOrEqualTo(3));
      expect(withChance, greaterThanOrEqualTo(3));
      expect(withCliff * 2, greaterThanOrEqualTo(pool.length), reason: '클리프행어 절반 이상');
      expect(withNext, greaterThanOrEqualTo(1));
      expect(withAlbum, greaterThanOrEqualTo(3), reason: '흑역사 앨범 실패가 첫 세션에 보여야 한다');
    });

    test('효과 크기는 초반 균형(±4 이내, 돈 ±10 이내)', () {
      for (final id in openingAll) {
        final e = bundle.eventById[id]!;
        for (final c in e.choices) {
          for (final fx in [c.effects, c.fail]) {
            fx.stats.forEach((k, v) {
              final cap = k == Stat.money ? 10 : (k == Stat.stress ? 6 : 4);
              expect(v.abs(), lessThanOrEqualTo(cap), reason: '$id $k=$v');
            });
            for (final v in [...fx.affection.values, ...fx.trust.values]) {
              expect(v.abs(), lessThanOrEqualTo(4), reason: '$id 호감/신뢰 $v');
            }
          }
        }
      }
    });
  });

  group('1~3일차 계획', () {
    test('시드 $seeds개: 1일차·2일차 planDay 가 3개 이상, 3일차도 3개 이상', () {
      final minPer = <int, int>{1: 99, 2: 99, 3: 99};
      final sumPer = <int, int>{1: 0, 2: 0, 3: 0};
      final minCand = <int, int>{1: 99, 2: 99, 3: 99};
      final sumCand = <int, int>{1: 0, 2: 0, 3: 0};
      for (var seed = 1; seed <= seeds; seed++) {
        final s = fresh(seed);
        for (var day = 1; day <= 3; day++) {
          expect(s.day, day);
          final cand = engine.candidates(s, EventLayer.daily).length +
              engine.candidates(s, EventLayer.route).length +
              engine.candidates(s, EventLayer.main).length;
          final plan = engine.planDay(s);
          expect(plan.length, greaterThanOrEqualTo(3),
              reason: '시드 $seed $day일차 계획이 ${plan.map((e) => e.id)}');
          if (day <= 2) {
            expect(plan.first.id, 'm0$day', reason: '메인이 먼저');
            expect(plan.any((e) => e.layer == EventLayer.route), isTrue,
                reason: '시드 $seed $day일차에 루트 첫 접촉이 없다');
            expect(plan.any((e) => e.layer == EventLayer.daily), isTrue,
                reason: '시드 $seed $day일차에 일상이 없다');
          }
          minPer[day] = plan.length < minPer[day]! ? plan.length : minPer[day]!;
          sumPer[day] = sumPer[day]! + plan.length;
          minCand[day] = cand < minCand[day]! ? cand : minCand[day]!;
          sumCand[day] = sumCand[day]! + cand;
          playPlain(s, plan);
          engine.endDay(s);
        }
      }
      for (final day in [1, 2, 3]) {
        print('[오프닝] $day일차 계획 min ${minPer[day]} avg ${(sumPer[day]! / seeds).toStringAsFixed(2)}'
            ' · 후보(main+daily+route) min ${minCand[day]} avg ${(sumCand[day]! / seeds).toStringAsFixed(1)}');
      }
    });

    test('1·2일차 루트는 r00 이고, 3일차부터 그 캐릭터의 r01 이 열린다', () {
      for (var seed = 1; seed <= seeds; seed++) {
        final s = fresh(seed);
        final seenRoute = <String>[];
        for (var day = 1; day <= 2; day++) {
          final plan = engine.planDay(s);
          final route = plan.firstWhere((e) => e.layer == EventLayer.route);
          expect(route.id, endsWith('_r00'), reason: '시드 $seed $day일차 루트 ${route.id}');
          expect(seenRoute, isNot(contains(route.id)), reason: '같은 r00 이 이틀 연속');
          seenRoute.add(route.id);
          playPlain(s, plan);
          engine.endDay(s);
        }
        // 3일차: r00 을 본 캐릭터는 r01 후보가 열려 있고, 무판정 선택으로 올린
        // 호감(2~3)이 r01 구간 [0,45] 안에 있다.
        final routes = engine.candidates(s, EventLayer.route).map((e) => e.id).toList();
        for (final r00 in seenRoute) {
          final ch = bundle.eventById[r00]!.character!;
          expect(routes, contains('${ch}_r01'), reason: '시드 $seed: $ch r01 이 3일차에 안 열림');
          expect(routes, isNot(contains(r00)), reason: 'once 인데 다시 후보');
        }
      }
    });

    test('컨트롤러 newGame → startDay 로도 1일차 큐가 3개 이상', () async {
      for (var seed = 1; seed <= seeds; seed++) {
        final c = await makeController();
        await c.newGame(seed: seed);
        final started = await c.startDay(c.config.actions.first);
        expect(started, isTrue);
        expect(c.phase, Phase.event);
        expect(c.current!.id, 'm01');
        // current 하나 + 남은 큐.
        expect(1 + c.queuedEventIds.length, greaterThanOrEqualTo(3),
            reason: '시드 $seed: ${c.current!.id} + ${c.queuedEventIds}');
      }
    });
  });

  group('4일차 이후 격리', () {
    test('일상 오프닝(2단 포함)은 4일차부터 후보에 들지 않는다', () {
      for (var seed = 1; seed <= 5; seed++) {
        for (var day = 4; day <= bundle.config.totalDays; day++) {
          final s = fresh(seed)..day = day;
          final ids = engine.candidates(s, EventLayer.daily).map((e) => e.id).toSet();
          final leaked = ids.intersection({...openingDaily, ...openingChained});
          expect(leaked, isEmpty, reason: '$day일차 일상 후보에 오프닝이 남음: $leaked');
        }
      }
    });

    test('2단 이벤트는 어떤 날에도 단독 후보가 아니다', () {
      for (var day = 1; day <= bundle.config.totalDays; day++) {
        final s = fresh(3)..day = day;
        final ids = engine.candidates(s, EventLayer.daily).map((e) => e.id);
        expect(ids, isNot(anyOf(openingChained.map(contains).toList())), reason: '$day일차');
      }
    });

    test('r00 은 호감 16 이상이면 닫히고, 그 뒤엔 r01 이 받는다', () {
      for (final id in openingRoute) {
        final e = bundle.eventById[id]!;
        final ch = e.character!;
        final s = fresh(2)..day = 5;
        s.rel(ch).affection = 16;
        final routes = engine.candidates(s, EventLayer.route).map((e) => e.id).toList();
        expect(routes, isNot(contains(id)), reason: '$id 가 호감 16 에서 열려 있다');
        expect(routes, contains('${ch}_r01'), reason: '$ch r01 이 호감 16·5일차에 닫혀 있다');
      }
    });

    test('4일차 이후 기존 풀 잠식 없음: 10일차 일상 후보 수가 오프닝 추가 전과 같다', () {
      final s = fresh(1)..day = 10;
      final ids = engine.candidates(s, EventLayer.daily).map((e) => e.id).toSet();
      expect(ids.where((id) => id.startsWith('d_open_')), isEmpty);
    });
  });
}
