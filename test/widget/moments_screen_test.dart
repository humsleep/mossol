// 모먼트 화면: 전화(수신 → 받기/거절), 먼저 온 톡 알림, 사진 메시지. docs/MOMENTS_SPEC.md.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/debug/debug_gallery.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/call_view.dart';
import 'package:mossol/ui/design_system.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/notification_card.dart';
import 'package:mossol/ui/widgets.dart';

import 'helpers.dart';

void main() {
  late GameController c;
  late StoryEvent call, preview, photo;

  setUp(() async {
    c = await makeController();
    await c.newGame(seed: 11);
    final samples = momentSamples(c.bundle);
    call = samples[0].$3;
    preview = samples[1].$3;
    photo = samples[2].$3;
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

  group('전화', () {
    testWidgets('수신 → 받기 → 자막·타이머 → 선택(decline 숨김) → 반응 자막 → 결과', (
      tester,
    ) async {
      await show(tester, call);
      expect(findText('전화가 왔어요'), findsOneWidget);
      expect(find.byType(PulseAvatar), findsOneWidget);
      expect(findText('받기'), findsOneWidget);
      expect(findText('거절'), findsOneWidget);
      // 받기 전에는 대사가 흐르지 않는다.
      await tester.pump(const Duration(seconds: 2));
      expect(c.revealed, 0);

      await tester.tap(findText('받기'));
      await tester.pump();
      expect(find.byType(IncomingCallView), findsNothing);
      expect(findText('통화 중'), findsOneWidget);
      expect(findText('00:00'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 850));
      expect(c.revealed, 1);
      expect(findText('어… 자고 있었어?'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(findText('00:01'), findsOneWidget);

      await revealAll(tester, c);
      // 대기 줄은 카운트다운이 아니라 침묵. 벌점·광고 버튼 없음.
      expect(findText(CallSubtitle.silence), findsOneWidget);
      expect(findTextContaining('초째 답이 없다'), findsNothing);
      // 통화 중 선택지: decline 은 숨긴다.
      expect(
        find.byType(OutlinedButton),
        findsNWidgets(call.choices.length - 1),
      );
      expect(findWidgetWithText(OutlinedButton, '거절'), findsNothing);

      await tester.tap(findWidgetWithText(OutlinedButton, '나도 마침 생각하고 있었어'));
      await tester.pump();
      expect(c.lastOutcome, isNotNull);
      expect(c.lastOutcome!.success, isTrue);
      // 내 말이 자막으로 남고, 반응은 자막으로 한 줄씩.
      expect(findText('나도 마침 생각하고 있었어'), findsOneWidget);
      expect(findText('계속'), findsNothing);
      await settleReplies(tester);
      expect(findText('진짜? 다행이다'), findsOneWidget);
      expect(
        find.byType(ChatBubble),
        findsNothing,
        reason: '통화 중 반응은 말풍선이 아니다',
      );
      expect(findText('계속'), findsOneWidget);
      expect(findText('통화 종료'), findsOneWidget);
      // 결과 패널이 뜨면 통화 시간이 멈춘다.
      final t1 = tester
          .widget<Text>(findTextContaining(RegExp(r'^\d\d:\d\d$')))
          .data;
      await tester.pump(const Duration(seconds: 3));
      final t2 = tester
          .widget<Text>(findTextContaining(RegExp(r'^\d\d:\d\d$')))
          .data;
      expect(t2, t1);

      await tester.tap(findText('계속'));
      await tester.pump();
      expect(c.phase, Phase.summary);
      await tester.pumpWidget(Container());
    });

    testWidgets('수신 → 거절 = decline 선택지. 반응은 채팅 말풍선', (tester) async {
      final affBefore = c.state!.affectionOf(call.character!);
      await show(tester, call);
      await tester.tap(findText('거절'));
      await tester.pump();
      expect(c.lastOutcome, isNotNull);
      expect(c.lastReply.first.text, '바빠? 나중에 연락해');
      expect(
        c.state!.affectionOf(call.character!),
        lessThanOrEqualTo(affBefore),
      );
      expect(find.byType(ActiveCallView), findsNothing);
      expect(findTextContaining('부재중 전화'), findsOneWidget);
      // 대사는 보이지 않는다(받지 않은 전화).
      expect(findText('어… 자고 있었어?'), findsNothing);
      await settleReplies(tester);
      expect(findWidgetWithText(ChatBubble, '바빠? 나중에 연락해'), findsOneWidget);
      expect(findText('계속'), findsOneWidget);
      // 거절은 '성공' 이 아니다.
      expect(findText('전화를 넘겼다'), findsOneWidget);
      expect(findText('성공'), findsNothing);
      // 결정한 선택지 문구('거절')를 내 말풍선으로 남기지 않는다.
      expect(findWidgetWithText(ChatBubble, '거절'), findsNothing);

      // 되돌리기(광고 보상)면 다시 울리는 화면으로.
      if (c.canOfferUndo) {
        c.undoChoice();
        await tester.pump();
        expect(find.byType(IncomingCallView), findsOneWidget);
      }
      await tester.pumpWidget(Container());
    });

    testWidgets('이미 진행 중인 전화(대사 공개됨)는 수신 없이 통화 화면으로', (tester) async {
      await show(tester, call, revealed: true);
      expect(find.byType(IncomingCallView), findsNothing);
      expect(find.byType(ActiveCallView), findsOneWidget);
      expect(findWidgetWithText(OutlinedButton, '거절'), findsNothing);
      await tester.pumpWidget(Container());
    });
  });

  group('먼저 온 톡 알림', () {
    testWidgets('알림 카드가 뜨고 탭하면 대사가 시작된다', (tester) async {
      await show(tester, preview);
      expect(find.byType(NotificationCard), findsOneWidget);
      expect(findText(preview.preview!), findsOneWidget);
      expect(findText('지금'), findsOneWidget);
      expect(findText(c.characterName(preview.character)), findsOneWidget);
      // 알림이 떠 있는 동안 자동 공개 타이머는 돌지 않는다.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(c.revealed, 0);

      await tester.tap(find.byType(NotificationCard));
      await tester.pump();
      expect(find.byType(NotificationCard), findsNothing);
      expect(c.revealed, 0);
      await tester.pump(const Duration(milliseconds: 850));
      expect(c.revealed, 1);
      expect(
        findWidgetWithText(ChatBubble, preview.lines.first.text),
        findsOneWidget,
      );
      await tester.pumpWidget(Container());
    });

    testWidgets('탭하지 않아도 1.8초 뒤 열린다', (tester) async {
      await show(tester, preview);
      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.byType(NotificationCard), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(NotificationCard), findsNothing);
      await tester.pump(const Duration(milliseconds: 850));
      expect(c.revealed, 1);
      await tester.pumpWidget(Container());
    });

    testWidgets('동작 줄이기면 알림 없이 바로 열린다', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await show(tester, preview);
      expect(find.byType(NotificationCard), findsNothing);
      await tester.pump(const Duration(milliseconds: 850));
      expect(c.revealed, 1);
      await tester.pumpWidget(Container());
    });

    testWidgets('캐릭터가 없으면 첫 them 줄의 name 을 쓰고, 둘 다 없으면 알림을 건너뛴다', (
      tester,
    ) async {
      final named = StoryEvent.fromJson({
        'id': 'mo_t',
        'layer': 'daily',
        'preview': '야 뭐 해',
        'lines': [
          {'who': 'them', 'name': '태현', 'text': '야 뭐 해'},
        ],
        'choices': [
          {'text': 'x', 'reply': 'ㅇㅇ'},
        ],
      });
      await show(tester, named);
      expect(find.byType(NotificationCard), findsOneWidget);
      expect(findText('태현'), findsOneWidget);
      await tester.pumpWidget(Container());

      final nameless = StoryEvent.fromJson({
        'id': 'mo_n',
        'layer': 'daily',
        'preview': '야 뭐 해',
        'lines': [
          {'who': 'them', 'text': '야 뭐 해'},
        ],
        'choices': [
          {'text': 'x', 'reply': 'ㅇㅇ'},
        ],
      });
      await show(tester, nameless);
      expect(find.byType(NotificationCard), findsNothing);
      await tester.pumpWidget(Container());
    });
  });

  group('사진', () {
    testWidgets('사진 카드 · 아래 말풍선 · 스크린리더 라벨 · 모르는 아이콘은 기본 사진', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, photo, revealed: true);
      await tester.pump(const Duration(milliseconds: 400)); // 등장 페이드
      expect(find.byType(PhotoBubble), findsNWidgets(3));
      String label(int i) =>
          tester.getSemantics(find.byType(PhotoBubble).at(i)).label;
      expect(label(0), contains('사진: 창가 자리 잡았어'));
      expect(label(2), contains('사진: 출발 인증'));
      expect(find.byIcon(Icons.local_cafe), findsOneWidget);
      expect(find.byIcon(Icons.face), findsOneWidget);
      expect(find.byIcon(Icons.photo), findsOneWidget, reason: '모르는 아이콘');
      // text 가 있으면 사진 아래 말풍선.
      expect(findText('여기 올래?'), findsOneWidget);
      expect(
        tester.getRect(findText('여기 올래?')).top,
        greaterThan(tester.getRect(find.byType(PhotoBubble).first).bottom),
      );
      // 내가 보낸 사진은 오른쪽.
      final mine = tester.getRect(find.byType(PhotoBubble).at(2));
      final theirs = tester.getRect(find.byType(PhotoBubble).first);
      expect(mine.right, greaterThan(theirs.right));

      // 반응 줄의 사진도 같은 경로로 그린다.
      await tester.tap(
        findWidgetWithText(OutlinedButton, photo.choices.first.text),
      );
      await tester.pump();
      await settleReplies(tester);
      expect(find.byType(PhotoBubble), findsNWidgets(4));
      expect(label(3), contains('사진: 케이크도 시켜 둠'));
      handle.dispose();
      await tester.pumpWidget(Container());
    });

    test('아이콘 매핑 14종이 규격 목록과 같다', () {
      expect(photoIcons.keys.toSet(), Photo.icons.toSet());
      expect(photoIcons.length, 14);
      expect(photoIconFor('???'), Icons.photo);
    });

    testWidgets('폴라로이드: 폭 220 이하 · 기울기 ±1.5° · 탭하면 크게 보기와 닫기', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(430, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, photo, revealed: true);
      await tester.pump(const Duration(milliseconds: 400));

      // 채팅 흐름을 막지 않는 크기: 화면 60% 와 220 중 작은 쪽.
      final frame = tester.getSize(find.byType(PolaroidFrame).first);
      expect(frame.width, lessThanOrEqualTo(PhotoBubble.maxWidth));

      // 기울기는 결정론적이고 범위 안.
      for (final icon in [...Photo.icons, '???']) {
        for (final cap in ['', '창가 자리 잡았어', '가나다라마바사아자차카타파하 한강 야경']) {
          final p = Photo(icon: icon, caption: cap);
          final d = photoTiltDegrees(p);
          expect(d, inInclusiveRange(-1.5, 1.5));
          expect(photoTiltDegrees(Photo(icon: icon, caption: cap)), d);
        }
      }

      // 스크린리더에게는 버튼 + 힌트.
      final data = tester
          .getSemantics(find.byType(PhotoBubble).first)
          .getSemanticsData();
      expect(data.hint, '크게 보기');
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(find.byType(PhotoBubble).first);
      await tester.pumpAndSettle();
      expect(findText('닫기'), findsOneWidget);
      expect(find.bySemanticsLabel('사진: 창가 자리 잡았어'), findsWidgets);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.tap(findText('닫기'));
      await tester.pumpAndSettle();
      expect(findText('닫기'), findsNothing);
      handle.dispose();
      await tester.pumpWidget(Container());
    });

    testWidgets('캡션 잉크색은 모든 캐릭터·라이트/다크에서 인화지 위 4.5:1 이상', (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        late BuildContext ctx;
        await tester.pumpWidget(
          wrapApp(
            Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox();
              },
            ),
            mode: mode,
          ),
        );
        final t = ctx.tokens;
        final paper = PolaroidFrame.paperOf(ctx);
        for (final a in [...t.characterAccents.values, t.neutralAccent]) {
          final ink = PolaroidFrame.inkOf(ctx, a);
          final l1 = ink.computeLuminance(), l2 = paper.computeLuminance();
          final ratio = (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
          expect(ratio, greaterThanOrEqualTo(4.5), reason: '$mode $a');
        }
      }
      await tester.pumpWidget(Container());
    });
  });

  testWidgets('디버그 갤러리: 모먼트 미리보기 세 줄이 있고 전화를 바로 띄운다', (tester) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(DebugGalleryApp(bundle: testBundle()));
    await tester.pumpAndSettle();
    expect(findText('모먼트 미리보기'), findsOneWidget);
    for (final s in momentSamples(testBundle())) {
      expect(findText(s.$1), findsOneWidget);
    }
    await tester.tap(findText('전화 (수신 → 받기/거절)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(IncomingCallView), findsOneWidget);
    await tester.tap(findText('거절'));
    await tester.pump();
    await settleReplies(tester);
    await tester.tap(findText('계속'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(IncomingCallView), findsNothing);
    expect(findText('모먼트 미리보기'), findsOneWidget);
    await tester.pumpWidget(Container());
  });
}
