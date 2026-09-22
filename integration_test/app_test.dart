// 출시 전 통합 테스트. 시뮬레이터에서 실제 플러그인·SharedPreferences·에셋으로 앱 전체를 돈다.
//
//   flutter test integration_test/ -d <iPhone 17 udid>
//
// 광고 SDK 는 마지막 스모크 테스트에서만 켠다(helpers.dart 참고). 모든 테스트는 FlutterError
// (overflow 포함)가 나면 실패한다 — testWidgets 가 FlutterError.onError 를 잡아 실패로 보고한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mossol/ads/ad_manager.dart';
import 'package:mossol/app_meta.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/action_screen.dart';
import 'package:mossol/ui/album_screen.dart';
import 'package:mossol/ui/ending_screen.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/onboarding_gender_screen.dart';
import 'package:mossol/ui/onboarding_mbti_screen.dart';
import 'package:mossol/ui/onboarding_name_screen.dart';
import 'package:mossol/ui/preference_screen.dart';
import 'package:mossol/ui/settings_screen.dart';
import 'package:mossol/ui/summary_screen.dart';
import 'package:mossol/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'helpers.dart';

/// 리포트용 기록. 실패는 아니지만 알려야 할 관찰.
void note(String s) => debugPrint('[IT-NOTE] $s');

class _FakeLauncher extends UrlLauncherPlatform {
  final launched = <(String, PreferredLaunchMode)>[];
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> canLaunch(String url) async => true;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add((url, options.mode));
    return true;
  }
}

/// 온보딩: 홈 "새 게임" → 나는? → 이름 → MBTI → 캐스트 소개. 캐스트 화면에서 멈춘다.
Future<void> onboardToCast(
  WidgetTester tester, {
  String gender = '남자',
  String? name,
  String? mbtiToggles, // 예: 'INFP' — 네 칸을 토글로
  List<String>? quiz, // 예: ['E','S','T','J'] — 잘 몰라요 간이 테스트
}) async {
  await tapAndPump(tester, findText('새 게임'), settle: const Duration(milliseconds: 700));
  expect(findText(OnboardingGenderScreen.title), findsOneWidget);
  await tapAndPump(tester, findText(gender), settle: const Duration(milliseconds: 700));

  expect(findText(OnboardingNameScreen.title), findsOneWidget);
  if (name == null) {
    await tapAndPump(tester, find.byKey(const Key('name-skip')), settle: const Duration(milliseconds: 700));
  } else {
    await tester.enterText(find.byKey(const Key('name-field')), name);
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(findTextContaining(name), findsWidgets, reason: '이름 미리보기');
    await tapAndPump(tester, find.byKey(const Key('name-submit')), settle: const Duration(milliseconds: 700));
  }

  expect(findText(OnboardingMbtiScreen.title), findsOneWidget);
  if (mbtiToggles != null) {
    for (final l in mbtiToggles.split('')) {
      await tapAndPump(tester, find.byKey(Key('mbti-$l')), settle: const Duration(milliseconds: 150));
    }
    expect(findText('나는 $mbtiToggles'), findsOneWidget);
    await tapAndPump(tester, find.byKey(const Key('mbti-submit')), settle: const Duration(milliseconds: 700));
  } else if (quiz != null) {
    await tapAndPump(tester, find.byKey(const Key('mbti-unsure')), settle: const Duration(milliseconds: 700));
    expect(findText(MbtiQuizScreen.title), findsOneWidget);
    for (var i = 0; i < quiz.length; i++) {
      expect(findText('${i + 1} / 4'), findsOneWidget);
      await tapAndPump(tester, find.byKey(Key('mbti-quiz-${quiz[i]}')), settle: const Duration(milliseconds: 600));
    }
    expect(findText(OnboardingMbtiScreen.title), findsOneWidget, reason: '퀴즈 뒤 MBTI 화면으로 돌아와야 함');
    expect(find.byKey(const Key('mbti-quiz-note')), findsOneWidget);
    expect(findText('나는 ${quiz.join()}'), findsOneWidget);
    await tapAndPump(tester, find.byKey(const Key('mbti-submit')), settle: const Duration(milliseconds: 700));
  } else {
    await tapAndPump(tester, find.byKey(const Key('mbti-skip')), settle: const Duration(milliseconds: 700));
  }
  expect(findText(PreferenceScreen.title), findsOneWidget);
}

