/// 엔딩 기념품 카드를 그림으로 굽고 시스템 공유 시트에 넘긴다.
/// 규격은 docs/DESIGN_SYSTEM.md §2.5(엔딩), 근거는 docs/review/11_polish_verdict.md 10위.
///
/// 이 장르에서 엔딩 카드는 **유일한 자연 유입 장치**다. `ending_screen.dart` 에는
/// `shareBoundaryKey` 가 진작 트리에 꽂혀 있었지만 `toImage()` 를 부르는 곳이 한 군데도
/// 없었다 — 주석이 적어 둔 "나중" 이 여기다.
///
/// **밖으로 나가는 것은 플레이어가 보고 있는 카드 한 장뿐이다.** 굽는 대상은
/// `RepaintBoundary` 안쪽(기념품 덩어리)이라 버튼·다음 판 카드는 들어가지 않고,
/// 곁들이는 문구도 앱 이름 한 줄로 고정이다(이름·세이브·통계 같은 건 붙이지 않는다).
/// 파일은 앱 임시 폴더에 잠깐 놓았다가 시트가 닫히면 지운다.
///
/// **못 하면 조용히 못 한다.** 그림을 못 굽거나(경계가 아직 안 그려짐) 공유를 못 하면
/// (플러그인 없음·지원하지 않는 기기) 예외를 밖으로 내보내지 않고 `false` 만 돌려준다.
/// 부르는 쪽이 그때 스낵바 한 줄을 띄운다.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// 공유 한 번. [instance] 를 갈아 끼울 수 있다.
///
/// 위젯 테스트에는 공유 플러그인 채널이 없어서 실제 호출은 `MissingPluginException`
/// 이 된다. `SfxService.instance` 와 같은 방식으로 바꿔 끼우면 테스트는 "무엇을
/// 넘겼는지" 만 보고 지나갈 수 있다.
class KeepsakeShare {
  static KeepsakeShare instance = KeepsakeShare();

  /// 임시 파일 이름. 엔딩 이름을 파일명에 넣지 않는다 — 카드에 이미 적혀 있고,
  /// 파일명은 공유받는 쪽의 기기에 남는 자리다.
  static const fileName = 'mossol_ending.png';

  /// 굽는 배율의 상한. 기기 배율이 그대로 곱해지면 큰 화면에서 몇 MB 가 된다.
  static const maxPixelRatio = 3.0;

  /// [key] 가 가리키는 [RepaintBoundary] 를 PNG 로 굽고 공유 시트를 띄운다.
  /// 어느 단계에서든 실패하면 `false`.
  Future<bool> shareBoundary(
    GlobalKey key, {
    required double pixelRatio,
    required String text,
    Rect? origin,
  }) async {
    final png = await capture(key, pixelRatio: pixelRatio);
    if (png == null) return false;
    return sharePng(png, text: text, origin: origin);
  }

  /// 경계 하나를 PNG 바이트로. 실패하면 null(예외를 내보내지 않는다).
  Future<Uint8List?> capture(
    GlobalKey key, {
    required double pixelRatio,
  }) async {
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;
    ui.Image? image;
    try {
      image = await object.toImage(
        pixelRatio: pixelRatio.clamp(1.0, maxPixelRatio),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      // 아직 한 번도 안 그려진 경계, 지원하지 않는 기기 — 둘 다 "공유 못 함" 이다.
      return null;
    } finally {
      image?.dispose();
    }
  }

  /// 실제 시트. 테스트가 덮어쓰는 자리다.
  @protected
  Future<bool> sharePng(
    Uint8List png, {
    required String text,
    Rect? origin,
  }) async {
    File? file;
    try {
      file = await File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName',
      ).writeAsBytes(png, flush: true);
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: [XFile(file.path, mimeType: 'image/png', name: fileName)],
          // 아이패드·맥은 시트를 누른 자리에 띄운다. 없으면 화면 가운데다.
          sharePositionOrigin: origin,
        ),
      );
      // 사용자가 시트를 닫은 것(dismissed)은 실패가 아니다 — 아무 말도 하지 않는다.
      return result.status != ShareResultStatus.unavailable;
    } catch (_) {
      return false;
    } finally {
      // 카드 말고는 아무것도 남기지 않는다.
      try {
        await file?.delete();
      } catch (_) {}
    }
  }
}
