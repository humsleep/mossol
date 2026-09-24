/// 장면 삽화(docs/overhaul/06_scene_plan.md §1, DESIGN_SYSTEM §2.3.2).
///
/// 그림이 **없으면 아무것도 그리지 않는다** — 자리도 잡지 않아서 지금 화면과 1px 도
/// 다르지 않다. 있으면 채팅 맨 위(구분줄 위)에 3:2 카드 한 장, 통화 2단계의 배경,
/// 엔딩 이름 위 히어로로 같은 그림이 쓰인다.
///
/// 목록은 [SceneRegistry] 가 시작할 때 한 번 읽는다. 늦게 도착할 수 있으므로
/// 화면은 [SceneRegistry.listenable] 을 구독한다(초상화와 같다).
library;

import 'package:flutter/material.dart';

import 'design_system.dart';
import 'scene_registry.dart';
import 'widgets.dart' show showAppDialog;

/// 그림 한 장. 읽는 중·실패·없음이면 [fallback](기본은 빈 칸)을 그린다.
///
/// - 항상 [BoxFit.cover]. 3:2·4:3 틀은 부르는 쪽이 잡는다.
/// - `cacheWidth` 는 레이아웃 폭 × 기기 배율 — 1200px 원본을 화면 폭에 맞게 줄여 읽는다.
/// - 깨진 파일이 들어와도 `errorBuilder` 가 [fallback] 으로 떨어져 깨진 상자가 안 뜬다.
/// - [kenBurns] 면 [AppMotion.scene] 동안 아주 천천히 확대한다(동작 줄이기면 정지).
class SceneImage extends StatelessWidget {
  final String path;

  /// 레이아웃 폭(pt). 디코딩 크기를 정한다.
  final double width;

  final String? semanticLabel;
  final AssetBundle? bundle;
  final WidgetBuilder? fallback;
  final bool kenBurns;
  final Alignment alignment;

  /// 파일이 깨져 못 읽었을 때. 부르는 쪽이 카드 자체를 접어 "그림 없음" 으로 돌아간다.
  final VoidCallback? onFailed;

  /// 켄번즈 끝 배율. 8초에 6% — "움직이는 줄 모르게" 가 기준이다.
  static const double kenBurnsZoom = 1.06;

  const SceneImage({
    super.key,
    required this.path,
    required this.width,
    this.semanticLabel,
    this.bundle,
    this.fallback,
    this.kenBurns = false,
    this.alignment = Alignment.center,
    this.onFailed,
  });

  @override
  Widget build(BuildContext context) {
    final empty = fallback ?? (_) => const SizedBox.shrink();
    final px = (width * MediaQuery.devicePixelRatioOf(context)).ceil();
    Widget image = Image.asset(
      path,
      bundle: bundle,
      // scale 을 주면 ExactAssetImage 가 된다. 해상도 변형(2.0x 폴더)을 찾느라
      // 매니페스트를 다시 읽지 않는다. 장면 그림은 한 벌뿐이다.
      scale: 1,
      cacheWidth: px > 0 ? px : null,
      fit: BoxFit.cover,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) =>
          frame == null && !sync ? empty(context) : child,
      errorBuilder: (context, error, stack) {
        final failed = onFailed;
        if (failed != null) {
          // 그리는 중에는 상태를 못 바꾼다. 다음 프레임에 카드를 접는다.
          WidgetsBinding.instance.addPostFrameCallback((_) => failed());
        }
        return empty(context);
      },
    );
    if (kenBurns) {
      final d = AppMotion.scene(context);
      if (d > Duration.zero) {
        image = TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: kenBurnsZoom),
          duration: d,
          curve: Curves.linear,
          builder: (context, v, child) =>
              Transform.scale(scale: v, child: child),
          child: image,
        );
      }
    }
    return ClipRect(child: image);
  }
}

/// 채팅 맨 위 장면 카드. 풀폭 3:2, [AppRadius.rLg], 탭하면 크게 보기.
///
/// [path] 가 null 이면 [SizedBox.shrink] — 위아래 여백도 없다.
class SceneCard extends StatefulWidget {
  /// 에셋 경로. null 이면 아무것도 그리지 않는다.
  final String? path;

  /// 스크린리더 라벨에 쓰는 이벤트 제목.
  final String title;

  final AssetBundle? bundle;

  const SceneCard({
    super.key,
    required this.path,
    this.title = '',
    this.bundle,
  });

  /// 좌우 여백. 말풍선과 같은 `md` 선에 맞춘다.
  static const double inset = AppSpace.md;

