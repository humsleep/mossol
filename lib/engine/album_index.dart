import 'models.dart';

/// 흑역사 한 장이 어디서 나왔는지. 앨범 상세에서 "그날 무슨 일이" 를 다시 보여 준다.
///
/// 세이브에는 흑역사 제목만 남으므로(예전 세이브 호환) 제목으로 스토리 데이터를
/// 거꾸로 찾는다. 같은 제목이 여러 이벤트에 있으면(남녀 쌍 `_m` 등) [roster] 에 있는
/// 캐릭터의 것을 먼저, 그다음 캐릭터 없는 이벤트를 고른다.
class ShameSource {
  final StoryEvent event;
  final Choice choice;

  /// 실패해서 남은 흑역사면 true(`fail.album`), 선택 자체가 흑역사면 false(`effects.album`).
  final bool failed;

  const ShameSource(this.event, this.choice, {required this.failed});

  /// 그 선택 뒤에 돌아온 반응. 대기 줄(`sys`)은 뺀다.
  List<Line> get aftermath => [
    for (final l in failed ? choice.failReply : choice.reply)
      if (l.text.isNotEmpty) l,
  ];

  /// 선택 직전 장면에서 마지막 대사 몇 줄(맥락).
  List<Line> setup({int max = 2}) {
    final said = [
      for (final l in event.lines)
        if (l.text.isNotEmpty) l,
    ];
    return said.length <= max ? said : said.sublist(said.length - max);
  }
}

abstract final class AlbumIndex {
  /// [title] 흑역사의 출처. 못 찾으면 null(데이터에서 빠진 옛 흑역사 등).
  static ShameSource? find(
    Iterable<StoryEvent> events,
    String title, {
    Set<String> roster = const {},
  }) {
    ShameSource? neutral;
    ShameSource? other;
    for (final e in events) {
      for (final c in e.choices) {
        final ShameSource hit;
        if (c.fail.album == title) {
          hit = ShameSource(e, c, failed: true);
        } else if (c.effects.album == title) {
          hit = ShameSource(e, c, failed: false);
        } else {
          continue;
        }
        final ch = e.character;
        if (ch != null && roster.contains(ch)) return hit;
        if (ch == null) {
          neutral ??= hit;
        } else {
          other ??= hit;
        }
      }
    }
    return neutral ?? other;
  }
}
