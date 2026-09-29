// 진행 막대(`AppProgressBar`)가 흐르는지. docs/DESIGN_SYSTEM.md §3.1·§1.10.
//
// 근거: docs/review/11_polish_verdict.md 15위 — 막대가 암시 애니메이션 없는 맨
// `FractionallySizedBox` 라서, `Timer.periodic(100ms)` 가 미는 미니게임 시간 막대가
// **초당 열 번 계단처럼** 튀었다.
//
// 흐르는 시간은 "값이 바뀐 간격" 이다. 그래서 여기서 보는 것은 세 가지다:
// ① 100ms 박자로 밀면 중간값을 지나간다(계단이 아니다),
// ② 부모가 프레임마다 밀면 겹쳐 돌지 않고 그대로 따라간다(뒤처지지 않는다),
// ③ 동작 줄이기면 흐르지 않는다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/ui/design_system.dart';
import 'package:mossol/ui/widgets.dart';

import 'helpers.dart';

void main() {
  /// 지금 화면에 그려진 채움 비율.
  double fill(WidgetTester tester) => tester
      .widget<FractionallySizedBox>(
        find.descendant(
          of: find.byType(AppProgressBar),
          matching: find.byType(FractionallySizedBox),
        ),
      )
      .widthFactor!;

  /// 값을 밖에서 밀 수 있는 막대 하나. [reduced] 면 동작 줄이기 상태로 띄운다.
  Future<void Function(double)> mount(
    WidgetTester tester, {
    bool reduced = false,
  }) async {
    var value = 0.0;
    late StateSetter setter;
    final widget = StatefulBuilder(
      builder: (context, setState) {
        setter = setState;
        return Center(
          child: SizedBox(
            width: 200,
            child: AppProgressBar(value: value, semanticLabel: '진행도'),
          ),
        );
      },
    );
    if (reduced) useReducedMotion(tester);
    await tester.pumpWidget(wrapApp(widget));
    return (double v) => setter(() => value = v);
  }

  testWidgets('첫 값은 그대로 그린다 — 0 에서 기어오지 않는다', (tester) async {
    await tester.pumpWidget(
      wrapApp(
        const Center(
          child: SizedBox(
            width: 200,
            child: AppProgressBar(value: 0.4, semanticLabel: '진행도'),
          ),
        ),
      ),
    );
    expect(fill(tester), closeTo(0.4, 0.001));
  });

  testWidgets('값이 바뀌면 그 자리로 튀지 않고 흐른다', (tester) async {
    final push = await mount(tester);

    push(0.4);
    await tester.pump(const Duration(seconds: 1));
    // 값이 바뀐 프레임에는 아직 옛 값이다 — 여기서 0.4 면 "튀었다" 는 뜻이다.
    expect(fill(tester), closeTo(0.0, 0.001));

    await tester.pump(AppMotion.dBase);
    expect(fill(tester), closeTo(0.4, 0.001));
  });

  testWidgets('100ms 박자로 밀면 중간값을 지나간다', (tester) async {
    final push = await mount(tester);

    // 박자를 알려 준다 — 100ms 간격으로 세 번.
    for (final v in [0.4, 0.5, 0.6]) {
      push(v);
      await tester.pump(const Duration(milliseconds: 100));
    }
    // 간격이 100ms 였으므로 앞 구간은 딱 맞게 끝나 있다.
    expect(fill(tester), closeTo(0.5, 0.01));

    // 네 번째를 밀고 절반만 흘린다.
    push(0.7);
    await tester.pump(const Duration(milliseconds: 50));
    final mid = fill(tester);
    expect(mid, greaterThan(0.5), reason: '움직이지 않았다 = 계단');
    expect(mid, lessThan(0.7), reason: '끝까지 갔다 = 튀었다');

    await tester.pump(const Duration(milliseconds: 60));
    expect(fill(tester), closeTo(0.7, 0.01));
  });

  testWidgets('부모가 프레임마다 밀면 겹쳐 돌지 않고 그대로 따라간다', (tester) async {
    final push = await mount(tester);

    // 16ms 간격 = `AppProgressBar.liveInterval` 안쪽. 부모가 이미 애니메이션 중이다
    // (`timing_games.dart` 의 "길게 누르기" 막대가 550ms 를 프레임마다 채운다).
    for (final v in [0.2, 0.4, 0.6, 0.8]) {
      push(v);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(fill(tester), closeTo(0.8, 0.001), reason: '막대가 부모보다 늦게 도착한다');
  });

  testWidgets('동작 줄이기: 흐르지 않고 곧바로 새 값이다 (§1.10)', (tester) async {
    final push = await mount(tester, reduced: true);

    push(0.4);
    await tester.pump(const Duration(seconds: 1));
    expect(fill(tester), closeTo(0.4, 0.001));
    push(0.9);
    await tester.pump(const Duration(milliseconds: 16));
    expect(fill(tester), closeTo(0.9, 0.001));
  });

  testWidgets('스크린리더는 흐르는 중간값이 아니라 지금 값을 읽는다', (tester) async {
    final handle = tester.ensureSemantics();
    final push = await mount(tester);

    push(0.42);
    await tester.pump(const Duration(seconds: 1));
    // 그림은 아직 0 쪽이지만 값은 42% 다.
    expect(fill(tester), lessThan(0.42));
    expect(tester.getSemantics(find.byType(AppProgressBar)).value, '42%');
    expect(tester.getSemantics(find.byType(AppProgressBar)).label, '진행도');
    handle.dispose();
  });

  testWidgets('NaN·범위 밖 값에도 무너지지 않는다', (tester) async {
    final push = await mount(tester);
    push(double.nan);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(fill(tester), closeTo(0.0, 0.001));
    push(3.0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(AppMotion.dGaugeMax);
    expect(fill(tester), closeTo(1.0, 0.001));
    expect(tester.takeException(), isNull);
  });
}
