import 'package:flutter/material.dart';

import '../engine/meta_service.dart';
import '../engine/models.dart';
import '../engine/save_service.dart';
import '../engine/signals.dart';
import '../engine/story_repository.dart';
import '../game_controller.dart';
import '../minigames/minigame.dart';
import '../minigames/registry.dart';
import '../ui/action_screen.dart';
import '../ui/design_system.dart';
import '../ui/ending_screen.dart';
import '../ui/event_screen.dart';
import '../ui/home_screen.dart';
import '../ui/onboarding_gender_screen.dart';
import '../ui/preference_screen.dart';
import '../ui/summary_screen.dart';
import '../ui/widgets.dart';

/// QA 용 디버그 갤러리. 미니게임 12종과 엔딩 화면을 100일 플레이 없이 연다.
///
/// 진입: `flutter run --dart-define=MOSSOL_DEBUG_GALLERY=true` (디버그 빌드에서만).
/// main.dart 가 `if (kDebugMode && kDebugGallery)` 로 분기하므로 릴리스 빌드에서는
/// 이 파일 전체가 트리셰이킹된다.
const bool kDebugGallery = bool.fromEnvironment('MOSSOL_DEBUG_GALLERY');

class DebugGalleryApp extends StatelessWidget {
  final StoryBundle bundle;
  const DebugGalleryApp({super.key, required this.bundle});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '모쏠 키우기 · 디버그 갤러리',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: DebugGalleryScreen(bundle: bundle),
    );
  }
}

class DebugGalleryScreen extends StatefulWidget {
  final StoryBundle bundle;
  const DebugGalleryScreen({super.key, required this.bundle});

  @override
  State<DebugGalleryScreen> createState() => _DebugGalleryScreenState();
}

class _DebugGalleryScreenState extends State<DebugGalleryScreen> {
  static const _tiers = ['happy', 'good', 'solo', 'bad', 'hidden'];
  static const _tierLabels = {
    'happy': '해피',
    'good': '굿',
    'solo': '솔로',
    'bad': '배드',
    'hidden': '히든',
  };

  /// 미니게임 난이도에 쓰는 상대. null 이면 기본값(replyZone 가운데, warm).
  String? _partnerId;

  /// 미리보기 회차의 선호. 모먼트·정산·홈·엔딩 미리보기가 이 쪽 캐릭터로 꾸며진다.
  String _pref = Preference.all;

  StoryBundle get bundle => widget.bundle;

  /// 미리보기 선호에서 등장하는 캐릭터.
  List<CharacterDef> get _roster => bundle.charactersFor(_pref);

  /// 미니게임·엔딩에 넘길 샘플 상태. 눈치 30 정도의 중반 플레이어.
  GameState _sampleState({int day = 40}) {
    final s = GameState.fresh(
      bundle.config,
      bundle.characters,
      seed: 7,
      preference: _pref,
    )..day = day;
    for (final k in [Stat.charm, Stat.talk, Stat.esteem, Stat.sense]) {
      s.stats[k] = 30 + (s.stats[k] ?? 0);
    }
    return s;
  }

