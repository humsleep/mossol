// 개편 2 · 1라운드 화면 흐름(docs/overhaul2/review/r1_meeting.md §4 "엔진·UI").
// r1_scripts/zz_r1_flow_test 정식화 + D5(빨리 감기·NEW)·D7(카드 도장·기본 선택)·D8(clock)·
// D10(운명 고정·결과 연출)·R1-6(온보딩 퍼널)·캐스트 소개 시작별.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/analytics/analytics.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/ending_screen.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/intro_screen.dart';
import 'package:mossol/ui/notification_card.dart';
import 'package:mossol/ui/preference_screen.dart';
import 'package:mossol/ui/settings_screen.dart';
import 'package:mossol/ui/start_pick_sheet.dart';
import 'package:mossol/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<void> _settleTyping(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    if (find.byType(TypingIndicator).evaluate().isEmpty) break;
    await tester.pump(const Duration(milliseconds: 2500));
  }
  await tester.pumpAndSettle();
}

/// 첫 실행 인트로를 시작 카드 시트까지.
Future<void> _introToSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('title-start')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.tap(find.byType(NotificationCard));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('intro-yes')));
  await _settleTyping(tester);
  await tester.pump(IntroScreen.startSheetDelay);
  await tester.pumpAndSettle();
  expect(find.byType(StartPickSheet), findsOneWidget);
}

/// 운명 카드를 눌러 결과를 보고 그 이야기로 시작한다.
Future<void> _drawFateAndGo(WidgetTester tester) async {
  await scrollStartSheetTo(tester, find.byKey(const Key('start-fate')));
  await tester.tap(find.byKey(const Key('start-fate')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('start-fate-reveal')), findsOneWidget);
  await tester.tap(find.byKey(const Key('start-fate-go')));
  await tester.pumpAndSettle();
}

StoryEvent _event(Map<String, dynamic> j) => StoryEvent.fromJson({
  'id': 'r1_probe',
  'layer': 'daily',
  'title': '확인',
  'choices': [
    {'text': '하나'},
    {'text': '둘'},
  ],
  ...j,
});

