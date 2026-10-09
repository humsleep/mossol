import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../game_controller.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'scene_card.dart' show SceneImage;
import 'scene_registry.dart';

/// 시작 카드 시트(docs/overhaul2/01_design.md §4). 카드 하나하나가 태현의 "갑자기 왜. 무슨 일
/// 있었지?" 에 대한 주인공의 대답이다.
///
/// - 맨 위 **운명 뽑기** 카드(r1_playtest P2-5: 맨 아래면 4~6화면 밑이라 안 보였다) + 세로 스크롤 카드.
/// - 기본 선택([suggestedId], D7·D9): 첫 회차면 `recommended` 시작, 그 뒤로는 아직 끝내 보지 않은
///   첫 시작. 운명 카드 바로 아래 맨 앞에 두고 테두리로 강조한다 — 클래식으로 돌아가는 관성을 끊는다.
/// - 카드: 1일차 장면 그림(없으면 그라데이션 + 아이콘), 제목·훅, 톤 태그, 자극도 칸(텍스트 칩 —
///   §4.3 이 이모지를 쓰지 않는다고 정해 아이콘으로 그린다), "먼저 다가오는 사람", 엔딩 도장.
/// - 배지 우선순위: 운명 > 처음이라면 > 새로 열림 > 본 적 있음.
/// - 잠김: 엔딩 앨범의 서로 다른 엔딩 수가 `unlockEndings` 보다 적으면 그림을 흐리게 하고 자물쇠.
///   탭하면 훅 한 줄만 펼친다(호기심). 고를 수는 없다.
/// - 운명 뽑기: 잠긴 것을 포함한 전부에서 무작위 하나(바로 전 회차의 시작은 뺀다). 잠긴 시작도
///   **이번 회차만** 열린다. 뽑는 순간 [onFateDrawn] 으로 알린다 — 컨트롤러가 메타에 남겨
///   인트로·홈·엔딩 어디서도, 앱을 다시 켜도 재추첨할 수 없다(r1_meeting D10). 뽑으면 결과를
///   짧게 보여 주고(무엇이 나왔는지, 잠긴 이야기가 열렸는지) "이 이야기로 시작" 으로 고른다.
///
/// 고른 id 를 돌려주고, 시트를 그냥 닫으면 null.
/// 시트의 결과. [fate] 면 운명 뽑기로 나온 시작이다(잠겨 있어도 이번 회차만 열린다).
typedef StartPick = ({String id, bool fate});

class StartPickSheet extends StatefulWidget {
  final List<StartScenario> starts;

  /// 이미 뽑은 운명. 있으면 다시 뽑지 않는다 — 운명 카드는 이 결과를 그대로 돌려주고, 그 시작
  /// 카드는 잠겨 있어도 고를 수 있다.
  final String? fateLocked;

  /// "새로 열림" 배지를 달 시작(처음 열린 뒤 아직 안 보여 준 것). 한 번 보이면 메타에 남아
  /// 다음부터는 달지 않는다([GameController.markStartsAnnounced]).
  final Set<String> newIds;

  /// 엔딩 앨범의 서로 다른 엔딩 수. 해금 판정에 쓴다.
  final int endingCount;

  /// 바로 전 회차의 시작(운명 뽑기에서 뺀다). 없으면 null.
  final String? lastStart;

  /// 이 기기의 첫 회차인지. 기본 선택 카드에 "처음이라면" 배지를 단다.
  final bool firstRun;

  /// 기본 선택 시작(맨 앞, 강조). 없으면 정의 순서 그대로. 첫 회차에 이것이 없으면 클래식이
  /// "처음이라면" 이다(예전 동작).
  final String? suggestedId;

  /// 시작 id → 그 시작으로 본 서로 다른 엔딩 수. 1 이상이면 "본 적 있음" 과 엔딩 도장.
  final Map<String, int> endingsByStart;

  /// 캐릭터 id → 이름. "먼저 다가오는 사람" 줄이 쓴다. 이 회차에 없는 id 는 빠진다.
  final Map<String, String> charNames;

