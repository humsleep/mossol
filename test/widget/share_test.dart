// 엔딩 공유(`KeepsakeShare` · `EndingScreen` 의 `엔딩 공유` 버튼).
// 규격 docs/DESIGN_SYSTEM.md §2.5, 근거 docs/review/11_polish_verdict.md 10위.
//
// 예전에는 `shareBoundaryKey` 가 트리에 꽂혀 있었지만 `toImage()` 를 부르는 곳이 없는
// **죽은 경계**였다. 여기서 보는 것은 세 가지다:
// ① 정말로 PNG 가 구워지는가(가짜 바이트가 아니라 실제 `toImage`),
// ② 나가는 것이 기념품 카드뿐인가(버튼·다음 판 카드는 경계 밖),
// ③ 못 할 때 예외가 아니라 스낵바 한 줄로 끝나는가.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/ending_screen.dart';
import 'package:mossol/ui/keepsake_share.dart';
import 'package:mossol/ui/retention_widgets.dart';

import 'helpers.dart';

/// PNG 파일의 첫 여덟 바이트.
const _pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// 시스템 시트 대신 넘어온 것만 적어 두는 공유. 굽는 단계는 [captureBytes] 로 가른다.
class _FakeShare extends KeepsakeShare {
  _FakeShare({this.ok = true, this.boom = false, this.captureBytes = true});

  final bool ok;
  final bool boom;

  /// false 면 "그림을 못 구웠다"(아직 안 그려진 경계·지원하지 않는 기기).
  final bool captureBytes;

  int captures = 0;
  int shares = 0;
  Uint8List? png;
  String? text;
  Rect? origin;

  /// 정하면 이 시트가 열린 채로 멈춘다(두 번 눌러도 한 번인지 보려고).
  Completer<bool>? gate;

  @override
  Future<Uint8List?> capture(
    GlobalKey key, {
    required double pixelRatio,
  }) async {
    captures++;
    return captureBytes ? Uint8List.fromList(_pngMagic) : null;
  }

  @override
  Future<bool> sharePng(
    Uint8List png, {
    required String text,
    Rect? origin,
  }) async {
    shares++;
    this.png = png;
    this.text = text;
    this.origin = origin;
    if (boom) throw StateError('공유 시트를 열 수 없는 기기');
    final g = gate;
    if (g != null) return g.future;
    return ok;
  }
}

