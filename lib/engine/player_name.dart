/// 플레이어 이름 입력 규칙. 온보딩 이름 단계와 설정의 "내 이름" 이 같이 쓴다.
///
/// 1~[maxLength]자(자소 묶음 기준), 한글 완성형·영문·숫자만, 공백 없음, 부적절한 말 금지.
/// 이름은 기기 메타(`PlayerMeta.playerName`)에만 저장하고 밖으로 보내지 않는다.
library;

import 'package:characters/characters.dart';

import 'text_template.dart';

class PlayerName {
  PlayerName._();

  static const maxLength = TextTemplate.maxName;

  /// 입력 중에 받아 주는 글자: 완성형 한글, 조합 중에 잠깐 보이는 자모, 영문, 숫자.
  /// 자모만 남은 이름은 [validate] 가 막는다.
  static final allowedChar = RegExp(r'[가-힣ㄱ-ㅎㅏ-ㅣA-Za-z0-9]');

  static final _complete = RegExp(r'^[가-힣A-Za-z0-9]+$');

  /// 막는 말(작게 유지). 소문자·숫자 뺀 형태에 포함되면 막는다("시1발" 도 걸린다).
  /// 욕설·성적 표현·혐오 표현의 흔한 형태만 담는다.
  static const blocked = [
    '시발',
    '씨발',
    '씨바',
    '시바',
    '씹',
    '좆',
    '존나',
    '졸라',
    '병신',
    '븅신',
    '지랄',
    '개새',
    '새끼',
    '미친놈',
    '미친년',
    '염병',
    '닥쳐',
    '꺼져',
    '엠창',
    '느금',
    '니미',
    '애미',
    '애비',
    '창녀',
    '걸레',
    '보지',
    '자지',
    '섹스',
    '야동',
    '김치녀',
    '된장녀',
    '틀딱',
    '급식충',
    '맘충',
    '짱깨',
    '쪽바리',
    '깜둥이',
    '장애새',
    '홍어',
    'fuck',
    'shit',
    'bitch',
    'sex',
    'porn',
    'dick',
    'pussy',
    'cunt',
    'nigg',
    'fag',
    'slut',
    'whore',
  ];

  /// 앞뒤 공백을 떼고 안쪽 공백을 지운 값. 저장 전에 거친다.
  static String normalize(String raw) => raw.replaceAll(RegExp(r'\s'), '');

  /// 글자 수(자소 묶음). 조합 중인 한 음절도 한 글자다.
  static int lengthOf(String s) => s.characters.length;

  /// 문제가 있으면 안내 문구, 없으면 null. 빈 값은 null(버튼만 꺼진다).
  static String? validate(String raw) {
    final s = normalize(raw);
    if (s.isEmpty) return null;
    if (lengthOf(s) > maxLength) return '$maxLength자까지 쓸 수 있어요';
    if (!_complete.hasMatch(s)) {
      return RegExp(r'[ㄱ-ㅎㅏ-ㅣ]').hasMatch(s)
          ? '완성된 글자로 써 주세요'
          : '한글 · 영문 · 숫자만 쓸 수 있어요';
    }
    if (isBlocked(s)) return '이 이름은 쓸 수 없어요. 다른 이름을 써 주세요';
    return null;
  }

  static bool isBlocked(String s) {
    final flat = s.toLowerCase().replaceAll(RegExp(r'[0-9]'), '');
    return blocked.any(flat.contains);
  }

  /// 저장해도 되는 이름인지.
  static bool isValid(String raw) =>
      normalize(raw).isNotEmpty && validate(raw) == null;
}
