import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../analytics/analytics.dart';

/// AdMob 래퍼. 광고 정책(빈도 캡)을 여기서만 관리한다.
///
/// 흐름 (Google 권장, https://developers.google.com/admob/flutter/privacy):
///   1. UMP `requestConsentInfoUpdate` → 2. `loadAndShowConsentFormIfRequired`
///   → 3. (iOS) ATT 프롬프트 → 4. `canRequestAds()` 가 true 일 때만, 그리고 딱 한 번
///   `MobileAds.initialize()` → 5. 광고 미리 로드.
///
/// 광고 단위 ID: 릴리스 빌드(TestFlight·App Store)는 AdMob 콘솔의 실제 ID(앱 "Mossol"),
/// 디버그·프로필 빌드는 Google 공식 테스트 ID 를 쓴다. 개발 중 실수로 자기 실제 광고를
/// 누르는 일(AdMob 무효 트래픽 → 계정 정지 사유)을 막기 위해서다.
/// iOS 앱 ID 는 Info.plist 의 GADApplicationIdentifier. Android 는 아직 앱이 없어 테스트 ID 다.
class AdManager with WidgetsBindingObserver {
  AdManager._();
  static final AdManager instance = AdManager._();

  /// Google 공식 테스트 광고 단위 ID. 디버그 빌드와 Android(아직 AdMob 앱 없음)에서 쓴다.
  static const _testIds = {
    'android': {
      'interstitial': 'ca-app-pub-3940256099942544/1033173712',
      'rewarded': 'ca-app-pub-3940256099942544/5224354917',
      'banner': 'ca-app-pub-3940256099942544/6300978111',
    },
    'ios': {
      'interstitial': 'ca-app-pub-3940256099942544/4411468910',
      'rewarded': 'ca-app-pub-3940256099942544/1712485313',
      'banner': 'ca-app-pub-3940256099942544/2934735716',
    },
  };

  /// AdMob 콘솔의 실제 광고 단위 ID (앱 "Mossol", 2026-09-22 발급). 릴리스 빌드에서만 쓴다.
  /// Android 앱을 AdMob 에 추가하면 'android' 항목을 채운다.
  static const _realIds = {
    'ios': {
      'interstitial': 'ca-app-pub-4073994600346533/8783923243',
      'rewarded': 'ca-app-pub-4073994600346533/5122687865',
      'banner': 'ca-app-pub-4073994600346533/7646935542',
    },
  };

  /// 이 빌드·플랫폼에서 쓸 광고 단위 ID 표. 테스트에서 확인할 수 있게 공개한다.
  static Map<String, String> idsFor({required bool ios, required bool release}) {
    final platform = ios ? 'ios' : 'android';
    return (release ? _realIds[platform] : null) ?? _testIds[platform]!;
  }

  /// 개발 중 실제 광고 단위로 시험할 때 쓰는 테스트 기기 ID. 로그에 찍히는 값을 넣는다.
  /// 디버그 빌드에서만 적용되며 릴리스 빌드에는 절대 들어가지 않는다.
  static const List<String> _debugTestDeviceIds = <String>[];

  /// 전면 광고 정책. 설계서 07 항목과 같다.
  /// `interstitialMinDay` 는 게임 내 일차(day), 나머지는 실제 시각 기준이다.
  ///
  /// 왜 이 값인가(docs/review/00_VERDICT.md §3 R1): 게임 내 하루가 약 2분이라
  /// 최소 간격 2분은 "하루에 한 번" 과 같았고, D+3 은 첫 세션(약 10분) 안이었다.
  /// 벤치마크에서 별점을 떨어뜨린 1순위가 광고 빈도다 — 첫 세션은 광고 없이 끝낸다.
  static const interstitialMinDay = 7;
  static const interstitialMinInterval = Duration(minutes: 6);
  static const interstitialMaxPerDay = 6;

  /// 로드된 전면·리워드 광고는 약 1시간 뒤 만료된다(Google 안내). 여유를 두고 갈아 끼운다.
  static const _adMaxAge = Duration(minutes: 50);

