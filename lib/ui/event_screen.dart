import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../engine/event_engine.dart';
import '../engine/models.dart';
import '../game_controller.dart';
import '../minigames/minigame.dart';
import '../minigames/registry.dart';
import 'call_view.dart';
import 'design_system.dart';
import 'notification_card.dart';
import 'widgets.dart';

/// 전화 이벤트의 단계. docs/MOMENTS_SPEC.md §1.1.
enum CallStage { ringing, active, declined }

/// 채팅형 이벤트 화면. 말풍선이 순서대로 나타나고, 끝나면 하단 패널이 올라온다.
///
/// 규격: docs/DESIGN_SYSTEM.md §2.3.
/// - 주인공은 말풍선 흐름이다. 대화 영역은 `tokens.chatBackground` 로 화면 바탕과
///   한 단 구분하고, 상단 헤더와 하단 패널은 배경으로 물러난다.
/// - 헤더는 상대(이니셜 원형 + 이름) · 이벤트 제목 · 날짜 · 진행 막대까지
///   한 줄로 정리한다. 진행 막대는 이 대화가 얼마나 남았는지를 알려 준다.
/// - 컨트롤러 호출과 상태 사용 방식은 이전과 같다. 표현 계층만 바뀌었다.
///
/// 모먼트 변형(docs/MOMENTS_SPEC.md, DESIGN_SYSTEM §2.3):
/// - `format == "call"`: 수신 화면 → (받기) 통화 화면(자막·타이머) → 선택지(decline 숨김)
///   → 반응(자막) → 결과 패널. (거절) decline 선택지를 고르고 반응은 채팅 말풍선.
/// - `preview`: 대화가 열리기 전 잠금화면 알림 카드. 탭하거나 1.8초 뒤 열린다.
///   대사 자동 공개 타이머는 알림이 닫힌 뒤에 시작한다.
class EventScreen extends StatefulWidget {
  final GameController c;
  const EventScreen({super.key, required this.c});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  Timer? _timer;
  int _waitLeft = 0;
  String? _eventId;
  final _scroll = ScrollController();

  /// 방금 고른 선택지 문구. 결과 패널이 떠 있는 동안 내 말풍선으로 대화에 남긴다.
  /// 표시 전용이며 컨트롤러 상태와 무관하다.
  String? _picked;

  /// 선택 뒤 상대 반응 중 지금까지 보여 준 줄 수.
  int _replyShown = 0;
  Timer? _replyTimer;
  ChoiceOutcome? _replyFor;

  /// 전화 이벤트 단계. 채팅 이벤트에서는 쓰지 않는다.
  CallStage _callStage = CallStage.active;

  /// 통화 시간(초)과 그 타이머.
  int _callSeconds = 0;
  Timer? _callTimer;

  /// 알림 카드가 떠 있는지와 자동 열림 타이머.
  bool _previewOpen = false;
  Timer? _previewTimer;

  /// 통화 중 대기 줄(`wait`)은 카운트다운 대신 이만큼 침묵한다. 벌점·광고 없음.
  static const callSilence = Duration(seconds: 2);

  /// initState 에서는 MediaQuery(동작 줄이기)를 읽을 수 없어서 첫 동기화를 미룬다.
  bool _started = false;

