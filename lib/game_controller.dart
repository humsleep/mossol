import 'dart:math';

import 'package:flutter/foundation.dart';

import 'engine/attendance.dart';
import 'engine/effects.dart';
import 'engine/ending_resolver.dart';
import 'engine/event_engine.dart';
import 'engine/meta_service.dart';
import 'engine/models.dart';
import 'engine/save_service.dart';
import 'engine/story_repository.dart';

export 'engine/attendance.dart' show CheckInResult, Attendance;
export 'engine/signals.dart' show RelationShift;

enum Phase { home, action, event, summary, ending }

/// 홈이 세이브를 복원하지 않고도 그릴 수 있게 세이브 파일에서 뽑은 요약.
/// 규격은 docs/HOME_REDESIGN.md §0.2. [GameController.saveSummary] 로 읽는다.
@immutable
class SaveSummary {
  final int run;
  final int day;
  final int totalDays;
  final int chapter;

  /// 어젯밤 예고. 첫날(아직 하루를 안 넘긴 세이브)이면 null.
  final String? lastCliffhanger;

  /// 지금 시각 기준으로 회복까지 반영한 하트.
  final int hearts;

  /// 호감 최고 캐릭터. 전원 0 이면 null. 동점이면 characters.json 순서.
  final String? topCharacterId;
  final int topAffection;

  /// 최애의 서사 신호 한 줄(signals.json). 호감 0 이거나 데이터가 없으면 null.
  /// 같은 세이브·같은 날이면 몇 번을 그려도 같은 문장이다.
  final String? topSignal;

  /// 캐릭터 id → 호감. [affectionOf] 로 읽는다.
  final Map<String, int> affection;

  const SaveSummary({
    required this.run,
    required this.day,
    required this.totalDays,
    required this.chapter,
    required this.lastCliffhanger,
    required this.hearts,
    required this.topCharacterId,
    required this.topAffection,
    this.topSignal,
    required this.affection,
  });

  factory SaveSummary.fromState(
    GameState s,
    GameConfig config,
    List<CharacterDef> characters, {
    SignalBook signals = SignalBook.empty,
  }) {
    String? best;
    var bestAff = 0;
    final aff = <String, int>{};
    for (final c in characters) {
      final a = s.affectionOf(c.id);
      aff[c.id] = a;
      if (a > bestAff) {
        bestAff = a;
        best = c.id;
      }
    }
    return SaveSummary(
      run: s.run,
      day: s.day,
      totalDays: config.totalDays,
      chapter: s.chapter(config),
      lastCliffhanger: s.lastCliffhanger,
      hearts: s.hearts,
      topCharacterId: best,
      topAffection: bestAff,
      topSignal: best == null
          ? null
          : signals.signalFor(best, bestAff, seed: s.seed, day: s.day),
      affection: Map.unmodifiable(aff),
    );
  }

  int affectionOf(String id) => affection[id] ?? 0;
}

/// 화면 흐름과 게임 상태를 잇는 컨트롤러. 광고 호출은 화면에서 하고,
/// 여기서는 보상 적용(하트 충전, 되돌리기, 힌트)만 담당한다.
class GameController extends ChangeNotifier {
  final StoryBundle bundle;
  final SaveService save;
  final MetaService metaService;
  late final EventEngine engine = EventEngine(bundle);
  late final EndingResolver resolver = EndingResolver(bundle.endings);

  /// 현재 시각(ms). 테스트에서 시계를 고정할 때 바꿔 끼운다.
  final int Function() nowMs;

  GameController({
    required this.bundle,
    required this.save,
    MetaService? meta,
    int Function()? clock,
  }) : metaService = meta ?? MetaService(),
       nowMs = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  Phase phase = Phase.home;
  GameState? state;
  bool hasSave = false;
  List<String> endingAlbum = [];

  /// 홈이 읽는 세이브 요약. 세이브가 없으면 null. [init] 에서 파일만 읽어 채우고,
  /// [goHome] 과 홈에서 일어나는 저장(출석·하트) 뒤에 다시 만든다.
  /// [state] 는 여전히 [continueGame] 때 복원한다 — 홈에서 `state == null` 인 의미는 그대로.
  SaveSummary? saveSummary;

