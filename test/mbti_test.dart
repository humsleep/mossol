// MBTI 분기 엔진 규칙. docs/MBTI_SPEC.md.
//
// 유형·조건·궁합·기질, 트리거(mbti · noMbti · compat · flagsAtLeast), 줄·선택지·반응 거르기,
// `{mbti}` 치환, 궁합 배율, 기질 에필로그, 세이브·메타 왕복, 검증기 에러, 컨트롤러 연결.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/conditions.dart';
import 'package:mossol/engine/effects.dart';
import 'package:mossol/engine/ending_resolver.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/mbti.dart';
import 'package:mossol/engine/meta_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/engine/text_template.dart';
import 'package:mossol/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _config = {
  'totalDays': 30,
  'initialStats': {'charm': 10},
  'actions': [],
  'mbti': {
    'compatMultiplier': [0.5, 0.75, 1.0, 1.25, 1.5],
  },
};
const _chars = [
  {'id': 'a', 'name': '가람', 'gender': 'f', 'role': 'senior', 'mbti': 'INTJ'},
  {'id': 'b', 'name': '보람', 'gender': 'm', 'role': 'senior', 'mbti': 'ESFP'},
];
const _endings = [
  {'id': 'd', 'name': 'd', 'default': true, 'when': {}},
];

StoryBundle _bundle(
  List<Map<String, Object?>> events, {
  List<Map<String, Object?>> endings = _endings,
  List<Map<String, Object?>> chars = _chars,
}) => StoryBundle.fromJsonStrings(
  config: jsonEncode(_config),
  characters: jsonEncode(chars),
  events: [jsonEncode(events)],
  endings: jsonEncode(endings),
);

void _expectError(
  List<Map<String, Object?>> events,
  String fragment, {
  List<Map<String, Object?>> endings = _endings,
  List<Map<String, Object?>> chars = _chars,
}) {
  expect(
    () => _bundle(events, endings: endings, chars: chars),
    throwsA(
      isA<StateError>().having((e) => e.message, 'message', contains(fragment)),
    ),
    reason: fragment,
  );
}

/// 캐릭터 a(INTJ) 의 루트 이벤트 하나. 기본은 조건 없는 줄 둘·선택지 둘.
Map<String, Object?> _ev({
  String id = 'a_r01',
  Object? character = 'a',
  List<Object?>? lines,
  List<Object?>? choices,
  Map<String, Object?> extra = const {},
}) => {
  'id': id,
  'layer': 'route',
  'character': ?character,
  'lines':
      lines ??
      [
        {'who': 'them', 'text': '안녕'},
      ],
  'choices':
      choices ??
      [
        {'text': '응', 'reply': '좋아'},
        {'text': '아니', 'reply': '그래'},
      ],
  ...extra,
};

GameState _state(StoryBundle b, {String? mbti, String pref = 'all'}) =>
    GameState.fresh(
      b.config,
      b.characters,
      seed: 1,
      mbti: mbti,
      preference: pref,
      nowMs: 0,
    );

