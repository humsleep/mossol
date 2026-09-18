import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../game_controller.dart';
import 'album_screen.dart';
import 'design_system.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// 첫 화면 v2. 규격은 docs/HOME_REDESIGN.md §1 (요약은 DESIGN_SYSTEM §2.1).
///
/// 블록은 위에서 아래로 A 헤더 → B 히어로 카드 → C 자원 줄(세이브 있음만) → D 출석 줄
/// → E 1차 버튼 → F 사람들 → G 앨범. 1차 버튼은 여전히 하나(`이어하기` 또는 `새 게임`)이고
/// 나머지는 전부 한 단 이상 뒤로 물러난다. 배경은 `surface` 단색 — 상단 40% 여백과
/// 로즈 그라데이션은 실기기에서 휑함으로 읽혀 폐지했다.
class HomeScreen extends StatefulWidget {
  final GameController c;
  const HomeScreen({super.key, required this.c});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameController get c => widget.c;

  /// 홈 진입 때의 출석 결과. null 이면 아직 답이 안 온 첫 프레임.
  CheckInResult? _checkIn;

  /// 출석 처리 전에 이미 오늘 출석했었는지. 답이 오기 전 프레임의 줄 상태에 쓴다.
  bool _wasCheckedIn = false;

  /// `받기` 를 눌러 보상 줄을 수령 상태로 넘겼는지.
  bool _claimed = false;

  /// 하트 타이머. 1초마다 남은 시간을 다시 그리고 찬 하트를 반영한다.
  Timer? _timer;

  /// 어느 메타·어느 날짜에 대해 출석을 처리했는지. 설정의 저장 초기화는 메타 객체를
  /// 새로 만들고, 홈을 켜 둔 채 자정을 넘기면 날짜가 바뀐다 — 둘 다 "홈에 새로
  /// 들어온 것" 과 같으므로 출석을 다시 돈다. 시계가 과거로 가는 경우는 키가 그대로라
  /// 매초 다시 부르지 않는다.
  String? _entryKey;

  String get _currentEntryKey =>
      '${identityHashCode(c.meta)}|'
      '${Attendance.dateKey(DateTime.fromMillisecondsSinceEpoch(c.nowMs()))}';

