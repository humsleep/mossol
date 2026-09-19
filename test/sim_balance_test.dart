// 시뮬레이션 결과를 콘솔과 파일로 남기는 분석용 테스트다.
// ignore_for_file: avoid_print
// 밸런스 시뮬레이션. `flutter test test/sim_balance_test.dart` 로 실행.
// 결과는 콘솔과 tool/sim_out/ 아래 파일로 남긴다. 소스는 건드리지 않는다.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/ending_resolver.dart';
import 'package:mossol/engine/effects.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';

const kSeeds = int.fromEnvironment('SEEDS', defaultValue: 200);
const kMinigameSuccess = int.fromEnvironment("MG", defaultValue: 60) / 100;

/// 스토리 데이터 위치. 전후 비교 때 같은 스냅샷을 쓰려고 바꿀 수 있게 둔다.
const kStoryDir = String.fromEnvironment(
  'STORY_DIR',
  defaultValue: 'assets/story',
);

/// 결과 파일 위치. 여러 실험을 동시에 돌릴 때 서로 덮어쓰지 않게 바꿀 수 있다.
const kOutDir = String.fromEnvironment('SIM_OUT', defaultValue: 'tool/sim_out');

/// true 면 config 의 earlyAffection(초반 호감 가속)을 빼고 돌린다. 전후 비교용.
const kNoEarly = bool.fromEnvironment('NO_EARLY');

/// 회차 선호(`--dart-define=PREF=f|m|all`). 봇은 이 쪽 캐릭터만 대상으로 삼는다.
/// `all` 은 선호 도입 전(예전 세이브)과 같은 전원 등장 회차다.
const kPref = String.fromEnvironment('PREF', defaultValue: Preference.female);

/// [kPref] 를 검사해 돌려준다. 오타면 조용히 all 로 돌지 않게 바로 실패한다.
String simPreference() {
  if (!Preference.values.contains(kPref)) {
    throw ArgumentError('PREF 는 ${Preference.values.join('|')}: $kPref');
  }
  return kPref;
}

String _config() {
  final raw = File('$kStoryDir/config.json').readAsStringSync();
  if (!kNoEarly) return raw;
  final j = jsonDecode(raw) as Map<String, dynamic>..remove('earlyAffection');
  return jsonEncode(j);
}

StoryBundle loadBundle() => StoryBundle.fromJsonStrings(
  config: _config(),
  characters: File('$kStoryDir/characters.json').readAsStringSync(),
  events: [
    for (final f in StoryBundle.eventFiles)
      File('$kStoryDir/$f').readAsStringSync(),
  ],
  endings: File('$kStoryDir/endings.json').readAsStringSync(),
  signals: File('$kStoryDir/signals.json').existsSync()
      ? File('$kStoryDir/signals.json').readAsStringSync()
      : null,
  knownMinigames: minigameIds,
  requireEndingHints: true,
);

// ---------- 전략 ----------

/// 선택 직전의 호감 1위. 효과 키 `@top` 을 봇이 실제 대상으로 읽게 한다.
/// 이게 없으면 `@top` 선택지를 가치 0으로 보고 엉뚱한 선택을 한다.
String? simTop;

/// 지금 회차 선호 밖이라 등장하지 않는 캐릭터. 엔진이 그 id 효과를 버리므로 봇도 가치 0으로 본다.
Set<String> simAbsent = const {};

double sumMap(Map<String, int> m, {String? only, String? self}) {
  var t = 0.0;
  m.forEach((k, v) {
    final id = k == '*' ? self : (k == topKey ? simTop : k);
    if (id == null || simAbsent.contains(id)) return;
    if (only == null || id == only) t += v;
  });
  return t;
}

double pSuccess(GameState s, Choice c, EventEngine e) {
  if (c.minigame != null) return kMinigameSuccess;
  if (c.chance != null) {
    return (c.chance! + e.chanceBonus(s)).clamp(0, 100) / 100;
  }
  return 1;
}

double statSum(Map<String, int> m, {bool stressPositive = true}) {
  var t = 0.0;
  m.forEach((k, v) {
    if (k == Stat.stress) {
      t += stressPositive ? -v : 0;
    } else if (k == Stat.money) {
      t += v / 10;
    } else {
      t += v;
    }
  });
  return t;
}

DayAction byId(List<DayAction> a, String id) => a.firstWhere((x) => x.id == id);

abstract class Strategy {
  String get name;
  DayAction action(GameState s, List<DayAction> acts, Random r, StoryBundle b);
  int pick(
    GameState s,
    StoryEvent ev,
    List<ChoiceView> open,
    Random r,
    EventEngine e,
  );
}

/// 1. 항상 첫 번째(열린) 선택지, 아침 행동도 첫 번째(헬스장).
class FirstStrategy extends Strategy {
  @override
  String get name => 'first';
  @override
  DayAction action(
    GameState s,
    List<DayAction> acts,
    Random r,
    StoryBundle b,
  ) => acts.first;
  @override
  int pick(
    GameState s,
    StoryEvent ev,
    List<ChoiceView> open,
    Random r,
    EventEngine e,
  ) => open.first.index;
}

DayAction sensibleAction(
  GameState s,
  List<DayAction> acts,
  List<String> rotate,
) {
  if (s.stat(Stat.stress) >= 65) return byId(acts, 'rest');
  if (s.stat(Stat.money) < 15) return byId(acts, 'work');
  return byId(acts, rotate[s.day % rotate.length]);
}

/// 2. 모든 캐릭터 호감 합의 기대값이 가장 큰 선택지.
class MaxAffectionStrategy extends Strategy {
  @override
  String get name => 'maxAff';
  @override
  DayAction action(
    GameState s,
    List<DayAction> acts,
    Random r,
    StoryBundle b,
  ) => sensibleAction(s, acts, ['read', 'style', 'friends', 'gym']);
  @override
  int pick(
    GameState s,
    StoryEvent ev,
    List<ChoiceView> open,
    Random r,
    EventEngine e,
  ) {
    ChoiceView? best;
    var bestScore = double.negativeInfinity;
    for (final v in open) {
      final c = v.choice;
      final p = pSuccess(s, c, e);
      final self = ev.character;
      final score =
          p *
              (sumMap(c.effects.affection, self: self) +
                  0.5 * sumMap(c.effects.trust, self: self) +
                  0.1 * statSum(c.effects.stats)) +
          (1 - p) *
              (sumMap(c.fail.affection, self: self) +
                  0.5 * sumMap(c.fail.trust, self: self) +
                  0.1 * statSum(c.fail.stats) -
                  (c.fail.album != null ? 1 : 0)) -
          (c.effects.album != null ? 1 : 0);
      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return best!.index;
  }
}

/// [target] 의 해피 엔딩(`<id>_happy`)이 요구하는 플래그. 집중 플레이어는 그걸 세우는 선택을 안다
/// (서연 반말 `seoyeon_banmal`, 건우 `geonwoo_stay`, 유나 `yuna_noticed` 등). 12명 모두 같은 규칙.
Set<String> happyFlags(StoryBundle b, String target) => _happyFlags.putIfAbsent(
  '${identityHashCode(b)}:$target',
  () => {
    for (final e in b.endings)
      if (e.id == '${target}_happy') ...e.when.flags,
  },
);
final _happyFlags = <String, Set<String>>{};

/// 3. 한 캐릭터 집중. 그 캐릭터의 호감·신뢰, 진정성을 최대화.
class FocusStrategy extends Strategy {
  final String target;
  final bool useHint;
  FocusStrategy(this.target, {this.useHint = false});
  @override
  String get name => useHint ? 'focus+hint' : 'focus';