/// nextDouble 이 늘 같은 값을 주는 난수(확률 올림 검사용).
class _FixedRandom implements Random {
  final double v;
  _FixedRandom(this.v);
  @override
  double nextDouble() => v;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  group('유형 · 조건 · 궁합 · 기질', () {
    test('16유형 + 모름 = 17가지, parse 는 대문자 4글자만', () {
      expect(Mbti.types, hasLength(16));
      expect(Mbti.types.toSet(), hasLength(16));
      expect(Mbti.playerCases, hasLength(17));
      expect(Mbti.playerCases.first, isNull);
      expect(Mbti.parse('intj'), 'INTJ');
      expect(Mbti.parse(' ENFP '), 'ENFP');
      for (final bad in ['INT', 'INTJX', 'IITJ', 'XNTJ', 'NITJ', '', 3, null]) {
        expect(Mbti.parse(bad), isNull, reason: '$bad');
      }
    });

    test('matches: 적힌 글자가 모두 있어야 참, 플레이어 null 이면 늘 거짓', () {
      expect(Mbti.matches('I', 'INTJ'), isTrue);
      expect(Mbti.matches('NF', 'INTJ'), isFalse);
      expect(Mbti.matches('NT', 'INTJ'), isTrue);
      expect(Mbti.matches('ESTJ', 'ESTJ'), isTrue);
      expect(Mbti.matches('ESTJ', 'ESTP'), isFalse);
      expect(Mbti.matches('I', null), isFalse);
    });

    test('조건 글자 검사: 모르는 글자 · 같은 축 두 글자', () {
      expect(Mbti.conditionProblem('I'), isNull);
      expect(Mbti.conditionProblem('ENFP'), isNull);
      expect(Mbti.conditionProblem('NE'), isNull, reason: '순서는 상관없다');
      expect(Mbti.conditionProblem('EI'), contains('같은 축'));
      expect(Mbti.conditionProblem('TF'), contains('같은 축'));
      expect(Mbti.conditionProblem('X'), contains('모르는 글자'));
      expect(Mbti.conditionProblem('i'), contains('모르는 글자'));
      expect(Mbti.conditionProblem(''), isNotNull);
    });

    test('기질: NT · NF · SJ · SP, null 은 null', () {
      expect(Mbti.temperament('INTJ'), 'NT');
      expect(Mbti.temperament('ENFP'), 'NF');
      expect(Mbti.temperament('ISFJ'), 'SJ');
      expect(Mbti.temperament('ESTP'), 'SP');
      expect(Mbti.temperament(null), isNull);
    });

    test('궁합 = (S/N 같음 2) + (E/I 다름 1) + (J/P 다름 1), null 이면 2', () {
      expect(Mbti.compat('ENTP', 'INTJ'), 4); // 천생연분
      expect(Mbti.compat('INTP', 'INTJ'), 3);
      expect(Mbti.compat('ENTJ', 'INTJ'), 3);
      expect(Mbti.compat('INTJ', 'INTJ'), 2);
      expect(Mbti.compat('ESTP', 'INTJ'), 2);
      expect(Mbti.compat('ISTP', 'INTJ'), 1);
      expect(Mbti.compat('ESTJ', 'INTJ'), 1);
      expect(Mbti.compat('ISTJ', 'INTJ'), 0); // 정반대
      expect(Mbti.compat(null, 'INTJ'), 2);
      expect(Mbti.compat('INTJ', null), 2);
      // 16 × 16 전부 0~4 이고 대칭이다.
      for (final p in Mbti.types) {
        for (final c in Mbti.types) {
          final v = Mbti.compat(p, c);
          expect(v, inInclusiveRange(0, 4));
          expect(Mbti.compat(c, p), v);
        }
      }
      // 한 캐릭터에게 점수별 유형 수: 4점 2명, 3점 4명, 2점 4명, 1점 4명, 0점 2명.
      final hist = List.filled(5, 0);
      for (final p in Mbti.types) {
        hist[Mbti.compat(p, 'INFP')]++;
      }
      expect(hist, [2, 4, 4, 4, 2]);
    });

    test('라벨: 점수 4 → 천생연분, 0 → 정반대', () {
      expect(Mbti.compatLabel(4), '천생연분');
      expect(Mbti.compatLabel(3), '잘 맞아요');
      expect(Mbti.compatLabel(2), '무난해요');
      expect(Mbti.compatLabel(1), '노력하면');
      expect(Mbti.compatLabel(0), '정반대');
    });

    test('playersFor: 조건에 맞는 플레이어 경우', () {
      expect(Mbti.playersFor(const Trigger()).first, isNull);
      expect(Mbti.playersFor(const Trigger(noMbti: true)), [null]);
      expect(Mbti.playersFor(const Trigger(mbti: 'I')), hasLength(8));
      final destiny = Mbti.playersFor(
        const Trigger(compat: Range(4, 4)),
        characterMbti: 'INTJ',
      ).toList();
      expect(destiny, unorderedEquals(['ENTP', 'ENFP']));
    });
  });

