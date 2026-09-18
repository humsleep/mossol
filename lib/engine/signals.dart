import 'dart:convert';

/// 서사 신호. 호감 숫자 대신 "예은이 프사를 바꿨다" 같은 한 줄로 관계 진전을 보여 준다.
///
/// 데이터는 `assets/story/signals.json`(선택). 파일이 없거나 비면 [SignalBook.empty] 이고,
/// 그때 UI 는 신호 없이 예전처럼 숫자를 보여 준다.
///
/// ```json
/// {"characters": {"yeeun": {
///   "bands": [{"min": 1, "max": 9, "lines": ["…", "…", "…"]}, …, {"min": 90, "max": 100, …}],
///   "down": ["…", "…"]
/// }}}
/// ```
///
/// 규칙(검증기가 잡는다): 캐릭터 id 는 characters.json 에 있어야 하고, 구간은 1~100 을
/// 빈칸·겹침 없이 오름차순으로 덮는다. 문장은 비어 있지 않고 [maxLength]자 이내.
/// 호감 0 은 어느 구간에도 속하지 않는다 — 아직 아무 신호도 없다(히든 도윤 포함).
class SignalBand {
  final int min;
  final int max;
  final List<String> lines;

  const SignalBand({required this.min, required this.max, required this.lines});

  bool contains(int affection) => affection >= min && affection <= max;

  factory SignalBand.fromJson(Map<String, dynamic> j) => SignalBand(
    min: ((j['min'] as num?) ?? 0).toInt(),
    max: ((j['max'] as num?) ?? 0).toInt(),
    lines: [for (final l in (j['lines'] as List?) ?? const []) l as String],
  );
}

/// 캐릭터 한 명의 신호 묶음.
class CharacterSignals {
  final List<SignalBand> bands;

  /// 구간이 내려간 날의 조용한 문장("요즘 답이 늦다").
  final List<String> down;

  const CharacterSignals({this.bands = const [], this.down = const []});

  factory CharacterSignals.fromJson(Map<String, dynamic> j) => CharacterSignals(
    bands: [
      for (final b in (j['bands'] as List?) ?? const [])
        SignalBand.fromJson(b as Map<String, dynamic>),
    ],
    down: [for (final l in (j['down'] as List?) ?? const []) l as String],
  );
}

/// 하루 동안 한 캐릭터의 호감 구간이 바뀐 것. 정산의 "관계 변화" 카드 한 장.
class RelationShift {
  final String id;

  /// 하루 시작 때 호감과 지금 호감.
  final int from;
  final int to;

  /// 구간 번호. 호감 0(구간 없음)은 -1.
  final int fromBand;
  final int toBand;

  /// 카드에 띄울 문장. 상승이면 새 구간의 신호, 하강이면 하강 신호.
  final String text;

  const RelationShift({
    required this.id,
    required this.from,
    required this.to,
    required this.fromBand,
    required this.toBand,
    required this.text,
  });

  bool get up => toBand > fromBand;
}

class SignalBook {
  final Map<String, CharacterSignals> byCharacter;

  const SignalBook(this.byCharacter);

  static const empty = SignalBook({});

  /// 문장 최대 길이(글자). 홈 카드 두 줄에 들어가야 한다.
  static const maxLength = 40;

  bool get isEmpty => byCharacter.isEmpty;