  @override
  DayAction action(GameState s, List<DayAction> acts, Random r, StoryBundle b) {
    if (s.stat(Stat.stress) >= 65) return byId(acts, 'rest');
    if (s.stat(Stat.money) < 15) return byId(acts, 'work');
    final likes = b.characterById[target]!.likes;
    final like = likes.isEmpty ? 'talk' : likes[s.day % likes.length];
    return switch (like) {
      'charm' =>
        s.stat(Stat.money) >= 30 ? byId(acts, 'style') : byId(acts, 'gym'),
      'talk' => byId(acts, 'read'),
      'sense' => byId(acts, 'read'),
      'esteem' => byId(acts, 'friends'),
      'money' => byId(acts, 'work'),
      'stress' => byId(acts, 'rest'),
      _ => byId(acts, 'read'),
    };
  }

  @override
  int pick(
    GameState s,
    StoryEvent ev,
    List<ChoiceView> open,
    Random r,
    EventEngine e,
  ) {
    if (useHint && ev.hint != null && open.any((v) => v.index == ev.hint)) {
      return ev.hint!;
    }
    ChoiceView? best;
    var bestScore = double.negativeInfinity;
    for (final v in open) {
      final c = v.choice;
      final p = pSuccess(s, c, e);
      final self = ev.character;
      double val(Effects f) =>
          sumMap(f.affection, only: target, self: self) +
          0.8 * sumMap(f.trust, only: target, self: self) +
          0.4 * (f.stats[Stat.sincerity] ?? 0) +
          0.15 * statSum(f.stats) +
          (f.album != null ? -1.5 : 0) +
          (f.setFlags.any(happyFlags(e.bundle, target).contains) ? 6 : 0) +
          (f.setFlags.contains('fishing_mind') || f.setFlags.contains('greedy')
              ? -3
              : 0);
      final score = p * val(c.effects) + (1 - p) * val(c.fail);
      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return best!.index;
  }
}

/// 4. 무작위.
class RandomStrategy extends Strategy {
  @override
  String get name => 'random';
  @override
  DayAction action(
    GameState s,
    List<DayAction> acts,
    Random r,
    StoryBundle b,
  ) => acts[r.nextInt(acts.length)];
  @override
  int pick(
    GameState s,
    StoryEvent ev,
    List<ChoiceView> open,
    Random r,
    EventEngine e,
  ) => open[r.nextInt(open.length)].index;
}

/// 5. 스탯 성장 우선.
class StatGrowthStrategy extends Strategy {
  @override
  String get name => 'statGrow';
  @override
  DayAction action(GameState s, List<DayAction> acts, Random r, StoryBundle b) {
    if (s.stat(Stat.stress) >= 70) return byId(acts, 'rest');
    if (s.stat(Stat.money) < 20) return byId(acts, 'work');
    return byId(acts, ['gym', 'read', 'friends', 'style'][s.day % 4]);
  }

  @override
  int pick(
    GameState s,
    StoryEvent ev,
    List<ChoiceView> open,
    Random r,
    EventEngine e,
  ) {
    ChoiceView? best;
    var bestScore = double.negativeInfinity;
    for (final v in open) {
      final c = v.choice;
      final p = pSuccess(s, c, e);
      final self = ev.character;
      final score =
          p *
              (statSum(c.effects.stats) +
                  0.2 * sumMap(c.effects.affection, self: self)) +
          (1 - p) *
              (statSum(c.fail.stats) +
                  0.2 * sumMap(c.fail.affection, self: self));
      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return best!.index;
  }
}

/// 6. 회피형: 로맨스를 최대한 피하고 스탯·평판·돈만 챙긴다.
/// forever_solo / wedding_guest / coach / ceo 처럼 "누구와도 안 엮이는" 엔딩 도달 시험용.
class AvoidantStrategy extends Strategy {
  @override
  String get name => 'avoidant';
  @override
  DayAction action(GameState s, List<DayAction> acts, Random r, StoryBundle b) {
    // 스탯도 되도록 안 키운다: 돈 떨어질 때만 일하고 그 외엔 휴식.
    if (s.stat(Stat.money) < 10) return byId(acts, 'work');
    return byId(acts, 'rest');
  }

  @override
  int pick(
    GameState s,
    StoryEvent ev,
    List<ChoiceView> open,
    Random r,
    EventEngine e,
  ) {
    // 호감·신뢰 총합(전 캐릭터)이 가장 낮은, 즉 누구와도 안 엮이는 선택지.
    // 동점(대개 0점, 연애와 무관한 이벤트)이면 무작위로 골라 특정 선택지로 쏠리지 않게 한다.
    var bestScore = double.infinity;
    final tied = <ChoiceView>[];
    for (final v in open) {
      final c = v.choice;
      final p = pSuccess(s, c, e);
      double val(Effects f) => sumMap(f.affection) + sumMap(f.trust);
      final score = p * val(c.effects) + (1 - p) * val(c.fail);
      if (score < bestScore - 1e-9) {
        bestScore = score;
        tied
          ..clear()
          ..add(v);
      } else if (score < bestScore + 1e-9) {
        tied.add(v);
      }
    }
    return tied[r.nextInt(tied.length)].index;
  }
}

/// 6b. 결혼식 하객: 회피형과 비슷하지만 평판만 조금씩 챙기고, 눈에 띄는 "나쁜 플래그"는
/// 피해서 jiwoo_bad/doyun_bad/album_master 같은 다른 엔딩에 잡아먹히지 않게 한다.
/// 남성 쪽 짝(승현 소개팅 `seunghyun_intro` ↔ 지우, 유나 `yuna_body_comment` ↔ 도윤 `fake_record`)도 같이 피한다.
/// wedding_guest / friend_wedding 도달 시험용.
class WallflowerStrategy extends Strategy {
  static const _avoidFlags = {
    'jiwoo_intro', 'fake_record', 'overtraining', 'greedy', //
    'seunghyun_intro', 'yuna_body_comment',
  };

