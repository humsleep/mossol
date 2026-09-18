// 초반 호감 가속(config.earlyAffection)과 서사 신호(signals.json) 테스트.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/effects.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';

import 'widget/helpers.dart';

const _chars = '''[
  {"id": "a", "name": "가", "hidden": false},
  {"id": "b", "name": "나", "hidden": false},
  {"id": "h", "name": "히", "hidden": true}
]''';

const _endings =
    '[{"id": "solo", "name": "솔로", "tier": "solo", "default": true}]';

/// 선택지 하나짜리 합성 이벤트. [fx] 는 성공 효과, [fail] 은 실패 효과.
String _events(Map<String, dynamic> fx, {Map<String, dynamic>? fail}) =>
    jsonEncode([
      {
        'id': 'e1',
        'layer': 'route',
        'character': 'a',
        'lines': [
          {'who': 'a', 'text': '안녕'},
        ],
        'choices': [
          {
            'text': '응',
            'effects': fx,
            if (fail != null) ...{'chance': 50, 'fail': fail},
          },
        ],
      },
    ]);

StoryBundle _bundle({
  Object? early = const {
    'curve': [2, 2, 2],
    'maxTotal': 3,
  },
  Map<String, dynamic> fx = const {
    'affection': {'*': 1},
  },
  Map<String, dynamic>? fail,
  String? signals,
}) => StoryBundle.fromJsonStrings(
  config: jsonEncode({'totalDays': 100, 'earlyAffection': ?early}),
  characters: _chars,
  events: [_events(fx, fail: fail)],
  endings: _endings,
  signals: signals,
);

/// 캐릭터 a 에 대한 합성 신호. 구간 1~9 / 10~19 / 20~100.
Map<String, dynamic> _signalsJson({
  List<Map<String, dynamic>>? bands,
  List<String> down = const ['요즘 답이 늦다', '읽고 한참 뒤에 답했다'],
  String id = 'a',
}) => {
  'characters': {
    id: {
      'bands':
          bands ??
          [
            {
              'min': 1,
              'max': 9,
              'lines': ['첫째 구간 1', '첫째 구간 2', '첫째 구간 3'],
            },
            {
              'min': 10,
              'max': 19,
              'lines': ['둘째 구간 1', '둘째 구간 2', '둘째 구간 3'],
            },
            {
              'min': 20,
              'max': 100,
              'lines': ['셋째 구간 1', '셋째 구간 2', '셋째 구간 3'],
            },
          ],
      'down': down,
    },
  },
};

({GameState s, AppliedDelta d}) _choose(
  StoryBundle b, {
  int day = 1,
  bool crit = false,
  bool success = true,
  int start = 0,
}) {
  final engine = EventEngine(b);
  final s = GameState.fresh(b.config, b.characters, seed: 1)..day = day;
  s.rel('a').affection = start;
  s.rel('b')
    ..affection = 50
    ..trust = 50;
  final ev = b.eventById['e1']!;
  final out = engine.applyChoice(
    s,
    ev,
    ev.choices.first,
    forcedSuccess: success,
    forcedCritical: crit,
  );
  return (s: s, d: out.delta);
}