  /// [init] 에서 읽어 둔 세이브. [state] 로 승격하지 않고 요약과 하트 회복 계산에만 쓴다.
  GameState? _peek;

  /// 회차를 넘어 유지되는 기록. [init] 에서 읽는다. 그 전에는 null.
  PlayerMeta? meta;

  /// 이번 회차 시작 때 받은 회차 간 보너스. 새 회차 화면에서 보여 준다.
  Map<String, int> runBonus = const {};

  final List<StoryEvent> _queue = [];
  StoryEvent? current;
  int revealed = 0;
  ChoiceOutcome? lastOutcome;
  Choice? _lastChoice;

  /// 방금 선택에 대한 상대의 반응 줄. 결과가 없으면 빈 목록.
  List<Line> get lastReply {
    final o = lastOutcome;
    final ch = _lastChoice;
    if (o == null || ch == null) return const [];
    return ch.replyFor(success: o.success, critical: o.critical);
  }

  /// 방금 끝난 미니게임의 한 줄 결과. 결과 패널에 같이 보여 준다.
  String? minigameNote;
  int? hintIndex;
  Ending? ending;

  /// 하루 동안 쌓인 변화. 정산 화면에서 보여 준다.
  final AppliedDelta dayDelta = AppliedDelta();

  /// 오늘 호감 구간을 넘은 캐릭터들(정산의 "관계 변화" 카드).
  ///
  /// 하루 시작 때 호감은 `지금 - dayDelta.affection` 으로 되짚는다. [dayDelta] 는
  /// 실제 적용된 변화량만 쌓고 되돌리기 때 함께 복원되므로 따로 스냅샷을 두지 않는다.
  /// 오른 쪽이 먼저(새 구간이 높은 순, 같으면 많이 오른 순), 내려간 쪽이 뒤.
  /// 신호 데이터가 없으면 빈 목록. 화면은 앞에서 [maxShiftCards] 장만 쓴다.
  List<RelationShift> get todayShifts {
    final s = state;
    if (s == null || bundle.signals.isEmpty) return const [];
    final out = <RelationShift>[];
    for (final ch in bundle.characters) {
      final now = s.affectionOf(ch.id);
      final before = now - (dayDelta.affection[ch.id] ?? 0);
      final shift = bundle.signals.shiftFor(
        ch.id,
        before,
        now,
        seed: s.seed,
        day: s.day,
      );
      // 0 → 첫 구간은 "처음 알게 됨" 이라 카드를 띄우지 않는다. 1일차에 매번 두 장이
      // 뜨면 진짜 "가까워졌다" 의 무게가 떨어진다. 한 번에 두 구간 이상 뛰면 보여 준다.
      if (shift == null || (before <= 0 && shift.toBand == 0)) continue;
      out.add(shift);
    }
    out.sort((a, b) {
      if (a.up != b.up) return a.up ? -1 : 1;
      if (a.up) {
        final band = b.toBand - a.toBand;
        if (band != 0) return band;
        return (b.to - b.from) - (a.to - a.from);
      }
      return (a.to - a.from) - (b.to - b.from);
    });
    return out;
  }

  /// 정산에 띄우는 관계 변화 카드 최대 수.
  static const maxShiftCards = 2;
  String? cliffhanger;

  /// 되돌리기용 스냅샷. 선택 직전 상태와 그 시점의 하루 합계.
  Map<String, dynamic>? _undoSnapshot;
  AppliedDelta? _undoDayDelta;
  bool undoUsedThisEvent = false;

  /// 오늘 아직 볼 이벤트 id. 테스트·디버그용 읽기 전용 뷰.
  List<String> get queuedEventIds => [for (final e in _queue) e.id];

  /// 오늘 룰렛 결과. null 이면 아직 안 돌렸다.
  int? rouletteSlot;
  bool rouletteRerolled = false;