  @override
  String get name => 'wallflower';
  @override
  DayAction action(GameState s, List<DayAction> acts, Random r, StoryBundle b) {
    if (s.stat(Stat.stress) >= 60) return byId(acts, 'rest');
    if (s.stat(Stat.money) < 15) return byId(acts, 'work');
    // 평판 60 문턱을 넘으면 더는 안 키운다: friend_wedding(평판 60~) 이 wedding_guest(70+)
    // 로 넘어가기 전 구간에 걸리도록.
    if (s.stat(Stat.reputation) >= 63) return byId(acts, 'rest');
    return byId(acts, 'friends');
  }

  @override
  int pick(
    GameState s,
    StoryEvent ev,
    List<ChoiceView> open,
    Random r,
    EventEngine e,
  ) {
    var bestScore = double.infinity;
    final tied = <ChoiceView>[];
    for (final v in open) {
      final c = v.choice;
      if (c.effects.setFlags.any(_avoidFlags.contains)) continue;
      if (c.effects.album != null) continue;
      final p = pSuccess(s, c, e);
      double val(Effects f) => sumMap(f.affection) + sumMap(f.trust);
      final score = p * val(c.effects) + (1 - p) * val(c.fail);
      if (score < bestScore - 1e-9) {
        bestScore = score;
        tied
          ..clear()
          ..add(v);
      } else if (score < bestScore + 1e-9) {
        tied.add(v);
      }
    }
    if (tied.isEmpty) return open.first.index;
    return tied[r.nextInt(tied.length)].index;
  }
}

/// 7. 독성 연애: 호감만 챙기고 신뢰·진정성은 내다 버린다.
/// seoyeon_bad/haneul_bad/minjae_bad(고호감·저진정성·저신뢰), fishing(양다리) 도달 시험용.
class ToxicStrategy extends Strategy {
  final String target;
  ToxicStrategy(this.target);
  @override
  String get name => 'toxic';
  @override
  DayAction action(GameState s, List<DayAction> acts, Random r, StoryBundle b) {
    if (s.stat(Stat.stress) >= 70) return byId(acts, 'rest');
    return byId(acts, 'style');
  }

  @override
  int pick(
    GameState s,
    StoryEvent ev,
    List<ChoiceView> open,
    Random r,
    EventEngine e,
  ) {
    ChoiceView? best;
    var bestScore = double.negativeInfinity;
    for (final v in open) {
      final c = v.choice;
      final p = pSuccess(s, c, e);
      final self = ev.character;
      // 진정성은 아예 점수에서 빼서, 즉시 pickup_fall(진정성 0)로 끝나기보단
      // 100일까지 버티며 고호감·저진정성 상태로 도착하게 한다.
      double val(Effects f) =>
          sumMap(f.affection, only: target, self: self) -
          1.1 * sumMap(f.trust, only: target, self: self);
      final score = p * val(c.effects) + (1 - p) * val(c.fail);
      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return best!.index;
  }
}

/// 8. 흑역사 수집가: 실패·미니게임을 피하지 않고 album(흑역사)이 남는 선택지를 우선한다.
/// album_master(흑역사 20+) 도달 시험용.
class ChaoticStrategy extends Strategy {
  @override
  String get name => 'worst';
  @override
  DayAction action(GameState s, List<DayAction> acts, Random r, StoryBundle b) {
    // burnout_x3 로 즉시 끝나면 album_master(흑역사 20+)를 못 보므로 스트레스를 관리한다.
    if (s.stat(Stat.stress) >= 55) return byId(acts, 'rest');
    if (s.stat(Stat.money) < 15) return byId(acts, 'work');
    return byId(acts, 'read');
  }

  @override
  int pick(
    GameState s,
    StoryEvent ev,
    List<ChoiceView> open,
    Random r,
    EventEngine e,
  ) {
    // album 이 남는 선택지가 있으면 그걸 고른다(성공/실패 양쪽 다 확인).
    // 단, 진정성이 바닥이면 pickup_fall 로 즉시 끝나 album_master 를 못 보므로,
    // 진정성이 낮을 땐 진정성을 깎지 않는 album 선택지만 받아들인다.
    final lowSincerity = s.stat(Stat.sincerity) <= 8;
    for (final v in open) {
      final c = v.choice;
      final hasAlbum = c.effects.album != null || c.fail.album != null;
      if (!hasAlbum) continue;
      final sincDelta = c.effects.stats[Stat.sincerity] ?? 0;
      if (lowSincerity && sincDelta < 0) continue;
      return v.index;
    }
    // 없으면 호감·신뢰가 가장 깎이는 선택지(진정성이 낮을 땐 그건 건드리지 않는다).
    // 동점(둘 다 0, 이 이벤트와 무관)이면 무작위로 골라 첫 선택지로만 쏠리지 않게 한다.
    var bestScore = double.infinity;
    final tied = <ChoiceView>[];
    for (final v in open) {
      final c = v.choice;
      if (lowSincerity && (c.effects.stats[Stat.sincerity] ?? 0) < 0) continue;
      final p = pSuccess(s, c, e);
      final self = ev.character;
      double val(Effects f) =>
          sumMap(f.affection, self: self) + 0.5 * sumMap(f.trust, self: self);
      final score = p * val(c.effects) + (1 - p) * val(c.fail);
      if (score < bestScore - 1e-9) {
        bestScore = score;
        tied
          ..clear()
          ..add(v);
      } else if (score < bestScore + 1e-9) {
        tied.add(v);
      }
    }
    if (tied.isEmpty) return open.first.index;
    return tied[r.nextInt(tied.length)].index;
  }
}

/// 9. 양다리: 두 캐릭터의 호감만 같이 끌어올린다. fishing(둘 다 60+, 저진정성) 도달 시험용.
class DoubleTimerStrategy extends Strategy {
  final String targetA;
  final String targetB;
  DoubleTimerStrategy(this.targetA, this.targetB);
  @override
  String get name => 'doubleTimer';
  @override
  DayAction action(GameState s, List<DayAction> acts, Random r, StoryBundle b) {
    if (s.stat(Stat.stress) >= 65) return byId(acts, 'rest');
    if (s.stat(Stat.money) < 15) return byId(acts, 'work');
    return byId(acts, ['style', 'read'][s.day % 2]);
  }

