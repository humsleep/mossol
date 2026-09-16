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
      stats.isEmpty && affection.isEmpty && trust.isEmpty && flags.isEmpty && album == null;

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

/// [effects] 를 [s] 에 적용하고 실제 변화량을 돌려준다.
/// [affectionMultiplier] 는 크리티컬 성공 시 2.
AppliedDelta applyEffects(
  GameState s,
  Effects effects, {
  String? self,
  int affectionMultiplier = 1,
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
      final id = k == '*' ? self : k;
      if (id == null) return;
      final r = s.rel(id);
      final before = isAffection ? r.affection : r.trust;
      final amount = isAffection && v > 0 ? v * affectionMultiplier : v;
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
