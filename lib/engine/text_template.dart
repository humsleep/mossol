/// 대사 자리표시자 → 플레이어 이름. 규격 전문은 docs/NAME_GUIDE.md.
///
/// ```text
/// {name}               이름 그대로                 민지 / 민석
/// {name|아야}          호격                        민지야 / 민석아
/// {name|이가}          주격                        민지가 / 민석이
/// {name|은는}          보조사                      민지는 / 민석은
/// {name|을를}          목적격                      민지를 / 민석을
/// {name|과와}          공동격                      민지와 / 민석과
/// {name|이랑랑}        공동격(구어)                민지랑 / 민석이랑
/// {name|으로로}        방향·자격(ㄹ 받침은 '로')   민지로 / 민석으로 / 하늘로
/// {name|이}            친근한 '이'(받침 있을 때만)  민지 / 민석이   예: {name|이}랑 → 민지랑 / 민석이랑
/// {name|씨}            존칭 ' 씨'                  민지 씨 / 민석 씨
/// {name|씨+이가}       ' 씨' 뒤에 조사             민지 씨가
/// {name|아야|자기}     세 번째 칸 = 이름이 없을 때 쓸 말(조사는 그 말에 맞춘다) → 자기야
/// {name||너}           조사 없이 대체어만
/// {name|아야|}         대체어를 비우면 자리표시자를 통째로 지우고 쉼표·공백을 정리한다
/// ```
///
/// 이름이 없고 대체어도 안 적었을 때(기본값):
/// - 호격(`아야`)은 통째로 지우고 옆 쉼표를 정리한다: `{name|아야}, 자?` → `자?`
/// - `씨` 가 붙은 것은 `그쪽`: `{name|씨}` → `그쪽`, `{name|씨+이가}` → `그쪽이`
/// - 나머지는 `너` + 조사: `{name|을를}` → `너를`, `{name|이가}` → `네가`(너·나·저 + 이가 는 네가·내가·제가)
///
/// 받침 판단([finalOf]): 한글은 마지막 음절의 종성. 숫자는 한국어로 읽은 소리
/// (1 일·3 삼·6 육·7 칠·8 팔·0 영 받침 있음, 10 십·100 백·1000 천·10000 만).
/// 영문은 발음 추정(아래 [_latinFinal]). 그 밖의 글자는 받침 없음으로 본다.
///
/// 형식이 틀린 자리표시자(모르는 조사, 닫히지 않은 중괄호 등)는 **그대로 두고**
/// 디버그 로그를 한 번 남긴다. 출시 데이터는 검증기(`StoryBundle.validate`)가 먼저 막는다.
///
/// 순서: 치환이 먼저, `keepAll`(한국어 단어 단위 줄바꿈)은 그 결과에. `keepAll` 이 넣는
/// WORD JOINER 가 `{name|아야}` 안에 끼면 더는 자리표시자로 읽히지 않는다.
library;

import 'package:flutter/foundation.dart';

/// 마지막 소리의 받침.
enum Final { none, rieul, other }

class TextTemplate {
  TextTemplate._();

  /// 지금 플레이어 이름. `GameController` 가 기기 메타를 읽고 바꿀 때 맞춰 둔다.
  /// 컨트롤러를 받지 않는 화면(캐스트 소개의 첫 메시지, `StoryBundle.firstLineOf`)이 쓴다.
  static String? currentName;

  /// 이름 최대 길이(글자). 입력창과 길이 검사가 같이 쓴다.
  static const maxName = 6;

  /// 이름이 없을 때의 기본 대체어.
  static const defaultFallback = '너';
  static const honorificFallback = '그쪽';

  /// 끝 조사(마지막에 하나만). 값은 (받침 있을 때, 없을 때).
  static const particles = <String, (String, String)>{
    '아야': ('아', '야'),
    '이가': ('이', '가'),
    '은는': ('은', '는'),
    '을를': ('을', '를'),
    '과와': ('과', '와'),
    '이랑랑': ('이랑', '랑'),
    '으로로': ('으로', '로'),
  };

  /// 줄기 수식(맨 앞에 하나만): 친근한 '이', 존칭 ' 씨'.
  static const stems = {'이', '씨'};

  static const vocative = '아야';

  /// `{` 부터 가장 가까운 `}` 까지. 안에 `{` 가 또 있으면 닫히지 않은 것.
  static final _token = RegExp(r'\{([^{}]*)\}');

  /// 지워진 자리표시자 자리. 쉼표·공백 정리 뒤 남지 않는다.
  static const _hole = '\uE000';

  static final Set<String> _logged = {};

