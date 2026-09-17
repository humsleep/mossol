import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../engine/models.dart';
import '../game_controller.dart';
import 'album_screen.dart';
import 'design_system.dart';
import 'roulette_sheet.dart';
import 'widgets.dart';

/// 아침 행동 선택 화면. 하트 1개를 쓰고 하루를 시작한다.
///
/// 규격: docs/DESIGN_SYSTEM.md §2.2.
/// 이 화면의 주인공은 "오늘 뭘 할까" 아래 행동 목록이다. 하트·콤보·클리프행어·
/// 스탯·관계는 결정을 돕는 배경이라 위에서부터 한 단씩 낮춰 쌓는다.
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
    // 히든 캐릭터는 한 번이라도 얽힌 뒤에야 관계 줄에 나온다(기존 규칙 유지).
    final cast = [
      for (final ch in c.bundle.characters)
        if (!ch.hidden || s.affectionOf(ch.id) > 0) ch,
    ];
    final cliffhanger = s.lastCliffhanger;

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
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screenX,
          AppSpace.screenY,
          AppSpace.screenX,
          AppSpace.xxl,
        ),
        children: [
          // 1. 자원 줄. 폭이 모자라면 콤보 배지가 아랫줄로 내려간다.
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              HeartsRow(
                hearts: c.hearts,
                max: c.config.maxHearts,
                nextIn: c.nextHeartIn,
              ),
              if (c.combo > 0) ComboBadge(combo: c.combo, onFire: c.onFire),
            ],
          ),

          // 2. 어젯밤의 예고. 어제와 오늘을 잇는 감정선이라 결정 바로 위에 둔다.
          if (cliffhanger != null) ...[
            const SizedBox(height: AppSpace.md),
            CliffhangerCard(text: '어젯밤: $cliffhanger'),
          ],

          // 3. 스탯. 결정의 근거이므로 축약해서 보여 준다.
          const SizedBox(height: AppSpace.lg),
          StatBars(state: s, compact: true),

          // 4. 관계.
          if (cast.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sectionGap),
            const SectionHeader(title: '관계'),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final ch in cast)
                  CharacterChip(
                    name: ch.name,
                    affection: s.affectionOf(ch.id),
                    trust: s.trustOf(ch.id),
                    accent: context.tokens.accentFor(ch.id),
                  ),
              ],
            ),
          ],

          // 5. 오늘의 결정. 화면의 주인공.
          const SizedBox(height: AppSpace.sectionGap),
          const SectionHeader(title: '오늘 뭘 할까'),
          for (var i = 0; i < c.config.actions.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.listGap),
            AppListRow(
              title: c.config.actions[i].name,
              subtitle: c.config.actions[i].desc,
              leading: _ActionGlyph(id: c.config.actions[i].id),
              onTap: () => _start(context, c.config.actions[i]),
            ),
          ],
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

/// 행동 목록 왼쪽의 아이콘 원. 여섯 줄이 글자만으로 늘어서지 않게 잡아 준다.
/// 색으로 뜻을 전하지 않으므로 전부 같은 중립색을 쓴다(구분은 아이콘 모양).
class _ActionGlyph extends StatelessWidget {
  final String id;
  const _ActionGlyph({required this.id});

  static const _icons = <String, IconData>{
    'gym': Icons.fitness_center,
    'read': Icons.menu_book_outlined,
    'work': Icons.work_outline,
    'style': Icons.checkroom_outlined,
    'rest': Icons.bedtime_outlined,
    'friends': Icons.groups_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      width: AppSpace.huge,
      height: AppSpace.huge,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.rPill,
      ),
      child: Icon(
        _icons[id] ?? Icons.wb_twilight,
        size: AppSpace.xl,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
