// 초반 호감 가속(config.earlyAffection)과 서사 신호(signals.json) 테스트.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/effects.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/signals.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget/helpers.dart';

const _chars = '''[
  {"id": "a", "name": "가", "gender": "f", "role": "senior", "hidden": false},
  {"id": "b", "name": "나", "gender": "m", "role": "senior", "hidden": false},
  {"id": "h", "name": "히", "gender": "m", "role": "trainer", "hidden": true}
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

      test('분량: 50~69·70~89 는 8문장 이상, 나머지 4문장 이상, 하강 5문장 이상', () {
        expect(File('assets/story/signals.json').existsSync(), isTrue);
        for (final ch in b.characters) {
          final sig = b.signals.byCharacter[ch.id];
          expect(sig, isNotNull, reason: ch.id);
          expect(sig!.bands.length, greaterThanOrEqualTo(6), reason: ch.id);
          var cond = 0;
          var total = 0;
          for (final band in sig.bands) {
            final need = band.min == 50 || band.min == 70 ? 8 : 4;
            expect(
              band.entries.length,
              greaterThanOrEqualTo(need),
              reason: '${ch.id} ${band.min}~${band.max}',
            );
            // 조건이 하나도 안 맞아도(새 회차 첫날) 구간마다 고를 문장이 있다.
            expect(
              band.entries.where((e) => !e.conditional),
              isNotEmpty,
              reason: '${ch.id} ${band.min}~${band.max} 조건 없는 문장',
            );
            total += band.entries.length;
            cond += band.entries.where((e) => e.conditional).length;
          }
          expect(sig.down.length, greaterThanOrEqualTo(5), reason: ch.id);
          // 절반 가까이는 그 캐릭터 루트의 실제 사건을 되짚는다.
          expect(cond / total, greaterThanOrEqualTo(0.4), reason: ch.id);
        }
      });

      test('when 이 가리키는 이벤트·플래그가 실제로 있다', () {
        b.signals.validateReferences(b.events);
      });

      test('사건을 전제하는 문장("같이 간", "첫 승리" 등)은 조건 없이 쓰지 않는다', () {
        final premise = RegExp(r'우리가|같이 간|첫 승리|내가 준|내 자리|그 편의점|국밥|편지');
        for (final s in b.signals.byCharacter.values) {
          for (final band in s.bands) {
            for (final e in band.entries) {
              if (premise.hasMatch(e.text)) {
                expect(e.conditional, isTrue, reason: e.text);
              }
            }
          }
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

  group('문맥 조건(when)', () {
    Map<String, dynamic> cond(String text, Map<String, dynamic> when) => {
      'text': text,
      'when': when,
    };

    SignalBook bookWith(List<Object> lines, {List<Object>? down}) =>
        SignalBook.fromJsonString(
          jsonEncode({
            'characters': {
              'a': {
                'bands': [
                  {'min': 1, 'max': 100, 'lines': lines},
                ],
                'down': down ?? const ['요즘 답이 늦다'],
              },
            },
          }),
        );

    Set<String?> picks(SignalBook book, SignalContext ctx) => {
      for (var d = 1; d <= 60; d++)
        book.signalFor('a', 50, seed: 3, day: d, context: ctx),
    };

    test('조건이 맞는 문장만 후보가 된다(flags·notFlags·seen AND)', () {
      final book = bookWith([
        '평문',
        cond('플래그', {
          'flags': ['f'],
        }),
        cond('본 이벤트', {
          'seen': ['e1'],
        }),
        cond('플래그 없을 때', {
          'notFlags': ['f'],
        }),
        cond('둘 다', {
          'flags': ['f'],
          'seen': ['e2'],
        }),
      ]);
      final withCtx = picks(
        book,
        const SignalContext(flags: {'f'}, seen: {'e1'}),
      );
      expect(withCtx, {'평문', '플래그', '본 이벤트'});
      expect(picks(book, SignalContext.none), {'평문', '플래그 없을 때'});
      expect(
        picks(book, const SignalContext(flags: {'f'}, seen: {'e1', 'e2'})),
        {'평문', '플래그', '본 이벤트', '둘 다'},
      );
    });

    test('조건 문장이 하나도 안 맞으면 조건 없는 문장, 그것도 없으면 null', () {
      final fallback = bookWith([
        cond('전시 얘기', {
          'seen': ['e1'],
        }),
        '평문 하나',
      ]);
      expect(picks(fallback, SignalContext.none), {'평문 하나'});
      final none = bookWith(
        [
          cond('전시 얘기', {
            'seen': ['e1'],
          }),
        ],
        down: [
          cond('하강 조건', {
            'flags': ['f'],
          }),
        ],
      );
      expect(none.signalFor('a', 50, seed: 1, day: 1), isNull);
      expect(none.downSignalFor('a', seed: 1, day: 1), isNull);
      expect(none.shiftFor('a', 50, 0, seed: 1, day: 1), isNull);
      expect(
        none.signalFor(
          'a',
          50,
          seed: 1,
          day: 1,
          context: const SignalContext(seen: {'e1'}),
        ),
        '전시 얘기',
      );
    });

    group('검증기', () {
      final events = jsonEncode([
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
              'effects': {
                'setFlags': ['f'],
              },
              'chance': 50,
              'fail': {
                'setFlags': ['g'],
              },
            },
          ],
        },
      ]);

      StoryBundle withWhen(Map<String, dynamic> when) =>
          StoryBundle.fromJsonStrings(
            config: jsonEncode({'totalDays': 100}),
            characters: _chars,
            events: [events],
            endings: _endings,
            signals: jsonEncode(
              _signalsJson(
                bands: [
                  {
                    'min': 1,
                    'max': 100,
                    'lines': [
                      '평문',
                      {'text': '조건', 'when': when},
                    ],
                  },
                ],
              ),
            ),
          );

      test('있는 플래그(성공·실패 setFlags)와 이벤트는 통과', () {
        final b = withWhen({
          'flags': ['f'],
          'notFlags': ['g'],
          'seen': ['e1'],
        });
        b.signals.validateReferences(b.events);
      });

      test('없는 플래그·없는 이벤트는 StateError', () {
        for (final (w, msg) in [
          (
            {
              'flags': ['zz'],
            },
            '없는 플래그',
          ),
          (
            {
              'notFlags': ['zz'],
            },
            '없는 플래그',
          ),
          (
            {
              'seen': ['nope'],
            },
            '없는 이벤트',
          ),
        ]) {
          final b = withWhen(w);
          expect(
            () => b.signals.validateReferences(b.events),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains(msg),
              ),
            ),
            reason: '$w',
          );
        }
      });

      test('when 의 모르는 키·빈 when 은 번들 검증에서 막힌다', () {
        expect(
          () => withWhen({
            'seenn': ['e1'],
          }),
          throwsStateError,
        );
        expect(() => withWhen({}), throwsStateError);
      });
    });
  });

  group('반복 방지', () {
    /// 캐릭터 a 를 호감 [aff] 에 묶어 두고 [days] 일 동안 매일 마감한다. 날마다 고정된 문장.
    List<String> run(
      SignalBook book, {
      int aff = 50,
      int days = 30,
      int seed = 5,
    }) {
      final b = _bundle(signals: jsonEncode(_signalsJson()));
      final s = GameState.fresh(b.config, b.characters, seed: seed);
      s.rel('a').affection = aff;
      final out = <String>[];
      for (var d = 1; d <= days; d++) {
        s.day = d;
        book.rollover(s, ids: const ['a'], before: {'a': aff});
        out.add(book.todaySignal(s, 'a')!);
      }
      return out;
    }

    test('후보가 4개 이상이면 연속 4일 안에 같은 문장이 없다. 결정적이다', () {
      final book = SignalBook.fromJsonString(
        jsonEncode(
          _signalsJson(
            bands: [
              {
                'min': 1,
                'max': 100,
                'lines': ['하나', '둘', '셋', '넷', '다섯'],
              },
            ],
          ),
        ),
      );
      final seq = run(book);
      for (var i = 0; i + 3 < seq.length; i++) {
        expect(seq.sublist(i, i + 4).toSet().length, 4, reason: '$i: $seq');
      }
      expect(run(book), seq, reason: '같은 세이브면 같은 순서');
      expect(seq.toSet().length, 5, reason: '모든 문장이 돈다');
    });

    test('후보가 2개면 번갈아, 1개면 그 하나', () {
      SignalBook of(List<String> lines) => SignalBook.fromJsonString(
        jsonEncode(
          _signalsJson(
            bands: [
              {'min': 1, 'max': 100, 'lines': lines},
            ],
          ),
        ),
      );
      final two = run(of(['가', '나']), days: 10);
      for (var i = 1; i < two.length; i++) {
        expect(two[i], isNot(two[i - 1]));
      }
      expect(run(of(['가']), days: 3), ['가', '가', '가']);
    });

    test('실제 데이터: 50~69·70~89 에 20일 머물러도 연속 4일 안에 반복이 없다', () {
      final b = testBundle();
      for (final ch in b.characters) {
        for (final aff in [60, 80]) {
          final s = GameState.fresh(b.config, b.characters, seed: 11);
          s.rel(ch.id).affection = aff;
          final seq = <String>[];
          for (var d = 1; d <= 20; d++) {
            s.day = d;
            b.signals.rollover(s, ids: [ch.id], before: {ch.id: aff});
            seq.add(b.signals.todaySignal(s, ch.id)!);
          }
          for (var i = 0; i + 3 < seq.length; i++) {
            expect(
              seq.sublist(i, i + 4).toSet().length,
              4,
              reason: '${ch.id} $aff: $seq',
            );
          }
        }
      }
    });

    test('기록은 키마다 최근 3개만 남는다', () {
      final h = <String, List<int>>{};
      for (final k in [1, 2, 3, 4, 2]) {
        SignalBook.remember(h, 'a:0', k);
      }
      expect(h['a:0'], [3, 4, 2]);
    });
  });

  group('컨트롤러: 정산·홈 일치, 밤사이 하락, 재시작', () {
    late GameController c;
    setUp(() async {
      c = await makeController();
      await c.newGame(seed: 21);
    });

    test('정산에서 본 "가까워졌다" 문장이 다음 날 홈 카드 문장이다', () async {
      for (final seed in [1, 2, 3, 21, 99]) {
        await c.newGame(seed: seed);
        final s = c.state!;
        s.rel('yeeun')
          ..affection = 12
          ..contactedToday = true;
        c.dayDelta.affection['yeeun'] = 5;
        final shown = c.todayShifts.single;
        expect(shown.up, isTrue);
        await c.endDay();
        c.goHome();
        expect(c.saveSummary!.topCharacterId, 'yeeun');
        expect(c.saveSummary!.topSignal, shown.text, reason: 'seed $seed');
        // 반복 방지 기록에도 들어갔다.
        expect(s.signalHistory['yeeun:1'], contains(shown.index));
      }
    });

    test('마감 −1 로 구간이 내려가면 overnightShifts 에 하강 문장, 다음 마감에 비운다', () async {
      final s = c.state!;
      s.rel('seoyeon').affection = 10; // 10~19 → 마감 −1 → 9 (1~9)
      s.rel('haneul')
        ..affection = 10
        ..contactedToday = true; // 연락했으면 안 내려간다
      await c.endDay();
      expect(s.affectionOf('seoyeon'), 9);
      expect(c.overnightShifts.keys, ['seoyeon']);
      expect(
        c.bundle.signals.byCharacter['seoyeon']!.down,
        contains(c.overnightShifts['seoyeon']),
      );
      expect(c.todayShifts, isEmpty, reason: '밤사이 하락은 오늘 정산 몫이 아니다');
      // 세이브에도 남는다(앱을 껐다 켜도 아침 한 줄이 뜬다).
      final loaded = await SaveService().load();
      expect(loaded!.overnightShifts, {
        'seoyeon': c.overnightShifts['seoyeon'],
      });
      c.goHome();
      expect(c.saveSummary!.overnight.keys, ['seoyeon']);
      s.rel('haneul').contactedToday = true;
      await c.endDay(); // 9 → 8, 같은 구간
      expect(c.overnightShifts, isEmpty);
    });

    test('하루 도중 앱을 다시 켜도 dayDelta·todayShifts 가 이어진다', () async {
      final s = c.state!;
      s.rel('yeeun').affection = 12;
      c.dayDelta.affection['yeeun'] = 5;
      c.dayDelta.stats[Stat.charm] = 3;
      c.dayDelta.trust['yeeun'] = 2;
      await c.grantHeart(); // 아무 저장이나 — 저장 때 dayDelta 가 함께 남는다
      final before = c.todayShifts;
      expect(before.single.id, 'yeeun');

      // 재시작: 같은 저장소로 새 컨트롤러.
      final c2 = GameController(bundle: c.bundle, save: SaveService());
      await c2.init();
      expect(await c2.continueGame(), isTrue);
      expect(c2.dayDelta.affection, {'yeeun': 5});
      expect(c2.dayDelta.stats, {Stat.charm: 3});
      expect(c2.dayDelta.trust, {'yeeun': 2});
      final after = c2.todayShifts;
      expect(after.map((x) => (x.id, x.from, x.to, x.text)).toList(), [
        for (final x in before) (x.id, x.from, x.to, x.text),
      ]);

      // 마감하면 비워진 채 저장된다.
      await c2.endDay();
      expect((await SaveService().load())!.dayDelta, isEmpty);
    });

    test('실제 선택으로 쌓인 변화도 재시작 뒤 남는다', () async {
      expect(await c.startDay(c.config.actions.first), isTrue);
      if (c.current != null) {
        final i = c.choices
            .firstWhere(
              (v) =>
                  !v.locked &&
                  v.choice.minigame == null &&
                  v.choice.chance == null,
            )
            .index;
        c.choose(i);
      }
      await c.grantHeart();
      final stats = Map.of(c.dayDelta.stats);
      final aff = Map.of(c.dayDelta.affection);
      expect(stats, isNotEmpty);
      final c2 = GameController(bundle: c.bundle, save: SaveService());
      await c2.init();
      await c2.continueGame();
      expect(c2.dayDelta.stats, stats);
      expect(c2.dayDelta.affection, aff);
    });

    test('새 필드가 없는 예전 세이브 JSON 도 읽힌다', () async {
      final s = c.state!;
      s.rel('yeeun').affection = 30;
      final old = s.toJson()
        ..remove('signalHistory')
        ..remove('signalPins')
        ..remove('overnightShifts')
        ..remove('dayDelta');
      final g = GameState.fromJson(jsonDecode(jsonEncode(old)));
      expect(g.signalHistory, isEmpty);
      expect(g.signalPins, isEmpty);
      expect(g.overnightShifts, isEmpty);
      expect(g.dayDelta, isEmpty);

      SharedPreferences.setMockInitialValues({
        'mossol_save_v1': jsonEncode(old),
      });
      final c2 = GameController(bundle: c.bundle, save: SaveService());
      await c2.init();
      expect(c2.saveSummary!.topSignal, isNotNull);
      expect(c2.overnightShifts, isEmpty);
      expect(await c2.continueGame(), isTrue);
      expect(c2.dayDelta.isEmpty, isTrue);
      expect(c2.todayShifts, isEmpty);
      await c2.endDay();
      // 새 필드가 생겨 저장된다.
      final raw = (await SharedPreferences.getInstance()).getString(
        'mossol_save_v1',
      )!;
      expect(jsonDecode(raw), containsPair('signalPins', isA<Map>()));
    });

    test('세이브 왕복: 신호 필드가 그대로 돌아온다', () {
      final s = c.state!
        ..signalHistory['a:1'] = [2, 0]
        ..signalPins['yeeun'] = [1, 3]
        ..overnightShifts['seoyeon'] = '말이 없다'
        ..dayDelta['stats'] = {Stat.charm: 1};
      final g = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(g.signalHistory, s.signalHistory);
      expect(g.signalPins, s.signalPins);
      expect(g.overnightShifts, s.overnightShifts);
      expect(g.dayDelta, s.dayDelta);
    });
  });
}