  /// 로드 실패 시 재시도 백오프. 무한 재요청은 무효 트래픽으로 잡힐 수 있다.
  static const _retryBase = Duration(seconds: 2);
  static const _retryMax = Duration(minutes: 5);
  static const _retryMaxAttempts = 8;

  bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  String _unit(String kind) =>
      idsFor(ios: Platform.isIOS, release: kReleaseMode)[kind]!;

  bool _initCalled = false;
  bool _sdkInitialized = false;
  bool _initializing = false;
  bool _consentDone = false;
  bool _showingFullScreen = false;

  /// 전체 화면 광고를 띄운 시각. 표시 콜백(닫힘·표시 실패)이 끝내 오지 않으면
  /// 플래그가 영원히 남아 그 세션의 광고가 전부 조용히 막힌다 — 시각을 함께 들고
  /// 있다가 [_fullScreenBusy] 가 스스로 푼다.
  DateTime? _showingSince;

  /// 이 시간이 지나도록 콜백이 없으면 플래그가 잘못 남은 것으로 본다.
  static const _showStuck = Duration(minutes: 2);

  /// 지금 전체 화면 광고가 떠 있는가. 오래 남은 플래그는 여기서 푼다.
  bool get _fullScreenBusy {
    if (!_showingFullScreen) return false;
    final since = _showingSince;
    if (since == null || DateTime.now().difference(since) < _showStuck) {
      return true;
    }
    debugPrint('전체 화면 광고 상태가 ${_showStuck.inMinutes}분 넘게 남아 있어 푼다.');
    _endFullScreen();
    return false;
  }

  void _beginFullScreen() {
    _showingFullScreen = true;
    _showingSince = DateTime.now();
  }

  void _endFullScreen() {
    _showingFullScreen = false;
    _showingSince = null;
  }

  bool get consentDone => _consentDone;
  bool get sdkInitialized => _sdkInitialized;

  final _interstitial = _FullScreenSlot<InterstitialAd>('전면');
  final _rewarded = _FullScreenSlot<RewardedAd>('리워드');

  DateTime? _lastInterstitialAt;
  int _interstitialsShown = 0;
  /// 캡을 세는 달력 날짜(yyyymmdd, 로컬). 게임 내 일차가 아니라 실제 날짜로 센다.
  int _countedCalendarDay = -1;

  Future<void> init() async {
    if (!supported || _initCalled) return;
    _initCalled = true;
    WidgetsBinding.instance.addObserver(this);
    _startConsentFlow();
  }

  // ───────────────────────── 동의(UMP) / ATT ─────────────────────────

