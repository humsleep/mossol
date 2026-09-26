/// 제한형 자유 입력 — 플레이어가 친 문장을 지금 이벤트의 보이는 선택지 하나로 분류한다.
/// 설계 전문: docs/overhaul/07_free_input.md §1. LLM·서버·형태소 분석기 없음, 순수 함수뿐이라
/// `flutter test` 로 그대로 돈다. UI·컨트롤러에 의존하지 않는다.
///
/// 점수(§1.5):
/// ```
/// score = 0.40·dice(입력 2-gram, 문구 2-gram)   // 입력이 서술형이면 서술형 후보에 0.50
///       + 0.15·dice(입력 2-gram, 반응 2-gram)
///       + 0.35·jaccard(입력 태그, 후보 태그)
///       + 0.10·style                            // polite 같음 .5 · question 같음 .3 · 길이 인접 .2
///       − 0.25 (반대 극성)
/// ```
/// 임계값은 [FreeInputThresholds]. 픽스처(test/fixtures/free_input.json)로 맞춘 최종값이다.
library;

import 'free_input_lexicon.dart';
import 'event_engine.dart';
import 'models.dart';
import 'text_template.dart';

/// 자동 확정·피커 경계(07 §1.6). 픽스처 기준으로 잡았다 — 바꾸면 test/free_input_test.dart 를 다시 돌린다.
abstract final class FreeInputThresholds {
  /// 자동 확정: 1위 점수가 이 이상이고 …
  static const autoMin = 0.38;

  /// … 2위와의 차가 이 이상.
  static const autoMargin = 0.12;

  /// 이 아래면 "잘 못 알아들었어요" — 피커에 강조 없음.
  static const weak = 0.18;

  /// 동점 폭. 이 안이면 항상 피커(무작위 선택은 절대 없다).
  static const tie = 0.02;

  /// 반대 극성 벌점.
  static const polarityPenalty = 0.25;

  /// 입력 최대 길이. 넘는 부분은 자른다(2-gram 희석·말풍선 깨짐 방지).
  static const maxChars = 80;
}

// ---------------------------------------------------------------------------
// 정규화
// ---------------------------------------------------------------------------

/// 정규화 결과. [raw] 는 반복 압축·소문자화까지 한 원문(공백 유지), [compact] 는 공백·문장부호·이모지를
/// 뺀 것(ㅋㅋ 같은 자모는 남는다 — 사전 검사용), [body] 는 거기서 자모까지 뺀 본문(2-gram 용).
class NormText {
  final String raw;
  final String compact;
  final String body;

  /// [raw] 를 공백으로 나눈 낱말(문장부호 제거). 사전의 `^` 항목이 본다.
  final List<String> tokens;

  const NormText(this.raw, this.compact, this.body, this.tokens);

  bool get isEmpty => compact.isEmpty;
}

final _repeats = <(RegExp, String)>[
  (RegExp('ㅋ{3,}'), 'ㅋㅋ'),
  (RegExp('ㅎ{3,}'), 'ㅎㅎ'),
  (RegExp('[ㅠㅜ]{3,}'), 'ㅠㅠ'),
  (RegExp('!{2,}'), '!!'),
  (RegExp(r'\?{2,}'), '??'),
  (RegExp('[.…]{2,}'), '…'),
];

/// 본문에 남기는 글자: 한글 음절·라틴·숫자.
final _bodyChar = RegExp(r'[가-힣a-z0-9]', unicode: true);

/// 사전 검사용으로 남기는 글자: 본문 + 자모(ㅋㅋ·ㅇㅋ) + 하트.
final _compactChar = RegExp(r'[가-힣ㄱ-ㅎㅏ-ㅣa-z0-9♥❤💕]', unicode: true);

/// 낱말 안에서 지우는 문장부호.
final _punct = RegExp(r'''[^\s가-힣ㄱ-ㅎㅏ-ㅣa-z0-9♥❤💕]''', unicode: true);

