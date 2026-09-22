// 통합 테스트 공용 도구. 실기기(시뮬레이터)에서 실제 플러그인·SharedPreferences·에셋 번들로
// 앱을 main.dart 와 같은 순서로 띄운다. 광고(AdManager.init)는 기본으로 켜지 않는다 —
// ATT/UMP 시스템 팝업과 전면 광고(닫힐 때까지 await)가 흐름을 막기 때문이다.

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/analytics/analytics.dart';
import 'package:mossol/engine/event_engine.dart' show ChoiceView;
import 'package:mossol/engine/models.dart';
import 'package:mossol/minigames/minigame.dart' show minigameIds;
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/main.dart';
import 'package:mossol/minigames/registry.dart';
import 'package:mossol/ui/notification_card.dart';
import 'package:mossol/ui/portraits.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _booted = false;
StoryBundle? _bundle;

/// main() 의 초기화 중 한 번만 할 것(라이선스·미니게임 등록·Firebase·초상화).
Future<void> _bootOnce() async {
  if (_booted) return;
  _booted = true;
  registerPretendardLicense();
  registerMinigames();
  // 실제 Firebase 를 켠다(플러그인 확인). 테스트 이벤트가 운영 통계에 섞이지 않게 수집은 끈다.
  await Analytics.init();
  try {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
  } catch (e) {
    debugPrint('[it] analytics collection off 실패: $e');
  }
  await PortraitRegistry.load();
}

/// 앱을 "처음부터" 띄운다. [fresh] 면 SharedPreferences 를 비운다(새로 설치).
/// 아니면 디스크(NSUserDefaults)에서 다시 읽어 콜드 스타트를 흉내 낸다.
Future<GameController> bootApp(WidgetTester tester, {bool fresh = false}) async {
  await _bootOnce();
  // 이전 앱 트리(타이머 포함)를 내린다.
  await tester.pumpWidget(const SizedBox.shrink());
  final prefs = await SharedPreferences.getInstance();
  if (fresh) {
    await prefs.clear();
  } else {
    await prefs.reload();
  }
  // 에셋 번들도 main 처럼 실제로 읽는다(검증 포함). 두 번째부터는 캐시.
  _bundle ??= await StoryBundle.loadFromAssets(knownMinigames: minigameIds);
  final c = GameController(bundle: _bundle!, save: SaveService());
  await c.init();
  await tester.pumpWidget(MossolApp(controller: c));
  await pumpFor(tester, const Duration(milliseconds: 600));
  return c;
}

/// 실시간으로 [d] 동안 프레임을 돌린다. pumpAndSettle 은 1초 타이머 화면에서 끝나지 않을 수 있다.
Future<void> pumpFor(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  do {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  } while (DateTime.now().isBefore(end));
}

/// 조건이 참이 될 때까지(최대 [timeout]) 프레임을 돌린다. 시간 초과면 false.
Future<bool> pumpUntil(
  WidgetTester tester,
  bool Function() cond, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) return false;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
  await tester.pump();
  return true;
}

Future<void> tapAndPump(
  WidgetTester tester,
  Finder f, {
  Duration settle = const Duration(milliseconds: 500),
}) async {
  expect(f, findsWidgets, reason: '탭할 대상 없음: $f');
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first);
  await pumpFor(tester, settle);
}

// ---------------------------------------------------------------------------
// WORD JOINER(U+2060) 를 무시하는 찾기 (test/widget/helpers.dart 와 같은 규칙)
// ---------------------------------------------------------------------------

String plain(String? s) => (s ?? '').replaceAll('⁠', '');

String? _textOf(Widget w) {
  if (w is Text) return w.data ?? w.textSpan?.toPlainText();
  if (w is EditableText) return w.controller.text;
  return null;
}

Finder findText(String s) => find.byWidgetPredicate((w) {
  final t = _textOf(w);
  return t != null && plain(t) == s;
}, description: 'text "$s"');

Finder findTextContaining(Pattern p) => find.byWidgetPredicate((w) {
  final t = _textOf(w);
  return t != null && plain(t).contains(p);
}, description: 'text containing $p');

/// 화면에 그려진 모든 글자(RichText 기준, WJ 제거).
List<String> screenTexts(WidgetTester tester) => [
  for (final w in tester.allWidgets)
    if (w is RichText) plain(w.text.toPlainText()),
];

// ---------------------------------------------------------------------------
// 게임 진행 도구
// ---------------------------------------------------------------------------

/// 룰렛 시트를 UI 로 돌리고 닫는다.
Future<void> spinRouletteUi(WidgetTester tester) async {
  final ok = await pumpUntil(
    tester,
    () => findText('오늘의 운').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 5),
  );
  expect(ok, isTrue, reason: '룰렛 시트가 뜨지 않음');
  await tapAndPump(tester, findText('돌리기'), settle: const Duration(milliseconds: 1800));
  await tapAndPump(tester, findText('시작'), settle: const Duration(milliseconds: 800));
  expect(findText('오늘의 운'), findsNothing);
}

/// 컨트롤러로 고를 선택지: 힌트(잠기지 않았으면) → 잠기지 않은 첫 선택지.
ChoiceView pickChoice(GameController c, {bool avoidMinigame = false, bool avoidDecline = false}) {
  final views = c.choices;
  final hint = c.current?.hint;
  bool ok(ChoiceView v) =>
      !v.locked &&
      !(avoidMinigame && v.choice.minigame != null) &&
      !(avoidDecline && v.choice.decline);
  if (hint != null) {
    for (final v in views) {
      if (v.index == hint && ok(v)) return v;
    }
  }
  return views.firstWhere(ok, orElse: () => views.firstWhere((v) => !v.locked));
}

