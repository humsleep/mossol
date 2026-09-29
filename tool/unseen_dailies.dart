// 안 읽히는 1회성 일상(`once: true`)을 이벤트 하나씩 세는 진단 스크립트.
//
//     flutter test tool/unseen_dailies.dart
//
// 100일 완주 회차를 여러 개 돌리면서 일상 이벤트마다 두 가지를 센다.
//
//   - **후보로 올라온 적이 있나**(`candidates(daily)` 에 한 번이라도 들었나)
//   - **실제로 읽혔나**
//
// 한 번도 후보가 못 된 것은 추첨 운이 아니라 **트리거가 안 열린 것**이다. 그런 이벤트는
// 트리거 조항을 하나씩 떼어 보면서 "이 조항만 없으면 열렸을 날이 며칠인가"를 같이 찍는다.
// 어느 조항이 범인인지 눈으로 보고 고치라는 표다.
//
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/mbti.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/minigames/registry.dart';

import '../test/sim_balance_test.dart'
    show
        FocusStrategy,
        MaxAffectionStrategy,
        FirstStrategy,
        Strategy,
        kMinigameSuccess,
        loadBundle,
        simAbsent,
        simTop;

/// 회차 하나의 집계.
class RunTally {
  final Set<String> offered = {};
  final Set<String> seen = {};

  /// 스탯 이름 → 날마다의 값(계획 직전). 조건 범위를 어디에 그을지 재는 자료.
  final Map<String, List<int>> statByDay = {};

  /// 읽은 순서대로의 씬 식별자. 변형을 세는 판과 안 세는 판을 따로 둔다.
  final List<String> readIds = [];
  final List<String> readScenes = [];
  final Set<String> dailyOffered = {};
  int dailyPicks = 0;

  /// 이벤트 id → 그 조항 하나만 빼면 통과했을 날 수.
  final Map<String, Map<String, int>> nearMiss = {};
}

/// `Trigger` 를 조항별로 쪼개 하나씩 검사한다. `TriggerMatch.matches` 와 같은 규칙이다.
Map<String, bool> clauseResults(
  Trigger t,
  GameState s, {
  String? self,
  String? selfMbti,
  Set<String> absent = const {},
}) {
  final out = <String, bool>{};
  if (t.pref != null) {
    out['pref=${t.pref}'] = Preference.allowsSide(s.preference, t.pref);
  }
  if (t.mbti != null) out['mbti=${t.mbti}'] = Mbti.matches(t.mbti!, s.mbti);
  if (t.noMbti) out['noMbti'] = s.mbti == null;
  if (t.compat != null) {
    out['compat'] =
        self != null && t.compat!.contains(Mbti.compat(s.mbti, selfMbti));
  }
  if (t.flagsAtLeast != null) {
    final fc = t.flagsAtLeast!;
    out['flagsAtLeast ${fc.n}/${fc.of.join("|")}'] =
        fc.of.where(s.flags.contains).length >= fc.n;
  }
  if (t.day != null) out['day'] = t.day!.contains(s.day);
  if (t.run != null) out['run'] = t.run!.contains(s.run);
  for (final e in t.stats.entries) {
    out['stat:${e.key}'] = e.value.contains(s.stat(e.key));
  }
  for (final e in t.affection.entries) {
    final id = e.key == '*' ? self : e.key;
    if (id != null && absent.contains(id)) continue;
    out['aff:${e.key}'] = id != null && e.value.contains(s.affectionOf(id));
  }
  for (final e in t.trust.entries) {
    final id = e.key == '*' ? self : e.key;
    if (id != null && absent.contains(id)) continue;
    out['trust:${e.key}'] = id != null && e.value.contains(s.trustOf(id));
  }
  for (final f in t.flags) {
    out['flag:$f'] = s.flags.contains(f);
  }
  for (final f in t.notFlags) {
    out['notFlag:$f'] = !s.flags.contains(f);
  }
  final any = t.anyAffection;
  if (any != null) {
    var n = 0;
    s.relations.forEach((id, r) {
      if (!absent.contains(id) && r.affection >= any.min) n++;
    });
    out['anyAff ${any.count}명 ${any.min}↑'] = n >= any.count;
  }
  return out;
}