/// 07 §1.1: NFC(호환 자모 → 음절 합성), 앞뒤 공백 제거, 라틴 소문자화, 반복 압축.
NormText norm(String s) {
  var t = composeHangul(s).trim().toLowerCase();
  for (final (re, to) in _repeats) {
    t = t.replaceAll(re, to);
  }
  final compact = _keep(t, _compactChar);
  final body = _keep(t, _bodyChar);
  final tokens = [
    for (final w in t.split(RegExp(r'\s+')))
      if (w.replaceAll(_punct, '').isNotEmpty) w.replaceAll(_punct, ''),
  ];
  return NormText(t, compact, body, tokens);
}

String _keep(String s, RegExp re) {
  final b = StringBuffer();
  for (final m in re.allMatches(s)) {
    b.write(m[0]);
  }
  return b.toString();
}

/// 조합형 자모(U+1100~)로 풀린 한글을 음절로 합친다(NFD → NFC 의 한글 부분만). iOS 키보드는
/// 완성형을 내지만 붙여넣기·외부 입력은 아닐 수 있다. 패키지 없이 이것만 처리한다.
String composeHangul(String s) {
  if (!s.codeUnits.any((u) => u >= 0x1100 && u <= 0x11FF)) return s;
  final out = <int>[];
  final u = s.codeUnits;
  var i = 0;
  while (i < u.length) {
    final l = u[i];
    if (l >= 0x1100 && l <= 0x1112 && i + 1 < u.length) {
      final v = u[i + 1];
      if (v >= 0x1161 && v <= 0x1175) {
        var t = 0;
        var n = 2;
        if (i + 2 < u.length && u[i + 2] >= 0x11A8 && u[i + 2] <= 0x11C2) {
          t = u[i + 2] - 0x11A7;
          n = 3;
        }
        out.add(0xAC00 + ((l - 0x1100) * 21 + (v - 0x1161)) * 28 + t);
        i += n;
        continue;
      }
    }
    out.add(l);
    i++;
  }
  return String.fromCharCodes(out);
}

/// 음절 2-gram 집합. 한 글자면 빈 집합.
Set<String> bigrams(String body) => {
  for (var i = 0; i + 1 < body.length; i++) body.substring(i, i + 2),
};

double dice(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  return 2 * a.intersection(b).length / (a.length + b.length);
}

double jaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  return a.intersection(b).length / a.union(b).length;
}

bool _endsWithAny(String s, List<String> ends) => ends.any(s.endsWith);

/// 음절 [cu] 의 종성 번호(0 = 없음). 한글이 아니면 -1.
int _jong(int cu) => cu >= 0xAC00 && cu <= 0xD7A3 ? (cu - 0xAC00) % 28 : -1;

/// 07 §1.2 `polite`: 존댓말 +1 / 반말 −1 / 그 외 0.
int politenessOf(String body) {
  if (body.isEmpty) return 0;
  if (_endsWithAny(body, FreeInputLexicon.politeEndings) ||
      FreeInputLexicon.politeTokens.any(body.contains)) {
    return 1;
  }
  if (_endsWithAny(body, FreeInputLexicon.casualEndings)) return -1;
  return 0;
}

/// 완성형 음절(U+AC00–D7A3) 수.
int syllableCount(String s) =>
    s.codeUnits.where((u) => u >= 0xAC00 && u <= 0xD7A3).length;

/// 호환 자모(ㄱ-ㅎ·ㅏ-ㅣ) 수.
int jamoCount(String s) =>
    s.codeUnits.where((u) => u >= 0x3131 && u <= 0x318E).length;

int latinCount(String s) =>
    s.codeUnits.where((u) => u >= 0x61 && u <= 0x7A).length;

