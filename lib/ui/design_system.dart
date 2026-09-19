/// 모쏠 키우기 디자인 시스템.
///
/// 이 파일이 앱의 시각 언어를 혼자 정의한다. 화면 코드에는 색·간격·모서리·시간
/// 상수를 절대 쓰지 않고 여기서 꺼내 쓴다. 규격서는 docs/DESIGN_SYSTEM.md.
///
/// 꺼내 쓰는 법 (전부 한 줄):
///   final t = context.tokens;            // 의미색·캐릭터색·그림자·숫자 스타일
///   final scheme = context.scheme;       // Material 색 역할
///   final text = context.text;           // TextTheme
///   Duration d = AppMotion.base(context); // 모션 축소 설정이 반영된 지속시간
///
/// 색을 하드코딩하지 마라. `Colors.*` 와 `Color(0x...)` 는 이 파일에서만 등장한다.
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// 1. 원색 팔레트
// ---------------------------------------------------------------------------

/// 팔레트 원색. 화면에서 직접 쓰지 않는다. ColorScheme 과 AppTokens 를 거친다.
///
/// 방향: 브랜드 로즈(0xFFC2295A)를 중심으로, 라이트는 따뜻한 종이 흰색,
/// 다크는 자수정빛 잉크. 노란색 계열은 팔레트 전체에서 배제한다
/// (경고 상태색 하나만 예외이며 상태 표시에만 쓴다).
abstract final class AppPalette {
  // 브랜드 로즈
  static const rose600 = Color(0xFFC2295A); // 브랜드 기준색
  static const rose700 = Color(0xFF9E1B47);
  static const rose500 = Color(0xFFDA4A75);
  static const rose300 = Color(0xFFFF8CA8);
  static const rose200 = Color(0xFFFFB1C6);
  static const rose100 = Color(0xFFFFD9E2);
  static const rose900 = Color(0xFF47041F);
  static const roseDeep = Color(0xFF8C0F3A); // 다크 모드 내 말풍선
  static const roseInk = Color(0xFF54001D);

  // 보조: 자수정
  static const violet600 = Color(0xFF6B4BA8);
  static const violet300 = Color(0xFFC9B0FF);
  static const violet100 = Color(0xFFE9DDFF);
  static const violet800 = Color(0xFF52348C);
  static const violet900 = Color(0xFF26124F);

  // 3차: 청록
  static const teal600 = Color(0xFF0F6F73);
  static const teal300 = Color(0xFF6FD8DC);
  static const teal100 = Color(0xFFBEEFEA);
  static const teal800 = Color(0xFF0C5450);
  static const teal900 = Color(0xFF00302C);

  // 중립 (라이트: 따뜻한 종이 / 다크: 자수정 잉크)
  static const paper = Color(0xFFFFFAF9);
  static const paperBright = Color(0xFFFFFFFF);
  static const paperDim = Color(0xFFEFE2E4);
  static const paper050 = Color(0xFFFFF4F4);
  static const paper100 = Color(0xFFFAEDEE);
  static const paper200 = Color(0xFFF4E7E8);
  static const paper300 = Color(0xFFEEE0E2);
  static const inkText = Color(0xFF1C1216);
  static const inkTextSoft = Color(0xFF5B4A4F);
  static const inkOutline = Color(0xFF8C7A7F);
  static const inkOutlineSoft = Color(0xFFE0CFD3);

  static const night = Color(0xFF161014);
  static const nightDim = Color(0xFF120C10);
  static const nightBright = Color(0xFF3B2F34);
  static const night050 = Color(0xFF100A0E);
  static const night100 = Color(0xFF1E1519);
  static const night200 = Color(0xFF241A1E);
  static const night300 = Color(0xFF2F2429);
  static const night400 = Color(0xFF3A2E33);
  static const nightText = Color(0xFFF2E5E7);
  static const nightTextSoft = Color(0xFFD4BFC5);
  static const nightOutline = Color(0xFF9C868C);
  static const nightOutlineSoft = Color(0xFF4E3F44);
  static const nightBubble = Color(0xFF262027);
  static const nightInverse = Color(0xFF382D30);

  // 의미색
  static const successLight = Color(0xFF2F7A4D);
  static const successDark = Color(0xFF79D29A);
  static const successBgLight = Color(0xFFD5F0DF);
  static const successBgDark = Color(0xFF13462B);
  static const successOnBgLight = Color(0xFF0C3A21);
  static const successOnBgDark = Color(0xFFD5F0DF);

  static const warningLight = Color(0xFFA85A00);
  static const warningDark = Color(0xFFFFBE7A);
  static const warningBgLight = Color(0xFFFFE2C4);
  static const warningBgDark = Color(0xFF5A3100);
  static const warningOnBgLight = Color(0xFF3D1F00);
  static const warningOnBgDark = Color(0xFFFFE2C4);

  static const dangerLight = Color(0xFFB3261E);
  static const dangerDark = Color(0xFFFFB4AB);
  static const dangerBgLight = Color(0xFFFFDAD5);
  static const dangerBgDark = Color(0xFF93000A);
  static const dangerOnBgLight = Color(0xFF410E0A);
  static const dangerOnBgDark = Color(0xFFFFDAD5);

  static const infoLight = Color(0xFF3A5BC7);
  static const infoDark = Color(0xFFA8BEFF);
  static const infoBgLight = Color(0xFFDDE4FF);
  static const infoBgDark = Color(0xFF223C96);
  static const infoOnBgLight = Color(0xFF0E1E5C);
  static const infoOnBgDark = Color(0xFFDDE4FF);

