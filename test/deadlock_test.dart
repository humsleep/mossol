import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/conditions.dart';
import 'package:mossol/engine/ending_resolver.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';

/// 상호배타 게이트를 넣은 뒤 "여러 캐릭터를 고루 올린" 플레이가
/// 아무 루트 이벤트도 못 보는 교착에 빠지지 않는지 확인한다.
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

  setUpAll(() {
    registerMinigames();
    bundle = loadBundle();
    engine = EventEngine(bundle);
  });

  GameState freshIn(String pref, {int seed = 1, int run = 1}) =>
      GameState.fresh(
        bundle.config,
        bundle.characters,
        seed: seed,
        run: run,
        preference: pref,
      );

  /// 모든 스탯을 넉넉히 채워 require 때문에 막히는 경우를 배제한다.
  void maxStats(GameState s) {
    for (final k in Stat.all) {
      s.stats[k] = k == Stat.stress ? 0 : (k == Stat.money ? 900 : 100);
    }
  }

  // 선호마다 따로 본다. 그 쪽 캐릭터가 없으면(신규 캐스트 전) 건너뛴다.
  for (final pref in Preference.genders) {
    GameState fresh({int seed = 1, int run = 1}) =>
        freshIn(pref, seed: seed, run: run);

    test('[$pref] 여러 캐릭터를 고루 올려도 하루가 완전히 비지 않는다', () {
      final roster = bundle.charactersFor(pref);
      if (roster.isEmpty) {
        markTestSkipped('$pref 쪽 캐릭터 없음');
        return;
      }
      // 전원 동률로 올려 가며 그날 볼 수 있는 이벤트가 있는지 확인한다.
      final empty = <String>[];
      for (var aff = 0; aff <= 100; aff += 5) {
        for (final day in [10, 30, 50, 70, 90]) {
          final s = fresh()..day = day;
          maxStats(s);
          for (final c in roster) {
            s.rel(c.id).affection = aff;
            s.rel(c.id).trust = aff;
          }
          final plan = engine.planDay(s);
          if (plan.isEmpty) empty.add('호감 $aff / $day일차');
        }
      }
      expect(empty, isEmpty, reason: '완전히 빈 날: ${empty.join(", ")}');
    });

    test('[$pref] 전원 동률 구간에서도 루트 이벤트가 이어진다', () {
      final roster = bundle.charactersFor(pref);
      if (roster.isEmpty) {
        markTestSkipped('$pref 쪽 캐릭터 없음');
        return;
      }
      // 상호배타 조건이 겹쳐 모든 루트가 한꺼번에 닫히는 구간이 없어야 한다.
      final blocked = <String>[];
      for (var aff = 40; aff <= 80; aff += 5) {
        for (final day in [30, 50, 70, 90]) {
          final s = fresh()..day = day;
          maxStats(s);
          for (final c in roster) {
            s.rel(c.id).affection = aff;
            s.rel(c.id).trust = 60;
          }
          final routes = engine.candidates(s, EventLayer.route);
          if (routes.isEmpty) blocked.add('호감 $aff / $day일차');
        }
      }
      expect(blocked, isEmpty, reason: '루트가 전부 닫힌 구간: ${blocked.join(", ")}');
    });

    test('[$pref] 한 명에게 집중하면 그 캐릭터 루트가 끝까지 열린다', () {
      final roster = bundle.charactersFor(pref);
      if (roster.isEmpty) {
        markTestSkipped('$pref 쪽 캐릭터 없음');
        return;
      }
      for (final target in roster) {
        final gaps = <int>[];
        for (var aff = 0; aff <= 95; aff += 5) {
          final s = fresh()..day = 60;
          maxStats(s);
          // 집중 플레이: 대상만 올리고 나머지는 낮게 유지.
          for (final c in roster) {
            s.rel(c.id).affection = c.id == target.id ? aff : 10;
            s.rel(c.id).trust = c.id == target.id ? aff : 10;
          }
          final has = engine
              .candidates(s, EventLayer.route)
              .any((e) => e.character == target.id);
          if (!has) gaps.add(aff);
        }
        expect(gaps, isEmpty, reason: '${target.name} 루트가 끊기는 호감 구간: $gaps');
      }
    });

    test('[$pref] 엔딩 조건을 만족하면 그 엔딩이 실제로 나온다', () {
      final roster = bundle.charactersFor(pref);
      if (roster.isEmpty) {
        markTestSkipped('$pref 쪽 캐릭터 없음');
        return;
      }
      // 상호배타 게이트가 엔딩 도달을 막지 않는지 확인.
      expect(bundle.endings.length, 30);
      final resolver = EndingResolver(
        bundle.endings,
        characters: bundle.characters,
      );
      for (final e in bundle.endings.where(
        (e) => e.tier == 'happy' && bundle.endingInPreference(e, pref),
      )) {
        final s = fresh()..day = 101;
        maxStats(s);
        s.stats[Stat.sincerity] = 60;
        for (final c in roster) {
          s.rel(c.id).affection = 10;
          s.rel(c.id).trust = 10;
        }
        final id = e.character!;
        s.rel(id).affection = 95;
        s.rel(id).trust = 85;
        if (e.when.flags.isNotEmpty) s.flags.addAll(e.when.flags);
        expect(
          e.when.matches(s, self: e.character, absent: engine.absentFor(s)),
          isTrue,
          reason: '${e.name} 조건을 직접 만족시켰는데 판정이 false',
        );
        // 이 선호에서 나오는 엔딩은 이 쪽 캐릭터(또는 공용)뿐이다.
        final ids = roster.map((c) => c.id).toList();
        expect(ids, contains(id));
        final got = resolver.resolve(s);
        expect(got.character == null || ids.contains(got.character), isTrue);
      }
    });
  }
}
