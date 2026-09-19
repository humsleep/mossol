/// 사진 메시지 카드 — "누군가 찍어 보낸 인화 사진" (docs/DESIGN_SYSTEM.md §3.2).
///
/// 실제 이미지는 없다. 폴라로이드 테두리 + 아이콘 종류별 장면(그라데이션·빛 번짐·지평선)
/// + 손글씨처럼 조판한 캡션으로 "사진" 을 흉내 낸다. 아이콘은 주인공이 아니라 구석의 힌트다.
///
/// 색은 전부 design_system.dart(AppPalette · 캐릭터 강조색 · 토큰)에서 꺼낸다.
/// 노란색 계열은 쓰지 않는다(§5). 다크 모드에서는 장면을 어둡게 눌러 눈부심을 줄인다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/models.dart';
import 'design_system.dart';
import 'widgets.dart' show showAppDialog;

/// 사진 아이콘 이름(docs/MOMENTS_SPEC.md §1.3) → Material 아이콘. 14종.
const Map<String, IconData> photoIcons = {
  'cafe': Icons.local_cafe,
  'food': Icons.restaurant,
  'sky': Icons.wb_cloudy,
  'night': Icons.nightlight_round,
  'sea': Icons.waves,
  'selfie': Icons.face,
  'pet': Icons.pets,
  'book': Icons.menu_book,
  'gym': Icons.fitness_center,
  'game': Icons.sports_esports,
  'music': Icons.music_note,
  'flower': Icons.local_florist,
  'street': Icons.location_city,
  'ticket': Icons.confirmation_number,
};

/// 모르는 이름이면 기본 사진 아이콘.
IconData photoIconFor(String name) => photoIcons[name] ?? Icons.photo;

/// 사진의 결정론적 기울기(도). -1.5 ~ +1.5, 0.1 단위. 같은 사진은 늘 같은 각도.
///
/// `String.hashCode` 는 실행마다 같다는 보장이 없어 FNV-1a 로 직접 섞는다.
double photoTiltDegrees(Photo photo) {
  var h = 0x811c9dc5;
  for (final c in '${photo.icon}|${photo.caption}'.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return (h % 31) / 10 - 1.5;
}

/// 사진 메시지 카드. 폴라로이드 한 장.
///
/// - 폭: [width] 가 없으면 화면 60%, 최대 [maxWidth](220).
/// - 테두리: 라이트 흰 종이(paperBright) + 1px bubbleBorder + shadowCard 한 겹,
///   다크 따뜻한 회색(nightInverse) + 1px, 그림자 없음(§1.9).
/// - 사진 창 4:3, 테두리 sm, 아래 여백은 캡션을 담는 넓은 띠.
/// - 캡션: bodyMedium 기울임 + 넓은 자간 + 강조색을 섞은 잉크색, 2줄까지. 대비 4.5:1 이상.
/// - 탭하면 크게 보기 다이얼로그(닫기 버튼 포함).
/// - 스크린리더: 카드 전체가 이미지 하나 — "사진: {caption}", 힌트 "크게 보기".
class PhotoBubble extends StatelessWidget {
  final Photo photo;

  /// 장면 색의 바탕. null 이면 tokens.neutralAccent.
  final CharacterAccent? accent;

  /// 카드 폭. null 이면 화면 폭의 60%, 최대 [maxWidth].
  final double? width;

  const PhotoBubble({super.key, required this.photo, this.accent, this.width});

  static const maxWidth = 220.0;

  @override
  Widget build(BuildContext context) {
    final a = accent ?? context.tokens.neutralAccent;
    final w =
        width ?? math.min(MediaQuery.sizeOf(context).width * 0.6, maxWidth);
    final caption = photo.caption.trim();

    void open() => showAppDialog<void>(
      context,
      builder: (_) => _PhotoViewer(photo: photo, accent: a),
    );

    return Semantics(
      container: true,
      image: true,
      button: true,
      label: caption.isEmpty ? '사진' : '사진: $caption',
      hint: '크게 보기',
      onTap: open,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: open,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            // 기울어진 모서리와 그림자가 옆 줄에 닿지 않을 만큼.
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Transform.rotate(
              angle: photoTiltDegrees(photo) * math.pi / 180,
              child: PolaroidFrame(photo: photo, accent: a, width: w),
            ),
          ),
        ),
      ),
    );
  }
}