  bool get canSpinRoulette => state != null && state!.rouletteDay != state!.day;
  bool get canRerollRoulette => rouletteSlot != null && !rouletteRerolled;

  /// 하루 시작 전 럭키 룰렛. 결과 칸 번호를 돌려준다.
  /// 오늘 이미 돌렸으면 효과를 다시 주지 않고 그 결과만 돌려준다.
  int spinRoulette() {
    final s = state!;
    if (!canSpinRoulette) {
      final prev = rouletteSlot;
      if (prev == null) throw StateError('오늘 룰렛은 이미 돌렸다 (${s.day}일)');
      return prev;
    }
    final slot = engine.spinRoulette(s);
    s.rouletteDay = s.day;
    rouletteSlot = slot;
    rouletteRerolled = false;
    dayDelta.merge(engine.applyRoulette(s, slot));
    save.save(s);
    notifyListeners();
    return slot;
  }

  /// 리워드 광고 보상: 룰렛 한 번 더. 이전 결과는 취소하지 않고 덧붙인다.
  int rerollRoulette() {
    final s = state!;
    if (!canRerollRoulette) {
      final prev = rouletteSlot;
      if (prev == null) throw StateError('룰렛을 먼저 돌려야 한다');
      return prev;
    }
    final slot = engine.spinRoulette(s, random: Random(s.seed ^ s.day ^ 991));
    rouletteSlot = slot;
    rouletteRerolled = true;
    dayDelta.merge(engine.applyRoulette(s, slot));
    save.save(s);
    notifyListeners();
    return slot;
  }

  GameConfig get config => bundle.config;

  Future<void> init() async {
    hasSave = await save.exists();
    endingAlbum = await save.loadEndings();
    final m = await metaService.load();
    if (m.firstLaunchMs <= 0) {
      m.firstLaunchMs = nowMs();
      await metaService.save(m);
    }
    meta = m;
    // 세이브가 있으면 파일만 읽어 요약을 만든다. 상태 복원은 여전히 continueGame 의 몫.
    _peek = hasSave ? await save.load() : null;
    if (_peek != null) engine.regenHearts(_peek!, nowMs: nowMs());
    _syncSummary();
    notifyListeners();
  }

  /// [saveSummary] 를 지금 상태로 다시 만든다. 세이브가 없으면 null.
  void _syncSummary() {
    final s = hasSave ? (state ?? _peek) : null;
    saveSummary = s == null
        ? null
        : SaveSummary.fromState(
            s,
            config,
            bundle.characters,
            signals: bundle.signals,
          );
  }

  /// 설정의 "저장 데이터 초기화". 회차·앨범·메타를 전부 지우고 첫 실행 상태로 돌린다.
  Future<void> resetAllData() async {
    await save.clear();
    await save.clearEndings();
    await metaService.clear();
    final m = PlayerMeta(firstLaunchMs: nowMs());
    await metaService.save(m);
    meta = m;
    state = null;
    _peek = null;
    hasSave = false;
    endingAlbum = [];
    ending = null;
    runBonus = const {};
    _resetDay();
    _syncSummary();
    notifyListeners();
  }

  DateTime get _now => DateTime.fromMillisecondsSinceEpoch(nowMs());

  // ---- 출석·메타 ----

  /// 앱 실행·홈 진입 때 부른다. 오늘 첫 출석이면 연속 일수를 갱신하고 보상을 준다.
  /// 세이브가 있으면 하트를 바로 얹고, 없으면 메타에 보류해 뒀다가 다음
  /// [newGame]/[continueGame] 에서 얹는다. [init] 전에 부르면 null.
  Future<CheckInResult?> checkInToday() async {
    final m = meta;
    if (m == null) return null;
    final r = Attendance.checkIn(m, _now);
    if (!r.first) return r;
    // 엔딩 직후처럼 state 는 남았지만 세이브가 지워진 경우에 저장하면 끝난 회차가
    // 되살아난다. 세이브가 살아 있을 때만 바로 얹는다. 상태 복원 전(홈 첫 프레임)은
    // 보류함에 넣고 continueGame 이 얹는다.
    final s = hasSave ? state : null;
    var granted = 0;
    if (s != null) {
      granted = Attendance.grantHearts(s, r.heartsGranted, config.maxHearts);
      await save.save(s);
    }
    // 세이브가 없거나 상한에 걸려 못 얹은 몫은 보관해 뒀다가 다음에 얹는다.
    _bankHearts(m, r.heartsGranted - granted);
    await metaService.save(m);
    _syncSummary();
    notifyListeners();
    return r;
  }

