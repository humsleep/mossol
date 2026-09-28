import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/ui/action_screen.dart';
import 'package:mossol/ui/album_screen.dart';
import 'package:mossol/ui/relation_sheet.dart';
import 'package:mossol/ui/stat_guide.dart';

import 'helpers.dart';

void main() {
  testWidgets('관계는 한 줄이고, 누르면 상세가 뜬다', (tester) async {
    final c = await makeController();
    await c.newGame(seed: 5);
    c.state!
      ..rouletteDay = c.state!.day
      ..rel('seoyeon').affection = 46;
    await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
    await tester.pumpAndSettle();

    final strip = find.byType(RelationStrip);
    expect(strip, findsOneWidget);
    // 모든 칸이 같은 세로 위치(한 줄).
    final tops = {
      for (final e in find
          .descendant(of: strip, matching: find.byType(InkWell))
          .evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dy,
    };
    expect(tops.length, 1);

    await tester.tap(find.byKey(const Key('relation-seoyeon')));
    await tester.pumpAndSettle();
    expect(find.byType(RelationDetailSheet), findsOneWidget);
    expect(find.text('46 / 100'), findsOneWidget);
    expect(find.text('이건 조심'), findsOneWidget);
  });

  testWidgets('스탯 설명 시트에 여섯 스탯이 모두 있다', (tester) async {
    final c = await makeController();
    await c.newGame(seed: 5);
    c.state!.rouletteDay = c.state!.day;
    await tester.pumpWidget(wrapApp(ActionScreen(c: c)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stat-guide')));
    await tester.pumpAndSettle();
    expect(find.text(StatGuideSheet.title), findsOneWidget);
    expect(statGuide.length, 6);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('흑역사를 누르면 그날의 장면이 나온다', (tester) async {
    final c = await makeController();
    await c.newGame(seed: 5);
    c.state!.album.add('삭제 실패, 읽음 1');
    await tester.pumpWidget(wrapApp(AlbumScreen(c: c)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제 실패, 읽음 1'));
    await tester.pumpAndSettle();
    expect(find.byType(ShameDetailSheet), findsOneWidget);
    expect(findTextContaining('그날:'), findsOneWidget);
    expect(find.text('내 선택'), findsOneWidget);
  });
}
