// 출시 전 단위 테스트 보강: 세이브·메타의 예전 형식 / 손상 / 부분 JSON.
//
// 세이브(`mossol_save_v1`)와 메타(`mossol_meta_v1`)는 앱 업데이트를 넘어 살아남는다.
// 필드가 없거나 형식이 틀린 JSON 이 들어와도 앱이 죽지 않아야 하고, 읽을 수 있는
// 것은 기본값으로 읽혀 그대로 이어서 플레이할 수 있어야 한다.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/analytics/analytics.dart';
import 'package:mossol/engine/effects.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/meta_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget/helpers.dart';

const _saveKey = 'mossol_save_v1';
const _metaKey = 'mossol_meta_v1';

/// 선호·MBTI·모먼트·서사 신호·하루 정산 필드가 생기기 전의 세이브 모양.
Map<String, dynamic> legacySave({int day = 12, int hearts = 3, int? lastHeartMs}) {
  final b = testBundle();
  final s = GameState.fresh(b.config, b.characters, seed: 42, nowMs: 0)
    ..day = day
    ..hearts = hearts;
  s.rel(b.characters.first.id).affection = 30;
  final j = s.toJson();
  for (final k in const [
    'preference',
    'mbti',
    'lastMomentDay',
    'signalHistory',
    'signalPins',
    'overnightShifts',
    'dayDelta',
    'rouletteDay',
    'combo',
    'lastCliffhanger',
  ]) {
    j.remove(k);
  }
  if (lastHeartMs == null) {
    j.remove('lastHeartMs');
  } else {
    j['lastHeartMs'] = lastHeartMs;
  }
  return j;
}

