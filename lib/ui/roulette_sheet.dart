import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../engine/event_engine.dart';
import '../engine/models.dart';
import '../game_controller.dart';
import 'design_system.dart';
import 'keep_all.dart';

/// 하루 시작 전 럭키 룰렛. 결과가 나쁘면 광고로 한 번 더 돌릴 수 있다.
///
/// 규격: docs/DESIGN_SYSTEM.md §2.7.
/// - 주인공은 결과 슬롯 카드 하나. 제목·설명·버튼은 배경으로 물러난다.
/// - 결과의 좋고 나쁨을 색만이 아니라 아이콘(상승/하락)과 부호로 함께 말한다.
/// - 회전 중에는 불투명도를 내리지 않고 중립 표면 + 2차 글자색으로 물러난다.
/// - 닫을 수 없는 시트이므로 드래그 핸들을 두지 않는다(테마 기본값).
class RouletteSheet extends StatefulWidget {
  final GameController c;
  const RouletteSheet({super.key, required this.c});

  static Future<void> show(BuildContext context, GameController c) =>
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        // 글자 확대 1.3배에서도 내용이 9/16 높이에 잘리지 않도록 내용 높이를 따른다.
        isScrollControlled: true,
        builder: (_) => RouletteSheet(c: c),
      );

  @override
  State<RouletteSheet> createState() => _RouletteSheetState();
}

