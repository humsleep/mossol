import 'package:flutter/material.dart';

import '../engine/models.dart';
import 'design_system.dart';
import 'widgets.dart' show signed, statIcon;

/// 소문 지수 게이지(docs/overhaul2/01_design.md §5.1 F1). 글자 "소문" + 5칸 + 구간 이름.
///
/// GTA 의 수배 별을 옮긴 것이라 숫자보다 **칸**이 먼저 읽혀야 한다. 칸은 구간
/// (0~19 조용 · 20~39 수군수군 · 40~59 화제 · 60~79 박제 위기 · 80~100 대참사) 하나에 하나씩
/// 켜지고, 값이 0 이면 하나도 켜지지 않는다. 부르는 쪽은 소문이 1 이상인 회차에서만 그린다
/// ([shows]) — 클래식 회차의 홈은 지금과 같다.
///
/// 색은 경고색(`warning`)이고 마지막 칸(대참사)만 위험색이다. 색만으로 말하지 않도록
/// 구간 이름을 글자로 함께 쓴다.
class HeatGauge extends StatelessWidget {
  /// 지금 소문 값(0~100).
  final int heat;

  /// 오늘의 변화량(정산). null 이거나 0 이면 그리지 않는다.
  final int? delta;

  /// 홈 자원 줄처럼 좁은 자리. 구간 이름을 빼고 칸만 남긴다.
  final bool compact;

  /// 오늘 밤 저절로 바뀔 양(`config.dailyDrift.heat`, 예 −1). 정산에서 "밤사이 −1" 로 알린다.
  /// 소문이 0 이면(더 식을 것이 없으면) 그리지 않는다.
  final int? overnight;

  const HeatGauge({
    super.key,
    required this.heat,
    this.delta,
    this.compact = false,
    this.overnight,
  });

  /// "밤사이 −1".
  static String overnightLabel(int v) => '밤사이 ${signed(v)}';

  /// 게이지를 그릴 회차인지(§7.4-3: 소문이 1 이상일 때만).
  static bool shows(int heat) => heat > 0;

  /// 켜진 칸 수. 0 이면 0, 그 밖에는 구간 + 1.
  static int litOf(int heat) => heat <= 0 ? 0 : Stat.heatBand(heat) + 1;

  static const double _segW = 14;
  static const double _segWCompact = 10;
  static const double _segH = 8;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final lit = litOf(heat);
    final band = Stat.heatBands[Stat.heatBand(heat)];
    final label = Stat.label(Stat.heat);
    final d = delta;
    final hasDelta = d != null && d != 0;
    final segW = compact ? _segWCompact : _segW;
    final o = overnight;
    final showOvernight = o != null && o != 0 && heat > 0;
    final duration = AppMotion.base(context);

    Color segColor(int i) {
      if (i >= lit) return t.gaugeTrack;
      return i == Stat.heatSegments - 1 ? t.danger : t.warning;
    }

    return Semantics(
      container: true,
      label: '$label $heat, $band',
      value: hasDelta || showOvernight
          ? [
              if (hasDelta) signed(d),
              if (showOvernight) overnightLabel(o),
            ].join(', ')
          : null,
      child: ExcludeSemantics(
        // 게이지 한 줄 + 변화량 한 줄. 좁은 화면·큰 글자에서는 변화량("+25 · 밤사이 −1")이
        // 다음 줄로 내려간다 — 한 줄 Row 에 전부 고정 폭으로 두면 320pt 정산에서 넘쳤다(r1_bugs R1-1).
        child: Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statIcon(Stat.heat),
                  size: compact ? 14 : 16,
                  color: t.statColor(Stat.heat),
                ),
                const SizedBox(width: AppSpace.xs),
                Text(
                  label,
                  style:
                      (compact
                              ? context.text.labelSmall
                              : context.text.labelMedium)
                          ?.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(width: AppSpace.sm),
                for (var i = 0; i < Stat.heatSegments; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpace.xxs),
                  AnimatedContainer(
                    key: Key('heat-seg-$i'),
                    duration: duration,
                    curve: AppMotion.curve(context),
                    width: segW,
                    height: _segH,
                    decoration: BoxDecoration(
                      color: segColor(i),
                      borderRadius: AppRadius.rXs,
                    ),
                  ),
                ],
                if (!compact) ...[
                  const SizedBox(width: AppSpace.sm),
                  Flexible(
                    child: Text(
                      band,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (hasDelta || showOvernight)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasDelta)
                    Text(
                      signed(d),
                      style: t.numericSmall.copyWith(
                        color: t.deltaColor(good: Stat.isGood(Stat.heat, d)),
                      ),
                    ),
                  if (hasDelta && showOvernight)
                    const SizedBox(width: AppSpace.sm),
                  if (showOvernight)
                    Flexible(
                      child: Text(
                        overnightLabel(o),
                        key: const Key('heat-overnight'),
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
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

/// 진상 칩 "진상 n"(r2_meeting E4). GTA 의 별처럼 내가 쌓은 진상 짓이 화면에 보여야 라이벌·재판이
/// 왜 지금 왔는지 안다. 진상 지수가 1 이상일 때만 소문 게이지 옆(행동·정산)과 결과 패널에 붙는다.
///
/// 색은 경고·위험색이 아니라 **악명 전용 보라**다 — 진상은 감점이 아니라 고른 플레이 방식이다
/// (r2_bugs R2-4: 결과의 "진상 +1" 이 나쁜 쪽 칩으로 보이던 문제). 2·4·6 에서 한 단씩 진해진다.
class VillainChip extends StatelessWidget {
  /// 지금 진상 지수.
  final int villain;

  /// 방금 오른 양(결과 패널). null 이거나 0 이면 숫자만.
  final int? delta;

  const VillainChip({super.key, required this.villain, this.delta});

  /// 칩을 그릴 회차인지(진상 1 이상).
  static bool shows(int villain) => villain > 0;

  /// 색 단계 0~3. 1 · 2~3 · 4~5 · 6 이상.
  static int levelOf(int villain) => switch (villain) {
    >= 6 => 3,
    >= 4 => 2,
    >= 2 => 1,
    _ => 0,
  };

  static String label(int villain) => '${Stat.label(Stat.villain)} $villain';

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    const light = [
      (AppPalette.violet100, AppPalette.violet900),
      (AppPalette.violet300, AppPalette.violet900),
      (AppPalette.violet600, Colors.white),
      (AppPalette.violet900, Colors.white),
    ];
    const night = [
      (AppPalette.violet800, AppPalette.violet100),
      (AppPalette.violet600, Colors.white),
      (AppPalette.violet300, AppPalette.violet900),
      (AppPalette.violet100, AppPalette.violet900),
    ];
    final (bg, fg) = (dark ? night : light)[levelOf(villain)];
    final d = delta;
    final text = d != null && d > 0
        ? '${label(villain)} (${signed(d)})'
        : label(villain);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Container(
        key: const Key('villain-chip'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xxs,
        ),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.rPill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_police_outlined, size: 14, color: fg),
            const SizedBox(width: AppSpace.xxs),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
