import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'effects.dart';
import 'models.dart';
import 'signals.dart';

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
    );
  }

  /// 이벤트가 참조하는 미니게임 id 전부.
  Set<String> get referencedMinigames => {
    for (final e in events)
      for (final c in e.choices)
        if (c.minigame != null) c.minigame!,
  };

  /// 데이터 오류를 출시 전에 잡기 위한 검사. 문제가 있으면 예외.
  /// [knownMinigames] 를 주면 없는 미니게임 참조도 함께 잡는다.
  /// [requireEndingHints] 면 엔딩마다 비어 있지 않은 `hint` 가 있어야 한다.
  /// 테스트용 합성 번들은 힌트를 생략하므로 기본은 끈다.
  void validate({
    Set<String>? knownMinigames,
    bool requireEndingHints = false,
  }) {
    final ids = <String>{};
    final charIds = <String>{};
    for (final c in characters) {
      if (!charIds.add(c.id)) throw StateError('캐릭터 id 중복: ${c.id}');
    }
    _checkCast();
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
      _checkTrigger(e.trigger, '${e.id}.trigger');
      _checkMoment(e);
      _checkLines(e.lines, '${e.id}.lines');
      for (var i = 0; i < e.choices.length; i++) {
        final c = e.choices[i];
        final where = '${e.id}.choices[$i]';
        final chance = c.chance;
        if (chance != null && (chance < 0 || chance > 100)) {
          throw StateError('chance 범위 밖(0~100): $where = $chance');
        }
        _checkEffects(c.effects, '$where.effects');
        _checkEffects(c.fail, '$where.fail');
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
      _checkTrigger(e.when, 'ending ${e.id}');
      if (requireEndingHints && (e.hint ?? '').trim().isEmpty) {
        throw StateError('엔딩 hint 없음: ${e.id}');
      }
    }
    if (!endings.any((e) => e.isDefault)) throw StateError('default 엔딩이 없음');

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
      if (preview.length > StoryEvent.maxPreview) {
        throw StateError(
          'preview ${StoryEvent.maxPreview}자 초과: ${e.id} (${preview.length})',
        );
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

  /// 대사·반응 줄의 사진 설명 길이.
  void _checkLines(List<Line> lines, String where) {
    for (var i = 0; i < lines.length; i++) {
      final p = lines[i].photo;
      if (p != null && p.caption.length > Photo.maxCaption) {
        throw StateError(
          'photo caption ${Photo.maxCaption}자 초과: $where[$i] (${p.caption.length})',
        );
      }
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

  void _checkTrigger(Trigger t, String where) {
    final p = t.pref;
    if (p != null && !Preference.genders.contains(p)) {
      throw StateError('pref 는 f|m: $where -> $p');
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
