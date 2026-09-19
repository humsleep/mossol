import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/ui/keep_all.dart';

void main() {
  test('단어 안 글자 사이에만 WORD JOINER, 공백은 그대로', () {
    expect(keepAll('스토리에 올렸다'), '스⁠토⁠리⁠에 올⁠렸⁠다');
    expect(keepAll('a'), 'a');
    expect(keepAll(''), '');
  });

  test('이모지·결합 문자는 쪼개지 않는다', () {
    const family = '👨‍👩‍👧';
    final out = keepAll('가$family');
    expect(out, '가⁠$family');
    expect(out.replaceAll('⁠', ''), '가$family');
  });
}
