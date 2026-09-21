import 'conditions.dart';
import 'models.dart';

class EndingResolver {
  final List<Ending> endings;

  /// 캐릭터 성별로 엔딩을 거르는 데 쓴다. 비어 있으면(예전 호출부) 거르지 않는다.
  final List<CharacterDef> characters;

  EndingResolver(this.endings, {this.characters = const []});

  /// 캐릭터 id → MBTI. 엔딩 `when.compat` 이 그 엔딩 캐릭터와의 궁합을 본다.
  late final Map<String, String?> _mbti = {
    for (final c in characters) c.id: c.mbti,
  };

  /// [s] 회차 선호 밖이라 등장하지 않는 캐릭터 id.
  Set<String> _absent(GameState s) => {
    for (final c in characters)
      if (!c.appearsIn(s.preference)) c.id,
  };

  /// 이 회차에 나올 수 있는 엔딩인지와 조건 충족. 선호 밖 캐릭터의 엔딩은 후보가 아니고,
  /// 공용 엔딩 조건이 선호 밖 캐릭터를 가리키면 그 조건은 건너뛴다(`when.pref` 는 matches 가 본다).
  bool _hits(GameState s, Ending e, Set<String> absent) {
    final ch = e.character;
    if (ch != null && absent.contains(ch)) return false;
    return e.when.matches(
      s,
      self: ch,
      selfMbti: ch == null ? null : _mbti[ch],
      absent: absent,
    );
  }

  /// 조건 충족 즉시 게임을 끝내는 엔딩. 매일 마감 후 검사.
  Ending? immediate(GameState s) {
    final absent = _absent(s);
    for (final e in _sorted().where((e) => e.immediate)) {
      if (_hits(s, e, absent)) return e;
    }
    return null;
  }

  /// 100일 종료 시 엔딩. 우선순위가 같으면 호감도가 높은 캐릭터의 엔딩,
  /// 그것도 같으면 endings.json 에 먼저 적힌 것. (List.sort 는 안정 정렬을
  /// 보장하지 않으므로 원래 순서를 명시적으로 비교한다.)
  Ending resolve(GameState s) {
    final absent = _absent(s);
    final sorted = _sorted();
    var i = 0;
    while (i < sorted.length) {
      final p = sorted[i].priority;
      final tier = <Ending>[];
      while (i < sorted.length && sorted[i].priority == p) {
        final e = sorted[i++];
        if (_hits(s, e, absent)) tier.add(e);
      }
      if (tier.isEmpty) continue;
      tier.sort((a, b) {
        final aa = a.character == null ? -1 : s.affectionOf(a.character!);
        final bb = b.character == null ? -1 : s.affectionOf(b.character!);
        if (aa != bb) return bb.compareTo(aa);
        return _index[a]!.compareTo(_index[b]!);
      });
      return tier.first;
    }
    return endings.firstWhere((e) => e.isDefault, orElse: () => endings.last);
  }

  late final Map<Ending, int> _index = {
    for (var i = 0; i < endings.length; i++) endings[i]: i,
  };

  /// 우선순위 내림차순, 같은 우선순위면 파일 순서.
  List<Ending> _sorted() {
    final list = List<Ending>.of(endings);
    list.sort((a, b) {
      if (a.priority != b.priority) return b.priority.compareTo(a.priority);
      return _index[a]!.compareTo(_index[b]!);
    });
    return list;
  }
}
