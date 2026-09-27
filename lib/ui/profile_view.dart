/// 채팅 아바타를 눌러 여는 전체 화면 프로필. docs/DESIGN_SYSTEM.md §2.15.
///
/// 진짜 메신저처럼 "상대 사진을 누르면 크게 본다". 말풍선 왼쪽 아바타(40)와 통화 머리줄
/// 아바타(40)를 누르면 같은 초상화가 [AppSize.avatarHero] 로 날아오르고(Hero), 그 아래
/// 이름·호칭과 **플레이어가 이미 알게 된 것만** 붙는다. 아무 데나 탭하거나 아래로 쓸면 닫힌다.
///
/// 크게 보기 껍데기는 사진 카드(`photo_card.dart` `_PhotoViewer`)와 같은 모양이다 —
/// SafeArea + 가운데 스크롤 + `닫기` 버튼, 아무 데나 탭하면 닫힘. 다만 두 가지가 다르다.
///
/// ① `showAppDialog` 를 그대로 쓰지 못한다: `showDialog` 가 미는 것은 `PageRoute` 가
/// 아니라서 `HeroController` 가 비행을 시작하지 않는다(`HeroController.didPush` 는 양쪽이
/// `PageRoute` 일 때만 움직인다). 그래서 같은 생김새를 `PageRouteBuilder` 로 한 번 더 태운다.
/// ② 바탕은 스크림이 아니라 `scheme.surface` 한 장이다. 사진은 한 줄짜리 캡션뿐이지만
/// 프로필에는 이름·호칭·매력이 문단으로 들어가는데, 스크림 너머로 대화가 비치면 본문 대비가
/// 4.5:1 을 못 넘는다(§4.2). 라우트는 여전히 투명(`opaque: false`)이라 이 판이 아래로
/// 끌려 내려가면 그 뒤의 대화가 그대로 드러난다.
///
/// **모르는 것은 그리지 않는다.** 화면에 오르는 값은 전부 플레이어가 이미 다른 화면에서
/// 본 것들이다: 이름·호칭·한 줄 매력·MBTI·궁합은 캐스트 소개(§2.9)가 새 게임마다 보여
/// 주고, 호감은 홈 사람들 줄(§2.10)이 보여 준다. 히든 미해금·`모르는 번호` 처럼 정체를
/// 모르는 상대는 아예 열리지 않는다([CharacterProfile.viewable] 이 false).
library;

import 'package:flutter/material.dart';

import 'design_system.dart';
import 'keep_all.dart';
import 'portraits.dart';
import 'widgets.dart';

/// 프로필 한 장에 담기는 값. **플레이어가 이미 알게 된 것만** 넣는다.
@immutable
class CharacterProfile {
  /// 캐스트 id. null 이면 캐스트 밖 인물(태현·엄마 같은 조연)이라 초상화도 없다.
  final String? id;

  final String name;

  /// 소개 호칭(`CharacterDef.displayTitle`). 모르면 빈 문자열.
  final String title;

  /// 캐스트 소개의 한 줄 매력. 모르면 빈 문자열.
  final String tagline;

  /// 캐릭터 MBTI. 캐스트 소개 카드가 이미 보여 준 값이다.
  final String? mbti;

  /// 플레이어 MBTI 와의 궁합 점수. 플레이어가 MBTI 를 안 알려 줬으면 null.
  final int? compat;

  /// 이번 회차 호감. 세이브가 없거나 이 회차에 안 나오는 사람이면 null.
  final int? affection;

  /// 아직 정체를 모르는 상대(히든 미해금 · `모르는 번호`). 열지 않는다.
  final bool mystery;

  const CharacterProfile({
    this.id,
    required this.name,
    this.title = '',
    this.tagline = '',
    this.mbti,
    this.compat,
    this.affection,
    this.mystery = false,
  });

  /// 초상화가 번들에 있는지. 그림이 있으면 "크게 보기" 자체가 볼거리다.
  bool get hasPortrait => PortraitRegistry.current.pathFor(id) != null;

  /// 이름 말고 보여 줄 것이 하나라도 있는지.
  bool get hasFacts =>
      title.isNotEmpty ||
      tagline.isNotEmpty ||
      mbti != null ||
      affection != null;

  /// 열어도 되는 프로필인지. 정체를 모르는 상대는 열지 않고(스포일러), 그림도 사실도
  /// 없는 상대(이니셜 원 하나뿐인 조연)는 열어 봐야 빈 화면이라 열지 않는다.
  bool get viewable => !mystery && (hasPortrait || hasFacts);
}

