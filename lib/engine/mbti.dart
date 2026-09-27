/// 플레이어 MBTI 분기 도구. 규격은 docs/MBTI_SPEC.md.
///
/// - 유형: 대문자 4글자(`INTJ`). 모름·건너뜀은 null — null 도 정상 경로다.
/// - 조건 글자열(`"I"`, `"NF"`, `"ESTJ"`): 적힌 글자가 모두 플레이어 유형에 있어야 참,
///   플레이어가 null 이면 항상 거짓([Mbti.matches]).
/// - 궁합([Mbti.compat]): 0~4. 플레이어나 캐릭터가 null 이면 2(보통).
/// - 거르기([MbtiFilter.forMbti]): 줄·선택지·반응 줄의 조건을 보고 화면에 낼 사본을 만든다.
///   조건이 하나도 없는 이벤트는 원본을 그대로 돌려준다.
///
/// 조건은 **축 두 개**다. 이 파일이 둘 다 맡는 이유는 거르는 곳이 한 곳이기 때문이다.
///
/// | 축 | 필드 | 보는 것 |
/// |---|---|---|
/// | 플레이어 | `mbti` · `noMbti` · `compat` | 이 회차 플레이어의 MBTI, 이벤트 캐릭터와의 궁합 |
/// | 상대 목소리 | `humor` · `register` | **호감 1위**([MbtiView.humor] · [MbtiView.politeness]) |
///
/// 상대 축은 `character` 가 없는 씬(고백·첫 싸움·화해처럼 12명 중 누구와도 열리는 장면)을 위해
/// 있다. 자세한 사정은 docs/review/13_engine_fixes.md, 요청 원문은 12_main_rewrite.md §5.3.
library;

import 'models.dart';

class Mbti {
  Mbti._();

  /// 축 순서대로 두 글자씩: E/I, S/N, T/F, J/P.
  static const axes = ['EI', 'SN', 'TF', 'JP'];

  /// 플래그 이름에 쓰는 축 키(`<id>_mbti_<axis>`).
  static const axisKeys = ['ei', 'sn', 'tf', 'jp'];

  static const letters = 'EISNTFJP';

  /// 16유형. 축 순서대로 앞 글자부터(ESTJ … INFP).
  static final List<String> types = List.unmodifiable([
    for (final a in axes[0].split(''))
      for (final b in axes[1].split(''))
        for (final c in axes[2].split(''))
          for (final d in axes[3].split('')) '$a$b$c$d',
  ]);

  /// 검증·시뮬레이터가 도는 플레이어 경우 17가지(모름 null + 16유형).
  static final List<String?> playerCases = List.unmodifiable([null, ...types]);

  /// 기질 네 가지. 에필로그 덧붙임(`epilogueMbti`)의 키.
  static const temperaments = ['NT', 'NF', 'SJ', 'SP'];

  /// 궁합 점수 없음(플레이어·캐릭터 중 하나가 null)일 때의 값.
  static const neutralCompat = 2;
  static const maxCompat = 4;

  /// 점수(0~4)별 라벨. 인덱스 = 점수.
  static const compatLabels = ['정반대', '노력하면', '무난해요', '잘 맞아요', '천생연분'];

  /// 대문자 4글자로. 틀리거나 없으면 null.
  static String? parse(Object? v) => parseMbtiType(v);

  static bool isType(String? v) => v != null && parse(v) == v;

  /// 글자 [letter] 의 축 번호(0~3). 모르는 글자면 -1.
  static int axisOf(String letter) {
    for (var i = 0; i < axes.length; i++) {
      if (axes[i].contains(letter)) return i;
    }
    return -1;
  }

  /// 조건 글자열의 문제. 정상이면 null.
  static String? conditionProblem(String cond) {
    if (cond.isEmpty) return '빈 mbti 조건';
    final used = <int, String>{};
    for (final ch in cond.split('')) {
      final axis = axisOf(ch);
      if (axis < 0) return '모르는 글자 "$ch" (E I S N T F J P 만)';
      final prev = used[axis];
      if (prev != null) return '같은 축 두 글자 "$prev$ch"';
      used[axis] = ch;
    }
    return null;
  }