void main() {
  late GameController c;

  setUp(() async {
    c = await makeController();
    await c.newGame(seed: 3);
    c.state!.day = c.config.totalDays;
    await c.endDay();
    expect(c.ending, isNotNull);
  });

  T use<T extends KeepsakeShare>(T fake) {
    KeepsakeShare.instance = fake;
    addTearDown(() => KeepsakeShare.instance = KeepsakeShare());
    return fake;
  }

  Future<void> showEnding(WidgetTester tester, {ThemeMode? mode}) async {
    await tester.pumpWidget(
      wrapApp(EndingScreen(c: c), mode: mode ?? ThemeMode.light),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ending-share')));
    await tester.pumpAndSettle();
  }

  testWidgets('공유 버튼은 기념품 밖에 있다 — 캡처에 버튼이 들어가지 않는다', (tester) async {
    await showEnding(tester);
    final boundary = find.byKey(EndingScreen.shareBoundaryKey);
    expect(boundary, findsOneWidget);

    // 경계 안에 있는 것: 엔딩 이름과 등급. 즉 기념품.
    expect(
      find.descendant(of: boundary, matching: findText(c.ending!.name)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: boundary, matching: findText('연애 등급')),
      findsOneWidget,
    );
    // 경계 밖에 있는 것: 공유 버튼, 1차 버튼, 다음 판 카드.
    expect(
      find.descendant(
        of: boundary,
        matching: find.byKey(const Key('ending-share')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: boundary, matching: findText('2회차 시작')),
      findsNothing,
    );
    expect(
      find.descendant(of: boundary, matching: find.byType(NextRunCard)),
      findsNothing,
    );
    // 1차 버튼은 여전히 `N회차 시작` 하나다.
    expect(findText(EndingScreen.shareLabel), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('누르면 카드가 시트로 간다 — 곁들이는 문구는 앱 이름 한 줄뿐', (tester) async {
    final fake = use(_FakeShare());
    await showEnding(tester);
    await tester.tap(find.byKey(const Key('ending-share')));
    await tester.pumpAndSettle();

    expect(fake.captures, 1);
    expect(fake.shares, 1);
    expect(fake.text, EndingScreen.shareText);
    // 플레이어의 이름·기록이 문구로 새어 나가지 않는다.
    expect(fake.text, isNot(contains(c.ending!.name)));
    // 아이패드용 기준 사각형(버튼 자리)을 함께 넘긴다.
    expect(fake.origin, isNotNull);
    expect(fake.origin!.width, greaterThan(0));
    // 잘 됐으면 아무 말도 하지 않는다.
    expect(findText(EndingScreen.shareFailedText), findsNothing);
  });

  testWidgets('경계가 정말로 PNG 로 구워진다 (실제 toImage)', (tester) async {
    await showEnding(tester);
    // `toImage` 는 엔진의 실제 비동기 작업이라 `runAsync` 안에서만 끝난다.
    final bytes = await tester.runAsync(
      () => KeepsakeShare().capture(
        EndingScreen.shareBoundaryKey,
        pixelRatio: tester.view.devicePixelRatio,
      ),
    );
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(_pngMagic.length));
    expect(bytes.sublist(0, 8), _pngMagic);
  });

  testWidgets('없는 경계를 구우라고 하면 예외 대신 null', (tester) async {
    await showEnding(tester);
    final bytes = await tester.runAsync(
      () => KeepsakeShare().capture(GlobalKey(), pixelRatio: 1),
    );
    expect(bytes, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그림을 못 구우면 스낵바 한 줄 — 시트는 열지 않는다', (tester) async {
    final fake = use(_FakeShare(captureBytes: false));
    await showEnding(tester);
    await tester.tap(find.byKey(const Key('ending-share')));
    await tester.pumpAndSettle();

    expect(fake.shares, 0);
    expect(findText(EndingScreen.shareFailedText), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 화면은 그대로 남는다 — 보상 화면을 잃지 않는다.
    expect(findText(c.ending!.name), findsOneWidget);
  });

  testWidgets('공유가 안 되는 기기(false)도, 터지는 기기(throw)도 스낵바로 끝난다', (tester) async {
    for (final fake in [_FakeShare(ok: false), _FakeShare(boom: true)]) {
      use(fake);
      await showEnding(tester);
      await tester.tap(find.byKey(const Key('ending-share')));
      await tester.pumpAndSettle();
      expect(findText(EndingScreen.shareFailedText), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(findText('2회차 시작'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('두 번 눌러도 시트는 한 번만 열린다', (tester) async {
    final fake = use(_FakeShare()..gate = Completer<bool>());
    await showEnding(tester);
    await tester.tap(find.byKey(const Key('ending-share')));
    await tester.pump();
    // 도는 동안 버튼은 꺼져 있다.
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('ending-share')))
          .onPressed,
      isNull,
    );
    await tester.tap(
      find.byKey(const Key('ending-share')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(fake.shares, 1);
    fake.gate!.complete(true);
    await tester.pumpAndSettle();
    expect(fake.shares, 1);
    expect(findText(EndingScreen.shareFailedText), findsNothing);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode == ThemeMode.dark ? '다크' : '라이트';
    testWidgets('320x568 1.3배 $tag: 공유 버튼이 넘치지 않고 탭 타깃을 지킨다', (tester) async {
      useSmallScreenLargeFont(tester);
      if (mode == ThemeMode.dark) useDarkMode(tester);
      await showEnding(tester, mode: mode);
      expect(tester.takeException(), isNull);

      final share = tester.getRect(find.byKey(const Key('ending-share')));
      expect(share.height, greaterThanOrEqualTo(44));
      expect(share.left, greaterThanOrEqualTo(0));
      expect(share.right, lessThanOrEqualTo(320));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }
}
