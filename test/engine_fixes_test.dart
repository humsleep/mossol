// 07·08 진단 수선의 회귀 테스트: 일상 반복 냉각 · 클리프행어 층 우선순위 · 오프닝 대본.
//
// - B 일상 냉각: `config.dailyCooldownDays` 안에 같은 일상이 두 번 나오지 않는다.
//   진단은 "시드 300 전부가 20일 안에 같은 일상을 두 번 이상 받는다"였다
//   (docs/review/07_story_flow.md (c)#8).
// - D 클리프행어: 메인의 클리프행어를 뒤에 온 일상·루트가 덮어쓰지 않는다((c)#12, S7).
// - E 오프닝 대본: 1회차 D+1 에 `config.openingScript` 가 먼저, 적힌 순서대로 깔린다((c)#4).
//
// 합성 번들로 규칙을 고정하고, 일상 냉각만 실제 스토리 데이터로도 20일을 돌려 확인한다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
      // 앞 이틀은 서로 다른 장면, 그 뒤로는 어쩔 수 없이 되풀이된다.
      expect({days[0].first.id, days[1].first.id}, {'d1', 'd2'});
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
}