  /// 출석 하트 보관함. 상한은 세이브의 하트 상한과 같다(최대치 두 배).
  void _bankHearts(PlayerMeta m, int n) {
    if (n <= 0) return;
    m.pendingHearts = min(
      Attendance.heartCeiling(config.maxHearts),
      m.pendingHearts + n,
    );
  }

  /// 연속 출석 일수. 마지막 출석이 오늘·어제가 아니면 0.
  int get streakDays => meta == null ? 0 : Attendance.liveStreak(meta!, _now);

  bool get checkedInToday =>
      meta != null && Attendance.checkedInOn(meta!, _now);

  int get bestStreak => meta?.bestStreak ?? 0;
  int get totalRuns => meta?.totalRuns ?? 0;
  int get bestDayReached => meta?.bestDayReached ?? 0;

  /// 아직 세이브에 얹히지 않은 출석 하트. 세이브 없이 출석했을 때만 0 보다 크다.
  int get pendingHearts => meta?.pendingHearts ?? 0;

  /// 룰렛 무료 재도전권 (7일 연속 출석 보상).
  int get rerollTickets => meta?.rerollTickets ?? 0;
  bool get canUseRerollTicket => rerollTickets > 0 && canRerollRoulette;

  /// 재도전권으로 룰렛을 한 번 더 돌린다. 광고 없이 [rerollRoulette] 과 같다.
  Future<int> useRerollTicket() async {
    final m = meta;
    if (m == null || !canUseRerollTicket) throw StateError('쓸 수 있는 재도전권이 없다');
    final slot = rerollRoulette();
    m.rerollTickets -= 1;
    await metaService.save(m);
    notifyListeners();
    return slot;
  }

  /// 보류 중인 출석 하트를 세이브에 얹는다. 회차 시작·복원 직후에 부른다.
  Future<void> _applyPendingHearts(GameState s) async {
    final m = meta;
    if (m == null || m.pendingHearts <= 0) return;
    m.pendingHearts -= Attendance.grantHearts(
      s,
      m.pendingHearts,
      config.maxHearts,
    );
    await metaService.save(m);
  }

  Future<void> _recordBestDay(int day) async {
    final m = meta;
    if (m == null) return;
    final d = min(day, config.totalDays);
    if (d <= m.bestDayReached) return;
    m.bestDayReached = d;
    await metaService.save(m);
  }

  /// 호감도가 가장 높은 캐릭터. 세이브가 없거나 전원 0 이면 null.
  /// 동률이면 characters.json 순서가 앞선 쪽.
  String? get topCharacterId {
    final s = state;
    if (s == null) return null;
    String? best;
    var bestAff = 0;
    for (final c in bundle.characters) {
      final a = s.affectionOf(c.id);
      if (a > bestAff) {
        bestAff = a;
        best = c.id;
      }
    }
    return best;
  }

  int get topAffection => state?.affectionOf(topCharacterId ?? '') ?? 0;

  /// 앨범에 있는 엔딩을 등급(tier)별로 센다. 등급은 endings.json 의 tier 전부를
  /// 키로 가지며 없는 등급은 0.
  Map<String, int> get endingCountsByTier {
    final got = endingAlbum.toSet();
    final out = <String, int>{};
    for (final e in bundle.endings) {
      out.putIfAbsent(e.tier, () => 0);
      if (got.contains(e.id)) out[e.tier] = out[e.tier]! + 1;
    }
    return out;
  }

