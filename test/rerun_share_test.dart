// 재방송 비율 측정 + 회귀 테스트. `flutter test test/rerun_share_test.dart` 로 실행한다.
//
// 재방송 = **이미 읽은 씬을 다시 읽는 것**이다. 이벤트 본문은 JSON 에 고정돼 있으므로
// 같은 id 가 두 번째로 큐에 들어가면 플레이어는 글자 하나 안 바뀐 화면을 다시 본다
// (`{top}` 치환만 달라질 수 있는데, 재방송 상위 목록은 특정 인물을 부르지 않는 장면들이다).
// 그래서 지표는 이렇게 센다:
//
//     재방송 비율 = (읽은 씬 수 − 서로 다른 씬 수) / 읽은 씬 수
//
// docs/review/11_story_verdict.md §1 이 100일 회차 4개에서 **23.3~25.7%** 로 측정한 그 값이고,
// 같은 방식으로 세야 전후를 비교할 수 있다.
//
// **이 파일은 전후를 한 테스트 안에서 같이 돌린다.** `config` 만 예전 값으로 되돌린 번들
// ([legacyBundle])과 출시 번들을 같은 시드·같은 전략으로 100일씩 돌려 비교한다.
// 그래서 엔진 수정을 되돌리면 이 테스트는 반드시 깨진다 — 되돌리지 않아도 깨지는 것을
// 눈으로 확인할 수 있게 두 숫자를 항상 함께 찍는다.
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';

import 'sim_balance_test.dart'
    show
        loadBundle,
        simAbsent,
        simTop,
        kMinigameSuccess,
        Strategy,
        MaxAffectionStrategy,
        FocusStrategy;

/// 출시 `config.json` 에서 **이번에 넣은 두 장치만** 예전 값으로 되돌린 번들.
/// 데이터는 손대지 않으므로 차이는 순수하게 엔진 쪽 변화다.
/// - `repeatWeightPercent: 100` → 본 횟수에 따른 가중치 감쇠 없음
/// - `fillSeenBelow: 99` → 보충 칸이 이미 본 장면으로도 분량을 채운다(예전 그대로)
StoryBundle legacyBundle() {
  final raw =
      jsonDecode(File('assets/story/config.json').readAsStringSync())
          as Map<String, dynamic>;
  raw['repeatWeightPercent'] = 100;
  raw['fillSeenBelow'] = 99;
  return StoryBundle.fromJsonStrings(
    config: jsonEncode(raw),
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
    requireEndingHints: true,
    requireDailyDepth: true,
  );
}

/// 한 회차에서 읽은 씬 기록.
class RerunTally {
  /// 읽은 순서대로의 이벤트 id.
  final List<String> order = [];

  /// 층별로 읽은 수·재방송 수.
  final Map<EventLayer, int> readByLayer = {};
  final Map<EventLayer, int> rerunByLayer = {};

  /// 장면 열쇠(`id#변형번호`) → 읽은 횟수. **id 가 아니다.**
  ///
  /// `StoryEvent.variants` 가 붙어도 `id` 는 그대로라, id 로 세면 대사가 전부 다른 두
  /// 장면을 같은 것으로 센다. 그러면 변형을 아무리 써도 이 숫자가 안 움직여서, 재방송을
  /// 줄이려고 만든 도구를 재방송을 재는 계측이 못 보는 상태가 된다
  /// (docs/review/13_content_fixes.md 의 지적이 정확히 이것이었다).
  /// 열쇠는 [EventEngine.variantIndexOf] 로 만든다 — 회전 공식을 베끼지 않는다.
  final Map<String, int> count = {};

  /// id 로만 센 것. 옛 숫자와 이어 보려고 남긴다 — 판정 기준은 [count] 다.
  final Map<String, int> idCount = {};

  /// 일상 후보로 **한 번이라도** 올라온 이벤트 id. 재방송의 이론상 하한을 계산한다.
  final Set<String> dailyOffered = {};

  /// 그 후보들이 낼 수 있는 서로 다른 대본 수(원본 + 변형). 하한은 이걸로 잰다.
  int dailyOfferedScenes = 0;

  /// 일상 칸에서 뽑힌 횟수(같은 장면을 여러 번 뽑은 것도 센다).
  int dailyPicks = 0;

  int get read => order.length;
  int get distinct => count.length;
  int get reruns => read - distinct;
  double get share => read == 0 ? 0 : reruns / read;