  /// 운명 뽑기 난수(테스트가 고정한다).
  final Random? random;

  /// 운명을 새로 뽑은 순간(결과를 보여 주기 전). 저장하는 쪽이 받는다.
  final Future<void> Function(String id)? onFateDrawn;

  const StartPickSheet({
    super.key,
    required this.starts,
    required this.endingCount,
    this.lastStart,
    this.firstRun = false,
    this.charNames = const {},
    this.random,
    this.fateLocked,
    this.newIds = const {},
    this.suggestedId,
    this.endingsByStart = const {},
    this.onFateDrawn,
  });

  static const title = '무슨 일이 있었냐면';
  static const subtitle = '고른 카드가 내 대답이 된다. 100일의 시작이 달라진다';
  static const fateTitle = '운명 뽑기';
  static const fateHint = '잠긴 이야기도 나올 수 있어요. 이번 회차에만 열려요';
  static const fateBadge = '운명';

  /// 이미 뽑은 운명을 보여 줄 때의 안내.
  static String fateDrawn(String title) => '이번 운명은 $title. 다시 뽑을 수 없어요';

  /// 운명 결과 연출의 머리말·잠긴 시작 안내·시작 버튼.
  static const fateRevealTitle = '운명이 고른 이야기';
  static const fateRevealLocked = '잠긴 이야기가 이번 회차에만 열렸다';
  static const fateGo = '이 이야기로 시작';
  static const firstBadge = '처음이라면';
  static const newBadge = '새로 열림';
  static const seenBadge = '본 적 있음';
  static const spiceLabel = '자극';
  static const comesFirst = '먼저 다가오는 사람';

  /// 엔딩 도장 줄. "엔딩 2개".
  static String stampText(int n) => '엔딩 $n개';

  /// 도장 아이콘을 이만큼까지만 그린다(넘으면 숫자만).
  static const maxStamps = 5;

  /// 잠긴 카드의 안내. 이미 본 엔딩 수를 빼고 남은 개수로 말한다.
  static String lockText(int need, int have) =>
      have <= 0 ? '엔딩 $need개를 보면 열려요' : '엔딩 ${need - have}개 더 보면 열려요';

  /// 운명 뽑기 후보. 바로 전 시작을 빼되 그러면 비는 경우(시작이 하나뿐)는 전부.
  static List<StartScenario> fatePool(
    List<StartScenario> starts,
    String? lastStart,
  ) {
    final pool = [
      for (final s in starts)
        if (s.id != lastStart) s,
    ];
    return pool.isEmpty ? starts : pool;
  }

  /// 화면에 놓을 순서. [suggested] 가 있으면 맨 앞, 나머지는 정의 순서.
  static List<StartScenario> ordered(
    List<StartScenario> starts,
    String? suggested,
  ) {
    final i = starts.indexWhere((s) => s.id == suggested);
    if (i <= 0) return starts;
    return [starts[i], ...starts.take(i), ...starts.skip(i + 1)];
  }

