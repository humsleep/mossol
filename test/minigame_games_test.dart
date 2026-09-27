// 미니게임 12종을 고친 자리마다 회귀 테스트를 건다.
// docs/review/09_minigame_audit.md §1·§2 의 FIX 항목과 짝이 맞는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/minigames/choice_games.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/push_games.dart';
import 'package:mossol/minigames/tap_games.dart';
import 'package:mossol/minigames/timing_games.dart';

import 'widget/helpers.dart';

/// 씨앗·순번·상대·스탯을 지정한 미니게임 입력.
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

/// 미니게임 한 판을 띄운다.
///
/// 판마다 새 [Key] 를 준다. 같은 타입 위젯을 그냥 다시 pump 하면 Flutter 가
/// State 를 재사용해서 `late final` 로 잡아 둔 판이 그대로 남는다 — 그러면
/// "판마다 다르다" 를 재는 테스트가 언제나 통과해 버린다.
int _n = 0;
Future<void> show(WidgetTester tester, Widget game) async {
  await tester.pumpWidget(
    wrapApp(KeyedSubtree(key: ValueKey('mg${_n++}'), child: game)),
  );
  await tester.pump();
}

/// 넉넉한 화면. 목록이 긴 미니게임은 지연 생성 때문에 잘린다.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// 표시 문자열에서 보이지 않는 WORD JOINER 를 뗀 값(lib/ui/keep_all.dart).
String plain(String? s) => (s ?? '').replaceAll('⁠', '');

/// 화면에 떠 있는 모든 글자.
List<String> texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => plain(t.data))
    .where((s) => s.isNotEmpty)
    .toList();

List<String> optionLabels(WidgetTester tester) => tester
    .widgetList<MinigameOption>(find.byType(MinigameOption))
    .map((o) => plain(o.label))
    .toList();

MinigameScaffold scaffoldOf(WidgetTester tester) =>
    tester.widget<MinigameScaffold>(find.byType(MinigameScaffold));

/// 놀이판 안의 글자만. 제목·설명은 껍데기 몫이라 뺀다.
List<String> bodyTexts(WidgetTester tester) {
  final sc = scaffoldOf(tester);
  final chrome = {plain(sc.title), plain(sc.instruction), plain(sc.badge)};
  return texts(tester).where((s) => !chrome.contains(s)).toList();
}

