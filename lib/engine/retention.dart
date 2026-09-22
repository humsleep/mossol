/// 리텐션 장치(docs/ROADMAP.md Phase 1)의 순수 로직. 새 스토리 없이 있는 데이터만 쓴다.
///
/// - [NextRunAdvisor]: 엔딩 화면 "다음 판" 카드 — 권할 캐릭터 · 못 본 엔딩 힌트 · 반대쪽 권유.
/// - [TomorrowPeek]: 하루 정산의 "내일 ○○에게서 연락이 올 것 같다" 한 줄.
/// - [previousRunLineFor]: 새 회차 첫날의 "지난 판엔 ○○와 …으로 끝났다" 한 줄.
///
/// 전부 상태를 바꾸지 않는다. 화면·광고·분석에 의존하지 않으므로 그대로 단위 테스트한다.
library;

import 'event_engine.dart';
import 'mbti.dart';
import 'models.dart';
import 'story_repository.dart';
import 'text_template.dart';

// ---------------------------------------------------------------------------
// 다음 판 권하기
// ---------------------------------------------------------------------------

/// 엔딩 화면 "다음 판" 카드에 들어갈 것.
class NextRunSuggestion {
  /// 권하는 캐릭터. 권할 사람이 없으면(그 쪽 엔딩을 전부 봤고 캐릭터도 없음) null.
  final CharacterDef? character;

  /// 플레이어 MBTI 와의 궁합(0~4). 플레이어 MBTI 가 없으면 null.
  final int? compat;

  /// 캐릭터 아래 한 줄. 궁합 4·3 이면 궁합 문장, 아니면 중립 문장.
  final String reason;

  /// 아직 못 본 엔딩 하나(힌트를 보여 줄 것). 전부 봤으면 null.
  final Ending? hintEnding;

  /// 한쪽만 해 봤으면 반대쪽([Preference.female]·[Preference.male]). 아니면 null.
  final String? otherSide;

  const NextRunSuggestion({
    required this.character,
    required this.compat,
    required this.reason,
    required this.hintEnding,
    required this.otherSide,
  });
}

class NextRunAdvisor {
  final StoryBundle bundle;
  const NextRunAdvisor(this.bundle);

  static const destinyLine = '당신 MBTI와 천생연분이에요';
  static const goodMatchLine = '당신 MBTI와 잘 맞아요';
  static const neverLine = '아직 끝까지 가 본 적 없는 사람이에요';
  static const fewLine = '아직 못 본 이야기가 많이 남은 사람이에요';

  /// [side] 는 방금 끝난 회차의 선호([Preference]). `all`(예전 세이브)이면 모든 캐릭터.
  /// [album] 은 모은 엔딩 id(방금 본 것 포함). [justEnded] 는 방금 본 엔딩 — 그 캐릭터는
  /// 다른 후보가 있으면 권하지 않는다(다음 판은 새 사람을 만나는 쪽이 더 궁금하다).
  /// 히든 캐릭터는 권하지 않는다(정체가 스포일러다).
  NextRunSuggestion suggest({
    required String side,
    required List<String> album,
    required String? playerMbti,
    Ending? justEnded,
  }) {
    final got = album.toSet();
    final mbti = Mbti.parse(playerMbti);
    final cast = [
      for (final c in bundle.charactersFor(side))
        if (!c.hidden) c,
    ];

    List<Ending> endingsOf(String id) => [
      for (final e in bundle.endings)
        if (e.character == id) e,
    ];
    int seen(String id) =>
        endingsOf(id).where((e) => got.contains(e.id)).length;
    bool hasUnseen(String id) => endingsOf(id).any((e) => !got.contains(e.id));

    var pool = [
      for (final c in cast)
        if (hasUnseen(c.id)) c,
    ];
    if (pool.isEmpty) pool = cast;
    final ended = justEnded?.character;
    if (pool.length > 1) {
      pool = [
        for (final c in pool)
          if (c.id != ended) c,
      ];
    }

    final order = {for (var i = 0; i < cast.length; i++) cast[i].id: i};
    int compatOf(CharacterDef c) => Mbti.compat(mbti, c.mbti);
    pool.sort((a, b) {
      if (mbti != null) {
        final d = compatOf(b) - compatOf(a);
        if (d != 0) return d;
      }
      final s = seen(a.id) - seen(b.id);
      if (s != 0) return s;
      return order[a.id]! - order[b.id]!;
    });

    final pick = pool.isEmpty ? null : pool.first;
    final compat = (pick == null || mbti == null) ? null : compatOf(pick);
    final reason = switch (compat) {
      4 => destinyLine,
      3 => goodMatchLine,
      _ => pick != null && seen(pick.id) == 0 ? neverLine : fewLine,
    };

    return NextRunSuggestion(
      character: pick,
      compat: compat,
      reason: reason,
      hintEnding: _hint(pick, compat, got, side),
      otherSide: _otherSide(side, got),
    );
  }