  @override
  State<SceneCard> createState() => _SceneCardState();
}

class _SceneCardState extends State<SceneCard> {
  /// 파일이 깨졌으면 카드를 접는다(그림 없는 화면과 같아진다).
  bool _failed = false;

  @override
  void didUpdateWidget(SceneCard old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.path;
    if (p == null || _failed) return const SizedBox.shrink();
    final title = widget.title;
    final bundle = widget.bundle;
    const inset = SceneCard.inset;
    final w = MediaQuery.sizeOf(context).width - inset * 2;
    if (w <= 0) return const SizedBox.shrink();
    final label = title.isEmpty ? '장면' : '$title 장면';

    void open() => showAppSceneViewer(context, p, label: label, bundle: bundle);

    return Padding(
      padding: const EdgeInsets.fromLTRB(inset, AppSpace.sm, inset, 0),
      child: Semantics(
        image: true,
        button: true,
        label: label,
        hint: '크게 보기',
        onTap: open,
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: open,
            behavior: HitTestBehavior.opaque,
            child: ClipRRect(
              borderRadius: AppRadius.rLg,
              child: AspectRatio(
                aspectRatio: AppSize.sceneAspect,
                child: SceneImage(
                  path: p,
                  width: w,
                  bundle: bundle,
                  kenBurns: true,
                  onFailed: () {
                    if (mounted) setState(() => _failed = true);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 장면 크게 보기. 사진 뷰어와 같은 투명 바탕 + 닫기 버튼.
Future<void> showAppSceneViewer(
  BuildContext context,
  String path, {
  required String label,
  AssetBundle? bundle,
}) {
  return showAppDialog<void>(
    context,
    builder: (_) => _SceneViewer(path: path, label: label, bundle: bundle),
  );
}

class _SceneViewer extends StatelessWidget {
  final String path;
  final String label;
  final AssetBundle? bundle;

  const _SceneViewer({required this.path, required this.label, this.bundle});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width - AppSpace.xl * 2;
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  image: true,
                  label: label,
                  child: ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: AppRadius.rLg,
                      child: AspectRatio(
                        aspectRatio: AppSize.sceneAspect,
                        child: SceneImage(
                          path: path,
                          width: w,
                          bundle: bundle,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('닫기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 엔딩 히어로 한 장. 3:2, 이름 위. 티어에 따라 색만 코드가 바꾼다(06 §1):
/// bad = 채도를 낮춰 어둡게, hidden = 세피아, 그 밖은 그대로.
class EndingHero extends StatefulWidget {
  final String? path;
  final String tier;
  final String name;
  final AssetBundle? bundle;

  const EndingHero({
    super.key,
    required this.path,
    required this.tier,
    this.name = '',
    this.bundle,
  });

  /// 채도 낮춤(bad). 밝기도 함께 내린다.
  static const List<double> _fadedMatrix = <double>[
    0.30, 0.42, 0.12, 0, -12, //
    0.24, 0.48, 0.12, 0, -12,
    0.24, 0.42, 0.18, 0, -12,
    0, 0, 0, 1, 0,
  ];

  /// 세피아(hidden).
  static const List<double> _sepiaMatrix = <double>[
    0.39, 0.77, 0.19, 0, 0, //
    0.35, 0.69, 0.17, 0, 0,
    0.27, 0.53, 0.13, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static List<double>? matrixFor(String tier) => switch (tier) {
    'bad' => _fadedMatrix,
    'hidden' => _sepiaMatrix,
    _ => null,
  };

  @override
  State<EndingHero> createState() => _EndingHeroState();
}

class _EndingHeroState extends State<EndingHero> {
  bool _failed = false;

  @override
  void didUpdateWidget(EndingHero old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.path;
    if (p == null || _failed) return const SizedBox.shrink();
    final name = widget.name;
    final w = MediaQuery.sizeOf(context).width - AppSpace.screenX * 2;
    if (w <= 0) return const SizedBox.shrink();
    Widget hero = ClipRRect(
      borderRadius: AppRadius.rLg,
      child: AspectRatio(
        aspectRatio: AppSize.sceneAspect,
        child: SceneImage(
          path: p,
          width: w,
          bundle: widget.bundle,
          onFailed: () {
            if (mounted) setState(() => _failed = true);
          },
        ),
      ),
    );
    final matrix = EndingHero.matrixFor(widget.tier);
    if (matrix != null) {
      hero = ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: hero);
    }
    return Semantics(
      image: true,
      label: name.isEmpty ? '엔딩 그림' : '$name 엔딩 그림',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          child: hero,
        ),
      ),
    );
  }
}
