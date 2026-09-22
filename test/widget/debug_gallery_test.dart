import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mossol/debug/debug_gallery.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';
import 'package:mossol/ui/action_screen.dart';
import 'package:mossol/ui/ending_screen.dart';
import 'package:mossol/ui/home_screen.dart';
import 'package:mossol/ui/onboarding_gender_screen.dart';
import 'package:mossol/ui/onboarding_mbti_screen.dart';
import 'package:mossol/ui/preference_screen.dart';
import 'package:mossol/ui/retention_widgets.dart';
import 'package:mossol/ui/summary_screen.dart';
import 'package:mossol/ui/widgets.dart';

import 'helpers.dart';
import 'portrait_helpers.dart';

/// QA 디버그 갤러리 스모크 테스트. 미니게임·엔딩 목록이 뜨고 엔딩 화면이 실제로 열리는지.
void main() {
  testWidgets('미니게임 12종과 엔딩 티어 5종이 나열된다', (tester) async {
    // 목록이 길어 lazy ListView 가 끝까지 짓도록 높게 잡는다(온보딩 미리보기 4줄 포함).
    tester.view.physicalSize = const Size(400, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(DebugGalleryApp(bundle: testBundle()));
    await tester.pumpAndSettle();
    for (final label in minigameLabels.values) {
      expect(findText(label), findsOneWidget, reason: '$label 버튼 없음');
    }
    for (final t in ['해피', '굿', '솔로', '배드', '히든']) {
      expect(findTextContaining('$t 엔딩'), findsOneWidget);
    }
  });

  testWidgets('서사 신호 목록: 캐릭터별로 펼치면 구간 카드와 하강 카드가 뜬다', (tester) async {
    tester.view.physicalSize = const Size(400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bundle = testBundle();
    await tester.pumpWidget(DebugGalleryApp(bundle: bundle));
    await tester.pumpAndSettle();
    final first = bundle.characters.first;
    final title = findText('${first.name} 신호');
    await tester.dragUntilVisible(
      title,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(title);
    await tester.pumpAndSettle();
    final sig = bundle.signals.byCharacter[first.id]!;
    expect(find.byType(RelationShiftCard), findsNWidgets(sig.bands.length + 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('엔딩을 고르면 EndingScreen 이 뜨고 "홈으로" 로 돌아온다', (tester) async {
    tester.view.physicalSize = const Size(400, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bundle = testBundle();
    await tester.pumpWidget(DebugGalleryApp(bundle: bundle));
    await tester.pumpAndSettle();

    await tester.tap(findTextContaining('배드 엔딩'));
    await tester.pumpAndSettle();
    final bad = bundle.endings.firstWhere((e) => e.tier == 'bad');
    await tester.tap(findText(bad.name));
    await tester.pumpAndSettle();

    expect(find.byType(EndingScreen), findsOneWidget);
    expect(findText('배드 엔딩'), findsOneWidget);
    expect(findText('연애 등급'), findsOneWidget);

    await tester.tap(findText('홈으로'));
    await tester.pumpAndSettle();
    expect(find.byType(EndingScreen), findsNothing);
    expect(findText('디버그 갤러리'), findsOneWidget);
  });

  testWidgets('미니게임 버튼을 누르면 실제 미니게임이 뜬다', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(DebugGalleryApp(bundle: testBundle()));
    await tester.pumpAndSettle();
    await tester.tap(findText(minigameLabels['read_emotion']!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byType(DebugGalleryScreen),
      findsNothing,
      reason: '미니게임 라우트가 갤러리를 덮어야 한다',
    );
    // 미니게임 껍데기가 떠 있으면 충분하다. 결과 판정은 각 미니게임 테스트 몫.
    expect(find.byType(MinigameScaffold), findsOneWidget);
  });

  // ---- 정산·홈 미리보기 ----

  Future<void> openPreview(WidgetTester tester, String label) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(DebugGalleryApp(bundle: testBundle()));
    await tester.pumpAndSettle();
    final tile = findText(label);
    await tester.dragUntilVisible(
      tile,
      find.byType(ListView),
      const Offset(0, -300),
    );
    // 목록 끝자락에서 반쯤 걸친 채 멈추면 탭이 빗나간다. 화면 안으로 끌어온다.
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing, reason: '신호 데이터로 구성하지 못했다');
  }

  /// 미리보기 라우트를 닫고 갤러리로 돌아온다(행동·홈 화면의 1초 타이머 정리).
  Future<void> closePreview(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byType(DebugGalleryScreen), findsOneWidget);
  }

  List<bool> shiftCards(WidgetTester tester) => [
    for (final w in tester.widgetList<RelationShiftCard>(
      find.byType(RelationShiftCard),
    ))
      w.up,
  ];

  testWidgets('정산 미리보기: 서로 다른 두 사람의 상승 카드 2장', (tester) async {
    await openPreview(tester, '정산: 상승 카드 2장');
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(shiftCards(tester), [true, true]);
    final names = {
      for (final w in tester.widgetList<RelationShiftCard>(
        find.byType(RelationShiftCard),
      ))
        w.name,
    };
    expect(names.length, 2, reason: '두 장은 서로 다른 캐릭터여야 한다');
    expect(tester.takeException(), isNull);
    await closePreview(tester);
  });

  testWidgets('정산 미리보기: 상승 1장 + 하강 1장(오른 쪽이 먼저)', (tester) async {
    await openPreview(tester, '정산: 상승 1장 + 하강 1장');
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(shiftCards(tester), [true, false]);
    expect(tester.takeException(), isNull);
    await closePreview(tester);
  });

  testWidgets('행동 미리보기: 밤사이 하락 한 줄이 뜨고 룰렛은 안 뜬다', (tester) async {
    await openPreview(tester, '행동: 밤사이 하락 한 줄');
    expect(find.byType(ActionScreen), findsOneWidget);
    expect(find.byType(OvernightNote), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
    // 화면의 홈 버튼 → phase 가 바뀌면 갤러리로 돌아온다.
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(ActionScreen), findsNothing);
    expect(find.byType(DebugGalleryScreen), findsOneWidget);
  });

  testWidgets('리텐션 미리보기: 다음 판 카드 · 내일 예고 · 지난 판 · 하트 없음', (tester) async {
    await openPreview(tester, '엔딩: 다음 판 카드');
    expect(find.byType(EndingScreen), findsOneWidget);
    expect(find.byType(NextRunCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await closePreview(tester);

    await openPreview(tester, '정산: 내일 예고 한 줄');
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(find.byType(TomorrowLine), findsOneWidget);
    await closePreview(tester);

    await openPreview(tester, '행동: 지난 판 요약');
    expect(find.byType(PreviousRunNote), findsOneWidget);
    await closePreview(tester);

    await openPreview(tester, '행동: 하트 비었을 때');
    await tester.tap(findText('헬스장'));
    await tester.pumpAndSettle();
    expect(findText(heartEmptyTitle), findsOneWidget);
    await tester.tap(findText('기다릴게요'));
    await tester.pumpAndSettle();
    await closePreview(tester);
  });

  testWidgets('홈 미리보기: 이어하기 카드의 서사 신호와 밤사이 줄', (tester) async {
    final bundle = testBundle();
    await openPreview(tester, '홈: 서사 신호 줄 + 밤사이 줄');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(findText('이어하기'), findsOneWidget);
    expect(find.byType(OvernightNote), findsOneWidget);
    // 신호 문장 하나가 홈 어딘가에 보인다.
    final lines = {
      for (final sig in bundle.signals.byCharacter.values)
        for (final b in sig.bands) ...b.lines,
    };
    expect(
      lines.any((l) => findTextContaining(l).evaluate().isNotEmpty),
      isTrue,
      reason: '이어하기 카드에 서사 신호 줄이 없다',
    );
    expect(tester.takeException(), isNull);
    await closePreview(tester);
  });

  // ---- 새 게임 온보딩 ----

  testWidgets('온보딩 1단계 → 남자 → 2단계(여성 쪽) → 시작하면 스낵바로 결과만 알린다', (tester) async {
    await openPreview(tester, '1단계: 나는?');
    expect(find.byType(OnboardingGenderScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('gender-m')));
    await tester.pumpAndSettle();
    expect(find.byType(PreferenceScreen), findsOneWidget);
    expect(find.byKey(const Key('cast-seoyeon')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cast-start')));
    await tester.pumpAndSettle();
    expect(find.byType(DebugGalleryScreen), findsOneWidget);
    expect(findTextContaining('나는: 남자'), findsOneWidget);
    expect(findTextContaining('(f)'), findsOneWidget);
  });

  testWidgets('MBTI 단계 미리보기 → ENFP → 미리보기 MBTI 로 캐스트 소개에 궁합 줄', (tester) async {
    await openPreview(tester, 'MBTI 단계: 나의 MBTI는?');
    expect(find.byType(OnboardingMbtiScreen), findsOneWidget);
    for (final l in ['E', 'N', 'F', 'P']) {
      await tester.tap(find.byKey(Key('mbti-$l')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('mbti-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(DebugGalleryScreen), findsOneWidget);
    expect(findTextContaining('MBTI: ENFP'), findsOneWidget);
    final tile = findText('2단계: 캐스트 소개 · 여성 캐릭터');
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(CompatRow), findsWidgets);
    expect(findText('궁합 천생연분'), findsOneWidget, reason: '서연 INTJ × ENFP');
    expect(tester.takeException(), isNull);
  });

  for (final (label, side) in [
    ('2단계: 캐스트 소개 · 여성 캐릭터', 'f'),
    ('2단계: 캐스트 소개 · 남성 캐릭터', 'm'),
    ('2단계: 캐스트 소개 · 비교(선택 안 함)', null),
  ]) {
    testWidgets('$label 미리보기가 뜬다', (tester) async {
      await openPreview(tester, label);
      expect(find.byType(PreferenceScreen), findsOneWidget);
      if (side == null) {
        expect(find.byType(PreferenceCard), findsNWidgets(2));
        expect(find.byType(CastIntroCard), findsNothing);
      } else {
        expect(find.byKey(Key('cast-side-$side')), findsOneWidget);
        expect(find.byType(CastIntroCard), findsNWidgets(6));
      }
      expect(tester.takeException(), isNull);
      await closePreview(tester);
    });
  }

  testWidgets('초상화 12명 미리보기: 그림 있음·없음 모두 12줄, 다크 전환도 넘치지 않는다', (tester) async {
    usePortraits(ids: ['seoyeon', 'jeongwoo', 'yuna']);
    await openPreview(tester, '초상화 12명 미리보기');
    await settleImages(tester);
    expect(find.byType(PortraitPreviewScreen), findsOneWidget);
    expect(findTextContaining('12명 중 3장 있음'), findsOneWidget);
    // 다크로 바꾼 뒤 끝까지 내려 본다.
    await tester.tap(findText('다크'));
    await tester.pumpAndSettle();
    await settleImages(tester);
    for (final id in portraitIds) {
      await tester.dragUntilVisible(
        find.byKey(Key('portrait-$id')),
        find.byType(ListView).last,
        const Offset(0, -300),
      );
    }
    expect(tester.takeException(), isNull);
    await closePreview(tester);
  });
}
