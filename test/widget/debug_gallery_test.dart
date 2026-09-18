import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/debug/debug_gallery.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';
import 'package:mossol/ui/ending_screen.dart';

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
      expect(find.text(label), findsOneWidget, reason: '$label 버튼 없음');
    }
    for (final t in ['해피', '굿', '솔로', '배드', '히든']) {
      expect(find.textContaining('$t 엔딩'), findsOneWidget);
    }
  });

  testWidgets('엔딩을 고르면 EndingScreen 이 뜨고 "홈으로" 로 돌아온다', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bundle = testBundle();
    await tester.pumpWidget(DebugGalleryApp(bundle: bundle));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('배드 엔딩'));
    await tester.pumpAndSettle();
    final bad = bundle.endings.firstWhere((e) => e.tier == 'bad');
    await tester.tap(find.text(bad.name));
    await tester.pumpAndSettle();

    expect(find.byType(EndingScreen), findsOneWidget);
    expect(find.text('배드 엔딩'), findsOneWidget);
    expect(find.text('연애 등급'), findsOneWidget);

    await tester.tap(find.text('홈으로'));
    await tester.pumpAndSettle();
    expect(find.byType(EndingScreen), findsNothing);
    expect(find.text('디버그 갤러리'), findsOneWidget);
  });

  testWidgets('미니게임 버튼을 누르면 실제 미니게임이 뜬다', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(DebugGalleryApp(bundle: testBundle()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(minigameLabels['read_emotion']!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DebugGalleryScreen), findsNothing, reason: '미니게임 라우트가 갤러리를 덮어야 한다');
    // 미니게임 껍데기가 떠 있으면 충분하다. 결과 판정은 각 미니게임 테스트 몫.
    expect(find.byType(MinigameScaffold), findsOneWidget);
  });
}
