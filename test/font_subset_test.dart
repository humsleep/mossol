import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 서브셋 폰트(assets/fonts/Pretendard-*.otf)가 프로젝트의 모든 한글을 담고 있는지.
///
/// OTF cmap 을 Dart 로 파싱하는 대신, tool/subset_fonts.py 가 실제 cmap 에서 뽑아
/// 적어 둔 assets/fonts/coverage.txt 와 소스의 한글 집합을 비교한다.
/// 실패하면: `python3 tool/subset_fonts.py` 를 다시 돌리고 assets/fonts/ 를 함께 커밋.
void main() {
  // tool/subset_fonts.py 의 SOURCE_GLOBS 와 같은 목록을 유지할 것.
  final sourceFiles = <File>[
    ...Directory('assets/story').listSync().whereType<File>().where((f) => f.path.endsWith('.json')),
    ...Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
    File('ios/Runner/Info.plist'),
  ];
  final hangul = RegExp('[가-힣]');

  late Set<int> covered;
  late List<String> lines;

  setUpAll(() {
    lines = File('assets/fonts/coverage.txt').readAsLinesSync();
    covered = {
      for (final l in lines)
        if (l.isNotEmpty && !l.startsWith('#')) int.parse(l, radix: 16),
    };
  });

  test('coverage.txt 는 스크립트가 만든 그대로다 (해시 일치)', () {
    final head = lines.first;
    expect(head, startsWith('# fnv1a64 '), reason: '첫 줄은 fnv1a64 헤더여야 한다');
    final body = lines.where((l) => l.isNotEmpty && !l.startsWith('#')).join('\n');
    expect(head.substring('# fnv1a64 '.length), _fnv1a64(body),
        reason: 'coverage.txt 가 손으로 수정됐다. python3 tool/subset_fonts.py 를 다시 돌릴 것');
  });

  test('소스의 모든 한글 음절이 서브셋에 들어 있다', () {
    final missing = <String>{};
    for (final f in sourceFiles) {
      for (final m in hangul.allMatches(f.readAsStringSync())) {
        final ch = m.group(0)!;
        if (!covered.contains(ch.runes.first)) missing.add(ch);
      }
    }
    expect(missing, isEmpty,
        reason: '서브셋에 없는 한글 ${missing.length}자: ${missing.join()}\n'
            '→ python3 tool/subset_fonts.py 를 다시 돌리고 assets/fonts/ 를 커밋할 것');
  });

  test('KS X 1001 2350자와 필수 기호가 들어 있다', () {
    final syllables = covered.where((c) => c >= 0xAC00 && c <= 0xD7A3).length;
    expect(syllables, greaterThanOrEqualTo(2350));
    for (final ch in '₩…“”‘’·ㆍ♥★→'.runes) {
      expect(covered, contains(ch), reason: 'U+${ch.toRadixString(16).toUpperCase()} 누락');
    }
  });

  test('서브셋 OTF 4종이 있고 폰트 폴더 총합이 1.5MB 이하다', () {
    var total = 0;
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final f = File('assets/fonts/Pretendard-$w.otf');
      expect(f.existsSync(), isTrue, reason: '${f.path} 없음');
      total += f.lengthSync();
    }
    expect(total, lessThanOrEqualTo(1536 * 1024),
        reason: '폰트 총합 ${(total / 1024 / 1024).toStringAsFixed(2)}MB. 서브셋 범위를 점검할 것');
  });
}

/// tool/subset_fonts.py 의 fnv1a64 와 같은 계산.
String _fnv1a64(String text) {
  var h = 0xCBF29CE484222325;
  for (final b in utf8.encode(text)) {
    h = (h ^ b) * 0x100000001B3;
  }
  // 부호 있는 64비트 int 를 그대로 16진으로 찍으면 음수가 되므로 32비트씩 나눠 찍는다.
  return ((h >>> 32) & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0') +
      (h & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
}
