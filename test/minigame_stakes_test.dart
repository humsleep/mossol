// 미니게임의 판돈과 문턱. docs/review/11_polish_verdict.md §1 3위 · docs/review/12_audio_fixes.md.
//
// 여기서 보는 것 셋.
// 1. 질 수 있는가 — 질 수 없는 게임은 "탭 앞에 붙은 지연" 이다.
// 2. 초반에 보이는가 — 눈치 40 문턱은 시작값 25 에서 닿지 않아 초반엔 없는 장치였다.
// 3. 실패가 손에 남는가 — 실패 결과의 소리·진동이 성공과 다른지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/audio/sfx_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/push_games.dart';
import 'package:mossol/minigames/timing_games.dart';

import 'widget/helpers.dart';

MinigameContext ctx({
  int seed = 7,
  int round = 0,
  int day = 1,
  Map<String, int> stats = const {},
}) {
  final b = testBundle();
  final s = GameState.fresh(b.config, b.characters, seed: seed)..day = day;
  stats.forEach((k, v) => s.stats[k] = v);
  return MinigameContext(state: s, round: round);
}

int _n = 0;

Future<void> show(WidgetTester tester, Widget game) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    wrapApp(KeyedSubtree(key: ValueKey('st${_n++}'), child: game)),
  );
  await tester.pump();
}

Finder findText(String s) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').replaceAll('⁠', '') == s,
);

String instructionOf(WidgetTester tester) => tester
    .widget<MinigameScaffold>(find.byType(MinigameScaffold))
    .instruction
    .replaceAll('⁠', '');

void main() {
  late RecordingSfxService sfx;
  setUp(() => sfx = useRecordingSfx());

  // =====================================================================
  // 문장 만들기 — 질 수 있게 됐다
  // =====================================================================
  group('문장 만들기', () {
    testWidgets('실수 한도를 넘기면 진다 (예전에는 success: true 고정이었다)', (tester) async {
      MinigameResult? out;
      await show(tester, WordOrderGame(ctx: ctx(), done: (r) => out = r));
      // round 0 의 기준 문장은 "내가 먼저 연락할게" — 3장, 한도는 4번.
      expect(instructionOf(tester), contains('4번 틀리면'));
      for (var i = 0; i < 4; i++) {
        await tester.tap(findText('연락할게'));
        await tester.pump();
      }
      final r = tester.widget<MinigameScaffold>(
        find.byType(MinigameScaffold),
      ).result;
      expect(r, isNotNull);
      expect(r!.success, isFalse, reason: '질 수 있는 게임이어야 한다');
      expect(findText('실패'), findsOneWidget);
      // 실패는 손에도 다르게 남는다.
      expect(sfx.played, contains(Sfx.choiceFail));
      expect(sfx.haptics, contains(HapticKind.heavy));
      // 결과를 탭으로 넘기면 판이 닫힌다.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      expect(out?.success, isFalse);
    });

    testWidgets('한도 안에서 헤매면 여전히 이긴다 (짚어 준 카드를 따라가면 된다)', (tester) async {
      await show(tester, WordOrderGame(ctx: ctx(), done: (_) {}));
      // 세 번 틀려도(한도 4) 아직 살아 있다.
      for (var i = 0; i < 3; i++) {
        await tester.tap(findText('연락할게'));
        await tester.pump();
      }
      expect(
        tester.widget<MinigameScaffold>(find.byType(MinigameScaffold)).result,
        isNull,
      );
      for (final w in ['내가', '먼저', '연락할게']) {
        await tester.tap(findText(w));
        await tester.pump();
      }
      final r = tester.widget<MinigameScaffold>(
        find.byType(MinigameScaffold),
      ).result;
      expect(r?.success, isTrue);
    });

    testWidgets('남은 기회가 화면에 보인다', (tester) async {
      await show(tester, WordOrderGame(ctx: ctx(), done: (_) {}));
      await tester.tap(findText('연락할게'));
      await tester.pump();
      expect(findText('잘못 고름 1 / 4'), findsOneWidget);
    });
  });

  // =====================================================================
  // 5초 삭제 — 판정 확인(감사 주장의 반례)
  // =====================================================================
  group('5초 삭제', () {
    testWidgets('아무것도 안 하면 상대가 읽는다 = 실패 (이 게임은 질 수 있다)', (tester) async {
      await show(
        tester,
        DeleteFastGame(ctx: ctx(stats: {Stat.sense: 0}), done: (_) {}),
      );
      // 가장 짧게 걸린 판도 3.4초 안에는 끝난다(byPhase 3400 + 눈치 0 + 흔들림).
      await tester.pump(const Duration(milliseconds: 4600));
      final r = tester.widget<MinigameScaffold>(
        find.byType(MinigameScaffold),
      ).result;
      expect(r, isNotNull, reason: '마감이 지나면 판이 끝나야 한다');
      expect(r!.success, isFalse);
      expect(sfx.played, contains(Sfx.choiceFail));
    });
  });

  // =====================================================================
  // 답장 타이밍 — 초반에도 보이는 문턱
  // =====================================================================
  group('답장 타이밍 문턱', () {
    testWidgets('시작 눈치(25)에서는 아직 안 보이고, 문턱이 30 이라고 알려 준다', (tester) async {
      await show(
        tester,
        ReplyTimingGame(ctx: ctx(stats: {Stat.sense: 25}), done: (_) {}),
      );
      expect(instructionOf(tester), contains('눈치가 30을 넘으면'));
    });

    testWidgets('눈치 30 이면 구간이 보인다 (초반에 닿는 값)', (tester) async {
      await show(
        tester,
        ReplyTimingGame(ctx: ctx(stats: {Stat.sense: 30}), done: (_) {}),
      );
      final s = instructionOf(tester);
      expect(s, contains('구간이 보인다'));
      expect(s, contains('눈치 40을 넘으면'), reason: '다음 단이 뭔지도 알려 준다');
    });

    testWidgets('눈치 40 이면 크리티컬 칸까지 보인다 (옛 문턱의 값을 여기로 옮겼다)', (
      tester,
    ) async {
      await show(
        tester,
        ReplyTimingGame(ctx: ctx(stats: {Stat.sense: 40}), done: (_) {}),
      );
      expect(instructionOf(tester), contains('진한 칸이 크리티컬'));
    });

    test('문턱 상수는 시작 눈치(25)보다 위, 옛 문턱(40)보다 아래다', () {
      final b = testBundle();
      final start = GameState.fresh(b.config, b.characters, seed: 1);
      expect(start.stat(Stat.sense), 25);
      expect(ReplyTimingGame.senseToSeeZone, greaterThan(25));
      expect(ReplyTimingGame.senseToSeeZone, lessThan(40));
      expect(ReplyTimingGame.senseToSeeCrit, 40);
    });
  });
}
