// 이름 자리표시자와 한국어 조사. 규격: lib/engine/text_template.dart, docs/NAME_GUIDE.md.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/player_name.dart';
import 'package:mossol/engine/text_template.dart';
import 'package:mossol/ui/keep_all.dart';

String f(String s, [String? name]) => TextTemplate.fill(s, name: name);

void main() {
  group('받침 유무', () {
    test('호격 아야', () {
      expect(f('{name|아야}, 자?', '민석'), '민석아, 자?');
      expect(f('{name|아야}, 자?', '민수'), '민수야, 자?');
      expect(f('{name|아야}', '하늘'), '하늘아');
    });

    test('이가 · 은는 · 을를 · 과와 · 이랑랑', () {
      expect(f('{name|이가}', '민석'), '민석이');
      expect(f('{name|이가}', '민수'), '민수가');
      expect(f('{name|은는}', '민석'), '민석은');
      expect(f('{name|은는}', '민수'), '민수는');
      expect(f('{name|을를}', '민석'), '민석을');
      expect(f('{name|을를}', '민수'), '민수를');
      expect(f('{name|과와}', '민석'), '민석과');
      expect(f('{name|과와}', '민수'), '민수와');
      expect(f('{name|이랑랑}', '민석'), '민석이랑');
      expect(f('{name|이랑랑}', '민수'), '민수랑');
    });

    test('친근한 이: 받침 있을 때만', () {
      expect(f('{name|이}랑 밥 먹을래', '민석'), '민석이랑 밥 먹을래');
      expect(f('{name|이}랑 밥 먹을래', '민수'), '민수랑 밥 먹을래');
      expect(f('{name|이}가 그랬어', '민석'), '민석이가 그랬어');
      expect(f('{name|이}잖아', '민수'), '민수잖아');
    });

    test('존칭 씨 + 조사', () {
      expect(f('{name|씨}, 안녕하세요', '민석'), '민석 씨, 안녕하세요');
      expect(f('{name|씨+이가} 먼저', '민석'), '민석 씨가 먼저');
      expect(f('{name|씨+은는}요?', '민수'), '민수 씨는요?');
    });
  });

  group('으로로와 ㄹ 받침', () {
    test('ㄹ 받침은 로, 그 밖의 받침은 으로, 받침 없으면 로', () {
      expect(f('{name|으로로}', '하늘'), '하늘로');
      expect(f('{name|으로로}', '민석'), '민석으로');
      expect(f('{name|으로로}', '민수'), '민수로');
      // ㄹ 받침이라도 다른 조사는 받침 있음 규칙 그대로.
      expect(f('{name|이가}', '하늘'), '하늘이');
      expect(f('{name|아야}', '하늘'), '하늘아');
    });
  });

  group('영문 · 숫자', () {
    test('영문 이름은 발음으로 추정', () {
      expect(f('{name|아야}', 'Mina'), 'Mina야');
      expect(f('{name|아야}', 'Tom'), 'Tom아');
      expect(f('{name|을를}', 'Peter'), 'Peter를');
      expect(f('{name|으로로}', 'Paul'), 'Paul로');
      expect(f('{name|은는}', 'Jack'), 'Jack은');
      expect(f('{name|은는}', 'Mark'), 'Mark는');
      expect(f('{name|이가}', 'JANE'), 'JANE이');
      expect(f('{name|아야}', 'Kyle'), 'Kyle아');
    });

    test('숫자로 끝나면 한국어로 읽은 소리', () {
      expect(TextTemplate.finalOf('민수1'), Final.rieul); // 일
      expect(TextTemplate.finalOf('민수2'), Final.none); // 이
      expect(TextTemplate.finalOf('민수3'), Final.other); // 삼
      expect(TextTemplate.finalOf('민수10'), Final.other); // 십
      expect(TextTemplate.finalOf('0'), Final.other); // 영
      expect(f('{name|아야}', '민수7'), '민수7아');
      expect(f('{name|으로로}', '민수7'), '민수7로');
      expect(f('{name|을를}', '민수9'), '민수9를');
      expect(f('{name|을를}', 'a100'), 'a100을');
    });
  });

  group('한 글자 이름', () {
    test('받침 있음·없음', () {
      expect(f('{name|아야}, 뭐해', '별'), '별아, 뭐해');
      expect(f('{name|아야}, 뭐해', '해'), '해야, 뭐해');
      expect(f('{name|으로로}', '별'), '별로');
    });
  });

  group('이름 없음 → 대체어', () {
    test('호격 기본값은 지우고 쉼표·공백 정리', () {
      expect(f('{name|아야}, 자?'), '자?');
      expect(f('잘 자, {name|아야}.'), '잘 자.');
      expect(f('잘 자 {name|아야}'), '잘 자');
      expect(f('아 진짜 {name|아야} 왜 그래'), '아 진짜 왜 그래');
      expect(f('{name|아야}! 일어나'), '일어나');
    });

    test('그 밖의 기본값은 너 + 조사(너 + 이가 = 네가)', () {
      expect(f('{name}한테 할 말 있어'), '너한테 할 말 있어');
      expect(f('{name|이가} 먼저 했잖아'), '네가 먼저 했잖아');
      expect(f('{name|을를} 좋아해'), '너를 좋아해');
      expect(f('{name|은는}?'), '너는?');
      expect(f('{name|이}랑 갈래'), '너랑 갈래');
      expect(f('{name|으로로} 정했어'), '너로 정했어');
    });

    test('존칭 기본값은 그쪽', () {
      expect(f('{name|씨}, 안녕하세요'), '그쪽, 안녕하세요');
      expect(f('{name|씨+이가} 먼저'), '그쪽이 먼저');
    });

    test('대체어를 적으면 조사도 그 말에 맞춘다', () {
      expect(f('{name|아야|자기}, 자?'), '자기야, 자?');
      expect(f('{name|은는|선배}?'), '선배는?');
      expect(f('{name|을를|당신}'), '당신을');
      expect(f('{name||친구} 왔다'), '친구 왔다');
      expect(f('{name|이가|나}'), '내가');
      // 이름이 있으면 대체어는 쓰지 않는다.
      expect(f('{name|아야|자기}, 자?', '민지'), '민지야, 자?');
    });

    test('빈 대체어는 통째로 지운다', () {
      expect(f('{name||}, 들어 봐'), '들어 봐');
      expect(f('{name|아야|}, 자?'), '자?');
    });

    test('빈 문자열·공백 이름은 없는 것과 같다', () {
      expect(f('{name|아야}, 자?', ''), '자?');
      expect(f('{name|아야}, 자?', '  '), '자?');
    });
  });

  group('여러 자리표시자', () {
    test('한 문장에 둘 이상', () {
      expect(
        f('{name|아야}, {name|이}는 모르겠지만 나는 {name|이가} 좋아', '민석'),
        '민석아, 민석이는 모르겠지만 나는 민석이 좋아',
      );
      expect(f('{name|아야}, {name|은는} 어때?', '민수'), '민수야, 민수는 어때?');
      expect(f('{name|아야}, {name|은는} 어때?'), '너는 어때?');
    });

    test('자리표시자가 없으면 원문 그대로(같은 객체)', () {
      const s = '오늘 뭐 해?';
      expect(identical(f(s, '민지'), s), isTrue);
    });
  });

  group('잘못된 형식', () {
    late List<String> logs;
    late DebugPrintCallback saved;

    setUp(() {
      logs = [];
      saved = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
    });
    tearDown(() => debugPrint = saved);

    test('모르는 조사·키·순서는 그대로 두고 로그', () {
      for (final bad in [
        '{name|의}야',
        '{nmae} 안녕',
        '{name|아야|너|또}',
        '{name|이가+씨}',
        '{name|이+아야}',
        '{ name }',
      ]) {
        expect(f(bad, '민지'), bad, reason: bad);
        expect(TextTemplate.problems(bad), isNotEmpty, reason: bad);
      }
      expect(logs.where((l) => l.contains('TextTemplate')), isNotEmpty);
    });

    test('닫히지 않은 중괄호 · 여는 것 없는 닫는 괄호', () {
      expect(TextTemplate.problems('{name|아야, 자?'), contains('닫히지 않은 {'));
      expect(TextTemplate.problems('name}야'), contains('여는 { 없는 }'));
      // 형식이 맞는 것은 바꾸고, 틀린 부분은 그대로.
      expect(f('{name|아야}, {name 자?', '민지'), '민지야, {name 자?');
    });

    test('같은 문장은 한 번만 로그', () {
      f('{bad}', '민지');
      f('{bad}', '민지');
      expect(logs.where((l) => l.contains('{bad}')).length, 1);
    });

    test('정상 형식은 오류 없음', () {
      for (final ok in [
        '{name}',
        '{name|아야}',
        '{name|씨+이가}',
        '{name|이+은는}',
        '{name|아야|자기}',
        '{name||}',
      ]) {
        expect(TextTemplate.problems(ok), isEmpty, reason: ok);
      }
    });
  });

  group('keepAll 순서', () {
    test('치환 먼저, keepAll 은 결과에', () {
      final shown = keepAll(f('{name|아야}, 자?', '민지'));
      expect(shown.replaceAll(wordJoiner, ''), '민지야, 자?');
    });

    test('keepAll 을 먼저 씌우면 자리표시자가 깨진다(그래서 순서를 지킨다)', () {
      final wrong = f(keepAll('{name|아야}, 자?'), '민지');
      expect(wrong.contains('민지'), isFalse);
    });
  });

  group('길이 검사용 최대 길이', () {
    test('6자 이름의 가장 긴 조사로 잰다', () {
      expect(TextTemplate.maxLength('{name|아야}, 자?'), 6 + 1 + 4);
      expect(TextTemplate.maxLength('{name|이랑랑} 갈래'), 6 + 2 + 3);
      expect(TextTemplate.maxLength('그냥 문장'), 5);
    });
  });

  group('이름 입력 규칙', () {
    test('1~6자 · 한글 완성형·영문·숫자 · 공백 제거', () {
      expect(PlayerName.validate('민지'), isNull);
      expect(PlayerName.validate('Mina22'), isNull);
      expect(PlayerName.validate(''), isNull); // 빈 값은 버튼만 꺼진다
      expect(PlayerName.isValid(''), isFalse);
      expect(PlayerName.validate('가나다라마바사'), isNotNull);
      expect(PlayerName.validate('민ㅈ'), '완성된 글자로 써 주세요');
      expect(PlayerName.validate('민지!'), isNotNull);
      expect(PlayerName.normalize(' 민 지 '), '민지');
    });

    test('부적절한 말은 막는다(숫자를 끼워도)', () {
      expect(PlayerName.isBlocked('시발'), isTrue);
      expect(PlayerName.isBlocked('시1발'), isTrue);
      expect(PlayerName.isBlocked('FUCK'), isTrue);
      expect(PlayerName.isBlocked('민지'), isFalse);
      expect(PlayerName.validate('병신'), contains('쓸 수 없어요'));
    });
  });

  test('문장 맨 앞 호격 뒤 마침표도 이름이 없으면 함께 지운다', () {
    expect(TextTemplate.fill('{name|아야}. 너 나 좋아해?'), '너 나 좋아해?');
    expect(TextTemplate.fill('{name|아야}. 너 나 좋아해?', name: '민수'), '민수야. 너 나 좋아해?');
    expect(TextTemplate.fill('{name|아야}.'), '…');
    expect(TextTemplate.fill('{name|아야}…'), '…');
  });

  test('말줄임 바로 뒤 호격이 빠지면 빈칸 없이 붙인다', () {
    expect(TextTemplate.fill('…{name|아야}, 자?'), '…자?');
    expect(TextTemplate.fill('…{name|아야}, 자?', name: '민석'), '…민석아, 자?');
  });
}
