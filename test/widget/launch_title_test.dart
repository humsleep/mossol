import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/main.dart';
import 'package:mossol/ui/home_screen.dart';
import 'package:mossol/ui/intro_screen.dart';
import 'package:mossol/ui/title_screen.dart';
import 'package:mossol/ui/launch_title_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('켜면 라인업 타이틀이 먼저 나오고, 누르면 게임으로 간다', (tester) async {
    final c = await makeController();
    await tester.pumpWidget(MossolApp(controller: c, launchTitle: true));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(LaunchTitleScreen), findsOneWidget);
    expect(find.text(LaunchTitleScreen.title), findsOneWidget);
    expect(find.text(LaunchTitleScreen.tagline), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.tap(find.byType(LaunchTitleScreen));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LaunchTitleScreen), findsNothing);
  });

  testWidgets('첫 실행이면 라인업 타이틀 다음에 태현의 알림부터(타이틀 두 번 없음)', (tester) async {
    final c = await makeController(firstLaunch: true);
    await tester.pumpWidget(MossolApp(controller: c, launchTitle: true));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byType(LaunchTitleScreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(IntroScreen), findsOneWidget);
    expect(find.byType(TitleScreen), findsNothing);
    expect(findText(IntroScreen.previewLine), findsOneWidget);
    // 알림 자동 열림 타이머를 흘려보낸다.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('작은 화면·큰 글꼴에서도 넘치지 않는다', (tester) async {
    useSmallScreenLargeFont(tester);
    final c = await makeController();
    await tester.pumpWidget(MossolApp(controller: c, launchTitle: true));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text(LaunchTitleScreen.title), findsOneWidget);
  });

  testWidgets('테스트·기본값은 타이틀 없이 바로 게임', (tester) async {
    final c = await makeController();
    await tester.pumpWidget(fullApp(c));
    await tester.pump();
    expect(find.byType(LaunchTitleScreen), findsNothing);
  });
}