void main() {
  late int now;
  GameController controller({Analytics? analytics}) => GameController(
    bundle: testBundle(),
    save: SaveService(),
    clock: () => now,
    analytics: analytics ?? Analytics(backend: RecordingAnalyticsBackend()),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 9, 18, 10).millisecondsSinceEpoch;
  });

  // -------------------------------------------------------------------------
  group('GameState.fromJson: 예전 세이브', () {
    test('선호·MBTI·모먼트·신호·정산 필드가 없으면 기본값(all · null · 0 · 빈 값)', () {
      final s = GameState.fromJson(legacySave());
      expect(s.preference, Preference.all);
      expect(s.mbti, isNull);
      expect(s.lastMomentDay, 0);
      expect(s.rouletteDay, 0);
      expect(s.combo, 0);
      expect(s.lastCliffhanger, isNull);
      expect(s.signalHistory, isEmpty);
      expect(s.signalPins, isEmpty);
      expect(s.overnightShifts, isEmpty);
      expect(s.dayDelta, isEmpty);
      expect(s.day, 12);
      // 다시 저장하면 새 필드가 채워진다(왕복 안정).
      final again = GameState.fromJson(s.toJson());
      expect(again.toJson(), s.toJson());
    });

    test('틀린 선호 · MBTI 값은 all · null, 소문자·공백 MBTI 는 정규화', () {
      Map<String, dynamic> j(Object? pref, Object? mbti) =>
          legacySave()..addAll({'preference': pref, 'mbti': mbti});
      expect(GameState.fromJson(j('x', 'ABCD')).preference, Preference.all);
      expect(GameState.fromJson(j('x', 'ABCD')).mbti, isNull);
      expect(GameState.fromJson(j(3, 7)).mbti, isNull);
      expect(GameState.fromJson(j('m', ' infp ')).mbti, 'INFP');
      expect(GameState.fromJson(j('m', 'INFPX')).mbti, isNull);
      expect(GameState.fromJson(j('f', 'ENTJ')).preference, Preference.female);
      expect(GameState.fromJson(j(null, null)).preference, Preference.all);
    });

    test('숫자 필드가 double 로 저장돼 있어도 정수로 읽는다', () {
      final j = legacySave()
        ..['day'] = 7.0
        ..['hearts'] = 2.0
        ..['stats'] = {'charm': 40.0};
      final s = GameState.fromJson(j);
      expect(s.day, 7);
      expect(s.hearts, 2);
      expect(s.stat(Stat.charm), 40);
    });

    test('예전 세이브 상태로 하루를 진행해도 예외가 없다(효과 · 마감 · 계획)', () {
      final b = testBundle();
      final engine = EventEngine(b);
      final s = GameState.fromJson(legacySave());
      final plan = engine.planDay(s);
      expect(plan, isNotEmpty);
      for (final ev in plan) {
        final views = engine.choicesFor(s, ev).where((v) => !v.locked);
        final v = views.isEmpty ? engine.choicesFor(s, ev).first : views.first;
        final c = ev.choices[v.index];
        engine.applyChoice(
          s,
          ev,
          c,
          forcedSuccess: c.minigame == null ? null : true,
        );
      }
      engine.endDay(s);
      expect(s.day, 13);
    });

    // 세이브는 늘 toJson 전체를 쓰므로 실제로는 stats·album 이 빠질 일이 없다.
    // 다만 fromJson 이 이 필드가 없을 때 `const {}` / `const []`(수정 불가)를 넣어 두기 때문에
    // 손상·수동 편집된 세이브를 "읽는" 데는 성공하고 첫 선택에서 UnsupportedError 로 죽는다.
    test(
      '부분 세이브(stats · album · endings 없음)도 읽은 뒤 효과 적용이 된다',
      () {
        final s = GameState.fromJson({'day': 5, 'seed': 9});
        applyEffects(
          s,
          Effects.fromJson({
            'stats': {'charm': 1},
            'album': '첫 사진',
          }),
        );
        expect(s.stat(Stat.charm), 1);
        expect(s.album, ['첫 사진']);
        s.endings.add('x');
      },
    );

    test('dayDelta 안의 null 값·빈 맵은 빈 정산으로 읽힌다', () {
      final s = GameState.fromJson(
        legacySave()..['dayDelta'] = {'stats': null, 'affection': {}},
      );
      expect(s.dayDelta['stats'], isEmpty);
      expect(s.dayDelta['affection'], isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('SaveService: 형식이 틀린 세이브', () {
    test('읽다 실패하면 null + 키 삭제 (타입 불일치 · 필수 필드 누락)', () async {
      final bad = <String, Object>{
        'seed 없음': {'day': 1},
        'day 없음': {'seed': 1},
        'stats 가 리스트': {'day': 1, 'seed': 1, 'stats': [1, 2]},
        'stats 값이 문자열': {
          'day': 1,
          'seed': 1,
          'stats': {'charm': '10'},
        },
        'relations 값이 숫자': {
          'day': 1,
          'seed': 1,
          'relations': {'seoyeon': 3},
        },
        'flags 가 문자열': {'day': 1, 'seed': 1, 'flags': 'a,b'},
        'signalHistory 값이 숫자': {
          'day': 1,
          'seed': 1,
          'signalHistory': {'a:1': 3},
        },
        'JSON null': 'null-literal',
      };
      for (final e in bad.entries) {
        final raw = e.value == 'null-literal' ? 'null' : jsonEncode(e.value);
        SharedPreferences.setMockInitialValues({_saveKey: raw});
        final svc = SaveService();
        expect(await svc.load(), isNull, reason: e.key);
        expect(await svc.exists(), isFalse, reason: e.key);
      }
    });

    test('모르는 추가 필드는 무시하고 읽는다(다음 버전 세이브를 이전 버전이 열 때)', () async {
      SharedPreferences.setMockInitialValues({
        _saveKey: jsonEncode(legacySave()..['futureField'] = {'x': 1}),
      });
      final s = await SaveService().load();
      expect(s, isNotNull);
      expect(s!.day, 12);
    });
  });

  // -------------------------------------------------------------------------
  group('컨트롤러: 예전 · 손상 세이브', () {
    test('예전 세이브(all) 를 이어하면 모든 캐릭터가 등장하고 하루가 돈다', () async {
      SharedPreferences.setMockInitialValues({
        _saveKey: jsonEncode(legacySave(lastHeartMs: now)),
      });
      final c = controller();
      await c.init();
      expect(c.hasSave, isTrue);
      expect(c.saveSummary, isNotNull);
      expect(c.saveSummary!.preference, Preference.all);
      expect(await c.continueGame(), isTrue);
      expect(c.preference, Preference.all);
      expect(c.runMbti, isNull);
      expect(c.roster.length, c.bundle.characters.length);
      expect(await c.startDay(c.config.actions.first), isTrue);
      expect(c.phase, Phase.event);
    });

    test('lastHeartMs 가 없는 예전 세이브는 이어하면 하트가 가득 찬다', () async {
      SharedPreferences.setMockInitialValues({
        _saveKey: jsonEncode(legacySave(hearts: 1)),
      });
      final c = controller();
      await c.init();
      expect(c.saveSummary!.hearts, c.config.maxHearts);
      await c.continueGame();
      expect(c.hearts, c.config.maxHearts);
      expect(c.state!.lastHeartMs, now, reason: '가득 차면 타이머를 지금으로');
    });

    test('손상된 세이브: init 이 죽지 않고, 이어하기는 false, 새 게임은 된다', () async {
      SharedPreferences.setMockInitialValues({_saveKey: '{broken'});
      final c = controller();
      await c.init();
      expect(c.saveSummary, isNull);
      expect(await c.continueGame(), isFalse);
      await c.newGame(seed: 3, preference: Preference.female);
      expect(c.state, isNotNull);
      expect(c.hasSave, isTrue);
      expect(await SaveService().exists(), isTrue);
    });

    test(
      '손상된 세이브: init 뒤 hasSave 는 false (홈이 "이어하기" 를 띄우지 않는다)',
      () async {
        SharedPreferences.setMockInitialValues({_saveKey: '{broken'});
        final c = controller();
        await c.init();
        expect(await SaveService().exists(), isFalse, reason: 'load 가 키를 지웠다');
        expect(c.hasSave, isFalse);
      },
    );

    test('세이브 없이 출석 → 손상 세이브 복구 뒤에도 pending 하트가 새 게임에 얹힌다', () async {
      SharedPreferences.setMockInitialValues({_saveKey: '[]'});
      final c = controller();
      await c.init();
      final r = await c.checkInToday();
      expect(r!.first, isTrue);
      // hasSave 가 true 로 남아도 state 가 없으므로 보류함으로 간다.
      expect(c.pendingHearts, Attendance.dailyHearts);
      await c.newGame(seed: 1);
      expect(c.hearts, c.config.maxHearts + Attendance.dailyHearts);
      expect(c.pendingHearts, 0);
    });

    test('홈(복원 전)에서 시간이 지나면 요약 하트만 따라 오르고 저장하지 않는다', () async {
      final b = testBundle();
      final period = b.config.heartRegenMinutes * 60 * 1000;
      SharedPreferences.setMockInitialValues({
        _saveKey: jsonEncode(legacySave(hearts: 1, lastHeartMs: now)),
      });
      final c = controller();
      await c.init();
      expect(c.saveSummary!.hearts, 1);
      now += period * 2;
      expect(await c.refreshHearts(), 2);
      expect(c.saveSummary!.hearts, 3);
      // 파일은 그대로(1). continueGame 이 같은 시계로 다시 계산한다.
      final raw = (await SharedPreferences.getInstance()).getString(_saveKey)!;
      expect((jsonDecode(raw) as Map)['hearts'], 1);
      await c.continueGame();
      expect(c.hearts, 3);
    });
  });

  // -------------------------------------------------------------------------
  group('PlayerMeta: 형식이 틀린 필드', () {
    test('필드마다 틀린 타입은 기본값으로, 정상 필드는 살린다', () {
      final m = PlayerMeta.fromJson({
        'lastCheckInDate': 20260918,
        'streakDays': '3',
        'bestStreak': 4.0,
        'totalRuns': null,
        'pendingHearts': 2,
        'playerGender': 'x',
        'playerName': '   ',
        'nameAsked': 'true',
        'mbti': ' infp',
        'mbtiAsked': true,
        'lastEndingId': '',
      });
      expect(m.lastCheckInDate, isNull);
      expect(m.streakDays, 0);
      expect(m.bestStreak, 4);
      expect(m.totalRuns, 0);
      expect(m.pendingHearts, 2);
      expect(m.playerGender, isNull);
      expect(m.playerName, isNull);
      expect(m.nameAsked, isFalse);
      expect(m.mbti, 'INFP');
      expect(m.mbtiAsked, isTrue);
      expect(m.lastEndingId, isNull);
    });

    test('이름 앞뒤 공백은 떼고 읽는다', () {
      expect(PlayerMeta.fromJson({'playerName': ' 민지 '}).playerName, '민지');
    });

    test('MetaService: JSON 이 객체가 아니면(null · 문자열 · 배열) 초기화', () async {
      for (final raw in ['null', '"meta"', '[1]', '12', '{']) {
        SharedPreferences.setMockInitialValues({_metaKey: raw});
        final m = await MetaService().load();
        expect(m.toJson(), PlayerMeta().toJson(), reason: raw);
        final p = await SharedPreferences.getInstance();
        expect(p.containsKey(_metaKey), isFalse, reason: raw);
      }
    });

    test('모든 필드 왕복', () async {
      final m = PlayerMeta(
        lastCheckInDate: '2026-09-18',
        streakDays: 6,
        bestStreak: 9,
        totalCheckIns: 30,
        totalRuns: 4,
        bestDayReached: 100,
        firstLaunchMs: 123,
        pendingHearts: 2,
        rerollTickets: 3,
        playerGender: PlayerGender.none,
        playerName: 'Paul',
        nameAsked: true,
        mbti: 'ENTP',
        mbtiAsked: true,
        lastEndingId: 'forever_solo',
      );
      await MetaService().save(m);
      final r = await MetaService().load();
      expect(r.toJson(), m.toJson());
    });

    test('날짜가 깨진 lastCheckInDate 는 끊긴 연속으로 보고 1일째 출석을 준다', () {
      for (final bad in ['2026-13-01', '2026-02-00', 'yesterday', '2026-9']) {
        final m = PlayerMeta(lastCheckInDate: bad, streakDays: 6);
        final now = DateTime(2026, 9, 18, 9);
        expect(Attendance.liveStreak(m, now), 0, reason: bad);
        final r = Attendance.checkIn(m, now);
        expect(r.first, isTrue, reason: bad);
        expect(r.streak, 1, reason: bad);
        expect(m.lastCheckInDate, '2026-09-18');
      }
    });
  });
}
