import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../engine/models.dart';
import '../game_controller.dart';
import 'album_screen.dart';
import 'roulette_sheet.dart';
import 'widgets.dart';

/// 아침 행동 선택 화면. 하트 1개를 쓰고 하루를 시작한다.
class ActionScreen extends StatefulWidget {
  final GameController c;
  const ActionScreen({super.key, required this.c});

  @override
  State<ActionScreen> createState() => _ActionScreenState();
}

class _ActionScreenState extends State<ActionScreen> {
  GameController get c => widget.c;

  /// 룰렛 시트가 떠 있는 동안 컨트롤러가 갱신되면 didUpdateWidget 이 다시 불린다.
  /// 그때 시트를 또 띄우면 두 장이 겹치므로 열려 있는 동안은 막는다.
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    // 하루의 첫 화면에서 룰렛을 먼저 돌린다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRoulette());
  }

  @override
  void didUpdateWidget(ActionScreen old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRoulette());
  }

  Future<void> _maybeRoulette() async {
    if (_sheetOpen || !mounted || !c.canSpinRoulette) return;
    _sheetOpen = true;
    try {
      await RouletteSheet.show(context, c);
    } finally {
      _sheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('D+${s.day}  ·  ${s.chapter(c.config)}장'),
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: c.goHome,
        ),
        actions: [
          IconButton(
            tooltip: '앨범',
            icon: const Icon(Icons.photo_album_outlined),
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => AlbumScreen(c: c))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: HeartsRow(
                  hearts: c.hearts,
                  max: c.config.maxHearts,
                  nextIn: c.nextHeartIn,
                ),
              ),
              if (c.combo > 0) ...[
                const SizedBox(width: 8),
                ComboBadge(combo: c.combo, onFire: c.onFire),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (s.lastCliffhanger != null)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '어젯밤: ${s.lastCliffhanger}',
                  style: TextStyle(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          StatBars(state: s),
          const SizedBox(height: 16),
          Text('관계', style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final ch in c.bundle.characters)
                if (!ch.hidden || s.affectionOf(ch.id) > 0)
                  Chip(
                    label: Text(
                      '${ch.name} ♥${s.affectionOf(ch.id)} ✓${s.trustOf(ch.id)}',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
            ],
          ),
          const SizedBox(height: 20),
          Text('오늘 아침에 뭘 할까', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final a in c.config.actions)
            Card(
              child: ListTile(
                title: Text(a.name),
                subtitle: Text(a.desc),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _start(context, a),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const BannerSlot(),
    );
  }

  Future<void> _start(BuildContext context, DayAction action) async {
    final ok = await c.startDay(action);
    if (ok || !context.mounted) return;
    final watch = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('하트가 없어요'),
        content: Text(
          '${c.config.heartRegenMinutes}분마다 1개 회복됩니다. 광고를 보면 지금 바로 1개를 받을 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('기다릴게요'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('광고 보고 하트 받기'),
          ),
        ],
      ),
    );
    if (watch != true) return;
    final earned = await AdManager.instance.showRewarded();
    if (earned) {
      await c.grantHeart();
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('광고를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }
}