  GameController get c => widget.c;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _syncEvent();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _replyTimer?.cancel();
    _callTimer?.cancel();
    _previewTimer?.cancel();
    c.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    if (c.lastOutcome == null) {
      _picked = null;
      // 거절을 되돌리면(광고) 다시 울리는 화면으로.
      if (_callStage == CallStage.declined) _callStage = CallStage.ringing;
    }
    _syncEvent();
    _syncReply();
    if (c.current?.isCall == true &&
        _callStage == CallStage.active &&
        !_callEnded &&
        !(_callTimer?.isActive ?? false)) {
      _startCallClock();
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 프레임 사이에 화면이 내려갔을 수 있다. dispose 된 컨트롤러는 건드리지 않는다.
      if (!mounted || !_scroll.hasClients) return;
      // 동작 줄이기가 켜져 있으면 0ms 라 곧바로 끝까지 내려간다.
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.base(context),
        curve: AppMotion.curve(context),
      );
    });
  }

  void _syncEvent() {
    final ev = c.current;
    final id = ev?.id;
    if (id == _eventId) return;
    _eventId = id;
    _timer?.cancel();
    _callTimer?.cancel();
    _previewTimer?.cancel();
    _waitLeft = 0;
    _callSeconds = 0;
    _previewOpen = false;
    _callStage = CallStage.active;
    // 처음부터 보는 이벤트일 때만 전화 수신·알림을 연출한다(복원·디버그 진입은 건너뜀).
    final fresh = ev != null && c.revealed == 0 && c.lastOutcome == null;
    if (ev != null && ev.isCall) {
      if (fresh) {
        _callStage = CallStage.ringing;
        return;
      }
      _startCallClock();
    } else if (ev != null && fresh && _previewName(ev) != null) {
      // 동작 줄이기면 알림 없이 바로 대화가 열린다.
      if (!AppMotion.reduced(context)) {
        _previewOpen = true;
        _previewTimer = Timer(NotificationPreview.autoOpen, _openPreview);
        return;
      }
    }
    _scheduleReveal();
  }

  /// 알림 카드에 쓸 이름. 캐릭터 이름, 없으면 첫 `them` 줄의 name. 둘 다 없으면 null
  /// (알림을 띄우지 않는다). `preview` 가 없어도 null.
  String? _previewName(StoryEvent ev) {
    if (ev.preview == null) return null;
    if (ev.character != null) return c.characterName(ev.character);
    for (final l in ev.lines) {
      if (l.who == 'them') return l.name;
    }
    return null;
  }

  void _openPreview() {
    if (!mounted || !_previewOpen) return;
    _previewTimer?.cancel();
    setState(() => _previewOpen = false);
    _scheduleReveal();
  }

  // ---- 전화 ----

  /// 결과 패널이 떠서 통화가 끝났는지.
  bool get _callEnded =>
      c.lastOutcome != null && _replyShown >= c.lastReply.length;

  void _startCallClock() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_callEnded) {
        t.cancel();
        setState(() {});
        return;
      }
      setState(() => _callSeconds++);
    });
  }

  void _acceptCall() {
    setState(() => _callStage = CallStage.active);
    _startCallClock();
    _scheduleReveal();
  }

  /// 거절 = decline 선택지를 고른 것. 효과·반응·결과 패널이 그대로 따라온다.
  void _declineCall() {
    final i = c.current?.declineIndex;
    if (i == null) return;
    _timer?.cancel();
    setState(() => _callStage = CallStage.declined);
    _picked = null;
    c.choose(i);
  }

  /// 선택 결과가 새로 나오면 상대 반응을 한 줄씩 타이핑하듯 보여 준다.
  /// 동작 줄이기가 켜져 있으면 한 번에 다 보여 준다.
  void _syncReply() {
    final o = c.lastOutcome;
    if (identical(o, _replyFor)) return;
    _replyFor = o;
    _replyTimer?.cancel();
    _replyShown = 0;
    final total = c.lastReply.length;
    if (o == null || total == 0) return;
    if (MediaQuery.of(context).disableAnimations) {
      _replyShown = total;
      return;
    }
    void step() {
      _replyTimer = Timer(const Duration(milliseconds: 750), () {
        if (!mounted || !identical(c.lastOutcome, o)) return;
        setState(() => _replyShown++);
        _scrollToEnd();
        if (_replyShown < total) step();
      });
    }

    step();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.base(context),
        curve: AppMotion.curve(context),
      );
    });
  }

  /// 다음 줄을 자동으로 공개. 대기 줄이면 카운트다운.
  void _scheduleReveal() {
    _timer?.cancel();
    final ev = c.current;
    if (ev == null || c.linesDone) return;
    final next = ev.lines[c.revealed];
    if (next.isWait && ev.isCall) {
      // 통화 중 대기 줄은 "…(침묵)" 을 바로 띄우고 잠시 멈춘다.
      c.revealNext();
      _timer = Timer(callSilence, () {
        if (mounted) _scheduleReveal();
      });
      return;
    }
    if (next.isWait) {
      _waitLeft = next.wait;
      _runWaitCountdown();
      return;
    }
    final delay = switch (next.who) {
      'me' => 450,
      'narr' => 350,
      _ => 800,
    };
    _timer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      c.revealNext();
      _scheduleReveal();
    });
  }

  /// 남은 시간부터 1초씩 센다. 광고가 실패해 돌아왔을 때도 이 지점부터 이어 센다.
  void _runWaitCountdown() {
    _timer?.cancel();
    if (_waitLeft <= 0) return _finishWait();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _waitLeft--);
      if (_waitLeft <= 0) {
        t.cancel();
        _finishWait();
      }
    });
  }

  void _finishWait() {
    // 읽씹 대기는 자존감을 1 깎는다. 모쏠 체험의 핵심 감정.
    // 엔진을 거쳐야 정산 화면과 되돌리기, 세이브에 함께 잡힌다.
    c.applyWaitPenalty();
    c.revealNext();
    _scheduleReveal();
  }

  Future<void> _skipWait() async {
    // 광고를 기다리는 동안 카운트다운이 계속 돌면, 광고를 보고도 자존감이 깎이고
    // 대사 한 줄이 건너뛰어진다. 광고를 띄우기 전에 먼저 멈춘다.
    _timer?.cancel();
    final ok = await AdManager.instance.showRewarded();
    if (!mounted) return;
    if (ok) {
      _waitLeft = 0;
      c.revealNext();
      _scheduleReveal();
    } else {
      _snack('광고를 불러오지 못했어요.');
      _runWaitCountdown();
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// 말풍선 묶음 기준. 같은 사람이 이어 말하면 같은 키가 나온다.
  String _speakerKey(Line l, String partner) => switch (l.who) {
    'narr' => '#narr',
    'sys' => '#sys',
    'me' => '#me',
    _ => 'them:${l.name ?? partner}',
  };

  @override
  Widget build(BuildContext context) {
    final ev = c.current;
    if (ev == null) return const SizedBox.shrink();
    final partner = c.characterName(ev.character);
    if (_previewOpen) {
      return NotificationPreview(
        name: _previewName(ev) ?? partner,
        characterId: ev.character,
        preview: ev.preview ?? '',
        day: c.state!.day,
        onOpen: _openPreview,
      );
    }
    if (ev.isCall) {
      switch (_callStage) {
        case CallStage.ringing:
          return IncomingCallView(
            name: partner,
            characterId: ev.character,
            onAccept: _acceptCall,
            onDecline: _declineCall,
          );
        case CallStage.active:
          return _activeCall(ev, partner);
        case CallStage.declined:
          return _chat(ev, partner, missedCall: true);
      }
    }
    return _chat(ev, partner);
  }

  /// 통화 중 화면. 자막 → 선택지(decline 숨김) → 내 말·반응(자막) → 결과 패널.
  Widget _activeCall(StoryEvent ev, String partner) {
    final visible = ev.lines.take(c.revealed).toList();
    final o = c.lastOutcome;
    final replying = o != null && _replyShown < c.lastReply.length;
    Widget sub(Line l) =>
        CallSubtitle(line: l, partnerName: partner, characterId: ev.character);
    return ActiveCallView(
      name: partner,
      characterId: ev.character,
      seconds: _callSeconds,
      ended: _callEnded,
      scroll: _scroll,
      subtitles: [
        for (final l in visible) sub(l),
        if (o != null && _picked != null) sub(Line(who: 'me', text: _picked!)),
        if (o != null)
          for (final l in c.lastReply.take(_replyShown)) sub(l),
        if (replying || (o == null && !c.linesDone && !_pendingIsWait(ev)))
          const CallTyping(),
      ],
      bottom: o != null
          ? (replying ? null : _ResultPanel(c: c))
          : c.linesDone
          ? _ChoicePanel(
              c: c,
              hideDecline: true,
              onPicked: (text) => _picked = text,
            )
          : null,
    );
  }

  bool _pendingIsWait(StoryEvent ev) =>
      !c.linesDone && ev.lines[c.revealed].isWait;

  /// 채팅 화면. [missedCall] 이면 거절한 전화 뒤의 톡: 대사 대신 "부재중 전화" 와 반응만.
  Widget _chat(StoryEvent ev, String partner, {bool missedCall = false}) {
    final s = c.state!;
    final t = context.tokens;
    final accent = t.accentFor(ev.character);
    final visible = missedCall
        ? const <Line>[]
        : ev.lines.take(c.revealed).toList();
    final waitLine = c.linesDone || missedCall ? null : ev.lines[c.revealed];
    final waiting = waitLine != null && waitLine.isWait && _waitLeft > 0;
    final total = ev.lines.length;
    final progress = total == 0 || missedCall ? 1.0 : c.revealed / total;

    return Scaffold(
      appBar: _header(context, ev, partner, accent, s.day, progress),
      body: Column(
        children: [
          // 대화 영역만 한 단 어두운(밝은) 바탕을 깔아 패널·헤더와 분리한다.
          Expanded(
            child: ColoredBox(
              color: t.chatBackground,
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.only(
                  top: AppSpace.sm,
                  bottom: AppSpace.lg,
                ),
                children: [
                  if (missedCall) _MissedCall(name: partner),
                  for (var i = 0; i < visible.length; i++)
                    ChatBubble(
                      line: visible[i],
                      partnerName: partner,
                      accent: accent,
                      isFirstOfGroup:
                          i == 0 ||
                          _speakerKey(visible[i - 1], partner) !=
                              _speakerKey(visible[i], partner),
                      isLastOfGroup:
                          i == visible.length - 1 ||
                          _speakerKey(visible[i + 1], partner) !=
                              _speakerKey(visible[i], partner),
                    ),
                  if (c.lastOutcome != null && _picked != null)
                    ChatBubble(
                      line: Line(who: 'me', text: _picked!),
                      partnerName: partner,
                      accent: accent,
                      isFirstOfGroup:
                          visible.isEmpty ||
                          _speakerKey(visible.last, partner) != '#me',
                    ),
                  if (c.lastOutcome != null) ...[
                    for (final (i, l) in c.lastReply.take(_replyShown).indexed)
                      ChatBubble(
                        line: l,
                        partnerName: partner,
                        accent: accent,
                        isFirstOfGroup:
                            i == 0 ||
                            _speakerKey(c.lastReply[i - 1], partner) !=
                                _speakerKey(l, partner),
                      ),
                    if (_replyShown < c.lastReply.length) const _TypingBubble(),
                  ],
                  if (waiting)
                    _WaitingBlock(
                      secondsLeft: _waitLeft,
                      secondsTotal: waitLine.wait,
                      onSkip: _skipWait,
                    )
                  else if (!c.linesDone && !missedCall)
                    const _TypingBubble(),
                ],
              ),
            ),
          ),
          // 결과 패널은 상대 반응을 다 보여 준 뒤에 올린다. 대화의 끝을 먼저 읽게 한다.
          if (c.lastOutcome != null)
            _replyShown >= c.lastReply.length
                ? _ResultPanel(c: c)
                : const SizedBox.shrink()
          else if (c.linesDone)
            _ChoicePanel(c: c, onPicked: (text) => _picked = text),
        ],
      ),
    );
  }

  /// 상대 · 제목 · 날짜 · 대화 진행도를 한 줄에 정리한 헤더.
  PreferredSizeWidget _header(
    BuildContext context,
    StoryEvent ev,
    String partner,
    CharacterAccent accent,
    int day,
    double progress,
  ) {
    final scheme = context.scheme;
    final t = context.tokens;
    final hasPartner = partner.isNotEmpty;

    return AppBar(
      titleSpacing: AppSpace.lg,
      title: Row(
        children: [
          if (hasPartner) ...[
            _AvatarDot(name: partner, accent: accent),
            const SizedBox(width: AppSpace.sm),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (hasPartner) ...[
                    TextSpan(text: partner, style: context.text.titleLarge),
                    // 구분점도 글자다. 대비 기준(4.5:1)을 넘는 2차색을 쓴다.
                    TextSpan(
                      text: '  ·  ',
                      style: context.text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  TextSpan(
                    text: ev.title,
                    style: (hasPartner
                        ? context.text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          )
                        : context.text.titleLarge),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpace.sm),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: AppSpace.xs,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: AppRadius.rPill,
              ),
              child: Text(
                'D+$day',
                style: t.numericSmall.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(AppSpace.xs),
        child: AppProgressBar(
          value: progress,
          height: AppSpace.xs,
          semanticLabel: '대화 진행',
          // 상대가 없는 독백 이벤트는 강조색이 중립(거의 검정)이라 선이 무겁다.
          fill: hasPartner ? accent.base : t.systemLine,
        ),
      ),
    );
  }
}

/// 상대 이니셜 원형. 사진 대신 강조색 한 글자로 누구인지 알린다(§4.3).
class _AvatarDot extends StatelessWidget {
  final String name;
  final CharacterAccent accent;
  const _AvatarDot({required this.name, required this.accent});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: AppSpace.xxxl,
      height: AppSpace.xxxl,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.container,
        borderRadius: AppRadius.rPill,
        border: Border.all(color: accent.base, width: AppBorderWidth.hairline),
      ),
      child: Text(
        name.substring(0, 1),
        maxLines: 1,
        style: context.text.labelMedium?.copyWith(color: accent.onContainer),
      ),
    ),
  );
}

