// 제한형 자유 입력 매처(lib/engine/free_input.dart). docs/overhaul/07_free_input.md §1.7 의 기준:
// 픽스처 top-1 ≥ 88%, top-2 = 100%, 오확정(자동 확정인데 틀림) 0. 전 이벤트 자기 회수 100%(§2-4).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/free_input.dart';
import 'package:mossol/engine/free_input_lexicon.dart';
import 'package:mossol/engine/models.dart';

import 'widget/helpers.dart';

/// 픽스처 한 줄의 결과.
class _Case {
  final String ev;
  final int expected;
  final String input;
  final MatchResult r;
  _Case(this.ev, this.expected, this.input, this.r);

  bool get top1 => r.top?.index == expected;
  bool get top2 => r.topIndices(2).contains(expected);
  bool get wrongAuto => r.decision == MatchDecision.auto && !top1;

  @override
  String toString() =>
      '$ev[$expected] "$input" → ${r.topIndices(3)} ${r.decision.name} '
      's1=${r.s1.toStringAsFixed(2)} Δ=${r.margin.toStringAsFixed(2)}';
}

void main() {
  final bundle = testBundle();
  final engine = EventEngine(bundle);
  final state = freshState();

  /// 보이는 선택지(MBTI 없음). 통화면 decline 을 뺀다.
  List<ChoiceView> visibleOf(StoryEvent ev) => [
    for (final v in engine.choicesFor(state, ev))
      if (!(ev.isCall && v.choice.decline)) v,
  ];

  group('픽스처 (test/fixtures/free_input.json)', () {
    final fx = jsonDecode(File('test/fixtures/free_input.json').readAsStringSync()) as Map;
    final cases = <_Case>[];
    for (final e in fx['events'] as List) {
      final id = e['id'] as String;
      // group 본문에서는 expect 를 못 쓴다 — 없으면 여기서 바로 던진다.
      final ev = bundle.eventById[id] ?? (throw StateError('픽스처 이벤트 없음: $id'));
      final visible = visibleOf(ev);
      final m = FreeInputMatcher();
      for (final c in e['cases'] as List) {
        final idx = (c['choice'] as num).toInt();
        if (!visible.any((v) => v.index == idx)) throw StateError('$id 선택지 $idx 안 보임');
        for (final s in c['inputs'] as List) {
          cases.add(_Case(id, idx, s as String, m.match(s, visible, inCall: ev.isCall)));
        }
      }
    }

    test('이벤트 15 × 선택지당 예문 3', () {
      expect((fx['events'] as List).length, 15);
      for (final e in fx['events'] as List) {
        for (final c in e['cases'] as List) {
          expect((c['inputs'] as List).length, 3, reason: '${e['id']}[${c['choice']}]');
        }
      }
    });

    test('top-1 ≥ 88% · top-2 = 100% · 오확정 0', () {
      final n = cases.length;
      final top1 = cases.where((c) => c.top1).length;
      final top2 = cases.where((c) => c.top2).length;
      final wrong = cases.where((c) => c.wrongAuto).toList();
      final auto = cases.where((c) => c.r.decision == MatchDecision.auto).length;
      final confirm = cases.where((c) => c.r.decision == MatchDecision.confirm).length;
      final locked = cases.where((c) => c.r.decision == MatchDecision.locked).length;
      // 튜닝할 때 보는 요약. 실패 줄만 찍는다.
      // ignore: avoid_print
      print(
        'free_input fixture: n=$n top1=${(100 * top1 / n).toStringAsFixed(1)}% '
        'top2=${(100 * top2 / n).toStringAsFixed(1)}% auto=$auto confirm=$confirm '
        'locked=$locked wrongAuto=${wrong.length}',
      );
      for (final c in cases.where((c) => !c.top1)) {
        // ignore: avoid_print
        print('  miss: $c');
      }
      expect(top1 / n, greaterThanOrEqualTo(0.88), reason: 'top-1');
      expect(top2, n, reason: 'top-2 = 100%');
      expect(wrong, isEmpty, reason: '오확정: $wrong');
    });

    test('동점(차 < 0.02)이면 항상 피커', () {
      for (final c in cases) {
        if (c.r.ranked.length >= 2 && c.r.margin < FreeInputThresholds.tie && !c.r.top!.exact) {
          expect(c.r.decision, MatchDecision.pick, reason: '$c');
        }
      }
    });

    test('자동 확정 조건: s1 ≥ 0.38 · Δ ≥ 0.12 · 1위가 일반 선택지', () {
      for (final c in cases) {
        final r = c.r;
        if (r.decision == MatchDecision.auto) {
          expect(r.s1, greaterThanOrEqualTo(FreeInputThresholds.autoMin), reason: '$c');
          expect(r.margin, greaterThanOrEqualTo(FreeInputThresholds.autoMargin), reason: '$c');
          final ch = r.top!.view;
          expect(ch.locked, isFalse);
          expect(ch.choice.chance, isNull);
          expect(ch.choice.minigame, isNull);
        }
        if (r.decision == MatchDecision.confirm) {
          expect(r.top!.view.choice.chance != null || r.top!.view.choice.minigame != null, isTrue);
        }
        if (r.decision == MatchDecision.locked) expect(r.top!.view.locked, isTrue);
      }
    });
  });

  group('자기 회수 (전 이벤트)', () {
    test('선택지 문구를 그대로 치면 1위는 자기 자신(같은 문구면 동급)', () {
      final fails = <String>[];
      var n = 0;
      for (final ev in bundle.events) {
        final visible = visibleOf(ev);
        if (visible.length < 2) continue;
        final m = FreeInputMatcher();
        for (final v in visible) {
          n++;
          final text = v.choice.text;
          final r = m.match(text, visible, inCall: ev.isCall);
          final top = r.top;
          if (top == null) {
            fails.add('${ev.id}[${v.index}] "$text" → 후보 없음(${r.decision.name})');
            continue;
          }
          final same = top.index == v.index || norm(top.view.choice.text).body == norm(text).body;
          if (!same) fails.add('${ev.id}[${v.index}] "$text" → ${r.topIndices(2)}');
        }
      }
      // ignore: avoid_print
      print('free_input self-recall: n=$n fails=${fails.length}');
      expect(fails, isEmpty, reason: fails.take(20).join('\n'));
    });
  });

  group('norm · 특징', () {
    test('반복 압축 · 소문자 · 본문(자모·문장부호 제외)', () {
      final n = norm('  ㅋㅋㅋㅋ 진짜?? Hello!!! 뭐야…… ');
      expect(n.raw, 'ㅋㅋ 진짜?? hello!! 뭐야…');
      expect(n.compact, 'ㅋㅋ진짜hello뭐야');
      expect(n.body, '진짜hello뭐야');
      expect(n.tokens, ['ㅋㅋ', '진짜', 'hello', '뭐야']);
      expect(norm('ㅠㅠㅠㅠ').body, isEmpty);
      expect(norm('ㅠㅠㅠㅠ').isEmpty, isFalse);
      expect(norm('   ').isEmpty, isTrue);
      expect(norm('😂😂').isEmpty, isTrue);
    });

    test('조합형 자모는 음절로 합친다', () {
      expect(composeHangul('한'), '한');
      expect(norm('한글').body, '한글');
    });

    test('2-gram · dice · jaccard', () {
      expect(bigrams('하나만'), {'하나', '나만'});
      expect(bigrams('응'), isEmpty);
      expect(dice({'a', 'b'}, {'b', 'c'}), closeTo(0.5, 1e-9));
      expect(dice({}, {'a'}), 0);
      expect(jaccard({'a', 'b'}, {'b', 'c'}), closeTo(1 / 3, 1e-9));
      expect(jaccard({}, {}), 0);
    });

    test('polite · question · lenBucket · action · emo', () {
      InputFeatures f(String s) => InputFeatures.from(s);
      expect(f('제가 데려다 드릴게요').polite, 1);
      expect(f('선배님 저 왔어요').polite, 1);
      expect(f('그냥 바로 답장할래').polite, -1);
      expect(f('규칙대로 계속한다').polite, -1);
      expect(f('침대 ㅋㅋ').polite, 0);
      expect(f('프사 왜 바꿨어?').question, isTrue);
      expect(f('게임이나 켤까').question, isTrue);
      expect(f('누구시죠').question, isTrue);
      expect(f('다시 찍자').question, isFalse);
      expect(f('응').lenBucket, 0);
      expect(f('그냥 물어볼래').lenBucket, 1);
      expect(f('공지 봤어요 궁금한 거 있으면 여쭤볼게요').lenBucket, 2);
      expect(f('(조용히 캡처하고 모른 척한다)').action, isTrue);
      expect(f('규칙대로 계속한다').action, isTrue);
      expect(f('카운터에 종이 붙임').action, isTrue);
      expect(f('먼저 가세요').action, isFalse);
      expect(f('헐 ㅋㅋ ㅠㅠ 최고!! 음… ♥').emo, {'joke', 'sad', 'excited', 'hesitant', 'love'});
    });

    test('태그: 부분 문자열 · 낱말 일치(^) · 질문 조건(?)', () {
      Set<String> t(String s) => InputFeatures.from(s).tags;
      expect(t('그냥 싫어'), contains(Intent.refuse));
      expect(t('응 그래'), contains(Intent.agree));
      // '어' 는 낱말일 때만 agree — '어디' 는 아니다.
      expect(t('어디야'), isNot(contains(Intent.agree)));
      expect(t('어디야'), contains(Intent.ask));
      expect(t('괜찮아?'), contains(Intent.care));
      expect(t('괜찮아요'), contains(Intent.refuse));
      expect(t('괜찮아요'), isNot(contains(Intent.care)));
      expect(t('미안 나중에'), containsAll([Intent.sorry, Intent.delay]));
      expect(t('내가 먼저 말할게'), containsAll([Intent.assert_, Intent.honest]));
      expect(t('모른 척한다'), contains(Intent.passive));
      expect(t('뭐야?'), contains(Intent.ask));
    });

    test('효과 유도 태그', () {
      final tags = ChoiceSignature.tagsFromEffects(
        const Effects(stats: {Stat.sincerity: 2, Stat.esteem: 1, Stat.money: -5}, affection: {'a': -1}),
      );
      expect(tags, {Intent.honest, Intent.assert_, Intent.love, Intent.refuse, Intent.passive});
      expect(ChoiceSignature.tagsFromEffects(Effects.none, decline: true), {Intent.refuse});
      expect(
        ChoiceSignature.tagsFromEffects(const Effects(setFlags: ['seoyeon_dm_first'])),
        {Intent.love},
      );
    });

    test('마지막 문장만 매칭(두 문장 이상)', () {
      expect(InputFeatures.lastSentence('아 몰라. 그냥 규칙대로 해'), '그냥 규칙대로 해');
      expect(InputFeatures.lastSentence('그냥 규칙대로 해 ㅋㅋ'), '그냥 규칙대로 해 ㅋㅋ');
      // 마지막 조각이 짧으면 전체.
      expect(InputFeatures.lastSentence('규칙대로 계속할게. 응.'), '규칙대로 계속할게. 응.');
    });
  });

  group('극성 벌점 · 결정', () {
    final ev = StoryEvent.fromJson({
      'id': 't_pol',
      'layer': 'daily',
      'title': 't',
      'choices': [
        {'text': '좋아 가자', 'reply': 'ㅇㅋ'},
        {'text': '오늘은 안 갈래', 'reply': '아쉽다'},
        {'text': '생각해 볼게', 'reply': '응'},
      ],
    });
    final visible = engine.choicesFor(state, ev);
    final m = FreeInputMatcher();

    test('refuse 입력은 agree 후보에 −0.25', () {
      final i = InputFeatures.from('싫어 안 가');
      final agree = ChoiceSignature.build(ev.choices[0]);
      final refuse = ChoiceSignature.build(ev.choices[1]);
      expect(i.tags, contains(Intent.refuse));
      expect(agree.tags, contains(Intent.agree));
      expect(FreeInputMatcher.score(i, agree), lessThan(0));
      expect(FreeInputMatcher.score(i, refuse), greaterThan(FreeInputMatcher.score(i, agree)));
      expect(m.match('싫어 안 가', visible).top!.index, 1);
    });

    test('정확히 같은 문구는 항상 auto(exact)', () {
      final r = m.match('생각해 볼게', visible);
      expect(r.top!.exact, isTrue);
      expect(r.decision, MatchDecision.auto);
    });

    test('빈 입력·이모지·자음만 → empty/pick, 금칙어 → blocked, 되돌리기 뒤 → pick', () {
      expect(m.match('', visible).decision, MatchDecision.empty);
      expect(m.match('😂', visible).decision, MatchDecision.empty);
      expect(m.match('??', visible).decision, MatchDecision.empty);
      // 자음만·한 글자는 본문 2-gram 이 없다 → 억지 확정 없이 피커(강조 없음, 07 §4 #3).
      final jamo = m.match('ㅋㅋㅋ', visible);
      expect(jamo.decision, MatchDecision.pick);
      expect(jamo.weak, isTrue);
      expect(m.match('응', visible).decision, MatchDecision.pick);
      final b = m.match('시발 가자', visible);
      expect(b.decision, MatchDecision.blocked);
      expect(b.ranked, isEmpty);
      expect(m.match('생각해 볼게', visible, forcePick: true).decision, MatchDecision.pick);
    });

    test('80자 초과는 자른다', () {
      final long = '가' * 100;
      expect(m.match(long, visible).text.length, FreeInputThresholds.maxChars);
    });

    test('통화 중 "끊을게" → hangUp, decline 은 후보에서 빠진다', () {
      final call = StoryEvent.fromJson({
        'id': 't_call',
        'layer': 'daily',
        'format': 'call',
        'title': 't',
        'choices': [
          {'text': '거절', 'decline': true, 'reply': '…'},
          {'text': '응 뭐해', 'reply': '그냥'},
          {'text': '지금 바빠', 'reply': '아'},
        ],
      });
      final vis = engine.choicesFor(state, call);
      expect(m.match('나 이제 끊을게', vis, inCall: true).decision, MatchDecision.hangUp);
      final r = m.match('지금 바빠', vis, inCall: true);
      expect(r.ranked.map((s) => s.index), isNot(contains(0)));
      expect(r.top!.index, 2);
    });

    test('intent 필드는 문구 2-gram·태그에 합쳐진다', () {
      final plain = Choice.fromJson({'text': '하나만'});
      final tuned = Choice.fromJson({
        'text': '하나만',
        'intent': ['하트 하나', '적당히'],
      });
      expect(plain.intent, isEmpty);
      expect(tuned.intent, ['하트 하나', '적당히']);
      final a = ChoiceSignature.build(plain);
      final b = ChoiceSignature.build(tuned);
      expect(b.textGrams.length, greaterThan(a.textGrams.length));
      expect(b.tags, contains(Intent.love));
    });

    test('서명 캐시는 키가 같으면 재사용', () {
      final mm = FreeInputMatcher();
      final a = mm.signaturesFor('k', visible);
      final b = mm.signaturesFor('k', visible);
      expect(identical(a, b), isTrue);
      expect(identical(mm.signaturesFor('k2', visible), a), isFalse);
    });
  });
}
