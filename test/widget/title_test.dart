/// 앱 첫 화면(타이틀). docs/DESIGN_SYSTEM.md §2.16.
///
/// 흐름(타이틀 → 문자 → … → 캐스트 소개)은 `intro_test.dart` 가 본다. 여기서는 화면
/// 자체를 본다: 무엇이 쓰여 있는지, 배너가 없는지, 그림이 없어도 서는지, 320×568 ·
/// 글자 1.3배에서 넘치지 않고 시작 버튼이 첫 화면 안에 있는지.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/ui/design_system.dart';
import 'package:mossol/ui/scene_card.dart';
import 'package:mossol/ui/scene_registry.dart';
import 'package:mossol/ui/title_screen.dart';
import 'package:mossol/ui/widgets.dart';

import 'helpers.dart';
import 'scene_helpers.dart';

String sceneAsset(String key) => '${SceneRegistry.sceneDir}$key.webp';

void main() {
  testWidgets('이름 · 부제 · 한 줄 소개 · 시작 버튼. 배너는 없다', (tester) async {
    var started = 0;
    await tester.pumpWidget(wrapApp(TitleScreen(onStart: () => started++)));
    await tester.pumpAndSettle();

    expect(findText(TitleScreen.title), findsOneWidget);
    expect(findText(TitleScreen.genre), findsOneWidget);
    expect(findText(TitleScreen.tagline), findsOneWidget);
    expect(findText(TitleScreen.startLabel), findsOneWidget);
    // 앱의 첫 프레임이 광고일 수 없다(§2 공통).
    expect(find.byType(BannerSlot), findsNothing);

    await tester.tap(find.byKey(const Key('title-start')));
    await tester.pump();
    expect(started, 1);
  });

  testWidgets('그림이 없으면 그라데이션만 — 화면은 그대로 선다', (tester) async {
    SceneRegistry.debugOverride(null);
    await tester.pumpWidget(wrapApp(TitleScreen(onStart: () {})));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SceneImage), findsNothing);
    expect(findText(TitleScreen.title), findsOneWidget);
  });

  testWidgets('전용 그림이 없으면 게임의 첫 삽화(m01)를 쓴다', (tester) async {
    useScenes(paths: [sceneAsset(TitleScreen.fallbackArtKey)]);
    await tester.pumpWidget(wrapApp(TitleScreen(onStart: () {})));
    await tester.pumpAndSettle();
    expect(
      TitleScreen.artOf(SceneRegistry.current),
      sceneAsset(TitleScreen.fallbackArtKey),
    );
    expect(find.byType(SceneImage), findsOneWidget);

    // 전용 그림이 들어오면 그쪽이 먼저다.
    useScenes(
      paths: [
        sceneAsset(TitleScreen.artKey),
        sceneAsset(TitleScreen.fallbackArtKey),
      ],
    );
    expect(
      TitleScreen.artOf(SceneRegistry.current),
      sceneAsset(TitleScreen.artKey),
    );
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode == ThemeMode.dark ? '다크' : '라이트';
    testWidgets('320x568 1.3배 $tag: 넘치지 않고 시작 버튼이 첫 화면 안, 탭 타깃·대비', (
      tester,
    ) async {
      useSmallScreenLargeFont(tester);
      if (mode == ThemeMode.dark) useDarkMode(tester);
      // 그림이 있는 상태가 더 빡빡하다(바탕 위 글자 대비).
      useScenes(paths: [sceneAsset(TitleScreen.fallbackArtKey)]);
      await tester.pumpWidget(wrapApp(TitleScreen(onStart: () {}), mode: mode));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final start = tester.getRect(find.byKey(const Key('title-start')));
      expect(start.height, greaterThanOrEqualTo(AppSpace.minTouch));
      expect(start.bottom, lessThanOrEqualTo(568), reason: '시작 버튼');
      expect(start.right, lessThanOrEqualTo(320));
      // 제목도 첫 화면 안에서 잘리지 않는다.
      final title = tester.getRect(findText(TitleScreen.title));
      expect(title.bottom, lessThanOrEqualTo(568));
      expect(title.left, greaterThanOrEqualTo(0));
      expect(title.right, lessThanOrEqualTo(320));

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }

  testWidgets('동작 줄이기: 연출 없이 완성된 화면으로 선다', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: wrapApp(TitleScreen(onStart: () {})),
      ),
    );
    // 한 프레임 만에 제자리·불투명이다.
    await tester.pump();
    final opacity = tester
        .widgetList<FadeTransition>(find.byType(FadeTransition))
        .map((f) => f.opacity.value);
    expect(opacity, everyElement(1.0));
    expect(findText(TitleScreen.startLabel), findsOneWidget);
  });
}
