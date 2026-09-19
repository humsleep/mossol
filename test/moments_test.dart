// 모먼트(전화 · 먼저 온 톡 알림 · 사진) 엔진 규칙. docs/MOMENTS_SPEC.md.
//
// 파싱, 검증기 규칙별 실패, lastMomentDay 세이브 왕복, planDay 의 모먼트 가중치 보정.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';

const _config = {
  'totalDays': 30,
  'initialStats': {'charm': 10},
  'actions': [],
};
const _chars = [
  {'id': 'a', 'name': '가람'},
  {'id': 'b', 'name': '보람'},
];
const _endings = [
  {'id': 'd', 'name': 'd', 'default': true, 'when': {}},
];

Map<String, Object?> _call({
  String id = 'mo_call',
  Object? character = 'a',
  List<Map<String, Object?>>? choices,
  Map<String, Object?> extra = const {},
}) => {
  'id': id,
  'layer': 'route',
  'character': ?character,
  'format': 'call',
  'lines': [
    {'who': 'them', 'text': '여보세요?'},
  ],
  'choices':
      choices ??
      [
        {'text': '응 나야', 'reply': '다행이다'},
        {'text': '거절', 'decline': true, 'reply': '바빠? 나중에 연락해'},
      ],
  ...extra,
};

StoryBundle _bundle(List<Map<String, Object?>> events) =>
    StoryBundle.fromJsonStrings(
      config: jsonEncode(_config),
      characters: jsonEncode(_chars),
      events: [jsonEncode(events)],
      endings: jsonEncode(_endings),
    );

void _expectError(List<Map<String, Object?>> events, String fragment) {
  expect(
    () => _bundle(events),
    throwsA(
      isA<StateError>().having((e) => e.message, 'message', contains(fragment)),
    ),
    reason: fragment,
  );
}

