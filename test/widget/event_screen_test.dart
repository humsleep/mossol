import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/call_view.dart';
import 'package:mossol/ui/design_system.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/widgets.dart';

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

  // ---- 카톡형 개편(docs/overhaul/03_chat_ui_spec.md §1·§2) ----

  /// 시각 라벨(`오후 4:12`)을 담은 Text.
  final timeText = find.byWidgetPredicate(
    (w) => w is Text && RegExp(r'^오[전후] \d{1,2}:\d{2}$').hasMatch(w.data ?? ''),
  );

  testWidgets('헤더는 이름 + 상태 한 줄, 제목·D+N 은 대화 첫 구분줄로', (tester) async {
    final ev = c.bundle.events.firstWhere(
      (e) =>
          e.character != null &&
          !e.isCall &&
          e.preview == null &&
          // 그룹 대화가 아닌 1:1(상태 줄이 '온라인').
          e.lines.every(
            (l) =>
                l.who != 'them' ||
                l.name == null ||
                l.name == c.characterName(e.character),
          ),
    );
    await showEvent(tester, ev.id, revealed: true);
    final name = c.characterName(ev.character);
    final appBar = find.byType(AppBar);
    expect(find.descendant(of: appBar, matching: findText(name)), findsOneWidget);
    expect(find.descendant(of: appBar, matching: findText('온라인')), findsOneWidget);
    expect(
      find.descendant(of: appBar, matching: find.byType(CharacterAvatar)),
      findsNothing,
      reason: '상단은 이름만',
    );
    expect(findText('D+1'), findsNothing, reason: 'D+N pill 없음');
    expect(find.descendant(of: appBar, matching: findText(ev.title)), findsNothing);
    expect(find.byType(ChatDivider), findsOneWidget);
    expect(findText('D+1 · ${ev.title}'), findsOneWidget);
    // 진행 막대는 유지.
    expect(find.byType(AppProgressBar), findsOneWidget);
  });

  testWidgets('독백 이벤트는 제목이 이름 자리, 상태 줄 없음', (tester) async {
    await showEvent(tester, 'm02', revealed: true);
    final appBar = find.byType(AppBar);
    expect(find.descendant(of: appBar, matching: findText('태현의 첫 조언')), findsOneWidget);
    expect(findText('온라인'), findsNothing);
    expect(findText('D+1 · 태현의 첫 조언'), findsOneWidget);
  });

  testWidgets('아바타는 묶음 첫 줄에만, 시각은 묶음 마지막 줄에만', (tester) async {
    // m02: 태현 ×3 → 나 → 태현. 묶음 셋(태현·나·태현), 상대 묶음 둘.
    await showEvent(tester, 'm02', revealed: true);
    expect(find.byType(ChatBubble), findsNWidgets(5));
    expect(find.byType(CharacterAvatar), findsNWidgets(2));
    Finder bubbleOf(String text) =>
        find.ancestor(of: findText(text), matching: find.byType(ChatBubble));
    expect(
      find.descendant(of: bubbleOf('야 프사 바꿨네 ㅋㅋ'), matching: find.byType(CharacterAvatar)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bubbleOf('근데 너 100일 안에 연애하려면 규칙 하나만 지켜'),
        matching: find.byType(CharacterAvatar),
      ),
      findsNothing,
      reason: '둘째 줄은 같은 폭 빈 칸',
    );
    // 시각: 묶음마다 마지막 줄 옆에 하나씩(분이 다르므로 셋 다 보인다).
    expect(timeText, findsNWidgets(3));
    expect(
      find.descendant(of: bubbleOf('답장 속도. 즉답은 초반엔 독이야'), matching: timeText),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bubbleOf('야 프사 바꿨네 ㅋㅋ'), matching: timeText),
      findsNothing,
    );
    // 내 말 뒤로 상대 줄이 공개됐으니 읽음. 숫자 배지는 없다.
    expect(
      find.descendant(of: bubbleOf('그럼 얼마나 기다려'), matching: findText('읽음')),
      findsOneWidget,
    );
    expect(findText('1'), findsNothing);
    // 이름 옆 색 점은 없다(아바타가 그 역할).
    expect(findText('태현'), findsNWidgets(2));
  });

  testWidgets('그룹 대화: 화자마다 아바타, 상태 줄은 온라인 · N명, 모르는 번호는 실루엣', (tester) async {
    final ev = StoryEvent.fromJson({
      'id': 't_group',
      'layer': 'daily',
      'character': 'seoyeon',
      'title': '단톡',
      'lines': [
        {'who': 'them', 'text': '다들 뭐 해'},
        {'who': 'them', 'name': '하늘', 'text': '나 지금 카페'},
        {'who': 'them', 'name': '모르는 번호', 'text': '안녕하세요'},
        {'who': 'them', 'name': '엄마', 'text': '밥은 먹었니'},
      ],
      'choices': [
        {'text': 'x', 'reply': 'ㅇㅇ'},
      ],
    });
    c.current = ev;
    c.revealed = ev.lines.length;
    c.phase = Phase.event;
    await tester.pumpWidget(wrapApp(EventScreen(c: c)));
    await tester.pump();
    expect(findText('온라인 · 5명'), findsOneWidget);
    final avatars = tester.widgetList<CharacterAvatar>(find.byType(CharacterAvatar)).toList();
    expect(avatars.length, 4);
    expect(avatars.map((a) => a.characterId), ['seoyeon', 'haneul', null, null]);
    expect(avatars.map((a) => a.mystery), [false, false, true, false]);
    expect(avatars.every((a) => a.size == AppSize.avatarMd), isTrue);
    // 상대 이름 Text 는 각각.
    expect(findText('하늘'), findsOneWidget);
    expect(findText('모르는 번호'), findsOneWidget);
    expect(findText('엄마'), findsOneWidget);
  });

  testWidgets('타이핑 표시는 다음 화자의 아바타를 달고, 지문 앞에서는 가운데 …', (tester) async {
    await showEvent(tester, 'm02');
    expect(find.byType(TypingIndicator), findsOneWidget);
    expect(findText('…'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(TypingIndicator), matching: find.byType(CharacterAvatar)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(TypingIndicator), matching: findText('태현')),
      findsOneWidget,
      reason: '첫 줄이라 이름도 붙는다',
    );
    await tester.pump(const Duration(milliseconds: 850));
    expect(c.revealed, 1);
    // 같은 화자가 이어 치는 중: 아바타 자리는 빈 칸.
    expect(
      find.descendant(of: find.byType(TypingIndicator), matching: find.byType(CharacterAvatar)),
      findsNothing,
    );
    expect(findText('…'), findsOneWidget);
    await tester.pumpWidget(Container());

    // m01 은 sys·narr 뿐 → 가운데 '…'(CallTyping).
    await showEvent(tester, 'm01');
    expect(find.byType(TypingIndicator), findsNothing);
    expect(find.byType(CallTyping), findsOneWidget);
    expect(findText('…'), findsOneWidget);
    await tester.pumpWidget(Container());
  });

  testWidgets('쓰다 지움: 가장 긴 상대 줄 앞에서 …이 한 번 사라졌다 다시 뜬 뒤 대사', (tester) async {
    final ev = StoryEvent.fromJson({
      'id': 't_erase',
      'layer': 'daily',
      'character': 'seoyeon',
      'title': '망설임',
      'lines': [
        {'who': 'them', 'text': '있잖아'},
        {'who': 'them', 'text': '아까 그 말은 사실 농담이 아니었어'},
        {'who': 'them', 'text': '응'},
      ],
      'choices': [
        {'text': 'x', 'reply': 'ㅇㅇ'},
      ],
    });
    c.current = ev;
    c.revealed = 0;
    c.phase = Phase.event;
    await tester.pumpWidget(wrapApp(EventScreen(c: c)));
    await tester.pump();
    // 1줄째: 짧으니 800ms.
    await tester.pump(const Duration(milliseconds: 800));
    expect(c.revealed, 1);
    // 2줄째(가장 김): … 700ms → 사라짐(140) → 600ms → … → 600+14×18=852ms → 대사.
    // 사라진 동안에도 '…' Text 는 하나(불투명도로만 숨긴다).
    await tester.pump(const Duration(milliseconds: 1000));
    expect(c.revealed, 1);
    expect(findText('…'), findsOneWidget);
    final hidden = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.byType(TypingIndicator), matching: find.byType(AnimatedOpacity)),
    );
    expect(hidden.opacity, 0);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(c.revealed, 1, reason: '아직 치는 중');
    final shown = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.byType(TypingIndicator), matching: find.byType(AnimatedOpacity)),
    );
    expect(shown.opacity, 1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.revealed, 2);
    // 3줄째: 이벤트당 1회라 다시 하지 않는다 → 800ms.
    await tester.pump(const Duration(milliseconds: 850));
    expect(c.revealed, 3);
    await tester.pumpWidget(Container());
  });

  testWidgets('동작 줄이기: 쓰다 지움 없이 지연만', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await showEvent(tester, 'm02');
    // 2줄째가 가장 길다(28자 → 1104ms). 지움 없이 그만큼만.
    await tester.pump(const Duration(milliseconds: 850));
    expect(c.revealed, 1);
    await tester.pump(const Duration(milliseconds: 1150));
    expect(c.revealed, 2);
    await tester.pumpWidget(Container());
  });

  testWidgets('읽음은 보낸 뒤 500ms(실패 1500ms) 지나 내 말풍선 옆에 낱말로', (tester) async {
    final ev = StoryEvent.fromJson({
      'id': 't_read',
      'layer': 'daily',
      'character': 'seoyeon',
      'title': '읽음',
      'lines': [
        {'who': 'them', 'text': '뭐 해?'},
      ],
      'choices': [
        {'text': '너 생각', 'reply': '헐'},
        {'text': '몰라', 'chance': 0, 'reply': '...'},
      ],
    });
    c.current = ev;
    c.revealed = ev.lines.length;
    c.phase = Phase.event;
    await tester.pumpWidget(wrapApp(EventScreen(c: c)));
    await tester.pump();
    await tester.tap(findWidgetWithText(OutlinedButton, '너 생각'));
    await tester.pump();
    expect(c.lastOutcome!.success, isTrue);
    expect(findText('읽음'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(findText('읽음'), findsNothing);
    await tester.pump(const Duration(milliseconds: 150));
    expect(findText('읽음'), findsOneWidget);
    await settleReplies(tester);
    // 되돌리면 같이 사라진다.
    c.undoChoice();
    await tester.pump();
    expect(findText('읽음'), findsNothing);

    // 실패 톤은 1500ms — "읽고 고민했다".
    await tester.tap(findWidgetWithText(OutlinedButton, '몰라'));
    await tester.pump();
    expect(c.lastOutcome!.success, isFalse);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(findText('읽음'), findsNothing);
    await tester.pump(const Duration(milliseconds: 150));
    expect(findText('읽음'), findsOneWidget);
    await settleReplies(tester);
    await tester.pumpWidget(Container());
  });

  test('가짜 시계: 이벤트 수별 시간대, 줄당 1분, wait 는 초만큼, 한국어 12시간 표기', () {
    expect(ChatClock.label(9 * 3600 + 5 * 60), '오전 9:05');
    expect(ChatClock.label(16 * 3600 + 12 * 60), '오후 4:12');
    expect(ChatClock.label(0), '오전 12:00');
    expect(ChatClock.label(12 * 3600), '오후 12:00');
    int hourOf(int i, int n) =>
        ChatClock.startSeconds(seed: 7, day: 3, index: i, total: n) ~/ 3600;
    expect([for (var i = 0; i < 4; i++) hourOf(i, 4)], [9, 12, 16, 21]);
    expect([for (var i = 0; i < 3; i++) hourOf(i, 3)], [10, 15, 21]);
    expect([for (var i = 0; i < 2; i++) hourOf(i, 2)], [12, 20]);
    expect(hourOf(0, 1), 19);
    expect(hourOf(0, 0), 19, reason: '큐를 모르면 저녁');
    // 분은 시드·날·순번으로 결정적.
    final a = ChatClock.startSeconds(seed: 7, day: 3, index: 1, total: 4);
    expect(a, ChatClock.startSeconds(seed: 7, day: 3, index: 1, total: 4));
    expect((a % 3600) ~/ 60, lessThan(60));
    final times = ChatClock.timesFor(const [
      Line(who: 'them', text: 'a'),
      Line(who: 'sys', wait: 20),
      Line(who: 'them', text: 'b'),
    ], 100);
    expect(times, [100, 160, 240]);
  });
}
