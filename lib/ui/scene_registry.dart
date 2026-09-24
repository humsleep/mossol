/// 장면 삽화·사진·스티커·엔딩 그림 목록(docs/overhaul/06_scene_plan.md §4).
///
/// [PortraitRegistry] 와 같은 방식이다. 시작할 때 `AssetManifest` 를 한 번 읽어
/// `assets/scenes|photos|stickers|endings/` 에 **어떤 파일이 있는지만** 캐시한다.
/// 파일을 넣고 다시 빌드하면 그림이 뜨고, 하나도 없으면 지금 화면 그대로다
/// (자리도 잡지 않는다). 파일명 규약은 docs/SCENE_PROMPTS.md §0.3.
///
/// 위젯은 [SceneRegistry.listenable] 을 구독하므로 목록이 늦게 도착해도 다시 그려진다.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../engine/models.dart';
import 'portraits.dart';

/// 그림 파일 목록. 폴더별로 `파일 이름(확장자 뺀 것) → 에셋 경로`.
@immutable
class SceneRegistry {
  /// 장면 삽화(3:2). `assets/scenes/<이벤트 id>.webp`.
  static const sceneDir = 'assets/scenes/';

  /// 사진 메시지(4:3). 전용은 `<이벤트 id>_0`, 공용은 `<icon>`.
  static const photoDir = 'assets/photos/';

  /// 스티커(1:1 투명). `<캐릭터 id>_<감정>`.
  static const stickerDir = 'assets/stickers/';

  /// 엔딩 히어로(3:2). `<캐릭터 id>` · `common_<tier>`.
  static const endingDir = 'assets/endings/';

  static const dirs = [sceneDir, photoDir, stickerDir, endingDir];

  /// 같은 이름으로 여러 형식이 있으면 앞쪽을 쓴다. 초상화와 같은 순서다
  /// (webp 가 규약 형식이지만, png 를 임시로 넣어 봐도 뜨게 둔다).
  static const extensions = PortraitRegistry.extensions;

  final Map<String, Map<String, String>> _byDir;

  /// 목록에 있는 에셋 경로 전부. JSON 이 경로를 직접 적었을 때 존재를 확인한다.
  final Set<String> _paths;

  /// 그림을 읽을 번들. null 이면 `rootBundle`. 테스트가 가짜 번들을 넣는다.
  final AssetBundle? bundle;

  const SceneRegistry._(this._byDir, this._paths, this.bundle);

  /// 그림이 하나도 없는 상태(기본값).
  static const empty = SceneRegistry._({}, {}, null);

  /// 에셋 경로 목록에서 네 폴더의 `<이름>.<확장자>` 만 골라 만든다.
  /// 하위 폴더, 목록에 없는 형식, `.gitkeep` 같은 숨김 파일은 무시한다.
  factory SceneRegistry.fromAssets(
    Iterable<String> assets, {
    AssetBundle? bundle,
  }) {
    final found = <String, Map<String, String>>{
      for (final d in dirs) d: <String, String>{},
    };
    final rank = <String, Map<String, int>>{
      for (final d in dirs) d: <String, int>{},
    };
    final paths = <String>{};
    for (final path in assets) {
      String? dir;
      for (final d in dirs) {
        if (path.startsWith(d)) {
          dir = d;
          break;
        }
      }
      if (dir == null) continue;
      final file = path.substring(dir.length);
      if (file.contains('/') || file.startsWith('.')) continue;
      final dot = file.lastIndexOf('.');
      if (dot <= 0) continue;
      final key = file.substring(0, dot);
      final r = extensions.indexOf(file.substring(dot + 1).toLowerCase());
      if (r < 0) continue;
      paths.add(path);
      final best = rank[dir]![key];
      if (best == null || r < best) {
        rank[dir]![key] = r;
        found[dir]![key] = path;
      }
    }
    return SceneRegistry._(
      Map.unmodifiable({
        for (final d in dirs) d: Map<String, String>.unmodifiable(found[d]!),
      }),
      Set.unmodifiable(paths),
      bundle,
    );
  }

  /// [dir] 폴더에서 [key] 이름의 그림. 없거나 [key] 가 null 이면 null.
  String? pathIn(String dir, String? key) =>
      key == null ? null : _byDir[dir]?[key];

  /// 장면 삽화(`assets/scenes/<key>`).
  String? scene(String? key) => pathIn(sceneDir, key);

  /// 사진(`assets/photos/<key>`).
  String? photo(String? key) => pathIn(photoDir, key);

  /// 스티커(`assets/stickers/<key>`).
  String? sticker(String? key) => pathIn(stickerDir, key);

  /// 엔딩 히어로(`assets/endings/<key>`).
  String? ending(String? key) => pathIn(endingDir, key);

