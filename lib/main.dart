import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show
        LicenseEntryWithLineBreaks,
        LicenseRegistry,
        kDebugMode,
        kIsWeb,
        kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'ads/ad_manager.dart';
import 'analytics/analytics.dart';
import 'audio/sfx_service.dart';
import 'debug/debug_gallery.dart';
import 'engine/meta_service.dart';
import 'engine/save_service.dart';
import 'engine/story_repository.dart';
import 'game_controller.dart';
import 'minigames/minigame.dart';
import 'minigames/registry.dart';
import 'ui/action_screen.dart';
import 'ui/day_card.dart';
import 'ui/design_system.dart';
import 'ui/ending_screen.dart';
import 'ui/event_screen.dart';
import 'ui/home_screen.dart';
import 'ui/intro_screen.dart';
import 'ui/portraits.dart';
import 'ui/scene_registry.dart';
import 'ui/summary_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();
  registerPretendardLicense();
  registerSfxLicense();
  registerMinigames();
  installSfxService();
  try {
    // 측정. GoogleService-Info.plist 가 없으면(Firebase 프로젝트를 아직 안 만들었으면)
    // 조용히 디버그 백엔드로 남는다 — 던지지 않는다. 스토리 읽기와 나란히 돈다.
    final analytics = Analytics.init();
    // 초상화 목록(AssetManifest)은 스토리와 나란히 읽는다. 실패해도 던지지 않는다(이니셜로 대체).
    final portraits = PortraitRegistry.load();
    // 장면 삽화·사진·스티커·엔딩 목록도 같은 매니페스트에서. 없으면 그림 없는 화면 그대로.
    final scenes = SceneRegistry.load();
    final bundle = await StoryBundle.loadFromAssets(
      knownMinigames: minigameIds,
    );
    await portraits;
    await scenes;
    await analytics;
    if (kDebugMode && kDebugGallery) {
      // QA 용. `--dart-define=MOSSOL_DEBUG_GALLERY=true` 로 미니게임·엔딩 갤러리에서 시작.
      // kDebugMode 가 const false 인 릴리스 빌드에서는 갤러리 코드가 트리셰이킹된다.
      runApp(DebugGalleryApp(bundle: bundle));
      return;
    }
    final controller = GameController(bundle: bundle, save: SaveService());
    await controller.init();
    // 첫 실행이면 광고·ATT 를 인트로가 끝난 뒤에 켠다. 앱을 열자마자 추적 동의 팝업이
    // 태현의 첫 문자를 덮으면 연출이 죽고, 무슨 앱인지도 모르는 채 답하게 된다.
    // 인트로 동안에는 광고가 한 장도 안 나오므로 미뤄도 잃는 것이 없다.
    if (!controller.shouldShowIntro) unawaited(AdManager.instance.init());
    runApp(MossolApp(controller: controller));
  } catch (e, stack) {
    // 여기서 죽으면 유저는 흰 화면만 본다. 이유를 보여 주고 빠져나갈 길을 준다.
    debugPrint('시작 실패: $e\n$stack');
    runApp(StartupFailureApp(reason: '$e'));
  }
}

/// Pretendard(OFL 1.1) 전문을 라이선스 페이지에 올린다. runApp 전에 한 번.
/// 설정 → 오픈소스 라이선스에서 다른 패키지와 나란히 보인다(HOME_REDESIGN §2.4).
void registerPretendardLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/fonts/Pretendard-LICENSE.txt',
    );
    yield LicenseEntryWithLineBreaks(const ['Pretendard'], text);
  });
}

/// 효과음 출처(assets/sfx/LICENSES.md)를 같은 라이선스 페이지에 올린다.
void registerSfxLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/sfx/LICENSES.md');
    yield LicenseEntryWithLineBreaks(const ['효과음'], text);
  });
}

