import 'dart:async';

import 'package:flutter/material.dart';

import 'ads/ad_manager.dart';
import 'engine/save_service.dart';
import 'engine/story_repository.dart';
import 'game_controller.dart';
import 'minigames/minigame.dart';
import 'minigames/registry.dart';
import 'ui/action_screen.dart';
import 'ui/ending_screen.dart';
import 'ui/event_screen.dart';
import 'ui/home_screen.dart';
import 'ui/summary_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerMinigames();
  final bundle = await StoryBundle.loadFromAssets(knownMinigames: minigameIds);
  final controller = GameController(bundle: bundle, save: SaveService());
  await controller.init();
  unawaited(AdManager.instance.init());
  runApp(MossolApp(controller: controller));
}

class MossolApp extends StatelessWidget {
  final GameController controller;
  const MossolApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '모쏠 키우기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC2295A)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF06A8F), brightness: Brightness.dark),
        useMaterial3: true,
      ),
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
