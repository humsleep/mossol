import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../analytics/analytics.dart';
import '../engine/models.dart';
import '../game_controller.dart';
import 'album_screen.dart';
import 'design_system.dart';
import 'heat_gauge.dart';
import 'keep_all.dart';
import 'onboarding_gender_screen.dart';
import 'retention_widgets.dart';
import 'scene_card.dart' show SceneImage;
import 'scene_registry.dart';
import 'settings_screen.dart';
import 'start_pick_sheet.dart';
import 'widgets.dart';

/// 첫 화면 v2. 규격은 docs/HOME_REDESIGN.md §1 (요약은 DESIGN_SYSTEM §2.1).
///
/// 블록은 위에서 아래로 A 헤더 → 배너 → B 히어로 카드 → C 자원 줄(세이브 있음만) → D 출석 줄
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
      // 배너는 헤더 줄 **아래**(DESIGN_SYSTEM §2 공통). 다른 화면이 앱바 아래에 두는 것과 같은
      // 자리다 — 앱을 켠 첫 화면의 맨 위가 광고이고 앱 이름이 그 아래였다(00_VERDICT §3 R3).
      // 헤더는 좌우 여백을 직접 먹고, 배너 아래부터가 스크롤 목록이다.
      // 광고를 기다리는 동안에는 이 화면의 탭을 전부 막는다(무반응처럼 보이는 8초).
      body: RewardedBusyScope(
        child: SafeArea(
          child: Column(
            children: [
              // A. 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenX,
                  AppSpace.screenY,
                  AppSpace.screenX,
                  0,
                ),
                child: _Header(onSettings: () => _openSettings(context)),
              ),
              const BannerSlot(edge: BannerEdge.top, safeArea: false),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenX,
                    AppSpace.md,
                    AppSpace.screenX,
                    AppSpace.xxl,
                  ),
                  children: [
                    // B. 히어로 카드. 키 아트(assets/keyart/home)가 있으면 소개 카드의 바탕,
                    // 이어하기 카드는 그 위 창(키 큰 화면만)에 깐다. 없으면 지금 그대로.
                    if (!hasSave)
                      _IntroCard(endings: _endingsPerRun)
                    else if (summary == null)
                      const ContinueCard.placeholder()
                    else
                      _KeyArtWindow(
                        child: ContinueCard(
                          run: summary.run,
                          chapter: summary.chapter,
                          day: summary.day,
                          totalDays: summary.totalDays,
                          cliffhanger: c.sayOrNull(summary.lastCliffhanger),
                          topName: c.characterOf(summary.topCharacterId)?.name,
                          topAffection: summary.topAffection,
                          topSignal: c.sayOrNull(summary.topSignal),
                          topAccent: summary.topCharacterId == null
                              ? null
                              : context.tokens.accentFor(
                                  summary.topCharacterId,
                                ),
                          // 선호가 없던 예전 세이브(all)는 표기하지 않는다.
                          preferenceLabel: summary.preference == Preference.all
                              ? null
                              : Preference.label(summary.preference),
                        ),
                      ),
                    // B-0. 지난 판 요약. 세이브가 없거나(엔딩 뒤 홈) 새 회차 첫날일 때만.
                    if (_previousRun(summary) case final line?) ...[
                      const SizedBox(height: AppSpace.sm),
                      PreviousRunNote(text: line),
                    ],
                    // B-1. 밤사이 멀어진 사람(어젯밤 마감 −1 로 구간 하락). 조용한 한 줄.
                    if (summary != null)
                      for (final e in summary.overnight.entries) ...[
                        const SizedBox(height: AppSpace.sm),
                        OvernightNote(id: e.key, text: c.say(e.value)),
                      ],
                    const SizedBox(height: AppSpace.lg),

                    // C. 자원 줄 — 세이브가 있고 요약을 읽었을 때만.
                    if (summary != null) ...[
                      _ResourceRow(c: c, hearts: summary.hearts),
                      // C-1. 소문 게이지. 소문이 1 이상인 회차에서만(01_design §5.1).
                      if (HeatGauge.shows(summary.heat)) ...[
                        const SizedBox(height: AppSpace.sm),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: HeatGauge(heat: summary.heat),
                        ),
                      ],
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
                        onPressed: () => _startNewGame(context),
                        child: const Text('새 게임'),
                      ),
                    const SizedBox(height: AppSpace.sectionGap),

                    // F. 사람들. 세이브가 없고 아직 쪽을 모르면(첫 실행 · 선택 안 함) 줄을 숨긴다.
                    if (summary != null || c.defaultSide != null) ...[
                      SectionHeader(
                        title: summary != null ? '사람들' : '등장인물',
                        trailing: summary != null
                            ? Text('호감 순', style: context.text.labelMedium)
                            : null,
                      ),
                      CastStrip(entries: _castEntries(summary)),
                      const SizedBox(height: AppSpace.sectionGap),
                    ],

                    // G. 앨범
                    _AlbumCard(c: c, onTap: () => _openAlbum(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "지난 판엔 …으로 끝났다". 진행 중인 회차가 첫날을 넘겼으면 이미 지난 이야기라 숨긴다.
  String? _previousRun(SaveSummary? summary) {
    if (c.hasSave && (summary == null || summary.day > 1)) return null;
    return c.previousRunLine;
  }

  /// 소개 카드의 "엔딩 N개 중 하나". 한 회차가 닿을 수 있는 수(그 쪽 캐릭터 엔딩 + 공용)다.
  /// 쪽을 모르면 두 쪽 중 큰 값(지금 데이터는 둘 다 같다).
  int get _endingsPerRun {
    final b = c.bundle;
    final side = c.defaultSide;
    if (side != null) return b.endingCountFor(side);
    return Preference.genders.map(b.endingCountFor).fold(0, max);
  }

  /// 호감 내림차순(동점은 characters.json 순). 히든은 호감이 생기기 전까지 맨 뒤 `???`.
  /// 세이브가 있으면 그 회차 선호에 맞는 사람만, 없으면 "나는?" 답의 기본 쪽(등장인물 소개).
  List<CastEntry> _castEntries(SaveSummary? summary) {
    final chars = c.bundle.charactersFor(
      summary?.preference ?? c.defaultSide ?? Preference.all,
    );
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

  void _openSettings(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => SettingsScreen(c: c)));

  void _openAlbum(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => AlbumScreen(c: c)));

  /// 진행 중인 회차를 지우기 전에 한 번 묻는다. 문구·동작은 그대로 둔다.
  Future<void> _confirmNewGame(BuildContext context) async {
    final ok = await showAppDialog<bool>(
      context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 게임'),
        content: Text(keepAll('진행 중인 회차가 지워집니다. 시작할까요?')),
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
    if (ok != true || !context.mounted) return;
    await _startNewGame(context);
  }

  /// 시작 카드(01_design §4.1 — 시작이 가장 큰 결정이라 맨 앞) → 온보딩("나는?", 답이 없을 때만)
  /// → 이름 · MBTI(아직 안 물었을 때만) → 캐스트 소개를 거쳐 새 게임. 뒤로 가면 아무것도
  /// 하지 않는다. 1단계 답은 새 게임이 실제로 시작될 때 기기 메타에 저장한다.
  ///
  /// 시작 카드 다음 단계에서 뒤로 나오면 시작 카드로 돌아온다(앞 단계로 돌아가는 규칙).
  /// 시작 정의가 없으면(클래식뿐) 카드 없이 예전 흐름 그대로다.
  Future<void> _startNewGame(BuildContext context) async {
    final hasStarts = c.bundle.starts.length > 1;
    String? start;
    // 뽑은 운명은 컨트롤러가 메타에 고정한다(r1_meeting D10) — 뒤로 가기·시트 닫기·앱 재시작
    // 어느 길로도 다시 뽑지 못한다. newGame 이 지운다.
    if (hasStarts) c.logOnboardingStep(Analytics.stepStart);
    NewGamePick? pick;
    while (pick == null) {
      final picked = await StartPickSheet.showPickFor(context, c);
      if (picked == null || !context.mounted) return;
      start = picked.id;
      pick = await OnboardingGenderScreen.run(
        context,
        c.bundle,
        savedGender: c.playerGender,
        askName: c.shouldAskName,
        askMbti: c.shouldAskMbti,
        savedMbti: c.playerMbti,
        onStep: c.logOnboardingStep,
        start: start,
      );
      if (pick == null && (!hasStarts || !context.mounted)) return;
    }
    final g = pick.gender;
    if (g != null) await c.setPlayerGender(g);
    // 이름 단계: 입력했으면 저장, 건너뛰었으면 다음부터 묻지 않는다(설정에서 바꿀 수 있다).
    if (pick.nameStep) {
      final n = pick.name;
      n == null ? await c.skipPlayerName() : await c.setPlayerName(n);
    }
    // MBTI 단계: 골랐으면 저장, 건너뛰었으면 다음부터 묻지 않는다. 새 게임이 이 값을 복사한다.
    if (pick.mbtiStep) {
      final m = pick.mbti;
      m == null ? await c.skipPlayerMbti() : await c.setPlayerMbti(m);
    }
    c.logOnboardingDone(
      preference: pick.preference,
      mbtiSource: pick.mbtiFromQuiz
          ? Analytics.mbtiQuiz
          : c.playerMbti == null
          ? Analytics.mbtiSkip
          : Analytics.mbtiToggle,
    );
    await c.newGame(
      preference: pick.preference,
      start: start ?? StartScenario.classic,
    );
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
            '모쏠 탈출기',
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

/// 홈 키 아트가 한 장을 다 차지해도 되는 화면인지. 높이 예산(§1.5, 320×568)을 지키려고
/// 작은 화면에서는 그림을 바탕으로만 깔고 자리를 더 잡지 않는다.
bool _roomyHome(BuildContext context) =>
    MediaQuery.sizeOf(context).height >= _KeyArt.roomyHeight;

/// 홈 키 아트 공용 값. 그림은 밤 책상(3:2)이라 라이트·다크 모두 밤 잉크 위에 올린다 —
/// 글자는 언제나 밤 글자색이고, 스크림이 그림을 눌러 본문 대비 4.5:1 을 지킨다.
abstract final class _KeyArt {
  /// 이 높이(pt) 이상이면 그림 창을 따로 연다.
  static const double roomyHeight = 700;

  /// 그림 초점. 가운데 책상의 휴대폰·달력이 보이게 조금 오른쪽 아래.
  static const Alignment focus = Alignment(0.2, 0.1);

  /// 스크림 색(밤 잉크)과 그 위 글자색. 테마와 무관하게 밤이다.
  static const Color ink = AppPalette.night;
  static const Color onInk = AppPalette.nightText;
  static const Color onInkAccent = AppPalette.rose300;
}

/// B-1. 소개 카드(세이브 없음). 화면에서 primaryContainer 를 쓰는 유일한 면.
/// 3초 안에 "아침에 고르고, 밤에 톡 하고, 100일 뒤 엔딩" 이 읽혀야 한다.
///
/// 키 아트가 있으면 같은 내용을 밤 책상 그림 위에 올린다. 위쪽은 그림이 보이고 글자가 놓인
/// 아래쪽으로 갈수록 스크림이 짙어진다(글자 뒤 스크림 α0.86 이상 → 본문 대비 4.5:1 이상).
class _IntroCard extends StatelessWidget {
  /// 엔딩 총수. 캐릭터가 늘면 같이 는다(하드코딩 금지).
  final int endings;
  const _IntroCard({required this.endings});

  List<Widget> _body(BuildContext context, Color fg, Color label) => [
    Text('100일 프로젝트', style: context.text.labelSmall?.copyWith(color: label)),
    const SizedBox(height: AppSpace.xs),
    Text(
      keepAll('100일 뒤, 나는 달라져 있을까'),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: context.text.headlineMedium?.copyWith(color: fg),
    ),
    const SizedBox(height: AppSpace.md),
    _Step(Icons.wb_twilight, '아침: 오늘 할 일 하나 고르기', color: fg),
    const SizedBox(height: AppSpace.sm),
    _Step(Icons.chat_bubble_outline, '밤: 메신저로 대화하기', color: fg),
    const SizedBox(height: AppSpace.sm),
    _Step(Icons.auto_stories_outlined, '100일: 엔딩 $endings개 중 하나', color: fg),
  ];

  @override
  Widget build(BuildContext context) => SceneScope(
    builder: (context, registry) {
      final art = SceneImages.homeKeyart(registry: registry);
      if (art == null) {
        final fg = context.scheme.onPrimaryContainer;
        return AppCard(
          tone: AppTone.brand,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _body(context, fg, fg),
          ),
        );
      }
      return _KeyArtCard(
        path: art,
        bundle: registry.bundle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _body(context, _KeyArt.onInk, _KeyArt.onInkAccent),
        ),
      );
    },
  );
}

/// 키 아트를 바탕으로 깐 히어로 카드. 넓은 화면이면 위에 그림만 보이는 창(폭의 30%)을 연다.
class _KeyArtCard extends StatelessWidget {
  final String path;
  final AssetBundle? bundle;
  final Widget child;

  const _KeyArtCard({
    required this.path,
    required this.bundle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final window = _roomyHome(context) ? box.maxWidth * 0.3 : 0.0;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: _KeyArt.ink,
          borderRadius: AppRadius.rXl,
          boxShadow: context.isDark ? null : context.tokens.shadowCard,
        ),
        child: ClipRRect(
          borderRadius: AppRadius.rXl,
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: SceneImage(
                    path: path,
                    width: box.maxWidth,
                    bundle: bundle,
                    alignment: _KeyArt.focus,
                  ),
                ),
              ),
              // 스크림: 위는 그림이 숨 쉬고, 글자가 시작되는 곳부터 짙어진다.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _KeyArt.ink.withValues(alpha: window > 0 ? 0.05 : 0.72),
                        _KeyArt.ink.withValues(alpha: 0.86),
                        _KeyArt.ink.withValues(alpha: 0.92),
                      ],
                      stops: [0, window > 0 ? 0.42 : 0.3, 1],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: AppInsets.card.add(EdgeInsets.only(top: window)),
                child: child,
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 이어하기 카드 위의 키 아트 창. 넓은 화면에서만 연다 — 카드가 그림 아래쪽을 살짝 덮어
/// 한 덩어리로 읽힌다. 그림에는 글자가 없어 대비 문제가 없다(장식, 스크린리더 제외).
class _KeyArtWindow extends StatelessWidget {
  final Widget child;
  const _KeyArtWindow({required this.child});

  @override
  Widget build(BuildContext context) => SceneScope(
    builder: (context, registry) {
      final art = SceneImages.homeKeyart(registry: registry);
      if (art == null || !_roomyHome(context)) return child;
      return LayoutBuilder(
        builder: (context, box) {
          final h = box.maxWidth / 2.4;
          return Stack(
            children: [
              SizedBox(
                height: h,
                width: box.maxWidth,
                child: ClipRRect(
                  // 아래 모서리는 카드가 덮는다. 카드의 둥근 윗모서리 너머로 그림이 이어진다.
                  borderRadius: AppRadius.rXl,
                  child: ExcludeSemantics(
                    child: SceneImage(
                      path: art,
                      width: box.maxWidth,
                      bundle: registry.bundle,
                      alignment: _KeyArt.focus,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: h - AppSpace.xxxl),
                child: child,
              ),
            ],
          );
        },
      );
    },
  );
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Step(this.icon, this.text, {required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: AppSpace.sm),
      Expanded(
        child: Text(
          keepAll(text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyMedium?.copyWith(color: color),
        ),
      ),
    ],
  );
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
          RewardedButton(
            placement: 'heart_home',
            // 홈 전용 짧은 문구. 스크린리더에는 행동 화면과 같은 문장을 읽힌다.
            label: '광고로 +1',
            semanticsLabel: '광고 보고 하트 받기',
            onEarned: c.grantHeart,
          ),
        ],
      ],
    );
  }
}