  group('트리거', () {
    final b = _bundle([_ev()]);

    test('mbti: 글자가 모두 있어야, noMbti: 모름에게만', () {
      const t = Trigger(mbti: 'IN');
      expect(t.matches(_state(b, mbti: 'INTJ')), isTrue);
      expect(t.matches(_state(b, mbti: 'ISTJ')), isFalse);
      expect(t.matches(_state(b)), isFalse);
      const n = Trigger(noMbti: true);
      expect(n.matches(_state(b)), isTrue);
      expect(n.matches(_state(b, mbti: 'INTJ')), isFalse);
    });

    test('compat: self 캐릭터 MBTI 와의 궁합 범위, self 가 없으면 거짓', () {
      const t = Trigger(compat: Range(4, 4));
      final s = _state(b, mbti: 'ENTP');
      expect(t.matches(s, self: 'a', selfMbti: 'INTJ'), isTrue);
      expect(t.matches(s, self: 'a', selfMbti: 'ENTP'), isFalse);
      expect(t.matches(s), isFalse);
      // 모름은 2점.
      const mid = Trigger(compat: Range(2, 2));
      expect(mid.matches(_state(b), self: 'a', selfMbti: 'INTJ'), isTrue);
    });

    test('flagsAtLeast: 목록 중 n 개 이상', () {
      final t = Trigger.fromJson({
        'flagsAtLeast': {
          'n': 2,
          'of': ['a_mbti_ei', 'a_mbti_sn', 'a_mbti_tf', 'a_mbti_jp'],
        },
      });
      final s = _state(b);
      expect(t.matches(s), isFalse);
      s.flags.add('a_mbti_ei');
      expect(t.matches(s), isFalse);
      s.flags.add('a_mbti_jp');
      expect(t.matches(s), isTrue);
    });

    test('이벤트 후보: trigger.mbti · noMbti 가 planDay 후보를 가른다', () {
      final bb = _bundle([
        _ev(
          id: 'a_i',
          extra: {
            'trigger': {'mbti': 'I'},
          },
        ),
        _ev(
          id: 'a_null',
          extra: {
            'trigger': {'noMbti': true},
          },
        ),
      ]);
      final e = EventEngine(bb);
      List<String> ids(String? m) => [
        for (final ev in e.candidates(_state(bb, mbti: m), EventLayer.route))
          ev.id,
      ];
      expect(ids('INTJ'), ['a_i']);
      expect(ids('ENTJ'), isEmpty);
      expect(ids(null), ['a_null']);
    });

    test('엔딩 when.compat 은 엔딩 캐릭터 기준(EndingResolver)', () {
      final bb = _bundle(
        [_ev()],
        endings: [
          ..._endings,
          {
            'id': 'a_destiny',
            'name': '천생연분',
            'character': 'a',
            'priority': 210,
            'when': {
              'compat': [4, 4],
              'flagsAtLeast': {
                'n': 2,
                'of': ['x', 'y', 'z'],
              },
            },
          },
        ],
      );
      final r = EndingResolver(bb.endings, characters: bb.characters);
      final good = _state(bb, mbti: 'ENFP')..flags.addAll(['x', 'z']);
      expect(r.resolve(good).id, 'a_destiny');
      final few = _state(bb, mbti: 'ENFP')..flags.add('x');
      expect(r.resolve(few).id, 'd');
      final other = _state(bb, mbti: 'INTJ')..flags.addAll(['x', 'z']);
      expect(r.resolve(other).id, 'd');
      final none = _state(bb)..flags.addAll(['x', 'z']);
      expect(r.resolve(none).id, 'd');
    });
  });

