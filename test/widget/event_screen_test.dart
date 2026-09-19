import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/event_screen.dart';

import 'helpers.dart';

void main() {
  late GameController c;

  setUp(() async {
    c = await makeController();
    await c.newGame(seed: 11);
  });

  /// 이벤트를 현재 이벤트로 꽂고 이벤트 화면만 띄운다.
  Future<void> showEvent(WidgetTester tester, String id, {bool revealed = false}) async {
    final ev = c.bundle.eventById[id]!;
    c.current = ev;
    c.revealed = revealed ? ev.lines.length : 0;
    c.phase = Phase.event;
    await tester.pumpWidget(wrapApp(EventScreen(c: c)));
  }

  testWidgets('잠긴 선택지는 비활성이고 요구 문구를 보여 준다', (tester) async {
    // m02 의 두 번째 선택지는 자존감 30 이 필요. 초기 자존감은 15.
    expect(c.state!.stat(Stat.esteem), lessThan(30));
    await showEvent(tester, 'm02', revealed: true);
    final locked = c.choices.firstWhere((v) => v.locked);
    expect(locked.reason, '자존감 30↑');
    expect(findText('자존감 30↑'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    final btn = tester.widget<OutlinedButton>(
        findWidgetWithText(OutlinedButton, locked.choice.text));
    expect(btn.onPressed, isNull);
    expect(btn.enabled, isFalse);

    // 눌러도 아무 일도 없다.
    await tester.tap(findWidgetWithText(OutlinedButton, locked.choice.text),
        warnIfMissed: false);
    await tester.pump();
    expect(c.lastOutcome, isNull);

    // 미니게임 선택지엔 라벨이 붙는다.
    expect(findText('표정 읽기'), findsOneWidget);
    expect(find.byIcon(Icons.sports_esports_outlined), findsOneWidget);
  });

  testWidgets('대사가 시간에 따라 자동 공개되고 마지막에 선택지가 뜬다', (tester) async {
    await showEvent(tester, 'm02');
    expect(c.revealed, 0);
    expect(findText('…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 850));
    expect(c.revealed, 1);
    expect(findText('야 프사 바꿨네 ㅋㅋ'), findsOneWidget);
    expect(findText('태현'), findsWidgets);
    await revealAll(tester, c);
    expect(find.byType(OutlinedButton), findsNWidgets(3));
    expect(findText('…'), findsNothing);
  });

  testWidgets('읽씹 대기: 카운트다운이 돌고 끝나면 자존감 -1, 다음 줄로 넘어간다', (tester) async {
    // m03 마지막 줄이 sys wait 20.
    final ev = c.bundle.eventById['m03']!;
    final waitIdx = ev.lines.indexWhere((l) => l.isWait);
    expect(waitIdx, greaterThan(0));
    final esteemBefore = c.state!.stat(Stat.esteem);

    await showEvent(tester, 'm03');
    // 대기 줄 직전까지 공개.
    for (var i = 0; i < 40 && c.revealed < waitIdx; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(c.revealed, waitIdx);
    await tester.pump(const Duration(seconds: 1));
    expect(findTextContaining('초째 답이 없다'), findsOneWidget);
    expect(findText('광고 보고 기다리지 않기'), findsOneWidget);
    final t1 = tester.widget<Text>(findTextContaining('초째 답이 없다')).data!;
    await tester.pump(const Duration(seconds: 3));
    final t2 = tester.widget<Text>(findTextContaining('초째 답이 없다')).data!;
    expect(t1, isNot(t2), reason: '카운트다운이 움직여야 한다');
    expect(c.revealed, waitIdx, reason: '대기 중엔 줄이 넘어가지 않는다');
    expect(c.state!.stat(Stat.esteem), esteemBefore);

    // 광고 미지원 환경에서 건너뛰기를 누르면 스낵바만 뜨고 대기는 계속된다.
    await tester.tap(findText('광고 보고 기다리지 않기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(findText('광고를 불러오지 못했어요.'), findsOneWidget);
    expect(c.revealed, waitIdx);

    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(c.revealed, greaterThan(waitIdx));
    expect(c.state!.stat(Stat.esteem), esteemBefore - 1);
    expect(findTextContaining('초째 답이 없다'), findsNothing);
    await revealAll(tester, c);
    expect(find.byType(OutlinedButton), findsNWidgets(3));
  });

  testWidgets('선택 → 결과 패널 → 계속 → 다음 이벤트/정산', (tester) async {
    await showEvent(tester, 'm01', revealed: true);
    final idx = plainChoiceIndex(c);
    await tester.tap(findWidgetWithText(OutlinedButton, c.current!.choices[idx].text));
    await tester.pump();
    expect(c.lastOutcome, isNotNull);
    await settleReplies(tester);
    expect(findText('계속'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    await tester.tap(findText('계속'));
    await tester.pump();
    // 큐가 비어 있으니 정산으로.
    expect(c.phase, Phase.summary);
  });

  testWidgets('결과 패널: 실패면 되돌리기 제안이 뜨고 광고 실패 시 그대로다', (tester) async {
    await showEvent(tester, 'm01', revealed: true);
    // 확률 60 선택지를 실패로 강제.
    c.choose(0, minigameSuccess: false);
    await tester.pump();
    await settleReplies(tester);
    expect(findText('실패…'), findsOneWidget);
    expect(c.canOfferUndo, isTrue);
    expect(findText('10초 전으로 (광고)'), findsOneWidget);
    await tester.tap(findText('10초 전으로 (광고)'));
    await tester.pump();
    expect(c.lastOutcome, isNotNull, reason: '광고 미지원이면 되돌리기 안 됨');
    // 되돌리기가 실제로 동작하면 선택지로 돌아간다.
    c.undoChoice();
    await tester.pump();
    expect(find.byType(OutlinedButton), findsNWidgets(3));
    expect(c.canOfferUndo, isFalse);
  });

  testWidgets('힌트 버튼은 hint 가 있는 이벤트에만 뜬다', (tester) async {
    final withHint = c.bundle.events.firstWhere((e) => e.hint != null);
    await showEvent(tester, withHint.id, revealed: true);
    expect(findText('태현에게 물어보기 (광고)'), findsOneWidget);
    c.revealHint();
    await tester.pump();
    expect(findText('태현에게 물어보기 (광고)'), findsNothing);
  });

  testWidgets('이벤트 화면을 내려도 타이머와 리스너가 남지 않는다', (tester) async {
    await showEvent(tester, 'm03');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    // 남은 타이머가 있으면 여기서 "pending timers" 로 실패한다.
    await tester.pump(const Duration(seconds: 30));
    // 리스너가 남아 있으면 setState after dispose 가 터진다.
    c.revealNext();
    expect(tester.takeException(), isNull);
  });

  testWidgets('선택 뒤 상대 반응이 타이핑 뒤에 한 줄씩 뜬다', (tester) async {
    final ev = StoryEvent.fromJson({
      'id': 't_reply',
      'layer': 'daily',
      'title': '반응 테스트',
      'lines': [
        {'who': 'them', 'text': '뭐 해?'},
      ],
      'choices': [
        {
          'text': '너 생각',
          'reply': ['헐', {'who': 'narr', 'text': '답장이 빨라졌다.'}],
        },
      ],
    });
    c.current = ev;
    c.revealed = ev.lines.length;
    c.phase = Phase.event;
    await tester.pumpWidget(wrapApp(EventScreen(c: c)));
    await tester.pump();

    await tester.tap(findWidgetWithText(OutlinedButton, '너 생각'));
    await tester.pump();
    expect(c.lastReply.length, 2);
    // 내 말풍선은 바로, 상대 반응은 아직.
    expect(findText('너 생각'), findsOneWidget);
    expect(findText('헐'), findsNothing);
    expect(findText('…'), findsOneWidget);
    // 결과 패널은 반응이 끝난 뒤에.
    expect(findText('계속'), findsNothing);

    await tester.pump(const Duration(milliseconds: 800));
    expect(findText('헐'), findsOneWidget);
    expect(findText('답장이 빨라졌다.'), findsNothing);

    await tester.pump(const Duration(milliseconds: 800));
    expect(findText('답장이 빨라졌다.'), findsOneWidget);
    expect(findText('…'), findsNothing);
    expect(findText('계속'), findsOneWidget);
    await tester.pumpWidget(Container());
  });
}
