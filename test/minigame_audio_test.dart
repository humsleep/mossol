// 미니게임 12종의 소리·진동 배선. docs/review/12_audio_fixes.md 와 짝이 맞는다.
//
// **이 파일이 증명하는 것과 증명하지 못하는 것.**
// `RecordingSfxService` 는 `SfxService` 를 상속해 `onPlay`·`onHaptic` 호출만 적는다.
// 그래서 이 테스트가 통과한다는 것은 **호출이 났다**는 뜻이고, 소리가 실제로
// 들린다거나 모터가 돈다는 뜻이 아니다. 이 저장소는 한 번도 재생된 적 없는
// 사인파 자리표시자를 들고 TestFlight 를 세 번 냈고, 그동안 743개 테스트가
// 전부 통과했다 — 전부 `NoopSfxService` 를 썼기 때문이다. 실기기 확인 항목은
// docs/overhaul/05_audio_haptics.md §5 와 12_audio_fixes.md 마지막 절에 있다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/audio/sfx_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/minigames/choice_games.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/push_games.dart';
import 'package:mossol/minigames/tap_games.dart';
import 'package:mossol/minigames/timing_games.dart';

import 'widget/helpers.dart';

/// 씨앗·순번·상대·스탯을 지정한 미니게임 입력. 기본은 1일차 기준 판(round 0)이다.
MinigameContext ctx({
  int seed = 7,
  int round = 0,
  int day = 1,
  String? partner,
  Map<String, int> stats = const {},
}) {
  final b = testBundle();
  final s = GameState.fresh(b.config, b.characters, seed: seed)..day = day;
  stats.forEach((k, v) => s.stats[k] = v);
  return MinigameContext(
    state: s,
    partner: partner == null ? null : b.characterById[partner],
    round: round,
  );
}

int _n = 0;

/// 미니게임 한 판을 넉넉한 화면에 띄운다. 판마다 새 Key 를 줘서 State 가
/// 재사용되지 않게 한다(minigame_games_test.dart 와 같은 이유).
Future<void> show(WidgetTester tester, Widget game) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    wrapApp(KeyedSubtree(key: ValueKey('sfx${_n++}'), child: game)),
  );
  await tester.pump();
}

/// 보이지 않는 WORD JOINER 를 떼고 글자로 찾는다.
Finder findText(String s) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').replaceAll('⁠', '') == s,
);

/// 결과 큐가 났는지(성공이든 실패든).
bool sawResult(RecordingSfxService s) =>
    s.played.contains(Sfx.choiceOk) || s.played.contains(Sfx.choiceFail);

