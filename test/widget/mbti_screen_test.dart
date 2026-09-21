/// MBTI 화면: 온보딩 MBTI 단계(4축 토글 · 간이 테스트 · 건너뛰기), 새 게임 흐름 연결,
/// 캐스트 소개 카드의 MBTI 칩과 궁합 줄, 설정의 "내 MBTI". 규격: docs/MBTI_SPEC.md §2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/meta_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/onboarding_gender_screen.dart';
import 'package:mossol/ui/onboarding_mbti_screen.dart';
import 'package:mossol/ui/onboarding_name_screen.dart';
import 'package:mossol/ui/preference_screen.dart';
import 'package:mossol/ui/settings_screen.dart';
import 'package:mossol/ui/widgets.dart';

import 'helpers.dart';

void main() {
  FilledButton submit(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('mbti-submit')));

  Future<void> tapAxis(WidgetTester tester, String letter) async {
    final f = find.byKey(Key('mbti-$letter'));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pump();
  }

  group('온보딩 MBTI 단계', () {
    testWidgets('네 축을 다 골라야 다음이 켜지고, 고른 유형을 넘긴다', (tester) async {
      String? got;
      await tester.pumpWidget(
        wrapApp(OnboardingMbtiScreen(onSubmit: (m) => got = m, onSkip: () {})),
      );
      expect(findText(OnboardingMbtiScreen.title), findsOneWidget);
      for (final l in 'EISNTFJP'.split('')) {
        expect(find.byKey(Key('mbti-$l')), findsOneWidget);
      }
      // 축마다 짧은 힌트.
      expect(findText('혼자 있으면 충전돼요'), findsOneWidget);
      expect(findText(OnboardingMbtiScreen.pendingLabel), findsOneWidget);
      expect(submit(tester).onPressed, isNull);
      for (final l in ['E', 'N', 'T']) {
        await tapAxis(tester, l);
      }
      expect(submit(tester).onPressed, isNull);
      await tapAxis(tester, 'J');
      // 같은 축은 하나만: J 대신 P.
      await tapAxis(tester, 'P');
      expect(findText('나는 ENTP'), findsOneWidget);
      expect(submit(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('mbti-submit')));
      expect(got, 'ENTP');
    });

    testWidgets('고른 칸은 체크 아이콘 · 스크린리더 selected 로도 알린다', (tester) async {
      await tester.pumpWidget(
        wrapApp(OnboardingMbtiScreen(onSubmit: (_) {}, onSkip: () {})),
      );
      await tapAxis(tester, 'I');
      final i = find.byKey(const Key('mbti-I'));
      expect(
        find.descendant(of: i, matching: find.byIcon(Icons.check_circle)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('mbti-E')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsNothing,
      );
      expect(
        tester.getSemantics(i),
        matchesSemantics(
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          label: 'I 내향. 혼자 있으면 충전돼요',
        ),
      );
    });

    testWidgets('잘 몰라요 → 4문항 → 결과를 토글에 채우고 간이 테스트라고 밝힌다', (tester) async {
      String? got;
      await tester.pumpWidget(
        wrapApp(OnboardingMbtiScreen(onSubmit: (m) => got = m, onSkip: () {})),
      );
      await tester.ensureVisible(find.byKey(const Key('mbti-unsure')));
      await tester.tap(find.byKey(const Key('mbti-unsure')));
      await tester.pumpAndSettle();
      expect(find.byType(MbtiQuizScreen), findsOneWidget);
      expect(findText(MbtiQuizScreen.note), findsOneWidget);
      expect(findText('1 / 4'), findsOneWidget);
      // I · S · F · 한 번 뒤로 갔다가 다시 F · P.
      await tester.tap(find.byKey(const Key('mbti-quiz-I')));
      await tester.pumpAndSettle();
      expect(findText('2 / 4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mbti-quiz-S')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mbti-quiz-T')));
      await tester.pumpAndSettle();
      expect(findText('4 / 4'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(findText('3 / 4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mbti-quiz-F')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mbti-quiz-P')));
      await tester.pumpAndSettle();
      expect(find.byType(MbtiQuizScreen), findsNothing);
      expect(findText('나는 ISFP'), findsOneWidget);
      expect(findText(OnboardingMbtiScreen.quizNote), findsOneWidget);
      // 대충 맞아요? → 한 축 고친다.
      await tapAxis(tester, 'J');
      expect(findText('나는 ISFJ'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mbti-submit')));
      expect(got, 'ISFJ');
    });

    testWidgets('간이 테스트 첫 문항에서 뒤로 가면 아무것도 채우지 않는다', (tester) async {
      await tester.pumpWidget(
        wrapApp(OnboardingMbtiScreen(onSubmit: (_) {}, onSkip: () {})),
      );
      await tester.ensureVisible(find.byKey(const Key('mbti-unsure')));
      await tester.tap(find.byKey(const Key('mbti-unsure')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(MbtiQuizScreen), findsNothing);
      expect(findText(OnboardingMbtiScreen.pendingLabel), findsOneWidget);
      expect(find.byKey(const Key('mbti-quiz-note')), findsNothing);
    });

    testWidgets('건너뛰기 링크(온보딩)와 지우기 링크(설정)', (tester) async {
      var skipped = false;
      await tester.pumpWidget(
        wrapApp(
          OnboardingMbtiScreen(onSubmit: (_) {}, onSkip: () => skipped = true),
        ),
      );
      expect(find.byKey(const Key('mbti-clear')), findsNothing);
      await tester.tap(find.byKey(const Key('mbti-skip')));
      expect(skipped, isTrue);
      await tester.pumpWidget(
        wrapApp(
          OnboardingMbtiScreen(
            key: const ValueKey('settings'),
            initial: 'INFJ',
            submitLabel: OnboardingMbtiScreen.saveLabel,
            onSubmit: (_) {},
            onClear: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mbti-skip')), findsNothing);
      expect(find.byKey(const Key('mbti-clear')), findsOneWidget);
      expect(findText('나는 INFJ'), findsOneWidget, reason: '처음 값으로 채운다');
    });

    testWidgets('320×568 · 1.3배: 넘치지 않고 다음·건너뛰기가 첫 화면에', (tester) async {
      useSmallScreenLargeFont(tester);
      await tester.pumpWidget(
        wrapApp(OnboardingMbtiScreen(onSubmit: (_) {}, onSkip: () {})),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final k in ['mbti-submit', 'mbti-skip']) {
        final r = tester.getRect(find.byKey(Key(k)));
        expect(r.bottom, lessThanOrEqualTo(568), reason: k);
        expect(r.height, greaterThanOrEqualTo(44), reason: k);
      }
      for (final l in 'EISNTFJP'.split('')) {
        await tester.ensureVisible(find.byKey(Key('mbti-$l')));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(Key('mbti-$l'))).height,
          greaterThanOrEqualTo(44),
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('새 게임 흐름', () {
    late GameController c;
    setUp(() async => c = await makeController());

    Future<void> startNewGame(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(fullApp(c));
      await tester.pump();
      await tester.tap(findText('새 게임'));
      await tester.pumpAndSettle();
    }

    testWidgets('나는? → 이름 → MBTI → 캐스트(칩·궁합) → 시작: 회차와 메타에 MBTI', (
      tester,
    ) async {
      await startNewGame(tester);
      await tester.tap(find.byKey(Key('gender-${PlayerGender.male}')));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingNameScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('name-skip')));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingMbtiScreen), findsOneWidget);
      for (final l in ['E', 'N', 'F', 'P']) {
        await tapAxis(tester, l);
      }
      await tester.tap(find.byKey(const Key('mbti-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(PreferenceScreen), findsOneWidget);
      // 시작 전에는 저장하지 않는다.
      expect(c.playerMbti, isNull);
      // 서연 INTJ 와 ENFP 는 천생연분.
      final card = find.byKey(const Key('cast-seoyeon'));
      expect(
        find.descendant(of: card, matching: findText('INTJ')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: findText('궁합 천생연분')),
        findsOneWidget,
      );
      // 뒤로 가면 MBTI 단계, 고른 값은 그 화면에 남아 있다.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingMbtiScreen), findsOneWidget);
      expect(findText('나는 ENFP'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mbti-submit')));
      await tester.pumpAndSettle();
      await tester.tap(findText(PreferenceScreen.startLabel));
      await tester.pumpAndSettle();
      expect(c.phase, Phase.action);
      expect(c.playerMbti, 'ENFP');
      expect(c.state!.mbti, 'ENFP');
      final m = await MetaService().load();
      expect(m.mbti, 'ENFP');
      expect(m.mbtiAsked, isTrue);
      await spinRouletteSheet(tester);
      // 다음 새 게임에서는 묻지 않는다.
      c.goHome();
      await tester.pumpAndSettle();
      await tester.tap(findText('새 게임'));
      await tester.pumpAndSettle();
      await tester.tap(findText('시작'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingGenderScreen), findsNothing);
      expect(find.byType(OnboardingMbtiScreen), findsNothing);
      expect(find.byType(PreferenceScreen), findsOneWidget);
      expect(findText('궁합 천생연분'), findsOneWidget, reason: '저장된 MBTI 로 궁합');
      await tester.pumpWidget(Container());
    });

    testWidgets('MBTI 건너뛰기: 모름으로 시작, 궁합 줄 없음, 다시 묻지 않음', (tester) async {
      await c.setPlayerGender(PlayerGender.female);
      await c.setPlayerName('민지');
      await startNewGame(tester);
      expect(find.byType(OnboardingMbtiScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('mbti-skip')));
      await tester.pumpAndSettle();
      expect(find.byType(PreferenceScreen), findsOneWidget);
      expect(find.byType(CompatRow), findsNothing);
      expect(find.byType(MbtiChip), findsWidgets, reason: '캐릭터 MBTI 칩은 보인다');
      await tester.tap(findText(PreferenceScreen.startLabel));
      await tester.pumpAndSettle();
      expect(c.state!.mbti, isNull);
      expect(c.shouldAskMbti, isFalse);
      await tester.pumpWidget(Container());
    });
  });

  group('캐스트 소개 카드', () {
    testWidgets('플레이어 MBTI 가 있으면 칩 + 하트 5칸(점수+1) + 라벨, 히든은 ????', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final b = testBundle();
      await tester.pumpWidget(
        wrapApp(
          PreferenceScreen(
            bundle: b,
            side: Preference.female,
            playerMbti: 'ISTJ',
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 서연 INTJ × ISTJ = 정반대(0) → 하트 1칸.
      final seo = find.byKey(const Key('cast-seoyeon'));
      expect(
        find.descendant(of: seo, matching: findText('INTJ')),
        findsOneWidget,
      );
      final row = find.byKey(const Key('compat-seoyeon'));
      expect(
        find.descendant(of: row, matching: findText('궁합 정반대')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.favorite)),
        findsNWidgets(1),
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.favorite_border)),
        findsNWidgets(4),
      );
      // 다은 INFP × ISTJ: S/N 다름 0 + E/I 같음 0 + J/P 다름 1 = 1 → 하트 2칸.
      final daeun = find.byKey(const Key('compat-daeun'));
      expect(
        find.descendant(of: daeun, matching: find.byIcon(Icons.favorite)),
        findsNWidgets(2),
      );
      // 히든(유나)은 MBTI 도 ???? · 궁합 줄 없음.
      final yuna = find.byKey(const Key('cast-yuna'));
      await tester.ensureVisible(yuna);
      expect(
        find.descendant(of: yuna, matching: findText(CastIntro.hiddenMbti)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: yuna, matching: findText('ENFJ')),
        findsNothing,
      );
      expect(find.byKey(const Key('compat-yuna')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('플레이어 모름이면 궁합 줄을 숨긴다', (tester) async {
      await tester.pumpWidget(
        wrapApp(PreferenceScreen(bundle: testBundle(), side: Preference.male)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CompatRow), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('cast-haneul')),
          matching: findText('ESFP'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('320×568 · 1.3배 · 다크: 칩·궁합 줄이 있어도 넘치지 않는다', (tester) async {
      useSmallScreenLargeFont(tester);
      useDarkMode(tester);
      await tester.pumpWidget(
        wrapApp(
          PreferenceScreen(
            bundle: testBundle(),
            side: Preference.female,
            playerMbti: 'ENFP',
          ),
          mode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(CompatRow), findsWidgets);
    });

    test('introsOf: 궁합 점수는 Mbti.compat, 캐릭터 MBTI 가 없거나 플레이어 모름이면 null', () {
      final b = testBundle();
      final withMbti = PreferenceScreen.introsOf(
        b,
        Preference.female,
        playerMbti: 'ENTP',
      );
      final seo = withMbti.firstWhere((e) => e.id == 'seoyeon');
      expect(seo.mbti, 'INTJ');
      expect(seo.compat, 4);
      expect(withMbti.last.mystery, isTrue);
      expect(withMbti.last.mbti, CastIntro.hiddenMbti);
      expect(withMbti.last.compat, isNull);
      final none = PreferenceScreen.introsOf(b, Preference.female);
      expect(none.every((e) => e.compat == null), isTrue);
      expect(CompatRow.filledFor(0), 1);
      expect(CompatRow.filledFor(4), 5);
    });
  });

  group('설정 · 내 MBTI', () {
    late GameController c;
    setUp(() async => c = await makeController());

    testWidgets('모름 → 고르기 → 저장 → 지우기, 진행 중 회차는 그대로', (tester) async {
      await c.newGame(seed: 1);
      await tester.pumpWidget(wrapApp(SettingsScreen(c: c)));
      final row = find.byKey(const Key('settings-mbti'));
      expect(
        find.descendant(of: row, matching: findText('모름')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: findText('다음 새 게임부터 적용돼요')),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingMbtiScreen), findsOneWidget);
      expect(findText(OnboardingMbtiScreen.saveLabel), findsOneWidget);
      expect(findText(OnboardingMbtiScreen.settingsNote), findsOneWidget);
      expect(find.byKey(const Key('mbti-skip')), findsNothing);
      expect(find.byKey(const Key('mbti-clear')), findsNothing);
      for (final l in ['I', 'S', 'T', 'P']) {
        await tapAxis(tester, l);
      }
      await tester.tap(find.byKey(const Key('mbti-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        find.descendant(of: row, matching: findText('ISTP')),
        findsOneWidget,
      );
      expect(c.playerMbti, 'ISTP');
      expect(c.state!.mbti, isNull, reason: '진행 중 회차는 그대로');
      // 다시 열면 지우기 링크.
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(findText('나는 ISTP'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mbti-clear')));
      await tester.pumpAndSettle();
      expect(c.playerMbti, isNull);
      expect(
        find.descendant(of: row, matching: findText('모름')),
        findsOneWidget,
      );
      // 전체 초기화에서도 지운다.
      await c.setPlayerMbti('ENFJ');
      await c.resetAllData();
      expect(c.playerMbti, isNull);
      expect(c.shouldAskMbti, isTrue);
    });
  });
}