  /// [s] 의 자리표시자를 [name] 으로 바꾼다. [name] 이 null·빈 문자열이면 대체어.
  /// 자리표시자가 없으면 [s] 를 그대로 돌려준다.
  static String fill(String s, {String? name}) {
    if (!s.contains('{') && !s.contains('}')) return s;
    final n = (name ?? '').trim();
    final errors = problems(s);
    if (errors.isNotEmpty) {
      if (_logged.add(s)) {
        debugPrint(
          '[TextTemplate] 잘못된 자리표시자(그대로 둠): "$s" — ${errors.join('; ')}',
        );
      }
      // 형식이 맞는 자리표시자만 바꾸고, 나머지는 원문 그대로.
    }
    var holes = false;
    final out = s.replaceAllMapped(_token, (m) {
      final spec = _parse(m[1]!);
      if (spec == null) return m[0]!;
      final r = spec.render(n.isEmpty ? null : n);
      if (r.isEmpty) holes = true;
      return r.isEmpty ? _hole : r;
    });
    return holes ? _closeHoles(out) : out;
  }

  /// 지워진 자리표시자 옆 쉼표·공백을 정리한다.
  /// `{name|아야|}, 자?` → `자?`, `잘 자, {name|아야|}.` → `잘 자.`
  static String _closeHoles(String s) {
    final out = s
        // 문장 맨 앞: 뒤따르는 쉼표·느낌표·물결과 공백까지.
        .replaceAll(RegExp('^\\s*$_hole[,!~]*\\s*'), '')
        // 문장 끝이나 마침표 앞: 앞선 쉼표와 공백까지.
        .replaceAll(RegExp(',?\\s*$_hole(?=[.!?~…]|\$)'), '')
        // 가운데: 한 칸 공백으로.
        .replaceAll(RegExp('\\s*$_hole,?\\s*'), ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    return out.replaceAll(_hole, '');
  }

  /// 형식 오류 목록. 비어 있으면 정상. 검증기와 [fill] 의 로그가 쓴다.
  static List<String> problems(String s) {
    final out = <String>[];
    // 짝이 맞는 토큰을 빼고 남은 중괄호는 전부 오류.
    final rest = s.replaceAllMapped(_token, (m) {
      if (_parse(m[1]!) == null) out.add('모르는 자리표시자 ${m[0]}');
      return '';
    });
    if (rest.contains('{')) out.add('닫히지 않은 {');
    if (rest.contains('}')) out.add('여는 { 없는 }');
    return out;
  }

  /// 자리표시자가 있는지.
  static bool hasToken(String s) => _token.hasMatch(s);

  /// 길이 검사용: 가장 긴 치환 결과의 글자 수. 이름은 최대 길이([maxName])의
  /// 받침 있음·없음·ㄹ 세 경우와 이름 없음(대체어)을 모두 넣어 본다.
  static int maxLength(String s) {
    if (!hasToken(s)) return s.length;
    const sample = '가나다라마';
    var best = 0;
    for (final n in ['$sample박', '$sample바', '$sample발', null]) {
      final l = fill(s, name: n).length;
      if (l > best) best = l;
    }
    return best;
  }

  static _Spec? _parse(String body) {
    final parts = body.split('|');
    if (parts.length > 3 || parts.first != 'name') return null;
    final mods = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1].split('+')
        : const <String>[];
    // 줄기 수식은 맨 앞 하나, 끝 조사는 맨 뒤 하나.
    for (var i = 0; i < mods.length; i++) {
      final m = mods[i];
      if (stems.contains(m)) {
        if (i != 0) return null;
      } else if (particles.containsKey(m)) {
        if (i != mods.length - 1) return null;
      } else {
        return null;
      }
    }
    if (mods.length > 2) return null;
    // 호격은 줄기 수식과 섞지 않는다("민석이야"는 호격이 아니라 서술).
    if (mods.length == 2 && mods.last == vocative) return null;
    final fallback = parts.length == 3 ? parts[2].trim() : null;
    return _Spec(mods, fallback);
  }

  /// 단어 [word] 마지막 소리의 받침.
  static Final finalOf(String word) {
    if (word.isEmpty) return Final.none;
    final last = word.codeUnitAt(word.length - 1);
    if (last >= 0xAC00 && last <= 0xD7A3) {
      final jong = (last - 0xAC00) % 28;
      if (jong == 0) return Final.none;
      return jong == 8 ? Final.rieul : Final.other;
    }
    // 호환 자모: 자음이면 그 받침, 모음이면 없음.
    if (last >= 0x3131 && last <= 0x314E) {
      return last == 0x3139 ? Final.rieul : Final.other;
    }
    if (last >= 0x314F && last <= 0x3163) return Final.none;
    if (last >= 0x30 && last <= 0x39) return _digitFinal(word);
    final ch = String.fromCharCode(last).toLowerCase();
    if (RegExp('[a-z]').hasMatch(ch)) return _latinFinal(word.toLowerCase());
    return Final.none;
  }

