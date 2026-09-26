// 첫 실행 인트로(docs/DESIGN_SYSTEM.md §2.14, docs/review/00_VERDICT.md §3).
// 첫 실행은 홈을 건너뛰고 태현의 첫 문자로 시작해 이름·"나는?" 을 대화 안에서 받는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/audio/sfx_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/home_screen.dart';
import 'package:mossol/ui/intro_screen.dart';
import 'package:mossol/ui/notification_card.dart';
import 'package:mossol/ui/onboarding_gender_screen.dart';
import 'package:mossol/ui/onboarding_mbti_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('첫 실행은 홈이 아니라 인트로 — 태현의 문자 한 통(소리 + 진동)', (tester) async {
    final sfx = useRecordingSfx();
    final c = await makeController(firstLaunch: true);
    expect(c.shouldShowIntro, isTrue);

    await tester.pumpWidget(fullApp(c));
    await tester.pump();

    expect(find.byType(IntroScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    // 홈의 관리용 요소는 하나도 보이지 않는다.
    expect(findText('모쏠 탈출기'), findsNothing);
    expect(findText('새 게임'), findsNothing);
    expect(findTextContaining('앨범'), findsNothing);
    // 보이는 건 알림 카드 한 장과 그 한 줄.
    expect(find.byType(NotificationCard), findsOneWidget);
    expect(findText(IntroScreen.previewLine), findsOneWidget);
    expect(sfx.played, contains(Sfx.msgIn));
    expect(sfx.haptics, contains(HapticKind.medium));
  });

  testWidgets('인트로 4탭: 문자 열기 → 대답 → 이름 → 나는? → 첫날 첫 이벤트(홈을 안 거친다)', (
    tester,
  ) async {
    final c = await makeController(firstLaunch: true);
    await tester.pumpWidget(fullApp(c));
    await tester.pump();

    // 1탭: 알림 카드를 열면 대화가 시작된다(카드가 다 내려온 뒤, 자동 열림 1.8초 전에).
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byType(NotificationCard));
    await tester.pumpAndSettle();
    expect(findText(IntroScreen.previewLine), findsOneWidget);

    // 2탭: 대답이 곧 시작이다 — "시작하기" 버튼은 없다.
    await tester.tap(find.byKey(const Key('intro-yes')));
    await tester.pumpAndSettle();
    expect(findText(IntroScreen.yesLabel), findsOneWidget);
    expect(findText(IntroScreen.nameQuestion), findsOneWidget);

    // 3탭: 이름은 대화 안에서 받는다(별도 화면이 아니다).
    await tester.enterText(find.byKey(const Key('intro-name-field')), '민지');
    await tester.pump();
    await tester.tap(find.byKey(const Key('intro-name-submit')));
    await tester.pumpAndSettle();
    expect(findText(IntroScreen.genderQuestion), findsOneWidget);

    // 4탭: "나는?" 의 기존 문구 그대로. 남자 → 여성 캐릭터 회차.
    expect(findText(OnboardingGenderScreen.subtitle), findsWidgets);
    await tester.tap(find.byKey(const Key('gender-${PlayerGender.male}')));
    // 마지막 답 뒤 태현의 한 줄을 읽는 사이에 첫날이 열린다.
    await tester.pump(IntroScreen.startDelay);
    await tester.pumpAndSettle();

    // 인트로 다음은 홈이 아니라 첫날이다.
    expect(find.byType(HomeScreen), findsNothing);
    expect(c.playerName, '민지');
    expect(c.playerGender, PlayerGender.male);
    expect(c.state!.preference, Preference.female);
    expect(c.state!.day, 1);
    expect(c.hasSave, isTrue);
    // MBTI 는 여기서 묻지 않았다 — D+4 대화의 몫으로 남는다.
    expect(c.shouldAskMbti, isTrue);
    expect(c.phase, anyOf(Phase.dayStart, Phase.action));

    // 그대로 아침(룰렛 → 행동) → 첫 이벤트까지 이어진다.
    await spinRouletteSheet(tester);
    await tester.tap(findText(c.config.actions.first.name));
    await tester.pump();
    expect(c.phase, Phase.event);
    expect(find.byType(EventScreen), findsOneWidget);
    expect(c.current, isNotNull);
  });

  testWidgets('이름 건너뛰기: 이름 없이도 끝까지 간다, 규칙에 어긋난 이름은 버튼이 꺼진다', (tester) async {
    final c = await makeController(firstLaunch: true);
    await tester.pumpWidget(fullApp(c));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byType(NotificationCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('intro-maybe')));
    await tester.pumpAndSettle();

    // 빈 값이면 1차 버튼이 꺼져 있다(이름 화면과 같은 규칙).
    FilledButton submit() => tester.widget<FilledButton>(
      find.byKey(const Key('intro-name-submit')),
    );
    expect(submit().onPressed, isNull);
    // 6자까지. 더 치면 입력창이 잘라 낸다(이름 화면과 같은 거르개).
    await tester.enterText(
      find.byKey(const Key('intro-name-field')),
      '일곱글자이름임',
    );
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '일곱글자이름',
    );

    await tester.tap(find.byKey(const Key('intro-name-skip')));
    await tester.pumpAndSettle();
    expect(findText(IntroScreen.genderQuestion), findsOneWidget);

    // "선택 안 할래요" 는 어느 쪽을 먼저 만날지 한 번 더 묻는다.
    await tester.tap(find.byKey(const Key('gender-${PlayerGender.none}')));
    await tester.pumpAndSettle();
    expect(findText(IntroScreen.sideQuestion), findsOneWidget);
    await tester.tap(find.byKey(const Key('intro-side-${Preference.male}')));
    await tester.pump(IntroScreen.startDelay);
    await tester.pumpAndSettle();

    expect(c.playerName, isNull);
    expect(c.shouldAskName, isFalse, reason: '물어봤다 — 다시 묻지 않는다');
    expect(c.state!.preference, Preference.male);
  });

  testWidgets('두 번째 세션은 홈에서 시작한다(인트로는 한 번뿐)', (tester) async {
    final c = await makeController(firstLaunch: true);
    await tester.pumpWidget(fullApp(c));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byType(NotificationCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('intro-yes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('intro-name-skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gender-${PlayerGender.female}')));
    await tester.pump(IntroScreen.startDelay);
    await tester.pumpAndSettle();
    expect(c.hasSave, isTrue);

    // 앱을 껐다 켠 것과 같다: 같은 저장소로 새 컨트롤러.
    final again = GameController(bundle: c.bundle, save: c.save);
    await again.init();
    expect(again.shouldShowIntro, isFalse);
    await tester.pumpWidget(fullApp(again));
    await tester.pump();
    expect(find.byType(IntroScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(findText('이어하기'), findsOneWidget);
  });

  testWidgets('첫 회차 오프닝 D+1~3 은 하트를 쓰지 않는다 (R4)', (tester) async {
    final c = await makeController();
    await c.newGame(seed: 5, preference: Preference.female);
    final full = c.hearts;
    expect(c.config.firstRunFreeHeartDays, 3, reason: 'config.json 의 값');

    for (var day = 1; day <= c.config.firstRunFreeHeartDays; day++) {
      c.state!.day = day;
      expect(c.freeHeartToday, isTrue);
      expect(await c.startDay(c.config.actions.first), isTrue);
      expect(c.hearts, full, reason: 'D+$day 은 공짜');
    }
    // 오프닝 다음 날부터는 예전 그대로 하루에 하나.
    c.state!.day = c.config.firstRunFreeHeartDays + 1;
    expect(c.freeHeartToday, isFalse);
    expect(await c.startDay(c.config.actions.first), isTrue);
    expect(c.hearts, full - 1);
    // 2회차는 첫날부터 쓴다.
    await c.newGame(seed: 5, preference: Preference.female, run: 2);
    expect(c.freeHeartToday, isFalse);
  });

  group('MBTI 는 D+4 대화에서 묻는다 (R6)', () {
    late GameController c;
    late StoryEvent mbtiEvent;

    setUp(() async {
      c = await makeController();
      await c.newGame(seed: 5, preference: Preference.female);
      final ev = c.bundle.eventById['${EventScreen.mbtiEventPrefix}_f'];
      expect(
        ev,
        isNotNull,
        reason:
            'D+4 MBTI 대화 id 가 바뀌면 EventScreen.mbtiEventPrefix 도 같이 바꾼다',
      );
      mbtiEvent = ev!;
      c.state!.day = 4;
      c.current = mbtiEvent;
      c.phase = Phase.event;
    });

    testWidgets('대사가 끝나면 시트가 올라온다 — 고르면 이번 회차에도 바로 반영', (tester) async {
      expect(c.shouldAskMbti, isTrue);
      expect(c.runMbti, isNull);
      await tester.pumpWidget(wrapApp(EventScreen(c: c)));
      await revealAll(tester, c);
      await tester.pumpAndSettle();

      expect(find.byType(MbtiSheet), findsOneWidget);
      for (final letter in ['I', 'N', 'F', 'P']) {
        await tester.tap(find.byKey(Key('mbti-$letter')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('mbti-sheet-submit')));
      await tester.pumpAndSettle();

      expect(c.playerMbti, 'INFP');
      expect(c.runMbti, 'INFP', reason: '다음 새 게임이 아니라 지금 회차부터');
      expect(c.shouldAskMbti, isFalse);
    });

    testWidgets('건너뛰면 예전의 모름 그대로 — 아무것도 막히지 않는다', (tester) async {
      await tester.pumpWidget(wrapApp(EventScreen(c: c)));
      await revealAll(tester, c);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mbti-sheet-skip')));
      await tester.pumpAndSettle();

      expect(c.playerMbti, isNull);
      expect(c.runMbti, isNull);
      expect(c.shouldAskMbti, isFalse, reason: '물어봤다 — 다시 묻지 않는다');
      // 대화는 그대로 이어진다: 선택지를 고르면 결과가 나온다.
      expect(c.choices, isNotEmpty);
      c.choose(plainChoiceIndex(c));
      await tester.pump();
      expect(c.lastOutcome, isNotNull);
    });

    testWidgets('MBTI 를 이미 아는 회차에는 시트가 뜨지 않는다', (tester) async {
      await c.setPlayerMbti('ENFJ');
      await c.newGame(seed: 5, preference: Preference.female);
      c.state!.day = 4;
      c.current = mbtiEvent;
      c.phase = Phase.event;
      expect(c.shouldAskMbti, isFalse);
      await tester.pumpWidget(wrapApp(EventScreen(c: c)));
      await revealAll(tester, c);
      await tester.pumpAndSettle();
      expect(find.byType(MbtiSheet), findsNothing);
    });
  });
}
