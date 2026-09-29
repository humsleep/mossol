// 제한형 자유 입력 UI(docs/overhaul/07_free_input.md §3): 입력창 → 자동 확정 / 피커 / 잠김 / 무료 되돌리기 /
// 전송 상한 / 재생성·복원 뒤 말풍선. 선택지 버튼(OutlinedButton 3개)은 그대로다(DESIGN_SYSTEM §4.1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/analytics/analytics.dart';
import 'package:mossol/audio/sfx_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// 세 선택지가 태그로 또렷이 갈리는 합성 이벤트. 실제 데이터 튜닝에 흔들리지 않게 여기서 만든다.
final _ev = StoryEvent.fromJson({
  'id': 't_free',
  'layer': 'daily',
  'character': 'seoyeon',
  'title': '자유 입력',
  'lines': [
    {'who': 'them', 'text': '주말에 볼래?'},
  ],
  'choices': [
    {'text': '좋아 가자', 'reply': 'ㅇㅋ'},
    {'text': '오늘은 안 갈래', 'reply': '아쉽다'},
    {'text': '생각해 볼게', 'reply': '응'},
  ],
});

const _yes = '싫어 안 갈래';
const _input = Key('free-input');
const _send = Key('free-send');

void main() {
  late GameController c;
  late RecordingAnalyticsBackend rec;
  late RecordingSfxService sfx;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    rec = RecordingAnalyticsBackend();
    c = GameController(
      bundle: testBundle(),
      save: SaveService(),
      analytics: Analytics(backend: rec),
    );
    await c.init();
    await c.newGame(seed: 11);
    sfx = useRecordingSfx();
  });

  Future<void> show(WidgetTester tester, StoryEvent ev) async {
    c.current = ev;
    c.revealed = ev.lines.length;
    c.phase = Phase.event;
    await tester.pumpWidget(wrapApp(EventScreen(c: c)));
    await tester.pump();
  }

  /// 시트가 열리거나 닫히는 애니메이션을 흘린다. `pumpAndSettle` 은 통화 시계(주기 타이머) 때문에 안 쓴다.
  Future<void> settleSheet(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(_input), text);
    await tester.pump();
    await tester.tap(find.byKey(_send));
    await settleSheet(tester);
  }

  /// 보내기 잠금(1.2초)을 흘린다.
  Future<void> unlock(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 1300));

  Finder inSheet(String text) =>
      find.descendant(of: find.byType(BottomSheet), matching: findText(text));

  testWidgets('자동 확정: 친 문장이 내 말풍선에, 캡션·무료 되돌리기·기록·효과음', (tester) async {
    await show(tester, _ev);
    expect(find.byType(OutlinedButton), findsNWidgets(3), reason: '입력창은 OutlinedButton 이 아니다');
    expect(find.byKey(_input), findsOneWidget);
    expect(findText('직접 쓰기…'), findsOneWidget);
    // 이 문장은 매처가 자동 확정해야 한다(아니면 튜닝이 바뀐 것).
    expect(c.chooseFree(_yes).decision, MatchDecision.auto);
    c.freeSendsThisEvent = 0;

    await type(tester, _yes);
    expect(c.lastOutcome, isNotNull);
    expect(c.lastChoiceSource, ChoiceSource.freeText);
    expect(c.lastChoice!.text, '오늘은 안 갈래');
    expect(c.playerText, _yes);
    expect(sfx.played, contains(Sfx.msgOut));
    // 내 말풍선은 친 문장 그대로, 선택지 원문은 말풍선에 없다.
    expect(find.ancestor(of: findText(_yes), matching: find.byType(ChatBubble)), findsOneWidget);
    expect(find.ancestor(of: findText('오늘은 안 갈래'), matching: find.byType(ChatBubble)), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byKey(_input), findsNothing);

    await settleReplies(tester);
    expect(findText('→ "오늘은 안 갈래" 으로 알아들었어요'), findsOneWidget);
    expect(c.canOfferFreeUndo, isTrue);
    expect(findText('그런 뜻 아니었어요'), findsOneWidget);
    expect(findText('10초 전으로 (광고)'), findsNothing);

    final e = c.state!.freeInputs.single;
    expect(e.eventId, 't_free');
    expect(e.choiceIndex, 1);
    expect(e.text, _yes);
    expect(e.auto, isTrue);
    expect(e.day, c.state!.day);

    // 지표는 구조만 — 원문은 어디에도 없다.
    expect(rec.names, contains(Analytics.freeInputSent));
    for (final (_, params) in rec.events) {
      for (final v in params.values) {
        expect('$v', isNot(contains('싫어')));
      }
    }
    expect(rec.userProperties[Analytics.freeInputUse], '1');
    await tester.pumpWidget(Container());
  });

  testWidgets('낮은 확신: 피커가 뜨고, 고르면 친 문장 + 확인한 셈이라 무료 되돌리기 없음', (tester) async {
    await show(tester, _ev);
    await type(tester, '아무거나 ㅁㄴㅇ');
    expect(c.lastOutcome, isNull);
    expect(findText('이런 뜻이에요?'), findsOneWidget);
    expect(findText('다시 쓰기'), findsOneWidget);
    expect(inSheet('"아무거나 ㅁㄴㅇ"'), findsOneWidget);
    // 시트 안 행은 OutlinedButton 이 아니다.
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(OutlinedButton)),
      findsNothing,
    );
    // 다시 쓰기 → 문장은 남는다.
    await tester.tap(findText('다시 쓰기'));
    await settleSheet(tester);
    expect(findText('이런 뜻이에요?'), findsNothing);
    expect(tester.widget<TextField>(find.byKey(_input)).controller!.text, '아무거나 ㅁㄴㅇ');
    expect(c.lastOutcome, isNull);

    await unlock(tester);
    await tester.tap(find.byKey(_send));
    await settleSheet(tester);
    await tester.tap(inSheet('생각해 볼게'));
    await settleSheet(tester);
    expect(c.lastOutcome, isNotNull);
    expect(c.lastChoice!.text, '생각해 볼게');
    expect(c.lastChoiceSource, ChoiceSource.freeText);
    expect(c.playerText, '아무거나 ㅁㄴㅇ');
    expect(c.canOfferFreeUndo, isFalse, reason: '피커를 거친 건 플레이어가 확인한 셈');
    expect(c.state!.freeInputs.single.auto, isFalse);
    expect(rec.names, contains(Analytics.freeInputPicked));
    await settleReplies(tester);
    expect(findText('그런 뜻 아니었어요'), findsNothing);
    await tester.pumpWidget(Container());
  });

  testWidgets('잠긴 선택지가 1위면 턴을 쓰지 않고 안내 한 줄', (tester) async {
    // m02 의 두 번째 선택지는 자존감 30 이 필요. 초기 자존감은 15.
    final ev = c.bundle.eventById['m02']!;
    await show(tester, ev);
    final locked = c.choices.firstWhere((v) => v.locked);
    await type(tester, locked.choice.text);
    expect(c.lastOutcome, isNull);
    expect(c.state!.freeInputs, isEmpty);
    expect(c.undoUsedThisEvent, isFalse);
    expect(findText('아직 그 말은 안 나온다 (${locked.reason})'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(_input)).controller!.text, locked.choice.text);
    expect(rec.names, contains(Analytics.freeInputLocked));
    // 입력창에 포커스가 있는 동안 버튼은 칩 한 줄로 접힌다(07 §3.1). 잠긴 칩은 비활성.
    expect(find.byType(ActionChip), findsNWidgets(3));
    expect(find.byType(OutlinedButton), findsNothing);
    expect(
      tester.widget<ActionChip>(findWidgetWithText(ActionChip, locked.choice.text.length > 14
          ? '${locked.choice.text.substring(0, 14)}…'
          : locked.choice.text)).onPressed,
      isNull,
    );
    // 키보드가 내려가면 버튼 3개로 돌아온다.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OutlinedButton), findsNWidgets(3));
    expect(find.byType(ActionChip), findsNothing);
    await tester.pumpWidget(Container());
  });

  testWidgets('무료 되돌리기: 자동 확정 뒤 1회, 문장 복원, 재시도는 피커 강제', (tester) async {
    await show(tester, _ev);
    await type(tester, _yes);
    await settleReplies(tester);
    await tester.tap(findText('그런 뜻 아니었어요'));
    await tester.pump();
    expect(c.lastOutcome, isNull);
    expect(c.undoUsedThisEvent, isTrue);
    expect(c.canOfferFreeUndo, isFalse);
    expect(c.freePickForced, isTrue);
    expect(c.state!.freeInputs, isEmpty, reason: '되돌린 기록은 지운다');
    expect(rec.names, contains(Analytics.freeInputUndo));
    // 선택지로 돌아오고 문장이 입력창에 되살아난다.
    expect(find.byType(OutlinedButton), findsNWidgets(3));
    expect(tester.widget<TextField>(find.byKey(_input)).controller!.text, _yes);
    expect(findText(_yes), findsOneWidget, reason: '말풍선은 사라지고 입력창에만');

    // 같은 문장을 다시 보내도 자동 확정하지 않는다.
    await tester.tap(find.byKey(_send));
    await settleSheet(tester);
    expect(c.lastOutcome, isNull);
    expect(findText('이런 뜻이에요?'), findsOneWidget);
    await tester.tap(inSheet('좋아 가자'));
    await settleSheet(tester);
    expect(c.lastOutcome, isNotNull);
    expect(c.lastChoice!.text, '좋아 가자');
    expect(c.playerText, _yes);
    await settleReplies(tester);
    expect(findText('그런 뜻 아니었어요'), findsNothing, reason: '이벤트당 1회');
    await tester.pumpWidget(Container());
  });

  testWidgets('전송 5회면 입력창이 사라지고 버튼만 남는다', (tester) async {
    await show(tester, _ev);
    for (var i = 0; i < GameController.maxFreeSendsPerEvent; i++) {
      expect(find.byKey(_input), findsOneWidget, reason: '$i번째');
      await type(tester, 'ㅁㄴㅇㄹ');
      await tester.tap(findText('다시 쓰기'));
      await settleSheet(tester);
      await unlock(tester);
    }
    expect(c.freeSendsThisEvent, GameController.maxFreeSendsPerEvent);
    expect(c.canFreeInput, isFalse);
    expect(find.byKey(_input), findsNothing);
    expect(find.byType(OutlinedButton), findsNWidgets(3));
    expect(c.lastOutcome, isNull);
    await tester.pumpWidget(Container());
  });

  testWidgets('금칙어·빈 입력: 매핑·저장 없음, 안내 한 줄', (tester) async {
    await show(tester, _ev);
    await type(tester, '시발 가자');
    expect(c.lastOutcome, isNull);
    expect(c.state!.freeInputs, isEmpty);
    expect(findText('그 말은 보내지 않기로 했다.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(_input)).controller!.text, isEmpty);
    expect(c.freeSendsThisEvent, 0, reason: '금칙어는 전송으로 안 센다');
    expect(rec.paramsOf(Analytics.freeInputBlocked).single['reason'], 'profanity');
    await unlock(tester);
    await type(tester, '😂😂');
    expect(findText('조금만 더 써 주세요'), findsOneWidget);
    expect(c.lastOutcome, isNull);
    await tester.pumpWidget(Container());
  });

  testWidgets('화면을 다시 만들어도 내 말풍선은 친 문장, 세이브에도 남는다', (tester) async {
    await show(tester, _ev);
    await type(tester, _yes);
    await settleReplies(tester);
    // 화면 상태(_picked)가 사라져도 컨트롤러·세이브가 문장을 안다.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(wrapApp(EventScreen(c: c)));
    await tester.pump();
    expect(find.ancestor(of: findText(_yes), matching: find.byType(ChatBubble)), findsOneWidget);
    expect(find.ancestor(of: findText('오늘은 안 갈래'), matching: find.byType(ChatBubble)), findsNothing);

    // 세이브 왕복: 다른 컨트롤러로 이어하기 해도 기록이 있다(추가 필드, 예전 세이브 호환).
    final saved = await SaveService().load();
    expect(saved!.freeInputs.single.text, _yes);
    final c2 = GameController(bundle: testBundle(), save: SaveService());
    await c2.init();
    expect(await c2.continueGame(), isTrue);
    expect(c2.state!.freeInputs.single.text, _yes);
    expect(c2.state!.freeInputs.single.eventId, 't_free');
    await tester.pumpWidget(Container());
  });

  testWidgets('통화 중 "끊을게" 는 거절 경로 확인 시트', (tester) async {
    final call = c.bundle.events.firstWhere((e) => e.isCall && e.declineIndex != null);
    c.current = call;
    c.revealed = call.lines.length;
    c.phase = Phase.event;
    await tester.pumpWidget(wrapApp(EventScreen(c: c)));
    await tester.pump();
    // 대사가 이미 공개된 채 들어오면 수신 화면 없이 통화 중 화면(선택지 패널)이다.
    expect(findText('통화 중'), findsOneWidget);
    expect(find.byKey(_input), findsOneWidget);
    await type(tester, '나 이제 끊을게');
    expect(findText('전화를 끊을까요?'), findsOneWidget);
    await tester.tap(findText('끊기'));
    await settleSheet(tester);
    expect(c.lastOutcome, isNotNull);
    expect(c.lastChoice!.decline, isTrue);
    await tester.pumpWidget(Container());
  });
}
