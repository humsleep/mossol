import 'dart:math';

import 'package:flutter/foundation.dart';

import 'engine/effects.dart';
import 'engine/ending_resolver.dart';
import 'engine/event_engine.dart';
import 'engine/models.dart';
import 'engine/save_service.dart';
import 'engine/story_repository.dart';

enum Phase { home, action, event, summary, ending }

/// 화면 흐름과 게임 상태를 잇는 컨트롤러. 광고 호출은 화면에서 하고,
/// 여기서는 보상 적용(하트 충전, 되돌리기, 힌트)만 담당한다.
class GameController extends ChangeNotifier {
  final StoryBundle bundle;
  final SaveService save;
  late final EventEngine engine = EventEngine(bundle);
  late final EndingResolver resolver = EndingResolver(bundle.endings);

  /// 현재 시각(ms). 테스트에서 시계를 고정할 때 바꿔 끼운다.
  final int Function() nowMs;

  GameController({
    required this.bundle,
    required this.save,
    int Function()? clock,
  }) : nowMs = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  Phase phase = Phase.home;
  GameState? state;
  bool hasSave = false;
  List<String> endingAlbum = [];

  final List<StoryEvent> _queue = [];
  StoryEvent? current;
  int revealed = 0;
  ChoiceOutcome? lastOutcome;

  /// 방금 끝난 미니게임의 한 줄 결과. 결과 패널에 같이 보여 준다.
  String? minigameNote;
  int? hintIndex;
  Ending? ending;

  /// 하루 동안 쌓인 변화. 정산 화면에서 보여 준다.
  final AppliedDelta dayDelta = AppliedDelta();
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
    notifyListeners();
  }

  // ---- 회차 시작·복원 ----

  Future<void> newGame({int? seed, int run = 1}) async {
    state = GameState.fresh(
      config,
      bundle.characters,
      seed: seed ?? Random().nextInt(1 << 31),
      run: run,
      previousEndings: endingAlbum,
      nowMs: nowMs(),
    );
    ending = null;
    _resetDay();
    phase = Phase.action;
    await save.save(state!);
    hasSave = true;
    notifyListeners();
  }

  Future<bool> continueGame() async {
    final s = await save.load();
    if (s == null) return false;
    state = s;
    _regenHearts();
    _resetDay();
    phase = Phase.action;
    notifyListeners();
    return true;
  }

  void goHome() {
    phase = Phase.home;
    notifyListeners();
  }

  // ---- 하트 ----

  int get hearts => state?.hearts ?? 0;

  int get combo => state?.combo ?? 0;
  bool get onFire => state?.onFire ?? false;

  void _regenHearts() => engine.regenHearts(state!, nowMs: nowMs());

  Duration get nextHeartIn {
    final s = state;
    if (s == null) return Duration.zero;
    return Duration(milliseconds: engine.nextHeartInMs(s, nowMs: nowMs()));
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
    final s = state!;
    s.hearts = min(config.maxHearts, s.hearts + 1);
    await save.save(s);
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
  void choose(int index, {bool? minigameSuccess, bool? minigameCritical, String? note}) {
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
    dayDelta.merge(outcome.delta);
    if (ev.cliffhanger != null) cliffhanger = ev.cliffhanger;
    final next = outcome.nextEventId == null ? null : engine.byId(outcome.nextEventId!);
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
    if (o?.nextEventId != null && _queue.isNotEmpty && _queue.first.id == o!.nextEventId) {
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
    await save.addEnding(e.id);
    endingAlbum = await save.loadEndings();
    await save.clear();
    hasSave = false;
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