  @override
  void initState() {
    super.initState();
    _beginCheckIn();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  /// 홈 진입(또는 그와 같은 상황)의 출석 처리 시작. 줄 상태를 초기화하고 컨트롤러에 묻는다.
  void _beginCheckIn() {
    _entryKey = _currentEntryKey;
    _checkIn = null;
    _claimed = false;
    _wasCheckedIn = c.checkedInToday;
    unawaited(_checkInOnEntry());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 홈 진입 = 출석. 오늘 첫 출석이면 보상은 컨트롤러가 바로 얹고, 줄은 `받기` 를
  /// 누를 때까지 미수령 모습으로 남아 "오늘 받은 것" 을 알린다.
  Future<void> _checkInOnEntry() async {
    final key = _entryKey;
    final r = await c.checkInToday();
    // 답을 기다리는 사이 초기화가 일어났으면 이 답은 지난 메타의 것이다.
    if (!mounted || key != _entryKey) return;
    setState(() => _checkIn = r);
  }

  void _tick(Timer _) {
    if (!mounted) return;
    if (c.meta != null && _entryKey != _currentEntryKey) {
      // 저장 초기화(새 메타) 또는 자정 통과. 수령 상태로 굳은 줄을 풀고 다시 출석한다.
      setState(_beginCheckIn);
    }
    if (!c.hasSave || c.saveSummary == null || c.heartsFull) return;
    unawaited(c.refreshHearts());
    setState(() {});
  }

  RewardStripState get _stripState {
    final r = _checkIn;
    final first = r == null ? !_wasCheckedIn : r.first;
    if (!first || _claimed) return RewardStripState.claimed;
    return r?.extra == null
        ? RewardStripState.unclaimed
        : RewardStripState.unclaimedBonus;
  }

  /// 연속 출석 보너스 문구. 3일은 하트가 하나 더, 7일은 둘 더 + 재도전권.
  String? get _bonusLabel => switch (_checkIn?.extra) {
    Attendance.extraStreak3 => '보너스 하트 +${Attendance.streak3Bonus}',
    Attendance.extraStreak7 =>
      '보너스 하트 +${Attendance.streak7Bonus} · 룰렛 재도전권 +1',
    _ => null,
  };

  Future<void> _claim() async {
    if (!mounted) return;
    setState(() => _claimed = true);
  }

  @override
  Widget build(BuildContext context) {
    final hasSave = c.hasSave;
    final summary = hasSave ? c.saveSummary : null;
    final scheme = context.scheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screenX,
            AppSpace.screenY,
            AppSpace.screenX,
            AppSpace.xxl,
          ),
          children: [
            // A. 헤더
            _Header(onSettings: () => _openSettings(context)),
            const SizedBox(height: AppSpace.md),

            // B. 히어로 카드
            if (!hasSave)
              const _IntroCard()
            else if (summary == null)
              const ContinueCard.placeholder()
            else
              ContinueCard(
                run: summary.run,
                chapter: summary.chapter,
                day: summary.day,
                totalDays: summary.totalDays,
                cliffhanger: summary.lastCliffhanger,
                topName: c.characterOf(summary.topCharacterId)?.name,
                topAffection: summary.topAffection,
                topAccent: summary.topCharacterId == null
                    ? null
                    : context.tokens.accentFor(summary.topCharacterId),
              ),
            const SizedBox(height: AppSpace.lg),

            // C. 자원 줄 — 세이브가 있고 요약을 읽었을 때만.
            if (summary != null) ...[
              _ResourceRow(c: c, hearts: summary.hearts),
              const SizedBox(height: AppSpace.md),
            ],

            // D. 출석 줄
            RewardStrip(
              state: _stripState,
              streakDays: c.streakDays,
              bonusLabel: _bonusLabel,
              pendingHearts: hasSave ? 0 : c.pendingHearts,
              onClaim: _claim,
            ),
            const SizedBox(height: AppSpace.md),

            // E. 1차 버튼 묶음
            if (hasSave) ...[
              FilledButton(
                onPressed: () => c.continueGame(),
                child: const Text('이어하기'),
              ),
              const SizedBox(height: AppSpace.sm),
              TextButton(
                onPressed: () => _confirmNewGame(context),
                // DS §5.7 예외 ②: 2차 버튼을 1차와 다른 무게로.
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                ),
                child: const Text('새 게임'),
              ),
            ] else
              FilledButton(
                onPressed: () => c.newGame(),
                child: const Text('새 게임'),
              ),
            const SizedBox(height: AppSpace.sectionGap),

            // F. 사람들
            SectionHeader(
              title: summary != null ? '사람들' : '등장인물',
              trailing: summary != null
                  ? Text('호감 순', style: context.text.labelMedium)
                  : null,
            ),
            CastStrip(entries: _castEntries(summary)),
            const SizedBox(height: AppSpace.sectionGap),

            // G. 앨범
            _AlbumCard(c: c, onTap: () => _openAlbum(context)),
          ],
        ),
      ),
      bottomNavigationBar: const BannerSlot(),
    );
  }

  /// 호감 내림차순(동점은 characters.json 순). 히든은 호감이 생기기 전까지 맨 뒤 `???`.
  List<CastEntry> _castEntries(SaveSummary? summary) {
    final chars = c.bundle.characters;
    final known = <CastEntry>[];
    final mystery = <CastEntry>[];
    for (final ch in chars) {
      final aff = summary?.affectionOf(ch.id);
      if (ch.hidden && (aff ?? 0) <= 0) {
        mystery.add(CastEntry(id: ch.id, name: ch.name, mystery: true));
      } else {
        known.add(CastEntry(id: ch.id, name: ch.name, affection: aff));
      }
    }
    if (summary != null) {
      // 안정 정렬이라 동점은 원래 순서를 지킨다.
      known.sort((a, b) => (b.affection ?? 0).compareTo(a.affection ?? 0));
    }
    return [...known, ...mystery];
  }

  void _openSettings(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => SettingsScreen(c: c)),
  );

  void _openAlbum(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => AlbumScreen(c: c)),
  );

  /// 진행 중인 회차를 지우기 전에 한 번 묻는다. 문구·동작은 그대로 둔다.
  Future<void> _confirmNewGame(BuildContext context) async {
    final ok = await showAppDialog<bool>(
      context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 게임'),
        content: const Text('진행 중인 회차가 지워집니다. 시작할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('시작'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await c.newGame();
  }
}

/// A. 헤더 줄. 높이 44 고정 — 워드마크는 titleLarge 라 1.3배에서도 44 안에 든다.
/// 워드마크는 onSurface. 로즈로 물들이지 않는다(primary 는 버튼 몫).
class _Header extends StatelessWidget {
  final VoidCallback onSettings;
  const _Header({required this.onSettings});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppSpace.minTouch,
    child: Row(
      children: [
        Expanded(
          child: Text(
            '모쏠 키우기',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleLarge,
          ),
        ),
        IconButton(
          onPressed: onSettings,
          tooltip: '설정',
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
  );
}

/// B-1. 소개 카드(세이브 없음). 화면에서 primaryContainer 를 쓰는 유일한 면.
/// 3초 안에 "아침에 고르고, 밤에 톡 하고, 100일 뒤 엔딩" 이 읽혀야 한다.
class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final fg = context.scheme.onPrimaryContainer;
    return AppCard(
      tone: AppTone.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('100일 프로젝트', style: context.text.labelSmall?.copyWith(color: fg)),
          const SizedBox(height: AppSpace.xs),
          Text(
            '100일 뒤, 이 남자는 달라져 있을까',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.headlineMedium?.copyWith(color: fg),
          ),
          const SizedBox(height: AppSpace.md),
          const _Step(Icons.wb_twilight, '아침: 오늘 할 일 하나 고르기'),
          const SizedBox(height: AppSpace.sm),
          const _Step(Icons.chat_bubble_outline, '밤: 메신저로 대화하기'),
          const SizedBox(height: AppSpace.sm),
          const _Step(Icons.auto_stories_outlined, '100일: 엔딩 30개 중 하나'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Step(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final fg = context.scheme.onPrimaryContainer;
    return Row(
      children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(color: fg),
          ),
        ),
      ],
    );
  }
}

/// C. 자원 줄. 하트는 "지금 이어할 수 있나" 의 답이지 화면의 주인공이 아니다.
/// 한 줄 고정 — Wrap 을 쓰면 두 줄이 되어 높이 예산이 깨진다(§1.5).
class _ResourceRow extends StatelessWidget {
  final GameController c;
  final int hearts;
  const _ResourceRow({required this.c, required this.hearts});

  @override
  Widget build(BuildContext context) {
    final max = c.config.maxHearts;
    final canWatch = hearts < max && AdManager.instance.supported;
    return Row(
      children: [
        Expanded(
          child: HeartsRow(
            hearts: hearts,
            max: max,
            nextIn: Duration(seconds: c.secondsToNextHeart),
          ),
        ),
        if (canWatch) ...[
          const SizedBox(width: AppSpace.sm),
          TextButton.icon(
            onPressed: () => _watchAd(context),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            // 홈 전용 짧은 문구. 스크린리더에는 행동 화면과 같은 문장을 읽힌다.
            label: const Text('광고로 +1', semanticsLabel: '광고 보고 하트 받기'),
          ),
        ],
      ],
    );
  }

  Future<void> _watchAd(BuildContext context) async {
    final earned = await AdManager.instance.showRewarded();
    if (earned) {
      await c.grantHeart();
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('광고를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.'),
        ),
      );
    }
  }
}