/// 거절한 전화 자리 표시. 시스템 줄과 같은 중립 pill 이되 아이콘을 붙이고 글자는
/// 본문 2차색(`onSurfaceVariant`)으로 둔다 — 이 줄은 장식이 아니라 사건이라 읽혀야 한다.
class _MissedCall extends StatelessWidget {
  final String name;
  const _MissedCall({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fg = scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.xs + 2,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: AppRadius.rPill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_missed, size: 14, color: fg),
              const SizedBox(width: AppSpace.xs),
              Flexible(
                child: Text(
                  name.isEmpty ? '부재중 전화' : '부재중 전화 · $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 타이핑 중 표시. 상대 말풍선과 같은 껍데기라 "다음 줄이 오는 중" 으로 읽힌다.
///
/// 문구 '…' 는 고정이다(§4.1 이벤트 화면 테스트). 깜빡이는 반복 애니메이션은
/// 넣지 않는다 — 읽는 흐름을 방해하고 동작 줄이기 설정과도 충돌한다.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpace.md,
        right: AppSpace.md,
        top: AppSpace.sm,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: AppInsets.bubble,
          decoration: BoxDecoration(
            color: t.bubbleTheirs,
            borderRadius: AppRadius.bubble(mine: false),
            border: Border.all(
              color: t.bubbleBorder,
              width: AppBorderWidth.hairline,
            ),
          ),
          child: Text(
            '…',
            style: context.text.titleMedium?.copyWith(color: t.systemLine),
          ),
        ),
      ),
    );
  }
}

