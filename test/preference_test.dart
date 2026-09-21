// 남성향·여성향 분리(회차 선호) 검증. 엔진 필터 · 세이브 호환 · main 쪽별 버전 ·
// 선호 밖 캐릭터 효과 무시 · 선택 화면 위젯.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/ending_resolver.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/album_screen.dart';
import 'package:mossol/ui/preference_screen.dart';
import 'package:mossol/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget/helpers.dart';

// ---------------------------------------------------------------------------
// 합성 번들: 여성 fa(선배) · fb(온라인 친구), 남성 ma(선배) · mh(히든 트레이너).

const _config = {
  'totalDays': 100,
  'initialStats': {'sincerity': 50},
  'actions': [],
};

const _chars = [
  {'id': 'fa', 'name': '가영', 'gender': 'f', 'role': 'senior'},
  {'id': 'fb', 'name': '나래', 'gender': 'f', 'role': 'online'},
  {'id': 'ma', 'name': '다온', 'gender': 'm', 'role': 'senior'},
  {'id': 'mh', 'name': '라온', 'gender': 'm', 'role': 'trainer', 'hidden': true},
];

Map<String, Object?> _ev(
  String id,
  String layer, {
  String? character,
  int? day,
  Map<String, Object?>? trigger,
  Map<String, Object?> effects = const {},
  Map<String, Object?>? require,
  Map<String, Object?> extra = const {},
}) => {
  'id': id,
  'layer': layer,
  'character': ?character,
  'day': ?day,
  'trigger': ?trigger,
  'choices': [
    {'text': '응', 'effects': effects, 'require': ?require},
  ],
  ...extra,
};

final _events = [
  // main 1일차: 쪽별 버전 둘. 2일차: 공용 하나.
  _ev('m1f', 'main', day: 1, trigger: {'pref': 'f'}),
  _ev('m1m', 'main', day: 1, trigger: {'pref': 'm'}),
  _ev('m2', 'main', day: 2),
  // 캐릭터 루트.
  _ev(
    'fa_r',
    'route',
    character: 'fa',
    effects: {
      'affection': {'*': 2},
    },
  ),
  _ev('fb_r', 'route', character: 'fb'),
  _ev('ma_r', 'route', character: 'ma'),
  // 남성 쪽 모먼트(전화).
  {
    'id': 'ma_call',
    'layer': 'daily',
    'character': 'ma',
    'format': 'call',
    'choices': [
      {'text': '받기'},
      {'text': '거절', 'decline': true},
    ],
  },
  // 공용 일상: 특정 캐릭터 id 를 직접 쓴다.
  _ev(
    'd_direct',
    'daily',
    effects: {
      'affection': {'fa': 3, 'ma': 3},
      'trust': {'ma': 2},
    },
  ),
  _ev(
    'd_top',
    'daily',
    effects: {
      'affection': {'@top': 4},
    },
  ),
  // 선호 밖 캐릭터를 요구하는 조건·잠금.
  _ev(
    'd_need_ma',
    'daily',
    trigger: {
      'affection': {
        'ma': [30, 100],
      },
    },
  ),
  _ev(
    'd_lock_ma',
    'daily',
    require: {
      'affection': {'ma': 20},
    },
  ),
  _ev(
    'd_any',
    'daily',
    trigger: {
      'anyAffection': {'min': 10, 'count': 2},
    },
  ),
];

const _endings = [
  {
    'id': 'fa_happy',
    'name': 'fa',
    'priority': 200,
    'character': 'fa',
    'when': {
      'affection': {
        '*': [80, 100],
      },
    },
  },
  {
    'id': 'ma_happy',
    'name': 'ma',
    'priority': 200,
    'character': 'ma',
    'when': {
      'affection': {
        '*': [80, 100],
      },
    },
  },
  {
    'id': 'side_f',
    'name': '여성 쪽 공용',
    'priority': 150,
    'when': {
      'pref': 'f',
      'flags': ['side'],
    },
  },
  {
    'id': 'all_trust',
    'name': '전원 신뢰',
    'priority': 140,
    'when': {
      'trust': {
        'fa': [50, 100],
        'fb': [50, 100],
        'ma': [50, 100],
        'mh': [50, 100],
      },
    },
  },
  {'id': 'solo', 'name': '솔로', 'default': true, 'when': {}},
];