  /// 조건 [cond] 의 글자가 모두 [player] 에 있는지. [player] 가 null 이면 거짓.
  static bool matches(String cond, String? player) {
    if (player == null) return false;
    for (final ch in cond.split('')) {
      if (!player.contains(ch)) return false;
    }
    return true;
  }

  /// 기질: N+T=NT, N+F=NF, S+J=SJ, S+P=SP. [player] 가 null 이면 null.
  static String? temperament(String? player) {
    if (player == null || player.length != 4) return null;
    if (player[1] == 'N') return player[2] == 'T' ? 'NT' : 'NF';
    return player[3] == 'J' ? 'SJ' : 'SP';
  }

  /// 궁합 점수 0~4. `(S/N 같음 ? 2 : 0) + (E/I 다름 ? 1 : 0) + (J/P 다름 ? 1 : 0)`.
  /// 둘 중 하나라도 null 이면 [neutralCompat].
  static int compat(String? player, String? character) {
    if (player == null || character == null) return neutralCompat;
    if (player.length != 4 || character.length != 4) return neutralCompat;
    return (player[1] == character[1] ? 2 : 0) +
        (player[0] != character[0] ? 1 : 0) +
        (player[3] != character[3] ? 1 : 0);
  }

  /// 조건 [t] 의 MBTI 부분(`mbti`·`noMbti`·`compat`)을 만족하는 플레이어 경우([playerCases] 순).
  /// `compat` 은 [characterMbti] 와의 궁합으로 본다. 테스트·디버그가 조건에 맞는 회차를 만들 때 쓴다.
  static Iterable<String?> playersFor(Trigger t, {String? characterMbti}) =>
      playerCases.where((p) {
        final m = t.mbti;
        if (m != null && !matches(m, p)) return false;
        if (t.noMbti && p != null) return false;
        final c = t.compat;
        if (c != null && !c.contains(compat(p, characterMbti))) return false;
        return true;
      });

  static String compatLabel(int score) =>
      compatLabels[score.clamp(0, maxCompat)];

  /// 줄·선택지 하나의 **플레이어 축** 조건이 이 회차에 열리는지.
  /// [compatScore] 는 이벤트 캐릭터와의 궁합 점수. 상대 축은 [MbtiView._allowsVoice].
  static bool allows({
    required String? player,
    required int compatScore,
    String? mbti,
    bool noMbti = false,
    Range? compat,
  }) {
    if (noMbti && player != null) return false;
    if (mbti != null && !matches(mbti, player)) return false;
    if (compat != null && !compat.contains(compatScore)) return false;
    return true;
  }
}

/// 한 이벤트를 **지금 화면에 낼 시점**: 플레이어(MBTI·궁합)와 상대 목소리(1위의 농담 코드·말높임).
///
/// 이름은 처음 MBTI 만 보던 때 그대로 두었다 — 거르는 자리가 한 곳이라 여기에 축을 더하는 것이
/// 두 번째 거르개를 만드는 것보다 안전하다(빠뜨릴 자리가 늘지 않는다).
class MbtiView {
  final String? player;
  final int compat;

  /// 호감 1위의 농담 코드. 1위가 없으면 [Humor.fallback] — `{top}` 이 "그 사람" 이 되는 회차다.
  /// 기본값을 두는 이유: 그래야 `humor` 조건이 **전함수**가 되어 다섯 값만 덮으면 빈 화면이 없다.
  final String humor;

  /// 호감 1위의 말높임. 1위가 없으면 [Politeness.casual](12명 중 9명).
  final String politeness;

  const MbtiView(
    this.player, {
    this.compat = Mbti.neutralCompat,
    this.humor = Humor.fallback,
    this.politeness = Politeness.casual,
  });