  /// UMP 동의 폼. 유럽 등 동의가 필요한 지역에서만 실제로 뜬다.
  /// AdMob 콘솔에서 IDFA 설명 메시지를 만들어 두면 iOS 에서는 이 단계에서 UMP 가
  /// 설명 메시지 → ATT 프롬프트까지 대신 띄운다. 그 경우 아래 `_requestTracking` 은
  /// 이미 결정된 상태를 보고 아무것도 하지 않는다.
  /// 동의 → ATT → SDK 초기화를 한 줄로 엮는다.
  ///
  /// 순서를 시간(타임아웃)으로 재촉하면 안 된다. UMP 가 IDFA 설명 메시지를 띄우는
  /// 사이에 우리가 ATT 를 먼저 띄우면, "다음 화면에서 허용을 눌러 주세요" 안내가
  /// 이미 지나간 ATT 뒤에 나타나는 사고가 난다. 그래서 ATT 는 반드시 동의 콜백
  /// 안에서만 부르고, 동의가 끝나지 않으면 이번 세션에는 ATT 를 아예 묻지 않는다.
  void _startConsentFlow() {
    final params = ConsentRequestParameters(
      // 디버그 빌드에서만 테스트 기기를 등록한다. 지역 강제(debugGeography)는 필요할 때 켠다.
      consentDebugSettings: kDebugMode && _debugTestDeviceIds.isNotEmpty
          ? ConsentDebugSettings(testIdentifiers: _debugTestDeviceIds)
          : null,
    );
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            await _showConsentFormIfRequired();
          } catch (e) {
            debugPrint('동의 폼 실패: $e');
          }
          _consentDone = true;
          // 이용 통계는 동의가 필요 없는 지역(한국 등)에서만 켠다. 유럽 등 동의 대상 지역은
          // 사용자가 어떤 선택을 했는지 앱이 확인할 수 없으므로 거부 상태(동의 모드)로 둔다.
          try {
            final status = await ConsentInformation.instance.getConsentStatus();
            await Analytics.setAnalyticsConsent(
              status == ConsentStatus.notRequired,
            );
          } catch (e) {
            debugPrint('통계 동의 판정 실패: $e');
          }
          await _requestTrackingThenInit();
        },
        (err) async {
          debugPrint('동의 정보 갱신 실패: ${err.message}');
          _consentDone = true;
          // 갱신에 실패해도 지난 세션의 동의가 남아 있을 수 있다.
          await _requestTrackingThenInit();
        },
      );
    } catch (e) {
      debugPrint('동의 요청 실패: $e');
      _consentDone = true;
      unawaited(_initializeSdkIfAllowed());
      return;
    }

    // 동의 조회가 영영 돌아오지 않는 경우(네트워크 단절 등)의 안전장치.
    // 여기서는 ATT 를 묻지 않고, 이전 세션 동의만으로 가능한 광고만 켠다.
    Timer(const Duration(seconds: 10), () {
      if (_consentDone || _sdkInitialized) return;
      debugPrint('동의 조회가 지연된다. ATT 없이 초기화만 시도한다.');
      unawaited(_initializeSdkIfAllowed());
    });
  }

  /// ATT 를 묻고 나서 SDK 를 켠다. UMP 가 이미 ATT 를 띄웠다면
  /// 상태가 notDetermined 가 아니라 아무 일도 하지 않는다.
  Future<void> _requestTrackingThenInit() async {
    await _requestTracking();
    await _initializeSdkIfAllowed();
  }

  Future<void> _showConsentFormIfRequired() {
    final shown = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((err) {
      if (err != null) debugPrint('동의 폼 표시 실패: ${err.message}');
      if (!shown.isCompleted) shown.complete();
    });
    return shown.future;
  }

  /// iOS 앱 추적 투명성. 거부해도 게임은 그대로 돌아간다.
  /// 광고를 처음 요청하기 전에 끝내야 SDK 가 IDFA 를 쓸 수 있다.
  Future<void> _requestTracking() async {
    if (!Platform.isIOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // 시스템 팝업은 앱이 active 상태여야 뜬다. 화면이 안정될 시간을 준다.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('ATT 요청 실패: $e');
    }
  }

  /// `canRequestAds()` 가 true 일 때만, 그리고 단 한 번 SDK 를 초기화한다.
  Future<void> _initializeSdkIfAllowed() async {
    if (!supported || _sdkInitialized || _initializing) return;
    bool allowed;
    try {
      allowed = await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('canRequestAds 확인 실패: $e');
      return;
    }
    if (!allowed) {
      debugPrint('광고 요청 불가(동의 미완료). SDK 초기화를 보류한다.');
      return;
    }
    _initializing = true;
    try {
      if (kDebugMode && _debugTestDeviceIds.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: _debugTestDeviceIds),
        );
      }
      await MobileAds.instance.initialize();
      _sdkInitialized = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      debugPrint('MobileAds 초기화 실패: $e');
    } finally {
      _initializing = false;
    }
  }

  /// 설정 화면에서 동의를 다시 띄울 때 쓴다. 유럽 정책상 철회 경로가 필요하다.
  Future<void> showPrivacyOptions() async {
    if (!supported) return;
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((err) {
      if (err != null) debugPrint('개인정보 옵션 폼 실패: ${err.message}');
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    // 처음에 거부했다가 여기서 동의하면 이제야 광고를 켤 수 있다.
    await _initializeSdkIfAllowed();
  }

  Future<bool> get privacyOptionsRequired async {
    if (!supported) return false;
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  // ───────────────────────── 앱 생명주기 ─────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // 광고 도중 앱이 죽었다 살아나면 표시 콜백이 유실된다. 읽는 것만으로 풀린다.
    if (_fullScreenBusy) {
      debugPrint('복귀 시점에 전체 화면 광고가 아직 떠 있는 것으로 돼 있다.');
    }
    if (!_sdkInitialized) {
      // 첫 시도 때 동의 정보를 못 받아 canRequestAds 가 false 였을 수 있다.
      // 그대로 두면 그 세션 내내 광고가 하나도 안 뜨므로 복귀 때마다 다시 본다.
      unawaited(_initializeSdkIfAllowed());
      return;
    }
    // 백그라운드에 오래 있었으면 만료된 광고를 버리고 새로 받는다.
    // 백오프 대기 중이던 재시도도 복귀 시점에 바로 한 번 시도한다.
    if (_interstitial.isStale(_adMaxAge)) _interstitial.discard();
    if (_rewarded.isStale(_adMaxAge)) _rewarded.discard();
    if (_interstitial.ad == null) _loadInterstitial(resetBackoff: true);
    if (_rewarded.ad == null) _loadRewarded(resetBackoff: true);
  }

  // ───────────────────────── 로드 (백오프) ─────────────────────────

  void _loadInterstitial({bool resetBackoff = false}) {
    if (!_sdkInitialized || !_interstitial.beginLoad(resetBackoff: resetBackoff)) return;
    InterstitialAd.load(
      adUnitId: _unit('interstitial'),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial.loaded(ad),
        onAdFailedToLoad: (err) {
          _interstitial.failed(err);
          _scheduleRetry(_interstitial, _loadInterstitial);
        },
      ),
    );
  }

  void _loadRewarded({bool resetBackoff = false}) {
    if (!_sdkInitialized || !_rewarded.beginLoad(resetBackoff: resetBackoff)) return;
    RewardedAd.load(
      adUnitId: _unit('rewarded'),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded.loaded(ad),
        onAdFailedToLoad: (err) {
          _rewarded.failed(err);
          _scheduleRetry(_rewarded, _loadRewarded);
        },
      ),
    );
  }

  void _scheduleRetry(_FullScreenSlot<Object> slot, void Function({bool resetBackoff}) load) {
    if (slot.attempts >= _retryMaxAttempts) {
      debugPrint('${slot.label} 광고 재시도 상한 도달. 앱 복귀 또는 다음 표시 시도까지 멈춘다.');
      return;
    }
    final delay = _retryBase * math.pow(2, slot.attempts - 1).toInt();
    slot.retryTimer?.cancel();
    slot.retryTimer = Timer(delay > _retryMax ? _retryMax : delay, () => load());
  }

  bool get rewardedReady => _rewarded.ad != null && !_rewarded.isStale(_adMaxAge);

  // ───────────────────────── 전면 ─────────────────────────

  static int _calendarDay(DateTime t) => t.year * 10000 + t.month * 100 + t.day;

  /// 정책상 지금 전면 광고를 보여도 되는가. 상태를 바꾸지 않는다.
  bool canShowInterstitial(int day) {
    if (day < interstitialMinDay) return false;
    final now = DateTime.now();
    final shownToday = _countedCalendarDay == _calendarDay(now) ? _interstitialsShown : 0;
    if (shownToday >= interstitialMaxPerDay) return false;
    final last = _lastInterstitialAt;
    if (last != null && now.difference(last) < interstitialMinInterval) return false;
    return true;
  }

  void _countInterstitial(DateTime now) {
    final today = _calendarDay(now);
    if (_countedCalendarDay != today) {
      _countedCalendarDay = today;
      _interstitialsShown = 0;
    }
    _interstitialsShown++;
    _lastInterstitialAt = now;
  }

  /// 전면 광고. 정책에 걸리거나 로드가 안 됐으면 즉시 false 로 끝나 흐름을 막지 않는다.
  Future<bool> showInterstitial({required int day}) async {
    if (!supported || !_sdkInitialized || _fullScreenBusy) return false;
    if (!canShowInterstitial(day)) return false;
    if (_interstitial.isStale(_adMaxAge)) _interstitial.discard();
    final ad = _interstitial.take();
    if (ad == null) {
      // 대기 중이면 새로 요청하지 않는다. 표시 실패는 조용히 넘어간다.
      _loadInterstitial();
      return false;
    }
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _endFullScreen();
        _loadInterstitial();
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, err) {
        debugPrint('전면 광고 표시 실패: ${err.message}');
        a.dispose();
        _endFullScreen();
        _loadInterstitial();
        if (!done.isCompleted) done.complete(false);
      },
    );
    _beginFullScreen();
    _countInterstitial(DateTime.now());
    try {
      await ad.show();
    } catch (e) {
      debugPrint('전면 광고 show 예외: $e');
      _endFullScreen();
      return false;
    }
    // 콜백이 끝내 오지 않아도 여기서 풀린다(그 뒤의 광고까지 막히면 안 된다).
    return done.future.timeout(_showStuck, onTimeout: () {
      debugPrint('전면 광고 닫힘 콜백이 오지 않았다.');
      _endFullScreen();
      _loadInterstitial();
      return false;
    });
  }

  // ───────────────────────── 리워드 ─────────────────────────

  /// 버튼을 누른 순간 광고가 아직 안 와 있을 때 기다려 주는 시간.
  /// 미리 받아 둔 광고가 없으면 예전에는 그 자리에서 false 로 끝나 버려서,
  /// 사용자 눈에는 "눌러도 아무 일도 안 일어나는 버튼"이 됐다.
  static const _showWaitTimeout = Duration(seconds: 8);

  /// 리워드 광고를 쓸 수 있는 상태로 만든다. 이미 준비됐으면 즉시 true.
  ///
  /// 미리 로드가 실패해 슬롯이 비어 있으면(새 광고 단위의 노출 없음, 일시적 네트워크
  /// 오류, 백오프 상한 도달) 여기서 한 번 더 요청하고 [_showWaitTimeout] 까지 기다린다.
  Future<bool> _awaitRewarded() async {
    if (!_sdkInitialized) {
      // 동의·ATT 가 늦게 끝나 아직 SDK 가 안 켜졌을 수 있다. 한 번 더 시도한다.
      await _initializeSdkIfAllowed();
      if (!_sdkInitialized) {
        debugPrint('리워드 광고: SDK 초기화 전이라 표시할 수 없다.');
        return false;
      }
    }
    if (_rewarded.isStale(_adMaxAge)) _rewarded.discard();
    if (_rewarded.ad != null) return true;
    _loadRewarded(resetBackoff: true);
    final pending = _rewarded.inFlight;
    if (pending != null) {
      await pending.timeout(_showWaitTimeout, onTimeout: () {});
    }
    if (_rewarded.ad == null) debugPrint('리워드 광고: 기다렸지만 받지 못했다.');
    return _rewarded.ad != null;
  }

  /// 리워드 광고. 끝까지 봐서 보상을 받았을 때만 true.
  /// 보상은 `onUserEarnedReward` 콜백이 온 경우에만 인정하고, 닫힌 뒤에 결과를 돌려준다.
  /// [placement] 는 측정용 자리 이름(`heart_action` · `heart_home` · `hint` · `undo` ·
  /// `roulette` · `wait_skip`). 광고가 실제로 떴을 때만 `ad_rewarded_shown` 을 남긴다.
  Future<bool> showRewarded({String placement = 'unknown'}) async {
    if (!supported || _fullScreenBusy) return false;
    // 대기(최대 8초) 전에 자리를 잡는다. 그 사이 전면 광고가 끼어들면 둘 중 하나가
    // 표시 실패로 거절돼 "광고를 봤는데 보상이 없다" 가 된다(04 P2-2).
    _beginFullScreen();
    if (!await _awaitRewarded()) {
      _endFullScreen();
      return false;
    }
    final ad = _rewarded.take();
    if (ad == null) {
      _endFullScreen();
      return false;
    }
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _endFullScreen();
        _loadRewarded();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, err) {
        debugPrint('리워드 광고 표시 실패: ${err.message}');
        a.dispose();
        _endFullScreen();
        _loadRewarded();
        if (!done.isCompleted) done.complete(false);
      },
    );
    Analytics.instance.log(Analytics.adRewardedShown, {'placement': placement});
    try {
      await ad.show(onUserEarnedReward: (_, reward) {
        debugPrint('리워드 획득: ${reward.amount} ${reward.type}');
        earned = true;
      });
    } catch (e) {
      debugPrint('리워드 광고 show 예외: $e');
      _endFullScreen();
      return false;
    }
    return done.future.timeout(_showStuck, onTimeout: () {
      debugPrint('리워드 광고 닫힘 콜백이 오지 않았다.');
      _endFullScreen();
      _loadRewarded();
      // 끝까지 봤다면 보상은 준다 — 콜백 유실이 사용자 손해가 되면 안 된다.
      return earned;
    });
  }

  // ───────────────────────── 배너 ─────────────────────────

  /// 배너 광고 단위 ID. 화면 쪽에서 BannerAd 를 직접 만들 때 쓴다.
  String get bannerUnitId => _unit('banner');

  /// 홈·정산 화면 하단 배너. 채팅(이벤트) 화면에는 붙이지 않는다 — 선택지 옆에 배너를
  /// 두면 AdMob 배치 정책(우발적 클릭) 위반이다.
  ///
  /// [size] 를 주면 화면 폭에 맞춘 적응형 배너(`AdSize.getAnchoredAdaptiveBannerAdSize`)를
  /// 쓸 수 있다. 콜백을 넘기면 반환된 BannerAd 를 그대로 `load()` 해서 쓰면 된다.
  BannerAd createBanner({
    AdSize size = AdSize.banner,
    void Function(Ad ad)? onLoaded,
    void Function(Ad ad, LoadAdError err)? onFailed,
  }) =>
      BannerAd(
        adUnitId: bannerUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: onLoaded,
          onAdFailedToLoad: (ad, err) {
            ad.dispose();
            debugPrint('배너 로드 실패: ${err.message}');
            onFailed?.call(ad, err);
          },
        ),
      );
}

