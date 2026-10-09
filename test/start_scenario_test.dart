// 개편 2 — 시작 스토리·소문·파급 줄 엔진(docs/overhaul2/01_design.md §3·§5.0·§5.1·§5.2).
//
// 콘텐츠(events_start.json 등)는 작가가 따로 채운다. 여기서는 그 콘텐츠가 없어도 성립해야
// 하는 엔진 규칙과, 콘텐츠가 들어왔을 때 지켜야 할 불변식(시작마다 D1~3 main 정확히 하나)을 본다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/analytics/analytics.dart';
import 'package:mossol/engine/attendance.dart';
import 'package:mossol/engine/effects.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/mbti.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/heat_gauge.dart';
import 'package:mossol/ui/start_pick_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'story_files.dart';
import 'widget/helpers.dart';

/// 합성 번들의 최소 재료.
const _config = '{"initialStats": {"charm": 10}, "actions": []}';
const _chars = '''[
  {"id": "a", "name": "가람", "gender": "f", "role": "senior"},
  {"id": "b", "name": "나래", "gender": "m", "role": "senior"}
]''';
const _endings = '[{"id": "solo", "name": "솔로", "tier": "solo", "default": true}]';

Map<String, dynamic> _ev(
  String id, {
  String layer = 'daily',
  int? day,
  Map<String, dynamic>? trigger,
  List<Map<String, dynamic>>? lines,
  List<Map<String, dynamic>>? choices,
}) => {
  'id': id,
  'layer': layer,
  'day': ?day,
  'trigger': ?trigger,
  'lines': lines ?? [
    {'who': 'them', 'text': '안녕'},
  ],
  'choices':
      choices ??
      [
        {'text': '하나', 'effects': {'setFlags': ['f_one']}},
        {'text': '둘'},
      ],
};

StoryBundle _bundle(List<Map<String, dynamic>> events, {Object? starts}) =>
    StoryBundle.fromJsonStrings(
      config: _config,
      characters: _chars,
      events: [jsonEncode(events)],
      endings: _endings,
      starts: starts == null ? null : jsonEncode(starts),
    );

Map<String, dynamic> _start(
  String id, {
  Map<String, dynamic>? effects,
  int unlock = 0,
}) => {
  'id': id,
  'title': '제목',
  'hook': '훅',
  'introLine': '내 말',
  'introReply': '태현 말',
  'spice': 1,
  'unlockEndings': unlock,
  'effects':
      effects ??
      (id == StartScenario.classic
          ? <String, dynamic>{}
          : {
              'setFlags': [StartScenario.altFlag, id],
            }),
};

/// 실제 데이터(시작 정의 포함).
StoryBundle _real() => StoryBundle.fromJsonStrings(
  config: readStoryFile('config.json'),
  characters: readStoryFile('characters.json'),
  events: [for (final f in StoryBundle.eventFiles) readStoryFile(f)],
  endings: readStoryFile('endings.json'),
  starts: readStartsFile(),
  requireEndingHints: true,
  requireDailyDepth: true,
);

