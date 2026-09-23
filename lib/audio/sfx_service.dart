/// 효과음·진동의 유일한 입구. 명세는 docs/overhaul/05_audio_haptics.md.
///
/// 화면은 [SfxService.instance] 만 부르고 패키지(audioplayers · HapticFeedback)를
/// 직접 만지지 않는다. 기본값은 [NoopSfxService] 라 위젯 테스트는 플러그인 채널을
/// 건드리지 않고, 검증이 필요할 때만 기록용 구현으로 바꿔 끼운다.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 재생 우선순위. P0 는 다른 소리를 멈추고 단독, P2 는 P0(벨) 중엔 버린다.
enum SfxPriority { p0, p1, p2 }

/// 진동 종류. iOS 는 임의 파형이 없어 내장 다섯 가지로만 리듬을 만든다.
enum HapticKind { light, medium, heavy, selection, buzz }

/// 효과음 큐. 파일명은 `assets/sfx/<file>.wav` 로 1:1 대응한다(05 §3).
enum Sfx {
  /// 문자 도착(알림 카드). 동작 줄이기로 카드가 생략돼도 낸다.
  msgIn('msg_in', SfxPriority.p1, HapticKind.medium),

  /// 전화 벨. 루프 파일. 진동 케이던스는 [AudioSfxService] 가 따로 돌린다.
  callRing('call_ring', SfxPriority.p0, null),
  callConnect('call_connect', SfxPriority.p1, HapticKind.light),
  callEnd('call_end', SfxPriority.p1, HapticKind.medium),

  /// 내 말 전송.
  msgOut('msg_out', SfxPriority.p2, HapticKind.selection),

  /// 읽씹 대기 끝(읽음).
  waitRead('wait_read', SfxPriority.p2, HapticKind.light),
  choiceOk('choice_ok', SfxPriority.p1, HapticKind.medium),
  choiceFail('choice_fail', SfxPriority.p1, HapticKind.heavy),
  summary('summary', SfxPriority.p1, HapticKind.light),

  /// 엔딩. 다른 소리를 전부 멈춘다. 진동은 heavy → 120ms → light.
  ending('ending', SfxPriority.p0, HapticKind.heavy),

  /// 날짜 전환 카드(2단계에서 화면이 생긴다).
  dayStart('day_start', SfxPriority.p1, HapticKind.light);

  const Sfx(this.file, this.priority, this.haptic);

  /// 파일 이름(확장자 없음).
  final String file;
  final SfxPriority priority;

  /// 이 큐와 함께 나가는 기본 진동. null 이면 [cue] 가 진동을 내지 않는다.
  final HapticKind? haptic;
}

/// 효과음·진동 서비스. [play]·[haptic] 은 토글([sfxOn]·[hapticOn])로 걸러지고,
/// 구현체는 [onPlay]·[onHaptic] 만 채운다.
abstract class SfxService {
  /// 앱 전역 인스턴스. 테스트 기본값은 [NoopSfxService], `main()` 이 실기기에서 바꿔 끼운다.
  static SfxService instance = NoopSfxService();

  /// 설정의 효과음·진동 토글. `PlayerMeta` 값을 시작할 때와 바뀔 때 넣는다.
  bool sfxOn = true;
  bool hapticOn = true;

  /// 처음부터 재생. 같은 큐를 다시 부르면 처음부터 다시 난다.
  void play(Sfx cue) {
    if (sfxOn) onPlay(cue);
  }

  void haptic(HapticKind kind) {
    if (hapticOn) onHaptic(kind);
  }

  /// 소리와 그 큐의 기본 진동([Sfx.haptic])을 함께.
  void cue(Sfx c) {
    play(c);
    final h = c.haptic;
    if (h != null) haptic(h);
  }

  /// 벨 시작(소리 루프 + 진동 케이던스). 이미 울리는 중이면 무시한다.
  void startRing();

  /// 벨 정지. 받기·거절·다른 이벤트·dispose·백그라운드에서 부른다.
  void stopRing();

  /// 전부 정지(백그라운드·엔딩).
  void stopAll();

  @protected
  void onPlay(Sfx cue);

  @protected
  void onHaptic(HapticKind kind);
}

/// 아무것도 하지 않는다. 테스트와 웹의 기본값.
class NoopSfxService extends SfxService {
  @override
  void onPlay(Sfx cue) {}

  @override
  void onHaptic(HapticKind kind) {}

  @override
  void startRing() {}

  @override
  void stopRing() {}

  @override
  void stopAll() {}
}

/// audioplayers + HapticFeedback 구현. 큐마다 플레이어 하나를 미리 만들어 둔다.
///
/// 세션은 `ambient` + `mixWithOthers` — 무음 스위치를 존중하고 사용자의 음악을 끊지
/// 않는다. 백그라운드 재생은 하지 않는다(`UIBackgroundModes` 에 audio 를 넣지 않는다).
class AudioSfxService extends SfxService with WidgetsBindingObserver {
  /// 벨 진동 한 주기. 아이폰 기본 벨의 "두 번 울리고 쉼" 을 흉내 낸다(05 §2.3).
  static const ringPeriod = Duration(milliseconds: 2600);
  static const ringSecondBeat = Duration(milliseconds: 600);

