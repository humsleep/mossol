import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/conditions.dart';
import 'package:mossol/engine/ending_resolver.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';

StoryBundle loadBundle() => StoryBundle.fromJsonStrings(
  config: File('assets/story/config.json').readAsStringSync(),
  characters: File('assets/story/characters.json').readAsStringSync(),
  events: [
    for (final f in StoryBundle.eventFiles)
      File('assets/story/$f').readAsStringSync(),
  ],
  endings: File('assets/story/endings.json').readAsStringSync(),
  signals: File('assets/story/signals.json').existsSync()
      ? File('assets/story/signals.json').readAsStringSync()
      : null,
  knownMinigames: minigameIds,
  requireEndingHints: true,
);

void main() {
  late StoryBundle bundle;
  late EventEngine engine;
  late EndingResolver resolver;

  setUpAll(() {
    registerMinigames();
    bundle = loadBundle();
    engine = EventEngine(bundle);
    resolver = EndingResolver(bundle.endings);
  });

  GameState fresh({int seed = 42, int run = 1}) =>
      GameState.fresh(bundle.config, bundle.characters, seed: seed, run: run);

  group('데이터 로드', () {
    // 모먼트(events_moments.json, id 접두사 mo_)는 작가가 계속 채우는 파일이라
    // 분량 고정 검사에서 뺀다. 모먼트 규칙은 test/moments_test.dart 가 본다.
    bool isMomentFile(StoryEvent e) => e.id.startsWith('mo_');
    List<StoryEvent> baseEvents() => [
      for (final e in bundle.events)
        if (!isMomentFile(e)) e,
    ];

    test('스토리 파일 전체가 검증을 통과한다', () {
      expect(bundle.characters.length, 12);
      expect(baseEvents().length, 377);
      expect(bundle.endings.length, 48);
      expect(bundle.endings.where((e) => e.isDefault).length, 1);
    });

    test('엔딩 48개 전부에 사람이 쓴 한 줄 힌트가 있고, 검증기가 누락을 잡는다', () {
      for (final e in bundle.endings) {
        final h = (e.hint ?? '').trim();
        expect(h, isNotEmpty, reason: '${e.id} hint 없음');
        expect(
          h.length,
          inInclusiveRange(8, 30),
          reason: '${e.id}: "$h" 는 한 줄 힌트 길이가 아니다',
        );
        expect(
          h,
          isNot(matches(RegExp(r'[0-9]'))),
          reason: '${e.id}: 수치("호감 60") 금지 → "$h"',
        );
        expect(h, isNot(contains('이상')), reason: '${e.id}: 기계 문장 금지 → "$h"');
      }
      expect(
        () => bundle.validate(
          knownMinigames: minigameIds,
          requireEndingHints: true,
        ),
        returnsNormally,
      );
      final broken = StoryBundle(
        config: bundle.config,
        characters: bundle.characters,
        events: bundle.events,
        endings: [
          for (final e in bundle.endings)
            e.id == 'forever_solo'
                ? Ending(
                    id: e.id,
                    name: e.name,
                    tier: e.tier,
                    priority: e.priority,
                    when: e.when,
                    isDefault: true,
                  )
                : e,
        ],
      );
      expect(
        () => broken.validate(requireEndingHints: true),
        throwsA(isA<StateError>()),
      );
      expect(
        () => broken.validate(),
        returnsNormally,
        reason: '기본값은 합성 번들을 위해 끈다',
      );
    });

    test('레이어별 분량이 기획대로다', () {
      final byLayer = {for (final l in EventLayer.values) l: 0};
      for (final e in baseEvents()) {
        byLayer[e.layer] = byLayer[e.layer]! + 1;
      }
      expect(byLayer, {
        EventLayer.main: 51,
        EventLayer.route: 189,
        EventLayer.daily: 105,
        EventLayer.crisis: 16,
        EventLayer.hidden: 16, // h_* 15 + 유나 첫 만남(yuna_r00)
      });
    });

    test('캐릭터마다 루트 이벤트가 15개씩, 오프닝 r00 이 있는 9명은 16개', () {
      const withR00 = {
        'seoyeon', 'haneul', 'minjae', 'yeeun', //
        'jeongwoo', 'daeun', 'sohee', 'geonwoo', 'seunghyun',
      };
      for (final c in bundle.characters) {
        final n = baseEvents()
            .where((e) => e.layer == EventLayer.route && e.character == c.id)
            .length;
        expect(n, withR00.contains(c.id) ? 16 : 15, reason: '${c.name} 루트');
      }
    });

    test('메인 이벤트가 1일부터 100일까지 고르게 깔려 있다', () {
      final days =
          bundle.events
              .where((e) => e.layer == EventLayer.main)
              .map((e) => e.day!)
              .toList()
            ..sort();
      expect(days.first, 1);
      expect(days.last, 100);
      for (var i = 1; i < days.length; i++) {
        expect(
          days[i] - days[i - 1],
          lessThanOrEqualTo(4),
          reason: '${days[i]}일 앞이 빔',
        );
      }
    });

    test('미니게임 12종이 전부 등록되고 전부 쓰인다', () {
      expect(minigameIds.length, 12);
      expect(minigameLabels.keys.toSet(), minigameIds);
      expect(bundle.referencedMinigames, minigameIds, reason: '안 쓰이는 미니게임이 있음');
    });

    test('미니게임 선택지는 실패 효과가 있고 확률과 겹치지 않는다', () {
      var n = 0;
      for (final e in bundle.events) {
        for (final c in e.choices) {
          if (c.minigame == null) continue;
          n++;
          expect(c.chance, isNull, reason: '${e.id}: 확률과 미니게임이 겹침');
          final f = c.fail;
          final hasFail =
              f.stats.isNotEmpty ||
              f.affection.isNotEmpty ||
              f.trust.isNotEmpty ||
              f.album != null;
          expect(hasFail, isTrue, reason: '${e.id}: 실패해도 아무 일이 없음');
        }
      }
      expect(n, greaterThanOrEqualTo(100), reason: '미니게임 배치가 너무 적음');
      expect(n, lessThan(bundle.events.length), reason: '모든 이벤트에 붙으면 지루함');
    });

    test('미니게임은 잠긴 선택지에 붙지 않는다', () {
      // 미니게임은 스탯 대신 실력으로 넘는 관문이다. 스탯 게이트와 겹치면 안 된다.
      for (final e in bundle.events) {
        for (final c in e.choices) {
          if (c.minigame == null) continue;
          expect(c.require, isNull, reason: '${e.id}: "${c.text}"');
        }
      }
    });

    test('한 이벤트에 미니게임은 최대 하나', () {
      for (final e in bundle.events) {
        expect(
          e.choices.where((c) => c.minigame != null).length,
          lessThanOrEqualTo(1),
          reason: e.id,
        );
      }
    });

    test('엔딩이 참조하는 플래그는 이벤트가 실제로 세운다', () {
      final produced = {
        for (final e in bundle.events)
          for (final c in e.choices) ...[
            ...c.effects.setFlags,
            ...c.fail.setFlags,
          ],
      }..addAll(['album_10', 'album_20', 'burnout_x3']);
      final required = {for (final e in bundle.endings) ...e.when.flags};
      expect(required.difference(produced), isEmpty);
    });

    test('초기 스탯이 config 대로 들어간다', () {
      final s = fresh();
      expect(s.stat(Stat.esteem), 15);
      expect(s.stat(Stat.sincerity), 50);
      expect(s.relations.length, 12);
      expect(s.hearts, 5);
    });
  });

  group('조건 판정', () {
    test('범위·플래그·캐릭터 self 매핑', () {
      final s = fresh();
      s.rel('seoyeon').affection = 50;
      s.flags.add('x');
      const t = Trigger(
        day: Range(1, 10),
        affection: {'*': Range(40, 60)},
        flags: ['x'],
        notFlags: ['y'],
      );
      expect(t.matches(s, self: 'seoyeon'), isTrue);
      expect(t.matches(s, self: 'haneul'), isFalse);
      s.flags.add('y');
      expect(t.matches(s, self: 'seoyeon'), isFalse);
    });

    test('anyAffection 집계 조건', () {
      final s = fresh();
      const t = Trigger(anyAffection: CountCondition(60, 2));
      expect(t.matches(s), isFalse);
      s.rel('seoyeon').affection = 65;
      s.rel('haneul').affection = 60;
      expect(t.matches(s), isTrue);
    });

    test('잠긴 선택지는 필요 스탯 문구를 돌려준다', () {
      final s = fresh();
      final ev = bundle.eventById['seoyeon_r04']!;
      final views = engine.choicesFor(s, ev);
      expect(views[1].locked, isTrue);
      expect(views[1].reason, '자존감 40↑');
      s.stats[Stat.esteem] = 40;
      expect(engine.choicesFor(s, ev)[1].locked, isFalse);
    });
  });

  group('하루 계획', () {
    test('1일차는 프사 고르기 메인 이벤트로 시작한다', () {
      final s = fresh();
      final plan = engine.planDay(s);
      expect(plan.first.id, 'm01');
      expect(
        plan.map((e) => e.id).toSet().length,
        plan.length,
        reason: '중복 없음',
      );
    });

    test('같은 시드·같은 날이면 계획이 같다', () {
      final a = engine.planDay(fresh(seed: 7)..day = 12);
      final b = engine.planDay(fresh(seed: 7)..day = 12);
      expect(a.map((e) => e.id), b.map((e) => e.id));
    });

    test('스트레스 90 이상이면 일상 대신 번아웃 위기가 잡힌다', () {
      final s = fresh()..day = 20;
      s.stats[Stat.stress] = 95;
      final ids = engine.planDay(s).map((e) => e.id).toList();
      expect(ids, contains('c_burnout'));
      expect(ids.where((id) => id.startsWith('d_')), isEmpty);
    });

    test('호감도가 가장 높은 캐릭터의 루트가 우선한다', () {
      final s = fresh()..day = 30;
      s.rel('yeeun').affection = 30;
      final route = engine
          .planDay(s)
          .firstWhere((e) => e.layer == EventLayer.route);
      expect(route.character, 'yeeun');
    });

    test('100일을 끝까지 돌려도 매일 볼 이벤트가 남는다', () {
      final s = fresh(seed: 3);
      var emptyDays = 0;
      for (var day = 1; day <= 100; day++) {
        final plan = engine.planDay(s);
        if (plan.isEmpty) emptyDays++;
        for (final ev in plan) {
          engine.applyChoice(s, ev, ev.choices.first);
        }
        // 루트가 계속 열리도록 관심 캐릭터의 호감도를 올려 준다.
        s.rel('seoyeon').affection = (day * 0.9).round().clamp(0, 100);
        engine.endDay(s);
      }
      expect(emptyDays, lessThanOrEqualTo(12), reason: '빈 날이 너무 많음');
      expect(s.seen.length, greaterThan(100), reason: '100일간 본 이벤트 수');
    });

    test('호감도 구간에 빈 곳이 없다', () {
      for (final c in bundle.characters) {
        for (final day in [30, 50, 80, 95]) {
          for (var aff = 0; aff <= 90; aff += 10) {
            final s = fresh()..day = day;
            // 도윤은 헬스장에서만 만나므로 매력 조건을 채워 준다.
            if (c.hidden) s.stats[Stat.charm] = 70;
            s.rel(c.id).affection = aff;
            final has = engine
                .candidates(s, EventLayer.route)
                .any((e) => e.character == c.id);
            expect(has, isTrue, reason: '${c.name} $day일차 호감 $aff 구간에 이벤트 없음');
          }
        }
      }
    });

    test('once 이벤트는 본 뒤 다시 나오지 않는다', () {
      final s = fresh();
      final ev = bundle.eventById['m01']!;
      engine.applyChoice(s, ev, ev.choices[1]);
      expect(engine.planDay(s).map((e) => e.id), isNot(contains('m01')));
    });

    test('히든 캐릭터 도윤은 2회차·매력 60 이상에서만 후보가 된다', () {
      final s = fresh()..day = 10;
      s.stats[Stat.charm] = 70;
      expect(engine.candidates(s, EventLayer.hidden), isEmpty);
      final s2 = fresh(run: 2)..day = 10;
      s2.stats[Stat.charm] = 70;
      expect(
        engine.candidates(s2, EventLayer.hidden).map((e) => e.id),
        contains('h_doyun_intro'),
      );
    });
  });

  group('선택 적용', () {
    test('효과가 적용되고 상한에서 잘린다', () {
      final s = fresh();
      final ev = bundle.eventById['m01']!;
      s.rel('haneul').affection = 99;
      final out = engine.applyChoice(s, ev, ev.choices[2], random: Random(0));
      expect(out.success, isTrue);
      expect(s.affectionOf('haneul'), 100);
      expect(out.delta.affection['haneul'], 1, reason: '실제 변화량만 기록');
      expect(s.affectionOf('jiwoo'), 0, reason: '0 아래로 내려가지 않음');
      expect(s.seen, contains('m01'));
      expect(
        s.rel('haneul').contactedToday,
        isFalse,
        reason: '캐릭터 없는 이벤트는 접촉 아님',
      );
    });

    test('미니게임 결과가 확률을 대신한다', () {
      final ev = bundle.events.firstWhere(
        (e) => e.choices.any((c) => c.minigame != null),
      );
      final idx = ev.choices.indexWhere((c) => c.minigame != null);

      final win = fresh();
      final okOut = engine.applyChoice(
        win,
        ev,
        ev.choices[idx],
        forcedSuccess: true,
        forcedCritical: true,
      );
      expect(okOut.success, isTrue);
      expect(okOut.critical, isTrue);

      final lose = fresh();
      final badOut = engine.applyChoice(
        lose,
        ev,
        ev.choices[idx],
        forcedSuccess: false,
      );
      expect(badOut.success, isFalse);
      expect(badOut.critical, isFalse);
    });

    test('확률 선택지는 대략 명시된 확률만큼 성공한다', () {
      // 미니게임이 붙지 않은, 확률이 남아 있는 선택지를 하나 찾는다.
      final ev = bundle.events.firstWhere(
        (e) => e.choices.any((c) => c.chance != null && c.minigame == null),
      );
      final choice = ev.choices.firstWhere(
        (c) => c.chance != null && c.minigame == null,
      );
      final p = choice.chance!;
      var successes = 0;
      for (var i = 0; i < 400; i++) {
        final out = engine.applyChoice(fresh(), ev, choice, random: Random(i));
        if (out.success) successes++;
      }
      final rate = successes / 400 * 100;
      expect(rate, closeTo(p, 12), reason: '${ev.id} 기대 $p%');
    });

    test('확률 선택지가 실패하면 fail 효과만 적용된다', () {
      final ev = bundle.events.firstWhere(
        (e) => e.choices.any(
          (c) => c.chance != null && c.minigame == null && c.fail.album != null,
        ),
      );
      final choice = ev.choices.firstWhere(
        (c) => c.chance != null && c.minigame == null && c.fail.album != null,
      );
      for (var i = 0; i < 200; i++) {
        final s = fresh();
        final out = engine.applyChoice(s, ev, choice, random: Random(i));
        if (!out.success) {
          expect(s.album, contains(choice.fail.album));
          return;
        }
      }
      fail('실패 사례를 못 찾음');
    });

    test('크리티컬이면 호감 상승이 2배', () {
      // 초반 가속(config.earlyAffection) 기간이 끝난 날에서 크리티컬만 본다.
      final s = fresh()..day = 11;
      s.stats[Stat.sense] = 100; // 크리티컬 10%
      final ev = bundle.eventById['seoyeon_r01']!;
      // rng: 첫 nextInt(100)는 chance 없으므로 건너뜀 → crit 판정에 쓰임. 0 을 주는 시드 탐색.
      for (var seed = 0; seed < 500; seed++) {
        final probe = Random(seed);
        if (probe.nextInt(100) < engine.critChance(s)) {
          final out = engine.applyChoice(
            s,
            ev,
            ev.choices[0],
            random: Random(seed),
          );
          expect(out.critical, isTrue);
          expect(s.affectionOf('seoyeon'), 4);
          return;
        }
      }
      fail('크리티컬 시드를 찾지 못함');
    });

    test('하루 마감: 미접촉 호감 -1, 스트레스 -3, 번아웃 누적', () {
      final s = fresh();
      s.rel('seoyeon').affection = 10;
      s.rel('haneul')
        ..affection = 10
        ..contactedToday = true;
      s.stats[Stat.stress] = 50;
      s.flags.add('burnout');
      engine.endDay(s, cliffhanger: '내일');
      expect(s.affectionOf('seoyeon'), 9);
      expect(s.affectionOf('haneul'), 10);
      expect(s.stat(Stat.stress), 47);
      expect(s.day, 2);
      expect(s.lastCliffhanger, '내일');
      expect(s.flags, contains('burnout_1'));
      expect(s.flags, isNot(contains('burnout')));
    });
  });

  group('콤보와 룰렛', () {
    test('좋은 선택 3연속이면 물오름 상태가 된다', () {
      final s = fresh();
      final ev = bundle.eventById['seoyeon_r01']!;
      expect(s.onFire, isFalse);
      for (var i = 0; i < 3; i++) {
        s.seen.clear();
        engine.applyChoice(s, ev, ev.choices[0], random: Random(1));
      }
      expect(s.combo, 3);
      expect(s.onFire, isTrue);
    });

    test('물오름이면 크리티컬 확률이 두 배', () {
      final s = fresh();
      final base = engine.critChance(s);
      s.combo = 3;
      expect(engine.critChance(s), base * 2);
      expect(engine.chanceBonus(s), 20);
    });

    test('실패하면 콤보가 끊긴다', () {
      final s = fresh()..combo = 4;
      final ev = bundle.events.firstWhere(
        (e) => e.choices.any((c) => c.minigame != null),
      );
      final idx = ev.choices.indexWhere((c) => c.minigame != null);
      final out = engine.applyChoice(
        s,
        ev,
        ev.choices[idx],
        forcedSuccess: false,
      );
      expect(s.combo, 0);
      expect(out.comboBroken, isTrue);
    });

    test('호감이 깎이는 선택은 콤보를 쌓지 않는다', () {
      final s = fresh()..combo = 2;
      s.rel('seoyeon').affection = 20; // 0에서는 -1이 깎일 곳이 없다
      final ev = bundle.eventById['seoyeon_r01']!;
      engine.applyChoice(s, ev, ev.choices[2], random: Random(1));
      expect(s.affectionOf('seoyeon'), 19);
      expect(s.combo, 0);
    });

    test('호감이 이미 0이면 감소가 없으므로 콤보가 끊기지 않는다', () {
      // 실제로 잃은 게 없으면 벌하지 않는다는 규칙을 고정한다.
      final s = fresh()..combo = 2;
      final ev = bundle.eventById['seoyeon_r01']!;
      engine.applyChoice(s, ev, ev.choices[2], random: Random(1));
      expect(s.affectionOf('seoyeon'), 0);
      expect(s.combo, 3);
    });

    test('룰렛은 항상 정의된 칸을 돌려주고 효과가 적용된다', () {
      for (var day = 1; day <= 30; day++) {
        final s = fresh()..day = day;
        final slot = engine.spinRoulette(s);
        expect(slot, inInclusiveRange(0, EventEngine.rouletteSlots.length - 1));
        final before = Map.of(s.stats);
        final d = engine.applyRoulette(s, slot);
        expect(
          d.stats.isNotEmpty || before.toString() == s.stats.toString(),
          isTrue,
        );
      }
    });

    test('룰렛은 하루에 한 번만 돌릴 수 있다', () {
      final s = fresh();
      expect(s.rouletteDay, isNot(s.day));
      s.rouletteDay = s.day;
      expect(s.rouletteDay, s.day);
      engine.endDay(s);
      expect(s.rouletteDay, isNot(s.day), reason: '날이 바뀌면 다시 돌릴 수 있어야 함');
    });
  });

  group('엔딩', () {
    test('아무것도 안 하면 영구 모쏠', () {
      final s = fresh()..day = 101;
      expect(resolver.resolve(s).id, 'forever_solo');
    });

    test('서연 해피 엔딩 조건', () {
      final s = fresh()..day = 101;
      s.rel('seoyeon')
        ..affection = 85
        ..trust = 75;
      s.stats[Stat.sincerity] = 60;
      expect(
        resolver.resolve(s).id,
        isNot('seoyeon_happy'),
        reason: '반말 플래그 없으면 해피 불가',
      );
      s.flags.add('seoyeon_banmal');
      expect(resolver.resolve(s).id, 'seoyeon_happy');
    });

    test('같은 우선순위면 호감도 높은 캐릭터 엔딩', () {
      final s = fresh()..day = 101;
      s.stats[Stat.sincerity] = 60;
      s.rel('haneul')
        ..affection = 82
        ..trust = 75;
      s.rel('yeeun')
        ..affection = 90
        ..trust = 75;
      expect(resolver.resolve(s).id, 'yeeun_happy');
    });

    test('두 명 이상 호감 60 이상에 진정성 낮으면 어장 관리자', () {
      final s = fresh()..day = 101;
      s.stats[Stat.sincerity] = 30;
      s.rel('seoyeon').affection = 65;
      s.rel('minjae').affection = 61;
      expect(resolver.resolve(s).id, 'fishing');
    });

    test('진정성 0 이면 즉시 종료 엔딩', () {
      final s = fresh();
      expect(resolver.immediate(s), isNull);
      s.stats[Stat.sincerity] = 0;
      expect(resolver.immediate(s)?.id, 'pickup_fall');
    });
  });

  group('저장', () {
    test('toJson → fromJson 왕복', () {
      final s = fresh(seed: 99)..day = 33;
      s.rel('jiwoo')
        ..affection = 44
        ..trust = 12;
      s.flags.add('jiwoo_intro');
      s.seen.add('m01');
      s.album.add('테스트');
      s.hearts = 2;
      s.combo = 4;
      s.rouletteDay = 33;
      final r = GameState.fromJson(s.toJson());
      expect(r.day, 33);
      expect(r.seed, 99);
      expect(r.affectionOf('jiwoo'), 44);
      expect(r.trustOf('jiwoo'), 12);
      expect(r.flags, contains('jiwoo_intro'));
      expect(r.seen, contains('m01'));
      expect(r.album, ['테스트']);
      expect(r.hearts, 2);
      expect(r.combo, 4);
      expect(r.onFire, isTrue);
      expect(r.rouletteDay, 33);
    });
  });
}
