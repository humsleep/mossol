// 개편 2 · 1라운드 회귀 시뮬레이션(docs/overhaul2/review/r1_scripts 정식화).
//
// - zz_r1_sim_test: 시작 × 선호 × D1 갈래 × 미니게임 성패, D1~10 결정적 전수. 100일 무작위(시작마다 시드 10).
// - zz_r1_resume_test: 하루 도중(선택 전·후) 앱을 끄고 다시 켜도 화면·플래그·소문·큐가 같다.
// - zz_r1_legacy_test: 예전 세이브(선호 없음/f/m, heat 키 없음)가 클래식으로 100일까지 간다(시드 5).
// - zz_r1_template_test: 새 줄 전부를 f/m × 이름 4종으로 치환해도 깨지지 않는다.
//
// 대본이 같이 바뀌는 중이라 실제 데이터를 쓴다. 실패 메시지에 시작·선호·시드·날짜가 찍힌다.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/save_service.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/engine/text_template.dart';
import 'package:mossol/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'story_files.dart';
import 'widget/helpers.dart';

class _Report {
  final problems = <String>[];
  void add(String s) {
    if (problems.length < 200) problems.add(s);
  }
}

Future<GameController> _fresh(StoryBundle b) async {
  SharedPreferences.setMockInitialValues({});
  final c = GameController(bundle: b, save: SaveService());
  await c.init();
  await c.markIntroSeen();
  return c;
}

/// [days] 일을 돈다. [pick] 은 잠기지 않은 선택지 번호 중 하나를 고른다.
Future<void> _play(
  GameController c,
  _Report r,
  String tag,
  int days, {
  required int Function(GameController c, List<int> open) pick,
  required DayAction Function(GameController c) action,
  bool Function()? minigameOk,
}) async {
  final b = c.bundle;
  var bets = 0;
  for (var d = 0; d < days; d++) {
    if (c.ending != null) return;
    final s = c.state!;
    final day = s.day;
    c.beginMorning();
    s.hearts = b.config.maxHearts;
    if (!await c.startDay(action(c))) {
      r.add('$tag D$day startDay false');
      return;
    }
    if (c.current == null) r.add('$tag D$day 빈 하루');
    final shown = <String>[];
    var guard = 0;
    while (c.phase == Phase.event && c.current != null) {
      if (guard++ > 40) {
        r.add('$tag D$day 이벤트 40개 넘음(고리?) ${shown.join(",")}');
        return;
      }
      final ev = c.current!;
      if (shown.contains(ev.id)) r.add('$tag D$day 같은 날 두 번 ${ev.id}');
      shown.add(ev.id);
      if (ev.id == 'd_open_bet') bets++;
      if (ev.lines.where((l) => !l.isWait).isEmpty) {
        r.add('$tag D$day ${ev.id} 대사 0줄');
      }
      if (c.choices.isEmpty) r.add('$tag D$day ${ev.id} 선택지 0개');
      final open = [
        for (final v in c.choices)
          if (!v.locked) v.index,
      ];
      if (open.isEmpty) {
        r.add('$tag D$day ${ev.id} 선택지가 전부 잠김');
        return;
      }
      for (final l in ev.lines) {
        final t = c.say(l.text);
        if (RegExp(r'\{[a-z]').hasMatch(t)) r.add('$tag ${ev.id} 치환 안 됨: $t');
      }
      final i = pick(c, open);
      final mg = ev.choices[i].minigame != null;
      c.choose(i, minigameSuccess: mg ? minigameOk?.call() : null);
      final nx = c.lastOutcome?.nextEventId;
      if (nx != null && b.eventById[nx] == null) r.add('$tag ${ev.id} 없는 next $nx');
      c.continueAfterChoice();
    }
    if (c.phase != Phase.summary) {
      r.add('$tag D$day 이벤트 뒤 phase ${c.phase}');
      return;
    }
    final heat = c.state!.stat(Stat.heat);
    final villain = c.state!.stat(Stat.villain);
    if (heat < 0 || heat > 100) r.add('$tag D$day 소문 범위 밖 $heat');
    if (villain < 0 || villain > Stat.villainMax) r.add('$tag D$day 진상 범위 밖 $villain');
    await c.endDay();
  }
  if (days >= 10 && c.engine.startIdOf(c.state!) == StartScenario.classic) {
    // 클래식만 치킨 내기를 정확히 한 번 본다(신규 시작은 대본이 정한다).
    if (bets != 1) r.add('$tag 치킨 내기 $bets번');
  }
}

String _viewSig(GameController c) {
  final e = c.current;
  if (e == null) return 'null';
  return jsonEncode({
    'id': e.id,
    'lines': [for (final l in e.lines) c.say(l.text)],
    'choices': [
      for (final v in c.choices) '${v.index}:${v.locked}:${c.say(v.choice.text)}',
    ],
    'replies': [
      for (final ch in e.choices) [for (final l in ch.reply) l.text],
    ],
  });
}