  Future<void> _openMinigame(String id) async {
    final ctx = MinigameContext(
      state: _sampleState(),
      partner: bundle.characterById[_partnerId],
    );
    final r = await playMinigame(context, id, ctx);
    if (!mounted) return;
    final verdict = r.critical ? '크리티컬' : (r.success ? '성공' : '실패');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${minigameLabels[id] ?? id}: $verdict · score ${r.score.toStringAsFixed(2)}'
            '${r.message.isEmpty ? '' : ' · ${r.message}'}',
          ),
        ),
      );
  }

  Future<void> _openEnding(Ending e) async {
    // 실제 SaveService 를 쓰면 기기의 진짜 세이브를 덮어쓴다. 메모리 세이브로 대체.
    final c = GameController(bundle: bundle, save: _MemorySave());
    final s = _sampleState(day: bundle.config.totalDays + 1);
    final who =
        e.character ??
        (_roster.isEmpty ? bundle.characters.first.id : _roster.first.id);
    s.relations[who]
      ?..affection = e.tier == 'solo' || e.tier == 'bad' ? 20 : 85
      ..trust = 60;
    if (e.tier == 'bad') s.album.addAll(List.filled(7, 'sample'));
    c
      ..state = s
      ..ending = e
      ..phase = Phase.ending;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _EndingPreview(controller: c)),
    );
  }

  /// 모먼트 미리보기: 합성 이벤트 하나를 실제 EventScreen 으로 연다.
  /// 메모리 세이브라 기기 세이브를 건드리지 않는다. 결과 패널의 '계속' 이면 돌아온다.
  Future<void> _openMoment(StoryEvent ev) async {
    final c = GameController(bundle: bundle, save: _MemorySave());
    c
      ..state = _sampleState(day: 12)
      ..current = ev
      ..revealed = 0
      ..phase = Phase.event;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _MomentPreview(controller: c)),
    );
  }

  // ---- 정산·홈 미리보기 ----
  //
  // 컨트롤러·엔진은 건드리지 않고 공개 필드(state, dayDelta, cliffhanger, phase,
  // hasSave, saveSummary)로 "그날 밤" 을 꾸민 뒤 실제 화면을 띄운다. 호감은 서사 신호
  // 구간 경계를 넘도록 잡고, 그 캐릭터의 문장이 실제로 뽑히는지 shiftFor 로 먼저 확인한다.

  /// 메모리 세이브·메모리 메타 컨트롤러. 기기 세이브와 출석 기록을 건드리지 않는다.
  GameController _previewController(GameState s) =>
      GameController(bundle: bundle, save: _MemorySave(), meta: _MemoryMeta())
        ..state = s;

  /// 룰렛 시트가 뜨지 않도록 오늘 룰렛을 이미 돈 샘플 상태.
  GameState _previewState({int day = 23}) => _sampleState(day: day)
    ..rouletteDay = day
    ..lastCliffhanger = '(미리보기) 새벽 2시, 읽지 않은 메시지가 하나 남아 있다.';

  /// [s] 에서 구간 경계를 넘는 호감 (전, 후)를 찾는다. 오르면 [up]. 없으면 null.
  /// 문장 조건(when)이 안 맞아 신호가 비는 캐릭터·구간은 건너뛴다.
  ({String id, int from, int to, String text})? _findShift(
    GameState s, {
    required bool up,
    Set<String> exclude = const {},
  }) {
    final signals = bundle.signals;
    final ctx = SignalContext.of(s);
    for (final ch in _roster) {
      if (ch.hidden || exclude.contains(ch.id)) continue;
      final bands = signals.byCharacter[ch.id]?.bands;
      if (bands == null || bands.length < 2) continue;
      // 가운데 구간부터: 첫 구간(0→처음 알게 됨)은 카드가 뜨지 않는다.
      for (var k = bands.length ~/ 2; k < bands.length; k++) {
        final lower = bands[k - 1].min;
        final edge = bands[k].min;
        final below = (edge - 3).clamp(lower, edge - 1);
        final above = (edge + 2).clamp(edge, bands[k].max);
        final (from, to) = up ? (below, above) : (above, below);
        final shift = signals.shiftFor(
          ch.id,
          from,
          to,
          seed: s.seed,
          day: s.day,
          context: ctx,
        );
        if (shift != null) {
          return (id: ch.id, from: from, to: to, text: shift.text);
        }
      }
    }
    return null;
  }

  /// 정산 화면. [ups] 장의 상승과 [downs] 장의 하강 카드가 나오도록 오늘 호감 변화를 꾸민다.
  Future<void> _openSummary({required int ups, required int downs}) async {
    final s = _previewState();
    final c = _previewController(s);
    final used = <String>{};
    for (final up in [
      for (var i = 0; i < ups; i++) true,
      for (var i = 0; i < downs; i++) false,
    ]) {
      final f = _findShift(s, up: up, exclude: used);
      if (f == null) continue;
      used.add(f.id);
      s.relations[f.id]?.affection = f.to;
      c.dayDelta.affection[f.id] = f.to - f.from;
    }
    c.dayDelta.stats
      ..[Stat.charm] = 2
      ..[Stat.talk] = 1;
    c
      ..cliffhanger = '(미리보기) 내일 아침, 모르는 번호로 전화가 온다.'
      ..phase = Phase.summary;
    if (used.length < ups + downs) _warnShort(ups + downs, used.length);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PhasePreview(
          controller: c,
          phase: Phase.summary,
          builder: (c) => SummaryScreen(c: c),
        ),
      ),
    );
  }

  /// 어젯밤 마감으로 구간이 내려간 사람 한 명을 세이브에 남긴 상태.
  ({String id, String text})? _overnight(
    GameState s, {
    Set<String> exclude = const {},
  }) {
    final f = _findShift(s, up: false, exclude: exclude);
    if (f == null) return null;
    s.relations[f.id]?.affection = f.to;
    s.overnightShifts[f.id] = f.text;
    return (id: f.id, text: f.text);
  }

  /// 행동 화면: 어젯밤의 예고 아래 "밤사이 하락" 한 줄.
  Future<void> _openOvernightAction() async {
    final s = _previewState();
    if (_overnight(s) == null) _warnShort(1, 0);
    final c = _previewController(s)..phase = Phase.action;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PhasePreview(
          controller: c,
          phase: Phase.action,
          builder: (c) => ActionScreen(c: c),
        ),
      ),
    );
  }

  /// 홈: 이어하기 카드의 서사 신호 줄 + 밤사이 하락 한 줄.
  Future<void> _openHome() async {
    final s = _previewState();
    final top = _findShift(s, up: true);
    if (top != null) s.relations[top.id]?.affection = top.to;
    final night = _overnight(s, exclude: {?top?.id});
    if (top == null || night == null) {
      _warnShort(2, (top == null ? 0 : 1) + (night == null ? 0 : 1));
    }
    final c = GameController(
      bundle: bundle,
      save: _MemorySave(),
      meta: _MemoryMeta(),
    );
    // 실제 홈 첫 프레임처럼 state 는 비우고 세이브 요약만 준다.
    c
      ..hasSave = true
      ..saveSummary = SaveSummary.fromState(
        s,
        bundle.config,
        bundle.characters,
        signals: bundle.signals,
      )
      ..phase = Phase.home;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PhasePreview(
          controller: c,
          phase: Phase.home,
          builder: (c) => HomeScreen(c: c),
        ),
      ),
    );
  }

  /// 새 게임 1단계("나는?")부터 2단계(캐스트 소개)까지. 끝까지 고르면 새 게임 대신
  /// 고른 값을 알려 주고 돌아온다. 기기 메타는 건드리지 않는다.
  Future<void> _openOnboarding() async {
    final pick = await OnboardingGenderScreen.run(context, bundle);
    if (!mounted || pick == null) return;
    _toast(
      '나는: ${PlayerGender.label(pick.gender)} · '
      '고른 쪽: ${Preference.label(pick.preference)} (${pick.preference})',
    );
  }

  /// 새 게임 2단계만. [side] 가 null 이면 "선택 안 할래요" 의 비교 모드.
  Future<void> _openCast(String? side) async {
    final pref = await PreferenceScreen.show(context, bundle, side: side);
    if (!mounted || pref == null) return;
    _toast('고른 쪽: ${Preference.label(pref)} ($pref)');
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _warnShort(int want, int got) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('신호 데이터가 모자라 $want개 중 $got개만 구성했다')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final moments = momentSamples(bundle, preference: _pref);
    final byTier = <String, List<Ending>>{for (final t in _tiers) t: []};
    for (final e in bundle.endings) {
      (byTier[e.tier] ??= []).add(e);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('디버그 갤러리')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xxl),
        children: [
          // 미리보기 회차의 선호. 모먼트·정산·홈·엔딩 미리보기가 이 쪽 캐릭터를 쓴다.
          const _Header('미리보기 선호'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenX),
            child: SegmentedButton<String>(
              key: const Key('debug-preference'),
              segments: [
                for (final p in Preference.values)
                  ButtonSegment(
                    value: p,
                    label: Text(switch (p) {
                      Preference.female => '여성',
                      Preference.male => '남성',
                      _ => '전체(예전 세이브)',
                    }),
                  ),
              ],
              selected: {_pref},
              onSelectionChanged: (v) => setState(() => _pref = v.first),
            ),
          ),
          const _Header('미니게임 12종'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenX),
            child: DropdownButtonFormField<String?>(
              initialValue: _partnerId,
              decoration: const InputDecoration(labelText: '상대 (난이도 기준)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('기본값')),
                for (final ch in bundle.characters)
                  DropdownMenuItem(value: ch.id, child: Text(ch.name)),
              ],
              onChanged: (v) => setState(() => _partnerId = v),
            ),
          ),
          for (final id in minigameLabels.keys)
            ListTile(
              leading: const Icon(Icons.sports_esports),
              title: Text(minigameLabels[id]!),
              subtitle: Text(id),
              trailing: const Icon(Icons.chevron_right),
              enabled: minigameRegistry.containsKey(id),
              onTap: () => _openMinigame(id),
            ),
          // QA 실기기 확인용: 전화 · 알림 · 사진을 하루 진행 없이 바로 띄운다.
          const _Header('모먼트 미리보기'),
          for (final (label, icon, ev) in moments)
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              subtitle: Text(ev.id),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openMoment(ev),
            ),
          // QA 실기기 확인용: 관계 변화 카드와 밤사이 하락 줄을 100일 플레이 없이 띄운다.
          const _Header('정산·홈 미리보기'),
          ListTile(
            leading: const Icon(Icons.trending_up),
            title: const Text('정산: 상승 카드 2장'),
            subtitle: const Text('서로 다른 두 사람이 오늘 구간을 올라갔다'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSummary(ups: 2, downs: 0),
          ),
          ListTile(
            leading: const Icon(Icons.swap_vert),
            title: const Text('정산: 상승 1장 + 하강 1장'),
            subtitle: const Text('한 사람은 가까워지고 한 사람은 멀어졌다'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSummary(ups: 1, downs: 1),
          ),
          ListTile(
            leading: const Icon(Icons.nightlight_outlined),
            title: const Text('행동: 밤사이 하락 한 줄'),
            subtitle: const Text('어젯밤 마감으로 구간이 내려간 사람'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openOvernightAction,
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('홈: 서사 신호 줄 + 밤사이 줄'),
            subtitle: const Text('이어하기 카드와 하락 한 줄'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openHome,
          ),
          const _Header('새 게임 온보딩'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('1단계: 나는?'),
            subtitle: const Text('남자 · 여자 · 선택 안 할래요 → 캐스트 소개'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openOnboarding,
          ),
          for (final (side, label) in [
            (Preference.female, '2단계: 캐스트 소개 · 여성 캐릭터'),
            (Preference.male, '2단계: 캐스트 소개 · 남성 캐릭터'),
            (null, '2단계: 캐스트 소개 · 비교(선택 안 함)'),
          ])
            ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: Text(label),
              subtitle: Text(
                side == null ? '두 쪽 요약 → 세그먼트로 비교' : '반대쪽 링크 · 시작하기',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openCast(side),
            ),
          const _Header('엔딩 화면'),
          for (final t in byTier.keys)
            ExpansionTile(
              title: Text('${_tierLabels[t] ?? t} 엔딩 (${byTier[t]!.length})'),
              initiallyExpanded: false,
              children: [
                for (final e in byTier[t]!)
                  ListTile(
                    leading: const Icon(Icons.flag),
                    title: Text(e.name),
                    subtitle: Text(
                      '${e.id}${e.character == null ? '' : ' · ${bundle.characterById[e.character!]?.name ?? e.character}'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openEnding(e),
                  ),
              ],
            ),
          // 서사 신호: 캐릭터별 구간 문장과 정산 "관계 변화" 카드 모양을 한눈에 본다.
          _Header('서사 신호 (${bundle.signals.byCharacter.length}명)'),
          for (final ch in bundle.characters)
            if (bundle.signals.byCharacter[ch.id] case final sig?)
              ExpansionTile(
                title: Text('${ch.name} 신호'),
                children: [
                  for (final band in sig.bands)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.screenX,
                        vertical: AppSpace.xs,
                      ),
                      child: RelationShiftCard(
                        name: '${ch.name} ♥${band.min}~${band.max}',
                        text: band.lines.join('\n'),
                        up: true,
                        accent: context.tokens.accentFor(ch.id),
                      ),
                    ),
                  if (sig.down.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.screenX,
                        AppSpace.xs,
                        AppSpace.screenX,
                        AppSpace.md,
                      ),
                      child: RelationShiftCard(
                        name: ch.name,
                        text: sig.down.join('\n'),
                        up: false,
                        accent: context.tokens.accentFor(ch.id),
                      ),
                    ),
                ],
              ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.screenX,
      AppSpace.lg,
      AppSpace.screenX,
      AppSpace.xs,
    ),
    child: Text(text, style: context.text.titleMedium),
  );
}

/// 엔딩 화면을 실제 위젯으로 띄운다. 화면 안의 'N회차 시작' / '홈으로' 를 누르면
/// 컨트롤러 phase 가 바뀌므로 그때 갤러리로 돌아온다.
class _EndingPreview extends StatelessWidget {
  final GameController controller;
  const _EndingPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.phase != Phase.ending) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        return EndingScreen(c: controller);
      },
    );
  }
}