/// 실기기(iOS·Android)에서만 audioplayers 구현을 끼운다. 웹·테스트는 [NoopSfxService]
/// 그대로. 컨트롤러 init 이 메타의 토글을 여기에 밀어 넣으므로 그보다 먼저 부른다.
void installSfxService() {
  if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return;
  final service = AudioSfxService();
  SfxService.instance = service;
  // 프리로드는 스토리 읽기와 나란히. 실패해도 던지지 않는다(소리만 없다).
  unawaited(service.init());
}

/// 처리되지 않은 오류가 조용히 사라지지 않게 한다.
/// 출시 뒤 원인을 알 수 있는 유일한 창구이고, 나중에 크래시 수집을 붙일 자리이기도 하다.
void _installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('위젯 오류: ${details.exceptionAsString()}');
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('처리되지 않은 오류: $error');
    return true;
  };
  if (kReleaseMode) {
    // 출시 빌드에서 빨간 오류 화면 대신 조용한 자리를 남긴다.
    ErrorWidget.builder = (_) => const SizedBox.shrink();
  }
}

/// 스토리 데이터나 세이브를 읽지 못해 앱이 뜨지 못했을 때의 화면.
class StartupFailureApp extends StatelessWidget {
  final String reason;
  const StartupFailureApp({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sentiment_dissatisfied, size: 48),
                const SizedBox(height: 16),
                Text(
                  '게임을 시작하지 못했어요',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  '앱을 완전히 닫았다 다시 열어 주세요. '
                  '그래도 같은 화면이 나오면 저장된 기록을 지우고 새로 시작할 수 있어요.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    // 세이브만 지우면 깨진 엔딩 기록·설정 때문에 같은 화면이 반복될 수 있다.
                    final save = SaveService();
                    await save.clear();
                    await save.clearEndings();
                    await MetaService().clear();
                  },
                  child: const Text('저장된 기록 지우기'),
                ),
                if (kDebugMode) const SizedBox(height: 16),
                // 오류 원문은 개발 중에만 보인다.
                if (kDebugMode)
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MossolApp extends StatefulWidget {
  final GameController controller;
  const MossolApp({super.key, required this.controller});

  @override
  State<MossolApp> createState() => _MossolAppState();
}

class _MossolAppState extends State<MossolApp> {
  GameController get controller => widget.controller;
  Phase? _lastPhase;

  @override
  void initState() {
    super.initState();
    _lastPhase = controller.phase;
    controller.addListener(_onPhase);
  }

  @override
  void dispose() {
    controller.removeListener(_onPhase);
    super.dispose();
  }

  /// 정산·엔딩 진입음. SummaryScreen 이 Stateless 라 화면이 아니라 phase 변화를 듣는다
  /// (docs/overhaul/05_audio_haptics.md §1 #10·#11). 엔딩은 다른 소리를 전부 멈춘다.
  void _onPhase() {
    final phase = controller.phase;
    if (phase == _lastPhase) return;
    _lastPhase = phase;
    switch (phase) {
      case Phase.summary:
        SfxService.instance.cue(Sfx.summary);
      case Phase.ending:
        SfxService.instance.cue(Sfx.ending);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '모쏠 탈출기',
      debugShowCheckedModeBanner: false,
      // 테마는 전부 lib/ui/design_system.dart 에서 나온다.
      // 화면에서 색·간격·모서리를 다시 정의하지 마라. 규격은 docs/DESIGN_SYSTEM.md.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => switch (controller.phase) {
          // 첫 실행에는 홈 대신 인트로(태현의 첫 문자)를 세운다. 인트로가 끝나면
          // 곧바로 첫날이라 홈은 두 번째 세션부터 보인다(00_VERDICT §3).
          Phase.home when controller.shouldShowIntro => IntroScreen(
            c: controller,
          ),
          Phase.home => HomeScreen(c: controller),
          Phase.dayStart => DayTransitionScreen(c: controller),
          Phase.action => ActionScreen(c: controller),
          Phase.event => EventScreen(c: controller),
          Phase.summary => SummaryScreen(c: controller),
          Phase.ending => EndingScreen(c: controller),
        },
      ),
    );
  }
}
