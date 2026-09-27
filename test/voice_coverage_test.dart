// 목소리 축(`humor` · `register`)으로 갈라 놓은 대사가 **어떤 1위에게도 빠짐없이** 있는지.
// 실제 출시 데이터를 본다.
//
// 왜 따로 있나: `StoryBundle.validate` 의 커버리지 검사는 **묶음 전체가 0줄**일 때만 거부한다.
// 클라이맥스 씬은 지문이나 조건 없는 줄이 늘 섞여 있어서 묶음이 0줄이 될 수가 없고, 그래서
// 한 칸을 빠뜨려도 통과한다. 직접 확인했다 — `m26.lines` 에서 도윤 칸(warm·polite) 한 줄을
// 지우고 전체 스위트를 돌리면 971개가 전부 초록이었다(docs/review/13_main_voices.md §1).
//
// 여기서 보는 것은 **덩어리(block)** 다. 조건이 붙은 줄이 연달아 오는 한 자리가 한 덩어리이고,
// 그 자리는 "지금 상대가 말할 차례" 를 뜻한다. 그 덩어리에서 한 목소리라도 아무 줄을 못 받으면
// 그 캐릭터를 공략한 플레이어만 침묵을 본다 — 이번 라운드가 고치려던 무음 클라이맥스 버그다.
//
// 개수가 같은지는 보지 않는다. `meme` 은 짤 한 장 뒤에 한 줄을 더 붙이는 게 정상이고
// (`m36` 의 `[짤] 뭔가 정리하는 사람.jpg` + `물어봐도 되는지`), 그건 결함이 아니라 농담이다.
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/mbti.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/minigames/registry.dart';

import 'sim_balance_test.dart' show loadBundle;

bool _gated(Line l) => l.humor.isNotEmpty || l.register != null;

/// 조건이 붙은 줄이 연달아 오는 자리들. 각 덩어리가 "상대가 말할 한 차례" 다.
///
/// `humor` 가 붙은 줄과 `register` 만 붙은 줄은 **다른 자리로 센다.** 한 덩어리로 묶으면
/// 농담 코드 칸이 비어 있어도 그 뒤의 말높임 줄이 대신 채워 통과한다 — `m26` 에서 도윤 칸
/// (warm·polite) 한 줄을 지우고 확인했다. 굵게 나눈 첫 판이 그 구멍을 놓쳤고, 이 주석이
/// 그 반증 실험의 결과다.
List<List<Line>> _blocks(List<Line> lines) {
  final out = <List<Line>>[];
  var run = <Line>[];
  bool? kind;
  void flush() {
    if (run.isNotEmpty) out.add(run);
    run = <Line>[];
    kind = null;
  }

  for (final l in lines) {
    if (!_gated(l)) {
      flush();
      continue;
    }
    final k = l.humor.isNotEmpty;
    if (kind != null && k != kind) flush();
    kind = k;
    run.add(l);
  }
  flush();
  return out;
}

String _label(CharacterDef? v) =>
    v == null ? '1위 없음' : '${v.name}(${v.humor}·${v.politeness})';

void main() {
  late StoryBundle bundle;
  late List<CharacterDef?> voices;

  setUpAll(() {
    // 데이터 검증이 `"minigame"` 값을 등록된 id 와 맞춰 본다.
    registerMinigames();
    bundle = loadBundle();
    // 이 씬에서 말하는 상대의 경우: 1위 없음 + 캐스트 전원.
    voices = [null, ...bundle.characters];
  });

  /// 한 덩어리를 모든 1위 경우로 걸러 보고, 한 줄도 못 받는 경우를 모은다.
  List<String> holes(String where, List<Line> block, String? charMbti) {
    final bad = <String>[];
    for (final player in Mbti.playerCases) {
      for (final v in voices) {
        final view = MbtiView.of(player, charMbti, voice: v);
        if (block.any(view.allowsLine)) continue;
        bad.add('$where: 1위 ${_label(v)} 플레이어(${player ?? '미정'})에게 대사가 0줄');
      }
    }
    return bad;
  }

  test('목소리로 갈린 자리마다 1위가 누구든 대사가 있다', () {
    final bad = <String>[];
    var blocks = 0;
    for (final ev in bundle.events) {
      final charMbti = bundle.characterById[ev.character]?.mbti;
      void check(String where, List<Line> lines) {
        for (var i = 0; i < _blocks(lines).length; i++) {
          final b = _blocks(lines)[i];
          blocks++;
          bad.addAll(holes('${ev.id}.$where[$i]', b, charMbti));
        }
      }

      check('lines', ev.lines);
      for (final vs in ev.variants) {
        check('variants', vs);
      }
      for (var i = 0; i < ev.choices.length; i++) {
        final c = ev.choices[i];
        check('choices[$i].reply', c.reply);
        check('choices[$i].failReply', c.failReply);
        check('choices[$i].critReply', c.critReply);
      }
    }
    // 검사가 "볼 것이 없어서" 통과한 게 아님을 같은 테스트 안에서 고정한다.
    expect(blocks, greaterThan(10), reason: '목소리로 갈린 자리가 실제로 있어야 한다');
    expect(bad, isEmpty, reason: bad.take(12).join('\n'));
  });

  test('이 검사가 실제로 잡는다 — 한 칸을 지우면 실패한다', () {
    // `validate` 가 못 잡는 그 삭제를 여기서는 잡아야 한다.
    final ev = bundle.events.firstWhere(
      (e) => _blocks(e.lines).any((b) => b.length >= 5 && b.first.humor.isNotEmpty),
    );
    final block = _blocks(
      ev.lines,
    ).firstWhere((b) => b.length >= 5 && b.first.humor.isNotEmpty);
    final charMbti = bundle.characterById[ev.character]?.mbti;
    expect(holes(ev.id, block, charMbti), isEmpty, reason: '원본은 빈 곳이 없다');

    for (final drop in block) {
      final broken = [for (final l in block) if (l != drop) l];
      expect(
        holes(ev.id, broken, charMbti),
        isNotEmpty,
        reason: '${ev.id} 에서 "${drop.text}" 를 빼면 누군가는 침묵을 본다',
      );
    }
  });
}
