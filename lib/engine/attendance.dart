import 'dart:math';

import 'meta_service.dart';
import 'models.dart';

/// 출석 한 번의 결과.
class CheckInResult {
  /// 오늘 첫 출석인지. false 면 보상은 없다.
  final bool first;

  /// 출석 후의 연속 일수.
  final int streak;

  /// 이번 출석으로 받은 하트 수 (기본 + 연속 보너스).
  final int heartsGranted;

  /// 추가 보상 식별자. 문구는 UI 가 정한다.
  /// [Attendance.extraStreak3] 또는 [Attendance.extraStreak7], 없으면 null.
  final String? extra;

  const CheckInResult({
    required this.first,
    required this.streak,
    required this.heartsGranted,
    this.extra,
  });

  @override
  String toString() =>
      'CheckInResult(first: $first, streak: $streak, hearts: $heartsGranted, extra: $extra)';
}

/// 출석·연속 접속 계산. 순수 함수 모음이라 시계만 넣어 주면 그대로 테스트된다.
///
/// 보상표 (7일 주기로 반복):
/// | 연속 | 하트 | 추가 |
/// |------|------|------|
/// | 매일 | +1   |      |
/// | 3, 10, 17… (7n+3) | +2 | [extraStreak3] |
/// | 7, 14, 21… (7n) | +3 | [extraStreak7] + 룰렛 재도전권 1장 |
///
/// 한 주 개근이면 하트 10개 + 재도전권 1장. 최대치(5)의 두 배이므로 "출석만으로
/// 하루 두 세션"이 되고, 광고 하트는 그 위의 보너스로 남는다.
class Attendance {
  static const dailyHearts = 1;
  static const streak3Bonus = 1;
  static const streak7Bonus = 2;
  static const extraStreak3 = 'streak3';
  static const extraStreak7 = 'streak7';

  /// 재도전권은 쌓아 두고 안 쓰면 의미가 없으므로 상한을 둔다.
  static const maxRerollTickets = 3;

  /// 출석 하트는 최대치를 넘겨 쌓일 수 있지만, 무한정은 아니다.
  /// 최대치의 두 배까지. 그 이상은 어차피 한 세션에 못 쓴다.
  static int heartCeiling(int maxHearts) => maxHearts * 2;

  /// 기기 로컬 날짜를 yyyy-MM-dd 로.
  static String dateKey(DateTime now) {
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  /// yyyy-MM-dd → 그 날의 UTC 자정. DST 때문에 하루가 23시간이어도
  /// 날짜 차이를 정확히 세려고 UTC 로 계산한다. 형식이 깨져 있으면 null.
  static DateTime? parseDate(String? key) {
    if (key == null) return null;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime.utc(y, m, d);
  }

  /// [from] 부터 [now] 의 날짜까지 며칠 지났는지. 같은 날이면 0, 어제면 1.
  /// [now] 가 과거면 음수.
  static int daysBetween(String from, DateTime now) {
    final a = parseDate(from);
    if (a == null) return 1 << 30;
    final b = DateTime.utc(now.year, now.month, now.day);
    return b.difference(a).inDays;
  }

  /// 오늘 이미 출석했는지.
  static bool checkedInOn(PlayerMeta m, DateTime now) =>
      m.lastCheckInDate == dateKey(now);

  /// 마지막 출석이 오늘·어제가 아니면 연속은 이미 끊긴 것이므로 0 으로 본다.
  /// 홈 화면에 "연속 N일"을 띄울 때 이 값을 쓴다.
  static int liveStreak(PlayerMeta m, DateTime now) {
    final last = m.lastCheckInDate;
    if (last == null) return 0;
    final gap = daysBetween(last, now);
    // 시계가 뒤로 간 경우(gap < 0)는 기록을 믿고 그대로 보여 준다.
    return gap <= 1 ? m.streakDays : 0;
  }

  /// 연속 [streak]일째 출석의 보상. 하트 수와 추가 보상 식별자.
  static (int hearts, String? extra) rewardFor(int streak) {
    if (streak > 0 && streak % 7 == 0) {
      return (dailyHearts + streak7Bonus, extraStreak7);
    }
    if (streak % 7 == 3) return (dailyHearts + streak3Bonus, extraStreak3);
    return (dailyHearts, null);
  }

  /// 출석 처리. [m] 을 갱신하고 결과를 돌려준다. 하트는 여기서 주지 않고
  /// 호출자가 [CheckInResult.heartsGranted] 를 세이브나 pending 에 넣는다.
  ///
  /// - 오늘 이미 출석: first=false, 보상 없음, 기록 그대로.
  /// - 기기 시계가 마지막 출석보다 과거: 조작·되감기로 보고 보상 없음.
  /// - 어제 출석: streak+1. 그 외(이틀 이상 건너뜀·첫 출석): streak=1.
  static CheckInResult checkIn(PlayerMeta m, DateTime now) {
    final last = m.lastCheckInDate;
    final gap = last == null ? null : daysBetween(last, now);
    if (gap != null && gap <= 0) {
      // gap == 0: 오늘 이미 출석. gap < 0: 시계가 뒤로 감.
      return CheckInResult(first: false, streak: m.streakDays, heartsGranted: 0);
    }
    final streak = gap == 1 ? m.streakDays + 1 : 1;
    final (hearts, extra) = rewardFor(streak);
    m
      ..lastCheckInDate = dateKey(now)
      ..streakDays = streak
      ..bestStreak = max(m.bestStreak, streak)
      ..totalCheckIns += 1;
    if (extra == extraStreak7) {
      m.rerollTickets = min(maxRerollTickets, m.rerollTickets + 1);
    }
    return CheckInResult(first: true, streak: streak, heartsGranted: hearts, extra: extra);
  }

  /// 출석 하트를 세이브에 얹는다. 최대치를 넘길 수 있지만 [heartCeiling] 까지.
  /// 실제로 얹은 개수를 돌려준다.
  static int grantHearts(GameState s, int n, int maxHearts) {
    if (n <= 0) return 0;
    final ceiling = heartCeiling(maxHearts);
    final before = s.hearts;
    s.hearts = min(max(before, ceiling), before + n);
    return s.hearts - before;
  }
}

/// 회차 간 이어지는 보너스. 앨범에 엔딩이 하나라도 있으면 새 회차 초기 스탯이
/// 조금 오른다. 엔딩 1개당 매력·화술·자존감 +1, 각 +[crossRunCap] 까지.
///
/// 초기치가 매력 35·화술 20·자존감 15 라 +5 는 "느껴지지만 루트를 공짜로 열지는
/// 않는" 폭이다 (루트 잠금은 대부분 60~80 이상).
const crossRunCap = 5;

Map<String, int> crossRunBonus(int endingsSeen) {
  final n = endingsSeen.clamp(0, crossRunCap);
  if (n <= 0) return const {};
  return {Stat.charm: n, Stat.talk: n, Stat.esteem: n};
}

/// [bonus] 를 초기 스탯에 더한다. 스탯 상한을 넘기지 않는다.
void applyCrossRunBonus(GameState s, Map<String, int> bonus) {
  for (final e in bonus.entries) {
    s.stats[e.key] = min(Stat.maxOf(e.key), s.stat(e.key) + e.value);
  }
}
