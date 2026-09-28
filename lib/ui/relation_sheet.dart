import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../game_controller.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'widgets.dart';

/// 행동 화면의 관계 줄. 사람 수와 상관없이 **한 줄**이고 넘치면 옆으로 민다.
///
/// 칸마다 초상화 + `'서연 ♥12'`(한 덩어리 Text, 테스트 고정). 누르면
/// [RelationDetailSheet] 로 그 사람의 소개·호감·신뢰·취향이 뜬다.
class RelationStrip extends StatelessWidget {
  final GameController c;
  final List<CharacterDef> cast;

  const RelationStrip({super.key, required this.c, required this.cast});

  static const double _avatar = 48;

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final scaler = MediaQuery.textScalerOf(context);
    // 초상화 + 간격 + 이름 한 줄. 큰 글꼴에서도 잘리지 않게 글자 높이는 배율을 곱한다.
    final height = _avatar + AppSpace.xs + scaler.scale(18) + AppSpace.sm * 2;
    return SizedBox(
      height: height,
      // ListView 가 아니라 Row: 화면의 세로 ListView 와 헷갈리지 않게(사람은 많아야 6명).
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // 화면 좌우 여백 밖까지 밀리게 해서 "옆에 더 있다" 가 보이게 한다.
        clipBehavior: Clip.none,
        child: Row(children: [for (final ch in cast) _tile(context, s, ch)]),
      ),
    );
  }

  Widget _tile(BuildContext context, GameState s, CharacterDef ch) {
    final aff = s.affectionOf(ch.id);
    final accent = context.tokens.accentFor(ch.id);
    return Semantics(
      button: true,
      label: '${ch.name}, 호감 $aff, 신뢰 ${s.trustOf(ch.id)}. 자세히 보기',
      excludeSemantics: true,
      child: InkWell(
        key: Key('relation-${ch.id}'),
        borderRadius: AppRadius.rMd,
        onTap: () => RelationDetailSheet.show(context, c, ch),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: AppSpace.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeartRing(
                value: aff / 100,
                color: accent.base,
                child: CharacterAvatar(
                  name: ch.name,
                  characterId: ch.id,
                  accent: accent,
                  size: _avatar - 6,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                '${ch.name} ♥$aff',
                maxLines: 1,
                style: context.text.labelSmall?.copyWith(
                  color: context.scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 초상화 둘레의 호감 고리. 호감이 찰수록 고리가 닫힌다.
class _HeartRing extends StatelessWidget {
  final double value;
  final Color color;
  final Widget child;

  const _HeartRing({
    required this.value,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: RelationStrip._avatar,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: value.clamp(0.0, 1.0),
            strokeWidth: 2.5,
            color: color,
            backgroundColor: context.scheme.surfaceContainerHighest,
          ),
        ),
        child,
      ],
    ),
  );
}

/// 관계 상세. 누구인지(호칭·MBTI·한 줄 소개), 지금 어디쯤인지(호감·신뢰·요즘 기류),
/// 무엇을 좋아하고 무엇을 조심해야 하는지.
class RelationDetailSheet extends StatelessWidget {
  final GameController c;
  final CharacterDef ch;

  const RelationDetailSheet({super.key, required this.c, required this.ch});

  static Future<void> show(
    BuildContext context,
    GameController c,
    CharacterDef ch,
  ) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => RelationDetailSheet(c: c, ch: ch),
  );

  /// 호감 구간 이름. 숫자만으로는 "지금 어디쯤" 이 안 읽힌다.
  static String stageOf(int affection) => switch (affection) {
    >= 80 => '거의 연인',
    >= 60 => '썸',
    >= 40 => '신경 쓰이는 사이',
    >= 20 => '아는 사이',
    > 0 => '첫인상',
    _ => '아직 모르는 사이',
  };

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final t = context.tokens;
    final text = context.text;
    final accent = t.accentFor(ch.id);
    final aff = s.affectionOf(ch.id);
    final trust = s.trustOf(ch.id);
    final signal = c.sayOrNull(c.bundle.signals.todaySignal(s, ch.id));
    // 궁합은 플레이어 MBTI 를 알 때만(모르면 모두 '보통' 이라 보여 줄 게 없다).
    final compat = s.mbti == null || ch.mbti == null
        ? null
        : c.engine.compatWith(s, ch.id);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screenX,
            0,
            AppSpace.screenX,
            AppSpace.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CharacterAvatar(
                    name: ch.name,
                    characterId: ch.id,
                    accent: accent,
                    size: 72,
                  ),
                  const SizedBox(width: AppSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ch.name, style: text.headlineSmall),
                        const SizedBox(height: AppSpace.xxs),
                        Wrap(
                          spacing: AppSpace.xs,
                          runSpacing: AppSpace.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              ch.title,
                              style: text.bodyMedium?.copyWith(
                                color: accent.base,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (ch.mbti != null) MbtiChip(mbti: ch.mbti!),
                          ],
                        ),
                        if (compat != null) ...[
                          const SizedBox(height: AppSpace.xs),
                          CompatRow(score: compat),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (ch.tagline.isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
                Text(
                  keepAll('“${ch.tagline}”'),
                  style: text.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              _Meter(
                icon: Icons.favorite,
                label: '호감',
                value: aff,
                color: accent.base,
                note: stageOf(aff),
              ),
              const SizedBox(height: AppSpace.md),
              _Meter(
                icon: Icons.verified_outlined,
                label: '신뢰',
                value: trust,
                color: t.statColor(Stat.sense),
                note: trust >= 50 ? '믿고 기대는 사이' : '아직 지켜보는 중',
              ),
              if (signal != null) ...[
                const SizedBox(height: AppSpace.lg),
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome, size: 18, color: accent.base),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(keepAll(signal), style: text.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              Text('이 사람이 끌리는 것', style: text.titleSmall),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  for (final k in ch.likes)
                    _Tag(
                      label: Stat.label(k),
                      icon: Icons.thumb_up_alt_outlined,
                      color: accent.base,
                    ),
                  for (final tag in ch.tags) _Tag(label: '#$tag'),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                keepAll(
                  '${ch.likes.map(Stat.label).join('·')}을 키울수록 '
                  '${ch.name}의 마음을 여는 선택지가 열린다.',
                ),
                style: text.bodySmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
              if (ch.mines.isNotEmpty) ...[
                const SizedBox(height: AppSpace.lg),
                Text('이건 조심', style: text.titleSmall),
                const SizedBox(height: AppSpace.sm),
                for (final m in ch.mines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.xs),
                    child: Row(
                      children: [
                        Icon(
                          Icons.do_not_disturb_on_outlined,
                          size: 18,
                          color: t.danger,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Text(keepAll(m), style: text.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final String note;

  const _Meter({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpace.xs),
            Text(label, style: text.titleSmall),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                keepAll(note),
                style: text.bodySmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ),
            Text('$value / 100', style: context.tokens.numericSmall),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        AppProgressBar(
          value: value / 100,
          semanticLabel: '$label $value',
          fill: color,
        ),
      ],
    );
  }
}

/// 취향 태그 한 알. [icon] 이 있으면 강조(끌리는 스탯), 없으면 중립(#취향).
class _Tag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;

  const _Tag({required this.label, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fg = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.rPill,
        border: Border.all(
          color: color ?? scheme.outlineVariant,
          width: AppBorderWidth.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: AppSpace.xs),
          ],
          Text(label, style: context.text.labelMedium?.copyWith(color: fg)),
        ],
      ),
    );
  }
}
