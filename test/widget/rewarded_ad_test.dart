// 보상형 광고를 기다리는 8초 동안의 화면(docs/review/01 P1-1 · 00 §1 ②).
//
// 실제로 일어난 사고: 힌트 버튼이 무반응으로 보여 다시 탭했더니 그 탭이 선택지에
// 떨어져 "읽씹" 이 확정됐다. 되돌리려면 광고를 한 번 더 봐야 했다.
// 그래서 광고를 부르는 자리는 전부 RewardedButton 하나를 쓰고, 대기 중에는
// 그 화면의 조작이 전부 막힌다. 자리마다 따로 짜면 또 갈라진다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/widgets.dart';

import 'helpers.dart';

void main() {
  late GameController c;
  Completer<bool>? ad;
  late List<String> placements;

  setUp(() async {
    c = await makeController();
    await c.newGame(seed: 11);
    ad = null;
    placements = [];
    // 느린 광고. 실기기에서는 최대 8초(AdManager 의 대기)가 이 자리다.
    // Completer 는 테스트 본문(가짜 시계 영역) 안에서 만들어야 pump 로 풀린다.
    debugRewarded = (p) {
      placements.add(p);
      return (ad = Completer<bool>()).future;
    };
    addTearDown(() => debugRewarded = null);
  });

  Future<void> showEvent(
    WidgetTester tester,
    String id, {
    bool revealed = false,
  }) async {
    final ev = c.bundle.eventById[id]!;
    c.current = ev;
    c.revealed = revealed ? ev.lines.length : 0;
    c.phase = Phase.event;
    await tester.pumpWidget(wrapApp(EventScreen(c: c)));
    await tester.pump();
  }

  testWidgets('힌트 광고를 기다리는 동안 버튼은 로딩, 선택지는 잠긴다', (tester) async {
    final withHint = c.bundle.events.firstWhere(
      (e) => e.hint != null && !e.isCall,
    );
    await showEvent(tester, withHint.id, revealed: true);
    await tester.tap(findText('태현에게 물어보기 (광고)'));
    await tester.pump();

    expect(placements, ['hint']);
    expect(findText(adLoadingLabel), findsOneWidget);
    expect(findText('태현에게 물어보기 (광고)'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 여기서 두 번째 탭이 선택지에 떨어지면 안 된다 — 이게 실제로 났던 사고다.
    final first = c.choices.firstWhere((v) => !v.locked).choice;
    await tester.tap(
      findWidgetWithText(OutlinedButton, first.text),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(c.lastOutcome, isNull, reason: '광고를 기다리는 동안은 선택이 확정되지 않는다');

    // 광고를 못 받았으면 이유를 말하고 버튼은 되돌아온다.
    ad!.complete(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(findTextContaining('광고를 불러오지 못했어요'), findsOneWidget);
    expect(findText('태현에게 물어보기 (광고)'), findsOneWidget);
    expect(c.hintIndex, isNull);

    // 잠금이 풀렸다.
    expect(
      tester
          .widgetList<AbsorbPointer>(find.byType(AbsorbPointer))
          .any((a) => a.absorbing),
      isFalse,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            findWidgetWithText(OutlinedButton, first.text),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(Container());
  });

  testWidgets('힌트 광고를 끝까지 보면 힌트가 열린다', (tester) async {
    final withHint = c.bundle.events.firstWhere(
      (e) => e.hint != null && !e.isCall,
    );
    await showEvent(tester, withHint.id, revealed: true);
    await tester.tap(findText('태현에게 물어보기 (광고)'));
    await tester.pump();
    ad!.complete(true);
    await tester.pump();
    await tester.pump();
    expect(c.hintIndex, isNotNull);
    expect(findText(adLoadingLabel), findsNothing);
    await tester.pumpWidget(Container());
  });

  testWidgets('되돌리기 광고를 기다리는 동안 계속 버튼도 막힌다', (tester) async {
    await showEvent(tester, 'm01', revealed: true);
    c.choose(0, minigameSuccess: false);
    await tester.pump();
    await settleReplies(tester);
    expect(findText('10초 전으로 (광고)'), findsOneWidget);

    await tester.tap(findText('10초 전으로 (광고)'));
    await tester.pump();
    expect(placements, ['undo']);
    expect(findText(adLoadingLabel), findsOneWidget);

    await tester.tap(findText('계속'), warnIfMissed: false);
    await tester.pump();
    expect(c.lastOutcome, isNotNull, reason: '광고 대기 중 계속이 눌리면 되돌릴 기회가 사라진다');

    ad!.complete(true);
    await tester.pump();
    await tester.pump();
    expect(c.lastOutcome, isNull, reason: '보상을 받았으면 선택 전으로');
    await tester.pumpWidget(Container());
  });

  testWidgets('읽씹 건너뛰기 광고를 기다리는 동안 카운트다운이 멈춘다', (tester) async {
    final ev = c.bundle.eventById['m03']!;
    final waitIdx = ev.lines.indexWhere((l) => l.isWait);
    await showEvent(tester, 'm03');
    for (var i = 0; i < 40 && c.revealed < waitIdx; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pump(const Duration(seconds: 1));
    final before = tester.widget<Text>(findTextContaining('초째 답이 없다')).data!;

    await tester.tap(findText('광고 보고 기다리지 않기'));
    await tester.pump();
    expect(placements, ['wait_skip']);
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<Text>(findTextContaining('초째 답이 없다')).data!,
      before,
      reason: '광고를 보고도 자존감이 깎이면 안 된다',
    );
    expect(c.revealed, waitIdx);

    // 실패하면 멈춘 그 초부터 다시 센다.
    ad!.complete(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(findTextContaining('광고를 불러오지 못했어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.widget<Text>(findTextContaining('초째 답이 없다')).data!,
      isNot(before),
    );
    await tester.pumpWidget(Container());
  });
}