  group('거르기 (줄 · 선택지 · 반응)', () {
    final b = _bundle([
      _ev(
        lines: [
          {'who': 'them', 'text': '공통'},
          {'who': 'them', 'text': '내향', 'mbti': 'I'},
          {'who': 'them', 'text': '외향', 'mbti': 'E'},
          {'who': 'them', 'text': '모름', 'noMbti': true},
          {
            'who': 'them',
            'text': '찰떡',
            'compat': [4, 4],
          },
          {
            'who': 'them',
            'text': '보통 이하',
            'compat': [0, 2],
          },
        ],
        choices: [
          {
            'text': '공통',
            'reply': [
              '기본 반응',
              {'who': 'them', 'text': 'T 반응', 'mbti': 'T'},
            ],
            'critReply': [
              {'who': 'them', 'text': 'F 크리', 'mbti': 'F'},
              {'who': 'them', 'text': '공통 크리'},
            ],
          },
          {'text': '내향 전용', 'mbti': 'I', 'reply': '혼자가 좋지'},
          {'text': '모름 전용', 'noMbti': true, 'reply': '그렇구나'},
          {
            'text': '찰떡 전용',
            'compat': [4, 4],
            'reply': '역시',
          },
          {'text': '정답', 'reply': '딩동'},
        ],
        extra: {'hint': 4},
      ),
    ]);
    final raw = b.eventById['a_r01']!;
    final e = EventEngine(b);

    List<String> texts(List<Line> ls) => [for (final l in ls) l.text];

    test('모름: noMbti 줄·선택지와 궁합 2(보통) 줄만', () {
      final v = e.viewFor(_state(b), raw);
      expect(texts(v.lines), ['공통', '모름', '보통 이하']);
      expect([for (final c in v.choices) c.text], ['공통', '모름 전용', '정답']);
      expect(texts(v.choices.first.reply), ['기본 반응']);
      expect(texts(v.choices.first.critReply), ['공통 크리']);
      expect(v.hint, 2, reason: '힌트 인덱스는 거른 목록 기준');
    });

    test('ENTP(INTJ 와 천생연분): E 줄·찰떡 줄·찰떡 선택지, T 반응', () {
      final v = e.viewFor(_state(b, mbti: 'ENTP'), raw);
      expect(texts(v.lines), ['공통', '외향', '찰떡']);
      expect([for (final c in v.choices) c.text], ['공통', '찰떡 전용', '정답']);
      expect(texts(v.choices.first.reply), ['기본 반응', 'T 반응']);
      expect(texts(v.choices.first.critReply), ['공통 크리']);
    });

    test('ISFJ(궁합 1): I 줄·I 선택지, F 크리', () {
      final v = e.viewFor(_state(b, mbti: 'ISFJ'), raw);
      expect(texts(v.lines), ['공통', '내향', '보통 이하']);
      expect([for (final c in v.choices) c.text], ['공통', '내향 전용', '정답']);
      expect(texts(v.choices.first.critReply), ['F 크리', '공통 크리']);
      expect(v.hint, 2);
    });

    test('조건 없는 이벤트는 원본 그대로(같은 인스턴스)', () {
      final plain = StoryEvent.fromJson(_ev());
      expect(identical(plain.forMbti(const MbtiView('INTJ')), plain), isTrue);
      expect(plain.hasMbtiGates, isFalse);
      expect(raw.hasMbtiGates, isTrue);
    });

    test('힌트 선택지가 걸러지면 힌트는 null', () {
      final ev = StoryEvent.fromJson(
        _ev(
          choices: [
            {'text': 'I', 'mbti': 'I'},
            {'text': 'E', 'mbti': 'E'},
            {'text': '공통'},
          ],
          extra: {'hint': 0},
        ),
      );
      expect(ev.forMbti(const MbtiView('INTJ')).hint, 0);
      expect(ev.forMbti(const MbtiView('ENTJ')).hint, isNull);
    });

    test('choicesFor: 원래 인덱스로 거른 목록, 거른 사본을 넣으면 사본 기준', () {
      final s = _state(b, mbti: 'ISFJ');
      final views = e.choicesFor(s, raw);
      expect([for (final v in views) v.index], [0, 1, 4]);
      final shown = e.viewFor(s, raw);
      expect([for (final v in e.choicesFor(s, shown)) v.index], [0, 1, 2]);
    });

    test('applyChoice: 이 플레이어에게 보이지 않는 선택지는 거부', () {
      final s = _state(b, mbti: 'ENTJ');
      expect(
        () => e.applyChoice(s, raw, raw.choices[1]),
        throwsA(isA<ArgumentError>()),
      );
      expect(() => e.applyChoice(s, raw, raw.choices[0]), returnsNormally);
    });

    test('캐스트 소개 첫 메시지는 조건 붙은 줄을 건너뛴다', () {
      final bb = _bundle([
        _ev(
          lines: [
            {'who': 'them', 'text': 'I 만', 'mbti': 'I'},
            {'who': 'them', 'text': '모두에게'},
          ],
        ),
      ]);
      expect(bb.firstLineOf('a'), '모두에게');
    });
  });

