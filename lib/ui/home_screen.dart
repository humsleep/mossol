import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../game_controller.dart';
import 'album_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  final GameController c;
  const HomeScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '모쏠 키우기',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text('100일 안에 연애 고수가 되기까지', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 40),
              if (c.hasSave)
                FilledButton(
                  onPressed: () => c.continueGame(),
                  child: const Text('이어하기'),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  if (c.hasSave) {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('새 게임'),
                        content: const Text('진행 중인 회차가 지워집니다. 시작할까요?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('취소'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('시작'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                  }
                  await c.newGame();
                },
                child: const Text('새 게임'),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => AlbumScreen(c: c))),
                icon: const Icon(Icons.photo_album_outlined, size: 18),
                label: Text(
                  '앨범  ${c.endingAlbum.length} / ${c.bundle.endings.length}',
                ),
              ),
              const SizedBox(height: 4),
              FutureBuilder<bool>(
                future: AdManager.instance.privacyOptionsRequired,
                builder: (context, snap) => snap.data == true
                    ? TextButton(
                        onPressed: AdManager.instance.showPrivacyOptions,
                        child: const Text(
                          '개인정보 설정',
                          style: TextStyle(fontSize: 12),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BannerSlot(),
    );
  }
}