  /// JSON 이 적어 준 경로. 네 폴더 안에 **실제로 있는** 파일일 때만 돌려준다
  /// (없는 파일을 그리면 깨진 상자가 되므로 애초에 그리지 않는다).
  ///
  /// 확장자를 빼고 적어도 된다(`assets/photos/mo_daily_dad_sky_0`). 그래야 JSON 이
  /// 파일 형식에 묶이지 않는다 — png 로 뽑았다가 jpg 로 줄여도 대본을 고칠 일이 없다.
  String? exact(String? path) {
    if (path == null) return null;
    if (_paths.contains(path)) return path;
    final slash = path.lastIndexOf('/');
    if (slash < 0) return null;
    final dir = path.substring(0, slash + 1);
    final key = path.substring(slash + 1);
    // 확장자가 이미 붙어 있으면(위에서 못 찾았으므로) 없는 파일이다.
    return key.contains('.') ? null : pathIn(dir, key);
  }

  /// [dir] 폴더에 있는 이름들.
  Iterable<String> keysIn(String dir) => _byDir[dir]?.keys ?? const [];

  int get length => _paths.length;

  // ── 앱 전역 캐시 ─────────────────────────────────────────────

  static final ValueNotifier<SceneRegistry> _current = ValueNotifier(empty);

  /// 지금 쓰는 목록. 시작 전이나 읽기 실패 시 [empty].
  static SceneRegistry get current => _current.value;

  /// 위젯이 구독하는 알림. [load]·[debugOverride] 가 바꾼다.
  static ValueListenable<SceneRegistry> get listenable => _current;

  /// 번들의 `AssetManifest` 를 한 번 읽는다. 실패해도 던지지 않고 [empty] 로 남는다
  /// (그림이 없을 뿐 게임은 그대로 돈다).
  static Future<SceneRegistry> load({AssetBundle? bundle}) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(
        bundle ?? rootBundle,
      );
      _current.value = SceneRegistry.fromAssets(
        manifest.listAssets(),
        bundle: bundle,
      );
    } catch (e) {
      debugPrint('장면 그림 목록을 읽지 못함: $e');
      _current.value = empty;
    }
    return _current.value;
  }

  /// 테스트·디버그용. [registry] 로 바꾸고, null 이면 [empty] 로 되돌린다.
  @visibleForTesting
  static void debugOverride(SceneRegistry? registry) =>
      _current.value = registry ?? empty;
}

/// 지금 목록([SceneRegistry.current])으로 그리고, 목록이 늦게 도착하면 다시 그린다.
/// 그림 자리는 전부 이 껍데기 안에 있다(초상화 레지스트리 구독과 같은 이유).
class SceneScope extends StatelessWidget {
  final Widget Function(BuildContext context, SceneRegistry registry) builder;
  const SceneScope({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<SceneRegistry>(
    valueListenable: SceneRegistry.listenable,
    builder: (context, registry, _) => builder(context, registry),
  );
}

/// 데이터 → 그림 경로(06 §4 표). 필드가 있으면 그것을 먼저 보고, 없으면 규약 경로를
/// 찾고, 그것도 없으면 null — 그리는 쪽은 null 이면 **아무것도 그리지 않는다**.
abstract final class SceneImages {
  static SceneRegistry _r(SceneRegistry? r) => r ?? SceneRegistry.current;

  /// 이벤트 삽화. `image` 필드 → `assets/scenes/<이벤트 id>.<확장자>`.
  static String? forEvent(StoryEvent? e, {SceneRegistry? registry}) {
    if (e == null) return null;
    final r = _r(registry);
    return r.exact(e.image) ?? r.scene(e.id);
  }

  /// 사진 메시지. `photo.image` 필드 → `assets/photos/<icon>.<확장자>`(공용).
  static String? forPhoto(Photo? p, {SceneRegistry? registry}) {
    if (p == null) return null;
    final r = _r(registry);
    return r.exact(p.image) ?? r.photo(p.icon);
  }

  /// 엔딩 히어로. `image` 필드 → 엔딩 id → 캐릭터 id → 공용 `common_<tier>`.
  static String? forEnding(Ending? e, {SceneRegistry? registry}) {
    if (e == null) return null;
    final r = _r(registry);
    return r.exact(e.image) ??
        r.ending(e.id) ??
        r.ending(e.character) ??
        r.ending(commonEndingKey(e.tier));
  }

  /// 공용 엔딩 그림 이름. solo·bad·hidden 만 공용이 있다(happy·good 은 캐릭터 그림).
  static String? commonEndingKey(String tier) =>
      const {'solo', 'bad', 'hidden'}.contains(tier) ? 'common_$tier' : null;

  /// 스티커. [key] 는 파일 이름 그대로(`seoyeon_joy`·`daeun_blank`).
  /// 화이트리스트 밖 이름은 찾지 않는다.
  static String? forSticker(String? key, {SceneRegistry? registry}) =>
      key != null && Sticker.isValid(key) ? _r(registry).sticker(key) : null;
}
