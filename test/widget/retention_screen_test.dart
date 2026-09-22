// 엔딩 "다음 판" 카드 · 정산 내일 예고 · 지난 판 요약 · 하트 없음 문구(docs/ROADMAP.md Phase 1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/analytics/analytics.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/retention.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/action_screen.dart';
import 'package:mossol/ui/ending_screen.dart';
import 'package:mossol/ui/preference_screen.dart';
import 'package:mossol/ui/retention_widgets.dart';
import 'package:mossol/ui/summary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<(GameController, RecordingAnalyticsBackend)> recorded() async {
  SharedPreferences.setMockInitialValues({});
  final rec = RecordingAnalyticsBackend();
  final c = GameController(
    bundle: testBundle(),
    save: SaveService(),
    analytics: Analytics(backend: rec),
  );
  await c.init();
  return (c, rec);
}

/// 여성 쪽 1회차를 마지막 날까지 건너뛰어 엔딩 화면에 둔다.
Future<GameController> endedRun(
  RecordingAnalyticsBackend? _,
  GameController c, {
  String? mbti,
}) async {
  if (mbti != null) await c.setPlayerMbti(mbti);
  await c.newGame(seed: 11, preference: Preference.female);
  c.state!.day = c.config.totalDays;
  await c.endDay();
  expect(c.phase, Phase.ending);
  return c;
}