void main() {
  late RecordingSfxService sfx;
  setUp(() => sfx = useRecordingSfx());

  // =====================================================================
  // 결과 큐 — 12종이 공유하는 단 한 자리(MinigameScaffold)
  // =====================================================================
  group('결과 큐', () {
    /// 결과 없는 껍데기를 띄운 뒤 같은 자리에 결과를 꽂는다(didUpdateWidget).
    Future<void> setResult(WidgetTester tester, MinigameResult? r) async {
      await tester.pumpWidget(
        wrapApp(
          MinigameScaffold(
            title: '판',
            instruction: '설명',
            result: r,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('성공은 choiceOk + medium 한 박자', (tester) async {
      await setResult(tester, null);
      await setResult(tester, const MinigameResult(success: true));
      expect(sfx.played, [Sfx.choiceOk]);
      expect(sfx.haptics, [HapticKind.medium]);
    });

    testWidgets('실패는 choiceFail + heavy — 성공과 소리·진동이 모두 다르다', (tester) async {
      await setResult(tester, null);
      await setResult(tester, const MinigameResult.miss('졌다'));
      expect(sfx.played, [Sfx.choiceFail]);
      expect(sfx.haptics, [HapticKind.heavy]);
    });

    testWidgets('크리티컬은 성공과 같은 소리에 두 번째 진동이 더 붙는다', (tester) async {
      await setResult(tester, null);
      await setResult(
        tester,
        const MinigameResult(success: true, critical: true),
      );
      expect(sfx.played, [Sfx.choiceOk]);
      // 둘째 박자는 90ms 뒤에 온다. 그 전에는 성공과 구별되지 않는다.
      expect(sfx.haptics, [HapticKind.medium]);
      await tester.pump(MinigameSfx.critBeat + const Duration(milliseconds: 10));
      expect(sfx.haptics, [HapticKind.medium, HapticKind.heavy]);
    });

    testWidgets('효과음을 끄면 소리는 없고 진동만 난다', (tester) async {
      sfx.sfxOn = false;
      await setResult(tester, null);
      await setResult(tester, const MinigameResult.miss('졌다'));
      expect(sfx.played, isEmpty);
      expect(sfx.haptics, [HapticKind.heavy]);
    });

    testWidgets('진동을 끄면 진동은 없고 소리만 난다', (tester) async {
      sfx.hapticOn = false;
      await setResult(tester, null);
      await setResult(tester, const MinigameResult(success: true));
      expect(sfx.played, [Sfx.choiceOk]);
      expect(sfx.haptics, isEmpty);
    });
  });

  // =====================================================================
  // 시간 경고 — 타이머가 큐를 도배하지 않는다
  // =====================================================================
  group('남은 시간 경고', () {
    Future<void> setTime(WidgetTester tester, double v) async {
      await tester.pumpWidget(
        wrapApp(
          MinigameScaffold(
            title: '판',
            instruction: '설명',
            timeLeft: v,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('30% 경계를 넘을 때 한 번만 난다 (틱마다 울리지 않는다)', (tester) async {
      await setTime(tester, 1.0);
      await setTime(tester, 0.5);
      expect(sfx.played, isEmpty);
      await setTime(tester, 0.29);
      expect(sfx.played, [Sfx.callEnd]);
      // 타이머는 100ms 마다 setState 한다. 그 뒤로도 큐가 늘어나면 안 된다.
      for (final v in [0.25, 0.2, 0.15, 0.1, 0.05, 0.0]) {
        await setTime(tester, v);
      }
      expect(sfx.played, [Sfx.callEnd]);
    });

    testWidgets('시계를 되감으면 다시 장전된다 (표정 읽기는 문제마다 되감는다)', (tester) async {
      await setTime(tester, 1.0);
      await setTime(tester, 0.2);
      await setTime(tester, 1.0);
      await setTime(tester, 0.2);
      expect(sfx.played, [Sfx.callEnd, Sfx.callEnd]);
    });
  });

  // =====================================================================
  // 결과 뒤 1.1초 — 탭으로 건너뛴다
  // =====================================================================
  group('결과 체류 시간', () {
    late int finished;

    Future<void> pumpScaffold(WidgetTester tester, MinigameResult? r) async {
      await tester.pumpWidget(
        wrapApp(
          MinigameScaffold(
            title: '판',
            instruction: '설명',
            result: r,
            onFinished: () => finished++,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pump();
    }

    setUp(() => finished = 0);

    testWidgets('결과가 뜬 직후에는 못 넘긴다 (판정이 등록될 시간)', (tester) async {
      await pumpScaffold(tester, null);
      await pumpScaffold(tester, const MinigameResult(success: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(findText('아무 데나 눌러서 넘기기'), findsNothing);
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      expect(finished, 0);
      // 자동 종료는 그대로 1.1초.
      await tester.pump(const Duration(milliseconds: 1100));
      expect(finished, 1);
    });

    testWidgets('350ms 뒤에는 아무 데나 눌러 넘긴다 (1.1초를 안 기다린다)', (tester) async {
      await pumpScaffold(tester, null);
      await pumpScaffold(tester, const MinigameResult(success: true));
      await tester.pump(const Duration(milliseconds: 400));
      expect(findText('아무 데나 눌러서 넘기기'), findsOneWidget);
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      expect(finished, 1, reason: '탭으로 결과를 넘길 수 있어야 한다');
      // 남은 dwell 이 지나도 두 번 불리지 않는다.
      await tester.pump(const Duration(milliseconds: 1200));
      expect(finished, 1);
    });
  });

  // =====================================================================
  // 12종 — 입력마다 대답한다
  // =====================================================================
  group('입력 큐 12종', () {
    testWidgets('1. 답장 타이밍: 멈추면 결과 큐만 난다 (탭 큐와 겹치지 않는다)', (tester) async {
      await show(
        tester,
        ReplyTimingGame(ctx: ctx(), done: (_) {}),
      );
      await tester.tap(findText('화면 아무 데나 눌러서 멈추기'));
      await tester.pump();
      expect(sawResult(sfx), isTrue);
      expect(sfx.played, hasLength(1));
      expect(sfx.haptics, hasLength(1));
    });

    testWidgets('2. 문장 만들기: 맞는 카드는 waitRead + light, 틀린 카드는 heavy 진동', (
      tester,
    ) async {
      await show(tester, WordOrderGame(ctx: ctx(), done: (_) {}));
      // round 0 의 기준 문장은 "내가 먼저 연락할게".
      await tester.tap(findText('연락할게'));
      await tester.pump();
      expect(sfx.played, isEmpty, reason: '헛디딤은 실패음을 내지 않는다');
      expect(sfx.haptics, [HapticKind.heavy]);
      sfx.clear();
      await tester.tap(findText('내가'));
      await tester.pump();
      expect(sfx.played, [Sfx.waitRead]);
      expect(sfx.haptics, [HapticKind.light]);
    });

    testWidgets('3. 코스 짜기: 담기 · 빼기 · 꽉 찬 뒤의 헛탭이 모두 다르다', (tester) async {
      await show(tester, DateCourseGame(ctx: ctx(), done: (_) {}));
      final opts = find.byType(MinigameOption);
      for (var i = 0; i < 3; i++) {
        await tester.tap(opts.at(i));
        await tester.pump();
      }
      expect(sfx.played, List.filled(3, Sfx.msgOut));
      expect(sfx.haptics, List.filled(3, HapticKind.selection));
      sfx.clear();
      // 네 번째는 못 담는다 — 예전에는 아무 반응도 없었다.
      await tester.tap(opts.at(3));
      await tester.pump();
      expect(sfx.played, isEmpty);
      expect(sfx.haptics, [HapticKind.heavy]);
      sfx.clear();
      // 담은 것을 다시 누르면 빼기.
      await tester.tap(opts.at(0));
      await tester.pump();
      expect(sfx.played, [Sfx.waitRead]);
      expect(sfx.haptics, [HapticKind.medium]);
    });

    testWidgets('4. 표정 읽기: 문제마다 맞았는지가 그 자리에서 난다', (tester) async {
      await show(tester, ReadEmotionGame(ctx: ctx(), done: (_) {}));
      // round 0 첫 문제는 "괜찮아 ㅎㅎ 신경 쓰지 마" → 정답 '서운함'.
      await tester.tap(findText('화남'));
      await tester.pump();
      expect(sfx.played, isEmpty);
      expect(sfx.haptics, [HapticKind.heavy]);
      // 다음 문제로 넘어간 뒤 정답을 고른다.
      await tester.pump(const Duration(milliseconds: 600));
      sfx.clear();
      await tester.tap(find.byType(MinigameOption).at(0));
      await tester.pump();
      expect(sfx.played.isNotEmpty || sfx.haptics.isNotEmpty, isTrue);
      // 다음 문제로 넘기는 550ms 타이머를 흘려 보낸다(남겨 두면 tearDown 이 잡는다).
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('5. 짤 고르기: 한 번 누르면 결과 큐 하나만 난다', (tester) async {
      await show(tester, PickMemeGame(ctx: ctx(), done: (_) {}));
      await tester.tap(find.byType(MinigameOption).first);
      await tester.pump();
      expect(sawResult(sfx), isTrue);
      expect(sfx.played, hasLength(1));
    });

    testWidgets('6. 5초 삭제: 말풍선에 손이 닿는 순간 대답한다', (tester) async {
      await show(
        tester,
        DeleteFastGame(ctx: ctx(stats: {Stat.sense: 30}), done: (_) {}),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GestureDetector).first),
      );
      await tester.pump();
      expect(sfx.played, [Sfx.msgOut]);
      expect(sfx.haptics, [HapticKind.selection]);
      sfx.clear();
      // 0.55초를 끝까지 누르면 지운다 = 성공.
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pump();
      expect(sfx.played, [Sfx.choiceOk]);
    });

    testWidgets('7. 결심의 순간: 멈추면 결과 큐만 난다', (tester) async {
      await show(tester, NerveGaugeGame(ctx: ctx(), done: (_) {}));
      await tester.tap(findText('화면 아무 데나 눌러서 멈추기'));
      await tester.pump();
      expect(sawResult(sfx), isTrue);
      expect(sfx.played, hasLength(1));
    });

    testWidgets('8. 단톡방 대응: 고르기와 무르기가 다른 소리다', (tester) async {
      await show(tester, GroupChatGame(ctx: ctx(), done: (_) {}));
      await tester.tap(find.byType(MinigameOption).first);
      await tester.pump();
      expect(sfx.played, [Sfx.msgOut]);
      expect(sfx.haptics, [HapticKind.selection]);
      sfx.clear();
      await tester.tap(findText('마지막 하나 무르기'));
      await tester.pump();
      expect(sfx.played, [Sfx.waitRead]);
      expect(sfx.haptics, [HapticKind.medium]);
    });

    testWidgets('9. 선 지키기: 한 번 더가 살아남으면 전진 큐, 멈추면 결과 큐', (tester) async {
      await show(tester, DrinkLimitGame(ctx: ctx(), done: (_) {}));
      // 첫 드립의 흑역사 확률은 0% 다(0*0*5 - tolerance → 0). 반드시 살아남는다.
      await tester.tap(findText('한 번 더'));
      await tester.pump();
      expect(sfx.played, [Sfx.waitRead]);
      expect(sfx.haptics, [HapticKind.light]);
      sfx.clear();
      await tester.tap(findText('여기까지'));
      await tester.pump();
      expect(sfx.played, [Sfx.choiceOk]);
    });

    testWidgets('10. 옷장 코디: 칸을 고를 때마다 대답한다', (tester) async {
      await show(tester, OutfitGame(ctx: ctx(), done: (_) {}));
      await tester.tap(find.byType(MinigameOption).first);
      await tester.pump();
      expect(sfx.played, [Sfx.msgOut]);
      expect(sfx.haptics, [HapticKind.selection]);
    });

    testWidgets('11. 프로필 고르기: 넘기기와 관심이 다른 소리다', (tester) async {
      await show(tester, ProfileSwipeGame(ctx: ctx(), done: (_) {}));
      await tester.tap(find.bySemanticsLabel('넘기기'));
      await tester.pump();
      expect(sfx.played, [Sfx.msgOut]);
      sfx.clear();
      // 관심은 매칭 여부에 따라 전진(waitRead) 또는 헛디딤(진동)으로 갈린다.
      await tester.tap(find.bySemanticsLabel('관심 있음'));
      await tester.pump();
      expect(
        sfx.played.isNotEmpty || sfx.haptics.isNotEmpty,
        isTrue,
        reason: '오른쪽으로 밀었으면 결과가 손에 남아야 한다',
      );
    });

    testWidgets('12. 맞장구: 미리 누르면 진동만, 창이 열린 뒤 누르면 전진 큐', (tester) async {
      await show(tester, CallRhythmGame(ctx: ctx(), done: (_) {}));
      // 창이 열리기 전(lead 700ms) 의 탭.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(sfx.played, isEmpty);
      expect(sfx.haptics, [HapticKind.heavy]);
      sfx.clear();
      // 창이 열린 뒤.
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(sfx.played, [Sfx.waitRead]);
      expect(sfx.haptics, [HapticKind.light]);
    });
  });
}
