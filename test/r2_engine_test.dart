// 개편 2 · 2라운드 엔진(docs/overhaul2/review/r2_meeting.md §4 "엔진·UI", r2_bugs.md).
// r2_scripts/zz_r2_engine_test·zz_r2_clock_test 정식화.
//
// - E5 빨리 감기 조건(처음 보는 변형·파급 줄이 있으면 안 함, R2-2)
// - E6 출시판 메타 이전(R2-1), E8 운명은 그 운명 회차의 엔딩에서만 지운다(R2-5, r1_engine_test 에도)
// - E7 같은 날 시계는 거꾸로 가지 않는다(R2-3)
// - E9 메타 손상(R2-6), 재시작 클리프행어, 되돌리기가 계획된 이벤트를 떨어뜨리지 않음
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/meta_service.dart';
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
const _endings =
    '[{"id": "solo", "name": "솔로", "tier": "solo", "default": true}]';

Map<String, dynamic> _ev(
  String id, {
  String layer = 'daily',
  int? day,
  Map<String, dynamic>? trigger,
  List<Map<String, dynamic>>? lines,
  List<List<Map<String, dynamic>>>? variants,
  List<Map<String, dynamic>>? choices,
  String? cliffhanger,
  String? clock,
  bool? once,
}) => {
  'id': id,
  'layer': layer,
  'day': ?day,
  'trigger': ?trigger,
  'cliffhanger': ?cliffhanger,
  'clock': ?clock,
  'once': ?once,
  'lines':
      lines ??
      [
        {'who': 'them', 'text': '안녕'},
      ],
  if (variants != null)
    'variants': [
      for (final v in variants) {'lines': v},
    ],
  'choices':
      choices ??
      [
        {'text': '하나'},
        {'text': '둘'},
      ],
};

StoryBundle _bundle(List<Map<String, dynamic>> events) =>
    StoryBundle.fromJsonStrings(
      config: _config,
      characters: _chars,
      events: [jsonEncode(events)],
      endings: _endings,
    );

Future<GameController> _ctl(StoryBundle b, {Map<String, Object>? prefs}) async {
  SharedPreferences.setMockInitialValues(prefs ?? {});
  final c = GameController(bundle: b, save: SaveService());
  await c.init();
  await c.markIntroSeen();
  return c;
}

Future<void> _startDay(GameController c) async {
  c.beginMorning();
  c.state!.hearts = c.config.maxHearts;
  await c.startDay(const DayAction(id: 'x', name: 'x', desc: ''));
}

