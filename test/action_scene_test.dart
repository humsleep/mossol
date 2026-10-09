/// 아침 행동과 그날 이야기가 이어지는지("헬스장" 을 골랐는데 딴 얘기만 나오던 문제).
///
/// - `trigger.action`: 오늘 고른 행동([GameState.todayAction])이 목록 안에 있어야 열린다.
/// - 행동 장면은 하루에 하나, 오프닝 뒤에는 하루의 **첫 장면**이다(오프닝에는 메인 뒤).
/// - `DayAction.affinity`: 어울리는 일상은 그날 가중치가 [DayAction.affinityBoost]배.
/// - 행동 장면은 장소 그림(`assets/scenes/<행동 id>`)으로 열린다.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';
import 'package:mossol/ui/scene_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget/helpers.dart';
import 'story_files.dart';

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
          readStoryFile(f),
      ],
      endings: File('assets/story/endings.json').readAsStringSync(),
      starts: readStartsFile(),
      signals: File('assets/story/signals.json').readAsStringSync(),
      knownMinigames: minigameIds,
    );
    engine = EventEngine(bundle);
  });

  GameState at(
    int day, {
    String? action,
    int seed = 7,
    int run = 2,
    String pref = Preference.all,
  }) =>
      GameState.fresh(
          bundle.config,
          bundle.characters,
          seed: seed,
          run: run,
          preference: pref,
        )
        ..day = day
        ..todayAction = action;

  List<String> actionIds() => [for (final a in bundle.config.actions) a.id];
  List<StoryEvent> scenes() =>
      bundle.events.where(engine.isActionScene).toList();

  group('데이터', () {
    test('모든 행동에 장면이 있고, 장면은 모두 아는 행동을 가리킨다', () {
      final ids = actionIds().toSet();
      // 개편 2 의 의뢰(a_hustle_*)는 작가가 덧붙이는 중이라 빼고 센다.
      expect(
        scenes().where((e) => !e.id.startsWith(overhaul2HustlePrefix)),
        hasLength(55),
      );
      for (final a in ids) {
        expect(
          scenes().where((e) => e.trigger.action.contains(a)).length,
          greaterThanOrEqualTo(6),
          reason: a,
        );
      }
      for (final e in scenes()) {
        expect(e.layer, EventLayer.daily, reason: e.id);
        expect(ids.containsAll(e.trigger.action), isTrue, reason: e.id);
      }
    });

    test('행동마다 조건 없이 반복되는 장면이 있다(100일 내내 마르지 않게)', () {
      for (final a in actionIds()) {
        final evergreen = [
          for (final e in scenes())
            if (e.trigger.action.contains(a) &&
                !e.once &&
                e.character == null &&
                e.trigger.day == null &&
                e.trigger.stats.isEmpty &&
                e.trigger.flags.isEmpty)
              e.id,
        ];
        expect(evergreen, isNotEmpty, reason: a);
      }
    });

    test('affinity 접두어는 모두 실제 일상 이벤트를 가리킨다', () {
      final daily = [
        for (final e in bundle.events)
          if (e.layer == EventLayer.daily && !engine.isActionScene(e)) e.id,
      ];
      for (final a in bundle.config.actions) {
        expect(a.affinity, isNotEmpty, reason: a.id);
        for (final p in a.affinity) {
          expect(
            daily.any((id) => id.startsWith(p)),
            isTrue,
            reason: '$a.id $p',
          );
        }
      }
    });

    test('검증기: 모르는 행동·일상 밖 행동 장면을 거부한다', () {
      StoryEvent ev(String layer, List<String> action) => StoryEvent.fromJson({
        'id': 'x',
        'layer': layer,
        if (layer == 'main') 'day': 1,
        'trigger': {'action': action},
        'lines': [
          {'who': 'narr', 'text': '장면'},
        ],
        'choices': [
          {'text': '고른다'},
        ],
      });
      // 엔딩은 기본 엔딩만 — 실제 엔딩은 이 합성 묶음에 없는 m36 결과 플래그를 읽는다(검증기 F5).
      StoryBundle with1(StoryEvent e) => StoryBundle(
        config: bundle.config,
        characters: bundle.characters,
        events: [e],
        endings: [
          for (final x in bundle.endings)
            if (x.isDefault) x,
        ],
      );
      expect(() => with1(ev('daily', ['gym'])).validate(), returnsNormally);
      expect(() => with1(ev('daily', ['gyn'])).validate(), throwsStateError);
      expect(() => with1(ev('main', ['gym'])).validate(), throwsStateError);
    });

    test('행동 장면은 소프트락 방지선(repeatableDaily)에 세지 않는다', () {
      for (final pref in Preference.genders) {
        expect(
          bundle.repeatableDaily(pref).where(engine.isActionScene),
          isEmpty,
        );
      }
    });
  });

  group('하루 계획', () {
    test('오프닝 뒤에는 고른 행동의 장면이 하루의 첫 장면이다', () {
      for (final a in actionIds()) {
        for (final day in [4, 20, 50, 99]) {
          for (final seed in [1, 2, 3]) {
            final plan = engine.planDay(at(day, action: a, seed: seed));
            expect(plan, isNotEmpty);
            // 새벽·아침으로 시각을 정한 장면(과 그날의 메인)은 행동 장면보다 앞일 수 있다(r3 F2).
            final first = plan.firstWhere((e) => !_dawnOrMain(e));
            expect(
              first.trigger.action,
              contains(a),
              reason: '$a D$day seed$seed → ${[for (final e in plan) e.id]}',
            );
            // 행동 장면은 하루에 하나.
            expect(plan.where(engine.isActionScene).length, 1);
          }
        }
      }
    });

    test('오프닝에는 메인 이야기가 먼저, 행동 장면은 그 뒤', () {
      for (final run in [1, 2]) {
        for (final day in [1, 2, 3]) {
          final plan = engine.planDay(at(day, action: 'gym', run: run));
          // D1 첫 장면은 늘 메인(m01 또는 시작 메인). D2·3 은 새벽으로 정한 장면이 먼저일 수 있다(r5 H1).
          final firstMain = plan.firstWhere((e) => !_dawnOrMain(e) || e.layer == EventLayer.main);
          expect(
            day == 1 ? plan.first.layer : firstMain.layer,
            EventLayer.main,
            reason: 'run$run D$day',
          );
          final i = plan.indexWhere((e) => e.trigger.action.contains('gym'));
          expect(i, greaterThan(0), reason: 'run$run D$day');
          expect(
            plan.take(i).every(_dawnOrMain),
            isTrue,
            reason: 'run$run D$day ${[for (final e in plan) e.id]}',
          );
        }
      }
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

    test('once 장면을 다 봐도 반복 장면이 첫 자리를 채운다', () {
      for (final a in actionIds()) {
        final s = at(40, action: a);
        for (final e in scenes()) {
          if (e.once) s.seen.add(e.id);
        }
        final plan = engine.planDay(s);
        expect(
          plan.firstWhere((e) => !_dawnOrMain(e)).trigger.action,
          contains(a),
          reason: a,
        );
      }
    });

    test('재방송 억제: 냉각 중이거나 최대 횟수를 본 장면은 첫 자리에 오지 않는다', () {
      for (final a in actionIds()) {
        // 냉각: 어제 본 반복 장면은 후보가 아니다(되돌림 없음 — 그날은 평소 하루).
        final cooled = at(40, action: a);
        for (final e in scenes()) {
          if (e.once) {
            cooled.seen.add(e.id);
          } else {
            cooled.dailySeenDay[e.id] = 39;
          }
        }
        expect(engine.actionScenePool(cooled), isEmpty, reason: a);
        expect(engine.planDay(cooled).where(engine.isActionScene), isEmpty);
        expect(engine.planDay(cooled), isNotEmpty, reason: '하루가 비지는 않는다');

        // 최대 횟수: 반복 장면도 actionSceneMaxViews 번 보면 끝이다.
        final worn = at(40, action: a);
        for (final e in scenes()) {
          worn.seen.add(e.id);
          if (!e.once) {
            worn.seenCount[e.id] = EventEngine.actionSceneMaxViews;
          }
        }
        expect(engine.actionScenePool(worn), isEmpty, reason: a);
      }
    });

    test('같은 상태·같은 행동이면 같은 계획(결정적)', () {
      final a = [for (final e in engine.planDay(at(30, action: 'work'))) e.id];
      final b = [for (final e in engine.planDay(at(30, action: 'work'))) e.id];
      expect(a, b);
    });

    test('affinity: 어울리는 일상의 추첨 가중치가 affinityBoost 배', () {
      final work = bundle.config.actions.firstWhere((a) => a.id == 'work');
      final d = bundle.eventById['d_work_01']!;
      final other = bundle.eventById['d_drink_01']!;
      expect(work.fits(d.id), isTrue);
      expect(work.fits(other.id), isFalse);
      final plain = at(30);
      final withWork = at(30, action: 'work');
      expect(
        engine.pickWeight(withWork, d),
        engine.pickWeight(plain, d) * DayAction.affinityBoost,
      );
      expect(
        engine.pickWeight(withWork, other),
        engine.pickWeight(plain, other),
      );
    });

    test('affinity: 행동을 고른 날 어울리는 일상이 더 자주 나온다', () {
      int hits(String? action) {
        final work = bundle.config.actions.firstWhere((a) => a.id == 'work');
        var n = 0;
        for (var seed = 0; seed < 300; seed++) {
          for (final e in engine.planDay(at(30, action: action, seed: seed))) {
            if (!engine.isActionScene(e) && work.fits(e.id)) n++;
          }
        }
        return n;
      }

      expect(hits('work'), greaterThan(hits(null) * 3 ~/ 2));
    });
  });

  group('상태', () {
    test('오늘 행동은 세이브에 남고 예전 세이브는 null', () {
      final s = at(5, action: 'work');
      final back = GameState.fromJson(s.toJson());
      expect(back.todayAction, 'work');
      final old = s.toJson()..remove('todayAction');
      expect(GameState.fromJson(old).todayAction, isNull);
    });

    test('엔진 마감이 오늘 행동을 비운다(내일 미리보기가 오늘 장면을 끌고 가지 않게)', () {
      final s = at(10, action: 'gym');
      engine.endDay(s);
      expect(s.todayAction, isNull);
      expect(engine.planDay(s).where(engine.isActionScene), isEmpty);
    });

    test('컨트롤러: 행동을 고르면 그 장면이 오늘 큐에 들고, 이어하기에도 남고, 마감에서 비워진다', () async {
      SharedPreferences.setMockInitialValues({});
      final b = testBundle();
      final c1 = GameController(bundle: b, save: SaveService());
      await c1.init();
      await c1.newGame();
      final gym = b.config.actions.firstWhere((a) => a.id == 'gym');
      expect(await c1.startDay(gym), isTrue);
      expect(c1.state!.todayAction, 'gym');
      final today = [c1.current!.id, ...c1.queuedEventIds];
      expect(
        today.where((id) => b.eventById[id]!.trigger.action.contains('gym')),
        hasLength(1),
        reason: '$today',
      );

      final c2 = GameController(bundle: b, save: SaveService());
      await c2.init();
      expect(await c2.continueGame(), isTrue);
      expect(c2.state!.todayAction, 'gym');

      await c2.endDay();
      expect(c2.state!.todayAction, isNull);
    });
  });

  group('장소 그림', () {
    // 실제 에셋 목록으로 만든 레지스트리. 앱이 AssetManifest 로 읽는 것과 같은 경로 형식이다.
    SceneRegistry realRegistry() => SceneRegistry.fromAssets([
      for (final f in Directory('assets').listSync(recursive: true))
        if (f is File) f.path.replaceAll(r'\', '/'),
    ]);

    test('행동마다 장소 그림이 있다', () {
      final r = realRegistry();
      for (final a in actionIds()) {
        expect(
          SceneImages.forAction(a, registry: r),
          'assets/scenes/$a.webp',
          reason: a,
        );
      }
    });

    test('행동 장면은 전부 그 행동의 장소 그림으로 열린다', () {
      final r = realRegistry();
      for (final e in scenes()) {
        final a = e.trigger.action.first;
        expect(e.image, 'assets/scenes/$a', reason: e.id);
        expect(
          SceneImages.forEvent(e, registry: r),
          'assets/scenes/$a.webp',
          reason: e.id,
        );
      }
    });
  });
}

/// 행동 장면보다 앞에 올 수 있는 장면: 메인, 정오 전으로 시각을 정한 장면(r3_meeting F2).
bool _dawnOrMain(StoryEvent e) =>
    e.layer == EventLayer.main ||
    (e.clockSeconds != null && e.clockSeconds! < EventEngine.clockNoon);