  group('{mbti} 치환', () {
    test('{mbti} 는 유형, 모름이면 지우고, {mbti|대체어} 는 대체어', () {
      expect(TextTemplate.fill('너 {mbti}지?', mbti: 'INFP'), '너 INFP지?');
      expect(TextTemplate.fill('{mbti|모름} 맞지?', mbti: 'INFP'), 'INFP 맞지?');
      expect(TextTemplate.fill('{mbti|모름} 맞지?'), '모름 맞지?');
      expect(TextTemplate.fill('역시 {mbti}.'), '역시.');
      expect(
        TextTemplate.fill('{name|아야}, {mbti}!', name: '민지', mbti: 'ESTP'),
        '민지야, ESTP!',
      );
    });

    test('형식: {mbti|a|b} 는 오류, hasBareMbti 는 대체어 없는 것만', () {
      expect(TextTemplate.problems('{mbti}'), isEmpty);
      expect(TextTemplate.problems('{mbti|너}'), isEmpty);
      expect(TextTemplate.problems('{mbti|a|b}'), isNotEmpty);
      expect(TextTemplate.hasBareMbti('나 {mbti}'), isTrue);
      expect(TextTemplate.hasBareMbti('나 {mbti|몰라}'), isFalse);
      expect(TextTemplate.hasBareMbti('{name|아야}'), isFalse);
    });

    test('길이 검사는 MBTI 4글자도 넣어 본다', () {
      expect(TextTemplate.maxLength('{mbti|?}'), 4);
    });
  });

  group('궁합 배율', () {
    test('scaleCompat: 양수만, 소수는 확률 올림(없으면 반올림), 최소 1', () {
      expect(scaleCompat(10, 1.06), 11);
      expect(scaleCompat(10, 0.95), 10); // 9.5 → 10
      expect(scaleCompat(3, 1.0), 3);
      expect(scaleCompat(-3, 1.5), -3);
      expect(scaleCompat(1, 0.5), 1);
      expect(scaleCompat(10, 1.06, random: _FixedRandom(0.5)), 11);
      expect(scaleCompat(10, 1.06, random: _FixedRandom(0.7)), 10);
    });

    test('applyChoice: 그 캐릭터 호감 상승에만 궁합 배율(config), 감소·모름은 그대로', () {
      final b = _bundle([
        _ev(
          choices: [
            {
              'text': '좋아',
              'effects': {
                'affection': {'*': 4},
              },
            },
            {
              'text': '싫어',
              'effects': {
                'affection': {'*': -4},
              },
            },
          ],
        ),
      ]);
      final e = EventEngine(b);
      final ev = b.eventById['a_r01']!;
      int gain(String? m, int i) {
        final s = _state(b, mbti: m)..day = 20; // 초반 가속 밖
        s.rel('a').affection = 50;
        final out = e.applyChoice(
          s,
          ev,
          ev.choices[i],
          forcedCritical: false,
          random: _FixedRandom(0.99),
        );
        return out.delta.affection['a'] ?? 0;
      }

      // 테스트 config 배율 [0.5, 0.75, 1, 1.25, 1.5]. 4 × 1.5 = 6, 4 × 0.5 = 2.
      expect(gain('ENTP', 0), 6);
      expect(gain('ISTJ', 0), 2);
      expect(gain('INTJ', 0), 4);
      expect(gain(null, 0), 4);
      expect(gain('ENTP', 1), -4);
      expect(gain('ISTJ', 1), -4);
    });

    test('실제 config: 배율 [1.0, 1.0, 1.0, 1.03, 1.06] — 낮은 궁합은 깎지 않는다', () {
      expect(GameConfig.defaultCompatMultiplier, [1.0, 1.0, 1.0, 1.03, 1.06]);
      expect(GameConfig.fromJson({}).compatMultiplierFor(2), 1.0);
    });
  });