/// G. 앨범 카드. 엔딩 컬렉션만 — 흑역사 수는 앨범 안에서 본다.
class _AlbumCard extends StatelessWidget {
  final GameController c;
  final VoidCallback onTap;
  const _AlbumCard({required this.c, required this.onTap});

  /// endings.json 순서로 훑어 미획득이면서 배드·히든이 아닌 첫 엔딩의 힌트.
  /// 해피·굿·솔로를 다 봤으면 남은 것을, 30개를 다 봤으면 그 사실을 말한다.
  String _hintLine() {
    final got = c.endingAlbum.toSet();
    final all = c.bundle.endings;
    if (all.isNotEmpty && got.length >= all.length) return '모든 엔딩을 봤다';
    for (final e in all) {
      if (got.contains(e.id) || e.tier == 'bad' || e.tier == 'hidden') continue;
      return '다음 엔딩 힌트 · ${endingHintFor(e, c)}';
    }
    return '남은 건 배드 엔딩과 히든뿐이다';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final totals = c.endingTotalsByTier;
    final counts = c.endingCountsByTier;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_album_outlined,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                // 공백 두 개, 단일 Text(테스트 고정).
                child: Text(
                  '앨범  ${c.endingAlbum.length} / ${c.bundle.endings.length}',
                  maxLines: 1,
                  style: t.numericMedium,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          EndingTierDots(
            counts: {
              for (final e in totals.entries) e.key: (counts[e.key] ?? 0, e.value),
            },
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xxs),
                child: Icon(Icons.lightbulb_outline, size: 16, color: t.info),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  _hintLine(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
