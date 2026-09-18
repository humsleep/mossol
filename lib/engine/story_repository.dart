import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

/// 스토리 데이터 묶음. JSON 4개 파일에서 만들어진다.
class StoryBundle {
  final GameConfig config;
  final List<CharacterDef> characters;
  final List<StoryEvent> events;
  final List<Ending> endings;
  late final Map<String, StoryEvent> eventById = {for (final e in events) e.id: e};
  late final Map<String, CharacterDef> characterById = {for (final c in characters) c.id: c};

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
  });

  /// 이벤트는 레이어별로 파일이 나뉘어 있다. 파일을 추가하면 여기에만 이름을 넣으면 된다.
  static const eventFiles = [
    'events_main.json',
    'events_route_a.json',
    'events_route_b.json',
    'events_daily.json',
    'events_special.json',
  ];

  factory StoryBundle.fromJsonStrings({
    required String config,
    required String characters,
    required List<String> events,
    required String endings,
    Set<String>? knownMinigames,
    bool requireEndingHints = false,
  }) {
    final bundle = StoryBundle(
      config: GameConfig.fromJson(jsonDecode(config) as Map<String, dynamic>),
      characters: (jsonDecode(characters) as List)
          .map((e) => CharacterDef.fromJson(e as Map<String, dynamic>))
          .toList(),
      events: [
        for (final raw in events)
          ...(jsonDecode(raw) as List)
              .map((e) => StoryEvent.fromJson(e as Map<String, dynamic>)),
      ],
      endings: (jsonDecode(endings) as List)
          .map((e) => Ending.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    bundle.validate(knownMinigames: knownMinigames, requireEndingHints: requireEndingHints);
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
      eventFiles.map((f) => rootBundle.loadString('$dir/$f')),
    );
    return StoryBundle.fromJsonStrings(
      config: config,
      characters: characters,
      events: events,
      endings: endings,
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
  void validate({Set<String>? knownMinigames, bool requireEndingHints = false}) {
    final ids = <String>{};
    final charIds = <String>{};
    for (final c in characters) {
      if (!charIds.add(c.id)) throw StateError('캐릭터 id 중복: ${c.id}');
    }
    _checkStatKeys(config.initialStats.keys, 'config.initialStats');
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
      for (var i = 0; i < e.choices.length; i++) {
        final c = e.choices[i];
        final where = '${e.id}.choices[$i]';
        final chance = c.chance;
        if (chance != null && (chance < 0 || chance > 100)) {
          throw StateError('chance 범위 밖(0~100): $where = $chance');
        }
        _checkEffects(c.effects, '$where.effects');
        _checkEffects(c.fail, '$where.fail');
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
          if (n != null && !ids.contains(n)) throw StateError('없는 next 참조: ${e.id} -> $n');
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
    final mainDays = <int, String>{};
    for (final e in events.where((e) => e.layer == EventLayer.main)) {
      final prev = mainDays[e.day!];
      if (prev != null) throw StateError('main 날짜 중복: ${e.day}일 ($prev, ${e.id})');
      mainDays[e.day!] = e.id;
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
    _checkStatKeys(t.stats.keys, where);
    _checkCharKeys(t.affection.keys, '$where.affection');
    _checkCharKeys(t.trust.keys, '$where.trust');
  }

  void _checkEffects(Effects e, String where) {
    _checkStatKeys(e.stats.keys, where);
    _checkCharKeys(e.affection.keys, '$where.affection');
    _checkCharKeys(e.trust.keys, '$where.trust');
  }

  /// 치명적이지는 않지만 의도와 다를 가능성이 큰 데이터. 출시 전 점검용.
  /// 예: character 가 없는 이벤트에서 `*` 를 쓰면 그 효과는 조용히 버려진다.
  List<String> lint() {
    final out = <String>[];
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
    for (final e in endings) {
      if (e.character == null && (e.when.affection.containsKey('*') || e.when.trust.containsKey('*'))) {
        out.add('ending ${e.id}: character 없이 * 사용 (절대 도달 불가)');
      }
    }
    return out;
  }

  /// 레이어별 이벤트 수. 콘텐츠 분량 확인용.
  Map<EventLayer, int> get countByLayer {
    final m = {for (final l in EventLayer.values) l: 0};
    for (final e in events) {
      m[e.layer] = m[e.layer]! + 1;
    }
    return m;
  }
}
