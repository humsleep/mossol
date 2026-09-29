/// 행동 화면의 관계 줄과 관계 상세 시트. docs/DESIGN_SYSTEM.md §2.2.
///
/// 관계 줄([RelationStrip])은 사람 수와 상관없이 **한 줄**이고 넘치면 옆으로 민다.
/// 칸마다 호감 고리를 두른 초상화 + `'서연 ♥12'`(한 덩어리 Text, 테스트 고정).
/// 누르면 [RelationDetailSheet] 가 그 사람의 표정·소개·호감·신뢰·요즘 기류·취향을 보인다.
///
/// **모르는 것은 그리지 않는다**(프로필 크게 보기 §2.15 와 같은 규칙). 히든은 호감이 생기기
/// 전까지 줄에 나오지 않으므로 시트도 열리지 않고, 해금 뒤에도 취향·지뢰는 비워 둔다 —
/// 캐스트 소개가 한 번도 보여 준 적 없는 사람이라 "아직 알아 가는 중" 한 줄만 둔다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/mbti.dart';
import '../engine/models.dart';
import '../game_controller.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'portraits.dart';
import 'scene_card.dart' show SceneImage;
import 'scene_registry.dart';
import 'widgets.dart';

/// 행동 화면의 관계 줄. 가로 한 줄, 넘치면 옆으로 민다.
///
/// 화면의 세로 `ListView` 는 하나뿐이어야 한다(테스트가 그 목록을 끈다). 그래서 여기는
/// `ListView` 가 아니라 `SingleChildScrollView` + `Row` 다(사람은 많아야 여섯 명).
class RelationStrip extends StatelessWidget {
  final GameController c;
  final List<CharacterDef> cast;

