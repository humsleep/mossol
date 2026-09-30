import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_meta.dart';
import '../engine/models.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'intro_screen.dart' show IntroScreen;
import 'portraits.dart';

/// 앱을 새로 켤 때마다(콜드 스타트) 가장 먼저 보이는 타이틀 화면.
///
/// 첫 실행이면 이 화면 다음에 태현의 문자([IntroScreen] — 타이틀 단계는 건너뛴다)로,
/// 이어하는 사람이면 홈으로 간다. 앱이 살아 있는 동안에는 다시 뜨지 않는다.
///
/// 게임의 "대표 이미지" 자리다. 위쪽에 여성·남성 캐릭터 라인업이 서로 반대 방향으로
/// 천천히 흐르고, 아래에 앱 이름·한 줄 소개·시작 안내가 차례로 떠오른다.
/// 화면 어디를 눌러도 [onStart] 가 불린다. 테마(라이트·다크)와 상관없이 늘 같은
/// 밤 장면이고, 색은 [IntroPalette] 에서 온다. 스토어 홍보 이미지 00a 와 같은 톤이라
/// 스토어 → 첫 화면이 한 장면처럼 이어진다.
class LaunchTitleScreen extends StatefulWidget {
  final List<CharacterDef> cast;
  final VoidCallback onStart;

  const LaunchTitleScreen({super.key, required this.cast, required this.onStart});

  /// 제목·소개 문구. 테스트와 접근성 라벨이 같은 문자열을 쓴다.
  static const title = '모쏠 탈출기';
  static const badge = '100일 연애 시뮬레이션';
  static const tagline = '톡 한 줄로 썸부터 고백까지';
  static const pitch = '100일 뒤, 이 중 누군가와\n연인이 될 수 있을까?';
  static const startLabel = '화면을 터치해서 시작';

  @override
  State<LaunchTitleScreen> createState() => _LaunchTitleScreenState();
}