void main() {
  group('엔딩 · 다음 판 카드', () {
    testWidgets('권하는 캐릭터 · 궁합 문장 · 힌트 · 반대쪽 링크 → 캐릭터를 누르면 다음 회차', (
      tester,
    ) async {
      final (c0, rec) = await recorded();
      final c = await endedRun(rec, c0, mbti: 'INFP');
      final next = c.nextRunSuggestion!;
      final ch = next.character!;
      await tester.pumpWidget(fullApp(c));
      await tester.pumpAndSettle();

      expect(find.byType(NextRunCard), findsOneWidget);
      expect(findText(NextRunCard.title), findsOneWidget);
      expect(findTextContaining('다음엔 ${ch.name}'), findsOneWidget);
      expect(findText(ch.tagline), findsOneWidget);
      expect(findText(next.reason), findsOneWidget);
      expect(
        next.reason,
        anyOf(NextRunAdvisor.destinyLine, NextRunAdvisor.goodMatchLine),
      );
      expect(find.byKey(const Key('next-run-hint')), findsOneWidget);
      expect(findText(NextRunCard.otherSideLabel), findsOneWidget);
      // 1차 버튼은 그대로 하나.
      expect(findText('2회차 시작'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('next-run-character')));
      await tester.tap(find.byKey(const Key('next-run-character')));
      await tester.pumpAndSettle();
      expect(c.phase, Phase.action);
      expect(c.state!.run, 2);
      expect(c.state!.preference, Preference.female);
      expect(rec.paramsOf(Analytics.nextRunSuggestionTapped).single, {
        'kind': 'character',
      });
      // 광고는 없다.
      expect(rec.paramsOf(Analytics.adRewardedShown), isEmpty);
      await tester.pumpWidget(Container());
    });

    testWidgets('반대쪽 캐릭터도 만나 보기 → 반대쪽 캐스트 → 시작하면 그 쪽 다음 회차', (tester) async {
      final (c0, rec) = await recorded();
      final c = await endedRun(rec, c0);
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(fullApp(c));
      await tester.pumpAndSettle();
      // MBTI 모름이면 중립 문장.
      expect(
        c.nextRunSuggestion!.reason,
        anyOf(NextRunAdvisor.neverLine, NextRunAdvisor.fewLine),
      );
      await tester.ensureVisible(find.byKey(const Key('next-run-other-side')));
      await tester.tap(find.byKey(const Key('next-run-other-side')));
      await tester.pumpAndSettle();
      expect(find.byType(PreferenceScreen), findsOneWidget);
      await tester.tap(findText(PreferenceScreen.startLabel));
      await tester.pumpAndSettle();
      expect(c.phase, Phase.action);
      expect(c.state!.preference, Preference.male);
      expect(c.state!.run, 2);
      expect(rec.paramsOf(Analytics.nextRunSuggestionTapped).single, {
        'kind': 'other_side',
      });
      await tester.pumpWidget(Container());
    });

    testWidgets('320×568 · 1.3배: 카드가 있어도 넘치지 않는다', (tester) async {
      final (c0, rec) = await recorded();
      final c = await endedRun(rec, c0, mbti: 'ESTJ');
      useSmallScreenLargeFont(tester);
      await tester.pumpWidget(wrapApp(EndingScreen(c: c)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(NextRunCard), findsOneWidget);
    });
  });

  group('정산 · 내일 예고', () {
    testWidgets('엔진이 내일 연락할 사람을 보면 그 이름으로 한 줄', (tester) async {
      GameController? found;
      TomorrowHint? hint;
      for (var seed = 1; seed < 30 && found == null; seed++) {
        final c = await makeController();
        await c.newGame(seed: seed, preference: Preference.female);
        await c.startDay(c.config.actions.first);
        for (var i = 0; i < 40 && c.phase == Phase.event; i++) {
          final open = c.choices.where((v) => !v.locked).toList();
          if (open.isNotEmpty) {
            c.choose(open.first.index, minigameSuccess: true);
          }
          c.continueAfterChoice();
        }
        final h = c.tomorrowHint;
        if (h != null) {
          found = c;
          hint = h;
        }
      }
      final c = found!;
      final name = c.characterName(hint!.characterId);
      await tester.pumpWidget(wrapApp(SummaryScreen(c: c)));
      await tester.pumpAndSettle();
      expect(find.byType(TomorrowLine), findsOneWidget);
      expect(findText(TomorrowPeek.lineFor(name)), findsOneWidget);
      expect(
        find.byKey(const Key('tomorrow-preview')),
        hint.preview == null ? findsNothing : findsOneWidget,
      );
    });

    testWidgets('마지막 날 정산에는 예고가 없다', (tester) async {
      final c = await makeController();
      await c.newGame(seed: 2);
      c
        ..state!.day = c.config.totalDays
        ..phase = Phase.summary;
      await tester.pumpWidget(wrapApp(SummaryScreen(c: c)));
      await tester.pumpAndSettle();
      expect(find.byType(TomorrowLine), findsNothing);
      expect(findText('엔딩 보기'), findsOneWidget);
    });
  });

  group('지난 판 요약 · 하트 없음', () {
    testWidgets('2회차 첫날 행동 화면에 한 줄, 둘째 날부터는 없다', (tester) async {
      final (c0, rec) = await recorded();
      final c = await endedRun(rec, c0);
      final line = previousRunLineFor(c.bundle, c.ending!.id)!;
      await c.nextRun();
      c.state!.rouletteDay = c.state!.day;
      await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
      await tester.pumpAndSettle();
      expect(findText(line), findsOneWidget);

      c.state!
        ..day = 2
        ..rouletteDay = 2;
      await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
      await tester.pumpAndSettle();
      expect(find.byType(PreviousRunNote), findsNothing);
    });

    testWidgets('엔딩 뒤 홈(세이브 없음)에도 한 줄', (tester) async {
      final (c0, rec) = await recorded();
      final c = await endedRun(rec, c0);
      c.goHome();
      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      expect(
        findText(previousRunLineFor(c.bundle, c.ending!.id)!),
        findsOneWidget,
      );
      await tester.pumpWidget(Container());
    });

    test('하트 없음 문구: 남은 분을 올려서, 0 이면 곧', () {
      expect(heartEmptyBody(61), startsWith('하트는 2분 뒤 1개 찬다.'));
      expect(heartEmptyBody(900), startsWith('하트는 15분 뒤 1개 찬다.'));
      expect(heartEmptyBody(0), startsWith('하트는 곧 1개 찬다.'));
    });
  });
}