void main() {
  late StoryBundle b;
  setUpAll(() => b = testBundle());

  test('D1~10 결정적: 시작 × 선호 × D1 갈래 × 미니게임 성패', () async {
    final r = _Report();
    for (final st in b.starts) {
      for (final pref in Preference.genders) {
        for (var branch = 0; branch < 4; branch++) {
          for (final mg in [true, false]) {
            final c = await _fresh(b);
            await c.newGame(preference: pref, seed: 7 + branch, start: st.id);
            await _play(
              c,
              r,
              '${st.id}/$pref/b$branch/mg$mg',
              10,
              minigameOk: () => mg,
              action: (c) => b.config.actions[c.state!.day % b.config.actions.length],
              pick: (c, open) =>
                  c.state!.day == 1 && c.current!.layer == EventLayer.main
                  ? open[min(branch, open.length - 1)]
                  : open.first,
            );
          }
        }
      }
    }
    expect(r.problems.toSet(), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('100일 무작위: 시작마다 시드 10, 모든 판이 엔딩에 닿는다', () async {
    final r = _Report();
    for (final st in b.starts) {
      for (var seed = 0; seed < 10; seed++) {
        final rnd = Random(seed * 31 + st.id.length * 7);
        final c = await _fresh(b);
        final pref = Preference.genders[seed % 2];
        await c.newGame(preference: pref, seed: seed, start: st.id);
        final tag = '${st.id}/$pref/s$seed';
        await _play(
          c,
          r,
          tag,
          120,
          minigameOk: rnd.nextBool,
          action: (c) => b.config.actions[rnd.nextInt(b.config.actions.length)],
          pick: (c, open) => open[rnd.nextInt(open.length)],
        );
        if (c.ending == null) r.add('$tag 엔딩 없음 D${c.state!.day}');
      }
    }
    expect(r.problems.toSet(), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 15)));

  test('하루 도중 저장·복원: 시작마다 선택 전·후로 끄고 켜도 같다', () async {
    final problems = <String>[];
    Future<GameController> reload() async {
      final c2 = GameController(bundle: b, save: SaveService());
      await c2.init();
      expect(await c2.continueGame(), isTrue);
      return c2;
    }

    for (final st in b.starts) {
      for (final pref in Preference.genders) {
        for (var seed = 0; seed < 3; seed++) {
          var c = await _fresh(b);
          await c.newGame(preference: pref, seed: seed, start: st.id);
          final rnd = Random(seed);
          final killDay = 1 + rnd.nextInt(4);
          for (var d = 0; d < 5; d++) {
            final day = c.state!.day;
            c.beginMorning();
            c.state!.hearts = b.config.maxHearts;
            await c.startDay(b.config.actions[rnd.nextInt(b.config.actions.length)]);
            var k = 0;
            while (c.phase == Phase.event && c.current != null) {
              final tag = '${st.id}/$pref/s$seed D$day #$k';
              final kill = day == killDay && k <= 2;
              if (kill) {
                final sig = _viewSig(c);
                final flags = Set.of(c.state!.flags);
                final heat = c.state!.stat(Stat.heat);
                final queue = c.queuedEventIds.join(',');
                final c2 = await reload();
                if (sig != _viewSig(c2)) problems.add('$tag 선택 전 화면 다름');
                if (flags.length != c2.state!.flags.length ||
                    !flags.containsAll(c2.state!.flags)) {
                  problems.add('$tag 플래그 다름');
                }
                if (heat != c2.state!.stat(Stat.heat)) problems.add('$tag 소문 다름');
                if (queue != c2.queuedEventIds.join(',')) problems.add('$tag 큐 다름');
                c = c2;
              }
              final open = [
                for (final v in c.choices)
                  if (!v.locked) v.index,
              ];
              final i = open[rnd.nextInt(open.length)];
              final mg = c.current!.choices[i].minigame != null;
              c.choose(i, minigameSuccess: mg ? rnd.nextBool() : null);
              await Future<void>.delayed(Duration.zero);
              if (kill) {
                final stats = jsonEncode(c.state!.stats);
                final queue = c.queuedEventIds;
                final c2 = await reload();
                if (stats != jsonEncode(c2.state!.stats)) problems.add('$tag 선택 후 스탯 다름');
                final expectNext = queue.isEmpty ? null : queue.first;
                if (c2.current?.id != expectNext) {
                  problems.add('$tag 선택 후 복원 ${c2.current?.id} (기대 $expectNext)');
                }
                c = c2;
                k++;
                continue;
              }
              k++;
              c.continueAfterChoice();
            }
            if (c.phase == Phase.summary) await c.endDay();
          }
        }
      }
    }
    expect(problems.toSet(), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('예전 세이브(heat 키 없음)는 클래식으로 이어 가고 새 시작 장면이 새지 않는다', () async {
    final startIds = {
      for (final e in jsonDecode(readStoryFile('events_start.json')) as List)
        (e as Map)['id'] as String,
    };
    final problems = <String>[];
    for (final pref in ['none', 'f', 'm']) {
      for (var seed = 0; seed < 5; seed++) {
        for (final startDay in [2, 50]) {
          final s = GameState.fresh(b.config, b.characters, seed: seed, nowMs: 0)..day = startDay;
          if (startDay == 2) s.seen.addAll(['m01', 'd_open_bet', 'd_open_bet_2']);
          final j = s.toJson();
          for (final k in const [
            'preference',
            'mbti',
            'lastMomentDay',
            'signalHistory',
            'signalPins',
            'overnightShifts',
            'dayDelta',
            'rouletteDay',
            'combo',
            'lastCliffhanger',
            'seenCount',
          ]) {
            j.remove(k);
          }
          (j['stats'] as Map)
            ..remove(Stat.heat)
            ..remove(Stat.villain);
          if (pref != 'none') j['preference'] = pref;
          SharedPreferences.setMockInitialValues({'mossol_save_v1': jsonEncode(j)});
          final c = GameController(bundle: b, save: SaveService());
          await c.init();
          await c.markIntroSeen();
          expect(await c.continueGame(), isTrue);
          final rnd = Random(seed);
          var bets = 0;
          for (var d = 0; d < 110 && c.ending == null; d++) {
            final day = c.state!.day;
            c.beginMorning();
            c.state!.hearts = b.config.maxHearts;
            await c.startDay(b.config.actions[rnd.nextInt(b.config.actions.length)]);
            while (c.phase == Phase.event && c.current != null) {
              final ev = c.current!;
              final tag = '$pref/s$seed/$startDay D$day';
              // events_start.json 의 장면 중 시작 플래그를 읽는 것만(공용 장면 m36_answer 같은 것은 빼고).
              final startOnly = ev.trigger.flags.any(
                (f) => f == StartScenario.altFlag || f.startsWith(StartScenario.idPrefix),
              );
              if (startIds.contains(ev.id) && startOnly) {
                problems.add('$tag 새 시작 장면 ${ev.id}');
              }
              if (ev.id == 'd_open_bet') bets++;
              for (final l in ev.lines) {
                if (l.ifFlags.any((f) => f.startsWith('sc_') || f == StartScenario.altFlag)) {
                  problems.add('$tag ${ev.id} 새 시작 줄');
                }
              }
              final open = [
                for (final v in c.choices)
                  if (!v.locked) v.index,
              ];
              final i = open[rnd.nextInt(open.length)];
              c.choose(i, minigameSuccess: ev.choices[i].minigame != null ? rnd.nextBool() : null);
              c.continueAfterChoice();
            }
            if (c.phase == Phase.summary) await c.endDay();
          }
          if (c.ending == null) problems.add('$pref/s$seed/$startDay 엔딩 없음');
          if (bets > 0) problems.add('$pref/s$seed/$startDay 치킨 내기 다시 나옴 $bets');
        }
      }
    }
    expect(problems.toSet(), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('새 줄 전부: f/m × 이름 4종 치환이 깨지지 않는다', () {
    final newIds = <String>{
      ...overhaul2FileEventIds(),
      for (final e in b.events)
        if (e.id.startsWith(overhaul2HustlePrefix)) e.id,
    };
    final problems = <String>{};
    for (final e in b.events) {
      final isNew = newIds.contains(e.id);
      final texts = <String>[
        for (final l in e.lines)
          if (isNew || l.isFlagGated) l.text,
        for (final v in e.variants)
          for (final l in v)
            if (isNew || l.isFlagGated) l.text,
        for (final c in e.choices) ...[
          if (isNew || c.isFlagGated) c.text,
          for (final l in [...c.reply, ...c.failReply, ...c.critReply])
            if (isNew || l.isFlagGated) l.text,
        ],
      ];
      for (final pref in Preference.genders) {
        if (e.trigger.pref != null && e.trigger.pref != pref) continue;
        if (e.character != null && b.absentIds(pref).contains(e.character)) continue;
        final chars = b.charNamesFor(pref);
        for (final name in ['민석', '민지', 'Jin', null]) {
          for (final t in texts.where((t) => t.trim().isNotEmpty)) {
            final out = TextTemplate.fill(
              t,
              name: name,
              mbti: null,
              top: name == null ? null : '다은',
              chars: chars,
            );
            if (out.contains('{') || out.contains('}')) problems.add('${e.id}/$pref 치환 안 됨: $out');
            if (out.contains('  ') || out.trim().isEmpty) problems.add('${e.id}/$pref 빈칸: "$out"');
            if (t.contains('{char:') && out.contains(TextTemplate.topFallback)) {
              problems.add('${e.id}/$pref {char:} 가 "그 사람" 으로: $out');
            }
          }
        }
      }
    }
    expect(problems, isEmpty);
  });
}
