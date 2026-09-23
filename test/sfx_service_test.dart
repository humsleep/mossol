// SfxService 의 기본값과 토글 게이트(docs/overhaul/05_audio_haptics.md §4).
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/audio/sfx_service.dart';
import 'package:mossol/engine/meta_service.dart';

import 'widget/helpers.dart';

void main() {
  test('기본 인스턴스는 NoopSfxService — 위젯 테스트가 플러그인 없이 돈다', () {
    expect(SfxService.instance, isA<NoopSfxService>());
    // 아무것도 던지지 않는다.
    SfxService.instance
      ..cue(Sfx.msgIn)
      ..startRing()
      ..stopRing()
      ..stopAll()
      ..haptic(HapticKind.buzz);
  });

  test('큐 11개, 파일명은 snake_case 로 1:1', () {
    expect(Sfx.values.length, 11);
    expect(Sfx.values.map((s) => s.file).toSet().length, 11);
    for (final s in Sfx.values) {
      expect(s.file, matches(RegExp(r'^[a-z_]+$')), reason: s.name);
    }
    expect(Sfx.callRing.priority, SfxPriority.p0);
    expect(Sfx.ending.priority, SfxPriority.p0);
    expect(Sfx.msgOut.priority, SfxPriority.p2);
    expect(Sfx.waitRead.priority, SfxPriority.p2);
  });

  test('sfxOn 이 꺼지면 play 는 무시, haptic 은 그대로', () {
    final s = RecordingSfxService()..sfxOn = false;
    s.cue(Sfx.choiceOk);
    expect(s.played, isEmpty);
    expect(s.haptics, [HapticKind.medium]);
    s.startRing();
    expect(s.played, isEmpty);
    expect(s.ringing, isTrue, reason: '벨 상태(진동)는 소리와 별개');
  });

  test('hapticOn 이 꺼지면 haptic 은 무시, play 는 그대로', () {
    final s = RecordingSfxService()..hapticOn = false;
    s.cue(Sfx.choiceFail);
    expect(s.played, [Sfx.choiceFail]);
    expect(s.haptics, isEmpty);
    s.haptic(HapticKind.buzz);
    expect(s.haptics, isEmpty);
  });

  test('cue 는 큐마다 정해진 기본 진동을 낸다', () {
    final s = RecordingSfxService();
    for (final c in Sfx.values) {
      s.clear();
      s.cue(c);
      expect(s.played, [c]);
      expect(s.haptics, c.haptic == null ? isEmpty : [c.haptic]);
    }
  });

  test('PlayerMeta: sfxOn·hapticOn 은 추가 필드 — 없으면 켬, false 만 끔', () {
    final old = PlayerMeta.fromJson({'streakDays': 2});
    expect(old.sfxOn, isTrue);
    expect(old.hapticOn, isTrue);
    final bad = PlayerMeta.fromJson({'sfxOn': 'no', 'hapticOn': 0});
    expect(bad.sfxOn, isTrue);
    expect(bad.hapticOn, isTrue);
    final off = PlayerMeta.fromJson({'sfxOn': false, 'hapticOn': false});
    expect(off.sfxOn, isFalse);
    expect(off.hapticOn, isFalse);
    final j = PlayerMeta(sfxOn: false).toJson();
    expect(j['sfxOn'], isFalse);
    expect(j['hapticOn'], isTrue);
  });
}
