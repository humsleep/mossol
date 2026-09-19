import 'dart:convert';

import 'models.dart';

/// 서사 신호. 호감 숫자 대신 "예은이 프사를 바꿨다" 같은 한 줄로 관계 진전을 보여 준다.
///
/// 데이터는 `assets/story/signals.json`(선택). 파일이 없거나 비면 [SignalBook.empty] 이고,
/// 그때 UI 는 신호 없이 예전처럼 숫자를 보여 준다.
///
/// ```json
/// {"characters": {"yeeun": {
///   "bands": [{"min": 1, "max": 9, "lines": [
///     "조건 없는 문장",
///     {"text": "예은이 철거 전 교실 사진을 또 꺼내 봤다",
///      "when": {"seen": ["yeeun_r04"], "flags": [], "notFlags": []}}
///   ]}, …, {"min": 90, "max": 100, …}],
///   "down": ["…", {"text": "…", "when": {…}}]
/// }}}
/// ```
///
/// 문장은 문자열(조건 없음) 또는 `{"text", "when"}` 객체다. `when` 의 세 목록은 모두
/// 선택이고 AND 로 묶인다: `flags` 는 전부 켜져 있어야, `notFlags` 는 전부 꺼져 있어야,
/// `seen` 은 전부 본 이벤트여야 한다. 조건이 맞지 않는 문장은 후보에서 빠지고, 조건 없는
/// 문장은 늘 후보다. 후보가 하나도 없으면 null(화면은 숫자로 돌아간다).
///
/// 규칙(검증기가 잡는다): 캐릭터 id 는 characters.json 에 있어야 하고, 구간은 1~100 을
/// 빈칸·겹침 없이 오름차순으로 덮는다. 문장은 비어 있지 않고 [SignalBook.maxLength]자 이내.
/// `when` 이 가리키는 이벤트 id·플래그가 실제로 있는지는 [SignalBook.validateReferences].
/// 호감 0 은 어느 구간에도 속하지 않는다 — 아직 아무 신호도 없다(히든 도윤 포함).
class SignalWhen {
  final List<String> flags;
  final List<String> notFlags;
  final List<String> seen;

  /// 모르는 키(오타). 검증기가 잡는다.
  final List<String> unknownKeys;

  const SignalWhen({
    this.flags = const [],
    this.notFlags = const [],
    this.seen = const [],
    this.unknownKeys = const [],
  });

  static const _keys = {'flags', 'notFlags', 'seen'};

  factory SignalWhen.fromJson(Map<String, dynamic> j) => SignalWhen(
    flags: _strs(j['flags']),
    notFlags: _strs(j['notFlags']),
    seen: _strs(j['seen']),
    unknownKeys: [
      for (final k in j.keys)
        if (!_keys.contains(k)) k,
    ],
  );

  bool get isEmpty => flags.isEmpty && notFlags.isEmpty && seen.isEmpty;

  bool matches(SignalContext c) =>
      flags.every(c.flags.contains) &&
      !notFlags.any(c.flags.contains) &&
      seen.every(c.seen.contains);
}

/// 신호 한 줄. [when] 이 null 이면 조건 없는 문장.
class SignalLine {
  final String text;
  final SignalWhen? when;

  const SignalLine(this.text, {this.when});

  bool get conditional => when != null;

  bool eligible(SignalContext c) => when == null || when!.matches(c);

  /// 문자열이면 조건 없는 문장, 객체면 `{"text", "when"}`.
  factory SignalLine.fromJson(Object? j) {
    if (j is String) return SignalLine(j);
    if (j is Map<String, dynamic>) {
      final w = j['when'];
      if (w != null && w is! Map<String, dynamic>) {
        throw const FormatException('signals 문장의 when 은 객체여야 한다');
      }
      return SignalLine(
        (j['text'] as String?) ?? '',
        when: w == null ? null : SignalWhen.fromJson(w as Map<String, dynamic>),
      );
    }
    throw FormatException('signals 문장은 문자열이나 객체여야 한다: $j');
  }
}

List<String> _strs(Object? v) => [
  for (final x in (v as List?) ?? const []) x as String,
];

List<SignalLine> _lines(Object? v) => [
  for (final x in (v as List?) ?? const []) SignalLine.fromJson(x),
];

class SignalBand {
  final int min;
  final int max;
  final List<SignalLine> entries;

  const SignalBand({
    required this.min,
    required this.max,
    required this.entries,
  });

  /// 문장 글자만. 디버그 갤러리처럼 조건과 상관없이 전부 훑을 때 쓴다.
  List<String> get lines => [for (final e in entries) e.text];