/// 디버그 갤러리의 모먼트 합성 이벤트 세 개(전화 · 알림 · 사진). 상대는 [preference]
/// 회차에 등장하는 첫 캐릭터(없으면 전체의 첫 캐릭터).
/// 데이터 규격은 docs/MOMENTS_SPEC.md 그대로다(검증기를 통과하는 모양).
List<(String, IconData, StoryEvent)> momentSamples(
  StoryBundle bundle, {
  String preference = Preference.all,
}) {
  final roster = bundle.charactersFor(preference);
  final who = roster.isNotEmpty
      ? roster.first.id
      : bundle.characters.isEmpty
      ? null
      : bundle.characters.first.id;
  final call = StoryEvent.fromJson({
    'id': 'mo_debug_call',
    'layer': 'route',
    'character': who,
    'format': 'call',
    'title': '밤 11시의 전화',
    'lines': [
      {'who': 'them', 'text': '어… 자고 있었어?'},
      {'who': 'me', 'text': '아니, 깨어 있었어.'},
      {'who': 'narr', 'text': '수화기 너머로 바람 소리가 들린다.'},
      {'who': 'sys', 'wait': 5},
      {'who': 'them', 'text': '그냥… 목소리 듣고 싶어서.'},
    ],
    'choices': [
      {
        'text': '나도 마침 생각하고 있었어',
        'effects': {
          'affection': {'*': 3},
        },
        'reply': [
          '진짜? 다행이다',
          {'who': 'narr', 'text': '웃음소리가 조금 길어졌다.'},
        ],
      },
      {
        'text': '무슨 일 있어?',
        'minigame': 'call_rhythm',
        'effects': {
          'trust': {'*': 2},
        },
        'reply': '아니야, 그냥. 고마워',
        'failReply': '…아냐, 됐어. 잘 자',
      },
      {
        'text': '거절',
        'decline': true,
        'effects': {
          'affection': {'*': -1},
        },
        'reply': [
          '바빠? 나중에 연락해',
          {'who': 'narr', 'text': '부재중 표시가 오래 남았다.'},
        ],
      },
    ],
  });
  final preview = StoryEvent.fromJson({
    'id': 'mo_debug_preview',
    'layer': 'route',
    'character': who,
    'title': '먼저 온 톡',
    'preview': '오늘 퇴근길에 네 생각 났어',
    'lines': [
      {'who': 'them', 'text': '오늘 퇴근길에 네 생각 났어'},
      {'who': 'them', 'text': '편의점 앞에서 네가 좋아하는 거 봤거든'},
    ],
    'choices': [
      {
        'text': '뭔데? 궁금해',
        'effects': {
          'affection': {'*': 2},
        },
        'reply': '비밀. 다음에 사 줄게',
      },
      {'text': 'ㅋㅋ 그랬구나', 'reply': '응 ㅋㅋ'},
    ],
  });
  final photo = StoryEvent.fromJson({
    'id': 'mo_debug_photo',
    'layer': 'daily',
    'character': who,
    'title': '사진 한 장',
    'lines': [
      {
        'who': 'them',
        'photo': {'icon': 'cafe', 'caption': '창가 자리 잡았어'},
        'text': '여기 올래?',
      },
      {
        'who': 'them',
        'photo': {'icon': 'unknown_icon', 'caption': '모르는 아이콘은 기본 사진'},
      },
      {
        'who': 'me',
        'photo': {'icon': 'selfie', 'caption': '출발 인증'},
        'text': '지금 간다',
      },
    ],
    'choices': [
      {
        'text': '자리 맡아 줘서 고마워',
        'reply': [
          {
            'who': 'them',
            'photo': {'icon': 'food', 'caption': '케이크도 시켜 둠'},
          },
          '빨리 와',
        ],
      },
    ],
  });
  return [
    ('전화 (수신 → 받기/거절)', Icons.call, call),
    ('먼저 온 톡 알림', Icons.notifications_active_outlined, preview),
    ('사진 메시지', Icons.photo_outlined, photo),
  ];
}

