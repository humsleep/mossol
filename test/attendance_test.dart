import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/attendance.dart';
import 'package:mossol/engine/meta_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget/helpers.dart';

/// 출석·연속 접속·메타 저장·홈 화면용 조회 API 를 고정한다.
/// 시계는 컨트롤러의 clock 으로 넣고, 날짜는 기기 로컬 기준이므로
/// 테스트도 DateTime(y, m, d, h) 로 로컬 시각을 만든다.
void main() {
  int at(int y, int m, int d, [int h = 10]) => DateTime(y, m, d, h).millisecondsSinceEpoch;

  late int now;
  GameController controller() =>
      GameController(bundle: testBundle(), save: SaveService(), clock: () => now);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = at(2026, 9, 18);
  });

  group('순수 함수', () {
    test('보상표: 매일 1, 3일째 2, 7일째 3 + 재도전권, 7일 주기로 반복', () {
      expect(Attendance.rewardFor(1), (1, null));
      expect(Attendance.rewardFor(2), (1, null));
      expect(Attendance.rewardFor(3), (2, Attendance.extraStreak3));
      expect(Attendance.rewardFor(6), (1, null));
      expect(Attendance.rewardFor(7), (3, Attendance.extraStreak7));
      expect(Attendance.rewardFor(10), (2, Attendance.extraStreak3));
      expect(Attendance.rewardFor(14), (3, Attendance.extraStreak7));
      // 한 주 개근 = 하트 10.
      var sum = 0;
      for (var d = 1; d <= 7; d++) {
        sum += Attendance.rewardFor(d).$1;
      }
      expect(sum, 10);
    });

    test('같은 날 두 번 출석하면 두 번째는 보상이 없다', () {
      final m = PlayerMeta();
      final a = Attendance.checkIn(m, DateTime(2026, 9, 18, 9));
      expect(a.first, isTrue);
      expect(a.streak, 1);
      expect(a.heartsGranted, 1);
      final b = Attendance.checkIn(m, DateTime(2026, 9, 18, 23, 59));
      expect(b.first, isFalse);
      expect(b.heartsGranted, 0);
      expect(b.streak, 1);
      expect(m.totalCheckIns, 1);
    });

    test('연속 계산: 어제 → 오늘 +1, 이틀 건너뛰면 1 로 돌아간다', () {
      final m = PlayerMeta();
      Attendance.checkIn(m, DateTime(2026, 9, 18));
      expect(Attendance.checkIn(m, DateTime(2026, 9, 19)).streak, 2);
      expect(Attendance.checkIn(m, DateTime(2026, 9, 20)).streak, 3);
      expect(m.bestStreak, 3);
      // 21일 건너뛰고 22일.
      final r = Attendance.checkIn(m, DateTime(2026, 9, 22));
      expect(r.streak, 1);
      expect(r.heartsGranted, 1);
      expect(m.bestStreak, 3, reason: '최고 기록은 남는다');
      expect(m.totalCheckIns, 4);
    });

    test('자정 직전 출석 후 자정 직후 출석은 다음 날로 센다', () {
      final m = PlayerMeta();
      Attendance.checkIn(m, DateTime(2026, 9, 18, 23, 59, 59));
      final r = Attendance.checkIn(m, DateTime(2026, 9, 19, 0, 0, 1));
      expect(r.first, isTrue);
      expect(r.streak, 2);
    });

    test('월말·연말을 넘어도 연속이 이어진다', () {
      final m = PlayerMeta();
      Attendance.checkIn(m, DateTime(2026, 12, 31));
      expect(Attendance.checkIn(m, DateTime(2027, 1, 1)).streak, 2);
      Attendance.checkIn(m, DateTime(2027, 2, 28));
      expect(Attendance.checkIn(m, DateTime(2027, 3, 1)).streak, 2);
    });

    test('3일·7일 보너스와 재도전권', () {
      final m = PlayerMeta();
      CheckInResult? r;
      for (var d = 1; d <= 7; d++) {
        r = Attendance.checkIn(m, DateTime(2026, 9, d));
        if (d == 3) {
          expect(r.heartsGranted, 2);
          expect(r.extra, Attendance.extraStreak3);
        } else if (d == 7) {
          expect(r.heartsGranted, 3);
          expect(r.extra, Attendance.extraStreak7);
        } else {
          expect(r.heartsGranted, 1);
          expect(r.extra, isNull);
        }
      }
      expect(m.rerollTickets, 1);
      // 14일째에도 한 장 더. 상한은 3.
      for (var d = 8; d <= 28; d++) {
        Attendance.checkIn(m, DateTime(2026, 9, d));
      }
      expect(m.streakDays, 28);
      expect(m.rerollTickets, Attendance.maxRerollTickets);
    });

    test('시계가 과거로 가면 보상 없이 기록을 지킨다', () {
      final m = PlayerMeta();
      Attendance.checkIn(m, DateTime(2026, 9, 18));
      Attendance.checkIn(m, DateTime(2026, 9, 19));
      final r = Attendance.checkIn(m, DateTime(2026, 9, 17));
      expect(r.first, isFalse);
      expect(r.heartsGranted, 0);
      expect(m.streakDays, 2);
      expect(m.lastCheckInDate, '2026-09-19');
      expect(m.totalCheckIns, 2);
      // 시계가 돌아오면 다음 날부터 정상.
      expect(Attendance.checkIn(m, DateTime(2026, 9, 20)).streak, 3);
    });

    test('liveStreak: 어제까지 출석이면 유지, 그제면 0', () {
      final m = PlayerMeta();
      Attendance.checkIn(m, DateTime(2026, 9, 18));
      Attendance.checkIn(m, DateTime(2026, 9, 19));
      expect(Attendance.liveStreak(m, DateTime(2026, 9, 19)), 2);
      expect(Attendance.liveStreak(m, DateTime(2026, 9, 20)), 2);
      expect(Attendance.liveStreak(m, DateTime(2026, 9, 21)), 0);
      expect(Attendance.liveStreak(PlayerMeta(), DateTime(2026, 9, 21)), 0);
    });

    test('출석 하트는 최대치를 넘길 수 있지만 두 배까지만', () {
      final s = freshState();
      final max = testBundle().config.maxHearts;
      expect(s.hearts, max);
      expect(Attendance.grantHearts(s, 3, max), 3);
      expect(s.hearts, max + 3);
      expect(Attendance.grantHearts(s, 100, max), max * 2 - (max + 3));
      expect(s.hearts, max * 2);
      expect(Attendance.grantHearts(s, 1, max), 0);
      expect(Attendance.grantHearts(s, 0, max), 0);
    });

    test('회차 간 보너스: 엔딩 1개당 +1, 상한 5, 스탯 상한 안 넘김', () {
      expect(crossRunBonus(0), isEmpty);
      expect(crossRunBonus(2), {Stat.charm: 2, Stat.talk: 2, Stat.esteem: 2});
      expect(crossRunBonus(30)[Stat.charm], crossRunCap);
      final s = freshState()..stats[Stat.charm] = 99;
      applyCrossRunBonus(s, crossRunBonus(5));
      expect(s.stat(Stat.charm), 100);
      expect(s.stat(Stat.talk), 25);
    });
  });

  group('메타 저장소', () {
    test('저장·복원 왕복, 손상되면 초기화', () async {
      final svc = MetaService();
      final m = PlayerMeta(
        lastCheckInDate: '2026-09-18',
        streakDays: 4,
        bestStreak: 9,
        totalCheckIns: 20,
        totalRuns: 3,
        bestDayReached: 57,
        firstLaunchMs: 123,
        pendingHearts: 2,
        rerollTickets: 1,
      );
      await svc.save(m);
      final r = await svc.load();
      expect(r.toJson(), m.toJson());

      SharedPreferences.setMockInitialValues({'mossol_meta_v1': '{broken'});
      expect((await svc.load()).toJson(), PlayerMeta().toJson());
      SharedPreferences.setMockInitialValues({'mossol_meta_v1': '[1,2]'});
      expect((await svc.load()).streakDays, 0);
      // 필드가 빠지거나 타입이 이상해도 기본값으로.
      SharedPreferences.setMockInitialValues({
        'mossol_meta_v1': jsonEncode({'streakDays': 'x', 'lastCheckInDate': ''}),
      });
      final p = await svc.load();
      expect(p.streakDays, 0);
      expect(p.lastCheckInDate, isNull);
    });

    test('세이브 키를 건드리지 않는다', () async {
      final c = controller();
      await c.init();
      await c.checkInToday();
      final p = await SharedPreferences.getInstance();
      expect(p.getKeys(), {'mossol_meta_v1'});
      expect(c.meta!.firstLaunchMs, now);
    });
  });

  group('컨트롤러', () {
    test('init 전에는 null, 세이브 없이 출석하면 pending 에 쌓이고 newGame 에서 얹힌다',
        () async {
      final c = controller();
      expect(await c.checkInToday(), isNull);
      await c.init();
      expect(c.hasSave, isFalse);
      final r = await c.checkInToday();
      expect(r!.first, isTrue);
      expect(c.pendingHearts, 1);
      expect(c.checkedInToday, isTrue);
      expect(c.streakDays, 1);
      // 같은 날 두 번째는 아무것도 안 준다.
      final again = await c.checkInToday();
      expect(again!.first, isFalse);
      expect(c.pendingHearts, 1);

      // 다른 인스턴스로 다시 읽어도 pending 이 남아 newGame 에 적용된다.
      final c2 = controller();
      await c2.init();
      expect(c2.pendingHearts, 1);
      await c2.newGame(seed: 1);
      expect(c2.hearts, c2.config.maxHearts + 1);
      expect(c2.pendingHearts, 0);
      expect(c2.totalRuns, 1);
      expect(c2.runBonus, isEmpty, reason: '앨범이 비었으면 보너스 없음');
    });

    test('세이브가 있으면 출석 하트를 바로 얹고 저장한다', () async {
      final c = controller();
      await c.init();
      await c.newGame(seed: 1);
      final max = c.config.maxHearts;
      final r = await c.checkInToday();
      expect(r!.heartsGranted, 1);
      expect(c.hearts, max + 1);
      expect(c.pendingHearts, 0);
      // 상한에 걸리면 나머지는 보관함으로.
      c.state!.hearts = max * 2;
      now += 24 * 60 * 60 * 1000;
      expect((await c.checkInToday())!.heartsGranted, 1);
      expect(c.hearts, max * 2);
      expect(c.pendingHearts, 1);
      c.state!.hearts = max + 1;
      c.meta!.pendingHearts = 0;
      await c.metaService.save(c.meta!);
      await c.save.save(c.state!);
      now -= 24 * 60 * 60 * 1000;
      // 저장됐는지: 새 컨트롤러로 이어 하기.
      final c2 = controller();
      await c2.init();
      expect(await c2.continueGame(), isTrue);
      expect(c2.hearts, max + 1);
      // 초과분은 재생 대상이 아니다: 시간이 지나도 늘지 않고 타이머는 0.
      now += 24 * 60 * 60 * 1000;
      expect(await c2.refreshHearts(), 0);
      expect(c2.hearts, max + 1);
      expect(c2.secondsToNextHeart, 0);
      expect(c2.heartsFull, isTrue);
      // 초과 하트로 하루를 시작할 수 있다.
      expect(await c2.startDay(c2.config.actions.first), isTrue);
      expect(c2.hearts, max);
    });

    test('continueGame 도 pending 을 얹는다', () async {
      final c = controller();
      await c.init();
      await c.newGame(seed: 1);
      c.state!.hearts = 0;
      await c.save.save(c.state!);

      final c2 = controller();
      await c2.init();
      expect(c2.state, isNull);
      await c2.checkInToday();
      expect(c2.pendingHearts, 1);
      expect(await c2.continueGame(), isTrue);
      expect(c2.hearts, 1);
      expect(c2.pendingHearts, 0);
    });

    test('secondsToNextHeart 경계값', () async {
      final c = controller();
      await c.init();
      await c.newGame(seed: 1);
      final period = c.engine.heartPeriodMs;
      expect(c.secondsToNextHeart, 0, reason: '가득 찼으면 0');
      await c.startDay(c.config.actions.first);
      expect(c.secondsToNextHeart, period ~/ 1000);
      now += 1;
      expect(c.secondsToNextHeart, period ~/ 1000, reason: '1ms 지나면 올림해서 그대로');
      now += period - 1001;
      expect(c.secondsToNextHeart, 1);
      now += 999;
      expect(c.secondsToNextHeart, 1, reason: '1ms 남아도 1초');
      now += 1;
      expect(c.secondsToNextHeart, 0, reason: '정확히 주기가 지나면 0');
      expect(await c.refreshHearts(), 1);
      expect(c.hearts, c.config.maxHearts);
      expect(c.secondsToNextHeart, 0);
      // 시계가 뒤로 가도 음수가 나오지 않는다.
      await c.startDay(c.config.actions.first);
      now -= 10 * period;
      expect(c.secondsToNextHeart, greaterThan(0));
      expect(c.secondsToNextHeart, lessThanOrEqualTo(period ~/ 1000 * 11));
    });

    test('세이브 없으면 secondsToNextHeart 0, topCharacter null', () async {
      final c = controller();
      await c.init();
      expect(c.secondsToNextHeart, 0);
      expect(c.topCharacterId, isNull);
      expect(c.topAffection, 0);
      expect(c.heartsFull, isFalse);
    });

    test('topCharacterId: 최고 호감, 전원 0 이면 null, 동률은 앞 순서', () async {
      final c = controller();
      await c.init();
      await c.newGame(seed: 1);
      expect(c.topCharacterId, isNull);
      final chars = c.bundle.characters;
      c.state!.rel(chars[2].id).affection = 7;
      c.state!.rel(chars[0].id).affection = 7;
      expect(c.topCharacterId, chars[0].id);
      expect(c.topAffection, 7);
      c.state!.rel(chars[2].id).affection = 8;
      expect(c.topCharacterId, chars[2].id);
      expect(c.topAffection, 8);
    });

    test('endingCountsByTier·endingTotalsByTier·nextLockedEndingHint', () async {
      final c = controller();
      await c.init();
      final tiers = c.bundle.endings.map((e) => e.tier).toSet();
      expect(c.endingCountsByTier.keys.toSet(), tiers);
      expect(c.endingCountsByTier.values.every((v) => v == 0), isTrue);
      final totals = c.endingTotalsByTier;
      expect(totals.values.fold(0, (a, b) => a + b), c.bundle.endings.length);

      // 힌트: 기본 엔딩을 뺀 최저 priority.
      final nonDefault = c.bundle.endings.where((e) => !e.isDefault).toList();
      final lowest = nonDefault.map((e) => e.priority).reduce((a, b) => a < b ? a : b);
      final hint = c.nextLockedEndingHint!;
      expect(hint.priority, lowest);
      expect(hint.isDefault, isFalse);

      await c.save.addEnding(hint.id);
      final happy = c.bundle.endings.firstWhere((e) => e.tier == 'happy');
      await c.save.addEnding(happy.id);
      c.endingAlbum = await c.save.loadEndings();
      expect(c.endingCountsByTier[hint.tier], 1 + (happy.tier == hint.tier ? 1 : 0));
      expect(c.endingCountsByTier['happy'], 1);
      expect(c.nextLockedEndingHint!.id, isNot(hint.id));

      // 전부 보면 null.
      for (final e in c.bundle.endings) {
        await c.save.addEnding(e.id);
      }
      c.endingAlbum = await c.save.loadEndings();
      expect(c.nextLockedEndingHint, isNull);
      expect(c.endingCountsByTier, totals);
    });

    test('회차 간 보너스가 두 번째 회차 초기 스탯에 붙는다', () async {
      final c = controller();
      await c.init();
      await c.save.addEnding('seoyeon_friend');
      await c.save.addEnding('jiwoo_some');
      c.endingAlbum = await c.save.loadEndings();
      await c.newGame(seed: 1, run: 2);
      final init = c.config.initialStats;
      expect(c.runBonus, {Stat.charm: 2, Stat.talk: 2, Stat.esteem: 2});
      expect(c.state!.stat(Stat.charm), init[Stat.charm]! + 2);
      expect(c.state!.stat(Stat.talk), init[Stat.talk]! + 2);
      expect(c.state!.stat(Stat.esteem), init[Stat.esteem]! + 2);
      expect(c.state!.stat(Stat.sense), init[Stat.sense]);
    });

    test('bestDayReached 와 totalRuns 가 메타에 남는다', () async {
      final c = controller();
      await c.init();
      await c.newGame(seed: 3);
      await c.startDay(c.config.actions.first);
      while (c.phase == Phase.event) {
        final v = c.choices.firstWhere((v) => !v.locked);
        c.choose(v.index, minigameSuccess: v.choice.minigame == null ? null : true);
        c.continueAfterChoice();
      }
      expect(c.phase, Phase.summary);
      await c.endDay();
      expect(c.bestDayReached, 2);
      await c.newGame(seed: 4);
      expect(c.totalRuns, 2);
      expect(c.bestDayReached, 2, reason: '새 회차를 시작해도 최고 기록은 유지');
      final m = await MetaService().load();
      expect(m.totalRuns, 2);
      expect(m.bestDayReached, 2);
    });

    test('재도전권으로 룰렛을 광고 없이 한 번 더 돌린다', () async {
      final c = controller();
      await c.init();
      // 7일 연속 출석.
      for (var d = 1; d <= 7; d++) {
        now = at(2026, 9, d);
        await c.checkInToday();
      }
      expect(c.rerollTickets, 1);
      expect(c.pendingHearts, 10);
      await c.newGame(seed: 1);
      expect(c.hearts, Attendance.heartCeiling(c.config.maxHearts),
          reason: '한 주치 출석 하트도 상한(최대치 두 배)까지만');
      expect(c.pendingHearts, 5, reason: '못 얹은 몫은 보관함에 남는다');
      expect(c.canUseRerollTicket, isFalse, reason: '룰렛을 먼저 돌려야 한다');
      expect(() => c.useRerollTicket(), throwsStateError);
      c.spinRoulette();
      expect(c.canUseRerollTicket, isTrue);
      await c.useRerollTicket();
      expect(c.rerollTickets, 0);
      expect(c.rouletteRerolled, isTrue);
      expect(c.canUseRerollTicket, isFalse);
      expect((await MetaService().load()).rerollTickets, 0);
    });
  });
}