  group('기질 에필로그', () {
    final ending = Ending.fromJson({
      'id': 'x',
      'name': 'x',
      'epilogue': '기본.',
      'epilogueMbti': {'NT': '계획표.', 'SP': '즉흥 여행.'},
    });

    test('기질이 맞으면 한 문단 덧붙이고, 없거나 모름이면 기본만', () {
      expect(ending.epilogueForTemperament('NT'), '기본.\n\n계획표.');
      expect(ending.epilogueForTemperament('NF'), '기본.');
      expect(ending.epilogueForTemperament(null), '기본.');
    });

    test('검증: 키는 NT · NF · SJ · SP 만', () {
      _expectError(
        [_ev()],
        'epilogueMbti 키',
        endings: [
          ..._endings,
          {
            'id': 'e',
            'name': 'e',
            'epilogueMbti': {'XX': '?'},
          },
        ],
      );
    });
  });

  group('세이브 · 메타', () {
    test('GameState.mbti 저장·복원, 예전 세이브·틀린 값은 null', () {
      final b = _bundle([_ev()]);
      final s = _state(b, mbti: 'INFP');
      final j = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      expect(j['mbti'], 'INFP');
      expect(GameState.fromJson(j).mbti, 'INFP');
      expect(GameState.fromJson({...j}..remove('mbti')).mbti, isNull);
      expect(GameState.fromJson({...j, 'mbti': 'XXXX'}).mbti, isNull);
    });

    test('PlayerMeta.mbti · mbtiAsked 왕복, 예전 메타는 null · false', () {
      final m = PlayerMeta(mbti: 'ESTJ', mbtiAsked: true);
      final back = PlayerMeta.fromJson(
        jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>,
      );
      expect(back.mbti, 'ESTJ');
      expect(back.mbtiAsked, isTrue);
      final old = PlayerMeta.fromJson({'totalRuns': 3});
      expect(old.mbti, isNull);
      expect(old.mbtiAsked, isFalse);
    });

    test('컨트롤러: 새 게임이 메타 MBTI 를 복사, 설정을 바꿔도 진행 중 회차는 그대로', () async {
      SharedPreferences.setMockInitialValues({});
      final b = _bundle([_ev()]);
      final c = GameController(bundle: b, save: SaveService(), clock: () => 0);
      await c.init();
      expect(c.shouldAskMbti, isTrue);
      await c.setPlayerMbti('isfp');
      expect(c.playerMbti, 'ISFP');
      expect(c.shouldAskMbti, isFalse);
      expect(() => c.setPlayerMbti('ABCD'), throwsArgumentError);
      await c.newGame(seed: 1);
      expect(c.state!.mbti, 'ISFP');
      expect(c.runMbti, 'ISFP');
      await c.setPlayerMbti('ENTJ');
      expect(c.state!.mbti, 'ISFP', reason: '다음 새 게임부터');
      expect(c.say('{mbti} 맞지?'), 'ISFP 맞지?');
      // 저장된 세이브에도 남는다.
      expect((await SaveService().load())!.mbti, 'ISFP');
      await c.setPlayerMbti(null);
      expect(c.playerMbti, isNull);
      expect(c.shouldAskMbti, isFalse, reason: '지워도 다시 묻지 않는다');
    });

    test('컨트롤러: 건너뛰기는 값 없이 다시 묻지 않음', () async {
      SharedPreferences.setMockInitialValues({});
      final c = GameController(
        bundle: _bundle([_ev()]),
        save: SaveService(),
        clock: () => 0,
      );
      await c.init();
      await c.skipPlayerMbti();
      expect(c.playerMbti, isNull);
      expect(c.shouldAskMbti, isFalse);
      expect((await MetaService().load()).mbtiAsked, isTrue);
    });

    test('컨트롤러: current 는 거른 사본, choose 인덱스는 거른 목록 기준', () async {
      SharedPreferences.setMockInitialValues({});
      final b = _bundle([
        _ev(
          choices: [
            {'text': 'E 전용', 'mbti': 'E', 'reply': 'E'},
            {'text': 'I 전용', 'mbti': 'I', 'reply': 'I 반응'},
            {'text': '공통', 'reply': '공통 반응'},
            {'text': '공통2'},
          ],
        ),
      ]);
      final c = GameController(bundle: b, save: SaveService(), clock: () => 0);
      await c.init();
      await c.setPlayerMbti('INTJ');
      await c.newGame(seed: 1);
      c.current = b.eventById['a_r01'];
      expect(
        [for (final x in c.current!.choices) x.text],
        ['I 전용', '공통', '공통2'],
      );
      expect([for (final v in c.choices) v.index], [0, 1, 2]);
      c.choose(0);
      expect([for (final l in c.lastReply) l.text], ['I 반응']);
    });

    test('컨트롤러: 엔딩 에필로그는 이 회차 기질', () async {
      SharedPreferences.setMockInitialValues({});
      final c = GameController(
        bundle: _bundle([_ev()]),
        save: SaveService(),
        clock: () => 0,
      );
      await c.init();
      await c.setPlayerMbti('ESTP');
      await c.newGame(seed: 1);
      final e = Ending.fromJson({
        'id': 'x',
        'name': 'x',
        'epilogue': '기본.',
        'epilogueMbti': {'SP': '즉흥.', 'NT': '계획.'},
      });
      expect(c.epilogueOf(e), '기본.\n\n즉흥.');
      expect(c.epilogueOf(e, mbti: 'INTJ'), '기본.\n\n계획.');
    });
  });

