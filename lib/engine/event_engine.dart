import 'dart:math';

import 'conditions.dart';
import 'effects.dart';
import 'models.dart';
import 'story_repository.dart';

/// 선택 하나의 결과.
class ChoiceOutcome {
  final bool success;
  final bool critical;
  final AppliedDelta delta;
  final String? nextEventId;

  /// 이 선택으로 콤보가 어떻게 됐는지. UI 연출에 쓴다.
  final int combo;
  final bool comboBroken;
  final bool comboStarted;

  const ChoiceOutcome({
    required this.success,
    required this.critical,
    required this.delta,
    this.nextEventId,
    this.combo = 0,
    this.comboBroken = false,
    this.comboStarted = false,
  });
}

/// 선택지와 잠금 여부.
class ChoiceView {
  final int index;
  final Choice choice;
  final bool locked;
  final String reason;

  const ChoiceView(this.index, this.choice, this.locked, this.reason);
}

/// 하루 계획, 선택 적용, 하루 마감을 담당하는 순수 로직.
/// UI 나 광고에 의존하지 않으므로 그대로 단위 테스트할 수 있다.
class EventEngine {
  final StoryBundle bundle;

  /// 히든 이벤트가 후보에 있을 때 그날 등장할 확률(%).
  final int hiddenChancePercent;

  /// 하루에 최소 이 개수만큼은 채우려 한다. 모자라면 일상 이벤트를 더 얹는다.
  /// 후보가 없으면 채우지 못할 수도 있다.
  final int minEventsPerDay;

  /// 오프닝(1~[openingDays]일차)에는 하루를 이만큼 채운다.
  /// 첫 세션이 첫인상이라 평소보다 하나 더 보여 준다.
  final int openingMinEventsPerDay;
  final int openingDays;

  EventEngine(
    this.bundle, {
    this.hiddenChancePercent = 30,
    this.minEventsPerDay = 3,
    this.openingMinEventsPerDay = 4,
    this.openingDays = 3,
  });

  /// 오프닝 구간인지. 하루 분량과 루트 선택 규칙이 달라진다.
  bool isOpening(GameState s) => s.day <= openingDays;

  /// 같은 상태·같은 날·같은 용도면 항상 같은 난수. 데일리 시나리오와 테스트용.
  ///
  /// `Object.hash` 는 실행마다 다른 시드를 섞기 때문에 앱을 껐다 켜면 결과가
  /// 달라진다. 저장·복원 뒤에도 같아야 하므로 직접 섞는다.
  Random rng(GameState s, String salt) => Random(stableSeed(s.seed, s.day, salt));

  /// FNV-1a 로 (seed, day, salt) 를 32비트로 섞는다. 플랫폼·실행에 무관하게 같다.
  static int stableSeed(int seed, int day, String salt) {
    var h = 0x811C9DC5;
    void mix(int byte) {
      h ^= byte & 0xff;
      h = (h * 0x01000193) & 0xffffffff;
    }

    for (var i = 0; i < 8; i++) {
      mix(seed >> (8 * i));
    }
    for (var i = 0; i < 4; i++) {
      mix(day >> (8 * i));
    }
    for (final u in salt.codeUnits) {
      mix(u);
      mix(u >> 8);
    }
    return h;
  }

  bool _available(GameState s, StoryEvent e) {
    if (e.once && s.seen.contains(e.id)) return false;
    if (e.day != null && e.day != s.day) return false;
    return e.trigger.matches(s, self: e.character);
  }

  List<StoryEvent> candidates(GameState s, EventLayer layer) =>
      bundle.eventsByLayer[layer]!.where((e) => _available(s, e)).toList();

  StoryEvent? _weightedPick(List<StoryEvent> list, Random r) {
    if (list.isEmpty) return null;
    final total = list.fold<int>(0, (a, e) => a + max(1, e.weight));
    var roll = r.nextInt(total);
    for (final e in list) {
      roll -= max(1, e.weight);
      if (roll < 0) return e;
    }
    return list.last;
  }