  /// 방치했을 때의 짜증·배터리를 막는다. 소리는 계속 울린다.
  static const ringHapticLimit = Duration(seconds: 20);

  /// 엔딩 진동의 두 번째 박자.
  static const endingSecondBeat = Duration(milliseconds: 120);

  final _players = <Sfx, AudioPlayer>{};
  bool _ready = false;
  bool _ringing = false;
  Timer? _ringTimer;
  Timer? _ringBeat;
  Timer? _ringHapticStop;
  Timer? _endingBeat;

  /// 앱 시작 1회: 세션 카테고리 + 큐마다 setSource. 실패해도 던지지 않는다 —
  /// 소리가 안 나는 것이 앱이 안 뜨는 것보다 낫다.
  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      for (final c in Sfx.values) {
        final p = AudioPlayer(playerId: 'sfx_${c.file}');
        await p.setReleaseMode(
          c == Sfx.callRing ? ReleaseMode.loop : ReleaseMode.stop,
        );
        // AudioCache 기본 접두사가 `assets/` 라 여기서는 그 아래 경로만 적는다.
        await p.setSource(AssetSource('sfx/${c.file}.wav'));
        _players[c] = p;
      }
      _ready = true;
    } catch (e) {
      debugPrint('효과음 준비 실패: $e');
    }
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onPlay(Sfx cue) {
    if (!_ready) return;
    // 벨(P0) 이 울리는 동안 잔소리(P2) 는 버린다.
    if (_ringing && cue.priority == SfxPriority.p2) return;
    final p = _players[cue];
    if (p == null) return;
    if (cue.priority == SfxPriority.p0) {
      // 단독 재생. 벨 자신을 켤 때는 벨 상태를 건드리지 않는다.
      if (cue != Sfx.callRing) stopRing();
      _endingBeat?.cancel();
      for (final e in _players.entries) {
        if (e.key != cue) unawaited(e.value.stop());
      }
    }
    // 같은 큐 재트리거는 처음부터 다시.
    unawaited(p.stop().then((_) => p.resume()));
    if (cue == Sfx.ending) {
      _endingBeat?.cancel();
      _endingBeat = Timer(endingSecondBeat, () => haptic(HapticKind.light));
    }
  }

  @override
  void onHaptic(HapticKind kind) {
    // 시스템 진동 끄기 등으로 실패해도 앱은 조용히 넘어간다.
    unawaited(switch (kind) {
      HapticKind.light => HapticFeedback.lightImpact(),
      HapticKind.medium => HapticFeedback.mediumImpact(),
      HapticKind.heavy => HapticFeedback.heavyImpact(),
      HapticKind.selection => HapticFeedback.selectionClick(),
      HapticKind.buzz => HapticFeedback.vibrate(),
    });
  }

  @override
  void startRing() {
    if (_ringing) return;
    _ringing = true;
    play(Sfx.callRing);
    if (hapticOn) _startRingHaptics();
  }

  @override
  void stopRing() {
    _stopRingHaptics();
    if (!_ringing) return;
    _ringing = false;
    final p = _players[Sfx.callRing];
    if (p != null) unawaited(p.stop());
  }

  @override
  void stopAll() {
    stopRing();
    _endingBeat?.cancel();
    for (final p in _players.values) {
      unawaited(p.stop());
    }
  }

  /// t=0 진동, t=600ms 진동, 2.6s 마다 반복. `Timer.periodic` 은 한 주기 뒤에 시작하므로
  /// 첫 박자는 직접 친다. `vibrate()` 는 겹쳐 부르면 무시되니 간격을 500ms 이상 둔다.
  void _startRingHaptics() {
    _stopRingHaptics();
    void burst() {
      onHaptic(HapticKind.buzz);
      _ringBeat?.cancel();
      _ringBeat = Timer(ringSecondBeat, () => onHaptic(HapticKind.buzz));
    }

    burst();
    _ringTimer = Timer.periodic(ringPeriod, (_) => burst());
    _ringHapticStop = Timer(ringHapticLimit, _stopRingHaptics);
  }

  void _stopRingHaptics() {
    _ringTimer?.cancel();
    _ringBeat?.cancel();
    _ringHapticStop?.cancel();
    _ringTimer = null;
    _ringBeat = null;
    _ringHapticStop = null;
  }

  /// 홈으로 나가거나 실제 전화가 오면 벨·진동을 즉시 끊는다. 잠금화면에서 게임 벨이
  /// 울리면 안 된다. 복귀 뒤 벨 재개는 EventScreen 이 자기 상태를 보고 다시 건다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      stopAll();
    }
  }
}