/// "본문이 없는" 입력(07 §4 #3). 매칭 근거가 자모·문장부호뿐이라 어떤 후보도 자동 확정하면 안 된다 —
/// 결정은 기껏해야 피커(강조 없음).
///
/// 기기에서 본 경로: 한글 자판을 켠 채 영문처럼 두드린 `?ㅁㄱㄷ ㅃㅐㅕ ㄱㄷㅁㅣㅍ ㅁ 햐기` 가 본문 `햐기`(2-gram 1개)
/// + `?` 하나로 `ask` 태그를 얻어, 유일한 의문형 선택지 `ㄱㄱ 오늘 몇 시까지 함?` 과 태그 jaccard 1.0 → 0.40 으로
/// 자동 확정돼 호감이 올랐다. 그래서 두 조건 중 하나면 퇴화로 본다:
/// - 완성형 음절 2개 미만이고 라틴 3자 미만(자모·이모지·문장부호만).
/// - 음절이 2개 이하인데 자모가 음절보다 많다(우연히 조합된 한 낱말 + 자판 쓰레기).
bool isDegenerate(String raw) {
  final syl = syllableCount(raw);
  if (syl < 2 && latinCount(raw) < 3) return true;
  return syl <= 2 && jamoCount(raw) > syl;
}

/// 07 §1.2 `question`.
bool questionOf(NormText n) =>
    n.raw.contains('?') ||
    (n.body.isNotEmpty && _endsWithAny(n.body, FreeInputLexicon.questionEndings));

/// 07 §1.2 `lenBucket`: ≤4 / 5~15 / 16+.
int lenBucketOf(String body) => body.length <= 4
    ? 0
    : body.length <= 15
    ? 1
    : 2;

/// 07 §1.2 `action`: `(` 로 시작하거나 서술형 어미(`ㄴ다`·`했다`)로 끝난다.
/// 튜닝 추가: 음슴체(`…함`·`…임`·`…음`, 종성 ㅁ)도 행동 서술로 본다 — 픽스처 예문
/// "카운터에 종이 붙임" 이 행동형 후보를 찾는 입력이라서.
bool actionOf(NormText n) {
  if (n.raw.startsWith('(')) return true;
  final b = n.body;
  if (b.length < 2) return false;
  final last = b.codeUnitAt(b.length - 1);
  final prev = b.codeUnitAt(b.length - 2);
  if (b.endsWith('다') && (_jong(prev) == 4 || b.endsWith('했다'))) return true;
  return _jong(last) == 16 && b.length >= 3;
}

Set<String> emoOf(String raw) => {
  for (final e in FreeInputLexicon.emo.entries)
    if (e.value.any(raw.contains)) e.key,
};

/// 사전으로 태그를 뽑는다(07 §1.3). `^` 항목은 낱말 일치, `?` 항목은 질문일 때만, `!` 는 질문이 아닐 때만.
Set<String> tagsOf(NormText n, {required bool question}) {
  final out = <String>{};
  for (final e in FreeInputLexicon.tags.entries) {
    for (final p in e.value) {
      var pat = p;
      final needQ = pat.endsWith('?');
      final needNotQ = pat.endsWith('!');
      if (needQ || needNotQ) pat = pat.substring(0, pat.length - 1);
      if ((needQ && !question) || (needNotQ && question)) continue;
      if (pat.startsWith('^')) {
        if (n.tokens.contains(pat.substring(1))) {
          out.add(e.key);
          break;
        }
      } else if (n.compact.contains(pat)) {
        out.add(e.key);
        break;
      }
    }
  }
  // `?` 자체가 ask 항목이다(07 §1.3).
  if (question) out.add(Intent.ask);
  return out;
}

