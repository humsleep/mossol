// 개편 2 · 3라운드 엔진(docs/overhaul2/review/r3_meeting.md F2·F3·F5, r3_bugs.md).
// r3_scripts/zz_r3_engine_test 정식화. 출시판 실제 세이브 덤프는 test/fixtures/r3_live_dumps/.
//
// - F2 시각을 정한 장면은 하루 계획에서 시각 순으로 앞(정오 이후는 뒤)에
// - F3 `m36_*` 를 읽는 이벤트는 m36 다음 날부터
// - F5 엔딩 `when.notFlags`/`flags` (엔진 판정 + 검증)
// - R3-1 되돌리기가 디스크에 남는다(메인 세션 수정의 회귀 테스트)
// - 출시판 세이브 6종: 이전 → 이어 하기 → 엔딩 → 다음 회차
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/ending_resolver.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/event_screen.dart' show ChatClock;
import 'package:shared_preferences/shared_preferences.dart';

import 'widget/helpers.dart';

const _config = '{"initialStats": {"charm": 10}, "actions": []}';
const _chars = '''[
  {"id": "a", "name": "가람", "gender": "f", "role": "senior"},
  {"id": "b", "name": "나래", "gender": "m", "role": "senior"}
]''';
const _defaultEnding = {
  'id': 'solo',
  'name': '솔로',
  'tier': 'solo',
  'default': true,
};

Map<String, dynamic> _ev(
  String id, {
  String layer = 'daily',
  int? day,
  Map<String, dynamic>? trigger,
  List<Map<String, dynamic>>? choices,
  String? clock,
}) => {
  'id': id,
  'layer': layer,
  'day': ?day,
  'trigger': ?trigger,
  'clock': ?clock,
  'lines': [
    {'who': 'them', 'text': '안녕'},
  ],
  'choices':
      choices ??
      [
        {'text': '하나'},
        {'text': '둘'},
      ],
};

StoryBundle _bundle(
  List<Map<String, dynamic>> events, {
  List<Map<String, dynamic>> endings = const [_defaultEnding],
}) => StoryBundle.fromJsonStrings(
  config: _config,
  characters: _chars,
  events: [jsonEncode(events)],
  endings: jsonEncode(endings),
);

/// 화면처럼 시계를 먼저 묻고 무작위로 고른다.
void _playOne(GameController c, Random rnd) {
  final ev = c.current!;
  final s = c.state!;
  if (!ev.isCall) {
    c.clockStartFor(
      ev,
      ChatClock.startSeconds(
        seed: s.seed,
        day: s.day,
        index: c.todayEventIndex,
        total: c.todayEventTotal,
      ),
    );
  }
  final open = [
    for (final v in c.choices)
      if (!v.locked) v.index,
  ];
  final i = open[rnd.nextInt(open.length)];
  c.choose(i, minigameSuccess: ev.choices[i].minigame != null ? rnd.nextBool() : null);
  c.continueAfterChoice();
}