  /// [player] 와 캐릭터 MBTI [characterMbti], 그리고 이 씬에서 말하는 상대 [voice] 로 만든다.
  /// [voice] 는 `{top}` 이 이름을 꺼내는 바로 그 사람이어야 한다(`EventEngine.voiceOf`) —
  /// 말풍선 머리에 "지우" 라고 찍히면서 대사를 서연 몫으로 고르면 안 된다.
  factory MbtiView.of(
    String? player,
    String? characterMbti, {
    CharacterDef? voice,
  }) => MbtiView(
    player,
    compat: Mbti.compat(player, characterMbti),
    humor: switch (voice?.humor) {
      final String h when h.isNotEmpty => h,
      _ => Humor.fallback,
    },
    politeness: voice?.politeness ?? Politeness.casual,
  );

  /// 상대 축 조건. 빈 목록·null 은 조건 없음.
  bool _allowsVoice(List<String> humorCond, String? register) {
    if (humorCond.isNotEmpty && !humorCond.contains(humor)) return false;
    if (register != null && register != politeness) return false;
    return true;
  }

  bool allowsLine(Line l) =>
      Mbti.allows(
        player: player,
        compatScore: compat,
        mbti: l.mbti,
        noMbti: l.noMbti,
        compat: l.compat,
      ) &&
      _allowsVoice(l.humor, l.register);

  bool allowsChoice(Choice c) =>
      Mbti.allows(
        player: player,
        compatScore: compat,
        mbti: c.mbti,
        noMbti: c.noMbti,
        compat: c.compat,
      ) &&
      _allowsVoice(c.humor, c.register);

  List<Line> lines(List<Line> ls) => ls.any((l) => l.isGated)
      ? [
          for (final l in ls)
            if (allowsLine(l)) l,
        ]
      : ls;
}

extension MbtiFilter on StoryEvent {
  /// 줄·선택지·반응 줄 중 [onLine]·[onChoice] 에 걸리는 것이 있는지.
  /// 변형 대사([StoryEvent.variants])도 본다 — 검증기가 변형 묶음까지 덮어야 하기 때문이다.
  bool _anyGate(bool Function(Line) onLine, bool Function(Choice) onChoice) =>
      lines.any(onLine) ||
      variants.any((v) => v.any(onLine)) ||
      choices.any(
        (c) =>
            onChoice(c) ||
            c.reply.any(onLine) ||
            c.failReply.any(onLine) ||
            c.critReply.any(onLine),
      );

  /// 조건이 붙은 줄·선택지가 하나라도 있는지.
  bool get hasMbtiGates => _anyGate((l) => l.isGated, (c) => c.isGated);

  /// 플레이어 축(`mbti`·`noMbti`·`compat`) 조건이 있는지.
  bool get hasPlayerGates =>
      _anyGate((l) => l.isPlayerGated, (c) => c.isPlayerGated);

  /// 상대 축(`humor`·`register`) 조건이 있는지.
  bool get hasVoiceGates =>
      _anyGate((l) => l.isVoiceGated, (c) => c.isVoiceGated);

  /// [v] 플레이어에게 보이는 사본. 맞지 않는 줄·선택지·반응 줄을 빼고, 힌트 인덱스를
  /// 남은 선택지 기준으로 다시 맞춘다(힌트 선택지가 빠지면 null). 조건이 없으면 원본.
  ///
  /// 선택지 인덱스는 **거른 뒤** 목록 기준이다. 화면·컨트롤러는 거른 사본만 쓰고, 엔진은
  /// 원본을 받아도 [EventEngine.choicesFor] 가 원래 인덱스로 거른 목록을 돌려준다.
  StoryEvent forMbti(MbtiView v) {
    if (!hasMbtiGates) return this;
    final keep = <Choice>[];
    int? hintOut;
    for (var i = 0; i < choices.length; i++) {
      final c = choices[i];
      if (!v.allowsChoice(c)) continue;
      if (i == hint) hintOut = keep.length;
      keep.add(
        c.withReplies(
          reply: v.lines(c.reply),
          failReply: v.lines(c.failReply),
          critReply: v.lines(c.critReply),
        ),
      );
    }
    return withContent(lines: v.lines(lines), choices: keep, hint: hintOut);
  }
}