  /// 오늘 재생할 이벤트 목록. 순서: 메인 → 위기 또는 일상 → 캐릭터 루트 → 히든.
  List<StoryEvent> planDay(GameState s) {
    final plan = <StoryEvent>[];
    final planned = <String>{};

    void add(StoryEvent? e) {
      if (e != null && planned.add(e.id)) plan.add(e);
    }

    for (final e in candidates(s, EventLayer.main)) {
      add(e);
    }

    final crisis = candidates(s, EventLayer.crisis)..sort((a, b) => b.weight - a.weight);
    if (crisis.isNotEmpty) {
      add(crisis.first);
    } else {
      add(_weightedPick(candidates(s, EventLayer.daily), rng(s, 'daily')));
    }

    add(_pickRoute(s));

    final hidden = candidates(s, EventLayer.hidden);
    if (hidden.isNotEmpty && rng(s, 'hidden').nextInt(100) < hiddenChancePercent) {
      add(_weightedPick(hidden, rng(s, 'hidden-pick')));
    }

    // 하루가 너무 짧으면 하트 하나를 쓴 보람이 없다.
    // 이미 꽉 찬 날은 그대로 두고, 한산한 날에만 일상을 하나 더 얹어
    // 하루 분량을 고르게 맞춘다. 오프닝에는 목표치까지 채운다.
    final opening = isOpening(s);
    final target = opening ? openingMinEventsPerDay : minEventsPerDay;
    final maxFill = opening ? target : 1;
    for (var i = 0; i < maxFill && plan.length < target; i++) {
      final more = candidates(
        s,
        EventLayer.daily,
      ).where((e) => !planned.contains(e.id)).toList();
      final pick = _weightedPick(more, rng(s, 'daily-${i + 2}'));
      if (pick == null) break;
      add(pick);
    }
    return plan;
  }

  /// 호감도가 가장 높은 캐릭터를 우선하되, 후보가 있는 캐릭터 중에서 고른다.
  /// 오프닝(1~[openingDays]일차)에는 호감을 보지 않고 균등하게 고른다.
  StoryEvent? _pickRoute(GameState s) {
    final routes = candidates(s, EventLayer.route);
    if (routes.isEmpty) return null;
    final byChar = <String, List<StoryEvent>>{};
    for (final e in routes) {
      byChar.putIfAbsent(e.character ?? '', () => []).add(e);
    }
    final r = rng(s, 'route');
    final chars = byChar.keys.toList()
      ..sort((a, b) {
        final diff = s.affectionOf(b) - s.affectionOf(a);
        return diff != 0 ? diff : a.compareTo(b);
      });
    // 오프닝에는 호감이 아직 의미가 없다. 첫날 동전 던지기 결과가 며칠씩
    // 같은 캐릭터를 밀어주지 않도록 후보가 있는 캐릭터 중 균등 무작위.
    if (isOpening(s)) {
      final chosen = chars[r.nextInt(chars.length)];
      return _weightedPick(byChar[chosen]!, r);
    }
    // 최상위와 호감도가 같은 캐릭터들 사이에서는 무작위.
    final top = s.affectionOf(chars.first);
    final tied = chars.where((c) => s.affectionOf(c) == top).toList();
    final chosen = tied[r.nextInt(tied.length)];
    return _weightedPick(byChar[chosen]!, r);
  }

  StoryEvent? byId(String id) => bundle.eventById[id];

  List<ChoiceView> choicesFor(GameState s, StoryEvent ev) => [
        for (var i = 0; i < ev.choices.length; i++)
          () {
            final c = ev.choices[i];
            final req = c.require;
            final ok = req == null || req.satisfied(s, self: ev.character);
            return ChoiceView(i, c, !ok, ok ? '' : req.describe());
          }(),
      ];

  /// 크리티컬 확률(%). 기본 5, 눈치 20당 +1, 물오름 상태면 두 배.
  int critChance(GameState s) {
    final base = 5 + s.stat(Stat.sense) ~/ 20;
    return s.onFire ? base * 2 : base;
  }

  /// 확률 판정 보정(%p). 물오름 상태면 +20.
  int chanceBonus(GameState s) => s.onFire ? 20 : 0;

  /// 선택이 '좋은 선택'이었는지. 호감·신뢰가 오르고 아무것도 깎이지 않았을 때.
  bool _isGoodChoice(AppliedDelta d) {
    final up = d.affection.values.any((v) => v > 0) ||
        d.trust.values.any((v) => v > 0) ||
        d.stats.entries.any((e) => e.key != Stat.stress && e.value > 0);
    final down = d.affection.values.any((v) => v < 0) ||
        d.trust.values.any((v) => v < 0) ||
        d.album != null;
    return up && !down;
  }

  /// [forcedSuccess] / [forcedCritical] 가 오면 확률 대신 그 결과를 쓴다.
  /// 미니게임이 있는 선택지는 실력이 성패를 가르므로 여기로 결과가 들어온다.
  ChoiceOutcome applyChoice(
    GameState s,
    StoryEvent ev,
    Choice c, {
    Random? random,
    bool? forcedSuccess,
    bool? forcedCritical,
  }) {
    final r = random ?? rng(s, '${ev.id}:${c.text}');
    s.seen.add(ev.id);
    final self = ev.character;
    if (self != null) s.rel(self).contactedToday = true;

    final chance = c.chance;
    final failed = forcedSuccess != null
        ? !forcedSuccess
        : chance != null && r.nextInt(100) >= (chance + chanceBonus(s)).clamp(0, 100);
    if (failed) {
      final d = applyEffects(s, c.fail, self: self);
      final had = s.combo;
      s.combo = 0;
      return ChoiceOutcome(
        success: false,
        critical: false,
        delta: d,
        nextEventId: c.failNext,
        comboBroken: had >= 3,
      );
    }
    final crit = forcedCritical ?? (r.nextInt(100) < critChance(s));
    final d = applyEffects(s, c.effects, self: self, affectionMultiplier: crit ? 2 : 1);
    final wasOnFire = s.onFire;
    if (_isGoodChoice(d)) {
      s.combo++;
    } else {
      s.combo = 0;
    }
    return ChoiceOutcome(
      success: true,
      critical: crit,
      delta: d,
      nextEventId: c.next,
      combo: s.combo,
      comboBroken: wasOnFire && !s.onFire,
      comboStarted: !wasOnFire && s.onFire,
    );
  }

