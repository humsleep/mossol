import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/audio/sfx_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/main.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';
import 'package:mossol/ui/design_system.dart';
import 'package:mossol/ui/onboarding_mbti_screen.dart';
import 'package:mossol/ui/onboarding_name_screen.dart';
import 'package:mossol/ui/start_pick_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../story_files.dart';

StoryBundle? _cached;

/// 실제 assets/story/*.json 을 dart:io 로 읽는다. 광고 SDK 는 건드리지 않는다.
StoryBundle testBundle() {
  registerMinigames();
  return _cached ??= StoryBundle.fromJsonStrings(
    config: File('assets/story/config.json').readAsStringSync(),
    characters: File('assets/story/characters.json').readAsStringSync(),
    events: [
      for (final f in StoryBundle.eventFiles)
        readStoryFile(f),
    ],
    endings: File('assets/story/endings.json').readAsStringSync(),
    signals: File('assets/story/signals.json').existsSync()
        ? File('assets/story/signals.json').readAsStringSync()
        : null,
    starts: readStartsFile(),
    knownMinigames: minigameIds,
  );
}

/// 기본은 **두 번째 세션 이후**의 컨트롤러다: 첫 실행 인트로를 이미 본 것으로 표시하므로
/// `fullApp(c)` 가 홈에서 시작한다(기존 흐름 테스트가 보던 상태).
/// [firstLaunch] 를 주면 아무것도 표시하지 않아 첫 실행(인트로)이 그대로 뜬다.
Future<GameController> makeController({bool firstLaunch = false}) async {
  SharedPreferences.setMockInitialValues({});
  final c = GameController(bundle: testBundle(), save: SaveService());
  await c.init();
  if (!firstLaunch) await c.markIntroSeen();
  return c;
}

/// 앱과 같은 테마로 화면 하나를 감싼다. 실제 앱의 AppTheme 를 그대로 쓴다.
Widget wrapApp(Widget child, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: mode,
  home: child,
);

Widget fullApp(GameController c) => MossolApp(controller: c);

/// 작은 화면 + 큰 글꼴. tearDown 에서 자동 복원.
void useSmallScreenLargeFont(
  WidgetTester tester, {
  Size size = const Size(320, 568),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// 시스템 "동작 줄이기" 를 켠다(`MediaQuery.disableAnimations`). tearDown 에서 복원.
///
/// 조상에 `MediaQuery(data: MediaQueryData(disableAnimations: true))` 를 씌우는 방법도
/// 있지만, 그러면 `MediaQueryData()` 의 기본값인 **크기 0×0** 까지 함께 덮어써서 화면이
/// 레이아웃되지 않는다 — 탭이 아무것도 맞히지 못하는 테스트가 된다. 앱의 `MediaQuery` 는
/// 뷰에서 만들어지므로 접근성 설정을 뷰에 꽂는 쪽이 실제 기기와 같다.
void useReducedMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void useDarkMode(WidgetTester tester) {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// 새 게임 이름 단계("뭐라고 불러 드릴까요?")가 떠 있으면 건너뛰기를 누른다. 없으면 아무것도 안 한다.
/// 이름 단계는 이름이 없고 아직 한 번도 묻지 않았을 때만 뜬다(docs/NAME_GUIDE.md).
///
/// 이어서 MBTI 단계("나의 MBTI는?")가 떠 있으면 그것도 건너뛴다([skipMbtiStep]).
/// 두 단계 모두 캐스트 소개 앞에 오고, 기존 흐름 테스트는 둘 다 건너뛴 경로를 본다.
Future<void> skipNameStep(WidgetTester tester) async {
  await tester.pumpAndSettle();
  if (find.byType(OnboardingNameScreen).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('name-skip')));
    await tester.pumpAndSettle();
  }
  await skipMbtiStep(tester);
}

/// 새 게임 MBTI 단계가 떠 있으면 `건너뛰기` 를 누른다. 없으면 아무것도 안 한다.
/// MBTI 단계는 MBTI 가 없고 아직 한 번도 묻지 않았을 때만 뜬다(docs/MBTI_SPEC.md §2.1).
Future<void> skipMbtiStep(WidgetTester tester) async {
  await tester.pumpAndSettle();
  if (find.byType(OnboardingMbtiScreen).evaluate().isEmpty) return;
  await tester.tap(find.byKey(const Key('mbti-skip')));
  await tester.pumpAndSettle();
}

/// 이벤트 대사가 전부 공개될 때까지 1초씩 시간을 흘린다(읽씹 대기 포함).
Future<void> revealAll(WidgetTester tester, GameController c) async {
  for (var i = 0; i < 400 && !c.linesDone; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pump();
  expect(c.linesDone, isTrue, reason: '대사가 끝나지 않음: ${c.current?.id}');
}

/// 선택 뒤 상대 반응(최대 3줄, 줄당 750ms)이 다 뜨고 결과 패널이 올라올 때까지.
Future<void> settleReplies(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 800));
  }
}

/// 잠기지 않고 미니게임도 없는 첫 선택지.
/// 잠기지 않고, 미니게임도 확률 판정도 없는 선택지.
/// 결과가 항상 성공이라 테스트가 난수에 흔들리지 않는다.
int plainChoiceIndex(GameController c) => c.choices
    .firstWhere(
      (v) => !v.locked && v.choice.minigame == null && v.choice.chance == null,
    )
    .index;