/// G. 앨범 카드. 엔딩 컬렉션만 — 흑역사 수는 앨범 안에서 본다.
class _AlbumCard extends StatelessWidget {
  final GameController c;
  final VoidCallback onTap;
  const _AlbumCard({required this.c, required this.onTap});

  /// endings.json 순서로 훑어 미획득이면서 배드·히든이 아닌 첫 엔딩의 힌트.
  /// 해피·굿·솔로를 다 봤으면 남은 것을, 전부 다 봤으면 그 사실을 말한다.
  ///
  /// 고르는 범위는 [homeHintScope]: 세이브가 있으면 그 회차 쪽 + 공용, 없으면 "나는?" 답의
  /// 기본 쪽 + 공용, 쪽을 모르면 공용 먼저(공용을 다 봤으면 전체).
  String _hintLine() {
    final got = c.endingAlbum.toSet();
    final all = c.bundle.endings;
    if (all.isNotEmpty && got.length >= all.length) return '모든 엔딩을 봤다';
    final scope = homeHintScope(c);
    Ending? first(Iterable<Ending> es) {
      for (final e in es) {
        if (got.contains(e.id) || e.tier == 'bad' || e.tier == 'hidden') {
          continue;
        }
        return e;
      }
      return null;
    }

    final e =
        first(all.where(scope.contains)) ?? (scope.neutral ? first(all) : null);
    if (e != null) return '다음 엔딩 힌트 · ${endingHintFor(e, c)}';
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
                  keepAll(
                    '앨범  ${c.endingAlbum.length} / ${c.bundle.endings.length}',
                  ),
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
              for (final e in totals.entries)
                e.key: (counts[e.key] ?? 0, e.value),
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
                  keepAll(_hintLine()),
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

/// 밤사이 멀어진 사람의 조용한 한 줄. 경고색 없이 캐릭터 점 + 흐린 글씨.
/// 행동 화면(어젯밤 마감 직후 첫 화면)과 홈이 같이 쓴다.
class OvernightNote extends StatelessWidget {
  final String id;
  final String text;
  const OvernightNote({super.key, required this.id, required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = context.scheme.onSurfaceVariant;
    return Semantics(
      label: '밤사이: $text',
      excludeSemantics: true,
      child: Row(
        key: Key('overnight-$id'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xs),
            child: Icon(
              Icons.nights_stay_outlined,
              size: AppSpace.lg,
              color: context.tokens.accentFor(id).base,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              keepAll(text),
              style: context.text.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// 홈 앨범 카드의 "다음 엔딩 힌트" 가 고르는 범위.
///
/// - 세이브가 있으면 그 회차 선호 쪽 + 공용(예전 세이브 `all` 은 전체).
/// - 세이브가 없고 "나는?" 답이 남자/여자면 그 기본 쪽 + 공용.
/// - 쪽을 모르면(첫 실행 · 선택 안 함) 공용만. [neutral] 이라 공용을 다 봤으면 전체로 넓힌다.
typedef HintScope = ({bool Function(Ending) contains, bool neutral});

HintScope homeHintScope(GameController c) {
  final b = c.bundle;
  final pref = c.saveSummary?.preference ?? c.defaultSide;
  if (pref == Preference.all) return (contains: (_) => true, neutral: false);
  if (pref != null) {
    return (contains: (e) => b.endingInPreference(e, pref), neutral: false);
  }
  return (contains: (e) => b.endingSide(e) == null, neutral: true);
}