StoryBundle _bundle({
  Object characters = _chars,
  List<Map<String, Object?>>? events,
  Object endings = _endings,
}) => StoryBundle.fromJsonStrings(
  config: jsonEncode(_config),
  characters: jsonEncode(characters),
  events: [jsonEncode(events ?? _events)],
  endings: jsonEncode(endings),
);

void main() {
  late StoryBundle b;
  late EventEngine engine;

  setUp(() {
    b = _bundle();
    engine = EventEngine(b);
  });

  GameState fresh(String pref, {int day = 1}) =>
      GameState.fresh(b.config, b.characters, seed: 1, preference: pref)
        ..day = day;

  List<String> ids(Iterable<StoryEvent> es) => [for (final e in es) e.id];

  group('필터', () {
    test('route: 선호 쪽 캐릭터의 루트만 후보(all 은 전부)', () {
      expect(ids(engine.candidates(fresh('f'), EventLayer.route)), [
        'fa_r',
        'fb_r',
      ]);
      expect(ids(engine.candidates(fresh('m'), EventLayer.route)), ['ma_r']);
      expect(ids(engine.candidates(fresh('all'), EventLayer.route)), [
        'fa_r',
        'fb_r',
        'ma_r',
      ]);
    });

    test('moment: 선호 밖 캐릭터의 전화는 후보가 아니다', () {
      expect(
        ids(engine.candidates(fresh('f'), EventLayer.daily)),
        isNot(contains('ma_call')),
      );
      expect(
        ids(engine.candidates(fresh('m'), EventLayer.daily)),
        contains('ma_call'),
      );
    });

    test('pref 이벤트: 선호가 같을 때만, all 세이브는 f 버전만', () {
      expect(ids(engine.planDay(fresh('f')).where(_isMain)), ['m1f']);
      expect(ids(engine.planDay(fresh('m')).where(_isMain)), ['m1m']);
      expect(ids(engine.planDay(fresh('all')).where(_isMain)), ['m1f']);
      // 공용 main 은 어느 쪽이든 나온다.
      for (final p in Preference.values) {
        expect(ids(engine.planDay(fresh(p, day: 2)).where(_isMain)), [
          'm2',
        ], reason: p);
      }
    });

    test('정적 판정 eventInPreference / endingInPreference / endingSide', () {
      final e = b.eventById;
      expect(b.eventInPreference(e['ma_r']!, 'f'), isFalse);
      expect(b.eventInPreference(e['m1m']!, 'all'), isFalse);
      expect(b.eventInPreference(e['m1f']!, 'all'), isTrue);
      expect(b.eventInPreference(e['d_direct']!, 'm'), isTrue);
      final end = {for (final x in b.endings) x.id: x};
      expect(b.endingInPreference(end['ma_happy']!, 'f'), isFalse);
      expect(b.endingInPreference(end['side_f']!, 'm'), isFalse);
      expect(b.endingSide(end['fa_happy']!), 'f');
      expect(b.endingSide(end['side_f']!), 'f');
      expect(b.endingSide(end['solo']!), isNull);
    });

    test('엔딩: 캐릭터 엔딩은 성별로, 공용은 when.pref 로 거른다', () {
      final r = EndingResolver(b.endings, characters: b.characters);
      // 선호 밖 ma 의 호감을 직접 올려도 f 회차에서는 ma 엔딩이 나오지 않는다.
      final f = fresh('f', day: 101);
      f.rel('ma').affection = 95;
      f.rel('fa').affection = 85;
      expect(r.resolve(f).id, 'fa_happy');
      final all = fresh('all', day: 101);
      all.rel('ma').affection = 95;
      all.rel('fa').affection = 85;
      expect(r.resolve(all).id, 'ma_happy', reason: 'all 은 호감 높은 쪽');
      // when.pref: f 쪽 공용 엔딩은 f·all 에서만.
      for (final (p, want) in [
        ('f', 'side_f'),
        ('all', 'side_f'),
        ('m', 'solo'),
      ]) {
        final s = fresh(p, day: 101)..flags.add('side');
        expect(r.resolve(s).id, want, reason: p);
      }
      // 예전 호출부(characters 없음)는 거르지 않는다.
      expect(EndingResolver(b.endings).resolve(f).id, 'ma_happy');
    });

    test('엔딩: 공용 엔딩 조건이 선호 밖 캐릭터를 가리키면 그 조건은 건너뛴다', () {
      final r = EndingResolver(b.endings, characters: b.characters);
      final f = fresh('f', day: 101);
      f.rel('fa').trust = 60;
      f.rel('fb').trust = 60;
      expect(r.resolve(f).id, 'all_trust', reason: 'ma·mh 는 f 회차에 없다');
      final all = fresh('all', day: 101);
      all.rel('fa').trust = 60;
      all.rel('fb').trust = 60;
      expect(r.resolve(all).id, 'solo', reason: 'all 은 네 명 모두 필요');
    });

    test('trigger·require·anyAffection 도 선호 밖 캐릭터를 세지 않는다', () {
      final f = fresh('f');
      // d_need_ma: ma 호감 30+ 조건은 f 회차에서 빠진다(없는 사람은 조건에서 제외).
      expect(
        ids(engine.candidates(f, EventLayer.daily)),
        contains('d_need_ma'),
      );
      final m = fresh('m');
      expect(
        ids(engine.candidates(m, EventLayer.daily)),
        isNot(contains('d_need_ma')),
      );
      // d_lock_ma: ma 호감 20 잠금도 f 회차에서는 풀린다.
      final lock = b.eventById['d_lock_ma']!;
      expect(engine.choicesFor(f, lock).single.locked, isFalse);
      expect(engine.choicesFor(m, lock).single.locked, isTrue);
      // anyAffection: 선호 밖 ma 는 세지 않는다.
      f.rel('fa').affection = 20;
      f.rel('ma').affection = 20;
      expect(
        ids(engine.candidates(f, EventLayer.daily)),
        isNot(contains('d_any')),
      );
      f.rel('fb').affection = 20;
      expect(ids(engine.candidates(f, EventLayer.daily)), contains('d_any'));
    });

    test('@top: 선호 밖 캐릭터는 1위가 되지 않는다', () {
      final f = fresh('f', day: 30);
      f.rel('ma').affection = 50;
      f.rel('fb').affection = 10;
      expect(engine.topCharacter(f), 'fb');
      final ev = b.eventById['d_top']!;
      final out = engine.applyChoice(
        f,
        ev,
        ev.choices.single,
        forcedCritical: false,
      );
      expect(out.delta.affection, {'fb': 4});
      expect(f.affectionOf('ma'), 50);
      // 선호 쪽에 호감이 아무도 없으면 @top 은 버려진다.
      final g = fresh('f', day: 30)..rel('ma').affection = 50;
      final none = engine.applyChoice(
        g,
        ev,
        ev.choices.single,
        forcedCritical: false,
      );
      expect(none.delta.affection, isEmpty);
    });

    test('서사 신호·홈 요약: 선호 밖 캐릭터는 대상이 아니다', () async {
      SharedPreferences.setMockInitialValues({});
      final real = testBundle();
      final c = GameController(bundle: real, save: SaveService());
      await c.init();
      await c.newGame(preference: Preference.female, seed: 21);
      final s = c.state!;
      // 선호 밖 하늘(m)의 호감을 직접 올리고 오늘 변화에도 넣어 본다.
      s.rel('haneul').affection = 60;
      s.rel('seoyeon').affection = 30;
      c.dayDelta.affection['haneul'] = 40;
      c.dayDelta.affection['seoyeon'] = 25;
      expect(c.roster.map((x) => x.id), [
        'seoyeon',
        'jiwoo',
        'yeeun',
        'daeun',
        'sohee',
        'yuna',
      ]);
      expect(c.topCharacterId, 'seoyeon');
      expect(c.todayShifts.map((x) => x.id), isNot(contains('haneul')));
      expect(c.todayShifts.map((x) => x.id), contains('seoyeon'));
      s.overnightShifts['haneul'] = '하늘이 조용하다';
      expect(c.overnightShifts, isEmpty);
      final sum = SaveSummary.fromState(
        s,
        real.config,
        real.characters,
        signals: real.signals,
      );
      expect(sum.preference, Preference.female);
      expect(sum.topCharacterId, 'seoyeon');
      expect(sum.affection.keys, [
        'seoyeon',
        'jiwoo',
        'yeeun',
        'daeun',
        'sohee',
        'yuna',
      ]);
      expect(sum.overnight, isEmpty);
      await c.endDay();
      expect(s.signalPins.keys, isNot(contains('haneul')));
      expect(s.signalPins.keys, contains('seoyeon'));
    });
  });

  group('세이브 호환', () {
    test('preference 필드가 없는 예전 세이브는 all 로 읽는다', () {
      final j = fresh('f').toJson()..remove('preference');
      expect(GameState.fromJson(j).preference, Preference.all);
      final odd = fresh('f').toJson()..['preference'] = 'x';
      expect(GameState.fromJson(odd).preference, Preference.all);
      final round = GameState.fromJson(
        jsonDecode(jsonEncode(fresh('m').toJson())) as Map<String, dynamic>,
      );
      expect(round.preference, Preference.male);
    });

    test('예전 세이브를 이어하면 all 회차로 그대로 돈다(전원 등장)', () async {
      final real = testBundle();
      final legacy = GameState.fresh(real.config, real.characters, seed: 3)
        ..day = 5;
      final j = legacy.toJson()..remove('preference');
      SharedPreferences.setMockInitialValues({'mossol_save_v1': jsonEncode(j)});
      final c = GameController(bundle: real, save: SaveService());
      await c.init();
      expect(c.saveSummary!.preference, Preference.all);
      expect(await c.continueGame(), isTrue);
      expect(c.state!.preference, Preference.all);
      expect(c.roster.length, real.characters.length);
    });

    test('newGame 기본값은 all, 다음 회차는 선호를 잇는다', () async {
      SharedPreferences.setMockInitialValues({});
      final c = GameController(bundle: testBundle(), save: SaveService());
      await c.init();
      await c.newGame(seed: 1);
      expect(c.state!.preference, Preference.all);
      await c.newGame(preference: Preference.male, seed: 2);
      expect(c.state!.preference, Preference.male);
      await c.nextRun();
      expect(c.state!.preference, Preference.male);
      expect(c.state!.run, 2);
    });
  });

  group('main 같은 날 쪽별 버전', () {
    List<Map<String, Object?>> mains(List<Map<String, Object?>> ms) => [
      ...ms,
      _ev('fa_r', 'route', character: 'fa'),
    ];

    Matcher clash(String fragment) => throwsA(
      isA<StateError>().having((e) => e.message, 'message', contains(fragment)),
    );

    test('f 와 m 각 1개는 공존한다', () {
      expect(
        () => _bundle(
          events: mains([
            _ev('a', 'main', day: 3, trigger: {'pref': 'f'}),
            _ev('b', 'main', day: 3, trigger: {'pref': 'm'}),
          ]),
        ),
        returnsNormally,
      );
    });

    test('공용 + 쪽별, 같은 쪽 둘, 공용 둘은 오류', () {
      for (final pair in [
        [null, 'f'],
        ['m', null],
        ['f', 'f'],
        [null, null],
      ]) {
        expect(
          () => _bundle(
            events: mains([
              _ev('a', 'main', day: 3, trigger: {'pref': ?pair[0]}),
              _ev('b', 'main', day: 3, trigger: {'pref': ?pair[1]}),
            ]),
          ),
          clash('main 날짜 중복: 3일'),
          reason: '$pair',
        );
      }
    });

    test('pref 값은 f|m 만', () {
      expect(
        () => _bundle(
          events: mains([
            _ev('a', 'main', day: 3, trigger: {'pref': 'all'}),
          ]),
        ),
        clash('pref 는 f|m'),
      );
    });

    test('한쪽 버전만 있는 main 날은 lint 경고', () {
      final one = _bundle(
        events: mains([
          _ev('a', 'main', day: 3, trigger: {'pref': 'f'}),
        ]),
      );
      expect(one.lint(), contains('main 3일: 남성 캐릭터 쪽 버전 없음'));
    });
  });

  group('캐스트 검증', () {
    Matcher err(String fragment) => throwsA(
      isA<StateError>().having((e) => e.message, 'message', contains(fragment)),
    );

    List<Map<String, Object?>> with1(Map<String, Object?> c) => [
      for (final x in _chars) Map.of(x),
      c,
    ];

    test('gender·role 필수, 성별마다 역할당 1명, 히든은 트레이너', () {
      expect(
        () => _bundle(
          characters: with1({'id': 'x', 'name': 'x', 'role': 'classmate'}),
        ),
        err('gender'),
      );
      expect(
        () =>
            _bundle(characters: with1({'id': 'x', 'name': 'x', 'gender': 'f'})),
        err('role'),
      );
      expect(
        () => _bundle(
          characters: with1({
            'id': 'x',
            'name': 'x',
            'gender': 'f',
            'role': 'senior',
          }),
        ),
        err('같은 성별·역할이 둘: f/senior'),
      );
      expect(
        () => _bundle(
          characters: with1({
            'id': 'x',
            'name': 'x',
            'gender': 'f',
            'role': 'trainer',
          }),
        ),
        err('히든'),
      );
      expect(
        () => _bundle(
          characters: with1({
            'id': 'x',
            'name': 'x',
            'gender': 'f',
            'role': 'classmate',
            'hidden': true,
          }),
        ),
        err('히든'),
      );
    });

    test('빈 역할은 오류가 아니라 lint 경고', () {
      expect(b.castGaps, {
        'f': ['parttime', 'blinddate', 'classmate', 'trainer'],
        'm': ['parttime', 'blinddate', 'online', 'classmate'],
      });
      final casts = b.lint().where(
        (w) => w.startsWith(StoryBundle.castLintPrefix),
      );
      expect(casts, hasLength(2));
      expect(casts.first, contains('여성 캐릭터 쪽에 역할 없음'));
    });

    test('실제 데이터: 6+6, 역할 짝이 겹치지 않는다', () {
      final real = testBundle();
      expect(real.charactersFor('f').map((c) => c.id), [
        'seoyeon',
        'jiwoo',
        'yeeun',
        'daeun',
        'sohee',
        'yuna',
      ]);
      expect(real.charactersFor('m').map((c) => c.id), [
        'haneul',
        'minjae',
        'doyun',
        'jeongwoo',
        'seunghyun',
        'geonwoo',
      ]);
      // 성별마다 역할 6개가 한 명씩, 히든은 트레이너 하나씩.
      for (final g in Preference.genders) {
        final side = real.charactersFor(g);
        expect(
          side.map((c) => c.role).toSet(),
          CastRole.values.toSet(),
          reason: g,
        );
        expect(side.where((c) => c.hidden).map((c) => c.role), [
          CastRole.trainer,
        ], reason: g);
      }
      for (final c in real.characters) {
        expect(c.title, isNotEmpty, reason: '${c.id} 소개 호칭');
      }
    });
  });

  group('선호 밖 캐릭터 id 효과', () {
    test('공용 이벤트의 "ma": 3 은 f 회차에서 적용하지 않는다', () {
      final ev = b.eventById['d_direct']!;
      final f = fresh('f', day: 30);
      final out = engine.applyChoice(
        f,
        ev,
        ev.choices.single,
        forcedCritical: false,
      );
      expect(out.delta.affection, {'fa': 3});
      expect(out.delta.trust, isEmpty);
      expect(f.affectionOf('ma'), 0);
      expect(f.trustOf('ma'), 0);

      final m = fresh('m', day: 30);
      final outM = engine.applyChoice(
        m,
        ev,
        ev.choices.single,
        forcedCritical: false,
      );
      expect(outM.delta.affection, {'ma': 3});
      expect(outM.delta.trust, {'ma': 2});

      final all = fresh('all', day: 30);
      final outA = engine.applyChoice(
        all,
        ev,
        ev.choices.single,
        forcedCritical: false,
      );
      expect(outA.delta.affection, {'fa': 3, 'ma': 3});
    });

    test('실제 데이터: m01 의 "haneul": 2 는 여성 쪽 회차에서 버려진다', () {
      final real = testBundle();
      final e = EventEngine(real);
      final s = GameState.fresh(
        real.config,
        real.characters,
        seed: 1,
        preference: 'f',
      );
      final m01 = real.eventById['m01']!;
      final i = m01.choices.indexWhere(
        (c) => c.effects.affection.containsKey('haneul'),
      );
      expect(i, isNonNegative);
      e.applyChoice(s, m01, m01.choices[i], forcedCritical: false);
      expect(s.affectionOf('haneul'), 0);
    });
  });

  group('캐스트 소개(새 게임 2단계)', () {
    Future<GameController> ctl() async {
      SharedPreferences.setMockInitialValues({});
      final c = GameController(bundle: testBundle(), save: SaveService());
      await c.init();
      return c;
    }

    Finder cardOf(String id) => find.byKey(Key('cast-$id'));

    testWidgets('기본 쪽: 다섯 명 카드(이름 · 역할 · 매력 · 첫 메시지) + 히든 ??? 한 칸', (
      tester,
    ) async {
      final bundle = testBundle();
      tester.view.physicalSize = const Size(400, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? picked;
      await tester.pumpWidget(
        wrapApp(
          PreferenceScreen(
            bundle: bundle,
            side: Preference.female,
            onPicked: (p) => picked = p,
          ),
        ),
      );
      expect(findText(PreferenceScreen.title), findsOneWidget);
      expect(find.byType(CastIntroCard), findsNWidgets(6));
      final side = bundle.characters.where((c) => c.gender == 'f');
      for (final ch in side) {
        if (ch.hidden) {
          // 히든은 이름 · 역할 · 매력 · 첫 메시지를 전부 숨긴다(스포일러).
          expect(findText(ch.name), findsNothing);
          expect(findText(ch.tagline), findsNothing);
          continue;
        }
        final card = cardOf(ch.id);
        expect(card, findsOneWidget, reason: ch.id);
        expect(
          find.descendant(of: card, matching: findText(ch.name)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: findText(ch.displayTitle)),
          findsOneWidget,
        );
        expect(ch.tagline, isNotEmpty, reason: '${ch.id} tagline');
        expect(
          find.descendant(of: card, matching: findText(ch.tagline)),
          findsOneWidget,
        );
        final line = bundle.firstLineOf(ch.id);
        expect(line, isNotNull, reason: '${ch.id} 첫 메시지');
        expect(
          find.descendant(of: card, matching: findText(line!)),
          findsOneWidget,
        );
      }
      expect(findText('???'), findsOneWidget);
      expect(findText(CastIntroCard.mysteryNote), findsOneWidget);
      // 남성 쪽은 보이지 않는다.
      expect(cardOf('jeongwoo'), findsNothing);
      await tester.tap(findText(PreferenceScreen.startLabel));
      expect(picked, Preference.female);
    });

    testWidgets('반대쪽 캐릭터 만나기 → 같은 화면에서 남성 쪽, 링크는 원래대로', (tester) async {
      String? picked;
      await tester.pumpWidget(
        wrapApp(
          PreferenceScreen(
            bundle: testBundle(),
            side: Preference.female,
            onPicked: (p) => picked = p,
          ),
        ),
      );
      expect(find.byKey(const Key('cast-side-f')), findsOneWidget);
      expect(findText(PreferenceScreen.restoreLabel), findsNothing);
      await tester.tap(findText(PreferenceScreen.flipLabel));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cast-side-m')), findsOneWidget);
      expect(find.byKey(const Key('cast-side-f')), findsNothing);
      expect(cardOf('jeongwoo'), findsOneWidget);
      expect(findText('나한테만 메신저가 서툰 회장님'), findsOneWidget);
      expect(findText(PreferenceScreen.flipLabel), findsNothing);
      expect(findText(PreferenceScreen.restoreLabel), findsOneWidget);
      // 보고 있는 쪽으로 시작한다.
      await tester.tap(findText(PreferenceScreen.startLabel));
      expect(picked, Preference.male);

      await tester.tap(findText(PreferenceScreen.restoreLabel));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cast-side-f')), findsOneWidget);
      expect(findText(PreferenceScreen.flipLabel), findsOneWidget);
      await tester.tap(findText(PreferenceScreen.startLabel));
      expect(picked, Preference.female);
    });

    testWidgets('비교 모드: 기본 선택 없음 · 시작 꺼짐 → 한쪽을 고르면 켜지고, 세그먼트로 오간다', (
      tester,
    ) async {
      final bundle = testBundle();
      String? picked;
      await tester.pumpWidget(
        wrapApp(PreferenceScreen(bundle: bundle, onPicked: (p) => picked = p)),
      );
      FilledButton start() =>
          tester.widget<FilledButton>(find.byKey(const Key('cast-start')));
      expect(start().onPressed, isNull, reason: '기본 선택 없음');
      expect(findText(PreferenceScreen.compareHint), findsOneWidget);
      // 비교 모드에는 반대쪽 링크가 없다(세그먼트가 그 역할).
      expect(findText(PreferenceScreen.flipLabel), findsNothing);
      // 아직 안 골랐으면 두 쪽 요약 카드. 아바타 여섯씩(히든은 실루엣), 소개는 쪽마다 다르다.
      expect(find.byType(PreferenceCard), findsNWidgets(2));
      expect(find.byType(CastIntroCard), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is CharacterAvatar && w.mystery),
        findsNWidgets(2),
      );
      final introF = PreferenceScreen.introOf(bundle, 'f');
      final introM = PreferenceScreen.introOf(bundle, 'm');
      expect(introF, isNot(introM));
      expect(findText(introF), findsOneWidget);
      await tester.tap(find.byKey(const Key('cast-start')));
      expect(picked, isNull, reason: '꺼진 시작은 눌리지 않는다');

      // 요약 카드를 누르면 그 쪽을 펼친다(시작은 아직 아님).
      await tester.tap(find.byKey(const Key('preference-m')));
      await tester.pumpAndSettle();
      expect(picked, isNull);
      expect(find.byKey(const Key('cast-side-m')), findsOneWidget);
      expect(start().onPressed, isNotNull);

      // 세그먼트로 반대쪽 비교.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('cast-segment')),
          matching: findText('여성 캐릭터'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cast-side-f')), findsOneWidget);
      await tester.tap(findText(PreferenceScreen.startLabel));
      expect(picked, Preference.female);
    });

    testWidgets('한쪽 캐릭터가 없으면 그 쪽은 준비 중(탭 안 됨), 반대쪽 링크도 없다', (tester) async {
      final only = _bundle(
        characters: [_chars[0], _chars[1]],
        events: [_ev('fa_r', 'route', character: 'fa')],
        endings: [_endings.last],
      );
      String? picked;
      await tester.pumpWidget(
        wrapApp(PreferenceScreen(bundle: only, onPicked: (p) => picked = p)),
      );
      expect(findText('준비 중'), findsOneWidget);
      await tester.tap(findText('남성 캐릭터').last);
      await tester.pumpAndSettle();
      expect(find.byType(CastIntroCard), findsNothing);
      await tester.tap(find.byKey(const Key('preference-f')));
      await tester.pumpAndSettle();
      await tester.tap(findText(PreferenceScreen.startLabel));
      expect(picked, Preference.female);

      await tester.pumpWidget(
        wrapApp(
          PreferenceScreen(
            key: const Key('default-f'),
            bundle: only,
            side: Preference.female,
            onPicked: (p) => picked = p,
          ),
        ),
      );
      expect(findText(PreferenceScreen.flipLabel), findsNothing);
      // 매력 문구가 없는 데이터에서도 카드는 이름 · 역할로 그린다.
      expect(find.byType(CastIntroCard), findsNWidgets(2));
    });

    testWidgets('홈의 새 게임 → 나는? 남자 → 여성 쪽 소개 → 시작하기 → 확인 없이 그 선호로 시작', (
      tester,
    ) async {
      final c = await ctl();
      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      await tester.tap(findText('새 게임'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gender-m')));
      await tester.pumpAndSettle();
      await skipNameStep(tester);
      expect(find.byType(PreferenceScreen), findsOneWidget);
      expect(find.byKey(const Key('cast-side-f')), findsOneWidget);
      await tester.tap(findText(PreferenceScreen.startLabel));
      await tester.pumpAndSettle();
      expect(find.byType(PreferenceScreen), findsNothing);
      expect(c.phase, Phase.action);
      expect(c.state!.preference, Preference.female);
      expect(c.playerGender, PlayerGender.male);
      expect(findText('오늘의 운'), findsOneWidget, reason: '확인 없이 바로 첫날');
    });
  });

  group('홈 · 앨범 표시', () {
    Future<GameController> started(String pref) async {
      SharedPreferences.setMockInitialValues({});
      final c = GameController(bundle: testBundle(), save: SaveService());
      await c.init();
      await c.newGame(preference: pref, seed: 5);
      c.state!.rel('haneul').affection = 40;
      c.state!.rel('seoyeon').affection = 12;
      await c.save.save(c.state!);
      c.goHome();
      return c;
    }

    testWidgets('이어하기 카드에 "1회차 · 여성 캐릭터", 사람들 줄은 선호 쪽만', (tester) async {
      final c = await started(Preference.female);
      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      expect(findText('1회차 · 1장'), findsOneWidget);
      expect(findText(' · 여성 캐릭터'), findsOneWidget);
      final strip = find.byType(CastStrip);
      for (final name in ['서연', '지우', '예은']) {
        expect(
          find.descendant(of: strip, matching: findText(name)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: strip, matching: findText('하늘')),
        findsNothing,
      );
      expect(findTextContaining('하늘 ♥'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('320×568 · 1.3배 · 다크: 선호 꼬리가 붙어도 회차 줄이 넘치지 않는다', (
      tester,
    ) async {
      useSmallScreenLargeFont(tester);
      useDarkMode(tester);
      final c = await started(Preference.male);
      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(findText('1회차 · 1장'), findsOneWidget);
      expect(find.byKey(const Key('continue-preference')), findsOneWidget);
    });

    testWidgets('예전 세이브(all)는 선호 표기가 없다', (tester) async {
      final c = await started(Preference.all);
      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      expect(find.byKey(const Key('continue-preference')), findsNothing);
      expect(findTextContaining('하늘 ♥40'), findsOneWidget);
    });

    testWidgets('앨범 엔딩 필터: 여성 / 남성 / 공용, 진행도는 전체 기준', (tester) async {
      final c = await started(Preference.female);
      final bundle = c.bundle;
      tester.view.physicalSize = const Size(400, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrapApp(AlbumScreen(c: c)));
      await tester.tap(findText('엔딩'));
      await tester.pumpAndSettle();
      final total = '0 / ${bundle.endings.length}';
      int cards() => find.byIcon(Icons.lock_outline).evaluate().length;
      expect(findText(total), findsOneWidget);
      expect(cards(), bundle.endings.length);
      final bySide = <String?, int>{};
      for (final e in bundle.endings) {
        final side = bundle.endingSide(e);
        bySide[side] = (bySide[side] ?? 0) + 1;
      }
      for (final (label, side) in [('여성', 'f'), ('남성', 'm'), ('공용', null)]) {
        await tester.tap(findText(label));
        await tester.pumpAndSettle();
        expect(cards(), bySide[side] ?? 0, reason: label);
        expect(findText(total), findsOneWidget, reason: '진행도는 그대로');
      }
      expect(bySide['f'], 6 * 4, reason: '여성 6명 × 캐릭터 엔딩 4종(천생연분 포함)');
      expect(bySide['m'], 6 * 4, reason: '남성 6명 × 캐릭터 엔딩 4종(천생연분 포함)');
      expect(bySide[null], 12, reason: '공용 엔딩');
    });
  });
}

bool _isMain(StoryEvent e) => e.layer == EventLayer.main;
