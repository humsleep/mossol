import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/main.dart';
import 'package:mossol/ui/home_screen.dart';
import 'package:mossol/ui/intro_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('켜면 타이틀 화면이 먼저 나오고, 누르면 홈으로 간다', (tester) async {
    final c = await makeController();
    await tester.pumpWidget(MossolApp(controller: c, intro: true));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(IntroScreen), findsOneWidget);
    expect(find.text(IntroScreen.title), findsOneWidget);
    expect(find.text(IntroScreen.tagline), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.tap(find.byType(IntroScreen));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(IntroScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('작은 화면·큰 글꼴에서도 넘치지 않는다', (tester) async {
    useSmallScreenLargeFont(tester);
    final c = await makeController();
    await tester.pumpWidget(MossolApp(controller: c, intro: true));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text(IntroScreen.title), findsOneWidget);
  });

  testWidgets('테스트·기본값은 타이틀 없이 바로 홈', (tester) async {
    final c = await makeController();
    await tester.pumpWidget(fullApp(c));
    await tester.pump();
    expect(find.byType(IntroScreen), findsNothing);
  });
}
