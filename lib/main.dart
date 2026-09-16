import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'ads/ad_manager.dart';
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
import 'ui/summary_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();
  registerMinigames();
  try {
    final bundle = await StoryBundle.loadFromAssets(knownMinigames: minigameIds);
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