  /// 권한 사람의 못 본 엔딩(천생연분 궁합이면 천생연분, 아니면 해피 → 굿 순). 없으면 이
  /// 쪽 공용 엔딩 중 못 본 해피·굿·솔로. 배드·히든·기본 엔딩은 목표로 권하지 않는다.
  Ending? _hint(CharacterDef? pick, int? compat, Set<String> got, String side) {
    bool open(Ending e) =>
        !got.contains(e.id) &&
        !e.isDefault &&
        e.tier != 'bad' &&
        e.tier != 'hidden';
    if (pick != null) {
      final mine = [
        for (final e in bundle.endings)
          if (e.character == pick.id && open(e)) e,
      ];
      int rank(Ending e) {
        final destiny = e.id.endsWith('_destiny');
        if (destiny) return compat == Mbti.maxCompat ? 0 : 2;
        return e.tier == 'happy' ? 1 : 3;
      }

      mine.sort((a, b) => rank(a) - rank(b));
      if (mine.isNotEmpty) return mine.first;
    }
    for (final e in bundle.endings) {
      if (e.character == null &&
          open(e) &&
          bundle.endingInPreference(e, side)) {
        return e;
      }
    }
    return null;
  }

  /// 해 본 쪽이 하나뿐이면 반대쪽. 앨범의 캐릭터 엔딩 쪽 + 방금 회차의 쪽으로 판단한다.
  /// 예전 세이브(`all`)는 두 쪽을 다 만난 것으로 본다.
  String? _otherSide(String side, Set<String> got) {
    if (side == Preference.all) return null;
    final sides = <String>{side};
    for (final e in bundle.endings) {
      if (!got.contains(e.id) || e.character == null) continue;
      final s = bundle.endingSide(e);
      if (s != null) sides.add(s);
    }
    if (sides.length > 1) return null;
    return side == Preference.female ? Preference.male : Preference.female;
  }
}

// ---------------------------------------------------------------------------
// 내일 예고
// ---------------------------------------------------------------------------

/// 정산의 "내일 ○○에게서 연락이 올 것 같다".
class TomorrowHint {
  final String characterId;

  /// 모먼트 알림 미리보기(`preview`, 원문 — 이름 치환 전). 없으면 null.
  final String? preview;

  final String eventId;

  const TomorrowHint({
    required this.characterId,
    required this.preview,
    required this.eventId,
  });
}

/// 내일 계획을 **사본**으로 미리 본다. [EventEngine.planDay] 는 (seed, day, salt) 난수만
/// 쓰고 상태를 바꾸지 않으며, 마감([EventEngine.endDay])은 사본에만 적용한다. 그래서
/// 미리 봐도 진짜 내일의 계획·난수는 그대로다.
///
/// 내일 아침 행동·룰렛으로 스탯이 바뀌면 조건이 달라질 수 있어 "~것 같다" 로 말한다.
class TomorrowPeek {
  final EventEngine engine;
  const TomorrowPeek(this.engine);

  /// [s] 의 오늘을 [cliffhanger] 로 닫았을 때 내일 연락해 올 사람. 없으면 null.
  ///
  /// 고르는 순서: 모먼트(전화·알림·사진) → 캐릭터 루트 → 그 밖의 캐릭터 이벤트, 같은 층
  /// 안에서는 계획 순서. 선호 밖 캐릭터, 아직 호감이 없는 히든 캐릭터는 이름을 대지 않는다.
  /// 내일이 없으면(마지막 날) null.
  TomorrowHint? peek(GameState s, {String? cliffhanger}) {
    final clone = GameState.fromJson(s.toJson());
    engine.endDay(clone, cliffhanger: cliffhanger);
    if (engine.isFinished(clone)) return null;
    final roster = {for (final c in engine.rosterFor(clone)) c.id: c};
    final plan = engine.planDay(clone);
    int rank(StoryEvent e) =>
        e.isMoment ? 0 : (e.layer == EventLayer.route ? 1 : 2);
    StoryEvent? best;
    for (final e in plan) {
      final id = e.character;
      final ch = id == null ? null : roster[id];
      if (ch == null) continue;
      if (ch.hidden && clone.affectionOf(ch.id) <= 0) continue;
      if (best == null || rank(e) < rank(best)) best = e;
    }
    if (best == null) return null;
    final p = best.preview?.trim();
    return TomorrowHint(
      characterId: best.character!,
      preview: (p == null || p.isEmpty) ? null : p,
      eventId: best.id,
    );
  }

  /// 화면 문장. [name] 은 캐릭터 이름.
  static String lineFor(String name) => '내일 $name에게서 연락이 올 것 같다';
}

// ---------------------------------------------------------------------------
// 이전 회차 요약
// ---------------------------------------------------------------------------

/// "지난 판엔 서연과 대등한 연인으로 끝났다" / "지난 판은 번아웃으로 끝났다".
/// 캐릭터 엔딩 이름의 "서연 · " 머리는 떼어 낸다. [endingId] 가 모르는 값이면 null.
String? previousRunLineFor(StoryBundle bundle, String? endingId) {
  if (endingId == null) return null;
  Ending? e;
  for (final x in bundle.endings) {
    if (x.id == endingId) e = x;
  }
  if (e == null) return null;
  final ch = e.character == null ? null : bundle.characterById[e.character];
  var title = e.name;
  if (ch != null && title.startsWith('${ch.name} · ')) {
    title = title.substring(ch.name.length + 3);
  }
  // "천생연분 — 즉흥 담당" 처럼 긴 부제는 앞부분만.
  final dash = title.indexOf(' — ');
  if (dash > 0) title = title.substring(0, dash);
  final particle = TextTemplate.particleFor(title, '으로로');
  if (ch == null) return '지난 판은 $title$particle 끝났다';
  final wa = TextTemplate.particleFor(ch.name, '과와');
  return '지난 판엔 ${ch.name}$wa $title$particle 끝났다';
}
