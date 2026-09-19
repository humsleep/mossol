import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/main.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';
import 'package:mossol/ui/design_system.dart';
import 'package:mossol/ui/onboarding_name_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

StoryBundle? _cached;

/// 실제 assets/story/*.json 을 dart:io 로 읽는다. 광고 SDK 는 건드리지 않는다.
StoryBundle testBundle() {
  registerMinigames();
  return _cached ??= StoryBundle.fromJsonStrings(
    config: File('assets/story/config.json').readAsStringSync(),
    characters: File('assets/story/characters.json').readAsStringSync(),
    events: [
      for (final f in StoryBundle.eventFiles)
        File('assets/story/$f').readAsStringSync(),
    ],
    endings: File('assets/story/endings.json').readAsStringSync(),
    signals: File('assets/story/signals.json').existsSync()
        ? File('assets/story/signals.json').readAsStringSync()
        : null,
    knownMinigames: minigameIds,
  );
}

Future<GameController> makeController() async {
  SharedPreferences.setMockInitialValues({});
  final c = GameController(bundle: testBundle(), save: SaveService());
  await c.init();
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

void useDarkMode(WidgetTester tester) {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// 새 게임 이름 단계("뭐라고 불러 드릴까요?")가 떠 있으면 건너뛰기를 누른다. 없으면 아무것도 안 한다.
/// 이름 단계는 이름이 없고 아직 한 번도 묻지 않았을 때만 뜬다(docs/NAME_GUIDE.md).
Future<void> skipNameStep(WidgetTester tester) async {
  await tester.pumpAndSettle();
  if (find.byType(OnboardingNameScreen).evaluate().isEmpty) return;
  await tester.tap(find.byKey(const Key('name-skip')));
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
