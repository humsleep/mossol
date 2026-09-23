// 효과음·진동 큐가 명세(docs/overhaul/05_audio_haptics.md §1)의 지점에서 나가는지.
// 소리 자체는 재생하지 않고 RecordingSfxService 가 호출 순서만 남긴다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/audio/sfx_service.dart';
import 'package:mossol/debug/debug_gallery.dart';
import 'package:mossol/engine/meta_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/settings_screen.dart';

import 'helpers.dart';

void main() {
  late GameController c;
  late RecordingSfxService sfx;
  late StoryEvent call, preview;

  setUp(() async {
    sfx = useRecordingSfx();
    c = await makeController();
    await c.newGame(seed: 11);
    final samples = momentSamples(c.bundle);
    call = samples[0].$3;
    preview = samples[1].$3;
    // 컨트롤러 init 이 메타 기본값(둘 다 켬)을 서비스에 넣었는지.
    expect(sfx.sfxOn, isTrue);
    expect(sfx.hapticOn, isTrue);
    sfx.clear();
  });

  Future<void> show(
    WidgetTester tester,
    StoryEvent ev, {
    bool revealed = false,
  }) async {
    c.current = ev;
    c.revealed = revealed ? ev.lines.length : 0;
    c.lastOutcome = null;
    c.phase = Phase.event;
    await tester.pumpWidget(wrapApp(EventScreen(c: c)));
    await tester.pump();
  }

  testWidgets('문자 도착: 알림 카드가 뜨는 순간 msgIn + medium 진동', (tester) async {
    await show(tester, preview);
    expect(sfx.played, [Sfx.msgIn]);
    expect(sfx.haptics, [HapticKind.medium]);
    // 카드가 열려도 다시 울리지 않는다.
    await tester.pump(const Duration(seconds: 2));
    expect(sfx.played, [Sfx.msgIn]);
    await tester.pumpWidget(Container());
  });

  testWidgets('문자 도착: 동작 줄이기로 카드가 생략돼도 소리·진동은 난다', (tester) async {
    c.current = preview;
    c.revealed = 0;
    c.lastOutcome = null;
    c.phase = Phase.event;
    await tester.pumpWidget(
      wrapApp(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: EventScreen(c: c),
        ),
      ),
    );
    await tester.pump();
    expect(findText('지금'), findsNothing, reason: '알림 카드는 생략');
    expect(sfx.played, [Sfx.msgIn]);
    expect(sfx.haptics, [HapticKind.medium]);
    await tester.pumpWidget(Container());
  });

  testWidgets('전화: 수신에 벨, 받으면 벨 정지 + callConnect, 끝나면 callEnd', (tester) async {
    await show(tester, call);
    expect(sfx.played, [Sfx.callRing]);
    expect(sfx.ringing, isTrue);

    await tester.tap(findText('받기'));
    await tester.pump();
    expect(sfx.ringing, isFalse);
    expect(sfx.ringStops, 1);
    expect(sfx.played, [Sfx.callRing, Sfx.callConnect]);
    expect(sfx.haptics, [HapticKind.light]);

    await revealAll(tester, c);
    await tester.tap(findWidgetWithText(OutlinedButton, '나도 마침 생각하고 있었어'));
    await tester.pump();
    // 보내기 → 결과(성공).
    expect(sfx.played.sublist(2), [Sfx.msgOut, Sfx.choiceOk]);
    await settleReplies(tester);
    // 결과 패널이 뜨고 통화 시계가 멈추는 틱에 종료음.
    await tester.pump(const Duration(seconds: 1));
    expect(sfx.played.last, Sfx.callEnd);
    expect(sfx.played.where((s) => s == Sfx.callEnd).length, 1);
    await tester.pumpWidget(Container());
  });

  testWidgets('전화: 거절하면 벨 정지 + callEnd, 성패음은 없다', (tester) async {
    await show(tester, call);
    await tester.tap(findText('거절'));
    await tester.pump();
    expect(sfx.ringing, isFalse);
    expect(sfx.played, [Sfx.callRing, Sfx.callEnd]);
    expect(sfx.haptics, [HapticKind.medium]);
    await settleReplies(tester);
    expect(sfx.played, [Sfx.callRing, Sfx.callEnd]);
    await tester.pumpWidget(Container());
  });

  testWidgets('전화: 거절을 되돌리면 벨이 다시 울린다', (tester) async {
    await show(tester, call);
    await tester.tap(findText('거절'));
    await tester.pump();
    await settleReplies(tester);
    sfx.clear();
    c.undoChoice();
    await tester.pump();
    expect(findText('전화가 왔어요'), findsOneWidget);
    expect(sfx.played, [Sfx.callRing]);
    expect(sfx.ringing, isTrue);
    // 화면을 내리면 벨도 끊긴다.
    await tester.pumpWidget(Container());
    expect(sfx.ringing, isFalse);
  });

  testWidgets('전화: 다른 이벤트로 넘어가면 벨이 끊긴다', (tester) async {
    await show(tester, call);
    expect(sfx.ringing, isTrue);
    c.current = c.bundle.eventById['m01']!;
    c.revealed = c.current!.lines.length;
    c.notifyListeners();
    await tester.pump();
    expect(sfx.ringing, isFalse);
    await tester.pumpWidget(Container());
  });

  testWidgets('선택: 누르면 msgOut + selection, 결과에 따라 choiceOk / choiceFail', (
    tester,
  ) async {
    await show(tester, c.bundle.eventById['m01']!, revealed: true);
    expect(sfx.played, isEmpty, reason: '복원 진입은 알림음이 없다');
    final idx = plainChoiceIndex(c);
    await tester.tap(
      findWidgetWithText(OutlinedButton, c.current!.choices[idx].text),
    );
    await tester.pump();
    expect(sfx.played, [Sfx.msgOut, Sfx.choiceOk]);
    expect(sfx.haptics, [HapticKind.selection, HapticKind.medium]);
    await settleReplies(tester);
    await tester.pumpWidget(Container());
  });

  testWidgets('선택 실패: choiceFail + heavy 진동, 되돌리면 다시 안 울린다', (tester) async {
    await show(tester, c.bundle.eventById['m01']!, revealed: true);
    c.choose(0, minigameSuccess: false);
    await tester.pump();
    expect(sfx.played, [Sfx.choiceFail]);
    expect(sfx.haptics, [HapticKind.heavy]);
    await settleReplies(tester);
    c.undoChoice();
    await tester.pump();
    expect(sfx.played, [Sfx.choiceFail]);
    await tester.pumpWidget(Container());
  });

  testWidgets('읽씹 대기가 끝나면 waitRead', (tester) async {
    final ev = c.bundle.eventById['m03']!;
    final waitIdx = ev.lines.indexWhere((l) => l.isWait);
    await show(tester, ev);
    for (var i = 0; i < 40 && c.revealed < waitIdx; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(sfx.played, isEmpty, reason: '말풍선마다 소리를 내지 않는다');
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    expect(sfx.played, [Sfx.waitRead]);
    expect(sfx.haptics, [HapticKind.light]);
    await revealAll(tester, c);
    await tester.pumpWidget(Container());
  });

  testWidgets('정산 진입에 summary 큐 (앱 phase 전환에서)', (tester) async {
    final ev = c.bundle.eventById['m01']!;
    c.current = ev;
    c.revealed = ev.lines.length;
    c.phase = Phase.event;
    await tester.pumpWidget(fullApp(c));
    await tester.pump();
    final idx = plainChoiceIndex(c);
    await tester.tap(
      findWidgetWithText(OutlinedButton, c.current!.choices[idx].text),
    );
    await tester.pump();
    await settleReplies(tester);
    sfx.clear();
    await tester.tap(findText('계속'));
    await tester.pump();
    expect(c.phase, Phase.summary);
    expect(sfx.played, [Sfx.summary]);
    expect(sfx.haptics, [HapticKind.light]);
    await tester.pumpWidget(Container());
  });

  testWidgets('설정 토글: 효과음·진동 행이 메타에 저장되고 서비스에 반영된다', (tester) async {
    await tester.pumpWidget(wrapApp(SettingsScreen(c: c)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-sfx')), findsOneWidget);
    expect(find.byKey(const Key('settings-haptic')), findsOneWidget);
    expect(findText('효과음'), findsOneWidget);
    expect(findText('진동'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-sfx')));
    await tester.pumpAndSettle();
    expect(c.sfxOn, isFalse);
    expect(sfx.sfxOn, isFalse);
    expect(c.meta!.sfxOn, isFalse);
    sfx.play(Sfx.msgIn);
    expect(sfx.played, isEmpty, reason: '효과음 꺼짐');

    await tester.tap(find.byKey(const Key('settings-haptic')));
    await tester.pumpAndSettle();
    expect(c.hapticOn, isFalse);
    expect(sfx.hapticOn, isFalse);
    sfx.haptic(HapticKind.light);
    expect(sfx.haptics, isEmpty, reason: '진동 꺼짐');

    // 메타 JSON 에 남아 다시 읽어도 유지된다.
    final again = await MetaService().load();
    expect(again.sfxOn, isFalse);
    expect(again.hapticOn, isFalse);
  });
}
