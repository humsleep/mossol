// 개편 2 · 3라운드 화면 회귀(docs/overhaul2/review/r3_bugs.md R3-3, 범위 밖 1).
// r3_scripts/zz_r3_ui_test 정식화. 메인 세션이 고친 것의 회귀 테스트다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/analytics/analytics.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/heat_gauge.dart';

import 'helpers.dart';

List<String> _errors(WidgetTester tester) {
  final out = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    out.add('$e'.split('\n').first);
  }
  return out;
}

void main() {
  testWidgets('무료 건너뛰기를 한 프레임에 두 번 눌러도 한 줄만, 기록도 한 번 (R3-3)', (tester) async {
    final rec = RecordingAnalyticsBackend();
    final old = Analytics.instance.backend;
    Analytics.instance.backend = rec;
    addTearDown(() => Analytics.instance.backend = old);
    final c = await makeController();
    await c.newGame(seed: 11, preference: Preference.female);
    final ev = StoryEvent.fromJson({
      'id': 'r3_wait',
      'layer': 'daily',
      'lines': [
        {'who': 'them', 'text': '하나'},
        {'who': 'sys', 'wait': 30},
        {'who': 'sys', 'wait': 30},
        {'who': 'them', 'text': '둘'},
      ],
      'choices': [
        {'text': '가'},
        {'text': '나'},
      ],
    });
    c.meta!.seenEvents.add(ev.id);
    c.current = ev;
    c.revealed = 0;
    c.phase = Phase.event;
    await tester.pumpWidget(wrapApp(EventScreen(c: c)));
    await tester.pump(const Duration(seconds: 1));
    final skip = find.byKey(const Key('wait-free-skip'));
    expect(skip, findsOneWidget);
    final before = c.revealed;
    await tester.tap(skip);
    await tester.tap(skip, warnIfMissed: false);
    await tester.pump();
    expect(c.revealed, before + 1, reason: '두 번째 대기 줄까지 공짜로 넘지 않는다');
    expect(rec.paramsOf(Analytics.waitSkipFree).length, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(_errors(tester), isEmpty);
  });

  testWidgets('320pt · 배율 3.0: 진상 선택의 결과 칩(돈 +2.5만원 · 진상)이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final c = await makeController();
    await c.newGame(seed: 11, preference: Preference.female);
    final ev = StoryEvent.fromJson({
      'id': 'r3_villain',
      'layer': 'daily',
      'lines': [
        {'who': 'them', 'text': '어쩔래'},
      ],
      'choices': [
        {
          'text': '(진상) 판을 엎는다',
          'effects': {
            'stats': {'villain': 1, 'money': 25, 'reputation': -8},
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
    expect(_errors(tester), isEmpty);
  });
}
