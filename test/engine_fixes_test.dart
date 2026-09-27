// 07·08 진단 수선의 회귀 테스트: 일상 반복 냉각 · 클리프행어 층 우선순위 · 오프닝 대본.
//
// - B 일상 냉각: `config.dailyCooldownDays` 안에 같은 일상이 두 번 나오지 않는다.
//   진단은 "시드 300 전부가 20일 안에 같은 일상을 두 번 이상 받는다"였다
//   (docs/review/07_story_flow.md (c)#8).
// - D 클리프행어: 메인의 클리프행어를 뒤에 온 일상·루트가 덮어쓰지 않는다((c)#12, S7).
// - E 오프닝 대본: 1회차 D+1 에 `config.openingScript` 가 먼저, 적힌 순서대로 깔린다((c)#4).
//
// 11 판정 수선(docs/review/12_engine_fixes.md)에서 붙인 것:
// - F `once`: 한 회차에 한 번만 나오는 이벤트가 **전 층**에서 지켜지고 세이브를 넘어간다.
// - G 반복 감쇠: 같은 장면을 볼수록 추첨 가중치가 깎인다(`config.repeatWeightPercent`).
// - H 카운트다운: 남은 날 수와 분기점을 엔진이 화면에 내준다(11_story_verdict §4-3).
// - I 변형 대사(`variants`): 같은 장면을 또 볼 때 다른 대사를 쓴다(§4-1 의 분량 문제).
// - J `{char:<id>}`: 대사가 특정 인물을 이름으로 지목한다(§4-5 의 블라인드 선택지).
//
// 합성 번들로 규칙을 고정하고, 일상 냉각만 실제 스토리 데이터로도 20일을 돌려 확인한다.
// 100일 완주 기준의 재방송 비율 실측은 test/rerun_share_test.dart 가 따로 한다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/engine/text_template.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// 도우미
// ---------------------------------------------------------------------------

StoryBundle realBundle() {
  registerMinigames();
  return StoryBundle.fromJsonStrings(
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
  );
}

const _chars = [
  {'id': 'a', 'name': '아름', 'gender': 'f', 'role': 'senior'},
  {'id': 'b', 'name': '보미', 'gender': 'f', 'role': 'parttime'},
];

const _endings = [
  {'id': 'def', 'name': '기본', 'priority': 0, 'default': true, 'when': {}},
];

Map<String, Object?> _config({
  int? dailyCooldownDays,
  List<String>? openingScript,
  int totalDays = 40,
}) => {
  'totalDays': totalDays,
  'maxHearts': 9,
  'heartRegenMinutes': 1,
  'initialStats': const {'charm': 30, 'stress': 10, 'money': 30},
  'actions': const [
    {
      'id': 'act',
      'name': '행동',
      'effects': {
        'stats': {'charm': 1},
      },
    },
  ],
  'dailyCooldownDays': ?dailyCooldownDays,
  'openingScript': ?openingScript,
};

/// 선택지 하나짜리 이벤트.
Map<String, Object?> _event(
  String id,
  String layer, {
  int? day,
  String? character,
  String? cliffhanger,
  bool once = false,
  Map<String, Object?>? trigger,
  List<List<String>>? variants,
}) => {
  'id': id,
  'layer': layer,
  'day': ?day,
  'character': ?character,
  'cliffhanger': ?cliffhanger,
  'trigger': ?trigger,
  'once': once,
  'title': id,
  'lines': [
    {'who': 'them', 'text': '$id 대사'},
  ],
  'variants': ?variants
      ?.map(
        (v) => {
          'lines': [
            for (final t in v) {'who': 'them', 'text': t},
          ],
        },
      )
      .toList(),
  'choices': [
    {
      'text': '응',
      'effects': {
        'affection': {'*': 1},
      },
    },
  ],
};

StoryBundle fixture({
  required List<Map<String, Object?>> events,
  Map<String, Object?>? config,
}) => StoryBundle.fromJsonStrings(
  config: jsonEncode(config ?? _config()),
  characters: jsonEncode(_chars),
  events: [jsonEncode(events)],
  endings: jsonEncode(_endings),
);

/// 하루를 계획하고 모든 이벤트를 첫 번째(잠기지 않은) 선택지로 넘긴 뒤 마감한다.
/// 실제 플레이와 같은 경로를 타야 `seen`·냉각 기록이 쌓인다.
List<List<StoryEvent>> playDays(EventEngine engine, GameState s, int days) {
  final out = <List<StoryEvent>>[];
  for (var d = 0; d < days; d++) {
    final plan = engine.planDay(s);
    out.add(plan);
    for (final ev in plan) {
      final views = engine.choicesFor(s, ev);
      if (views.isEmpty) continue;
      final v = views.firstWhere(
        (c) => !c.locked,
        orElse: () => views.first,
      );
      engine.applyChoice(s, ev, ev.choices[v.index], forcedSuccess: true);
    }
    engine.endDay(s);
  }
  return out;
}

/// (일상 id, 같은 id 가 다시 나오기까지의 간격) 중 가장 짧은 것. 반복이 없으면 null.
({String id, int gap})? shortestDailyRepeat(List<List<StoryEvent>> days) {
  final last = <String, int>{};
  ({String id, int gap})? worst;
  for (var i = 0; i < days.length; i++) {
    for (final e in days[i]) {
      if (e.layer != EventLayer.daily) continue;
      final prev = last[e.id];
      if (prev != null) {
        final gap = i - prev;
        if (worst == null || gap < worst.gap) worst = (id: e.id, gap: gap);
      }
      last[e.id] = i;
    }
  }
  return worst;
}

