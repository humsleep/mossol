import 'conditions.dart';
import 'models.dart';

class EndingResolver {
  final List<Ending> endings;

  EndingResolver(this.endings);

  /// 조건 충족 즉시 게임을 끝내는 엔딩. 매일 마감 후 검사.
  Ending? immediate(GameState s) {
    for (final e in _sorted().where((e) => e.immediate)) {
      if (e.when.matches(s, self: e.character)) return e;
    }
    return null;
  }

  /// 100일 종료 시 엔딩. 우선순위가 같으면 호감도가 높은 캐릭터의 엔딩,
  /// 그것도 같으면 endings.json 에 먼저 적힌 것. (List.sort 는 안정 정렬을
  /// 보장하지 않으므로 원래 순서를 명시적으로 비교한다.)
  Ending resolve(GameState s) {
    final sorted = _sorted();
    var i = 0;
    while (i < sorted.length) {
      final p = sorted[i].priority;
      final tier = <Ending>[];
      while (i < sorted.length && sorted[i].priority == p) {
        final e = sorted[i++];
        if (e.when.matches(s, self: e.character)) tier.add(e);
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