  /// 등급별 전체 엔딩 수. "행복 2 / 6" 식으로 쓸 때 분모.
  Map<String, int> get endingTotalsByTier {
    final out = <String, int>{};
    for (final e in bundle.endings) {
      out[e.tier] = (out[e.tier] ?? 0) + 1;
    }
    return out;
  }

  /// 아직 못 본 엔딩 중 priority 가 가장 낮은 것 (대체로 가장 쉬운 목표).
  /// 기본(default) 엔딩은 목표가 아니므로 뺀다. 전부 봤으면 null.
  Ending? get nextLockedEndingHint {
    final got = endingAlbum.toSet();
    Ending? best;
    for (final e in bundle.endings) {
      if (e.isDefault || got.contains(e.id)) continue;
      if (best == null || e.priority < best.priority) best = e;
    }
    return best;
  }

  // ---- 회차 시작·복원 ----

  Future<void> newGame({int? seed, int run = 1}) async {
    final s = GameState.fresh(
      config,
      bundle.characters,
      seed: seed ?? Random().nextInt(1 << 31),
      run: run,
      previousEndings: endingAlbum,
      nowMs: nowMs(),
    );
    runBonus = crossRunBonus(endingAlbum.length);
    applyCrossRunBonus(s, runBonus);
    state = s;
    ending = null;
    _resetDay();
    phase = Phase.action;
    final m = meta;
    if (m != null) {
      m.totalRuns += 1;
      await metaService.save(m);
    }
    await _applyPendingHearts(s);
    await save.save(s);
    hasSave = true;
    _peek = null;
    _syncSummary();
    notifyListeners();
  }

  Future<bool> continueGame() async {
    final s = await save.load();
    if (s == null) return false;
    state = s;
    _peek = null;
    runBonus = const {};
    _regenHearts();
    _resetDay();
    phase = Phase.action;
    if (pendingHearts > 0) {
      await _applyPendingHearts(s);
      await save.save(s);
    }
    _syncSummary();
    notifyListeners();
    return true;
  }

  void goHome() {
    phase = Phase.home;
    _syncSummary();
    notifyListeners();
  }

  // ---- 하트 ----

  int get hearts => state?.hearts ?? 0;

  int get combo => state?.combo ?? 0;
  bool get onFire => state?.onFire ?? false;

  void _regenHearts() => engine.regenHearts(state!, nowMs: nowMs());

  /// 홈·행동 화면의 타이머 틱에서 부른다. 시간이 지나 찬 하트를 반영하고,
  /// 하나라도 찼으면 저장한다. 찬 개수를 돌려준다.
  Future<int> refreshHearts() async {
    final s = state;
    if (s == null) {
      // 홈 첫 프레임처럼 상태 복원 전이면 요약 쪽 하트만 따라가게 한다.
      // 저장은 안 한다 — continueGame 이 같은 시계로 다시 계산한다.
      final p = _peek;
      if (p == null) return 0;
      final gained = engine.regenHearts(p, nowMs: nowMs());
      if (gained > 0) {
        _syncSummary();
        notifyListeners();
      }
      return gained;
    }
    final gained = engine.regenHearts(s, nowMs: nowMs());
    if (gained > 0) {
      await save.save(s);
      _syncSummary();
      notifyListeners();
    }
    return gained;
  }

  Duration get nextHeartIn {
    final s = state;
    if (s == null) return Duration.zero;
    return Duration(milliseconds: engine.nextHeartInMs(s, nowMs: nowMs()));
  }