  // 캐릭터 강조색 (라이트 / 다크)
  static const seoyeonLight = violet600;
  static const seoyeonDark = violet300;
  static const haneulLight = teal600;
  static const haneulDark = teal300;
  static const jiwooLight = Color(0xFFB5442A);
  static const jiwooDark = Color(0xFFFFA88F);
  static const minjaeLight = Color(0xFF3A5BC7);
  static const minjaeDark = Color(0xFFA8BEFF);
  static const yeeunLight = Color(0xFF3F6B3A);
  static const yeeunDark = Color(0xFFA2D39A);
  static const doyunLight = Color(0xFF4A6572);
  static const doyunDark = Color(0xFF9FBCCB);

  static const heartLight = rose600;
  static const heartDark = rose300;
}

// ---------------------------------------------------------------------------
// 2. 간격 · 모서리 · 테두리
// ---------------------------------------------------------------------------

/// 4 배수 간격 체계. 여기 없는 숫자는 쓰지 않는다.
abstract final class AppSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  /// 화면 좌우 기본 여백.
  static const double screenX = 20;

  /// 화면 위아래 기본 여백.
  static const double screenY = 16;

  /// 카드·패널 안쪽 여백.
  static const double cardPad = 16;

  /// 같은 묶음 안 요소 사이.
  static const double gap = 12;

  /// 리스트 항목 사이.
  static const double listGap = 8;

  /// 서로 다른 묶음(섹션) 사이.
  static const double sectionGap = 24;

  /// 터치 대상 최소 한 변. 접근성 기준선이다.
  static const double minTouch = 44;
}

/// 자주 쓰는 EdgeInsets 묶음.
abstract final class AppInsets {
  static const screen = EdgeInsets.symmetric(
    horizontal: AppSpace.screenX,
    vertical: AppSpace.screenY,
  );
  static const screenX = EdgeInsets.symmetric(horizontal: AppSpace.screenX);
  static const card = EdgeInsets.all(AppSpace.cardPad);
  static const cardTight = EdgeInsets.symmetric(
    horizontal: AppSpace.cardPad,
    vertical: AppSpace.md,
  );

  /// 하단 고정 패널(선택지·결과). SafeArea 는 패널이 직접 감싼다.
  static const panel = EdgeInsets.fromLTRB(
    AppSpace.lg,
    AppSpace.md,
    AppSpace.lg,
    AppSpace.lg,
  );
  static const chip = EdgeInsets.symmetric(
    horizontal: AppSpace.md,
    vertical: AppSpace.sm,
  );

  /// 말풍선 안쪽.
  static const bubble = EdgeInsets.symmetric(
    horizontal: AppSpace.md,
    vertical: AppSpace.sm + 2,
  );
}

/// 모서리 단계.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const rXs = BorderRadius.all(Radius.circular(xs));
  static const rSm = BorderRadius.all(Radius.circular(sm));
  static const rMd = BorderRadius.all(Radius.circular(md));
  static const rLg = BorderRadius.all(Radius.circular(lg));
  static const rXl = BorderRadius.all(Radius.circular(xl));
  static const rPill = BorderRadius.all(Radius.circular(pill));

  /// 바텀시트 위쪽만 둥글게.
  static const sheet = BorderRadius.vertical(top: Radius.circular(xl));

  /// 말풍선. [mine] 이면 오른쪽 아래 꼬리가 각진다.
  static BorderRadius bubble({required bool mine, bool tail = true}) {
    const r = Radius.circular(18);
    const t = Radius.circular(AppRadius.xs);
    return BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: mine || !tail ? r : t,
      bottomRight: mine && tail ? t : r,
    );
  }
}

/// 테두리 굵기 단계. 색은 토큰에서 가져온다.
abstract final class AppBorderWidth {
  /// 카드·칩의 기본 실선.
  static const double hairline = 1;

  /// 선택·추천 상태.
  static const double emphasis = 2;

  /// 포커스 링.
  static const double focus = 3;
}

// ---------------------------------------------------------------------------
// 3. 모션
// ---------------------------------------------------------------------------

/// 지속시간과 커브. 시스템 "동작 줄이기" 를 켠 사용자에게는 0ms 를 준다.
///
/// 화면에서는 반드시 `AppMotion.base(context)` 처럼 context 버전을 쓴다.
/// 상수 버전(`AppMotion.dBase`)은 context 가 없는 곳에서만.
abstract final class AppMotion {
  static const Duration dInstant = Duration(milliseconds: 90);
  static const Duration dFast = Duration(milliseconds: 140);
  static const Duration dBase = Duration(milliseconds: 220);
  static const Duration dSlow = Duration(milliseconds: 320);
  static const Duration dSheet = Duration(milliseconds: 380);

  /// 기본 진입·퇴장.
  static const Curve standard = Curves.easeOutCubic;

  /// 강조(배지·콤보 팝).
  static const Curve emphasized = Curves.easeOutBack;

  /// 값이 오르내리는 게이지.
  static const Curve gauge = Curves.easeInOutCubic;

  /// 시스템이 애니메이션 축소를 요청했는지.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration _scaled(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;

  static Duration instant(BuildContext context) => _scaled(context, dInstant);
  static Duration fast(BuildContext context) => _scaled(context, dFast);
  static Duration base(BuildContext context) => _scaled(context, dBase);
  static Duration slow(BuildContext context) => _scaled(context, dSlow);
  static Duration sheet(BuildContext context) => _scaled(context, dSheet);

