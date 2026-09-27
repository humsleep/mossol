/// 앱 첫 화면(타이틀). docs/DESIGN_SYSTEM.md §2.16.
///
/// 흐름(타이틀 → 문자 → … → 캐스트 소개)은 `intro_test.dart` 가 본다. 여기서는 화면
/// 자체를 본다: 무엇이 쓰여 있는지, 배너가 없는지, 그림이 없어도 서는지, 320×568 ·
/// 글자 1.3배에서 넘치지 않고 시작 버튼이 첫 화면 안에 있는지.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/ui/call_view.dart';
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

  // docs/review/11_polish_verdict.md 7위: ① 아래 45% 가 빈 자수정 띠였고
  // ② 로고가 본문과 같은 `displaySmall` 이었다. 그 둘을 각각 본다.
  group('구성과 서체 (11_polish_verdict 7위)', () {
    testWidgets('그림이 화면을 꽉 채운다 — 아래 45% 가 비어 있지 않다', (tester) async {
      useScenes(paths: [sceneAsset(TitleScreen.fallbackArtKey)]);
      await tester.pumpWidget(wrapApp(TitleScreen(onStart: () {})));
      await tester.pumpAndSettle();

      // 통화 화면의 0.55 를 물려받지 않는다.
      final backdrop = tester.widget<CallBackdrop>(find.byType(CallBackdrop));
      expect(backdrop.heightFactor, 1.0);
      expect(backdrop.heightFactor, isNot(CallBackdrop.sceneHeightFactor));
      expect(backdrop.bottomScrim, isTrue, reason: '글자가 앉을 어둠');

      // 그림이 놓이는 상자가 화면 높이 전체다(그림 파일 자체는 테스트에서 디코딩되지
      // 않으므로 그림이 아니라 그 자리를 본다).
      final slot = find.ancestor(
        of: find.byType(SceneImage),
        matching: find.byType(FractionallySizedBox),
      );
      expect(
        tester.widget<FractionallySizedBox>(slot.first).heightFactor,
        1.0,
      );
      final screen = tester.getSize(find.byType(TitleScreen));
      expect(tester.getSize(slot.first).height, closeTo(screen.height, 1));
    });

    testWidgets('워드마크 묶음과 시작 버튼이 한 덩어리로 아래에 앉는다', (tester) async {
      await tester.pumpWidget(wrapApp(TitleScreen(onStart: () {})));
      await tester.pumpAndSettle();

      final screen = tester.getSize(find.byType(TitleScreen));
      final tagline = tester.getRect(findText(TitleScreen.tagline));
      final start = tester.getRect(find.byKey(const Key('title-start')));

      // 예전에는 가운데 묶음과 하단 버튼 사이가 화면 절반쯤 비어 있었다.
      expect(
        start.top - tagline.bottom,
        lessThan(screen.height * 0.2),
        reason: '부제와 버튼 사이가 여전히 벌어져 있다',
      );
      // 묶음 전체가 화면 아래쪽 절반에 있다(위쪽은 그림 자리).
      expect(tagline.top, greaterThan(screen.height * 0.5));
      expect(start.bottom, lessThanOrEqualTo(screen.height));
    });

    testWidgets('앱 이름은 본문 서체가 아니다 — 더 크고 더 좁다', (tester) async {
      await tester.pumpWidget(wrapApp(TitleScreen(onStart: () {})));
      await tester.pumpAndSettle();

      final wordmark = tester.widget<Text>(findText(TitleScreen.title));
      final style = wordmark.style!;
      // 타이틀 바탕은 항상 다크 테마다(CallBackdrop).
      final body = AppTheme.dark.textTheme;
      expect(
        style.fontSize,
        greaterThan(body.displaySmall!.fontSize!),
        reason: '예전에는 홈 헤더와 같은 displaySmall 이었다',
      );
      expect(
        style.fontSize,
        greaterThan(body.displayLarge!.fontSize!),
        reason: '앱에서 가장 큰 글자 한 낱말',
      );
      expect(
        style.letterSpacing,
        lessThan(body.displayLarge!.letterSpacing!),
        reason: '로고 수준으로 자간을 좁힌다',
      );
      // 한 줄로 고정. 폭이 모자라면 줄바꿈이 아니라 통째로 줄어든다.
      expect(wordmark.maxLines, 1);
      expect(find.byType(FittedBox), findsWidgets);
    });
  });

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