/// 아바타가 자기 프로필을 찾는 곳. 화면(이벤트·통화)이 컨트롤러를 알고 있으므로
/// 말풍선까지 매개변수를 들고 내려가지 않고 여기서 거꾸로 묻는다.
///
/// 스코프가 없으면([of] 가 null) 아바타는 그냥 그림이다 — 누를 수 없다. 인트로처럼
/// 캐스트가 아직 없는 화면과 위젯 테스트가 그 상태로 돈다.
class ProfileScope extends InheritedWidget {
  /// 화자 id·이름으로 프로필을 찾는다. 모르는 사람이면 null.
  final CharacterProfile? Function(String? id, String name) resolve;

  const ProfileScope({super.key, required this.resolve, required super.child});

  static ProfileScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileScope>();

  /// 열 수 있는 프로필만 돌려준다. 스코프가 없거나 모르는 사람이면 null.
  static CharacterProfile? lookup(
    BuildContext context, {
    required String? id,
    required String name,
  }) {
    final p = of(context)?.resolve(id, name);
    return p != null && p.viewable ? p : null;
  }

  @override
  bool updateShouldNotify(ProfileScope old) => old.resolve != resolve;
}

/// 아바타 하나를 Hero 로 감싼다.
///
/// 40 → 200 처럼 크기가 크게 달라지므로 비행 중에는 [FittedBox] 로 줄인다. 그러지
/// 않으면 [CharacterAvatar] 가 자기 크기를 고집해 비행 중간 프레임에서 원이 잘린다.
class PortraitHero extends StatelessWidget {
  final Object tag;
  final Widget child;

  const PortraitHero({super.key, required this.tag, required this.child});

  @override
  Widget build(BuildContext context) => Hero(
    tag: tag,
    // 양쪽(작은 아바타·큰 초상화) 모두에 달아 둔다. 미는 쪽은 도착지의 것을,
    // 닫는 쪽은 출발지의 것을 쓰므로 둘이 같아야 비행이 매끄럽다.
    flightShuttleBuilder: (context, animation, direction, from, to) =>
        FittedBox(fit: BoxFit.contain, child: child),
    child: child,
  );
}

/// 누르면 프로필이 열리는 아바타 한 칸. 열 수 없는 상대면 [child] 를 그대로 돌려준다
/// (레이아웃도 시맨틱도 지금과 1px 도 다르지 않다).
///
/// Hero 태그는 이 State 가 들고 있는 [Object] 하나다. 같은 사람이 한 화면에 여러 번
/// 나와도(묶음마다 아바타 하나) 태그가 겹치지 않아 Hero 가 터지지 않는다.
class PortraitTapTarget extends StatefulWidget {
  /// 아바타 그 자체. [CharacterAvatar] 든 통화용 원이든 상관없다.
  final Widget child;

  /// 화자 id(캐스트 id). NPC 는 null.
  final String? characterId;

  /// 화자 이름. 프로필을 찾을 때 id 가 없으면 이것으로 찾는다.
  final String name;

  const PortraitTapTarget({
    super.key,
    required this.child,
    required this.characterId,
    required this.name,
  });

  @override
  State<PortraitTapTarget> createState() => _PortraitTapTargetState();
}

class _PortraitTapTargetState extends State<PortraitTapTarget> {
  /// 이 아바타만의 Hero 태그. 화면이 다시 그려져도 같은 값이다.
  final Object _tag = Object();

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.lookup(
      context,
      id: widget.characterId,
      name: widget.name,
    );
    if (profile == null) return widget.child;
    return Semantics(
      button: true,
      label: '${widget.name} 프로필',
      hint: '사진 크게 보기',
      excludeSemantics: true,
      onTap: () => showCharacterProfile(context, profile, heroTag: _tag),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showCharacterProfile(context, profile, heroTag: _tag),
        child: PortraitHero(tag: _tag, child: widget.child),
      ),
    );
  }
}