  /// 럭키 룰렛 칸. 하루에 한 번, 광고로 한 번 더.
  static const rouletteSlots = [
    ('돈이 생겼다', {Stat.money: 40}, '길에서 주운 5만원'),
    ('컨디션 최고', {Stat.stress: -20}, '푹 잤다'),
    ('거울이 좋다', {Stat.charm: 4}, '오늘따라 잘 나왔다'),
    ('말이 잘 통한다', {Stat.talk: 4}, '농담이 세 번 먹혔다'),
    ('눈치가 밝다', {Stat.sense: 4}, '분위기가 읽힌다'),
    ('자신감', {Stat.esteem: 5}, '거울 앞에서 안 피했다'),
    ('꽝', {Stat.stress: 8}, '지하철에서 발을 밟혔다'),
    ('대박', {Stat.charm: 3, Stat.talk: 3, Stat.esteem: 3}, '오늘은 되는 날'),
  ];

  /// 룰렛을 돌린다. 연속 출석 7일이면 '대박' 칸이 두 배로 넓어진다.
  int spinRoulette(GameState s, {Random? random}) {
    final r = random ?? rng(s, 'roulette:${s.rouletteDay}');
    final lucky = s.day % 7 == 0;
    final n = rouletteSlots.length;
    var pick = r.nextInt(lucky ? n + 1 : n);
    if (pick >= n) pick = n - 1;
    return pick;
  }

  AppliedDelta applyRoulette(GameState s, int slot) {
    final e = rouletteSlots[slot];
    return applyEffects(s, Effects(stats: e.$2));
  }

  AppliedDelta applyAction(GameState s, DayAction a) => applyEffects(s, a.effects);

  /// 하루 마감. 접촉 없던 캐릭터 호감도 -1, 스트레스 자연 감소, 날짜 +1.
  void endDay(GameState s, {String? cliffhanger}) {
    for (final r in s.relations.values) {
      if (!r.contactedToday && r.affection > 0) r.affection -= 1;
      r.contactedToday = false;
    }
    s.stats[Stat.stress] = max(0, s.stat(Stat.stress) - 3);
    if (s.flags.contains('burnout')) {
      s.flags.remove('burnout');
      final n = (s.flags.where((f) => f.startsWith('burnout_')).length) + 1;
      s.flags.add('burnout_$n');
      if (n >= 3) s.flags.add('burnout_x3');
    }
    s.lastCliffhanger = cliffhanger;
    s.day += 1;
  }

  bool isFinished(GameState s) => s.day > bundle.config.totalDays;

  // ---- 하트 ----

  /// [nowMs] 기준으로 하트를 회복하고 회복한 개수를 돌려준다.
  /// 회복 주기는 마지막 회복 시각(lastHeartMs)에서 이어지므로 앱을 자주 켜도
  /// 손해가 없다. 가득 차면 타이머를 지금으로 맞춘다. 기기 시계가 뒤로 가서
  /// 경과 시간이 음수면 타이머를 지금부터 다시 센다(하트가 영원히 안 차는 것 방지).
  int regenHearts(GameState s, {required int nowMs}) {
    final cfg = bundle.config;
    if (s.hearts >= cfg.maxHearts) {
      s.lastHeartMs = nowMs;
      return 0;
    }
    final per = heartPeriodMs;
    final elapsed = nowMs - s.lastHeartMs;
    if (elapsed < 0) {
      s.lastHeartMs = nowMs;
      return 0;
    }
    final gained = elapsed ~/ per;
    if (gained <= 0) return 0;
    final add = min(gained, cfg.maxHearts - s.hearts);
    s.hearts += add;
    s.lastHeartMs = s.hearts >= cfg.maxHearts ? nowMs : s.lastHeartMs + gained * per;
    return add;
  }

  int get heartPeriodMs => max(1, bundle.config.heartRegenMinutes) * 60 * 1000;

  /// 다음 하트까지 남은 시간(ms). 가득 차 있으면 0.
  int nextHeartInMs(GameState s, {required int nowMs}) {
    if (s.hearts >= bundle.config.maxHearts) return 0;
    return max(0, s.lastHeartMs + heartPeriodMs - nowMs);
  }
}
