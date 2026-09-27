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
/// 플레이어 MBTI(docs/MBTI_SPEC.md §1.4):
///
/// ```text
/// {mbti}               플레이어 MBTI              INFP (모름이면 빈칸 — `mbti` 조건이 붙은 줄에서만 쓴다)
/// {mbti|대체어}        모름이면 대체어            INFP / 대체어
/// ```
///
/// 지금 호감 1위(`@top`)의 이름. 조사·대체어 규칙은 `{name}` 과 똑같다:
///
/// ```text
/// {top}                호감 1위 이름              다은
/// {top|이랑랑}         조사                       다은이랑
/// {top|아야|자기}      이름이 없을 때 쓸 말       자기야
/// ```
///
/// **특정 인물**의 이름. 조사·대체어 규칙은 `{name}` 과 똑같다:
///
/// ```text
/// {char:daeun}                  그 캐릭터 이름          다은
/// {char:daeun|이랑랑}           조사                    다은이랑
/// {char:daeun|아야}             호격                    다은아
/// {char:seoyeon|은는|그}        이름을 모를 때 쓸 말    서연은 / 그는
/// {char:seoyeon,jeongwoo|이가}  이 회차에 있는 첫 사람  서연이 / 정우가
/// ```
///
/// `{top}`(호감 1위)·`{name}`(플레이어)과 달리 **대사가 사람을 직접 지목**한다.
/// 선택하는 시점에 상대가 누군지 모르는 선택지(11_story_verdict §4-5 의 11개)를
/// 이벤트 레코드를 쪼개지 않고 고칠 수 있게 하려고 넣었다 — `m01`/`m01_m` 처럼
/// 쪼개면 이벤트 수가 바뀌어 다른 테스트까지 끌려 들어간다.
///
/// **id 를 쉼표로 여러 개 적으면 이 회차에 등장하는 첫 사람**을 쓴다. 한 레코드가
/// 여성 회차와 남성 회차에서 각각 맞는 사람을 부르므로 `d_meet_05`(서연/정우)·
/// `d_family_02`(예은/건우)·`m01`(다은/하늘)을 쪼개지 않고 닫을 수 있다
/// (12_content_handoff.md §6.1 의 요청. 거기 적힌 중첩 `{char:a||{char:b}}` 는 자리표시자
/// 문법이 중괄호 중첩을 읽지 않아서 쓸 수 없고, 이 쉼표 목록이 같은 일을 한다).
///
/// id 는 characters.json 의 id 다. **없는 id 는 검증기가 출시 전에 막는다**
/// (`StoryBundle.validate` → [charIdsIn]). 런타임에 이름을 못 찾으면(이 회차 선호 밖이거나
/// 목록이 다 비었으면) `{top}` 과 같은 중립 명사([topFallback])로, 대체어를 적었으면
/// 그것으로 떨어진다 — **id 를 화면에 그대로 내지 않는다.**
///
/// 넘겨받는 이름표는 **이 회차에 등장하는 사람만** 담는다
/// (`StoryBundle.charNamesFor`). 그래서 여성 회차 대사가 남성 쪽 캐릭터 이름을
/// 실수로 부르는 일이 생기지 않는다.
///
/// **누구를 넣는지(해소 규칙, docs/review/07_story_flow.md (e)1).** 데이트·카톡 일상 40여 개는
/// 효과 키 `@top`(호감 1위)으로 호감을 주면서 대사에서는 상대 이름을 한 번도 부르지 않았다.
/// `{top}` 은 **그 `@top` 효과가 실제로 가리키는 사람과 같은 사람**을 넣는다. 순서는 셋뿐이다.
///
/// 1. 이 회차 호감 1위(선호 밖 캐릭터 제외, [topCharacterOf] 와 같은 규칙).
///    호감이 같으면 `@top` 과 마찬가지로 characters.json 에서 앞선 사람 — 화면과 효과가 엇갈리지 않게
///    **일부러 같은 함수를 쓴다**.
/// 2. 1위가 없으면(D+1 처럼 전원 호감 0) **그 이벤트가 지목한 캐릭터**(`event.character`).
///    루트·모먼트는 상대가 정해져 있으므로 이게 가장 자연스럽다.
/// 3. 둘 다 없으면(캐릭터 없는 일상의 첫날, 또는 이름을 모르는 id) 중립 명사 [topFallback] — `그 사람`.
///    호격(`{top|아야}`)은 부를 이름이 없으므로 `{name|아야}` 와 같이 통째로 지운다.
///
/// "파일 첫 번째 캐릭터"처럼 플레이와 무관한 사람은 **절대 넣지 않는다.** 이름을 모르는 id
/// (characters.json 에 없는 사람)도 id 를 그대로 노출하지 않고 2 → 3 으로 내려간다.
/// 해소는 [EventEngine.topNameFor] 가 하고, 이 파일은 받은 이름을 조사에 맞춰 붙이기만 한다.
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

  /// 지금 플레이어 MBTI(캐스트 소개 등 컨트롤러를 받지 않는 화면용). [currentName] 과 같은 쓰임.
  static String? currentMbti;

  /// 지금 호감 1위 이름(컨트롤러를 받지 않는 화면용). 없으면 null → [topFallback].
  /// 회차가 없는 화면(캐스트 소개)에서는 null 로 둔다.
  static String? currentTop;

  /// 캐릭터 id → 이름. `{char:<id>}` 를 채운다. [fill] 에 `chars` 를 넘기면 그쪽이 이기고,
  /// 안 넘기는 화면(자유 입력 미리보기 등)은 이 값을 쓴다. `GameController` 가 채워 둔다.
  static Map<String, String> currentChars = const {};

  /// 이름 최대 길이(글자). 입력창과 길이 검사가 같이 쓴다.
  static const maxName = 6;

  /// 이름이 없을 때의 기본 대체어.
  static const defaultFallback = '너';
  static const honorificFallback = '그쪽';

  /// `{top}` 을 채울 사람이 아무도 없을 때 쓰는 중립 명사(해소 규칙 3단계).
  static const topFallback = '그 사람';

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
  /// `{mbti}` 는 [mbti] 로(null 이면 대체어, 대체어도 없으면 지운다).
  /// `{top}` 은 [top](이미 해소된 호감 1위 이름)으로 — null·빈 문자열이면 [topFallback].
  /// 자리표시자가 없으면 [s] 를 그대로 돌려준다.
  static String fill(
    String s, {
    String? name,
    String? mbti,
    String? top,
    Map<String, String>? chars,
  }) {
    if (!s.contains('{') && !s.contains('}')) return s;
    final n = (name ?? '').trim();
    final t = (top ?? '').trim();
    final cs = chars ?? currentChars;
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
      final r = spec.render(
        n.isEmpty ? null : n,
        mbti,
        t.isEmpty ? null : t,
        cs,
      );
      if (r.isEmpty) holes = true;
      return r.isEmpty ? _hole : r;
    });
    return holes ? _closeHoles(out) : out;
  }

  /// 지워진 자리표시자 옆 쉼표·공백을 정리한다.
  /// `{name|아야|}, 자?` → `자?`, `잘 자, {name|아야|}.` → `잘 자.`
  static String _closeHoles(String s) {
    final out = s
        // 문장 맨 앞: 뒤따르는 쉼표·마침표·느낌표·물결·말줄임과 공백까지.
        // `{name|아야}. 너 나…` 가 `. 너 나…` 로 남지 않게 마침표도 지운다.
        .replaceAll(RegExp('^\\s*$_hole[,.!~…]*\\s*'), '')
        // 문장 끝이나 마침표 앞: 앞선 쉼표와 공백까지.
        .replaceAll(RegExp(',?\\s*$_hole(?=[.!?~…]|\$)'), '')
        // 말줄임·물결 바로 뒤: 빈칸 없이 붙인다. `…{name|아야}, 자?` → `…자?`
        .replaceAll(RegExp('(?<=[…~])\\s*$_hole,?\\s*'), '')
        // 가운데: 한 칸 공백으로.
        .replaceAll(RegExp('\\s*$_hole,?\\s*'), ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    final result = out.replaceAll(_hole, '');
    // 이름만 부르던 줄(`{name|아야}.`)이 통째로 비면 빈 말풍선 대신 말줄임.
    return result.isEmpty ? '…' : result;
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

  /// [s] 가 `{char:<id>}` 로 지목한 캐릭터 id 전부(중복 제거). 검증기가 없는 id 를 잡는다.
  static Set<String> charIdsIn(String s) => {
    for (final m in _token.allMatches(s))
      if (_parse(m[1]!) case _Spec(charIds: final ids?)) ...ids,
  };

  /// 대체어 없는 `{mbti}` 가 있는지. 이런 문장은 `mbti` 조건이 붙은 줄·선택지에서만 쓸 수 있다
  /// (MBTI 를 모르는 플레이어에게 빈칸이 보이지 않게, 검증기가 막는다).
  static bool hasBareMbti(String s) => _token
      .allMatches(s)
      .any(
        (m) => switch (_parse(m[1]!)) {
          _MbtiSpec(fallback: null) => true,
          _ => false,
        },
      );

  /// 길이 검사용: 가장 긴 치환 결과의 글자 수. 이름은 최대 길이([maxName])의
  /// 받침 있음·없음·ㄹ 세 경우와 이름 없음(대체어)을 모두 넣어 본다.
  /// `{top}` 은 캐스트 이름(세 글자)과 1위 없음([topFallback], 네 글자) 두 경우.
  /// `{char:<id>}` 는 [chars] 의 실제 이름으로 잰다. 없는 id 는 [fill] 이 [topFallback]
  /// (네 글자)로 떨어뜨리므로 그대로 최악값이 된다.
  static int maxLength(String s, {Map<String, String>? chars}) {
    if (!hasToken(s)) return s.length;
    const sample = '가나다라마';
    var best = 0;
    for (final n in ['$sample박', '$sample바', '$sample발', null]) {
      for (final m in const ['INTJ', null]) {
        for (final t in const ['가나다', null]) {
          final l = fill(s, name: n, mbti: m, top: t, chars: chars).length;
          if (l > best) best = l;
        }
      }
    }
    return best;
  }

  static _Token? _parse(String body) {
    final parts = body.split('|');
    if (parts.first == 'mbti') {
      if (parts.length > 2) return null;
      return _MbtiSpec(parts.length == 2 ? parts[1].trim() : null);
    }
    final isTop = parts.first == 'top';
    // `{char:<id>}` 또는 `{char:<id>,<id>…}`. 빈 id 는 오류다.
    final charIds = parts.first.startsWith(_charPrefix)
        ? [
            for (final id in parts.first
                .substring(_charPrefix.length)
                .split(','))
              id.trim(),
          ]
        : null;
    if (charIds != null && (charIds.isEmpty || charIds.any((c) => c.isEmpty))) {
      return null;
    }
    if (parts.length > 3 ||
        (!isTop && charIds == null && parts.first != 'name')) {
      return null;
    }
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
    return _Spec(mods, fallback, top: isTop, charIds: charIds);
  }

  /// `{char:<id>}` 의 머리말.
  static const _charPrefix = 'char:';

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

/// 자리표시자 하나. [render] 가 빈 문자열이면 그 자리를 지우고 쉼표·공백을 정리한다.
sealed class _Token {
  const _Token();
  String render(
    String? name,
    String? mbti,
    String? top,
    Map<String, String> chars,
  );
}

/// `{mbti}` · `{mbti|대체어}`.
class _MbtiSpec extends _Token {
  final String? fallback;
  const _MbtiSpec(this.fallback);

  @override
  String render(
    String? name,
    String? mbti,
    String? top,
    Map<String, String> chars,
  ) => mbti ?? fallback ?? '';
}

/// 이름 자리표시자 하나: 수식 목록 + 대체어(null 이면 기본값, '' 이면 지움).
/// [top] 이면 `{name}` 이 아니라 `{top}`(호감 1위) 자리다 — 조사 규칙은 같고 기본 대체어만 다르다.
class _Spec extends _Token {
  final List<String> mods;
  final String? fallback;
  final bool top;

  /// `{char:<id>,…}` 가 지목한 캐릭터 id 목록(적은 순서). 그 밖에는 null.
  final List<String>? charIds;

  const _Spec(this.mods, this.fallback, {this.top = false, this.charIds});

  String? get _terminal =>
      mods.isNotEmpty && TextTemplate.particles.containsKey(mods.last)
      ? mods.last
      : null;

  bool get _honorific => mods.contains('씨');

  @override
  String render(
    String? name,
    String? mbti,
    String? topName,
    Map<String, String> chars,
  ) {
    // 여러 id 를 적었으면 이 회차 이름표에 있는 **첫 사람**을 쓴다.
    String? firstPresent(List<String> ids) {
      for (final id in ids) {
        final n = chars[id]?.trim();
        if (n != null && n.isNotEmpty) return n;
      }
      return null;
    }

    final who = switch (charIds) {
      final ids? => firstPresent(ids),
      _ => top ? topName : name,
    };
    if (who != null) {
      var base = who;
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
        // 호격은 부를 이름이 없으면 통째로 지운다({name} · {top} 공통).
        (term == TextTemplate.vocative
            ? ''
            : _honorific
            ? TextTemplate.honorificFallback
            // 3인칭 지목({top}·{char:})은 이름이 없으면 중립 명사, 플레이어는 '너'.
            : (top || charIds != null)
            ? TextTemplate.topFallback
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