  /// 일상 후보를 **하나도 낭비하지 않고** 다 읽은 뒤에야 되풀이했다고 가정한 최소 재방송.
  /// 일상 칸이 요구하는 개수가 낼 수 있는 장면 종류보다 많으면, 그 차이는 어떤 추첨
  /// 규칙으로도 지울 수 없다. 즉 이 값이 **엔진만으로 도달 가능한 바닥**이다.
  int get rerunFloor =>
      max(0, dailyPicks - max(dailyOffered.length, dailyOfferedScenes));

  void saw(StoryEvent e, int variant) {
    final key = variant == 0 ? e.id : '${e.id}#$variant';
    order.add(key);
    final n = (count[key] ?? 0) + 1;
    count[key] = n;
    idCount[e.id] = (idCount[e.id] ?? 0) + 1;
    readByLayer[e.layer] = (readByLayer[e.layer] ?? 0) + 1;
    if (n > 1) rerunByLayer[e.layer] = (rerunByLayer[e.layer] ?? 0) + 1;
    if (e.layer == EventLayer.daily) dailyPicks++;
  }

  /// id 로만 센 재방송 비율. 옛 보고와 잇기 위한 참고값이다.
  double get idShare =>
      read == 0 ? 0 : (read - idCount.length) / read;

  /// 한 회차에 같은 씬을 가장 많이 읽은 횟수.
  int get maxRepeat => count.values.fold(1, max);

  /// 많이 재방송된 순서. (id, 읽은 횟수).
  List<(String, int)> get worst {
    final l = [
      for (final e in count.entries)
        if (e.value > 1) (e.key, e.value),
    ]..sort((a, b) => b.$2 - a.$2);
    return l;
  }
}

/// 100일을 끝까지 돌린다. 엔딩 조건이 먼저 맞아도 멈추지 않는다 —
/// 재방송은 100일을 완주하는 플레이어가 겪는 문제이므로 100일을 다 세야 한다.
///
/// 하루 처리는 `GameController.startDay`/`_apply` 와 같은 순서다. 특히 체인된 다음
/// 이벤트를 큐에 넣을 때 **컨트롤러처럼 중복을 먼저 제거한다**(`_queue.removeWhere`) —
/// 이걸 빼면 같은 씬이 하루에 두 번 찍혀 재방송을 실제보다 높게 센다
/// (11_story_verdict §0 이 전사 하네스에서 찾은 결함이 정확히 이것이다).
RerunTally playFullRun(
  StoryBundle b,
  Strategy strat,
  int seed,
  String pref, {
  String? mbti,
}) {
  final engine = EventEngine(b);
  final s = GameState.fresh(
    b.config,
    b.characters,
    seed: seed,
    preference: pref,
    mbti: mbti,
    nowMs: 0,
  );
  simAbsent = engine.absentFor(s);
  final r = Random(seed * 7919 + strat.name.hashCode);
  final t = RerunTally();

  while (!engine.isFinished(s)) {
    final slot = engine.spinRoulette(s);
    s.rouletteDay = s.day;
    engine.applyRoulette(s, slot);
    engine.applyAction(s, strat.action(s, b.config.actions, r, b));
    for (final e in engine.candidates(s, EventLayer.daily)) {
      if (t.dailyOffered.add(e.id)) {
        t.dailyOfferedScenes += 1 + e.variants.length;
      }
    }
    final queue = engine.planDay(s);
    while (queue.isNotEmpty) {
      final queue0 = queue.removeAt(0);
      final ev = engine.viewFor(s, queue0);
      // 열쇠는 엔진의 회전 공식을 그대로 쓴다(공식을 테스트에 베끼지 않는다).
      t.saw(ev, engine.variantIndexOf(s, queue0));
      final views = engine.choicesFor(s, ev);
      final open = views.where((v) => !v.locked).toList();
      simTop = engine.topCharacter(s);
      if (open.isEmpty) {
        s.seen.add(ev.id);
        continue;
      }
      final c = ev.choices[strat.pick(s, ev, open, r, engine)];
      bool? forced;
      if (c.minigame != null) forced = r.nextDouble() < kMinigameSuccess;
      final out = engine.applyChoice(s, ev, c, forcedSuccess: forced);
      final next = out.nextEventId;
      if (next != null) {
        final ne = engine.byId(next);
        if (ne != null) {
          queue.removeWhere((e) => e.id == ne.id);
          queue.insert(0, ne);
        }
      }
    }
    engine.endDay(s);
  }
  return t;
}