/// 폴라로이드 한 장(기울기·탭·시맨틱 없음). 말풍선과 크게 보기가 함께 쓴다.
class PolaroidFrame extends StatelessWidget {
  final Photo photo;
  final CharacterAccent accent;
  final double width;

  /// 크게 보기에서는 캡션을 줄이지 않는다.
  final bool fullCaption;

  const PolaroidFrame({
    super.key,
    required this.photo,
    required this.accent,
    required this.width,
    this.fullCaption = false,
  });

  /// 테두리(인화지) 색. 라이트 흰 종이, 다크 따뜻한 회색.
  static Color paperOf(BuildContext context) =>
      context.isDark ? AppPalette.nightInverse : AppPalette.paperBright;

  /// 캡션 잉크색. 기본 글자색에 캐릭터 강조색을 섞어 "펜으로 쓴" 느낌을 낸다.
  /// 라이트: inkText 쪽으로 55% 이상 → 흰 종이 위 대비 7:1 안팎.
  /// 다크: nightText 쪽으로 60% → nightInverse 위 대비 7:1 안팎.
  static Color inkOf(BuildContext context, CharacterAccent a) => context.isDark
      ? Color.lerp(AppPalette.nightText, a.base, 0.4)!
      : Color.lerp(AppPalette.inkText, a.base, 0.45)!;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final caption = photo.caption.trim();
    final big = width >= 280; // 크게 보기(태블릿·큰 화면) 여백

