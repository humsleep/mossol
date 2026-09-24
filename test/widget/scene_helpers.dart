import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/ui/scene_registry.dart';

/// `assets/scenes|photos|stickers|endings/*` 요청에 test/fixtures 의 16px PNG 를
/// 돌려주는 가짜 번들. [fail] 이면 전부 실패시킨다(목록엔 있는데 파일이 깨진 경우).
class FixtureSceneBundle extends CachingAssetBundle {
  final bool fail;
  FixtureSceneBundle({this.fail = false});

  static final Uint8List _png = File(
    'test/fixtures/portrait_16.png',
  ).readAsBytesSync();

  @override
  Future<ByteData> load(String key) async {
    if (!fail) {
      for (final d in SceneRegistry.dirs) {
        if (key.startsWith(d)) return ByteData.sublistView(_png);
      }
    }
    throw FlutterError('없는 에셋: $key');
  }
}

/// 그림 목록을 [paths] 로 바꾸고 테스트가 끝나면 되돌린다. 기본은 빈 목록
/// (= 지금 저장소 상태: 그림 파일이 하나도 없다).
FixtureSceneBundle useScenes({
  Iterable<String> paths = const [],
  bool fail = false,
}) {
  final bundle = FixtureSceneBundle(fail: fail);
  SceneRegistry.debugOverride(
    SceneRegistry.fromAssets(paths, bundle: bundle),
  );
  addTearDown(() => SceneRegistry.debugOverride(null));
  return bundle;
}

/// 가짜 번들 이미지는 실제 디코딩(엔진 비동기)이 필요하다. 진짜 시간을 조금 흘린 뒤 다시 그린다.
Future<void> settleSceneImages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
}