void main() {
  group('파싱', () {
    test('format · preview · photo · decline 을 읽고, 없으면 지금과 같다', () {
      final ev = StoryEvent.fromJson({
        'id': 'mo_x',
        'layer': 'daily',
        'preview': '창가 자리 잡았어',
        'lines': [
          {
            'who': 'them',
            'photo': {'icon': 'cafe', 'caption': '창가 자리 잡았어'},
            'text': '여기 올래?',
          },
          {'who': 'me', 'text': '응'},
        ],
        'choices': [
          {'text': 'x', 'decline': true},
        ],
      });
      expect(ev.format, 'chat');
      expect(ev.isCall, isFalse);
      expect(ev.preview, '창가 자리 잡았어');
      expect(ev.lines.first.photo!.icon, 'cafe');
      expect(ev.lines.first.photo!.caption, '창가 자리 잡았어');
      expect(ev.lines.first.text, '여기 올래?');
      expect(ev.lines.last.photo, isNull);
      expect(ev.choices.single.decline, isTrue);
      expect(ev.declineIndex, 0);

      final plain = StoryEvent.fromJson({
        'id': 'p',
        'layer': 'daily',
        'choices': [
          {'text': 'x'},
        ],
      });
      expect(plain.format, StoryEvent.formatChat);
      expect(plain.preview, isNull);
      expect(plain.choices.single.decline, isFalse);
      expect(plain.declineIndex, isNull);
      expect(plain.isMoment, isFalse);
    });

    test('빈 preview 는 없는 것으로 본다', () {
      final ev = StoryEvent.fromJson({
        'id': 'p',
        'layer': 'daily',
        'preview': '  ',
        'choices': [
          {'text': 'x'},
        ],
      });
      expect(ev.preview, isNull);
      expect(ev.isMoment, isFalse);
    });

    test('모먼트 판정: 전화 · 알림 · 사진(대사와 반응 모두)', () {
      final call = StoryEvent.fromJson(_call());
      expect(call.isCall, isTrue);
      expect(call.isMoment, isTrue);
      expect(call.declineIndex, 1);

      final photoInReply = StoryEvent.fromJson({
        'id': 'r',
        'layer': 'daily',
        'choices': [
          {
            'text': 'x',
            'reply': [
              {
                'who': 'them',
                'photo': {'icon': 'pet', 'caption': '우리 집 고양이'},
              },
            ],
          },
        ],
      });
      expect(photoInReply.hasPhoto, isTrue);
      expect(photoInReply.isMoment, isTrue);
      final b = _bundle([_call(), photoInReply.toTestJson()]);
      final eng = EventEngine(b);
      expect(eng.isMoment(b.eventById['mo_call']!), isTrue);
    });

    test('실제 번들이 events_moments.json 을 읽는다(비어 있어도 된다)', () {
      expect(StoryBundle.eventFiles, contains('events_moments.json'));
      final f = File('assets/story/events_moments.json');
      expect(f.existsSync(), isTrue, reason: '빈 배열 파일이라도 있어야 한다');
      final raw = f.readAsStringSync();
      final list = raw.trim().isEmpty ? const [] : jsonDecode(raw) as List;
      for (final e in list.cast<Map<String, dynamic>>()) {
        expect(e['id'] as String, startsWith('mo_'), reason: '규격 §3 id 접두사');
      }
    });

    test('빈 문자열 이벤트 파일은 이벤트 0개로 읽힌다', () {
      final b = StoryBundle.fromJsonStrings(
        config: jsonEncode(_config),
        characters: jsonEncode(_chars),
        events: [
          jsonEncode([_call()]),
          '',
          '  \n',
          '[]',
        ],
        endings: jsonEncode(_endings),
      );
      expect(b.events.length, 1);
    });
  });

  group('검증기 (규격 §1)', () {
    test('정상 call · preview · photo 는 통과한다', () {
      final b = _bundle([
        _call(),
        {
          'id': 'mo_pv',
          'layer': 'daily',
          'preview': '가' * StoryEvent.maxPreview,
          'lines': [
            {
              'who': 'them',
              'name': '태현',
              'photo': {'icon': 'nope', 'caption': '가' * Photo.maxCaption},
            },
          ],
          'choices': [
            {'text': 'x'},
          ],
        },
      ]);
      expect(b.events.length, 2);
    });

    test('알 수 없는 format', () {
      _expectError([
        {..._call(), 'format': 'video'},
      ], '알 수 없는 format');
    });

    test('call 은 character 필수', () {
      _expectError([_call(character: null)], 'character 필수');
    });

    test('call 은 decline 선택지가 정확히 1개', () {
      _expectError([
        _call(
          choices: [
            {'text': '응'},
            {'text': '음'},
          ],
        ),
      ], 'decline 선택지가 정확히 1개');
      _expectError([
        _call(
          choices: [
            {'text': '응'},
            {'text': '거절', 'decline': true},
            {'text': '거절2', 'decline': true},
          ],
        ),
      ], 'decline 선택지가 정확히 1개');
    });

    test('decline 에 require · minigame · chance 금지', () {
      for (final (key, value) in [
        (
          'require',
          {
            'stats': {'charm': 1},
          },
        ),
        ('minigame', 'call_rhythm'),
        ('chance', 50),
      ]) {
        _expectError([
          _call(
            choices: [
              {'text': '응'},
              {'text': '거절', 'decline': true, key: value},
            ],
          ),
        ], 'decline 선택지에 $key 금지');
      }
    });

    test('call 은 decline 이 아닌 선택지가 1개 이상', () {
      _expectError([
        _call(
          choices: [
            {'text': '거절', 'decline': true},
          ],
        ),
      ], 'decline 이 아닌 선택지가 1개 이상');
    });

    test('decline 은 call 이벤트에만', () {
      _expectError([
        {
          'id': 'c',
          'layer': 'daily',
          'choices': [
            {'text': '거절', 'decline': true},
          ],
        },
      ], 'decline 은 call 이벤트에만');
    });

    test('preview 40자 초과 · call 에 preview', () {
      _expectError([
        {
          'id': 'p',
          'layer': 'daily',
          'preview': '가' * (StoryEvent.maxPreview + 1),
          'choices': [
            {'text': 'x'},
          ],
        },
      ], 'preview 40자 초과');
      _expectError([
        _call(extra: {'preview': '전화 왔어'}),
      ], 'preview 는 chat 이벤트에만');
    });

    test('photo caption 20자 초과(대사 · 반응)', () {
      final long = '가' * (Photo.maxCaption + 1);
      _expectError([
        {
          'id': 'p',
          'layer': 'daily',
          'lines': [
            {
              'who': 'them',
              'photo': {'icon': 'sky', 'caption': long},
            },
          ],
          'choices': [
            {'text': 'x'},
          ],
        },
      ], 'caption 20자 초과: p.lines[0]');
      _expectError([
        {
          'id': 'p',
          'layer': 'daily',
          'choices': [
            {
              'text': 'x',
              'reply': [
                '앞 줄',
                {
                  'who': 'me',
                  'photo': {'icon': 'sky', 'caption': long},
                },
              ],
            },
          ],
        },
      ], 'caption 20자 초과: p.choices[0].reply[1]');
    });
  });

  group('세이브', () {
    test('lastMomentDay 왕복', () {
      final s = GameState(seed: 1, stats: {}, relations: {})
        ..lastMomentDay = 17;
      final r = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(r.lastMomentDay, 17);
    });

    test('필드가 없는 예전 세이브는 0 으로 읽힌다', () {
      final r = GameState.fromJson({'day': 9, 'seed': 3});
      expect(r.lastMomentDay, 0);
    });
  });

  group('등장 빈도 (규격 §2)', () {
    // 모먼트 1개 + 평범한 일상 1개. 하루 첫 일상 추첨(salt 'daily')만 본다.
    final events = [
      {
        'id': 'd_plain',
        'layer': 'daily',
        'once': false,
        'choices': [
          {'text': 'x'},
        ],
      },
      {
        'id': 'mo_photo',
        'layer': 'daily',
        'once': false,
        'lines': [
          {
            'who': 'them',
            'photo': {'icon': 'sky', 'caption': '하늘'},
          },
        ],
        'choices': [
          {'text': 'x'},
        ],
      },
    ];

    GameState at(int seed, int day, int lastMoment) =>
        GameState(seed: seed, stats: {}, relations: {}, day: day)
          ..lastMomentDay = lastMoment;

    test('보정 조건: 3일차부터, 마지막 모먼트가 2일 이상 전', () {
      final eng = EventEngine(_bundle(events));
      expect(eng.momentBoostActive(at(1, 1, 0)), isFalse, reason: '1일차 강제 안 함');
      expect(eng.momentBoostActive(at(1, 2, 0)), isFalse, reason: '3일차부터');
      expect(eng.momentBoostActive(at(1, 3, 0)), isTrue);
      expect(eng.momentBoostActive(at(1, 3, 1)), isTrue, reason: '2일 전');
      expect(eng.momentBoostActive(at(1, 3, 2)), isFalse, reason: '어제 봤다');
      expect(eng.momentBoostActive(at(1, 10, 10)), isFalse, reason: '오늘 봤다');
      expect(eng.momentBoostActive(at(1, 10, 8)), isTrue);
    });

    test('보정이 켜지면 모먼트가 첫 추첨에서 3배로 더 자주 뽑힌다(결정적)', () {
      final eng = EventEngine(_bundle(events));
      int count(int lastMoment) {
        var n = 0;
        for (var seed = 1; seed <= 600; seed++) {
          if (eng.planDay(at(seed, 5, lastMoment)).first.id == 'mo_photo') n++;
        }
        return n;
      }

      final boosted = count(0); // 기대 3/4
      final plain = count(4); // 기대 1/2
      expect(boosted, inInclusiveRange(400, 500));
      expect(plain, inInclusiveRange(240, 360));
      expect(boosted, greaterThan(plain + 60));
      // 같은 상태면 몇 번을 계획해도 같다.
      expect(count(0), boosted);
      final s = at(42, 7, 0);
      final a = [for (final e in eng.planDay(s)) e.id];
      final restored = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect([for (final e in eng.planDay(restored)) e.id], a);
    });

    test('모먼트가 없는 번들은 보정 여부와 무관하게 같은 계획(salt·난수 순서 보존)', () {
      final eng = EventEngine(
        _bundle([
          for (var i = 0; i < 5; i++)
            {
              'id': 'd$i',
              'layer': 'daily',
              'once': false,
              'weight': i + 1,
              'choices': [
                {'text': 'x'},
              ],
            },
        ]),
      );
      for (var seed = 1; seed <= 50; seed++) {
        final on = [for (final e in eng.planDay(at(seed, 6, 0))) e.id];
        final off = [for (final e in eng.planDay(at(seed, 6, 6))) e.id];
        expect(on, off, reason: 'seed $seed');
      }
    });

    test('모먼트 선택을 적용하면 그날이 lastMomentDay 가 된다(거절 포함), 평범한 이벤트는 그대로', () {
      final b = _bundle([...events, _call()]);
      final eng = EventEngine(b);
      final s = at(1, 8, 2);
      eng.applyChoice(
        s,
        b.eventById['d_plain']!,
        b.eventById['d_plain']!.choices[0],
      );
      expect(s.lastMomentDay, 2);
      final call = b.eventById['mo_call']!;
      eng.applyChoice(s, call, call.choices[call.declineIndex!]);
      expect(s.lastMomentDay, 8);
      expect(eng.momentBoostActive(s), isFalse);
    });
  });
}

extension on StoryEvent {
  /// 테스트용: 파싱한 이벤트를 번들 입력으로 되돌린다(사진 반응 한 줄짜리만).
  Map<String, Object?> toTestJson() => {
    'id': id,
    'layer': layer.name,
    'choices': [
      for (final c in choices)
        {
          'text': c.text,
          'reply': [
            for (final l in c.reply)
              {
                'who': l.who,
                if (l.photo != null)
                  'photo': {'icon': l.photo!.icon, 'caption': l.photo!.caption},
              },
          ],
        },
    ],
  };
}