void main() {
  // -------------------------------------------------------------------------
  group('B. 일상 반복 냉각 (config.dailyCooldownDays)', () {
    test('실제 데이터 20일 × 시드 30 × 선호 2쪽: 냉각 기간 안에 같은 일상이 없다', () {
      final bundle = realBundle();
      final cool = bundle.config.dailyCooldownDays;
      expect(cool, 14, reason: 'assets/story/config.json 의 값');
      var runs = 0;
      for (final pref in [Preference.female, Preference.male]) {
        for (var seed = 1; seed <= 30; seed++) {
          final engine = EventEngine(bundle);
          final s = GameState.fresh(
            bundle.config,
            bundle.characters,
            seed: seed,
            preference: pref,
            nowMs: 0,
          );
          final days = playDays(engine, s, 20);
          runs++;
          final repeat = shortestDailyRepeat(days);
          expect(
            repeat?.gap ?? cool,
            greaterThanOrEqualTo(cool),
            reason:
                '시드 $seed($pref): ${repeat?.id} 가 ${repeat?.gap}일 만에 다시 나왔다',
          );
        }
      }
      expect(runs, 60);
    });

    test('냉각을 끄면(0) 예전 그대로 20일 안에 같은 일상이 되풀이된다', () {
      // 같은 데이터·같은 시드로 냉각만 껐을 때 반복이 실제로 일어나는지 — 위 테스트가
      // 데이터가 넉넉해서 저절로 통과하는 게 아니라는 확인이다.
      final raw = jsonDecode(File('assets/story/config.json').readAsStringSync())
          as Map<String, dynamic>;
      raw['dailyCooldownDays'] = 0;
      // 반복을 막는 장치는 이제 둘이다 — 냉각(이 테스트의 대상)과 반복 감쇠.
      // 냉각만 끄면 감쇠가 여전히 반복을 12/30 회차로 눌러서, 이 테스트가
      // "냉각이 없으면 반복한다"를 증명하지 못한다. 그래서 감쇠도 같이 끈다
      // (감쇠 자체의 증명은 test/rerun_share_test.dart 가 따로 한다).
      raw['repeatWeightPercent'] = 100;
      raw['fillSeenBelow'] = 99;
      final bundle = StoryBundle.fromJsonStrings(
        config: jsonEncode(raw),
        characters: File('assets/story/characters.json').readAsStringSync(),
        events: [
          for (final f in StoryBundle.eventFiles)
            File('assets/story/$f').readAsStringSync(),
        ],
        endings: File('assets/story/endings.json').readAsStringSync(),
        signals: File('assets/story/signals.json').readAsStringSync(),
        knownMinigames: minigameIds,
      );
      expect(bundle.config.dailyCooldownDays, 0);
      var repeated = 0;
      for (var seed = 1; seed <= 30; seed++) {
        final engine = EventEngine(bundle);
        final s = GameState.fresh(
          bundle.config,
          bundle.characters,
          seed: seed,
          preference: Preference.female,
          nowMs: 0,
        );
        final r = shortestDailyRepeat(playDays(engine, s, 20));
        if (r != null && r.gap < 14) repeated++;
      }
      expect(
        repeated,
        greaterThan(20),
        reason: '진단(07 (c)#8)은 300시드 전부에서 반복이었다',
      );
    });

    test('후보가 전부 냉각 중이면 그날은 냉각을 무시하고 하루를 채운다', () {
      // 일상이 둘뿐이라 3일째에는 반드시 냉각과 부딪힌다. 그래도 하루가 비면 안 된다.
      final b = fixture(
        config: _config(dailyCooldownDays: 10),
        events: [_event('d1', 'daily'), _event('d2', 'daily')],
      );
      final engine = EventEngine(b);
      final s = GameState.fresh(b.config, b.characters, seed: 7, nowMs: 0);
      final days = playDays(engine, s, 6);
      for (var i = 0; i < days.length; i++) {
        expect(days[i], isNotEmpty, reason: '${i + 1}일차가 비었다');
      }
      // 앞 이틀 안에 둘 다 한 번씩은 나온다(같은 장면만 두 번 틀지 않는다).
      // 어느 날 어느 쪽이 먼저 나오는지는 시드 문제라 고정하지 않는다 —
      // 반복 감쇠(GameConfig.repeatWeightPercent)가 들어오면서 순서가 바뀌었고,
      // 이 테스트가 확인하려는 것은 순서가 아니라 '하루가 비지 않는다'와 '변화가 있다'다.
      expect(
        {...days[0].map((e) => e.id), ...days[1].map((e) => e.id)},
        {'d1', 'd2'},
      );
      expect(engine.dailyPool(s), hasLength(2), reason: '냉각뿐이면 원래 후보로 되돌린다');
    });

    test('세이브: dailySeenDay 는 추가만 — 없는 예전 세이브는 빈 맵으로 읽힌다', () {
      final b = fixture(events: [_event('d1', 'daily')]);
      final s = GameState.fresh(b.config, b.characters, seed: 1, nowMs: 0);
      s.noteDailySeen('d1', cooldownDays: 14);
      final json = s.toJson();
      expect(json['dailySeenDay'], {'d1': 1});
      expect(GameState.fromJson(json).dailySeenDay, {'d1': 1});
      // 예전 세이브(칸 없음) → 빈 맵, 냉각 중인 일상 없음.
      final legacy = Map<String, dynamic>.of(json)..remove('dailySeenDay');
      final old = GameState.fromJson(legacy);
      expect(old.dailySeenDay, isEmpty);
      expect(EventEngine(b).dailyPool(old), hasLength(1));
      final nulled = Map<String, dynamic>.of(json)..['dailySeenDay'] = null;
      expect(GameState.fromJson(nulled).dailySeenDay, isEmpty);
      // 망가진 값은 stats·dayDelta 등 기존 필드와 같은 계약 — 던지고,
      // SaveService.load 가 세이브를 버린다(test/save_migration_test.dart).
      final broken = Map<String, dynamic>.of(json)..['dailySeenDay'] = '망가짐';
      expect(() => GameState.fromJson(broken), throwsA(isA<TypeError>()));
    });

    test('냉각이 지난 기록은 버려서 세이브가 계속 커지지 않는다', () {
      final b = fixture(events: [_event('d1', 'daily')]);
      final s = GameState.fresh(b.config, b.characters, seed: 1, nowMs: 0);
      s.noteDailySeen('old', cooldownDays: 5);
      s.day = 10;
      s.noteDailySeen('new', cooldownDays: 5);
      expect(s.dailySeenDay.keys, ['new']);
    });
  });

  // -------------------------------------------------------------------------
  group('D. 클리프행어는 층 우선순위로 남는다', () {
    late GameController c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // 메인(클리프행어 있음) → 일상(클리프행어 있음) → 루트 순으로 하루가 찬다.
      final b = fixture(
        events: [
          _event('m01', 'main', day: 1, cliffhanger: '메인 훅', once: true),
          _event('d1', 'daily', cliffhanger: '일상 훅'),
          // 실제 루트는 전부 once(한 회차 한 번) — 단계가 하루에 하나씩 나간다.
          _event('a_r00', 'route', character: 'a', cliffhanger: '루트 훅', once: true),
          _event('a_r01', 'route', character: 'a', cliffhanger: '루트 훅2', once: true),
        ],
      );
      c = GameController(bundle: b, save: SaveService(), clock: () => 0);
      await c.init();
      await c.markIntroSeen();
      await c.newGame(preference: Preference.female, seed: 3);
    });

    test('층 순위는 메인 > 위기 > 히든 > 루트 > 일상', () {
      expect(
        GameController.cliffhangerRankOf(EventLayer.main),
        lessThan(GameController.cliffhangerRankOf(EventLayer.route)),
      );
      expect(
        GameController.cliffhangerRankOf(EventLayer.route),
        lessThan(GameController.cliffhangerRankOf(EventLayer.daily)),
      );
      expect(
        GameController.cliffhangerRankOf(EventLayer.crisis),
        lessThan(GameController.cliffhangerRankOf(EventLayer.hidden)),
      );
    });

    test('메인 뒤에 온 일상·루트가 메인의 클리프행어를 덮어쓰지 않는다', () async {
      await c.startDay(c.config.actions.first);
      final seen = <String>[];
      while (c.current != null) {
        seen.add(c.current!.id);
        c.choose(0);
        c.continueAfterChoice();
      }
      expect(seen.first, 'm01');
      expect(seen, containsAll(['d1', 'a_r00']), reason: '메인 뒤에 다른 층이 온다');
      expect(seen.indexOf('m01'), lessThan(seen.indexOf('d1')));
      expect(c.cliffhanger, '메인 훅');
      expect(
        c.cliffhangerRank,
        GameController.cliffhangerRankOf(EventLayer.main),
      );
      // 그리고 그 문장이 그대로 다음 날 아침으로 넘어간다.
      await c.endDay();
      expect(c.state!.lastCliffhanger, '메인 훅');
    });

    test('메인이 없는 날은 예전처럼 마지막 것(같은 층이면 나중 것)이 남는다', () async {
      // 2일차에는 메인이 없다 — 일상·루트만 남는다.
      await c.startDay(c.config.actions.first);
      while (c.current != null) {
        c.choose(0);
        c.continueAfterChoice();
      }
      await c.endDay();
      await c.startDay(c.config.actions.first);
      final layers = <EventLayer>[];
      while (c.current != null) {
        layers.add(c.current!.layer);
        c.choose(0);
        c.continueAfterChoice();
      }
      expect(layers, isNot(contains(EventLayer.main)));
      expect(c.cliffhanger, '루트 훅2', reason: '남은 층 중 가장 센 것(루트 > 일상)');
    });
  });

  // -------------------------------------------------------------------------
  group('E. 오프닝 대본 (config.openingScript)', () {
    List<Map<String, Object?>> events() => [
      _event('m01', 'main', day: 1, once: true),
      _event('m02', 'main', day: 2, once: true),
      _event('d_bet', 'daily', once: true),
      _event('d_bet_2', 'daily', once: true, trigger: {
        'day': [0, 0],
      }),
      _event('d1', 'daily'),
      _event('d2', 'daily'),
      _event('a_r00', 'route', character: 'a'),
    ];

    List<String> planIds(StoryBundle b, {int run = 1, int day = 1}) {
      final engine = EventEngine(b);
      final s = GameState.fresh(b.config, b.characters, seed: 11, nowMs: 0)
        ..run = run
        ..day = day;
      return [for (final e in engine.planDay(s)) e.id];
    }

    test('비어 있으면(지금 데이터) 아무것도 바뀌지 않는다', () {
      final real = realBundle();
      expect(real.config.openingScript, isEmpty);
      final plain = fixture(events: events());
      final scripted = fixture(
        events: events(),
        config: _config(openingScript: const []),
      );
      expect(planIds(scripted), planIds(plain));
    });

    test('1회차 D+1 에만, 적힌 순서대로 맨 앞에 깔린다', () {
      final b = fixture(
        events: events(),
        config: _config(openingScript: const ['d_bet', 'm01']),
      );
      final ids = planIds(b);
      expect(ids.take(2).toList(), ['d_bet', 'm01']);
      expect(ids.length, greaterThanOrEqualTo(4), reason: '오프닝은 4개까지 채운다');
      // 대본이 이미 넣은 메인을 두 번 넣지 않는다.
      expect(ids.where((i) => i == 'm01'), hasLength(1));
      // 2일차와 2회차 첫날은 대본을 쓰지 않는다 — 하루가 평소처럼 메인으로 시작한다.
      expect(planIds(b, day: 2).first, 'm02');
      expect(planIds(b, run: 2).first, 'm01');
    });

    test('오늘 낼 수 없는 이벤트(트리거 불일치)는 대본이라도 건너뛴다', () {
      // d_bet_2 는 trigger day [0,0] — 어느 날도 아니다.
      final b = fixture(
        events: events(),
        config: _config(openingScript: const ['d_bet_2', 'd_bet']),
      );
      final ids = planIds(b);
      expect(ids, isNot(contains('d_bet_2')));
      expect(ids.first, 'd_bet');
    });

    test('없는 id 는 조용히 건너뛰고 나머지는 그대로 깔린다', () {
      final b = fixture(
        events: events(),
        config: _config(openingScript: const ['없는거', 'd_bet', '또없는거', 'm01']),
      );
      expect(planIds(b).take(2).toList(), ['d_bet', 'm01']);
    });

    test('대본 전체가 없는 id 여도 하루는 평소처럼 돈다', () {
      final b = fixture(
        events: events(),
        config: _config(openingScript: const ['없는거1', '없는거2']),
      );
      final ids = planIds(b);
      expect(ids, isNotEmpty);
      expect(ids.first, 'm01', reason: '평소 계획(메인 먼저)으로 되돌아간다');
    });

    test('config.json 이 칸을 몰라도(예전 데이터) 기본값으로 읽힌다', () {
      final b = fixture(events: events(), config: _config());
      expect(b.config.openingScript, isEmpty);
      expect(b.config.dailyCooldownDays, GameConfig.defaultDailyCooldownDays);
    });
  });

  // -------------------------------------------------------------------------
  // F. once — 한 회차에 한 번
  // -------------------------------------------------------------------------
  group('F. once 이벤트는 층과 무관하게 한 회차에 한 번만', () {
    test('기본값은 true — 칸이 없는 데이터는 한 번만 나온다', () {
      final e = StoryEvent.fromJson({
        'id': 'x',
        'layer': 'daily',
        'choices': [
          {'text': '응'},
        ],
      });
      expect(e.once, isTrue);
      expect(
        StoryEvent.fromJson({
          'id': 'y',
          'layer': 'daily',
          'once': false,
          'choices': [
            {'text': '응'},
          ],
        }).once,
        isFalse,
      );
    });

    test('daily·crisis·hidden·route 전부에서 두 번째 날에는 후보에서 빠진다', () {
      // 층마다 `once: true` 한 개씩. 첫날 후보에 있고, 보고 나면 사라져야 한다.
      final b = fixture(
        config: _config(dailyCooldownDays: 0),
        events: [
          _event('d1', 'daily', once: true),
          _event('c1', 'crisis', once: true),
          _event('h1', 'hidden', once: true),
          _event('a_r00', 'route', character: 'a', once: true),
        ],
      );
      final engine = EventEngine(b);
      final s = GameState.fresh(b.config, b.characters, seed: 3, nowMs: 0);
      for (final layer in EventLayer.values) {
        if (layer == EventLayer.main) continue;
        expect(
          engine.candidates(s, layer).map((e) => e.id),
          hasLength(1),
          reason: '$layer 첫날 후보',
        );
      }
      // 실제로 재생해 `seen` 을 쌓는다.
      for (final id in ['d1', 'c1', 'h1', 'a_r00']) {
        final ev = b.eventById[id]!;
        engine.applyChoice(s, ev, ev.choices.first, forcedSuccess: true);
      }
      engine.endDay(s);
      for (final layer in EventLayer.values) {
        expect(
          engine.candidates(s, layer),
          isEmpty,
          reason: '$layer: once 인데 이튿날 후보로 돌아왔다',
        );
      }
      // 냉각을 껐어도(= 일상 냉각과 무관하게) 일상 풀도 비어 있다.
      expect(engine.dailyPool(s), isEmpty);
    });

    test('once 판정은 세이브를 거쳐도 유지된다', () {
      final b = fixture(
        events: [_event('d1', 'daily', once: true), _event('d2', 'daily')],
      );
      final engine = EventEngine(b);
      final s = GameState.fresh(b.config, b.characters, seed: 1, nowMs: 0);
      final ev = b.eventById['d1']!;
      engine.applyChoice(s, ev, ev.choices.first, forcedSuccess: true);
      engine.endDay(s);
      final restored = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(restored.seen, contains('d1'));
      expect(engine.candidates(restored, EventLayer.daily).map((e) => e.id), [
        'd2',
      ]);
    });

    test('일상이 전부 once 인 데이터는 validate(requireDailyDepth) 가 막는다', () {
      // 소프트락 방지선. 이걸 막지 않으면 100일 후반에 일상 칸이 통째로 빈다.
      Object? err;
      try {
        fixture(
          config: _config(dailyCooldownDays: 3),
          events: [
            _event('d1', 'daily', once: true),
            _event('d2', 'daily', once: true),
          ],
        ).validate(requireDailyDepth: true);
      } catch (e) {
        err = e;
      }
      expect(err, isStateError);
      expect('$err', contains('반복 가능한 일상'));
      // 기본(검사 끔)에서는 통과한다 — 합성 번들이 다 깨지지 않게.
      expect(
        () => fixture(
          config: _config(dailyCooldownDays: 3),
          events: [_event('d1', 'daily', once: true)],
        ).validate(),
        returnsNormally,
      );
    });
  });

  // -------------------------------------------------------------------------
  // G. 반복 감쇠 (config.repeatWeightPercent)
  // -------------------------------------------------------------------------
  group('G. 반복 감쇠 (config.repeatWeightPercent)', () {
    /// 일상 `n`개 중 하나만 미리 `views`번 본 상태로 만들고, 30시드 동안
    /// 그 장면이 몇 번 뽑히는지 센다.
    int picksOfSeenOne({required int repeatPercent, required int views}) {
      final b = fixture(
        // 냉각을 꺼서 감쇠만 보이게 한다.
        config: {
          ..._config(dailyCooldownDays: 0),
          'repeatWeightPercent': repeatPercent,
        },
        events: [for (var i = 0; i < 4; i++) _event('d$i', 'daily')],
      );
      final engine = EventEngine(b);
      var hits = 0;
      for (var seed = 1; seed <= 30; seed++) {
        final s = GameState.fresh(b.config, b.characters, seed: seed, nowMs: 0);
        for (var i = 0; i < views; i++) {
          s.noteSeenCount('d0');
        }
        s.seen.add('d0');
        // 오프닝 규칙을 피해 4일차부터 하루를 계획한다.
        s.day = 4;
        if (engine.planDay(s).any((e) => e.id == 'd0')) hits++;
      }
      return hits;
    }

    test('한 번 본 장면은 처음 보는 장면보다 덜 뽑힌다', () {
      final never = picksOfSeenOne(repeatPercent: 20, views: 0);
      final once = picksOfSeenOne(repeatPercent: 20, views: 1);
      final twice = picksOfSeenOne(repeatPercent: 20, views: 2);
      expect(once, lessThan(never), reason: '1회 본 것이 안 본 것보다 덜 나와야 한다');
      expect(twice, lessThanOrEqualTo(once), reason: '2회 본 것은 1회보다 더 덜');
    });

    test('가중치가 본 횟수마다 실제로 깎인다 (감쇠를 끄면 안 깎인다)', () {
      // 위 통계 테스트가 데이터 우연이 아니라 감쇠 때문임을 가중치 값으로 고정한다.
      List<int> weights(int repeatPercent) {
        final b = fixture(
          config: {..._config(), 'repeatWeightPercent': repeatPercent},
          events: [_event('d1', 'daily')],
        );
        final engine = EventEngine(b);
        final s = GameState.fresh(b.config, b.characters, seed: 1, nowMs: 0);
        final ev = b.eventById['d1']!;
        return [
          for (var i = 0; i <= 5; i++)
            () {
              final w = engine.pickWeight(s, ev);
              s.noteSeenCount('d1');
              return w;
            }(),
        ];
      }

      final decayed = weights(20);
      expect(decayed.first, EventEngine.repeatWeightScale);
      for (var i = 1; i < decayed.length; i++) {
        expect(
          decayed[i],
          lessThan(decayed[i - 1]),
          reason: '$i번 본 뒤에도 가중치가 안 줄었다: $decayed',
        );
      }
      expect(decayed.last, greaterThanOrEqualTo(1), reason: '하한은 1');
      // 100 = 감쇠 없음. 몇 번을 봐도 가중치가 같다.
      expect(weights(100).toSet(), hasLength(1));
    });

    test('감쇠만으로 후보가 비지는 않는다 (가중치 하한 1)', () {
      final b = fixture(
        config: {
          ..._config(dailyCooldownDays: 0),
          'repeatWeightPercent': 0,
        },
        events: [_event('d1', 'daily')],
      );
      final engine = EventEngine(b);
      final s = GameState.fresh(b.config, b.characters, seed: 5, nowMs: 0);
      for (var i = 0; i < 20; i++) {
        s.noteSeenCount('d1');
      }
      s.seen.add('d1');
      s.day = 4;
      expect(engine.planDay(s).map((e) => e.id), contains('d1'));
    });

    test('세이브: seenCount 는 추가만 — 없는 예전 세이브는 빈 맵으로 읽힌다', () {
      final b = fixture(events: [_event('d1', 'daily')]);
      final s = GameState.fresh(b.config, b.characters, seed: 1, nowMs: 0);
      final engine = EventEngine(b);
      final ev = b.eventById['d1']!;
      engine.applyChoice(s, ev, ev.choices.first, forcedSuccess: true);
      final json = s.toJson();
      expect(json['seenCount'], {'d1': 1});
      expect(GameState.fromJson(json).viewsOf('d1'), 1);
      // 예전 세이브(칸 없음) → 빈 맵. 감쇠가 꺼진 것과 같아 예전처럼 굴러간다.
      final legacy = Map<String, dynamic>.of(json)..remove('seenCount');
      final restored = GameState.fromJson(legacy);
      expect(restored.seenCount, isEmpty);
      expect(restored.viewsOf('d1'), 0);
    });

    test('되돌리기는 본 횟수도 선택 직전으로 돌린다', () async {
      // 되돌린 장면이 '한 번 본 것'으로 남으면 다음 추첨에서 부당하게 뒤로 밀린다.
      SharedPreferences.setMockInitialValues({});
      final b = fixture(
        events: [
          _event('m01', 'main', day: 1, once: true),
          _event('d1', 'daily'),
          _event('d2', 'daily'),
        ],
      );
      final c = GameController(bundle: b, save: SaveService(), clock: () => 0);
      await c.init();
      await c.markIntroSeen();
      await c.newGame(preference: Preference.female, seed: 3);
      await c.startDay(c.config.actions.first);
      // 일상이 나올 때까지 진행하며, 그 선택 직후에 되돌린다.
      while (c.current != null && c.current!.layer != EventLayer.daily) {
        c.choose(0);
        c.continueAfterChoice();
      }
      final ev = c.current!;
      expect(ev.once, isFalse);
      expect(c.state!.viewsOf(ev.id), 0);
      c.choose(0);
      expect(c.state!.viewsOf(ev.id), 1);
      c.undoChoice();
      expect(
        c.state!.viewsOf(ev.id),
        0,
        reason: '되돌렸는데 본 횟수가 남았다 — 감쇠가 헛돈다',
      );
      expect(c.state!.seen, isNot(contains(ev.id)));
    });

    test('once 이벤트는 본 횟수를 세지 않는다 (세이브를 키우지 않는다)', () {
      final b = fixture(
        events: [_event('d1', 'daily', once: true), _event('d2', 'daily')],
      );
      final engine = EventEngine(b);
      final s = GameState.fresh(b.config, b.characters, seed: 1, nowMs: 0);
      for (final id in ['d1', 'd2']) {
        final ev = b.eventById[id]!;
        engine.applyChoice(s, ev, ev.choices.first, forcedSuccess: true);
      }
      expect(s.seenCount.keys, ['d2']);
      expect(engine.viewsOf(s, b.eventById['d1']!), 0);
    });
  });

  // -------------------------------------------------------------------------
  // H. 카운트다운 (11_story_verdict §4-3)
  // -------------------------------------------------------------------------
  group('H. 카운트다운을 엔진이 내준다', () {
    test('daysLeft 는 대본(m_week1 "오늘로 D-93")과 같은 축척이다', () {
      const cfg = GameConfig(totalDays: 100);
      final s = GameState(seed: 1, stats: {}, relations: {});
      s.day = 7;
      expect(s.daysLeft(cfg), 93);
      s.day = 1;
      expect(s.daysLeft(cfg), 99);
      s.day = 100;
      expect(s.daysLeft(cfg), 0);
      // 마지막 날을 넘겨도 음수가 되지 않는다.
      s.day = 120;
      expect(s.daysLeft(cfg), 0);
    });

    test('분기점은 config 가 정하고, 칸이 없으면 기본 목록이다', () {
      final b = fixture(events: [_event('d1', 'daily')]);
      expect(
        b.config.countdownMilestones,
        GameConfig.defaultCountdownMilestones,
      );
      const cfg = GameConfig(totalDays: 100, countdownMilestones: [93, 50]);
      final s = GameState(seed: 1, stats: {}, relations: {});
      s.day = 7;
      expect(s.isCountdownMilestone(cfg), isTrue);
      s.day = 8;
      expect(s.isCountdownMilestone(cfg), isFalse);
      s.day = 50;
      expect(s.isCountdownMilestone(cfg), isTrue);
    });

    test('출시 config 는 분기점을 가지고 있고 100일 중 열흘 넘게 걸린다', () {
      final b = realBundle();
      expect(b.config.countdownMilestones, isNotEmpty);
      final s = GameState.fresh(b.config, b.characters, seed: 1, nowMs: 0);
      var hits = 0;
      for (var d = 1; d <= b.config.totalDays; d++) {
        s.day = d;
        if (s.isCountdownMilestone(b.config)) hits++;
      }
      // 실측은 카운트다운이 화면에 4~5일만 떴다. 분기점만으로도 그보다 많아야 한다.
      expect(hits, greaterThan(5), reason: '분기점이 실측(4~5일)보다 적으면 의미가 없다');
    });

    test('SaveSummary 가 화면에 daysLeft·분기점을 내준다', () {
      final b = realBundle();
      final s = GameState.fresh(b.config, b.characters, seed: 1, nowMs: 0)
        ..day = 50;
      final sum = SaveSummary.fromState(s, b.config, b.characters);
      expect(sum.daysLeft, 50);
      expect(sum.countdownMilestone, isTrue, reason: 'D-50 은 기본 분기점이다');
      s.day = 51;
      expect(
        SaveSummary.fromState(s, b.config, b.characters).countdownMilestone,
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  // I. 변형 대사 (StoryEvent.variants)
  // -------------------------------------------------------------------------
  group('I. 변형 대사 (variants)', () {
    /// 변형 둘을 단 일상 하나(= 대사 묶음 셋).
    StoryBundle three() => fixture(
      config: _config(dailyCooldownDays: 0),
      events: [
        _event('d1', 'daily', variants: [
          ['d1 두 번째'],
          ['d1 세 번째'],
        ]),
      ],
    );

    /// [views]번 본 상태에서 화면에 뜨는 첫 줄.
    String shownLine(StoryBundle b, int seed, int views) {
      final engine = EventEngine(b);
      final s = GameState.fresh(b.config, b.characters, seed: seed, nowMs: 0);
      for (var i = 0; i < views; i++) {
        s.noteSeenCount('d1');
      }
      return engine.viewFor(s, b.eventById['d1']!).lines.first.text;
    }

    test('변형이 없으면 원본 그대로 (칸이 없는 예전 데이터)', () {
      final b = fixture(events: [_event('d1', 'daily')]);
      expect(b.eventById['d1']!.variants, isEmpty);
      expect(shownLine(b, 1, 0), 'd1 대사');
      expect(shownLine(b, 1, 5), 'd1 대사', reason: '변형이 없으면 몇 번을 봐도 같다');
    });

    test('연속해서 같은 대사가 나오지 않고, 세 번째에 원래 것으로 돌아온다', () {
      final b = three();
      for (var seed = 1; seed <= 20; seed++) {
        final seq = [for (var v = 0; v < 3; v++) shownLine(b, seed, v)];
        expect(
          seq.toSet(),
          hasLength(3),
          reason: '시드 $seed: 세 번 보는 동안 대사가 겹쳤다 — $seq',
        );
        // 네 번째는 첫 번째와 같다(회전).
        expect(shownLine(b, seed, 3), seq.first);
      }
    });

    test('회차 시드가 다르면 첫 대사도 갈린다', () {
      final b = three();
      final firsts = {for (var seed = 1; seed <= 30; seed++) shownLine(b, seed, 0)};
      expect(firsts, hasLength(3), reason: '시드를 30개 돌려도 첫 대사가 한 종류면 회전 시작점이 죽었다');
    });

    test('같은 회차·같은 본 횟수면 언제나 같다 (세이브를 거쳐도)', () {
      final b = three();
      final engine = EventEngine(b);
      final s = GameState.fresh(b.config, b.characters, seed: 9, nowMs: 0);
      s.noteSeenCount('d1');
      final a = engine.viewFor(s, b.eventById['d1']!).lines.first.text;
      // 날이 바뀌어도 같다 — 회전 시작점에 날짜를 섞지 않는다.
      s.day = 57;
      expect(engine.viewFor(s, b.eventById['d1']!).lines.first.text, a);
      final restored = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(engine.viewFor(restored, b.eventById['d1']!).lines.first.text, a);
      // 세이브에 변형 때문에 더 적는 칸은 없다.
      expect(s.toJson().containsKey('variants'), isFalse);
    });

    test('바뀌는 것은 대사뿐 — 선택지·효과·id 는 그대로', () {
      final b = three();
      final engine = EventEngine(b);
      final s = GameState.fresh(b.config, b.characters, seed: 2, nowMs: 0);
      s.noteSeenCount('d1');
      final base = b.eventById['d1']!;
      final shown = engine.viewFor(s, base);
      expect(shown.id, base.id);
      expect(shown.layer, base.layer);
      expect(shown.once, base.once);
      expect(shown.choices.length, base.choices.length);
      expect(shown.choices.first.text, base.choices.first.text);
      expect(shown.variants, base.variants, reason: '변형 목록은 사본에도 남는다');
    });

    test('검증기: 빈 변형 · once 에 변형 · 사진 유무 불일치를 막는다', () {
      expect(
        () => fixture(
          events: [_event('d1', 'daily', variants: [[]]),
          ],
        ),
        throwsStateError,
      );
      expect(
        () => fixture(
          events: [
            _event('d1', 'daily', once: true, variants: [
              ['또'],
            ]),
          ],
        ),
        throwsStateError,
      );
      // 원본에 없는 사진 줄을 변형이 들고 오면 모먼트 판정이 회차마다 달라진다.
      expect(
        () => fixture(
          events: [
            {
              'id': 'd1',
              'layer': 'daily',
              'once': false,
              'lines': [
                {'who': 'them', 'text': '원본'},
              ],
              'variants': [
                {
                  'lines': [
                    {
                      'who': 'them',
                      'photo': {'asset': 'x.png', 'caption': '사진'},
                    },
                  ],
                },
              ],
              'choices': [
                {'text': '응'},
              ],
            },
          ],
        ),
        throwsStateError,
      );
    });

    test('검증기: 변형 안의 자리표시자 오타도 잡는다', () {
      expect(
        () => fixture(
          events: [
            _event('d1', 'daily', variants: [
              ['{topp} 잘 지냈어'],
            ]),
          ],
        ),
        throwsStateError,
      );
      // 제대로 쓴 것은 통과한다.
      expect(
        () => fixture(
          events: [
            _event('d1', 'daily', variants: [
              ['{top|아야} 잘 지냈어'],
            ]),
          ],
        ),
        returnsNormally,
      );
    });

    test('출시 데이터: 변형이 붙은 이벤트는 전부 반복 가능하다', () {
      // 콘텐츠가 변형을 붙이는 중이다. 붙은 것이 하나도 없어도 이 테스트는 통과하고,
      // 붙었다면 `once: true` 에 잘못 달리지 않았는지 본다(검증기와 같은 규칙).
      final b = realBundle();
      final withVariants = b.events.where((e) => e.variants.isNotEmpty);
      for (final e in withVariants) {
        expect(e.once, isFalse, reason: '${e.id}: once 인데 변형이 붙었다');
      }
    });
  });

  // -------------------------------------------------------------------------
  // J. {char:<id>} — 대사가 특정 인물을 부른다
  // -------------------------------------------------------------------------
  group('J. {char:<id>} 자리표시자', () {
    const chars = {'a': '아름', 'b': '보미', 'haneul': '하늘'};

    String fill(String s) => TextTemplate.fill(s, name: '민수', chars: chars);

    test('이름과 조사가 {name}·{top} 과 같은 규칙으로 붙는다', () {
      expect(fill('{char:a}'), '아름');
      // 아름: 받침 있음(ㅁ).
      expect(fill('{char:a|이가} 왔다'), '아름이 왔다');
      expect(fill('{char:a|아야}'), '아름아');
      expect(fill('{char:a|이랑랑} 갈래'), '아름이랑 갈래');
      // 보미: 받침 없음.
      expect(fill('{char:b|이가} 왔다'), '보미가 왔다');
      expect(fill('{char:b|아야}'), '보미야');
      // 하늘: ㄹ 받침 → '로'.
      expect(fill('{char:haneul|으로로}'), '하늘로');
      expect(fill('{char:a|씨+이가}'), '아름 씨가');
    });

    test('{name}·{top} 과 섞여도 각자 제 사람을 부른다', () {
      expect(
        TextTemplate.fill(
          '{name|아야}, {char:b|이가} {top|을를} 찾아',
          name: '민수',
          top: '아름',
          chars: chars,
        ),
        '민수야, 보미가 아름을 찾아',
      );
    });

    test('이름을 못 찾으면 id 가 아니라 중립 명사로 떨어진다', () {
      expect(TextTemplate.fill('{char:nobody|이가}', chars: chars), '그 사람이');
      expect(TextTemplate.fill('{char:nobody}', chars: chars), '그 사람');
      // 대체어를 적었으면 그것.
      expect(TextTemplate.fill('{char:nobody|은는|그}', chars: chars), '그는');
      // 호격은 부를 이름이 없으면 통째로 지운다({name}·{top} 과 같다).
      expect(TextTemplate.fill('{char:nobody|아야}, 자?', chars: chars), '자?');
    });

    test('형식이 틀린 것은 자리표시자로 읽지 않는다', () {
      for (final bad in ['{char:}', '{char:a|몰라}', '{char:a|아야|여분|더}']) {
        expect(
          TextTemplate.problems(bad),
          isNotEmpty,
          reason: '$bad 를 정상으로 읽었다',
        );
      }
    });

    test('id 를 여러 개 적으면 이 회차에 있는 첫 사람을 쓴다', () {
      // 한 레코드가 여성 회차·남성 회차에서 각각 맞는 사람을 부른다
      // (12_content_handoff §6.1 의 d_meet_05 · d_family_02 · m01).
      const fOnly = {'a': '아름'};
      const mOnly = {'haneul': '하늘'};
      expect(TextTemplate.fill('{char:a,haneul|이가}', chars: fOnly), '아름이');
      expect(TextTemplate.fill('{char:a,haneul|이가}', chars: mOnly), '하늘이');
      // 적은 순서대로 — 둘 다 있으면 앞의 사람.
      expect(TextTemplate.fill('{char:a,haneul}', chars: chars), '아름');
      expect(TextTemplate.fill('{char:haneul,a}', chars: chars), '하늘');
      // 아무도 없으면 대체어, 없으면 중립 명사.
      expect(TextTemplate.fill('{char:x,y|은는|그}', chars: chars), '그는');
      expect(TextTemplate.fill('{char:x,y|은는}', chars: chars), '그 사람은');
      // 빈 id 는 자리표시자로 읽지 않는다.
      expect(TextTemplate.problems('{char:a,}'), isNotEmpty);
    });

    test('회차 이름표는 선호 밖 캐릭터를 담지 않는다', () {
      final b = realBundle();
      final f = b.charNamesFor(Preference.female);
      final m = b.charNamesFor(Preference.male);
      expect(f.keys.toSet().intersection(m.keys.toSet()), isEmpty,
          reason: '여성/남성 회차 이름표가 겹치면 선호 격리가 깨진 것이다');
      expect(b.charNames.length, greaterThan(f.length));
      // 여성 회차 대사가 남성 쪽 id 를 부르면 이름이 아니라 중립 명사가 나온다.
      final mId = m.keys.first;
      expect(TextTemplate.fill('{char:$mId}', chars: f), TextTemplate.topFallback);
    });

    test('charIdsIn 이 지목된 id 를 다 모은다', () {
      expect(
        TextTemplate.charIdsIn('{char:a|이가} {char:b} {name} {char:a}'),
        {'a', 'b'},
      );
      // 쉼표 목록도 전부 모은다 — 검증기가 목록 안의 오타를 놓치지 않는다.
      expect(TextTemplate.charIdsIn('{char:a,b,haneul}'), {'a', 'b', 'haneul'});
      expect(TextTemplate.charIdsIn('{name|아야} {top}'), isEmpty);
    });

    test('검증기: 없는 캐릭터를 지목하면 출시 전에 막힌다', () {
      expect(
        () => fixture(
          events: [
            _event('d1', 'daily', variants: [
              ['{char:없는사람|이가} 왔다'],
            ]),
          ],
        ),
        throwsStateError,
      );
      Object? err;
      try {
        fixture(events: [_event('d1', 'daily', variants: [['{char:zzz}']])]);
      } catch (e) {
        err = e;
      }
      expect('$err', contains('{char:zzz}'));
      // 있는 캐릭터(_chars 의 a·b)는 통과한다.
      expect(
        () => fixture(
          events: [
            _event('d1', 'daily', variants: [
              ['{char:a|이가} 왔다'],
            ]),
          ],
        ),
        returnsNormally,
      );
      expect(
        () => fixture(
          events: [
            _event('d1', 'daily', variants: [
              ['{char:a,b|이가} 왔다'],
            ]),
          ],
        ),
        returnsNormally,
      );
      // 쉼표 목록 안의 오타도 잡는다.
      expect(
        () => fixture(
          events: [
            _event('d1', 'daily', variants: [
              ['{char:a,없는사람|이가} 왔다'],
            ]),
          ],
        ),
        throwsStateError,
      );
    });

    test('길이 검사가 실제 이름으로 잰다', () {
      // {char:a} = 아름(2글자) → " 왔다"(3) 포함 5글자.
      expect(TextTemplate.maxLength('{char:a} 왔다', chars: chars), 5);
      // 모르는 id 는 '그 사람'(4글자)이 최악값.
      expect(TextTemplate.maxLength('{char:zzz} 왔다', chars: chars), 7);
    });

    test('컨트롤러의 say 가 출시 데이터의 이름으로 바꿔 준다', () {
      final b = realBundle();
      final id = b.characters.first.id;
      expect(
        TextTemplate.fill('{char:$id|이가} 왔다', chars: b.charNames),
        '${b.characters.first.name}${TextTemplate.particleFor(b.characters.first.name, '이가')} 왔다',
      );
    });
  });
}
