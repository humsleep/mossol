import 'dart:math';

import 'models.dart';

/// 실제로 적용된 변화량. UI 피드백용.
class AppliedDelta {
  final Map<String, int> stats = {};
  final Map<String, int> affection = {};
  final Map<String, int> trust = {};
  final List<String> flags = [];
  String? album;

  bool get isEmpty =>
      stats.isEmpty &&
      affection.isEmpty &&
      trust.isEmpty &&
      flags.isEmpty &&
      album == null;

  AppliedDelta copy() => AppliedDelta()..merge(this);

  void clear() {
    stats.clear();
    affection.clear();
    trust.clear();
    flags.clear();
    album = null;
  }

  void merge(AppliedDelta o) {
    o.stats.forEach((k, v) => stats[k] = (stats[k] ?? 0) + v);
    o.affection.forEach((k, v) => affection[k] = (affection[k] ?? 0) + v);
    o.trust.forEach((k, v) => trust[k] = (trust[k] ?? 0) + v);
    flags.addAll(o.flags);
    album ??= o.album;
  }
}

/// 효과 키 `@top`: 지금 호감이 가장 높은 사람. 캐릭터가 정해지지 않은 일상
/// 이벤트에서 "그 사람" 한 명에게만 효과를 줄 때 쓴다. 다섯 명 모두를 적으면
/// 한 사람에게 한 행동이 모두에게 똑같이 번지는 문제가 생긴다.
const topKey = '@top';

/// 호감이 가장 높은 캐릭터 id. 동점이면 먼저 만난(관계 목록 앞) 쪽.
/// 아무와도 호감이 없으면 null 이고, 그때 `@top` 효과는 적용되지 않는다.
/// [absent](선호 밖 캐릭터)는 후보에서 뺀다.
String? topCharacterOf(GameState s, {Set<String> absent = const {}}) {
  String? best;
  var bestAff = 0;
  s.relations.forEach((id, r) {
    if (absent.contains(id)) return;
    if (r.affection > bestAff) {
      bestAff = r.affection;
      best = id;
    }
  });
  return best;
}

/// 오르는 호감 [v] 에 배율 [m] 을 곱해 올림한다. 1.5배면 +1 → +2, +3 → +5.
/// 부동소수 오차(2 × 1.5 = 3.0000001)로 한 칸 더 올라가지 않게 아주 작은 값을 뺀다.
int scaleGain(int v, double m) {
  if (v <= 0 || m <= 1) return v;
  return max(v, (v * m - 1e-9).ceil());
}

/// [effects] 를 [s] 에 적용하고 실제 변화량을 돌려준다.
/// [affectionMultiplier] 는 **오르는 호감에만** 곱한다(올림). 크리티컬 2배와
/// 초반 가속(`EarlyAffection`)을 곱한 값이 들어온다. 감소·신뢰는 그대로.
///
/// [absent] 는 이 회차 선호 밖 캐릭터 id. 그 캐릭터를 id 로 직접 가리킨 호감·신뢰
/// 효과(`"seoyeon": 3`)는 적용하지 않고, `@top` 도 그 캐릭터를 고르지 않는다.
AppliedDelta applyEffects(
  GameState s,
  Effects effects, {
  String? self,
  double affectionMultiplier = 1,
  Set<String> absent = const {},
}) {
  final d = AppliedDelta();

  effects.stats.forEach((k, v) {
    final before = s.stat(k);
    final after = max(0, min(Stat.maxOf(k), before + v));
    if (after != before) d.stats[k] = after - before;
    s.stats[k] = after;
  });

  void bump(Map<String, int> src, Map<String, int> out, bool isAffection) {
    src.forEach((k, v) {
      final id = switch (k) {
        '*' => self,
        topKey => topCharacterOf(s, absent: absent),
        _ => k,
      };
      if (id == null || absent.contains(id)) return;
      final r = s.rel(id);
      final before = isAffection ? r.affection : r.trust;
      final amount = isAffection ? scaleGain(v, affectionMultiplier) : v;
      final after = max(0, min(100, before + amount));
      if (isAffection) {
        r.affection = after;
      } else {
        r.trust = after;
      }
      if (after != before) out[id] = after - before;
    });
  }

  bump(effects.affection, d.affection, true);
  bump(effects.trust, d.trust, false);

  for (final f in effects.setFlags) {
    if (s.flags.add(f)) d.flags.add('+$f');
  }
  for (final f in effects.clearFlags) {
    if (s.flags.remove(f)) d.flags.add('-$f');
  }
  final album = effects.album;
  if (album != null) {
    s.album.add(album);
    d.album = album;
    if (s.album.length >= 10) s.flags.add('album_10');
    if (s.album.length >= 20) s.flags.add('album_20');
  }
  return d;
}