  bool contains(int affection) => affection >= min && affection <= max;

  factory SignalBand.fromJson(Map<String, dynamic> j) => SignalBand(
    min: ((j['min'] as num?) ?? 0).toInt(),
    max: ((j['max'] as num?) ?? 0).toInt(),
    entries: _lines(j['lines']),
  );
}

/// 캐릭터 한 명의 신호 묶음.
class CharacterSignals {
  final List<SignalBand> bands;

  /// 구간이 내려간 날의 조용한 문장("요즘 답이 늦다").
  final List<SignalLine> downEntries;

  const CharacterSignals({this.bands = const [], this.downEntries = const []});

  List<String> get down => [for (final e in downEntries) e.text];

  factory CharacterSignals.fromJson(Map<String, dynamic> j) => CharacterSignals(
    bands: [
      for (final b in (j['bands'] as List?) ?? const [])
        SignalBand.fromJson(b as Map<String, dynamic>),
    ],
    downEntries: _lines(j['down']),
  );
}

/// 신호를 고를 때 보는 세이브 조각: 조건 판정용 플래그·본 이벤트와 반복 방지용 기록.
class SignalContext {
  final Set<String> flags;
  final Set<String> seen;

  /// 기록 키(`id:구간번호` 또는 `id:down`) → 최근에 보여 준 문장 번호(최근 것이 뒤).
  final Map<String, List<int>> history;

  const SignalContext({
    this.flags = const {},
    this.seen = const {},
    this.history = const {},
  });

  /// 문맥 없음: 조건 있는 문장은 전부 빠지고, 기록이 없어 날짜로만 고른다.
  static const none = SignalContext();

  factory SignalContext.of(GameState s) =>
      SignalContext(flags: s.flags, seen: s.seen, history: s.signalHistory);
}

/// 고른 문장. [key] 는 반복 방지 기록 키, [index] 는 그 구간(또는 down) 안의 번호.
class SignalPick {
  final int band;
  final int index;
  final String key;
  final String text;

  const SignalPick({
    required this.band,
    required this.index,
    required this.key,
    required this.text,
  });
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

  /// 고른 문장의 번호(상승이면 새 구간 안, 하강이면 down 안). 모르면 -1.
  final int index;

  const RelationShift({
    required this.id,
    required this.from,
    required this.to,
    required this.fromBand,
    required this.toBand,
    required this.text,
    this.index = -1,
  });

  bool get up => toBand > fromBand;
}

class SignalBook {
  final Map<String, CharacterSignals> byCharacter;

  const SignalBook(this.byCharacter);

  static const empty = SignalBook({});

  /// 문장 최대 길이(글자). 홈 카드 두 줄에 들어가야 한다.
  static const maxLength = 40;

  /// 반복 방지로 기억하는 최근 문장 수(기록 키마다).
  static const historySize = 3;

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

  static String bandKey(String id, int band) => '$id:$band';
  static String downKey(String id) => '$id:down';

  /// [entries] 가운데 조건이 맞는 후보에서 최근 기록을 피해 하나를 고른다.
  ///
  /// 1. 후보 = 조건이 맞는 문장(조건 없는 문장은 늘 후보). 없으면 null.
  /// 2. 최근 [historySize]개를 뺀 후보에서 고른다. 다 빠지면 바로 전 것만 빼고,
  ///    그래도 없으면(후보가 하나뿐) 그 하나.
  /// 3. (seed, day, 기록 키) 해시로 고른다 — 같은 입력이면 늘 같은 문장.
  static int? _choose(
    List<SignalLine> entries,
    SignalContext ctx, {
    required String key,
    required int seed,
    required int day,
  }) {
    final eligible = [
      for (var k = 0; k < entries.length; k++)
        if (entries[k].eligible(ctx)) k,
    ];
    if (eligible.isEmpty) return null;
    final recent = ctx.history[key] ?? const <int>[];
    var pool = [
      for (final k in eligible)
        if (!recent.contains(k)) k,
    ];
    if (pool.isEmpty && recent.isNotEmpty) {
      pool = [
        for (final k in eligible)
          if (k != recent.last) k,
      ];
    }
    if (pool.isEmpty) pool = eligible;
    return pool[pickIndex(pool.length, seed: seed, day: day, id: key)];
  }