  const RelationStrip({super.key, required this.c, required this.cast});

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final dropped = c.overnightShifts;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // 화면 좌우 여백 밖까지 밀리게 해서 "옆에 더 있다" 가 보이게 한다.
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cast.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.xs),
            _RelationTile(
              c: c,
              ch: cast[i],
              affection: s.affectionOf(cast[i].id),
              trust: s.trustOf(cast[i].id),
              dropped: dropped.containsKey(cast[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

/// 관계 줄 한 칸. 탭 대상은 칸 전체(최소 44×44 를 넉넉히 넘는다).
class _RelationTile extends StatelessWidget {
  final GameController c;
  final CharacterDef ch;
  final int affection;
  final int trust;
  final bool dropped;

  const _RelationTile({
    required this.c,
    required this.ch,
    required this.affection,
    required this.trust,
    required this.dropped,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.tokens.accentFor(ch.id);
    return Semantics(
      button: true,
      label:
          '${ch.name}, 호감 $affection, 신뢰 $trust'
          '${dropped ? ', 밤사이 멀어짐' : ''}. 자세히 보기',
      // 라벨은 여기서, 탭 동작은 InkWell 이 같은 노드에 합친다. 안쪽 그림·글자는 뺀다.
      child: InkWell(
        key: Key('relation-${ch.id}'),
        borderRadius: AppRadius.rMd,
        onTap: () => RelationDetailSheet.show(context, c, ch),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: AppSpace.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AffectionRing(
                  value: affection / 100,
                  color: accent.base,
                  badge: dropped ? Icons.nights_stay_outlined : null,
                  child: CharacterAvatar(
                    name: ch.name,
                    characterId: ch.id,
                    accent: accent,
                    size: AppSize.avatarLg,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                // 한 덩어리 Text 를 유지한다(테스트가 '서연 ♥12' 로 찾는다).
                Text(
                  '${ch.name} ♥$affection',
                  maxLines: 1,
                  style: context.text.labelMedium?.copyWith(
                    color: context.scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 초상화 둘레의 호감 고리. 호감이 찰수록 12시 방향부터 시계 방향으로 닫힌다.
///
/// 색만으로 말하지 않는다 — 같은 값이 바로 아래 `♥N` 글자로 함께 선다(§4.2).
/// [badge] 가 있으면 오른쪽 아래에 작은 원 배지(밤사이 멀어짐 등)를 얹는다.
class AffectionRing extends StatelessWidget {
  final double value;
  final Color color;
  final Widget child;
  final IconData? badge;

  /// 고리 두께. 아바타와 고리 사이는 [gap] 만큼 띄운다.
  static const double stroke = 3;
  static const double gap = AppSpace.xxs;

  const AffectionRing({
    super.key,
    required this.value,
    required this.color,
    required this.child,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    const inset = stroke + gap;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.all(inset), child: child),
        Positioned.fill(
          child: CircularProgressIndicator(
            value: value.clamp(0.0, 1.0),
            strokeWidth: stroke,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: context.tokens.gaugeTrack,
          ),
        ),
        if (badge != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: AppSpace.xl,
              height: AppSpace.xl,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.outlineVariant,
                  width: AppBorderWidth.hairline,
                ),
              ),
              child: Icon(badge, size: AppSpace.md, color: color),
            ),
          ),
      ],
    );
  }
}

/// 표정 하나. 파일은 `assets/expressions/<id>_<mood>`, [mood] 가 null 이면 평소(초상화).
@immutable
class MoodShot {
  final String? mood;
  final String path;
  final AssetBundle? bundle;

  const MoodShot(this.mood, this.path, this.bundle);

  /// 화면에 붙는 이름. 스크린리더도 같은 낱말을 읽는다.
  String get label => labelOf(mood);

  static String labelOf(String? mood) => switch (mood) {
    Expression.flutter => '설렘',
    Expression.flustered => '당황',
    Expression.sulky => '삐짐',
    _ => '평소',
  };
}

/// 관계 상세. 누구인지(표정·호칭·MBTI·한 줄 소개), 지금 어디쯤인지(호감·신뢰·요즘 기류),
/// 무엇에 끌리고 무엇을 조심해야 하는지.
class RelationDetailSheet extends StatefulWidget {
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

  /// 지금 분위기에 맞는 표정. null 이면 평소 얼굴(초상화).
  ///
  /// - 밤사이 멀어졌거나(연락 없음으로 구간 하락), 가까워졌는데 믿음이 따라오지 않으면 삐짐.
  /// - 호감 50 이상이면 설렘, 25 이상이면 당황(신경 쓰이기 시작한 얼굴).
  static String? moodOf({
    required int affection,
    required int trust,
    bool dropped = false,
  }) {
    if (dropped || (affection >= 30 && trust < 10)) return Expression.sulky;
    if (affection >= 50) return Expression.flutter;
    if (affection >= 25) return Expression.flustered;
    return null;
  }

  @override
  State<RelationDetailSheet> createState() => _RelationDetailSheetState();
}

class _RelationDetailSheetState extends State<RelationDetailSheet> {
  GameController get c => widget.c;
  CharacterDef get ch => widget.ch;

  /// 사용자가 표정 줄에서 고른 것. null 이면 지금 분위기([RelationDetailSheet.moodOf]).
  String? _picked;
  bool _touched = false;

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final t = context.tokens;
    final text = context.text;
    final soft = context.scheme.onSurfaceVariant;
    final accent = t.accentFor(ch.id);
    final aff = s.affectionOf(ch.id);
    final trust = s.trustOf(ch.id);
    final overnight = c.overnightShifts[ch.id];
    final dropped = overnight != null;
    final signal = dropped
        ? c.say(overnight)
        : c.sayOrNull(c.bundle.signals.todaySignal(s, ch.id));
    final mine = c.runMbti ?? c.playerMbti;
    // 궁합은 플레이어 MBTI 를 알 때만(모르면 모두 '보통' 이라 보여 줄 게 없다).
    final compat = mine == null || ch.mbti == null
        ? null
        : Mbti.compat(mine, ch.mbti);
    final mood = RelationDetailSheet.moodOf(
      affection: aff,
      trust: trust,
      dropped: dropped,
    );
    final sheetH = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: sheetH * 0.88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screenX,
            0,
            AppSpace.screenX,
            AppSpace.xxl,
          ),
          child: SceneScope(
            builder: (context, registry) {
              final shots = _shotsFor(registry);
              final current = _touched ? _picked : mood;
              final shown =
                  shots.where((m) => m.mood == current).firstOrNull ??
                  shots.where((m) => m.mood == null).firstOrNull ??
                  shots.firstOrNull;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (shown != null) ...[
                    _MoodPicture(
                      shot: shown,
                      name: ch.name,
                      accent: accent,
                      now: shown.mood == mood,
                    ),
                    if (shots.length > 1) ...[
                      const SizedBox(height: AppSpace.md),
                      _MoodStrip(
                        shots: shots,
                        selected: shown.mood,
                        current: mood,
                        name: ch.name,
                        accent: accent,
                        onPick: (m) => setState(() {
                          _touched = true;
                          _picked = m;
                        }),
                      ),
                    ],
                    const SizedBox(height: AppSpace.lg),
                  ],
                  _Identity(
                    ch: ch,
                    accent: accent,
                    compat: compat,
                    showAvatar: shown == null,
                  ),
                  if (ch.tagline.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.md),
                    Text(
                      keepAll('“${ch.tagline}”'),
                      style: text.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.xl),
                  _Meter(
                    icon: Icons.favorite,
                    label: '호감',
                    value: aff,
                    color: accent.base,
                    note: RelationDetailSheet.stageOf(aff),
                  ),
                  const SizedBox(height: AppSpace.md),
                  _Meter(
                    icon: Icons.verified_outlined,
                    label: '신뢰',
                    value: trust,
                    color: t.info,
                    note: trust >= 50 ? '믿고 기대는 사이' : '아직 지켜보는 중',
                  ),
                  if (signal != null) ...[
                    const SizedBox(height: AppSpace.lg),
                    _SignalCard(
                      text: signal,
                      dropped: dropped,
                      color: accent.base,
                    ),
                  ],
                  const SizedBox(height: AppSpace.xl),
                  if (ch.hidden)
                    Text(
                      keepAll('아직 알아 가는 중이다. 취향은 대화 속에서 드러난다.'),
                      style: text.bodyMedium?.copyWith(color: soft),
                    )
                  else ...[
                    _Likes(ch: ch, accent: accent),
                    if (ch.mines.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.xl),
                      _Mines(mines: ch.mines),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 볼 수 있는 표정 전부(평소 → 설렘 → 당황 → 삐짐). 파일이 없는 것은 뺀다.
  List<MoodShot> _shotsFor(SceneRegistry registry) {
    final portraits = PortraitRegistry.current;
    final portrait = portraits.pathFor(ch.id);
    return [
      if (portrait != null) MoodShot(null, portrait, portraits.bundle),
      for (final m in Expression.all)
        if (SceneImages.forExpression(ch.id, m, registry: registry)
            case final p?)
          MoodShot(m, p, registry.bundle),
    ];
  }
}

/// 큰 표정 그림. 정사각 원본을 5:4 로 얼굴 쪽에 맞춰 자르고, 왼쪽 위에 표정 이름 pill.
class _MoodPicture extends StatelessWidget {
  final MoodShot shot;
  final String name;
  final CharacterAccent accent;

  /// 지금 분위기의 표정인지. 그렇다면 pill 이 `지금 · 설렘` 이 된다.
  final bool now;

  const _MoodPicture({
    required this.shot,
    required this.name,
    required this.accent,
    required this.now,
  });

  /// 초상화 구도(가슴 위 상반신)에서 얼굴이 위쪽 1/3 쯤이라 위로 당겨 자른다.
  static const Alignment focus = Alignment(0, -0.45);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final pill = now && shot.mood != null ? '지금 · ${shot.label}' : shot.label;
    return Semantics(
      image: true,
      label: '$name ${shot.label} 표정',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.container,
          borderRadius: AppRadius.rXl,
          border: Border.all(
            color: scheme.outlineVariant,
            width: AppBorderWidth.hairline,
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.rXl,
          child: LayoutBuilder(
            builder: (context, box) => SizedBox(
              // 폰에서는 5:4, 넓은 화면·가로에서는 화면 높이의 38% 까지만(아래 내용이 보이게).
              height: math.min(
                box.maxWidth * 4 / 5,
                MediaQuery.sizeOf(context).height * 0.38,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: AppMotion.base(context),
                    switchInCurve: AppMotion.curve(context),
                    // 기본 레이아웃은 느슨한 Stack 이라 그림이 틀을 다 채우지 못한다.
                    layoutBuilder: (current, previous) => Stack(
                      fit: StackFit.expand,
                      children: [...previous, ?current],
                    ),
                    child: SceneImage(
                      key: ValueKey(shot.path),
                      path: shot.path,
                      width: box.maxWidth,
                      bundle: shot.bundle,
                      alignment: focus,
                    ),
                  ),
                  PositionedDirectional(
                    start: AppSpace.md,
                    top: AppSpace.md,
                    child: Container(
                      padding: AppInsets.chip,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: AppRadius.rPill,
                        border: Border.all(
                          color: accent.base,
                          width: AppBorderWidth.hairline,
                        ),
                      ),
                      child: Text(
                        pill,
                        style: context.text.labelMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 표정 고르기 줄. 칸마다 정사각 썸네일 + 이름. 고른 칸은 강조색 굵은 테두리 + 굵은 글씨,
/// 지금 분위기의 칸에는 작은 점(색만으로 말하지 않게 스크린리더에는 `지금` 을 붙인다).
class _MoodStrip extends StatelessWidget {
  final List<MoodShot> shots;
  final String? selected;
  final String? current;
  final String name;
  final CharacterAccent accent;
  final ValueChanged<String?> onPick;

  const _MoodStrip({
    required this.shots,
    required this.selected,
    required this.current,
    required this.name,
    required this.accent,
    required this.onPick,
  });

  /// 한 칸의 최대 폭. 넓은 화면에서 썸네일이 과하게 커지지 않게.
  static const double maxThumb = 96;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // 칸이 적어도 네 칸 기준 폭을 쓴다 — 칸 수에 따라 썸네일 크기가 출렁이지 않게.
      const gap = AppSpace.sm;
      final w = math.min((box.maxWidth - gap * 3) / 4, maxThumb);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < shots.length; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            SizedBox(
              width: w,
              child: _MoodThumb(
                shot: shots[i],
                name: name,
                accent: accent,
                selected: shots[i].mood == selected,
                now: shots[i].mood == current,
                onTap: () => onPick(shots[i].mood),
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _MoodThumb extends StatelessWidget {
  final MoodShot shot;
  final String name;
  final CharacterAccent accent;
  final bool selected;
  final bool now;
  final VoidCallback onTap;

  const _MoodThumb({
    required this.shot,
    required this.name,
    required this.accent,
    required this.selected,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    return Semantics(
      button: true,
      selected: selected,
      label: '${shot.label} 표정${now ? ', 지금 분위기' : ''}',
      child: InkWell(
        key: Key('mood-${shot.mood ?? 'portrait'}'),
        onTap: onTap,
        borderRadius: AppRadius.rMd,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xxs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: AppMotion.fast(context),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.container
                        : scheme.surfaceContainerHigh,
                    borderRadius: AppRadius.rMd,
                    border: Border.all(
                      color: selected ? accent.base : scheme.outlineVariant,
                      width: selected
                          ? AppBorderWidth.emphasis
                          : AppBorderWidth.hairline,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpace.xxs),
                  child: ClipRRect(
                    borderRadius: AppRadius.rSm,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: LayoutBuilder(
                        builder: (context, box) => SceneImage(
                          path: shot.path,
                          width: box.maxWidth,
                          bundle: shot.bundle,
                          alignment: _MoodPicture.focus,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (now) ...[
                      Container(
                        width: AppSpace.xs + AppSpace.xxs,
                        height: AppSpace.xs + AppSpace.xxs,
                        decoration: BoxDecoration(
                          color: accent.base,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpace.xs),
                    ],
                    Flexible(
                      child: Text(
                        shot.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelMedium?.copyWith(
                          color: selected
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 이름 · 호칭 · MBTI · 궁합. 그림이 없으면 왼쪽에 아바타(72)를 둔다.
class _Identity extends StatelessWidget {
  final CharacterDef ch;
  final CharacterAccent accent;
  final int? compat;
  final bool showAvatar;

  const _Identity({
    required this.ch,
    required this.accent,
    required this.compat,
    required this.showAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ch.name, style: text.headlineSmall),
        const SizedBox(height: AppSpace.xxs),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              keepAll(ch.displayTitle),
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
          CompatRow(score: compat!),
        ],
      ],
    );
    if (!showAvatar) return body;
    return Row(
      children: [
        CharacterAvatar(
          name: ch.name,
          characterId: ch.id,
          accent: accent,
          size: AppSize.avatarXl,
        ),
        const SizedBox(width: AppSpace.lg),
        Expanded(child: body),
      ],
    );
  }
}

/// 요즘 기류 한 줄. 밤사이 멀어졌으면 달 아이콘 + 하강 문장, 아니면 오늘의 신호.
class _SignalCard extends StatelessWidget {
  final String text;
  final bool dropped;
  final Color color;

  const _SignalCard({
    required this.text,
    required this.dropped,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${dropped ? '밤사이' : '요즘'}: $text',
    excludeSemantics: true,
    child: AppCard(
      accentStripe: color,
      padding: AppInsets.cardTight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xxs),
            child: Icon(
              dropped ? Icons.nights_stay_outlined : Icons.auto_awesome,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(keepAll(text), style: context.text.bodyMedium)),
        ],
      ),
    ),
  );
}

/// 이 사람이 끌리는 것: 스탯 태그(강조) + #취향 태그(중립) + 한 줄 풀이.
class _Likes extends StatelessWidget {
  final CharacterDef ch;
  final CharacterAccent accent;

  const _Likes({required this.ch, required this.accent});

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    if (ch.likes.isEmpty && ch.tags.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('이 사람이 끌리는 것', style: text.titleSmall),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final k in ch.likes)
              _Tag(label: Stat.label(k), icon: statIcon(k), color: accent.base),
            for (final tag in ch.tags) _Tag(label: '#$tag'),
          ],
        ),
        if (ch.likes.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          Text(
            keepAll(
              '${_objectOf(ch.likes.map(Stat.label).join('·'))} 키울수록 '
              '${ch.name}의 마음을 여는 선택지가 열린다.',
            ),
            style: text.bodySmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// 목적격 조사를 붙인다. 마지막 글자에 받침이 있으면 `을`, 없으면 `를`.
String _objectOf(String word) {
  if (word.isEmpty) return word;
  final last = word.runes.last;
  final batchim = last >= 0xAC00 && last <= 0xD7A3 && (last - 0xAC00) % 28 != 0;
  return '$word${batchim ? '을' : '를'}';
}

/// 이건 조심: 지뢰 목록. 아이콘 + 문장(색만으로 말하지 않는다).
class _Mines extends StatelessWidget {
  final List<String> mines;
  const _Mines({required this.mines});

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final danger = context.tokens.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('이건 조심', style: text.titleSmall),
        const SizedBox(height: AppSpace.sm),
        for (final m in mines)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xxs),
                  child: Icon(
                    Icons.do_not_disturb_on_outlined,
                    size: 18,
                    color: danger,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(child: Text(keepAll(m), style: text.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// 호감·신뢰 막대 한 줄. 라벨 · 구간 이름 · `N / 100` 위, 막대 아래.
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
    return Semantics(
      container: true,
      label: '$label $value / 100, $note',
      excludeSemantics: true,
      child: Column(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      ),
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
      padding: AppInsets.chip,
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
