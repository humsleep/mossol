/// 날짜 전환 카드(docs/overhaul/02_game_loop.md §2, lib/ui/day_card.dart).
///
/// 계약: `Phase.dayStart` 는 저장되지 않고, 카드는 `AnimationController` 하나로 돌아
/// `pumpAndSettle` 이 통과한다. 첫 350ms 탭 무시, 그 뒤 탭·박자 종료 → `beginMorning`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/audio/sfx_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/retention.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/action_screen.dart';
import 'package:mossol/ui/day_card.dart';
import 'package:mossol/ui/roulette_sheet.dart';

import 'helpers.dart';

/// 첫날을 엔진 호출로 정산까지 돌린다(화면 없이).
Future<void> playToSummary(GameController c) async {
  await c.startDay(c.config.actions.first);
  for (var i = 0; i < 40 && c.phase == Phase.event; i++) {
    final open = c.choices.where((v) => !v.locked).toList();
    if (open.isNotEmpty) c.choose(open.first.index, minigameSuccess: true);
    c.continueAfterChoice();
  }
  expect(c.phase, Phase.summary);
}

void main() {
  late GameController c;

  setUp(() async {
    c = await makeController();
  });

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(Container());
  }

  group('next 변형 (정산 → 다음 날)', () {
    Future<void> toDayTwo() async {
      await c.newGame(seed: 11, preference: Preference.female);
      c.beginMorning();
      c.state!.rouletteDay = c.state!.day;
      await playToSummary(c);
      await c.endDay();
    }

    testWidgets('endDay 는 행동이 아니라 dayStart 로 가고 카드가 D+2 · 2일째를 보여 준다', (
      tester,
    ) async {
      await toDayTwo();
      expect(c.phase, Phase.dayStart);
      expect(c.dayCard!.variant, DayCardVariant.next);
      expect(c.state!.day, 2);
      expect(c.dayCard!.weekday, '화요일');
      expect(['맑음', '흐림', '비'], contains(c.dayCard!.weather));

      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      expect(find.byKey(const Key('day-card')), findsOneWidget);
      expect(findText('D+2'), findsOneWidget);
      expect(findTextContaining('2일째'), findsOneWidget);
      expect(findTextContaining('화요일'), findsOneWidget);
      expect(findText('1장'), findsOneWidget, reason: '장 제목이 없으면 숫자만');
      expect(findText(DayTransitionScreen.skipHint), findsOneWidget);
      // 카드가 보이는 동안 행동 화면·룰렛은 트리에 없다.
      expect(find.byType(ActionScreen), findsNothing);
      expect(find.byType(RouletteSheet), findsNothing);
      expect(findText('오늘의 운'), findsNothing);
      // 기존 고정 문구와 충돌하지 않는다.
      expect(findText('D+2  ·  1장'), findsNothing);
      expect(findTextContaining('어젯밤: '), findsNothing);
      await unmount(tester);
    });

    testWidgets('350ms 안의 탭은 무시되고, 그 뒤의 탭은 곧바로 아침으로', (tester) async {
      await toDayTwo();
      await tester.pumpWidget(fullApp(c));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('day-card')));
      await tester.pump();
      expect(c.phase, Phase.dayStart, reason: '두 번째 탭 방지 구간');

      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('day-card')));
      await tester.pump();
      expect(c.phase, Phase.action);
      await tester.pump();
      expect(find.byKey(const Key('day-card')), findsNothing);
      expect(find.byType(ActionScreen), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('탭하지 않아도 1.4초 뒤 자동으로 넘어가고 룰렛이 뜬다', (tester) async {
      await toDayTwo();
      await tester.pumpWidget(fullApp(c));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(c.phase, Phase.dayStart);
      await tester.pump(const Duration(milliseconds: 150));
      expect(c.phase, Phase.action);
      // 카드가 완전히 사라진 뒤에야 룰렛.
      await spinRouletteSheet(tester);
      expect(findText('D+2  ·  1장'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('pumpAndSettle 만으로 카드를 지나 룰렛까지 간다(Timer 금지 계약)', (
      tester,
    ) async {
      await toDayTwo();
      await tester.pumpWidget(fullApp(c));
      await tester.pumpAndSettle();
      expect(c.phase, Phase.action);
      expect(findText('오늘의 운'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('동작 줄이기에서도 체류는 그대로이고 자동으로 넘어간다', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await toDayTwo();
      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      expect(find.byKey(const Key('day-card')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(c.phase, Phase.dayStart, reason: '체류는 1.4초 그대로');
      await tester.pump(const Duration(milliseconds: 450));
      expect(c.phase, Phase.action);
      await unmount(tester);
    });

    testWidgets('아침 효과음이 한 번 난다', (tester) async {
      final sfx = useRecordingSfx();
      await toDayTwo();
      sfx.clear();
      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      expect(sfx.played, [Sfx.dayStart]);
      expect(sfx.haptics, [HapticKind.light]);
      await unmount(tester);
    });

    testWidgets('beginMorning 은 멱등이다', (tester) async {
      await toDayTwo();
      var notified = 0;
      c.addListener(() => notified++);
      c.beginMorning();
      c.beginMorning();
      expect(c.phase, Phase.action);
      expect(notified, 1);
      c.phase = Phase.summary;
      c.beginMorning();
      expect(c.phase, Phase.summary, reason: 'dayStart 가 아니면 아무것도 안 한다');
    });

    test('정산의 내일 예고가 카드로 옮겨져 "오늘" 문장이 된다', () async {
      // 예고가 있는 시드를 찾는다(마감 전에 읽어야 한다 — 마감 뒤엔 모레가 된다).
      DayCard? card;
      String? name;
      for (var seed = 1; seed < 40 && card == null; seed++) {
        final k = await makeController();
        await k.newGame(seed: seed, preference: Preference.female);
        k.beginMorning();
        k.state!.rouletteDay = k.state!.day;
        await playToSummary(k);
        final hint = k.tomorrowHint;
        if (hint == null) continue;
        name = k.characterName(hint.characterId);
        await k.endDay();
        card = k.dayCard;
      }
      expect(card, isNotNull, reason: '40 시드 안에 예고가 있는 날이 없다');
      expect(card!.hintName, name);
      expect(TomorrowPeek.todayLineFor(name!), '오늘 $name에게서 연락이 올 것 같다');
    });

    test('마지막 날 마감은 카드 없이 엔딩으로', () async {
      await c.newGame(seed: 3, preference: Preference.female);
      c.beginMorning();
      c.state!.day = c.config.totalDays;
      await c.endDay();
      expect(c.phase, Phase.ending);
      expect(c.dayCard?.variant, isNot(DayCardVariant.next));
    });
  });

  group('first · resume 변형', () {
    testWidgets('새 게임은 first 카드: N회차 · 첫날, 지난 판 한 줄', (tester) async {
      await c.setPlayerMbti('INFP');
      await c.newGame(seed: 11, preference: Preference.female);
      c.state!.day = c.config.totalDays;
      await c.endDay();
      expect(c.phase, Phase.ending);
      await c.nextRun();
      expect(c.phase, Phase.dayStart);
      final card = c.dayCard!;
      expect(card.variant, DayCardVariant.first);
      expect(card.day, 1);
      expect(card.run, 2);
      expect(card.weekday, '월요일');
      expect(card.previousRunLine, c.previousRunLine);
      expect(card.hintName, isNull);
      expect(card.overnight, isNull);

      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      expect(findText('D+1'), findsOneWidget);
      expect(findTextContaining('2회차 · 첫날'), findsOneWidget);
      expect(findTextContaining('1일째'), findsNothing);
      expect(find.byKey(const Key('previous-run')), findsOneWidget);
      // 2.2초 체류.
      await tester.pump(const Duration(milliseconds: 2100));
      expect(c.phase, Phase.dayStart);
      await tester.pump(const Duration(milliseconds: 150));
      expect(c.phase, Phase.action);
      await unmount(tester);
    });

    testWidgets('이어하기(아침)는 resume 카드: 예고·밤사이 줄 없이 1초', (tester) async {
      await c.newGame(seed: 5, preference: Preference.female);
      c.beginMorning();
      c.state!.day = 4;
      await c.save.save(c.state!);
      c.goHome();
      await c.init();
      expect(await c.continueGame(), isTrue);
      expect(c.phase, Phase.dayStart);
      expect(c.dayCard!.variant, DayCardVariant.resume);
      expect(c.dayCard!.day, 4);

      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      expect(findText('D+4'), findsOneWidget);
      expect(findTextContaining('4일째'), findsOneWidget);
      expect(find.byKey(const Key('tomorrow-line')), findsNothing);
      expect(find.byKey(const Key('day-card-overnight')), findsNothing);
      await tester.pump(const Duration(milliseconds: 900));
      expect(c.phase, Phase.dayStart);
      await tester.pump(const Duration(milliseconds: 150));
      expect(c.phase, Phase.action);
      await unmount(tester);
    });

    test('하루 도중 이어하기는 카드 없이 남은 이벤트로', () async {
      await c.newGame(seed: 5, preference: Preference.female);
      c.beginMorning();
      c.state!.rouletteDay = c.state!.day;
      await c.startDay(c.config.actions.first);
      expect(c.phase, Phase.event);
      c.goHome();
      await c.init();
      expect(await c.continueGame(), isTrue);
      expect(c.phase, Phase.event);
      expect(c.dayCard?.variant, isNot(DayCardVariant.resume));
    });
  });

  group('요일 · 날씨', () {
    test('요일은 (day-1)%7, 날씨는 stableSeed 로 결정적이며 5장은 눈', () {
      expect(DayCard.weekdayFor(1), '월요일');
      expect(DayCard.weekdayFor(7), '일요일');
      expect(DayCard.weekdayFor(8), '월요일');
      expect(DayCard.weekdayFor(100), '화요일');
      final a = DayCard.weatherFor(7, 3, 1);
      expect(a, DayCard.weatherFor(7, 3, 1));
      final all = {for (var d = 1; d <= 80; d++) DayCard.weatherFor(7, d, 1)};
      expect(all, containsAll(['맑음', '흐림']));
      expect(all, isNot(contains('눈')));
      final late = {
        for (var d = 81; d <= 100; d++) DayCard.weatherFor(7, d, 5),
      };
      expect(late, isNot(contains('비')));
    });

    test('config 의 chapterTitles 는 선택이고 없으면 null', () {
      expect(c.config.chapterTitles, isEmpty);
      expect(c.config.chapterTitleFor(1), isNull);
      final cfg = GameConfig.fromJson({
        'chapterTitles': ['처음 보는 사람들', ''],
      });
      expect(cfg.chapterTitleFor(1), '처음 보는 사람들');
      expect(cfg.chapterTitleFor(2), isNull);
      expect(cfg.chapterTitleFor(3), isNull);
    });
  });
}