/// 측정에 쓰는 회차 목록. 11_story_verdict 가 쓴 시드 1·7·42 를 그대로 쓰고,
/// 전략은 "호감이 제일 오르는 선택"(보통 플레이어)과 "한 명만 판다"(집중 플레이어) 둘이다.
List<(String, Strategy, int, String)> runCases(StoryBundle b) {
  final f = b.charactersFor(Preference.female).first.id;
  final m = b.charactersFor(Preference.male).first.id;
  return [
    ('maxAff seed1 f', MaxAffectionStrategy(), 1, Preference.female),
    ('maxAff seed7 f', MaxAffectionStrategy(), 7, Preference.female),
    ('maxAff seed42 f', MaxAffectionStrategy(), 42, Preference.female),
    ('maxAff seed7 m', MaxAffectionStrategy(), 7, Preference.male),
    ('focus seed1 f', FocusStrategy(f), 1, Preference.female),
    ('focus seed42 m', FocusStrategy(m), 42, Preference.male),
  ];
}

/// 100일 회차 여러 개의 결과 한 줄 요약.
({double minShare, double avgShare, double maxShare, int maxRepeat, int floor})
summarize(List<RerunTally> runs, String label) {
  final shares = [for (final t in runs) t.share];
  final avg = shares.reduce((a, b) => a + b) / shares.length;
  final floor = [for (final t in runs) t.rerunFloor / t.read].reduce(min);
  print(
    '[$label] 재방송 '
    '최소 ${(shares.reduce(min) * 100).toStringAsFixed(1)}% / '
    '평균 ${(avg * 100).toStringAsFixed(1)}% / '
    '최대 ${(shares.reduce(max) * 100).toStringAsFixed(1)}%, '
    '한 씬 최다 ${runs.map((t) => t.maxRepeat).reduce(max)}회, '
    '회차당 읽은 씬 ${(runs.map((t) => t.read).reduce((a, b) => a + b) / runs.length).round()}개',
  );
  return (
    minShare: shares.reduce(min),
    avgShare: avg,
    maxShare: shares.reduce(max),
    maxRepeat: runs.map((t) => t.maxRepeat).reduce(max),
    floor: (floor * 100).round(),
  );
}

