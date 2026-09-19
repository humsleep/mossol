/// 캐릭터 초상화(프로필 이미지). 규칙 기반이라 JSON 에 경로를 적지 않는다.
///
/// `assets/portraits/<캐릭터 id>.png` 가 번들에 있으면 그 그림을 쓰고, 없으면 지금처럼
/// 강조색 이니셜 원으로 그린다. 파일만 넣고 다시 빌드하면 끝이다(docs/PORTRAIT_PROMPTS.md).
///
/// 어떤 파일이 있는지는 시작할 때 `AssetManifest` 를 한 번 읽어 [PortraitRegistry] 에
/// 캐시한다. 위젯은 [PortraitRegistry.listenable] 을 구독하므로, 목록이 늦게 도착해도
/// 이니셜 → 그림으로 바뀐다.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 초상화 파일 목록. 캐릭터 id → 에셋 경로.
@immutable
class PortraitRegistry {
  /// 초상화 폴더. pubspec.yaml 의 `assets/portraits/` 와 같다.
  static const dir = 'assets/portraits/';

  /// 같은 id 로 여러 형식이 있으면 앞쪽을 쓴다.
  static const extensions = ['png', 'jpg', 'jpeg', 'webp'];

  final Map<String, String> _paths;

  /// 그림을 읽을 번들. null 이면 `rootBundle`. 테스트가 가짜 번들을 넣는다.
  final AssetBundle? bundle;

  const PortraitRegistry._(this._paths, this.bundle);

  /// 초상화가 하나도 없는 상태(기본값).
  static const empty = PortraitRegistry._({}, null);

  /// 에셋 경로 목록에서 `assets/portraits/<id>.<확장자>` 만 골라 만든다.
  /// 하위 폴더, 목록에 없는 형식, `.gitkeep` 같은 숨김 파일은 무시한다.
  factory PortraitRegistry.fromAssets(
    Iterable<String> assets, {
    AssetBundle? bundle,
  }) {
    final found = <String, String>{};
    final rank = <String, int>{};
    for (final path in assets) {
      if (!path.startsWith(dir)) continue;
      final file = path.substring(dir.length);
      if (file.contains('/') || file.startsWith('.')) continue;
      final dot = file.lastIndexOf('.');
      if (dot <= 0) continue;
      final id = file.substring(0, dot);
      final r = extensions.indexOf(file.substring(dot + 1).toLowerCase());
      if (r < 0) continue;
      if (rank[id] == null || r < rank[id]!) {
        rank[id] = r;
        found[id] = path;
      }
    }
    return PortraitRegistry._(Map.unmodifiable(found), bundle);
  }

  /// 초상화 경로. 없거나 [id] 가 null 이면 null.
  String? pathFor(String? id) => id == null ? null : _paths[id];

  /// 초상화가 있는 캐릭터 id.
  Iterable<String> get ids => _paths.keys;

  int get length => _paths.length;

  // ── 앱 전역 캐시 ─────────────────────────────────────────────

  static final ValueNotifier<PortraitRegistry> _current = ValueNotifier(empty);

  /// 지금 쓰는 목록. 시작 전이나 읽기 실패 시 [empty].
  static PortraitRegistry get current => _current.value;

  /// 위젯이 구독하는 알림. [load]·[debugOverride] 가 바꾼다.
  static ValueListenable<PortraitRegistry> get listenable => _current;

  /// 번들의 `AssetManifest` 를 한 번 읽는다. 실패해도 던지지 않고 [empty] 로 남는다
  /// (초상화가 없을 뿐 게임은 그대로 돈다).
  static Future<PortraitRegistry> load({AssetBundle? bundle}) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(
        bundle ?? rootBundle,
      );
      _current.value = PortraitRegistry.fromAssets(
        manifest.listAssets(),
        bundle: bundle,
      );
    } catch (e) {
      debugPrint('초상화 목록을 읽지 못함: $e');
      _current.value = empty;
    }
    return _current.value;
  }

  /// 테스트·디버그용. [registry] 로 바꾸고, null 이면 [empty] 로 되돌린다.
  @visibleForTesting
  static void debugOverride(PortraitRegistry? registry) =>
      _current.value = registry ?? empty;
}

/// 원형으로 자른 초상화 한 장. 그림을 읽는 중이거나 실패하면 [fallback] 을 그린다.
///
/// 크기는 항상 [size]×[size] 라서 그림 유무로 레이아웃이 달라지지 않는다. 디코딩은
/// 화면 크기(× 기기 배율)로 줄여 메모리를 아낀다(1024px 원본을 40pt 에 그리지 않게).
class PortraitImage extends StatelessWidget {
  final String path;
  final double size;
  final String semanticLabel;
  final AssetBundle? bundle;
  final WidgetBuilder fallback;

  const PortraitImage({
    super.key,
    required this.path,
    required this.size,
    required this.semanticLabel,
    required this.fallback,
    this.bundle,
  });

  @override
  Widget build(BuildContext context) {
    final px = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          path,
          bundle: bundle,
          // scale 을 주면 ExactAssetImage 가 된다. 해상도 변형(2.0x 폴더)을 찾느라
          // 매니페스트를 다시 읽지 않는다. 초상화는 1024px 한 벌뿐이다.
          scale: 1,
          cacheWidth: px,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          semanticLabel: semanticLabel,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, sync) =>
              frame == null && !sync ? fallback(context) : child,
          errorBuilder: (context, error, stack) => fallback(context),
        ),
      ),
    );
  }
}
