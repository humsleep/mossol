/// 홈 v2 (docs/HOME_REDESIGN.md §1) 와 설정 화면(§2).
///
/// 홈은 1초 타이머를 돌리므로 테스트 끝에 `tester.pumpWidget(Container())` 로
/// 내려서 Timer 가 남지 않게 한다.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/app_meta.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/album_screen.dart';
import 'package:mossol/ui/settings_screen.dart';
import 'package:mossol/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'helpers.dart';

/// 브라우저가 없는 환경. 링크를 못 여는 경로를 시험한다.
class _NoBrowser extends UrlLauncherPlatform {
  final List<String> launched = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return false;
  }
}

void main() {
  late GameController c;

  setUp(() async {
    c = await makeController();
  });

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(Container());
  }

  Future<void> showHome(WidgetTester tester) async {
    await tester.pumpWidget(fullApp(c));
    await tester.pump();
  }

  group('세이브 없음', () {
    testWidgets('소개 카드 · 새 게임 · 등장인물 · 앨범 0 / N · 힌트', (tester) async {
      await showHome(tester);
      expect(findText('모쏠 키우기'), findsOneWidget);
      expect(findText('100일 뒤, 나는 달라져 있을까'), findsOneWidget);
      expect(findText('아침: 오늘 할 일 하나 고르기'), findsOneWidget);
      expect(findWidgetWithText(FilledButton, '새 게임'), findsOneWidget);
      expect(findText('새 게임'), findsOneWidget);
      expect(findText('이어하기'), findsNothing);

      // 하트 줄은 세이브가 없으면 그리지 않는다.
      expect(find.byType(HeartsRow), findsNothing);
      expect(findText('광고로 +1'), findsNothing);

      // 첫 실행("나는?" 답 없음): 쪽을 모르므로 등장인물 줄을 그리지 않는다. 12명을 섞어
      // 보여 주지 않는다 — 소개는 새 게임 2단계(캐스트 소개)가 맡는다.
      expect(findText('등장인물'), findsNothing);
      expect(find.byType(CastStrip), findsNothing);
      expect(findText('호감 순'), findsNothing);
      expect(findTextContaining('♥'), findsNothing);
      // 소개 카드의 엔딩 수는 한 회차가 닿을 수 있는 수(한쪽 캐릭터 엔딩 + 공용).
      final perRun = c.bundle.endingCountFor(Preference.female);
      expect(perRun, lessThan(c.bundle.endings.length));
      expect(findText('100일: 엔딩 $perRun개 중 하나'), findsOneWidget);

      // 앨범 카드.
      final total = c.bundle.endings.length;
      expect(findTextContaining('앨범  0 / $total'), findsOneWidget);
      expect(find.byType(EndingTierDots), findsOneWidget);
      expect(findTextContaining('다음 엔딩 힌트 · '), findsOneWidget);
      // 쪽을 모르면 힌트는 공용 엔딩에서 고른다(한쪽 캐릭터 문장이 뜨지 않는다).
      final common = c.bundle.endings.firstWhere(
        (e) =>
            c.bundle.endingSide(e) == null &&
            e.tier != 'bad' &&
            e.tier != 'hidden',
      );
      expect(
        findText('다음 엔딩 힌트 · ${endingHintFor(common, c)}'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    for (final (gender, side) in [
      (PlayerGender.male, Preference.female),
      (PlayerGender.female, Preference.male),
    ]) {
      testWidgets(
        '나는 ${PlayerGender.label(gender)}: 등장인물 줄은 기본 쪽 5명 + ???, 힌트도 그 쪽',
        (tester) async {
          await c.setPlayerGender(gender);
          await showHome(tester);
          expect(findText('등장인물'), findsOneWidget);
          final strip = tester.widget<CastStrip>(find.byType(CastStrip));
          final roster = c.bundle.charactersFor(side);
          expect(strip.entries.map((e) => e.id).toSet(), {
            for (final ch in roster) ch.id,
          });
          expect(strip.entries.length, 6);
          expect(strip.entries.where((e) => e.mystery), hasLength(1));
          expect(strip.entries.last.mystery, isTrue);
          expect(findText('???'), findsOneWidget);
          expect(findTextContaining('♥'), findsNothing);
          // 반대쪽 이름은 없다.
          for (final ch in c.bundle.characters) {
            if (ch.gender == side || ch.hidden) continue;
            expect(
              find.descendant(
                of: find.byType(CastStrip),
                matching: findText(ch.name),
              ),
              findsNothing,
              reason: ch.name,
            );
          }
          // 힌트: 그 쪽 + 공용 중 첫 미획득(endings.json 순이라 그 쪽 해피가 먼저).
          final first = c.bundle.endings.firstWhere(
            (e) =>
                c.bundle.endingInPreference(e, side) &&
                e.tier != 'bad' &&
                e.tier != 'hidden',
          );
          expect(first.character, isNotNull);
          expect(c.bundle.characterById[first.character]!.gender, side);
          expect(
            findText('다음 엔딩 힌트 · ${endingHintFor(first, c)}'),
            findsOneWidget,
          );
          await unmount(tester);
        },
      );
    }

    testWidgets('나는 선택 안 함: 첫 실행처럼 등장인물 줄 없음 · 공용 힌트', (tester) async {
      await c.setPlayerGender(PlayerGender.none);
      await showHome(tester);
      expect(find.byType(CastStrip), findsNothing);
      final hint = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').replaceAll('\u2060', ''))
          .firstWhere((t) => t.startsWith('다음 엔딩 힌트 · '));
      final commonHints = {
        for (final e in c.bundle.endings)
          if (c.bundle.endingSide(e) == null) endingHintFor(e, c),
      };
      expect(commonHints.any((h) => hint.endsWith(h)), isTrue, reason: hint);
      await unmount(tester);
    });

    testWidgets('앨범 카드를 누르면 앨범으로 간다', (tester) async {
      await showHome(tester);
      await tester.tap(findTextContaining('앨범  0 /'));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumScreen), findsOneWidget);
      await unmount(tester);
    });
  });

  group('세이브 있음', () {
    setUp(() async {
      await c.newGame(seed: 5);
      c.state!
        ..day = 37
        ..lastCliffhanger = '내일 서연이 먼저 연락한다고 했는데 아직 아무 말이 없다';
      c.state!.rel('seoyeon').affection = 42;
      c.state!.rel('haneul').affection = 10;
      await c.save.save(c.state!);
      c.goHome();
    });

    testWidgets('이어하기 카드 · 버튼 둘 · 호감 순 · 히든 잠김', (tester) async {
      await showHome(tester);
      final s = c.saveSummary!;
      expect(s.day, 37);
      expect(s.topCharacterId, 'seoyeon');
      expect(findText('1회차 · 2장'), findsOneWidget);
      expect(findText('D+37 / 100'), findsOneWidget);
      expect(findTextContaining('어젯밤: 내일 서연이'), findsOneWidget);
      expect(findTextContaining('서연 ♥42'), findsOneWidget);
      // 숫자 대신 서사 신호가 주인공. '가장 가까운 사람' 꼬리표는 신호가 대신한다.
      expect(s.topSignal, isNotNull);
      expect(findTextContaining(s.topSignal!), findsOneWidget);
      expect(findText('가장 가까운 사람'), findsNothing);

      expect(findWidgetWithText(FilledButton, '이어하기'), findsOneWidget);
      expect(findWidgetWithText(TextButton, '새 게임'), findsOneWidget);
      expect(findText('새 게임'), findsOneWidget);
      expect(findText('이어하기'), findsOneWidget);

      expect(findText('사람들'), findsOneWidget);
      expect(findText('호감 순'), findsOneWidget);
      final strip = tester.widget<CastStrip>(find.byType(CastStrip));
      expect(strip.entries.first.name, '서연');
      expect(strip.entries[1].name, '하늘');
      expect(strip.entries.last.mystery, isTrue);
      expect(findText('♥42'), findsOneWidget);
      // 전원 등장(all) 세이브라 히든 두 명(도윤·유나)이 잠겨 있다.
      expect(findText('???'), findsNWidgets(2));
      await unmount(tester);
    });

    testWidgets('히든은 호감이 생기면 이름으로 보인다', (tester) async {
      c.state!.rel('doyun').affection = 3;
      await c.save.save(c.state!);
      c.goHome();
      await showHome(tester);
      // 도윤만 풀리고 호감 0 인 유나는 그대로 잠겨 있다.
      expect(findText('???'), findsOneWidget);
      expect(findText('도윤'), findsOneWidget);
      expect(findText('♥3'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('앱을 새로 켠 것처럼 state 없이도 요약으로 그린다', (tester) async {
      c.state = null;
      await c.init();
      expect(c.state, isNull);
      expect(c.saveSummary, isNotNull);
      await showHome(tester);
      expect(findText('D+37 / 100'), findsOneWidget);
      expect(findTextContaining('서연 ♥42'), findsOneWidget);
      expect(find.byType(HeartsRow), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('요약 대기 프레임은 placeholder 카드, 하트 줄 없음', (tester) async {
      // 세이브 파일은 있는데 아직 읽지 못한 첫 프레임을 흉내 낸다.
      c.state = null;
      c.saveSummary = null;
      await showHome(tester);
      expect(c.saveSummary, isNull);
      expect(findText('저장된 회차'), findsOneWidget);
      expect(findText('어젯밤: 불러오는 중…'), findsOneWidget);
      expect(find.byType(HeartsRow), findsNothing);
      expect(findText('이어하기'), findsOneWidget);
      expect(findText('새 게임'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('최애 신호: 같은 날 다시 그려도 같은 문장, 하트는 작은 보조 꼬리', (tester) async {
      await showHome(tester);
      final signal = c.saveSummary!.topSignal!;
      final line = findTextContaining(signal);
      expect(line, findsOneWidget);
      // 신호와 '서연 ♥42' 는 한 덩어리 Text.rich. 신호가 주인공이라 글자가 더 크다.
      final spans = (tester.widget<Text>(line).textSpan! as TextSpan).children!;
      final sig = spans.whereType<TextSpan>().firstWhere(
        (x) => x.text?.replaceAll('\u2060', '') == signal,
      );
      // 꼬리는 줄바꿈에 쪼개지지 않게 WidgetSpan 안의 Text 다.
      final heart = tester.widget<Text>(findText('서연 ♥42'));
      expect(sig.style!.fontSize!, greaterThan(heart.style!.fontSize!));
      c.goHome();
      await tester.pump();
      expect(findTextContaining(signal), findsOneWidget);
      expect(c.saveSummary!.topSignal, signal);
      await unmount(tester);
    });

    testWidgets('signals.json 이 없으면 예전처럼 숫자 + 가장 가까운 사람', (tester) async {
      final b = c.bundle;
      final bare = GameController(
        bundle: StoryBundle(
          config: b.config,
          characters: b.characters,
          events: b.events,
          endings: b.endings,
        ),
        save: SaveService(),
      );
      await bare.init();
      expect(bare.saveSummary!.topSignal, isNull);
      await tester.pumpWidget(fullApp(bare));
      await tester.pump();
      expect(findText('서연 ♥42'), findsOneWidget);
      expect(findText('가장 가까운 사람'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('전원 호감 0 이면 아바타 대신 안내 문장', (tester) async {
      c.state!.rel('seoyeon').affection = 0;
      c.state!.rel('haneul').affection = 0;
      await c.save.save(c.state!);
      c.goHome();
      await showHome(tester);
      expect(findText('아직 아무와도 가까워지지 않았다'), findsOneWidget);
      expect(findText('가장 가까운 사람'), findsNothing);
      await unmount(tester);
    });
  });

  group('출석 줄', () {
    testWidgets('미수령 → 받기 → 수령, 다시 들어오면 수령 상태', (tester) async {
      await showHome(tester);
      expect(findText('출석 보상 하트 +1'), findsOneWidget);
      expect(findText('연속 1일째'), findsOneWidget);
      expect(findText('받기'), findsOneWidget);
      // 보상은 홈 진입 때 이미 얹혔다. 세이브가 없으니 보류함으로.
      expect(c.pendingHearts, 1);
      expect(c.checkedInToday, isTrue);

      await tester.tap(findText('받기'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(findText('오늘 출석 완료'), findsOneWidget);
      expect(findText('받기'), findsNothing);
      expect(findText('하트 +1 은 새 게임을 시작하면 들어온다'), findsOneWidget);

      // 같은 날 다시 홈에 오면 바로 수령 상태.
      await unmount(tester);
      await showHome(tester);
      expect(findText('오늘 출석 완료'), findsOneWidget);
      expect(findText('받기'), findsNothing);
      expect(c.pendingHearts, 1, reason: '두 번 주면 안 된다');
      await unmount(tester);
    });

    testWidgets('저장 초기화 뒤에는 첫 실행처럼 다시 미수령 줄이 된다 (회귀)', (tester) async {
      // 실기기: 설정 → 저장 데이터 초기화 뒤 홈이 '오늘 출석 완료 · 연속 0일째' 로 굳어 있었다.
      await c.newGame(seed: 1);
      c.goHome();
      await showHome(tester);
      await tester.tap(findText('받기'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(findText('오늘 출석 완료'), findsOneWidget);

      await c.resetAllData();
      expect(c.checkedInToday, isFalse);
      // 홈이 켜진 채라 다음 틱에서 새 메타를 알아채고 출석을 다시 돈다.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(findText('출석 보상 하트 +1'), findsOneWidget);
      expect(findText('받기'), findsOneWidget);
      expect(findText('연속 1일째'), findsOneWidget);
      expect(findTextContaining('연속 0일째'), findsNothing);
      expect(c.checkedInToday, isTrue);
      expect(c.pendingHearts, 1, reason: '세이브가 없으니 보류함에 다시 쌓인다');
      await unmount(tester);
    });

    testWidgets('세이브가 있으면 수령 부제가 연속 일수', (tester) async {
      await c.newGame(seed: 1);
      c.goHome();
      await showHome(tester);
      await tester.tap(findText('받기'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(findText('연속 1일째 · 내일 또 +1'), findsOneWidget);
      expect(c.hearts, c.config.maxHearts + 1, reason: '출석 하트는 세이브에 바로 얹힌다');
      await unmount(tester);
    });
  });

  group('하트 타이머', () {
    late int now;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      now = DateTime(2026, 9, 18, 21).millisecondsSinceEpoch;
      c = GameController(
        bundle: testBundle(),
        save: SaveService(),
        clock: () => now,
      );
      await c.init();
      await c.newGame(seed: 9);
      c.state!
        ..hearts = 3
        ..lastHeartMs = now;
      await c.save.save(c.state!);
      c.goHome();
    });

    testWidgets('1초마다 줄고, 시간이 차면 하트가 늘어 타이머가 사라진다', (tester) async {
      await showHome(tester);
      // 출석 +1 로 4개. 아직 부족하니 타이머가 보인다.
      expect(c.saveSummary!.hearts, 4);
      expect(findText('다음 하트 15:00'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      now += 1000;
      await tester.pump(const Duration(seconds: 1));
      expect(findText('다음 하트 14:59'), findsOneWidget);

      now += 899 * 1000;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(c.saveSummary!.hearts, 5);
      expect(findTextContaining('다음 하트'), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      await unmount(tester);
    });
  });

  group('앨범 카드', () {
    testWidgets('N / M 과 힌트 문구가 획득 수에 따라 바뀐다', (tester) async {
      final all = c.bundle.endings;
      for (final e in all.take(2)) {
        await c.save.addEnding(e.id);
      }
      c.endingAlbum = await c.save.loadEndings();
      c.goHome();
      await showHome(tester);
      expect(findTextContaining('앨범  2 / ${all.length}'), findsOneWidget);
      expect(findTextContaining('다음 엔딩 힌트 · '), findsOneWidget);

      // 해피·굿·솔로를 다 보면 남은 것을 말한다.
      for (final e in all) {
        if (e.tier != 'bad' && e.tier != 'hidden') await c.save.addEnding(e.id);
      }
      c.endingAlbum = await c.save.loadEndings();
      c.goHome();
      await tester.pump();
      expect(findText('남은 건 배드 엔딩과 히든뿐이다'), findsOneWidget);

      for (final e in all) {
        await c.save.addEnding(e.id);
      }
      c.endingAlbum = await c.save.loadEndings();
      c.goHome();
      await tester.pump();
      expect(
        findTextContaining('앨범  ${all.length} / ${all.length}'),
        findsOneWidget,
      );
      expect(findText('모든 엔딩을 봤다'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('설정', () {
    testWidgets('헤더 아이콘으로 진입, 항목이 규격 순서로 있다', (tester) async {
      // 목록이 한 화면보다 길다(게임 섹션 추가). 끝까지 지어지도록 높게.
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showHome(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(findText('설정'), findsOneWidget);
      // 광고 미지원 환경(테스트)에서는 UMP 행이 없다.
      expect(findText('개인정보 설정'), findsNothing);
      final titles = [
        '내 성별',
        '개인정보처리방침',
        '오픈소스 라이선스',
        '서체',
        '앱 버전',
        '저장 데이터 초기화',
      ];
      double lastTop = -1;
      for (final t in titles) {
        final rect = tester.getRect(findText(t));
        expect(rect.top, greaterThan(lastTop), reason: '$t 순서');
        lastTop = rect.top;
      }
      expect(
        findText('Pretendard · SIL Open Font License 1.1'),
        findsOneWidget,
      );
      expect(findText('OFL'), findsOneWidget);
      expect(findText(AppMeta.versionLabel), findsOneWidget);
      expect(findText('© 2026 모쏠 키우기'), findsOneWidget);

      // 서체·앱 버전 행은 눌리지 않는다.
      final rows = tester
          .widgetList<AppListRow>(find.byType(AppListRow))
          .toList();
      expect(rows.firstWhere((r) => r.title == '서체').onTap, isNull);
      expect(rows.firstWhere((r) => r.title == '앱 버전').onTap, isNull);
      expect(
        rows.firstWhere((r) => r.title == '저장 데이터 초기화').tone,
        AppTone.danger,
      );
      await unmount(tester);
    });

    testWidgets('개인정보처리방침을 못 열면 주소를 보여 준다', (tester) async {
      final launcher = _NoBrowser();
      UrlLauncherPlatform.instance = launcher;
      await tester.pumpWidget(wrapApp(SettingsScreen(c: c)));
      await tester.tap(findText('개인정보처리방침'));
      await tester.pumpAndSettle();
      expect(launcher.launched, [AppLinks.privacyPolicy]);
      expect(findText('링크를 열 수 없어요'), findsOneWidget);
      expect(findText(AppLinks.privacyPolicy), findsOneWidget);
      await tester.tap(findText('닫기'));
      await tester.pumpAndSettle();
      expect(findText('링크를 열 수 없어요'), findsNothing);
    });

    testWidgets('저장 데이터 초기화: 취소는 그대로, 지우기는 홈을 첫 실행 상태로', (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await c.setPlayerGender(PlayerGender.male);
      await c.newGame(seed: 5);
      await c.save.addEnding(c.bundle.endings.first.id);
      c.endingAlbum = await c.save.loadEndings();
      c.goHome();
      await showHome(tester);
      expect(findText('이어하기'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(findText('저장 데이터 초기화'));
      await tester.pumpAndSettle();
      expect(findTextContaining('엔딩 앨범(1개)'), findsOneWidget);
      await tester.tap(findText('취소'));
      await tester.pumpAndSettle();
      expect(c.hasSave, isTrue);
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.tap(findText('저장 데이터 초기화'));
      await tester.pumpAndSettle();
      await tester.tap(findText('지우기'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
      expect(findText('저장 데이터를 지웠어요'), findsOneWidget);
      expect(c.hasSave, isFalse);
      expect(c.saveSummary, isNull);
      expect(c.endingAlbum, isEmpty);
      expect(await c.save.exists(), isFalse);
      expect(await c.save.loadEndings(), isEmpty);
      // "나는?" 답도 지워진다(다음 새 게임에서 다시 묻는다: onboarding_test).
      expect(c.playerGender, isNull);
      expect((await c.metaService.load()).playerGender, isNull);
      expect(find.byType(CastStrip), findsNothing);
      expect(findWidgetWithText(FilledButton, '새 게임'), findsOneWidget);
      expect(findText('이어하기'), findsNothing);
      expect(findTextContaining('앨범  0 /'), findsOneWidget);
      // 첫 실행과 같아야 하므로 출석도 다시 돈다: 새 메타에 오늘 출석 1일째, 보류 하트 1.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(c.streakDays, 1);
      expect(c.pendingHearts, 1);
      expect(findText('출석 보상 하트 +1'), findsOneWidget);
      expect(findTextContaining('연속 0일째'), findsNothing);
      await unmount(tester);
    });

    test('AppMeta 버전은 pubspec 과 같다', () {
      final line = File('pubspec.yaml')
          .readAsLinesSync()
          .firstWhere((l) => l.startsWith('version:'));
      final v = line.substring('version:'.length).trim().split('+');
      expect(AppMeta.version, v[0]);
      expect(AppMeta.build, v[1]);
    });
  });

  group('서사 신호: 밤사이 하락 · 정산과 홈 일치', () {
    Future<void> freshRun() async {
      await c.newGame(seed: 21);
      final s = c.state!;
      for (final ch in c.bundle.characters) {
        s.rel(ch.id).affection = 0;
      }
    }

    testWidgets('마감 −1 로 구간이 내려간 사람은 다음 날 행동 화면에 조용한 한 줄', (tester) async {
      await freshRun();
      c.state!.rel('seoyeon').affection = 10;
      await c.endDay();
      expect(c.phase, Phase.action);
      final text = c.overnightShifts['seoyeon']!;
      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      expect(find.byKey(const Key('overnight-seoyeon')), findsOneWidget);
      expect(findText(text), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('같은 한 줄이 홈에도 뜨고, 하락이 없으면 자리도 없다', (tester) async {
      await freshRun();
      c.state!.rel('seoyeon').affection = 10;
      await c.endDay();
      c.goHome();
      await showHome(tester);
      expect(find.byKey(const Key('overnight-seoyeon')), findsOneWidget);
      expect(findText(c.overnightShifts['seoyeon']!), findsOneWidget);

      await c.continueGame();
      c.state!.rel('seoyeon').contactedToday = true;
      await c.endDay();
      c.goHome();
      await showHome(tester);
      expect(find.byKey(const Key('overnight-seoyeon')), findsNothing);
      await unmount(tester);
    });

    testWidgets('정산 카드 문장과 다음 날 아침 홈 카드 문장이 같다', (tester) async {
      await freshRun();
      final s = c.state!;
      s.rel('yeeun')
        ..affection = 12
        ..contactedToday = true;
      c.dayDelta.affection['yeeun'] = 5;
      c.phase = Phase.summary;
      await tester.pumpWidget(fullApp(c));
      await tester.pumpAndSettle();
      final card = tester.widget<RelationShiftCard>(
        find.byType(RelationShiftCard),
      );
      await c.endDay();
      c.goHome();
      await tester.pump();
      expect(c.saveSummary!.topSignal, card.text);
      expect(findTextContaining(card.text), findsOneWidget);
      await unmount(tester);
    });
  });
}
