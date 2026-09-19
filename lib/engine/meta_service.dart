import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart' show PlayerGender;

/// 회차와 세이브를 넘어 유지되는 플레이어 메타 기록.
/// 출석·연속 접속·누적 회차·보류 중인 보상을 담는다.
///
/// `mossol_save_v1`(회차 세이브)·`mossol_endings_v1`(앨범)과는 별개 키에 저장하며
/// 그 둘의 형식은 건드리지 않는다.
class PlayerMeta {
  /// 마지막 출석 날짜. 기기 로컬 날짜, yyyy-MM-dd. 한 번도 없으면 null.
  String? lastCheckInDate;
  int streakDays;
  int bestStreak;
  int totalCheckIns;
  int totalRuns;
  int bestDayReached;
  int firstLaunchMs;

  /// 세이브가 없을 때 받은 출석 하트. 다음 newGame/continueGame 에서 적용된다.
  int pendingHearts;

  /// 7일 연속 출석으로 받은 룰렛 무료 재도전권. 회차와 무관하게 유지된다.
  int rerollTickets;

  /// 온보딩 "나는?" 의 답([PlayerGender] 의 `m` | `f` | `none`). 아직 안 물었으면 null.
  /// 새 게임 캐스트 소개의 기본 쪽만 정한다. 기기 밖으로 보내지 않고, 전체 초기화에서 지워진다.
  /// 이 필드가 없던 예전 메타 JSON 은 null 로 읽힌다.
  String? playerGender;

  /// 온보딩 이름 단계 · 설정 "내 이름" 의 값. 캐릭터가 대사에서 이 이름을 부른다
  /// (docs/NAME_GUIDE.md). 없으면 null — 대사는 대체어로 나간다. 기기 밖으로 보내지
  /// 않고, 세이브에 복사하지 않으며(회차 도중 바꾸면 다음 대사부터 반영), 전체 초기화에서 지워진다.
  String? playerName;

  /// 이름 단계를 한 번 거쳤는지(입력했든 건너뛰었든). true 면 다음 새 게임에서 다시 묻지 않는다.
  bool nameAsked;

  PlayerMeta({
    this.lastCheckInDate,
    this.streakDays = 0,
    this.bestStreak = 0,
    this.totalCheckIns = 0,
    this.totalRuns = 0,
    this.bestDayReached = 0,
    this.firstLaunchMs = 0,
    this.pendingHearts = 0,
    this.rerollTickets = 0,
    this.playerGender,
    this.playerName,
    this.nameAsked = false,
  });

  Map<String, dynamic> toJson() => {
    'lastCheckInDate': lastCheckInDate,
    'streakDays': streakDays,
    'bestStreak': bestStreak,
    'totalCheckIns': totalCheckIns,
    'totalRuns': totalRuns,
    'bestDayReached': bestDayReached,
    'firstLaunchMs': firstLaunchMs,
    'pendingHearts': pendingHearts,
    'rerollTickets': rerollTickets,
    'playerGender': playerGender,
    'playerName': playerName,
    'nameAsked': nameAsked,
  };

  static int _int(Object? v) => v is num ? v.toInt() : 0;

  factory PlayerMeta.fromJson(Map<String, dynamic> j) {
    final date = j['lastCheckInDate'];
    return PlayerMeta(
      lastCheckInDate: date is String && date.isNotEmpty ? date : null,
      streakDays: _int(j['streakDays']),
      bestStreak: _int(j['bestStreak']),
      totalCheckIns: _int(j['totalCheckIns']),
      totalRuns: _int(j['totalRuns']),
      bestDayReached: _int(j['bestDayReached']),
      firstLaunchMs: _int(j['firstLaunchMs']),
      pendingHearts: _int(j['pendingHearts']),
      rerollTickets: _int(j['rerollTickets']),
      playerGender: PlayerGender.parse(j['playerGender']),
      playerName: switch (j['playerName']) {
        final String v when v.trim().isNotEmpty => v.trim(),
        _ => null,
      },
      nameAsked: j['nameAsked'] == true,
    );
  }
}

/// 메타 저장소. SharedPreferences 의 `mossol_meta_v1` 한 키에 JSON 으로 저장한다.
/// 읽다가 깨져 있으면 초기화한다 (메타는 잃어도 회차 진행에는 영향이 없다).
class MetaService {
  static const _key = 'mossol_meta_v1';

  Future<PlayerMeta> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return PlayerMeta();
    try {
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) throw const FormatException('메타가 객체가 아님');
      return PlayerMeta.fromJson(j);
    } catch (_) {
      await p.remove(_key);
      return PlayerMeta();
    }
  }

  Future<void> save(PlayerMeta m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(m.toJson()));
  }

  /// 설정의 "저장 데이터 초기화". 출석·연속·재도전권까지 전부 지운다.
  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}
