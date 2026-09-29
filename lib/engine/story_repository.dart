import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'effects.dart';
import 'mbti.dart';
import 'models.dart';
import 'signals.dart';
import 'text_template.dart';

export 'signals.dart' show SignalBook, RelationShift;

/// 스토리 데이터 묶음. JSON 파일들(+ 선택 signals.json)에서 만들어진다.
class StoryBundle {
  final GameConfig config;
  final List<CharacterDef> characters;
  final List<StoryEvent> events;
  final List<Ending> endings;

  /// 서사 신호(선택). 파일이 없거나 비면 [SignalBook.empty].
  final SignalBook signals;
  late final Map<String, StoryEvent> eventById = {
    for (final e in events) e.id: e,
  };
  late final Map<String, CharacterDef> characterById = {
    for (final c in characters) c.id: c,
  };

  /// [pref] 회차에 등장하는 캐릭터(characters.json 순). [Preference.all] 이면 전부.
  List<CharacterDef> charactersFor(String pref) => _rosters.putIfAbsent(
    pref,
    () => List.unmodifiable(characters.where((c) => c.appearsIn(pref))),
  );
  final Map<String, List<CharacterDef>> _rosters = {};

  /// [pref] 회차에 등장하지 않는 캐릭터 id. 엔진이 조건·효과·후보에서 뺀다.
  Set<String> absentIds(String pref) => _absent.putIfAbsent(
    pref,
    () => Set.unmodifiable({
      for (final c in characters)
        if (!c.appearsIn(pref)) c.id,
    }),
  );
  final Map<String, Set<String>> _absent = {};

  /// 이벤트가 [pref] 회차에 나올 수 있는지(날짜·조건과 무관한 정적 판정).
  /// 캐릭터 이벤트는 그 캐릭터가 등장해야 하고, `trigger.pref` 는 쪽이 맞아야 한다.
  bool eventInPreference(StoryEvent e, String pref) {
    final ch = e.character;
    if (ch != null && absentIds(pref).contains(ch)) return false;
    return Preference.allowsSide(pref, e.trigger.pref);
  }

  /// 엔딩이 [pref] 회차에 나올 수 있는지. 캐릭터 엔딩은 캐릭터 성별, 공용은 `when.pref`.
  bool endingInPreference(Ending e, String pref) {
    final ch = e.character;
    if (ch != null && absentIds(pref).contains(ch)) return false;
    return Preference.allowsSide(pref, e.when.pref);
  }

  /// 엔딩의 쪽. 캐릭터 엔딩은 캐릭터 성별, 공용은 `when.pref`, 둘 다 없으면 null(공용).
  /// 앨범 필터가 쓴다.
  String? endingSide(Ending e) {
    final ch = e.character;
    if (ch != null) {
      final g = characterById[ch]?.gender;
      if (g != null && g.isNotEmpty) return g;
    }
    return e.when.pref;
  }

  /// 캐스트 소개(새 게임 2단계)의 첫 메시지 미리보기.
  ///
  /// characters.json 의 `firstLine` 이 있으면 그것. 없으면 그 캐릭터의 루트 이벤트
  /// `<id>_rNN` 을 번호 순으로 훑어 처음 나오는 `them` 대사(글이 있는 것). 둘 다 없으면 null.
  ///
  /// 자리표시자(`{name|아야}` 등)는 [TextTemplate.currentName] 으로 바꿔 돌려준다 — 캐스트
  /// 소개 화면은 컨트롤러를 받지 않으므로 여기서 치환한다. 원문은 [rawFirstLineOf].
  /// MBTI 조건이 붙은 줄은 건너뛴다(누구에게나 같은 첫 메시지).
  String? firstLineOf(String id) {
    final raw = rawFirstLineOf(id);
    return raw == null
        ? null
        : TextTemplate.fill(
            raw,
            name: TextTemplate.currentName,
            mbti: TextTemplate.currentMbti,
            chars: charNames,
          );
  }