  /// null·빈 문자열·`{}` 는 빈 책. 형식이 틀리면 예외(다른 스토리 데이터와 같다).
  factory SignalBook.fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    final j = jsonDecode(raw);
    if (j is! Map<String, dynamic>) {
      throw const FormatException('signals.json 은 객체여야 한다');
    }
    final chars = j['characters'];
    if (chars == null) return empty;
    if (chars is! Map<String, dynamic>) {
      throw const FormatException('signals.json 의 characters 는 객체여야 한다');
    }
    return SignalBook({
      for (final e in chars.entries)
        e.key: CharacterSignals.fromJson(e.value as Map<String, dynamic>),
    });
  }

  /// [affection] 이 속한 구간 번호. 0 이하·데이터 없음·구간 밖이면 -1.
  int bandIndex(String id, int affection) {
    if (affection <= 0) return -1;
    final bands = byCharacter[id]?.bands ?? const <SignalBand>[];
    for (var i = 0; i < bands.length; i++) {
      if (bands[i].contains(affection)) return i;
    }
    return -1;
  }

  /// 지금 호감에 맞는 신호 한 줄. 호감 0(히든 미해금 포함)이나 데이터가 없으면 null.
  /// 같은 (seed, day, 캐릭터) 면 몇 번을 불러도 같은 문장이다.
  String? signalFor(
    String id,
    int affection, {
    required int seed,
    required int day,
  }) {
    final i = bandIndex(id, affection);
    if (i < 0) return null;
    final lines = byCharacter[id]!.bands[i].lines;
    if (lines.isEmpty) return null;
    return lines[pickIndex(lines.length, seed: seed, day: day, id: id)];
  }

  /// 구간이 내려간 날의 문장. 없으면 null.
  String? downSignalFor(String id, {required int seed, required int day}) {
    final lines = byCharacter[id]?.down ?? const <String>[];
    if (lines.isEmpty) return null;
    return lines[pickIndex(lines.length, seed: seed, day: day, id: '$id:down')];
  }

  /// [from] → [to] 로 구간이 바뀌었으면 그 변화. 같은 구간이거나 문장이 없으면 null.
  RelationShift? shiftFor(
    String id,
    int from,
    int to, {
    required int seed,
    required int day,
  }) {
    final a = bandIndex(id, from);
    final b = bandIndex(id, to);
    if (a == b) return null;
    final text = b > a
        ? signalFor(id, to, seed: seed, day: day)
        : downSignalFor(id, seed: seed, day: day);
    if (text == null) return null;
    return RelationShift(
      id: id,
      from: from,
      to: to,
      fromBand: a,
      toBand: b,
      text: text,
    );
  }

  /// seed ^ day ^ 캐릭터 해시를 섞어 [n] 개 중 하나. 플랫폼·실행에 무관하게 같다.
  static int pickIndex(
    int n, {
    required int seed,
    required int day,
    required String id,
  }) {
    if (n <= 1) return 0;
    var h = (seed ^ day ^ _fnv(id)) & 0xffffffff;
    // 이웃한 날짜가 같은 칸에 몰리지 않게 한 번 더 섞는다(murmur3 finalizer).
    h ^= h >> 16;
    h = (h * 0x85EBCA6B) & 0xffffffff;
    h ^= h >> 13;
    h = (h * 0xC2B2AE35) & 0xffffffff;
    h ^= h >> 16;
    return h % n;
  }

  static int _fnv(String s) {
    var h = 0x811C9DC5;
    for (final u in s.codeUnits) {
      h ^= u & 0xff;
      h = (h * 0x01000193) & 0xffffffff;
      h ^= u >> 8;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// 데이터 검사. 문제가 있으면 [StateError].
  void validate(Set<String> characterIds) {
    void checkLine(String l, String where) {
      if (l.trim().isEmpty) throw StateError('signals 빈 문장: $where');
      final n = l.runes.length;
      if (n > maxLength) {
        throw StateError('signals 문장이 $maxLength자 초과($n자): $where "$l"');
      }
    }

    for (final e in byCharacter.entries) {
      final id = e.key;
      if (!characterIds.contains(id)) throw StateError('signals 없는 캐릭터: $id');
      final bands = e.value.bands;
      if (bands.isEmpty) throw StateError('signals 구간 없음: $id');
      var expectMin = 1;
      for (var i = 0; i < bands.length; i++) {
        final b = bands[i];
        final where = '$id.bands[$i](${b.min}~${b.max})';
        if (b.min > b.max) throw StateError('signals 구간 min > max: $where');
        if (b.min < expectMin) throw StateError('signals 구간 겹침: $where');
        if (b.min > expectMin) {
          throw StateError('signals 구간 빈칸 ($expectMin~${b.min - 1}): $where');
        }
        if (b.lines.isEmpty) throw StateError('signals 구간에 문장 없음: $where');
        for (var k = 0; k < b.lines.length; k++) {
          checkLine(b.lines[k], '$where.lines[$k]');
        }
        expectMin = b.max + 1;
      }
      if (expectMin <= 100) {
        throw StateError('signals 구간 빈칸 ($expectMin~100): $id');
      }
      for (var k = 0; k < e.value.down.length; k++) {
        checkLine(e.value.down[k], '$id.down[$k]');
      }
    }
  }
}
