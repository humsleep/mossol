import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// 측정(docs/ROADMAP.md Phase 0). 이벤트 이름·파라미터 규칙은 여기 한곳에 모은다.
///
/// - 이름은 snake_case, 파라미터 키는 25자 이하, 값은 작은 정수·짧은 문자열뿐.
/// - **개인 데이터는 보내지 않는다.** 플레이어 이름·자유 입력 글은 절대 싣지 않는다.
///   bool 은 0/1 정수로 보낸다(Firebase 파라미터는 문자열·숫자만 받는다).
/// - 모든 호출은 fire-and-forget. 실패해도 게임 흐름을 막지 않는다.
///
/// 백엔드는 갈아 끼운다: Firebase 가 켜져 있으면 [FirebaseAnalyticsBackend], 아니면
/// (GoogleService-Info.plist 없음 · 테스트) [DebugAnalyticsBackend] — 디버그 빌드에서만
/// debugPrint, 릴리스에서는 아무것도 하지 않는다. 테스트는 가짜 백엔드를 [backend] 에 넣는다.
class Analytics {
  Analytics({AnalyticsBackend? backend})
    : backend = backend ?? const DebugAnalyticsBackend();

  /// 앱 전역 인스턴스. [init] 이 Firebase 를 켜면 백엔드가 바뀐다.
  static final Analytics instance = Analytics();

  AnalyticsBackend backend;

  /// Firebase 를 켜 본다. plist 가 없거나 초기화가 실패하면 조용히 디버그 백엔드로 남는다.
  /// 앱은 어느 쪽이든 그대로 뜬다. 여러 번 불러도 된다.
  static Future<void> init() async {
    try {
      // 시작을 붙잡지 않게 시간 제한을 둔다. 넘기면 이번 실행은 측정 없이 간다.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      }
      instance.backend = FirebaseAnalyticsBackend(FirebaseAnalytics.instance);
    } catch (e) {
      if (kDebugMode) debugPrint('[analytics] Firebase 꺼짐(디버그 백엔드): $e');
    }
  }