const _daily = {
  'day': [1, 100],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // ---------------------------------------------------------------------------
  group('출시판 메타 이전 (E6, r2_bugs R2-1)', () {
    // 출시판(HEAD) PlayerMeta.toJson 이 쓰던 키만.
    final legacyMeta = {
      'lastCheckInDate': '2026-10-01',
      'streakDays': 3,
      'bestStreak': 5,
      'totalCheckIns': 9,
      'totalRuns': 4,
      'bestDayReached': 100,
      'firstLaunchMs': 1,
      'pendingHearts': 0,
      'rerollTickets': 0,
      'playerGender': 'f',
      'playerName': '민지',
      'nameAsked': true,
      'mbti': 'INFP',
      'mbtiAsked': true,
      'lastEndingId': 'coach',
      'sfxOn': true,
      'hapticOn': true,
      'freeInputSends': 2,
      'introSeen': true,
    };

    test('엔딩이 있는 출시판 사용자: 클래식을 끝낸 것으로 채우고 안 해 본 시작을 권한다', () async {
      final b = testBundle();
      SharedPreferences.setMockInitialValues({
        'mossol_meta_v1': jsonEncode(legacyMeta),
        'mossol_endings_v1': ['coach', 'solo_strong', 'coach'],
      });
      final c = GameController(bundle: b, save: SaveService());
      await c.init();
      expect(c.meta!.totalRuns, 4);
      expect(c.completedStarts, [StartScenario.classic]);
      expect(c.startEndingCount(StartScenario.classic), 2);
      expect(c.suggestedStart, isNot(StartScenario.classic));
      await c.newGame(preference: Preference.female, seed: 1, start: 'sc_leak');
      expect(c.state!.flags, containsAll(['done_classic', StartScenario.veteranFlag]));
      // 멱등: 다시 켜도 그대로.
      final c2 = GameController(bundle: b, save: SaveService());
      await c2.init();
      expect(c2.completedStarts, [StartScenario.classic]);
      expect(c2.startEndingCount(StartScenario.classic), 2);
    });

    test('회차를 여러 번 한 기기는 지금 세이브의 본 장면으로 seenEvents 를 시드한다', () async {
      final b = testBundle();
      final s = GameState.fresh(b.config, b.characters, seed: 9, nowMs: 0)
        ..day = 30
        ..seen.addAll(['m01', 'd_open_bet']);
      SharedPreferences.setMockInitialValues({
        'mossol_meta_v1': jsonEncode(legacyMeta),
        'mossol_endings_v1': ['coach'],
        'mossol_save_v1': jsonEncode(s.toJson()),
      });
      final c = GameController(bundle: b, save: SaveService());
      await c.init();
      expect(c.seenInEarlierRun('m01'), isTrue);
      expect(c.seenInEarlierRun('d_open_bet'), isTrue);
    });

    test('엔딩이 없는 새 사용자는 건드리지 않는다', () async {
      final c = await _ctl(testBundle());
      expect(c.completedStarts, isEmpty);
      expect(c.meta!.seenEvents, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  test('메타 announcedStarts 형식이 틀려도 그 칸만 비운다 (R2-6)', () async {
    SharedPreferences.setMockInitialValues({
      'mossol_meta_v1': jsonEncode({
        'totalRuns': 7,
        'playerName': '민지',
        'announcedStarts': 'sc_swap',
        'completedStarts': 'classic',
        'startEndings': ['x'],
      }),
    });
    final m = await MetaService().load();
    expect(m.totalRuns, 7);
    expect(m.playerName, '민지');
    expect(m.announcedStarts, isEmpty);
    expect(m.completedStarts, isEmpty);
    expect(m.startEndings, isEmpty);
  });

  // ---------------------------------------------------------------------------
  test('없는 id 를 담은 세이브·메타: 이어 하기 → 3일 → 새 게임까지 예외 없음', () async {
    final b = testBundle();
    final s = GameState.fresh(
      b.config,
      b.characters,
      seed: 9,
      nowMs: 0,
      preference: Preference.female,
    )
      ..day = 7
      ..dayStarted = true;
    s.dayQueue = ['gone_event_x', 'd_kakao_03', 'gone_event_y'];
    s.seen.addAll(['gone_a', 'm01']);
    s.dailySeenDay['gone_b'] = 6;
    s.flags.addAll(['sc_gone', 'gone_flag']);
    s.chainRank['gone_c'] = 0;
    final meta = PlayerMeta(
      firstLaunchMs: 1,
      introSeen: true,
      totalRuns: 2,
      pendingFate: 'sc_gone',
      lastStart: 'sc_gone',
      completedStarts: ['sc_gone', 'classic'],
      startEndings: {
        'sc_gone': ['gone_ending'],
      },
      seenEvents: ['gone_a', 'gone_b#1'],
      seenRipples: ['gone|L|abc'],
      announcedStarts: ['sc_gone'],
    );
    SharedPreferences.setMockInitialValues({
      'mossol_save_v1': jsonEncode(s.toJson()),
      'mossol_meta_v1': jsonEncode(meta.toJson()),
      'mossol_endings_v1': ['gone_ending'],
    });
    final c = GameController(bundle: b, save: SaveService());
    await c.init();
    expect(c.pendingFate, isNull);
    expect(await c.continueGame(), isTrue);
    expect(c.current?.id, 'd_kakao_03');
    for (var d = 0; d < 3 && c.ending == null; d++) {
      while (c.phase == Phase.event) {
        c.choose(c.choices.firstWhere((v) => !v.locked).index);
        c.continueAfterChoice();
      }
      if (c.phase == Phase.summary) await c.endDay();
      c.beginMorning();
      c.state!.hearts = b.config.maxHearts;
      await c.startDay(b.config.actions.first);
    }
    await c.newGame(preference: Preference.female, seed: 3, start: 'sc_leak');
    expect(c.state!.flags, containsAll(['done_sc_gone', StartScenario.veteranFlag]));
  });

  // ---------------------------------------------------------------------------
  group('빨리 감기는 정말 본 내용만 (E5, r2_bugs R2-2)', () {
    test('지난 회차에 변형 A 만 봤으면 이번 변형 B 는 무료 건너뛰기·빨리 감기 없음', () async {
      final b = _bundle([
        _ev(
          'e1',
          once: false,
          trigger: _daily,
          lines: [
            {'who': 'them', 'text': '원본 앞'},
            {'who': 'sys', 'wait': 20},
            {'who': 'them', 'text': '원본 뒤'},
          ],
          variants: [
            [
              {'who': 'them', 'text': '변형 앞'},
              {'who': 'sys', 'wait': 20},
              {'who': 'them', 'text': '변형 뒤'},
            ],
          ],
        ),
      ]);
      final c = await _ctl(b);
      await c.newGame(seed: 1);
      await _startDay(c);
      final first = c.current!.lines.first.text;
      c.choose(0);
      c.continueAfterChoice();
      // 같은 묶음이 다시 나오는 회차 → 빨리 감기, 다른 묶음 → 안 함.
      var sameSeen = false, otherSeen = false;
      for (var seed = 2; seed < 60 && !(sameSeen && otherSeen); seed++) {
        await c.newGame(seed: seed);
        await _startDay(c);
        final same = c.current!.lines.first.text == first;
        expect(c.canFreeSkipWait, same, reason: 'seed $seed');
        expect(c.canFastForward, same);
        if (same) {
          sameSeen = true;
        } else {
          otherSeen = true;
        }
      }
      expect(sameSeen && otherSeen, isTrue);
    });

    test('처음 보는 파급 줄이 있으면 빨리 감기 없음, 다 본 뒤에는 있음', () async {
      final b = _bundle([
        _ev(
          'e1',
          trigger: _daily,
          lines: [
            {'who': 'them', 'text': '평소'},
            {'who': 'sys', 'wait': 20},
            {'who': 'them', 'text': '갈래', 'ifFlags': ['fa']},
          ],
          choices: [
            {'text': '하나'},
            {
              'text': '둘',
              'effects': {
                'setFlags': ['fa'],
              },
            },
          ],
        ),
      ]);
      final c = await _ctl(b);
      await c.newGame(seed: 1);
      await _startDay(c);
      c.choose(0);
      c.continueAfterChoice();
      await c.newGame(seed: 2);
      await _startDay(c);
      expect(c.canFastForward, isTrue, reason: '같은 내용');
      c.choose(0);
      c.continueAfterChoice();
      await c.newGame(seed: 3);
      c.state!.flags.add('fa');
      await _startDay(c);
      expect(c.newRippleLines, isNotEmpty);
      expect(c.canFastForward, isFalse);
      expect(c.canFreeSkipWait, isFalse);
      c.choose(0);
      c.continueAfterChoice();
      await c.newGame(seed: 4);
      c.state!.flags.add('fa');
      await _startDay(c);
      expect(c.canFastForward, isTrue, reason: '그 파급 줄도 이제 봤다');
    });

    test('버린 회차의 본 장면은 앱을 다시 켠 뒤 새 게임에서도 합쳐진다', () async {
      final b = _bundle([_ev('e1', once: false, trigger: _daily)]);
      final c = await _ctl(b);
      await c.newGame(seed: 1);
      await _startDay(c);
      c.choose(0);
      c.continueAfterChoice();
      final c2 = GameController(bundle: b, save: SaveService());
      await c2.init();
      expect(c2.hasSave, isTrue);
      await c2.newGame(seed: 2);
      expect(c2.seenInEarlierRun('e1'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('클리프행어 (D6 · E9)', () {
    Future<String?> run(StoryBundle b, int Function(GameController) pick) async {
      final c = await _ctl(b);
      await c.newGame(seed: 5);
      await _startDay(c);
      while (c.phase == Phase.event) {
        c.choose(pick(c));
        c.continueAfterChoice();
      }
      return c.cliffhanger;
    }

    test('여러 단계 사슬 main → 일상 → 일상(예고) 은 마지막 갈래가 이긴다', () async {
      final b = _bundle([
        _ev(
          'm1',
          layer: 'main',
          day: 1,
          cliffhanger: 'M',
          choices: [
            {'text': 'go', 'next': 'h1'},
            {'text': 'no'},
          ],
        ),
        _ev(
          'h1',
          trigger: {
            'day': [0, 0],
          },
          choices: [
            {'text': 'go', 'next': 'h2'},
            {'text': 'no'},
          ],
        ),
        _ev(
          'h2',
          cliffhanger: 'H2',
          trigger: {
            'day': [0, 0],
          },
        ),
        _ev(
          'o',
          cliffhanger: 'O',
          trigger: {
            'day': [1, 1],
          },
        ),
      ]);
      expect(await run(b, (c) => 0), 'H2');
    });

    test('failNext 갈래도 이긴다', () async {
      final b = _bundle([
        _ev(
          'm1',
          layer: 'main',
          day: 1,
          cliffhanger: 'M',
          choices: [
            {'text': 'go', 'chance': 0, 'failNext': 'f1', 'next': 'h1'},
            {'text': 'no'},
          ],
        ),
        _ev(
          'f1',
          cliffhanger: 'F',
          trigger: {
            'day': [0, 0],
          },
        ),
        _ev(
          'h1',
          cliffhanger: 'H',
          trigger: {
            'day': [0, 0],
          },
        ),
      ]);
      expect(await run(b, (c) => 0), 'F');
    });

    test('하루 도중 앱을 다시 켜도 오늘의 예고 순위가 이어진다', () async {
      final b = _bundle([
        _ev(
          'm1',
          layer: 'main',
          day: 1,
          cliffhanger: 'M',
          choices: [
            {'text': 'go', 'next': 'h1'},
            {'text': 'no'},
          ],
        ),
        _ev(
          'h1',
          trigger: {
            'day': [0, 0],
          },
        ),
        _ev(
          'o',
          cliffhanger: 'O',
          trigger: {
            'day': [1, 1],
          },
        ),
      ]);
      final c = await _ctl(b);
      await c.newGame(seed: 5);
      await _startDay(c);
      c.choose(0);
      c.continueAfterChoice();
      await Future<void>.delayed(Duration.zero);
      final c2 = GameController(bundle: b, save: SaveService());
      await c2.init();
      await c2.continueGame();
      expect(c2.cliffhanger, 'M');
      while (c2.phase == Phase.event) {
        c2.choose(0);
        c2.continueAfterChoice();
      }
      expect(c2.cliffhanger, 'M', reason: '사슬 밖 일상은 main 을 못 이긴다');
    });

    test('되돌리기: 다음 이벤트로 당겼던 오늘 계획 이벤트를 떨어뜨리지 않고, 예고도 되돌린다', () async {
      final b = _bundle([
        _ev(
          'm1',
          layer: 'main',
          day: 1,
          cliffhanger: 'M',
          choices: [
            {'text': 'go', 'next': 'x'},
            {'text': 'no'},
          ],
        ),
        _ev(
          'x',
          cliffhanger: 'X',
          trigger: {
            'day': [1, 1],
          },
        ),
      ]);
      final c = await _ctl(b);
      await c.newGame(seed: 5);
      await _startDay(c);
      final planned = c.queuedEventIds.toList();
      expect(planned, contains('x'));
      final order = <String>[];
      while (c.phase == Phase.event) {
        order.add(c.current!.id);
        if (c.current!.id == 'm1') {
          c.choose(0);
          c.undoChoice();
          expect(c.queuedEventIds, planned);
          c.choose(1);
        } else {
          c.choose(0);
        }
        c.continueAfterChoice();
      }
      expect(order, ['m1', 'x']);
      expect(c.cliffhanger, 'M', reason: '되돌린 갈래의 순위가 남지 않는다');
    });
  });

  // ---------------------------------------------------------------------------
  group('하루 안 시계는 거꾸로 가지 않는다 (E7, r2_bugs R2-3)', () {
    test('합성: 앞 장면 끝보다 이른 고정 시각은 다음 분으로 밀린다', () async {
      final b = _bundle([
        _ev(
          'm1',
          layer: 'main',
          day: 1,
          clock: '01:10',
          lines: [
            {'who': 'them', 'text': '하나'},
            {'who': 'them', 'text': '둘'},
            {'who': 'them', 'text': '셋'},
          ],
          choices: [
            {'text': 'go', 'next': 'branch'},
            {'text': 'no', 'next': 'branch'},
          ],
        ),
        _ev(
          'branch',
          clock: '01:12',
          trigger: {
            'day': [0, 0],
          },
        ),
      ]);
      final c = await _ctl(b);
      await c.newGame(seed: 5);
      await _startDay(c);
      expect(c.clockStartFor(c.current!, 9 * 3600), 70 * 60);
      c.choose(0);
      // 01:10 + 줄 3 + 내 말 1 = 01:14
      expect(c.dayClockEnd, 74 * 60);
      c.continueAfterChoice();
      expect(c.clockStartFor(c.current!, 12 * 3600), 75 * 60);
      // 하루 도중 재시작해도 끝 시각이 이어진다.
      final c2 = GameController(bundle: b, save: SaveService());
      await c2.init();
      await c2.continueGame();
      expect(c2.dayClockEnd, 74 * 60);
      expect(c2.clockStartFor(c2.current!, 12 * 3600), 75 * 60);
    });

    test('실제 데이터: 시작 6종 × 시드 3 × 20일, 거꾸로 0번', () async {
      final b = testBundle();
      final back = <String>[];
      for (final st in b.starts) {
        for (var seed = 0; seed < 3; seed++) {
          final c = await _ctl(b);
          final rnd = Random(seed);
          await c.newGame(
            preference: Preference.genders[seed % 2],
            seed: seed,
            start: st.id,
          );
          for (var d = 0; d < 20 && c.ending == null; d++) {
            c.beginMorning();
            c.state!.hearts = b.config.maxHearts;
            await c.startDay(b.config.actions[rnd.nextInt(b.config.actions.length)]);
            int? last;
            String? lastId;
            while (c.phase == Phase.event) {
              final ev = c.current!;
              final s = c.state!;
              // 화면과 같은 계산.
              final start = c.clockStartFor(
                ev,
                ChatClock.startSeconds(
                  seed: s.seed,
                  day: s.day,
                  index: c.todayEventIndex,
                  total: c.todayEventTotal,
                ),
              );
              if (last != null && start <= last) {
                back.add('${st.id}/s$seed D${s.day} $lastId→${ev.id}');
              }
              final open = [
                for (final v in c.choices)
                  if (!v.locked) v.index,
              ];
              final i = open[rnd.nextInt(open.length)];
              c.choose(i, minigameSuccess: ev.choices[i].minigame != null ? rnd.nextBool() : null);
              last = c.dayClockEnd;
              lastId = ev.id;
              c.continueAfterChoice();
            }
            if (c.phase == Phase.summary) await c.endDay();
          }
        }
      }
      expect(back, isEmpty);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
