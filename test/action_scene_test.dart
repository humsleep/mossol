import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/album_index.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';

/// 아침 행동과 그날 장면이 이어지는지(“헬스장” 을 골랐는데 딴 얘기만 나오던 문제).
void main() {
  late StoryBundle bundle;
  late EventEngine engine;

  setUpAll(() {
    registerMinigames();
    bundle = StoryBundle.fromJsonStrings(
      config: File('assets/story/config.json').readAsStringSync(),
      characters: File('assets/story/characters.json').readAsStringSync(),
      events: [
        for (final f in StoryBundle.eventFiles)
          File('assets/story/$f').readAsStringSync(),
      ],
      endings: File('assets/story/endings.json').readAsStringSync(),
      signals: File('assets/story/signals.json').readAsStringSync(),
      knownMinigames: minigameIds,
    );
    engine = EventEngine(bundle);
  });

  GameState at(int day, {String? action, int seed = 7}) =>
      GameState.fresh(bundle.config, bundle.characters, seed: seed)
        ..day = day
        ..todayAction = action;

  List<String> actionIds() => [for (final a in bundle.config.actions) a.id];

  test('모든 행동에 장면이 있고, 장면은 모두 아는 행동을 가리킨다', () {
    final ids = actionIds().toSet();
    final scenes = bundle.events.where(engine.isActionScene).toList();
    for (final a in ids) {
      expect(
        scenes.where((e) => e.trigger.action.contains(a)).length,
        greaterThanOrEqualTo(6),
        reason: a,
      );
    }
    for (final e in scenes) {
      expect(e.layer, EventLayer.daily, reason: e.id);
      expect(ids.containsAll(e.trigger.action), isTrue, reason: e.id);
    }
  });

  test('오프닝 뒤에는 고른 행동의 장면이 하루의 첫 장면이다', () {
    for (final a in actionIds()) {
      for (final day in [4, 20, 50, 99]) {
        for (final seed in [1, 2, 3]) {
          final plan = engine.planDay(at(day, action: a, seed: seed));
          expect(plan, isNotEmpty);
          expect(
            plan.first.trigger.action,
            contains(a),
            reason: '$a D$day seed$seed → ${plan.first.id}',
          );
          // 행동 장면은 하루에 하나.
          expect(plan.where(engine.isActionScene).length, 1);
        }
      }
    }
  });

  test('오프닝에는 메인 이야기가 먼저, 행동 장면은 그 뒤', () {
    final plan = engine.planDay(at(1, action: 'gym'));
    expect(plan.first.layer, EventLayer.main);
    expect(plan.any((e) => e.trigger.action.contains('gym')), isTrue);
  });

  test('행동을 고르지 않았거나 다른 행동이면 그 장면은 나오지 않는다', () {
    for (var day = 1; day <= 100; day += 3) {
      final none = engine.planDay(at(day));
      expect(none.where(engine.isActionScene), isEmpty, reason: 'D$day');
      final rest = engine.planDay(at(day, action: 'rest'));
      expect(
        rest.where((e) => e.trigger.action.contains('gym')),
        isEmpty,
        reason: 'D$day',
      );
    }
  });

  test('반복 장면이 있어 100일 내내 장면이 마르지 않는다', () {
    for (final a in actionIds()) {
      final s = at(4, action: a);
      for (final e in bundle.events.where(engine.isActionScene)) {
        if (e.once) s.seen.add(e.id);
      }
      final plan = engine.planDay(s);
      expect(plan.first.trigger.action, contains(a), reason: a);
    }
  });

  test('오늘 행동은 세이브에 남고 예전 세이브는 null', () {
    final s = at(5, action: 'work');
    final back = GameState.fromJson(s.toJson());
    expect(back.todayAction, 'work');
    final old = s.toJson()..remove('todayAction');
    expect(GameState.fromJson(old).todayAction, isNull);
  });

  test('흑역사 제목으로 출처 장면을 찾는다', () {
    final titles = <String>{
      for (final e in bundle.events)
        for (final c in e.choices) ...[?c.fail.album, ?c.effects.album],
    };
    expect(titles, isNotEmpty);
    for (final t in titles) {
      final src = AlbumIndex.find(bundle.events, t);
      expect(src, isNotNull, reason: t);
      final album = src!.failed
          ? src.choice.fail.album
          : src.choice.effects.album;
      expect(album, t);
    }
    expect(AlbumIndex.find(bundle.events, '없는 흑역사'), isNull);
  });
}
