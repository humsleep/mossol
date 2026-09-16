import 'dart:math';

import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../engine/event_engine.dart';
import '../engine/models.dart';
import '../game_controller.dart';

/// 하루 시작 전 럭키 룰렛. 결과가 나쁘면 광고로 한 번 더 돌릴 수 있다.
class RouletteSheet extends StatefulWidget {
  final GameController c;
  const RouletteSheet({super.key, required this.c});

  static Future<void> show(BuildContext context, GameController c) =>
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => RouletteSheet(c: c),
      );

  @override
  State<RouletteSheet> createState() => _RouletteSheetState();
}

class _RouletteSheetState extends State<RouletteSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  int? _slot;
  bool _spinning = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _run(int Function() action) async {
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
    final scheme = Theme.of(context).colorScheme;
    final slots = EventEngine.rouletteSlots;
    final slot = _slot;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('오늘의 운', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '하루에 한 번. 결과가 마음에 안 들면 광고로 한 번 더.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 132,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, _) {
                  if (slot != null && !_spinning) {
                    final e = slots[slot];
                    return _SlotCard(
                      title: e.$1,
                      sub: e.$3,
                      effects: e.$2,
                      highlight: true,
                    );
                  }
                  if (!_spinning) {
                    // 돌리기 전에는 결과처럼 보이면 안 된다.
                    return const _SlotCard(
                      title: '?',
                      sub: '돌려야 나온다',
                      effects: {},
                    );
                  }
                  final t = Curves.easeOut.transform(_spin.value);
                  final i =
                      ((t * 40).floor() + Random().nextInt(2)) % slots.length;
                  final e = slots[i];
                  return _SlotCard(
                    title: e.$1,
                    sub: e.$3,
                    effects: e.$2,
                    dim: true,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            if (slot == null)
              FilledButton(
                onPressed: _spinning ? null : () => _run(widget.c.spinRoulette),
                child: const Text('돌리기'),
              )
            else
              Row(
                children: [
                  if (widget.c.canRerollRoulette)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _spinning
                            ? null
                            : () async {
                                final ok = await AdManager.instance
                                    .showRewarded();
                                if (ok) await _run(widget.c.rerollRoulette);
                              },
                        icon: const Icon(Icons.replay, size: 18),
                        label: const Text('한 번 더 (광고)'),
                      ),
                    ),
                  if (widget.c.canRerollRoulette) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('시작'),
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

class _SlotCard extends StatelessWidget {
  final String title;
  final String sub;
  final Map<String, int> effects;
  final bool highlight;
  final bool dim;

  const _SlotCard({
    required this.title,
    required this.sub,
    required this.effects,
    this.highlight = false,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final good = effects.entries.any(
      (e) => e.key == Stat.stress ? e.value < 0 : e.value > 0,
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: highlight
            ? (good ? scheme.primaryContainer : scheme.errorContainer)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Opacity(
        opacity: dim ? 0.6 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            if (effects.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                effects.entries
                    .map(
                      (e) =>
                          '${Stat.label(e.key)} ${e.value > 0 ? '+' : ''}${e.value}',
                    )
                    .join('  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