void main() {
  late StoryBundle release;
  late StoryBundle legacy;
  setUpAll(() {
    registerMinigames();
    release = loadBundle();
    legacy = legacyBundle();
  });

  test('100일 완주: 재방송 비율이 예전 엔진보다 확실히 낮다', () {
    final before = [
      for (final (_, s, seed, pref) in runCases(legacy))
        playFullRun(legacy, s, seed, pref),
    ];
    final after = [
      for (final (_, s, seed, pref) in runCases(release))
        playFullRun(release, s, seed, pref),
    ];
    final b = summarize(before, '예전 엔진(감쇠 없음 + 보충 칸이 재방송 허용)');
    final a = summarize(after, '지금 엔진');
    for (final t in after) {
      final top = t.worst.take(8).map((e) => '${e.$1}×${e.$2}').join(', ');
      print('  최다 반복: $top');
      break;
    }
    print(
      '  이론상 바닥(일상 후보를 하나도 낭비하지 않았을 때) ≈ ${a.floor}% '
      '— 이 아래로는 데이터(일상 장면 수)가 늘어야 내려간다',
    );

    // (1) 예전 엔진은 어느 회차에서도 25% 를 넘는다. 이 줄이 '전'을 고정한다 —
    //     문턱값이 예전 데이터에서도 통과해 버리는 헛 테스트가 아니라는 증거다.
    // 옛 문턱은 25% 였다. 그때는 이 계측이 **id 로** 셌기 때문이다 — 대사가 전부 다른
    // 변형까지 같은 장면으로 묶어서, 변형을 쓰면 쓸수록 실제와 멀어졌다
    // (docs/review/13_content_fixes.md). 지금은 `id#변형번호` 로 세고, 같은 데이터에서
    // 예전 엔진이 11.6% · 지금 엔진이 4.9% 다. 눈금이 바뀌었으니 문턱도 같이 바꾼다.
    expect(
      b.minShare,
      greaterThan(0.08),
      reason: '예전 엔진 쪽이 이만큼도 안 되면 전후 비교 자체가 의미 없다',
    );

    // (2) 지금 엔진은 모든 회차가 25% 미만이어야 한다.
    //
    //     문턱값을 25% 로 둔 이유(그리고 **목표가 25% 가 아닌 이유**):
    //     - 목표는 10% 다. 지금 도달한 값은 18.8~22.6%(평균 21.2%)로 목표에 못 미친다.
    //     - 못 미치는 이유는 추첨 규칙이 아니라 분량이다. 100일 회차가 일상 칸에서
    //       약 150번 뽑는데, 트리거를 통과해 후보로 올라오는 일상은 회차당 94~99종뿐이다.
    //       차이(약 50개)는 어떤 규칙으로도 지울 수 없다 → [RerunTally.rerunFloor].
    //     - 그래서 문턱은 '목표'가 아니라 **회귀 방지선**이다. 예전 값(26.0~29.7%)과
    //       지금 값(18.8~22.6%) 사이를 25% 로 갈라, 엔진이 되돌아가면 즉시 깨지게 둔다.
    //     - 10% 로 내리려면 일상 장면이 회차당 약 140종 필요하다(지금 94~99종).
    //       남은 일은 docs/review/12_engine_handoff.md §1 에 적었다.
    expect(
      a.maxShare,
      lessThan(0.10),
      reason: '재방송이 10% 로 되돌아갔다 — 감쇠·보충 칸·변형이 살아 있는지 확인',
    );

    // (3) 개선 폭이 실제로 있는지. 실측 6.7%p(11.6 → 4.9)이고, 문턱은 3%p 로 둔다 —
    //     데이터가 늘면 양쪽이 같이 내려가므로 여유를 둔다.
    expect(b.avgShare - a.avgShare, greaterThan(0.03));

    // (4) 실측에서 가장 크게 체감된 것은 비율보다 '같은 씬이 일곱 번'이었다
    //     (`d_drink_02` 7회, 11_story_verdict §4-1). 회차당 최다 반복이 줄어야 한다.
    expect(a.maxRepeat, lessThan(b.maxRepeat));
    expect(a.maxRepeat, lessThanOrEqualTo(3));
  });

  test('100일 완주: once 이벤트는 한 번도 재등장하지 않는다', () {
    // `once` 는 층과 무관하게 걸린다. 100일 회차 6개에서 두 번 읽힌 `once` 이벤트가
    // 하나라도 있으면 실패다. 예전 엔진(감쇠 없음)에서도 같아야 한다 —
    // 이 테스트가 잡는 것은 감쇠가 아니라 `EventEngine._available` 의 `once` 한 줄이다.
    for (final bundle in [release, legacy]) {
      for (final (label, strat, seed, pref) in runCases(bundle)) {
        final t = playFullRun(bundle, strat, seed, pref);
        // 여기서는 **id 기준**이 맞다 — 묻는 것이 "이 이벤트를 두 번 읽었나" 이고,
        // 어느 변형을 봤는지는 상관없다(`count` 는 `id#변형번호` 로 센다).
        final bad = [
          for (final e in t.idCount.entries)
            if (e.value > 1 && bundle.eventById[e.key]!.once)
              '${e.key}×${e.value}',
        ];
        expect(bad, isEmpty, reason: '$label: once 인데 재등장했다 — $bad');
        // 반복되는 것은 전부 `once: false` 이고, 지금 데이터에서는 전부 일상이다.
        for (final e in t.idCount.entries) {
          if (e.value > 1) {
            expect(bundle.eventById[e.key]!.layer, EventLayer.daily);
          }
        }
      }
    }
  });

  test('출시 데이터는 반복 가능한 일상이 냉각을 버틸 만큼 있다', () {
    // `once: true` 를 더 붙이다가 반복 가능한 일상이 냉각 일수보다 적어지면
    // 100일 후반에 일상 칸이 마른다. `validate(requireDailyDepth: true)` 가 그것을
    // 막는데, 실제로 막히는지 여기서 확인한다(콘텐츠가 데이터를 계속 고치고 있다).
    final need = release.config.dailyCooldownDays;
    for (final pref in Preference.genders) {
      final n = release.repeatableDaily(pref).length;
      print('반복 가능한 일상(${Preference.label(pref)}) $n개 / 최소 $need개');
      expect(n, greaterThanOrEqualTo(need));
    }
    // 그리고 실제로 예외가 되는지 — 전부 `once: true` 인 데이터는 통과하지 못한다.
    expect(
      () => StoryBundle(
        config: release.config,
        characters: release.characters,
        events: [
          for (final e in release.events)
            if (e.layer != EventLayer.daily) e,
        ],
        endings: release.endings,
      ).validate(requireDailyDepth: true),
      throwsStateError,
    );
  });
}