    return Container(
      width: width,
      padding: EdgeInsets.fromLTRB(
        big ? AppSpace.md : AppSpace.sm,
        big ? AppSpace.md : AppSpace.sm,
        big ? AppSpace.md : AppSpace.sm,
        0,
      ),
      decoration: BoxDecoration(
        color: paperOf(context),
        borderRadius: AppRadius.rXs,
        border: Border.all(
          color: context.tokens.bubbleBorder,
          width: AppBorderWidth.hairline,
        ),
        boxShadow: dark ? null : context.tokens.shadowCard,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: PhotoScene(icon: photo.icon, accent: accent, dark: dark),
          ),
          // 폴라로이드의 넓은 아래 여백. 캡션이 없어도 여백은 남긴다.
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: big ? AppSpace.huge + AppSpace.sm : AppSpace.huge,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.xs,
                AppSpace.sm,
                AppSpace.xs,
                big ? AppSpace.lg : AppSpace.md,
              ),
              child: caption.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      caption,
                      maxLines: fullCaption ? null : 2,
                      overflow: fullCaption ? null : TextOverflow.ellipsis,
                      style:
                          (big
                                  ? context.text.bodyLarge
                                  : context.text.bodyMedium)
                              ?.copyWith(
                                color: inkOf(context, accent),
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.4,
                                height: 1.35,
                              ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 사진 창. 장면 그림 + 구석의 작은 아이콘 힌트.
class PhotoScene extends StatelessWidget {
  final String icon;
  final CharacterAccent accent;
  final bool dark;

  const PhotoScene({
    super.key,
    required this.icon,
    required this.accent,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScenePainter(icon, accent, dark: dark),
      child: Align(
        alignment: AlignmentDirectional.bottomEnd,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppPalette.inkText.withValues(alpha: 0.28),
              borderRadius: AppRadius.rPill,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xs),
              child: Icon(
                photoIconFor(icon),
                size: AppSpace.md + 2,
                color: AppPalette.paperBright.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 장면
// ---------------------------------------------------------------------------

/// 빛 번짐 원 하나. 위치·반지름은 사진 창에 대한 비율.
@immutable
class SceneGlow {
  final Offset at;
  final double radius;
  final Color color;
  final double alpha;
  const SceneGlow(this.at, this.radius, this.color, [this.alpha = 0.7]);
}

/// 장면 한 벌: 바탕 그라데이션 + (선택) 아래 띠(지평선·탁자·바닥) + 빛 번짐.
@immutable
class PhotoSceneSpec {
  final List<Color> colors;
  final Alignment begin;
  final Alignment end;

  /// 아래 띠가 시작하는 높이 비율(0~1). null 이면 띠 없음.
  final double? bandTop;
  final List<Color> band;
  final List<SceneGlow> glows;

  /// 거리 실루엣(건물 윤곽)을 띠 위에 세울지.
  final bool skyline;

  const PhotoSceneSpec({
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.bandTop,
    this.band = const [],
    this.glows = const [],
    this.skyline = false,
  });
}

/// 다크 테마의 강조색(base 옅음 · container 짙음)을 사진용 라이트 조합으로 되돌린다.
///
/// 사진은 테마와 상관없이 "찍힌 색" 이어야 한다. 다크 강조색을 그대로 쓰면 container 가
/// 짙어서 하늘·접시 같은 밝은 자리가 탁해진다. 대신 장면 전체를 [_ScenePainter] 가 눌러 준다.
CharacterAccent photoAccentOf(CharacterAccent dark) => CharacterAccent(
  base: Color.lerp(dark.base, dark.container, 0.45)!,
  container: Color.lerp(dark.base, AppPalette.paperBright, 0.6)!,
  onContainer: dark.container,
);

/// 아이콘 이름 → 장면. 강조색이 늘 한 자리는 차지해 캐릭터 색이 남는다.
PhotoSceneSpec sceneFor(String icon, CharacterAccent a) {
  const white = AppPalette.paperBright;
  final deep = Color.lerp(a.container, a.base, 0.55)!;
  switch (icon) {
    case 'cafe': // 창가 오후. 따뜻한 복숭아빛 + 아래 나무 탁자 + 창 빛.
      return PhotoSceneSpec(
        colors: [AppPalette.warningBgLight, a.container],
        bandTop: 0.7,
        band: [
          Color.lerp(AppPalette.jiwooLight, AppPalette.warningBgLight, 0.45)!,
          AppPalette.jiwooLight,
        ],
        glows: const [
          SceneGlow(Offset(0.2, 0.22), 0.42, white, 0.85),
          SceneGlow(Offset(0.78, 0.5), 0.14, AppPalette.paper050, 0.6),
        ],
      );
    case 'food': // 위에서 내려다본 접시.
      return PhotoSceneSpec(
        colors: [AppPalette.rose100, a.container, AppPalette.warningBgLight],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        glows: [
          const SceneGlow(Offset(0.5, 0.52), 0.34, white, 0.95),
          SceneGlow(const Offset(0.5, 0.52), 0.16, deep, 0.35),
        ],
      );
    case 'sky': // 파란 하늘 → 강조색 노을기, 오른쪽 위 해 번짐, 구름 두 덩이.
      return PhotoSceneSpec(
        colors: [AppPalette.infoLight, AppPalette.infoBgLight, a.container],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        glows: const [
          SceneGlow(Offset(0.8, 0.18), 0.3, white, 0.9),
          SceneGlow(Offset(0.3, 0.6), 0.2, white, 0.55),
          SceneGlow(Offset(0.5, 0.66), 0.16, white, 0.45),
        ],
      );
    case 'night': // 밤하늘 + 달 + 아래 불빛 보케.
      return PhotoSceneSpec(
        colors: [AppPalette.night050, AppPalette.violet900, a.base],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        glows: const [
          SceneGlow(Offset(0.76, 0.2), 0.1, AppPalette.paper050, 0.95),
          SceneGlow(Offset(0.2, 0.84), 0.08, AppPalette.rose300, 0.7),
          SceneGlow(Offset(0.42, 0.9), 0.06, AppPalette.infoDark, 0.7),
          SceneGlow(Offset(0.64, 0.82), 0.07, AppPalette.rose200, 0.6),
        ],
      );
    case 'sea': // 하늘 · 수평선 · 청록 바다, 수면 반짝임.
      return PhotoSceneSpec(
        colors: [AppPalette.infoBgLight, a.container],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        bandTop: 0.52,
        band: [AppPalette.teal600, AppPalette.teal900],
        glows: const [
          SceneGlow(Offset(0.3, 0.3), 0.26, white, 0.8),
          SceneGlow(Offset(0.62, 0.66), 0.12, AppPalette.teal100, 0.55),
        ],
      );
    case 'selfie': // 얼굴 자리에 부드러운 밝은 원, 가장자리는 강조색 비네팅.
      return PhotoSceneSpec(
        colors: [a.container, deep],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        glows: [
          const SceneGlow(Offset(0.5, 0.46), 0.36, AppPalette.paper050, 0.9),
          SceneGlow(const Offset(0.18, 0.18), 0.18, a.base, 0.25),
        ],
      );
    case 'pet': // 따뜻한 바닥 + 둥근 털뭉치.
      return PhotoSceneSpec(
        colors: [a.container, AppPalette.paper200],
        bandTop: 0.7,
        band: [AppPalette.paperDim, AppPalette.inkOutlineSoft],
        glows: const [
          SceneGlow(Offset(0.5, 0.62), 0.3, AppPalette.warningBgLight, 0.9),
          SceneGlow(Offset(0.82, 0.2), 0.2, white, 0.7),
        ],
      );
    case 'book': // 종이빛 + 오른쪽 위 스탠드 불빛 + 아래 책상.
      return PhotoSceneSpec(
        colors: [AppPalette.paper100, a.container],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        bandTop: 0.74,
        band: [deep, a.base],
        glows: const [
          SceneGlow(Offset(0.82, 0.14), 0.4, AppPalette.warningBgLight, 0.85),
          SceneGlow(Offset(0.36, 0.56), 0.24, white, 0.7),
        ],
      );
    case 'gym': // 차가운 회청 + 바닥 매트 + 천장 조명.
      return PhotoSceneSpec(
        colors: [AppPalette.doyunDark, a.container],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        bandTop: 0.72,
        band: [AppPalette.doyunLight, AppPalette.night300],
        glows: const [
          SceneGlow(Offset(0.3, 0.08), 0.22, white, 0.8),
          SceneGlow(Offset(0.72, 0.08), 0.22, white, 0.8),
        ],
      );
    case 'game': // 어두운 방 + 모니터 빛.
      return PhotoSceneSpec(
        colors: [AppPalette.night200, AppPalette.violet900, a.base],
        glows: const [
          SceneGlow(Offset(0.5, 0.42), 0.4, AppPalette.infoDark, 0.6),
          SceneGlow(Offset(0.5, 0.42), 0.18, AppPalette.teal300, 0.55),
        ],
      );
    case 'music': // 공연장 조명 보케.
      return PhotoSceneSpec(
        colors: [AppPalette.violet900, a.base, AppPalette.rose600],
        glows: const [
          SceneGlow(Offset(0.22, 0.3), 0.16, AppPalette.rose200, 0.75),
          SceneGlow(Offset(0.56, 0.2), 0.12, AppPalette.violet100, 0.7),
          SceneGlow(Offset(0.8, 0.44), 0.18, AppPalette.rose300, 0.6),
          SceneGlow(Offset(0.4, 0.7), 0.1, AppPalette.paper050, 0.5),
        ],
      );
    case 'flower': // 연두 잎 바탕 + 분홍 꽃송이 번짐.
      return PhotoSceneSpec(
        colors: [AppPalette.successBgLight, a.container],
        glows: const [
          SceneGlow(Offset(0.34, 0.4), 0.24, AppPalette.rose200, 0.9),
          SceneGlow(Offset(0.66, 0.58), 0.2, AppPalette.rose100, 0.9),
          SceneGlow(Offset(0.52, 0.3), 0.1, white, 0.8),
        ],
      );
    case 'street': // 하늘 + 건물 윤곽 + 가로등.
      return PhotoSceneSpec(
        colors: [AppPalette.infoBgLight, a.container],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        bandTop: 0.82,
        band: [AppPalette.inkOutline, AppPalette.inkTextSoft],
        skyline: true,
        glows: const [
          SceneGlow(Offset(0.2, 0.2), 0.24, white, 0.8),
          SceneGlow(Offset(0.86, 0.6), 0.06, AppPalette.rose100, 0.9),
        ],
      );
    case 'ticket': // 무대 위 스포트라이트.
      return PhotoSceneSpec(
        colors: [AppPalette.night100, a.base],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        bandTop: 0.78,
        band: [AppPalette.rose700, AppPalette.rose900],
        glows: const [
          SceneGlow(Offset(0.5, 0.0), 0.5, AppPalette.paper050, 0.55),
          SceneGlow(Offset(0.5, 0.74), 0.2, AppPalette.rose200, 0.6),
        ],
      );
    default: // 모르는 사진: 강조색 하늘 · 먼 언덕 · 해 번짐. 평범한 풍경 한 장.
      return PhotoSceneSpec(
        colors: [AppPalette.paper050, a.container],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        bandTop: 0.66,
        band: [deep, a.base],
        glows: [
          const SceneGlow(Offset(0.72, 0.3), 0.26, white, 0.9),
          SceneGlow(const Offset(0.24, 0.72), 0.2, a.container, 0.5),
        ],
      );
  }
}

class _ScenePainter extends CustomPainter {
  final String icon;
  final CharacterAccent accent;
  final bool dark;
  final PhotoSceneSpec scene;

  _ScenePainter(this.icon, this.accent, {required this.dark})
    : scene = sceneFor(icon, dark ? photoAccentOf(accent) : accent);

  /// 다크 모드에서는 인화 사진을 조금 눌러 눈부심을 줄인다.
  Color _c(Color c) => dark ? Color.lerp(c, AppPalette.night, 0.28)! : c;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: scene.begin,
          end: scene.end,
          colors: scene.colors.map(_c).toList(),
        ).createShader(rect),
    );

    final bandTop = scene.bandTop;
    if (bandTop != null && scene.band.isNotEmpty) {
      final top = size.height * bandTop;
      if (scene.skyline) {
        // 들쑥날쑥한 건물 윤곽. 고정 비율이라 늘 같은 거리.
        const blocks = [
          (0.0, 0.14, 0.34),
          (0.14, 0.3, 0.2),
          (0.3, 0.44, 0.44),
          (0.44, 0.62, 0.26),
          (0.62, 0.74, 0.5),
          (0.74, 1.0, 0.3),
        ];
        final bp = Paint()
          ..color = _c(Color.lerp(scene.band.first, scene.colors.last, 0.35)!)
              .withValues(alpha: 0.85);
        for (final (l, r, h) in blocks) {
          canvas.drawRect(
            Rect.fromLTRB(
              size.width * l,
              top - size.height * h,
              size.width * r,
              top,
            ),
            bp,
          );
        }
      }
      final band = Rect.fromLTRB(0, top, size.width, size.height);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: scene.band.map(_c).toList(),
          ).createShader(band),
      );
    }

    // 빛 번짐: 가운데가 밝고 바깥으로 사라지는 원.
    final unit = math.max(size.width, size.height);
    for (final g in scene.glows) {
      final center = Offset(size.width * g.at.dx, size.height * g.at.dy);
      final r = unit * g.radius;
      final color = _c(g.color).withValues(alpha: g.alpha * (dark ? 0.8 : 1));
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    // 렌즈 비네팅: 모서리를 아주 살짝 어둡게.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [
            AppPalette.night.withValues(alpha: 0),
            AppPalette.night.withValues(alpha: dark ? 0.28 : 0.16),
          ],
          stops: const [0.6, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.icon != icon ||
      old.dark != dark ||
      old.accent.base != accent.base ||
      old.accent.container != accent.container;
}

// ---------------------------------------------------------------------------
// 크게 보기
// ---------------------------------------------------------------------------

class _PhotoViewer extends StatelessWidget {
  final Photo photo;
  final CharacterAccent accent;

  const _PhotoViewer({required this.photo, required this.accent});

  @override
  Widget build(BuildContext context) {
    final caption = photo.caption.trim();
    final w = math.min(
      MediaQuery.sizeOf(context).width - AppSpace.huge * 2,
      340.0,
    );
    // 기본 Dialog 는 테마의 모서리·테두리를 그려 인화지 뒤에 빈 판이 하나 더 보인다.
    // 사진만 띄우도록 투명 Material 위에 직접 놓는다. 스크림 탭으로도 닫힌다.
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  image: true,
                  label: caption.isEmpty ? '사진' : '사진: $caption',
                  child: ExcludeSemantics(
                    child: PolaroidFrame(
                      photo: photo,
                      accent: accent,
                      width: w,
                      fullCaption: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('닫기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