void main() {
  group('운명 고정 (D10, r1_bugs R1-2)', () {
    testWidgets('인트로: 운명 → "다른 일이었어" → 다시 열린 시트는 같은 운명에 고정, 퍼널은 한 번씩', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final rec = RecordingAnalyticsBackend();
      final c = GameController(
        bundle: testBundle(),
        save: SaveService(),
        analytics: Analytics(backend: rec),
      );
      await c.init();
      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      await _introToSheet(tester);
      await _drawFateAndGo(tester);
      await _settleTyping(tester);
      final fate = c.pendingFate;
      expect(fate, isNotNull);
      await tester.ensureVisible(find.byKey(const Key('intro-start-back')));
      await tester.tap(find.byKey(const Key('intro-start-back')));
      await tester.pumpAndSettle();
      final sheet = tester.widget<StartPickSheet>(find.byType(StartPickSheet));
      expect(sheet.fateLocked, fate);
      final title = c.bundle.startOf(fate!)!.title;
      expect(findText(StartPickSheet.fateDrawn(title)), findsOneWidget);
      // 운명 카드를 다시 눌러도 같은 시작이다(결과 연출 없이 바로).
      await tester.tap(find.byKey(const Key('start-fate')));
      await tester.pumpAndSettle();
      await _settleTyping(tester);
      expect(findText(c.bundle.startOf(fate)!.introLine), findsOneWidget);
      final steps = [
        for (final p in rec.paramsOf(Analytics.onboardingStep)) p['step'],
      ];
      expect(steps.where((s) => s == Analytics.stepStart).length, 1);
      expect(steps.where((s) => s == Analytics.stepName).length, 1);
    });

    testWidgets('홈: 운명을 뽑고 시트를 닫아도 다음에 열면 같은 운명이다', (tester) async {
      final c = await makeController();
      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      await tester.tap(findText('새 게임'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-fate')));
      await tester.pumpAndSettle();
      final fate = c.pendingFate;
      expect(fate, isNotNull);
      // 결과만 보고 시트를 닫는다.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(StartPickSheet), findsNothing);
      await tester.tap(findText('새 게임'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<StartPickSheet>(find.byType(StartPickSheet)).fateLocked,
        fate,
      );
    });

    testWidgets('엔딩의 "다음 회차" 를 두 번 눌러도 시트는 하나', (tester) async {
      final c = await makeController();
      await c.newGame(preference: Preference.female, seed: 3);
      c.state!.day = c.config.totalDays;
      await c.endDay();
      expect(c.ending, isNotNull);
      await tester.pumpWidget(wrapApp(EndingScreen(c: c)));
      await tester.pump(const Duration(seconds: 5));
      final btn = findText('${c.state!.run + 1}회차 시작');
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.tap(btn, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(StartPickSheet), findsOneWidget);
    });
  });

  group('시작 카드 (D7·D9, r1_bugs R1-7, r1_playtest P2-2/3/5)', () {
    testWidgets('운명이 맨 위, 기본 선택이 그다음(강조), 배지 우선순위와 엔딩 도장', (tester) async {
      final b = testBundle();
      await tester.pumpWidget(
        wrapApp(
          Scaffold(
            body: StartPickSheet(
              starts: b.starts,
              endingCount: 3,
              suggestedId: 'sc_speech',
              newIds: const {'sc_swap'},
              endingsByStart: const {StartScenario.classic: 2, 'sc_swap': 1},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      double top(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
      expect(top('start-fate'), lessThan(top('start-card-sc_speech')));
      expect(
        StartPickSheet.ordered(b.starts, 'sc_speech').map((s) => s.id).take(2),
        ['sc_speech', StartScenario.classic],
      );
      // 클래식: 본 적 있음 + 도장 2개.
      final classic = find.byKey(const Key('start-card-classic'));
      await scrollStartSheetTo(tester, classic);
      expect(
        find.descendant(of: classic, matching: findText(StartPickSheet.seenBadge)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: classic, matching: find.byIcon(Icons.verified)),
        findsNWidgets(2),
      );
      // 새로 열림이 본 적 있음보다 먼저.
      final swap = find.byKey(const Key('start-card-sc_swap'));
      await scrollStartSheetTo(tester, swap);
      expect(
        find.descendant(of: swap, matching: findText(StartPickSheet.newBadge)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: swap, matching: find.byKey(const Key('start-stamps'))),
        findsOneWidget,
      );
    });

    testWidgets('첫 회차: "처음이라면" 은 기본 선택(recommended) 카드에', (tester) async {
      final b = testBundle();
      await tester.pumpWidget(
        wrapApp(
          Scaffold(
            body: StartPickSheet(
              starts: b.starts,
              endingCount: 0,
              firstRun: true,
              suggestedId: 'sc_leak',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final leak = find.byKey(const Key('start-card-sc_leak'));
      expect(
        find.descendant(of: leak, matching: findText(StartPickSheet.firstBadge)),
        findsOneWidget,
      );
      expect(findText(StartPickSheet.firstBadge), findsOneWidget);
    });

    testWidgets('잠긴 카드 흐림은 그림 띠 안에서 잘린다', (tester) async {
      final b = testBundle();
      await tester.pumpWidget(
        wrapApp(
          Scaffold(body: StartPickSheet(starts: b.starts, endingCount: 0)),
        ),
      );
      final locked = find.byKey(const Key('start-card-sc_swap'));
      await scrollStartSheetTo(tester, locked);
      final blur = find.descendant(of: locked, matching: find.byType(ImageFiltered));
      expect(blur, findsOneWidget);
      expect(
        find.ancestor(of: blur, matching: find.byType(ClipRect)),
        findsWidgets,
      );
    });

    testWidgets('운명 결과: 잠긴 시작이 나오면 "이번 회차에만 열렸다"', (tester) async {
      final b = testBundle();
      final locked = b.starts.firstWhere((s) => !s.unlockedBy(0));
      StartPick? got;
      String? saved;
      await tester.pumpWidget(
        wrapApp(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () async => got = await StartPickSheet.show(
                ctx,
                starts: [locked],
                endingCount: 0,
                onFateDrawn: (id) async => saved = id,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-fate')));
      await tester.pumpAndSettle();
      expect(saved, locked.id, reason: '보여 주기 전에 저장');
      expect(findText(StartPickSheet.fateRevealLocked), findsOneWidget);
      expect(findText(locked.title), findsWidgets);
      await tester.tap(find.byKey(const Key('start-fate-go')));
      await tester.pumpAndSettle();
      expect(got, (id: locked.id, fate: true));
    });
  });

  group('이벤트 화면', () {
    late GameController c;
    setUp(() async {
      c = await makeController();
      await c.newGame(seed: 11, preference: Preference.female);
    });

    Future<void> show(WidgetTester tester, StoryEvent ev, {int revealed = 0}) async {
      c.current = ev;
      c.revealed = revealed;
      c.phase = Phase.event;
      await tester.pumpWidget(wrapApp(EventScreen(c: c)));
    }

    testWidgets('clock 이 있으면 말풍선 시각이 그 시각이다 (D8)', (tester) async {
      await show(
        tester,
        _event({
          'clock': '01:12',
          'lines': [
            {'who': 'them', 'text': '자?'},
          ],
        }),
      );
      await revealAll(tester, c);
      await tester.pumpAndSettle();
      expect(find.text('오전 1:12'), findsOneWidget);
    });

    final waitEvent = _event({
      'lines': [
        {'who': 'me', 'text': '뭐 해?'},
        {'who': 'sys', 'wait': 30},
        {'who': 'them', 'text': '이제 봤다'},
      ],
    });

    testWidgets('처음 보는 장면의 대기: 광고 버튼 그대로, 무료 건너뛰기 없음', (tester) async {
      await show(tester, waitEvent);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('wait-free-skip')), findsNothing);
      expect(find.byType(RewardedButton), findsOneWidget);
    });

    testWidgets('이전 회차에서 본 장면의 대기: 무료 건너뛰기(대가 없음), 설정을 끄면 광고 (D5)', (
      tester,
    ) async {
      // 지난 회차에서 본 장면(메타 seenEvents). 컨트롤러는 처음 물을 때 읽는다.
      c.meta!.seenEvents.add(waitEvent.id);
      await show(tester, waitEvent);
      await tester.pump(const Duration(seconds: 2));
      expect(c.canFreeSkipWait, isTrue);
      expect(find.byKey(const Key('wait-free-skip')), findsOneWidget);
      expect(find.byType(RewardedButton), findsNothing);
      final esteem = c.state!.stat(Stat.esteem);
      await tester.tap(find.byKey(const Key('wait-free-skip')));
      await tester.pump(const Duration(seconds: 3));
      expect(findText('이제 봤다'), findsOneWidget);
      expect(c.state!.stat(Stat.esteem), esteem, reason: '기다린 대가(자존감 −1) 없음');

      await c.setFastForwardSeen(false);
      await tester.pumpWidget(const SizedBox());
      await show(tester, waitEvent);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('wait-free-skip')), findsNothing);
      expect(find.byType(RewardedButton), findsOneWidget);
    });

    testWidgets('이전 회차에서 본 장면의 처음 보는 파급 줄·선택지에 NEW (D5)', (tester) async {
      final ev = _event({
        'lines': [
          {'who': 'them', 'text': '평소'},
          {'who': 'them', 'text': '갈래 줄', 'ifFlags': ['start_alt']},
        ],
        'choices': [
          {'text': '하나'},
          {'text': '둘'},
          {'text': '갈래 선택지', 'ifFlags': ['start_alt']},
        ],
      });
      c.meta!.seenEvents.add(ev.id);
      c.state!.flags.add(StartScenario.altFlag);
      await show(tester, ev);
      await revealAll(tester, c);
      await tester.pumpAndSettle();
      expect(find.byType(NewDot), findsNWidgets(2), reason: '줄 하나 + 선택지 하나');
      expect(
        find.ancestor(of: find.byType(NewDot), matching: find.byType(ChoiceButton)),
        findsOneWidget,
      );
    });
  });

  testWidgets('설정: 읽은 장면 빨리 감기 토글(기본 켬)', (tester) async {
    final c = await makeController();
    expect(c.fastForwardSeen, isTrue);
    await tester.pumpWidget(wrapApp(SettingsScreen(c: c)));
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('settings-fast-forward'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(c.fastForwardSeen, isFalse);
    expect(c.meta!.fastForwardSeen, isFalse);
  });

  testWidgets('캐스트 소개: 시작의 "먼저 다가오는 사람" 이 맨 앞, 표시가 붙는다', (tester) async {
    final b = testBundle();
    final leak = b.startOf('sc_leak')!;
    final first = leak.effects.affection.keys.firstWhere(
      (id) => b.characterById[id]!.gender == Preference.female,
    );
    final intros = PreferenceScreen.introsOf(b, Preference.female, start: 'sc_leak');
    expect(intros.first.id, first);
    expect(intros.first.comesFirst, isTrue);
    expect(intros.skip(1).any((e) => e.comesFirst), isFalse);
    final plain = PreferenceScreen.introsOf(b, Preference.female);
    expect(plain.any((e) => e.comesFirst), isFalse);
    await tester.pumpWidget(
      wrapApp(
        PreferenceScreen(bundle: b, side: Preference.female, start: 'sc_leak'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(Key('cast-first-$first')), findsOneWidget);
  });

  testWidgets('신규 시작 1일차 이벤트 화면이 뜬다', (tester) async {
    final c = await makeController();
    await c.newGame(preference: Preference.male, seed: 3, start: 'sc_leak');
    c.beginMorning();
    await c.startDay(c.config.actions.first);
    await tester.pumpWidget(fullApp(c));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(EventScreen), findsOneWidget);
  });
}