/// 읽씹 대기 연출. 중립 pill 안에서 숫자가 줄고, 아래 막대가 남은 시간을 그린다.
///
/// 카운트다운 문구는 숫자를 포함한 **하나의 Text** 여야 한다(테스트 고정).
/// 자리수가 흔들리지 않도록 tabular 숫자를 쓴다.
class _WaitingBlock extends StatelessWidget {
  final int secondsLeft;
  final int secondsTotal;
  final Future<void> Function() onSkip;

  const _WaitingBlock({
    required this.secondsLeft,
    required this.secondsTotal,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final base = context.text.labelSmall ?? const TextStyle();
    final left = secondsTotal <= 0
        ? 0.0
        : (secondsLeft / secondsTotal).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xl,
        vertical: AppSpace.md,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.xs + 2,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: AppRadius.rPill,
            ),
            child: Text(
              '읽음 · $secondsLeft초째 답이 없다',
              textAlign: TextAlign.center,
              style: AppTypography.tabular(base.copyWith(color: t.systemLine)),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          // 기다림의 길이를 형태로도 보여 준다. 색만으로 말하지 않는다.
          AppProgressBar(
            value: left,
            height: AppSpace.xs,
            semanticLabel: '답장 대기 남은 시간',
            fill: t.systemLine,
          ),
          const SizedBox(height: AppSpace.xs),
          TextButton.icon(
            onPressed: onSkip,
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('광고 보고 기다리지 않기'),
          ),
        ],
      ),
    );
  }
}