/// 금칙어(07 §4 #2). 강한 어간은 낱말 앞부분 일치(`씨발놈아`), 평범한 말에도 들어가는 어간
/// (`보지`·`자지`·`씹`)은 낱말 전체 일치만 — "운명인가 보지"·"읽씹" 이 걸리면 안 된다.
bool isBlocked(String text) {
  final n = norm(text);
  for (final t in n.tokens) {
    if (_blockedWord(t)) return true;
  }
  // 띄어쓰기로 쪼갠 변형(`씨 발`·`ㅅ ㅂ`). 한 글자짜리 낱말이 이어질 때만 도로 붙인다 —
  // 공백을 뺀 문장 전체를 보면 멀쩡한 낱말 둘이 붙어 없던 욕이 생긴다(04 P1-3).
  for (var i = 0; i < n.tokens.length; i++) {
    if (n.tokens[i].length != 1) continue;
    final run = StringBuffer(n.tokens[i]);
    for (var j = i + 1; j < n.tokens.length && n.tokens[j].length == 1; j++) {
      run.write(n.tokens[j]);
      if (_blockedWord(run.toString())) return true;
    }
  }
  return false;
}

/// 낱말 하나가 금칙인가. `새끼손가락`·`개새벽` 처럼 어간을 품은 멀쩡한 낱말은 먼저 뺀다.
bool _blockedWord(String w) {
  if (FreeInputLexicon.blockedAllow.any(w.startsWith)) return false;
  if (FreeInputLexicon.blockedPrefix.any(w.startsWith)) return true;
  return FreeInputLexicon.blockedExact.contains(w);
}

/// 통화 중 "끊을게"(07 §4 #7). 부정형(`안 끊을게`·`끊지 않고`)은 아니다.
bool isHangUp(NormText n) {
  final c = n.compact;
  if (FreeInputLexicon.hangUpNot.any(c.contains)) return false;
  return FreeInputLexicon.hangUp.any(c.contains);
}

// ---------------------------------------------------------------------------
// 입력 특징 · 선택지 서명
// ---------------------------------------------------------------------------

/// 07 §1.2. 입력 문장과 선택지 문구 모두 이걸로 본다.
class InputFeatures {
  final NormText text;
  final Set<String> grams;
  final int polite;
  final bool question;
  final int lenBucket;
  final Set<String> emo;
  final bool action;
  final Set<String> tags;

  /// 본문이 없는 입력([isDegenerate]). 자동 확정·확인 불가, 피커도 강조 없음.
  final bool degenerate;

  const InputFeatures({
    required this.text,
    required this.grams,
    required this.polite,
    required this.question,
    required this.lenBucket,
    required this.emo,
    required this.action,
    required this.tags,
    this.degenerate = false,
  });

  factory InputFeatures.from(String s) {
    final n = norm(s);
    final degenerate = isDegenerate(n.raw);
    // 퇴화 입력에서는 `?` 하나로 질문(ask)이 되지 않는다 — 의문 어미가 본문에 있을 때만.
    final q = degenerate
        ? n.body.isNotEmpty && _endsWithAny(n.body, FreeInputLexicon.questionEndings)
        : questionOf(n);
    // 자모(ㅋㅋ·ㅇㅋ)는 사전 태그로만 기여한다. 후보를 임계값 너머로 올리는 건 [decide] 가 막는다.
    return InputFeatures(
      text: n,
      grams: bigrams(n.body),
      polite: politenessOf(n.body),
      question: q,
      lenBucket: lenBucketOf(n.body),
      emo: emoOf(n.raw),
      action: actionOf(n),
      tags: tagsOf(n, question: q),
      degenerate: degenerate,
    );
  }

  /// 07 §4 #4: 두 문장 이상이면 마지막 문장만 매칭한다(결정은 보통 뒤에 온다). 말풍선은 전체.
  /// `.`·`!`·`?` 뒤에 공백이 있을 때만 문장 경계로 본다(`ㅋㅋ`·`…` 은 아님). 마지막 조각이
  /// 너무 짧으면(본문 4자 미만) 전체를 쓴다.
  static String lastSentence(String s) {
    final parts = s.split(RegExp(r'(?<=[.!?])\s+'));
    if (parts.length < 2) return s;
    final last = parts.last.trim();
    return norm(last).body.length >= 4 ? last : s;
  }
}