  @override
  int pick(
    GameState s,
    StoryEvent ev,
    List<ChoiceView> open,
    Random r,
    EventEngine e,
  ) {
    // 진정성이 바닥나면 pickup_fall 로 즉시 끝나 fishing/양다리를 못 보므로,
    // 진정성이 낮을 땐 그걸 더 깎는 선택지를 후보에서 뺀다.
    final lowSincerity = s.stat(Stat.sincerity) <= 8;
    ChoiceView? best;
    var bestScore = double.negativeInfinity;
    for (final v in open) {
      final c = v.choice;
      if (lowSincerity && (c.effects.stats[Stat.sincerity] ?? 0) < 0) continue;
      final p = pSuccess(s, c, e);
      final self = ev.character;
      double val(Effects f) =>
          sumMap(f.affection, only: targetA, self: self) +
          sumMap(f.affection, only: targetB, self: self) -
          0.4 * (f.stats[Stat.sincerity] ?? 0);
      final score = p * val(c.effects) + (1 - p) * val(c.fail);
      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return (best ?? open.first).index;
  }
}

/// 9. 조율자(3회차 전용): 특정 캐릭터에 몰빵하지 않고 신뢰를 고르게 쌓는다.
/// legend(전원 신뢰 70+, 호감 79 이하, hardcore 플래그, run≥3) 도달 시험용.
class HarmonizerStrategy extends Strategy {
  @override
  String get name => 'harmonizer';
  @override
  DayAction action(GameState s, List<DayAction> acts, Random r, StoryBundle b) {
    if (s.stat(Stat.stress) >= 65) return byId(acts, 'rest');
    if (s.stat(Stat.money) < 15) return byId(acts, 'work');
    return byId(acts, ['read', 'friends', 'gym', 'style'][s.day % 4]);
  }

  @override
  int pick(
    GameState s,
    StoryEvent ev,
    List<ChoiceView> open,
    Random r,
    EventEngine e,
  ) {
    for (final v in open) {
      if (v.choice.effects.setFlags.contains('hardcore')) return v.index;
    }
    ChoiceView? best;
    var bestScore = double.negativeInfinity;
    for (final v in open) {
      final c = v.choice;
      final p = pSuccess(s, c, e);
      final self = ev.character;
      double val(Effects f) =>
          sumMap(f.trust, self: self) -
          0.4 * sumMap(f.affection, self: self) +
          0.1 * statSum(f.stats);
      final score = p * val(c.effects) + (1 - p) * val(c.fail);
      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return best!.index;
  }
}

// ---------- 한 회차 결과 ----------

class RunResult {
  final String strategy;
  final int seed;
  final String? target;
  String ending = '';
  String tier = '';
  int endDay = 0;
  final Map<String, int> stats = {};
  final Map<String, int> aff = {};
  final Map<String, int> trust = {};
  int lockedSeen = 0;
  int lockedOpen = 0;
  int eventsTotal = 0;
  int daysPlayed = 0;
  int emptyDays = 0;
  int album = 0;
  int crisisDays = 0;
  final Map<String, int> crisisIds = {};
  int burnoutEvents = 0;
  int stressMax = 0;
  int stressHighDays = 0;
  int minigamePlays = 0;
  int minigameFails = 0;
  int chanceFails = 0;
  int crits = 0;
  int onFireChoices = 0;
  int? dailyExhaustDay;
  int dailyPicked = 0;
  int dailyRepeatPicked = 0;
  final Map<String, int> routeByChar = {};
  int hiddenSeen = 0;
  int stuckEvents = 0;
  int waitLines = 0;
  int daysWithNoDailyCandidate = 0;
  final Set<String> flags = {};
  int mainSeen = 0;
  final Map<String, int> gainByLayer = {};
  final Map<String, int> lossByLayer = {};
  int decayTotal = 0;
  final Map<String, int> firstDay = {};
  final Map<int, int> onceDailyUnseenAt = {};
  final Map<int, int> onceDailyAvailAt = {};
  final Set<String> dailySeen = {};
  final List<int> lockSeenByCh = List.filled(5, 0);
  final List<int> lockOpenByCh = List.filled(5, 0);
  final Map<int, Map<String, int>> statAt = {};

