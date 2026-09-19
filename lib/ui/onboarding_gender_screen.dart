import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../engine/story_repository.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'preference_screen.dart';
import 'widgets.dart';

/// 새 게임 흐름의 결과. [gender] 는 이번에 1단계에서 답했을 때만 있다(이미 답이 있으면 null).
typedef NewGamePick = ({String? gender, String preference});

/// 새 게임 1단계: "나는?" → 남자 / 여자 / 선택 안 할래요.
///
/// 규격: docs/DESIGN_SYSTEM.md §2.11. 답은 캐스트 소개(2단계, [PreferenceScreen])에서 어느
/// 쪽을 먼저 보여 줄지만 정한다. 버튼을 누르면 확인 없이 2단계로 넘어가고, 2단계에서 뒤로
/// 가면 이 화면으로 돌아온다. 저장은 새 게임이 실제로 시작될 때 호출부가 한다(중간에
/// 나가면 아무것도 남지 않는다).
class OnboardingGenderScreen extends StatelessWidget {
  /// 고른 값을 받는 곳([PlayerGender] 값).
  final ValueChanged<String> onPicked;

  const OnboardingGenderScreen({super.key, required this.onPicked});

  static const title = '나는?';
  static const subtitle = '만나게 될 사람들이 달라져요';
  static const note = '이 기기에만 저장돼요. 설정에서 바꿀 수 있어요';

  /// 버튼 세 개의 라벨·보조 문구. 순서가 곧 화면 순서.
  static const options = [
    (PlayerGender.male, Icons.male, '남자', '여성 캐릭터를 먼저 소개해요'),
    (PlayerGender.female, Icons.female, '여자', '남성 캐릭터를 먼저 소개해요'),
    (PlayerGender.none, Icons.people_outline, '선택 안 할래요', '두 쪽을 비교해 보고 골라요'),
  ];

  /// 새 게임 흐름 전체. [savedGender] 가 있으면 1단계를 건너뛰고 2단계(기본 쪽)부터.
  /// 없으면 1단계 → 2단계. 끝까지 고르면 결과를, 도중에 나가면 null.
  static Future<NewGamePick?> run(
    BuildContext context,
    StoryBundle bundle, {
    String? savedGender,
  }) async {
    if (savedGender != null) {
      final pref = await PreferenceScreen.show(
        context,
        bundle,
        side: PlayerGender.sideFor(savedGender),
      );
      return pref == null ? null : (gender: null, preference: pref);
    }
    return Navigator.of(context).push<NewGamePick>(
      MaterialPageRoute(
        builder: (ctx) => OnboardingGenderScreen(
          onPicked: (g) async {
            final pref = await PreferenceScreen.show(
              ctx,
              bundle,
              side: PlayerGender.sideFor(g),
            );
            if (pref == null || !ctx.mounted) return;
            Navigator.of(ctx).pop<NewGamePick>((gender: g, preference: pref));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.screenX,
              AppSpace.xs,
              AppSpace.screenX,
              AppSpace.xxl,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: box.maxHeight - AppSpace.xs - AppSpace.xxl,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: context.text.displaySmall),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      keepAll(subtitle),
                      style: context.text.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    // 빈 가운데를 메신저 장면 하나로 채운다: 아직 모르는 누군가가 입력 중.
                    // 작은 화면에서는 빼고 버튼을 올린다.
                    Expanded(
                      child: box.maxHeight >= _TypingTeaser.minScreen
                          ? const Center(child: _TypingTeaser())
                          : const SizedBox(height: AppSpace.xxl),
                    ),
                    for (final (i, (g, icon, label, hint))
                        in options.indexed) ...[
                      if (i > 0) const SizedBox(height: AppSpace.gap),
                      GenderOptionCard(
                        key: Key('gender-$g'),
                        icon: icon,
                        label: label,
                        hint: hint,
                        onTap: () => onPicked(g),
                      ),
                    ],
                    const SizedBox(height: AppSpace.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpace.xxs),
                          child: Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Text(
                            keepAll(note),
                            style: context.text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 가운데 장식: 실루엣 아바타 + 입력 중 말풍선(점 세 개) + 한 줄. 장식이라 스크린리더에서 뺀다.
class _TypingTeaser extends StatelessWidget {
  const _TypingTeaser();

  /// 이 높이보다 낮은 본문에서는 그리지 않는다(320×568 에서는 버튼이 먼저다).
  static const minScreen = 600.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _typingRow(t),
            const SizedBox(height: AppSpace.md),
            Text(
              keepAll(caption),
              style: context.text.labelMedium?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const caption = '누가 먼저 말을 걸어올까요?';

  Widget _typingRow(AppTokens t) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      const CharacterAvatar(name: '', mystery: true, size: 56),
      const SizedBox(width: AppSpace.sm),
      Container(
        padding: AppInsets.bubble,
        decoration: BoxDecoration(
          color: t.bubbleTheirs,
          borderRadius: AppRadius.bubble(mine: false),
          border: Border.all(
            color: t.bubbleBorder,
            width: AppBorderWidth.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: AppSpace.xs),
              Container(
                width: AppSpace.sm,
                height: AppSpace.sm,
                decoration: BoxDecoration(
                  color: t.systemLine,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
