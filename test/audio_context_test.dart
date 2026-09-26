// 실제 구현([AudioSfxService])의 회귀 방지선. 다른 테스트는 전부 NoopSfxService 라
// 이 파일이 없으면 진짜 오디오 경로는 한 줄도 돌지 않는다 —
// 그래서 `AudioContextIOS(ambient + mixWithOthers)` 가 세 번의 TestFlight 빌드 동안
// 초기화 첫 줄에서 던지고, 11개 큐가 전부 무음인 채 통과했다(docs/review/04 P1-1).
//
// 플랫폼은 채널 모킹으로 대신한다. `xyz.luan/audioplayers` 는 메서드 채널,
// 플레이어마다 `…/events/<playerId>` 이벤트 채널이 있고, `setSourceUrl` 뒤에
// `audio.onPrepared` 가 와야 `setSource` 가 끝난다.
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/audio/sfx_service.dart';

/// 플랫폼에 도착한 호출 한 건.
typedef _Call = ({String method, String? playerId});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <_Call>[];
  late AudioSfxService sfx;

  setUp(() {
    calls.clear();
    final sinks = <String, MockStreamHandlerEventSink>{};
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    for (final c in Sfx.values) {
      final id = 'sfx_${c.file}';
      messenger.setMockStreamHandler(
        EventChannel('xyz.luan/audioplayers/events/$id'),
        MockStreamHandler.inline(onListen: (_, sink) => sinks[id] = sink),
      );
    }
    messenger.setMockStreamHandler(
      const EventChannel('xyz.luan/audioplayers.global/events'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        final args = (call.arguments as Map?) ?? const {};
        final id = args['playerId'] as String?;
        calls.add((method: call.method, playerId: id));
        // 네이티브가 준비를 알려야 setSource 의 future 가 끝난다.
        if (call.method == 'setSourceUrl' && id != null) {
          sinks[id]?.success(const {'event': 'audio.onPrepared', 'value': true});
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async {
        calls.add((method: 'global:${call.method}', playerId: null));
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      // 에셋을 복사해 둘 임시 폴더. 실제로 파일을 쓴다.
      (call) async => '${Directory.systemTemp.path}/mossol_sfx_test',
    );

    sfx = AudioSfxService();
    addTearDown(() {
      WidgetsBinding.instance.removeObserver(sfx);
      for (final name in const [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
        'plugins.flutter.io/path_provider',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(name), null);
      }
    });
  });

  test('세션 조합이 audioplayers 의 assert 를 통과한다', () {
    // AudioContextIOS 는 생성자에서 assert 한다 — 만드는 것만으로 검사가 된다.
    late AudioContext ctx;
    expect(() => ctx = AudioSfxService.audioContext, returnsNormally);
    final ios = ctx.iOS;
    expect(ios.category, AVAudioSessionCategory.ambient);
    expect(
      ios.options,
      isEmpty,
      reason: 'ambient 는 옵션 없이도 다른 앱과 섞이고, mixWithOthers 를 명시하면 던진다',
    );
  });

  test('init 이 조용히 실패하지 않는다 — lastInitError 는 null, 큐 11개가 준비된다', () async {
    expect(sfx.lastInitError, isNull);
    await sfx.init();
    expect(sfx.lastInitError, isNull, reason: 'init 의 catch 가 무엇도 삼키지 않았다');
    expect(
      calls.map((c) => c.method),
      contains('global:setAudioContext'),
      reason: '세션 설정이 실제로 플랫폼까지 갔다',
    );
    expect(
      calls.where((c) => c.method == 'setSourceUrl').length,
      Sfx.values.length,
    );
  });

  test('벨을 바로 끄면 뒤늦은 resume 이 되살리지 않는다', () async {
    await sfx.init();
    calls.clear();
    // 거절 → 계속 이 한 틱에 만들던 경합(04 P1-2). stop 의 then 이 도는 사이에 정지가 왔다.
    sfx.startRing();
    sfx.stopRing();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    // 위치 폴링(getCurrentPosition)은 재생 상태와 무관하니 재생 명령만 본다.
    const playback = {'stop', 'resume', 'pause'};
    final ring = calls
        .where((c) => c.playerId == 'sfx_${Sfx.callRing.file}')
        .map((c) => c.method)
        .where(playback.contains)
        .toList();
    expect(ring, isNotEmpty);
    expect(ring, isNot(contains('resume')), reason: '멈춘 벨을 다시 켜면 안 된다');
    expect(ring.last, 'stop');
  });
}