/// 룰렛 시트를 돌리고 시작을 눌러 닫는다.
Future<void> spinRouletteSheet(WidgetTester tester) async {
  await tester.pumpAndSettle();
  expect(findText('오늘의 운'), findsOneWidget);
  await tester.tap(findText('돌리기'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump();
  await tester.tap(findText('시작'));
  await tester.pumpAndSettle();
  expect(findText('오늘의 운'), findsNothing);
}

/// 효과음·진동 호출을 기록만 하는 서비스. 플러그인 채널을 건드리지 않는다.
///
/// `setUp` 에서 `SfxService.instance = RecordingSfxService()`, `tearDown` 에서
/// `NoopSfxService()` 로 되돌린다([useRecordingSfx]). 벨은 [played] 에
/// `Sfx.callRing` 으로 남고 정지는 [ringStops] 로 센다.
class RecordingSfxService extends SfxService {
  final played = <Sfx>[];
  final haptics = <HapticKind>[];
  int ringStops = 0;
  int stopAlls = 0;
  bool ringing = false;

  @override
  void onPlay(Sfx cue) => played.add(cue);

  @override
  void onHaptic(HapticKind kind) => haptics.add(kind);

  @override
  void startRing() {
    if (ringing) return;
    ringing = true;
    play(Sfx.callRing);
  }

  @override
  void stopRing() {
    if (!ringing) return;
    ringing = false;
    ringStops++;
  }

  @override
  void stopAll() {
    stopRing();
    stopAlls++;
  }

  void clear() {
    played.clear();
    haptics.clear();
  }
}

/// 기록용 서비스를 끼우고 테스트가 끝나면 기본(Noop)으로 되돌린다.
RecordingSfxService useRecordingSfx() {
  final s = RecordingSfxService();
  SfxService.instance = s;
  addTearDown(() => SfxService.instance = NoopSfxService());
  return s;
}

MinigameContext ctxFor(GameController c, {String? partner}) => MinigameContext(
  state: c.state!,
  partner: partner == null ? null : c.characterOf(partner),
);

GameState freshState() {
  final b = testBundle();
  return GameState.fresh(b.config, b.characters, seed: 7);
}

// ---------------------------------------------------------------------------
// 화면 글자 찾기. 표시 문자열에는 한국어 단어 단위 줄바꿈을 위해 보이지 않는
// WORD JOINER(U+2060)가 들어간다(lib/ui/keep_all.dart). flutter_test 의
// find.text 는 문자열을 그대로 비교하므로, 이 문자를 지우고 비교하는 찾기를 쓴다.
// ---------------------------------------------------------------------------

String _plain(String? s) => (s ?? '').replaceAll('⁠', '');

String? _textOf(Widget w) {
  if (w is Text) return w.data ?? w.textSpan?.toPlainText();
  if (w is EditableText) return w.controller.text;
  return null;
}

/// find.text 와 같되 WORD JOINER 를 무시한다.
Finder findText(String s, {bool skipOffstage = true}) => find.byWidgetPredicate(
  (w) {
    final t = _textOf(w);
    return t != null && _plain(t) == s;
  },
  description: 'text "$s"',
  skipOffstage: skipOffstage,
);

/// find.textContaining 과 같되 WORD JOINER 를 무시한다.
Finder findTextContaining(Pattern p, {bool skipOffstage = true}) =>
    find.byWidgetPredicate(
      (w) {
        final t = _textOf(w);
        return t != null && _plain(t).contains(p);
      },
      description: 'text containing $p',
      skipOffstage: skipOffstage,
    );

/// find.widgetWithText 와 같되 WORD JOINER 를 무시한다.
Finder findWidgetWithText(Type type, String s, {bool skipOffstage = true}) =>
    find.ancestor(
      of: findText(s, skipOffstage: skipOffstage),
      matching: find.byType(type, skipOffstage: skipOffstage),
    );

/// 시작 카드 시트(docs/overhaul2/01_design.md §4)가 떠 있으면 [id] 카드를 고른다.
/// 시트가 없으면(시작 정의가 없는 번들) 아무것도 하지 않는다.
/// [settle] 이 false 면 고른 뒤 한 프레임만 그린다(바로 다음 단계를 프레임 단위로 볼 때).
Future<void> pickStart(
  WidgetTester tester, [
  String id = StartScenario.classic,
  bool settle = true,
]) async {
  await tester.pumpAndSettle();
  if (find.byType(StartPickSheet).evaluate().isEmpty) return;
  final card = find.byKey(Key('start-card-$id'));
  await scrollStartSheetTo(tester, card);
  await tester.tap(card);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// 시작 카드 시트 목록을 [target] 이 보일 때까지 굴린다(목록은 화면 밖 카드를 아직 안 만든다).
Future<void> scrollStartSheetTo(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scrollable = find.descendant(
      of: find.byKey(const Key('start-pick-list')),
      matching: find.byType(Scrollable),
    );
    // 운명 카드가 맨 위라 아래로 굴린 뒤에는 위로 돌아가야 보인다. 맨 위에서 아래로 찾는다.
    final pos = tester.state<ScrollableState>(scrollable).position;
    pos.jumpTo(pos.minScrollExtent);
    await tester.pump();
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
    }
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
