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
/// - 항상 [BoxFit.cover]. 틀(3:2·4:3, 세로 그림이면 [SceneFrame])은 부르는 쪽이 잡는다.
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

  /// 그림 공급자. [SceneFrame] 이 같은 키로 크기를 먼저 읽으므로 디코딩은 한 번이다.
  ///
  /// `ExactAssetImage` 는 해상도 변형(2.0x 폴더)을 찾느라 매니페스트를 다시 읽지 않는다
  /// (장면 그림은 한 벌뿐이다). `cacheWidth` 는 레이아웃 폭 × 기기 배율 — 1200px 원본을
  /// 화면 폭에 맞게 줄여 읽는다(세로는 비율대로 따라온다).
  static ImageProvider providerFor(
    String path, {
    AssetBundle? bundle,
    required int cacheWidth,
  }) => ResizeImage.resizeIfNeeded(
    cacheWidth > 0 ? cacheWidth : null,
    null,
    ExactAssetImage(path, bundle: bundle),
  );

  @override
  Widget build(BuildContext context) {
    final empty = fallback ?? (_) => const SizedBox.shrink();
    final px = (width * MediaQuery.devicePixelRatioOf(context)).ceil();
    Widget image = Image(
      image: providerFor(path, bundle: bundle, cacheWidth: px),
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

/// 채팅 맨 위 장면 카드. 풀폭 3:2(세로 그림은 [SceneFrame] 이 3:4 까지 세운다),
/// [AppRadius.rLg], 탭하면 크게 보기.
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
              child: SceneFrame(
                path: p,
                width: w,
                bundle: bundle,
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
                      // 크게 보기는 그림 전체를 보여 준다(세로 2:3 도 자르지 않는다).
                      child: SceneFrame(
                        path: path,
                        width: w,
                        bundle: bundle,
                        minAspect: SceneFrame.viewerMin,
                        child: SceneImage(path: path, width: w, bundle: bundle),
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

/// 엔딩 히어로 한 장. 이름 위. 틀은 [SceneFrame](가로 3:2, 세로 그림은 최대 3:4). 티어에 따라 색만 코드가 바꾼다(06 §1):
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
      child: SceneFrame(
        path: p,
        width: w,
        bundle: widget.bundle,
        child: SceneImage(
          path: p,
          width: w,
          bundle: widget.bundle,
          // 세로 엔딩 그림은 얼굴이 위쪽 1/3 에 있다. 잘리면 아래(발치)가 잘리게 둔다.
          alignment: Alignment.topCenter,
          onFailed: () {
            if (mounted) setState(() => _failed = true);
          },
        ),
      ),
    );
    final matrix = EndingHero.matrixFor(widget.tier);
    if (matrix != null) {
      hero = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: hero,
      );
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

/// 그림 비율을 따르는 틀. 장면 카드·크게 보기·엔딩 히어로가 같이 쓴다.
///
/// 장면 그림은 대부분 가로 3:2 지만 위기 장면과 엔딩 그림은 세로 2:3 이다. 3:2 틀에
/// [BoxFit.cover] 로 넣으면 세로 그림은 가운데 얇은 띠만 남는다(얼굴이 잘린다). 그래서:
///  - 가로·정사각 그림(가로 ≥ 세로)은 지금까지처럼 [AppSize.sceneAspect](3:2) — 화면이 1px 도
///    달라지지 않는다.
///  - 세로 그림은 실제 비율을 따르되 [portraitMin](3:4) 아래로는 세우지 않는다. 2:3 그림이면
///    위아래가 조금(11%)만 잘리고 거의 다 보인다.
///
/// 비율은 [SceneImage] 와 **같은 공급자**를 한 번 풀어 읽는다(디코딩은 한 번). 모르는 동안은
/// 3:2 로 두고, 알게 되면 [AppMotion.base] 동안 부드럽게 늘인다(동작 줄이기면 즉시).
/// 한 번 읽은 비율은 경로별로 기억해 두어서 두 번째부터는 처음부터 제 비율로 그린다.
class SceneFrame extends StatefulWidget {
  final String path;

  /// 레이아웃 폭(pt). [SceneImage.width] 와 같아야 공급자 키가 맞는다.
  final double width;
  final AssetBundle? bundle;

  /// 세로 그림을 세우는 한계. 기본 [portraitMin].
  final double minAspect;
  final Widget child;

  const SceneFrame({
    super.key,
    required this.path,
    required this.width,
    required this.child,
    this.bundle,
    this.minAspect = portraitMin,
  });

  /// 가로 그림 틀(3:2).
  static const double landscape = AppSize.sceneAspect;

  /// 세로 그림을 세우는 한계(3:4). 2:3 그림이 거의 다 보이고, 화면을 다 덮지는 않는다.
  static const double portraitMin = 3 / 4;

  /// 크게 보기의 한계(1:2). 2:3 그림을 자르지 않는다.
  static const double viewerMin = 1 / 2;

  /// 그림 [w]×[h] 에 맞는 틀 비율(가로/세로).
  static double aspectFor(num w, num h, {double min = portraitMin}) {
    if (w <= 0 || h <= 0) return landscape;
    final a = w / h;
    return a >= 1 ? landscape : a.clamp(min, landscape).toDouble();
  }

  /// 경로 → 그림 실제 비율(가로/세로). 한 번 읽은 것만 있다.
  static final Map<String, double> _known = {};

  /// 테스트용: 기억한 비율을 지운다.
  @visibleForTesting
  static void debugForget() => _known.clear();

  @override
  State<SceneFrame> createState() => _SceneFrameState();
}

class _SceneFrameState extends State<SceneFrame> {
  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// 이 틀이 처음 그려질 때 이미 비율을 알았는지. 알았으면 늘이는 동작이 없다.
  late bool _knewAtStart = SceneFrame._known.containsKey(widget.path);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(SceneFrame old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path ||
        old.bundle != widget.bundle ||
        old.width != widget.width) {
      _knewAtStart = SceneFrame._known.containsKey(widget.path);
      _resolve();
    }
  }

  void _resolve() {
    if (SceneFrame._known.containsKey(widget.path)) {
      _stop();
      return;
    }
    final px = (widget.width * MediaQuery.devicePixelRatioOf(context)).ceil();
    final provider = SceneImage.providerFor(
      widget.path,
      bundle: widget.bundle,
      cacheWidth: px,
    );
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stop();
    final path = widget.path;
    final listener = ImageStreamListener(
      (info, _) {
        final img = info.image;
        SceneFrame._known[path] = img.width / img.height;
        info.dispose();
        if (mounted && path == widget.path) setState(_stop);
      },
      // 못 읽으면 3:2 그대로. 깨진 파일은 SceneImage 가 카드를 접는다.
      onError: (_, _) {},
    );
    _stream = stream..addListener(listener);
    _listener = listener;
  }

  void _stop() {
    final l = _listener;
    if (l != null) _stream?.removeListener(l);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final real = SceneFrame._known[widget.path];
    final target = real == null
        ? SceneFrame.landscape
        : SceneFrame.aspectFor(real, 1, min: widget.minAspect);
    final d = _knewAtStart ? Duration.zero : AppMotion.base(context);
    if (d == Duration.zero) {
      return AspectRatio(aspectRatio: target, child: widget.child);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: target),
      duration: d,
      curve: AppMotion.standard,
      builder: (context, aspect, child) =>
          AspectRatio(aspectRatio: aspect, child: child),
      child: widget.child,
    );
  }
}