/// 선택지 패널. 대화와 같은 세계에 있되 한 단 위로 올라온 종이처럼 보인다.
///
/// 선택지는 `ChoiceButton` 하나로 통일한다. 내부가 `OutlinedButton` 이고
/// 이 영역에 다른 `OutlinedButton` 이 없어야 한다(§4.1).
class _ChoicePanel extends StatelessWidget {
  final GameController c;

  /// 선택이 확정되기 직전에 부른다. 화면이 내 말풍선을 그리는 데만 쓴다.
  final ValueChanged<String> onPicked;

  /// 통화 중이면 `decline` 선택지(= 거절 버튼)를 숨긴다.
  final bool hideDecline;
  const _ChoicePanel({
    required this.c,
    required this.onPicked,
    this.hideDecline = false,
  });

  /// 미니게임이 붙은 선택지는 먼저 게임을 돌리고 그 결과로 성패를 정한다.
  Future<void> _pick(BuildContext context, int index) async {
    final ev = c.current!;
    final id = ev.choices[index].minigame;
    if (id == null) {
      onPicked(ev.choices[index].text);
      c.choose(index);
      return;
    }
    final result = await playMinigame(
      context,
      id,
      MinigameContext(state: c.state!, partner: c.characterOf(ev.character)),
    );
    // 미니게임 도중 컨트롤러가 갱신돼도 지워지지 않게 결과 직전에 넘긴다.
    onPicked(ev.choices[index].text);
    c.choose(
      index,
      minigameSuccess: result.success,
      minigameCritical: result.critical,
      note: result.message,
    );
  }