  /// 숫자: 한국어로 읽은 마지막 소리. 끝의 0 은 자릿수(십·백·천·만)로 읽는다.
  static Final _digitFinal(String word) {
    final digits = RegExp(r'\d+$').firstMatch(word)![0]!;
    final trimmed = digits.replaceFirst(RegExp(r'^0+'), '');
    if (trimmed.isEmpty) return Final.other; // 0, 00 → 영
    final zeros =
        trimmed.length - trimmed.replaceFirst(RegExp(r'0+$'), '').length;
    if (zeros > 0) {
      // 10 십(ㅂ) · 100 백(ㄱ) · 1000 천(ㄴ) · 10000 이상 만(ㄴ). 전부 ㄹ 아닌 받침.
      return Final.other;
    }
    return switch (trimmed[trimmed.length - 1]) {
      '1' || '7' || '8' => Final.rieul, // 일 칠 팔
      '3' || '6' => Final.other, // 삼 육
      _ => Final.none, // 이 사 오 구
    };
  }

  /// 영문: 발음 추정. 완벽하지 않다 — 표기법을 따르는 대부분의 이름에서 맞는 정도.
  /// - l, le → ㄹ (Paul 폴, Nicole 니콜, Kyle 카일)
  /// - m, n, ng, me, ne → 받침 (Tom 톰, Jean 진, Jane 제인)
  /// - 모음 하나 뒤의 b·p·t·k, 그리고 ck → 받침 (Bob 밥, Pat 팻, Jack 잭)
  /// - 그 밖(모음, r, 자음 뒤 파열음, d·g·s·x 등) → 없음 (Peter 피터, Mark 마크, Max 맥스)
  static Final _latinFinal(String w) {
    if (w.endsWith('l') || w.endsWith('le')) return Final.rieul;
    if (RegExp(r'(m|n|ng|me|ne)$').hasMatch(w)) return Final.other;
    if (w.endsWith('ck')) return Final.other;
    if (RegExp(r'(^|[^aeiou])[aeiou][bptk]$').hasMatch(w)) return Final.other;
    return Final.none;
  }

  /// [word] 뒤에 붙일 조사. [pair] = (받침 있을 때, 없을 때). `으로로` 는 ㄹ 받침에 '로'.
  static String particleFor(String word, String key) {
    final (withF, withoutF) = particles[key]!;
    final f = finalOf(word);
    if (key == '으로로' && f == Final.rieul) return withoutF;
    return f == Final.none ? withoutF : withF;
  }
}

/// 자리표시자 하나: 수식 목록 + 대체어(null 이면 기본값, '' 이면 지움).
class _Spec {
  final List<String> mods;
  final String? fallback;

  const _Spec(this.mods, this.fallback);

  String? get _terminal =>
      mods.isNotEmpty && TextTemplate.particles.containsKey(mods.last)
      ? mods.last
      : null;

  bool get _honorific => mods.contains('씨');

  String render(String? name) {
    if (name != null) {
      var base = name;
      for (final m in mods) {
        base = switch (m) {
          '씨' => '$base 씨',
          '이' => TextTemplate.finalOf(base) == Final.none ? base : '$base이',
          _ => base + TextTemplate.particleFor(base, m),
        };
      }
      return base;
    }
    // 이름이 없을 때.
    final term = _terminal;
    final word =
        fallback ??
        (term == TextTemplate.vocative
            ? ''
            : _honorific
            ? TextTemplate.honorificFallback
            : TextTemplate.defaultFallback);
    if (word.isEmpty) return '';
    var base = word;
    for (final m in mods) {
      if (m == '씨') continue; // 대체어에는 존칭을 붙이지 않는다(그쪽 씨 ✗).
      if (m == '이') {
        base = TextTemplate.finalOf(base) == Final.none ? base : '$base이';
        continue;
      }
      // 너·나·저 + 이가 → 네가·내가·제가.
      if (m == '이가') {
        const contracted = {'너': '네', '나': '내', '저': '제'};
        final c = contracted[base];
        if (c != null) {
          base = '$c가';
          continue;
        }
      }
      base = base + TextTemplate.particleFor(base, m);
    }
    return base;
  }
}