class _RouletteSheetState extends State<RouletteSheet>
    with SingleTickerProviderStateMixin {
  /// 릴이 도는 시간. 연출이 아니라 하루를 여는 게임의 박자이고
  /// 위젯 테스트가 기다리는 시간이라 AppMotion 단계가 아닌 상수로 둔다.
  static const Duration _spinBeat = Duration(milliseconds: 1400);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: _spinBeat,
  );
  int? _slot;
  bool _spinning = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _run(int Function() action) async {
    // 동작 줄이기: 중간 프레임 없이 결과만 보여 준다(§1.10).
    _spin.duration = AppMotion.reduced(context) ? Duration.zero : _spinBeat;
    setState(() => _spinning = true);
    await _spin.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _slot = action();
      _spinning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final slots = EventEngine.rouletteSlots;
    final slot = _slot;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xxl,
          AppSpace.xl,
          AppSpace.xxl,
          AppSpace.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '오늘의 운',
              textAlign: TextAlign.center,
              style: context.text.titleLarge,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(keepAll('하루에 한 번. 결과가 마음에 안 들면 광고로 한 번 더.'),
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpace.xl),
            AnimatedBuilder(
              animation: _spin,
              builder: (context, _) {
                if (slot != null && !_spinning) {
                  final e = slots[slot];
                  return _SlotCard(
                    title: e.$1,
                    sub: e.$3,
                    effects: e.$2,
                    phase: _SlotPhase.result,
                  );
                }
                if (!_spinning) {
                  // 돌리기 전에는 결과처럼 보이면 안 된다.
                  return const _SlotCard(
                    title: '?',
                    sub: '돌려야 나온다',
                    effects: {},
                    phase: _SlotPhase.idle,
                  );
                }
                // 릴은 감속하며 지나간다. 값은 보여 주기용일 뿐 판정과 무관하다.
                final t = AppMotion.curve(
                  context,
                  AppMotion.standard,
                ).transform(_spin.value);
                final e = slots[(t * 40).floor() % slots.length];
                return _SlotCard(
                  title: e.$1,
                  sub: e.$3,
                  effects: e.$2,
                  phase: _SlotPhase.spinning,
                );
              },
            ),
            const SizedBox(height: AppSpace.xl),
            if (slot == null)
              FilledButton(
                onPressed: _spinning ? null : () => _run(widget.c.spinRoulette),
                child: const Text('돌리기'),
              )
            else ...[
              // 하루를 여는 1차 행동이 위, 광고 제안은 그 아래에 따로 둔다.
              // 광고 버튼을 1차 버튼과 같은 무게로 나란히 두면 오인 탭을 노린
              // 배치가 된다.
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('시작'),
              ),
              if (widget.c.canUseRerollTicket) ...[
                // 7일 연속 출석으로 받은 재도전권. 광고 없이 한 번 더.
                const SizedBox(height: AppSpace.md),
                OutlinedButton.icon(
                  onPressed: _spinning
                      ? null
                      : () => _run(() {
                            // 티켓 차감은 비동기지만 결과 칸은 즉시 정해진다.
                            final done = widget.c.useRerollTicket();
                            unawaited(done);
                            return widget.c.rouletteSlot!;
                          }),
                  icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                  label: Text(keepAll('재도전권 사용 (${widget.c.rerollTickets}장)')),
                ),
              ] else if (widget.c.canRerollRoulette) ...[
                const SizedBox(height: AppSpace.md),
                OutlinedButton.icon(
                  onPressed: _spinning
                      ? null
                      : () async {
                          final ok = await AdManager.instance.showRewarded();
                          if (ok && mounted) await _run(widget.c.rerollRoulette);
                        },
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('한 번 더 (광고)'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// 슬롯 카드가 지금 무엇을 말하고 있는지.
enum _SlotPhase {
  /// 아직 돌리지 않았다.
  idle,

  /// 릴이 도는 중. 결과로 읽히면 안 된다.
  spinning,

  /// 확정된 결과.
  result,
}

/// 결과 슬롯 카드. 이 화면의 주인공이다.
///
/// 결과가 확정될 때만 의미색(성공/위험)과 상승·하락 아이콘이 함께 켜진다.
/// 회전 중에는 불투명도를 내리는 대신 중립 표면과 2차 글자색으로 물러나
/// 대비를 유지한다(§2.7).
class _SlotCard extends StatelessWidget {
  final String title;
  final String sub;
  final Map<String, int> effects;
  final _SlotPhase phase;

  const _SlotCard({
    required this.title,
    required this.sub,
    required this.effects,
    required this.phase,
  });

  /// 스트레스만 오르면 나쁘다. 하나라도 이로우면 좋은 칸으로 본다.
  static bool _isGood(String key, int v) => key == Stat.stress ? v < 0 : v > 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final result = phase == _SlotPhase.result;
    final good = effects.entries.any((e) => _isGood(e.key, e.value));

    final Color bg;
    final Color fg;
    final Color line;
    if (!result) {
      // 다크 시트 배경이 High 라 카드는 한 단 더 위(§2.7).
      bg = scheme.surfaceContainerHighest;
      fg = phase == _SlotPhase.spinning
          ? scheme.onSurfaceVariant
          : scheme.onSurface;
      line = scheme.outlineVariant;
    } else if (good) {
      bg = t.successContainer;
      fg = t.onSuccessContainer;
      line = t.success;
    } else {
      bg = t.dangerContainer;
      fg = t.onDangerContainer;
      line = t.danger;
    }

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (result) ...[
              // 좋고 나쁨을 색 말고 형태로도 알린다.
              Icon(
                good ? Icons.trending_up : Icons.trending_down,
                size: 22,
                color: fg,
              ),
              const SizedBox(width: AppSpace.sm),
            ],
            Flexible(
              child: Text(
                keepAll(title),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: (result
                        ? context.text.headlineSmall
                        : context.text.headlineMedium)
                    ?.copyWith(color: fg),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          keepAll(sub),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(
            color: result ? fg : scheme.onSurfaceVariant,
          ),
        ),
        if (effects.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpace.md,
            runSpacing: AppSpace.xs,
            children: [
              for (final e in effects.entries)
                _EffectChip(
                  label:
                      '${Stat.label(e.key)} ${e.value > 0 ? '+' : ''}${e.value}',
                  good: _isGood(e.key, e.value),
                  up: e.value > 0,
                  muted: !result,
                ),
            ],
          ),
        ],
      ],
    );

    if (result) {
      // 결과 공개는 이 화면에서 유일하게 튀는 순간이다. 한 번만, 짧게.
      content = TweenAnimationBuilder<double>(
        key: ValueKey(title),
        tween: Tween<double>(begin: 0.96, end: 1),
        duration: AppMotion.base(context),
        curve: AppMotion.curve(context, AppMotion.emphasized),
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: content,
      );
    }

    return AnimatedContainer(
      duration: AppMotion.base(context),
      curve: AppMotion.curve(context),
      width: double.infinity,
      // 고정 높이 대신 최소 높이. 글자를 키우면 카드가 늘어난다(§2.7).
      constraints: const BoxConstraints(minHeight: 132),
      alignment: Alignment.center,
      padding: AppInsets.card,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: line, width: AppBorderWidth.hairline),
      ),
      child: content,
    );
  }
}

/// 슬롯이 주는 변화 하나. 색 + 부호 + 화살표 3중으로 방향을 말한다.
class _EffectChip extends StatelessWidget {
  final String label;
  final bool good;

  /// 수치가 오르는지. 화살표 방향만 정한다(스트레스 -20 은 ↓ + 성공색).
  final bool up;

  /// 회전 중처럼 아직 결과가 아닐 때. 의미색을 켜지 않는다.
  final bool muted;

  const _EffectChip({
    required this.label,
    required this.good,
    required this.up,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = muted
        ? context.scheme.onSurfaceVariant
        : t.deltaColor(good: good);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward : Icons.arrow_downward,
          size: 14,
          color: color,
        ),
        const SizedBox(width: AppSpace.xxs),
        Text(label, style: t.numericSmall.copyWith(color: color)),
      ],
    );
  }
}
