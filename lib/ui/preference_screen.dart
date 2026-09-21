import 'package:flutter/material.dart';

import '../engine/mbti.dart';
import '../engine/models.dart';
import '../engine/story_repository.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'widgets.dart';

/// 새 게임 2단계: 캐스트 소개 "이 사람들을 만나게 돼요".
///
/// 규격: docs/DESIGN_SYSTEM.md §2.9. 한쪽(여성 캐릭터 / 남성 캐릭터) 다섯 명을 [CastIntroCard]
/// 로 한 명씩 소개하고(아바타 · 이름 · 역할 · 한 줄 매력 · 첫 메시지 말풍선), 히든은 `???` 한 칸.
/// 하단 패널의 `시작하기` 를 누르면 보고 있는 쪽으로 닫힌다([show] 가 고른 값을 돌려준다).
/// 뒤로 가면 null — 새 게임을 시작하지 않는다.
///
/// - [side] 가 있으면(1단계에서 남자/여자) 그 쪽을 먼저 보여 주고, 패널의 `반대쪽 캐릭터 만나기`
///   로 같은 화면에서 반대쪽을 본다(링크는 `원래대로` 로 바뀐다).
/// - [side] 가 null 이면(1단계 "선택 안 할래요") 세그먼트로 두 쪽을 비교한다. 처음에는 아무 쪽도
///   고르지 않은 상태라 두 쪽 요약 카드([PreferenceCard])가 보이고 `시작하기` 는 꺼져 있다.
///
/// 캐릭터 데이터가 한쪽에 없으면 그 쪽은 `준비 중` 이다. 캐스트가 3+3 이든 6+6 이든
/// characters.json 만 보고 그린다.
class PreferenceScreen extends StatefulWidget {
  final StoryBundle bundle;

  /// 먼저 보여 줄 쪽([Preference.female] | [Preference.male]). null 이면 비교 모드.
  final String? side;

  /// 고른 값을 받는 곳. 기본은 `Navigator.pop(context, 값)`.
  final ValueChanged<String>? onPicked;

  /// 플레이어 MBTI. 있으면 카드마다 궁합 줄(하트 5칸 + 라벨)을 그린다(docs/MBTI_SPEC.md §2.2).
  final String? playerMbti;

  const PreferenceScreen({
    super.key,
    required this.bundle,
    this.side,
    this.onPicked,
    this.playerMbti,
  });

  static const title = '이 사람들을 만나게 돼요';
  static const subtitle = '100일 동안 톡을 주고받을 사람들이에요';
  static const compareHint = '두 쪽을 눌러 비교해 보고 골라요';
  static const startLabel = '시작하기';
  static const flipLabel = '반대쪽 캐릭터 만나기';
  static const restoreLabel = '원래대로';
  static const note = '나중에 새 게임에서 바꿀 수 있어요';