  /// 다음 하트까지 남은 초 (올림). 세이브가 없거나 최대치 이상이면 0.
  /// 0 인데 하트가 안 찼다면 [refreshHearts] 를 부르면 된다.
  int get secondsToNextHeart {
    final s = state ?? _peek;
    if (s == null || s.hearts >= config.maxHearts) return 0;
    final ms = s.lastHeartMs + engine.heartPeriodMs - nowMs();
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  bool get heartsFull {
    final s = state ?? _peek;
    return s != null && s.hearts >= config.maxHearts;
  }

  /// 하루 단위로 쌓이는 것들을 비운다. 새 날이 시작되기 직전(마감 직후)에 부른다.
  /// 룰렛은 아침 행동보다 먼저 돌므로 startDay 에서 비우면 룰렛 결과가 정산에서 빠진다.
  void _resetDay() {
    dayDelta.clear();
    cliffhanger = null;
    rouletteSlot = null;
    rouletteRerolled = false;
    _queue.clear();
    current = null;
    revealed = 0;
    lastOutcome = null;
    minigameNote = null;
    hintIndex = null;
    _undoSnapshot = null;
    _undoDayDelta = null;
    undoUsedThisEvent = false;
  }

  /// 리워드 광고 보상: 하트 1개.
  Future<void> grantHeart() async {
    // 홈(상태 복원 전)에서도 광고 하트를 받을 수 있어야 한다.
    final s = (state ?? _peek)!;
    s.hearts = min(config.maxHearts, s.hearts + 1);
    await save.save(s);
    _syncSummary();
    notifyListeners();
  }

  // ---- 하루 진행 ----

  /// 아침 행동 선택. 하트 1개를 쓰고 그날의 이벤트를 계획한다.
  Future<bool> startDay(DayAction action) async {
    final s = state!;
    _regenHearts();
    if (s.hearts <= 0) {
      notifyListeners();
      return false;
    }
    s.hearts -= 1;
    dayDelta.merge(engine.applyAction(s, action));
    cliffhanger = null;
    _queue
      ..clear()
      ..addAll(engine.planDay(s));
    // 하트를 쓴 시점을 저장한다. 여기서 끊기면 하트만 사라지고 하루는 안 시작된 게 된다.
    await save.save(s);
    _nextEvent();
    return true;
  }

  void _nextEvent() {
    lastOutcome = null;
    minigameNote = null;
    hintIndex = null;
    undoUsedThisEvent = false;
    _undoSnapshot = null;
    _undoDayDelta = null;
    if (_queue.isEmpty) {
      current = null;
      revealed = 0;
      phase = Phase.summary;
      save.save(state!);
    } else {
      current = _queue.removeAt(0);
      revealed = 0;
      phase = Phase.event;
    }
    notifyListeners();
  }

  bool get linesDone => current != null && revealed >= current!.lines.length;

  /// 읽씹 대기를 끝까지 기다렸을 때의 대가. 자존감 1.
  /// 화면에서 상태를 직접 건드리면 하루 합계·되돌리기·세이브에서 빠진다.
  void applyWaitPenalty() {
    final s = state;
    if (s == null) return;
    dayDelta.merge(applyEffects(s, const Effects(stats: {Stat.esteem: -1})));
    save.save(s);
    notifyListeners();
  }

  /// 다음 말풍선 공개. 대기(읽씹) 줄은 화면에서 카운트다운 후 다시 호출한다.
  void revealNext() {
    final c = current;
    if (c == null || linesDone) return;
    revealed++;
    notifyListeners();
  }

  List<ChoiceView> get choices =>
      current == null ? const [] : engine.choicesFor(state!, current!);

  /// [minigameSuccess] 가 오면 확률 대신 미니게임 결과로 성패가 정해진다.
  void choose(
    int index, {
    bool? minigameSuccess,
    bool? minigameCritical,
    String? note,
  }) {
    final s = state!;
    final ev = current!;
    if (index < 0 || index >= ev.choices.length) {
      throw RangeError.index(index, ev.choices, 'index');
    }
    if (!undoUsedThisEvent) {
      _undoSnapshot = s.toJson();
      _undoDayDelta = dayDelta.copy();
    }
    final outcome = engine.applyChoice(
      s,
      ev,
      ev.choices[index],
      forcedSuccess: minigameSuccess,
      forcedCritical: minigameCritical,
    );
    minigameNote = note;
    lastOutcome = outcome;
    _lastChoice = ev.choices[index];
    dayDelta.merge(outcome.delta);
    if (ev.cliffhanger != null) cliffhanger = ev.cliffhanger;
    final next = outcome.nextEventId == null
        ? null
        : engine.byId(outcome.nextEventId!);
    if (next != null) {
      // 오늘 계획에 이미 잡혀 있던 이벤트면 앞으로 당길 뿐 두 번 보여 주지 않는다.
      _queue.removeWhere((e) => e.id == next.id);
      _queue.insert(0, next);
    }
    // 선택은 되돌릴 수 없는 진행이다. 여기서 끊겨도 결과가 남아야 한다.
    save.save(s);
    notifyListeners();
  }

  /// 선택 결과가 나쁠 때 되돌리기 제안 여부. 호감도가 떨어졌고 아직 안 썼을 때.
  bool get canOfferUndo {
    final s = state;
    if (s == null) return false;
    final o = lastOutcome;
    if (o == null || undoUsedThisEvent || _undoSnapshot == null) return false;
    // 하드코어는 되돌리기를 포기하는 대신 보너스를 받는 선언이다.
    // 이걸 막지 않으면 스탯만 공짜로 챙기고 히든 엔딩 조건까지 열린다.
    if (s.flags.contains('hardcore')) return false;
    return o.delta.affection.values.any((v) => v < 0) || !o.success;
  }

  /// 리워드 광고 보상: 선택 직전으로 되돌린다.
  /// 한 이벤트에 한 번만. 선택으로 바뀐 것(스탯·관계·플래그·본 목록·앨범·콤보)과
  /// 하루 합계를 선택 직전으로 되돌리고, 그 선택이 끼워 넣은 다음 이벤트를 큐에서 뺀다.
  void undoChoice() {
    final snap = _undoSnapshot;
    final dayBefore = _undoDayDelta;
    if (snap == null || dayBefore == null || undoUsedThisEvent) return;
    final restored = GameState.fromJson(snap);
    final s = state!;
    s
      ..stats.clear()
      ..stats.addAll(restored.stats)
      ..relations.clear()
      ..relations.addAll(restored.relations)
      ..flags.clear()
      ..flags.addAll(restored.flags)
      ..seen.clear()
      ..seen.addAll(restored.seen)
      ..album.clear()
      ..album.addAll(restored.album)
      ..combo = restored.combo;
    dayDelta
      ..clear()
      ..merge(dayBefore);
    final o = lastOutcome;
    if (o?.nextEventId != null &&
        _queue.isNotEmpty &&
        _queue.first.id == o!.nextEventId) {
      _queue.removeAt(0);
    }
    lastOutcome = null;
    minigameNote = null;
    undoUsedThisEvent = true;
    _undoSnapshot = null;
    _undoDayDelta = null;
    notifyListeners();
  }

  /// 리워드 광고 보상: 정답 선택지 표시.
  void revealHint() {
    hintIndex = current?.hint;
    notifyListeners();
  }

  /// 선택 결과 확인 후 다음 이벤트로.
  void continueAfterChoice() => _nextEvent();

  /// 정산 화면에서 "다음 날".
  Future<void> endDay() async {
    final s = state!;
    engine.endDay(s, cliffhanger: cliffhanger);
    _resetDay();
    await _recordBestDay(s.day);
    final imm = resolver.immediate(s);
    if (imm != null) {
      await _finish(imm);
      return;
    }
    if (engine.isFinished(s)) {
      await _finish(resolver.resolve(s));
      return;
    }
    phase = Phase.action;
    await save.save(s);
    notifyListeners();
  }

  Future<void> _finish(Ending e) async {
    ending = e;
    await _recordBestDay(state?.day ?? 0);
    await save.addEnding(e.id);
    endingAlbum = await save.loadEndings();
    await save.clear();
    hasSave = false;
    _peek = null;
    _syncSummary();
    phase = Phase.ending;
    notifyListeners();
  }

  /// 엔딩 후 다음 회차. run 이 올라가 히든 조건이 열린다.
  Future<void> nextRun() async {
    final prevRun = state?.run ?? 1;
    await newGame(run: prevRun + 1);
  }

  String characterName(String? id) =>
      id == null ? '' : (bundle.characterById[id]?.name ?? id);

  CharacterDef? characterOf(String? id) =>
      id == null ? null : bundle.characterById[id];
}
