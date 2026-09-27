/// 앱을 처음 켠 사람이 보는 첫 화면(타이틀). 규격은 docs/DESIGN_SYSTEM.md §2.16.
///
/// 지금까지 첫 프레임은 태현의 문자였다. 무슨 앱인지 알기 전에 대화가 시작되니
/// "잘못 켠 화면" 으로 읽혔다(유저 피드백 2026-09-26: "앱을 처음 켯을때 바로 대화부터
/// 나오는데 앱의 메인 인트로가 있고 그 후에 나오면 좋을것 같아요"). 그래서 대화 앞에
/// 이름·부제·그림 한 장과 들어가는 문 하나를 세운다.
///
/// **언제 뜨는가 — 첫 실행에만.** 이 화면은 [IntroScreen] 의 0단계다. 즉 `shouldShowIntro`
/// (세이브도 회차 기록도 없고 인트로를 아직 안 봄)일 때만 서고, 두 번째 세션부터는
/// 홈이 첫 화면이다(§2.1). **이어하기가 있는 사람을 매번 여기로 통과시키지 않는다**:
/// 이 화면이 하는 일은 "이게 무슨 앱인지" 를 알리는 것 하나뿐이고, 그건 한 번이면 된다.
/// 돌아온 사람에게 앱의 이름을 다시 말해 주는 자리는 이미 홈 헤더의 워드마크다.
/// 매 콜드 스타트마다 세우면 가장 자주 지나는 길(열기 → 이어하기)에 탭이 하나 늘 뿐이다.
/// 덤으로 ATT·광고 초기화 규칙(`main.dart`)도 그대로다 — 인트로가 끝나야 켜지므로
/// 추적 동의 팝업은 여전히 이 화면과 태현의 문자 **뒤에** 뜬다.
///
/// 배너는 두지 않는다(§2 공통). 앱의 첫 프레임이 광고일 수 없다.
///
/// **구성이 §2.16 과 두 군데 다르다**(docs/review/11_polish_verdict.md 7위 판정 반영,
/// 규격서 갱신 요청은 docs/review/12_ui_handoff.md):
/// ① 그림이 상단 55% 가 아니라 **화면 전체**다([TitleScreen.artHeightFactor]) — 0.55 는
///    아래 45% 를 자막·버튼이 채우는 통화 화면의 값이고, 타이틀에는 채울 것이 없어서
///    빈 자수정 띠와 가로 이음매만 남았다. 글자 자리는 하단 스크림이 만든다.
/// ② 워드마크 묶음이 화면 가운데가 아니라 **버튼과 함께 아래쪽**에 앉는다. 가운데
///    정렬 + 하단 버튼이던 예전 구성은 부제와 버튼 사이에 큰 공백을 남겼다.
/// 그리고 앱 이름은 본문과 같은 `displaySmall` 이 아니라 [AppTypography.wordmark] 다.
library;

import 'package:flutter/material.dart';

import 'call_view.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'scene_registry.dart';

class TitleScreen extends StatefulWidget {
  /// `시작하기` 를 눌렀을 때. 인트로가 태현의 문자로 넘어간다.
  final VoidCallback onStart;

  const TitleScreen({super.key, required this.onStart});

  /// 워드마크. 홈 헤더와 같은 낱말이다(앱 이름).
  static const title = '모쏠 탈출기';

  /// 앱 이름의 뒷부분. 스토어 이름 `모쏠 탈출기 : 100일 연애 시뮬레이션` 과 같다.
  static const genre = '100일 연애 시뮬레이션';

  /// 한 줄 소개. App Store 부제와 같은 문장이다(docs/STORE_LISTING.md §1).
  static const tagline = '톡 한 줄로 썸부터 고백까지';

  static const startLabel = '시작하기';

  /// 배경 그림. 전용 그림(`assets/scenes/title`)이 들어오면 그것을 쓰고, 없으면
  /// 게임의 첫 삽화(`m01` — 밤 자취방 책상 위, 엎어 둔 폰의 알림 불빛)로 대신한다.
  /// 둘 다 없으면 통화·알림 화면과 같은 자수정 그라데이션만 남는다.
  static const artKey = 'title';
  static const fallbackArtKey = 'm01';