  /// 반복 애니메이션(룰렛 회전, 스윕바)은 축소 설정에서 멈춰야 한다.
  /// 게임 판정에 필요한 연출은 멈추지 말고 커브만 단순하게 바꾼다.
  static Curve curve(BuildContext context, [Curve c = standard]) =>
      reduced(context) ? Curves.linear : c;
}

// ---------------------------------------------------------------------------
// 4. 타이포그래피
// ---------------------------------------------------------------------------

/// 서체 설정. Pretendard 를 번들하고, 없으면 한글 시스템 서체로 떨어진다.
abstract final class AppFonts {
  static const String family = 'Pretendard';

  /// 번들이 빠졌거나 글리프가 없을 때의 한글 대체 서체.
  static const List<String> fallback = <String>[
    'Apple SD Gothic Neo',
    'AppleSDGothicNeo-Regular',
    'Noto Sans KR',
    'Malgun Gothic',
    'sans-serif',
  ];
}

/// 역할별 타이포. 한글은 라틴보다 자간을 좁히고 행간을 넓혀야 읽힌다.
///
/// - 큰 글자일수록 자간을 더 좁힌다 (-0.8 ~ 0).
/// - 본문 행간은 1.6. 대사·에필로그처럼 여러 줄 읽는 곳은 1.65.
/// - 숫자가 줄마다 흔들리면 안 되는 곳(스탯, 타이머, 정산, 확률)은
///   [tabular] 을 거친 스타일을 쓴다.
abstract final class AppTypography {
  static const List<FontFeature> _tab = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// 표·타이머·스탯처럼 자리수가 고정돼야 하는 숫자.
  static TextStyle tabular(TextStyle base) =>
      base.copyWith(fontFeatures: _tab);

