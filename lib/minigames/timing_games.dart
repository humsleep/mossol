import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../ui/design_system.dart';
import '../ui/widgets.dart';
import 'minigame.dart';

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
  final double critWidth;
  final void Function(double value) onStop;

  const _SweepBar({
    required this.speed,
    required this.zone,
    required this.zoneVisible,
    required this.onStop,
    this.critWidth = 0.25,
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
                      Positioned(
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
                                color: scheme.onSurface,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: needleW,
                              height: needleH,
                              decoration: BoxDecoration(
                                color: scheme.onSurface,
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
                  child: Text(
                    '화면 아무 데나 눌러서 멈추기',
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

/// 1. 답장 타이밍 슬라이더 — 눈치
class ReplyTimingGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const ReplyTimingGame({super.key, required this.ctx, required this.done});

  @override
  State<ReplyTimingGame> createState() => _ReplyTimingGameState();
}

class _ReplyTimingGameState extends State<ReplyTimingGame> {
  MinigameResult? _result;

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final sense = ctx.stat(Stat.sense);
    final visible = sense >= 40;
    final zone = ctx.replyZone;
    return MinigameScaffold(
      title: '답장 타이밍',
      badge: '${Stat.label(Stat.sense)} $sense',
      instruction: visible
          ? '${ctx.partnerName}이(가) 좋아하는 속도 구간이 보인다. 진한 칸이 크리티컬.'
          : '눈치가 40을 넘으면 상대가 좋아하는 구간이 보인다. 지금은 감으로.',
      result: _result,
      onFinished: () => widget.done(_result!),
      child: _SweepBar(
        speed: 1 + sense / 120,
        zone: zone,
        zoneVisible: visible,
        onStop: _judge,
      ),
    );
  }

  void _judge(double v) {
    final zone = widget.ctx.replyZone;
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
  MinigameResult? _result;
  late final double _half = 0.09 + widget.ctx.stat(Stat.esteem) / 420;

  @override
  Widget build(BuildContext context) {
    return MinigameScaffold(
      title: '결심의 순간',
      badge: '${Stat.label(Stat.esteem)} ${widget.ctx.stat(Stat.esteem)}',
      instruction:
          '자존감이 높을수록 안전 구간이 넓어진다. '
          '지금 구간 폭 ${(_half * 200).round()}%.',
      result: _result,
      onFinished: () => widget.done(_result!),
      child: _SweepBar(
        speed: 1.6,
        zone: [0.5 - _half, 0.5 + _half],
        zoneVisible: true,
        critWidth: 0.3,
        onStop: _judge,
      ),
    );
  }

  void _judge(double v) {
    final d = (v - 0.5).abs();
    final ok = d <= _half;
    final crit = d <= _half * 0.15;
    setState(() {
      _result = MinigameResult(
        success: ok,
        critical: crit,
        score: ok ? 1 : 0,
        message: crit
            ? '손이 떨리지 않았다.'
            : ok
            ? '해냈다. 목소리가 조금 갈라졌지만.'
            : '말이 목에서 걸렸다.',
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

class _DeleteFastGameState extends State<DeleteFastGame> {
  static const _hold = Duration(milliseconds: 550);
  late final int _readMs = 1800 + Random().nextInt(3200);
  final _sw = Stopwatch()..start();
  Timer? _tick, _readTimer, _holdTimer;
  MinigameResult? _result;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted && _result == null) setState(() {});
    });
    _readTimer = Timer(Duration(milliseconds: _readMs), () {
      if (_result == null) {
        _finish(const MinigameResult.miss('읽음 1이 사라졌다. 상대가 봤다.'));
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _readTimer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _finish(MinigameResult r) {
    _readTimer?.cancel();
    _holdTimer?.cancel();
    _tick?.cancel();
    if (mounted) setState(() => _result = r);
  }

  void _down() {
    if (_result != null) return;
    setState(() => _holding = true);
    _holdTimer = Timer(_hold, () {
      final ms = _sw.elapsedMilliseconds;
      _finish(
        MinigameResult(
          success: true,
          critical: ms < 1500,
          score: 1,
          message: ms < 1500 ? '1.5초 만에 지웠다. 손이 빨랐다.' : '아슬아슬하게 지웠다.',
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
    final elapsed = _sw.elapsedMilliseconds;
    final read = elapsed >= _readMs;
    // 조작 대상은 말풍선 하나다. 이벤트 화면과 같은 말풍선 토큰을 써서
    // "방금 내가 보낸 그 메시지" 로 읽히게 한다.
    final bubbleMax = MediaQuery.sizeOf(context).width * 0.72;

    return MinigameScaffold(
      title: '삭제',
      instruction: '메시지를 길게 눌러 삭제한다. 상대가 읽기 전에.',
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
                    child: Text(
                      '야 서연 선배 오늘 진짜 멋있지 않았냐',
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
