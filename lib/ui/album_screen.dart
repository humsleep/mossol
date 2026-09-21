import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../game_controller.dart';
import 'design_system.dart';
import 'widgets.dart';
import 'keep_all.dart';

/// 흑역사 앨범과 엔딩 앨범. 실패도 수집 요소가 된다.
///
/// 규격: docs/DESIGN_SYSTEM.md §2.6.
/// - 주인공은 상단 수집 진행도와 카드 목록, 배경은 탭 바와 티어 라벨.
/// - 엔딩은 트로피(메달 + 좌측 강조 띠), 흑역사는 번호가 붙은 수집 카드.
/// - 미획득은 불투명도를 내리지 않고 자물쇠 + 글자색으로만 구분한다.
class AlbumScreen extends StatelessWidget {
  final GameController c;
  const AlbumScreen({super.key, required this.c});

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
        body: TabBarView(
          children: [
            _ShameTab(c: c),
            _EndingTab(c: c),
          ],
        ),
        bottomNavigationBar: const BannerSlot(),
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
    return ListView(
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
          _ShameCard(number: i + 1, text: album[i]),
          if (i > 0) const SizedBox(height: AppSpace.listGap),
        ],
      ],
    );
  }
}

/// 흑역사 한 장. 번호 메달이 붙은 수집 카드처럼 보이게 한다.
class _ShameCard extends StatelessWidget {
  final int number;
  final String text;

  const _ShameCard({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: AppInsets.cardTight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 고정 높이 대신 최소 크기. 글자를 키워도 번호가 잘리지 않는다.
          Container(
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
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Text(text, style: context.text.bodyMedium),
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
    return ListView(
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
              return _EndingCard(
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

  const _EndingCard({
    required this.title,
    required this.body,
    required this.tierLabel,
    required this.owned,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;

    return AppCard(
      padding: AppInsets.cardTight,
      accentStripe: owned ? accent.base : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 메달. 획득 여부를 색이 아니라 모양(체크/자물쇠)으로 먼저 알린다.
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