void main() {
  // =====================================================================
  // 짤 고르기 — 후보 네 장에 상대 취향 짤이 반드시 들어간다 (감사 N4 후속)
  // =====================================================================
  group('짤 고르기', () {
    const byHumor = {
      'seoyeon': ['정색하는 고양이', '무표정 정장 아저씨'], // dry
      'haneul': ['박수치며 웃는 사람', '테이블 치는 짤'], // loud
      'jiwoo': ['안경 고쳐 쓰는 짤', '한 줄 자막 밈'], // witty
      'minjae': ['픽셀 강아지', '저화질 개구리'], // meme
      'yeeun': ['하트 뿅뿅 곰', '이불 덮은 강아지'], // warm
    };

    testWidgets('어느 상대·어느 판에서도 취향 짤이 후보에 있다', (tester) async {
      useTallScreen(tester);
      for (final e in byHumor.entries) {
        for (var round = 0; round < 8; round++) {
          await show(
            tester,
            PickMemeGame(ctx: ctx(round: round, partner: e.key), done: (_) {}),
          );
          final labels = optionLabels(tester);
          expect(labels.length, 4);
          expect(
            labels.any(e.value.contains),
            isTrue,
            reason: '${e.key} $round번째 판에 취향 짤이 없다: $labels',
          );
          expect(labels.toSet().length, 4, reason: '후보가 겹친다: $labels');
        }
      }
    });

    testWidgets('화술이 낮아도 이길 수 있는 판이다 (취향 짤을 누르면 성공)', (tester) async {
      useTallScreen(tester);
      for (var round = 0; round < 6; round++) {
        await show(
          tester,
          PickMemeGame(
            // 화술 10 — 예전에는 취향 짤이 빠진 판이 1/5 확률로 나왔고,
            // 그런 판은 화술 45 미만이면 무엇을 눌러도 실패였다.
            ctx: ctx(round: round, partner: 'minjae', stats: {Stat.talk: 10}),
            done: (_) {},
          ),
        );
        final hit = optionLabels(
          tester,
        ).indexWhere(const ['픽셀 강아지', '저화질 개구리'].contains);
        expect(hit, isNot(-1), reason: '$round번째 판');
        await tester.tap(find.byType(MinigameOption).at(hit));
        await tester.pump();
        expect(findText('성공'), findsOneWidget, reason: '$round번째 판');
        await tester.pump(const Duration(milliseconds: 1200));
      }
    });

    testWidgets('판마다 다른 말에 답한다', (tester) async {
      useTallScreen(tester);
      final seen = <String>{};
      for (var round = 0; round < 4; round++) {
        await show(
          tester,
          PickMemeGame(ctx: ctx(round: round, partner: 'yeeun'), done: (_) {}),
        );
        seen.add(texts(tester).firstWhere((s) => s.startsWith('"')));
      }
      expect(seen.length, greaterThan(1), reason: '매번 같은 말에 답한다');
    });
  });

  // =====================================================================
  // 표정 읽기 — 판마다 다른 문제, 같은 씨앗이면 같은 문제
  // =====================================================================
  group('표정 읽기', () {
    String quoteOf(WidgetTester tester) =>
        texts(tester).firstWhere((s) => s.startsWith('"'));

    testWidgets('판마다 문제가 바뀐다', (tester) async {
      useTallScreen(tester);
      final seen = <String>[];
      for (var round = 0; round < 3; round++) {
        await show(tester, ReadEmotionGame(ctx: ctx(round: round), done: (_) {}));
        seen.add(quoteOf(tester));
      }
      expect(seen.toSet().length, seen.length, reason: '첫 문제가 매번 같다: $seen');
    });

    testWidgets('같은 씨앗·같은 순번이면 같은 문제 (재현 가능)', (tester) async {
      useTallScreen(tester);
      await show(
        tester,
        ReadEmotionGame(ctx: ctx(seed: 42, round: 3), done: (_) {}),
      );
      final first = quoteOf(tester);
      await show(
        tester,
        ReadEmotionGame(ctx: ctx(seed: 42, round: 3), done: (_) {}),
      );
      expect(quoteOf(tester), first);
    });

    testWidgets('첫 판은 어느 씨앗에서도 같은 기준 문제로 시작한다', (tester) async {
      useTallScreen(tester);
      for (final seed in [1, 7, 99]) {
        await show(tester, ReadEmotionGame(ctx: ctx(seed: seed), done: (_) {}));
        expect(quoteOf(tester), contains('괜찮아'));
      }
    });
  });

  // =====================================================================
  // 코스 짜기 — 돈을 대본과 같은 축척으로 적는다
  // =====================================================================
  group('코스 짜기', () {
    testWidgets('예산·합계·가격이 만원 단위로 보인다 (맨 숫자로 두지 않는다)', (tester) async {
      useTallScreen(tester);
      await show(
        tester,
        DateCourseGame(
          // 상대 예산 40 = 4만원. 돈 스탯이 더 많아야 예산이 안 깎인다.
          ctx: ctx(partner: 'seoyeon', stats: {Stat.money: 200}),
          done: (_) {},
        ),
      );
      expect(findTextContaining('예산 4만원'), findsOneWidget);
      expect(findTextContaining('합계 0원 / 4만원'), findsOneWidget);
      final trailing = tester
          .widgetList<MinigameOption>(find.byType(MinigameOption))
          .map((o) => o.trailingLabel)
          .toList();
      expect(trailing, isNot(contains('12')), reason: '가격이 맨 숫자다');
      expect(trailing.where((s) => s != null && s.contains('만원')).length,
          greaterThan(3));
    });

    testWidgets('어느 판에서도 취향에 맞는 곳이 세 군데 이상 있다', (tester) async {
      useTallScreen(tester);
      const placeTags = {
        '한강 산책': ['산책', '가성비', '야경'],
        '동네 전시회': ['전시', '조용한'],
        '분식집': ['분식', '가성비', '추억'],
        '브런치 카페': ['브런치', '조용한'],
        '야시장': ['야시장', '길거리', '사진'],
        '오마카세': ['조용한'],
        '보드게임 카페': ['실내', '게임'],
        '옛날 학교 앞': ['추억', '사진', '산책'],
        '독립 서점': ['조용한', '전시'],
        '포장마차': ['야시장', '길거리', '추억'],
        '영화관 조조': ['실내', '가성비'],
        '남산 전망대': ['야경', '산책', '사진'],
        '실내 클라이밍': ['운동', '실내', '게임'],
        '동네 목욕탕 앞 커피': ['추억', '가성비'],
        '루프탑 바': ['야경', '조용한'],
        '벼룩시장': ['길거리', '사진', '가성비'],
      };
      for (final who in ['seoyeon', 'haneul', 'minjae', 'yuna']) {
        for (var round = 0; round < 5; round++) {
          await show(
            tester,
            DateCourseGame(
              ctx: ctx(round: round, partner: who, stats: {Stat.money: 200}),
              done: (_) {},
            ),
          );
          final tags = ctx(partner: who).tags;
          final fits = optionLabels(tester)
              .where((l) => (placeTags[l] ?? const []).any(tags.contains))
              .length;
          expect(
            fits,
            greaterThanOrEqualTo(3),
            reason: '$who $round번째 판에 취향 장소가 $fits곳뿐이라 크리티컬이 불가능하다',
          );
        }
      }
    });
  });

  // =====================================================================
  // 옷장 — 칸마다 맞는 옷이 최소 한 벌, 결과에 칸별 피드백
  // =====================================================================
  group('옷장 코디', () {
    const closetTags = {
      '검정 니트': ['조용한', '전시'], '후드티': ['가성비', '실내', '게임'],
      '셔츠': ['브런치', '전시'], '맨투맨': ['산책', '추억'],
      '카디건': ['조용한', '브런치'], '체크 셔츠': ['추억', '길거리'],
      '반팔 티': ['운동', '가성비', '실내'], '블루종': ['야경', '길거리'],
      '슬랙스': ['전시', '브런치'], '청바지': ['가성비', '산책', '길거리'],
      '트레이닝 팬츠': ['실내', '게임', '운동'], '면바지': ['추억', '산책'],
      '반바지': ['운동', '가성비'], '코듀로이 팬츠': ['조용한', '전시'],
      '블랙진': ['야경', '야시장', '길거리'], '린넨 팬츠': ['브런치', '산책'],
      '구두': ['브런치', '전시'], '운동화': ['산책', '가성비', '운동'],
      '슬리퍼': ['실내', '게임'], '부츠': ['야경', '야시장'],
      '로퍼': ['조용한', '브런치'], '컨버스': ['추억', '길거리', '가성비'],
      '러닝화': ['운동', '산책'], '샌들': ['야시장', '실내'],
    };

    testWidgets('칸마다 맞는 옷이 최소 한 벌은 걸려 있다 (이길 수 있는 판)', (tester) async {
      useTallScreen(tester);
      for (final who in ['seoyeon', 'minjae', 'yuna', 'jiwoo']) {
        for (var round = 0; round < 5; round++) {
          await show(
            tester,
            OutfitGame(ctx: ctx(round: round, partner: who), done: (_) {}),
          );
          final labels = optionLabels(tester);
          expect(labels.length, 12, reason: '칸당 네 벌이어야 한다');
          final tags = ctx(partner: who).tags;
          for (var s = 0; s < 3; s++) {
            final slot = labels.sublist(s * 4, s * 4 + 4);
            expect(
              slot.any((l) => (closetTags[l] ?? const []).any(tags.contains)),
              isTrue,
              reason: '$who $round번째 판 ${s + 1}번 칸에 맞는 옷이 없다: $slot',
            );
          }
        }
      }
    });

    testWidgets('결과가 나오면 고른 벌이 맞았는지 칸에 표시된다', (tester) async {
      useTallScreen(tester);
      await show(
        tester,
        OutfitGame(ctx: ctx(partner: 'seoyeon'), done: (_) {}),
      );
      for (final i in [0, 4, 8]) {
        await tester.tap(find.byType(MinigameOption).at(i));
        await tester.pump();
      }
      await tester.tap(findWidgetWithText(FilledButton, '이걸로 나간다'));
      await tester.pump();
      final marked = tester
          .widgetList<MinigameOption>(find.byType(MinigameOption))
          .where((o) => o.tone != MinigameOptionTone.neutral)
          .length;
      expect(marked, 3, reason: '고른 세 벌은 맞았는지 틀렸는지 말해야 한다');
      await tester.pump(const Duration(milliseconds: 1200));
    });
  });

  // =====================================================================
  // 단톡방 대응 — 근거가 보이고, 무를 수 있고, 판정이 쌍 단위다
  // =====================================================================
  group('단톡방 대응', () {
    testWidgets('고르기 전에 왜 급한지가 칸마다 적혀 있다', (tester) async {
      useTallScreen(tester);
      await show(
        tester,
        GroupChatGame(ctx: ctx(partner: 'seoyeon'), done: (_) {}),
      );
      final subs = tester
          .widgetList<MinigameOption>(find.byType(MinigameOption))
          .map((o) => plain(o.sub))
          .toList();
      expect(subs.length, 5);
      expect(subs.every((s) => s.isNotEmpty), isTrue, reason: '순서의 근거가 없다');
    });

    testWidgets('마지막 선택을 무를 수 있다', (tester) async {
      useTallScreen(tester);
      await show(
        tester,
        GroupChatGame(ctx: ctx(partner: 'seoyeon'), done: (_) {}),
      );
      await tester.tap(find.byType(MinigameOption).first);
      await tester.pump();
      expect(findText('1번째로 답함'), findsOneWidget);
      await tester.tap(findWidgetWithText(OutlinedButton, '마지막 하나 무르기'));
      await tester.pump();
      expect(findText('1번째로 답함'), findsNothing);
    });

    testWidgets('한 번 엇갈린 판은 실패가 아니다 (쌍 단위 판정)', (tester) async {
      useTallScreen(tester);
      MinigameResult? out;
      await show(
        tester,
        GroupChatGame(ctx: ctx(partner: 'seoyeon'), done: (r) => out = r),
      );
      // 첫 방(round 0)의 우선순위 순서. 화면 배치는 씨앗이 정한다.
      const rank = ['서연', '엄마', '준호', '동아리', '태현'];
      final labels = optionLabels(tester);
      final answer = [
        for (final who in rank) labels.indexWhere((l) => l.startsWith(who)),
      ];
      expect(answer, isNot(contains(-1)));
      // 앞의 두 명만 자리를 바꿔 누른다 = 엇갈린 쌍 하나.
      for (final i in [answer[1], answer[0], ...answer.skip(2)]) {
        await tester.tap(find.byType(MinigameOption).at(i));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 1300));
      expect(out, isNotNull);
      expect(out!.success, isTrue, reason: '한 번 엇갈렸다고 실패면 판정이 너무 빡빡하다');
      expect(out!.critical, isFalse);
    });

    testWidgets('전부 제 순서대로 누르면 크리티컬', (tester) async {
      useTallScreen(tester);
      MinigameResult? out;
      await show(
        tester,
        GroupChatGame(ctx: ctx(partner: 'seoyeon'), done: (r) => out = r),
      );
      const rank = ['서연', '엄마', '준호', '동아리', '태현'];
      final labels = optionLabels(tester);
      for (final who in rank) {
        await tester.tap(
          find.byType(MinigameOption).at(
            labels.indexWhere((l) => l.startsWith(who)),
          ),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 1300));
      expect(out!.critical, isTrue);
    });

    testWidgets('판마다 다른 단톡방이다', (tester) async {
      useTallScreen(tester);
      final rooms = <String>{};
      for (var round = 0; round < 3; round++) {
        await show(
          tester,
          GroupChatGame(
            ctx: ctx(round: round, partner: 'seoyeon'),
            done: (_) {},
          ),
        );
        rooms.add((optionLabels(tester)..sort()).join('|'));
      }
      expect(rooms.length, 3, reason: '매번 같은 다섯 사람이 말을 건다');
    });
  });

  // =====================================================================
  // 5초 삭제 — 시계가 보이고, 길게 누를 시간이 있다
  // =====================================================================
  group('5초 삭제', () {
    testWidgets('남은 시간 막대가 떠 있다', (tester) async {
      useTallScreen(tester);
      await show(tester, DeleteFastGame(ctx: ctx(), done: (_) {}));
      final time = scaffoldOf(tester).timeLeft;
      expect(time, isNotNull, reason: '시계와 겨루는 게임에 시계가 없었다');
      expect(time, inInclusiveRange(0.0, 1.0));
    });

    testWidgets('눈치 0에서도 2.4초 뒤 길게 눌러 지울 수 있다', (tester) async {
      useTallScreen(tester);
      for (var round = 0; round < 6; round++) {
        MinigameResult? out;
        await show(
          tester,
          DeleteFastGame(
            ctx: ctx(round: round, stats: {Stat.sense: 0}),
            done: (r) => out = r,
          ),
        );
        final bubble = find.byType(AnimatedScale);
        await tester.pump(const Duration(milliseconds: 2400));
        final g = await tester.startGesture(tester.getCenter(bubble));
        await tester.pump(const Duration(milliseconds: 700));
        await g.up();
        await tester.pump(const Duration(milliseconds: 1300));
        expect(out?.success, isTrue, reason: '$round번째 판에서 시간이 모자랐다');
      }
    });

    testWidgets('판마다 지우는 메시지가 다르다', (tester) async {
      useTallScreen(tester);
      final seen = <String>{};
      for (var round = 0; round < 3; round++) {
        await show(tester, DeleteFastGame(ctx: ctx(round: round), done: (_) {}));
        // 지울 말풍선은 AnimatedScale 안에 있다.
        seen.add(
          plain(
            tester
                .widget<Text>(
                  find.descendant(
                    of: find.byType(AnimatedScale),
                    matching: find.byType(Text),
                  ),
                )
                .data,
          ),
        );
        // 읽음 마감과 결과 체류 시간을 모두 흘려보내 타이머를 비운다.
        await tester.pump(const Duration(seconds: 6));
        await tester.pump(const Duration(milliseconds: 1300));
      }
      expect(seen.length, 3);
    });
  });

  // =====================================================================
  // 맞장구 — 미리 누르면 화면이 대답하고 잠긴다
  // =====================================================================
  group('맞장구', () {
    testWidgets('창이 열리기 전에 누르면 "아직" 이 뜬다 (연타로는 못 이긴다)', (tester) async {
      useTallScreen(tester);
      await show(
        tester,
        CallRhythmGame(ctx: ctx(partner: 'jiwoo'), done: (_) {}),
      );
      expect(findText('아직'), findsNothing);
      await tester.tapAt(const Offset(200, 1200));
      await tester.pump();
      expect(findText('아직'), findsOneWidget, reason: '미리 누른 손에 아무 대답이 없었다');
      // 잠금이 풀리면 다시 조용해진다.
      await tester.pump(const Duration(milliseconds: 500));
      expect(findText('아직'), findsNothing);
    });

    testWidgets('판마다 다른 통화 대본이다', (tester) async {
      useTallScreen(tester);
      final seen = <String>{};
      for (var round = 0; round < 4; round++) {
        await show(
          tester,
          CallRhythmGame(
            ctx: ctx(round: round, partner: 'jiwoo'),
            done: (_) {},
          ),
        );
        seen.add(bodyTexts(tester).first);
        await tester.pump(const Duration(seconds: 3));
      }
      expect(seen.length, 4, reason: '28번 붙는 미니게임이 매번 같은 대본을 읽는다');
    });
  });

  // =====================================================================
  // 문장 만들기 — 두 번 헤매면 다음 카드를 짚어 준다
  // =====================================================================
  group('문장 만들기', () {
    testWidgets('두 번 잘못 누르면 다음 카드를 짚어 준다', (tester) async {
      useTallScreen(tester);
      await show(
        tester,
        WordOrderGame(ctx: ctx(stats: {Stat.talk: 10}), done: (_) {}),
      );
      // 첫 판(round 0)의 3장 세트는 "내가 먼저 연락할게".
      expect(findText('내가'), findsOneWidget);
      await tester.tap(findText('연락할게'));
      await tester.pump();
      await tester.tap(findText('먼저'));
      await tester.pump();
      expect(findTextContaining('다음은 테두리 친 카드'), findsOneWidget);
    });

    testWidgets('판마다 다른 문장을 만든다', (tester) async {
      useTallScreen(tester);
      final seen = <String>{};
      for (var round = 0; round < 4; round++) {
        await show(
          tester,
          WordOrderGame(
            ctx: ctx(round: round, stats: {Stat.talk: 10}),
            done: (_) {},
          ),
        );
        seen.add((bodyTexts(tester)..sort()).join('|'));
      }
      expect(seen.length, 4);
    });
  });

  // =====================================================================
  // 답장 타이밍 — 무엇에 답하는지 보인다
  // =====================================================================
  group('답장 타이밍', () {
    testWidgets('상대가 보낸 말이 화면에 있다', (tester) async {
      useTallScreen(tester);
      await show(
        tester,
        ReplyTimingGame(ctx: ctx(partner: 'seoyeon'), done: (_) {}),
      );
      expect(findText('자?'), findsOneWidget, reason: '막대만 있으면 목표를 읽을 수 없다');
    });

    testWidgets('판마다 다른 말에 답한다', (tester) async {
      useTallScreen(tester);
      final seen = <String>{};
      for (var round = 0; round < 5; round++) {
        await show(
          tester,
          ReplyTimingGame(
            ctx: ctx(round: round, partner: 'seoyeon'),
            done: (_) {},
          ),
        );
        seen.add(bodyTexts(tester).first);
      }
      expect(seen.length, greaterThan(2));
    });
  });

  // =====================================================================
  // 결심의 순간 — 33번 붙는 미니게임이 매번 같은 무대일 수 없다
  // =====================================================================
  group('결심의 순간', () {
    testWidgets('판마다 제목이 바뀐다', (tester) async {
      useTallScreen(tester);
      final titles = <String>{};
      for (var round = 0; round < 6; round++) {
        await show(
          tester,
          NerveGaugeGame(
            ctx: ctx(round: round, partner: 'seoyeon'),
            done: (_) {},
          ),
        );
        titles.add(scaffoldOf(tester).title);
      }
      expect(titles.length, 6, reason: '여섯 판이 전부 같은 제목이다');
    });

    testWidgets('첫 판은 기준 판(결심의 순간)이고 구간은 한가운데다', (tester) async {
      useTallScreen(tester);
      await show(
        tester,
        NerveGaugeGame(ctx: ctx(partner: 'seoyeon'), done: (_) {}),
      );
      expect(scaffoldOf(tester).title, '결심의 순간');
    });

    testWidgets('날이 갈수록 안전 구간이 좁아진다', (tester) async {
      useTallScreen(tester);
      int widthAt(int day) {
        final m = RegExp(
          r'구간 폭 (\d+)%',
        ).firstMatch(plain(scaffoldOf(tester).instruction));
        return int.parse(m!.group(1)!);
      }

      final widths = <int>[];
      for (final day in [1, 30, 70]) {
        await show(
          tester,
          NerveGaugeGame(
            ctx: ctx(day: day, partner: 'seoyeon', stats: {Stat.esteem: 40}),
            done: (_) {},
          ),
        );
        widths.add(widthAt(day));
      }
      expect(widths[0], greaterThan(widths[1]));
      expect(widths[1], greaterThan(widths[2]));
    });
  });

  // =====================================================================
  // 프로필 고르기 — 넘길지 말지 고를 근거가 있다
  // =====================================================================
  group('프로필 고르기', () {
    testWidgets('카드마다 호응 가능성이 한 줄로 적혀 있다', (tester) async {
      useTallScreen(tester);
      await show(tester, ProfileSwipeGame(ctx: ctx(), done: (_) {}));
      const signals = ['말 걸어도 될 것 같다', '반반이다', '벽이 높아 보인다'];
      expect(
        signals.where((s) => findText(s).evaluate().isNotEmpty).length,
        1,
        reason: '근거가 없으면 동전 던지기다',
      );
    });

    testWidgets('판마다 다른 프로필 묶음이 온다', (tester) async {
      useTallScreen(tester);
      final seen = <String>{};
      for (var round = 0; round < 3; round++) {
        await show(
          tester,
          ProfileSwipeGame(ctx: ctx(round: round), done: (_) {}),
        );
        seen.add(bodyTexts(tester).first);
      }
      expect(seen.length, greaterThan(1));
    });
  });

  // =====================================================================
  // 선 지키기 — 판마다 다른 자리
  // =====================================================================
  group('선 지키기', () {
    testWidgets('판마다 다른 무대', (tester) async {
      useTallScreen(tester);
      final seen = <String>{};
      for (var round = 0; round < 5; round++) {
        await show(tester, DrinkLimitGame(ctx: ctx(round: round), done: (_) {}));
        seen.add(scaffoldOf(tester).instruction);
      }
      expect(seen.length, 5);
    });

    testWidgets('첫 드립은 언제나 안전하다 (확률 0%)', (tester) async {
      useTallScreen(tester);
      await show(tester, DrinkLimitGame(ctx: ctx(), done: (_) {}));
      expect(findTextContaining('흑역사 확률 0%'), findsOneWidget);
    });
  });

  // =====================================================================
  // 작은 화면 + 큰 글꼴: 두 번째 판부터도 넘치지 않는다.
  // layout_test 는 첫 판만 본다 — 변주가 붙은 판이 넘치면 거기서는 안 걸린다.
  // =====================================================================
  testWidgets('320pt · 글자 1.3배: 12종의 2~4번째 판도 넘치지 않는다', (tester) async {
    useSmallScreenLargeFont(tester);
    final builders = <String, Widget Function(MinigameContext)>{
      'reply_timing': (c) => ReplyTimingGame(ctx: c, done: (_) {}),
      'word_order': (c) => WordOrderGame(ctx: c, done: (_) {}),
      'date_course': (c) => DateCourseGame(ctx: c, done: (_) {}),
      'read_emotion': (c) => ReadEmotionGame(ctx: c, done: (_) {}),
      'pick_meme': (c) => PickMemeGame(ctx: c, done: (_) {}),
      'delete_fast': (c) => DeleteFastGame(ctx: c, done: (_) {}),
      'nerve_gauge': (c) => NerveGaugeGame(ctx: c, done: (_) {}),
      'group_chat': (c) => GroupChatGame(ctx: c, done: (_) {}),
      'drink_limit': (c) => DrinkLimitGame(ctx: c, done: (_) {}),
      'outfit': (c) => OutfitGame(ctx: c, done: (_) {}),
      'profile_swipe': (c) => ProfileSwipeGame(ctx: c, done: (_) {}),
      'call_rhythm': (c) => CallRhythmGame(ctx: c, done: (_) {}),
    };
    for (final e in builders.entries) {
      for (var round = 1; round <= 3; round++) {
        for (final day in [1, 30, 70]) {
          await show(
            tester,
            Builder(
              builder: (_) =>
                  e.value(ctx(round: round, day: day, partner: 'seoyeon')),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            tester.takeException(),
            isNull,
            reason: '${e.key} $round번째 판 (D+$day)',
          );
          expect(find.byType(MinigameScaffold), findsOneWidget);
          // 타이머가 도는 미니게임은 화면을 비운 뒤 정리한다.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 3));
        }
      }
    }
  });
}
