/// 한국어 단어 단위 줄바꿈(CSS `word-break: keep-all`).
///
/// Flutter 는 한글을 글자마다 줄을 바꿀 수 있는 문자로 보아 "올 / 렸다" 처럼 단어
/// 가운데서 줄이 바뀐다. 표시용 문자열의 단어 안 글자 사이에 WORD JOINER(U+2060,
/// 폭 0·보이지 않음)를 넣어 공백에서만 줄이 바뀌게 한다. 한 단어가 한 줄보다
/// 길면 엔진이 강제로 끊으므로 넘치지는 않는다.
///
/// 글자는 자소 단위(grapheme)로 나눠 이모지·결합 문자를 깨뜨리지 않는다.
///
/// 표시에만 쓴다. 저장·비교·스크린리더에는 원문을 쓴다(WJ 는 읽히지 않지만
/// 문자열 비교가 달라진다). 테스트에서 화면 글자를 찾을 때도 [keepAll] 로 감싼다.
library;

import 'package:characters/characters.dart';

const wordJoiner = '⁠';

final _word = RegExp(r'\S{2,}');

String keepAll(String s) {
  if (s.length < 2) return s;
  return s.replaceAllMapped(_word, (m) => m[0]!.characters.join(wordJoiner));
}