/// 캐스트 소개 검사: 카드·초상화·MBTI 칩·궁합 줄.
Future<void> checkCast(WidgetTester tester, {required String side, required bool compat, String? name}) async {
  expect(find.byKey(Key('cast-side-$side')), findsOneWidget);
  final cards = find.byType(CastIntroCard);
  expect(cards, findsWidgets);
  // 초상화(assets/portraits/*.jpg)가 이니셜 대신 그려졌는지.
  expect(find.descendant(of: cards.first, matching: find.byType(Image)), findsWidgets,
      reason: '첫 카드에 초상화 이미지가 없음');
  expect(find.byType(MbtiChip), findsWidgets);
  final compatRows = find.byType(CompatRow);
  if (compat) {
    expect(compatRows, findsWidgets, reason: 'MBTI 가 있으면 궁합 줄');
    expect(findTextContaining('궁합 '), findsWidgets);
  } else {
    expect(compatRows, findsNothing, reason: 'MBTI 모름이면 궁합 줄 숨김');
  }
  // 카드 전부를 한 번씩 화면에 올려 레이아웃 오류를 잡는다.
  final scroll = find.byType(Scrollable).first;
  for (var i = 0; i < 6; i++) {
    await tester.drag(scroll, const Offset(0, -300));
    await pumpFor(tester, const Duration(milliseconds: 150));
  }
  if (name != null) {
    final hit = screenTexts(tester).any((t) => t.contains(name));
    note('cast intro first-message contains player name "$name": $hit');
  }
}

