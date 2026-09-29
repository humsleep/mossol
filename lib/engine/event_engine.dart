import 'dart:math';

import 'conditions.dart';
import 'effects.dart';
import 'mbti.dart';
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
  Random rng(GameState s, String salt) =>
      Random(stableSeed(s.seed, s.day, salt));

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

  /// 이 회차 선호 밖이라 등장하지 않는 캐릭터 id([StoryBundle.absentIds]).
  Set<String> absentFor(GameState s) => bundle.absentIds(s.preference);

  /// 이 회차에 등장하는 캐릭터(characters.json 순).
  List<CharacterDef> rosterFor(GameState s) =>
      bundle.charactersFor(s.preference);

  /// 선호 밖 캐릭터를 뺀 호감 1위. 효과 키 `@top` 과 같은 사람이다.
  String? topCharacter(GameState s) => topCharacterOf(s, absent: absentFor(s));

  /// 대사의 `{top}` 에 넣을 이름. 규칙 전문은 lib/engine/text_template.dart 의 해소 규칙.
  /// 1) 호감 1위([topCharacter], `@top` 효과와 같은 사람) → 2) [event] 가 지목한 캐릭터
  /// → 3) null(= 화면에서는 `그 사람`). characters.json 에 없는 id 는 이름이 없으므로
  /// 다음 단계로 내려간다 — id 를 그대로 화면에 내지 않는다.
  String? topNameFor(GameState s, {StoryEvent? event}) {
    String? nameOf(String? id) {
      if (id == null) return null;
      final n = bundle.characterById[id]?.name.trim();
      return (n == null || n.isEmpty) ? null : n;
    }

    return nameOf(topCharacter(s)) ?? nameOf(event?.character);
  }

  /// 오늘 [e] 를 후보로 올릴 수 있는지. **모든 층이 이 한 곳을 지난다**
  /// ([candidates] → [planDay] 의 main·crisis·route·hidden, [dailyPool] 의 daily,
  /// [openingScriptEvents] 의 1회차 D+1 대본). 그래서 `once` 도 여기 한 줄로 전 층에 걸린다.
  bool _available(GameState s, StoryEvent e) {
    // `once`(기본 true): 한 회차에 한 번. 본 목록은 세이브에 남으므로 앱을 껐다 켜도,
    // 회차를 이어서 해도 다시 나오지 않는다. `once: false` 인 것만 반복될 수 있고,
    // 그것들은 [dailyPool] 의 냉각과 [_weightOf] 의 감쇠가 다시 걸러 낸다.
    if (e.once && s.seen.contains(e.id)) return false;
    if (e.day != null && e.day != s.day) return false;
    final absent = absentFor(s);
    // 선호 밖 캐릭터의 이벤트는 후보가 아니다. `trigger.pref` 는 matches 가 본다.
    if (e.character != null && absent.contains(e.character)) return false;
    return e.trigger.matches(
      s,
      self: e.character,
      selfMbti: mbtiOf(e.character),
      absent: absent,
    );
  }

  // ---- MBTI (docs/MBTI_SPEC.md) ----

  /// 캐릭터 [id] 의 MBTI. 없으면 null.
  String? mbtiOf(String? id) =>
      id == null ? null : bundle.characterById[id]?.mbti;

  /// 이 회차 플레이어와 캐릭터 [id] 의 궁합 점수(0~4). 어느 쪽이든 MBTI 가 없으면 2.
  int compatWith(GameState s, String? id) => Mbti.compat(s.mbti, mbtiOf(id));

  /// [ev] 에서 **말하는 상대**. 줄 조건 `humor`·`register` 가 이 사람을 본다.
  ///
  /// 해소 규칙은 `{top}` 의 이름 규칙([topNameFor])과 **글자 그대로 같다** —
  /// 1) 호감 1위 → 2) 이벤트가 지목한 캐릭터 → 3) null(화면에서는 "그 사람").
  /// 같아야 하는 이유: 말풍선 머리에 "지우" 라고 찍히는데 대사는 다른 사람의 농담 코드로
  /// 골라지면 이 기능이 고치려던 바로 그 어긋남이 자리만 옮긴 것이 된다.
  CharacterDef? voiceOf(GameState s, StoryEvent ev) =>
      bundle.characterById[topCharacter(s)] ??
      bundle.characterById[ev.character];

  /// [ev] 를 볼 시점(플레이어 MBTI + 이벤트 캐릭터와의 궁합 + 상대 목소리).
  MbtiView mbtiView(GameState s, StoryEvent ev) =>
      MbtiView.of(s.mbti, mbtiOf(ev.character), voice: voiceOf(s, ev));

  /// [ev] 를 이 회차 플레이어에게 보이는 줄·선택지만 남긴 사본. 조건이 없으면 원본.
  /// 선택지 인덱스·힌트는 거른 목록 기준이다. `GameController.current` 가 이것이다.
  ///
  /// 변형 대사([StoryEvent.variants])를 먼저 고르고 그 위에 MBTI 조건을 거른다 —
  /// 순서가 반대면 변형 안의 `mbti` 조건 줄이 걸러지지 않는다.
  StoryEvent viewFor(GameState s, StoryEvent ev) =>
      variantOf(s, ev).forMbti(mbtiView(s, ev));

  /// [ev] 를 이 회차에 **몇 번째로 보는지**에 따라 대사 묶음을 고른 사본.
  /// 변형이 없으면 원본 그대로다.
  ///
  /// 규칙은 회전이다. 대사 묶음이 N개(원본 1 + 변형 N−1)일 때
  ///
  ///     보여 줄 묶음 = (회차 시드로 정한 시작점 + 이 회차에 본 횟수) % N
  ///
  /// - **결정적이다.** 시작점은 [stableSeed] 로 (회차 시드, 이벤트 id)에서만 나온다 —
  ///   날짜를 섞지 않으므로 며칠에 보든 같은 회차에서는 같은 순서다. 저장·복원 뒤에도 같다.
  /// - **연속해서 같은 대사가 나오지 않는다.** 무작위로 고르면 두 번째에 또 같은 것이
  ///   나올 수 있는데(변형을 붙인 보람이 사라진다), 회전은 N번째까지 반드시 다 다르다.
  /// - **회차마다 첫 대사가 다르다.** 시작점이 시드에 달려 있어 2회차에 같은 장면을
  ///   만나도 첫인상이 같지 않다.
  /// - 본 횟수는 [GameState.seenCount] 다. 세이브에 변형 때문에 더 적는 것은 없다.
  ///
  /// 화면이 한 장면 도중에 이 값을 다시 계산해도 안전하다 — 본 횟수는 선택을 확정하는
  /// `applyChoice` 에서만 올라가고, 그때 그 장면은 이미 끝난다. `GameController.current`
  /// 는 넣을 때 한 번만 거르므로 화면에 뜬 대사가 도중에 바뀌지 않는다.
  StoryEvent variantOf(GameState s, StoryEvent ev) {
    final i = variantIndexOf(s, ev);
    return i == 0 ? ev : ev.withLines(ev.variants[i - 1]);
  }

  /// [variantOf] 가 고를 대본의 번호(0 = 원본). 회전 공식은 한 군데만 둔다.
  ///
  /// 밖으로 낸 이유: 변형이 붙은 뒤에도 `StoryEvent.id` 는 그대로라, id 로 세는 계측은
  /// **변형을 아예 못 본다.** 재방송 비율이 그 함정에 빠져 있었다(같은 id 를 두 번 읽으면
  /// 대사가 전부 달라도 재방송으로 셌다 — docs/review/13_content_fixes.md).
  /// 그래서 "플레이어가 실제로 다시 읽은 것" 을 세려면 id 가 아니라 `id#번호` 여야 한다.
  int variantIndexOf(GameState s, StoryEvent ev) {
    if (ev.variants.isEmpty) return 0;
    final n = ev.variants.length + 1;
    final start = stableSeed(s.seed, 0, 'variant:${ev.id}') % n;
    return (start + viewsOf(s, ev)) % n;
  }

  /// 캐릭터 [id] 호감이 오를 때 곱할 궁합 배율(config.mbti.compatMultiplier).
  double compatMultiplier(GameState s, String id) =>
      bundle.config.compatMultiplierFor(compatWith(s, id));

  List<StoryEvent> candidates(GameState s, EventLayer layer) =>
      bundle.eventsByLayer[layer]!.where((e) => _available(s, e)).toList();

  /// 일상 [e] 가 아직 냉각 중인지(최근 [GameConfig.dailyCooldownDays]일 안에 봤는지).
  bool inDailyCooldown(GameState s, StoryEvent e) {
    final cool = bundle.config.dailyCooldownDays;
    if (cool <= 0) return false;
    final last = s.dailySeenDay[e.id];
    return last != null && s.day - last < cool;
  }

  /// 오늘 뽑을 수 있는 일상 후보. 최근에 본 일상은 빼되([inDailyCooldown]),
  /// 그러면 후보가 하나도 안 남는 날에는 **원래 후보를 그대로 쓴다** — 냉각 때문에
  /// 하루가 비는 일은 없다(docs/review/07_story_flow.md (c)#8 의 수선).
  /// [exclude] 는 오늘 이미 계획에 들어간 id.
  ///
  /// 행동 장면([isActionScene])은 여기서 뺀다 — 하루 첫 장면 자리([actionScenePool])에서만
  /// 뽑는다. 섞이면 한 날 행동 장면이 둘 나오거나 일상 칸을 행동 장면이 차지한다.
  List<StoryEvent> dailyPool(GameState s, {Set<String> exclude = const {}}) =>
      _cooled(s, [
        for (final e in candidates(s, EventLayer.daily))
          if (!exclude.contains(e.id) && !isActionScene(e)) e,
      ]);

  /// [all] 에서 냉각 중인 것을 뺀다. 그러면 하나도 안 남으면 [all] 그대로.
  List<StoryEvent> _cooled(GameState s, List<StoryEvent> all) {
    final fresh = [
      for (final e in all)
        if (!inDailyCooldown(s, e)) e,
    ];
    return fresh.isEmpty ? all : fresh;
  }

  // ---- 아침 행동과 그날 이야기 ----

  /// 오늘 아침에 고른 행동. 행동을 고르기 전(또는 config 에 없는 id)이면 null.
  DayAction? todayAction(GameState s) {
    final id = s.todayAction;
    if (id == null) return null;
    for (final a in bundle.config.actions) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// 행동 장면(`trigger.action` 이 있는 일상, assets/story/events_action.json).
  /// 오늘 행동과 맞는 것만 후보가 된다(conditions.dart 의 `action` 판정).
  bool isActionScene(StoryEvent e) => e.trigger.action.isNotEmpty;

  /// 오늘 행동으로 열리는 행동 장면 후보. 최근 [GameConfig.dailyCooldownDays]일 안에 본
  /// 장면은 뺀다([inDailyCooldown]).
  ///
  /// [dailyPool] 과 달리 **냉각 때문에 비면 되돌리지 않는다** — 그날은 행동 장면 없이
  /// 평소 하루가 된다. 행동 장면은 하루를 채우는 칸이 아니라 얹는 칸이라, 행동 하나에
  /// 장면이 열 개 안팎뿐인데 같은 행동을 매일 고르면 되돌림이 곧 재방송이 된다
  /// (test/rerun_share_test.dart 의 10% 선). 같은 이유로 반복 장면도 한 회차에
  /// [actionSceneMaxViews]번까지만.
  List<StoryEvent> actionScenePool(GameState s) => [
    for (final e in candidates(s, EventLayer.daily))
      if (isActionScene(e) &&
          !inDailyCooldown(s, e) &&
          viewsOf(s, e) < actionSceneMaxViews)
        e,
  ];

  /// 반복 행동 장면(`once: false`)을 한 회차에 최대 몇 번 보여 줄지.
  static const actionSceneMaxViews = 2;

  /// 형식을 깨는 이벤트(전화·알림·사진)인지. docs/MOMENTS_SPEC.md §2.
  bool isMoment(StoryEvent e) => e.isMoment;

  /// 모먼트 가중치 배율과 적용 시작일.
  static const momentBoost = 3;
  static const momentBoostFromDay = 3;

  /// 모먼트를 이만큼(일) 못 봤으면 가중치를 올린다.
  static const momentGapDays = 2;

  /// 오늘 모먼트 가중치를 올릴지. 오프닝 흐름을 지키려고 [momentBoostFromDay]일차부터.
  bool momentBoostActive(GameState s) =>
      s.day >= momentBoostFromDay && s.day - s.lastMomentDay >= momentGapDays;

  /// 이 회차에 [e] 를 이미 몇 번 봤는지. `once` 이벤트는 두 번 나오지 않으므로 항상 0 —
  /// 세지도 않는다([GameState.seenCount]).
  int viewsOf(GameState s, StoryEvent e) => e.once ? 0 : s.viewsOf(e.id);

  /// 감쇠를 **정수**로 하려고 가중치에 먼저 곱하는 척도.
  ///
  /// 가중치 추첨은 `Random.nextInt` 라 정수여야 하는데, 20% 감쇠를 정수에서 바로 하면
  /// weight 1 이 한 번에 1 로 바닥을 쳐서 '한 번 본 것'과 '다섯 번 본 것'이 같아진다.
  /// 그러면 장면 하나가 6~7번까지 나오는 것을 못 막는다 — 실측에서 가장 크게 체감된 게
  /// 비율보다 이 쪽이었다(`d_drink_02` 7회, docs/review/11_story_verdict.md §4-1).
  /// 4096 이면 20% 감쇠가 4096 → 819 → 163 → 32 → 6 → 1 로 **다섯 번째 시청까지**
  /// 구분되어, 후보가 마른 뒤에도 '적게 본 것'이 먼저 나간다.
  /// 최악의 합계는 3(weight) × 3(모먼트) × 4096 × 후보 100여 개 ≈ 370만으로
  /// `nextInt` 한계(2^32)에서 한참 멀다.
  static const repeatWeightScale = 4096;

  /// 그날 후보 추첨 가중치. 모먼트 보정이 켜져 있으면 모먼트는 [momentBoost]배,
  /// 이미 본 장면은 본 횟수만큼 [GameConfig.repeatWeightPercent] 를 곱한다.
  /// [scale] 은 [_weightedPick] 이 넘기는 정수 척도다.
  /// 오늘 아침 행동([act])과 어울리는 일상([DayAction.affinity])은 [DayAction.affinityBoost]배.
  int _weightOf(
    StoryEvent e,
    bool boost, {
    int views = 0,
    int scale = 1,
    DayAction? act,
  }) {
    var w =
        max(1, e.weight) *
        (boost && isMoment(e) ? momentBoost : 1) *
        (act != null && act.fits(e.id) ? DayAction.affinityBoost : 1) *
        scale;
    if (views <= 0) return w;
    final p = bundle.config.repeatWeightPercent;
    if (p >= 100) return w;
    for (var i = 0; i < views && w > 1; i++) {
      // 1 이 하한이다 — 감쇠만으로 후보가 사라지는 일은 없다(빈 하루 방지).
      w = max(1, w * p ~/ 100);
    }
    return w;
  }

  /// 오늘 [e] 가 추첨에서 갖는 가중치. [_weightedPick] 이 쓰는 값과 같은 척도다
  /// (감쇠가 없는 날에는 [_weightedPick] 이 척도를 곱하지 않지만, 그건 후보 전체에
  /// 같은 배수라 순위·비율에는 영향이 없다). 진단·테스트가 감쇠를 눈으로 확인하는 창구다.
  int pickWeight(GameState s, StoryEvent e, {bool boost = false}) => _weightOf(
    e,
    boost,
    views: viewsOf(s, e),
    scale: repeatWeightScale,
    act: todayAction(s),
  );

  /// 난수는 항상 한 번만 뽑는다. 가중치만 바뀌므로 salt 순서·호출 횟수는 그대로다.
  ///
  /// **후보 전부가 처음 보는 장면인 날에는 척도를 곱하지 않는다.** 곱하면 합계가 64배가
  /// 되어 같은 `nextInt` 값에서 다른 장면이 뽑히고, 감쇠가 할 일이 없는 날까지 기존
  /// 회차·테스트가 통째로 흔들린다. 감쇠는 '이미 본 것을 뒤로 미루는' 장치이므로
  /// 미룰 것이 없으면 아무 일도 하지 않는 게 맞다.
  StoryEvent? _weightedPick(
    GameState s,
    List<StoryEvent> list,
    Random r, {
    bool boost = false,
    DayAction? act,
  }) {
    if (list.isEmpty) return null;
    final views = [for (final e in list) viewsOf(s, e)];
    final scale = views.any((v) => v > 0) ? repeatWeightScale : 1;
    int w(int i) =>
        _weightOf(list[i], boost, views: views[i], scale: scale, act: act);
    var total = 0;
    for (var i = 0; i < list.length; i++) {
      total += w(i);
    }
    var roll = r.nextInt(total);
    for (var i = 0; i < list.length; i++) {
      roll -= w(i);
      if (roll < 0) return list[i];
    }
    return list.last;
  }

  /// 오늘이 오프닝 대본(`config.openingScript`)을 까는 날인지. **1회차 D+1 뿐이다** —
  /// 이어하기·2회차는 평소대로 돈다.
  bool usesOpeningScript(GameState s) =>
      s.run == 1 && s.day == 1 && bundle.config.openingScript.isNotEmpty;

  /// 오프닝 대본에 적힌 이벤트를 적힌 순서대로. 건너뛰는 경우는 둘뿐이다.
  /// - **없는 id**: 데이터가 앞서 나가거나 이벤트 이름이 바뀌어도 앱이 죽지 않게 조용히 넘긴다.
  /// - **오늘 낼 수 없는 이벤트**([_available]): 선호(`pref`)·플래그가 맞지 않는 장면을
  ///   대본이라는 이유로 억지로 틀면 남성 회차에 여성 쪽 장면이 나오는 식으로 깨진다.
  ///   이미 본 이벤트(`next` 로 먼저 본 경우)도 여기서 걸린다.
  List<StoryEvent> openingScriptEvents(GameState s) => [
    for (final id in bundle.config.openingScript)
      if (byId(id) case final e?)
        if (_available(s, e)) e,
  ];

  /// 오늘 재생할 이벤트 목록. 순서: 행동 장면 → 메인 → 위기 또는 일상 → 캐릭터 루트
  /// → 히든 (→ 보충 일상).
  ///
  /// 행동 장면은 아침에 고른 행동([GameState.todayAction])이 여는 장면 **하나**다
  /// ("헬스장" 을 골랐으면 헬스장에서 하루가 시작된다). 오프닝([isOpening])에는
  /// 전제를 세우는 (오프닝 대본 →) 메인이 먼저고 행동 장면이 그 뒤다.
  List<StoryEvent> planDay(GameState s) {
    final plan = <StoryEvent>[];
    final planned = <String>{};
    final boost = momentBoostActive(s);
    final act = todayAction(s);

    void add(StoryEvent? e) {
      if (e != null && planned.add(e.id)) plan.add(e);
    }

    // 행동을 안 골랐으면(null) 후보가 없어 난수도 뽑지 않는다 — 다른 칸의 난수는
    // salt 가 달라 이 줄과 무관하다.
    final scene = act == null
        ? null
        : _weightedPick(s, actionScenePool(s), rng(s, 'action'));
    final opening = isOpening(s);
    if (!opening) add(scene);

    // 전제를 세우는 장면은 추첨에 맡기지 않는다(docs/review/07_story_flow.md (c)#4).
    // 대본이 비어 있으면(기본) 이 줄은 아무 일도 하지 않는다.
    if (usesOpeningScript(s)) {
      for (final e in openingScriptEvents(s)) {
        add(e);
      }
    }

    for (final e in candidates(s, EventLayer.main)) {
      add(e);
    }
    add(scene); // 오프닝 날. 평소에는 이미 맨 앞에 있어 아무 일도 하지 않는다.

    final crisis = candidates(s, EventLayer.crisis)
      ..sort((a, b) => b.weight - a.weight);
    if (crisis.isNotEmpty) {
      add(crisis.first);
    } else {
      add(
        _weightedPick(
          s,
          dailyPool(s, exclude: planned),
          rng(s, 'daily'),
          boost: boost,
          act: act,
        ),
      );
    }

    add(_pickRoute(s, boost: boost));

    final hidden = candidates(s, EventLayer.hidden);
    if (hidden.isNotEmpty &&
        rng(s, 'hidden').nextInt(100) < hiddenChancePercent) {
      add(_weightedPick(s, hidden, rng(s, 'hidden-pick'), boost: boost));
    }

    // 하루가 너무 짧으면 하트 하나를 쓴 보람이 없다.
    // 이미 꽉 찬 날은 그대로 두고, 한산한 날에만 일상을 하나 더 얹어
    // 하루 분량을 고르게 맞춘다. 오프닝에는 목표치까지 채운다.
    final target = opening ? openingMinEventsPerDay : minEventsPerDay;
    final maxFill = opening ? target : 1;
    for (var i = 0; i < maxFill && plan.length < target; i++) {
      // 보충 칸은 분량을 맞추려고 있는 칸이다. 이미 본 장면으로 채우면 분량만 늘고
      // 하루의 가치는 오히려 떨어지므로 처음 보는 장면만 쓴다. 단, 오늘이 정말 얇은
      // 날(장면이 GameConfig.fillSeenBelow 개보다 적은 날)은 재방송으로라도 채운다 —
      // 하트 하나에 장면 하나는 재방송보다 나쁘다.
      final allowSeen = plan.length < bundle.config.fillSeenBelow;
      final more = [
        for (final e in dailyPool(s, exclude: planned))
          if (allowSeen || !s.seen.contains(e.id)) e,
      ];
      final pick = _weightedPick(
        s,
        more,
        rng(s, 'daily-${i + 2}'),
        boost: boost,
        act: act,
      );
      if (pick == null) break;
      add(pick);
    }
    return plan;
  }

  /// 캐릭터 [id] 에게서 **이미 본** 루트 중 가장 높은 단계([StoryEvent.stage]). 없으면 null.
  /// 진행 상황을 읽는 용도(테스트·진단)다 — [nextStageEvents] 는 이 값으로 후보를 막지 않는다.
  int? highestSeenStage(GameState s, String id) {
    if (id.isEmpty) return null;
    int? best;
    for (final seen in s.seen) {
      final e = bundle.eventById[seen];
      if (e == null || e.layer != EventLayer.route || e.character != id) {
        continue;
      }
      final st = e.stage;
      if (st != null && (best == null || st > best)) best = st;
    }
    return best;
  }

  /// [list](한 캐릭터의 오늘 후보) 중 **오늘 낼 차례인 단계**만.
  ///
  /// 규칙 하나다: **오늘 낼 수 있는 것 중 가장 낮은 단계부터.** 같은 단계가 여럿이면
  /// 그 안에서 예전처럼 가중치 추첨. 그래서 `r05` 와 `r13` 이 같은 날 후보로 같이 올라오면
  /// **언제나 `r05` 가 먼저** 나간다(docs/review/07_story_flow.md (c)#3 — 수정 전에는
  /// 후보 전체에서 무작위라 `r13` → `r05` 같은 역행이 회차의 96.7~100% 에서 일어났다).
  ///
  /// **후보에서 빼지는 않는다.** "이미 본 단계보다 큰 것만" 으로 잠가 봤더니
  /// `r13` 처럼 조건이 느슨한 사이드 장면이 초반에 한 번 뽑히면 그 앞 단계가 영구히 막히고,
  /// 그 앞 단계의 플래그를 요구하는 `r15`(마지막 장면, 엔딩 조건)에 **아무도 못 닿았다**
  /// (MBTI 17종 도달성 테스트에서 f·m 각 4명이 0%). 그래서 순서는 '우선순위'로만 지키고,
  /// 늦게 열리는 앞 단계를 막는 일은 데이터(트리거) 쪽에 맡긴다 — 09_engine_handoff.md §3.
  ///
  /// 번호가 없는 루트 모먼트(`mo_seoyeon_call_dawn` 등 48개)는 단계 개념이 없으므로
  /// 언제나 함께 후보에 남는다.
  List<StoryEvent> nextStageEvents(GameState s, List<StoryEvent> list) {
    if (list.isEmpty) return const [];
    final free = [
      for (final e in list)
        if (e.stage == null) e,
    ];
    final numbered = [
      for (final e in list)
        if (e.stage != null) e,
    ];
    if (numbered.isEmpty) return free;
    final lowest = numbered.map((e) => e.stage!).reduce(min);
    return [
      ...free,
      for (final e in numbered)
        if (e.stage == lowest) e,
    ];
  }

  /// 호감도가 가장 높은 캐릭터를 우선하되, 후보가 있는 캐릭터 중에서 고른다.
  /// 오프닝(1~[openingDays]일차)에는 호감을 보지 않고 균등하게 고른다.
  /// [boost] 면 고른 캐릭터의 후보 안에서 모먼트 가중치를 올린다(캐릭터 선택은 그대로).
  ///
  /// 캐릭터를 고른 다음에는 [nextStageEvents] 가 단계 순서를 지킨다. 그러다 오늘 낼
  /// 것이 하나도 없는 사람이 나오면 루트 칸을 비우지 않고 다음 우선순위로 넘긴다.
  StoryEvent? _pickRoute(GameState s, {bool boost = false}) {
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
    final String chosen;
    // 오프닝에는 호감이 아직 의미가 없다. 첫날 동전 던지기 결과가 며칠씩
    // 같은 캐릭터를 밀어주지 않도록 후보가 있는 캐릭터 중 균등 무작위.
    if (isOpening(s)) {
      chosen = chars[r.nextInt(chars.length)];
    } else {
      // 최상위와 호감도가 같은 캐릭터들 사이에서는 무작위.
      final top = s.affectionOf(chars.first);
      final tied = chars.where((c) => s.affectionOf(c) == top).toList();
      chosen = tied[r.nextInt(tied.length)];
    }
    for (final c in [
      chosen,
      for (final x in chars)
        if (x != chosen) x,
    ]) {
      final pool = nextStageEvents(s, byChar[c]!);
      if (pool.isEmpty) continue;
      final pick = _weightedPick(s, pool, r, boost: boost);
      if (pick != null) return pick;
    }
    return null;
  }

  StoryEvent? byId(String id) => bundle.eventById[id];

  /// 보이는 선택지와 잠금 여부. MBTI·궁합 조건이 맞지 않는 선택지는 빠지고,
  /// [ChoiceView.index] 는 [ev].choices 의 원래 인덱스다(거른 사본을 넘기면 그 사본 기준).
  List<ChoiceView> choicesFor(GameState s, StoryEvent ev) {
    final v = mbtiView(s, ev);
    return [
      for (var i = 0; i < ev.choices.length; i++)
        if (v.allowsChoice(ev.choices[i])) _viewOf(s, ev, i),
    ];
  }

  ChoiceView _viewOf(GameState s, StoryEvent ev, int i) {
    final c = ev.choices[i];
    final req = c.require;
    final ok =
        req == null ||
        req.satisfied(s, self: ev.character, absent: absentFor(s));
    return ChoiceView(i, c, !ok, ok ? '' : req.describe());
  }

  /// 크리티컬 확률(%). 기본 5, 눈치 20당 +1, 물오름 상태면 두 배.
  int critChance(GameState s) {
    final base = 5 + s.stat(Stat.sense) ~/ 20;
    return s.onFire ? base * 2 : base;
  }

  /// 크리티컬이 호감에 곱하는 배율.
  static const critFactor = 2.0;

  /// 오늘 오르는 호감에 곱할 배율. 초반 가속(config.earlyAffection) × 크리티컬,
  /// 상한은 `EarlyAffection.maxTotal`. 가속 기간이 끝나면 1(크리티컬이면 2).
  double affectionMultiplier(GameState s, {bool critical = false}) => bundle
      .config
      .earlyAffection
      .combined(s.day, critical: critical, critFactor: critFactor);

  /// 확률 판정 보정(%p). 물오름 상태면 +20.
  int chanceBonus(GameState s) => s.onFire ? 20 : 0;

  /// 선택이 '좋은 선택'이었는지. 호감·신뢰가 오르고 아무것도 깎이지 않았을 때.
  bool _isGoodChoice(AppliedDelta d) {
    final up =
        d.affection.values.any((v) => v > 0) ||
        d.trust.values.any((v) => v > 0) ||
        d.stats.entries.any((e) => e.key != Stat.stress && e.value > 0);
    final down =
        d.affection.values.any((v) => v < 0) ||
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
    if (!mbtiView(s, ev).allowsChoice(c)) {
      throw ArgumentError.value(
        c.text,
        'choice',
        '이 플레이어(MBTI ${s.mbti ?? '모름'})에게 보이지 않는 선택지: ${ev.id}',
      );
    }
    final r = random ?? rng(s, '${ev.id}:${c.text}');
    double compat(String id) => compatMultiplier(s, id);
    s.seen.add(ev.id);
    // 반복될 수 있는 이벤트는 '몇 번째냐'도 적는다. 다음 추첨에서 그만큼 가중치가
    // 깎인다(GameConfig.repeatWeightPercent). `once` 는 두 번 안 나오므로 세지 않는다.
    if (!ev.once) s.noteSeenCount(ev.id);
    // 같은 일상이 며칠 안에 또 나오지 않게 본 날을 적는다(GameConfig.dailyCooldownDays).
    if (ev.layer == EventLayer.daily) {
      s.noteDailySeen(ev.id, cooldownDays: bundle.config.dailyCooldownDays);
    }
    // 모먼트를 본 날. 다음 모먼트 보정의 기준이 된다(거절한 전화도 본 것이다).
    if (isMoment(ev)) s.lastMomentDay = s.day;
    final self = ev.character;
    if (self != null) s.rel(self).contactedToday = true;

    final chance = c.chance;
    final failed = forcedSuccess != null
        ? !forcedSuccess
        : chance != null &&
              r.nextInt(100) >= (chance + chanceBonus(s)).clamp(0, 100);
    if (failed) {
      // 실패에도 오르는 호감(위로받는 선택 등)이 있으면 초반 가속만 건다.
      final d = applyEffects(
        s,
        c.fail,
        self: self,
        affectionMultiplier: affectionMultiplier(s),
        absent: absentFor(s),
        compatMultiplier: compat,
        random: r,
      );
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
    // 운으로 나는 크리티컬은 호감을 2배로 올리는 연출이라, 호감이 오르지 않는
    // 선택지(차갑게 굴기 등)에서는 굴리지 않는다. 미니게임 크리티컬은 실력으로
    // 딴 것이므로 그대로 인정한다.
    final canCrit = c.effects.affection.entries.any(
      (e) => e.value > 0 && !absentFor(s).contains(e.key),
    );
    final crit = forcedCritical ?? (canCrit && r.nextInt(100) < critChance(s));
    final d = applyEffects(
      s,
      c.effects,
      self: self,
      affectionMultiplier: affectionMultiplier(s, critical: crit),
      absent: absentFor(s),
      compatMultiplier: compat,
      random: r,
    );
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
    ('돈이 생겼다', {Stat.money: 40}, '길에서 주운 4만원'),
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

  /// 아침 행동. 효과를 적용하고 오늘 행동으로 적어 둔다([GameState.todayAction]) —
  /// 그다음 [planDay] 가 그 행동의 장면을 하루 첫 장면으로 깐다. 마감([endDay])에서 비운다.
  AppliedDelta applyAction(GameState s, DayAction a) {
    s.todayAction = a.id;
    return applyEffects(
      s,
      a.effects,
      absent: absentFor(s),
      compatMultiplier: (id) => compatMultiplier(s, id),
    );
  }

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
    // 아침 행동은 그날 하루 것이다. 내일 미리보기(사본 마감)가 오늘 행동 장면을 내일로
    // 끌고 가지 않게 엔진 마감에서도 비운다.
    s.todayAction = null;
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
    s.lastHeartMs = s.hearts >= cfg.maxHearts
        ? nowMs
        : s.lastHeartMs + gained * per;
    return add;
  }

  int get heartPeriodMs => max(1, bundle.config.heartRegenMinutes) * 60 * 1000;

  /// 다음 하트까지 남은 시간(ms). 가득 차 있으면 0.
  int nextHeartInMs(GameState s, {required int nowMs}) {
    if (s.hearts >= bundle.config.maxHearts) return 0;
    return max(0, s.lastHeartMs + heartPeriodMs - nowMs);
  }
}
