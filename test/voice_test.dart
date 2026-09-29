// 상대 목소리 축(`humor` · `register`) — 상대가 정해지지 않은 씬에서 호감 1위의 농담 코드와
// 말높임으로 줄·선택지를 고르는 조건. 설계와 데이터 스키마는 docs/review/13_engine_fixes.md,
// 요청 원문은 docs/review/12_main_rewrite.md §5.3(E1·E2).
//
// 이 파일이 지키는 것 둘.
// 1) 거르기가 **1위를 본다** — `{top}` 이 이름을 꺼내는 그 사람과 같은 사람([EventEngine.voiceOf]).
// 2) 검증기가 **덮이지 않은 값을 거부한다** — 조건으로 갈라 놓고 한 값을 빠뜨리면 그 값을 가진
//    캐릭터를 공략한 플레이어만 빈 화면을 본다. 무음 클라이맥스가 바로 그 버그였다.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/mbti.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';

const _config = {
  'totalDays': 30,
  'initialStats': {'charm': 10},
  'actions': [],
  'mbti': {
    'compatMultiplier': [0.5, 0.75, 1.0, 1.25, 1.5],
  },
};

/// 실제 캐스트의 모양을 줄인 것: humor 다섯 값이 다 있고, 존댓말이 양쪽에 하나씩 있다
/// (docs/CAST_BIBLE.md §0.2 — 지우 witty·존댓말 / 승현 dry·존댓말).
/// 성별마다 역할이 겹치면 `_checkCast` 가 막으므로 역할을 다 다르게 준다.
const _chars = [
  {
    'id': 'garam',
    'name': '가람',
    'gender': 'f',
    'role': 'senior',
    'humor': 'dry',
  },
  {
    'id': 'nari',
    'name': '나리',
    'gender': 'f',
    'role': 'blinddate',
    'humor': 'witty',
    'politeness': 'polite',
  },
  {
    'id': 'dasom',
    'name': '다솜',
    'gender': 'f',
    'role': 'classmate',
    'humor': 'warm',
  },
  {
    'id': 'raon',
    'name': '라온',
    'gender': 'm',
    'role': 'blinddate',
    'humor': 'dry',
    'politeness': 'polite',
  },
  {
    'id': 'maru',
    'name': '마루',
    'gender': 'm',
    'role': 'parttime',
    'humor': 'loud',
  },
  {
    'id': 'bada',
    'name': '바다',
    'gender': 'm',
    'role': 'online',
    'humor': 'meme',
  },
];

const _endings = [
  {'id': 'd', 'name': 'd', 'default': true, 'when': {}},
];

StoryBundle _bundle(
  List<Map<String, Object?>> events, {
  List<Map<String, Object?>> chars = _chars,
}) => StoryBundle.fromJsonStrings(
  config: jsonEncode(_config),
  characters: jsonEncode(chars),
  events: [jsonEncode(events)],
  endings: jsonEncode(_endings),
);

void _expectError(
  List<Map<String, Object?>> events,
  String fragment, {
  List<Map<String, Object?>> chars = _chars,
}) {
  expect(
    () => _bundle(events, chars: chars),
    throwsA(
      isA<StateError>().having((e) => e.message, 'message', contains(fragment)),
    ),
    reason: fragment,
  );
}

/// 상대가 정해지지 않은 씬(`character` 없음) 하나. 고백·첫 싸움이 이 모양이다.
Map<String, Object?> _ev({
  String id = 'm21',
  List<Object?>? lines,
  List<Object?>? choices,
  Map<String, Object?> extra = const {},
}) => {
  'id': id,
  'layer': 'daily',
  'once': false,
  'lines':
      lines ??
      [
        {'who': 'them', 'text': '공통'},
      ],
  'choices':
      choices ??
      [
        {'text': '응', 'reply': '좋아'},
        {'text': '아니', 'reply': '그래'},
      ],
  ...extra,
};

