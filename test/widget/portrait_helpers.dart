import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/ui/portraits.dart';

/// 12명 id. characters.json 과 같다.
const portraitIds = [
  'seoyeon',
  'haneul',
  'jiwoo',
  'minjae',
  'yeeun',
  'doyun',
  'jeongwoo',
  'daeun',
  'seunghyun',
  'sohee',
  'geonwoo',
  'yuna',
];

/// `assets/portraits/*` 요청에 test/fixtures 의 16px PNG 를 돌려주는 가짜 번들.
/// [fail] 이면 초상화 요청을 전부 실패시킨다(파일이 목록엔 있는데 못 읽는 경우).
class FixturePortraitBundle extends CachingAssetBundle {
  final bool fail;
  FixturePortraitBundle({this.fail = false});

  static final Uint8List _png = File('test/fixtures/portrait_16.png')
      .readAsBytesSync();

  @override
  Future<ByteData> load(String key) async {
    if (!fail && key.startsWith(PortraitRegistry.dir)) {
      return ByteData.sublistView(_png);
    }
    throw FlutterError('없는 에셋: $key');
  }
}

/// 초상화 목록을 [ids] 로 바꾸고 테스트가 끝나면 되돌린다.
FixturePortraitBundle usePortraits({
  Iterable<String> ids = portraitIds,
  bool fail = false,
}) {
  final bundle = FixturePortraitBundle(fail: fail);
  PortraitRegistry.debugOverride(
    PortraitRegistry.fromAssets([
      for (final id in ids) '${PortraitRegistry.dir}$id.png',
    ], bundle: bundle),
  );
  addTearDown(() => PortraitRegistry.debugOverride(null));
  return bundle;
}

/// 가짜 번들 이미지는 실제 디코딩(엔진 비동기)이 필요하다. 진짜 시간을 조금 흘린 뒤 다시 그린다.
Future<void> settleImages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
}
