import 'mbti.dart';
import 'models.dart';

extension TriggerMatch on Trigger {
  /// [self] 는 이벤트나 엔딩이 속한 캐릭터 id. 조건 키 `*` 가 여기에 매핑된다.
  ///
  /// [absent] 는 이 회차 선호 밖이라 등장하지 않는 캐릭터 id. 그 캐릭터를 직접 가리키는
  /// 호감·신뢰 조건은 건너뛰고(없는 사람은 조건에서 빠진다), `anyAffection` 도 세지 않는다.
  /// `pref` 가 있으면 [GameState.preference] 쪽과 같아야 한다([Preference.allowsSide]).
  ///
  /// MBTI(docs/MBTI_SPEC.md §1.3): `mbti` 는 [GameState.mbti] 에 글자가 모두 있어야,
  /// `noMbti` 는 [GameState.mbti] 가 null 이어야 참. `compat` 은 [self] 캐릭터의 MBTI
  /// [selfMbti] 와의 궁합 점수 범위다([self] 가 없으면 거짓).
  bool matches(
    GameState s, {
    String? self,
    String? selfMbti,
    Set<String> absent = const {},
  }) {
    if (!Preference.allowsSide(s.preference, pref)) return false;
    final m = mbti;
    if (m != null && !Mbti.matches(m, s.mbti)) return false;
    if (noMbti && s.mbti != null) return false;
    final c = compat;
    if (c != null &&
        (self == null || !c.contains(Mbti.compat(s.mbti, selfMbti)))) {
      return false;
    }
    final fc = flagsAtLeast;
    if (fc != null && fc.of.where(s.flags.contains).length < fc.n) return false;
    if (day != null && !day!.contains(s.day)) return false;
    if (run != null && !run!.contains(s.run)) return false;
    for (final e in stats.entries) {
      if (!e.value.contains(s.stat(e.key))) return false;
    }
    for (final e in affection.entries) {
      final id = e.key == '*' ? self : e.key;
      if (id != null && absent.contains(id)) continue;
      if (id == null || !e.value.contains(s.affectionOf(id))) return false;
    }
    for (final e in trust.entries) {
      final id = e.key == '*' ? self : e.key;
      if (id != null && absent.contains(id)) continue;
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
      var n = 0;
      s.relations.forEach((id, r) {
        if (!absent.contains(id) && r.affection >= any.min) n++;
      });
      if (n < any.count) return false;
    }
    return true;
  }
}

extension RequirementCheck on Requirement {
  /// [absent] 는 [TriggerMatch.matches] 와 같다. 선호 밖 캐릭터를 요구하는 잠금은 건너뛴다.
  bool satisfied(GameState s, {String? self, Set<String> absent = const {}}) {
    for (final e in stats.entries) {
      if (s.stat(e.key) < e.value) return false;
    }
    for (final e in affection.entries) {
      final id = e.key == '*' ? self : e.key;
      if (id != null && absent.contains(id)) continue;
      if (id == null || s.affectionOf(id) < e.value) return false;
    }
    for (final e in trust.entries) {
      final id = e.key == '*' ? self : e.key;
      if (id != null && absent.contains(id)) continue;
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
