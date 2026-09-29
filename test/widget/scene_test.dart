/// 장면 삽화·사진·스티커·엔딩 히어로 슬롯(docs/overhaul/06_scene_plan.md §1·§4).
///
/// 핵심 계약 둘:
///  1. 그림이 **하나도 없으면** 화면이 지금과 똑같다 — 카드도, 자리도, 여백도 없다.
///  2. 파일을 넣으면(가짜 번들) 같은 자리에 그림이 뜬다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/call_view.dart';
import 'package:mossol/ui/design_system.dart';
import 'package:mossol/ui/ending_screen.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/scene_card.dart';
import 'package:mossol/ui/widgets.dart';

import 'helpers.dart';
import 'retention_screen_test.dart' show endedRun;
import 'scene_helpers.dart';

/// 사진 줄이 있는 모먼트(events_moments.json). 아이콘은 `night`.
const photoEventId = 'mo_seoyeon_photo_night';

/// 전화 모먼트.
const callEventId = 'mo_seoyeon_call_eleven';

void main() {
  late GameController c;

  setUp(() async {
    c = await makeController();
    await c.newGame(seed: 11);
  });

  Future<void> showEvent(WidgetTester tester, String id) async {
    final ev = c.bundle.eventById[id]!;
    c.current = ev;
    c.revealed = ev.lines.length;
    c.phase = Phase.event;
    await tester.pumpWidget(wrapApp(EventScreen(c: c)));
    await settleSceneImages(tester);
  }

  group('그림이 없을 때(지금 저장소 상태)', () {
    testWidgets('채팅: 장면 카드가 자리를 잡지 않고 구분줄이 맨 위 그대로', (tester) async {
      useScenes();
      await showEvent(tester, 'm02');
      expect(find.byType(SceneImage), findsNothing);
      // 높이 0 — 카드도 여백도 없다(가로는 Column 이 늘린 빈 칸일 뿐).
      expect(tester.getSize(find.byType(SceneCard)).height, 0);
      // 구분줄이 대화 영역의 첫 줄(장면 카드가 위 여백조차 만들지 않는다).
      final divider = tester.getTopLeft(find.byType(ChatDivider));
      final scene = tester.getTopLeft(find.byType(SceneCard));
      expect(divider.dy, scene.dy);
    });

    testWidgets('사진: 지금까지의 아이콘 카드 그대로', (tester) async {
      useScenes();
      await showEvent(tester, photoEventId);
      expect(find.byType(PhotoBubble), findsWidgets);
      expect(find.byType(PhotoScene), findsWidgets);
      expect(find.byType(SceneImage), findsNothing);
      expect(find.byIcon(Icons.nightlight_round), findsWidgets);
    });

    testWidgets('스티커: 아무것도 그리지 않는다(빈 줄도 없음)', (tester) async {
      useScenes();
      await tester.pumpWidget(
        wrapApp(
          const Scaffold(
            body: StickerBubble(characterId: 'seoyeon', emotion: 'joy'),
          ),
        ),
      );
      await settleSceneImages(tester);
      expect(find.byType(Image), findsNothing);
      expect(tester.getSize(find.byType(StickerBubble)), Size.zero);
    });

    testWidgets('통화: 배경 삽화 없이 지금의 그라데이션', (tester) async {
      useScenes();
      await showEvent(tester, callEventId);
      expect(find.byType(CallBackdrop), findsOneWidget);
      expect(
        tester.widget<CallBackdrop>(find.byType(CallBackdrop)).image,
        isNull,
      );
      expect(find.byType(SceneImage), findsNothing);
    });

    testWidgets('엔딩: 히어로가 자리를 잡지 않는다', (tester) async {
      useScenes();
      final ended = await endedRun(null, c);
      await tester.pumpWidget(wrapApp(EndingScreen(c: ended)));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(EndingHero)), Size.zero);
      expect(find.byType(SceneImage), findsNothing);
      expect(findText(ended.ending!.name), findsOneWidget);
    });
  });

  group('그림이 있을 때(가짜 번들)', () {
    testWidgets('채팅: 구분줄 위 풀폭 3:2 카드', (tester) async {
      useScenes(paths: const ['assets/scenes/m02.png']);
      await showEvent(tester, 'm02');
      final image = find.descendant(
        of: find.byType(SceneCard),
        matching: find.byType(SceneImage),
      );
      expect(image, findsOneWidget);
      final card = tester.getSize(
        find.descendant(
          of: find.byType(SceneCard),
          matching: find.byType(AspectRatio),
        ),
      );
      final screen = tester.getSize(find.byType(Scaffold)).width;
      expect(card.width, screen - SceneCard.inset * 2);
      expect(card.height / card.width, closeTo(1 / AppSize.sceneAspect, 0.01));
      // 그림은 구분줄 위에 있다.
      expect(
        tester.getTopLeft(find.byType(SceneCard)).dy,
        lessThan(tester.getTopLeft(find.byType(ChatDivider)).dy),
      );
      expect(
        tester.widget<SceneImage>(image).path,
        'assets/scenes/m02.png',
      );
    });

    testWidgets('사진: 폴라로이드 안이 실제 그림으로 바뀐다', (tester) async {
      useScenes(paths: const ['assets/photos/night.png']);
      await showEvent(tester, photoEventId);
      final window = find.descendant(
        of: find.byType(PolaroidFrame),
        matching: find.byType(SceneImage),
      );
      expect(window, findsWidgets);
      expect(find.byType(PhotoScene), findsNothing, reason: '아이콘 카드는 대체됐다');
    });

    testWidgets('사진: photo.image 가 아이콘 공용보다 우선', (tester) async {
      useScenes(
        paths: const [
          'assets/photos/night.png',
          'assets/photos/mo_seoyeon_photo_night_0.png',
        ],
      );
      await tester.pumpWidget(
        wrapApp(
          const Scaffold(
            body: PhotoBubble(
              photo: Photo(
                icon: 'night',
                caption: '창밖',
                image: 'assets/photos/mo_seoyeon_photo_night_0.png',
              ),
            ),
          ),
        ),
      );
      await settleSceneImages(tester);
      expect(
        tester.widget<SceneImage>(find.byType(SceneImage)).path,
        'assets/photos/mo_seoyeon_photo_night_0.png',
      );
    });

    testWidgets('스티커: 120 정사각 한 장 + 스크린리더 라벨', (tester) async {
      useScenes(paths: const ['assets/stickers/seoyeon_joy.png']);
      await tester.pumpWidget(
        wrapApp(
          const Scaffold(
            body: StickerBubble(
              characterId: 'seoyeon',
              emotion: 'joy',
              name: '서연',
            ),
          ),
        ),
      );
      await settleSceneImages(tester);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, AppSize.sticker);
      expect(image.height, AppSize.sticker);
      expect(image.semanticLabel, '서연 스티커: 기쁨');
    });

    testWidgets('스티커: 화이트리스트 밖 감정은 그리지 않는다', (tester) async {
      useScenes(paths: const ['assets/stickers/seoyeon_angry.png']);
      await tester.pumpWidget(
        wrapApp(
          const Scaffold(
            body: StickerBubble(characterId: 'seoyeon', emotion: 'angry'),
          ),
        ),
      );
      await settleSceneImages(tester);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('통화: 삽화가 배경으로 깔린다', (tester) async {
      useScenes(paths: const ['assets/scenes/$callEventId.png']);
      await showEvent(tester, callEventId);
      expect(
        tester.widget<CallBackdrop>(find.byType(CallBackdrop)).image,
        'assets/scenes/$callEventId.png',
      );
      expect(find.byType(SceneImage), findsOneWidget);
    });

    testWidgets('엔딩: 이름 위에 히어로 3:2', (tester) async {
      final ended = await endedRun(null, c);
      final e = ended.ending!;
      useScenes(paths: ['assets/endings/${e.id}.png']);
      await tester.pumpWidget(wrapApp(EndingScreen(c: ended)));
      await settleSceneImages(tester);
      final hero = find.byType(EndingHero);
      expect(
        find.descendant(of: hero, matching: find.byType(SceneImage)),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(hero).dy,
        lessThanOrEqualTo(tester.getTopLeft(findText(e.name)).dy),
      );
    });

    testWidgets('깨진 파일은 깨진 상자 대신 카드를 접는다', (tester) async {
      useScenes(paths: const ['assets/scenes/m02.png'], fail: true);
      await showEvent(tester, 'm02');
      await tester.pump();
      expect(tester.getSize(find.byType(SceneCard)).height, 0);
      expect(find.byType(AspectRatio), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('동작 줄이기: 켄번즈 없이 정지 그림', (tester) async {
      useScenes(paths: const ['assets/scenes/m02.png']);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures.allOn;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await showEvent(tester, 'm02');
      expect(find.byType(SceneImage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SceneCard),
          matching: find.byType(TweenAnimationBuilder<double>),
        ),
        findsNothing,
      );
    });
  });
}