/// 전면·리워드 광고 하나를 담는 슬롯. 로드 중복, 만료, 재시도 횟수를 함께 관리한다.
class _FullScreenSlot<T extends Object> {
  _FullScreenSlot(this.label);
  final String label;

  T? ad;
  DateTime? loadedAt;
  bool loading = false;
  int attempts = 0;
  Timer? retryTimer;

  /// 진행 중인 로드 한 번이 끝나면(성공이든 실패든) 완료된다.
  /// 버튼을 누른 순간 광고가 아직 안 와 있을 때 이걸 기다린다.
  Completer<void>? _inFlight;
  Future<void>? get inFlight => _inFlight?.future;

  /// 새 로드를 시작해도 되면 true. 이미 로드됐거나 진행 중이면 false.
  bool beginLoad({bool resetBackoff = false}) {
    if (ad != null || loading) return false;
    if (resetBackoff) attempts = 0; // 복귀·버튼 누름은 백오프를 처음부터
    retryTimer?.cancel();
    retryTimer = null;
    loading = true;
    attempts++;
    _inFlight ??= Completer<void>();
    return true;
  }

  void loaded(T a) {
    ad = a;
    loadedAt = DateTime.now();
    loading = false;
    attempts = 0;
    _settle();
  }

  void failed(LoadAdError err) {
    loading = false;
    ad = null;
    debugPrint('$label 광고 로드 실패($attempts회): ${err.message}');
    _settle();
  }

  /// 기다리던 쪽을 깨운다. 다음 로드는 새 Completer 를 쓴다.
  void _settle() {
    final c = _inFlight;
    _inFlight = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  bool isStale(Duration maxAge) {
    final t = loadedAt;
    return ad != null && t != null && DateTime.now().difference(t) > maxAge;
  }

  /// 광고를 꺼내면서 슬롯을 비운다.
  T? take() {
    final a = ad;
    ad = null;
    loadedAt = null;
    return a;
  }

  void discard() {
    final a = take();
    if (a is InterstitialAd) a.dispose();
    if (a is RewardedAd) a.dispose();
  }
}