RunTally playRun(StoryBundle b, Strategy strat, int seed, String pref) {
  final engine = EventEngine(b);
  final s = GameState.fresh(
    b.config,
    b.characters,
    seed: seed,
    preference: pref,
    mbti: null,
    nowMs: 0,
  );
  simAbsent = engine.absentFor(s);
  final absent = engine.absentFor(s);
  final r = Random(seed * 7919 + strat.name.hashCode);
  final t = RunTally();
  final dailies = b.eventsByLayer[EventLayer.daily]!;

  while (!engine.isFinished(s)) {
    final slot = engine.spinRoulette(s);
    s.rouletteDay = s.day;
    engine.applyRoulette(s, slot);
    engine.applyAction(s, strat.action(s, b.config.actions, r, b));
    for (final e in engine.candidates(s, EventLayer.daily)) {
      t.offered.add(e.id);
      t.dailyOffered.add(e.id);
    }
    if (s.day >= 20) {
      for (final k in const [
        'esteem',
        'stress',
        'money',
        'talk',
        'charm',
        'sincerity',
      ]) {
        (t.statByDay[k] ??= []).add(s.stat(k));
      }
    }
    // 오늘 후보가 못 된 것들에 대해 조항별 근접도를 센다.
    for (final e in dailies) {
      if (e.once && s.seen.contains(e.id)) continue;
      if (e.character != null && absent.contains(e.character)) continue;
      final res = clauseResults(
        e.trigger,
        s,
        self: e.character,
        selfMbti: engine.mbtiOf(e.character),
        absent: absent,
      );
      final failed = [
        for (final kv in res.entries)
          if (!kv.value) kv.key,
      ];
      if (failed.length == 1) {
        (t.nearMiss[e.id] ??= {}).update(
          failed.first,
          (v) => v + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final queue = engine.planDay(s);
    while (queue.isNotEmpty) {
      final base = queue.removeAt(0);
      // 변형을 세는 판의 씬 식별자. `EventEngine.variantOf` 와 같은 회전식이다.
      final n = base.variants.length + 1;
      final vi = n == 1
          ? 0
          : (EventEngine.stableSeed(s.seed, 0, 'variant:${base.id}') % n +
                    (base.once ? 0 : s.viewsOf(base.id))) %
                n;
      final ev = engine.viewFor(s, base);
      t.readIds.add(ev.id);
      t.readScenes.add(vi == 0 ? ev.id : '${ev.id}#$vi');
      if (ev.layer == EventLayer.daily) t.dailyPicks++;
      t.seen.add(ev.id);
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

void main() {
  test('안 읽히는 once 일상 목록', () {
    registerMinigames();
    final b = loadBundle();
    final dailies = b.eventsByLayer[EventLayer.daily]!;
    final cases = <(Strategy, int, String)>[
      for (final seed in [1, 7, 42, 99, 2024])
        for (final pref in [Preference.female, Preference.male]) ...[
          (MaxAffectionStrategy(), seed, pref),
          (FirstStrategy(), seed, pref),
          (
            FocusStrategy(b.charactersFor(pref).first.id),
            seed,
            pref,
          ),
        ],
    ];
    final runs = [for (final (s, seed, pref) in cases) playRun(b, s, seed, pref)];

    // 회차별 집계
    final offeredIn = <String, int>{};
    final seenIn = <String, int>{};
    final nearMiss = <String, Map<String, int>>{};
    for (final t in runs) {
      for (final id in t.offered) {
        offeredIn.update(id, (v) => v + 1, ifAbsent: () => 1);
      }
      for (final id in t.seen) {
        seenIn.update(id, (v) => v + 1, ifAbsent: () => 1);
      }
      t.nearMiss.forEach((id, m) {
        final dst = nearMiss[id] ??= {};
        m.forEach((k, v) => dst.update(k, (o) => o + v, ifAbsent: () => v));
      });
    }

    final once = [for (final e in dailies) if (e.once) e];
    print('=== 일상 ${dailies.length}개 (once ${once.length}) · 회차 ${runs.length}개 ===');
    final avgUnseen =
        runs.map((t) => once.where((e) => !t.seen.contains(e.id)).length).reduce((a, x) => a + x) /
        runs.length;
    print('회차당 안 읽힌 once 일상 평균 ${avgUnseen.toStringAsFixed(1)} / ${once.length}');

    print('\n--- A. 어느 회차에서도 후보조차 못 된 것 (트리거가 안 열린다) ---');
    for (final e in once) {
      if ((offeredIn[e.id] ?? 0) == 0) {
        final nm = nearMiss[e.id] ?? {};
        final top = (nm.entries.toList()
              ..sort((a, b) => b.value - a.value))
            .take(3)
            .map((x) => '${x.key}×${x.value}')
            .join(', ');
        print('  ${e.id}  w=${e.weight}  ${top.isEmpty ? "(조항 둘 이상이 동시에 막는다)" : "이것만 아니면 열렸을 날: $top"}');
      }
    }

    var neverOffered = 0;
    var offeredUnseen = 0;
    for (final t in runs) {
      for (final e in once) {
        if (t.seen.contains(e.id)) continue;
        if (t.offered.contains(e.id)) {
          offeredUnseen++;
        } else {
          neverOffered++;
        }
      }
    }
    print(
      '회차당 — 후보조차 못 됨 ${(neverOffered / runs.length).toStringAsFixed(1)} · '
      '후보는 됐는데 안 뽑힘 ${(offeredUnseen / runs.length).toStringAsFixed(1)}',
    );

    // 재방송 비율 — 30회차 평균. `test/rerun_share_test.dart` 와 같은 정의다
    // (읽은 씬 − 서로 다른 씬) / 읽은 씬. 변형을 세는 판을 같이 찍는다.
    double avg(Iterable<double> xs) =>
        xs.reduce((a, b) => a + b) / xs.length;
    double shareOf(List<String> l) =>
        l.isEmpty ? 0 : (l.length - l.toSet().length) / l.length;
    final byId = [for (final t in runs) shareOf(t.readIds)];
    final byScene = [for (final t in runs) shareOf(t.readScenes)];
    final floors = [
      for (final t in runs)
        max(0, t.dailyPicks - t.dailyOffered.length) / t.readIds.length,
    ];
    print(
      '\n재방송(30회차) — id 기준 평균 ${(avg(byId) * 100).toStringAsFixed(1)}% '
      '(${(byId.reduce(min) * 100).toStringAsFixed(1)}~${(byId.reduce(max) * 100).toStringAsFixed(1)}%) · '
      '변형까지 센 기준 ${(avg(byScene) * 100).toStringAsFixed(1)}%',
    );
    print(
      '  회차당 읽은 씬 ${(runs.map((t) => t.readIds.length).reduce((a, b) => a + b) / runs.length).toStringAsFixed(1)} · '
      '일상 칸 뽑기 ${(runs.map((t) => t.dailyPicks).reduce((a, b) => a + b) / runs.length).toStringAsFixed(1)} · '
      '일상 후보 종류 ${(runs.map((t) => t.dailyOffered.length).reduce((a, b) => a + b) / runs.length).toStringAsFixed(1)} · '
      '이론상 바닥 ${(avg(floors) * 100).toStringAsFixed(1)}%',
    );

    print('\n--- A1. 뒷일 장면(mo_fail_*)이 회차당 몇 번 읽히나 ---');
    final failReads = <String, int>{};
    for (final t in runs) {
      for (final id in t.readIds) {
        if (id.startsWith('mo_fail_')) {
          failReads.update(id, (v) => v + 1, ifAbsent: () => 1);
        }
      }
    }
    final fr = failReads.entries.toList()..sort((a, b) => b.value - a.value);
    for (final e in fr) {
      print('  ${e.key.padRight(24)} 회차당 ${(e.value / runs.length).toStringAsFixed(2)}회');
    }
    print('  합계 회차당 ${(failReads.values.fold(0, (a, b) => a + b) / runs.length).toStringAsFixed(1)}회');

    print('\n--- A2. 전체 표 (읽힌 회차 수 오름차순) ---');
    final all = [
      for (final e in once) (e.id, offeredIn[e.id] ?? 0, seenIn[e.id] ?? 0),
    ]..sort((a, b) => a.$3 != b.$3 ? a.$3 - b.$3 : a.$2 - b.$2);
    for (final (id, o, sn) in all) {
      print('  ${id.padRight(26)} 후보 ${o.toString().padLeft(2)}/30 · 읽힘 ${sn.toString().padLeft(2)}/30');
    }

    print('\n--- B. 후보는 되지만 회차 절반 이상에서 안 읽히는 것 ---');
    final half = runs.length / 2;
    final rows = <(String, int, int)>[];
    for (final e in once) {
      final o = offeredIn[e.id] ?? 0;
      final sn = seenIn[e.id] ?? 0;
      if (o > 0 && sn < half) rows.add((e.id, o, sn));
    }
    rows.sort((a, b) => a.$3 - b.$3);
    for (final (id, o, sn) in rows) {
      print('  $id  후보 $o/${runs.length}회차 · 읽힘 $sn/${runs.length}회차');
    }

    print('\n--- C. 후보로는 되는데 읽힌 적이 0인 것 ---');
    for (final e in once) {
      if ((offeredIn[e.id] ?? 0) > 0 && (seenIn[e.id] ?? 0) == 0) {
        print('  ${e.id}  후보 ${offeredIn[e.id]}회차 · 한 번도 안 읽힘');
      }
    }

    print('\n--- C2. D+20 이후 스탯 분포(백분위) ---');
    for (final k in const [
      'esteem',
      'stress',
      'money',
      'talk',
      'charm',
      'sincerity',
    ]) {
      final all = <int>[];
      for (final t in runs) {
        all.addAll(t.statByDay[k] ?? const []);
      }
      all.sort();
      int p(int q) => all[(all.length - 1) * q ~/ 100];
      print(
        '  ${k.padRight(10)} p05=${p(5)} p25=${p(25)} p50=${p(50)} p75=${p(75)} p95=${p(95)}',
      );
    }

    print('\n--- D. 반복 가능(once:false) 일상 ---');
    for (final e in dailies) {
      if (!e.once) {
        print('  ${e.id}  후보 ${offeredIn[e.id] ?? 0}/${runs.length} · 읽힘 ${seenIn[e.id] ?? 0}/${runs.length} · 변형 ${e.variants.length}');
      }
    }
    expect(true, isTrue);
  });
}
