// 리텐션 장치(docs/ROADMAP.md Phase 1)의 순수 로직: 다음 판 권하기 · 내일 예고 · 지난 판 요약.
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/mbti.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/retention.dart';
import 'package:mossol/game_controller.dart';

import 'widget/helpers.dart';

/// 하루를 끝까지 진행한다(정산 화면까지). 선택은 잠기지 않은 첫 선택지, 미니게임은 성공.
Future<void> playToSummary(GameController c) async {
  await c.startDay(c.config.actions.first);
  for (var i = 0; i < 40 && c.phase == Phase.event; i++) {
    final open = c.choices.where((v) => !v.locked).toList();
    if (open.isNotEmpty) c.choose(open.first.index, minigameSuccess: true);
    c.continueAfterChoice();
  }
  expect(c.phase, Phase.summary);
}

void main() {
  final bundle = testBundle();
  final advisor = NextRunAdvisor(bundle);

  group('다음 판 권하기', () {
    test('MBTI 가 있으면 같은 쪽에서 궁합이 가장 좋은 캐릭터를 권한다', () {
      // INFP: S/N 같고(N) E/I·J/P 다른 ENFJ/ENTJ 류가 4점. 여성 쪽 ENTJ(지우)가 천생연분.
      const mbti = 'INFP';
      final r = advisor.suggest(
        side: Preference.female,
        album: const [],
        playerMbti: mbti,
      );
      final ch = r.character!;
      expect(ch.gender, Preference.female);
      expect(ch.hidden, isFalse);
      final best = bundle
          .charactersFor(Preference.female)
          .where((c) => !c.hidden)
          .map((c) => Mbti.compat(mbti, c.mbti))
          .reduce((a, b) => a > b ? a : b);
      expect(r.compat, best);
      expect(Mbti.compat(mbti, ch.mbti), best);
      if (best == 4) expect(r.reason, NextRunAdvisor.destinyLine);
      if (best == 3) expect(r.reason, NextRunAdvisor.goodMatchLine);
    });

    test('방금 끝낸 캐릭터는 다른 후보가 있으면 권하지 않는다', () {
      final first = advisor.suggest(
        side: Preference.female,
        album: const [],
        playerMbti: 'INFP',
      );
      final ended = bundle.endings.firstWhere(
        (e) => e.character == first.character!.id && e.tier == 'happy',
      );
      final r = advisor.suggest(
        side: Preference.female,
        album: [ended.id],
        playerMbti: 'INFP',
        justEnded: ended,
      );
      expect(r.character!.id, isNot(first.character!.id));
    });

    test('모든 엔딩을 본 캐릭터보다 못 본 엔딩이 남은 캐릭터를 권한다', () {
      final side = bundle
          .charactersFor(Preference.male)
          .where((c) => !c.hidden)
          .toList();
      // 첫 사람을 빼고 전원의 엔딩을 다 봤다 → 첫 사람만 못 본 엔딩이 남는다.
      final album = [
        for (final e in bundle.endings)
          if (e.character != null && e.character != side.first.id) e.id,
      ];
      final r = advisor.suggest(
        side: Preference.male,
        album: album,
        playerMbti: 'ESTJ',
      );
      expect(r.character!.id, side.first.id);
    });

    test('MBTI 가 없으면 엔딩을 가장 적게 본 사람 + 중립 문장', () {
      final side = bundle
          .charactersFor(Preference.female)
          .where((c) => !c.hidden)
          .toList();
      // 첫 사람은 하나 봤고 나머지는 0 → 두 번째 사람(characters.json 순)을 권한다.
      final seenOne = bundle.endings.firstWhere(
        (e) => e.character == side.first.id,
      );
      final r = advisor.suggest(
        side: Preference.female,
        album: [seenOne.id],
        playerMbti: null,
      );
      expect(r.compat, isNull);
      expect(r.character!.id, side[1].id);
      expect(r.reason, NextRunAdvisor.neverLine);
    });

    test('힌트는 못 본 엔딩이고 배드·히든·기본이 아니다', () {
      final r = advisor.suggest(
        side: Preference.female,
        album: const [],
        playerMbti: 'INFP',
      );
      final h = r.hintEnding!;
      expect(h.tier, isNot(anyOf('bad', 'hidden')));
      expect(h.isDefault, isFalse);
      expect(h.character, r.character!.id);
      // 천생연분 궁합이면 천생연분 엔딩을 먼저 권한다.
      if (r.compat == 4) expect(h.id, endsWith('_destiny'));
    });

    test('한쪽만 해 봤으면 반대쪽을 권하고, 두 쪽을 다 봤으면 안 권한다', () {
      final f = bundle.endings.firstWhere(
        (e) => bundle.endingSide(e) == Preference.female && e.character != null,
      );
      final m = bundle.endings.firstWhere(
        (e) => bundle.endingSide(e) == Preference.male && e.character != null,
      );
      expect(
        advisor
            .suggest(side: Preference.female, album: [f.id], playerMbti: null)
            .otherSide,
        Preference.male,
      );
      expect(
        advisor
            .suggest(
              side: Preference.female,
              album: [f.id, m.id],
              playerMbti: null,
            )
            .otherSide,
        isNull,
      );
      expect(
        advisor
            .suggest(side: Preference.all, album: const [], playerMbti: null)
            .otherSide,
        isNull,
      );
    });

    test('히든 캐릭터는 권하지 않는다', () {
      for (final mbti in Mbti.playerCases) {
        for (final side in Preference.genders) {
          final r = advisor.suggest(
            side: side,
            album: const [],
            playerMbti: mbti,
          );
          expect(r.character!.hidden, isFalse, reason: '$mbti/$side');
        }
      }
    });
  });

  group('내일 예고', () {
    test('미리 봐도 상태가 바뀌지 않고 진짜 내일 계획과 같다', () {
      final engine = EventEngine(bundle);
      final peek = TomorrowPeek(engine);
      for (final seed in [1, 7, 42, 99, 2026]) {
        for (final day in [1, 4, 12, 30]) {
          final s = GameState.fresh(
            bundle.config,
            bundle.characters,
            seed: seed,
            preference: Preference.female,
          )..day = day;
          s.relations['seoyeon']!.affection = 20;
          final before = s.toJson().toString();
          final a = peek.peek(s, cliffhanger: '예고');
          final b = peek.peek(s, cliffhanger: '예고');
          expect(s.toJson().toString(), before, reason: '상태가 바뀌었다');
          expect(a?.eventId, b?.eventId, reason: '같은 입력이면 같은 결과');

          // 진짜로 하루를 닫고 계획한다(아침 행동 없이 — 엔진 계획만 비교).
          final twin = GameState.fromJson(s.toJson());
          engine.endDay(twin, cliffhanger: '예고');
          final plan = engine.planDay(twin);
          if (a != null) {
            expect(
              plan.map((e) => e.id),
              contains(a.eventId),
              reason: 'seed $seed day $day',
            );
          }
          // 미리 본 쪽과 안 본 쪽의 진짜 계획이 같다.
          final fresh = GameState.fromJson(s.toJson());
          engine.endDay(fresh, cliffhanger: '예고');
          expect(
            engine.planDay(fresh).map((e) => e.id).toList(),
            plan.map((e) => e.id).toList(),
          );
        }
      }
    });

    test('컨트롤러: 정산에서 예고를 봐도 다음 날 계획이 같다', () async {
      Future<(TomorrowHint?, List<String>)> run({required bool peek}) async {
        final c = await makeController();
        await c.newGame(seed: 314, preference: Preference.female);
        c.state!.rouletteDay = c.state!.day;
        await playToSummary(c);
        final hint = peek ? c.tomorrowHint : null;
        await c.endDay();
        c.state!.rouletteDay = c.state!.day;
        await c.startDay(c.config.actions.first);
        return (hint, [?c.current?.id, ...c.queuedEventIds]);
      }

      final (hint, withPeek) = await run(peek: true);
      final (_, withoutPeek) = await run(peek: false);
      expect(withPeek, withoutPeek);
      if (hint != null) {
        expect(c2names(hint), isNotEmpty);
      }
    });

    test('선호 밖 · 아직 모르는 히든 캐릭터는 이름을 대지 않는다', () {
      final engine = EventEngine(bundle);
      final peek = TomorrowPeek(engine);
      for (final pref in Preference.genders) {
        for (var seed = 0; seed < 40; seed++) {
          for (final day in [3, 15, 40]) {
            final s = GameState.fresh(
              bundle.config,
              bundle.characters,
              seed: seed,
              preference: pref,
            )..day = day;
            final h = peek.peek(s);
            if (h == null) continue;
            final ch = bundle.characterById[h.characterId]!;
            expect(ch.gender, pref);
            expect(ch.hidden, isFalse, reason: '호감 0 인 히든: ${ch.id}');
          }
        }
      }
    });

    test('마지막 날에는 예고가 없다', () {
      final s = GameState.fresh(bundle.config, bundle.characters, seed: 3)
        ..day = bundle.config.totalDays;
      expect(TomorrowPeek(EventEngine(bundle)).peek(s), isNull);
    });

    test('문장', () {
      expect(TomorrowPeek.lineFor('서연'), '내일 서연에게서 연락이 올 것 같다');
    });
  });

  group('지난 판 요약', () {
    test('캐릭터 엔딩은 이름 머리를 떼고 조사를 맞춘다', () {
      expect(
        previousRunLineFor(bundle, 'seoyeon_happy'),
        '지난 판엔 서연과 대등한 연인으로 끝났다',
      );
      expect(
        previousRunLineFor(bundle, 'jiwoo_happy'),
        '지난 판엔 지우와 첫인상 뒤집기로 끝났다',
      );
      // 긴 부제(— 이후)는 뺀다.
      expect(
        previousRunLineFor(bundle, 'seoyeon_destiny'),
        '지난 판엔 서연과 천생연분으로 끝났다',
      );
    });

    test('공용 엔딩 · 모르는 id', () {
      expect(previousRunLineFor(bundle, 'burnout'), '지난 판은 번아웃으로 끝났다');
      expect(previousRunLineFor(bundle, 'nope'), isNull);
      expect(previousRunLineFor(bundle, null), isNull);
    });

    test('컨트롤러: 엔딩 뒤 메타에 남고 다시 켜도 읽힌다', () async {
      final c = await makeController();
      await c.newGame(seed: 1);
      expect(c.previousRunLine, isNull);
      c.state!.day = c.config.totalDays;
      await playToSummary(c);
      await c.endDay();
      expect(c.phase, Phase.ending);
      final id = c.ending!.id;
      expect(c.meta!.lastEndingId, id);
      expect(c.previousRunLine, previousRunLineFor(bundle, id));

      // 같은 저장소로 새 컨트롤러 → 메타에서 그대로.
      final again = GameController(bundle: bundle, save: c.save);
      await again.init();
      expect(again.meta!.lastEndingId, id);
    });
  });
}

/// 예고가 가리키는 캐릭터 이름(테스트용).
String c2names(TomorrowHint h) =>
    testBundle().characterById[h.characterId]!.name;