class _LaunchTitleScreenState extends State<LaunchTitleScreen>
    with TickerProviderStateMixin {
  /// 등장 연출(라인업 → 배지 → 제목 → 소개 → 시작 안내). 한 번만 돈다.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  /// 라인업이 한 바퀴 흐르는 시간. 느릴수록 고급스럽다.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 48),
  );

  /// "터치해서 시작" 의 숨쉬기.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _enter.value = 1;
      _drift.stop();
      _pulse.stop();
    } else if (!_enter.isAnimating && _enter.value == 0) {
      _enter.forward();
      _drift.repeat();
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _drift.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    widget.onStart();
  }

  /// [from]~[to] 구간(0~1)에서 0→1 로 오르는 등장 곡선.
  Animation<double> _stage(double from, double to) => CurvedAnimation(
    parent: _enter,
    curve: Interval(from, to, curve: AppMotion.standard),
  );

  @override
  Widget build(BuildContext context) {
    final women = [
      for (final c in widget.cast)
        if (c.gender == 'f') c,
    ];
    final men = [
      for (final c in widget.cast)
        if (c.gender == 'm') c,
    ];
    final width = MediaQuery.sizeOf(context).width;

    return Semantics(
      button: true,
      label: '${LaunchTitleScreen.title}. ${LaunchTitleScreen.startLabel}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _start,
        child: Scaffold(
          backgroundColor: IntroPalette.base,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.35),
                radius: 1.1,
                colors: [
                  IntroPalette.glow,
                  IntroPalette.base,
                  IntroPalette.deep,
                ],
                stops: [0, 0.55, 1],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // 제목 블록이 차지하고 남은 높이를 라인업이 쓴다. 작은 기기(SE)·큰 글꼴에서도
                  // 제목이 잘리지 않게 카드 크기를 남은 높이에 맞추고, 너무 좁으면 라인업을 뺀다.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final cardH =
                            ((box.maxHeight - AppSpace.huge * 2 - AppSpace.sm) /
                                    2)
                                .clamp(0.0, 168.0);
                        if (cardH < 56) return const SizedBox.shrink();
                        return Align(
                          alignment: const Alignment(0, 0.4),
                          child: _lineup(cardH, width, women, men),
                        );
                      },
                    ),
                  ),
                  _titleBlock(context),
                  const SizedBox(height: AppSpace.xxl),
                  _fadeUp(
                    _stage(0.75, 1),
                    FadeTransition(
                      opacity: Tween(begin: 0.45, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _pulse,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: Text(
                        LaunchTitleScreen.startLabel,
                        style: context.text.titleSmall?.copyWith(
                          color: IntroPalette.body,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    'v${AppMeta.version}',
                    style: context.text.labelSmall?.copyWith(
                      color: IntroPalette.soft,
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineup(
    double cardH,
    double width,
    List<CharacterDef> women,
    List<CharacterDef> men,
  ) {
    return _fadeUp(
      _stage(0, 0.45),
      // 포스터처럼 살짝 기울이고, 기울어 생긴 모서리 빈틈은 넓혀서 덮는다.
      // 아래쪽은 배경으로 녹여 제목 블록과 한 장면이 되게 한다.
      ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            IntroPalette.title,
            IntroPalette.title,
            IntroPalette.scrimClear,
          ],
          stops: [0, 0.8, 1],
        ).createShader(rect),
        child: SizedBox(
          height: cardH * 2 + AppSpace.huge * 2,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: width * 1.4,
              child: Transform.rotate(
                angle: -0.06,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LineupRow(
                      cast: women,
                      cardHeight: cardH,
                      drift: _drift,
                      reverse: false,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    _LineupRow(
                      cast: men,
                      cardHeight: cardH,
                      drift: _drift,
                      reverse: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      dy: -12,
    );
  }

  Widget _titleBlock(BuildContext context) {
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenX),
      child: Column(
        children: [
          _fadeUp(
            _stage(0.3, 0.6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.xs,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.rPill,
                border: Border.all(color: IntroPalette.pillBorder),
              ),
              child: Text(
                LaunchTitleScreen.badge,
                style: text.labelLarge?.copyWith(color: IntroPalette.body),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          _fadeUp(
            _stage(0.4, 0.75),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                LaunchTitleScreen.title,
                style: text.displayMedium?.copyWith(
                  color: IntroPalette.title,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.5,
                  shadows: const [
                    Shadow(color: IntroPalette.glow, blurRadius: 24),
                  ],
                ),
              ),
            ),
            dy: 16,
          ),
          const SizedBox(height: AppSpace.sm),
          _fadeUp(
            _stage(0.5, 0.85),
            Text(
              LaunchTitleScreen.tagline,
              style: text.titleMedium?.copyWith(
                color: IntroPalette.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          _fadeUp(
            _stage(0.6, 0.95),
            Text(
              keepAll(LaunchTitleScreen.pitch),
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(
                color: IntroPalette.body,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fadeUp(Animation<double> a, Widget child, {double dy = 10}) =>
      AnimatedBuilder(
        animation: a,
        child: child,
        builder: (context, child) => Opacity(
          opacity: a.value,
          child: Transform.translate(
            offset: Offset(0, dy * (1 - a.value)),
            child: child,
          ),
        ),
      );
}

/// 한 줄 라인업. 카드들을 두 벌 이어 붙이고 한 벌 길이만큼 흘려 끊김 없이 돈다.
class _LineupRow extends StatelessWidget {
  final List<CharacterDef> cast;
  final double cardHeight;
  final Animation<double> drift;
  final bool reverse;

  const _LineupRow({
    required this.cast,
    required this.cardHeight,
    required this.drift,
    required this.reverse,
  });

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();
    final cardW = cardHeight * 0.78;
    const gap = AppSpace.md;
    final loop = cast.length * (cardW + gap);
    final cards = [
      for (var i = 0; i < 2; i++)
        for (final c in cast) ...[
          _LineupCard(c: c, width: cardW, height: cardHeight),
          const SizedBox(width: gap),
        ],
    ];
    return SizedBox(
      height: cardHeight + AppSpace.md,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: drift,
          builder: (context, child) {
            final t = reverse ? 1 - drift.value : drift.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(left: -t * loop, top: AppSpace.xs, child: child!),
              ],
            );
          },
          child: Row(mainAxisSize: MainAxisSize.min, children: cards),
        ),
      ),
    );
  }
}

/// 라인업 카드 한 장: 초상화 + 이름 띠. 히든 캐릭터에는 '히든' 배지가 붙는다.
class _LineupCard extends StatelessWidget {
  final CharacterDef c;
  final double width;
  final double height;

  const _LineupCard({
    required this.c,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final registry = PortraitRegistry.current;
    final path = registry.pathFor(c.id);
    final labelH = math.max(26.0, height * 0.2);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: IntroPalette.card,
        borderRadius: AppRadius.rLg,
        boxShadow: const [
          BoxShadow(
            color: IntroPalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (path != null)
                  Image.asset(
                    path,
                    bundle: registry.bundle,
                    scale: 1,
                    cacheWidth: (width * dpr * 1.2).ceil(),
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.4),
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => _initial(context),
                  )
                else
                  _initial(context),
                if (c.hidden)
                  Positioned(
                    top: AppSpace.xs,
                    right: AppSpace.xs,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: IntroPalette.hiddenBadge,
                        borderRadius: AppRadius.rPill,
                      ),
                      child: Text(
                        '히든',
                        style: context.text.labelSmall?.copyWith(
                          color: IntroPalette.hiddenBadgeText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: labelH,
            child: Center(
              child: Text(
                c.name,
                style: context.text.labelLarge?.copyWith(
                  color: IntroPalette.cardText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initial(BuildContext context) {
    final accent = context.tokens.accentFor(c.id);
    return ColoredBox(
      color: accent.container,
      child: Center(
        child: Text(
          c.name.characters.first,
          style: context.text.headlineMedium?.copyWith(
            color: accent.onContainer,
          ),
        ),
      ),
    );
  }
}