/// 07 §1.4. 런타임에 만들고 이벤트별로 캐시한다([FreeInputMatcher]).
class ChoiceSignature {
  final Set<String> textGrams;
  final Set<String> replyGrams;

  /// 문구 ∪ 효과 ∪ `intent` 태그. 의도 일치(jaccard)에 쓴다.
  final Set<String> tags;

  /// 문구(와 `intent`)에서만 뽑은 태그. 극성 벌점은 이것만 본다 — 효과에서 유도한 passive·refuse 는
  /// 추론이라, "내가"·"바꿔" 로 assert 가 붙은 입력과 맞부딪히면 좋은 문구 일치까지 깎아 먹는다.
  final Set<String> textTags;
  final int polite;
  final bool question;
  final int lenBucket;
  final bool action;

  /// 정규화한 문구 본문. 자기 회수(입력 == 문구) 판정용.
  final String body;

  const ChoiceSignature({
    required this.textGrams,
    required this.replyGrams,
    required this.tags,
    required this.textTags,
    required this.polite,
    required this.question,
    required this.lenBucket,
    required this.action,
    required this.body,
  });

  /// 서명이 사실상 비었는지(본문 2-gram ≤ 2 이고 태그 0). tool/intent_report.py 의 EMPTY 와 같은 기준.
  bool get isEmpty => textGrams.length <= 2 && tags.isEmpty;

  /// [text]·[replyLines]·[effects] 를 주지 않으면 [choice] 의 것. [say] 는 `{name|…}` 치환
  /// (컨트롤러의 `say`). 없으면 이름 없이 기본 대체어로 채운다.
  factory ChoiceSignature.build(
    Choice choice, {
    String? text,
    List<Line>? replyLines,
    Effects? effects,
    String Function(String)? say,
  }) {
    final fill = say ?? (String s) => TextTemplate.fill(s);
    final t = _stripQuotes(fill(text ?? choice.text));
    final n = norm(t);
    final q = questionOf(n);
    final tags = tagsOf(n, question: q);
    final replies =
        replyLines ??
        [
          for (final l in [...choice.reply, ...choice.critReply])
            if (l.who == 'them' || l.who == 'narr') l,
        ];
    // 튜닝: 반응 줄은 2-gram 만 쓰고 태그는 뽑지 않는다(07 §1.4 (a) 에서 반응 줄 부분을 뺐다).
    // 상대 반응에는 ㅋㅋ·?·"아니" 가 흔해서 joke·ask·refuse 가 거의 모든 후보에 붙고, 그러면
    // 의도 일치가 뭉개지고 극성 벌점이 엉뚱하게 터진다(픽스처 top-1 78% → 뺀 뒤 84%).
    final replyGrams = <String>{};
    for (final l in replies) {
      replyGrams.addAll(bigrams(norm(fill(l.text)).body));
    }
    // 선택 필드 `intent`: 플레이어가 칠 법한 짧은 표현. 문구 2-gram 과 태그에 합친다(07 §2).
    final textGrams = bigrams(n.body);
    for (final s in choice.intent) {
      final inn = norm(s);
      final ig = bigrams(inn.body);
      textGrams.addAll(ig);
      replyGrams.addAll(ig.isEmpty ? {inn.body} : ig);
      tags.addAll(tagsOf(inn, question: questionOf(inn)));
    }
    final textTags = Set.of(tags);
    tags.addAll(tagsFromEffects(effects ?? choice.effects, decline: choice.decline));
    return ChoiceSignature(
      textGrams: textGrams,
      replyGrams: replyGrams,
      tags: tags,
      textTags: textTags,
      polite: politenessOf(n.body),
      question: q,
      lenBucket: lenBucketOf(n.body),
      action: actionOf(n),
      body: n.body,
    );
  }

