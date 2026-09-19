import 'dart:async';

import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry, kDebugMode, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'ads/ad_manager.dart';
import 'debug/debug_gallery.dart';
import 'engine/save_service.dart';
import 'engine/story_repository.dart';
import 'game_controller.dart';
import 'minigames/minigame.dart';
import 'minigames/registry.dart';
import 'ui/action_screen.dart';
import 'ui/design_system.dart';
import 'ui/ending_screen.dart';
import 'ui/event_screen.dart';
import 'ui/home_screen.dart';
import 'ui/portraits.dart';
import 'ui/summary_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();
  registerPretendardLicense();
  registerMinigames();
  try {
    // 초상화 목록(AssetManifest)은 스토리와 나란히 읽는다. 실패해도 던지지 않는다(이니셜로 대체).
    final portraits = PortraitRegistry.load();
    final bundle = await StoryBundle.loadFromAssets(
      knownMinigames: minigameIds,
    );
    await portraits;
    if (kDebugMode && kDebugGallery) {
      // QA 용. `--dart-define=MOSSOL_DEBUG_GALLERY=true` 로 미니게임·엔딩 갤러리에서 시작.
      // kDebugMode 가 const false 인 릴리스 빌드에서는 갤러리 코드가 트리셰이킹된다.
      runApp(DebugGalleryApp(bundle: bundle));
      return;
    }
    final controller = GameController(bundle: bundle, save: SaveService());
    await controller.init();
    unawaited(AdManager.instance.init());
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
                    await SaveService().clear();
                  },
                  child: const Text('저장된 기록 지우기'),
                ),
                const SizedBox(height: 16),
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

class MossolApp extends StatelessWidget {
  final GameController controller;
  const MossolApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '모쏠 키우기',
      debugShowCheckedModeBanner: false,
      // 테마는 전부 lib/ui/design_system.dart 에서 나온다.
      // 화면에서 색·간격·모서리를 다시 정의하지 마라. 규격은 docs/DESIGN_SYSTEM.md.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => switch (controller.phase) {
          Phase.home => HomeScreen(c: controller),
          Phase.action => ActionScreen(c: controller),
          Phase.event => EventScreen(c: controller),
          Phase.summary => SummaryScreen(c: controller),
          Phase.ending => EndingScreen(c: controller),
        },
      ),
    );
  }
}