/// 이벤트 하나를 실제 UI 로 진행한다(알림 카드 · 전화 받기 · 선택 탭 · 계속).
/// [realtime] 이면 말풍선 자동 공개 타이머를 기다리고(읽씹 대기는 [maxWait] 까지),
/// 아니면 컨트롤러 revealNext 로 대사를 즉시 공개한다. 화면 글자를 [seen] 에 모은다.
Future<String> playEventUi(
  WidgetTester tester,
  GameController c, {
  bool realtime = false,
  Duration maxWait = const Duration(seconds: 45),
  List<String>? seen,
}) async {
  final id = c.current!.id;
  // 잠금화면 알림 카드: 탭하면 열린다(아니면 1.8초 뒤 자동).
  if (find.byType(NotificationPreview).evaluate().isNotEmpty) {
    await tester.tap(find.byType(NotificationPreview).first);
    await pumpFor(tester, const Duration(milliseconds: 400));
  }
  // 전화 수신 화면이면 받는다.
  if (findText('받기').evaluate().isNotEmpty) {
    await tapAndPump(tester, findText('받기'), settle: const Duration(milliseconds: 400));
  }
  if (realtime) {
    final done = await pumpUntil(tester, () => c.linesDone, timeout: maxWait);
    if (!done) {
      // 긴 읽씹 대기 — 광고 스킵 대신 컨트롤러로 공개한다.
      while (!c.linesDone) {
        c.revealNext();
      }
    }
  } else {
    while (!c.linesDone) {
      c.revealNext();
    }
  }
  await pumpFor(tester, const Duration(milliseconds: 300));
  seen?.addAll(screenTexts(tester));
  if (c.lastOutcome == null) {
    final v = pickChoice(c, avoidMinigame: true, avoidDecline: true);
    final text = plain(c.say(v.choice.text));
    final btn = find.ancestor(
      of: findText(text),
      matching: find.byType(OutlinedButton),
    );
    expect(btn, findsWidgets, reason: '$id 선택지 버튼 없음: $text');
    await tester.ensureVisible(btn.first);
    await tester.pump();
    await tester.tap(btn.first);
    await tester.pump();
    expect(c.lastOutcome, isNotNull, reason: '$id 선택이 적용되지 않음');
  }
  final panel = await pumpUntil(
    tester,
    () => findText('계속').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 8),
  );
  expect(panel, isTrue, reason: '$id 결과 패널(계속)이 뜨지 않음');
  seen?.addAll(screenTexts(tester));
  await tapAndPump(tester, findText('계속'), settle: const Duration(milliseconds: 300));
  return id;
}

/// 행동 화면의 행동 한 줄을 탭한다.
Future<void> tapAction(WidgetTester tester, String name) async {
  final f = findText(name);
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.pump();
  await tester.tap(f);
  await pumpFor(tester, const Duration(milliseconds: 300));
}

/// 정산 화면의 마지막 버튼("다음 날로" / "엔딩 보기")까지 내려 탭한다.
Future<void> tapSummaryButton(WidgetTester tester, String label) async {
  final f = findText(label);
  await tester.scrollUntilVisible(f, 250, scrollable: find.byType(Scrollable).first);
  await pumpFor(tester, const Duration(milliseconds: 200));
  await tester.tap(f);
  await pumpFor(tester, const Duration(milliseconds: 500));
}

/// 오늘의 행동. 스트레스가 높으면 휴식.
DayAction chooseAction(GameController c, int day) {
  final acts = c.config.actions;
  final s = c.state!;
  if (s.stat(Stat.stress) >= 60) return acts.firstWhere((a) => a.id == 'rest');
  const cycle = ['read', 'friends', 'gym', 'style', 'read', 'work'];
  var id = cycle[day % cycle.length];
  if (id == 'style' && s.stat(Stat.money) < 15) id = 'work';
  return acts.firstWhere((a) => a.id == id);
}

/// 컨트롤러 API 로 하루를 빠르게 넘긴다. 화면은 단계마다 한 프레임씩 그려 레이아웃 오류를 잡는다.
/// 룰렛은 시트가 뜨기 전에 컨트롤러로 돌린다. 하트가 없으면 [refill] 일 때 광고 보상(grantHeart)으로 채운다.
/// 돌려주는 값: 이날 본 이벤트 수. 하트가 없어 시작 못 했으면 -1.
Future<int> fastDay(WidgetTester tester, GameController c, {bool refill = true, bool finishDay = true}) async {
  expect(c.phase, Phase.action);
  if (findText('오늘의 운').evaluate().isNotEmpty) {
    await spinRouletteUi(tester);
  } else if (c.canSpinRoulette) {
    c.spinRoulette();
  }
  await tester.pump();
  if (refill && c.state!.hearts <= 0) await c.grantHeart();
  final ok = await c.startDay(chooseAction(c, c.state!.day));
  if (!ok) return -1;
  await tester.pump();
  var n = 0;
  while (c.phase == Phase.event && n < 30) {
    while (!c.linesDone) {
      c.revealNext();
    }
    await tester.pump();
    final v = pickChoice(c);
    c.choose(
      v.index,
      minigameSuccess: v.choice.minigame != null ? true : null,
    );
    await tester.pump();
    c.continueAfterChoice();
    await tester.pump();
    n++;
  }
  expect(c.phase, Phase.summary, reason: '이벤트 큐가 끝나지 않음 (day ${c.state!.day})');
  await tester.pump();
  if (finishDay) {
    await c.endDay();
    if (c.phase == Phase.action && c.canSpinRoulette) c.spinRoulette();
    await tester.pump();
  }
  return n;
}
