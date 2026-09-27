// 플레이어가 실제로 받는 큐를 순서대로 찍는 일회용 진단 스크립트. 소스는 건드리지 않는다.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/retention.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/engine/text_template.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/minigames/registry.dart';

const kDir = 'assets/story';
const kOut = String.fromEnvironment('OUT', defaultValue: 'tool/transcripts');
const kName = '민수';

StoryBundle loadBundle() => StoryBundle.fromJsonStrings(
  config: File('$kDir/config.json').readAsStringSync(),
  characters: File('$kDir/characters.json').readAsStringSync(),
  events: [
    for (final f in StoryBundle.eventFiles)
      File('$kDir/$f').readAsStringSync(),
  ],
  endings: File('$kDir/endings.json').readAsStringSync(),
  signals: File('$kDir/signals.json').readAsStringSync(),
  knownMinigames: minigameIds,
);

String? curTop;
String say(String t) =>
    TextTemplate.fill(t, name: kName, mbti: null, top: curTop);

/// 한 회차 전사. [picker] 가 선택지를 고른다.
String transcript(
  StoryBundle b,
  int seed, {
  required String pickerName,
  required int Function(GameState, StoryEvent, List<ChoiceView>, Random) pick,
  required DayAction Function(GameState, List<DayAction>, Random) action,
  int days = 32,
  String pref = 'f',
}) {
  final engine = EventEngine(b);
  final s = GameState.fresh(
    b.config,
    b.characters,
    seed: seed,
    run: 1,
    preference: pref,
    mbti: null,
  );
  final r = Random(seed * 104729 + pickerName.hashCode);
  final o = StringBuffer();
  o.writeln('==============================================================');
  o.writeln('시드 $seed · 선호 $pref · 이름 $kName · MBTI 모름 · 선택 전략 $pickerName');
  o.writeln('로스터: ${engine.rosterFor(s).map((c) => '${c.name}(${c.id}${c.hidden ? ",히든" : ""})').join(', ')}');
  o.writeln('==============================================================');

  final layerCount = <String, int>{};
  final charDays = <String, List<int>>{};

  while (s.day <= days) {
    final slot = engine.spinRoulette(s);
    s.rouletteDay = s.day;
    engine.applyRoulette(s, slot);
    final act = action(s, b.config.actions, r);
    engine.applyAction(s, act);

    o.writeln('');
    o.writeln('################ D+${s.day} ################');
    o.writeln('[아침] 룰렛 "${EventEngine.rouletteSlots[slot].$1}" · 행동 ${act.name}');
    final aff = engine
        .rosterFor(s)
        .map((c) => '${c.name} ${s.affectionOf(c.id)}/${s.trustOf(c.id)}')
        .join(' | ');
    o.writeln('[호감/신뢰] $aff');
    o.writeln('[플래그] ${s.flags.isEmpty ? '없음' : s.flags.join(' ')}');

    final queue = engine.planDay(s);
    o.writeln('[오늘 큐 ${queue.length}개] ${queue.map((e) => '${e.id}(${e.layer.name}${e.character == null ? '' : '/${e.character}'})').join(' → ')}');
    var cliff = s.lastCliffhanger;
    String? lastCliffOfDay;
    var idx = 0;
    while (queue.isNotEmpty) {
      final raw = queue.removeAt(0);
      final ev = engine.viewFor(s, raw);
      curTop = engine.topNameFor(s, event: raw);
      idx++;
      final ch = ev.character == null
          ? '없음'
          : '${b.characterById[ev.character]?.name ?? ev.character}(${ev.character})';
      layerCount[ev.layer.name] = (layerCount[ev.layer.name] ?? 0) + 1;
      if (ev.character != null) {
        charDays.putIfAbsent(ev.character!, () => []).add(s.day);
      }
      o.writeln('');
      o.writeln('  --- [$idx] ${ev.id} · 층 ${ev.layer.name} · 상대 $ch · 제목 ${ev.title} ${ev.isMoment ? '· 모먼트' : ''}');
      if (ev.preview != null) o.writeln('      (알림 미리보기) ${say(ev.preview!)}');
      for (final l in ev.lines) {
        if (l.isWait) {
          o.writeln('      [읽씹 대기 ${l.wait}초]');
        } else {
          final who = switch (l.who) {
            'me' => '나',
            'narr' => '(지문)',
            'sys' => '(시스템)',
            _ => l.name ?? (ev.character == null ? '상대' : (b.characterById[ev.character]?.name ?? '상대')),
          };
          o.writeln('      $who: ${say(l.text)}');
        }
      }
      final views = engine.choicesFor(s, ev);
      final open = views.where((v) => !v.locked).toList();
      for (final v in views) {
        o.writeln('      ${v.locked ? '[잠김: ${v.reason}]' : '[ ]'} ${say(v.choice.text)}');
      }
      if (open.isEmpty) {
        o.writeln('      >>> 열린 선택지 없음(소프트락). 넘어간다.');
        s.seen.add(ev.id);
        continue;
      }
      final i = pick(s, ev, open, r);
      final c = ev.choices[i];
      bool? forced;
      if (c.minigame != null) forced = r.nextDouble() < 0.6;
      final out = engine.applyChoice(s, ev, c, forcedSuccess: forced);
      o.writeln('      >>> 선택: "${say(c.text)}"${c.minigame != null ? ' (미니게임 ${c.minigame} ${out.success ? '성공' : '실패'})' : (c.chance != null ? ' (확률 ${c.chance}% ${out.success ? '성공' : '실패'})' : '')}');
      final rep = !out.success
          ? (c.failReply.isEmpty ? c.reply : c.failReply)
          : (out.critical && c.critReply.isNotEmpty ? c.critReply : c.reply);
      for (final l in rep) {
        if (l.isWait) continue;
        final who = switch (l.who) {
          'me' => '나',
          'narr' => '(지문)',
          'sys' => '(시스템)',
          _ => l.name ?? (b.characterById[ev.character]?.name ?? '상대'),
        };
        o.writeln('      $who: ${say(l.text)}');
      }
      final d = out.delta;
      o.writeln('      [변화] 호감 ${d.affection} 신뢰 ${d.trust} 스탯 ${d.stats}${d.album == null ? '' : ' 흑역사 "${d.album}"'}${c.effects.setFlags.isEmpty ? '' : ' 플래그+${c.effects.setFlags}'}');
      if (ev.cliffhanger != null) lastCliffOfDay = ev.cliffhanger;
      final next = out.nextEventId;
      if (next != null) {
        final ne = engine.byId(next);
        if (ne != null) queue.insert(0, ne);
      }
    }
    cliff = lastCliffOfDay;
    final hint = TomorrowPeek(engine).peek(s, cliffhanger: cliff);
    o.writeln('');
    o.writeln('  [정산] 클리프행어: ${cliff == null ? '(없음)' : say(cliff)}');
    o.writeln('  [정산] 내일 예고: ${hint == null ? '(없음)' : '${b.characterById[hint.characterId]?.name}에게서 연락이 올 것 같다 [${hint.eventId}]${hint.preview == null ? '' : ' / 미리보기: ${say(hint.preview!)}'}'}');
    engine.endDay(s, cliffhanger: cliff);
  }

  o.writeln('');
  o.writeln('==== 집계 (D+1~D+$days) ====');
  o.writeln('층별 이벤트 수: $layerCount (합 ${layerCount.values.fold(0, (a, x) => a + x)})');
  final cd = charDays.entries.toList()
    ..sort((a, b2) => b2.value.length - a.value.length);
  for (final e in cd) {
    o.writeln('  ${b.characterById[e.key]?.name ?? e.key}: ${e.value.length}회 — 등장일 ${e.value.join(',')}');
  }
  o.writeln('최종 호감/신뢰: ${engine.rosterFor(s).map((c) => '${c.name} ${s.affectionOf(c.id)}/${s.trustOf(c.id)}').join(' | ')}');
  o.writeln('플래그: ${s.flags.join(' ')}');
  return o.toString();
}

