import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../ui/design_system.dart';
import '../ui/widgets.dart';
import 'minigame.dart';
import '../ui/keep_all.dart';

/// 좌우로 움직이는 마커를 원하는 구간에서 멈추는 공용 위젯.
///
/// 조작 대상은 **마커 하나**다. 그래서 마커에만 머리(원)를 달아 굵게 세우고,
/// 트랙과 구간은 뒤로 물린다: 트랙은 `gaugeTrack`, 안전 구간은
/// `primaryContainer`, 크리티컬 구간은 `primary` 로 세 단계를 만든다.
/// 반복 애니메이션은 판정에 필요하므로 동작 줄이기 설정에서도 멈추지 않는다
/// (규격서 §1.10).
class _SweepBar extends StatefulWidget {
  final double speed;
  final List<double> zone;
  final bool zoneVisible;

  /// 진한 크리티컬 칸을 보여 줄지. [zoneVisible] 이 켜져도 이 값이 false 면
  /// 안전 구간만 보인다(답장 타이밍의 2단 공개 — `ReplyTimingGame` 참고).
  final bool critVisible;
  final double critWidth;
  final void Function(double value) onStop;

  /// 트랙 위에 얹는 상황 카드(무엇에 대고 타이밍을 재는지). 없으면 생략.
  final Widget? header;

  /// 판정이 끝난 뒤 멈춘 마커가 입을 톤. 판정은 부모가 하고 여기선 색만 받는다.
  /// null 이면 판정 전.
  final AppTone? outcome;

  const _SweepBar({
    required this.speed,
    required this.zone,
    required this.zoneVisible,
    required this.onStop,
    this.critVisible = true,
    this.critWidth = 0.25,
    this.outcome,
    this.header,
  });

  @override
  State<_SweepBar> createState() => _SweepBarState();
}

