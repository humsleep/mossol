import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../engine/save_service.dart';
import '../engine/story_repository.dart';
import '../game_controller.dart';
import '../minigames/minigame.dart';
import '../minigames/registry.dart';
import '../ui/design_system.dart';
import '../ui/ending_screen.dart';
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

  StoryBundle get bundle => widget.bundle;

  /// 미니게임·엔딩에 넘길 샘플 상태. 눈치 30 정도의 중반 플레이어.
  GameState _sampleState({int day = 40}) {
    final s = GameState.fresh(bundle.config, bundle.characters, seed: 7)
      ..day = day;
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
    final who = e.character ?? bundle.characters.first.id;
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

  @override
  Widget build(BuildContext context) {
    final byTier = <String, List<Ending>>{
      for (final t in _tiers) t: [],
    };
    for (final e in bundle.endings) {
      (byTier[e.tier] ??= []).add(e);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('디버그 갤러리')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xxl),
        children: [
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