  /// 그날 아침(전날 마감 뒤) 최고 호감과 집중 대상 호감. 키는 "며칠째 끝" (3, 10, 20).
  final Map<int, int> topAffAfter = {};
  final Map<int, int> targetAffAfter = {};
  double estSeconds = 0;
  int dailyNoCandFrom2 = 0;
  RunResult(this.strategy, this.seed, this.target);
}

RunResult simulate(
  StoryBundle b,
  Strategy strat,
  int seed, {
  int run = 1,
  String? pref,
}) {
  final engine = EventEngine(b);
  final resolver = EndingResolver(b.endings, characters: b.characters);
  final s = GameState.fresh(
    b.config,
    b.characters,
    seed: seed,
    run: run,
    preference: pref ?? simPreference(),
  );
  simAbsent = engine.absentFor(s);
  final r = Random(seed * 7919 + strat.name.hashCode);
  final res = RunResult(
    strat.name,
    seed,
    strat is FocusStrategy ? strat.target : null,
  );
  Ending? ending;

  while (!engine.isFinished(s)) {
    // 룰렛 (광고 재추첨 없음)
    final slot = engine.spinRoulette(s);
    s.rouletteDay = s.day;
    engine.applyRoulette(s, slot);
    // 아침 행동
    engine.applyAction(s, strat.action(s, b.config.actions, r, b));

    if (const [4, 11, 21].contains(s.day)) {
      res.topAffAfter[s.day - 1] = s.relations.values.fold(
        0,
        (a, x) => max(a, x.affection),
      );
      if (res.target != null) {
        res.targetAffAfter[s.day - 1] = s.affectionOf(res.target!);
      }
    }
    final dailyCandList = engine.candidates(s, EventLayer.daily);
    final dailyCand = dailyCandList.length;
    if (dailyCand == 0 && s.day >= 2) {
      res.dailyNoCandFrom2++;
      res.dailyExhaustDay ??= s.day;
    }
    if (const [10, 20, 40, 60, 80, 100].contains(s.day)) {
      final onceDaily = b.events.where(
        (e) => e.layer == EventLayer.daily && e.once,
      );
      res.onceDailyUnseenAt[s.day] = onceDaily
          .where((e) => !s.seen.contains(e.id))
          .length;
      res.onceDailyAvailAt[s.day] = dailyCandList.where((e) => e.once).length;
      res.statAt[s.day] = {for (final k in Stat.all) k: s.stat(k)};
    }
    res.estSeconds += 8; // 룰렛·아침 행동·정산 화면
    final queue = engine.planDay(s);
    if (queue.isEmpty) res.emptyDays++;
    if (queue.any((e) => e.layer == EventLayer.crisis)) res.crisisDays++;
    for (final e in queue) {
      if (e.layer == EventLayer.crisis) {
        res.crisisIds[e.id] = (res.crisisIds[e.id] ?? 0) + 1;
        if (e.id == 'c_burnout') res.burnoutEvents++;
      }
      if (e.layer == EventLayer.daily) {
        res.dailyPicked++;
        res.dailySeen.add(e.id);
        if (!e.once) res.dailyRepeatPicked++;
      }
      if (e.layer == EventLayer.route) {
        res.routeByChar[e.character ?? '?'] =
            (res.routeByChar[e.character ?? '?'] ?? 0) + 1;
      }
      if (e.layer == EventLayer.hidden) res.hiddenSeen++;
      if (e.layer == EventLayer.main) res.mainSeen++;
    }

    while (queue.isNotEmpty) {
      final ev = queue.removeAt(0);
      res.eventsTotal++;
      // 읽씹 대기 줄: UI 가 자존감 -1
      for (final l in ev.lines) {
        if (l.isWait) {
          res.waitLines++;
          res.estSeconds += l.wait;
          s.stats[Stat.esteem] = (s.stat(Stat.esteem) - 1).clamp(0, 100);
        } else {
          res.estSeconds +=
              switch (l.who) {
                'me' => 0.45,
                'narr' => 0.35,
                _ => 0.8,
              } +
              l.text.length / 25.0;
        }
      }
      res.estSeconds += 5; // 선택 고민
      final views = engine.choicesFor(s, ev);
      final ch = ((s.day - 1) ~/ b.config.chapterLength).clamp(0, 4);
      for (final v in views) {
        if (v.choice.require != null) {
          res.lockedSeen++;
          res.lockSeenByCh[ch]++;
          if (!v.locked) {
            res.lockedOpen++;
            res.lockOpenByCh[ch]++;
          }
        }
      }
      final open = views.where((v) => !v.locked).toList();
      simTop = engine.topCharacter(s);
      if (open.isEmpty) {
        res.stuckEvents++;
        s.seen.add(ev.id);
        continue;
      }
      final idx = strat.pick(s, ev, open, r, engine);
      final c = ev.choices[idx];
      bool? forced;
      if (c.minigame != null) {
        res.minigamePlays++;
        res.estSeconds += 12;
        forced = r.nextDouble() < kMinigameSuccess;
        if (!forced) res.minigameFails++;
      }
      if (s.onFire) res.onFireChoices++;
      final out = engine.applyChoice(s, ev, c, forcedSuccess: forced);
      out.delta.affection.forEach((k, v) {
        final key = ev.layer.name;
        if (v > 0) {
          res.gainByLayer[key] = (res.gainByLayer[key] ?? 0) + v;
        } else {
          res.lossByLayer[key] = (res.lossByLayer[key] ?? 0) + v;
        }
      });
      final core = [Stat.charm, Stat.talk, Stat.esteem, Stat.sense];
      if (core.every((k) => s.stat(k) >= 60)) {
        res.firstDay.putIfAbsent('core60', () => s.day);
      }
      if (core.any((k) => s.stat(k) >= 100)) {
        res.firstDay.putIfAbsent('anyStat100', () => s.day);
      }
      if (core.every((k) => s.stat(k) >= 100)) {
        res.firstDay.putIfAbsent('allStat100', () => s.day);
      }
      if (s.relations.values.any((x) => x.affection >= 80)) {
        res.firstDay.putIfAbsent('aff80', () => s.day);
      }
      if (s.relations.values.any((x) => x.trust >= 70)) {
        res.firstDay.putIfAbsent('trust70', () => s.day);
      }
      if (s.stat(Stat.sincerity) >= 100) {
        res.firstDay.putIfAbsent('sinc100', () => s.day);
      }
      if (!out.success && c.minigame == null) res.chanceFails++;
      if (out.critical) res.crits++;
      final next = out.nextEventId;
      if (next != null) {
        final ne = engine.byId(next);
        if (ne != null) queue.insert(0, ne);
      }
    }

    final st = s.stat(Stat.stress);
    if (st > res.stressMax) res.stressMax = st;
    if (st >= 70) res.stressHighDays++;
    res.daysPlayed++;
    res.decayTotal += s.relations.values
        .where((x) => !x.contactedToday && x.affection > 0)
        .length;
    engine.endDay(s);
    final imm = resolver.immediate(s);
    if (imm != null) {
      ending = imm;
      break;
    }
  }
  ending ??= resolver.resolve(s);
  res.ending = ending.id;
  res.tier = ending.tier;
  res.endDay = s.day - 1;
  res.stats.addAll(s.stats);
  for (final c in engine.rosterFor(s)) {
    res.aff[c.id] = s.affectionOf(c.id);
    res.trust[c.id] = s.trustOf(c.id);
  }
  res.album = s.album.length;
  res.flags.addAll(s.flags);
  return res;
}

// ---------- 집계 ----------

String pct(num a, num b) =>
    b == 0 ? '-' : '${(100 * a / b).toStringAsFixed(1)}%';

class Dist {
  final List<num> xs;
  Dist(Iterable<num> v) : xs = v.toList()..sort();
  num get mean => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
  num q(double p) => xs.isEmpty ? 0 : xs[((xs.length - 1) * p).round()];
  String get summary =>
      'mean ${mean.toStringAsFixed(1)} p10 ${q(0.1)} med ${q(0.5)} p90 ${q(0.9)} max ${xs.isEmpty ? 0 : xs.last}';
  String hist(List<int> edges) {
    final counts = List.filled(edges.length, 0);
    for (final x in xs) {
      for (var i = edges.length - 1; i >= 0; i--) {
        if (x >= edges[i]) {
          counts[i]++;
          break;
        }
      }
    }
    return [
      for (var i = 0; i < edges.length; i++)
        '${edges[i]}+:${pct(counts[i], xs.length)}',
    ].join(' ');
  }
}

void main() {
  late StoryBundle bundle;
  setUpAll(() {
    registerMinigames();
    bundle = loadBundle();
  });

  test('밸런스 시뮬레이션 200시드 × 전략', () {
    final out = StringBuffer();
    void p(Object o) {
      print(o);
      out.writeln(o);
    }

    final pref = simPreference();
    final roster = bundle.charactersFor(pref);
    final chars = roster.map((c) => c.id).toList();
    final targets = chars; // 히든 포함 선호 쪽 전원 순환
    final hiddenId = roster.where((c) => c.hidden).map((c) => c.id).firstOrNull;
    final strategies = <String, Strategy Function(int seed)>{
      'first': (_) => FirstStrategy(),
      'maxAff': (_) => MaxAffectionStrategy(),
      'focus': (seed) => FocusStrategy(targets[seed % targets.length]),
      'random': (_) => RandomStrategy(),
      'statGrow': (_) => StatGrowthStrategy(),
      'focus+hint': (seed) =>
          FocusStrategy(targets[seed % targets.length], useHint: true),
      'avoidant': (_) => AvoidantStrategy(),
      'wallflower': (_) => WallflowerStrategy(),
      'toxic': (seed) => ToxicStrategy(targets[seed % targets.length]),
      'worst': (_) => ChaoticStrategy(),
      'doubleTimer': (seed) => DoubleTimerStrategy(
        chars[seed % chars.length],
        chars[(seed + 2) % chars.length],
      ),
    };

    final all = <RunResult>[];
    final csv = StringBuffer(
      'strategy,seed,target,ending,tier,endDay,album,events,emptyDays,crisisDays,'
      '${Stat.all.join(',')},${chars.map((c) => 'aff_$c').join(',')},${chars.map((c) => 'trust_$c').join(',')}\n',
    );
    for (final entry in strategies.entries) {
      for (var seed = 1; seed <= kSeeds; seed++) {
        final res = simulate(bundle, entry.value(seed), seed);
        all.add(res);
        csv.writeln(
          [
            res.strategy,
            res.seed,
            res.target ?? '',
            res.ending,
            res.tier,
            res.endDay,
            res.album,
            res.eventsTotal,
            res.emptyDays,
            res.crisisDays,
            ...Stat.all.map((k) => res.stats[k]),
            ...chars.map((c) => res.aff[c]),
            ...chars.map((c) => res.trust[c]),
          ].join(','),
        );
      }
    }

    final byStrat = <String, List<RunResult>>{};
    for (final r in all) {
      byStrat.putIfAbsent(r.strategy, () => []).add(r);
    }

    p(
      '=== 시뮬레이션: 선호 $pref(${chars.join(' ')}), 시드 $kSeeds × 전략 ${byStrat.length}종, 미니게임 성공률 ${(kMinigameSuccess * 100).round()}% ===',
    );
    for (final e in byStrat.entries) {
      final rs = e.value;
      final n = rs.length;
      p('\n##### 전략 ${e.key} (n=$n)');
      // (a) 엔딩 분포
      final endCount = <String, int>{};
      final tierCount = <String, int>{};
      for (final r in rs) {
        endCount[r.ending] = (endCount[r.ending] ?? 0) + 1;
        tierCount[r.tier] = (tierCount[r.tier] ?? 0) + 1;
      }
      final sortedEnd = endCount.entries.toList()
        ..sort((a, b) => b.value - a.value);
      p(
        '[a] 엔딩 분포: ${sortedEnd.map((x) => '${x.key} ${x.value}(${pct(x.value, n)})').join(', ')}',
      );
      p(
        '    티어: ${tierCount.entries.map((x) => '${x.key} ${pct(x.value, n)}').join(', ')}',
      );
      p('    평균 종료일 ${Dist(rs.map((r) => r.endDay)).mean.toStringAsFixed(1)}');
      if (e.key.startsWith('focus')) {
        final byT = <String, Map<String, int>>{};
        for (final r in rs) {
          byT.putIfAbsent(r.target!, () => {});
          byT[r.target!]![r.ending] = (byT[r.target!]![r.ending] ?? 0) + 1;
        }
        for (final t in byT.entries) {
          final tn = t.value.values.fold(0, (a, b) => a + b);
          final items = t.value.entries.toList()
            ..sort((a, b) => b.value - a.value);
          p(
            '    대상 ${t.key} (n=$tn): ${items.map((x) => '${x.key} ${x.value}').join(', ')}',
          );
        }
      }
      // (c) 호감·신뢰
      p('[c] 최종 호감/신뢰');
      for (final c in chars) {
        final a = Dist(rs.map((r) => r.aff[c]!));
        final t = Dist(rs.map((r) => r.trust[c]!));
        p('    $c 호감 ${a.summary} | ${a.hist([0, 20, 40, 60, 80])}');
        p('    $c 신뢰 ${t.summary} | ${t.hist([0, 30, 50, 70])}');
      }
      final bestAff = Dist(rs.map((r) => r.aff.values.reduce(max)));
      final bestTrust = Dist(rs.map((r) => r.trust.values.reduce(max)));
      p('    최고 호감 ${bestAff.summary} | ${bestAff.hist([0, 20, 40, 60, 80])}');
      p('    최고 신뢰 ${bestTrust.summary} | ${bestTrust.hist([0, 30, 50, 70])}');
      // 해피 조건 부분 충족
      final aff80 = rs.where((r) => r.aff.values.any((v) => v >= 80)).length;
      final tr70 = rs.where((r) => r.trust.values.any((v) => v >= 70)).length;
      final both = rs
          .where((r) => chars.any((c) => r.aff[c]! >= 80 && r.trust[c]! >= 70))
          .length;
      final sinc50 = rs.where((r) => r.stats[Stat.sincerity]! >= 50).length;
      for (final d in [3, 10, 20]) {
        final top = Dist(
          rs
              .where((r) => r.topAffAfter[d] != null)
              .map((r) => r.topAffAfter[d]!),
        );
        final tgt = rs
            .where((r) => r.targetAffAfter[d] != null)
            .map<num>((r) => r.targetAffAfter[d]!);
        p(
          '    [early] D$d 마감 최고 호감 ${top.summary}'
          '${tgt.isEmpty ? '' : ' | 대상 호감 ${Dist(tgt).summary}'} | 15~25 ${pct(top.xs.where((x) => x >= 15 && x <= 25).length, top.xs.length)}',
        );
      }
      p(
        '    누군가 호감≥80: ${pct(aff80, n)} · 신뢰≥70: ${pct(tr70, n)} · 같은 사람 둘 다: ${pct(both, n)} · 진정성≥50: ${pct(sinc50, n)}',
      );
      // (d) 스탯
      p('[d] 최종 스탯');
      for (final k in Stat.all) {
        p('    ${Stat.label(k)} ${Dist(rs.map((r) => r.stats[k]!)).summary}');
      }
      // (e) 잠긴 선택지
      final seen = rs.fold(0, (a, r) => a + r.lockedSeen);
      final open = rs.fold(0, (a, r) => a + r.lockedOpen);
      p(
        '[e] require 선택지 조우 ${(seen / n).toStringAsFixed(1)}회/회차, 열린 비율 ${pct(open, seen)}, 전부 잠긴 이벤트(소프트락) ${rs.fold(0, (a, r) => a + r.stuckEvents)}건',
      );
      // (f) 이벤트 수
      final evPerDay = Dist(rs.map((r) => r.eventsTotal / r.daysPlayed));
      p(
        '[f] 하루 평균 이벤트 ${evPerDay.summary}; 빈 날 평균 ${Dist(rs.map((r) => r.emptyDays)).mean.toStringAsFixed(2)}; 일상 후보 0인 날 평균 ${Dist(rs.map((r) => r.daysWithNoDailyCandidate)).mean.toStringAsFixed(1)}; 일상 고갈 첫날 ${Dist(rs.where((r) => r.dailyExhaustDay != null).map((r) => r.dailyExhaustDay!)).summary} (고갈 발생 ${pct(rs.where((r) => r.dailyExhaustDay != null).length, n)})',
      );
      p(
        '    일상 중 반복(once:false) 비율 ${pct(rs.fold(0, (a, r) => a + r.dailyRepeatPicked), rs.fold(0, (a, r) => a + r.dailyPicked))}; 읽씹 대기 줄 ${Dist(rs.map((r) => r.waitLines)).mean.toStringAsFixed(1)}회/회차; 히든 ${Dist(rs.map((r) => r.hiddenSeen)).mean.toStringAsFixed(2)}회/회차',
      );
      final routeTot = <String, num>{
        for (final c in chars)
          c: Dist(rs.map((r) => r.routeByChar[c] ?? 0)).mean,
      };
      p(
        '    루트 이벤트/회차: ${routeTot.entries.map((x) => '${x.key} ${x.value.toStringAsFixed(1)}').join(', ')} (합 ${routeTot.values.reduce((a, b) => a + b).toStringAsFixed(1)})',
      );
      // (g) 흑역사
      final alb = Dist(rs.map((r) => r.album));
      p('[g] 흑역사 ${alb.summary} | ${alb.hist([0, 5, 10, 20])}');
      // (h)(i)
      p(
        '[h] 진정성 0 즉시 종료(pickup_fall) ${pct(endCount['pickup_fall'] ?? 0, n)}; 진정성 최종 ${Dist(rs.map((r) => r.stats[Stat.sincerity]!)).summary}',
      );
      p(
        '[i] 번아웃 엔딩 ${pct(endCount['burnout'] ?? 0, n)}; c_burnout 발생 ${Dist(rs.map((r) => r.burnoutEvents)).mean.toStringAsFixed(2)}회/회차; 스트레스 max ${Dist(rs.map((r) => r.stressMax)).summary}; 스트레스≥70 일수 ${Dist(rs.map((r) => r.stressHighDays)).mean.toStringAsFixed(1)}',
      );
      final cid = <String, int>{};
      for (final r in rs) {
        r.crisisIds.forEach((k, v) => cid[k] = (cid[k] ?? 0) + v);
      }
      final cidSorted = cid.entries.toList()..sort((a, b) => b.value - a.value);
      p(
        '    위기 일수 ${Dist(rs.map((r) => r.crisisDays)).mean.toStringAsFixed(1)}/회차; 위기별 총발생: ${cidSorted.map((x) => '${x.key} ${x.value}').join(', ')}',
      );
      p(
        '    미니게임 ${Dist(rs.map((r) => r.minigamePlays)).mean.toStringAsFixed(1)}판/회차, 확률실패 ${Dist(rs.map((r) => r.chanceFails)).mean.toStringAsFixed(1)}, 크리티컬 ${Dist(rs.map((r) => r.crits)).mean.toStringAsFixed(1)}, 물오름 중 선택 ${Dist(rs.map((r) => r.onFireChoices)).mean.toStringAsFixed(1)}',
      );
      final flagCount = <String, int>{};
      for (final r in rs) {
        for (final f in r.flags) {
          flagCount[f] = (flagCount[f] ?? 0) + 1;
        }
      }
      final fs = flagCount.entries.toList()..sort((a, b) => b.value - a.value);
      p(
        '    플래그 상위: ${fs.take(14).map((x) => '${x.key} ${pct(x.value, n)}').join(', ')}',
      );
      // 추가 지표
      final gl = <String, num>{};
      for (final r in rs) {
        r.gainByLayer.forEach((k, v) => gl[k] = (gl[k] ?? 0) + v);
      }
      final ll = <String, num>{};
      for (final r in rs) {
        r.lossByLayer.forEach((k, v) => ll[k] = (ll[k] ?? 0) + v);
      }
      p(
        '[j] 호감 공급(전 캐릭터 합, 회차 평균): 증가 ${gl.entries.map((x) => '${x.key} ${(x.value / n).toStringAsFixed(0)}').join(', ')} | 감소 ${ll.entries.map((x) => '${x.key} ${(x.value / n).toStringAsFixed(0)}').join(', ')} | 일일 -1 감소 합 ${Dist(rs.map((r) => r.decayTotal)).mean.toStringAsFixed(0)}',
      );
      String fd(String k) {
        final xs = rs
            .where((r) => r.firstDay[k] != null)
            .map((r) => r.firstDay[k]!);
        return xs.isEmpty
            ? '$k 없음'
            : '$k ${Dist(xs).q(0.5)}일(med) ${pct(xs.length, n)}';
      }

      p(
        '[k] 최초 도달일: ${['core60', 'anyStat100', 'allStat100', 'aff80', 'trust70', 'sinc100'].map(fd).join(' · ')}',
      );
      for (final d in [10, 20, 40, 60, 80, 100]) {
        final st =
            [
                  Stat.charm,
                  Stat.talk,
                  Stat.esteem,
                  Stat.sense,
                  Stat.money,
                  Stat.stress,
                  Stat.sincerity,
                ]
                .map(
                  (k) =>
                      '${Stat.label(k)} ${Dist(rs.where((r) => r.statAt[d] != null).map((r) => r.statAt[d]![k]!)).mean.toStringAsFixed(0)}',
                )
                .join(' ');
        p(
          '    D$d 스탯 평균: $st | once 일상 미열람 ${Dist(rs.where((r) => r.onceDailyUnseenAt[d] != null).map((r) => r.onceDailyUnseenAt[d]!)).mean.toStringAsFixed(1)}/56, 그날 once 후보 ${Dist(rs.where((r) => r.onceDailyAvailAt[d] != null).map((r) => r.onceDailyAvailAt[d]!)).mean.toStringAsFixed(1)}',
        );
      }
      p(
        '[l] 챕터별 require 열린 비율: ${List.generate(5, (i) => '${i + 1}장 ${pct(rs.fold(0, (a, r) => a + r.lockOpenByCh[i]), rs.fold(0, (a, r) => a + r.lockSeenByCh[i]))}').join(', ')}',
      );
      p(
        '[m] 추정 플레이 시간: 회차 ${Dist(rs.map((r) => r.estSeconds / 60)).mean.toStringAsFixed(0)}분, 하루 ${Dist(rs.map((r) => r.estSeconds / r.daysPlayed)).summary}초 (읽씹 대기 포함), 대기 제외 하루 ${Dist(rs.map((r) => (r.estSeconds - r.waitLines * 0) / r.daysPlayed)).mean.toStringAsFixed(0)}초',
      );
      final dseen = <String, int>{};
      for (final r in rs) {
        for (final id in r.dailySeen) {
          dseen[id] = (dseen[id] ?? 0) + 1;
        }
      }
      final dailyIds = bundle.events
          .where((e) => e.layer == EventLayer.daily)
          .map((e) => e.id);
      final neverDaily = dailyIds
          .where((id) => !dseen.containsKey(id))
          .toList();
      final rareDaily = dailyIds
          .where((id) => dseen.containsKey(id) && dseen[id]! < n * 0.1)
          .toList();
      p(
        '[n] 일상 ${dailyIds.length}개 중 한 번도 안 나온 것 ${neverDaily.length}: ${neverDaily.join(' ')} | 10% 미만 ${rareDaily.length}: ${rareDaily.join(' ')}',
      );
    }

    // 2회차 실험: focus (도윤 포함) run=2
    p('\n##### 2회차(run=2) focus 실험 (n=$kSeeds)');
    final run2 = <RunResult>[];
    for (var seed = 1; seed <= kSeeds; seed++) {
      run2.add(
        simulate(
          bundle,
          FocusStrategy(targets[seed % targets.length]),
          seed,
          run: 2,
        ),
      );
    }
    {
      final ec = <String, int>{};
      for (final r in run2) {
        ec[r.ending] = (ec[r.ending] ?? 0) + 1;
      }
      final items = ec.entries.toList()..sort((a, b) => b.value - a.value);
      p('    엔딩: ${items.map((x) => '${x.key} ${x.value}').join(', ')}');
      final byT = <String, Map<String, int>>{};
      for (final r in run2) {
        byT.putIfAbsent(r.target!, () => {});
        byT[r.target!]![r.ending] = (byT[r.target!]![r.ending] ?? 0) + 1;
      }
      for (final t in byT.entries) {
        final it = t.value.entries.toList()..sort((a, b) => b.value - a.value);
        p(
          '    대상 ${t.key}: ${it.map((x) => '${x.key} ${x.value}').join(', ')}',
        );
      }
      // 히든 캐릭터(트레이너)는 선호 쪽에 있을 때만 본다.
      final h = hiddenId;
      if (h != null) {
        final d = Dist(run2.map((r) => r.aff[h]!));
        final dt = Dist(run2.map((r) => r.trust[h]!));
        p(
          '    히든 $h 호감 ${d.summary} | 신뢰 ${dt.summary} | 히든 이벤트 ${Dist(run2.map((r) => r.hiddenSeen)).mean.toStringAsFixed(2)}회/회차',
        );
        final dd = run2.where((r) => r.target == h).toList();
        p(
          '    $h 집중 시 $h 호감 ${Dist(dd.map((r) => r.aff[h]!)).summary} 신뢰 ${Dist(dd.map((r) => r.trust[h]!)).summary} $h 루트 이벤트 ${Dist(dd.map((r) => r.routeByChar[h] ?? 0)).mean.toStringAsFixed(1)}개',
        );
      } else {
        p(
          '    히든 이벤트 ${Dist(run2.map((r) => r.hiddenSeen)).mean.toStringAsFixed(2)}회/회차 (선호 $pref 쪽에 히든 캐릭터 없음)',
        );
      }
    }
    all.addAll(run2);

    // 3회차(run=3) 실험: legend/loop 은 run≥3 에서만 열리는 히든 엔딩이라 별도로 찔러본다.
    p('\n##### 3회차(run=3) harmonizer/random 실험 (n=$kSeeds 씩)');
    final run3 = <RunResult>[];
    for (var seed = 1; seed <= kSeeds; seed++) {
      run3.add(simulate(bundle, HarmonizerStrategy(), seed, run: 3));
    }
    for (var seed = 1; seed <= kSeeds; seed++) {
      run3.add(simulate(bundle, RandomStrategy(), seed, run: 3));
    }
    {
      final ec = <String, int>{};
      for (final r in run3) {
        ec[r.ending] = (ec[r.ending] ?? 0) + 1;
      }
      final items = ec.entries.toList()..sort((a, b) => b.value - a.value);
      p('    엔딩: ${items.map((x) => '${x.key} ${x.value}').join(', ')}');
    }
    all.addAll(run3);

    // (b) 한 번도 안 나온 엔딩
    final reached = all.map((r) => r.ending).toSet();
    final possible = bundle.endings
        .where((e) => bundle.endingInPreference(e, pref))
        .toList();
    final never = possible
        .where((e) => !reached.contains(e.id))
        .map((e) => '${e.id}(${e.tier})')
        .toList();
    p(
      '\n[b] 전 전략 통틀어 한 번도 안 나온 엔딩 ${never.length}/${possible.length} (선호 $pref 에서 가능한 엔딩 기준): ${never.join(', ')}',
    );
    final leaked = reached
        .where((id) => !possible.any((e) => e.id == id))
        .toList();
    expect(leaked, isEmpty, reason: '선호 $pref 밖 엔딩이 나왔다');
    p('    나온 엔딩: ${reached.join(', ')}');

    final dir = Directory(kOutDir)..createSync(recursive: true);
    File('${dir.path}/sim_balance_report.txt')
        .writeAsStringSync(out.toString());
    File('${dir.path}/sim_balance_runs.csv').writeAsStringSync(csv.toString());
    p('\n저장: ${dir.path}/sim_balance_report.txt, sim_balance_runs.csv');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
