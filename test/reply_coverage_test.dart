// 선택지마다 상대 반응(reply / failReply)이 붙어 있는지 파일별로 검사한다.
// 메신저 게임에서 내 말에 아무도 대답하지 않으면 대화가 아니다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/text_template.dart';

const files = [
  'events_main.json',
  'events_daily.json',
  'events_route_a.json',
  'events_route_b.json',
  'events_special.json',
  'route_jeongwoo.json',
  'route_daeun.json',
  'route_seunghyun.json',
  'route_sohee.json',
  'route_geonwoo.json',
  'route_yuna.json',
  'events_moments.json',
];

const maxLines = 3;

/// 반응 한 줄 최대 글자 수. 이름 자리표시자(`{name|아야}` 등)가 있으면 **가장 긴 이름(6자)으로
/// 바꾼 결과**로 잰다 — 화면에 실제로 보이는 길이가 기준이다(docs/NAME_GUIDE.md).
const maxChars = 60;

List<Map<String, dynamic>> _events(String f) {
  final text = File('assets/story/$f').readAsStringSync();
  // 작가가 채우는 중인 빈 파일은 이벤트 0개로 본다(StoryBundle 과 같은 규칙).
  if (text.trim().isEmpty) return const [];
  final raw = jsonDecode(text);
  final list = raw is List ? raw : (raw as Map)['events'] as List;
  return list.cast<Map<String, dynamic>>();
}

/// 문제 목록. 비어 있으면 통과.
List<String> problemsIn(String f) {
  final out = <String>[];
  for (final e in _events(f)) {
    final choices = (e['choices'] as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < choices.length; i++) {
      final ch = Choice.fromJson(choices[i]);
      final where = '${e['id']}.choices[$i]';
      final canFail = ch.chance != null || ch.minigame != null;
      // 다음 이벤트로 이어지는 쪽은 그 이벤트의 첫 줄이 반응이다.
      if (ch.next == null && ch.reply.isEmpty) out.add('$where: reply 없음');
      if (canFail && ch.failNext == null && ch.failReply.isEmpty) {
        out.add('$where: failReply 없음');
      }
      for (final (name, lines) in [
        ('reply', ch.reply),
        ('failReply', ch.failReply),
        ('critReply', ch.critReply),
      ]) {
        if (lines.length > maxLines) out.add('$where.$name: $maxLines줄 초과');
        for (final l in lines) {
          if (!const {'them', 'narr', 'sys', 'me'}.contains(l.who)) {
            out.add('$where.$name: who=${l.who}');
          }
          // 사진 줄(MOMENTS_SPEC §1.3)은 글 없이 사진만 보내도 된다.
          if (l.text.trim().isEmpty && l.photo == null) {
            out.add('$where.$name: 빈 줄');
          }
          final n = TextTemplate.maxLength(l.text);
          if (n > maxChars) {
            out.add('$where.$name: $maxChars자 초과 ($n, 이름 6자 기준)');
          }
          if (l.wait > 0) out.add('$where.$name: 반응에는 대기 줄 금지');
        }
      }
    }
  }
  return out;
}

void main() {
  for (final f in files) {
    test('$f: 모든 선택지에 상대 반응이 있다', () {
      final p = problemsIn(f);
      expect(p, isEmpty, reason: '${p.length}건\n${p.take(40).join('\n')}');
    });
  }

  test('문자열 반응은 상대의 말 한 줄이 된다', () {
    final ch = Choice.fromJson({
      'text': 'a',
      'chance': 50,
      'reply': 'ㅋㅋ 뭐야',
      'failReply': [
        {'who': 'narr', 'text': '읽음 표시만 떴다.'},
      ],
      'critReply': ['헐', '진짜?'],
    });
    expect(ch.reply.single.who, 'them');
    expect(ch.replyFor(success: false, critical: false).single.who, 'narr');
    expect(ch.replyFor(success: true, critical: true).length, 2);
    expect(ch.replyFor(success: true, critical: false).single.text, 'ㅋㅋ 뭐야');
  });

  test('길이는 이름을 넣은 뒤 기준: 원문이 60자를 넘어도 6자 이름으로 바꾼 길이가 60 이내면 통과', () {
    // 원문 61자(자리표시자 9자) → 가장 긴 이름 '가나다라마박아, …' 59자.
    final ok = '{name|아야}, ${'가' * 50}';
    expect(ok.length, 61);
    expect(TextTemplate.maxLength(ok), 59);
    expect(TextTemplate.maxLength(ok), lessThanOrEqualTo(maxChars));
    // 대체어가 이름보다 길면 대체어 쪽 길이로 잰다.
    final long = '{name|씨|우리 동아리 새 신입 회원님}${'가' * 46}';
    expect(TextTemplate.maxLength(long), greaterThan(maxChars));
  });

  test('critReply 가 없으면 크리티컬에도 reply 를 쓴다', () {
    final ch = Choice.fromJson({'text': 'a', 'reply': '좋아'});
    expect(ch.replyFor(success: true, critical: true).single.text, '좋아');
  });
}