void main() {
  // ---------------------------------------------------------------------------
  group('starts.json (B1)', () {
    late StoryBundle b;
    setUpAll(() => b = _real());

    test('6종, id 유일, classic 포함, 신규는 sc_* 와 start_alt 를 세운다', () {
      final ids = [for (final s in b.starts) s.id];
      expect(ids.toSet().length, ids.length);
      expect(ids, [
        'classic',
        'sc_leak',
        'sc_speech',
        'sc_clip',
        'sc_swap',
        'sc_ghost',
      ]);
      final classic = b.startOf(StartScenario.classic)!;
      expect(classic.effects.setFlags, isEmpty);
      expect(classic.effects.stats, isEmpty);
      expect(classic.image, 'assets/scenes/m01');
      for (final s in b.starts.where((s) => !s.isClassic)) {
        expect(
          s.effects.setFlags,
          containsAll([StartScenario.altFlag, s.id]),
          reason: s.id,
        );
        expect(s.image, 'assets/scenes/${s.id}_d1');
        expect(s.introLine, isNotEmpty);
        expect(s.introReply, isNotEmpty);
        expect(s.tags, hasLength(2));
      }
    });

    test('§3.0 상한: 스탯 ±10, 진정성 −5 이상, 호감 +4 까지, 시작 소문 40 이하', () {
      for (final s in b.starts) {
        final fx = s.effects;
        fx.stats.forEach((k, v) {
          if (k == Stat.heat) {
            expect(v, inInclusiveRange(0, 40), reason: '${s.id}.$k');
          } else {
            expect(v.abs(), lessThanOrEqualTo(10), reason: '${s.id}.$k');
          }
        });
        expect(fx.stats[Stat.sincerity] ?? 0, greaterThanOrEqualTo(-5));
        fx.affection.forEach(
          (k, v) => expect(v, inInclusiveRange(0, 4), reason: '${s.id}.$k'),
        );
      }
      // §3.1 표의 시작 소문.
      final heat = {for (final s in b.starts) s.id: s.effects.stats[Stat.heat]};
      expect(heat, {
        'classic': null,
        'sc_leak': 30,
        'sc_speech': 35,
        'sc_clip': 40,
        'sc_swap': 15,
        'sc_ghost': 10,
      });
    });

    test('해금: 처음부터 4종(클래식·단톡·축사·마이크), 환승은 엔딩 1개, 새벽 3시는 2개', () {
      List<String> open(int n) => [
        for (final s in b.starts)
          if (s.unlockedBy(n)) s.id,
      ];
      expect(open(0), ['classic', 'sc_leak', 'sc_speech', 'sc_clip']);
      expect(open(1), contains('sc_swap'));
      expect(open(1), isNot(contains('sc_ghost')));
      expect(open(2), hasLength(6));
    });

    test('가속 호감은 같은 역할의 f/m 짝 두 명', () {
      for (final s in b.starts.where((s) => !s.isClassic)) {
        final ids = s.effects.affection.keys.toList();
        expect(ids, hasLength(2), reason: s.id);
        final chars = [for (final id in ids) b.characterById[id]!];
        expect(chars.map((c) => c.gender).toSet(), {'f', 'm'}, reason: s.id);
        expect(chars.map((c) => c.role).toSet(), hasLength(1), reason: s.id);
      }
    });

    test('파일이 없으면 클래식 하나뿐(예전 데이터 호환)', () {
      final none = _bundle([_ev('d1')]);
      expect(none.starts, isEmpty);
      expect(none.startsOrClassic.single.id, StartScenario.classic);
    });

    group('검증기가 거부한다', () {
      void bad(List<Map<String, dynamic>> starts, String why) => expect(
        () => _bundle([_ev('d1')], starts: {'starts': starts}),
        throwsA(isA<StateError>()),
        reason: why,
      );

      test('규칙 위반', () {
        bad([_start('sc_x')], 'classic 없음');
        bad([_start('classic'), _start('classic')], 'id 중복');
        bad([
          _start('classic'),
          _start('sc_x', effects: {
            'setFlags': ['sc_x'],
          }),
        ], 'start_alt 없음');
        bad([
          _start('classic'),
          _start('sc_x', effects: {
            'setFlags': ['start_alt'],
          }),
        ], '자기 id 없음');
        bad([
          _start('classic'),
          _start('x_bad', effects: {
            'setFlags': ['start_alt', 'x_bad'],
          }),
        ], 'sc_ 접두어');
        bad([
          _start('classic', effects: {
            'setFlags': ['start_alt'],
          }),
        ], '클래식이 플래그를 세움');
        bad([
          _start('classic'),
          _start('sc_x', effects: {
            'stats': {'nope': 1},
            'setFlags': ['start_alt', 'sc_x'],
          }),
        ], '없는 스탯 키');
        bad([
          _start('classic'),
          _start('sc_x', effects: {
            'stats': {'heat': 41},
            'setFlags': ['start_alt', 'sc_x'],
          }),
        ], '소문 40 초과');
        bad([
          _start('classic'),
          _start('sc_x', effects: {
            'stats': {'charm': 11},
            'setFlags': ['start_alt', 'sc_x'],
          }),
        ], '스탯 ±10 초과');
        bad([
          _start('classic'),
          _start('sc_x', effects: {
            'affection': {'a': 5},
            'setFlags': ['start_alt', 'sc_x'],
          }),
        ], '호감 +4 초과');
        bad([
          _start('classic'),
          _start('sc_x', effects: {
            'affection': {'zz': 1},
            'setFlags': ['start_alt', 'sc_x'],
          }),
        ], '없는 캐릭터');
        bad([
          _start('classic'),
          _start('sc_x', effects: {
            'setFlags': ['start_alt', 'sc_x', 'seoyeon_met'],
          }),
        ], '루트 플래그');
      });
    });
  });

  // ---------------------------------------------------------------------------
  group('newGame(start) (B2)', () {
    late StoryBundle b;
    setUpAll(() => b = testBundle());

    Future<GameController> ctl() async {
      SharedPreferences.setMockInitialValues({});
      final c = GameController(
        bundle: b,
        save: SaveService(),
        analytics: Analytics(backend: RecordingAnalyticsBackend()),
      );
      await c.init();
      return c;
    }

    test('신규 시작: 플래그와 보정이 교차 회차 보너스 다음에 붙는다', () async {
      final c = await ctl();
      await c.save.addEnding('forever_solo');
      c.endingAlbum = await c.save.loadEndings();
      await c.newGame(seed: 1, preference: Preference.female);
      final classic = Map.of(c.state!.stats);
      await c.newGame(
        seed: 1,
        preference: Preference.female,
        start: 'sc_leak',
      );
      final s = c.state!;
      expect(s.flags, {StartScenario.altFlag, 'sc_leak'});
      final leak = b.startOf('sc_leak')!.effects.stats;
      for (final k in Stat.all) {
        expect(
          s.stat(k),
          (classic[k]! + (leak[k] ?? 0)).clamp(0, Stat.maxOf(k)),
          reason: k,
        );
      }
      // 교차 회차 보너스(엔딩 1개 → 화술 +1)는 그대로 들어 있다.
      expect(c.runBonus, crossRunBonus(1));
      expect(s.stat(Stat.heat), 30);
      // 여성 회차: 다은(f) +4, 하늘(m, 이 회차에 없음)은 0.
      expect(s.affectionOf('daeun'), 4);
      expect(s.affectionOf('haneul'), 0);
      expect(c.meta!.lastStart, 'sc_leak');
      // 시작 보정은 오늘의 정산 변화가 아니다.
      expect(c.dayDelta.stats, isEmpty);
    });

    test('클래식(기본값)은 플래그도 소문도 없다, 모르는 id 도 클래식', () async {
      final c = await ctl();
      await c.newGame(seed: 2, preference: Preference.male);
      expect(c.state!.flags, isEmpty);
      expect(c.state!.stat(Stat.heat), 0);
      await c.newGame(seed: 2, preference: Preference.male, start: 'nope');
      expect(c.state!.flags, isEmpty);
      expect(c.meta!.lastStart, StartScenario.classic);
    });

    test('nextRun 은 시작을 넘긴다', () async {
      final c = await ctl();
      await c.newGame(seed: 3, preference: Preference.female);
      await c.nextRun(start: 'sc_clip');
      expect(c.state!.run, 2);
      expect(c.state!.flags, contains('sc_clip'));
      expect(c.state!.stat(Stat.heat), 40);
    });

    test('run_started 에 start 가 실린다', () async {
      SharedPreferences.setMockInitialValues({});
      final rec = RecordingAnalyticsBackend();
      final c = GameController(
        bundle: b,
        save: SaveService(),
        analytics: Analytics(backend: rec),
      );
      await c.init();
      await c.newGame(seed: 1, preference: Preference.female, start: 'sc_speech');
      expect(rec.paramsOf(Analytics.runStarted).single['start'], 'sc_speech');
    });
  });

  // ---------------------------------------------------------------------------
  group('클래식 오프닝은 그대로, 신규 시작은 클래식 장면을 피한다 (B4)', () {
    late StoryBundle b;
    late EventEngine e;
    setUpAll(() {
      b = testBundle();
      e = EventEngine(b);
    });

    GameState fresh(String pref, {Set<String> flags = const {}}) =>
        GameState.fresh(b.config, b.characters, seed: 7, preference: pref)
          ..flags.addAll(flags);

    const classicOnly = [
      'm01',
      'm02',
      'm_brief',
      'm_brief_m',
      'd_open_story',
      'd_open_pfp_who',
      'd_open_app_match',
    ];

    test('클래식 전용 장면 7개는 notFlags 에 start_alt', () {
      for (final id in classicOnly) {
        expect(
          b.eventById[id]!.trigger.notFlags,
          contains(StartScenario.altFlag),
          reason: id,
        );
      }
    });

    test('start=classic: D+1 main 은 여전히 m01', () {
      for (final pref in Preference.genders) {
        final mains = e.candidates(fresh(pref), EventLayer.main);
        expect(mains.map((x) => x.id), ['m01'], reason: pref);
      }
    });

    test('예전 세이브(플래그 칸 없음)는 클래식으로 이어진다', () {
      final s = fresh(Preference.female);
      final j = s.toJson()
        ..remove('flags')
        ..remove('preference');
      (j['stats'] as Map).remove(Stat.heat);
      final old = GameState.fromJson(j);
      expect(old.flags, isEmpty);
      expect(old.stat(Stat.heat), 0, reason: '소문 키가 없으면 0');
      expect(e.candidates(old, EventLayer.main).map((x) => x.id), ['m01']);
    });

    test('신규 시작 회차에는 클래식 전용 장면이 후보에 오르지 않는다', () {
      for (final pref in Preference.genders) {
        for (var day = 1; day <= 3; day++) {
          final s = fresh(pref, flags: {StartScenario.altFlag, 'sc_leak'})
            ..day = day;
          final ids = {
            for (final l in [EventLayer.main, EventLayer.daily])
              for (final x in e.candidates(s, l)) x.id,
          };
          for (final id in classicOnly) {
            expect(ids, isNot(contains(id)), reason: '$pref D$day $id');
          }
        }
      }
    });

    test('내기(d_open_bet)는 신규 시작에서 일상으로 뽑히지 않고 D2 main 의 next 로만 열린다', () {
      final bet = b.eventById['d_open_bet']!;
      expect(bet.trigger.notFlags, contains(StartScenario.altFlag));
      for (final st in b.starts.where((s) => !s.isClassic)) {
        for (final pref in Preference.genders) {
          final s = fresh(pref, flags: {...st.effects.setFlags})..day = 2;
          final d2 = e.candidates(s, EventLayer.main).single;
          expect(
            d2.choices.where((c) => c.next == 'd_open_bet'),
            isNotEmpty,
            reason: '${st.id} $pref ${d2.id}',
          );
          for (var day = 1; day <= 3; day++) {
            s.day = day;
            expect(
              e.dailyPool(s).map((x) => x.id),
              isNot(contains('d_open_bet')),
              reason: '${st.id} D$day',
            );
          }
        }
      }
      // 클래식의 증인 단톡 선언은 첫 소문 공급원이다(§3.2).
      final bet2 = b.eventById['d_open_bet_2']!;
      expect(bet2.choices.first.effects.stats[Stat.heat], 8);
    });

    test('시작마다 D1~3 main 은 정확히 하나(콘텐츠가 들어온 시작만)', () {
      for (final st in b.starts) {
        final hasContent =
            st.isClassic || b.eventById.containsKey('${st.id}_d1');
        if (!hasContent) continue;
        for (final pref in Preference.genders) {
          for (var day = 1; day <= 3; day++) {
            final s = fresh(pref, flags: {...st.effects.setFlags})..day = day;
            final mains = e.candidates(s, EventLayer.main);
            expect(
              mains,
              hasLength(1),
              reason: '${st.id} $pref D$day: ${mains.map((x) => x.id)}',
            );
          }
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  group('main 날짜 검증 키 (pref, startKey) (B3)', () {
    Map<String, dynamic> main(String id, Map<String, dynamic>? trigger) =>
        _ev(id, layer: 'main', day: 1, trigger: trigger);

    test('mainStartKey', () {
      expect(StoryBundle.mainStartKey(Trigger.always), isNull);
      expect(
        StoryBundle.mainStartKey(
          Trigger.fromJson({
            'flags': ['sc_leak'],
          }),
        ),
        'sc_leak',
      );
      expect(
        StoryBundle.mainStartKey(
          Trigger.fromJson({
            'notFlags': ['start_alt'],
          }),
        ),
        StartScenario.classic,
      );
    });

    test('서로 다른 시작·쪽은 같은 날에 둘 수 있다', () {
      expect(
        () => _bundle([
          main('c1', {
            'notFlags': ['start_alt'],
          }),
          main('l1', {
            'flags': ['sc_leak'],
          }),
          main('k1f', {
            'flags': ['sc_clip'],
            'pref': 'f',
          }),
          main('k1m', {
            'flags': ['sc_clip'],
            'pref': 'm',
          }),
        ]),
        returnsNormally,
      );
    });

    test('공용은 모든 시작과, 같은 시작·같은 쪽은 서로 겹친다', () {
      for (final pair in [
        [
          main('x', null),
          main('l1', {
            'flags': ['sc_leak'],
          }),
        ],
        [
          main('l1', {
            'flags': ['sc_leak'],
          }),
          main('l2', {
            'flags': ['sc_leak'],
          }),
        ],
        [
          main('k1', {
            'flags': ['sc_clip'],
          }),
          main('k1f', {
            'flags': ['sc_clip'],
            'pref': 'f',
          }),
        ],
        [
          main('c1', {
            'notFlags': ['start_alt'],
          }),
          main('c2', {
            'notFlags': ['start_alt'],
            'pref': 'm',
          }),
        ],
      ]) {
        expect(
          () => _bundle(pair),
          throwsA(isA<StateError>()),
          reason: '${pair.map((e) => e['id'])}',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  group('파급 줄 ifFlags / ifNotFlags (F2)', () {
    final ev = _ev(
      'd1',
      lines: [
        {'who': 'them', 'text': '공통'},
        {
          'who': 'them',
          'text': '박제 갈래',
          'ifFlags': ['f_one'],
        },
        {
          'who': 'them',
          'text': '아직',
          'ifNotFlags': 'f_one',
        },
      ],
      choices: [
        {
          'text': '하나',
          'effects': {
            'setFlags': ['f_one'],
          },
        },
        {'text': '둘'},
        {
          'text': '진상',
          'ifFlags': ['f_one'],
          'reply': [
            {'who': 'them', 'text': '그래'},
            {
              'who': 'them',
              'text': '숨은 줄',
              'ifNotFlags': ['f_one'],
            },
          ],
        },
      ],
    );

    test('줄과 선택지가 플래그로 걸러진다(MBTI 거르기와 같은 자리)', () {
      final b = _bundle([ev]);
      final e = EventEngine(b);
      final raw = b.eventById['d1']!;
      final s = GameState.fresh(b.config, b.characters, seed: 1);

      List<String> lines(StoryEvent v) => [for (final l in v.lines) l.text];
      final none = e.viewFor(s, raw);
      expect(lines(none), ['공통', '아직']);
      expect(none.choices.map((c) => c.text), ['하나', '둘']);
      expect(e.choicesFor(s, raw).map((v) => v.index), [0, 1]);

      s.flags.add('f_one');
      final some = e.viewFor(s, raw);
      expect(lines(some), ['공통', '박제 갈래']);
      expect(some.choices.map((c) => c.text), ['하나', '둘', '진상']);
      expect(some.choices[2].reply.map((l) => l.text), ['그래']);
      expect(e.choicesFor(s, raw).map((v) => v.index), [0, 1, 2]);
    });

    test('MbtiView.allowsFlags', () {
      const v = MbtiView(null, flags: {'a', 'b'});
      expect(v.allowsFlags(['a'], const []), isTrue);
      expect(v.allowsFlags(['a', 'c'], const []), isFalse);
      expect(v.allowsFlags(const [], ['c']), isTrue);
      expect(v.allowsFlags(const [], ['c', 'b']), isFalse);
    });

    test('검증: 조건 없는 선택지가 2개 미만이면 오류', () {
      expect(
        () => _bundle([
          _ev(
            'd1',
            choices: [
              {
                'text': '하나',
                'effects': {
                  'setFlags': ['f_one'],
                },
              },
              {
                'text': '둘',
                'ifNotFlags': ['f_one'],
              },
              {
                'text': '셋',
                'ifFlags': ['f_one'],
              },
            ],
          ),
        ]),
        throwsA(isA<StateError>()),
      );
    });

    test('검증: 아무도 세우지 않는 플래그를 읽으면 오류(오타 방지), 시작이 세우면 통과', () {
      Map<String, dynamic> reads(String f) => _ev(
        'd1',
        lines: [
          {'who': 'them', 'text': '공통'},
          {
            'who': 'them',
            'text': '갈래',
            'ifFlags': [f],
          },
        ],
      );
      expect(() => _bundle([reads('typo_flag')]), throwsA(isA<StateError>()));
      expect(() => _bundle([reads('f_one')]), returnsNormally);
      expect(
        () => _bundle(
          [reads('sc_x')],
          starts: {
            'starts': [_start('classic'), _start('sc_x')],
          },
        ),
        returnsNormally,
      );
      // 엔진이 직접 세우는 플래그도 읽을 수 있다.
      expect(() => _bundle([reads('album_10')]), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  group('소문 heat (F1)', () {
    test('스탯 키·이름·상한·숨김', () {
      expect(Stat.all, contains(Stat.heat));
      expect(Stat.hidden, contains(Stat.heat));
      expect(Stat.visible, isNot(contains(Stat.heat)));
      expect(Stat.label(Stat.heat), '소문');
      expect(Stat.maxOf(Stat.heat), 100);
      expect(Stat.isGood(Stat.heat, 5), isFalse);
      expect(Stat.isGood(Stat.heat, -5), isTrue);
    });

    test('구간 5칸: 0 은 꺼짐, 1~19 한 칸 … 80~100 다섯 칸', () {
      expect(HeatGauge.shows(0), isFalse);
      expect(HeatGauge.litOf(0), 0);
      expect(HeatGauge.litOf(1), 1);
      expect(HeatGauge.litOf(19), 1);
      expect(HeatGauge.litOf(20), 2);
      expect(HeatGauge.litOf(59), 3);
      expect(HeatGauge.litOf(60), 4);
      expect(HeatGauge.litOf(100), 5);
      expect(Stat.heatBands[Stat.heatBand(85)], '대참사');
    });

    test('config: 초기 0, 휴식 −6, 0 아래로 내려가지 않는다', () {
      final b = testBundle();
      expect(b.config.initialStats[Stat.heat], 0);
      final rest = b.config.actions.firstWhere((a) => a.id == 'rest');
      expect(rest.effects.stats[Stat.heat], -6);
      final s = GameState.fresh(b.config, b.characters, seed: 1);
      final d = applyEffects(s, rest.effects);
      expect(s.stat(Stat.heat), 0);
      expect(d.stats.containsKey(Stat.heat), isFalse, reason: '변화 없음은 정산에 안 뜬다');
      s.stats[Stat.heat] = 4;
      applyEffects(s, rest.effects);
      expect(s.stat(Stat.heat), 0);
    });

    test('dailyDrift: 출시 config 는 밤마다 소문 −1, 0 아래로 안 내려간다', () {
      final b = testBundle();
      expect(b.config.dailyDrift, {Stat.heat: -1});
      final e = EventEngine(b);
      final s = GameState.fresh(b.config, b.characters, seed: 1)
        ..stats[Stat.heat] = 2;
      e.endDay(s);
      expect(s.stat(Stat.heat), 1);
      e.endDay(s);
      e.endDay(s);
      expect(s.stat(Stat.heat), 0);
      // 키가 없는 예전 세이브도 0 에서 멈춘다.
      s.stats.remove(Stat.heat);
      e.endDay(s);
      expect(s.stat(Stat.heat), 0);
    });

    test('dailyDrift 는 스탯 일반: 상한·하한으로 자르고, 없는 키는 검증기가 거부', () {
      StoryBundle withDrift(String drift) => StoryBundle.fromJsonStrings(
        config:
            '{"initialStats": {"charm": 99, "talk": 1}, "actions": [], '
            '"dailyDrift": $drift}',
        characters: _chars,
        events: [
          jsonEncode([_ev('d1')]),
        ],
        endings: _endings,
      );
      final b = withDrift('{"charm": 3, "talk": -5}');
      final s = GameState.fresh(b.config, b.characters, seed: 1);
      EventEngine(b).endDay(s);
      expect(s.stat(Stat.charm), 100);
      expect(s.stat(Stat.talk), 0);
      // 칸이 없으면 변화 없음(예전 그대로).
      final none = _bundle([_ev('d1')]);
      expect(none.config.dailyDrift, isEmpty);
      expect(() => withDrift('{"nope": -1}'), throwsA(isA<StateError>()));
    });

    test('예전 세이브(heat 키 없음)는 0 으로 읽힌다', () {
      final b = testBundle();
      final j = GameState.fresh(b.config, b.characters, seed: 1).toJson();
      (j['stats'] as Map).remove(Stat.heat);
      final s = GameState.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>);
      expect(s.stats.containsKey(Stat.heat), isFalse);
      expect(s.stat(Stat.heat), 0);
    });

    test('소문만 오른 선택은 "좋은 선택"(콤보)이 아니다', () {
      final b = _bundle([
        _ev(
          'd1',
          choices: [
            {
              'text': '판을 키운다',
              'effects': {
                'stats': {'heat': 10},
              },
            },
            {
              'text': '조용히',
              'effects': {
                'stats': {'charm': 1},
              },
            },
          ],
        ),
      ]);
      final e = EventEngine(b);
      final s = GameState.fresh(b.config, b.characters, seed: 1);
      final ev = b.eventById['d1']!;
      e.applyChoice(s, ev, ev.choices[0]);
      expect(s.combo, 0);
      expect(s.stat(Stat.heat), 10);
      e.applyChoice(s, ev, ev.choices[1]);
      expect(s.combo, 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('운명 뽑기', () {
    test('바로 전 시작은 뺀다, 하나뿐이면 그대로', () {
      final b = testBundle();
      final pool = StartPickSheet.fatePool(b.starts, 'sc_leak');
      expect(pool.map((s) => s.id), isNot(contains('sc_leak')));
      expect(pool, hasLength(b.starts.length - 1));
      const only = [StartScenario(id: 'classic', title: '치킨')];
      expect(StartPickSheet.fatePool(only, 'classic'), only);
    });

    test('잠금 안내 문구', () {
      expect(StartPickSheet.lockText(1, 0), '엔딩 1개를 보면 열려요');
      expect(StartPickSheet.lockText(2, 1), '엔딩 1개 더 보면 열려요');
    });
  });

  // ---------------------------------------------------------------------------
  group('리뷰 후속', () {
    test('시작 호감 보정은 첫 접촉 전까지 밤 감소를 받지 않는다(클래식은 그대로)', () {
      final b = testBundle();
      final e = EventEngine(b);
      final s = GameState.fresh(
        b.config,
        b.characters,
        seed: 1,
        preference: Preference.female,
      )..flags.addAll({StartScenario.altFlag, 'sc_leak'});
      applyEffects(s, b.startOf('sc_leak')!.effects, absent: e.absentFor(s));
      s.rel('seoyeon').affection = 4; // 보정 없는 사람은 평소대로 준다.
      for (var i = 0; i < 6; i++) {
        e.endDay(s);
      }
      expect(s.affectionOf('daeun'), 4, reason: '접촉 전에는 그대로');
      expect(s.affectionOf('seoyeon'), 0);
      // 다은의 장면을 한 번 보면 그때부터는 평소 규칙.
      s.seen.add('daeun_r00');
      e.endDay(s);
      expect(s.affectionOf('daeun'), 3);

      final classic = GameState.fresh(b.config, b.characters, seed: 1);
      classic.rel('daeun').affection = 4;
      e.endDay(classic);
      expect(classic.affectionOf('daeun'), 3);
    });

    test('검증: 반응 줄을 같은 선택지가 세우는 플래그로 가르면 오류', () {
      expect(
        () => _bundle([
          _ev(
            'd1',
            choices: [
              {
                'text': '하나',
                'effects': {
                  'setFlags': ['f_one'],
                },
                'reply': [
                  {'who': 'them', 'text': '응'},
                  {
                    'who': 'them',
                    'text': '세웠지',
                    'ifFlags': ['f_one'],
                  },
                ],
              },
              {'text': '둘'},
            ],
          ),
        ]),
        throwsA(isA<StateError>()),
      );
    });

    test('검증: 플래그가 선 경우의 화면도 본다(전부 ifNotFlags 면 대사 0줄)', () {
      expect(
        () => _bundle([
          _ev(
            'd1',
            lines: [
              {
                'who': 'them',
                'text': '아직',
                'ifNotFlags': ['f_one'],
              },
            ],
          ),
        ]),
        throwsA(isA<StateError>()),
      );
    });

    test('"새로 열림" 배지는 한 번만', () async {
      SharedPreferences.setMockInitialValues({});
      final c = GameController(
        bundle: testBundle(),
        save: SaveService(),
        analytics: Analytics(backend: RecordingAnalyticsBackend()),
      );
      await c.init();
      expect(c.newlyUnlockedStarts, isEmpty);
      await c.save.addEnding('forever_solo');
      c.endingAlbum = await c.save.loadEndings();
      expect(c.newlyUnlockedStarts, {'sc_swap'});
      await c.markStartsAnnounced(c.newlyUnlockedStarts);
      expect(c.newlyUnlockedStarts, isEmpty);
    });

    testWidgets('운명 뽑기는 한 흐름에서 한 번: 고정된 운명은 다시 뽑지 않고 잠겨 있어도 고를 수 있다', (
      tester,
    ) async {
      final b = testBundle();
      final results = <StartPick?>[];
      await tester.pumpWidget(
        wrapApp(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () async => results.add(
                await StartPickSheet.show(
                  ctx,
                  starts: b.starts,
                  endingCount: 0,
                  fateLocked: 'sc_ghost',
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        final key = i == 0 ? 'start-fate' : 'start-card-sc_ghost';
        await scrollStartSheetTo(tester, find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }
      expect(results, [
        (id: 'sc_ghost', fate: true),
        (id: 'sc_ghost', fate: true),
      ]);
    });

    testWidgets('정산 게이지: 소문이 있으면 "밤사이 −1"', (tester) async {
      await tester.pumpWidget(
        wrapApp(const HeatGauge(heat: 12, delta: 5, overnight: -1)),
      );
      expect(find.text(HeatGauge.overnightLabel(-1)), findsOneWidget);
      await tester.pumpWidget(wrapApp(const HeatGauge(heat: 0, overnight: -1)));
      expect(find.byKey(const Key('heat-overnight')), findsNothing);
    });
  });
}