/// 다섯 humor 를 다 덮는 줄 묶음(검증기를 통과하는 최소 형태).
List<Object?> get _fiveHumors => [
  {'who': 'them', 'text': '건조', 'humor': 'dry'},
  {'who': 'them', 'text': '시끌', 'humor': 'loud'},
  {'who': 'them', 'text': '재치', 'humor': 'witty'},
  {'who': 'them', 'text': '짤', 'humor': 'meme'},
  {'who': 'them', 'text': '다정', 'humor': 'warm'},
];

GameState _state(StoryBundle b, {Map<String, int> affection = const {}}) {
  final s = GameState.fresh(
    b.config,
    b.characters,
    seed: 1,
    preference: 'all',
    nowMs: 0,
  );
  affection.forEach((id, v) => s.rel(id).affection = v);
  return s;
}

/// [id] 가 1위인 회차에서 [ev] 를 화면용으로 거른 대사.
List<String> _textsFor(StoryBundle b, String? id, StoryEvent ev) {
  final e = EventEngine(b);
  final s = _state(b, affection: id == null ? {} : {id: 50});
  return [for (final l in e.viewFor(s, ev).lines) l.text];
}

void main() {
  group('Line.humor — 1위의 농담 코드로 줄을 고른다', () {
    test('다섯 값이 각자 자기 줄만 본다', () {
      final b = _bundle([
        _ev(lines: _fiveHumors),
      ]);
      final ev = b.eventById['m21']!;
      expect(_textsFor(b, 'garam', ev), ['건조']); // dry
      expect(_textsFor(b, 'maru', ev), ['시끌']); // loud
      expect(_textsFor(b, 'nari', ev), ['재치']); // witty
      expect(_textsFor(b, 'bada', ev), ['짤']); // meme
      expect(_textsFor(b, 'dasom', ev), ['다정']); // warm
    });

    test('1위가 없으면 warm 으로 본다 — `{top}` 이 "그 사람" 인 회차도 빈 화면이 아니다', () {
      final b = _bundle([
        _ev(lines: _fiveHumors),
      ]);
      expect(_textsFor(b, null, b.eventById['m21']!), ['다정']);
      expect(const MbtiView(null).humor, Humor.fallback);
    });

    test('한 줄이 여러 값을 가질 수 있다', () {
      final b = _bundle([
        _ev(
          lines: [
            {
              'who': 'them',
              'text': '끊긴 말',
              'humor': ['dry', 'witty'],
            },
            {
              'who': 'them',
              'text': 'ㅋㅋㅋ',
              'humor': ['loud', 'meme', 'warm'],
            },
          ],
        ),
      ]);
      final ev = b.eventById['m21']!;
      expect(_textsFor(b, 'garam', ev), ['끊긴 말']);
      expect(_textsFor(b, 'nari', ev), ['끊긴 말']);
      expect(_textsFor(b, 'bada', ev), ['ㅋㅋㅋ']);
    });

    test('조건 없는 줄은 누구에게나 남는다', () {
      final b = _bundle([
        _ev(
          lines: [
            {'who': 'them', 'text': '공통'},
            {'who': 'them', 'text': '건조', 'humor': 'dry'},
          ],
        ),
      ]);
      final ev = b.eventById['m21']!;
      expect(_textsFor(b, 'garam', ev), ['공통', '건조']);
      expect(_textsFor(b, 'maru', ev), ['공통']);
    });
  });

  group('register — 1위의 말높임으로 줄·선택지를 고른다', () {
    test('반말 9명 / 존댓말 3명이 서로 다른 줄을 본다', () {
      final b = _bundle([
        _ev(
          lines: [
            {'who': 'them', 'text': '지금 나올 수 있어?', 'register': 'casual'},
            {'who': 'them', 'text': '지금 나오실 수 있어요?', 'register': 'polite'},
          ],
        ),
      ]);
      final ev = b.eventById['m21']!;
      expect(_textsFor(b, 'garam', ev), ['지금 나올 수 있어?']);
      expect(_textsFor(b, 'nari', ev), ['지금 나오실 수 있어요?']); // 존댓말
      expect(_textsFor(b, 'raon', ev), ['지금 나오실 수 있어요?']); // 존댓말
      // 1위가 없으면 반말(12명 중 9명).
      expect(_textsFor(b, null, ev), ['지금 나올 수 있어?']);
    });

    test('선택지 문구도 상대에 맞춰 고른다 — 지우에게 반말로 사과하지 않는다', () {
      final b = _bundle([
        _ev(
          choices: [
            {'text': '미안했어. 내가 부족했어', 'register': 'casual'},
            {'text': '미안했어요. 제가 부족했어요', 'register': 'polite'},
            {'text': '아무 말도 안 한다'},
          ],
        ),
      ]);
      final ev = b.eventById['m21']!;
      final e = EventEngine(b);
      List<String> texts(String id) => [
        for (final c in e.choicesFor(_state(b, affection: {id: 50}), ev))
          c.choice.text,
      ];
      expect(texts('garam'), ['미안했어. 내가 부족했어', '아무 말도 안 한다']);
      expect(texts('nari'), ['미안했어요. 제가 부족했어요', '아무 말도 안 한다']);
    });

    test('`{top}` 이 부르는 사람과 같은 사람을 본다', () {
      // 이벤트가 캐릭터를 지목해도 1위가 있으면 1위가 이긴다 — 말풍선 머리에 뜨는 이름
      // ([EventEngine.topNameFor])과 대사를 고르는 기준이 어긋나면 안 된다.
      final b = _bundle([
        {
          ..._ev(
            id: 'garam_r01',
            lines: [
              {'who': 'them', 'text': '건조', 'humor': 'dry'},
              {
                'who': 'them',
                'text': '나머지',
                'humor': ['loud', 'witty', 'meme', 'warm'],
              },
            ],
          ),
          'layer': 'route',
          'character': 'garam',
        },
      ]);
      final ev = b.eventById['garam_r01']!;
      final e = EventEngine(b);
      final s = _state(b, affection: {'maru': 50});
      expect(e.topNameFor(s, event: ev), '마루');
      expect(e.voiceOf(s, ev)!.id, 'maru');
      expect([for (final l in e.viewFor(s, ev).lines) l.text], ['나머지']);
      // 1위가 없으면 이벤트가 지목한 캐릭터로 내려간다(이름 규칙과 같다).
      final none = _state(b);
      expect(e.topNameFor(none, event: ev), '가람');
      expect(e.voiceOf(none, ev)!.id, 'garam');
      expect([for (final l in e.viewFor(none, ev).lines) l.text], ['건조']);
    });
  });

  group('검증기: 덮이지 않은 값은 빈 화면이다', () {
    test('humor 한 값이 빠지면 그 캐릭터를 든 회차가 무음 — 거부한다', () {
      // warm 이 없다 → 다솜(warm) 을 공략한 플레이어는 대사를 한 줄도 못 본다.
      _expectError([
        _ev(lines: _fiveHumors.take(4).toList()),
      ], '대사가 0줄');
      // 오류 문구가 **누가** 못 보는지 말한다(witty 만 빠진 묶음 → 나리).
      _expectError([
        _ev(
          lines: [
            for (final l in _fiveHumors)
              if ((l as Map)['humor'] != 'witty') l,
          ],
        ),
      ], '1위 나리(witty·polite)');
      // 1위가 없는 회차도 경우의 하나다(warm·casual 로 본다).
      _expectError([
        _ev(
          lines: [
            {'who': 'them', 'text': '건조', 'humor': 'dry'},
          ],
        ),
      ], '1위 없음(warm·casual)');
      // 다섯 값을 다 덮으면 통과.
      expect(() => _bundle([_ev(lines: _fiveHumors)]), returnsNormally);
    });

    test('register 한 쪽이 빠지면 거부한다', () {
      _expectError([
        _ev(
          lines: [
            {'who': 'them', 'text': '반말만', 'register': 'casual'},
          ],
        ),
      ], '1위 나리(witty·polite)');
      expect(
        () => _bundle([
          _ev(
            lines: [
              {'who': 'them', 'text': '반말', 'register': 'casual'},
              {'who': 'them', 'text': '존댓말', 'register': 'polite'},
            ],
          ),
        ]),
        returnsNormally,
      );
    });

    test('선택 뒤 반응이 비는 것도 잡는다', () {
      _expectError([
        _ev(
          choices: [
            {
              'text': 'a',
              'reply': [
                {'who': 'them', 'text': '건조', 'humor': 'dry'},
                {'who': 'them', 'text': '시끌', 'humor': 'loud'},
              ],
            },
            {'text': 'b'},
          ],
        ),
      ], '반응이 0줄');
    });

    test('선택지가 한쪽 말높임만 있으면 나머지 회차에 선택지가 모자란다', () {
      _expectError([
        _ev(
          choices: [
            {'text': '미안했어', 'register': 'casual'},
            {'text': '우리 얘기 좀 하자', 'register': 'casual'},
          ],
        ),
      ], '선택지가 0개');
    });

    test('변형 대사 묶음도 덮여야 한다', () {
      // 본편은 멀쩡한데 변형만 구멍이 나면 그 묶음이 뽑힌 회차만 무음이 되고,
      // 어느 회차에 뽑히는지는 시드가 정한다([EventEngine.variantOf]).
      _expectError([
        _ev(
          extra: {
            'variants': [
              {
                'lines': [
                  {'who': 'them', 'text': '건조', 'humor': 'dry'},
                ],
              },
            ],
          },
        ),
      ], 'm21.variants[0]');
    });

    test('MBTI 축과 겹쳐도 각각 본다', () {
      // 줄이 MBTI 로도 humor 로도 갈린 이벤트. I·warm 조합이 비어 있다.
      _expectError([
        _ev(
          lines: [
            {'who': 'them', 'text': '모름', 'noMbti': true},
            {'who': 'them', 'text': 'E', 'mbti': 'E'},
            {'who': 'them', 'text': 'I 건조', 'mbti': 'I', 'humor': 'dry'},
          ],
        ),
      ], 'MBTI ISTJ · 1위 없음(warm·casual)');
    });
  });

  group('검증기: 값 오타', () {
    test('모르는 humor·register 값은 거부한다', () {
      _expectError([
        _ev(
          lines: [
            {'who': 'them', 'text': 'x', 'humor': 'funny'},
          ],
        ),
      ], 'humor 조건은');
      _expectError([
        _ev(
          lines: [
            {'who': 'them', 'text': 'x', 'register': 'jondae'},
          ],
        ),
      ], 'register 는 casual|polite');
      _expectError([
        _ev(
          choices: [
            {'text': 'a', 'register': 'formal'},
            {'text': 'b'},
          ],
        ),
      ], 'register 는 casual|polite');
      _expectError([
        _ev(
          lines: [
            {
              'who': 'them',
              'text': 'x',
              'humor': ['dry', 'dry'],
            },
          ],
        ),
      ], 'humor 조건에 같은 값이 두 번');
    });

    test('캐릭터의 humor·politeness 오타는 조용히 기본값으로 떨어지므로 거부한다', () {
      final bad = [
        {'id': 'garam', 'name': '가람', 'gender': 'f', 'role': 'senior'},
      ];
      _expectError(
        [_ev()],
        '캐릭터 politeness 는 casual|polite',
        chars: [
          {...bad.first, 'politeness': 'jondaenmal'},
        ],
      );
      _expectError(
        [_ev()],
        '캐릭터 humor 는',
        chars: [
          {...bad.first, 'humor': 'sarcastic'},
        ],
      );
      // 안 적으면 반말이 기본이다 — 12명 중 9명이라 데이터 파일이 작아진다.
      final b = _bundle([_ev()], chars: bad);
      expect(b.characterById['garam']!.politeness, Politeness.casual);
      expect(b.characterById['garam']!.humor, Humor.fallback);
    });
  });
}
