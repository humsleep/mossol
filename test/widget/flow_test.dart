import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/onboarding_gender_screen.dart';
import 'package:mossol/ui/onboarding_mbti_screen.dart';
import 'package:mossol/ui/onboarding_name_screen.dart';
import 'package:mossol/ui/preference_screen.dart';

import 'helpers.dart';

void main() {
  late GameController c;

  setUp(() async {
    c = await makeController();
  });

  /// 이벤트 화면에서 결과 패널이나 선택지를 처리해 하루를 끝까지 진행한다.
  Future<void> playDay(WidgetTester tester, {int maxEvents = 12}) async {
    for (var i = 0; i < maxEvents && c.phase == Phase.event; i++) {
      await revealAll(tester, c);
      if (c.lastOutcome == null) {
        final idx = plainChoiceIndex(c);
        final text = c.current!.choices[idx].text;
        await tester.tap(findWidgetWithText(OutlinedButton, text));
        await tester.pump();
        expect(c.lastOutcome, isNotNull);
        await settleReplies(tester);
        expect(findText('계속'), findsOneWidget);
      }
      await tester.tap(findText('계속'));
      await tester.pump();
    }
    expect(c.phase, Phase.summary);
  }

  testWidgets('홈 → 새 게임 → 룰렛 → 행동 → 이벤트 → 정산 → D+2', (tester) async {
    await tester.pumpWidget(fullApp(c));
    expect(findText('모쏠 탈출기'), findsOneWidget);
    expect(findText('이어하기'), findsNothing);

    await tester.tap(findText('새 게임'));
    await tester.pumpAndSettle();
    // 첫 새 게임은 "나는?" → 캐스트 소개를 거친다. 시작하기를 누르면 확인 없이 시작한다.
    expect(findText(OnboardingGenderScreen.title), findsOneWidget);
    expect(c.phase, Phase.home);
    await tester.tap(findText('남자'));
    await tester.pumpAndSettle();
    // 그다음 이름 단계("뭐라고 불러 드릴까요?"). 건너뛰면 이름 없이 진행한다.
    expect(findText(OnboardingNameScreen.title), findsOneWidget);
    await skipNameStep(tester);
    expect(findText(PreferenceScreen.title), findsOneWidget);
    expect(c.phase, Phase.home);
    await tester.tap(findText(PreferenceScreen.startLabel));
    await tester.pumpAndSettle();
    expect(c.phase, Phase.action);
    expect(c.state!.preference, Preference.female);
    expect(c.playerGender, PlayerGender.male);
    await spinRouletteSheet(tester);
    expect(c.rouletteSlot, isNotNull);
    expect(findText('D+1  ·  1장'), findsOneWidget);

    await tester.tap(findText('헬스장'));
    await tester.pump();
    expect(c.phase, Phase.event);
    // 홈 진입 때 첫 출석 하트(+1)가 보류됐다가 새 게임에 얹힌다. 거기서 하나를 썼다.
    expect(c.hearts, c.config.maxHearts + Attendance.dailyHearts - 1);
    expect(find.byType(EventScreen), findsOneWidget);

    // 첫 이벤트는 m01. 대사가 자동으로 공개된다.
    expect(c.current!.id, 'm01');
    expect(c.revealed, 0);
    await tester.pump(const Duration(milliseconds: 900));
    expect(c.revealed, greaterThanOrEqualTo(1));

    await playDay(tester);
    expect(findText('D+1 정산'), findsOneWidget);

    // 첫날은 대개 누군가와 첫 구간에 들어서서 관계 변화 카드가 위에 뜬다. 버튼까지 내린다.
    await tester.dragUntilVisible(
      findText('다음 날로'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(findText('다음 날로'));
    await tester.pump();
    expect(c.phase, Phase.action);
    expect(c.state!.day, 2);
    await spinRouletteSheet(tester);
    expect(findText('D+2  ·  1장'), findsOneWidget);

    // D+2 의 m02 에는 미니게임 선택지(표정 읽기)가 있다.
    // 어젯밤 예고 카드가 생겨 행동 목록이 아래로 밀리므로 먼저 보이게 스크롤한다.
    final secondAction = findText(c.config.actions[1].name);
    await tester.dragUntilVisible(
      secondAction,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(secondAction);
    await tester.pump();
    expect(c.phase, Phase.event, reason: '행동을 고르면 하루가 시작돼야 한다');
    expect(c.current!.id, 'm02');
    await revealAll(tester, c);
    await tester.tap(findWidgetWithText(OutlinedButton, '알겠어, 연습해 볼게'));
    await tester.pumpAndSettle();
    expect(find.byType(MinigameScaffold), findsOneWidget);
    expect(findText('진짜 감정은?'), findsOneWidget);
    for (final answer in ['서운함', '대화 끊고 싶음', '삐짐', '위로 원함']) {
      await tester.tap(findText(answer));
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(findText('크리티컬!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    await settleReplies(tester);
    expect(find.byType(MinigameScaffold), findsNothing);
    expect(c.lastOutcome, isNotNull);
    expect(c.lastOutcome!.critical, isTrue);
    expect(
      findText('크리티컬!'),
      findsOneWidget,
      reason: 'm02 는 호감이 걸리지 않아 2배 문구가 없다',
    );
    expect(findTextContaining('전부 맞췄다'), findsOneWidget);

    await tester.tap(findText('계속'));
    await tester.pump();
    await playDay(tester);
  });

  testWidgets('이어하기: 세이브가 있으면 홈에 버튼이 뜨고 같은 날로 복원된다', (tester) async {
    await c.newGame(seed: 3);
    c.state!.day = 4;
    await c.save.save(c.state!);
    c.goHome();
    await c.init();
    await tester.pumpWidget(fullApp(c));
    expect(findText('이어하기'), findsOneWidget);
    await tester.tap(findText('이어하기'));
    await tester.pump();
    expect(c.phase, Phase.action);
    expect(c.state!.day, 4);
    await spinRouletteSheet(tester);
  });

  testWidgets('세이브가 있을 때 새 게임은 확인 다이얼로그를 거친다', (tester) async {
    await c.newGame(seed: 3);
    c.goHome();
    await tester.pumpWidget(fullApp(c));
    await tester.tap(findText('새 게임'));
    await tester.pumpAndSettle();
    expect(findText('진행 중인 회차가 지워집니다. 시작할까요?'), findsOneWidget);
    await tester.tap(findText('취소'));
    await tester.pumpAndSettle();
    expect(c.phase, Phase.home);
    await tester.tap(findText('새 게임'));
    await tester.pumpAndSettle();
    await tester.tap(findText('시작'));
    await tester.pumpAndSettle();
    // 지우기 확인 뒤 "나는?"(아직 답이 없다). 2단계에서 뒤로 가면 1단계로, 1단계에서 뒤로
    // 가면 홈으로 — 새 게임이 시작되지 않고 세이브도 그대로, 답도 저장되지 않는다.
    expect(findText(OnboardingGenderScreen.title), findsOneWidget);
    await tester.tap(findText('여자'));
    await tester.pumpAndSettle();
    expect(findText(OnboardingNameScreen.title), findsOneWidget);
    await tester.tap(find.byKey(const Key('name-skip')));
    await tester.pumpAndSettle();
    expect(findText(OnboardingMbtiScreen.title), findsOneWidget);
    await tester.tap(find.byKey(const Key('mbti-skip')));
    await tester.pumpAndSettle();
    expect(findText(PreferenceScreen.title), findsOneWidget);
    // 캐스트 소개 → MBTI → 이름 단계 → 나는? 순으로 뒤로 간다.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(findText(OnboardingMbtiScreen.title), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(findText(OnboardingNameScreen.title), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(findText(OnboardingGenderScreen.title), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(c.phase, Phase.home);
    expect(c.hasSave, isTrue);
    expect(c.playerGender, isNull);
    await tester.tap(findText('새 게임'));
    await tester.pumpAndSettle();
    await tester.tap(findText('시작'));
    await tester.pumpAndSettle();
    await tester.tap(findText('여자'));
    await tester.pumpAndSettle();
    await skipNameStep(tester);
    // 여자 → 남성 캐릭터 쪽이 기본.
    expect(find.byKey(const Key('cast-side-m')), findsOneWidget);
    await tester.tap(findText(PreferenceScreen.startLabel));
    await tester.pumpAndSettle();
    expect(c.phase, Phase.action);
    expect(c.state!.preference, Preference.male);
    expect(c.playerGender, PlayerGender.female);
    await spinRouletteSheet(tester);
  });
}