  /// 07 §1.4 효과 유도 규칙. 선택지 40% 가 행동문이라 문구만으로는 태도를 못 읽는다.
  static Set<String> tagsFromEffects(Effects e, {bool decline = false}) {
    final out = <String>{};
    int stat(String k) => e.stats[k] ?? 0;
    if (e.affection.values.any((v) => v < 0)) {
      out.addAll([Intent.refuse, Intent.passive]);
    }
    if (stat(Stat.sincerity) > 0) out.add(Intent.honest);
    if (stat(Stat.sincerity) < 0) out.add(Intent.passive);
    if (stat(Stat.esteem) > 0) out.add(Intent.assert_);
    if (stat(Stat.stress) < 0) out.addAll([Intent.passive, Intent.delay]);
    if (stat(Stat.money) < 0) out.add(Intent.love);
    // 튜닝: 07 §1.4 는 reputation>0 → joke·agree 인데 agree 는 뺐다(평판이 오르는 선택 대부분은
    // "동의" 가 아니라 "재치·나섬" 이라 agree 가 붙으면 응·네 입력이 온 데 걸린다). 대칭으로
    // reputation<0 → passive(소극·어색) 를 추가했다.
    if (stat(Stat.reputation) > 0) out.add(Intent.joke);
    if (stat(Stat.reputation) < 0) out.add(Intent.passive);
    if (decline) out.add(Intent.refuse);
    if (e.setFlags.any((f) => f.endsWith('_dm_first') || f.contains('_confess'))) {
      out.add(Intent.love);
    }
    return out;
  }

  /// 괄호·따옴표는 문구의 일부가 아니다(`(조용히 캡처하고 모른 척한다)`, `"너보다 먼저 알았어"`).
  static String _stripQuotes(String s) => s.replaceAll(RegExp(r'''["'“”‘’()（）\[\]]'''), '');
}

// ---------------------------------------------------------------------------
// 매칭
// ---------------------------------------------------------------------------

/// 07 §1.6 + §4. `auto`·`confirm`·`locked`·`pick` 는 점수에서, `empty`·`blocked`·`hangUp` 은 점수 전에.
enum MatchDecision {
  /// 1위로 바로 확정.
  auto,

  /// 1위가 `chance`·`minigame` — 확인 한 번.
  confirm,

  /// 1위가 `require` 로 잠김 — 확정하지 않고 "아직 못 하는 말" 안내. 턴 소모 없음.
  locked,

  /// "이런 뜻이에요?" 피커.
  pick,

  /// 본문이 없다(빈 문자열·이모지·자음만). 안내만.
  empty,

  /// 금칙어. 매핑·저장·기록 없음.
  blocked,

  /// 통화 중 "끊을게". 거절 경로 안내.
  hangUp,
}

/// 후보 하나의 점수.
class ChoiceScore {
  final ChoiceView view;
  final double score;

  /// 입력 본문이 문구 본문과 같다(선택지를 그대로 침).
  final bool exact;

  /// 입력이 문구를 통째로 품었다("고양이 사진" → "고양이 사진으로 할게").
  /// 선택지를 그대로 적고 말끝만 붙인 경우라 확인을 한 번 더 묻지 않는다(01 D-4).
  final bool near;

  const ChoiceScore(this.view, this.score, {this.exact = false, this.near = false});

  int get index => view.index;
}

class MatchResult {
  /// 매칭에 쓴 원문(앞뒤 공백·길이 정리 뒤).
  final String text;
  final InputFeatures? input;

  /// 점수순. 동점은 원래 순서(무작위 없음).
  final List<ChoiceScore> ranked;
  final MatchDecision decision;

  const MatchResult({
    required this.text,
    required this.input,
    required this.ranked,
    required this.decision,
  });