  /// [firstLineOf] 의 치환 전 원문.
  String? rawFirstLineOf(String id) => _firstLines.putIfAbsent(id, () {
    final ch = characterById[id];
    if (ch == null) return null;
    final own = ch.firstLine;
    if (own != null) return own;
    final re = RegExp('^${RegExp.escape(id)}_r(\\d+)\$');
    final route = [
      for (final e in events)
        if (re.firstMatch(e.id) case final m?) (int.parse(m.group(1)!), e),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, e) in route) {
      for (final l in e.lines) {
        if (l.who == 'them' &&
            l.photo == null &&
            !l.isGated &&
            l.text.trim().isNotEmpty) {
          return l.text.trim();
        }
      }
    }
    return null;
  });
  final Map<String, String?> _firstLines = {};

  /// [side] 쪽 회차에서 볼 수 있는 엔딩 수(그 쪽 캐릭터 엔딩 + 공용).
  int endingCountFor(String side) =>
      endings.where((e) => endingInPreference(e, side)).length;

  /// 레이어별 이벤트. 하루 계획에서 매번 240개를 훑지 않도록 한 번만 나눈다.
  late final Map<EventLayer, List<StoryEvent>> eventsByLayer = {
    for (final l in EventLayer.values)
      l: List.unmodifiable(events.where((e) => e.layer == l)),
  };

  StoryBundle({
    required this.config,
    required this.characters,
    required this.events,
    required this.endings,
    this.signals = SignalBook.empty,
  });

  /// 선택 데이터. 없어도 앱이 돈다.
  static const signalsFile = 'signals.json';

  /// 이벤트는 레이어별로 파일이 나뉘어 있다. 파일을 추가하면 여기에만 이름을 넣으면 된다.
  static const eventFiles = [
    'events_main.json',
    'events_route_a.json',
    'events_route_b.json',
    'events_daily.json',
    // 아침 행동(config.actions)마다 그날 첫 장면. `trigger.action` 으로 거른다.
    'events_action.json',
    'events_special.json',
    'route_jeongwoo.json',
    'route_daeun.json',
    'route_seunghyun.json',
    'route_sohee.json',
    'route_geonwoo.json',
    'route_yuna.json',
    // 형식을 깨는 이벤트(전화·알림·사진). docs/MOMENTS_SPEC.md. 비어 있거나 없어도 된다.
    'events_moments.json',
  ];

  /// 없거나 비어 있어도 되는 이벤트 파일. 작가가 채우는 중인 파일이 앱을 막지 않게 한다.
  static const optionalEventFiles = {'events_moments.json'};

  factory StoryBundle.fromJsonStrings({
    required String config,
    required String characters,
    required List<String> events,
    required String endings,
    String? signals,
    Set<String>? knownMinigames,
    bool requireEndingHints = false,
    bool requireDailyDepth = false,
  }) {
    final bundle = StoryBundle(
      config: GameConfig.fromJson(jsonDecode(config) as Map<String, dynamic>),
      characters: (jsonDecode(characters) as List)
          .map((e) => CharacterDef.fromJson(e as Map<String, dynamic>))
          .toList(),
      events: [
        // 빈 파일(작성 중)은 빈 배열로 본다.
        for (final raw in events)
          if (raw.trim().isNotEmpty)
            ...(jsonDecode(raw) as List).map(
              (e) => StoryEvent.fromJson(e as Map<String, dynamic>),
            ),
      ],
      endings: (jsonDecode(endings) as List)
          .map((e) => Ending.fromJson(e as Map<String, dynamic>))
          .toList(),
      signals: SignalBook.fromJsonString(signals),
    );
    bundle.validate(
      knownMinigames: knownMinigames,
      requireEndingHints: requireEndingHints,
      requireDailyDepth: requireDailyDepth,
    );
    return bundle;
  }

  static Future<StoryBundle> loadFromAssets({
    String dir = 'assets/story',
    Set<String>? knownMinigames,
  }) async {
    final config = await rootBundle.loadString('$dir/config.json');
    final characters = await rootBundle.loadString('$dir/characters.json');
    final endings = await rootBundle.loadString('$dir/endings.json');
    final events = await Future.wait(
      eventFiles.map((f) async {
        if (!optionalEventFiles.contains(f)) {
          return rootBundle.loadString('$dir/$f');
        }
        // 선택 파일은 번들에 없으면 빈 배열.
        try {
          return await rootBundle.loadString('$dir/$f');
        } catch (_) {
          return '[]';
        }
      }),
    );
    // 서사 신호는 선택. 파일이 번들에 없으면 신호 없이 숫자만 보여 준다.
    String? signals;
    try {
      signals = await rootBundle.loadString('$dir/$signalsFile');
    } catch (_) {
      signals = null;
    }
    return StoryBundle.fromJsonStrings(
      config: config,
      characters: characters,
      events: events,
      endings: endings,
      signals: signals,
      knownMinigames: knownMinigames,
      // 출시 데이터는 엔딩마다 사람이 쓴 힌트가 있어야 한다(홈·앨범의 "아직 못 본 엔딩").
      requireEndingHints: true,
      // 출시 데이터는 100일을 버틸 만큼 반복 가능한 일상이 있어야 한다([_checkRepeatables]).
      requireDailyDepth: true,
    );
  }

  /// 캐릭터 id → 이름(전원). 길이 계산과 회차가 없는 화면이 쓴다.
  late final Map<String, String> charNames = {
    for (final c in characters) c.id: c.name,
  };

  /// [pref] 회차에 **등장하는** 캐릭터만 담은 이름표. `{char:<id>}` 치환이 쓴다.
  /// 선호 밖 캐릭터를 부르는 대사는 이름을 못 찾아 중립 명사로 떨어진다 —
  /// 여성 회차 대사가 남성 쪽 이름을 실수로 부르는 일이 없다.
  Map<String, String> charNamesFor(String pref) => _charNames.putIfAbsent(
    pref,
    () => Map.unmodifiable({
      for (final c in charactersFor(pref)) c.id: c.name,
    }),
  );
  final Map<String, Map<String, String>> _charNames = {};

  /// 이벤트가 참조하는 미니게임 id 전부.
  Set<String> get referencedMinigames => {
    for (final e in events)
      for (final c in e.choices)
        if (c.minigame != null) c.minigame!,
  };

  /// 데이터 오류를 출시 전에 잡기 위한 검사. 문제가 있으면 예외.
  /// [knownMinigames] 를 주면 없는 미니게임 참조도 함께 잡는다.
  /// [requireEndingHints] 면 엔딩마다 비어 있지 않은 `hint` 가 있어야 한다.
  /// [requireDailyDepth] 면 반복 가능한 일상이 100일을 버틸 만큼 있어야 한다([_checkRepeatables]).
  /// 둘 다 **출시 데이터에만** 해당한다 — 테스트용 합성 번들은 이벤트가 몇 개뿐이라 기본은 끈다.
  void validate({
    Set<String>? knownMinigames,
    bool requireEndingHints = false,
    bool requireDailyDepth = false,
  }) {
    final ids = <String>{};
    final charIds = <String>{};
    for (final c in characters) {
      if (!charIds.add(c.id)) throw StateError('캐릭터 id 중복: ${c.id}');
    }
    _checkCast();
    for (final c in characters) {
      final first = c.firstLine;
      if (first != null) _checkTemplate(first, '${c.id}.firstLine');
      _checkNoTemplate(c.tagline, '${c.id}.tagline');
      _checkNoTemplate(c.name, '${c.id}.name');
      final m = c.mbti;
      if (m != null && !Mbti.isType(m)) {
        throw StateError(
          '캐릭터 mbti 는 대문자 4글자(E/I S/N T/F J/P): ${c.id} -> "$m"',
        );
      }
      // 오타는 조용히 기본값으로 떨어진다 — `"politness": "polite"` 한 글자에 지우가
      // 100일 내내 반말을 하게 되므로 여기서 막는다. 줄 조건 쪽 검사는 [_checkGate].
      if (!Humor.isValid(c.humor)) {
        throw StateError(
          '캐릭터 humor 는 ${Humor.values.join('|')}: ${c.id} -> "${c.humor}"',
        );
      }
      if (!Politeness.isValid(c.politeness)) {
        throw StateError(
          '캐릭터 politeness 는 ${Politeness.values.join('|')}: '
          '${c.id} -> "${c.politeness}"',
        );
      }
    }
    final cm = config.compatMultiplier;
    if (cm.length != Mbti.maxCompat + 1 || cm.any((v) => v < 0.5 || v > 1.5)) {
      throw StateError('mbti.compatMultiplier 는 0.5~1.5 값 5개: $cm');
    }
    for (final (where, text) in signals.allTexts) {
      _checkTemplate(text, 'signals $where');
    }
    _checkStatKeys(config.initialStats.keys, 'config.initialStats');
    final early = config.earlyAffection;
    for (var i = 0; i < early.curve.length; i++) {
      final m = early.curve[i];
      if (m < 1 || m > 4) {
        throw StateError('earlyAffection.curve[$i] 범위 밖(1~4): $m');
      }
    }
    if (early.maxTotal < 2) {
      throw StateError(
        'earlyAffection.maxTotal 은 크리티컬(2) 이상: ${early.maxTotal}',
      );
    }
    signals.validate(charIds);
    for (final a in config.actions) {
      _checkStatKeys(a.effects.stats.keys, 'action ${a.id}');
    }
    for (final e in events) {
      if (!ids.add(e.id)) throw StateError('이벤트 id 중복: ${e.id}');
      if (e.choices.isEmpty) throw StateError('선택지 없는 이벤트: ${e.id}');
      if (e.hint != null && (e.hint! < 0 || e.hint! >= e.choices.length)) {
        throw StateError('hint 인덱스 범위 밖: ${e.id}');
      }
      if (e.character != null && !characterById.containsKey(e.character)) {
        throw StateError('없는 캐릭터 참조: ${e.id} -> ${e.character}');
      }
      if (e.layer == EventLayer.main && e.day == null) {
        throw StateError('main 이벤트는 day 가 필요: ${e.id}');
      }
      for (final (where, text) in e.displayTexts) {
        _checkTemplate(text, where, bareMbtiOk: true);
      }
      _checkTrigger(
        e.trigger,
        '${e.id}.trigger',
        hasCharacter: e.character != null,
      );
      _checkMbti(e);
      _checkMoment(e);
      _checkImage(e.image, '${e.id}.image');
      _checkActionScene(e);
      _checkLines(e.lines, '${e.id}.lines');
      _checkVariants(e);
      for (var i = 0; i < e.choices.length; i++) {
        final c = e.choices[i];
        final where = '${e.id}.choices[$i]';
        final chance = c.chance;
        if (chance != null && (chance < 0 || chance > 100)) {
          throw StateError('chance 범위 밖(0~100): $where = $chance');
        }
        _checkEffects(c.effects, '$where.effects');
        _checkEffects(c.fail, '$where.fail');
        for (final a in [c.effects.album, c.fail.album]) {
          if (a != null) _checkNoTemplate(a, '$where.album');
        }
        for (final (name, lines) in [
          ('reply', c.reply),
          ('failReply', c.failReply),
          ('critReply', c.critReply),
        ]) {
          _checkLines(lines, '$where.$name');
        }
        final req = c.require;
        if (req != null) {
          _checkStatKeys(req.stats.keys, '$where.require');
          _checkCharKeys(req.affection.keys, '$where.require.affection');
          _checkCharKeys(req.trust.keys, '$where.require.trust');
        }
      }
    }
    for (final e in events) {
      for (final c in e.choices) {
        for (final n in [c.next, c.failNext]) {
          if (n != null && !ids.contains(n)) {
            throw StateError('없는 next 참조: ${e.id} -> $n');
          }
        }
      }
    }
    final endingIds = <String>{};
    for (final e in endings) {
      if (!endingIds.add(e.id)) throw StateError('엔딩 id 중복: ${e.id}');
      if (e.character != null && !characterById.containsKey(e.character)) {
        throw StateError('엔딩이 없는 캐릭터 참조: ${e.id} -> ${e.character}');
      }
      _checkTrigger(
        e.when,
        'ending ${e.id}',
        hasCharacter: e.character != null,
      );
      _checkTemplate(
        e.epilogue,
        'ending ${e.id}.epilogue',
        bareMbtiOk: e.when.mbti != null,
      );
      for (final MapEntry(:key, :value) in e.epilogueMbti.entries) {
        if (!Mbti.temperaments.contains(key)) {
          throw StateError(
            'epilogueMbti 키는 ${Mbti.temperaments.join('|')}: ending ${e.id} -> $key',
          );
        }
        // 기질 문단은 기질을 아는(MBTI 가 있는) 플레이어에게만 붙으므로 {mbti} 를 써도 된다.
        _checkTemplate(
          value,
          'ending ${e.id}.epilogueMbti.$key',
          bareMbtiOk: true,
        );
      }
      if (e.hint != null) _checkTemplate(e.hint!, 'ending ${e.id}.hint');
      _checkImage(e.image, 'ending ${e.id}.image');
      _checkNoTemplate(e.name, 'ending ${e.id}.name');
      if (requireEndingHints && (e.hint ?? '').trim().isEmpty) {
        throw StateError('엔딩 hint 없음: ${e.id}');
      }
    }
    if (!endings.any((e) => e.isDefault)) throw StateError('default 엔딩이 없음');
    if (requireDailyDepth) _checkRepeatables();

    if (knownMinigames != null) {
      final missing = referencedMinigames.difference(knownMinigames);
      if (missing.isNotEmpty) throw StateError('없는 미니게임 참조: $missing');
    }

    // main 이벤트는 날짜가 겹치면 하루에 둘이 잡혀 흐름이 꼬인다.
    // 예외: 쪽별 버전(`trigger.pref` f 와 m 각 1개)은 한 회차에 하나만 열리므로 같은 날 둔다.
    // 공용(pref 없음)과 쪽별 버전이 같은 날 겹치면 한 회차에 둘이 잡히므로 오류다.
    final mainDays = <int, Map<String?, String>>{};
    for (final e in events.where((e) => e.layer == EventLayer.main)) {
      final slots = mainDays.putIfAbsent(e.day!, () => {});
      final p = e.trigger.pref;
      final clash =
          slots[p] ??
          (p == null && slots.isNotEmpty ? slots.values.first : null) ??
          (p != null ? slots[null] : null);
      if (clash != null) {
        throw StateError('main 날짜 중복: ${e.day}일 ($clash, ${e.id})');
      }
      slots[p] = e.id;
    }
  }

  /// 변형 대사([StoryEvent.variants]) 규칙.
  ///
  /// - 빈 묶음은 빈 화면이 된다 → 오류.
  /// - **원본만 있고 변형 하나뿐인데 `once: true`** 면 변형이 영원히 안 쓰인다 → 낭비를 알린다.
  ///   (`once` 는 한 회차에 한 번이므로 두 번째 대사를 볼 기회가 없다.)
  /// - 사진 줄 유무는 원본과 같아야 한다. 다르면 같은 이벤트가 어떤 회차에서는 모먼트,
  ///   어떤 회차에서는 아닌 것이 되어 하루 계획의 가중치가 회차마다 달라진다
  ///   ([StoryEvent.hasPhoto] 주석).
  void _checkVariants(StoryEvent e) {
    if (e.variants.isEmpty) return;
    if (e.once) {
      throw StateError(
        'once 이벤트에 변형 대사: ${e.id} — 한 회차에 한 번만 나오므로 변형을 볼 기회가 없다',
      );
    }
    final basePhoto = e.lines.any((l) => l.photo != null);
    for (var i = 0; i < e.variants.length; i++) {
      final v = e.variants[i];
      final where = '${e.id}.variants[$i]';
      if (v.isEmpty) throw StateError('변형 대사가 비어 있음: $where');
      _checkLines(v, '$where.lines');
      if (v.any((l) => l.photo != null) != basePhoto) {
        throw StateError(
          '변형의 사진 줄 유무가 원본과 다름: $where (모먼트 판정이 회차마다 달라진다)',
        );
      }
    }
  }

  /// [pref] 회차에서 **반복될 수 있는** 일상(`once: false`) 이벤트.
  /// `once: true` 는 한 번 보면 후보에서 사라지므로([EventEngine] 의 `_available`),
  /// 100일 후반의 일상 칸은 결국 이 목록 안에서만 돌아간다.
  ///
  /// 행동 장면(`trigger.action`)은 일상 칸이 아니라 하루 첫 장면 자리에서만 뽑히므로
  /// 세지 않는다([EventEngine.dailyPool] 도 뺀다) — 세면 소프트락 방지선이 부풀려진다.
  List<StoryEvent> repeatableDaily(String pref) => [
    for (final e in events)
      if (e.layer == EventLayer.daily &&
          e.trigger.action.isEmpty &&
          !e.once &&
          _drawable(e) &&
          eventInPreference(e, pref))
        e,
  ];

  /// 일상 추첨에 오를 수 있는 날이 하나라도 있는가.
  ///
  /// `failNext` 로만 도달하는 뒷장면들은 `layer: daily` · `once: false` 로 두면서
  /// `day: [0,0]` 으로 추첨을 막아 뒀다(그 두 값은 다른 테스트가 강제한다 —
  /// docs/review/13_content_fixes.md §3). 그 10개를 [repeatableDaily] 가 같이 세면
  /// 소프트락 방지선이 **실제 후보 24개를 34개로 읽어**, 여유가 없는데 있다고 말한다.
  /// 그러면 다음 사람이 그 숫자를 믿고 `once: true` 를 더 붙이다 앱을 못 띄운다.
  bool _drawable(StoryEvent e) {
    final d = e.trigger.day;
    if (d == null) return true;
    return d.max >= 1 && d.min <= config.totalDays;
  }

  /// `once` 소진으로 하루가 비지 않는지. **소프트락 방지선이다.**
  ///
  /// 왜 검사가 필요한가: `once: true` 를 붙이면 재방송은 사라지지만 후보도 사라진다.
  /// 일상 전부에 붙이면 후반 100일차에는 뽑을 일상이 하나도 없어
  /// `planDay` 의 일상 칸과 채움 칸이 통째로 비고, 하루가 메인·루트 두 장면으로 끝난다.
  /// [EventEngine.dailyPool] 의 되돌림은 '냉각 때문에 빈 날'만 구제하고
  /// '전부 소진된 날'은 구제하지 못한다.
  ///
  /// 기준은 [GameConfig.dailyCooldownDays] 다. 냉각이 N일이면 최근 N일에 본 일상은
  /// 후보에서 빠지므로, 반복 가능한 일상이 N개보다 적으면 후반에 **냉각을 뚫고**
  /// 같은 장면을 다시 틀 수밖에 없다. 그래서 회차마다 최소 N개를 요구한다.
  /// (여유 있는 선은 하루에 일상을 최대 2개 뽑으므로 2N 이다. 지금 데이터는 24개로
  /// 그 선에 못 미치고, 그것이 재방송이 아직 20% 대에 남아 있는 이유다 —
  /// 숫자와 필요한 분량은 docs/review/12_engine_fixes.md §3 에 적었다.)
  void _checkRepeatables() {
    final need = config.dailyCooldownDays;
    if (need <= 0) return;
    for (final pref in Preference.genders) {
      if (charactersFor(pref).isEmpty) continue;
      final n = repeatableDaily(pref).length;
      if (n < need) {
        throw StateError(
          '${Preference.label(pref)} 회차에 반복 가능한 일상(once:false)이 $n개뿐 — '
          '냉각 $need일을 버티려면 최소 $need개가 필요하다 '
          '(부족하면 100일 후반에 일상 칸이 빈다)',
        );
      }
    }
  }

  /// 캐스트 규칙. gender·role 필수, 성별마다 역할당 최대 한 명, 히든은 트레이너 역할.
  /// 한쪽에 역할이 비어 있는 것은 오류가 아니라 [lint] 경고다(작가가 채우는 중일 수 있다).
  void _checkCast() {
    final seat = <String, String>{};
    for (final c in characters) {
      if (!Preference.genders.contains(c.gender)) {
        throw StateError('캐릭터 gender 는 f|m 필수: ${c.id} -> "${c.gender}"');
      }
      if (!CastRole.values.contains(c.role)) {
        throw StateError(
          '캐릭터 role 은 ${CastRole.values.join('|')} 중 하나: ${c.id} -> "${c.role}"',
        );
      }
      final key = '${c.gender}/${c.role}';
      final prev = seat[key];
      if (prev != null) {
        throw StateError('같은 성별·역할이 둘: $key ($prev, ${c.id})');
      }
      seat[key] = c.id;
      if (c.tagline.runes.length > CharacterDef.maxTagline) {
        throw StateError(
          'tagline ${CharacterDef.maxTagline}자 초과: ${c.id} (${c.tagline})',
        );
      }
      if (c.hidden != (c.role == CastRole.trainer)) {
        throw StateError(
          '히든은 ${CastRole.trainer} 역할만, ${CastRole.trainer} 는 히든만: ${c.id}',
        );
      }
    }
  }

  /// 성별마다 비어 있는 역할. 예: `{'m': ['senior', 'blinddate', 'classmate']}`.
  /// 빈 쪽이 없으면 빈 맵.
  Map<String, List<String>> get castGaps {
    final out = <String, List<String>>{};
    for (final g in Preference.genders) {
      final have = {
        for (final c in characters)
          if (c.gender == g) c.role,
      };
      final miss = [
        for (final r in CastRole.values)
          if (!have.contains(r)) r,
      ];
      if (miss.isNotEmpty) out[g] = miss;
    }
    return out;
  }

  /// 모먼트 규칙(docs/MOMENTS_SPEC.md §1). 형식·알림·전화 거절 선택지.
  void _checkMoment(StoryEvent e) {
    if (!StoryEvent.formats.contains(e.format)) {
      throw StateError('알 수 없는 format: ${e.id} -> ${e.format}');
    }
    final preview = e.preview;
    if (preview != null) {
      if (e.isCall) throw StateError('preview 는 chat 이벤트에만: ${e.id}');
      // 이름이 들어가는 문장은 가장 긴 이름(6자)으로 바꾼 길이로 잰다.
      final n = TextTemplate.maxLength(preview, chars: charNames);
      if (n > StoryEvent.maxPreview) {
        throw StateError('preview ${StoryEvent.maxPreview}자 초과: ${e.id} ($n)');
      }
    }
    final declines = e.choices.where((c) => c.decline).toList();
    if (!e.isCall) {
      if (declines.isNotEmpty) {
        throw StateError('decline 은 call 이벤트에만: ${e.id}');
      }
      return;
    }
    if (e.character == null) {
      throw StateError('call 이벤트는 character 필수: ${e.id}');
    }
    if (declines.length != 1) {
      throw StateError(
        'call 이벤트는 decline 선택지가 정확히 1개: ${e.id} (${declines.length})',
      );
    }
    final d = declines.single;
    if (d.require != null) throw StateError('decline 선택지에 require 금지: ${e.id}');
    if (d.minigame != null) {
      throw StateError('decline 선택지에 minigame 금지: ${e.id}');
    }
    if (d.chance != null) throw StateError('decline 선택지에 chance 금지: ${e.id}');
    if (e.choices.length < 2) {
      throw StateError('call 이벤트는 decline 이 아닌 선택지가 1개 이상: ${e.id}');
    }
  }

  /// 이름 자리표시자 형식(lib/engine/text_template.dart, docs/NAME_GUIDE.md).
  /// 모르는 조사·닫히지 않은 중괄호는 오류. 대체어 없는 `{mbti}` 는 [bareMbtiOk] 일 때만
  /// (MBTI 조건이 붙어 플레이어 MBTI 가 반드시 있는 곳).
  void _checkTemplate(String text, String where, {bool bareMbtiOk = false}) {
    final p = TextTemplate.problems(text);
    if (p.isNotEmpty) {
      throw StateError('자리표시자 오류: $where (${p.join(', ')}) "$text"');
    }
    if (!bareMbtiOk && TextTemplate.hasBareMbti(text)) {
      throw StateError(
        '{mbti} 는 mbti 조건이 붙은 줄·선택지에서만(아니면 {mbti|대체어}): $where "$text"',
      );
    }
    // `{char:<id>}` 는 런타임에 조용히 '그 사람'으로 떨어지므로, 오타를 여기서 잡아야
    // 아무도 모르게 이름이 사라지는 일이 없다(요청: 런타임이 아니라 검증 시점에 거부).
    for (final id in TextTemplate.charIdsIn(text)) {
      if (!characterById.containsKey(id)) {
        throw StateError('{char:$id} 가 없는 캐릭터를 지목: $where "$text"');
      }
    }
  }

  // ---- MBTI (docs/MBTI_SPEC.md §2.5) ----

  /// 줄·선택지 하나의 MBTI 조건 형식. [hasCharacter] 가 아니면 `compat` 금지.
  void _checkGate(
    String where, {
    required String? mbti,
    required bool noMbti,
    required Range? compat,
    required List<String> humor,
    required String? register,
    required bool hasCharacter,
  }) {
    for (final h in humor) {
      if (!Humor.isValid(h)) {
        throw StateError('humor 조건은 ${Humor.values.join('|')}: $where -> "$h"');
      }
    }
    if (humor.toSet().length != humor.length) {
      throw StateError('humor 조건에 같은 값이 두 번: $where $humor');
    }
    if (register != null && !Politeness.isValid(register)) {
      throw StateError(
        'register 는 ${Politeness.values.join('|')}: $where -> "$register"',
      );
    }
    if (mbti != null) {
      final p = Mbti.conditionProblem(mbti);
      if (p != null) throw StateError('mbti 조건 오류: $where ($p) "$mbti"');
      if (noMbti) throw StateError('mbti 와 noMbti 를 함께 쓸 수 없음: $where');
    }
    if (compat != null) {
      if (!hasCharacter) {
        throw StateError('compat 은 character 가 있는 이벤트·엔딩에서만: $where');
      }
      if (compat.min < 0 ||
          compat.max > Mbti.maxCompat ||
          compat.min > compat.max) {
        throw StateError('compat 범위는 0~${Mbti.maxCompat}: $where $compat');
      }
    }
  }

  /// 조건 붙은 줄·선택지를 볼 **경우의 수**를 모두 만든다.
  ///
  /// - 플레이어 축(`mbti`·`noMbti`·`compat`): 17가지(모름 + 16유형).
  /// - 상대 축(`humor`·`register`): 13가지(1위 없음 + 캐릭터 전원).
  ///
  /// 축이 안 쓰인 이벤트는 그 축을 한 경우로 접는다 — 조건이 붙지 않은 축을 17배·13배
  /// 돌아 봐야 결과가 같다.
  ///
  /// **1위 후보를 이 회차 선호로 좁히지 않는다.** `trigger.pref: "f"` 이벤트도
  /// [Preference.all] 회차에서는 열리고, 그 회차에는 남성 캐릭터가 1위일 수 있다
  /// ([StoryBundle.absentIds] 가 all 에서 아무도 빼지 않는다). 좁히면 검증이 거짓말을 한다.
  List<(String, MbtiView)> _viewCases(StoryEvent e) {
    final t = e.trigger;
    final charMbti = e.character != null
        ? characterById[e.character]?.mbti
        : null;
    final voiced = e.hasVoiceGates;
    final players = e.hasPlayerGates ? Mbti.playerCases : const <String?>[null];
    final voices = voiced
        ? <CharacterDef?>[null, ...characters]
        : const <CharacterDef?>[null];
    final out = <(String, MbtiView)>[];
    for (final p in players) {
      // 이벤트 트리거가 이 플레이어를 막으면 거른 결과는 볼 일이 없다.
      if (t.mbti != null && !Mbti.matches(t.mbti!, p)) continue;
      if (t.noMbti && p != null) continue;
      if (t.compat != null && !t.compat!.contains(Mbti.compat(p, charMbti))) {
        continue;
      }
      for (final voice in voices) {
        final v = MbtiView.of(p, charMbti, voice: voice);
        final label = [
          if (e.hasPlayerGates) 'MBTI ${p ?? '모름'}',
          if (voiced)
            voice == null
                ? '1위 없음(${v.humor}·${v.politeness})'
                : '1위 ${voice.name}(${v.humor}·${v.politeness})',
        ].join(' · ');
        out.add((label, v));
      }
    }
    return out;
  }

  /// 이벤트 하나의 조건 규칙: 조건 형식, 대체어 없는 `{mbti}` 위치, 그리고 [_viewCases]
  /// 각각에서 거른 뒤에도 대사·선택지·반응이 비지 않는지.
  ///
  /// 마지막 것이 이 검사의 존재 이유다. 씬의 대사가 전부 `humor`·`register` 로 갈려
  /// 있는데 다섯 값 중 하나가 빠지면 **그 값을 가진 캐릭터를 공략한 플레이어만 빈 화면**을
  /// 본다. 고백·첫 싸움 씬이 무음이던 것이 원래 이 버그였고(docs/review/11_story_verdict.md
  /// 4-7), 조건으로 다시 만들면 **데이터가 문법적으로 멀쩡해서** 나머지 테스트가 전부 초록인 채로
  /// 되살아난다. 그래서 검증기가 잡는다.
  void _checkMbti(StoryEvent e) {
    final hasChar = e.character != null;
    final t = e.trigger;
    // 이벤트 전체가 MBTI 를 아는 플레이어에게만 열리면 어디서든 {mbti} 를 써도 된다.
    final eventKnows = t.mbti != null;
    void bare(String text, String where, bool known) {
      if (!known && TextTemplate.hasBareMbti(text)) {
        throw StateError(
          '{mbti} 는 mbti 조건이 붙은 줄·선택지에서만(아니면 {mbti|대체어}): $where "$text"',
        );
      }
    }

    void lines(List<Line> ls, String where, bool known) {
      for (var i = 0; i < ls.length; i++) {
        final l = ls[i];
        _checkGate(
          '$where[$i]',
          mbti: l.mbti,
          noMbti: l.noMbti,
          compat: l.compat,
          humor: l.humor,
          register: l.register,
          hasCharacter: hasChar,
        );
        final k = known || l.mbti != null;
        bare(l.text, '$where[$i]', k);
        final p = l.photo;
        if (p != null) bare(p.caption, '$where[$i].photo.caption', k);
      }
    }

    bare(e.title, '${e.id}.title', eventKnows);
    if (e.preview != null) bare(e.preview!, '${e.id}.preview', eventKnows);
    if (e.cliffhanger != null) {
      bare(e.cliffhanger!, '${e.id}.cliffhanger', eventKnows);
    }
    lines(e.lines, '${e.id}.lines', eventKnows);
    for (var i = 0; i < e.variants.length; i++) {
      lines(e.variants[i], '${e.id}.variants[$i]', eventKnows);
    }
    for (var i = 0; i < e.choices.length; i++) {
      final c = e.choices[i];
      final where = '${e.id}.choices[$i]';
      _checkGate(
        where,
        mbti: c.mbti,
        noMbti: c.noMbti,
        compat: c.compat,
        humor: c.humor,
        register: c.register,
        hasCharacter: hasChar,
      );
      final known = eventKnows || c.mbti != null;
      bare(c.text, '$where.text', known);
      lines(c.reply, '$where.reply', known);
      lines(c.failReply, '$where.failReply', known);
      lines(c.critReply, '$where.critReply', known);
    }
    if (!e.hasMbtiGates) return;

    for (final (who, v) in _viewCases(e)) {
      final f = e.forMbti(v);
      if (e.lines.isNotEmpty && f.lines.isEmpty) {
        throw StateError('$who 플레이어에게 대사가 0줄: ${e.id}');
      }
      // 변형 대사 묶음도 화면 하나다. 본편만 덮고 변형을 빠뜨리면 그 묶음이 뽑힌 회차만
      // 무음이 되고, 그 회차는 시드가 정하므로 재현조차 어렵다([EventEngine.variantOf]).
      for (var i = 0; i < e.variants.length; i++) {
        if (e.variants[i].isNotEmpty && v.lines(e.variants[i]).isEmpty) {
          throw StateError('$who 플레이어에게 대사가 0줄: ${e.id}.variants[$i]');
        }
      }
      final need = e.choices.length >= 2 ? 2 : 1;
      if (f.choices.length < need) {
        throw StateError(
          '$who 플레이어에게 선택지가 ${f.choices.length}개(최소 $need): ${e.id}',
        );
      }
      if (e.isCall && f.declineIndex == null) {
        throw StateError('$who 플레이어에게 전화 거절 선택지가 없음: ${e.id}');
      }
      final orig = [
        for (final c in e.choices)
          if (v.allowsChoice(c)) c,
      ];
      for (var i = 0; i < orig.length; i++) {
        final o = orig[i];
        final c = f.choices[i];
        for (final (name, a, b) in [
          ('reply', o.reply, c.reply),
          ('failReply', o.failReply, c.failReply),
          ('critReply', o.critReply, c.critReply),
        ]) {
          if (a.isNotEmpty && b.isEmpty) {
            throw StateError('$who 플레이어에게 반응이 0줄: ${e.id} "${o.text}".$name');
          }
        }
      }
    }
  }

  /// 치환하지 않는 필드(이름·앨범 제목·한 줄 매력)에 자리표시자가 있으면 오류.
  void _checkNoTemplate(String text, String where) {
    if (text.contains('{') || text.contains('}')) {
      throw StateError('이 필드에는 자리표시자·중괄호를 쓸 수 없음: $where "$text"');
    }
  }

  /// 대사·반응 줄의 사진 설명 길이.
  void _checkLines(List<Line> lines, String where) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final sticker = line.sticker;
      if (sticker != null && !Sticker.isValid(sticker)) {
        throw StateError(
          'sticker 는 <캐릭터>_<${Sticker.emotions.join('|')}> 또는 '
          '${Sticker.extras.join('|')}: $where[$i] -> "$sticker"',
        );
      }
      final p = line.photo;
      if (p == null) continue;
      _checkImage(p.image, '$where[$i].photo.image');
      final n = TextTemplate.maxLength(p.caption, chars: charNames);
      if (n > Photo.maxCaption) {
        throw StateError(
          'photo caption ${Photo.maxCaption}자 초과: $where[$i] ($n)',
        );
      }
    }
  }

  /// 행동 장면(`trigger.action`)은 일상층이고, 아는 아침 행동만 가리킨다.
  /// 오타 난 행동 id 는 조용히 영영 안 열리는 장면이 되므로 여기서 막는다.
  void _checkActionScene(StoryEvent e) {
    final acts = e.trigger.action;
    if (acts.isEmpty) return;
    if (e.layer != EventLayer.daily) {
      throw StateError('trigger.action 은 daily 이벤트에만: ${e.id}');
    }
    final known = {for (final a in config.actions) a.id};
    for (final a in acts) {
      if (!known.contains(a)) {
        throw StateError('없는 아침 행동: ${e.id}.trigger.action -> $a');
      }
    }
  }

  /// 그림 경로 형식(06 §4). `assets/` 로 시작하는 한 줄만 본다 — **파일이 있는지는
  /// 검사하지 않는다**. 그림은 나중에 들어오고, 없으면 화면이 지금과 같을 뿐이다.
  void _checkImage(String? path, String where) {
    if (path == null) return;
    if (!AssetPath.isValid(path)) {
      throw StateError(
        'image 는 ${AssetPath.prefix} 로 시작하는 경로: $where -> "$path"',
      );
    }
  }

  void _checkStatKeys(Iterable<String> keys, String where) {
    for (final k in keys) {
      if (!Stat.all.contains(k)) throw StateError('없는 스탯 키: $where -> $k');
    }
  }

  void _checkCharKeys(Iterable<String> keys, String where) {
    for (final k in keys) {
      if (k != '*' && !characterById.containsKey(k)) {
        throw StateError('없는 캐릭터 키: $where -> $k');
      }
    }
  }

  void _checkTrigger(Trigger t, String where, {bool hasCharacter = false}) {
    final p = t.pref;
    if (p != null && !Preference.genders.contains(p)) {
      throw StateError('pref 는 f|m: $where -> $p');
    }
    _checkGate(
      where,
      mbti: t.mbti,
      noMbti: t.noMbti,
      compat: t.compat,
      // 트리거에는 상대 축이 없다. 1위의 농담 코드로 **이벤트**를 가르면 같은 날 열릴
      // 후보가 5벌로 늘고(planDay 는 조건을 만족하는 main 을 전부 큐에 넣는다) 상호배타도
      // 보장되지 않는다 — 가르는 자리는 줄이지 이벤트가 아니다(12_main_rewrite §5.2).
      humor: const [],
      register: null,
      hasCharacter: hasCharacter,
    );
    final fc = t.flagsAtLeast;
    if (fc != null && (fc.of.isEmpty || fc.n < 1 || fc.n > fc.of.length)) {
      throw StateError(
        'flagsAtLeast 는 1 ≤ n ≤ of 개수: $where (n ${fc.n}, of ${fc.of.length})',
      );
    }
    _checkStatKeys(t.stats.keys, where);
    _checkCharKeys(t.affection.keys, '$where.affection');
    _checkCharKeys(t.trust.keys, '$where.trust');
  }

  void _checkEffects(Effects e, String where) {
    _checkStatKeys(e.stats.keys, where);
    // `@top`(지금 가장 가까운 사람)은 효과에서만 쓸 수 있다.
    _checkCharKeys(
      e.affection.keys.where((k) => k != topKey),
      '$where.affection',
    );
    _checkCharKeys(e.trust.keys.where((k) => k != topKey), '$where.trust');
  }

  /// 치명적이지는 않지만 의도와 다를 가능성이 큰 데이터. 출시 전 점검용.
  /// 예: character 가 없는 이벤트에서 `*` 를 쓰면 그 효과는 조용히 버려진다.
  ///
  /// 캐스트 빈칸(한쪽 성별에 역할이 없음)은 `캐스트:` 로 시작하는 경고로 알린다.
  List<String> lint() {
    final out = <String>[
      for (final e in castGaps.entries)
        '$castLintPrefix ${Preference.label(e.key)} 쪽에 역할 없음: ${e.value.join(', ')}',
    ];

    for (final e in events) {
      final h = e.hint;
      if (h != null && h >= 0 && h < e.choices.length && e.choices[h].isGated) {
        // 조건의 종류를 밝힌다. `isGated` 는 플레이어 축(MBTI·궁합)과 상대 축
        // (humor·register)을 함께 보는데, 문구가 "MBTI" 로만 되어 있어서 말높임 두 벌을
        // 쓰려던 사람이 원인을 못 찾았다(docs/review/13_main_voices.md §2).
        //
        // 상대 축도 여기서 막는 것은 맞다: `hint` 는 **번호**이고 `forMbti` 는 그 번호가
        // 살아남을 때만 힌트를 옮긴다. 그래서 한 선택지를 casual·polite 두 벌로 쪼개면
        // 번호가 붙은 쪽만 힌트를 갖고 나머지 쪽 플레이어는 힌트를 잃는다.
        // 두 벌로 쪼개려면 `hint` 를 번호가 아닌 표식으로 바꾸는 작업이 먼저다.
        final kind = e.choices[h].isVoiceGated
            ? (e.choices[h].isPlayerGated ? 'MBTI·목소리' : '목소리(humor/register)')
            : 'MBTI';
        out.add('${e.id}: hint 선택지에 $kind 조건 (맞지 않는 플레이어에게는 힌트가 없음)');
      }
    }
    for (final e in events) {
      if (e.character != null) continue;
      bool star(Map<String, Object?> m) => m.containsKey('*');
      if (star(e.trigger.affection) || star(e.trigger.trust)) {
        out.add('${e.id}: character 없이 trigger 에 * 사용');
      }
      for (var i = 0; i < e.choices.length; i++) {
        final c = e.choices[i];
        for (final (label, fx) in [('effects', c.effects), ('fail', c.fail)]) {
          if (star(fx.affection) || star(fx.trust)) {
            out.add('${e.id}.choices[$i].$label: character 없이 * 사용 (효과가 버려짐)');
          }
        }
        final req = c.require;
        if (req != null && (star(req.affection) || star(req.trust))) {
          out.add('${e.id}.choices[$i].require: character 없이 * 사용 (항상 잠김)');
        }
      }
    }
    // main 쪽별 버전은 짝이 맞아야 한쪽 회차에만 빈 날이 생기지 않는다.
    final mainSides = <int, Set<String?>>{};
    for (final e in events.where((e) => e.layer == EventLayer.main)) {
      mainSides.putIfAbsent(e.day!, () => {}).add(e.trigger.pref);
    }
    for (final d in mainSides.keys.toList()..sort()) {
      final sides = mainSides[d]!;
      if (sides.contains(null)) continue;
      for (final g in Preference.genders) {
        if (!sides.contains(g)) {
          out.add('main $d일: ${Preference.label(g)} 쪽 버전 없음');
        }
      }
    }
    for (final e in endings) {
      if (e.character == null &&
          (e.when.affection.containsKey('*') ||
              e.when.trust.containsKey('*'))) {
        out.add('ending ${e.id}: character 없이 * 사용 (절대 도달 불가)');
      }
    }
    return out;
  }

  /// [lint] 의 캐스트 빈칸 경고 머리말.
  static const castLintPrefix = '캐스트:';

  /// 레이어별 이벤트 수. 콘텐츠 분량 확인용.
  Map<EventLayer, int> get countByLayer {
    final m = {for (final l in EventLayer.values) l: 0};
    for (final e in events) {
      m[e.layer] = m[e.layer]! + 1;
    }
    return m;
  }
}
