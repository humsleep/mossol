// 100일 카운트다운(`DeadlineBand`)과 하루 정산 맨 위 자리.
//
// 근거: docs/review/11_story_verdict.md §2·4-3 — `D-xx` 가 화면에 뜨는 날이 100일 중
// **4~5일**이었다(D+1, D+7, 그다음은 빨라야 D+24). 정산은 100일 중 100일 지나가는
// 화면이므로, 이 파일이 보는 것은 "아무 날의 정산에나 D-xx 가 있는가" 다.
//
// 숫자의 축척은 대본이 정한다: `m_week1` 이 D+7 에 "오늘로 D-93", `d_bet_settle` 이
// 90일째에 "오늘부로 D-10" 이라고 말한다 — 즉 `D-(총일수 − 오늘)`. 화면이 대사와 다른
// 숫자를 말하면 둘 다 못 믿게 되므로 그 두 기준점을 그대로 시험한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/summary_screen.dart';
import 'package:mossol/ui/widgets.dart';

import 'helpers.dart';

void main() {
  late GameController c;

  setUp(() async {
    c = await makeController();
    await c.newGame(seed: 11, preference: Preference.female);
  });

  Future<void> showSummary(WidgetTester tester, int day) async {
    c
      ..state!.day = day
      ..phase = Phase.summary;
    await tester.pumpWidget(wrapApp(SummaryScreen(c: c)));
    await tester.pumpAndSettle();
  }

  testWidgets('정산 화면은 어느 날이든 D-xx 를 말한다 (100일 중 100일)', (tester) async {
    // 대사가 카운트다운을 말하지 않는 날들. 예전에는 이 날 화면 어디에도 없었다.
    for (final day in [1, 2, 7, 24, 50, 72, 99, 100]) {
      await showSummary(tester, day);
      final left = c.config.totalDays - day;
      expect(
        findText('D-$left'),
        findsOneWidget,
        reason: 'D+$day 정산에 카운트다운이 없다',
      );
      expect(findText('D+$day 정산'), findsOneWidget, reason: '§4.1 고정 문구');
      expect(find.byType(DeadlineBand), findsOneWidget);
    }
  });

  testWidgets('축척은 대본과 같다 — D+7 은 D-93, 90일째는 D-10', (tester) async {
    // assets/story/events_main.json `m_week1`: "오늘로 D-93".
    await showSummary(tester, 7);
    expect(findText('D-93'), findsOneWidget);
    expect(findText('93일 남았다'), findsOneWidget);

    // assets/story/events_daily.json `d_bet_settle`(90~100일): "오늘부로 D-10".
    await showSummary(tester, 90);
    expect(findText('D-10'), findsOneWidget);
  });

  testWidgets('마지막 날은 D-0 이고 "오늘이 마지막 날" 이라고 쓴다', (tester) async {
    await showSummary(tester, c.config.totalDays);
    expect(findText('D-0'), findsOneWidget);
    expect(findText('오늘이 마지막 날'), findsOneWidget);
    // 남은 날이 0 이어도 "0일 남았다" 라고 쓰지 않는다.
    expect(findText('0일 남았다'), findsNothing);
    expect(findText('엔딩 보기'), findsOneWidget);
  });

  testWidgets('마지막 10일은 색·아이콘·낱말 셋이 함께 바뀐다 (§4.2)', (tester) async {
    Icon iconOf(WidgetTester t) => t.widget<Icon>(
      find.descendant(
        of: find.byType(DeadlineBand),
        matching: find.byType(Icon),
      ),
    );

    await showSummary(tester, 80); // D-20 — 아직 평소
    expect(iconOf(tester).icon, Icons.hourglass_empty);
    final calm = iconOf(tester).color;

    await showSummary(tester, 90); // D-10 — 여기서부터 위험
    expect(iconOf(tester).icon, Icons.hourglass_bottom);
    expect(iconOf(tester).color, isNot(calm));
    // 낱말이 같이 말한다 — 색을 못 봐도 남은 날을 읽을 수 있다.
    expect(findText('10일 남았다'), findsOneWidget);
  });

  testWidgets('막대와 스크린리더 값은 지나온 날을 가리킨다', (tester) async {
    await showSummary(tester, 25);
    final bar = tester.widget<AppProgressBar>(
      find.descendant(
        of: find.byType(DeadlineBand),
        matching: find.byType(AppProgressBar),
      ),
    );
    expect(bar.value, closeTo(0.25, 0.001));
    expect(bar.semanticLabel, contains('25일째'));
    expect(bar.semanticLabel, contains('75일 남았다'));
  });

  testWidgets('남은 날 셈은 총일수를 벗어나지 않는다', (tester) async {
    expect(DeadlineBand.remaining(1, 100), 99);
    expect(DeadlineBand.remaining(100, 100), 0);
    // 마지막 날을 넘긴 상태(엔딩 직전 마감 뒤)로 들어와도 음수가 되지 않는다.
    expect(DeadlineBand.remaining(101, 100), 0);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode == ThemeMode.dark ? '다크' : '라이트';
    testWidgets('320x568 1.3배 $tag: 카운트다운이 넘치지 않는다', (tester) async {
      useSmallScreenLargeFont(tester);
      if (mode == ThemeMode.dark) useDarkMode(tester);
      // 가장 빡빡한 날: 관계 변화가 많고 카운트다운이 위험색인 날.
      for (final k in Stat.visible) {
        c.dayDelta.stats[k] = k == Stat.stress ? 12 : -7;
      }
      for (final ch in c.bundle.characters) {
        c.dayDelta.affection[ch.id] = 4;
      }
      c
        ..state!.day = c.config.totalDays - 3
        ..phase = Phase.summary;
      await tester.pumpWidget(wrapApp(SummaryScreen(c: c), mode: mode));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final band = tester.getRect(find.byType(DeadlineBand));
      expect(band.left, greaterThanOrEqualTo(0));
      expect(band.right, lessThanOrEqualTo(320));
      expect(findText('D-3'), findsOneWidget);
      final number = tester.getRect(findText('D-3'));
      expect(number.right, lessThanOrEqualTo(320));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    });
  }
}
