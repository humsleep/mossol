import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../game_controller.dart';

class EndingScreen extends StatelessWidget {
  final GameController c;
  const EndingScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final e = c.ending!;
    final s = c.state!;
    final theme = Theme.of(context);
    final grade = _grade(s);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _tierLabel(e.tier),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                e.name,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                e.epilogue,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('연애 등급', style: theme.textTheme.labelMedium),
                      Text(
                        grade,
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${s.run}회차 · D+${s.day - 1} · 흑역사 ${s.album.length}개',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: c.nextRun,
                child: Text('${s.run + 1}회차 시작'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: c.goHome, child: const Text('홈으로')),
            ],
          ),
        ),
      ),
    );
  }

  String _tierLabel(String tier) => switch (tier) {
    'happy' => '해피 엔딩',
    'good' => '굿 엔딩',
    'bad' => '배드 엔딩',
    'solo' => '솔로 엔딩',
    'hidden' => '히든 엔딩',
    _ => '엔딩',
  };

  /// 스탯 합과 최고 호감도로 S~F.
  String _grade(GameState s) {
    final core = [
      Stat.charm,
      Stat.talk,
      Stat.esteem,
      Stat.sense,
    ].fold<int>(0, (a, k) => a + s.stat(k));
    final best = s.relations.values.fold<int>(
      0,
      (a, r) => a > r.affection ? a : r.affection,
    );
    final score = core / 4 * 0.6 + best * 0.4;
    if (score >= 80) return 'S';
    if (score >= 65) return 'A';
    if (score >= 50) return 'B';
    if (score >= 35) return 'C';
    if (score >= 20) return 'D';
    return 'F';
  }
}