  ChoiceScore? get top => ranked.isEmpty ? null : ranked.first;
  double get s1 => ranked.isEmpty ? 0 : ranked.first.score;
  double get s2 => ranked.length < 2 ? 0 : ranked[1].score;
  double get margin => s1 - s2;

  /// 피커에 강조 없음(잘 못 알아들었다). 퇴화 입력은 점수와 무관하게 약하다.
  bool get weak => (input?.degenerate ?? false) || s1 < FreeInputThresholds.weak;

  /// 점수순 상위 [n] 개의 선택지 index.
  List<int> topIndices(int n) => [for (final s in ranked.take(n)) s.index];

  /// [index] 의 점수 순위(0부터). 없으면 -1.
  int rankOf(int index) => ranked.indexWhere((s) => s.index == index);
}

/// 서명 캐시 + 매칭. 컨트롤러가 인스턴스 하나를 들고 이벤트마다 [signaturesFor] 로 캐시한다.
class FreeInputMatcher {
  String? _cacheKey;
  Map<int, ChoiceSignature> _cache = const {};

  /// [key] 가 바뀌면 다시 만든다(이벤트 id + 보이는 인덱스 + 이름).
  Map<int, ChoiceSignature> signaturesFor(
    String key,
    List<ChoiceView> views, {
    String Function(String)? say,
  }) {
    if (_cacheKey == key) return _cache;
    _cache = {
      for (final v in views) v.index: ChoiceSignature.build(v.choice, say: say),
    };
    _cacheKey = key;
    return _cache;
  }

  /// 점수 하나(07 §1.5).
  static double score(InputFeatures i, ChoiceSignature c) {
    final textW = i.action && c.action ? 0.50 : 0.40;
    var s =
        textW * dice(i.grams, c.textGrams) +
        0.15 * dice(i.grams, c.replyGrams) +
        0.35 * jaccard(i.tags, c.tags) +
        0.10 * style(i, c);
    // 극성 벌점은 후보의 문구 태그([ChoiceSignature.textTags])만 본다.
    // 입력이 양쪽을 다 가지면("이건 아니지, 다시 찍자") 극성이 없는 것으로 본다.
    final ct = c.textTags;
    for (final (a, b) in Intent.opposites) {
      if (i.tags.contains(a) && i.tags.contains(b)) continue;
      final flip =
          (i.tags.contains(a) && ct.contains(b) && !ct.contains(a)) ||
          (i.tags.contains(b) && ct.contains(a) && !ct.contains(b));
      if (flip) s -= FreeInputThresholds.polarityPenalty;
    }
    return s;
  }

  /// 문체 일치 0~1. 행동형 후보에는 polite 를 0점 처리한다(07 §1.7 ④ — 존댓말로 친 행동 서술에 벌점 없음).
  static double style(InputFeatures i, ChoiceSignature c) {
    var s = 0.0;
    if (!c.action && i.polite == c.polite) s += 0.5;
    if (i.question == c.question) s += 0.3;
    if ((i.lenBucket - c.lenBucket).abs() <= 1) s += 0.2;
    return s;
  }