  /// 지금 호감에 맞는 신호. 호감 0(히든 미해금 포함)·데이터 없음·후보 없음이면 null.
  SignalPick? pick(
    String id,
    int affection, {
    required int seed,
    required int day,
    SignalContext context = SignalContext.none,
  }) {
    final b = bandIndex(id, affection);
    if (b < 0) return null;
    final entries = byCharacter[id]!.bands[b].entries;
    final key = bandKey(id, b);
    final k = _choose(entries, context, key: key, seed: seed, day: day);
    if (k == null) return null;
    return SignalPick(band: b, index: k, key: key, text: entries[k].text);
  }

  /// [pick] 의 문장만. 같은 (seed, day, 캐릭터, 문맥) 이면 몇 번을 불러도 같다.
  String? signalFor(
    String id,
    int affection, {
    required int seed,
    required int day,
    SignalContext context = SignalContext.none,
  }) => pick(id, affection, seed: seed, day: day, context: context)?.text;

  /// 구간이 내려간 날의 문장. 없으면 null.
  SignalPick? pickDown(
    String id, {
    required int seed,
    required int day,
    SignalContext context = SignalContext.none,
  }) {
    final entries = byCharacter[id]?.downEntries ?? const <SignalLine>[];
    final key = downKey(id);
    final k = _choose(entries, context, key: key, seed: seed, day: day);
    if (k == null) return null;
    return SignalPick(band: -1, index: k, key: key, text: entries[k].text);
  }

  String? downSignalFor(
    String id, {
    required int seed,
    required int day,
    SignalContext context = SignalContext.none,
  }) => pickDown(id, seed: seed, day: day, context: context)?.text;

  /// [from] → [to] 로 구간이 바뀌었으면 그 변화. 같은 구간이거나 문장이 없으면 null.
  RelationShift? shiftFor(
    String id,
    int from,
    int to, {
    required int seed,
    required int day,
    SignalContext context = SignalContext.none,
  }) {
    final a = bandIndex(id, from);
    final b = bandIndex(id, to);
    if (a == b) return null;
    final p = b > a
        ? pick(id, to, seed: seed, day: day, context: context)
        : pickDown(id, seed: seed, day: day, context: context);
    if (p == null) return null;
    return RelationShift(
      id: id,
      from: from,
      to: to,
      fromBand: a,
      toBand: b,
      text: p.text,
      index: p.index,
    );
  }

  /// 오늘 [id] 의 신호. 홈 카드가 쓴다.
  ///
  /// 어젯밤 마감([rollover])에서 고정해 둔 문장이 지금 구간과 맞고 조건도 여전히 맞으면
  /// 그 문장 — 그래서 정산 카드에서 본 문장이 다음 날 아침 홈에도 그대로 뜬다.
  /// 고정이 없거나(첫날·예전 세이브) 낮 사이 구간이 바뀌었으면 기록을 피해 새로 고른다.
  String? todaySignal(GameState s, String id) {
    final aff = s.affectionOf(id);
    final b = bandIndex(id, aff);
    if (b < 0) return null;
    final ctx = SignalContext.of(s);
    final pin = s.signalPins[id];
    if (pin != null && pin.length == 2 && pin[0] == b) {
      final entries = byCharacter[id]!.bands[b].entries;
      final k = pin[1];
      if (k >= 0 && k < entries.length && entries[k].eligible(ctx)) {
        return entries[k].text;
      }
    }
    return signalFor(id, aff, seed: s.seed, day: s.day, context: ctx);
  }

  /// 반복 방지 기록에 [index] 를 넣는다. 최근 [historySize]개만 남긴다.
  static void remember(Map<String, List<int>> history, String key, int index) {
    if (index < 0) return;
    final list = history.putIfAbsent(key, () => <int>[])
      ..remove(index)
      ..add(index);
    while (list.length > historySize) {
      list.removeAt(0);
    }
  }