  static TextTheme textTheme(ColorScheme scheme) {
    final onSurface = scheme.onSurface;
    final soft = scheme.onSurfaceVariant;
    return TextTheme(
      // 디스플레이: 홈 타이틀, 엔딩 등급. 화면에 한 개만.
      displayLarge: TextStyle(
        fontSize: 40,
        height: 1.15,
        letterSpacing: -1.0,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 34,
        height: 1.18,
        letterSpacing: -0.8,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 28,
        height: 1.22,
        letterSpacing: -0.6,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      // 헤드라인: 엔딩 이름, 미니게임 결과.
      headlineLarge: TextStyle(
        fontSize: 26,
        height: 1.26,
        letterSpacing: -0.5,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 23,
        height: 1.3,
        letterSpacing: -0.4,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        height: 1.32,
        letterSpacing: -0.3,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      // 타이틀: AppBar, 카드 머리, 섹션 헤더.
      titleLarge: TextStyle(
        fontSize: 18,
        height: 1.34,
        letterSpacing: -0.3,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.4,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.42,
        letterSpacing: -0.1,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      // 본문: 대사, 설명, 에필로그.
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.6,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.5,
        height: 1.6,
        letterSpacing: -0.15,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        height: 1.5,
        letterSpacing: -0.1,
        fontWeight: FontWeight.w400,
        color: soft,
      ),
      // 라벨: 버튼, 칩, 배지, 보조 수치.
      labelLarge: TextStyle(
        fontSize: 15,
        height: 1.3,
        letterSpacing: -0.1,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        height: 1.3,
        letterSpacing: 0,
        fontWeight: FontWeight.w600,
        color: soft,
      ),
      labelSmall: TextStyle(
        fontSize: 11.5,
        height: 1.28,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w600,
        color: soft,
      ),
    ).apply(fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback);
  }
}

// ---------------------------------------------------------------------------
// 5. 토큰 (ThemeData 확장)
// ---------------------------------------------------------------------------

/// 캐릭터 강조색 한 벌.
@immutable
class CharacterAccent {
  /// 선·아이콘·이름에 쓰는 진한 쪽.
  final Color base;

  /// 칩·배경에 쓰는 옅은 쪽.
  final Color container;

  /// [container] 위에 올리는 글자색.
  final Color onContainer;

  const CharacterAccent({
    required this.base,
    required this.container,
    required this.onContainer,
  });

  static CharacterAccent lerp(CharacterAccent a, CharacterAccent b, double t) =>
      CharacterAccent(
        base: Color.lerp(a.base, b.base, t)!,
        container: Color.lerp(a.container, b.container, t)!,
        onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
      );
}

/// ColorScheme 이 담지 못하는 토큰. `context.tokens` 로 꺼낸다.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  // 의미색 — 반드시 아이콘이나 문구와 함께 쓴다. 색만으로 뜻을 전하지 않는다.
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  // 채팅
  final Color chatBackground;
  final Color bubbleMine;
  final Color onBubbleMine;
  final Color bubbleTheirs;
  final Color onBubbleTheirs;
  final Color bubbleBorder;
  final Color narration;
  final Color systemLine;

  // 게임 장치
  final Color heart;
  final Color heartEmpty;
  final Color comboIdle;
  final Color onComboIdle;
  final Color comboFire;
  final Color onComboFire;
  final Color lockedForeground;
  final Color gaugeTrack;

  /// 스탯 키(Stat.charm 등) → 막대·아이콘 색.
  final Map<String, Color> statColors;

  /// 캐릭터 id → 강조색. 없는 id 는 [accentFor] 가 기본값으로 메운다.
  final Map<String, CharacterAccent> characterAccents;

  /// 기본 강조색. 캐릭터가 없거나 모르는 id 일 때.
  final CharacterAccent neutralAccent;

  // 그림자 (다크 모드에서는 그림자 대신 테두리에 기댄다)
  final List<BoxShadow> shadowCard;
  final List<BoxShadow> shadowRaised;
  final List<BoxShadow> shadowSheet;

  // 숫자 스타일 — 표에서 자리수가 흔들리지 않는다.
  final TextStyle numericSmall;
  final TextStyle numericMedium;
  final TextStyle numericLarge;

  /// 말풍선 본문.
  final TextStyle bubbleText;

  /// 배지·칩 안의 짧은 라벨.
  final TextStyle badgeText;

  const AppTokens({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.chatBackground,
    required this.bubbleMine,
    required this.onBubbleMine,
    required this.bubbleTheirs,
    required this.onBubbleTheirs,
    required this.bubbleBorder,
    required this.narration,
    required this.systemLine,
    required this.heart,
    required this.heartEmpty,
    required this.comboIdle,
    required this.onComboIdle,
    required this.comboFire,
    required this.onComboFire,
    required this.lockedForeground,
    required this.gaugeTrack,
    required this.statColors,
    required this.characterAccents,
    required this.neutralAccent,
    required this.shadowCard,
    required this.shadowRaised,
    required this.shadowSheet,
    required this.numericSmall,
    required this.numericMedium,
    required this.numericLarge,
    required this.bubbleText,
    required this.badgeText,
  });

  /// 캐릭터 강조색. 모르는 id 나 null 이면 기본값.
  CharacterAccent accentFor(String? characterId) =>
      characterAccents[characterId] ?? neutralAccent;

  /// 스탯 막대 색. 모르는 키면 primary 대신 중립 강조색.
  Color statColor(String key) => statColors[key] ?? neutralAccent.base;

  /// 변화량의 색. [good] 이 false 면 위험색.
  /// 색만으로 전달하면 안 되므로 호출부에서 부호(+/-)나 아이콘을 함께 쓴다.
  Color deltaColor({required bool good}) => good ? success : danger;

  @override
  AppTokens copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? chatBackground,
    Color? bubbleMine,
    Color? onBubbleMine,
    Color? bubbleTheirs,
    Color? onBubbleTheirs,
    Color? bubbleBorder,
    Color? narration,
    Color? systemLine,
    Color? heart,
    Color? heartEmpty,
    Color? comboIdle,
    Color? onComboIdle,
    Color? comboFire,
    Color? onComboFire,
    Color? lockedForeground,
    Color? gaugeTrack,
    Map<String, Color>? statColors,
    Map<String, CharacterAccent>? characterAccents,
    CharacterAccent? neutralAccent,
    List<BoxShadow>? shadowCard,
    List<BoxShadow>? shadowRaised,
    List<BoxShadow>? shadowSheet,
    TextStyle? numericSmall,
    TextStyle? numericMedium,
    TextStyle? numericLarge,
    TextStyle? bubbleText,
    TextStyle? badgeText,
  }) {
    return AppTokens(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      chatBackground: chatBackground ?? this.chatBackground,
      bubbleMine: bubbleMine ?? this.bubbleMine,
      onBubbleMine: onBubbleMine ?? this.onBubbleMine,
      bubbleTheirs: bubbleTheirs ?? this.bubbleTheirs,
      onBubbleTheirs: onBubbleTheirs ?? this.onBubbleTheirs,
      bubbleBorder: bubbleBorder ?? this.bubbleBorder,
      narration: narration ?? this.narration,
      systemLine: systemLine ?? this.systemLine,
      heart: heart ?? this.heart,
      heartEmpty: heartEmpty ?? this.heartEmpty,
      comboIdle: comboIdle ?? this.comboIdle,
      onComboIdle: onComboIdle ?? this.onComboIdle,
      comboFire: comboFire ?? this.comboFire,
      onComboFire: onComboFire ?? this.onComboFire,
      lockedForeground: lockedForeground ?? this.lockedForeground,
      gaugeTrack: gaugeTrack ?? this.gaugeTrack,
      statColors: statColors ?? this.statColors,
      characterAccents: characterAccents ?? this.characterAccents,
      neutralAccent: neutralAccent ?? this.neutralAccent,
      shadowCard: shadowCard ?? this.shadowCard,
      shadowRaised: shadowRaised ?? this.shadowRaised,
      shadowSheet: shadowSheet ?? this.shadowSheet,
      numericSmall: numericSmall ?? this.numericSmall,
      numericMedium: numericMedium ?? this.numericMedium,
      numericLarge: numericLarge ?? this.numericLarge,
      bubbleText: bubbleText ?? this.bubbleText,
      badgeText: badgeText ?? this.badgeText,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      success: c(success, other.success),
      onSuccess: c(onSuccess, other.onSuccess),
      successContainer: c(successContainer, other.successContainer),
      onSuccessContainer: c(onSuccessContainer, other.onSuccessContainer),
      warning: c(warning, other.warning),
      onWarning: c(onWarning, other.onWarning),
      warningContainer: c(warningContainer, other.warningContainer),
      onWarningContainer: c(onWarningContainer, other.onWarningContainer),
      danger: c(danger, other.danger),
      onDanger: c(onDanger, other.onDanger),
      dangerContainer: c(dangerContainer, other.dangerContainer),
      onDangerContainer: c(onDangerContainer, other.onDangerContainer),
      info: c(info, other.info),
      onInfo: c(onInfo, other.onInfo),
      infoContainer: c(infoContainer, other.infoContainer),
      onInfoContainer: c(onInfoContainer, other.onInfoContainer),
      chatBackground: c(chatBackground, other.chatBackground),
      bubbleMine: c(bubbleMine, other.bubbleMine),
      onBubbleMine: c(onBubbleMine, other.onBubbleMine),
      bubbleTheirs: c(bubbleTheirs, other.bubbleTheirs),
      onBubbleTheirs: c(onBubbleTheirs, other.onBubbleTheirs),
      bubbleBorder: c(bubbleBorder, other.bubbleBorder),
      narration: c(narration, other.narration),
      systemLine: c(systemLine, other.systemLine),
      heart: c(heart, other.heart),
      heartEmpty: c(heartEmpty, other.heartEmpty),
      comboIdle: c(comboIdle, other.comboIdle),
      onComboIdle: c(onComboIdle, other.onComboIdle),
      comboFire: c(comboFire, other.comboFire),
      onComboFire: c(onComboFire, other.onComboFire),
      lockedForeground: c(lockedForeground, other.lockedForeground),
      gaugeTrack: c(gaugeTrack, other.gaugeTrack),
      statColors: {
        for (final e in statColors.entries)
          e.key: c(e.value, other.statColors[e.key] ?? e.value),
      },
      characterAccents: {
        for (final e in characterAccents.entries)
          e.key: CharacterAccent.lerp(
            e.value,
            other.characterAccents[e.key] ?? e.value,
            t,
          ),
      },
      neutralAccent: CharacterAccent.lerp(neutralAccent, other.neutralAccent, t),
      shadowCard: BoxShadow.lerpList(shadowCard, other.shadowCard, t)!,
      shadowRaised: BoxShadow.lerpList(shadowRaised, other.shadowRaised, t)!,
      shadowSheet: BoxShadow.lerpList(shadowSheet, other.shadowSheet, t)!,
      numericSmall: TextStyle.lerp(numericSmall, other.numericSmall, t)!,
      numericMedium: TextStyle.lerp(numericMedium, other.numericMedium, t)!,
      numericLarge: TextStyle.lerp(numericLarge, other.numericLarge, t)!,
      bubbleText: TextStyle.lerp(bubbleText, other.bubbleText, t)!,
      badgeText: TextStyle.lerp(badgeText, other.badgeText, t)!,
    );
  }

  /// 테마에 확장이 안 붙어 있을 때의 안전망(예: 자체 ThemeData 를 만드는 테스트).
  /// 화면 코드는 이걸 직접 부르지 말고 `context.tokens` 를 쓴다.
  static AppTokens fallback(Brightness brightness) =>
      brightness == Brightness.dark ? _darkTokens : _lightTokens;
}