/// 프로필을 전체 화면으로 띄운다. 화면 탭·아래로 쓸기·`닫기` 로 닫힌다.
Future<void> showCharacterProfile(
  BuildContext context,
  CharacterProfile profile, {
  required Object heroTag,
}) {
  // 통화 화면은 라이트 모드에서도 자기만 다크다(AppTheme.dark 를 지역에 덮어쓴다).
  // 라우트는 Navigator 아래에서 새로 만들어지므로 그 테마를 들고 간다.
  final theme = Theme.of(context);
  final duration = AppMotion.base(context);
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      // 투명 라우트라 아래로 끌어내리면 그 뒤의 대화가 보인다. 스크림은 두지 않는다 —
      // 본문 대비는 화면이 직접 깐 surface 가 책임진다.
      opaque: false,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondary) => Theme(
        data: theme,
        child: CharacterProfileView(profile: profile, heroTag: heroTag),
      ),
      // 초상화는 Hero 가 옮긴다. 나머지 글자만 같이 밝아진다.
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// 프로필 한 장의 본문. 사진 크게 보기(`_PhotoViewer`)와 같은 껍데기다.
class CharacterProfileView extends StatefulWidget {
  final CharacterProfile profile;
  final Object heroTag;

  const CharacterProfileView({
    super.key,
    required this.profile,
    required this.heroTag,
  });

  /// 이만큼 아래로 끌면 닫는다. 이보다 빠르게 튕기면 거리와 상관없이 닫는다.
  static const double dismissDistance = 96;
  static const double dismissVelocity = 700;

  @override
  State<CharacterProfileView> createState() => _CharacterProfileViewState();
}

class _CharacterProfileViewState extends State<CharacterProfileView> {
  /// 손가락을 따라 내려간 거리. 놓으면 0 으로 돌아가거나 화면이 닫힌다.
  double _dy = 0;
  bool _dragging = false;

  void _close() => Navigator.of(context).maybePop();

  void _dragUpdate(DragUpdateDetails d) => setState(() {
    _dragging = true;
    // 위로는 끌리지 않는다. 사진을 끌어내리는 동작 하나만 있다.
    _dy = (_dy + d.delta.dy).clamp(0, double.infinity);
  });

  void _dragEnd(DragEndDetails d) {
    final fling = d.velocity.pixelsPerSecond.dy;
    if (_dy >= CharacterProfileView.dismissDistance ||
        fling >= CharacterProfileView.dismissVelocity) {
      _close();
      return;
    }
    setState(() {
      _dragging = false;
      _dy = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final scheme = context.scheme;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: '${p.name} 프로필',
      child: GestureDetector(
        // 사진 위를 눌러도, 빈 자리를 눌러도 닫힌다(사진 크게 보기와 같은 약속).
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        onVerticalDragUpdate: _dragUpdate,
        onVerticalDragEnd: _dragEnd,
        child: AnimatedSlide(
          offset: Offset(0, _dy / MediaQuery.sizeOf(context).height),
          duration: _dragging ? Duration.zero : AppMotion.base(context),
          curve: AppMotion.curve(context),
          child: Material(
            color: scheme.surface,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PortraitHero(
                        tag: widget.heroTag,
                        child: CharacterAvatar(
                          name: p.name,
                          characterId: p.id,
                          accent: context.tokens.accentFor(p.id),
                          size: AppSize.avatarHero,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      Text(
                        p.name,
                        textAlign: TextAlign.center,
                        style: context.text.headlineMedium,
                      ),
                      if (p.title.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          keepAll(p.title),
                          textAlign: TextAlign.center,
                          style: context.text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (p.tagline.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.md),
                        Text(
                          keepAll(p.tagline),
                          textAlign: TextAlign.center,
                          style: context.text.bodyLarge,
                        ),
                      ],
                      if (p.mbti != null || p.affection != null) ...[
                        const SizedBox(height: AppSpace.md),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: AppSpace.sm,
                          runSpacing: AppSpace.sm,
                          children: [
                            if (p.mbti case final m?) MbtiChip(mbti: m),
                            if (p.affection case final a?)
                              _AffectionChip(affection: a),
                          ],
                        ),
                      ],
                      if (p.compat case final score?) ...[
                        const SizedBox(height: AppSpace.md),
                        CompatRow(score: score),
                      ],
                      const SizedBox(height: AppSpace.xl),
                      FilledButton.tonalIcon(
                        onPressed: _close,
                        icon: const Icon(Icons.close),
                        label: const Text('닫기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 이번 회차 호감 한 칸. 홈 사람들 줄과 같은 `'♥N'` 표기를 쓴다(§4.1 홈 사람들).
class _AffectionChip extends StatelessWidget {
  final int affection;
  const _AffectionChip({required this.affection});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Semantics(
      label: '호감 $affection',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xxs,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: AppRadius.rPill,
          border: Border.all(
            color: scheme.outlineVariant,
            width: AppBorderWidth.hairline,
          ),
        ),
        child: Text(
          keepAll('♥$affection'),
          style: context.tokens.numericSmall.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