double sumAff(Map<String, int> m) => m.values.fold(0.0, (a, x) => a + x);

/// 첫 플레이 초보: 호감 상승 합이 가장 큰 열린 선택지. 동점이면 첫 번째.
int naivePick(GameState s, StoryEvent ev, List<ChoiceView> open, Random r) {
  var best = open.first;
  var bestScore = double.negativeInfinity;
  for (final v in open) {
    final c = v.choice;
    final sc = sumAff(c.effects.affection) +
        0.5 * sumAff(c.effects.trust) +
        0.05 * (c.effects.stats.entries.fold(0, (a, e) => a + (e.key == Stat.stress ? -e.value : e.value)));
    if (sc > bestScore) {
      bestScore = sc;
      best = v;
    }
  }
  return best.index;
}

int randomPick(GameState s, StoryEvent ev, List<ChoiceView> open, Random r) =>
    open[r.nextInt(open.length)].index;

DayAction rotateAction(GameState s, List<DayAction> acts, Random r) {
  DayAction byId(String id) => acts.firstWhere((x) => x.id == id);
  if (s.stat(Stat.stress) >= 65) return byId('rest');
  if (s.stat(Stat.money) < 15) return byId('work');
  return byId(['read', 'style', 'friends', 'gym'][s.day % 4]);
}


/// m03(엄마의 소개팅 통보)에서 지정한 문을 고르고, 나머지는 naive 로 둔다.
/// door: 0=나간다(수락) 1=안 나가(거절) 2=나 썸 있어(거짓말)
int Function(GameState, StoryEvent, List<ChoiceView>, Random) doorPick(int door) =>
    (s, ev, open, r) {
      if (ev.id == 'm03' || ev.id == 'm03_m') {
        for (final v in open) {
          if (v.index == door) return v.index;
        }
      }
      return naivePick(s, ev, open, r);
    };

void main() {
  test('두 번째 문 전사', () {
    registerMinigames();
    final b = loadBundle();
    Directory(kOut).createSync(recursive: true);
    for (final (door, tag) in [(0, 'accept'), (1, 'refused'), (2, 'lied')]) {
      for (final pref in ['f', 'm']) {
        final t = transcript(
          b,
          7,
          pickerName: 'door=$tag(naive)',
          pick: doorPick(door),
          action: rotateAction,
          pref: pref,
        );
        final p = '$kOut/door_${tag}_$pref.txt';
        File(p).writeAsStringSync(t);
        print('wrote $p (${t.length} chars)');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
