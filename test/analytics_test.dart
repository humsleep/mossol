// 측정 이벤트 배선(docs/ROADMAP.md Phase 0). Firebase 없이 가짜 백엔드로 본다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/analytics/analytics.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/preference_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget/helpers.dart';

Future<(GameController, RecordingAnalyticsBackend)> recorded() async {
  SharedPreferences.setMockInitialValues({});
  final rec = RecordingAnalyticsBackend();
  final c = GameController(
    bundle: testBundle(),
    save: SaveService(),
    analytics: Analytics(backend: rec),
  );
  await c.init();
  return (c, rec);
}

void main() {
  test('facade: 백엔드가 던져도 삼킨다, 규칙에 맞는 이름만', () async {
    final a = Analytics(backend: _Throwing());
    a.log(Analytics.albumOpened);
    a.setUserProperty('pref', 'f');
    await Future<void>.delayed(Duration.zero);
    expect(() => a.log('Bad-Name'), throwsA(isA<AssertionError>()));
    expect(
      () => a.log('ok', {'this_key_is_way_too_long_for_firebase': 1}),
      throwsA(isA<AssertionError>()),
    );
  });

  test('run_started: 회차 · 선호 · 기기 누적 수, 사용자 속성 pref · mbti_known', () async {
    final (c, rec) = await recorded();
    expect(rec.userProperties['mbti_known'], '0');
    await c.setPlayerMbti('INFP');
    expect(rec.userProperties['mbti_known'], '1');
    await c.newGame(seed: 1, preference: Preference.female);
    await c.newGame(seed: 2, preference: Preference.male);
    expect(rec.paramsOf(Analytics.runStarted).toList(), [
      {'run': 1, 'pref': 'f', 'n': 1},
      {'run': 1, 'pref': 'm', 'n': 2},
    ]);
    expect(rec.userProperties['pref'], 'm');
  });

  test('day_reached 는 마일스톤 날에만', () async {
    final (c, rec) = await recorded();
    await c.newGame(seed: 3, preference: Preference.female);
    for (var i = 0; i < 35 && c.phase != Phase.ending; i++) {
      await c.endDay();
    }
    final days = [
      for (final p in rec.paramsOf(Analytics.dayReached)) p['day'] as int,
    ];
    final reached = c.state!.day;
    expect(days, [
      for (final d in [2, 3, 7, 10, 20, 30])
        if (d <= reached) d,
    ]);
    expect(days.toSet().length, days.length, reason: '같은 날 두 번 안 보낸다');
  });

  test('run_ended: 엔딩 id · 등급 · 회차 · 날', () async {
    final (c, rec) = await recorded();
    await c.newGame(seed: 4, preference: Preference.female);
    c.state!.day = c.config.totalDays;
    await c.endDay();
    expect(c.phase, Phase.ending);
    final p = rec.paramsOf(Analytics.runEnded).single;
    expect(p, {
      'ending': c.ending!.id,
      'tier': c.ending!.tier,
      'run': 1,
      'day': c.config.totalDays,
    });
  });

  test('heart_empty: 하트 없이 행동하면 그날', () async {
    final (c, rec) = await recorded();
    await c.newGame(seed: 5);
    c.state!
      ..hearts = 0
      ..lastHeartMs = c.nowMs();
    expect(await c.startDay(c.config.actions.first), isFalse);
    expect(rec.paramsOf(Analytics.heartEmpty).single, {'day': 1});
  });

  test('onboarding_done: 첫 판만, 이름은 있다/없다만', () async {
    final (c, rec) = await recorded();
    await c.setPlayerName('민석');
    c.logOnboardingDone(preference: 'f', mbtiSource: Analytics.mbtiSkip);
    expect(rec.paramsOf(Analytics.onboardingDone).single, {
      'pref': 'f',
      'has_name': 1,
      'has_mbti': 0,
      'mbti_source': 'skip',
    });
    await c.newGame(seed: 6, preference: Preference.female);
    c.logOnboardingDone(preference: 'f', mbtiSource: Analytics.mbtiSkip);
    c.logOnboardingStep(Analytics.stepCast);
    expect(rec.paramsOf(Analytics.onboardingDone), hasLength(1));
    expect(rec.paramsOf(Analytics.onboardingStep), isEmpty);
    // 어떤 이벤트에도 이름이 실리지 않는다.
    for (final (_, params) in rec.events) {
      expect(params.values.whereType<String>(), isNot(contains('민석')));
    }
  });

  testWidgets('온보딩 흐름: 단계마다 onboarding_step, 간이 테스트면 mbti_source quiz', (
    tester,
  ) async {
    final (c, rec) = await recorded();
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(fullApp(c));
    await tester.pump();
    await tester.tap(findText('새 게임'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('gender-${PlayerGender.male}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('name-skip')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('mbti-unsure')));
    await tester.tap(find.byKey(const Key('mbti-unsure')));
    await tester.pumpAndSettle();
    for (final l in ['I', 'N', 'F', 'P']) {
      await tester.tap(find.byKey(Key('mbti-quiz-$l')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('mbti-submit')));
    await tester.pumpAndSettle();
    await tester.tap(findText(PreferenceScreen.startLabel));
    await tester.pumpAndSettle();
    expect(c.phase, Phase.action);

    expect(
      [for (final p in rec.paramsOf(Analytics.onboardingStep)) p['step']],
      ['gender', 'name', 'mbti', 'cast'],
    );
    expect(rec.paramsOf(Analytics.onboardingDone).single, {
      'pref': 'f',
      'has_name': 0,
      'has_mbti': 1,
      'mbti_source': 'quiz',
    });
    // 온보딩 끝 → 회차 시작 순서.
    expect(
      rec.names.indexOf(Analytics.onboardingDone),
      lessThan(rec.names.indexOf(Analytics.runStarted)),
    );
    await tester.pumpWidget(Container());
  });
}

class _Throwing implements AnalyticsBackend {
  @override
  Future<void> logEvent(String name, Map<String, Object> params) async =>
      throw StateError('down');

  @override
  Future<void> setUserProperty(String name, String? value) =>
      throw StateError('sync down');
}
