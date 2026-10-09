// 개편 2 · 1라운드 엔진 수정(docs/overhaul2/review/r1_meeting.md §3·§4 "엔진·UI").
//
// - §3 데이터 계약: `villain` 숨김 스탯, 이벤트 `clock`, `done_<start>`·`veteran` 엔진 플래그,
//   `starts.json` `recommended`.
// - D5 읽은 장면(회차 간 `seenEvents`, 무료 건너뛰기 조건, NEW 점), D6 갈래 클리프행어,
//   D7 회차 간 기록, D10 운명 고정, D11 오프닝 가속 캐릭터.
// - r1_bugs R1-4(main 날짜 키), R1-5(무거운 검증은 출시 빌드 밖), "범위 밖" 같은 날 재등장.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/analytics/analytics.dart';
import 'package:mossol/engine/effects.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/meta_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'story_files.dart';
import 'widget/helpers.dart';

const _config = '{"initialStats": {"charm": 10}, "actions": []}';
const _chars = '''[
  {"id": "a", "name": "가람", "gender": "f", "role": "senior"},
  {"id": "b", "name": "나래", "gender": "m", "role": "senior"}
]''';
const _endings =
    '[{"id": "solo", "name": "솔로", "tier": "solo", "default": true}]';

Map<String, dynamic> _ev(
  String id, {
  String layer = 'daily',
  int? day,
  Map<String, dynamic>? trigger,
  List<Map<String, dynamic>>? lines,
  List<Map<String, dynamic>>? choices,
  String? cliffhanger,
  String? clock,
  String? character,
  bool? once,
}) => {
  'id': id,
  'layer': layer,
  'day': ?day,
  'trigger': ?trigger,
  'cliffhanger': ?cliffhanger,
  'clock': ?clock,
  'character': ?character,
  'once': ?once,
  'lines':
      lines ??
      [
        {'who': 'them', 'text': '안녕'},
      ],
  'choices':
      choices ??
      [
        {'text': '하나'},
        {'text': '둘'},
      ],
};

Map<String, dynamic> _start(
  String id, {
  Map<String, dynamic>? effects,
  int unlock = 0,
  bool recommended = false,
}) => {
  'id': id,
  'title': '제목',
  'hook': '훅',
  'introLine': '내 말',
  'introReply': '태현 말',
  'unlockEndings': unlock,
  'recommended': ?(recommended ? true : null),
  'effects':
      effects ??
      (id == StartScenario.classic
          ? <String, dynamic>{}
          : {
              'setFlags': [StartScenario.altFlag, id],
            }),
};

StoryBundle _bundle(
  List<Map<String, dynamic>> events, {
  List<Map<String, dynamic>>? starts,
  bool? deep,
}) => StoryBundle.fromJsonStrings(
  config: _config,
  characters: _chars,
  events: [jsonEncode(events)],
  endings: _endings,
  starts: starts == null ? null : jsonEncode(starts),
  deep: deep,
);

Future<GameController> _ctl(StoryBundle b, {Analytics? analytics}) async {
  SharedPreferences.setMockInitialValues({});
  final c = GameController(bundle: b, save: SaveService(), analytics: analytics);
  await c.init();
  await c.markIntroSeen();
  return c;
}

/// 잠기지 않은 선택지 하나(평범한 것 먼저).
int _anyChoice(GameController c) {
  final open = c.choices.where((v) => !v.locked).toList();
  return (open.where((v) => v.choice.minigame == null && v.choice.chance == null).firstOrNull ??
          open.first)
      .index;
}

/// 오늘을 시작하고(하트 무시) 큐의 첫 이벤트에서 멈춘다.
Future<void> _startDay(GameController c) async {
  c.beginMorning();
  c.state!.hearts = c.config.maxHearts;
  await c.startDay(const DayAction(id: 'x', name: 'x', desc: ''));
}

