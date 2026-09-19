import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../engine/story_repository.dart';
import '../engine/text_template.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'onboarding_name_screen.dart';
import 'preference_screen.dart';
import 'widgets.dart';

/// 새 게임 흐름의 결과. [gender] 는 이번에 1단계에서 답했을 때만 있다(이미 답이 있으면 null).
/// [nameStep] 은 이름 단계를 거쳤는지, [name] 은 거기서 입력한 이름(건너뛰었으면 null).
typedef NewGamePick = ({
  String? gender,
  bool nameStep,
  String? name,
  String preference,
});

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

  /// 새 게임 흐름 전체: 1단계 "나는?" → 이름 단계 → 2단계 캐스트 소개.
  ///
  /// [savedGender] 가 있으면 1단계를 건너뛴다. [askName] 이 true 일 때만 이름 단계를
  /// 끼운다(홈은 `GameController.shouldAskName` — 이름이 없고 아직 묻지 않았을 때).
  /// 뒤로 가면 앞 단계로 돌아간다. 끝까지 고르면 결과를, 도중에 나가면 null.
  /// 아무것도 저장하지 않는다 — 새 게임이 실제로 시작될 때 호출부가 저장한다.
  static Future<NewGamePick?> run(
    BuildContext context,
    StoryBundle bundle, {
    String? savedGender,
    bool askName = false,
  }) async {
    // [newGender] 는 이번에 1단계에서 고른 값(결과에 싣는다), [gender] 는 기본 쪽을 정할 값.
    Future<NewGamePick?> afterGender(
      BuildContext ctx,
      String? gender,
      String? newGender,
    ) async {
      final side = PlayerGender.sideFor(gender);
      if (!askName) {
        final pref = await PreferenceScreen.show(ctx, bundle, side: side);
        return pref == null
            ? null
            : (
                gender: newGender,
                nameStep: false,
                name: null,
                preference: pref,
              );
      }
      return Navigator.of(ctx).push<NewGamePick>(
        MaterialPageRoute(
          builder: (nctx) {
            Future<void> next(String? name) async {
              // 캐스트 소개의 첫 메시지도 방금 고른 이름으로 보여 준다(저장 전이라 잠시만).
              final saved = TextTemplate.currentName;
              TextTemplate.currentName = name;
              final String? pref;
              try {
                pref = await PreferenceScreen.show(nctx, bundle, side: side);
              } finally {
                TextTemplate.currentName = saved;
              }
              if (pref == null || !nctx.mounted) return;
              Navigator.of(nctx).pop<NewGamePick>((
                gender: newGender,
                nameStep: true,
                name: name,
                preference: pref,
              ));
            }

            return OnboardingNameScreen(
              onSubmit: next,
              onSkip: () => next(null),
            );
          },
        ),
      );
    }

    if (savedGender != null) {
      return afterGender(context, savedGender, null);
    }
    return Navigator.of(context).push<NewGamePick>(
      MaterialPageRoute(
        builder: (ctx) => OnboardingGenderScreen(
          onPicked: (g) async {
            final pick = await afterGender(ctx, g, g);
            if (pick == null || !ctx.mounted) return;
            Navigator.of(ctx).pop<NewGamePick>(pick);
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
