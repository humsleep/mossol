/// 캐릭터 초상화: 규칙 기반 목록([PortraitRegistry])과 [CharacterAvatar] 의 세 상태
/// (그림 있음 · 없음 · 로드 실패) + 히든 실루엣 + 레이아웃 불변.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/ui/design_system.dart';
import 'package:mossol/ui/portraits.dart';
import 'package:mossol/ui/widgets.dart';

import 'helpers.dart';
import 'portrait_helpers.dart';

void main() {
  group('PortraitRegistry.fromAssets', () {
    test('assets/portraits/<id>.<확장자> 만 고르고 png 를 먼저 쓴다', () {
      final r = PortraitRegistry.fromAssets([
        'assets/story/characters.json',
        'assets/portraits/.gitkeep',
        'assets/portraits/seoyeon.jpg',
        'assets/portraits/seoyeon.png',
        'assets/portraits/jiwoo.JPG',
        'assets/portraits/drafts/haneul.png',
        'assets/portraits/readme.txt',
        'assets/icon/app_icon.png',
      ]);
      expect(r.pathFor('seoyeon'), 'assets/portraits/seoyeon.png');
      expect(r.pathFor('jiwoo'), 'assets/portraits/jiwoo.JPG');
      expect(r.pathFor('haneul'), isNull, reason: '하위 폴더는 무시');
      expect(r.pathFor('readme'), isNull);
      expect(r.pathFor(null), isNull);
      expect(r.ids.toSet(), {'seoyeon', 'jiwoo'});
    });

    test('실제 번들 매니페스트를 읽고, 찾은 파일은 전부 캐릭터 id 다', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      addTearDown(() => PortraitRegistry.debugOverride(null));
      final r = await PortraitRegistry.load();
      expect(
        portraitIds.toSet().containsAll(r.ids),
        isTrue,
        reason: '${r.ids}',
      );
      expect(identical(PortraitRegistry.current, r), isTrue);
    });

    test('매니페스트를 못 읽으면 던지지 않고 빈 목록', () async {
      addTearDown(() => PortraitRegistry.debugOverride(null));
      final r = await PortraitRegistry.load(bundle: FixturePortraitBundle());
      expect(r.length, 0);
    });
  });

  group('CharacterAvatar', () {
    Future<void> pumpAvatar(
      WidgetTester tester, {
      String? id = 'seoyeon',
      bool byAccentOnly = false,
      bool mystery = false,
      double size = 56,
      ThemeMode mode = ThemeMode.light,
    }) async {
      await tester.pumpWidget(
        wrapApp(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: CharacterAvatar(
                  key: const Key('avatar'),
                  name: '서연',
                  characterId: byAccentOnly ? null : id,
                  accent: mystery ? null : context.tokens.accentFor(id),
                  mystery: mystery,
                  size: size,
                ),
              ),
            ),
          ),
          mode: mode,
        ),
      );
      await settleImages(tester);
    }

    Finder portraitImage() => find.descendant(
      of: find.byKey(const Key('avatar')),
      matching: find.byType(Image),
    );

    testWidgets('초상화가 없으면 이니셜(지금 그대로)', (tester) async {
      await pumpAvatar(tester);
      expect(find.text('서'), findsOneWidget);
      expect(find.byType(PortraitImage), findsNothing);
      expect(
        tester.getSize(find.byKey(const Key('avatar'))),
        const Size(56, 56),
      );
    });

    testWidgets('초상화가 있으면 원형 그림 + 강조색 테두리, 크기 같음', (tester) async {
      usePortraits();
      await pumpAvatar(tester);
      expect(find.byType(PortraitImage), findsOneWidget);
      expect(find.byType(ClipOval), findsOneWidget);
      expect(portraitImage(), findsOneWidget);
      // 디코딩이 끝나 이니셜 대신 그림이 보인다.
      expect(find.text('서'), findsNothing);
      final img = tester.widget<Image>(portraitImage());
      expect(img.semanticLabel, '서연');
      expect(img.image, isA<ResizeImage>());
      expect(
        (img.image as ResizeImage).width,
        (56 * PortraitImage.zoom * 3).ceil(),
        reason: 'cacheWidth — 확대분까지 선명하게',
      );
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('avatar')),
              matching: find.byType(Container),
            )
            .first,
      );
      final fg = box.foregroundDecoration! as BoxDecoration;
      final ctx = tester.element(find.byKey(const Key('avatar')));
      expect(
        (fg.border! as Border).top.color,
        ctx.tokens.accentFor('seoyeon').base,
      );
      expect(
        tester.getSize(find.byKey(const Key('avatar'))),
        const Size(56, 56),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('id 없이 accentFor 강조색만 줘도 캐릭터를 찾는다', (tester) async {
      usePortraits();
      await pumpAvatar(tester, byAccentOnly: true);
      expect(find.byType(PortraitImage), findsOneWidget);
    });

    testWidgets('다른 사람 그림만 있으면 이니셜', (tester) async {
      usePortraits(ids: ['jiwoo']);
      await pumpAvatar(tester);
      expect(find.byType(PortraitImage), findsNothing);
      expect(find.text('서'), findsOneWidget);
    });

    testWidgets('목록엔 있는데 로드 실패면 이니셜로 대체, 오류 없음', (tester) async {
      usePortraits(fail: true);
      await pumpAvatar(tester);
      expect(find.byType(PortraitImage), findsOneWidget);
      expect(find.text('서'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('avatar'))),
        const Size(56, 56),
      );
    });

    testWidgets('히든 미공개(mystery)는 그림이 있어도 실루엣', (tester) async {
      usePortraits();
      await pumpAvatar(tester, id: 'yuna', mystery: true);
      expect(find.byType(PortraitImage), findsNothing);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('avatar'))).label,
        '아직 만나지 않은 사람',
      );
    });

    testWidgets('스크린리더에는 이름 하나만 읽힌다', (tester) async {
      usePortraits();
      final handle = tester.ensureSemantics();
      await pumpAvatar(tester);
      expect(find.bySemanticsLabel('서연'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('목록이 늦게 와도 이니셜 → 그림으로 바뀐다', (tester) async {
      await pumpAvatar(tester);
      expect(find.text('서'), findsOneWidget);
      usePortraits();
      await tester.pump();
      await settleImages(tester);
      expect(find.byType(PortraitImage), findsOneWidget);
      expect(find.text('서'), findsNothing);
    });
  });

  test('테스트 PNG 가 있다', () {
    expect(FixturePortraitBundle().load('assets/portraits/x.png'), completes);
    expect(
      FixturePortraitBundle(fail: true).load('assets/portraits/x.png'),
      throwsA(isA<FlutterError>()),
    );
  });
}
