import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../engine/models.dart';
import '../game_controller.dart';
import 'widgets.dart';

/// 하루 정산. "다음 날" 을 누르면 정책에 맞을 때만 전면 광고가 나온다.
class SummaryScreen extends StatelessWidget {
  final GameController c;
  const SummaryScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final theme = Theme.of(context);
    final d = c.dayDelta;
    return Scaffold(
      appBar: AppBar(
        title: Text('D+${s.day} 정산'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StatBars(state: s, delta: d.stats),
          const SizedBox(height: 16),
          if (d.affection.isNotEmpty || d.trust.isNotEmpty) ...[
            Text('관계 변화', style: theme.textTheme.titleSmall),
            for (final e in d.affection.entries)
              Text(
                '${c.characterName(e.key)} 호감 ${e.value > 0 ? '+' : ''}${e.value}',
              ),
            for (final e in d.trust.entries)
              Text(
                '${c.characterName(e.key)} 신뢰 ${e.value > 0 ? '+' : ''}${e.value}',
              ),
            const SizedBox(height: 16),
          ],
          if (c.cliffhanger != null)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  c.cliffhanger!,
                  style: TextStyle(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await AdManager.instance.showInterstitial(day: s.day);
              await c.endDay();
            },
            child: Text(s.day >= c.config.totalDays ? '엔딩 보기' : '다음 날로'),
          ),
          const SizedBox(height: 8),
          Text(
            '스트레스 ${s.stat(Stat.stress)} · 흑역사 ${s.album.length}개',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: const BannerSlot(),
    );
  }
}
