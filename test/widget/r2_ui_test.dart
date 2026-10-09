// 개편 2 · 2라운드 화면(docs/overhaul2/review/r2_meeting.md §4 "엔진·UI").
// r2_scripts/zz_r2_villain_chip_test·zz_r2_ui_test 정식화.
//
// - E4 진상 칩(결과 패널·행동·정산), R2-4 "진상 +1" 경고색 칩이 사라졌는지
// - E5 빨리 감기(본 장면은 줄이 거의 한 번에, 탭하면 남은 줄을 바로)
// - E9 320pt 넘침 두 곳(정산 StatBars, 설정 "앱 버전") · 라이트/다크
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/action_screen.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/heat_gauge.dart';
import 'package:mossol/ui/settings_screen.dart';
import 'package:mossol/ui/summary_screen.dart';

import 'helpers.dart';

void _screen(
  WidgetTester tester,
  double scale, {
  Size size = const Size(320, 568),
  bool dark = false,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  if (dark) {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  }
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
}

List<String> _errors(WidgetTester tester) {
  final out = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    out.add('$e'.split('\n').first);
  }
  return out;
}

/// 모든 세로 스크롤을 끝까지 굴리며 넘침을 모은다.
Future<List<String>> _scrollAll(WidgetTester tester) async {
  final errs = _errors(tester);
  final scrollables = find.byType(Scrollable);
  for (var i = 0; i < scrollables.evaluate().length; i++) {
    final st = tester.state<ScrollableState>(scrollables.at(i));
    if (st.position.axis != Axis.vertical) continue;
    for (var k = 0; k < 40 && st.position.pixels < st.position.maxScrollExtent; k++) {
      st.position.jumpTo(
        (st.position.pixels + 200).clamp(0, st.position.maxScrollExtent),
      );
      await tester.pump();
      errs.addAll(_errors(tester));
    }
  }
  return errs;
}

StoryEvent _event(Map<String, dynamic> j) => StoryEvent.fromJson({
  'id': 'r2_probe',
  'layer': 'daily',
  'title': '확인',
  'choices': [
    {'text': '하나'},
    {'text': '둘'},
  ],
  ...j,
});