  /// 화면을 띄우고 고른 선호([Preference.female] | [Preference.male])를 돌려준다.
  static Future<String?> show(
    BuildContext context,
    StoryBundle bundle, {
    String? side,
    String? playerMbti,
  }) => Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) =>
          PreferenceScreen(bundle: bundle, side: side, playerMbti: playerMbti),
    ),
  );

  /// 반대쪽. 여성 ↔ 남성.
  static String opposite(String side) =>
      side == Preference.male ? Preference.female : Preference.male;

  /// 요약 카드의 아바타 줄. characters.json 순, 히든은 맨 뒤 실루엣.
  static List<CastEntry> castOf(StoryBundle bundle, String gender) {
    final side = bundle.characters.where((c) => c.gender == gender);
    return [
      for (final c in side)
        if (!c.hidden) CastEntry(id: c.id, name: c.name),
      for (final c in side)
        if (c.hidden) CastEntry(id: c.id, name: c.name, mystery: true),
    ];
  }

  /// 소개 카드 목록. characters.json 순, 히든은 맨 뒤에 이름·문구 없이 한 칸.
  /// [playerMbti] 가 있으면 캐릭터 MBTI 와의 궁합 점수를 싣는다(히든은 MBTI 도 숨긴다).
  static List<CastIntro> introsOf(
    StoryBundle bundle,
    String gender, {
    String? playerMbti,
  }) {
    final side = bundle.characters.where((c) => c.gender == gender);
    return [
      for (final c in side)
        if (!c.hidden)
          CastIntro(
            id: c.id,
            name: c.name,
            title: c.displayTitle,
            tagline: c.tagline,
            firstLine: bundle.firstLineOf(c.id),
            mbti: c.mbti,
            compat: playerMbti == null || c.mbti == null
                ? null
                : Mbti.compat(playerMbti, c.mbti),
          ),
      for (final c in side)
        if (c.hidden)
          CastIntro(
            id: c.id,
            name: '',
            mystery: true,
            mbti: c.mbti == null ? null : CastIntro.hiddenMbti,
          ),
    ];
  }

  /// 요약 카드의 소개. 한 줄 매력 두 개(히든 제외, characters.json 순). 매력 문구가 없는
  /// 데이터(테스트 합성 번들)는 역할 이름 목록.
  static String introOf(StoryBundle bundle, String gender) {
    final visible = [
      for (final c in bundle.characters)
        if (c.gender == gender && !c.hidden) c,
    ];
    final taglines = [
      for (final c in visible)
        if (c.tagline.isNotEmpty) c.tagline,
    ];
    if (taglines.isNotEmpty) return taglines.take(2).join(' · ');
    final roles = {for (final c in visible) c.role};
    return [
      for (final r in CastRole.values)
        if (roles.contains(r)) CastRole.label(r),
    ].join(' · ');
  }

  /// 제목 옆 인원. 예: `'5명 + ?'`.
  static String countOf(StoryBundle bundle, String gender) {
    final side = bundle.characters.where((c) => c.gender == gender);
    final shown = side.where((c) => !c.hidden).length;
    final hidden = side.length - shown;
    return hidden > 0 ? '$shown명 + ?' : '$shown명';
  }

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  /// 지금 보고 있는 쪽. 비교 모드에서 아직 안 골랐으면 null.
  late String? _side = widget.side;

  StoryBundle get bundle => widget.bundle;
  bool get _compare => widget.side == null;

  bool _has(String side) => bundle.characters.any((c) => c.gender == side);

  void _start() {
    final side = _side;
    if (side == null) return;
    final cb = widget.onPicked;
    if (cb != null) {
      cb(side);
    } else {
      Navigator.of(context).pop(side);
    }
  }

  void _show(String? side) => setState(() => _side = side);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final side = _side;
    final home = widget.side;
    final canStart = side != null && _has(side);

    return Scaffold(
      backgroundColor: scheme.surface,
      // 제목은 본문 헤드라인이 맡는다. AppBar 는 뒤로 가기만.
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screenX,
          AppSpace.xs,
          AppSpace.screenX,
          AppSpace.xxl,
        ),
        children: [
          Text(
            keepAll(PreferenceScreen.title),
            style: context.text.headlineMedium,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            keepAll(
              _compare
                  ? PreferenceScreen.compareHint
                  : PreferenceScreen.subtitle,
            ),
            style: context.text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          if (_compare) ...[
            _SideSegment(selected: side, onChanged: _show),
            const SizedBox(height: AppSpace.xxl),
          ],
          AnimatedSwitcher(
            duration: AppMotion.base(context),
            switchInCurve: AppMotion.curve(context),
            switchOutCurve: AppMotion.curve(context),
            child: side == null
                ? _Teasers(
                    key: const Key('cast-teasers'),
                    bundle: bundle,
                    onPick: _show,
                  )
                : _CastList(
                    key: Key('cast-side-$side'),
                    bundle: bundle,
                    side: side,
                    playerMbti: widget.playerMbti,
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              key: const Key('cast-start'),
              onPressed: canStart ? _start : null,
              child: const Text(PreferenceScreen.startLabel),
            ),
            if (home != null && _has(PreferenceScreen.opposite(home))) ...[
              const SizedBox(height: AppSpace.xs),
              TextButton(
                key: const Key('cast-flip'),
                onPressed: () => _show(
                  side == home ? PreferenceScreen.opposite(home) : home,
                ),
                // 2차 링크는 1차 버튼과 다른 무게(DS §5.7 예외 ②와 같은 처리).
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                ),
                child: Text(
                  side == home
                      ? PreferenceScreen.flipLabel
                      : PreferenceScreen.restoreLabel,
                ),
              ),
            ] else ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                keepAll(PreferenceScreen.note),
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 비교 모드의 두 쪽 세그먼트. 처음에는 아무것도 고르지 않은 상태다.
class _SideSegment extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _SideSegment({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => SegmentedButton<String>(
    key: const Key('cast-segment'),
    segments: [
      for (final g in Preference.genders)
        ButtonSegment(value: g, label: Text(Preference.label(g))),
    ],
    selected: {?selected},
    emptySelectionAllowed: true,
    onSelectionChanged: (v) {
      // 고른 쪽을 다시 눌러도 비우지 않는다. 비교는 두 쪽을 오가는 것이다.
      if (v.isNotEmpty) onChanged(v.first);
    },
    style: const ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, AppSpace.minTouch)),
      tapTargetSize: MaterialTapTargetSize.padded,
    ),
  );
}

/// 비교 모드에서 아직 한쪽을 고르지 않았을 때: 두 쪽 요약 카드. 누르면 그 쪽을 펼친다.
class _Teasers extends StatelessWidget {
  final StoryBundle bundle;
  final ValueChanged<String> onPick;

  const _Teasers({super.key, required this.bundle, required this.onPick});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, g) in Preference.genders.indexed) ...[
        if (i > 0) const SizedBox(height: AppSpace.gap),
        Builder(
          builder: (context) {
            final cast = PreferenceScreen.castOf(bundle, g);
            return PreferenceCard(
              key: Key('preference-$g'),
              title: Preference.label(g),
              intro: PreferenceScreen.introOf(bundle, g),
              cast: cast,
              onTap: cast.isEmpty ? null : () => onPick(g),
            );
          },
        ),
      ],
    ],
  );
}

/// 한쪽 캐스트 소개: 쪽 이름 + 인원 → 카드 목록.
class _CastList extends StatelessWidget {
  final StoryBundle bundle;
  final String side;
  final String? playerMbti;

  const _CastList({
    super.key,
    required this.bundle,
    required this.side,
    this.playerMbti,
  });

  @override
  Widget build(BuildContext context) {
    final intros = PreferenceScreen.introsOf(
      bundle,
      side,
      playerMbti: playerMbti,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: Preference.label(side),
          trailingText: intros.isEmpty
              ? null
              : PreferenceScreen.countOf(bundle, side),
        ),
        if (intros.isEmpty)
          Text(
            '준비 중',
            style: context.text.bodyMedium?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
        for (final (i, e) in intros.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpace.sm),
          CastIntroCard(key: Key('cast-${e.id}'), intro: e),
        ],
      ],
    );
  }
}
