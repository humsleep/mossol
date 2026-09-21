/// 플레이어 MBTI 분기 도구. 규격은 docs/MBTI_SPEC.md.
///
/// - 유형: 대문자 4글자(`INTJ`). 모름·건너뜀은 null — null 도 정상 경로다.
/// - 조건 글자열(`"I"`, `"NF"`, `"ESTJ"`): 적힌 글자가 모두 플레이어 유형에 있어야 참,
///   플레이어가 null 이면 항상 거짓([Mbti.matches]).
/// - 궁합([Mbti.compat]): 0~4. 플레이어나 캐릭터가 null 이면 2(보통).
/// - 거르기([MbtiFilter.forMbti]): 줄·선택지·반응 줄의 `mbti`/`noMbti`/`compat` 을 보고
///   화면에 낼 사본을 만든다. 조건이 하나도 없는 이벤트는 원본을 그대로 돌려준다.
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

  /// 줄·선택지 하나의 조건이 이 플레이어에게 열리는지.
  /// [compatScore] 는 이벤트 캐릭터와의 궁합 점수.
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

/// 한 이벤트를 볼 플레이어: MBTI 와 그 이벤트 캐릭터와의 궁합 점수.
class MbtiView {
  final String? player;
  final int compat;

  const MbtiView(this.player, {this.compat = Mbti.neutralCompat});

  /// [player] 와 캐릭터 MBTI [characterMbti] 로 만든다.
  factory MbtiView.of(String? player, String? characterMbti) =>
      MbtiView(player, compat: Mbti.compat(player, characterMbti));

  bool allowsLine(Line l) => Mbti.allows(
    player: player,
    compatScore: compat,
    mbti: l.mbti,
    noMbti: l.noMbti,
    compat: l.compat,
  );

  bool allowsChoice(Choice c) => Mbti.allows(
    player: player,
    compatScore: compat,
    mbti: c.mbti,
    noMbti: c.noMbti,
    compat: c.compat,
  );

  List<Line> lines(List<Line> ls) => ls.any((l) => l.isGated)
      ? [
          for (final l in ls)
            if (allowsLine(l)) l,
        ]
      : ls;
}

extension MbtiFilter on StoryEvent {
  /// 줄·선택지·반응 줄 중 MBTI·궁합 조건이 붙은 것이 있는지.
  bool get hasMbtiGates =>
      lines.any((l) => l.isGated) ||
      choices.any(
        (c) =>
            c.isGated ||
            c.reply.any((l) => l.isGated) ||
            c.failReply.any((l) => l.isGated) ||
            c.critReply.any((l) => l.isGated),
      );

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
