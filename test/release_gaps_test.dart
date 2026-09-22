// 출시 전 단위 테스트 보강: 기존 스위트가 덜 짚던 경계값과 정책 로직.
//
// - 하트 회복 · 자정 넘김 · 출석 경계(주입한 시계)
// - 1 · 3 · 99 · 100일 경계(장 · 완주 · 광고 최소일 · 측정 마일스톤)
// - 이름 입력 규칙 / 조사 치환의 모서리(6자 · 이모지 · 공백 · 숫자 · 영문)
// - MBTI 궁합 성질, 천생연분(destiny) 엔딩 우선순위
// - 다음 판 권하기 · 지난 판 한 줄의 모서리
// - 측정 파라미터 규칙이 실제 데이터(엔딩 id · 등급)로도 지켜지는지
// - 전면 광고 정책(최소일) · 광고 단위 표
// - 스토리 무결성: 모든 next/failNext 대상이 있고, 선호 2 × MBTI 17 로 100일 완주
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/ads/ad_manager.dart';
import 'package:mossol/analytics/analytics.dart';
import 'package:mossol/engine/ending_resolver.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/mbti.dart';
import 'package:mossol/engine/meta_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/player_name.dart';
import 'package:mossol/engine/retention.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/engine/text_template.dart';
import 'package:mossol/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget/helpers.dart';