  /// 우측 짧은 라벨: 미니게임 이름 또는 성공 확률. 잠긴 선택지는 이유만 보여 준다.
  String? _trailingLabel(ChoiceView v) {
    if (v.locked) return null;
    final mg = v.choice.minigame;
    if (mg != null) return minigameLabels[mg] ?? '미니게임';
    final chance = v.choice.chance;
    if (chance == null) return null;
    return c.onFire ? '${(chance + 20).clamp(0, 100)}%' : '$chance%';
  }

  /// 미니게임은 브랜드, 물올라 보정된 확률은 성공, 나머지는 중립.
  AppTone _trailingTone(ChoiceView v) {
    if (v.choice.minigame != null) return AppTone.brand;
    if (v.choice.chance != null && c.onFire) return AppTone.success;
    return AppTone.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final ev = c.current!;
    final choices = [
      for (final v in c.choices)
        if (!(hideDecline && v.choice.decline)) v,
    ];

    return BottomPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < choices.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == choices.length - 1 ? 0 : AppSpace.listGap,
              ),
              child: ChoiceButton(
                text: choices[i].choice.text,
                onPressed: choices[i].locked
                    ? null
                    : () => _pick(context, choices[i].index),
                lockedReason: choices[i].locked ? choices[i].reason : null,
                leadingIcon: choices[i].locked
                    ? Icons.lock_outline
                    : choices[i].choice.minigame != null
                    ? Icons.sports_esports_outlined
                    : null,
                trailingLabel: _trailingLabel(choices[i]),
                trailingTone: _trailingTone(choices[i]),
                recommended: c.hintIndex == choices[i].index,
              ),
            ),
          // 힌트는 선택지보다 한 단 아래. 광고 제안이 선택을 밀어내지 않게 한다.
          if (ev.hint != null && c.hintIndex == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final ok = await AdManager.instance.showRewarded();
                    if (ok) c.revealHint();
                  },
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                  label: const Text('태현에게 물어보기 (광고)'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 결과 패널. 크리티컬·성공·실패를 배경 톤 + 아이콘 + 문구 3중으로 알린다(§2.3).
class _ResultPanel extends StatelessWidget {
  final GameController c;
  const _ResultPanel({required this.c});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final o = c.lastOutcome!;

    final tone = o.critical
        ? AppTone.brand
        : !o.success
        ? AppTone.danger
        : AppTone.neutral;
    // 패널 배경이 톤에 따라 바뀌므로 글자색도 그 배경 위의 색으로 맞춘다.
    final fg = o.critical
        ? scheme.onPrimaryContainer
        : !o.success
        ? t.onDangerContainer
        : scheme.onSurface;
    final headline = o.critical
        // 초반에는 초반 가속과 겹쳐 2배가 넘으므로 배수를 적지 않는다. 실제 수치는 아래 칩에 있다.
        ? (o.delta.affection.values.any((v) => v > 0) ? '크리티컬! 호감 폭발' : '크리티컬!')
        : !o.success
        ? '실패…'
        : o.comboStarted
        ? '물올랐다!'
        : '성공';
    final icon = o.critical
        ? Icons.auto_awesome
        : !o.success
        ? Icons.error_outline
        : o.comboStarted
        ? Icons.local_fire_department
        : Icons.check_circle_outline;

    final parts = <_DeltaPart>[
      for (final e in o.delta.stats.entries)
        _DeltaPart(
          '${Stat.label(e.key)} ${signed(e.value)}',
          good: e.key == Stat.stress ? e.value < 0 : e.value > 0,
          up: e.value > 0,
        ),
      for (final e in o.delta.affection.entries)
        _DeltaPart(
          '${c.characterName(e.key)} 호감 ${signed(e.value)}',
          good: e.value > 0,
          up: e.value > 0,
        ),
      for (final e in o.delta.trust.entries)
        _DeltaPart(
          '${c.characterName(e.key)} 신뢰 ${signed(e.value)}',
          good: e.value > 0,
          up: e.value > 0,
        ),
    ];

    return BottomPanel(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  headline,
                  style: context.text.titleMedium?.copyWith(color: fg),
                ),
              ),
              if (o.combo > 0) ...[
                const SizedBox(width: AppSpace.sm),
                ComboBadge(combo: o.combo, onFire: o.combo >= 3, dense: true),
              ],
            ],
          ),
          if (o.comboBroken)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Row(
                children: [
                  Icon(Icons.trending_down, size: 14, color: fg),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    '콤보 끊김',
                    style: context.text.labelMedium?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          if (c.minigameNote != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Text(
                c.minigameNote!,
                style: context.text.bodyMedium?.copyWith(color: fg),
              ),
            ),
          const SizedBox(height: AppSpace.md),
          // 변화량은 색 + 부호 + 화살표 3중. 한 줄 문장 나열보다 눈에 먼저 든다.
          if (parts.isEmpty)
            Text('변화 없음', style: context.text.bodyMedium?.copyWith(color: fg))
          else
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [for (final p in parts) _DeltaChip(part: p)],
            ),
          if (o.delta.album != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.photo_album_outlined, size: 16, color: fg),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      '흑역사 앨범에 추가: ${o.delta.album}',
                      style: context.text.bodySmall?.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.lg),
          // 되돌리기(광고)는 구제책이지 주된 길이 아니다. 조용한 텍스트 버튼으로
          // 1차 버튼 위에 두어 "계속" 을 가리거나 밀어내지 않게 한다.
          if (c.canOfferUndo)
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final ok = await AdManager.instance.showRewarded();
                  if (ok) c.undoChoice();
                },
                icon: const Icon(Icons.replay, size: 18),
                // 톤 배경 위에서도 대비를 지키기 위해 전경색만 맞춘다.
                style: TextButton.styleFrom(foregroundColor: fg),
                label: const Text('10초 전으로 (광고)'),
              ),
            ),
          if (c.canOfferUndo) const SizedBox(height: AppSpace.sm),
          FilledButton(
            onPressed: c.continueAfterChoice,
            child: const Text('계속'),
          ),
        ],
      ),
    );
  }
}

/// 결과 한 항목. 문자열은 가공하지 않고 방향만 따로 들고 있다.
@immutable
class _DeltaPart {
  final String text;

  /// 이로운 변화인지. 색을 정한다.
  final bool good;

  /// 수치가 올랐는지. 화살표 방향을 정한다(스트레스 +2 는 ↑ + 위험색).
  final bool up;
  const _DeltaPart(this.text, {required this.good, required this.up});
}

/// 변화량 칩. 색 + 부호(문자열에 이미 있음) + 화살표 아이콘으로 방향을 말한다.
class _DeltaChip extends StatelessWidget {
  final _DeltaPart part;
  const _DeltaChip({required this.part});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = t.deltaColor(good: part.good);
    // 결과 패널 배경이 톤(로즈·위험)으로 바뀌어도 의미색 대비가 무너지지 않게
    // 칩은 항상 가장 밝은(다크: 가장 어두운) 표면 위에 올린다.
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerLowest,
        borderRadius: AppRadius.rSm,
        border: Border.all(color: color, width: AppBorderWidth.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            part.up ? Icons.arrow_upward : Icons.arrow_downward,
            size: 13,
            color: color,
          ),
          const SizedBox(width: AppSpace.xxs),
          Text(part.text, style: t.numericSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}
