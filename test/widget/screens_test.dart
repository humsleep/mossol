import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/action_screen.dart';
import 'package:mossol/ui/album_screen.dart';
import 'package:mossol/ui/ending_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  late GameController c;

  setUp(() async {
    c = await makeController();
    await c.newGame(seed: 5);
  });

  group('행동 화면', () {
    testWidgets('하트 0 이면 행동 탭 시 다이얼로그가 뜬다', (tester) async {
      c.state!
        ..hearts = 0
        ..lastHeartMs = DateTime.now().millisecondsSinceEpoch
        ..rouletteDay = c.state!.day; // 룰렛 시트는 이미 돌린 걸로.
      await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 운'), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsNWidgets(c.config.maxHearts));
      expect(find.textContaining('다음 하트'), findsOneWidget);

      await tester.tap(find.text('헬스장'));
      await tester.pumpAndSettle();
      expect(find.text('하트가 없어요'), findsOneWidget);
      expect(c.phase, Phase.action);
      expect(c.hearts, 0);
      await tester.tap(find.text('기다릴게요'));
      await tester.pumpAndSettle();
      expect(find.text('하트가 없어요'), findsNothing);

      // 광고 보기를 눌러도 미지원 환경에선 스낵바만.
      await tester.tap(find.text('헬스장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('광고 보고 하트 받기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('광고를 불러오지 못했어요'), findsOneWidget);
      expect(c.hearts, 0);
    });

    testWidgets('룰렛 시트는 하루에 한 번만 뜨고 다시 빌드돼도 중복으로 안 뜬다', (tester) async {
      await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 운'), findsOneWidget);
      // 시트가 열린 채로 컨트롤러가 갱신되면 didUpdateWidget 이 다시 불린다.
      c.notifyListeners();
      await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 운'), findsOneWidget);
      await spinRouletteSheet(tester);
      c.notifyListeners();
      await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 운'), findsNothing);
    });

    testWidgets('하트 타이머가 1초마다 줄고 차면 하트가 는다 (회귀)', (tester) async {
      // 실기기: 행동 화면의 '다음 하트 12:48' 이 3분 넘게 그대로였다(타이머 없음).
      var now = DateTime(2026, 9, 18, 12).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({});
      final tc = GameController(
        bundle: testBundle(),
        save: SaveService(),
        clock: () => now,
      );
      await tc.init();
      await tc.newGame(seed: 3);
      tc.state!
        ..hearts = 2
        ..lastHeartMs = now
        ..rouletteDay = tc.state!.day; // 룰렛 시트가 뜨지 않게 오늘 몫을 이미 돌린 것으로.
      await tester.pumpWidget(wrapApp(ActionScreen(c: tc)));
      await tester.pump();
      expect(find.text('다음 하트 15:00'), findsOneWidget);

      now += 1000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('다음 하트 14:59'), findsOneWidget);

      now += 899 * 1000;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(tc.hearts, 3);
      expect(find.text('다음 하트 15:00'), findsOneWidget, reason: '다음 하트를 다시 센다');
      await tester.pumpWidget(Container());
    });

    testWidgets('콤보와 클리프행어, 관계 칩이 표시된다', (tester) async {
      c.state!
        ..combo = 3
        ..lastCliffhanger = '내일 서연이 먼저 연락한다고 했다'
        ..rouletteDay = c.state!.day;
      c.state!.rel('seoyeon').affection = 12;
      await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
      await tester.pumpAndSettle();
      expect(find.text('물올랐다 3'), findsOneWidget);
      expect(find.textContaining('어젯밤:'), findsOneWidget);
      expect(find.textContaining('서연 ♥12'), findsOneWidget);
      // 앨범으로 이동.
      await tester.tap(find.byIcon(Icons.photo_album_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumScreen), findsOneWidget);
    });
  });

  group('엔딩 화면', () {
    testWidgets('렌더링되고 "N회차 시작" 이 run 을 올린다', (tester) async {
      c.state!.day = c.config.totalDays;
      await c.endDay();
      expect(c.phase, Phase.ending);
      expect(c.ending, isNotNull);
      expect(c.hasSave, isFalse);
      expect(c.endingAlbum, contains(c.ending!.id));

      await tester.pumpWidget(fullApp(c));
      expect(find.byType(EndingScreen), findsOneWidget);
      expect(find.text(c.ending!.name), findsOneWidget);
      expect(find.text('연애 등급'), findsOneWidget);
      expect(find.text('2회차 시작'), findsOneWidget);

      // 새 회차가 시작되면 controller.ending 은 비워지므로 미리 잡아 둔다.
      final endedId = c.ending!.id;
      await tester.tap(find.text('2회차 시작'));
      await tester.pump();
      expect(c.phase, Phase.action);
      expect(c.state!.run, 2);
      expect(c.state!.day, 1);
      expect(c.state!.endings, contains(endedId), reason: '엔딩 앨범은 회차를 넘어 유지된다');
      await spinRouletteSheet(tester);
      expect(find.text('D+1  ·  1장'), findsOneWidget);
    });

    testWidgets('홈으로 가면 이어하기가 없다', (tester) async {
      c.state!.day = c.config.totalDays;
      await c.endDay();
      await tester.pumpWidget(fullApp(c));
      await tester.tap(find.text('홈으로'));
      await tester.pump();
      expect(c.phase, Phase.home);
      expect(find.text('이어하기'), findsNothing);
      expect(find.textContaining('앨범  1 /'), findsOneWidget);
    });
  });

  group('앨범 화면', () {
    testWidgets('흑역사가 없을 때', (tester) async {
      await tester.pumpWidget(wrapApp(AlbumScreen(c: c)));
      expect(find.text('아직 흑역사가 없다'), findsOneWidget);
      await tester.tap(find.text('엔딩'));
      await tester.pumpAndSettle();
      expect(find.text('0 / ${c.bundle.endings.length}'), findsOneWidget);
      expect(find.text('???'), findsWidgets);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
    });

    testWidgets('흑역사가 있을 때와 획득한 엔딩', (tester) async {
      c.state!.album.addAll(['술자리에서 노래 부름', '읽씹 당하고 3번 더 보냄']);
      final e = c.bundle.endings.first;
      await c.save.addEnding(e.id);
      c.endingAlbum = await c.save.loadEndings();
      await tester.pumpWidget(wrapApp(AlbumScreen(c: c)));
      expect(find.text('2 / 20'), findsOneWidget);
      expect(find.text('술자리에서 노래 부름'), findsOneWidget);
      expect(find.text('읽씹 당하고 3번 더 보냄'), findsOneWidget);
      await tester.tap(find.text('엔딩'));
      await tester.pumpAndSettle();
      expect(find.text('1 / ${c.bundle.endings.length}'), findsOneWidget);
      expect(find.text(e.name), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('state 가 없어도(홈에서 진입) 앨범이 뜬다', (tester) async {
      final fresh = await makeController();
      expect(fresh.state, isNull);
      await tester.pumpWidget(wrapApp(AlbumScreen(c: fresh)));
      expect(find.text('아직 흑역사가 없다'), findsOneWidget);
    });
  });

  group('정산 화면', () {
    testWidgets('변화량과 클리프행어를 보여 주고 다음 날로 넘어간다', (tester) async {
      c.dayDelta.stats[Stat.charm] = 3;
      c.dayDelta.affection['seoyeon'] = 4;
      c.cliffhanger = '내일은 뭔가 다르다';
      c.phase = Phase.summary;
      await tester.pumpWidget(fullApp(c));
      expect(find.text('D+1 정산'), findsOneWidget);
      // 라벨과 변화량을 나눠 변화량을 앞세운다. 둘 다 화면에 있어야 한다.
      expect(find.text('오늘의 변화'), findsOneWidget);
      expect(find.text('서연 호감'), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
      expect(find.text('내일은 뭔가 다르다'), findsOneWidget);
      // 매력 막대 옆에 변화량(+3)과 오늘 값이 따로 보인다.
      expect(find.text('+3'), findsOneWidget);
      expect(find.text('${c.state!.stat(Stat.charm)}'), findsWidgets);
      await tester.tap(find.text('다음 날로'));
      await tester.pump();
      expect(c.state!.day, 2);
      expect(c.phase, Phase.action);
      await spinRouletteSheet(tester);
    });
  });
}
