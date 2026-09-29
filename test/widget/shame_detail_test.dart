/// 흑역사 상세·도장, 세로 그림 틀(SceneFrame), 선택 뒤 상대 표정(ReactionFace).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/album_index.dart';
import 'package:mossol/engine/effects.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/album_screen.dart';
import 'package:mossol/ui/ending_screen.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/scene_card.dart';
import 'package:mossol/ui/scene_registry.dart';

import 'helpers.dart';
import 'scene_helpers.dart';

/// 실제 세로 엔딩 그림(1024×1536)을 어느 경로로 물어도 돌려주는 번들.
class _PortraitBundle extends CachingAssetBundle {
  static final Uint8List _bytes = File('assets/endings/seoyeon_happy.webp')
      .readAsBytesSync();

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(_bytes);
}

void main() {
  late GameController c;

  setUp(() async {
    c = await makeController();
    await c.newGame(seed: 11, preference: Preference.female);
    SceneFrame.debugForget();
  });

  group('흑역사 카드·상세', () {
    const title = '택시에서 잠들어 종점';

    testWidgets('카드에 종류 라벨과 도장, 누르면 그날 대화(장면 → 내 선택 → 반응)', (tester) async {
      useScenes(paths: const ['assets/stamps/drink.png']);
      c.state!.album.add(title);
      await tester.pumpWidget(wrapApp(AlbumScreen(c: c)));
      await settleSceneImages(tester);

      expect(findText(title), findsOneWidget);
      expect(findText('술자리'), findsOneWidget);
      final stamp = tester.widget<ShameStampMark>(find.byType(ShameStampMark));
      expect(stamp.path, 'assets/stamps/drink.png');

      await tester.tap(findText(title));
      await tester.pumpAndSettle();
      expect(find.byType(ShameDetailSheet), findsOneWidget);
      final src = AlbumIndex.find(c.bundle.events, title, roster: {'seoyeon'})!;
      expect(findText('내 선택'), findsOneWidget);
      expect(findText(c.say(src.choice.text)), findsOneWidget);
      for (final l in src.aftermath) {
        expect(findText(c.say(l.text)), findsWidgets);
      }
      expect(findTextContaining('그날: ${src.event.title}'), findsOneWidget);
      expect(findText(ShameDetailSheet.quipFor(1)), findsOneWidget);
      // 상세에도 도장이 크게 한 번 더.
      expect(
        find.descendant(
          of: find.byType(ShameDetailSheet),
          matching: find.byType(ShameStampMark),
        ),
        findsOneWidget,
      );
    });

    testWidgets('도장 그림이 없으면 도장 자리 없이 글만, 출처 없는 옛 흑역사도 뜬다', (tester) async {
      useScenes();
      c.state!.album.add('술자리에서 노래 부름');
      await tester.pumpWidget(wrapApp(AlbumScreen(c: c)));
      await tester.pump();
      expect(find.byType(ShameStampMark), findsNothing);
      expect(findText('술자리'), findsOneWidget);
      await tester.tap(findText('술자리에서 노래 부름'));
      await tester.pumpAndSettle();
      expect(find.byType(ShameDetailSheet), findsOneWidget);
      expect(findText('내 선택'), findsNothing);
      expect(findText(ShameDetailSheet.quipFor(1)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SceneFrame', () {
    test('가로·정사각은 3:2, 세로는 실제 비율(최소 3:4)', () {
      expect(SceneFrame.aspectFor(1200, 800), SceneFrame.landscape);
      expect(SceneFrame.aspectFor(16, 16), SceneFrame.landscape);
      expect(SceneFrame.aspectFor(1024, 1536), SceneFrame.portraitMin);
      expect(SceneFrame.aspectFor(900, 1000), closeTo(0.9, 1e-9));
      expect(
        SceneFrame.aspectFor(1024, 1536, min: SceneFrame.viewerMin),
        closeTo(2 / 3, 1e-9),
      );
      expect(SceneFrame.aspectFor(0, 0), SceneFrame.landscape);
    });

    testWidgets('세로 엔딩 그림이면 히어로가 3:4 로 선다', (tester) async {
      final bundle = _PortraitBundle();
      SceneRegistry.debugOverride(
        SceneRegistry.fromAssets(const [
          'assets/endings/seoyeon_happy.webp',
        ], bundle: bundle),
      );
      addTearDown(() => SceneRegistry.debugOverride(null));
      c.state!.day = c.config.totalDays;
      await c.endDay();
      c.ending = c.bundle.endings.firstWhere((e) => e.id == 'seoyeon_happy');
      await tester.pumpWidget(wrapApp(EndingScreen(c: c)));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      final frame = tester.getSize(
        find.descendant(
          of: find.byType(EndingHero),
          matching: find.byType(AspectRatio),
        ),
      );
      expect(frame.width / frame.height, closeTo(SceneFrame.portraitMin, 0.01));
    });
  });

  group('선택 뒤 상대 표정', () {
    Future<void> outcome(WidgetTester tester, {required bool ok}) async {
      final ev = c.bundle.eventById['seoyeon_r03']!;
      c.current = ev;
      c.revealed = ev.lines.length;
      c.phase = Phase.event;
      await tester.pumpWidget(wrapApp(EventScreen(c: c)));
      c.choose(0, minigameSuccess: ok);
      await tester.pump();
      await settleReplies(tester);
    }

    test('표정 고르기: 성공 설렘 · 흑역사 실패 당황 · 그 밖 실패 시무룩', () {
      ChoiceOutcome o({required bool ok, bool crit = false, String? album}) =>
          ChoiceOutcome(
            success: ok,
            critical: crit,
            delta: AppliedDelta()..album = album,
          );
      expect(ReactionFace.moodFor(o(ok: true)), Expression.flutter);
      expect(ReactionFace.moodFor(o(ok: true, crit: true)), Expression.flutter);
      expect(
        ReactionFace.moodFor(o(ok: false, album: 'x')),
        Expression.flustered,
      );
      expect(ReactionFace.moodFor(o(ok: false)), Expression.sulky);
      // 상대: 이벤트 캐릭터 → 없으면 호감이 움직인 단 한 명.
      expect(
        ReactionFace.whoFor(c.bundle.eventById['seoyeon_r03'], AppliedDelta()),
        'seoyeon',
      );
      final one = AppliedDelta()..affection['haneul'] = 2;
      expect(ReactionFace.whoFor(null, one), 'haneul');
      final two = AppliedDelta()
        ..affection['haneul'] = 2
        ..affection['jiwoo'] = 1;
      expect(ReactionFace.whoFor(null, two), isNull);
    });

    testWidgets('성공이면 설렘 표정이 결과 옆에', (tester) async {
      useScenes(paths: const ['assets/expressions/seoyeon_flutter.png']);
      await outcome(tester, ok: true);
      await settleSceneImages(tester);
      final face = tester.widget<ReactionFace>(find.byType(ReactionFace));
      expect(face.mood, Expression.flutter);
      expect(face.path, 'assets/expressions/seoyeon_flutter.png');
      expect(find.bySemanticsLabel(RegExp('서연의 표정: 설렘')), findsOneWidget);
    });

    testWidgets('흑역사가 남은 실패는 당황', (tester) async {
      useScenes(
        paths: const [
          'assets/expressions/seoyeon_flustered.png',
          'assets/expressions/seoyeon_sulky.png',
        ],
      );
      await outcome(tester, ok: false);
      await settleSceneImages(tester);
      expect(c.lastOutcome!.delta.album, isNotNull);
      expect(
        tester.widget<ReactionFace>(find.byType(ReactionFace)).mood,
        Expression.flustered,
      );
    });

    testWidgets('표정 그림이 없으면 아무것도 없다', (tester) async {
      useScenes();
      await outcome(tester, ok: true);
      expect(find.byType(ReactionFace), findsNothing);
      expect(findText('계속'), findsOneWidget);
    });
  });
}