Future<void> _playToEnd(GameController c, Random rnd, {int maxDays = 130}) async {
  for (var d = 0; d < maxDays && c.ending == null; d++) {
    if (c.phase == Phase.dayStart) c.beginMorning();
    if (c.phase == Phase.action) {
      c.state!.hearts = c.config.maxHearts;
      await c.startDay(c.config.actions[rnd.nextInt(c.config.actions.length)]);
    }
    var guard = 0;
    while (c.phase == Phase.event && guard++ < 40) {
      _playOne(c, rnd);
    }
    if (c.phase == Phase.summary) await c.endDay();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  group('시각을 정한 장면의 자리 (F2)', () {
    StoryEvent e(String id, [String? clock, String layer = 'daily']) =>
        StoryEvent.fromJson(_ev(id, clock: clock, layer: layer, day: layer == 'main' ? 1 : null));

    test('하루 순서(r5 H1): 새벽 → 메인 → 오전 → 나머지 → 오후·밤', () {
      final plan = [
        e('scene'),
        e('m1', null, 'main'),
        e('late', '23:00'),
        e('dawn4', '04:00'),
        e('route'),
        e('am8', '08:00'),
        e('dawn2', '02:00'),
        e('m_night', '22:00', 'main'),
      ];
      expect(EventEngine.orderByClock(plan).map((x) => x.id), [
        'dawn2',
        'dawn4',
        'm1',
        'am8',
        'scene',
        'route',
        'm_night',
        'late',
      ]);
      // 새벽 메인도 새벽 무리에, 오전 메인은 메인 자리에.
      expect(
        EventEngine.orderByClock([
          e('scene'),
          e('m_am', '09:00', 'main'),
          e('dawn3', '03:00'),
          e('m_dawn', '01:00', 'main'),
        ]).map((x) => x.id),
        ['m_dawn', 'dawn3', 'm_am', 'scene'],
      );
      // 오후·밤 장면만 있는 날은 메인과 나머지 순서를 건드리지 않는다(행동 장면 → 메인 그대로).
      expect(
        EventEngine.orderByClock([e('scene'), e('m1', null, 'main'), e('late', '23:00'), e('r')])
            .map((x) => x.id),
        ['scene', 'm1', 'r', 'late'],
      );
      // 오프닝 첫날: 메인이 새벽 장면보다도 앞이다.
      expect(
        EventEngine.orderByClock([
          e('m01', null, 'main'),
          e('late_msg', '01:14'),
          e('scene'),
        ], mainsFirst: true).map((x) => x.id),
        ['m01', 'late_msg', 'scene'],
      );
      final none = [e('a'), e('b', null, 'main')];
      expect(identical(EventEngine.orderByClock(none), none), isTrue);
    });

    test('합성: 새벽 위기가 아침 장면 뒤에 밀리지 않는다', () async {
      final b = _bundle([
        _ev(
          'd_morning',
          trigger: {
            'day': [1, 1],
          },
        ),
        _ev(
          'c_dawn',
          layer: 'crisis',
          clock: '04:00',
          trigger: {
            'day': [1, 1],
          },
        ),
      ]);
      SharedPreferences.setMockInitialValues({});
      final c = GameController(bundle: b, save: SaveService());
      await c.init();
      await c.markIntroSeen();
      await c.newGame(seed: 1);
      c.beginMorning();
      await c.startDay(const DayAction(id: 'x', name: 'x', desc: ''));
      expect([c.current!.id, ...c.queuedEventIds].first, 'c_dawn');
      expect(c.clockStartFor(c.current!, 9 * 3600), 4 * 3600);
    });

    // 조건을 맞춰 놓고 그날을 돌린다 — 무작위 판에서는 드물게 나오는 장면까지 확실히 덮는다.
    for (final (id, start, pref, day, setup) in <(String, String, String, int, void Function(GameState))>[
      ('c_heat_meltdown', 'sc_clip', Preference.female, 10, (s) => s.stats[Stat.heat] = 90),
      ('sc_clip_open_2', 'sc_clip', Preference.female, 2, (s) {}),
      ('c_clip_truth', 'sc_clip', Preference.female, 45, (s) {
        s.flags.add('sc_clip_deny');
        s.rel('sohee').affection = 50;
        // 같은 가중치의 다른 위기(c_ghosted·c_money_fight)가 자리를 먼저 차지하지 않게.
        s.stats[Stat.sense] = 40;
        s.stats[Stat.money] = 100;
      }),
      ('sc_swap_trainer', 'sc_swap', Preference.female, 3, (s) => s.flags.add('trainer_early')),
    ]) {
      test('조건을 맞춘 날: $id 가 정한 시각 그대로(밀림 0)', () async {
        final b = testBundle();
        final ev0 = b.eventById[id];
        if (ev0 == null || ev0.clockSeconds == null) {
          markTestSkipped('$id 에 clock 이 없다(대본이 지웠다)');
          return;
        }
        var hits = 0;
        final pushed = <String>[];
        for (var seed = 0; seed < 40 && hits < 5; seed++) {
          SharedPreferences.setMockInitialValues({});
          final c = GameController(bundle: b, save: SaveService());
          await c.init();
          await c.markIntroSeen();
          await c.newGame(preference: pref, seed: seed, start: start);
          final s = c.state!..day = day;
          setup(s);
          c.beginMorning();
          s.hearts = b.config.maxHearts;
          await c.startDay(b.config.actions[seed % b.config.actions.length]);
          final rnd = Random(seed);
          while (c.phase == Phase.event) {
            final ev = c.current!;
            if (ev.id == id) {
              hits++;
              final t = c.clockStartFor(
                ev,
                ChatClock.startSeconds(
                  seed: s.seed,
                  day: s.day,
                  index: c.todayEventIndex,
                  total: c.todayEventTotal,
                ),
              );
              if (t != ev.clockSeconds) pushed.add('s$seed ${ChatClock.label(t)}');
            }
            _playOne(c, rnd);
          }
        }
        expect(hits, greaterThan(0), reason: '$id 가 한 번도 안 나왔다');
        expect(pushed, isEmpty);
      }, timeout: const Timeout(Duration(minutes: 3)));
    }

    // r3_script R3-3 기준선(밀린 횟수): c_heat_meltdown 38/38 · sc_clip_open_2 12/12 ·
    // c_clip_truth 8/8 · sc_swap_trainer 10/10. 대본이 이 장면들의 `clock` 을 지우면 이 검사는 빈다.
    test('실제 데이터: 새벽 고정 장면 4종이 정한 시각 그대로 나온다(밀림 0)', () async {
      final b = testBundle();
      const watch = {
        'c_heat_meltdown',
        'sc_clip_open_2',
        'c_clip_truth',
        'c_clip_truth_m',
        'sc_swap_trainer',
        'sc_swap_trainer_m',
      };
      final pushed = <String>[];
      final seen = <String, int>{};
      for (final st in ['sc_clip', 'sc_swap', 'sc_leak', StartScenario.classic]) {
        for (var seed = 0; seed < 6; seed++) {
          SharedPreferences.setMockInitialValues({});
          final c = GameController(bundle: b, save: SaveService());
          await c.init();
          await c.markIntroSeen();
          await c.newGame(preference: Preference.genders[seed % 2], seed: seed, start: st);
          final rnd = Random(seed);
          for (var d = 0; d < 100 && c.ending == null; d++) {
            c.beginMorning();
            c.state!.hearts = b.config.maxHearts;
            // 소문을 키워 c_heat_meltdown(소문 문턱)까지 닿게 휴식은 하지 않는다.
            final acts = b.config.actions.where((a) => a.id != 'rest').toList();
            await c.startDay(acts[rnd.nextInt(acts.length)]);
            while (c.phase == Phase.event) {
              final ev = c.current!;
              final s = c.state!;
              // 새벽(06:00 전) 장면은 메인 날에도 메인보다 앞이다(r5 H1). 오전 장면(trainer 07:00)은
              // 메인 뒤라, 메인이 오전 늦게 끝나면 밀릴 수 있다 — 그날 메인이 있으면 세지 않는다.
              final mainDay = b.events.any(
                (x) => x.layer == EventLayer.main && x.day == s.day,
              );
              final t = ev.clockSeconds;
              final strict = t != null && (t < EventEngine.clockDawnEnd || !mainDay);
              if (strict && watch.contains(ev.id)) {
                final start = c.clockStartFor(
                  ev,
                  ChatClock.startSeconds(
                    seed: s.seed,
                    day: s.day,
                    index: c.todayEventIndex,
                    total: c.todayEventTotal,
                  ),
                );
                seen.update(ev.id, (v) => v + 1, ifAbsent: () => 1);
                if (start != ev.clockSeconds) {
                  pushed.add('$st/s$seed D${s.day} ${ev.id} ${ChatClock.label(start)}');
                }
              }
              _playOne(c, rnd);
            }
            if (c.phase == Phase.summary) await c.endDay();
          }
        }
      }
      // ignore: avoid_print
      print('F2 clocked scenes seen: $seen pushed: ${pushed.length}');
      expect(pushed, isEmpty);
    }, timeout: const Timeout(Duration(minutes: 8)));
  });

  // ---------------------------------------------------------------------------
  group('m36_* 는 m36 다음 날부터 읽는다 (F3)', () {
    Map<String, dynamic> m36() => _ev(
      'm36',
      layer: 'main',
      day: 92,
      choices: [
        {
          'text': '고백',
          'effects': {
            'setFlags': ['m36_confessed'],
          },
        },
        {
          'text': '정리',
          'effects': {
            'setFlags': ['m36_parted'],
          },
        },
      ],
    );

    test('D93 부터 여는 장면은 통과', () {
      expect(
        () => _bundle([
          m36(),
          _ev(
            'settle',
            trigger: {
              'day': [93, 100],
              'notFlags': ['m36_confessed'],
            },
          ),
        ]),
        returnsNormally,
      );
    });

    test('D90 부터 열리면 거부(트리거·파급 줄 둘 다)', () {
      expect(
        () => _bundle([
          m36(),
          _ev(
            'settle_out',
            trigger: {
              'day': [90, 100],
              'notFlags': ['m36_confessed'],
            },
          ),
        ]),
        throwsA(isA<StateError>().having((e) => e.message, 'm', contains('D93'))),
      );
      expect(
        () => _bundle([
          m36(),
          {
            ..._ev(
              'late',
              trigger: {
                'day': [80, 100],
              },
            ),
            'lines': [
              {'who': 'them', 'text': '고백했지', 'ifFlags': ['m36_confessed']},
              {'who': 'them', 'text': '안녕'},
            ],
          },
        ]),
        throwsA(isA<StateError>()),
      );
    });

    test('해피를 막는 결과(notFlags 로 읽는 m36_parted)를 부정으로 읽는 것은 일찍 열려도 된다 (r5 R5-5)', () {
      final happy = {
        'id': 'happy_a',
        'name': '해피',
        'tier': 'happy',
        'priority': 10,
        'character': 'a',
        'when': {
          'notFlags': ['m36_parted'],
        },
      };
      final date = _ev(
        'd_date',
        trigger: {
          'day': [20, 100],
          'notFlags': ['m36_parted'],
        },
      );
      expect(
        () => _bundle([m36(), date], endings: [_defaultEnding, happy]),
        returnsNormally,
      );
      // 막는 결과가 아닌 것(고백하지 않았다)을 부정으로 읽으면 여전히 D93 부터.
      expect(
        () => _bundle([
          m36(),
          _ev(
            'early_not_confessed',
            trigger: {
              'day': [20, 100],
              'notFlags': ['m36_confessed'],
            },
          ),
        ], endings: [_defaultEnding, happy]),
        throwsA(isA<StateError>()),
      );
      // 긍정 읽기는 막는 결과라도 D93 부터.
      expect(
        () => _bundle([
          m36(),
          _ev(
            'early_parted',
            trigger: {
              'day': [20, 100],
              'flags': ['m36_parted'],
            },
          ),
        ], endings: [_defaultEnding, happy]),
        throwsA(isA<StateError>()),
      );
    });

    test('next 로만 닿는 사슬 장면과 m36 이 없는 데이터는 검사하지 않는다', () {
      expect(
        () => _bundle([
          m36(),
          _ev(
            'after',
            trigger: {
              'day': [0, 0],
              'flags': ['m36_confessed'],
            },
          ),
        ]),
        returnsNormally,
      );
      expect(
        () => _bundle([
          _ev(
            'x',
            trigger: {
              'day': [1, 100],
              'flags': ['m36_confessed'],
            },
            choices: [
              {
                'text': '하나',
                'effects': {
                  'setFlags': ['m36_confessed'],
                },
              },
              {'text': '둘'},
            ],
          ),
        ]),
        returnsNormally,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('엔딩 when 의 flags · notFlags (F5)', () {
    final events = [
      _ev(
        'm36',
        layer: 'main',
        day: 92,
        choices: [
          {
            'text': '고백',
            'effects': {
              'setFlags': ['m36_confessed'],
            },
          },
          {
            'text': '정리',
            'effects': {
              'setFlags': ['m36_parted'],
            },
          },
        ],
      ),
    ];
    final happy = {
      'id': 'happy_a',
      'name': '해피',
      'tier': 'happy',
      'priority': 10,
      'character': 'a',
      'when': {
        'affection': {
          '*': [80, 100],
        },
        'notFlags': ['m36_parted', 'm36_rejected'],
      },
    };

    test('notFlags 가 서 있으면 해피가 나오지 않는다', () {
      final b = _bundle(
        [
          ...events,
          _ev(
            'reject',
            trigger: {
              'day': [93, 100],
            },
            choices: [
              {
                'text': '보류',
                'effects': {
                  'setFlags': ['m36_rejected'],
                },
              },
              {'text': '둘'},
            ],
          ),
        ],
        endings: [_defaultEnding, happy],
      );
      final r = EndingResolver(b.endings, characters: b.characters);
      final s = GameState.fresh(b.config, b.characters, seed: 1, nowMs: 0)..day = 101;
      s.rel('a').affection = 90;
      expect(r.resolve(s).id, 'happy_a');
      s.flags.add('m36_parted');
      expect(r.resolve(s).id, 'solo');
      s.flags
        ..remove('m36_parted')
        ..add('m36_rejected');
      expect(r.resolve(s).id, 'solo');
      // 두 번째 대답(D94~95)이 고백으로 바꾸면 다시 해피.
      s.flags
        ..remove('m36_rejected')
        ..add('m36_confessed');
      expect(r.resolve(s).id, 'happy_a');
    });

    test('flags 도 같은 규칙(있어야 열림)', () {
      final b = _bundle(events, endings: [
        _defaultEnding,
        {
          ...happy,
          'when': {
            'flags': ['m36_confessed'],
          },
        },
      ]);
      final r = EndingResolver(b.endings, characters: b.characters);
      final s = GameState.fresh(b.config, b.characters, seed: 1, nowMs: 0)..day = 101;
      expect(r.resolve(s).id, 'solo');
      s.flags.add('m36_confessed');
      expect(r.resolve(s).id, 'happy_a');
    });

    test('검증기: 엔딩이 아무도 안 세우는 플래그를 읽으면 거부(오타)', () {
      expect(
        () => _bundle(events, endings: [
          _defaultEnding,
          {
            ...happy,
            'when': {
              'notFlags': ['m36_partd'],
            },
          },
        ]),
        throwsA(isA<StateError>().having((e) => e.message, 'm', contains('m36_partd'))),
      );
    });
  });

  // ---------------------------------------------------------------------------
  test('되돌리기는 디스크에도 남는다: 되돌린 직후 앱을 꺼도 선택 전 상태 (R3-1)', () async {
    final b = _bundle([
      _ev(
        'm1',
        layer: 'main',
        day: 1,
        choices: [
          {
            'text': 'A',
            'effects': {
              'affection': {'a': -3},
              'stats': {'charm': -5},
            },
            'next': 'h1',
          },
          {'text': 'B'},
        ],
      ),
      _ev(
        'h1',
        trigger: {
          'day': [0, 0],
        },
      ),
      _ev('x', day: null, trigger: {
        'day': [1, 1],
      }),
    ]);
    SharedPreferences.setMockInitialValues({});
    final c = GameController(bundle: b, save: SaveService());
    await c.init();
    await c.markIntroSeen();
    await c.newGame(seed: 1);
    c.beginMorning();
    await c.startDay(const DayAction(id: 'x', name: 'x', desc: ''));
    expect(c.current!.id, 'm1');
    final charm0 = c.state!.stat(Stat.charm);
    c.choose(0);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    c.undoChoice();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final c2 = GameController(bundle: b, save: SaveService());
    await c2.init();
    await c2.continueGame();
    expect(c2.current!.id, 'm1');
    expect(c2.state!.stat(Stat.charm), charm0);
    expect(c2.state!.seen, isNot(contains('m1')));
    expect(c2.queuedEventIds, ['x']);
    expect(c2.state!.chainRank, isEmpty);
  });

  // ---------------------------------------------------------------------------
  group('출시판 실제 세이브 (r3_bugs §1)', () {
    Map<String, Object> dump(String name) {
      final j =
          jsonDecode(File('test/fixtures/r3_live_dumps/$name.json').readAsStringSync()) as Map;
      return {
        for (final e in j.entries)
          e.key as String: e.value is List
              ? (e.value as List).cast<String>().toList()
              : e.value as Object,
      };
    }

    for (final name in [
      'veteran_mid_1',
      'veteran_mid_2',
      'veteran_mid_3',
      'newbie_mid',
      'veteran_morning',
    ]) {
      test('$name: 이전 → 이어 하기 → 엔딩 → 다음 회차 플래그', () async {
        final d = dump(name);
        SharedPreferences.setMockInitialValues(d);
        final album = (d['mossol_endings_v1'] as List<String>?) ?? const <String>[];
        final meta0 = jsonDecode(d['mossol_meta_v1'] as String) as Map<String, dynamic>;
        final save0 = jsonDecode(d['mossol_save_v1'] as String) as Map<String, dynamic>;
        final c = GameController(bundle: testBundle(), save: SaveService());
        await c.init();
        if (album.isNotEmpty) {
          expect(c.completedStarts, [StartScenario.classic]);
          expect(c.meta!.startEndings[StartScenario.classic]!.toSet(), album.toSet());
        } else {
          expect(c.completedStarts, isEmpty);
        }
        if ((meta0['totalRuns'] as int) > 1) {
          expect(c.meta!.seenEvents.toSet(), (save0['seen'] as List).cast<String>().toSet());
        }
        // 멱등: 두 번째 실행은 메타를 바꾸지 않는다.
        final p = await SharedPreferences.getInstance();
        final metaAfter = p.getString('mossol_meta_v1');
        final c2 = GameController(bundle: testBundle(), save: SaveService());
        await c2.init();
        expect(p.getString('mossol_meta_v1'), metaAfter);
        expect(await c2.continueGame(), isTrue);
        await _playToEnd(c2, Random(name.length * 31));
        expect(c2.ending, isNotNull);
        await c2.nextRun(start: 'sc_leak');
        expect(c2.state!.flags, contains(StartScenario.doneFlag(StartScenario.classic)));
        expect(c2.state!.flags, contains(StartScenario.veteranFlag));
      }, timeout: const Timeout(Duration(minutes: 3)));
    }

    test('veteran_after_ending(세이브 없음): 클래식 말고 안 해 본 시작을 권한다', () async {
      SharedPreferences.setMockInitialValues(dump('veteran_after_ending'));
      final c = GameController(bundle: testBundle(), save: SaveService());
      await c.init();
      expect(c.suggestedStart, isNot(StartScenario.classic));
      await c.newGame(start: 'sc_leak', preference: Preference.female);
      expect(c.state!.flags, containsAll([StartScenario.veteranFlag, 'done_classic']));
    });
  });
}