Future<void> startFromCast(WidgetTester tester, GameController c) async {
  await tapAndPump(tester, find.byKey(const Key('cast-start')), settle: const Duration(milliseconds: 700));
  expect(c.phase, Phase.action);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('1. 첫 실행 온보딩', () {
    testWidgets('1a 성별 → 한글 이름 → MBTI 토글 4칸 → 캐스트 → 시작', (tester) async {
      final c = await bootApp(tester, fresh: true);
      expect(findText('모쏠 탈출기'), findsOneWidget);
      expect(findText('이어하기'), findsNothing);
      await onboardToCast(tester, gender: '남자', name: '지호', mbtiToggles: 'INFP');
      await checkCast(tester, side: Preference.female, compat: true, name: '지호');
      // 저장 전(캐스트 화면)에는 아직 메타에 쓰지 않는다.
      expect(c.playerName, isNull);
      await startFromCast(tester, c);
      expect(c.playerName, '지호');
      expect(c.playerMbti, 'INFP');
      expect(c.state!.mbti, 'INFP');
      expect(c.state!.preference, Preference.female);
      expect(c.playerGender, PlayerGender.male);
      await spinRouletteUi(tester);
      expect(find.byType(ActionScreen), findsOneWidget);
    });

    testWidgets('1b 잘 몰라요 간이 테스트 경로', (tester) async {
      final c = await bootApp(tester, fresh: true);
      await onboardToCast(tester, gender: '여자', quiz: ['E', 'S', 'T', 'J']);
      await checkCast(tester, side: Preference.male, compat: true);
      await startFromCast(tester, c);
      expect(c.playerMbti, 'ESTJ');
      expect(c.state!.mbti, 'ESTJ');
      expect(c.state!.preference, Preference.male);
      expect(c.playerName, isNull);
      await spinRouletteUi(tester);
    });

    testWidgets('1c 건너뛰기 경로(선택 안 함 · 이름 · MBTI 모두 건너뜀)', (tester) async {
      final c = await bootApp(tester, fresh: true);
      await onboardToCast(tester, gender: '선택 안 할래요');
      // 비교 모드: 처음엔 시작하기가 꺼져 있다.
      final start = tester.widget<FilledButton>(find.byKey(const Key('cast-start')));
      expect(start.onPressed, isNull);
      await tapAndPump(tester, find.byKey(const Key('preference-${Preference.female}')));
      await checkCast(tester, side: Preference.female, compat: false);
      await startFromCast(tester, c);
      expect(c.playerMbti, isNull);
      expect(c.state!.mbti, isNull);
      expect(c.shouldAskMbti, isFalse, reason: '건너뛰면 다음부터 묻지 않음');
      expect(c.shouldAskName, isFalse);
      await spinRouletteUi(tester);
    });
  });

  testWidgets('2. 1일차 전체 플레이(UI) → 정산 → 다음 날, 대사 속 이름', (tester) async {
    final c = await bootApp(tester, fresh: true);
    await onboardToCast(tester, gender: '남자', name: '지호', mbtiToggles: 'ENFP');
    await startFromCast(tester, c);
    await spinRouletteUi(tester);
    expect(c.rouletteSlot, isNotNull);
    expect(findText('D+1  ·  1장'), findsOneWidget);
    final heartsBefore = c.hearts;

    await tapAction(tester, '헬스장');
    expect(c.phase, Phase.event);
    expect(c.hearts, heartsBefore - 1);
    expect(find.byType(EventScreen), findsOneWidget);
    expect(c.current!.id, 'm01');

    final seen = <String>[];
    final day1 = <String>[];
    // 1일차: 말풍선 자동 공개 타이머를 실제로 기다린다(읽씹은 최대 20초).
    while (c.phase == Phase.event && day1.length < 10) {
      day1.add(await playEventUi(tester, c, realtime: true, maxWait: const Duration(seconds: 20), seen: seen));
    }
    note('day1 events: $day1');
    expect(day1.length, greaterThanOrEqualTo(3), reason: '오프닝 1일차는 여러 이벤트');
    expect(c.phase, Phase.summary);
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(findText('D+1 정산'), findsOneWidget);
    expect(findText('오늘의 변화'), findsOneWidget);

    // 내일 예고 한 줄.
    final hint = c.tomorrowHint;
    note('tomorrowHint day1: ${hint?.characterId} preview=${hint?.preview}');
    if (hint != null) {
      await tester.scrollUntilVisible(find.byKey(const Key('tomorrow-line')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(findTextContaining('에게서 연락이 올 것 같다'), findsOneWidget);
    } else {
      note('BUG?: day-1 summary has no tomorrow-preview line');
    }
    await tapSummaryButton(tester, '다음 날로');
    expect(c.phase, Phase.action);
    expect(c.state!.day, 2);
    await spinRouletteUi(tester);
    expect(findText('D+2  ·  1장'), findsOneWidget);
    // 어젯밤 예고 카드(클리프행어).
    expect(findTextContaining('어젯밤:'), findsOneWidget);

    // 이름이 대사에 나올 때까지 며칠 더(UI, 대사는 즉시 공개). 오프닝 r00 루트가 {name} 을 쓴다.
    var named = seen.any((t) => t.contains('지호'));
    for (var day = 2; day <= 6 && !named; day++) {
      expect(c.phase, Phase.action);
      if (findText('오늘의 운').evaluate().isNotEmpty) await spinRouletteUi(tester);
      await tapAction(tester, chooseAction(c, day).name);
      while (c.phase == Phase.event) {
        await playEventUi(tester, c, seen: seen);
      }
      named = seen.any((t) => t.contains('지호'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      await tapSummaryButton(tester, '다음 날로');
      if (c.phase == Phase.action && findText('오늘의 운').evaluate().isNotEmpty) {
        await spinRouletteUi(tester);
      }
    }
    note('player name found in dialogue by day ${c.state!.day}: $named');
    expect(named, isTrue, reason: '플레이어 이름이 대사에 한 번도 나오지 않음');
    // 치환되지 않은 자리표시자가 화면에 새지 않았는지.
    expect(seen.where((t) => t.contains('{name') || t.contains('{mbti')), isEmpty);
  });

  testWidgets('3. 저장·재시작·설정 변경은 다음 새 게임부터', (tester) async {
    var c = await bootApp(tester, fresh: true);
    await onboardToCast(tester, gender: '남자', name: '민수', mbtiToggles: 'ISTJ');
    await startFromCast(tester, c);
    await spinRouletteUi(tester);
    await tapAction(tester, '독서·영상');
    final first = await playEventUi(tester, c);
    expect(c.phase, Phase.event, reason: '오프닝 1일차는 이벤트가 2개 이상');
    final day = c.state!.day;
    final midEvent = c.current!.id;
    final hearts = c.hearts;
    final seenCount = c.state!.seen.length;
    final delta = Map.of(c.dayDelta.stats);
    final stats = Map.of(c.state!.stats);
    await pumpFor(tester, const Duration(milliseconds: 500)); // 비동기 저장 대기

    // ---- 앱 재시작(새 컨트롤러, 디스크에서 다시 읽기) ----
    c = await bootApp(tester);
    expect(c.hasSave, isTrue);
    expect(findText('이어하기'), findsOneWidget);
    expect(findTextContaining('D+$day'), findsWidgets);
    await tapAndPump(tester, findText('이어하기'), settle: const Duration(milliseconds: 800));
    // 하트를 쓴 날은 행동 화면이 아니라 끊긴 이벤트부터 이어 간다(하트·아침 행동 중복 없음).
    expect(c.phase, Phase.event);
    expect(c.current?.id, midEvent);
    expect(c.state!.day, day);
    expect(c.state!.mbti, 'ISTJ');
    expect(c.state!.seen, contains(first));
    expect(c.state!.seen.length, seenCount);
    expect(c.state!.stats, stats);
    expect(c.dayDelta.stats, delta, reason: '하루 도중 변화(정산용)가 복원돼야 함');
    expect(c.canSpinRoulette, isFalse, reason: '같은 날 룰렛을 다시 주면 안 됨');
    expect(findText('오늘의 운'), findsNothing);
    note('mid-day restart: was at event "$midEvent" (heart spent: $hearts left). '
        'After 이어하기 → phase=${c.phase}, current=${c.current?.id}, hearts=${c.hearts}, '
        'queue=${c.queuedEventIds}');
    expect(c.hearts, hearts, reason: '재시작으로 하트가 바뀌면 안 됨');

    // ---- 설정에서 이름·MBTI 변경 ----
    c.goHome();
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(c.phase, Phase.home);
    await tapAndPump(tester, find.byTooltip('설정'), settle: const Duration(milliseconds: 700));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(findText('민수'), findsOneWidget);
    expect(findText('ISTJ'), findsOneWidget);

    await tapAndPump(tester, find.byKey(const Key('settings-name')), settle: const Duration(milliseconds: 700));
    await tester.enterText(find.byKey(const Key('name-field')), '서준');
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tapAndPump(tester, find.byKey(const Key('name-submit')), settle: const Duration(milliseconds: 700));
    expect(findText('서준'), findsOneWidget);

    await tapAndPump(tester, find.byKey(const Key('settings-mbti')), settle: const Duration(milliseconds: 700));
    for (final l in ['E', 'N', 'F', 'J']) {
      await tapAndPump(tester, find.byKey(Key('mbti-$l')), settle: const Duration(milliseconds: 150));
    }
    expect(findText('나는 ENFJ'), findsOneWidget);
    await tapAndPump(tester, find.byKey(const Key('mbti-submit')), settle: const Duration(milliseconds: 700));
    expect(findText('ENFJ'), findsOneWidget);
    expect(c.runMbti, 'ISTJ', reason: '진행 중인 회차 MBTI 는 그대로');

    // ---- 다시 재시작 ----
    c = await bootApp(tester);
    expect(c.playerName, '서준');
    expect(c.playerMbti, 'ENFJ');
    expect(c.runMbti, 'ISTJ', reason: '재시작 후에도 진행 중 회차는 원래 MBTI');
    await tapAndPump(tester, findText('이어하기'), settle: const Duration(milliseconds: 800));
    expect(c.state!.mbti, 'ISTJ');
    expect(c.say('{name|아야}'), startsWith('서준'), reason: '이름은 즉시 반영(설계: 메타만 저장)');
    c.goHome();
    await pumpFor(tester, const Duration(milliseconds: 500));

    // ---- 새 게임: 새 MBTI 가 반영, 온보딩 질문은 다시 안 나옴 ----
    await tapAndPump(tester, findText('새 게임'), settle: const Duration(milliseconds: 600));
    expect(findText('진행 중인 회차가 지워집니다. 시작할까요?'), findsOneWidget);
    await tapAndPump(tester, findText('시작'), settle: const Duration(milliseconds: 800));
    expect(findText(OnboardingGenderScreen.title), findsNothing);
    expect(findText(OnboardingNameScreen.title), findsNothing);
    expect(findText(OnboardingMbtiScreen.title), findsNothing);
    expect(findText(PreferenceScreen.title), findsOneWidget);
    expect(find.byType(CompatRow), findsWidgets);
    await startFromCast(tester, c);
    expect(c.state!.mbti, 'ENFJ');
    expect(c.state!.day, 1);
    await spinRouletteUi(tester);
  });

  testWidgets('4. 하트 소진 → 부드러운 다이얼로그, 광고 자동 표시 없음, 크래시 없음', (tester) async {
    var c = await bootApp(tester, fresh: true);
    await c.setPlayerMbti(null);
    await c.skipPlayerName();
    await c.newGame(preference: Preference.female);
    await pumpFor(tester, const Duration(milliseconds: 500));
    final start = c.hearts;
    note('hearts at run start (max ${c.config.maxHearts} + attendance): $start');
    var days = 0;
    while (c.hearts > 0 && days < 12) {
      await fastDay(tester, c, refill: false);
      days++;
    }
    expect(c.hearts, 0);
    expect(c.phase, Phase.action);
    await pumpFor(tester, const Duration(milliseconds: 500));
    if (findText('오늘의 운').evaluate().isNotEmpty) await spinRouletteUi(tester);

    final day = c.state!.day;
    await tapAction(tester, '헬스장');
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(findText(heartEmptyTitle), findsOneWidget);
    expect(findTextContaining('1개 찬다'), findsOneWidget);
    expect(c.phase, Phase.action);
    expect(c.state!.day, day);
    expect(AdManager.instance.sdkInitialized, isFalse);
    // 광고는 2차 선택지. 눌러도 광고 SDK 가 없으면 안내만 하고 멈추지 않는다.
    await tapAndPump(tester, findText('광고 보고 하트 받기'), settle: const Duration(milliseconds: 800));
    expect(findText(heartEmptyTitle), findsNothing);
    expect(findTextContaining('광고를 불러오지 못했어요'), findsOneWidget);
    expect(c.hearts, 0);
    await pumpFor(tester, const Duration(seconds: 4)); // 스낵바 사라짐
    await tapAction(tester, '집에서 휴식');
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(findText(heartEmptyTitle), findsOneWidget);
    await tapAndPump(tester, findText('기다릴게요'));
    expect(findText(heartEmptyTitle), findsNothing);
    expect(c.phase, Phase.action);

    // 홈에서도 하트 0 표시와 광고 +1 버튼(수동).
    await tapAndPump(tester, find.byIcon(Icons.home_outlined));
    expect(findText('광고로 +1'), findsOneWidget);
    await tapAndPump(tester, findText('광고로 +1'), settle: const Duration(milliseconds: 800));
    expect(findTextContaining('광고를 불러오지 못했어요'), findsOneWidget);

    // 하트 0 인 세이브로 재시작해도 뜬다.
    c = await bootApp(tester);
    expect(c.saveSummary?.hearts, 0);
    await tapAndPump(tester, findText('이어하기'), settle: const Duration(milliseconds: 800));
    expect(c.phase, Phase.action);
    expect(c.hearts, 0);
    await tapAction(tester, '헬스장');
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(findText(heartEmptyTitle), findsOneWidget);
    await tapAndPump(tester, findText('기다릴게요'));
  });

  testWidgets('5. 100일 완주 → 엔딩(다음 판 카드) → 2회차 지난 판 줄', (tester) async {
    var c = await bootApp(tester, fresh: true);
    await c.setPlayerName('지호');
    await c.setPlayerMbti('INTJ');
    await c.newGame(preference: Preference.female);
    await pumpFor(tester, const Duration(milliseconds: 400));
    final sw = Stopwatch()..start();
    var events = 0;
    var earlyEnding = false;
    while (c.phase == Phase.action && c.state!.day < c.config.totalDays) {
      final n = await fastDay(tester, c);
      events += n;
      if (c.phase == Phase.ending) {
        earlyEnding = true;
        break;
      }
      if (c.state!.day % 10 == 0) {
        // 틈틈이 실제 화면 한 번(행동 화면) 그려 둔다.
        await pumpFor(tester, const Duration(milliseconds: 200));
      }
    }
    if (earlyEnding) {
      note('run ended early (immediate ending ${c.ending?.id}) at day ${c.state!.day}');
    } else {
      expect(c.state!.day, c.config.totalDays);
      // 마지막 날은 정산 화면의 "엔딩 보기" 버튼을 실제로 누른다.
      await fastDay(tester, c, finishDay: false);
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(findText('D+100 정산'), findsOneWidget);
      expect(find.byKey(const Key('tomorrow-line')), findsNothing, reason: '마지막 날엔 내일 예고 없음');
      await tapSummaryButton(tester, '엔딩 보기');
    }
    note('long run: ${sw.elapsed.inSeconds}s, $events events, ending=${c.ending?.id} (${c.ending?.tier})');
    expect(c.phase, Phase.ending);
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.byType(EndingScreen), findsOneWidget);
    expect(c.hasSave, isFalse);
    expect(c.endingAlbum, contains(c.ending!.id));
    if (!earlyEnding) expect(findTextContaining('D+100'), findsOneWidget);
    // "다음 판" 카드.
    final card = find.byKey(const Key('next-run-card'));
    expect(c.nextRunSuggestion, isNotNull);
    await tester.scrollUntilVisible(card, 250, scrollable: find.byType(Scrollable).first);
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: findText('다음 판')), findsOneWidget);

    // 엔딩 화면 다크 모드.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await pumpFor(tester, const Duration(milliseconds: 600));
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    await pumpFor(tester, const Duration(milliseconds: 300));

    // 2회차.
    final lastEnding = c.ending!.id;
    final run2 = find.byWidgetPredicate(
      (w) => w is FilledButton && w.child is Text && plain((w.child as Text).data) == '2회차 시작',
    );
    await tester.scrollUntilVisible(run2, 250, scrollable: find.byType(Scrollable).first);
    await tapAndPump(tester, run2, settle: const Duration(milliseconds: 800));
    expect(c.phase, Phase.action);
    expect(c.state!.run, 2);
    expect(c.state!.day, 1);
    expect(c.meta!.lastEndingId, lastEnding);
    final prev = find.byKey(const Key('previous-run'));
    expect(prev, findsOneWidget);
    expect(find.descendant(of: prev, matching: findTextContaining('지난 판')), findsOneWidget);
    note('previous-run line: ${c.previousRunLine}');
    if (findText('오늘의 운').evaluate().isNotEmpty) await spinRouletteUi(tester);

    // 재시작 후 홈에도 지난 판 줄.
    c = await bootApp(tester);
    expect(find.byKey(const Key('previous-run')), findsOneWidget);
    expect(findText('이어하기'), findsOneWidget);
  });

  testWidgets('6. 설정: 앱 이름 · 개인정보처리방침 링크 · 라이선스 · 초기화', (tester) async {
    var c = await bootApp(tester, fresh: true);
    await c.setPlayerName('지호');
    await c.setPlayerMbti('INFP');
    await c.setPlayerGender(PlayerGender.male);
    await c.newGame(preference: Preference.female);
    await pumpFor(tester, const Duration(milliseconds: 400));
    if (findText('오늘의 운').evaluate().isNotEmpty) await spinRouletteUi(tester);
    c.goHome();
    await pumpFor(tester, const Duration(milliseconds: 500));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
    expect(app.title, '모쏠 탈출기');
    expect(findText('모쏠 탈출기'), findsOneWidget);

    await tapAndPump(tester, find.byTooltip('설정'), settle: const Duration(milliseconds: 700));
    expect(findText('설정'), findsOneWidget);
    expect(findText(AppMeta.versionLabel), findsOneWidget);

    // 개인정보처리방침: 실제 브라우저 대신 url_launcher 플랫폼을 가로채 목적지를 확인한다.
    final real = UrlLauncherPlatform.instance;
    final fake = _FakeLauncher();
    UrlLauncherPlatform.instance = fake;
    try {
      await tapAndPump(tester, findText('개인정보처리방침'));
    } finally {
      UrlLauncherPlatform.instance = real;
    }
    expect(fake.launched, hasLength(1));
    expect(fake.launched.single.$1, 'https://humsleep.github.io/apps/mossol/privacy/');
    expect(fake.launched.single.$1, AppLinks.privacyPolicy);
    expect(fake.launched.single.$2, PreferredLaunchMode.externalApplication);
    // 실제 플러그인도 이 주소를 열 수 있다고 답하는지(시뮬레이터 Safari).
    expect(await real.canLaunch(AppLinks.privacyPolicy), isTrue);

    // 라이선스 페이지(앱 이름 · Pretendard 등록).
    await tapAndPump(tester, findText('오픈소스 라이선스'), settle: const Duration(seconds: 2));
    expect(findTextContaining('모쏠 탈출기'), findsWidgets);
    expect(findTextContaining('Pretendard'), findsWidgets);
    await tester.pageBack();
    await pumpFor(tester, const Duration(milliseconds: 700));

    // 초기화: 취소 → 그대로, 지우기 → 전부 지워짐.
    await tapAndPump(tester, findText('저장 데이터 초기화'));
    expect(findText('저장 데이터를 지울까요?'), findsOneWidget);
    await tapAndPump(tester, findText('취소'));
    expect(c.hasSave, isTrue);
    await tapAndPump(tester, findText('저장 데이터 초기화'));
    await tapAndPump(tester, findText('지우기'), settle: const Duration(milliseconds: 900));
    expect(findText('저장 데이터를 지웠어요'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(c.hasSave, isFalse);
    expect(c.playerName, isNull);
    expect(c.playerMbti, isNull);
    expect(c.playerGender, isNull);
    expect(c.endingAlbum, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('mossol_save_v1'), isFalse);

    // 재시작 후에도 첫 실행 상태.
    c = await bootApp(tester);
    expect(c.hasSave, isFalse);
    expect(findText('이어하기'), findsNothing);
    await tapAndPump(tester, findText('새 게임'), settle: const Duration(milliseconds: 700));
    expect(findText(OnboardingGenderScreen.title), findsOneWidget);
    await tester.pageBack();
    await pumpFor(tester, const Duration(milliseconds: 500));
  });

  testWidgets('7. 다크 모드: 주요 화면 전부(overflow·예외 없음)', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final c = await bootApp(tester, fresh: true);
    expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.dark);
    await onboardToCast(tester, gender: '여자', name: '지호', quiz: ['I', 'N', 'F', 'P']);
    await checkCast(tester, side: Preference.male, compat: true);
    await tapAndPump(tester, find.byKey(const Key('cast-flip')));
    await checkCast(tester, side: Preference.female, compat: true);
    await startFromCast(tester, c);
    await spinRouletteUi(tester);
    await tapAction(tester, '친구 만나기');
    while (c.phase == Phase.event) {
      await playEventUi(tester, c);
    }
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.byType(SummaryScreen), findsOneWidget);
    await tapSummaryButton(tester, '다음 날로');
    if (findText('오늘의 운').evaluate().isNotEmpty) await spinRouletteUi(tester);
    // 앨범
    await tapAndPump(tester, find.byTooltip('앨범'), settle: const Duration(milliseconds: 700));
    expect(find.byType(AlbumScreen), findsOneWidget);
    await tester.pageBack();
    await pumpFor(tester, const Duration(milliseconds: 500));
    // 홈 · 설정
    await tapAndPump(tester, find.byIcon(Icons.home_outlined));
    await tapAndPump(tester, find.byTooltip('설정'), settle: const Duration(milliseconds: 700));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.pageBack();
    await pumpFor(tester, const Duration(milliseconds: 500));
    // 작은 글꼴 배율 1.3 으로 홈·행동 한 번 더.
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tapAndPump(tester, findText('이어하기'), settle: const Duration(milliseconds: 800));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await pumpFor(tester, const Duration(milliseconds: 400));
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await pumpFor(tester, const Duration(milliseconds: 300));
  });

  testWidgets('8. 광고 SDK 켠 스모크(UMP → ATT → 초기화) — 앱이 계속 돈다', (tester) async {
    final c = await bootApp(tester, fresh: true);
    await AdManager.instance.init();
    final inited = await pumpUntil(tester, () => AdManager.instance.sdkInitialized,
        timeout: const Duration(seconds: 20));
    note('ads: consentDone=${AdManager.instance.consentDone} sdkInitialized=$inited');
    await c.newGame(preference: Preference.female);
    await pumpFor(tester, const Duration(seconds: 2));
    if (findText('오늘의 운').evaluate().isNotEmpty) await spinRouletteUi(tester);
    // 1일차는 전면 광고 정책(3일차 이후) 밖이라 흐름이 막히지 않는다.
    expect(AdManager.instance.canShowInterstitial(1), isFalse);
    expect(AdManager.instance.canShowInterstitial(2), isFalse);
    c.goHome();
    await pumpFor(tester, const Duration(seconds: 6));
    note('banner on home loaded: ${find.byType(BannerFrame).evaluate().isNotEmpty}');
    expect(find.byType(Scaffold), findsWidgets);
  });
}
