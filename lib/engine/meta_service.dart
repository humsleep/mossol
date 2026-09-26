import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart' show PlayerGender, parseMbtiType;

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

  /// 온보딩 MBTI 단계 · 설정 "내 MBTI" 의 값(대문자 4글자). 모름·건너뜀은 null.
  /// 새 게임 때 세이브(`GameState.mbti`)로 복사되고, 바꾸면 **다음 새 게임부터** 반영된다
  /// (docs/MBTI_SPEC.md §1.2). 기기 밖으로 보내지 않고, 전체 초기화에서 지워진다.
  String? mbti;

  /// MBTI 단계를 한 번 거쳤는지(골랐든 건너뛰었든). true 면 다음 새 게임에서 다시 묻지 않는다.
  bool mbtiAsked;

  /// 가장 최근에 끝난 회차의 엔딩 id. 새 회차 첫날의 "지난 판엔 …으로 끝났다" 한 줄에 쓴다.
  /// 앨범(`mossol_endings_v1`)은 처음 본 순서만 남기므로 "마지막" 을 따로 적는다.
  /// 이 필드가 없던 예전 메타 JSON 은 null 로 읽힌다(한 줄을 띄우지 않는다).
  String? lastEndingId;

  /// 설정의 효과음·진동 토글(docs/overhaul/05_audio_haptics.md §4). 둘 다 기본 켬.
  /// 이 필드가 없던 예전 메타 JSON 은 true 로 읽힌다(추가만, 세이브 호환).
  bool sfxOn;
  bool hapticOn;

  /// 자유 입력을 보낸 횟수(회차 무관, 원문 없음). user property `free_input_use` 의 근거.
  /// docs/overhaul/07_free_input.md §5. 없던 예전 메타는 0.
  int freeInputSends;

  /// 첫 실행 인트로(태현의 첫 문자 → 이름 → "나는?")를 끝까지 봤는지.
  /// 이 필드가 없던 예전 메타는 false 로 읽히지만, 이미 한 판 이상 한 기기는
  /// `totalRuns > 0` 이라 인트로가 다시 뜨지 않는다([GameController.shouldShowIntro]).
  bool introSeen;

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
    this.mbti,
    this.mbtiAsked = false,
    this.lastEndingId,
    this.sfxOn = true,
    this.hapticOn = true,
    this.freeInputSends = 0,
    this.introSeen = false,
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
    'mbti': mbti,
    'mbtiAsked': mbtiAsked,
    'lastEndingId': lastEndingId,
    'sfxOn': sfxOn,
    'hapticOn': hapticOn,
    'freeInputSends': freeInputSends,
    'introSeen': introSeen,
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
      mbti: parseMbtiType(j['mbti']),
      mbtiAsked: j['mbtiAsked'] == true,
      lastEndingId: switch (j['lastEndingId']) {
        final String v when v.isNotEmpty => v,
        _ => null,
      },
      // 없거나 bool 이 아니면 켬. 끄는 건 명시적인 false 뿐이다.
      sfxOn: j['sfxOn'] != false,
      hapticOn: j['hapticOn'] != false,
      freeInputSends: _int(j['freeInputSends']),
      introSeen: j['introSeen'] == true,
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