  /// 분석 저장 동의. Info.plist 기본값은 거부(동의 모드)이고, 광고 동의(UMP) 결과가 나오면
  /// AdManager 가 부른다. 광고용 저장·데이터는 이 앱이 쓰지 않으므로 늘 거부로 둔다.
  static Future<void> setAnalyticsConsent(bool granted) async {
    final b = instance.backend;
    if (b is! FirebaseAnalyticsBackend) return;
    try {
      await b.fa.setConsent(
        analyticsStorageConsentGranted: granted,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[analytics] 동의 설정 실패: $e');
    }
  }

  // ---- 이벤트 이름 ----
  static const onboardingStep = 'onboarding_step';
  static const onboardingDone = 'onboarding_done';
  static const runStarted = 'run_started';

  /// 이전 회차에서 본 장면의 대기 줄을 광고 없이 건너뛰었다(r1_meeting D5).
  static const waitSkipFree = 'wait_skip_free';
  static const dayReached = 'day_reached';
  static const runEnded = 'run_ended';
  static const adHintUsed = 'ad_hint_used';
  static const adRewardedShown = 'ad_rewarded_shown';
  static const heartEmpty = 'heart_empty';
  static const albumOpened = 'album_opened';
  static const nextRunSuggestionTapped = 'next_run_suggestion_tapped';

  // 자유 입력(docs/overhaul/07_free_input.md §5). 구조 지표만 — 원문은 절대 싣지 않는다.
  static const freeInputSent = 'free_input_sent';
  static const freeInputPicked = 'free_input_picked';
  static const freeInputUndo = 'free_input_undo';
  static const freeInputBlocked = 'free_input_blocked';
  static const freeInputLocked = 'free_input_locked';

  /// user property: `0` 안 씀 · `1` 1~5회 · `2` 6회+.
  static const freeInputUse = 'free_input_use';

  /// `day_reached` 를 보내는 날. 매일 보내면 이벤트가 너무 많고 퍼널에는 이것으로 충분하다.
  static const dayMilestones = {2, 3, 7, 10, 20, 30, 50, 70, 100};

  /// 온보딩 단계 이름(`onboarding_step{step}`).
  /// [stepIntro] 는 첫 실행 인트로(태현의 첫 문자)가 떴을 때 — 홈을 건너뛴 경로다.
  static const stepIntro = 'intro';

  /// 시작 카드 시트가 처음 떴을 때(r1_bugs R1-6). 시트에서 떠난 사람이 `name` 직전 이탈로
  /// 섞이지 않게 따로 센다. 한 흐름에 한 번.
  static const stepStart = 'start';
  static const stepGender = 'gender';
  static const stepName = 'name';
  static const stepMbti = 'mbti';
  static const stepCast = 'cast';

  /// `onboarding_done{mbti_source}`.
  static const mbtiToggle = 'toggle';
  static const mbtiQuiz = 'quiz';
  static const mbtiSkip = 'skip';

  /// 인트로에서는 MBTI 를 아예 묻지 않았다(D+4 대화에서 묻는다). `skip` 과 구분한다.
  static const mbtiLater = 'later';

  // ---- 보내기 ----

  /// 규칙을 어긴 이름·파라미터는 디버그에서 assert 로 잡는다. 릴리스는 그냥 보낸다.
  void log(String name, [Map<String, Object> params = const {}]) {
    assert(_validName(name), 'analytics 이벤트 이름: $name');
    assert(
      params.keys.every((k) => k.length <= 25 && _validName(k)),
      'analytics 파라미터 키: ${params.keys}',
    );
    assert(
      params.values.every((v) => v is int || (v is String && v.length <= 40)),
      'analytics 파라미터 값은 int 또는 40자 이하 문자열: $params',
    );
    _guard(() => backend.logEvent(name, params));
  }

  void setUserProperty(String name, String? value) {
    assert(_validName(name) && name.length <= 24, 'user property: $name');
    _guard(() => backend.setUserProperty(name, value));
  }

  static bool _validName(String s) => RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(s);

  static void _guard(Future<void> Function() f) {
    try {
      unawaited(
        f().catchError((Object e) {
          if (kDebugMode) debugPrint('[analytics] 실패: $e');
        }),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[analytics] 실패: $e');
    }
  }

  // ---- 이벤트별 도우미. 호출부가 키 이름을 틀리지 않게 한다. ----

  void onboardingStepShown(String step) => log(onboardingStep, {'step': step});

  void onboardingCompleted({
    required String pref,
    required bool hasName,
    required bool hasMbti,
    required String mbtiSource,
  }) => log(onboardingDone, {
    'pref': pref,
    'has_name': hasName ? 1 : 0,
    'has_mbti': hasMbti ? 1 : 0,
    'mbti_source': mbtiSource,
  });

  /// [run] 은 게임 안 회차(엔딩 뒤 "다음 회차" 로만 오른다), [n] 은 이 기기에서 시작한
  /// 회차 수(메타 `totalRuns`, 이번 판 포함). 2회차 시작률은 `n >= 2` 로 본다.
  /// [start] 는 시작 스토리 id(docs/overhaul2/01_design.md §5.0 B5). 클래식은 `classic`.
  /// [fate] 면 운명 뽑기로 나온 시작이다(`fate: 1`, 01_design §7.4-2 결정용). 아니면 0.
  void runStart({
    required int run,
    required String pref,
    required int n,
    String start = 'classic',
    bool fate = false,
  }) {
    setUserProperty('pref', pref);
    log(runStarted, {
      'run': run,
      'pref': pref,
      'n': n,
      'start': start,
      'fate': fate ? 1 : 0,
    });
  }

  /// [day] 가 [dayMilestones] 일 때만 보낸다.
  void dayReach(int day) {
    if (dayMilestones.contains(day)) log(dayReached, {'day': day});
  }

  void runEnd({
    required String ending,
    required String tier,
    required int run,
    required int day,
  }) => log(runEnded, {'ending': ending, 'tier': tier, 'run': run, 'day': day});

  void mbtiKnown(bool known) =>
      setUserProperty('mbti_known', known ? '1' : '0');

  // ---- 자유 입력(07 §5). 값은 전부 작은 정수·짧은 문자열. ----

  /// 보낼 때마다. [confB]·[marginB] 는 점수×10 정수, [emo] 는 비트 5개 합(joke 1·sad 2·excited 4·
  /// hesitant 8·love 16), [topKind] 는 plain/chance/mg/locked, [result] 는 auto/confirm/picker/locked/blocked.
  void freeInputSend({
    required String layer,
    required String ev,
    required int nCh,
    required int lenB,
    required int polite,
    required bool q,
    required int emo,
    required int confB,
    required int marginB,
    required int topI,
    required String topKind,
    required String result,
  }) => log(freeInputSent, {
    'layer': layer,
    'ev': _id(ev),
    'n_ch': nCh,
    'len_b': lenB,
    'polite': polite,
    'q': q ? 1 : 0,
    'emo': emo,
    'conf_b': confB,
    'margin_b': marginB,
    'top_i': topI,
    'top_kind': topKind,
    'result': result,
  });

  /// 피커·확인 칩에서 고름. [rank] 는 고른 것의 점수 순위(0부터), [via] 는 picker/confirm/forced.
  void freeInputPick({
    required String ev,
    required int topI,
    required int pickI,
    required int rank,
    required String via,
  }) => log(freeInputPicked, {
    'ev': _id(ev),
    'top_i': topI,
    'pick_i': pickI,
    'rank': rank,
    'via': via,
  });

  /// 자동 확정 뒤 무료 되돌리기. [reI] 는 되돌린 뒤 고른 index(아직 모르면 -1).
  void freeInputUndone({
    required String ev,
    required int topI,
    required int reI,
    required int confB,
  }) => log(freeInputUndo, {
    'ev': _id(ev),
    'top_i': topI,
    're_i': reI,
    'conf_b': confB,
  });

  /// [reason] 은 empty/emoji/long/spam/profanity.
  void freeInputBlock(String reason) =>
      log(freeInputBlocked, {'reason': reason});

  void freeInputLock({required String ev, required int topI}) =>
      log(freeInputLocked, {'ev': _id(ev), 'top_i': topI});

  /// [sends] 누적 전송 횟수 → `0`/`1`/`2`.
  void freeInputUsage(int sends) => setUserProperty(
    freeInputUse,
    sends <= 0
        ? '0'
        : sends <= 5
        ? '1'
        : '2',
  );

  /// 이벤트 id 는 40자 이하로 자른다(파라미터 값 규칙).
  static String _id(String ev) => ev.length <= 40 ? ev : ev.substring(0, 40);
}

/// 분석 백엔드. 구현은 예외를 던져도 된다 — [Analytics] 가 삼킨다.
abstract class AnalyticsBackend {
  Future<void> logEvent(String name, Map<String, Object> params);
  Future<void> setUserProperty(String name, String? value);
}

/// Firebase 가 없을 때. 디버그 빌드에서만 콘솔에 찍고, 릴리스에서는 아무것도 안 한다.
/// `flutter test` 아래에서는 조용하다(테스트 출력이 이벤트로 덮이지 않게).
class DebugAnalyticsBackend implements AnalyticsBackend {
  const DebugAnalyticsBackend();

  static final bool _quiet =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  Future<void> logEvent(String name, Map<String, Object> params) async {
    if (kDebugMode && !_quiet) debugPrint('[analytics] $name $params');
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    if (kDebugMode && !_quiet) debugPrint('[analytics] user.$name = $value');
  }
}

class FirebaseAnalyticsBackend implements AnalyticsBackend {
  final FirebaseAnalytics fa;
  FirebaseAnalyticsBackend(this.fa);

  @override
  Future<void> logEvent(String name, Map<String, Object> params) =>
      fa.logEvent(name: name, parameters: params.isEmpty ? null : params);

  @override
  Future<void> setUserProperty(String name, String? value) =>
      fa.setUserProperty(name: name, value: value);
}

/// 테스트용. 보낸 이벤트를 차례로 쌓는다.
class RecordingAnalyticsBackend implements AnalyticsBackend {
  final List<(String, Map<String, Object>)> events = [];
  final Map<String, String?> userProperties = {};

  Iterable<Map<String, Object>> paramsOf(String name) =>
      events.where((e) => e.$1 == name).map((e) => e.$2);

  List<String> get names => [for (final e in events) e.$1];

  @override
  Future<void> logEvent(String name, Map<String, Object> params) async =>
      events.add((name, Map.of(params)));

  @override
  Future<void> setUserProperty(String name, String? value) async =>
      userProperties[name] = value;
}