  /// 시트를 띄운다. 고른 시작, 닫으면 null.
  static Future<StartPick?> show(
    BuildContext context, {
    required List<StartScenario> starts,
    required int endingCount,
    String? lastStart,
    bool firstRun = false,
    Map<String, String> charNames = const {},
    Random? random,
    String? fateLocked,
    Set<String> newIds = const {},
    String? suggestedId,
    Map<String, int> endingsByStart = const {},
    Future<void> Function(String id)? onFateDrawn,
  }) => showModalBottomSheet<StartPick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => StartPickSheet(
      starts: starts,
      endingCount: endingCount,
      lastStart: lastStart,
      firstRun: firstRun,
      charNames: charNames,
      random: random,
      fateLocked: fateLocked,
      newIds: newIds,
      suggestedId: suggestedId,
      endingsByStart: endingsByStart,
      onFateDrawn: onFateDrawn,
    ),
  );

  /// 컨트롤러의 데이터로 띄운다. 시작 정의(`starts.json`)가 없으면(클래식뿐) 시트 없이 곧바로
  /// 클래식을 돌려준다 — 예전 데이터·합성 번들에서 흐름이 그대로다.
  /// [preference] 를 알면 그 회차에 등장하는 사람만 "먼저 다가오는 사람" 에 적는다.
  static Future<String?> showFor(
    BuildContext context,
    GameController c, {
    String? preference,
    Random? random,
  }) async => (await showPickFor(
    context,
    c,
    preference: preference,
    random: random,
  ))?.id;

  /// [showFor] 와 같되 운명 뽑기 여부까지 돌려준다. 이미 뽑은 운명은 컨트롤러(메타)에서 읽고,
  /// 새로 뽑으면 거기에 남긴다(D10). [fateLocked] 를 주면 그것이 먼저다.
  static Future<StartPick?> showPickFor(
    BuildContext context,
    GameController c, {
    String? preference,
    Random? random,
    String? fateLocked,
  }) async {
    final b = c.bundle;
    if (b.starts.length <= 1) return (id: StartScenario.classic, fate: false);
    final fresh = c.newlyUnlockedStarts;
    final pick = await show(
      context,
      starts: b.starts,
      endingCount: c.distinctEndingCount,
      lastStart: c.lastStart,
      firstRun: c.isFirstOnboarding,
      charNames: preference == null ? b.charNames : b.charNamesFor(preference),
      random: random,
      fateLocked: fateLocked ?? c.pendingFate,
      newIds: fresh,
      suggestedId: c.suggestedStart,
      endingsByStart: {
        for (final s in b.starts)
          if (c.startEndingCount(s.id) > 0) s.id: c.startEndingCount(s.id),
      },
      onFateDrawn: c.rememberFate,
    );
    // 배지를 한 번 보여 줬으면 다음부터는 달지 않는다.
    if (fresh.isNotEmpty) await c.markStartsAnnounced(fresh);
    return pick;
  }

  @override
  State<StartPickSheet> createState() => _StartPickSheetState();
}

class _StartPickSheetState extends State<StartPickSheet> {
  /// 잠긴 카드 중 훅을 펼친 것.
  final Set<String> _peeked = {};

  /// 이 시트에서 방금 뽑은 운명(결과 연출 중). 고정된 운명([StartPickSheet.fateLocked])과 같이 쓴다.
  String? _drawn;

  String? get _fate => widget.fateLocked ?? _drawn;

  void _pick(String id, {bool fate = false}) =>
      Navigator.of(context).pop<StartPick>((id: id, fate: fate));

  Future<void> _fateTap() async {
    final locked = _fate;
    if (locked != null) return _pick(locked, fate: true);
    final pool = StartPickSheet.fatePool(widget.starts, widget.lastStart);
    final r = widget.random ?? Random();
    final id = pool[r.nextInt(pool.length)].id;
    // 먼저 남기고 보여 준다 — 결과를 보고 시트를 닫아도 다시 뽑을 수 없다.
    setState(() => _drawn = id);
    await widget.onFateDrawn?.call(id);
  }

  bool _open(StartScenario s) =>
      s.unlockedBy(widget.endingCount) || s.id == _fate;

  StartScenario? _startOf(String? id) => id == null
      ? null
      : [
          for (final s in widget.starts)
            if (s.id == id) s,
        ].firstOrNull;