  group('검증기', () {
    test('지금 데이터 형태(조건 없음)는 통과', () {
      expect(() => _bundle([_ev()]), returnsNormally);
    });

    test('잘못된 글자 · 같은 축 두 글자 · mbti 와 noMbti 함께', () {
      _expectError([
        _ev(
          lines: [
            {'who': 'them', 'text': 'x', 'mbti': 'X'},
            {'who': 'them', 'text': 'y'},
          ],
        ),
      ], '모르는 글자');
      _expectError([
        _ev(
          choices: [
            {'text': 'a', 'mbti': 'EI'},
            {'text': 'b'},
            {'text': 'c'},
          ],
        ),
      ], '같은 축');
      _expectError([
        _ev(
          extra: {
            'trigger': {'mbti': 'SN'},
          },
        ),
      ], '같은 축');
      _expectError([
        _ev(
          lines: [
            {'who': 'them', 'text': 'x', 'mbti': 'I', 'noMbti': true},
            {'who': 'them', 'text': 'y'},
          ],
        ),
      ], 'noMbti 를 함께');
    });

    test('캐릭터 없는 이벤트·엔딩의 compat 은 에러, 범위 밖도 에러', () {
      _expectError([
        _ev(
          id: 'daily_x',
          character: null,
          lines: [
            {
              'who': 'them',
              'text': 'x',
              'compat': [4, 4],
            },
            {'who': 'them', 'text': 'y'},
          ],
        ),
      ], 'compat 은 character');
      _expectError(
        [_ev()],
        'compat 은 character',
        endings: [
          ..._endings,
          {
            'id': 'e',
            'name': 'e',
            'when': {
              'compat': [4, 4],
            },
          },
        ],
      );
      _expectError([
        _ev(
          choices: [
            {
              'text': 'a',
              'compat': [3, 5],
            },
            {'text': 'b'},
            {'text': 'c'},
          ],
        ),
      ], 'compat 범위');
    });

    test('캐릭터 mbti 형식 · flagsAtLeast 형식', () {
      _expectError(
        [_ev()],
        '캐릭터 mbti',
        chars: [
          {
            'id': 'a',
            'name': '가람',
            'gender': 'f',
            'role': 'senior',
            'mbti': 'XYZW',
          },
        ],
      );
      _expectError([
        _ev(
          extra: {
            'trigger': {
              'flagsAtLeast': {
                'n': 3,
                'of': ['x', 'y'],
              },
            },
          },
        ),
      ], 'flagsAtLeast');
    });

    test('대체어 없는 {mbti} 는 mbti 조건이 붙은 줄·선택지(또는 트리거)에서만', () {
      _expectError([
        _ev(
          lines: [
            {'who': 'them', 'text': '너 {mbti}지?'},
          ],
        ),
      ], '{mbti}');
      _expectError([
        _ev(
          lines: [
            {'who': 'them', 'text': '너 {mbti}지?', 'noMbti': true},
            {'who': 'them', 'text': '공통'},
          ],
        ),
      ], '{mbti}');
      // 조건 붙은 줄, 조건 붙은 선택지의 반응, mbti 트리거 이벤트의 제목, 대체어 있는 것은 된다.
      expect(
        () => _bundle([
          _ev(
            lines: [
              {'who': 'them', 'text': '너 {mbti}지?', 'mbti': 'I'},
              {'who': 'them', 'text': '{mbti|너} 몰라'},
            ],
            choices: [
              {'text': '나 {mbti}', 'mbti': 'E', 'reply': '{mbti} 좋지'},
              {'text': 'a'},
              {'text': 'b'},
            ],
          ),
          _ev(
            id: 'a_r02',
            extra: {
              'title': '{mbti}',
              'trigger': {'mbti': 'N'},
            },
          ),
        ]),
        returnsNormally,
      );
      // 신호·첫 메시지 같은 곳은 늘 안 된다.
      _expectError(
        [_ev()],
        '{mbti}',
        chars: [
          {
            'id': 'a',
            'name': '가람',
            'gender': 'f',
            'role': 'senior',
            'firstLine': '{mbti}?',
          },
        ],
      );
    });

    test('17가지 플레이어 모두: 선택지 ≥ 2, 대사 ≥ 1, 반응이 0줄이 되지 않는다', () {
      // 원래 둘인데 하나가 I 전용 → E·모름에게 1개.
      _expectError([
        _ev(
          choices: [
            {'text': 'I', 'mbti': 'I'},
            {'text': '공통'},
          ],
        ),
      ], '선택지가 1개');
      // 대사가 전부 조건부 → 모름에게 0줄.
      _expectError([
        _ev(
          lines: [
            {'who': 'them', 'text': 'I', 'mbti': 'I'},
            {'who': 'them', 'text': 'E', 'mbti': 'E'},
          ],
        ),
      ], '대사가 0줄');
      // 반응이 전부 조건부 → 누군가에게 0줄.
      _expectError([
        _ev(
          choices: [
            {
              'text': 'a',
              'reply': [
                {'who': 'them', 'text': 'T', 'mbti': 'T'},
              ],
            },
            {'text': 'b'},
          ],
        ),
      ], '반응이 0줄');
      // 원래 1개인 선택지는 1개면 된다. 짝이 맞는 분기는 통과.
      expect(
        () => _bundle([
          _ev(
            choices: [
              {'text': '하나'},
            ],
          ),
          _ev(
            id: 'a_r02',
            lines: [
              {'who': 'them', 'text': '공통'},
              {'who': 'them', 'text': 'I', 'mbti': 'I'},
            ],
            choices: [
              {'text': 'I 전용', 'mbti': 'I'},
              {
                'text': '공통',
                'reply': [
                  {'who': 'them', 'text': 'T', 'mbti': 'T'},
                  {'who': 'them', 'text': '모두'},
                ],
              },
              {'text': '공통2'},
            ],
          ),
        ]),
        returnsNormally,
      );
    });

    test('트리거가 막는 플레이어는 거른 결과를 따지지 않는다', () {
      expect(
        () => _bundle([
          _ev(
            extra: {
              'trigger': {'mbti': 'I'},
            },
            choices: [
              {'text': 'I', 'mbti': 'I'},
              {'text': '공통'},
            ],
          ),
        ]),
        returnsNormally,
      );
    });
  });
}