void main() {
  // ---------------------------------------------------------------------------
  group('villain 숨김 스탯 (§3, D4)', () {
    test('숨김 스탯이고 0~99, 오르면 "좋은 선택" 이 아니다', () {
      expect(Stat.hidden, contains(Stat.villain));
      expect(Stat.visible, isNot(contains(Stat.villain)));
      expect(Stat.maxOf(Stat.villain), 99);
      expect(Stat.isGood(Stat.villain, 1), isFalse);
      final s = GameState.fresh(GameConfig.fromJson({}), const [], seed: 1, nowMs: 0);
      expect(s.stat(Stat.villain), 0, reason: '키 없는 예전 세이브는 0');
      for (var i = 0; i < 120; i++) {
        applyEffects(s, const Effects(stats: {Stat.villain: 1}));
      }
      expect(s.stat(Stat.villain), 99);
      applyEffects(s, const Effects(stats: {Stat.villain: -200}));
      expect(s.stat(Stat.villain), 0);
    });

    test('효과·트리거·요구에 쓸 수 있고 `stats.villain [3,99]` 로 열린다', () {
      final b = _bundle([
        _ev(
          'bad',
          choices: [
            {
              'text': '진상',
              'effects': {
                'stats': {'villain': 1},
              },
            },
            {'text': '참는다'},
          ],
        ),
        _ev(
          'rival',
          trigger: {
            'stats': {
              'villain': [3, 99],
            },
          },
        ),
      ]);
      final e = EventEngine(b);
      final s = GameState.fresh(b.config, b.characters, seed: 1, nowMs: 0);
      expect(e.candidates(s, EventLayer.daily).map((x) => x.id), ['bad']);
      for (var i = 0; i < 3; i++) {
        e.applyChoice(s, b.eventById['bad']!, b.eventById['bad']!.choices[0]);
      }
      expect(s.stat(Stat.villain), 3);
      expect(s.combo, 0, reason: '진상 +1 만 오른 선택은 콤보가 아니다');
      expect(e.candidates(s, EventLayer.daily).map((x) => x.id), contains('rival'));
    });

    test('config 의 initialStats 에 villain 0', () {
      expect(testBundle().config.initialStats[Stat.villain], 0);
    });
  });

  // ---------------------------------------------------------------------------
  group('이벤트 clock (§3, D8)', () {
    test('"HH:MM" 을 읽고 초로 바꾼다. 화면용 사본도 들고 간다', () {
      final ev = StoryEvent.fromJson(_ev('dawn', clock: '01:12'));
      expect(ev.clock, '01:12');
      expect(ev.clockSeconds, 1 * 3600 + 12 * 60);
      expect(ev.mapText((t) => t).clockSeconds, ev.clockSeconds);
      expect(ev.withLines(const []).clock, '01:12');
      expect(StoryEvent.fromJson(_ev('none')).clockSeconds, isNull);
    });

    test('검증기는 형식이 틀린 clock 을 거부한다', () {
      expect(() => _bundle([_ev('ok', clock: '23:59')]), returnsNormally);
      for (final bad in ['24:00', '1:12', '01:60', '새벽', '0112']) {
        expect(
          () => _bundle([_ev('x', clock: bad)]),
          throwsA(isA<StateError>()),
          reason: bad,
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  group('done_<start> · veteran (§3, D7)', () {
    final starts = [
      _start(StartScenario.classic),
      _start('sc_leak'),
      _start('sc_clip_x'),
    ];

    test('검증기: 엔진 플래그로 등록되어 대본이 읽어도 된다', () {
      final b = _bundle([
        _ev(
          'cameo',
          trigger: {
            'flags': ['done_sc_leak'],
            'notFlags': ['sc_leak'],
          },
          lines: [
            {'who': 'them', 'text': '어 그 말투', 'ifFlags': ['veteran']},
            {'who': 'them', 'text': '안녕'},
          ],
        ),
        _ev(
          'cameo2',
          trigger: {
            'flags': ['done_classic', 'veteran'],
          },
        ),
      ], starts: starts);
      expect(b.settableFlags, containsAll(['done_classic', 'done_sc_leak', 'veteran']));
    });

    test('검증기: 없는 시작의 done_* 는 오타로 거부한다', () {
      expect(
        () => _bundle([
          _ev(
            'cameo',
            trigger: {
              'flags': ['done_sc_lek'],
            },
          ),
        ], starts: starts),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('done_sc_lek')),
        ),
      );
    });

    test('새 게임이 메타 completedStarts 로 세우고, 엔딩이 기록한다', () async {
      final b = _bundle([_ev('d1')], starts: starts);
      final c = await _ctl(b);
      await c.newGame(seed: 1, start: 'sc_leak');
      expect(c.state!.flags.where((f) => f.startsWith('done_') || f == 'veteran'), isEmpty);
      // 엔딩까지 간다.
      c.state!.day = c.config.totalDays;
      await c.endDay();
      expect(c.ending, isNotNull);
      expect(c.completedStarts, ['sc_leak']);
      expect(c.startEndingCount('sc_leak'), 1);
      // 같은 시작을 또 끝내도 중복 없이.
      await c.nextRun(start: 'sc_leak');
      c.state!.day = c.config.totalDays;
      await c.endDay();
      expect(c.completedStarts, ['sc_leak']);
      expect(c.startEndingCount('sc_leak'), 1, reason: '같은 엔딩은 한 번');
      // 다음 회차(클래식)에 플래그가 선다.
      await c.nextRun();
      expect(c.state!.flags, containsAll(['done_sc_leak', 'veteran']));
      expect(c.state!.flags, isNot(contains('done_classic')));
      // 메타는 다시 읽어도 같다.
      final again = await MetaService().load();
      expect(again.completedStarts, ['sc_leak']);
      expect(again.startEndings, {
        'sc_leak': ['solo'],
      });
    });

    test('예전 세이브(플래그 없음)의 시작은 클래식으로 기록된다', () async {
      final b = _bundle([_ev('d1')], starts: starts);
      final c = await _ctl(b);
      await c.newGame(seed: 1);
      expect(c.engine.startIdOf(c.state!), StartScenario.classic);
      c.state!.day = c.config.totalDays;
      await c.endDay();
      expect(c.completedStarts, [StartScenario.classic]);
    });
  });

  // ---------------------------------------------------------------------------
  group('starts.json recommended (§3, D9)', () {
    test('읽고, 첫 회차 기본 선택이 된다. 그 뒤로는 아직 안 끝낸 첫 시작', () async {
      final b = _bundle(
        [_ev('d1')],
        starts: [
          _start(StartScenario.classic),
          _start('sc_leak', recommended: true),
          _start('sc_speech'),
          _start('sc_swap', unlock: 1),
        ],
      );
      expect(b.startOf('sc_leak')!.recommended, isTrue);
      final c = await _ctl(b);
      expect(c.isFirstOnboarding, isTrue);
      expect(c.suggestedStart, 'sc_leak');
      await c.newGame(seed: 1, start: 'sc_leak');
      c.state!.day = c.config.totalDays;
      await c.endDay();
      // 2회차: 클래식은 안 끝냈다 → 클래식이 첫 번째.
      expect(c.isFirstOnboarding, isFalse);
      expect(c.suggestedStart, StartScenario.classic);
      await c.nextRun();
      c.state!.day = c.config.totalDays;
      await c.endDay();
      expect(c.suggestedStart, 'sc_speech');
    });

    test('recommended 가 없으면 첫 회차 기본은 클래식', () async {
      final b = _bundle([_ev('d1')], starts: [_start(StartScenario.classic), _start('sc_leak')]);
      final c = await _ctl(b);
      expect(c.suggestedStart, StartScenario.classic);
    });

    test('검증기: 둘 이상이거나 잠긴 시작이면 거부', () {
      expect(
        () => _bundle([_ev('d1')], starts: [
          _start(StartScenario.classic, recommended: true),
          _start('sc_leak', recommended: true),
        ]),
        throwsA(isA<StateError>()),
      );
      expect(
        () => _bundle([_ev('d1')], starts: [
          _start(StartScenario.classic),
          _start('sc_swap', unlock: 1, recommended: true),
        ]),
        throwsA(isA<StateError>()),
      );
    });

    test('castLines: 없는 캐릭터·깨진 자리표시자는 거부', () {
      Map<String, dynamic> withLines(Map<String, String> m) =>
          _start('sc_leak')..['castLines'] = m;
      expect(
        () => _bundle([_ev('d1')], starts: [
          _start(StartScenario.classic),
          withLines({'a': '{name|아야} 안녕'}),
        ]),
        returnsNormally,
      );
      expect(
        () => _bundle([_ev('d1')], starts: [
          _start(StartScenario.classic),
          withLines({'zz': '안녕'}),
        ]),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('main 날짜 키는 실제 시작 id 로만 (r1_bugs R1-4)', () {
    Map<String, dynamic> main(String id, List<String> flags) => _ev(
      id,
      layer: 'main',
      day: 5,
      trigger: {'flags': flags},
      choices: [
        {
          'text': '하나',
          'effects': {
            'setFlags': ['sc_clip_deny'],
          },
        },
        {'text': '둘'},
      ],
    );
    final starts = [_start(StartScenario.classic), _start('sc_clip')];

    test('갈래 플래그 main 과 시작 main 이 같은 날이면 거부한다', () {
      expect(
        () => _bundle([
          main('m_a', ['sc_clip']),
          main('m_b', ['sc_clip_deny']),
        ], starts: starts),
        throwsA(isA<StateError>().having((e) => e.message, 'm', contains('main 날짜 중복'))),
      );
    });

    test('다른 시작끼리는 여전히 같은 날 둘 수 있다', () {
      expect(
        () => _bundle([
          main('m_a', ['sc_clip']),
          main('m_b', ['sc_leak']),
        ], starts: [...starts, _start('sc_leak')]),
        returnsNormally,
      );
    });

    test('startOfFlag 은 가장 긴 시작 id 접두어', () {
      final ids = ['classic', 'sc_clip', 'sc_clip_pro'];
      expect(StoryBundle.startOfFlag('sc_clip', ids), 'sc_clip');
      expect(StoryBundle.startOfFlag('sc_clip_deny', ids), 'sc_clip');
      expect(StoryBundle.startOfFlag('sc_clip_pro_x', ids), 'sc_clip_pro');
      expect(StoryBundle.startOfFlag('sc_clipper', ids), isNull);
      expect(
        StoryBundle.mainStartKey(
          Trigger.fromJson({
            'flags': ['sc_clip_deny'],
          }),
          startIds: ids,
        ),
        'sc_clip',
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('무거운 검증은 출시 빌드 밖에서만 (r1_bugs R1-5)', () {
    // 목소리(humor) 로만 갈린 대사: 한 값이 빠져 그 1위에게는 0줄 — 화면 검사가 잡는 문제.
    final silent = _ev(
      'quiet',
      lines: [
        {'who': 'them', 'text': '드라이', 'humor': ['dry']},
      ],
    );

    test('deep 이면 화면 검사까지, 아니면 건너뛴다', () {
      expect(() => _bundle([silent], deep: true), throwsA(isA<StateError>()));
      expect(() => _bundle([silent], deep: false), returnsNormally);
    });

    test('테스트(출시 아님)의 기본은 deep', () {
      expect(() => _bundle([silent]), throwsA(isA<StateError>()));
    });

    test('구조 검사는 deep 이 꺼져도 돈다 — 출시 빌드도 깨진 데이터에서 멈춘다', () {
      final broken = [
        _ev(
          'a',
          choices: [
            {'text': '하나', 'next': 'nowhere'},
            {'text': '둘'},
          ],
        ),
      ];
      expect(() => _bundle(broken, deep: false), throwsA(isA<StateError>()));
      expect(() => _bundle([_ev('a'), _ev('a')], deep: false), throwsA(isA<StateError>()));
      expect(
        () => _bundle([_ev('x', clock: '99:99')], deep: false),
        throwsA(isA<StateError>()),
      );
    });

    test('실제 데이터는 가벼운 검사(출시 빌드)로도 읽힌다', () {
      final b = StoryBundle.fromJsonStrings(
        config: File('assets/story/config.json').readAsStringSync(),
        characters: File('assets/story/characters.json').readAsStringSync(),
        events: [for (final f in StoryBundle.eventFiles) readStoryFile(f)],
        endings: File('assets/story/endings.json').readAsStringSync(),
        signals: File('assets/story/signals.json').readAsStringSync(),
        starts: readStartsFile(),
        requireEndingHints: true,
        requireDailyDepth: true,
        deep: false,
      );
      expect(b.events, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('같은 날 같은 장면이 next 로 두 번 끼지 않는다 (r1_bugs 범위 밖)', () {
    test('두 일상의 failNext 가 같은 모먼트로 이어져도 하루에 한 번', () async {
      Map<String, dynamic> risky(String id) => _ev(
        id,
        once: false,
        trigger: {
          'day': [1, 1],
        },
        choices: [
          {'text': '마신다', 'chance': 0, 'failNext': 'replay'},
          {'text': '참는다'},
        ],
      );
      final b = _bundle([
        risky('d_a'),
        risky('d_b'),
        _ev(
          'replay',
          once: false,
          trigger: {
            'day': [0, 0],
          },
        ),
      ]);
      final c = await _ctl(b);
      await c.newGame(seed: 3);
      await _startDay(c);
      final shown = <String>[];
      while (c.phase == Phase.event) {
        final ev = c.current!;
        shown.add(ev.id);
        c.choose(ev.id.startsWith('d_') ? 0 : 1);
        c.continueAfterChoice();
      }
      expect(shown.where((id) => id == 'replay').length, 1, reason: '$shown');
      expect(shown, containsAll(['d_a', 'd_b']));
    });
  });

  // ---------------------------------------------------------------------------
  group('갈래 클리프행어가 사슬 부모를 이긴다 (D6)', () {
    test('main → next 일상 갈래: 갈래의 예고가 남는다. 사슬 밖 일상은 main 을 못 이긴다', () async {
      final b = _bundle([
        _ev(
          'm1',
          layer: 'main',
          day: 1,
          cliffhanger: '부모 예고',
          choices: [
            {'text': '갈래로', 'next': 'branch'},
            {'text': '그냥'},
          ],
        ),
        _ev(
          'branch',
          cliffhanger: '갈래 예고',
          trigger: {
            'day': [0, 0],
          },
        ),
        _ev(
          'other',
          cliffhanger: '남의 예고',
          trigger: {
            'day': [1, 1],
          },
        ),
      ]);
      Future<String?> play(int pick) async {
        final c = await _ctl(b);
        await c.newGame(seed: 5);
        await _startDay(c);
        while (c.phase == Phase.event) {
          c.choose(c.current!.id == 'm1' ? pick : 0);
          c.continueAfterChoice();
        }
        return c.cliffhanger;
      }

      expect(await play(0), '갈래 예고');
      expect(await play(1), '부모 예고');
    });
  });

  // ---------------------------------------------------------------------------
  group('운명 고정 (D10)', () {
    test('한 번 뽑으면 바뀌지 않고, 그 운명으로 시작한 회차가 엔딩에 닿아야 지워진다 (E8). run_started 에 fate', () async {
      final b = _bundle([_ev('d1')], starts: [_start(StartScenario.classic), _start('sc_leak')]);
      final rec = RecordingAnalyticsBackend();
      final c = await _ctl(b, analytics: Analytics(backend: rec));
      expect(c.pendingFate, isNull);
      await c.rememberFate('sc_leak');
      await c.rememberFate(StartScenario.classic);
      expect(c.pendingFate, 'sc_leak');
      expect((await MetaService().load()).pendingFate, 'sc_leak', reason: '앱을 다시 켜도');
      // 다른 카드로 시작해 엔딩까지 가도 운명은 남는다(버리는 판으로 다시 뽑기 방지, r2_bugs R2-5).
      await c.newGame(seed: 1, start: StartScenario.classic);
      expect(rec.paramsOf(Analytics.runStarted).last['fate'], 0);
      expect(c.pendingFate, 'sc_leak');
      c.state!.day = c.config.totalDays;
      await c.endDay();
      expect(c.pendingFate, 'sc_leak');
      // 운명 시작으로 시작해 버려도 남는다.
      await c.newGame(seed: 2, start: 'sc_leak');
      expect(rec.paramsOf(Analytics.runStarted).last['fate'], 1);
      await c.newGame(seed: 3, start: 'sc_leak');
      expect(c.pendingFate, 'sc_leak');
      // 운명 시작으로 엔딩에 닿으면 지워진다.
      c.state!.day = c.config.totalDays;
      await c.endDay();
      expect(c.pendingFate, isNull);
      expect((await MetaService().load()).pendingFate, isNull);
    });

    test('지금 데이터에 없는 시작이 메타에 남아 있으면 없는 것으로 본다', () async {
      final b = _bundle([_ev('d1')], starts: [_start(StartScenario.classic), _start('sc_leak')]);
      final c = await _ctl(b);
      c.meta!.pendingFate = 'sc_gone';
      expect(c.pendingFate, isNull);
      await c.rememberFate('sc_leak');
      expect(c.pendingFate, 'sc_leak');
    });
  });

  // ---------------------------------------------------------------------------
  group('읽은 장면 (D5)', () {
    final b = _bundle([
      _ev(
        'e1',
        trigger: {
          'day': [1, 100],
        },
        lines: [
          {'who': 'them', 'text': '평소 줄'},
          {'who': 'them', 'text': '파급 A', 'ifFlags': ['fa']},
          {'who': 'them', 'text': '파급 없음', 'ifNotFlags': ['fa']},
        ],
        choices: [
          {'text': '하나'},
          {
            'text': '둘',
            'effects': {
              'setFlags': ['fa'],
            },
          },
          {'text': '갈래 선택지', 'ifFlags': ['fa']},
        ],
      ),
    ]);

    test('메타 필드: 저장·복원, 예전 메타는 기본값(빨리 감기 켬)', () {
      final m = PlayerMeta(
        pendingFate: 'sc_x',
        completedStarts: ['classic'],
        startEndings: {
          'classic': ['solo'],
        },
        seenEvents: ['e1'],
        seenRipples: ['k'],
        fastForwardSeen: false,
      );
      final back = PlayerMeta.fromJson(jsonDecode(jsonEncode(m.toJson())));
      expect(back.pendingFate, 'sc_x');
      expect(back.completedStarts, ['classic']);
      expect(back.startEndings, {
        'classic': ['solo'],
      });
      expect(back.seenEvents, ['e1']);
      expect(back.seenRipples, ['k']);
      expect(back.fastForwardSeen, isFalse);
      final legacy = PlayerMeta.fromJson({'totalRuns': 3});
      expect(legacy.fastForwardSeen, isTrue);
      expect(legacy.seenEvents, isEmpty);
      expect(legacy.completedStarts, isEmpty);
      expect(legacy.pendingFate, isNull);
    });

    test('1회차에는 무료 건너뛰기가 없다. 회차가 끝나면 본 장면이 쌓이고 2회차부터 열린다', () async {
      final c = await _ctl(b);
      await c.newGame(seed: 1);
      await _startDay(c);
      expect(c.current!.id, 'e1');
      expect(c.canFreeSkipWait, isFalse, reason: '처음 보는 장면은 광고로만');
      expect(c.newRippleLines, isEmpty, reason: '처음 보는 장면에는 NEW 를 안 찍는다');
      c.choose(0);
      c.continueAfterChoice();
      expect(c.seenInEarlierRun('e1'), isFalse, reason: '같은 회차 안에서는 아직');
      c.state!.day = c.config.totalDays;
      await c.endDay();
      expect(c.seenInEarlierRun('e1'), isTrue);

      // 2회차: 같은 장면, 다른 플래그 → 무료 건너뛰기 + 처음 보는 파급 줄·선택지에 NEW.
      await c.nextRun();
      c.state!.flags.add('fa');
      await _startDay(c);
      expect(c.current!.id, 'e1');
      // 처음 보는 파급 줄이 들어 있으므로 이 장면은 무료 건너뛰기를 하지 않는다(r2 E5, R2-2).
      expect(c.canFreeSkipWait, isFalse);
      final lines = c.current!.lines;
      expect([for (final i in c.newRippleLines) lines[i].text], ['파급 A']);
      expect([for (final i in c.newRippleChoices) c.current!.choices[i].text], ['갈래 선택지']);
      await c.setFastForwardSeen(false);
      expect((await MetaService().load()).fastForwardSeen, isFalse);
      await c.setFastForwardSeen(true);
      // 고르면 본 것으로 적힌다 → 다음 회차에는 NEW 가 아니다.
      c.choose(0);
      c.continueAfterChoice();
      c.state!.day = c.config.totalDays;
      await c.endDay();
      await c.nextRun();
      c.state!.flags.add('fa');
      await _startDay(c);
      expect(c.newRippleLines, isEmpty);
      expect(c.newRippleChoices, isEmpty);
    });

    test('엔딩 없이 새 게임으로 버린 회차의 장면도 쌓인다', () async {
      final c = await _ctl(b);
      await c.newGame(seed: 1);
      await _startDay(c);
      c.choose(0);
      c.continueAfterChoice();
      await c.newGame(seed: 2);
      expect(c.seenInEarlierRun('e1'), isTrue);
    });

    test('파급 키는 원문 기준이라 이름을 바꿔도 같다', () {
      expect(
        GameController.rippleKey('e', 'L', '{name|아야} 왔어?'),
        GameController.rippleKey('e', 'L', '{name|아야} 왔어?'),
      );
      expect(
        GameController.rippleKey('e', 'L', 'a'),
        isNot(GameController.rippleKey('e', 'C', 'a')),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('오프닝: 시작이 정한 "먼저 다가오는 사람" (D11, r1_bugs R1-3)', () {
    test('합성: D2 에 아직 못 만난 가속 캐릭터를 고른다. 클래식은 그대로', () {
      final b = _bundle(
        [
          _ev('a_r00', layer: 'route', character: 'a'),
          _ev('b_r00', layer: 'route', character: 'b'),
        ],
        starts: [
          _start(StartScenario.classic),
          _start(
            'sc_x',
            effects: {
              'setFlags': [StartScenario.altFlag, 'sc_x'],
              'affection': {'b': 4},
            },
          ),
        ],
      );
      final e = EventEngine(b);
      final s = GameState.fresh(b.config, b.characters, seed: 1, nowMs: 0)
        ..flags.addAll([StartScenario.altFlag, 'sc_x']);
      s.day = 1;
      expect(e.eagerStartCharacter(s, ['a', 'b']), isNull, reason: 'D1 은 우연');
      s.day = 2;
      expect(e.eagerStartCharacter(s, ['a', 'b']), 'b');
      expect(e.planDay(s).map((x) => x.id), contains('b_r00'));
      s.seen.add('b_r00');
      expect(e.eagerStartCharacter(s, ['a', 'b']), isNull, reason: '만났으면 끝');
      final classic = GameState.fresh(b.config, b.characters, seed: 1, nowMs: 0)..day = 2;
      expect(e.eagerStartCharacter(classic, ['a', 'b']), isNull);
    });

    // r1_scripts/zz_r1_sim_test "accelerated role r00 within D1-3" 정식화. 목표 100%.
    final StoryBundle b;
    try {
      b = testBundle();
    } catch (e) {
      // 대본이 편집 중이라 실제 데이터가 검증을 못 넘으면 이 묶음은 그 오류 하나로 실패한다.
      test('실제 데이터 읽기', () => throw e);
      return;
    }
    for (final st in b.starts.where((s) => !s.isClassic)) {
      for (final pref in Preference.genders) {
        final ids = [
          for (final id in st.effects.affection.keys)
            if (!b.absentIds(pref).contains(id)) id,
        ];
        // D1~3 에 루트 칸으로 나올 수 있는 그 사람의 장면이 데이터에 있는지(없으면 대본 몫).
        final reachable = b.events.any(
          (e) =>
              e.layer == EventLayer.route &&
              ids.contains(e.character) &&
              (e.trigger.day == null || e.trigger.day!.min <= 3) &&
              e.trigger.flags.every(
                (f) => f == st.id || f == StartScenario.altFlag || f.startsWith('${st.id}_'),
              ),
        );
        test(
          '${st.id}/$pref: ${ids.join(',')} 의 장면이 D3 까지 나온다 (시드 20)',
          () async {
            final miss = <int>[];
            for (var seed = 0; seed < 20; seed++) {
              SharedPreferences.setMockInitialValues({});
              final c = GameController(bundle: b, save: SaveService());
              await c.init();
              await c.markIntroSeen();
              await c.newGame(preference: pref, seed: seed, start: st.id);
              var met = false;
              for (var d = 0; d < 3 && !met; d++) {
                c.beginMorning();
                c.state!.hearts = b.config.maxHearts;
                await c.startDay(b.config.actions[(seed + d) % b.config.actions.length]);
                while (c.phase == Phase.event) {
                  if (ids.contains(c.current!.character)) met = true;
                  c.choose(_anyChoice(c));
                  c.continueAfterChoice();
                }
                if (c.phase == Phase.summary) await c.endDay();
              }
              if (!met) miss.add(seed);
            }
            expect(miss, isEmpty, reason: '못 만난 시드');
          },
          skip: reachable
              ? false
              : '대본 대기: ${st.id} 의 ${ids.join(',')} 에게 D1~3 첫 접촉 루트 장면이 아직 없다 (r1_meeting D11)',
        );
      }
    }
  });
}
