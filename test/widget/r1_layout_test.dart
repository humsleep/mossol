// 개편 2 · 1라운드 회귀(docs/overhaul2/review/r1_scripts/zz_r1_ui_test 를 정식화).
// 시작 카드 시트·소문 게이지·정산·홈·행동 화면이 작은 화면 + 큰 글자에서 넘치지 않는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/action_screen.dart';
import 'package:mossol/ui/heat_gauge.dart';
import 'package:mossol/ui/start_pick_sheet.dart';
import 'package:mossol/ui/summary_screen.dart';

import 'helpers.dart';

void _screen(
  WidgetTester tester,
  double scale, {
  Size size = const Size(320, 568),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
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

Future<GameController> _dayOne(String start, {int seed = 1}) async {
  final c = await makeController();
  await c.newGame(preference: Preference.female, seed: seed, start: start);
  c.beginMorning();
  await c.startDay(c.config.actions.first);
  while (c.phase == Phase.event) {
    c.choose(plainChoiceIndex(c));
    c.continueAfterChoice();
  }
  return c;
}

void main() {
  group('시작 카드 시트 320×568', () {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('배율 $scale: 카드 전부와 운명 카드까지 굴려도 넘치지 않는다', (tester) async {
        _screen(tester, scale);
        final b = testBundle();
        await tester.pumpWidget(
          wrapApp(
            Scaffold(
              body: StartPickSheet(
                starts: b.starts,
                endingCount: 0,
                firstRun: true,
                charNames: b.charNames,
                newIds: const {'sc_swap'},
                fateLocked: 'sc_ghost',
                suggestedId: 'sc_leak',
                endingsByStart: const {'classic': 7, 'sc_leak': 1},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final errs = _errors(tester);
        for (final k in [
          'start-fate',
          for (final s in b.starts) 'start-card-${s.id}',
        ]) {
          await scrollStartSheetTo(tester, find.byKey(Key(k)));
          errs.addAll(_errors(tester));
        }
        expect(errs, isEmpty);
      });
    }

    testWidgets('운명 결과 연출도 320 · 2.0 에서 넘치지 않는다', (tester) async {
      _screen(tester, 2.0);
      final b = testBundle();
      await tester.pumpWidget(
        wrapApp(
          Scaffold(
            body: StartPickSheet(starts: b.starts, endingCount: 0),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('start-fate')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('start-fate-reveal')), findsOneWidget);
      expect(_errors(tester), isEmpty);
    });
  });

  group('소문 게이지 (r1_bugs R1-1)', () {
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('정산 폭 248, 배율 $scale, 변화량 + 밤사이: 넘치지 않는다', (tester) async {
        _screen(tester, scale);
        await tester.pumpWidget(
          wrapApp(
            const Scaffold(
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: HeatGauge(heat: 88, delta: 15, overnight: -1),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: HeatGauge(heat: 45),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_errors(tester), isEmpty);
        expect(find.text(HeatGauge.overnightLabel(-1)), findsOneWidget);
      });
    }

    for (final (w, h, scale) in [
      (320.0, 568.0, 1.0),
      (320.0, 568.0, 1.3),
      (375.0, 667.0, 1.3),
      (390.0, 844.0, 1.6),
    ]) {
      testWidgets('실제 정산 화면 $w×$h · $scale · 소문 90 오늘 +25', (tester) async {
        _screen(tester, scale, size: Size(w, h));
        final c = await _dayOne('sc_clip');
        c.state!.stats[Stat.heat] = 90;
        c.dayDelta.stats[Stat.heat] = 25;
        await tester.pumpWidget(wrapApp(SummaryScreen(c: c)));
        await tester.pump(const Duration(seconds: 3));
        final g = find.byType(HeatGauge);
        expect(g, findsOneWidget);
        await tester.ensureVisible(g);
        await tester.pump(const Duration(seconds: 2));
        expect(_errors(tester), isEmpty);
      });
    }
  });

  group('홈 320 (r1_bugs 범위 밖: 2.0 에서 34px 넘침)', () {
    for (final (scale, heat) in [(1.0, 90), (1.6, 90), (2.0, 90), (2.0, 0)]) {
      testWidgets('배율 $scale · 소문 $heat', (tester) async {
        _screen(tester, scale);
        final c = await makeController();
        await c.newGame(
          preference: Preference.female,
          seed: 1,
          start: heat == 0 ? StartScenario.classic : 'sc_clip',
        );
        c.state!.stats[Stat.heat] = heat;
        c.goHome();
        await tester.pumpWidget(fullApp(c));
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(HeatGauge), heat > 0 ? findsOneWidget : findsNothing);
        expect(_errors(tester), isEmpty);
      });
    }
  });

  group('행동 화면 소문 (r1_playtest P1-3)', () {
    testWidgets('소문 있는 회차: 게이지와 휴식 "소문 -6", 320 · 1.3 에서 넘치지 않는다', (
      tester,
    ) async {
      useSmallScreenLargeFont(tester);
      final c = await makeController();
      await c.newGame(preference: Preference.female, seed: 1, start: 'sc_leak');
      c.beginMorning();
      expect(c.state!.stat(Stat.heat), greaterThan(0));
      await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('action-heat')), findsOneWidget);
      final rest = c.config.actions.firstWhere((a) => a.id == 'rest');
      final sub = actionSubtitle(rest, heat: c.state!.stat(Stat.heat));
      expect(sub, contains('소문 -6'));
      // 소문 정보는 소문 회차의 덧붙임 한 번뿐이다(r2_bugs R2-7). 설명 자체에는 없다.
      expect(rest.desc, isNot(contains('소문')));
      expect('소문'.allMatches(sub).length, 1);
      expect(_errors(tester), isEmpty);
      // 행동 목록까지 한 화면에 보이게 키워서 휴식 설명을 확인한다.
      tester.view.physicalSize = const Size(320, 2400);
      await tester.pumpAndSettle();
      expect(findText(sub), findsOneWidget);
      expect(_errors(tester), isEmpty);
    });

    testWidgets('클래식(소문 0): 게이지도 "소문" 덧붙임도 없다', (tester) async {
      final c = await makeController();
      await c.newGame(preference: Preference.female, seed: 1);
      c.beginMorning();
      await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('action-heat')), findsNothing);
      final rest = c.config.actions.firstWhere((a) => a.id == 'rest');
      expect(actionSubtitle(rest, heat: 0), rest.desc);
    });
  });
}