  /// [visible] 은 보이는 선택지(`GameController.choices`). [inCall] 이면 `decline` 은 후보에서 뺀다.
  /// [forcePick] 은 무료 되돌리기 뒤 재시도(자동 확정 금지). [signatures] 를 주면 캐시를 안 거친다.
  MatchResult match(
    String text,
    List<ChoiceView> visible, {
    bool inCall = false,
    bool forcePick = false,
    Map<int, ChoiceSignature>? signatures,
    String Function(String)? say,
    String? cacheKey,
  }) {
    var t = text.trim();
    if (t.length > FreeInputThresholds.maxChars) {
      t = t.substring(0, FreeInputThresholds.maxChars);
    }
    final cands = [
      for (final v in visible)
        if (!(inCall && v.choice.decline)) v,
    ];
    if (isBlocked(t)) {
      return MatchResult(text: t, input: null, ranked: const [], decision: MatchDecision.blocked);
    }
    final input = InputFeatures.from(InputFeatures.lastSentence(t));
    // 자기 회수: 두 문장짜리 선택지("정했겠지. 누구 들으라고?")를 그대로 치면 마지막 문장 규칙보다 앞선다.
    final fullBody = norm(t).body;
    if (input.text.isEmpty || cands.isEmpty) {
      return MatchResult(text: t, input: input, ranked: const [], decision: MatchDecision.empty);
    }
    if (inCall && isHangUp(input.text)) {
      return MatchResult(text: t, input: input, ranked: const [], decision: MatchDecision.hangUp);
    }
    final sigs =
        signatures ??
        signaturesFor(
          cacheKey ?? cands.map((v) => v.index).join(','),
          cands,
          say: say,
        );
    final scored = <ChoiceScore>[
      for (final v in cands)
        if (sigs[v.index] case final sig?)
          ChoiceScore(
            v,
            score(input, sig),
            exact: sig.body.isNotEmpty && (sig.body == input.text.body || sig.body == fullBody),
            near: _near(sig.body, input.text.body) || _near(sig.body, fullBody),
          ),
    ];
    // 안정 정렬: 동점은 원래 순서. 정확 일치가 맨 앞, 그 다음이 통째로 품은 문구.
    final ranked = List.of(scored)
      ..sort((a, b) {
        if (a.exact != b.exact) return a.exact ? -1 : 1;
        if (a.near != b.near) return a.near ? -1 : 1;
        final d = b.score.compareTo(a.score);
        return d != 0 ? d : a.index.compareTo(b.index);
      });
    return MatchResult(
      text: t,
      input: input,
      ranked: ranked,
      decision: decide(input, ranked, forcePick: forcePick),
    );
  }

  /// "선택지를 그대로 적고 말끝만 붙였다" 판정. 문구가 입력 안에 통째로 들어 있고,
  /// 입력의 절반 이상을 차지해야 한다 — 짧은 문구(`응`)가 아무 문장에나 걸리면 안 된다.
  static bool _near(String choiceBody, String inputBody) =>
      choiceBody.length >= 4 &&
      choiceBody != inputBody &&
      inputBody.contains(choiceBody) &&
      choiceBody.length * 2 >= inputBody.length;

  /// 07 §1.6 표.
  static MatchDecision decide(
    InputFeatures input,
    List<ChoiceScore> ranked, {
    bool forcePick = false,
  }) {
    if (ranked.isEmpty) return MatchDecision.empty;
    // 본문이 없는 입력은 기껏해야 피커(07 §4 #3, [isDegenerate]). 정확 일치보다 먼저 본다.
    if (input.degenerate) return MatchDecision.pick;
    // 2-gram 이 없는 한 글자 입력은 억지 확정하지 않는다.
    if (input.grams.isEmpty && !ranked.first.exact) return MatchDecision.pick;
    final top = ranked.first;
    final s1 = top.score;
    final s2 = ranked.length > 1 ? ranked[1].score : 0.0;
    // 선택지를 그대로 적고 말끝만 붙인 입력(01 D-4). 그런 후보가 둘이면 고를 수 없으니
    // 평소대로 피커로 간다.
    final onlyNear = top.near && !(ranked.length > 1 && ranked[1].near);
    final confident =
        top.exact ||
        onlyNear ||
        (s1 >= FreeInputThresholds.autoMin &&
            s1 - s2 >= FreeInputThresholds.autoMargin &&
            s1 - s2 >= FreeInputThresholds.tie);
    if (!confident) return MatchDecision.pick;
    if (top.view.locked) return MatchDecision.locked;
    if (forcePick) return MatchDecision.pick;
    final ch = top.view.choice;
    if (ch.chance != null || ch.minigame != null) return MatchDecision.confirm;
    return MatchDecision.auto;
  }
}
