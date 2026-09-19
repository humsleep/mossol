import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mossol/debug/debug_gallery.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';
import 'package:mossol/ui/action_screen.dart';
import 'package:mossol/ui/ending_screen.dart';
import 'package:mossol/ui/home_screen.dart';
import 'package:mossol/ui/summary_screen.dart';
import 'package:mossol/ui/widgets.dart';

import 'helpers.dart';

/// QA 디버그 갤러리 스모크 테스트. 미니게임·엔딩 목록이 뜨고 엔딩 화면이 실제로 열리는지.
void main() {
  testWidgets('미니게임 12종과 엔딩 티어 5종이 나열된다', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
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
    tester.view.physicalSize = const Size(400, 2400);
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
}
