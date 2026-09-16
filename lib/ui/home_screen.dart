import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../game_controller.dart';
import 'album_screen.dart';
import 'design_system.dart';
import 'widgets.dart';

/// 첫 화면. 규격은 docs/DESIGN_SYSTEM.md §2.1.
///
/// 위계는 하나뿐이다: 타이틀 → 1차 버튼. 나머지(부제, 진행 상태, 앨범,
/// 개인정보 설정)는 순서대로 뒤로 물러난다. 장식은 로즈 방사 그라데이션
/// 한 겹만 허용된다(규격 §2.1).
class HomeScreen extends StatelessWidget {
  final GameController c;
  const HomeScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _RoseGlow()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: AppInsets.screen,
                child: ConstrainedBox(
                  // 내용이 짧으면 화면을 채우고, 길어지면(큰 글꼴) 스크롤한다.
                  constraints: BoxConstraints(
                    minHeight: box.maxHeight - AppInsets.screen.vertical,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: _topSpace(context, box.maxHeight)),
                      const _Title(),
                      const SizedBox(height: AppSpace.huge),
                      _Start(c: c),
                      const SizedBox(height: AppSpace.xxl),
                      _Back(c: c),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BannerSlot(),
    );
  }

  /// 타이틀 위 여백. 규격은 화면의 40% 지만, 글자가 커지면 그만큼 양보한다.
  /// 작은 화면(320×568) + 1.3배에서 첫 화면이 스크롤로 밀리지 않게 하기 위해서다.
  static double _topSpace(BuildContext context, double height) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final factor = 0.40 - ((scale - 1).clamp(0.0, 0.6) * 0.35);
    return (height * factor).clamp(AppSpace.xxl, double.infinity);
  }
}

/// 배경 한 겹. 위에서 아래로 퍼지는 로즈 빛. 라이트에서는 종이에 번진 잉크,
/// 다크에서는 불 끈 방의 조명처럼 보인다.
class _RoseGlow extends StatelessWidget {
  const _RoseGlow();

  @override
  Widget build(BuildContext context) {
    final primary = context.scheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.1,
          colors: [
            primary.withValues(alpha: 0.06),
            primary.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// 타이틀 블록. 화면의 주인공이다.
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('모쏠 키우기', style: context.text.displaySmall),
      const SizedBox(height: AppSpace.sm),
      Text(
        '100일 안에 연애 고수가 되기까지',
        style: context.text.bodyLarge?.copyWith(
          color: context.scheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

/// 시작 묶음. 세이브가 있으면 `이어하기` 가 1차, `새 게임` 이 2차다.
/// 세이브가 없으면 빈자리를 남기지 않고 `새 게임` 이 1차 자리로 올라온다.
class _Start extends StatelessWidget {
  final GameController c;
  const _Start({required this.c});

  @override
  Widget build(BuildContext context) {
    if (!c.hasSave) {
      return FilledButton(
        onPressed: () => c.newGame(),
        child: const Text('새 게임'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Progress(c: c),
        FilledButton(
          onPressed: () => c.continueGame(),
          child: const Text('이어하기'),
        ),
        const SizedBox(height: AppSpace.md),
        OutlinedButton(
          onPressed: () => _confirmNewGame(context),
          child: const Text('새 게임'),
        ),
      ],
    );
  }

  /// 진행 중인 회차를 지우기 전에 한 번 묻는다. 문구·동작은 그대로 둔다.
  Future<void> _confirmNewGame(BuildContext context) async {
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
    await c.newGame();
  }
}

/// 이어할 회차가 어디까지 왔는지. `이어하기` 바로 위에서 그 버튼의 맥락이 된다.
/// 복원 전(앱을 새로 켠 직후)에는 상태가 없으므로 아무것도 그리지 않는다.
class _Progress extends StatelessWidget {
  final GameController c;
  const _Progress({required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.state;
    if (s == null) return const SizedBox.shrink();

    final total = c.config.totalDays;
    final ratio = total <= 0 ? 0.0 : (s.day / total).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'D+${s.day}',
            style: context.tokens.numericMedium,
          ),
          const SizedBox(height: AppSpace.sm),
          AppProgressBar(
            value: ratio,
            semanticLabel: '진행도 ${s.day}일 / $total일',
            height: AppSpace.xs + 2,
          ),
        ],
      ),
    );
  }
}

/// 배경 묶음. 앨범이 먼저, 개인정보 설정이 가장 뒤다.
class _Back extends StatelessWidget {
  final GameController c;
  const _Back({required this.c});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Column(
      children: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AlbumScreen(c: c)),
          ),
          icon: const Icon(Icons.photo_album_outlined, size: 18),
          // 한 덩어리 Text 를 유지한다(테스트가 '앨범  N /' 로 찾는다).
          label: Text(
            '앨범  ${c.endingAlbum.length} / ${c.bundle.endings.length}',
            style: context.tokens.numericSmall.copyWith(color: scheme.primary),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        FutureBuilder<bool>(
          future: AdManager.instance.privacyOptionsRequired,
          builder: (context, snap) => snap.data == true
              ? TextButton(
                  onPressed: AdManager.instance.showPrivacyOptions,
                  child: Text(
                    '개인정보 설정',
                    style: context.text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
