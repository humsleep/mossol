import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../game_controller.dart';
import '../minigames/minigame.dart' show CenteredScrollColumn;
import 'design_system.dart';
import 'widgets.dart';

/// 회차의 마지막 화면. 규격은 docs/DESIGN_SYSTEM.md §2.5.
///
/// 이 화면은 보상이다. 엔딩 이름·등급·에필로그·기록을 한 덩어리로 묶어
/// 기념품처럼 보이게 하고, 그 덩어리만 [shareBoundaryKey] 로 따로 그려
/// 나중에 이미지로 저장·공유할 수 있게 해 둔다.
class EndingScreen extends StatelessWidget {
  final GameController c;
  const EndingScreen({super.key, required this.c});

  /// 공유용 캡처 경계. `RenderRepaintBoundary.toImage()` 를 붙이면
  /// 버튼 없이 기념품 카드만 이미지로 나온다.
  static final GlobalKey shareBoundaryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final e = c.ending!;
    final s = c.state!;

    return Scaffold(
      body: SafeArea(
        // 에필로그가 길거나 글자가 커져도 넘치지 않게 스크롤 컬럼에 담는다.
        child: CenteredScrollColumn(
          padding: AppInsets.screen,
          children: [
            RepaintBoundary(
              key: shareBoundaryKey,
              child: _Keepsake(
                ending: e,
                state: s,
                grade: _grade(s),
                tierLabel: _tierLabel(e.tier),
              ),
            ),
            const SizedBox(height: AppSpace.xxl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: c.nextRun,
                child: Text('${s.run + 1}회차 시작'),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            TextButton(onPressed: c.goHome, child: const Text('홈으로')),
          ],
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

/// 기념품 덩어리: 티어 → 이름 → 에필로그 → 등급 카드.
///
/// 바탕을 `surface` 로 직접 칠해 둔다. 화면에서는 배경과 같은 색이라 보이지
/// 않지만, 이 경계만 이미지로 캡처했을 때 투명 배경이 되지 않게 한다.
class _Keepsake extends StatelessWidget {
  final Ending ending;
  final GameState state;
  final String grade;
  final String tierLabel;

  const _Keepsake({
    required this.ending,
    required this.state,
    required this.grade,
    required this.tierLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.scheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TierPill(label: tierLabel),
            const SizedBox(height: AppSpace.xs),
            Text(
              ending.name,
              textAlign: TextAlign.center,
              style: context.text.headlineMedium,
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              ending.epilogue,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(height: 1.65),
            ),
            const SizedBox(height: AppSpace.xxxl),
            SizedBox(
              width: double.infinity,
              child: _GradeCard(
                state: state,
                grade: grade,
                tier: ending.tier,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 티어 라벨. 규격대로 primary 한 벌로 칠한다. 티어의 뜻은 색이 아니라
/// 낱말('배드 엔딩')이 전한다.
class _TierPill extends StatelessWidget {
  final String label;
  const _TierPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: AppInsets.chip,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.rPill,
      ),
      child: Text(
        label,
        style: context.text.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// 등급 카드. 이 화면에서 유일하게 떠 있는(`raised`) 요소다.
/// 좌측 3px 띠가 엔딩 티어를 색으로 거들고, 본문 글자색은 건드리지 않아
/// 라이트·다크 양쪽에서 대비를 유지한다.
class _GradeCard extends StatelessWidget {
  final GameState state;
  final String grade;
  final String tier;

  const _GradeCard({
    required this.state,
    required this.grade,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final accent = switch (tier) {
      'happy' => scheme.primary,
      'good' => t.success,
      'bad' => t.danger,
      'hidden' => scheme.tertiary,
      _ => t.neutralAccent.base,
    };

    return AppCard(
      raised: true,
      accentStripe: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('연애 등급', style: context.text.labelMedium),
          const SizedBox(height: AppSpace.xs),
          Text(
            grade,
            style: context.text.displayMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            '${state.run}회차 · D+${state.day - 1} · 흑역사 ${state.album.length}개',
            textAlign: TextAlign.center,
            style: t.numericSmall,
          ),
        ],
      ),
    );
  }
}
