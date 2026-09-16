import 'models.dart';

extension TriggerMatch on Trigger {
  /// [self] 는 이벤트나 엔딩이 속한 캐릭터 id. 조건 키 `*` 가 여기에 매핑된다.
  bool matches(GameState s, {String? self}) {
    if (day != null && !day!.contains(s.day)) return false;
    if (run != null && !run!.contains(s.run)) return false;
    for (final e in stats.entries) {
      if (!e.value.contains(s.stat(e.key))) return false;
    }
    for (final e in affection.entries) {
      final id = e.key == '*' ? self : e.key;
      if (id == null || !e.value.contains(s.affectionOf(id))) return false;
    }
    for (final e in trust.entries) {
      final id = e.key == '*' ? self : e.key;
      if (id == null || !e.value.contains(s.trustOf(id))) return false;
    }
    for (final f in flags) {
      if (!s.flags.contains(f)) return false;
    }
    for (final f in notFlags) {
      if (s.flags.contains(f)) return false;
    }
    final any = anyAffection;
    if (any != null) {
      final n = s.relations.values.where((r) => r.affection >= any.min).length;
      if (n < any.count) return false;
    }
    return true;
  }
}

extension RequirementCheck on Requirement {
  bool satisfied(GameState s, {String? self}) {
    for (final e in stats.entries) {
      if (s.stat(e.key) < e.value) return false;
    }
    for (final e in affection.entries) {
      final id = e.key == '*' ? self : e.key;
      if (id == null || s.affectionOf(id) < e.value) return false;
    }
    for (final e in trust.entries) {
      final id = e.key == '*' ? self : e.key;
      if (id == null || s.trustOf(id) < e.value) return false;
    }
    for (final f in flags) {
      if (!s.flags.contains(f)) return false;
    }
    return true;
  }

  /// 잠긴 선택지 옆에 보여 줄 문구. 예: "자존감 40↑"
  String describe() {
    final parts = <String>[
      for (final e in stats.entries) '${Stat.label(e.key)} ${e.value}↑',
      for (final e in affection.entries) '호감 ${e.value}↑',
      for (final e in trust.entries) '신뢰 ${e.value}↑',
    ];
    return parts.join(' · ');
  }
}