void main() {
  group('진상 칩 (E4, r2_bugs R2-4)', () {
    test('색 단계: 1 · 2~3 · 4~5 · 6+', () {
      expect([1, 2, 3, 4, 5, 6, 40].map(VillainChip.levelOf), [0, 1, 1, 2, 2, 3, 3]);
      expect(VillainChip.shows(0), isFalse);
      expect(VillainChip.label(3), '진상 3');
    });

    testWidgets('결과 패널: 경고색 "진상 +1" 칩 대신 진상 칩', (tester) async {
      final c = await makeController();
      await c.newGame(preference: Preference.female, seed: 11);
      final ev = _event({
        'lines': [
          {'who': 'them', 'text': '어쩔래'},
        ],
        'choices': [
          {
            'text': '(진상) 판을 엎는다',
            'effects': {
              'stats': {'villain': 1, 'money': 25},
            },
          },
          {'text': '참는다'},
        ],
      });
      c.current = ev;
      c.revealed = ev.lines.length;
      c.phase = Phase.event;
      await tester.pumpWidget(wrapApp(EventScreen(c: c)));
      await tester.pump();
      c.choose(0);
      await tester.pump();
      await settleReplies(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(VillainChip), findsOneWidget);
      expect(findTextContaining('진상 1'), findsOneWidget);
      expect(findTextContaining('진상 +1'), findsNothing);
      expect(findTextContaining('돈 +2.5만원'), findsOneWidget, reason: '다른 칩은 그대로');
    });

    for (final dark in [false, true]) {
      testWidgets('행동·정산: 진상 1 이상이면 게이지 옆에, 0 이면 없다 (${dark ? '다크' : '라이트'})', (
        tester,
      ) async {
        _screen(tester, 2.0, dark: dark);
        final c = await makeController();
        await c.newGame(preference: Preference.female, seed: 1);
        c.beginMorning();
        await tester.pumpWidget(wrapApp(ActionScreen(c: c), mode: dark ? ThemeMode.dark : ThemeMode.light));
        await tester.pumpAndSettle();
        expect(find.byType(VillainChip), findsNothing);
        c.state!.stats[Stat.villain] = 6;
        c.state!.stats[Stat.heat] = 72;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(wrapApp(ActionScreen(c: c), mode: dark ? ThemeMode.dark : ThemeMode.light));
        await tester.pumpAndSettle();
        expect(find.byType(VillainChip), findsOneWidget);
        expect(await _scrollAll(tester), isEmpty);

        await c.startDay(c.config.actions.first);
        while (c.phase == Phase.event) {
          c.choose(plainChoiceIndex(c));
          c.continueAfterChoice();
        }
        c.dayDelta.stats[Stat.villain] = 2;
        c.dayDelta.stats[Stat.heat] = 25;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(wrapApp(SummaryScreen(c: c), mode: dark ? ThemeMode.dark : ThemeMode.light));
        await tester.pump(const Duration(seconds: 3));
        expect(findTextContaining('진상 6 (+2)'), findsOneWidget);
        expect(await _scrollAll(tester), isEmpty);
      });
    }
  });

  group('빨리 감기 (E5)', () {
    late GameController c;
    setUp(() async {
      c = await makeController();
      await c.newGame(seed: 11, preference: Preference.female);
    });

    final ev = _event({
      'lines': [
        for (var i = 0; i < 6; i++) {'who': 'them', 'text': '긴 대사 번호 $i 입니다 정말로 길게'},
      ],
    });

    Future<void> show(WidgetTester tester) async {
      c.current = ev;
      c.revealed = 0;
      c.phase = Phase.event;
      await tester.pumpWidget(wrapApp(EventScreen(c: c)));
    }

    testWidgets('처음 보는 장면은 타이핑 박자 그대로', (tester) async {
      await show(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.canFastForward, isFalse);
      expect(c.revealed, lessThanOrEqualTo(1));
    });

    testWidgets('이전 회차에서 본 장면은 1초 안에 다 쌓인다', (tester) async {
      c.meta!.seenEvents.add(ev.id);
      await show(tester);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(c.canFastForward, isTrue);
      expect(c.linesDone, isTrue);
    });

    testWidgets('본 장면에서 대화를 탭하면 남은 줄이 바로 열린다(대기 줄 앞까지)', (tester) async {
      final waitEv = _event({
        'id': 'r2_wait',
        'lines': [
          {'who': 'them', 'text': '하나'},
          {'who': 'them', 'text': '둘'},
          {'who': 'sys', 'wait': 30},
          {'who': 'them', 'text': '셋'},
        ],
      });
      c.meta!.seenEvents.add(waitEv.id);
      c.current = waitEv;
      c.revealed = 0;
      c.phase = Phase.event;
      await tester.pumpWidget(wrapApp(EventScreen(c: c)));
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-tap')), warnIfMissed: false);
      await tester.pump();
      expect(c.revealed, 2, reason: '대기 줄 앞에서 멈춘다');
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('wait-free-skip')), findsOneWidget);
      await tester.tap(find.byKey(const Key('wait-free-skip')));
      await tester.pump(const Duration(seconds: 1));
      expect(c.linesDone, isTrue);
    });
  });

  group('320pt 넘침 (r2_bugs 범위 밖 3·4)', () {
    for (final dark in [false, true]) {
      for (final scale in [1.6, 2.0]) {
        testWidgets('정산 StatBars ×$scale ${dark ? '다크' : '라이트'}', (tester) async {
          _screen(tester, scale, dark: dark);
          final c = await makeController();
          await c.newGame(preference: Preference.female, seed: 1);
          c.beginMorning();
          await c.startDay(c.config.actions.first);
          while (c.phase == Phase.event) {
            c.choose(plainChoiceIndex(c));
            c.continueAfterChoice();
          }
          for (final k in Stat.visible) {
            c.dayDelta.stats[k] = k == Stat.money ? -150 : 12;
          }
          c.state!.stats[Stat.money] = 9999;
          await tester.pumpWidget(
            wrapApp(SummaryScreen(c: c), mode: dark ? ThemeMode.dark : ThemeMode.light),
          );
          await tester.pump(const Duration(seconds: 3));
          expect(await _scrollAll(tester), isEmpty);
        });
      }
    }

    for (final scale in [1.8, 2.0]) {
      testWidgets('설정 "앱 버전" ×$scale', (tester) async {
        _screen(tester, scale);
        final c = await makeController();
        await tester.pumpWidget(wrapApp(SettingsScreen(c: c)));
        await tester.pumpAndSettle();
        expect(await _scrollAll(tester), isEmpty);
      });
    }
  });
}
