/// 행동 화면의 관계 줄 · 관계 상세 시트 · 스탯 설명 시트 · 행동 썸네일, 홈 키 아트.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/action_screen.dart';
import 'package:mossol/ui/home_screen.dart';
import 'package:mossol/ui/relation_sheet.dart';
import 'package:mossol/ui/scene_card.dart';
import 'package:mossol/ui/stat_guide.dart';
import 'package:mossol/ui/widgets.dart' show StatBars;

import 'helpers.dart';
import 'scene_helpers.dart';

void main() {
  Future<GameController> morning() async {
    final c = await makeController();
    await c.newGame(seed: 5);
    c.beginMorning();
    c.state!.rouletteDay = c.state!.day; // 룰렛 시트는 이미 돌린 걸로.
    return c;
  }

  testWidgets('관계는 한 줄이고, 누르면 상세가 뜬다', (tester) async {
    final c = await morning();
    c.state!.rel('seoyeon')
      ..affection = 46
      ..trust = 20;
    for (final id in ['jiwoo', 'yeeun', 'daeun', 'sohee']) {
      c.state!.rel(id).affection = 10;
    }
    await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
    await tester.pumpAndSettle();

    final strip = find.byType(RelationStrip);
    expect(strip, findsOneWidget);
    expect(findTextContaining('서연 ♥46'), findsOneWidget);
    // 모든 칸이 같은 세로 위치(한 줄).
    final tiles = find.descendant(of: strip, matching: find.byType(InkWell));
    expect(tiles.evaluate().length, greaterThan(3));
    final tops = {
      for (final e in tiles.evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dy,
    };
    expect(tops.length, 1);
    // 화면의 세로 ListView 는 여전히 하나다.
    expect(find.byType(ListView), findsOneWidget);

    await tester.tap(find.byKey(const Key('relation-seoyeon')));
    await tester.pumpAndSettle();
    expect(find.byType(RelationDetailSheet), findsOneWidget);
    expect(find.text('46 / 100'), findsOneWidget);
    expect(find.text('20 / 100'), findsOneWidget);
    expect(findText(RelationDetailSheet.stageOf(46)), findsOneWidget);
    expect(find.text('이건 조심'), findsOneWidget);
    expect(find.text('이 사람이 끌리는 것'), findsOneWidget);
    // 그림이 없으면 표정 줄도 없다.
    expect(find.byType(SceneImage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('표정 그림이 있으면 지금 분위기의 얼굴이 크게, 세 표정은 골라 볼 수 있다', (tester) async {
    useScenes(
      paths: [
        for (final m in ['flutter', 'flustered', 'sulky'])
          'assets/expressions/seoyeon_$m.webp',
      ],
    );
    final c = await morning();
    c.state!.rel('seoyeon')
      ..affection = 62
      ..trust = 40;
    await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('relation-seoyeon')));
    await tester.pumpAndSettle();
    await settleSceneImages(tester);

    // 호감 62 → 설렘이 지금 분위기.
    expect(findText('지금 · 설렘'), findsOneWidget);
    for (final m in ['flutter', 'flustered', 'sulky']) {
      expect(find.byKey(Key('mood-$m')), findsOneWidget);
    }
    expect(
      tester.getSemantics(find.byKey(const Key('mood-flutter'))),
      matchesSemantics(
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
        isSelected: true,
        hasSelectedState: true,
        label: '설렘 표정, 지금 분위기',
      ),
    );

    await tester.tap(find.byKey(const Key('mood-sulky')));
    await tester.pumpAndSettle();
    expect(findText('삐짐'), findsNWidgets(2)); // 큰 그림 pill + 줄의 이름
    expect(findText('지금 · 설렘'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('분위기: 밤사이 멀어짐·믿음 부족은 삐짐, 높으면 설렘, 중간은 당황, 낮으면 평소', () {
    String? m(int a, int t, {bool d = false}) =>
        RelationDetailSheet.moodOf(affection: a, trust: t, dropped: d);
    expect(m(70, 40, d: true), 'sulky');
    expect(m(40, 2), 'sulky');
    expect(m(55, 30), 'flutter');
    expect(m(30, 30), 'flustered');
    expect(m(10, 0), isNull);
  });

  testWidgets('스탯 설명: 머리줄 버튼과 막대 탭 둘 다 연다, 여섯 스탯이 모두 있다', (tester) async {
    final c = await morning();
    await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
    await tester.pumpAndSettle();
    expect(findText('내 스탯'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stat-guide')));
    await tester.pumpAndSettle();
    expect(find.text(StatGuideSheet.title), findsOneWidget);
    expect(statGuide.length, 6);
    await tester.drag(
      find.byKey(const Key('stat-guide-scroll')),
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(StatGuideSheet))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(StatBars));
    await tester.pumpAndSettle();
    expect(find.byType(StatGuideSheet), findsOneWidget);
  });

  test('스탯 설명의 아침 행동 줄은 config.json 수치에서 뽑는다', () {
    final actions = testBundle().config.actions;
    expect(StatGuideSheet.actionLine(Stat.charm, actions), '헬스장 +1 · 스타일링 +2');
    // 스트레스는 내리는 쪽(휴식)이 먼저.
    expect(
      StatGuideSheet.actionLine(Stat.stress, actions),
      startsWith('집에서 휴식 -12'),
    );
    expect(
      StatGuideSheet.actionLine(Stat.money, actions),
      '알바 +1.5만원 · 스타일링 -1만원 · 친구 만나기 -5천원',
    );
  });

  testWidgets('행동 행: 장소 그림이 있으면 썸네일, 없으면 아이콘 원', (tester) async {
    useScenes(paths: ['assets/scenes/gym.webp']);
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = await morning();
    await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
    await tester.pumpAndSettle();
    await settleSceneImages(tester);
    // 헬스장만 그림이 있다.
    expect(find.byType(SceneImage), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsOneWidget); // 썸네일 배지
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget); // 아이콘 원
    expect(tester.takeException(), isNull);
  });

  testWidgets('홈: 키 아트가 있으면 소개 카드 바탕에 깔리고 문구는 그대로', (tester) async {
    useScenes(paths: ['assets/keyart/home.webp']);
    final c = await makeController();
    await tester.pumpWidget(wrapApp(HomeScreen(c: c)));
    await tester.pump();
    await settleSceneImages(tester);
    expect(find.byType(SceneImage), findsOneWidget);
    expect(findText('100일 뒤, 나는 달라져 있을까'), findsOneWidget);
    expect(findText('아침: 오늘 할 일 하나 고르기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(Container());
  });
}