  /// 하루 마감 직후(`EventEngine.endDay` 가 호감 −1·day+1 을 한 뒤) 부른다.
  ///
  /// - [shown]: 방금 정산에 띄운 관계 변화(마감 전 `todayShifts`). 그 문장을 기록에 넣고,
  ///   오른 사람은 그 문장을 오늘 아침 문장으로 고정한다(정산 = 다음 날 홈).
  /// - [before]: 마감 직전 호감. 마감 −1 로 구간이 내려간 사람은 하강 문장을 골라
  ///   [GameState.overnightShifts] 에 둔다(행동 화면·홈의 조용한 한 줄).
  /// - 나머지 호감 1 이상인 사람은 기록을 피해 오늘 문장을 새로 골라 고정한다.
  ///   매일 한 번 기록이 쌓이므로 같은 구간에 오래 머물러도 최근 문장이 되풀이되지 않는다.
  void rollover(
    GameState s, {
    required Iterable<String> ids,
    required Map<String, int> before,
    List<RelationShift> shown = const [],
  }) {
    final history = s.signalHistory;
    s.signalPins.clear();
    s.overnightShifts.clear();
    if (isEmpty) return;
    for (final sh in shown) {
      remember(
        history,
        sh.up ? bandKey(sh.id, sh.toBand) : downKey(sh.id),
        sh.index,
      );
    }
    for (final id in ids) {
      final now = s.affectionOf(id);
      final b = bandIndex(id, now);
      final prev = before[id];
      if (prev != null && bandIndex(id, prev) > b) {
        final d = pickDown(
          id,
          seed: s.seed,
          day: s.day,
          context: SignalContext.of(s),
        );
        if (d != null) {
          s.overnightShifts[id] = d.text;
          remember(history, d.key, d.index);
        }
      }
      if (b < 0) continue;
      int? k;
      for (final sh in shown) {
        if (sh.id == id && sh.up && sh.toBand == b && sh.index >= 0) {
          k = sh.index;
        }
      }
      if (k == null) {
        final p = pick(
          id,
          now,
          seed: s.seed,
          day: s.day,
          context: SignalContext.of(s),
        );
        if (p == null) continue;
        k = p.index;
        remember(history, p.key, k);
      }
      s.signalPins[id] = [b, k];
    }
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

  /// 조건이 붙은 문장까지 모든 문장을 (위치, 문장) 으로 훑는다.
  Iterable<(String, SignalLine)> _allLines() sync* {
    for (final e in byCharacter.entries) {
      final bands = e.value.bands;
      for (var i = 0; i < bands.length; i++) {
        final b = bands[i];
        for (var k = 0; k < b.entries.length; k++) {
          yield (
            '${e.key}.bands[$i](${b.min}~${b.max}).lines[$k]',
            b.entries[k],
          );
        }
      }
      for (var k = 0; k < e.value.downEntries.length; k++) {
        yield ('${e.key}.down[$k]', e.value.downEntries[k]);
      }
    }
  }

  /// 데이터 검사. 문제가 있으면 [StateError]. `StoryBundle.validate` 가 부른다.
  void validate(Set<String> characterIds) {
    void checkLine(SignalLine l, String where) {
      final t = l.text;
      if (t.trim().isEmpty) throw StateError('signals 빈 문장: $where');
      final n = t.runes.length;
      if (n > maxLength) {
        throw StateError('signals 문장이 $maxLength자 초과($n자): $where "$t"');
      }
      final w = l.when;
      if (w != null) {
        if (w.unknownKeys.isNotEmpty) {
          throw StateError('signals when 에 모르는 키 ${w.unknownKeys}: $where');
        }
        if (w.isEmpty) throw StateError('signals 빈 when: $where');
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
        if (b.entries.isEmpty) throw StateError('signals 구간에 문장 없음: $where');
        for (var k = 0; k < b.entries.length; k++) {
          checkLine(b.entries[k], '$where.lines[$k]');
        }
        expectMin = b.max + 1;
      }
      if (expectMin <= 100) {
        throw StateError('signals 구간 빈칸 ($expectMin~100): $id');
      }
      for (var k = 0; k < e.value.downEntries.length; k++) {
        checkLine(e.value.downEntries[k], '$id.down[$k]');
      }
    }
  }

  /// `when` 이 가리키는 이벤트 id 와 플래그가 실제 스토리에 있는지 검사한다.
  /// 플래그는 이벤트 선택지(성공·실패 효과)의 `setFlags` 합집합이다.
  ///
  /// `StoryBundle.validate` 는 캐릭터 id 만 넘기므로 이 검사는 따로 부른다
  /// (`GameController` 가 디버그 빌드에서, 테스트가 실제 번들로).
  void validateReferences(Iterable<StoryEvent> events) {
    final ids = <String>{};
    final flags = <String>{};
    for (final e in events) {
      ids.add(e.id);
      for (final c in e.choices) {
        flags
          ..addAll(c.effects.setFlags)
          ..addAll(c.fail.setFlags);
      }
    }
    for (final (where, l) in _allLines()) {
      final w = l.when;
      if (w == null) continue;
      for (final f in [...w.flags, ...w.notFlags]) {
        if (!flags.contains(f)) {
          throw StateError('signals when 의 없는 플래그: $where -> $f');
        }
      }
      for (final ev in w.seen) {
        if (!ids.contains(ev)) {
          throw StateError('signals when 의 없는 이벤트: $where -> $ev');
        }
      }
    }
  }
}