class _SweepBarState extends State<_SweepBar>
    with SingleTickerProviderStateMixin {
  /// 마커가 선 자리를 그대로 두기 위한 표시용 플래그. 판정과 무관하다.
  bool _stopped = false;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (1600 / widget.speed).round()),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _stop() {
    if (_stopped) return;
    _c.stop();
    setState(() => _stopped = true);
    // 탭 큐를 따로 내지 않는다 — 이 탭이 곧 판정이라 [MinigameScaffold] 의
    // 결과 큐가 같은 프레임에 나간다. 둘을 다 내면 소리가 겹친다(MinigameSfx 규칙 3).
    widget.onStop(_c.value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final t = context.tokens;
    final zone = widget.zone;
    final mid = (zone[0] + zone[1]) / 2;
    final half = (zone[1] - zone[0]) * widget.critWidth / 2;

    // 전부 간격 토큰에서 끌어온 치수다.
    const boxH = AppSpace.huge + AppSpace.xxxl; // 72
    const barH = AppSpace.lg; // 16
    const needleW = AppSpace.xs; // 4
    const needleH = AppSpace.minTouch; // 44
    const headD = AppSpace.md; // 12
    const barTop = (boxH - barH) / 2;
    const needleTop = (boxH - needleH - headD) / 2;
    // 멈춘 순간 마커가 결과 톤으로 물든다. 문구는 스캐폴드의 결과 배지가 함께 말한다.
    final needle = switch (widget.outcome) {
      AppTone.brand => scheme.primary,
      AppTone.success => t.success,
      AppTone.danger => t.danger,
      _ => scheme.onSurface,
    };

    return Semantics(
      container: true,
      button: true,
      label: '화면 아무 데나 눌러서 멈추기',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _stop,
        child: CenteredScrollColumn(
          padding: AppInsets.screenX,
          children: [
            if (widget.header != null) ...[
              widget.header!,
              const SizedBox(height: AppSpace.xxl),
            ],
            LayoutBuilder(
              builder: (context, box) => SizedBox(
                height: boxH,
                child: Stack(
                  children: [
                    // 트랙.
                    Positioned(
                      top: barTop,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: barH,
                        decoration: BoxDecoration(
                          color: t.gaugeTrack,
                          borderRadius: AppRadius.rSm,
                        ),
                      ),
                    ),
                    if (widget.zoneVisible) ...[
                      // 안전 구간.
                      Positioned(
                        top: barTop,
                        left: box.maxWidth * zone[0],
                        width: box.maxWidth * (zone[1] - zone[0]),
                        child: Container(
                          height: barH,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: AppRadius.rSm,
                          ),
                        ),
                      ),
                      // 크리티컬 구간. 안전 구간보다 한 단 진하다.
                      if (widget.critVisible) Positioned(
                        top: barTop,
                        left: box.maxWidth * (mid - half),
                        width: box.maxWidth * half * 2,
                        child: Container(
                          height: barH,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: AppRadius.rXs,
                          ),
                        ),
                      ),
                    ],
                    // 마커. 머리(원)를 달아 "이게 내가 멈출 것" 임을 드러낸다.
                    // 좌표는 원래 식을 그대로 두어 체감 속도가 바뀌지 않는다.
                    AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) => Positioned(
                        left:
                            (box.maxWidth - needleW) * _c.value +
                            needleW / 2 -
                            headD / 2,
                        top: needleTop,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: headD,
                              height: headD,
                              decoration: BoxDecoration(
                                color: needle,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: needleW,
                              height: needleH,
                              decoration: BoxDecoration(
                                color: needle,
                                borderRadius: AppRadius.rXs,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpace.sm),
                Flexible(
                  child: Text(keepAll('화면 아무 데나 눌러서 멈추기'),
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 결과를 마커 톤으로 옮긴다. 스캐폴드의 결과 배지와 같은 대응이다.
AppTone? _outcomeTone(MinigameResult? r) => r == null
    ? null
    : r.critical
    ? AppTone.brand
    : r.success
    ? AppTone.success
    : AppTone.danger;

/// 1. 답장 타이밍 슬라이더 — 눈치
class ReplyTimingGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const ReplyTimingGame({super.key, required this.ctx, required this.done});

  /// 안전 구간이 보이기 시작하는 눈치. **30 이다.**
  ///
  /// 40 이었다. 그런데 시작 눈치가 25(`config.json` `initialStats`)이고 이야기가
  /// 주는 눈치는 한 번에 +1~+3 이라, 40 까지는 눈치가 오르는 선택을 대여섯 번
  /// 골라야 닿는다. 이 미니게임이 가장 자주 붙어 있는 구간이 바로 그 앞이므로,
  /// **이 장치가 존재하는지도 모르는 채로 초반을 다 지나가게 돼 있었다.**
  ///
  /// 30 은 25 에서 +5 — 눈치가 오르는 선택 두세 번이면 닿는다. "눈치를 올리면
  /// 구간이 보인다" 를 초반에 한 번은 겪게 하려면 그 정도여야 하고, 그러면서도
  /// 시작값보다는 위라서 공짜로 주는 것이 아니다.
  static const senseToSeeZone = 30;

  /// 진한 크리티컬 칸까지 보이는 눈치. 옛 문턱(40)을 여기로 옮겼다 —
  /// 공개를 두 단으로 쪼개면 40 이 여전히 뭔가를 의미하고, 난이도도 그대로다.
  static const senseToSeeCrit = 40;

  @override
  State<ReplyTimingGame> createState() => _ReplyTimingGameState();
}

class _ReplyTimingGameState extends State<ReplyTimingGame> {
  /// (온 메시지, 이 메시지에 맞는 답장 속도 보정). 보정은 선호 구간을 앞뒤로
  /// 살짝 민다 — "자?" 에 30분 뒤 답하는 것과 "나 방금 사고났어" 에 30분 뒤
  /// 답하는 것이 같은 점수일 수는 없다.
  static const _messages = [
    ('자?', 0.0),
    ('오늘 고마웠어', 0.0),
    ('나 방금 사고 날 뻔했어', -0.12),
    ('밥 먹었어?', 0.05),
    ('우리 얘기 좀 하자', -0.08),
    ('아까 그 사진 뭐야 ㅋㅋㅋ', 0.08),
    ('내일 시간 어때?', 0.0),
    ('…', 0.1),
  ];

  MinigameResult? _result;

  late final (String, double) _msg =
      widget.ctx.vary.one('reply_timing', _messages);

  /// 이 판의 선호 구간. 캐릭터 구간을 메시지에 맞게 앞뒤로 민 것이다.
  late final List<double> _zone = () {
    final z = widget.ctx.replyZone;
    final shift = _msg.$2;
    final lo = (z[0] + shift).clamp(0.05, 0.85);
    final hi = (z[1] + shift).clamp(lo + 0.08, 0.95);
    return [lo.toDouble(), hi.toDouble()];
  }();

  /// 마커 속도. 눈치로 오르던 기존 식에 날짜 단계를 얹었다.
  late final double _speed =
      (1 + widget.ctx.stat(Stat.sense) / 120) *
      widget.ctx.vary.byPhase(const [0.95, 1.1, 1.25]);

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final t = context.tokens;
    final sense = ctx.stat(Stat.sense);
    final visible = sense >= ReplyTimingGame.senseToSeeZone;
    final critVisible = sense >= ReplyTimingGame.senseToSeeCrit;
    return MinigameScaffold(
      title: '답장 타이밍',
      badge: '${Stat.label(Stat.sense)} $sense',
      instruction: critVisible
          ? '${ctx.partnerName}이(가) 좋아하는 속도 구간이 보인다. 진한 칸이 크리티컬.'
          : visible
          ? '${ctx.partnerName}이(가) 좋아하는 구간이 보인다. '
                '눈치 ${ReplyTimingGame.senseToSeeCrit}을 넘으면 크리티컬 칸까지 보인다.'
          : '눈치가 ${ReplyTimingGame.senseToSeeZone}을 넘으면 상대가 좋아하는 구간이 보인다. 지금은 감으로.',
      result: _result,
      onFinished: () => widget.done(_result!),
      child: _SweepBar(
        speed: _speed,
        zone: _zone,
        zoneVisible: visible,
        critVisible: critVisible,
        outcome: _outcomeTone(_result),
        onStop: _judge,
        // 무엇에 답하는지 먼저 보여 준다. 막대만 있으면 2초 안에 목표를 읽을 수 없다.
        header: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
            ),
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
                keepAll(_msg.$1),
                style: t.bubbleText.copyWith(color: t.onBubbleTheirs),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _judge(double v) {
    final zone = _zone;
    final mid = (zone[0] + zone[1]) / 2;
    final half = (zone[1] - zone[0]) * 0.125;
    final inZone = v >= zone[0] && v <= zone[1];
    final crit = (v - mid).abs() <= half;
    setState(() {
      _result = MinigameResult(
        success: inZone,
        critical: crit,
        score: inZone ? 1 : 0,
        message: crit
            ? '완벽한 타이밍. 읽자마자 답이 왔다.'
            : inZone
            ? '적당한 간격이었다.'
            : v < zone[0]
            ? '너무 빨랐다. 기다린 티가 났다.'
            : '너무 늦었다. 상대가 먼저 접었다.',
      );
    });
  }
}

/// 7. 눈치 게이지 멈추기 — 자존감
class NerveGaugeGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const NerveGaugeGame({super.key, required this.ctx, required this.done});

  @override
  State<NerveGaugeGame> createState() => _NerveGaugeGameState();
}

class _NerveGaugeGameState extends State<NerveGaugeGame> {
  /// (제목, 무엇을 하려는 참인지, 성공 문구, 실패 문구).
  /// 33번 붙어 있는 미니게임이라 판마다 무대가 바뀌어야 한다.
  static const _scenes = [
    ('결심의 순간', '지금 말을 꺼낸다.', '해냈다. 목소리가 조금 갈라졌지만.', '말이 목에서 걸렸다.'),
    ('보내기 직전', '쓴 메시지를 보낸다.', '보냈다. 손가락이 먼저 움직였다.', '지웠다. 또 지웠다.'),
    ('전화 걸기', '번호를 누르고 통화를 건다.', '신호가 두 번 가고 받았다.', '누르기 직전에 껐다.'),
    ('손 내밀기', '손을 잡는다.', '잡았다. 상대도 힘을 줬다.', '허공에서 멈췄다.'),
    ('먼저 인사', '먼저 말을 건다.', '"안녕하세요" 가 나왔다.', '입만 뻥긋했다.'),
    ('한 발 더', '한 걸음 다가선다.', '거리가 줄었다.', '그 자리에 서 있었다.'),
  ];

  late final (String, String, String, String) _scene =
      widget.ctx.vary.one('nerve_gauge', _scenes);

  /// 안전 구간 반폭. 자존감으로 넓어지고 날짜 단계로 조금 좁아진다.
  late final double _half =
      (0.09 + widget.ctx.stat(Stat.esteem) / 420) *
      widget.ctx.vary.byPhase(const [1.15, 1.0, 0.88]);

  /// 구간 중심. 늘 한가운데면 눈을 감고도 맞는다. 판마다 조금씩 옮긴다.
  late final double _center = (0.5 + widget.ctx.vary.one('nerve_center',
      const [0.0, -0.13, 0.11, -0.07, 0.16, -0.17]))
      .clamp(_half + 0.04, 1 - _half - 0.04)
      .toDouble();

  /// 마커 속도.
  late final double _speed =
      widget.ctx.vary.one('nerve_speed', const [1.6, 1.35, 1.85, 2.1]) *
      widget.ctx.vary.byPhase(const [0.9, 1.0, 1.1]);

  MinigameResult? _result;

  @override
  Widget build(BuildContext context) {
    return MinigameScaffold(
      title: _scene.$1,
      badge: '${Stat.label(Stat.esteem)} ${widget.ctx.stat(Stat.esteem)}',
      instruction:
          '${_scene.$2} 자존감이 높을수록 안전 구간이 넓어진다. '
          '지금 구간 폭 ${(_half * 200).round()}%.',
      result: _result,
      onFinished: () => widget.done(_result!),
      child: _SweepBar(
        speed: _speed,
        zone: [_center - _half, _center + _half],
        zoneVisible: true,
        // 판정은 `d <= _half * 0.15` 다. 표시 폭 = 구간폭 × critWidth / 2 = _half × critWidth
        // 이므로 0.15 여야 진한 칸이 실제 크리티컬 범위와 일치한다(기존 0.3 은 두 배로 보였다).
        critWidth: 0.15,
        outcome: _outcomeTone(_result),
        onStop: _judge,
      ),
    );
  }

  void _judge(double v) {
    final d = (v - _center).abs();
    final ok = d <= _half;
    final crit = d <= _half * 0.15;
    setState(() {
      _result = MinigameResult(
        success: ok,
        critical: crit,
        score: ok ? 1 : 0,
        message: crit ? '손이 떨리지 않았다.' : (ok ? _scene.$3 : _scene.$4),
      );
    });
  }
}

/// 6. 5초 삭제 — 위기
class DeleteFastGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const DeleteFastGame({super.key, required this.ctx, required this.done});

  @override
  State<DeleteFastGame> createState() => _DeleteFastGameState();
}

class _DeleteFastGameState extends State<DeleteFastGame>
    with SingleTickerProviderStateMixin {
  static const _hold = Duration(milliseconds: 550);

  /// 지울 메시지. 판마다 다르다 — 상대가 누구든 매번 "야 서연 선배…" 가 뜨면
  /// 이 게임이 이야기와 상관없는 부속품으로 읽힌다.
  static const _messages = [
    '야 서연 선배 오늘 진짜 멋있지 않았냐',
    '아 그 사람 프사 내가 저장해 둠 ㅋㅋ',
    '솔직히 오늘 나 보려고 나온 거 같지 않냐',
    '야 나 오늘 고백할까',
    '이거 걔한테 보내면 안 되는 거 맞지?',
    '아까 걔 웃는 거 보고 진짜 심장 떨어짐',
  ];

  late final String _message = widget.ctx.vary.one('delete_fast', _messages);

  /// 상대가 읽기까지 남은 시간. 길게 누르는 데 [_hold] 가 필요하므로
  /// **최소한 그 두 배는 준다** — 예전 식(1.8~5.0초 무작위)은 1.8초가 걸리면
  /// 화면을 읽고 손을 대기도 전에 끝났고, 남은 시간이 화면에 없어서 왜 졌는지도
  /// 알 수 없었다(09 §1). 눈치가 높을수록 조금 더 벌고, 날이 갈수록 짧아진다.
  late final int _readMs = () {
    final v = widget.ctx.vary;
    final base = v.byPhase(const [3400, 3000, 2700]);
    final sense = widget.ctx.stat(Stat.sense) * 12;
    final jitter = v.one('delete_fast_ms', const [0, 250, 500, 750, 1000]);
    return base + sense + jitter;
  }();

  /// 상대가 읽기까지의 시계. 프레임으로 돈다([MinigameClock] 참고).
  /// 예전에는 막대(진짜 `Stopwatch`)와 마감(`Timer`, 테스트에서는 가짜 시계)이
  /// **서로 다른 시계**를 봐서 테스트 안에서 둘이 어긋났다.
  late final MinigameClock _clock = MinigameClock(
    vsync: this,
    limit: Duration(milliseconds: _readMs),
    onExpire: () =>
        _finish(const MinigameResult.miss('읽음 1이 사라졌다. 상대가 봤다.')),
  );
  Timer? _holdTimer;
  MinigameResult? _result;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _clock.addListener(_onTick);
  }

  void _onTick() {
    if (mounted && _result == null) setState(() {});
  }

  @override
  void dispose() {
    _clock
      ..removeListener(_onTick)
      ..dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _finish(MinigameResult r) {
    if (_result != null) return;
    _clock.stop();
    _holdTimer?.cancel();
    if (mounted) setState(() => _result = r);
  }

  void _down() {
    if (_result != null) return;
    // 손가락이 말풍선에 닿은 그 순간에 대답한다. 0.55초를 누르고 있어야 하는
    // 게임이라 "먹혔나?" 를 가장 오래 참아야 하는 자리다.
    MinigameSfx.tap();
    setState(() => _holding = true);
    _holdTimer = Timer(_hold, () {
      final ms = _clock.elapsedMs;
      // 크리티컬 기준은 고정 1.5초가 아니라 **남은 시간의 절반** 이다.
      // 마감이 판마다 다른데 기준만 고정이면 빨리 눌러도 안 되는 판이 생긴다.
      final fast = ms <= _readMs * 0.5;
      _finish(
        MinigameResult(
          success: true,
          critical: fast,
          score: 1,
          message: fast
              ? '${(ms / 1000).toStringAsFixed(1)}초 만에 지웠다. 손이 빨랐다.'
              : '아슬아슬하게 지웠다.',
        ),
      );
    });
  }

  void _up() {
    _holdTimer?.cancel();
    if (mounted && _result == null) setState(() => _holding = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final elapsed = _clock.elapsedMs;
    final read = elapsed >= _readMs;
    // 조작 대상은 말풍선 하나다. 이벤트 화면과 같은 말풍선 토큰을 써서
    // "방금 내가 보낸 그 메시지" 로 읽히게 한다.
    final bubbleMax = MediaQuery.sizeOf(context).width * 0.72;

    return MinigameScaffold(
      title: '삭제',
      instruction:
          '메시지를 ${(_hold.inMilliseconds / 1000).toStringAsFixed(1)}초 길게 눌러 삭제한다. '
          '위 막대가 다 닳으면 상대가 읽는다.',
      // 남은 시간을 보여 준다. 이 게임은 시계와 겨루는 게임인데 시계가 없었다.
      // 판이 끝나면 null = "시계가 멈췄다". 막대 자리는 그대로 남는다.
      timeLeft: _result == null ? _clock.left : null,
      result: _result,
      child: CenteredScrollColumn(
        padding: AppInsets.screenX,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: bubbleMax,
                minHeight: AppSpace.minTouch,
              ),
              child: GestureDetector(
                onTapDown: (_) => _down(),
                onTapUp: (_) => _up(),
                onTapCancel: _up,
                child: AnimatedScale(
                  scale: _holding ? 0.96 : 1,
                  duration: AppMotion.instant(context),
                  curve: AppMotion.curve(context),
                  child: Container(
                    padding: AppInsets.bubble,
                    decoration: BoxDecoration(
                      color: t.bubbleMine,
                      borderRadius: AppRadius.bubble(mine: true),
                    ),
                    child: Text(keepAll(_message),
                      style: t.bubbleText.copyWith(color: t.onBubbleMine),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          // 읽음 여부는 색만으로 말하지 않는다. 읽히면 아이콘이 함께 붙는다.
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (read) ...[
                  Icon(Icons.visibility_outlined, size: 14, color: t.danger),
                  const SizedBox(width: AppSpace.xxs),
                ],
                Text(
                  read ? '읽음' : '읽지 않음',
                  style: context.text.labelSmall?.copyWith(
                    color: read ? t.danger : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xxxl),
          // 누르는 동안 차오르는 막대. 판정에 쓰는 연출이라 동작 줄이기
          // 설정에서도 그대로 돈다(규격서 §1.10).
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.minTouch),
            child: Center(
              child: _holding
                  ? SizedBox(
                      width: AppSpace.huge * 3,
                      child: TweenAnimationBuilder<double>(
                        key: const ValueKey('hold'),
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: _hold,
                        builder: (context, v, _) => AppProgressBar(
                          value: v,
                          semanticLabel: '길게 누르기',
                          height: AppSpace.sm,
                          fill: t.danger,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text('길게 누르기', style: context.text.labelMedium),
                      ],
                    ),
            ),
          ),
        ],
      ),
      onFinished: () => widget.done(_result!),
    );
  }
}