/// 한 줄로 꺼내 쓰기 위한 확장.
extension AppThemeContext on BuildContext {
  /// 디자인 토큰. 테마에 확장이 없으면 밝기에 맞는 기본값으로 떨어진다.
  AppTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<AppTokens>() ?? AppTokens.fallback(theme.brightness);
  }

  ColorScheme get scheme => Theme.of(this).colorScheme;

  TextTheme get text => Theme.of(this).textTheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// 모달(시트·다이얼로그) 뒤 스크림. 시트 테마의 modalBarrierColor 와 같은 값.
  Color get scrimColor => scheme.scrim.withValues(alpha: isDark ? 0.62 : 0.48);
}

// ---------------------------------------------------------------------------
// 6. ColorScheme 두 벌
// ---------------------------------------------------------------------------

const ColorScheme _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppPalette.rose600,
  onPrimary: Colors.white,
  primaryContainer: AppPalette.rose100,
  onPrimaryContainer: AppPalette.rose900,
  secondary: AppPalette.violet600,
  onSecondary: Colors.white,
  secondaryContainer: AppPalette.violet100,
  onSecondaryContainer: AppPalette.violet900,
  tertiary: AppPalette.teal600,
  onTertiary: Colors.white,
  tertiaryContainer: AppPalette.teal100,
  onTertiaryContainer: AppPalette.teal900,
  error: AppPalette.dangerLight,
  onError: Colors.white,
  errorContainer: AppPalette.dangerBgLight,
  onErrorContainer: AppPalette.dangerOnBgLight,
  surface: AppPalette.paper,
  onSurface: AppPalette.inkText,
  surfaceDim: AppPalette.paperDim,
  surfaceBright: AppPalette.paperBright,
  surfaceContainerLowest: AppPalette.paperBright,
  surfaceContainerLow: AppPalette.paper050,
  surfaceContainer: AppPalette.paper100,
  surfaceContainerHigh: AppPalette.paper200,
  surfaceContainerHighest: AppPalette.paper300,
  onSurfaceVariant: AppPalette.inkTextSoft,
  outline: AppPalette.inkOutline,
  outlineVariant: AppPalette.inkOutlineSoft,
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: Color(0xFF362A2D),
  onInverseSurface: Color(0xFFFBEEEF),
  inversePrimary: AppPalette.rose200,
  surfaceTint: AppPalette.rose600,
);

const ColorScheme _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: AppPalette.rose300,
  onPrimary: AppPalette.roseInk,
  primaryContainer: AppPalette.roseDeep,
  onPrimaryContainer: AppPalette.rose100,
  secondary: AppPalette.violet300,
  onSecondary: Color(0xFF3A1D6E),
  secondaryContainer: AppPalette.violet800,
  onSecondaryContainer: AppPalette.violet100,
  tertiary: AppPalette.teal300,
  onTertiary: Color(0xFF003733),
  tertiaryContainer: AppPalette.teal800,
  onTertiaryContainer: AppPalette.teal100,
  error: AppPalette.dangerDark,
  onError: Color(0xFF690005),
  errorContainer: AppPalette.dangerBgDark,
  onErrorContainer: AppPalette.dangerOnBgDark,
  surface: AppPalette.night,
  onSurface: AppPalette.nightText,
  surfaceDim: AppPalette.nightDim,
  surfaceBright: AppPalette.nightBright,
  surfaceContainerLowest: AppPalette.night050,
  surfaceContainerLow: AppPalette.night100,
  surfaceContainer: AppPalette.night200,
  surfaceContainerHigh: AppPalette.night300,
  surfaceContainerHighest: AppPalette.night400,
  onSurfaceVariant: AppPalette.nightTextSoft,
  outline: AppPalette.nightOutline,
  outlineVariant: AppPalette.nightOutlineSoft,
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: AppPalette.nightText,
  onInverseSurface: AppPalette.nightInverse,
  inversePrimary: AppPalette.rose600,
  surfaceTint: AppPalette.rose300,
);