  /// "처음이라면" 을 달 시작. 첫 회차의 기본 선택, 없으면 클래식.
  String? get _firstId =>
      widget.firstRun ? (widget.suggestedId ?? StartScenario.classic) : null;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final soft = context.scheme.onSurfaceVariant;
    final drawn = _startOf(_drawn);
    final starts = StartPickSheet.ordered(widget.starts, widget.suggestedId);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: ListView(
        key: const Key('start-pick-list'),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screenX,
          0,
          AppSpace.screenX,
          AppSpace.xxl,
        ),
        children: [
          Text(StartPickSheet.title, style: text.titleLarge),
          const SizedBox(height: AppSpace.xs),
          Text(
            keepAll(StartPickSheet.subtitle),
            style: text.bodyMedium?.copyWith(color: soft),
          ),
          const SizedBox(height: AppSpace.lg),
          AnimatedSwitcher(
            duration: AppMotion.base(context),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.0).animate(a),
                child: child,
              ),
            ),
            child: drawn != null && widget.fateLocked == null
                ? _FateReveal(
                    key: const Key('start-fate-reveal'),
                    start: drawn,
                    wasLocked: !drawn.unlockedBy(widget.endingCount),
                    onGo: () => _pick(drawn.id, fate: true),
                  )
                : _FateCard(
                    key: const Key('start-fate'),
                    onTap: () => unawaited(_fateTap()),
                    drawn: _startOf(widget.fateLocked)?.title,
                  ),
          ),
          for (final s in starts) ...[
            const SizedBox(height: AppSpace.gap),
            _StartCard(
              key: Key('start-card-${s.id}'),
              start: s,
              index: widget.starts.indexOf(s),
              locked: !_open(s),
              peeked: _peeked.contains(s.id),
              endingCount: widget.endingCount,
              badge: _badgeOf(s),
              comesFirst: _comesFirst(s),
              suggested: s.id == widget.suggestedId,
              stamps: widget.endingsByStart[s.id] ?? 0,
              onTap: () {
                if (_open(s)) {
                  _pick(s.id, fate: s.id == _fate);
                } else {
                  setState(() {
                    _peeked.contains(s.id)
                        ? _peeked.remove(s.id)
                        : _peeked.add(s.id);
                  });
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  String? _badgeOf(StartScenario s) {
    if (s.id == _fate) return StartPickSheet.fateBadge;
    if (s.id == _firstId) return StartPickSheet.firstBadge;
    if (widget.newIds.contains(s.id)) return StartPickSheet.newBadge;
    if ((widget.endingsByStart[s.id] ?? 0) > 0) return StartPickSheet.seenBadge;
    return null;
  }

  /// 보정이 호감을 주는 사람들의 이름. 이 회차에 없는 사람은 빠진다.
  String? _comesFirst(StartScenario s) {
    final names = [
      for (final id in s.effects.affection.keys) ?widget.charNames[id],
    ];
    return names.isEmpty ? null : names.join('·');
  }
}

/// 운명 뽑기 결과(짧은 연출). 무엇이 나왔는지와, 잠긴 이야기였다면 이번 회차만 열렸다는 것.
class _FateReveal extends StatelessWidget {
  final StartScenario start;
  final bool wasLocked;
  final VoidCallback onGo;
  const _FateReveal({
    super.key,
    required this.start,
    required this.wasLocked,
    required this.onGo,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    final on = scheme.onPrimaryContainer;
    return Semantics(
      liveRegion: true,
      label: '${StartPickSheet.fateRevealTitle}: ${start.title}',
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.rLg,
        child: Padding(
          padding: AppInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: on),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      StartPickSheet.fateRevealTitle,
                      style: text.labelLarge?.copyWith(color: on),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(start.title, style: text.headlineSmall?.copyWith(color: on)),
              const SizedBox(height: AppSpace.xs),
              Text(
                keepAll(start.hook),
                style: text.bodyMedium?.copyWith(color: on),
              ),
              if (wasLocked) ...[
                const SizedBox(height: AppSpace.xs),
                Row(
                  children: [
                    Icon(Icons.lock_open, size: 16, color: on),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Text(
                        keepAll(StartPickSheet.fateRevealLocked),
                        style: text.bodySmall?.copyWith(color: on),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.md),
              FilledButton(
                key: const Key('start-fate-go'),
                onPressed: onGo,
                child: const Text(StartPickSheet.fateGo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카드 그림이 없을 때(그림은 나중에 들어온다)의 색과 아이콘. 시작마다 다르게.
({List<Color> colors, IconData icon}) _placeholderOf(String id, int index) {
  const sets = [
    [AppPalette.rose500, AppPalette.violet600],
    [AppPalette.violet600, AppPalette.infoLight],
    [AppPalette.rose600, AppPalette.warningLight],
    [AppPalette.teal600, AppPalette.violet800],
    [AppPalette.rose700, AppPalette.night400],
    [AppPalette.infoBgDark, AppPalette.teal800],
  ];
  final icon = switch (id) {
    StartScenario.classic => Icons.emoji_events_outlined,
    'sc_leak' => Icons.forum_outlined,
    'sc_speech' => Icons.celebration_outlined,
    'sc_clip' => Icons.headset_mic_outlined,
    'sc_swap' => Icons.heart_broken_outlined,
    'sc_ghost' => Icons.edit_note,
    _ => Icons.auto_stories_outlined,
  };
  return (colors: sets[index % sets.length], icon: icon);
}

class _StartCard extends StatelessWidget {
  final StartScenario start;
  final int index;
  final bool locked;
  final bool peeked;
  final int endingCount;
  final String? badge;
  final String? comesFirst;

  /// 기본 선택(맨 앞, 강조 테두리).
  final bool suggested;

  /// 이 시작으로 본 엔딩 수(엔딩 도장).
  final int stamps;
  final VoidCallback onTap;

  const _StartCard({
    super.key,
    required this.start,
    required this.index,
    required this.locked,
    required this.peeked,
    required this.endingCount,
    required this.badge,
    required this.comesFirst,
    required this.onTap,
    this.suggested = false,
    this.stamps = 0,
  });

  /// 카드 그림 띠의 가로세로비. 3:2 원본의 가운데를 넓게 자른다.
  static const double imageAspect = 2.2;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final text = context.text;
    final soft = scheme.onSurfaceVariant;
    final lockLine = StartPickSheet.lockText(start.unlockEndings, endingCount);
    return Semantics(
      button: true,
      label: locked
          ? '${start.title}, 잠김. $lockLine'
          : '${start.title}. ${start.hook}',
      child: Material(
        // 라이트 모드는 시트 바탕(surfaceContainerLow)과 같은 색이라 카드 경계가 사라졌다
        // (r1_playtest P2-3). 한 단 밝은 면 + 가는 테두리로 한 장을 묶는다.
        color: context.isDark ? scheme.surfaceContainerLow : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rLg,
          side: BorderSide(
            color: suggested ? scheme.primary : scheme.outlineVariant,
            width: suggested
                ? AppBorderWidth.emphasis
                : AppBorderWidth.hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: imageAspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _blurIf(locked, _art(context)),
                    if (locked)
                      ColoredBox(
                        color: scheme.scrim.withValues(alpha: 0.35),
                        child: const Center(
                          child: Icon(
                            Icons.lock_outline,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (badge != null)
                      PositionedDirectional(
                        top: AppSpace.sm,
                        start: AppSpace.sm,
                        child: _Badge(text: badge!),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: AppInsets.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            start.title,
                            style: text.titleMedium?.copyWith(
                              color: locked ? t.lockedForeground : null,
                            ),
                          ),
                        ),
                        _Spice(level: start.spice, dim: locked),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xs),
                    if (locked) ...[
                      Text(
                        keepAll(lockLine),
                        style: text.bodySmall?.copyWith(color: soft),
                      ),
                      if (peeked) ...[
                        const SizedBox(height: AppSpace.xs),
                        Text(keepAll(start.hook), style: text.bodyMedium),
                      ],
                    ] else ...[
                      Text(keepAll(start.hook), style: text.bodyMedium),
                      if (stamps > 0) ...[
                        const SizedBox(height: AppSpace.xs),
                        _Stamps(count: stamps),
                      ],
                      if (start.logline.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          keepAll(start.logline),
                          style: text.bodySmall?.copyWith(color: soft),
                        ),
                      ],
                      const SizedBox(height: AppSpace.sm),
                      Wrap(
                        spacing: AppSpace.xs,
                        runSpacing: AppSpace.xs,
                        children: [
                          for (final tag in start.tags) _Tag(text: tag),
                          if (comesFirst != null)
                            _Tag(
                              text: '${StartPickSheet.comesFirst} $comesFirst',
                              icon: Icons.favorite_border,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 흐림은 그림 띠 안에서 자른다. 자르지 않으면 가장자리가 흰 안개처럼 본문으로 번진다
  /// (r1_playtest P2-2).
  Widget _blurIf(bool on, Widget child) => on
      ? ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: child,
          ),
        )
      : child;

  /// 그림(SceneRegistry 에 있으면) 또는 그라데이션 자리 그림.
  Widget _art(BuildContext context) {
    final ph = _placeholderOf(start.id, index);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ph.colors,
        ),
      ),
      child: Center(
        child: Icon(
          ph.icon,
          size: 40,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
    return SceneScope(
      builder: (context, registry) {
        final path = registry.exact(start.image);
        if (path == null) return placeholder;
        return LayoutBuilder(
          builder: (context, box) => SceneImage(
            path: path,
            width: box.maxWidth,
            // 카드(2.2:1)는 3:2 그림의 위아래를 자른다. 핵심 소품(스크린 배너·마이크 불)이 위쪽에 있어 위를 덜 자른다.
            alignment: const Alignment(0, -0.5),
            fallback: (_) => placeholder,
            bundle: registry.bundle,
          ),
        );
      },
    );
  }
}

class _FateCard extends StatelessWidget {
  final VoidCallback onTap;

  /// 이미 뽑은 운명의 제목. 있으면 안내가 "다시 뽑을 수 없어요" 로 바뀐다.
  final String? drawn;
  const _FateCard({super.key, required this.onTap, this.drawn});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    final d = drawn;
    final hint = d == null
        ? StartPickSheet.fateHint
        : StartPickSheet.fateDrawn(d);
    return Semantics(
      button: true,
      label: '${StartPickSheet.fateTitle}. $hint',
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.rLg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: AppInsets.card,
            child: Row(
              children: [
                Icon(Icons.shuffle, color: scheme.onPrimaryContainer),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        StartPickSheet.fateTitle,
                        style: text.titleMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xxs),
                      Text(
                        keepAll(hint),
                        style: text.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 자극도. 글자 "자극" + 칸 세 개(켜진 만큼 [spice]). 이모지 대신 아이콘(§4.3).
class _Spice extends StatelessWidget {
  final int level;
  final bool dim;
  const _Spice({required this.level, this.dim = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final on = dim ? t.lockedForeground : t.danger;
    return Semantics(
      label: '${StartPickSheet.spiceLabel} $level / 3',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              StartPickSheet.spiceLabel,
              style: context.text.labelSmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpace.xxs),
            for (var i = 0; i < 3; i++)
              Icon(
                Icons.local_fire_department,
                size: 16,
                color: i < level ? on : t.gaugeTrack,
              ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final IconData? icon;
  const _Tag({required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: AppInsets.chip,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpace.xxs),
          ],
          Flexible(
            child: Text(
              text,
              style: context.text.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: AppInsets.chip,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: AppRadius.rPill,
      ),
      child: Text(
        text,
        style: context.text.labelSmall?.copyWith(color: scheme.onPrimary),
      ),
    );
  }
}

/// 엔딩 도장(D7). 이 시작으로 본 엔딩 수만큼 도장 아이콘(최대 [StartPickSheet.maxStamps]) + "엔딩 n개".
class _Stamps extends StatelessWidget {
  final int count;
  const _Stamps({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final label = StartPickSheet.stampText(count);
    return Semantics(
      label: '${StartPickSheet.seenBadge}, $label',
      child: ExcludeSemantics(
        child: Row(
          key: const Key('start-stamps'),
          children: [
            for (var i = 0; i < min(count, StartPickSheet.maxStamps); i++)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpace.xxs),
                child: Icon(Icons.verified, size: 14, color: scheme.primary),
              ),
            const SizedBox(width: AppSpace.xxs),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