  /// 그림이 차지하는 화면 높이 비율. **화면을 꽉 채운다.**
  ///
  /// 예전에는 [CallBackdrop] 의 기본값 0.55 를 그대로 물려받았다. 그건 아래 45% 에
  /// 발신자 정보·자막·끊기 버튼이 차는 **통화 화면의 값**이고, 타이틀에는 그 자리를
  /// 채울 것이 없어서 아래 45% 가 빈 자수정색으로 남았다 — 그림이 끊기는 가로 이음매와
  /// 부제·버튼 사이의 큰 공백이 실기 스크린샷에서 바로 보였다
  /// (docs/review/11_polish_verdict.md 7위). 그래서 1.0 + 하단 스크림으로 바꾸고,
  /// 워드마크 묶음과 버튼을 **아래쪽에 함께** 앉혔다(게임 타이틀의 기본 구성).
  static const artHeightFactor = 1.0;

  static String? artOf(SceneRegistry r) =>
      r.scene(artKey) ?? r.scene(fallbackArtKey);

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with SingleTickerProviderStateMixin {
  /// 워드마크 → 버튼 순으로 한 번만 떠오른다. 반복·튕김은 없다(§1.10).
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.dSlow,
  );
  late final Animation<double> _wordmark = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.75, curve: AppMotion.standard),
  );
  late final Animation<double> _entry = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.4, 1, curve: AppMotion.standard),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 동작 줄이기면 연출 없이 완성된 화면으로 선다(알림 카드와 같은 처리).
    if (AppMotion.reduced(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 올라오면서 밝아진다. 거리는 자기 높이의 20% — 눈에 띄면 실패다.
  Widget _rise(Animation<double> a, Widget child) => FadeTransition(
    opacity: a,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(a),
      child: child,
    ),
  );

  /// 워드마크 묶음: 눈썹 줄 → 앱 이름 → 짧은 선 → 한 줄 소개.
  ///
  /// 이름은 [AppTypography.wordmark] — 본문과 같은 `displaySmall` 이 아니다(§1.7).
  /// 눈썹 줄(`100일 연애 시뮬레이션`)은 반대로 자간을 **넓혀** 큰 낱말과 대비를 만든다.
  /// 로고 이미지는 없으므로 처리는 크기·자간·행간과 선 하나로만 한다.
  Widget _lockup(BuildContext context) {
    final scheme = context.scheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          keepAll(TitleScreen.genre),
          textAlign: TextAlign.center,
          style: context.text.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            // 큰 낱말 위의 눈썹 줄. 좁히는 게 아니라 벌려서 로고 묶음으로 읽히게 한다.
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        // 워드마크는 언제나 한 줄이다. 320pt · 1.3배에서 폭이 모자라면 줄바꿈 대신
        // 통째로 줄어든다 — 회전하는 줄바꿈 위치보다 작아진 로고가 낫다(§4.2).
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            TitleScreen.title,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: AppTypography.wordmark(
              context.text.displayLarge ?? const TextStyle(),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        // 이름과 한 줄 소개를 갈라 주는 짧은 선 하나. 화면의 유일한 장식이다.
        SizedBox(
          width: AppSpace.xxxl,
          child: Divider(
            height: AppBorderWidth.hairline,
            thickness: AppBorderWidth.hairline,
            color: scheme.outline,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          keepAll(TitleScreen.tagline),
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => SceneScope(
    builder: (context, registry) => CallBackdrop(
      image: TitleScreen.artOf(registry),
      heightFactor: TitleScreen.artHeightFactor,
      bottomScrim: true,
      child: Builder(
        builder: (context) => SafeArea(
          top: false,
          // 그림은 화면 전체, 글자와 버튼은 아래쪽 한 덩어리다. 세로로 모자라면
          // (320×568 · 1.3배) 스크롤한다 — 잘리지 않는다(§4.2).
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screenX,
                AppSpace.screenY,
                AppSpace.screenX,
                AppSpace.xxl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: box.maxHeight - AppSpace.screenY - AppSpace.xxl,
                ),
                child: Column(
                  // 남는 높이는 위(그림)로 간다. 묶음은 늘 아래에 앉는다.
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _rise(_wordmark, _lockup(context)),
                    const SizedBox(height: AppSpace.xxxl),
                    _rise(
                      _entry,
                      FilledButton(
                        key: const Key('title-start'),
                        onPressed: widget.onStart,
                        child: const Text(TitleScreen.startLabel),
                      ),
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
