import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../engine/album_index.dart';
import '../engine/models.dart';
import '../game_controller.dart';
import 'design_system.dart';
import 'scene_card.dart';
import 'scene_registry.dart';
import 'widgets.dart';
import 'keep_all.dart';

/// 흑역사 앨범과 엔딩 앨범. 실패도 수집 요소가 된다.
///
/// 규격: docs/DESIGN_SYSTEM.md §2.6.
/// - 주인공은 상단 수집 진행도와 카드 목록, 배경은 탭 바와 티어 라벨.
/// - 엔딩은 트로피(메달 + 좌측 강조 띠), 흑역사는 번호가 붙은 수집 카드.
/// - 흑역사 카드에는 종류별 빨간 도장([ShameStamp])이 비스듬히 찍히고, 누르면 그날의
///   대화를 다시 보는 [ShameDetailSheet] 가 뜬다.
/// - 본 엔딩에 그림이 있으면 메달 자리에 세로 썸네일, 누르면 크게 보기.
/// - 미획득은 불투명도를 내리지 않고 자물쇠 + 글자색으로만 구분한다.
class AlbumScreen extends StatefulWidget {
  final GameController c;
  const AlbumScreen({super.key, required this.c});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  GameController get c => widget.c;

  @override
  void initState() {
    super.initState();
    // 측정: 앨범을 연 횟수(엔딩 수집 동기). 화면이 열릴 때 한 번.
    c.analytics.log(Analytics.albumOpened);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('앨범'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '흑역사'),
              Tab(text: '엔딩'),
            ],
          ),
        ),
        // 배너는 TabBar 아래, 탭을 바꿔도 고정(DESIGN_SYSTEM §2 공통).
        body: Column(
          children: [
            const BannerSlot(edge: BannerEdge.top, safeArea: false),
            Expanded(
              child: TabBarView(
                children: [
                  _ShameTab(c: c),
                  _EndingTab(c: c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 수집 진행도
// ---------------------------------------------------------------------------

/// 탭 상단의 수집 진행도. 개수(`'2 / 20'`)와 막대를 함께 둔다.
///
/// 개수 문자열은 하나의 Text 로 유지한다(테스트 고정, §4.1).
/// 제목은 탭 라벨('흑역사' / '엔딩')과 정확히 같은 낱말이 되지 않게 짓는다
/// ('모은 흑역사' / '본 엔딩'). 탭을 문구로 찾을 때 중복으로 걸리지 않게 하려는 것이다.
class _CollectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String count;
  final String? note;
  final double value;
  final String semanticLabel;

  const _CollectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    this.note,
    required this.value,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                keepAll(title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleMedium,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            // 개수는 하나의 Text 로 둔다(테스트 고정).
            Text(count, maxLines: 1, style: t.numericMedium),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        AppProgressBar(
          value: value,
          semanticLabel: semanticLabel,
          height: AppSpace.sm,
        ),
        if (note != null) ...[
          const SizedBox(height: AppSpace.sm),
          Text(note!, style: context.text.bodySmall),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 흑역사
// ---------------------------------------------------------------------------

class _ShameTab extends StatelessWidget {
  final GameController c;
  const _ShameTab({required this.c});

  /// 전용 엔딩이 열리는 수집 목표. 표기 `'N / 20'` 은 테스트가 고정한 형식이다.
  static const int _goal = 20;

  @override
  Widget build(BuildContext context) {
    final album = c.state?.album ?? const <String>[];
    if (album.isEmpty) {
      return const AppEmptyState(
        icon: Icons.sentiment_satisfied_alt,
        title: '아직 흑역사가 없다',
        body: '실패한 선택은 여기에 카드로 남는다. 20개를 모으면 전용 엔딩이 열린다.',
      );
    }
    return SceneScope(
      builder: (context, r) => ListView(
        padding: AppInsets.screen,
        children: [
          _CollectionHeader(
            icon: Icons.local_fire_department_outlined,
            title: '모은 흑역사',
            count: '${album.length} / $_goal',
            // 수집 목표가 빈 상태에서만 보이면 한 장 모으는 순간 동기가 사라진다.
            note: album.length < _goal ? '20개를 모으면 전용 엔딩이 열린다' : null,
            value: album.length / _goal,
            semanticLabel: '수집한 흑역사 ${album.length}개 / $_goal개',
          ),
          const SizedBox(height: AppSpace.sectionGap),
          // 최근 것이 위로. 번호는 실제 수집 순서를 유지한다.
          for (var i = album.length - 1; i >= 0; i--) ...[
            Builder(
              builder: (context) {
                final entry = ShameEntry.of(c, album[i]);
                return _ShameCard(
                  number: i + 1,
                  entry: entry,
                  stamp: r.stamp(entry.kind),
                  bundle: r.bundle,
                  onTap: () => ShameDetailSheet.show(
                    context,
                    c,
                    number: i + 1,
                    title: album[i],
                  ),
                );
              },
            ),
            if (i > 0) const SizedBox(height: AppSpace.listGap),
          ],
        ],
      ),
    );
  }
}

/// 흑역사 한 장의 출처([source], 못 찾으면 null)와 도장 종류([kind]).
@immutable
class ShameEntry {
  final String title;
  final ShameSource? source;
  final String kind;

  const ShameEntry(this.title, this.source, this.kind);

  /// 제목으로 출처를 찾고 도장을 고른다. 같은 제목이면 로스터 캐릭터 쪽이 먼저다.
  factory ShameEntry.of(GameController c, String title) {
    final src = AlbumIndex.find(
      c.bundle.events,
      title,
      roster: {for (final ch in c.roster) ch.id},
    );
    return ShameEntry(title, src, ShameStamp.classify(title, source: src));
  }
}

/// 흑역사 한 장. 번호 메달 + 제목 + 종류 라벨, 오른쪽에 비스듬한 도장. 누르면 상세.
class _ShameCard extends StatelessWidget {
  final int number;
  final ShameEntry entry;

  /// 도장 그림 경로. 없으면 도장 자리 없이 글만.
  final String? stamp;
  final AssetBundle? bundle;
  final VoidCallback onTap;

  const _ShameCard({
    required this.number,
    required this.entry,
    required this.stamp,
    required this.bundle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = ShameStamp.label(entry.kind);
    return Semantics(
      button: true,
      label: '흑역사 $number번: ${entry.title}. $label',
      hint: '그날 대화 다시 보기',
      excludeSemantics: true,
      child: AppCard(
        padding: AppInsets.cardTight,
        onTap: onTap,
        child: Row(
          children: [
            _ShameMedal(number: number),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(keepAll(entry.title), style: context.text.bodyMedium),
                  const SizedBox(height: AppSpace.xxs),
                  Text(
                    keepAll(label),
                    style: context.text.labelSmall?.copyWith(color: t.danger),
                  ),
                ],
              ),
            ),
            if (stamp != null) ...[
              const SizedBox(width: AppSpace.sm),
              ShameStampMark(
                path: stamp!,
                size: ShameStampMark.cardSize,
                seed: number,
                bundle: bundle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 빨간 고무도장 한 개. 번호로 정한 각도만큼 비스듬히, 살짝 바랜 잉크처럼 찍힌다.
/// 장식이다(뜻은 옆의 글 라벨이 전한다). 그림이 깨지면 빈 칸.
class ShameStampMark extends StatelessWidget {
  final String path;
  final double size;

  /// 각도를 고르는 수(흑역사 번호). 같은 카드는 늘 같은 각도로 찍힌다.
  final int seed;
  final AssetBundle? bundle;

  const ShameStampMark({
    super.key,
    required this.path,
    required this.size,
    required this.seed,
    this.bundle,
  });

  /// 카드 도장 한 변. 번호 메달(32)보다 크고 두 줄 카드 높이 안에 든다.
  static const double cardSize = AppSize.avatarLg;

  /// 상세 시트 도장 한 변.
  static const double sheetSize = AppSize.avatarXl + AppSpace.xxl;

  /// 찍힌 각도(라디안). 도장을 똑바로 찍는 사람은 없다: -12° ~ +9°.
  static const List<double> _angles = [-0.21, 0.12, -0.09, 0.16, -0.14, 0.06];

  /// 잉크가 덜 묻은 느낌. 글자 대비와 무관한 장식이라 불투명도를 조금 내린다.
  static const double _ink = 0.88;

  static double angleFor(int seed) => _angles[seed.abs() % _angles.length];

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: Transform.rotate(
        angle: angleFor(seed),
        child: Opacity(
          opacity: _ink,
          child: Image(
            image: SceneImage.providerFor(
              path,
              bundle: bundle,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
            ),
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}

class _ShameMedal extends StatelessWidget {
  final int number;
  const _ShameMedal({required this.number});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // 고정 높이 대신 최소 크기. 글자를 키워도 번호가 잘리지 않는다.
    return Container(
      constraints: const BoxConstraints(
        minWidth: AppSpace.xxxl,
        minHeight: AppSpace.xxxl,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: t.dangerContainer,
        borderRadius: AppRadius.rPill,
      ),
      child: Text(
        '$number',
        style: t.numericSmall.copyWith(color: t.onDangerContainer),
      ),
    );
  }
}

/// 흑역사 상세. 그날의 장면 → 내가 한 선택 → 돌아온 반응을 짧은 대화로 다시 보여 준다.
/// 출처는 제목으로 스토리 데이터를 거꾸로 찾는다([AlbumIndex]). 못 찾으면(데이터에서 빠진
/// 옛 흑역사) 제목·도장·한마디만.
class ShameDetailSheet extends StatelessWidget {
  final GameController c;
  final int number;
  final String title;

  const ShameDetailSheet({
    super.key,
    required this.c,
    required this.number,
    required this.title,
  });

  static Future<void> show(
    BuildContext context,
    GameController c, {
    required int number,
    required String title,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ShameDetailSheet(c: c, number: number, title: title),
  );

  /// 카드 맨 아래의 한마디. 번호로 돌려 가며 고른다.
  static const quips = [
    '이불 킥 한 번이면 괜찮아진다. 두 번이면… 조금 오래 간다.',
    '그날의 나에게: 그래도 용기는 있었다.',
    '흑역사도 모이면 추억이 된다. 아마도.',
    '친구들 단톡방에는 영원히 박제됐다.',
    '다음엔 3초만 더 생각하기로 했다.',
  ];

  static String quipFor(int number) => quips[(number - 1).abs() % quips.length];

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final t = context.tokens;
    final soft = context.scheme.onSurfaceVariant;
    final entry = ShameEntry.of(c, title);
    final src = entry.source;
    final ch = src?.event.character == null
        ? null
        : c.bundle.characterById[src!.event.character];
    final label = ShameStamp.label(entry.kind);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screenX,
            0,
            AppSpace.screenX,
            AppSpace.xxl,
          ),
          children: [
            // 머리: 번호 · 제목 · 종류 라벨, 오른쪽에 크게 찍힌 도장.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ShameMedal(number: number),
                          const SizedBox(width: AppSpace.sm),
                          Flexible(
                            child: Text(
                              keepAll('흑역사 #$number · $label'),
                              style: text.labelLarge?.copyWith(color: t.danger),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Semantics(
                        header: true,
                        child: Text(
                          keepAll(c.say(title)),
                          style: text.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                SceneScope(
                  builder: (context, r) {
                    final path = r.stamp(entry.kind);
                    if (path == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: AppSpace.sm),
                      child: ShameStampMark(
                        path: path,
                        size: ShameStampMark.sheetSize,
                        seed: number,
                        bundle: r.bundle,
                      ),
                    );
                  },
                ),
              ],
            ),
            if (src != null) ...[
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  if (ch != null)
                    CharacterAvatar(
                      name: ch.name,
                      characterId: ch.id,
                      accent: t.accentFor(ch.id),
                      size: AppSize.avatarSm,
                    )
                  else
                    Icon(Icons.history, size: 20, color: soft),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      keepAll(
                        '그날: ${c.say(src.event.title)}'
                        '${ch == null ? '' : ' · ${ch.name}'}',
                      ),
                      style: text.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final l in src.setup())
                      _RecapLine(c: c, line: l, ch: ch),
                    _RecapLine(
                      c: c,
                      line: Line(who: 'me', text: src.choice.text),
                      ch: ch,
                      label: '내 선택',
                    ),
                    for (final l in src.aftermath)
                      _RecapLine(c: c, line: l, ch: ch),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote, size: 18, color: soft),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: Text(
                    keepAll(quipFor(number)),
                    style: text.bodyMedium?.copyWith(color: soft),
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

/// 상세 속 대화 한 줄. 나는 오른쪽, 상대는 왼쪽, 지문은 가운데 기울임.
/// 채팅 화면과 같은 말풍선 모양([AppRadius.bubble])·색을 작게 쓴다.
class _RecapLine extends StatelessWidget {
  final GameController c;
  final Line line;
  final CharacterDef? ch;

  /// 내 줄 머리글. 없으면 '나'.
  final String? label;

  const _RecapLine({
    required this.c,
    required this.line,
    required this.ch,
    this.label,
  });

  /// 말풍선 최대 폭(화면 폭 대비). 채팅 말풍선보다 조금 좁다 — 카드 안이다.
  static const double _maxWidthFactor = 0.62;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final scheme = context.scheme;
    final t = context.tokens;
    final body = c.say(line.text);
    if (line.who == 'narr' || line.who == 'sys') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Text(
          keepAll(body),
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final me = line.who == 'me';
    final who = me
        ? (label ?? '나')
        : (line.name == null ? (ch?.name ?? '상대') : c.say(line.name!));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Column(
        crossAxisAlignment: me
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            keepAll(who),
            style: text.labelSmall?.copyWith(
              color: me ? t.danger : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpace.xxs),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * _maxWidthFactor,
            ),
            padding: AppInsets.bubble,
            decoration: BoxDecoration(
              color: me ? t.bubbleMine : t.bubbleTheirs,
              borderRadius: AppRadius.bubble(mine: me),
              border: me
                  ? null
                  : Border.all(
                      color: t.bubbleBorder,
                      width: AppBorderWidth.hairline,
                    ),
            ),
            child: Text(
              keepAll(body),
              style: text.bodyMedium?.copyWith(
                color: me ? t.onBubbleMine : t.onBubbleTheirs,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 엔딩
// ---------------------------------------------------------------------------

class _EndingTab extends StatefulWidget {
  final GameController c;
  const _EndingTab({required this.c});

  @override
  State<_EndingTab> createState() => _EndingTabState();
}

/// 엔딩 목록 필터. 캐릭터 엔딩은 캐릭터 성별, 공용 엔딩은 `when.pref` 로 나눈다.
enum EndingFilter {
  all('전체'),
  female('여성'),
  male('남성'),
  common('공용');

  final String label;
  const EndingFilter(this.label);

  /// [side] 는 `StoryBundle.endingSide` (f | m | null=공용).
  bool accepts(String? side) => switch (this) {
    all => true,
    female => side == Preference.female,
    male => side == Preference.male,
    common => side == null,
  };
}

class _EndingTabState extends State<_EndingTab> {
  EndingFilter _filter = EndingFilter.all;

  GameController get c => widget.c;

  @override
  Widget build(BuildContext context) {
    final got = c.endingAlbum.toSet();
    final all = c.bundle.endings;
    // 진행도는 늘 전체 기준(`N / M`). 필터는 아래 목록만 거른다.
    final shown = [
      for (final e in all)
        if (_filter.accepts(c.bundle.endingSide(e))) e,
    ];
    return SceneScope(
      builder: (context, r) => ListView(
        padding: AppInsets.screen,
        children: [
          _CollectionHeader(
            icon: Icons.emoji_events_outlined,
            title: '본 엔딩',
            count: '${got.length} / ${all.length}',
            value: all.isEmpty ? 0 : got.length / all.length,
            semanticLabel: '본 엔딩 ${got.length}개 / ${all.length}개',
          ),
          const SizedBox(height: AppSpace.lg),
          EndingFilterBar(
            value: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: AppSpace.lg),
          if (shown.isEmpty)
            const AppEmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: '이 분류의 엔딩이 없다',
              body: '다른 분류를 골라 보자.',
            ),
          for (var i = 0; i < shown.length; i++) ...[
            Builder(
              builder: (context) {
                final e = shown[i];
                final owned = got.contains(e.id);
                // 본 엔딩만 그림을 보여 준다. 못 본 엔딩의 그림은 스포일러다.
                final thumb = owned
                    ? SceneImages.forEnding(e, registry: r)
                    : null;
                return _EndingCard(
                  thumb: thumb == null
                      ? null
                      : _EndingThumb(
                          path: thumb,
                          tier: e.tier,
                          bundle: r.bundle,
                          accent: context.tokens.accentFor(e.character),
                        ),
                  onTap: thumb == null
                      ? null
                      : () => showAppSceneViewer(
                          context,
                          thumb,
                          label: '${e.name} 엔딩 그림',
                          bundle: r.bundle,
                        ),
                  title: owned ? e.name : '???',
                  body: owned
                      ? c.say(c.epilogueOf(e, mbti: c.runMbti ?? c.playerMbti))
                      : endingHintFor(e, c),
                  tierLabel: _tier(e.tier),
                  owned: owned,
                  accent: context.tokens.accentFor(e.character),
                );
              },
            ),
            if (i < shown.length - 1) const SizedBox(height: AppSpace.listGap),
          ],
        ],
      ),
    );
  }

  String _tier(String t) => switch (t) {
    'happy' => '해피',
    'good' => '굿',
    'bad' => '배드',
    'solo' => '솔로',
    'hidden' => '히든',
    _ => '',
  };
}

/// 플래그 이름만으로는 무슨 조건인지 알 수 없어 사람 말로 옮긴다.
const _flagHints = {
  'hardcore': '하드코어 모드',
  'seoyeon_banmal': '서연에게 반말하기',
  'burnout_x3': '번아웃 3번',
  'album_20': '흑역사 20개 수집',
  'chose_loop': '100일째의 마지막 선택',
  'jiwoo_intro': '엄마의 소개팅 나가기',
  'yeeun_avoid_1': '옛날 얘기 피하기',
  'fake_record': '운동일지에 거짓말',
  'learner': '준호의 비결 묻기',
};

/// 미획득 엔딩의 한 줄 힌트. 홈과 앨범이 같은 문장을 쓴다(HOME_REDESIGN §0.2).
///
/// 작가가 쓴 [Ending.hint] 가 있으면 그것을, 없으면 조건에서 기계 문장을 만든다.
/// 하한이 있으면 "N 이상", 상한만 있으면 "N 이하"로 읽기 쉽게 옮긴다.
String endingHintFor(Ending e, GameController c) {
  final human = e.hint?.trim();
  if (human != null && human.isNotEmpty) return c.say(human);

  final w = e.when;
  final parts = <String>[];

  void rel(Map<String, Range> src, String label) {
    for (final x in src.entries) {
      final name = c.characterName(x.key == '*' ? e.character : x.key);
      if (x.value.min > 0) {
        parts.add('$name $label ${x.value.min} 이상');
      } else if (x.value.max < 100) {
        parts.add('$name $label ${x.value.max} 이하');
      }
    }
  }

  rel(w.trust, '신뢰');
  rel(w.affection, '호감');
  for (final x in w.stats.entries) {
    parts.add(
      x.value.min > 0
          ? '${Stat.label(x.key)} ${x.value.min} 이상'
          : '${Stat.label(x.key)} ${x.value.max} 이하',
    );
  }
  if (w.anyAffection != null) {
    parts.add('호감 ${w.anyAffection!.min} 이상인 사람 ${w.anyAffection!.count}명');
  }
  for (final f in w.flags) {
    parts.add(_flagHints[f] ?? f);
  }
  if (w.run != null && w.run!.min > 1) parts.add('${w.run!.min}회차 이상');

  if (parts.isEmpty) {
    return e.isDefault ? '아무것도 이루지 못했을 때' : '조건을 찾아보자';
  }
  // 다 보여 주면 재미가 없다. 두 개까지만.
  final shown = parts.take(2).join(' · ');
  return parts.length > 2 ? '$shown 외 ${parts.length - 2}개' : shown;
}

/// 엔딩 한 장.
///
/// 획득: 좌측 강조 띠 + 메달(체크) + 이름 + 티어 pill + 에필로그 — 트로피.
/// 미획득: 자물쇠 메달 + `'???'` + 조건 힌트. 카드 전체를 흐리게 하지 않고
/// 제목과 자물쇠의 글자색만 [AppTokens.lockedForeground] 로 내린다(§2.6).
class _EndingCard extends StatelessWidget {
  final String title;
  final String body;
  final String tierLabel;
  final bool owned;
  final CharacterAccent accent;

  /// 본 엔딩의 그림 썸네일. 있으면 메달 대신 이것을, 카드를 누르면 크게 보기.
  final Widget? thumb;
  final VoidCallback? onTap;

  const _EndingCard({
    required this.title,
    required this.body,
    required this.tierLabel,
    required this.owned,
    required this.accent,
    this.thumb,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;

    return AppCard(
      padding: AppInsets.cardTight,
      accentStripe: owned ? accent.base : null,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 메달. 획득 여부를 색이 아니라 모양(체크/자물쇠)으로 먼저 알린다.
          // 본 엔딩에 그림이 있으면 그 자리에 썸네일(그 자체가 '봤다' 는 표시다).
          if (thumb != null)
            thumb!
          else
            Container(
              constraints: const BoxConstraints(
                minWidth: AppSpace.huge,
                minHeight: AppSpace.huge,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: owned ? accent.container : scheme.surfaceContainerHigh,
                borderRadius: AppRadius.rPill,
                border: Border.all(
                  color: owned ? accent.base : scheme.outlineVariant,
                  width: AppBorderWidth.hairline,
                ),
              ),
              child: Icon(
                owned ? Icons.check_circle : Icons.lock_outline,
                size: 20,
                color: owned ? accent.base : t.lockedForeground,
              ),
            ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        keepAll(title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium?.copyWith(
                          // 잠김은 자물쇠 메달이 먼저 말한다. 글자는 본문 대비(4.5:1)를 지킨다.
                          color: owned
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (tierLabel.isNotEmpty) ...[
                      const SizedBox(width: AppSpace.sm),
                      _TierPill(label: tierLabel, owned: owned, accent: accent),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  keepAll(body),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 본 엔딩의 세로 썸네일(3:4). 엔딩 그림은 대부분 세로 2:3 이라 얼굴이 있는 위쪽에 맞춘다.
/// 티어 색 보정(배드 = 바램, 히든 = 세피아)은 엔딩 화면 히어로와 같다([EndingHero.matrixFor]).
class _EndingThumb extends StatelessWidget {
  final String path;
  final String tier;
  final AssetBundle? bundle;
  final CharacterAccent accent;

  const _EndingThumb({
    required this.path,
    required this.tier,
    required this.bundle,
    required this.accent,
  });

  /// 썸네일 폭. 메달(40)보다 조금 넓고, 3:4 로 세우면 카드 세 줄 높이와 맞는다.
  static const double width = AppSize.avatarLg;

  @override
  Widget build(BuildContext context) {
    Widget img = ClipRRect(
      borderRadius: AppRadius.rSm,
      child: SizedBox(
        width: width,
        height: width / SceneFrame.portraitMin,
        child: SceneImage(
          path: path,
          width: width,
          bundle: bundle,
          alignment: Alignment.topCenter,
          fallback: (context) => ColoredBox(color: accent.container),
        ),
      ),
    );
    final matrix = EndingHero.matrixFor(tier);
    if (matrix != null) {
      img = ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: img);
    }
    return ExcludeSemantics(
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: AppRadius.rSm,
          border: Border.all(
            color: accent.base,
            width: AppBorderWidth.hairline,
          ),
        ),
        child: img,
      ),
    );
  }
}

/// 티어 라벨 pill. 획득이면 캐릭터 강조색, 미획득이면 중립.
class _TierPill extends StatelessWidget {
  final String label;
  final bool owned;
  final CharacterAccent accent;

  const _TierPill({
    required this.label,
    required this.owned,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: owned ? accent.container : scheme.surfaceContainerHigh,
        borderRadius: AppRadius.rPill,
        border: Border.all(
          color: owned ? accent.base : scheme.outlineVariant,
          width: AppBorderWidth.hairline,
        ),
      ),
      child: Text(
        keepAll(label),
        style: context.text.labelSmall?.copyWith(
          color: owned ? accent.onContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 엔딩 목록 필터 칩 줄(전체 · 여성 · 남성 · 공용). DESIGN_SYSTEM §3.2.
/// 선택 상태는 색 + 체크 아이콘으로 알린다(색만으로 전하지 않는다).
class EndingFilterBar extends StatelessWidget {
  final EndingFilter value;
  final ValueChanged<EndingFilter> onChanged;

  const EndingFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpace.sm,
    runSpacing: AppSpace.sm,
    children: [
      for (final f in EndingFilter.values)
        ChoiceChip(
          key: Key('ending-filter-${f.name}'),
          label: Text(f.label),
          selected: f == value,
          avatar: f == value ? const Icon(Icons.check, size: 16) : null,
          onSelected: (_) => onChanged(f),
        ),
    ],
  );
}
