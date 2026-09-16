import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/models.dart';
import 'minigame.dart';

/// 좌우로 움직이는 마커를 원하는 구간에서 멈추는 공용 위젯.
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
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (1600 / widget.speed).round()),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final zone = widget.zone;
    final mid = (zone[0] + zone[1]) / 2;
    final half = (zone[1] - zone[0]) * widget.critWidth / 2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _c.stop();
        widget.onStop(_c.value);
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, box) => SizedBox(
                  height: 72,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 28,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      if (widget.zoneVisible) ...[
                        Positioned(
                          top: 28,
                          left: box.maxWidth * zone[0],
                          width: box.maxWidth * (zone[1] - zone[0]),
                          child: Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 28,
                          left: box.maxWidth * (mid - half),
                          width: box.maxWidth * half * 2,
                          child: Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                      AnimatedBuilder(
                        animation: _c,
                        builder: (context, _) => Positioned(
                          left: (box.maxWidth - 4) * _c.value,
                          top: 14,
                          child: Container(
                            width: 4,
                            height: 44,
                            decoration: BoxDecoration(
                              color: scheme.onSurface,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '화면 아무 데나 눌러서 멈추기',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
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
    final scheme = Theme.of(context).colorScheme;
    final elapsed = _sw.elapsedMilliseconds;
    return MinigameScaffold(
      title: '삭제',
      instruction: '메시지를 길게 눌러 삭제한다. 상대가 읽기 전에.',
      result: _result,
      child: CenteredScrollColumn(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTapDown: (_) => _down(),
              onTapUp: (_) => _up(),
              onTapCancel: _up,
              child: AnimatedScale(
                scale: _holding ? 0.94 : 1,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '야 서연 선배 오늘 진짜 멋있지 않았냐',
                    style: TextStyle(color: scheme.onPrimary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              elapsed < _readMs ? '읽지 않음' : '읽음',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 28),
          if (_holding)
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  color: scheme.error,
                ),
              ),
            )
          else
            Text('길게 누르기', style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
      onFinished: () => widget.done(_result!),
    );
  }
}