void main() {
  late StoryBundle real;
  late EventEngine engine;
  late EndingResolver resolver;

  setUpAll(() {
    real = testBundle();
    engine = EventEngine(real);
    resolver = EndingResolver(real.endings, characters: real.characters);
  });

  late int now;
  late RecordingAnalyticsBackend rec;
  GameController controller() => GameController(
    bundle: real,
    save: SaveService(),
    clock: () => now,
    analytics: Analytics(backend: rec),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 9, 18, 10).millisecondsSinceEpoch;
    rec = RecordingAnalyticsBackend();
  });

  // -------------------------------------------------------------------------
  group('하트 회복 (주입한 시계)', () {
    int period() => engine.heartPeriodMs;

    test('여러 주기가 지나면 그만큼 차고, 남은 시간은 다음 하트로 이어진다', () {
      final s = GameState.fresh(real.config, real.characters, seed: 1, nowMs: 0)
        ..hearts = 1
        ..lastHeartMs = 1000;
      final gained = engine.regenHearts(s, nowMs: 1000 + period() * 2 + period() ~/ 2);
      expect(gained, 2);
      expect(s.hearts, 3);
      expect(s.lastHeartMs, 1000 + period() * 2, reason: '반 주기는 버리지 않는다');
      expect(
        engine.nextHeartInMs(s, nowMs: 1000 + period() * 2 + period() ~/ 2),
        period() - period() ~/ 2,
      );
    });

    test('오프라인으로 며칠이 지나도 최대치에서 멈추고 타이머는 지금으로', () {
      final s = GameState.fresh(real.config, real.characters, seed: 1, nowMs: 0)
        ..hearts = 0;
      const later = 3 * 24 * 3600 * 1000;
      expect(engine.regenHearts(s, nowMs: later), real.config.maxHearts);
      expect(s.hearts, real.config.maxHearts);
      expect(s.lastHeartMs, later);
      expect(engine.nextHeartInMs(s, nowMs: later), 0);
    });

    test('출석으로 최대치를 넘긴 하트는 회복 계산이 깎지 않는다', () {
      final s = GameState.fresh(real.config, real.characters, seed: 1, nowMs: 0)
        ..hearts = real.config.maxHearts + 3;
      expect(engine.regenHearts(s, nowMs: period() * 10), 0);
      expect(s.hearts, real.config.maxHearts + 3);
    });

    test('컨트롤러: 하트를 쓰고 한 주기 뒤 refreshHearts 가 채우고 저장한다', () async {
      final c = controller();
      await c.init();
      await c.newGame(seed: 5, preference: Preference.female);
      final full = c.hearts;
      expect(await c.startDay(real.config.actions.first), isTrue);
      expect(c.hearts, full - 1);
      now += period() - 1;
      expect(await c.refreshHearts(), 0);
      expect(c.secondsToNextHeart, 1);
      now += 1;
      expect(await c.refreshHearts(), 1);
      expect(c.hearts, full);
      expect((await SaveService().load())!.hearts, full);
    });

    test('컨트롤러: 하트 0 이면 startDay 가 false, heart_empty 를 그날로 남긴다', () async {
      final c = controller();
      await c.init();
      await c.newGame(seed: 5, preference: Preference.male);
      c.state!
        ..hearts = 0
        ..lastHeartMs = now;
      expect(await c.startDay(real.config.actions.first), isFalse);
      expect(rec.paramsOf(Analytics.heartEmpty).single, {'day': 1});
    });
  });

  // -------------------------------------------------------------------------
  group('출석 경계', () {
    test('컨트롤러: 23:59:59 출석 → 00:00:01 은 새 날(연속 2), 같은 날 재출석은 보상 없음', () async {
      now = DateTime(2026, 9, 18, 23, 59, 59).millisecondsSinceEpoch;
      final c = controller();
      await c.init();
      expect((await c.checkInToday())!.streak, 1);
      now = DateTime(2026, 9, 19, 0, 0, 1).millisecondsSinceEpoch;
      expect(c.checkedInToday, isFalse);
      final r = (await c.checkInToday())!;
      expect(r.first, isTrue);
      expect(r.streak, 2);
      now = DateTime(2026, 9, 19, 23, 0).millisecondsSinceEpoch;
      expect((await c.checkInToday())!.first, isFalse);
      expect(c.pendingHearts, 2);
    });

    test('윤년 2월 28일 → 29일 → 3월 1일도 연속', () {
      final m = PlayerMeta();
      for (final d in [
        DateTime(2028, 2, 28, 9),
        DateTime(2028, 2, 29, 9),
        DateTime(2028, 3, 1, 9),
      ]) {
        Attendance.checkIn(m, d);
      }
      expect(m.streakDays, 3);
    });

    test('보상표 경계: 0 · 3 · 7 · 10 · 14 · 17 · 21', () {
      expect(Attendance.rewardFor(0), (1, null));
      expect(Attendance.rewardFor(3), (2, Attendance.extraStreak3));
      expect(Attendance.rewardFor(7), (3, Attendance.extraStreak7));
      expect(Attendance.rewardFor(10), (2, Attendance.extraStreak3));
      expect(Attendance.rewardFor(14), (3, Attendance.extraStreak7));
      expect(Attendance.rewardFor(17), (2, Attendance.extraStreak3));
      expect(Attendance.rewardFor(21), (3, Attendance.extraStreak7));
    });

    test('재도전권은 연속 35일을 채워도 최대 3장', () {
      final m = PlayerMeta();
      var d = DateTime(2026, 1, 1, 9);
      for (var i = 0; i < 35; i++) {
        Attendance.checkIn(m, d);
        d = d.add(const Duration(days: 1));
      }
      expect(m.streakDays, 35);
      expect(m.rerollTickets, Attendance.maxRerollTickets);
      expect(m.totalCheckIns, 35);
    });

    test('이미 상한을 넘은 하트에는 출석 하트를 얹지 않는다(깎지도 않는다)', () {
      final s = freshState()..hearts = 12;
      expect(Attendance.grantHearts(s, 3, 5), 0);
      expect(s.hearts, 12);
      expect(Attendance.grantHearts(s, 0, 5), 0);
      expect(Attendance.grantHearts(s, -2, 5), 0);
    });
  });

  // -------------------------------------------------------------------------
  group('날짜 경계 1 · 3 · 99 · 100', () {
    test('장(chapter): 1 · 20 → 1장, 21 → 2장, 99 · 100 → 5장', () {
      int ch(int day) => (freshState()..day = day).chapter(real.config);
      expect(real.config.chapterLength, 20);
      expect(ch(1), 1);
      expect(ch(20), 1);
      expect(ch(21), 2);
      expect(ch(99), 5);
      expect(ch(100), 5);
    });

    test('isFinished: 100일은 아직, 101일부터 끝', () {
      expect(engine.isFinished(freshState()..day = 100), isFalse);
      expect(engine.isFinished(freshState()..day = 101), isTrue);
    });

    test('컨트롤러: 99일 마감 → 100일 계속, 100일 마감 → 엔딩(최고 도달 100, run_ended day 100)', () async {
      final c = controller();
      await c.init();
      await c.newGame(seed: 9, preference: Preference.female);
      c.state!.day = 99;
      await c.endDay();
      expect(c.phase, Phase.action);
      expect(c.state!.day, 100);
      expect(c.bestDayReached, 100);
      expect(rec.paramsOf(Analytics.dayReached).last, {'day': 100});
      await c.endDay();
      expect(c.phase, Phase.ending);
      expect(c.hasSave, isFalse);
      expect(c.bestDayReached, 100, reason: '101 이 아니라 totalDays 로 자른다');
      final ended = rec.paramsOf(Analytics.runEnded).single;
      expect(ended['day'], 100);
      expect(ended['ending'], c.ending!.id);
      expect(real.bundleEndingOk(c.ending!, Preference.female), isTrue);
    });

    test('day_reached 는 1~101 중 마일스톤 날에만', () {
      final a = Analytics(backend: rec);
      for (var d = 1; d <= 101; d++) {
        a.dayReach(d);
      }
      expect(
        rec.paramsOf(Analytics.dayReached).map((p) => p['day']).toList(),
        [2, 3, 7, 10, 20, 30, 50, 70, 100],
      );
    });

    test('전면 광고: 1 · 2일은 안 되고 3일부터(처음 켠 상태), 상수는 설계서대로', () {
      final ads = AdManager.instance;
      expect(ads.canShowInterstitial(1), isFalse);
      expect(ads.canShowInterstitial(2), isFalse);
      expect(ads.canShowInterstitial(3), isTrue);
      expect(ads.canShowInterstitial(100), isTrue);
      expect(AdManager.interstitialMinDay, 3);
      expect(AdManager.interstitialMinInterval, const Duration(minutes: 2));
      expect(AdManager.interstitialMaxPerDay, 12);
    });

    test('광고 단위 표: 종류 3개, 서로 다른 단위, 실제·테스트가 섞이지 않는다', () {
      for (final ios in [true, false]) {
        for (final release in [true, false]) {
          final ids = AdManager.idsFor(ios: ios, release: release);
          expect(ids.keys, unorderedEquals(['interstitial', 'rewarded', 'banner']));
          expect(ids.values.toSet().length, 3, reason: 'ios=$ios release=$release');
          final pubs = ids.values.map((v) => v.split('/').first).toSet();
          expect(pubs.length, 1, reason: '한 표에 실제·테스트 단위가 섞임');
        }
      }
      expect(
        AdManager.idsFor(ios: true, release: true).values.toSet().intersection(
          AdManager.idsFor(ios: true, release: false).values.toSet(),
        ),
        isEmpty,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('이름 입력 모서리', () {
    test('6자 통과 · 7자 거부 (한글 · 영문 · 섞임)', () {
      for (final ok in ['가나다라마바', 'Alexan', 'Kim민수1', '1']) {
        expect(PlayerName.validate(ok), isNull, reason: ok);
        expect(PlayerName.isValid(ok), isTrue, reason: ok);
      }
      for (final no in ['가나다라마바사', 'Alexand', '민수1234567']) {
        expect(PlayerName.validate(no), '6자까지 쓸 수 있어요', reason: no);
        expect(PlayerName.isValid(no), isFalse, reason: no);
      }
    });

    test('이모지 · 기호 · 전각 숫자는 거부, 자모만 남으면 완성 글자 안내', () {
      for (final no in ['민수😀', '😀', '👨‍👩‍👧', '민_수', 'a.b', '１２', 'é']) {
        expect(PlayerName.validate(no), '한글 · 영문 · 숫자만 쓸 수 있어요', reason: no);
      }
      expect(PlayerName.validate('ㅁㅅ'), '완성된 글자로 써 주세요');
      expect(PlayerName.validate('민수ㅋ'), '완성된 글자로 써 주세요');
      // 이모지 하나는 한 글자로 센다(길이 안내가 이모지 때문에 먼저 뜨지 않는다).
      expect(PlayerName.lengthOf('가나다라마👨‍👩‍👧'), 6);
    });

    test('공백: 안쪽·앞뒤·탭·줄바꿈은 지우고, 공백뿐이면 값 없음', () {
      expect(PlayerName.normalize(' 홍 길\t동\n'), '홍길동');
      expect(PlayerName.isValid(' 홍 길 동 '), isTrue);
      expect(PlayerName.validate('   '), isNull, reason: '빈 값은 버튼만 꺼진다');
      expect(PlayerName.isValid('   '), isFalse);
      // 공백을 빼면 6자 → 통과.
      expect(PlayerName.isValid('가 나 다 라 마 바'), isTrue);
    });

    test('컨트롤러 setPlayerName: 규칙 위반은 ArgumentError, 공백은 정규화해 저장', () async {
      final c = controller();
      await c.init();
      expect(() => c.setPlayerName('민수😀'), throwsArgumentError);
      expect(() => c.setPlayerName('가나다라마바사'), throwsArgumentError);
      expect(c.playerName, isNull);
      await c.setPlayerName(' 민 수 ');
      expect(c.playerName, '민수');
      expect((await MetaService().load()).playerName, '민수');
      await c.setPlayerName('  ');
      expect(c.playerName, isNull);
      expect(c.shouldAskName, isFalse);
      TextTemplate.currentName = null;
    });

    test('6자 이름 · 숫자 · 영문 이름에 조사', () {
      String f(String s, String? n) => TextTemplate.fill(s, name: n);
      expect(f('{name|이가} 왔어', '가나다라마박'), '가나다라마박이 왔어');
      expect(f('{name|아야}', '가나다라마바'), '가나다라마바야');
      expect(f('{name|으로로}', '가나다라마발'), '가나다라마발로');
      expect(f('{name|으로로}', '민수1'), '민수1로', reason: '일 = ㄹ');
      expect(f('{name|으로로}', '민수3'), '민수3으로', reason: '삼');
      expect(f('{name|이가}', '민수2'), '민수2가', reason: '이');
      expect(f('{name|이가}', '민수10'), '민수10이', reason: '십');
      expect(f('{name|은는}', '0'), '0은', reason: '영');
      expect(f('{name|과와}', 'A7'), 'A7과', reason: '칠');
      expect(f('{name|이랑랑}', 'Paul'), 'Paul이랑');
      expect(f('{name|을를}', 'Tom'), 'Tom을');
      expect(f('{name|아야}', 'Mike'), 'Mike야');
      expect(f('{name|이가}', 'JACK'), 'JACK이', reason: '대문자도 발음 추정');
      expect(f('{name|씨+이가}', '가나다라마박'), '가나다라마박 씨가');
    });

    test('이름이 빈 값 · 공백 · null 이면 모두 같은 대체어', () {
      for (final n in [null, '', '  ']) {
        expect(TextTemplate.fill('{name|이가} 왔네', name: n), '네가 왔네');
        expect(TextTemplate.fill('{name|아야}, 자?', name: n), '자?');
        expect(TextTemplate.fill('{name|씨}', name: n), '그쪽');
      }
    });

    test('받침 판단: 끝이 이모지 · 기호면 받침 없음, 자모 ㄹ 은 ㄹ 받침', () {
      expect(TextTemplate.finalOf('민수😀'), Final.none);
      expect(TextTemplate.finalOf('민수!'), Final.none);
      expect(TextTemplate.finalOf('ㄹ'), Final.rieul);
      expect(TextTemplate.finalOf('ㅂ'), Final.other);
      expect(TextTemplate.finalOf('ㅏ'), Final.none);
      expect(TextTemplate.finalOf(''), Final.none);
    });
  });

  // -------------------------------------------------------------------------
  group('MBTI 궁합 · 천생연분 엔딩', () {
    test('궁합은 대칭이고 0~4, 같은 유형은 2, 모든 유형에 천생연분 짝이 있다', () {
      for (final a in Mbti.types) {
        expect(Mbti.compat(a, a), 2, reason: a);
        expect(Mbti.types.where((b) => Mbti.compat(a, b) == 4), isNotEmpty);
        for (final b in Mbti.types) {
          final v = Mbti.compat(a, b);
          expect(v, inInclusiveRange(0, 4));
          expect(Mbti.compat(b, a), v, reason: '$a/$b');
        }
        expect(Mbti.compat(a, null), Mbti.neutralCompat);
        expect(Mbti.compat(null, a), Mbti.neutralCompat);
        expect(Mbti.compat(a, 'INF'), Mbti.neutralCompat, reason: '형식 틀림');
      }
    });

    test('모든 캐릭터에 형식이 맞는 MBTI 가 있다(궁합 · 천생연분이 동작하는 전제)', () {
      for (final c in real.characters) {
        expect(Mbti.isType(c.mbti), isTrue, reason: c.id);
      }
    });

    /// [e] 의 조건을 맞춘 상태. [mbti] 로 회차 MBTI 를 정한다.
    GameState stateFor(Ending e, String? mbti, {int mbtiFlags = 4}) {
      final ch = real.characterById[e.character]!;
      final w = e.when;
      final s = GameState.fresh(
        real.config,
        real.characters,
        seed: 1,
        preference: ch.gender,
        mbti: mbti,
      )..day = 101;
      if (w.run != null) s.run = w.run!.min;
      int pick(Range r, int cap) => r.max < cap ? r.max : r.min;
      w.stats.forEach((k, r) => s.stats[k] = pick(r, Stat.maxOf(k)));
      w.affection.forEach(
        (k, r) => s.rel(k == '*' ? ch.id : k).affection = pick(r, 100),
      );
      w.trust.forEach((k, r) => s.rel(k == '*' ? ch.id : k).trust = pick(r, 100));
      s.flags.addAll(w.flags);
      final fc = w.flagsAtLeast;
      if (fc != null) s.flags.addAll(fc.of.take(mbtiFlags));
      return s;
    }

    test('destiny: 궁합 4 + 축 플래그 2개면 destiny, 궁합 3 이하 · 모름 · 플래그 1개면 happy', () {
      final destinies = real.endings.where((e) => e.id.endsWith('_destiny'));
      expect(destinies.length, real.characters.length);
      for (final d in destinies) {
        final ch = real.characterById[d.character]!;
        final happyId = '${ch.id}_happy';
        expect(
          real.endings.any((e) => e.id == happyId),
          isTrue,
          reason: '$happyId 없음',
        );
        final best = Mbti.types.firstWhere((t) => Mbti.compat(t, ch.mbti) == 4);
        final worse = Mbti.types.firstWhere((t) => Mbti.compat(t, ch.mbti) == 3);
        expect(resolver.resolve(stateFor(d, best)).id, d.id, reason: '${d.id} 궁합 4');
        expect(
          resolver.resolve(stateFor(d, best, mbtiFlags: 2)).id,
          d.id,
          reason: '${d.id} 플래그 2개면 충분',
        );
        for (final (label, s) in [
          ('궁합 3', stateFor(d, worse)),
          ('모름', stateFor(d, null)),
          ('플래그 1개', stateFor(d, best, mbtiFlags: 1)),
        ]) {
          expect(resolver.resolve(s).id, happyId, reason: '${d.id} $label');
        }
      }
    });

    test('destiny 는 우선순위가 happy 보다 높고 legend · loop 보다 낮다', () {
      int p(String id) => real.endings.firstWhere((e) => e.id == id).priority;
      for (final c in real.characters) {
        expect(p('${c.id}_destiny'), greaterThan(p('${c.id}_happy')), reason: c.id);
        expect(p('${c.id}_destiny'), lessThan(p('legend')), reason: c.id);
      }
    });
  });

  // -------------------------------------------------------------------------
  group('다음 판 · 지난 판 모서리', () {
    final advisor = NextRunAdvisor(testBundle());

    test('모든 엔딩을 다 봤어도 권할 캐릭터는 있고 힌트 · 반대쪽 권유는 없다', () {
      final all = [for (final e in real.endings) e.id];
      for (final side in Preference.genders) {
        final r = advisor.suggest(side: side, album: all, playerMbti: null);
        expect(r.character, isNotNull, reason: side);
        expect(r.character!.hidden, isFalse);
        expect(r.hintEnding, isNull, reason: side);
        expect(r.otherSide, isNull, reason: side);
        expect(r.reason, NextRunAdvisor.fewLine);
      }
    });

    test('권한 캐릭터의 엔딩을 다 봤으면 이 쪽 공용 엔딩(해피·굿·솔로)을 힌트로', () {
      // 캐릭터 엔딩은 전부 봤고 공용은 하나도 안 본 앨범.
      final album = [
        for (final e in real.endings)
          if (e.character != null) e.id,
      ];
      final r = advisor.suggest(
        side: Preference.female,
        album: album,
        playerMbti: 'INFP',
      );
      final h = r.hintEnding;
      expect(h, isNotNull);
      expect(h!.character, isNull);
      expect(h.tier, isNot(anyOf('bad', 'hidden')));
      expect(h.isDefault, isFalse);
      expect(real.endingInPreference(h, Preference.female), isTrue);
    });

    test('예전 세이브(all) 회차 뒤에는 반대쪽을 권하지 않는다, 틀린 MBTI 는 모름 취급', () {
      final r = advisor.suggest(
        side: Preference.all,
        album: const [],
        playerMbti: 'XXXX',
      );
      expect(r.otherSide, isNull);
      expect(r.compat, isNull);
      expect(r.character, isNotNull);
      expect(r.reason, NextRunAdvisor.neverLine);
    });

    test('지난 판 한 줄: 모든 엔딩에 대해 자리표시자·빈 제목 없이 "끝났다" 로 끝난다', () {
      expect(previousRunLineFor(real, null), isNull);
      expect(previousRunLineFor(real, 'nope'), isNull);
      for (final e in real.endings) {
        final line = previousRunLineFor(real, e.id);
        expect(line, isNotNull, reason: e.id);
        expect(line, endsWith('끝났다'), reason: e.id);
        expect(line, isNot(contains('{')), reason: e.id);
        expect(line, isNot(contains('  ')), reason: '${e.id}: $line');
        expect(line, isNot(contains(' 으로 ')), reason: '${e.id}: $line');
      }
    });

    test('내일 예고: 상태를 바꾸지 않고, 같은 입력이면 같은 답(10일 × 두 쪽)', () {
      final peek = TomorrowPeek(engine);
      for (final pref in Preference.genders) {
        final s = GameState.fresh(
          real.config,
          real.characters,
          seed: 77,
          preference: pref,
        );
        for (var d = 1; d <= 10; d++) {
          final before = s.toJson();
          final a = peek.peek(s, cliffhanger: 'x');
          final b = peek.peek(s, cliffhanger: 'x');
          expect(s.toJson(), before, reason: '$pref $d일 상태 변경');
          expect(a?.eventId, b?.eventId);
          expect(a?.characterId, b?.characterId);
          if (a != null) {
            final ch = real.characterById[a.characterId]!;
            expect(ch.appearsIn(pref), isTrue, reason: '$pref ${a.characterId}');
          }
          engine.endDay(s);
        }
      }
      final last = freshState()..day = real.config.totalDays;
      expect(peek.peek(last), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('측정 규칙 × 실제 데이터', () {
    test('모든 엔딩 id · 등급이 파라미터 규칙(40자 이하 문자열)에 맞아 run_ended 가 assert 없이 나간다', () {
      final a = Analytics(backend: rec);
      for (final e in real.endings) {
        expect(e.id.length, lessThanOrEqualTo(40), reason: e.id);
        expect(e.tier.length, lessThanOrEqualTo(40), reason: e.id);
        a.runEnd(ending: e.id, tier: e.tier, run: 1, day: 100);
      }
      expect(rec.paramsOf(Analytics.runEnded).length, real.endings.length);
    });

    test('run_started 는 세 선호 값(f · m · all)과 사용자 속성 pref 를 받는다', () {
      final a = Analytics(backend: rec);
      for (final p in Preference.values) {
        a.runStart(run: 1, pref: p, n: 1);
        expect(rec.userProperties['pref'], p);
      }
      expect(rec.paramsOf(Analytics.runStarted).length, 3);
    });

    test('규칙을 어긴 이름 · 키 · 값은 디버그에서 assert 로 잡힌다', () {
      final a = Analytics(backend: rec);
      expect(() => a.log('BadName'), throwsA(isA<AssertionError>()));
      expect(() => a.log('ok', {'a' * 26: 1}), throwsA(isA<AssertionError>()));
      expect(() => a.log('ok', {'k': 'x' * 41}), throwsA(isA<AssertionError>()));
      expect(() => a.log('ok', {'k': 1.5}), throwsA(isA<AssertionError>()));
      expect(() => a.setUserProperty('a' * 25, '1'), throwsA(isA<AssertionError>()));
      expect(rec.events, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('스토리 무결성', () {
    test('모든 선택지의 next · failNext 대상 이벤트가 실제로 있다', () {
      final missing = <String>[];
      var refs = 0;
      for (final ev in real.events) {
        for (final c in ev.choices) {
          for (final target in [c.next, c.failNext]) {
            if (target == null) continue;
            refs++;
            if (real.eventById[target] == null) missing.add('${ev.id} → $target');
          }
        }
      }
      expect(refs, greaterThan(0));
      expect(missing, isEmpty);
    });

    test('next 대상은 선호가 같거나 공용이다(쪽이 다른 캐릭터로 이어지지 않는다)', () {
      final bad = <String>[];
      for (final ev in real.events) {
        for (final c in ev.choices) {
          for (final target in [c.next, c.failNext]) {
            final t = target == null ? null : real.eventById[target];
            if (t == null) continue;
            for (final pref in Preference.genders) {
              if (real.eventInPreference(ev, pref) &&
                  !real.eventInPreference(t, pref)) {
                bad.add('[$pref] ${ev.id} → ${t.id}');
              }
            }
          }
        }
      }
      expect(bad, isEmpty);
    });

    test('선호 2 × MBTI 17: 100일 완주, 선호 밖 이벤트 0, 선택지 0개인 날 없음, 엔딩은 그 쪽 것', () {
      final tally = <String, int>{};
      for (final pref in Preference.genders) {
        for (var i = 0; i < Mbti.playerCases.length; i++) {
          final mbti = Mbti.playerCases[i];
          final tag = '[$pref/${mbti ?? '모름'}]';
          final s = GameState.fresh(
            real.config,
            real.characters,
            seed: 1000 + i,
            preference: pref,
            mbti: mbti,
          );
          final r = Random(i);
          Ending? end;
          while (end == null && !engine.isFinished(s)) {
            engine.applyAction(
              s,
              real.config.actions[r.nextInt(real.config.actions.length)],
            );
            for (final ev in engine.planDay(s)) {
              expect(
                real.eventInPreference(ev, pref),
                isTrue,
                reason: '$tag ${s.day}일 ${ev.id}',
              );
              final views = engine.choicesFor(s, ev);
              expect(views, isNotEmpty, reason: '$tag ${ev.id} 선택지 0개');
              final open = views.where((v) => !v.locked).toList();
              final pool = open.isEmpty ? views : open;
              final c = ev.choices[pool[r.nextInt(pool.length)].index];
              engine.applyChoice(
                s,
                ev,
                c,
                forcedSuccess: c.minigame == null ? null : r.nextBool(),
              );
            }
            engine.endDay(s);
            end = resolver.immediate(s);
          }
          end ??= resolver.resolve(s);
          expect(
            real.endingInPreference(end, pref),
            isTrue,
            reason: '$tag 엔딩 ${end.id}',
          );
          tally[end.id] = (tally[end.id] ?? 0) + 1;
        }
      }
      expect(tally.values.fold(0, (a, b) => a + b), 34);
    });
  });
}

extension on StoryBundle {
  bool bundleEndingOk(Ending e, String pref) => endingInPreference(e, pref);
}