// ---------------------------------------------------------------------------
// 7. 토큰 두 벌
// ---------------------------------------------------------------------------

/// 스탯 키. engine/models.dart 의 Stat 과 같은 문자열을 쓴다.
/// 표현 계층이 엔진을 import 하지 않도록 여기서 문자열로만 둔다.
abstract final class _StatKey {
  static const charm = 'charm';
  static const talk = 'talk';
  static const esteem = 'esteem';
  static const sense = 'sense';
  static const money = 'money';
  static const stress = 'stress';
}

final AppTokens _lightTokens = AppTokens(
  success: AppPalette.successLight,
  onSuccess: Colors.white,
  successContainer: AppPalette.successBgLight,
  onSuccessContainer: AppPalette.successOnBgLight,
  warning: AppPalette.warningLight,
  onWarning: Colors.white,
  warningContainer: AppPalette.warningBgLight,
  onWarningContainer: AppPalette.warningOnBgLight,
  danger: AppPalette.dangerLight,
  onDanger: Colors.white,
  dangerContainer: AppPalette.dangerBgLight,
  onDangerContainer: AppPalette.dangerOnBgLight,
  info: AppPalette.infoLight,
  onInfo: Colors.white,
  infoContainer: AppPalette.infoBgLight,
  onInfoContainer: AppPalette.infoOnBgLight,
  chatBackground: AppPalette.paper050,
  bubbleMine: AppPalette.rose600,
  onBubbleMine: Colors.white,
  bubbleTheirs: AppPalette.paperBright,
  onBubbleTheirs: AppPalette.inkText,
  bubbleBorder: AppPalette.inkOutlineSoft,
  narration: AppPalette.inkTextSoft,
  systemLine: AppPalette.inkOutline,
  heart: AppPalette.heartLight,
  heartEmpty: AppPalette.inkOutlineSoft,
  comboIdle: AppPalette.paper200,
  onComboIdle: AppPalette.inkTextSoft,
  comboFire: AppPalette.rose600,
  onComboFire: Colors.white,
  lockedForeground: AppPalette.inkOutline,
  gaugeTrack: AppPalette.paper300,
  statColors: const {
    _StatKey.charm: AppPalette.rose600,
    _StatKey.talk: AppPalette.violet600,
    _StatKey.esteem: AppPalette.teal600,
    _StatKey.sense: AppPalette.infoLight,
    _StatKey.money: AppPalette.successLight,
    _StatKey.stress: AppPalette.dangerLight,
  },
  characterAccents: const {
    'seoyeon': CharacterAccent(
      base: AppPalette.seoyeonLight,
      container: AppPalette.violet100,
      onContainer: AppPalette.violet900,
    ),
    'haneul': CharacterAccent(
      base: AppPalette.haneulLight,
      container: AppPalette.teal100,
      onContainer: AppPalette.teal900,
    ),
    'jiwoo': CharacterAccent(
      base: AppPalette.jiwooLight,
      container: Color(0xFFFFDCD2),
      onContainer: Color(0xFF44120A),
    ),
    'minjae': CharacterAccent(
      base: AppPalette.minjaeLight,
      container: AppPalette.infoBgLight,
      onContainer: AppPalette.infoOnBgLight,
    ),
    'yeeun': CharacterAccent(
      base: AppPalette.yeeunLight,
      container: Color(0xFFD9EED4),
      onContainer: Color(0xFF12290F),
    ),
    'doyun': CharacterAccent(
      base: AppPalette.doyunLight,
      container: Color(0xFFD8E4EA),
      onContainer: Color(0xFF16242B),
    ),
    'jeongwoo': CharacterAccent(
      base: Color(0xFF7F553C),
      container: Color(0xFFFFE2D2),
      onContainer: Color(0xFF411F06),
    ),
    'daeun': CharacterAccent(
      base: Color(0xFF8B3C78),
      container: Color(0xFFFCE0F3),
      onContainer: Color(0xFF44163A),
    ),
    'seunghyun': CharacterAccent(
      base: Color(0xFF6A5779),
      container: Color(0xFFF1E3FC),
      onContainer: Color(0xFF31213F),
    ),
    'sohee': CharacterAccent(
      base: Color(0xFF005A82),
      container: Color(0xFFD0ECFF),
      onContainer: Color(0xFF002E50),
    ),
    'geonwoo': CharacterAccent(
      base: Color(0xFF874957),
      container: Color(0xFFFFDFE5),
      onContainer: Color(0xFF4B1323),
    ),
    'yuna': CharacterAccent(
      base: Color(0xFF1D6A53),
      container: Color(0xFFCEF0E2),
      onContainer: Color(0xFF00311E),
    ),
  },
  neutralAccent: const CharacterAccent(
    base: AppPalette.inkTextSoft,
    container: AppPalette.paper200,
    onContainer: AppPalette.inkText,
  ),
  shadowCard: const [
    BoxShadow(
      color: Color(0x0F1C1216),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ],
  shadowRaised: const [
    BoxShadow(
      color: Color(0x1A1C1216),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ],
  shadowSheet: const [
    BoxShadow(
      color: Color(0x261C1216),
      blurRadius: 28,
      offset: Offset(0, -6),
    ),
  ],
  numericSmall: _numeric(12.5, FontWeight.w600, AppPalette.inkTextSoft),
  numericMedium: _numeric(15, FontWeight.w700, AppPalette.inkText),
  numericLarge: _numeric(28, FontWeight.w700, AppPalette.inkText),
  bubbleText: _bubble(AppPalette.inkText),
  badgeText: _badge(AppPalette.inkText),
);

final AppTokens _darkTokens = AppTokens(
  success: AppPalette.successDark,
  onSuccess: Color(0xFF07301A),
  successContainer: AppPalette.successBgDark,
  onSuccessContainer: AppPalette.successOnBgDark,
  warning: AppPalette.warningDark,
  onWarning: Color(0xFF2E1700),
  warningContainer: AppPalette.warningBgDark,
  onWarningContainer: AppPalette.warningOnBgDark,
  danger: AppPalette.dangerDark,
  onDanger: Color(0xFF690005),
  dangerContainer: AppPalette.dangerBgDark,
  onDangerContainer: AppPalette.dangerOnBgDark,
  info: AppPalette.infoDark,
  onInfo: Color(0xFF0B1A4F),
  infoContainer: AppPalette.infoBgDark,
  onInfoContainer: AppPalette.infoOnBgDark,
  chatBackground: AppPalette.nightDim,
  bubbleMine: Color(0xFFA32048),
  onBubbleMine: Color(0xFFFFE3EA),
  bubbleTheirs: AppPalette.nightBubble,
  onBubbleTheirs: AppPalette.nightText,
  bubbleBorder: AppPalette.nightOutlineSoft,
  narration: AppPalette.nightTextSoft,
  systemLine: AppPalette.nightOutline,
  heart: AppPalette.heartDark,
  heartEmpty: AppPalette.nightOutlineSoft,
  comboIdle: AppPalette.night300,
  onComboIdle: AppPalette.nightTextSoft,
  comboFire: AppPalette.rose300,
  onComboFire: AppPalette.roseInk,
  lockedForeground: AppPalette.nightOutline,
  gaugeTrack: AppPalette.night400,
  statColors: const {
    _StatKey.charm: AppPalette.rose300,
    _StatKey.talk: AppPalette.violet300,
    _StatKey.esteem: AppPalette.teal300,
    _StatKey.sense: AppPalette.infoDark,
    _StatKey.money: AppPalette.successDark,
    _StatKey.stress: AppPalette.dangerDark,
  },
  characterAccents: const {
    'seoyeon': CharacterAccent(
      base: AppPalette.seoyeonDark,
      container: AppPalette.violet800,
      onContainer: AppPalette.violet100,
    ),
    'haneul': CharacterAccent(
      base: AppPalette.haneulDark,
      container: AppPalette.teal800,
      onContainer: AppPalette.teal100,
    ),
    'jiwoo': CharacterAccent(
      base: AppPalette.jiwooDark,
      container: Color(0xFF6B2513),
      onContainer: Color(0xFFFFDCD2),
    ),
    'minjae': CharacterAccent(
      base: AppPalette.minjaeDark,
      container: AppPalette.infoBgDark,
      onContainer: AppPalette.infoOnBgDark,
    ),
    'yeeun': CharacterAccent(
      base: AppPalette.yeeunDark,
      container: Color(0xFF274A21),
      onContainer: Color(0xFFD9EED4),
    ),
    'doyun': CharacterAccent(
      base: AppPalette.doyunDark,
      container: Color(0xFF2C4250),
      onContainer: Color(0xFFD8E4EA),
    ),
    'jeongwoo': CharacterAccent(
      base: Color(0xFFEFC7B0),
      container: Color(0xFF5F3921),
      onContainer: Color(0xFFFFE2D2),
    ),
    'daeun': CharacterAccent(
      base: Color(0xFFF1B0DE),
      container: Color(0xFF603354),
      onContainer: Color(0xFFFCE0F3),
    ),
    'seunghyun': CharacterAccent(
      base: Color(0xFFD6C2E5),
      container: Color(0xFF4D3B5B),
      onContainer: Color(0xFFF1E3FC),
    ),
    'sohee': CharacterAccent(
      base: Color(0xFF84CCF9),
      container: Color(0xFF00486A),
      onContainer: Color(0xFFD0ECFF),
    ),
    'geonwoo': CharacterAccent(
      base: Color(0xFFF7B9C4),
      container: Color(0xFF6A2F3D),
      onContainer: Color(0xFFFFDFE5),
    ),
    'yuna': CharacterAccent(
      base: Color(0xFF9BD5BF),
      container: Color(0xFF004C38),
      onContainer: Color(0xFFCEF0E2),
    ),
  },
  neutralAccent: const CharacterAccent(
    base: AppPalette.nightTextSoft,
    container: AppPalette.night300,
    onContainer: AppPalette.nightText,
  ),
  shadowCard: const [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ],
  shadowRaised: const [
    BoxShadow(
      color: Color(0x59000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ],
  shadowSheet: const [
    BoxShadow(
      color: Color(0x73000000),
      blurRadius: 30,
      offset: Offset(0, -8),
    ),
  ],
  numericSmall: _numeric(12.5, FontWeight.w600, AppPalette.nightTextSoft),
  numericMedium: _numeric(15, FontWeight.w700, AppPalette.nightText),
  numericLarge: _numeric(28, FontWeight.w700, AppPalette.nightText),
  bubbleText: _bubble(AppPalette.nightText),
  badgeText: _badge(AppPalette.nightText),
);

TextStyle _numeric(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: AppFonts.family,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  fontWeight: weight,
  height: 1.2,
  letterSpacing: 0,
  color: color,
  fontFeatures: const [FontFeature.tabularFigures()],
);

TextStyle _bubble(Color color) => TextStyle(
  fontFamily: AppFonts.family,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: 15,
  height: 1.55,
  letterSpacing: -0.2,
  fontWeight: FontWeight.w400,
  color: color,
);

TextStyle _badge(Color color) => TextStyle(
  fontFamily: AppFonts.family,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: 12.5,
  height: 1.25,
  letterSpacing: -0.1,
  fontWeight: FontWeight.w700,
  color: color,
);

// ---------------------------------------------------------------------------
// 8. ThemeData
// ---------------------------------------------------------------------------

/// MaterialApp 에 넣는 테마 두 벌. 화면에서 컴포넌트 스타일을 다시 정의할 일이
/// 없도록 기본값을 여기서 끝낸다.
abstract final class AppTheme {
  static final ThemeData light = _build(_lightScheme, _lightTokens);
  static final ThemeData dark = _build(_darkScheme, _darkTokens);

  static ThemeData _build(ColorScheme scheme, AppTokens tokens) {
    final text = AppTypography.textTheme(scheme);
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[tokens],
      textTheme: text,
      fontFamily: AppFonts.family,
      fontFamilyFallback: AppFonts.fallback,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,

      // 스크롤 끝에서 물결이 튀는 대신 조용히 멈춘다.
      highlightColor: Colors.transparent,

      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      primaryIconTheme: IconThemeData(color: scheme.onPrimary, size: 22),

      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: scheme.shadow,
        centerTitle: false,
        titleSpacing: AppSpace.lg,
        toolbarHeight: 56,
        titleTextStyle: text.titleLarge,
        toolbarTextStyle: text.bodyMedium,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
        actionsPadding: const EdgeInsets.only(right: AppSpace.sm),
      ),

      // 본문 버튼. 최소 높이 48 로 44pt 기준을 넘긴다.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          minimumSize: const Size(72, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xxl,
            vertical: AppSpace.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          elevation: 0,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          disabledForegroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          backgroundColor: scheme.surfaceContainerLowest,
          minimumSize: const Size(72, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.md,
          ),
          side: BorderSide(
            color: scheme.outlineVariant,
            width: AppBorderWidth.hairline,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
          textStyle: text.labelLarge,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          disabledForegroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          minimumSize: const Size(48, AppSpace.minTouch),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.rSm),
          textStyle: text.labelLarge,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(AppSpace.minTouch, AppSpace.minTouch),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.rSm),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      // 기본 Card 를 그대로 쓰지 말고 AppCard 를 쓴다.
      // 그래도 어딘가에서 Card 가 쓰이면 최소한 집안 규격으로 보이게 해 둔다.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow,
        elevation: isDark ? 0 : 1,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rLg,
          side: BorderSide(
            color: scheme.outlineVariant,
            width: AppBorderWidth.hairline,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
        labelStyle: text.labelMedium?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: text.labelMedium,
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
        padding: AppInsets.chip,
        side: BorderSide(
          color: scheme.outlineVariant,
          width: AppBorderWidth.hairline,
        ),
        shape: const StadiumBorder(),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 16),
      ),

      // 모달 시트. 다크에서는 바탕보다 두 단 위(surfaceContainerHigh)로 띄우고
      // 두 테마 모두 상단 1px 테두리를 둔다(HOME_REDESIGN §3.3).
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow,
        modalBackgroundColor: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow,
        modalBarrierColor: scheme.scrim.withValues(alpha: isDark ? 0.62 : 0.48),
        elevation: 0,
        modalElevation: 0,
        // 기본은 핸들 없음. 닫을 수 있는 시트만 호출부에서 true.
        showDragHandle: false,
        dragHandleColor: scheme.outline,
        dragHandleSize: const Size(36, 4),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.sheet,
          side: BorderSide(
            color: scheme.outlineVariant,
            width: AppBorderWidth.hairline,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.lg,
          AppSpace.lg,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        elevation: 2,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: text.titleSmall,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant,
        dividerHeight: 1,
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? scheme.primary.withValues(alpha: 0.08)
              : null,
        ),
      ),

      // 다이얼로그도 시트와 같은 규칙(§3.4). 스크림은 showAppDialog 가 맞춘다.
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: scheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rLg,
          side: BorderSide(
            color: scheme.outlineVariant,
            width: AppBorderWidth.hairline,
          ),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          0,
          AppSpace.md,
          AppSpace.md,
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xxl,
          vertical: AppSpace.xxl,
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.cardPad,
          vertical: AppSpace.xs,
        ),
        minVerticalPadding: AppSpace.md,
        minTileHeight: 56,
        titleTextStyle: text.titleSmall?.copyWith(fontSize: 15),
        subtitleTextStyle: text.bodySmall,
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // LinearProgressIndicator 를 직접 쓰는 대신 AppProgressBar 를 쓴다.
      // 남아 있는 사용처도 집안 색으로 보이게 둔다.
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: tokens.gaugeTrack,
        linearMinHeight: AppSpace.sm,
        circularTrackColor: tokens.gaugeTrack,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadius.rSm,
        ),
        textStyle: text.labelMedium?.copyWith(color: scheme.onInverseSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
      ),
    );
  }
}
