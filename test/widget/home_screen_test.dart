/// 홈 v2 (docs/HOME_REDESIGN.md §1) 와 설정 화면(§2).
///
/// 홈은 1초 타이머를 돌리므로 테스트 끝에 `tester.pumpWidget(Container())` 로
/// 내려서 Timer 가 남지 않게 한다.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/app_meta.dart';
import 'package:mossol/engine/save_service.dart';
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
      expect(find.text('모쏠 키우기'), findsOneWidget);
      expect(find.text('100일 뒤, 이 남자는 달라져 있을까'), findsOneWidget);
      expect(find.text('아침: 오늘 할 일 하나 고르기'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '새 게임'), findsOneWidget);
      expect(find.text('새 게임'), findsOneWidget);
      expect(find.text('이어하기'), findsNothing);

      // 하트 줄은 세이브가 없으면 그리지 않는다.
      expect(find.byType(HeartsRow), findsNothing);
      expect(find.text('광고로 +1'), findsNothing);

      // 사람들: 수치 없이 이름만, 히든은 맨 뒤 '???'.
      expect(find.text('등장인물'), findsOneWidget);
      expect(find.text('호감 순'), findsNothing);
      expect(find.text('???'), findsOneWidget);
      expect(find.textContaining('♥'), findsNothing);
      final strip = tester.widget<CastStrip>(find.byType(CastStrip));
      expect(strip.entries.last.mystery, isTrue);
      expect(strip.entries.length, c.bundle.characters.length);

      // 앨범 카드.
      final total = c.bundle.endings.length;
      expect(find.textContaining('앨범  0 / $total'), findsOneWidget);
      expect(find.byType(EndingTierDots), findsOneWidget);
      expect(find.textContaining('다음 엔딩 힌트 · '), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('앨범 카드를 누르면 앨범으로 간다', (tester) async {
      await showHome(tester);
      await tester.tap(find.textContaining('앨범  0 /'));
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
      expect(find.text('1회차 · 2장'), findsOneWidget);
      expect(find.text('D+37 / 100'), findsOneWidget);
      expect(find.textContaining('어젯밤: 내일 서연이'), findsOneWidget);
      expect(find.textContaining('서연 ♥42'), findsOneWidget);
      expect(find.text('가장 가까운 사람'), findsOneWidget);

      expect(find.widgetWithText(FilledButton, '이어하기'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '새 게임'), findsOneWidget);
      expect(find.text('새 게임'), findsOneWidget);
      expect(find.text('이어하기'), findsOneWidget);

      expect(find.text('사람들'), findsOneWidget);
      expect(find.text('호감 순'), findsOneWidget);
      final strip = tester.widget<CastStrip>(find.byType(CastStrip));
      expect(strip.entries.first.name, '서연');
      expect(strip.entries[1].name, '하늘');
      expect(strip.entries.last.mystery, isTrue);
      expect(find.text('♥42'), findsOneWidget);
      expect(find.text('???'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('히든은 호감이 생기면 이름으로 보인다', (tester) async {
      c.state!.rel('doyun').affection = 3;
      await c.save.save(c.state!);
      c.goHome();
      await showHome(tester);
      expect(find.text('???'), findsNothing);
      expect(find.text('도윤'), findsOneWidget);
      expect(find.text('♥3'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('앱을 새로 켠 것처럼 state 없이도 요약으로 그린다', (tester) async {
      c.state = null;
      await c.init();
      expect(c.state, isNull);
      expect(c.saveSummary, isNotNull);
      await showHome(tester);
      expect(find.text('D+37 / 100'), findsOneWidget);
      expect(find.textContaining('서연 ♥42'), findsOneWidget);
      expect(find.byType(HeartsRow), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('요약 대기 프레임은 placeholder 카드, 하트 줄 없음', (tester) async {
      // 세이브 파일은 있는데 아직 읽지 못한 첫 프레임을 흉내 낸다.
      c.state = null;
      c.saveSummary = null;
      await showHome(tester);
      expect(c.saveSummary, isNull);
      expect(find.text('저장된 회차'), findsOneWidget);
      expect(find.text('어젯밤: 불러오는 중…'), findsOneWidget);
      expect(find.byType(HeartsRow), findsNothing);
      expect(find.text('이어하기'), findsOneWidget);
      expect(find.text('새 게임'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('전원 호감 0 이면 아바타 대신 안내 문장', (tester) async {
      c.state!.rel('seoyeon').affection = 0;
      c.state!.rel('haneul').affection = 0;
      await c.save.save(c.state!);
      c.goHome();
      await showHome(tester);
      expect(find.text('아직 아무와도 가까워지지 않았다'), findsOneWidget);
      expect(find.text('가장 가까운 사람'), findsNothing);
      await unmount(tester);
    });
  });

  group('출석 줄', () {
    testWidgets('미수령 → 받기 → 수령, 다시 들어오면 수령 상태', (tester) async {
      await showHome(tester);
      expect(find.text('출석 보상 하트 +1'), findsOneWidget);
      expect(find.text('연속 1일째'), findsOneWidget);
      expect(find.text('받기'), findsOneWidget);
      // 보상은 홈 진입 때 이미 얹혔다. 세이브가 없으니 보류함으로.
      expect(c.pendingHearts, 1);
      expect(c.checkedInToday, isTrue);

      await tester.tap(find.text('받기'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('오늘 출석 완료'), findsOneWidget);
      expect(find.text('받기'), findsNothing);
      expect(find.text('하트 +1 은 새 게임을 시작하면 들어온다'), findsOneWidget);

      // 같은 날 다시 홈에 오면 바로 수령 상태.
      await unmount(tester);
      await showHome(tester);
      expect(find.text('오늘 출석 완료'), findsOneWidget);
      expect(find.text('받기'), findsNothing);
      expect(c.pendingHearts, 1, reason: '두 번 주면 안 된다');
      await unmount(tester);
    });

    testWidgets('세이브가 있으면 수령 부제가 연속 일수', (tester) async {
      await c.newGame(seed: 1);
      c.goHome();
      await showHome(tester);
      await tester.tap(find.text('받기'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('연속 1일째 · 내일 또 +1'), findsOneWidget);
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
      expect(find.text('다음 하트 15:00'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      now += 1000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('다음 하트 14:59'), findsOneWidget);

      now += 899 * 1000;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(c.saveSummary!.hearts, 5);
      expect(find.textContaining('다음 하트'), findsNothing);
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
      expect(find.textContaining('앨범  2 / ${all.length}'), findsOneWidget);
      expect(find.textContaining('다음 엔딩 힌트 · '), findsOneWidget);

      // 해피·굿·솔로를 다 보면 남은 것을 말한다.
      for (final e in all) {
        if (e.tier != 'bad' && e.tier != 'hidden') await c.save.addEnding(e.id);
      }
      c.endingAlbum = await c.save.loadEndings();
      c.goHome();
      await tester.pump();
      expect(find.text('남은 건 배드 엔딩과 히든뿐이다'), findsOneWidget);

      for (final e in all) {
        await c.save.addEnding(e.id);
      }
      c.endingAlbum = await c.save.loadEndings();
      c.goHome();
      await tester.pump();
      expect(find.textContaining('앨범  ${all.length} / ${all.length}'), findsOneWidget);
      expect(find.text('모든 엔딩을 봤다'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('설정', () {
    testWidgets('헤더 아이콘으로 진입, 항목이 규격 순서로 있다', (tester) async {
      await showHome(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('설정'), findsOneWidget);
      // 광고 미지원 환경(테스트)에서는 UMP 행이 없다.
      expect(find.text('개인정보 설정'), findsNothing);
      final titles = [
        '개인정보처리방침',
        '오픈소스 라이선스',
        '서체',
        '앱 버전',
        '저장 데이터 초기화',
      ];
      double lastTop = -1;
      for (final t in titles) {
        final rect = tester.getRect(find.text(t));
        expect(rect.top, greaterThan(lastTop), reason: '$t 순서');
        lastTop = rect.top;
      }
      expect(find.text('Pretendard · SIL Open Font License 1.1'), findsOneWidget);
      expect(find.text('OFL'), findsOneWidget);
      expect(find.text(AppMeta.versionLabel), findsOneWidget);
      expect(find.text('© 2026 모쏠 키우기'), findsOneWidget);

      // 서체·앱 버전 행은 눌리지 않는다.
      final rows = tester.widgetList<AppListRow>(find.byType(AppListRow)).toList();
      expect(rows.firstWhere((r) => r.title == '서체').onTap, isNull);
      expect(rows.firstWhere((r) => r.title == '앱 버전').onTap, isNull);
      expect(rows.firstWhere((r) => r.title == '저장 데이터 초기화').tone, AppTone.danger);
      await unmount(tester);
    });

    testWidgets('개인정보처리방침을 못 열면 주소를 보여 준다', (tester) async {
      final launcher = _NoBrowser();
      UrlLauncherPlatform.instance = launcher;
      await tester.pumpWidget(wrapApp(SettingsScreen(c: c)));
      await tester.tap(find.text('개인정보처리방침'));
      await tester.pumpAndSettle();
      expect(launcher.launched, [AppLinks.privacyPolicy]);
      expect(find.text('링크를 열 수 없어요'), findsOneWidget);
      expect(find.text(AppLinks.privacyPolicy), findsOneWidget);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.text('링크를 열 수 없어요'), findsNothing);
    });

    testWidgets('저장 데이터 초기화: 취소는 그대로, 지우기는 홈을 첫 실행 상태로', (tester) async {
      await c.newGame(seed: 5);
      await c.save.addEnding(c.bundle.endings.first.id);
      c.endingAlbum = await c.save.loadEndings();
      c.goHome();
      await showHome(tester);
      expect(find.text('이어하기'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장 데이터 초기화'));
      await tester.pumpAndSettle();
      expect(find.textContaining('엔딩 앨범(1개)'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(c.hasSave, isTrue);
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.tap(find.text('저장 데이터 초기화'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('지우기'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text('저장 데이터를 지웠어요'), findsOneWidget);
      expect(c.hasSave, isFalse);
      expect(c.saveSummary, isNull);
      expect(c.endingAlbum, isEmpty);
      expect(c.streakDays, 0);
      expect(c.pendingHearts, 0);
      expect(await c.save.exists(), isFalse);
      expect(await c.save.loadEndings(), isEmpty);
      expect(find.widgetWithText(FilledButton, '새 게임'), findsOneWidget);
      expect(find.text('이어하기'), findsNothing);
      expect(find.textContaining('앨범  0 /'), findsOneWidget);
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
}