void main() {
  group('초반 호감 가속', () {
    test('1일차 +1 은 +2, 곡선이 끝난 다음 날(4일차)은 원래대로 +1', () {
      final b = _bundle();
      expect(_choose(b, day: 1).d.affection, {'a': 2});
      expect(_choose(b, day: 3).d.affection, {'a': 2});
      expect(_choose(b, day: 4).d.affection, {'a': 1});
      expect(_choose(b, day: 40).d.affection, {'a': 1});
    });

    test('감소와 신뢰는 배율을 받지 않는다', () {
      final b = _bundle(
        fx: {
          'affection': {'*': 3, 'b': -4},
          'trust': {'*': 2, 'b': -1},
        },
      );
      final r = _choose(b, day: 1, crit: true);
      // 오르는 호감만: 3 × min(2×2, 상한 3) = 9.
      expect(r.d.affection, {'a': 9, 'b': -4});
      expect(r.d.trust, {'a': 2, 'b': -1});
    });

    test('크리티컬과 곱하되 상한(maxTotal)으로 자른다', () {
      final b = _bundle(
        fx: {
          'affection': {'*': 5},
        },
      );
      // 1일차: 2 × 2 = 4 → 상한 3. +5 → +15.
      expect(_choose(b, day: 1, crit: true).d.affection, {'a': 15});
      // 가속이 끝나면 크리티컬만 2배.
      expect(_choose(b, day: 4, crit: true).d.affection, {'a': 10});
      // 크리티컬 없는 1일차는 가속만 2배.
      expect(_choose(b, day: 1).d.affection, {'a': 10});
      final e = b.config.earlyAffection;
      expect(e.combined(1, critical: true), 3);
      expect(e.combined(4, critical: true), 2);
      expect(e.combined(2), 2);
      expect(e.lastDay, 3);
    });

    test('상한이 크리티컬보다 작게 적혀 있어도 크리티컬은 손해가 아니다', () {
      const e = EarlyAffection(curve: [1.5], maxTotal: 1);
      expect(e.combined(1, critical: true), 2);
      expect(e.combined(1), 1.5);
    });

    test('배율은 올림한다: 1.5배면 +1→+2, +2→+3, +3→+5', () {
      expect(scaleGain(1, 1.5), 2);
      expect(scaleGain(2, 1.5), 3);
      expect(scaleGain(3, 1.5), 5);
      expect(scaleGain(4, 1.25), 5);
      expect(scaleGain(3, 1), 3);
      expect(scaleGain(-3, 2), -3);
      expect(scaleGain(0, 2), 0);
    });

    test('untilDay/multiplier 형식도 읽는다', () {
      final b = _bundle(early: {'untilDay': 10, 'multiplier': 1.5});
      expect(b.config.earlyAffection.multiplierFor(10), 1.5);
      expect(b.config.earlyAffection.multiplierFor(11), 1);
      expect(_choose(b, day: 10).d.affection, {'a': 2});
      expect(_choose(b, day: 11).d.affection, {'a': 1});
    });

    test('설정이 없으면 늘 1배(크리티컬만 2배)', () {
      final b = _bundle(early: null);
      expect(b.config.earlyAffection.isEmpty, isTrue);
      expect(_choose(b, day: 1).d.affection, {'a': 1});
      expect(_choose(b, day: 1, crit: true).d.affection, {'a': 2});
    });

    test('실패 효과의 오르는 호감에도 초반 가속만 걸린다', () {
      final b = _bundle(
        fail: {
          'affection': {'*': 1},
        },
      );
      final r = _choose(b, day: 2, success: false);
      expect(r.d.affection, {'a': 2});
    });

    test('100 을 넘지 않는다', () {
      final r = _choose(_bundle(), day: 1, start: 99);
      expect(r.s.affectionOf('a'), 100);
      expect(r.d.affection, {'a': 1});
    });

    test('검증기: 곡선 범위와 상한', () {
      expect(
        () => _bundle(
          early: {
            'curve': [0.5],
          },
        ),
        throwsStateError,
      );
      expect(
        () => _bundle(
          early: {
            'curve': [5],
          },
        ),
        throwsStateError,
      );
      expect(
        () => _bundle(
          early: {
            'curve': [2],
            'maxTotal': 1.5,
          },
        ),
        throwsStateError,
      );
    });

    test('실제 config: 1~2일차 2배, 3일차 1.5배, 4일차부터 1배, 크리티컬 상한 3', () {
      final e = testBundle().config.earlyAffection;
      expect(
        [for (var d = 1; d <= 5; d++) e.multiplierFor(d)],
        [2, 2, 1.5, 1, 1],
      );
      expect(e.combined(1, critical: true), 3);
    });
  });

  group('서사 신호', () {
    late SignalBook book;
    setUp(() {
      book = SignalBook.fromJsonString(jsonEncode(_signalsJson()));
    });

    test('호감 0 이면 신호가 없다', () {
      expect(book.signalFor('a', 0, seed: 1, day: 1), isNull);
      expect(book.bandIndex('a', 0), -1);
      expect(
        book.signalFor('b', 30, seed: 1, day: 1),
        isNull,
        reason: '데이터 없는 캐릭터',
      );
    });

    test('구간 경계', () {
      expect(book.bandIndex('a', 1), 0);
      expect(book.bandIndex('a', 9), 0);
      expect(book.bandIndex('a', 10), 1);
      expect(book.bandIndex('a', 19), 1);
      expect(book.bandIndex('a', 20), 2);
      expect(book.bandIndex('a', 100), 2);
      expect(book.signalFor('a', 9, seed: 3, day: 5), startsWith('첫째'));
      expect(book.signalFor('a', 10, seed: 3, day: 5), startsWith('둘째'));
    });

    test('결정적이다: 같은 (seed, day, 캐릭터) 면 같은 문장, 날이 바뀌면 고르게 돈다', () {
      final first = book.signalFor('a', 12, seed: 77, day: 8);
      for (var i = 0; i < 5; i++) {
        expect(book.signalFor('a', 12, seed: 77, day: 8), first);
      }
      // 같은 날 다시 불러도 JSON 을 다시 읽어도 같다.
      final again = SignalBook.fromJsonString(jsonEncode(_signalsJson()));
      expect(again.signalFor('a', 12, seed: 77, day: 8), first);
      final seen = {
        for (var d = 1; d <= 30; d++) book.signalFor('a', 12, seed: 77, day: d),
      };
      expect(seen.length, 3, reason: '한 구간의 문장 3개가 모두 쓰여야 한다');
      expect(
        SignalBook.pickIndex(3, seed: 5, day: 9, id: 'a'),
        SignalBook.pickIndex(3, seed: 5, day: 9, id: 'a'),
      );
    });

    test('구간 변화: 상승·하강·같은 구간', () {
      final up = book.shiftFor('a', 8, 11, seed: 1, day: 2)!;
      expect(up.up, isTrue);
      expect(up.fromBand, 0);
      expect(up.toBand, 1);
      expect(up.text, startsWith('둘째'));
      final first = book.shiftFor('a', 0, 2, seed: 1, day: 1)!;
      expect(first.up, isTrue, reason: '0 → 첫 구간도 상승이다');
      final down = book.shiftFor('a', 21, 15, seed: 1, day: 2)!;
      expect(down.up, isFalse);
      expect(['요즘 답이 늦다', '읽고 한참 뒤에 답했다'], contains(down.text));
      expect(book.shiftFor('a', 11, 18, seed: 1, day: 2), isNull);
      // 하강 문장이 없으면 하강 카드도 없다.
      final noDown = SignalBook.fromJsonString(
        jsonEncode(_signalsJson(down: const [])),
      );
      expect(noDown.shiftFor('a', 21, 15, seed: 1, day: 2), isNull);
    });

    test('파일이 없거나 비어도 번들이 뜬다', () {
      for (final raw in [null, '', '   ', '{}']) {
        final b = _bundle(signals: raw);
        expect(b.signals.isEmpty, isTrue, reason: '$raw');
      }
    });

    group('검증기', () {
      String bad(Map<String, dynamic> j) => jsonEncode(j);

      test('없는 캐릭터', () {
        expect(
          () => _bundle(signals: bad(_signalsJson(id: 'zz'))),
          throwsStateError,
        );
      });

      test('구간 겹침', () {
        expect(
          () => _bundle(
            signals: bad(
              _signalsJson(
                bands: [
                  {
                    'min': 1,
                    'max': 10,
                    'lines': ['x'],
                  },
                  {
                    'min': 10,
                    'max': 100,
                    'lines': ['y'],
                  },
                ],
              ),
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('겹침'),
            ),
          ),
        );
      });

      test('구간 빈칸(중간·앞·끝)', () {
        for (final bands in [
          [
            {
              'min': 1,
              'max': 9,
              'lines': ['x'],
            },
            {
              'min': 11,
              'max': 100,
              'lines': ['y'],
            },
          ],
          [
            {
              'min': 2,
              'max': 100,
              'lines': ['x'],
            },
          ],
          [
            {
              'min': 1,
              'max': 89,
              'lines': ['x'],
            },
          ],
        ]) {
          expect(
            () => _bundle(signals: bad(_signalsJson(bands: bands))),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('빈칸'),
              ),
            ),
          );
        }
      });

      test('문장 길이·빈 문장·빈 구간', () {
        final long = '가' * (SignalBook.maxLength + 1);
        expect(
          () => _bundle(
            signals: bad(
              _signalsJson(
                bands: [
                  {
                    'min': 1,
                    'max': 100,
                    'lines': [long],
                  },
                ],
              ),
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('초과'),
            ),
          ),
        );
        expect(
          () => _bundle(signals: bad(_signalsJson(down: const [' ']))),
          throwsStateError,
        );
        expect(
          () => _bundle(
            signals: bad(
              _signalsJson(
                bands: [
                  {'min': 1, 'max': 100, 'lines': <String>[]},
                ],
              ),
            ),
          ),
          throwsStateError,
        );
        // 정확히 40자는 통과.
        _bundle(
          signals: bad(
            _signalsJson(
              bands: [
                {
                  'min': 1,
                  'max': 100,
                  'lines': ['가' * SignalBook.maxLength],
                },
              ],
            ),
          ),
        );
      });
    });

    group('실제 signals.json', () {
      late StoryBundle b;
      setUpAll(() => b = testBundle());

      test('모든 캐릭터가 1~100 을 구간 6개 이상, 구간당 3문장, 하강 2~3문장으로 덮는다', () {
        expect(File('assets/story/signals.json').existsSync(), isTrue);
        for (final ch in b.characters) {
          final sig = b.signals.byCharacter[ch.id];
          expect(sig, isNotNull, reason: ch.id);
          expect(sig!.bands.length, greaterThanOrEqualTo(6), reason: ch.id);
          for (final band in sig.bands) {
            expect(
              band.lines.length,
              3,
              reason: '${ch.id} ${band.min}~${band.max}',
            );
          }
          expect(sig.down.length, inInclusiveRange(2, 3), reason: ch.id);
        }
      });

      test('히든(도윤)은 호감 0 이면 신호가 없고, 생기면 있다', () {
        final hidden = b.characters.firstWhere((c) => c.hidden).id;
        expect(b.signals.signalFor(hidden, 0, seed: 9, day: 3), isNull);
        expect(b.signals.signalFor(hidden, 1, seed: 9, day: 3), isNotNull);
      });

      test('주인공 성별을 정하는 호칭·실존 브랜드가 없다', () {
        final all = [
          for (final s in b.signals.byCharacter.values) ...[
            for (final band in s.bands) ...band.lines,
            ...s.down,
          ],
        ];
        final banned = RegExp(
          r'오빠|언니|누나|형이|형한테|그녀|여친|남친|여자친구|남자친구|카톡|카카오|인스타|스타벅스|페이스북|유튜브',
        );
        for (final l in all) {
          expect(banned.hasMatch(l), isFalse, reason: l);
        }
      });
    });
  });

  group('컨트롤러 todayShifts · SaveSummary.topSignal', () {
    late GameController c;
    setUp(() async {
      c = await makeController();
      await c.newGame(seed: 21);
    });

    test('하루 시작 대비 구간을 넘은 사람만, 오른 쪽 먼저', () {
      final s = c.state!;
      // 예은 7 → 12 (1~9 → 10~19 상승), 서연 12 → 9 (하강), 하늘 11 → 15 (같은 구간).
      s.rel('yeeun').affection = 12;
      c.dayDelta.affection['yeeun'] = 5;
      s.rel('seoyeon').affection = 9;
      c.dayDelta.affection['seoyeon'] = -3;
      s.rel('haneul').affection = 15;
      c.dayDelta.affection['haneul'] = 4;
      // 지우 0 → 25 (구간 없음 → 20~34, 두 칸 이상 점프)
      s.rel('jiwoo').affection = 25;
      c.dayDelta.affection['jiwoo'] = 25;

      final shifts = c.todayShifts;
      expect(shifts.map((x) => x.id).toList(), ['jiwoo', 'yeeun', 'seoyeon']);
      expect(shifts[0].up, isTrue);
      expect(shifts[1].up, isTrue);
      expect(shifts[1].from, 7);
      expect(shifts[1].to, 12);
      expect(shifts[2].up, isFalse);
      expect(
        c.bundle.signals.byCharacter['seoyeon']!.down,
        contains(shifts[2].text),
      );
      final yeeunLines = c.bundle.signals.byCharacter['yeeun']!.bands[1].lines;
      expect(yeeunLines, contains(shifts[1].text));
      // 몇 번을 물어도 같은 문장.
      expect(c.todayShifts[1].text, shifts[1].text);
    });

    test('0 에서 첫 구간으로 오르는 것은 카드로 띄우지 않는다', () {
      final s = c.state!;
      s.rel('yeeun').affection = 3;
      c.dayDelta.affection['yeeun'] = 3;
      expect(c.todayShifts, isEmpty);
    });

    test('변화가 없거나 신호 데이터가 없으면 빈 목록', () {
      expect(c.todayShifts, isEmpty);
      final b = c.bundle;
      final bare = StoryBundle(
        config: b.config,
        characters: b.characters,
        events: b.events,
        endings: b.endings,
      );
      final s = GameState.fresh(b.config, b.characters, seed: 1);
      s.rel('yeeun').affection = 12;
      final sum = SaveSummary.fromState(
        s,
        b.config,
        b.characters,
        signals: bare.signals,
      );
      expect(sum.topSignal, isNull);
      expect(sum.topCharacterId, 'yeeun');
    });

    test('홈 요약의 최애 신호는 같은 날 몇 번을 만들어도 같다', () {
      final s = c.state!;
      s.rel('yeeun').affection = 2;
      final a = SaveSummary.fromState(
        s,
        c.config,
        c.bundle.characters,
        signals: c.bundle.signals,
      );
      final b = SaveSummary.fromState(
        s,
        c.config,
        c.bundle.characters,
        signals: c.bundle.signals,
      );
      expect(a.topSignal, isNotNull);
      expect(a.topSignal, b.topSignal);
      expect(
        c.bundle.signals.byCharacter['yeeun']!.bands.first.lines,
        contains(a.topSignal),
      );
      s.rel('yeeun').affection = 0;
      expect(
        SaveSummary.fromState(
          s,
          c.config,
          c.bundle.characters,
          signals: c.bundle.signals,
        ).topSignal,
        isNull,
      );
    });
  });
}