/// 모먼트 이벤트를 실제 EventScreen 으로 띄운다. '계속' 으로 이벤트가 끝나면
/// (컨트롤러가 정산으로 넘어가면) 갤러리로 돌아온다.
class _MomentPreview extends StatelessWidget {
  final GameController controller;
  const _MomentPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.phase != Phase.event || controller.current == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        return EventScreen(c: controller);
      },
    );
  }
}

/// 컨트롤러가 [phase] 에 있는 동안 [builder] 화면을 띄운다. 화면 안의 버튼(다음 날로,
/// 홈으로, 이어하기 등)으로 phase 가 바뀌면 갤러리로 돌아온다.
class _PhasePreview extends StatelessWidget {
  final GameController controller;
  final Phase phase;
  final Widget Function(GameController c) builder;
  const _PhasePreview({
    required this.controller,
    required this.phase,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.phase != phase) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        return builder(controller);
      },
    );
  }
}

/// 기기의 출석·연속 기록을 건드리지 않는 메타. 홈 미리보기의 출석 처리가 여기로 간다.
class _MemoryMeta extends MetaService {
  PlayerMeta? _meta;

  @override
  Future<PlayerMeta> load() async => _meta ??= PlayerMeta();

  @override
  Future<void> save(PlayerMeta m) async => _meta = m;

  @override
  Future<void> clear() async => _meta = null;
}

/// 기기 SharedPreferences 를 건드리지 않는 세이브. 갤러리 안에서만 쓴다.
class _MemorySave extends SaveService {
  GameState? _state;
  final List<String> _endings = [];

  @override
  Future<void> save(GameState s) async => _state = s;

  @override
  Future<GameState?> load() async => _state;

  @override
  Future<bool> exists() async => _state != null;

  @override
  Future<void> clear() async => _state = null;

  @override
  Future<List<String>> loadEndings() async => List.of(_endings);

  @override
  Future<void> addEnding(String id) async {
    if (!_endings.contains(id)) _endings.add(id);
  }
}
