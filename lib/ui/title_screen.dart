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

  @override
  Widget build(BuildContext context) => SceneScope(
    builder: (context, registry) => CallBackdrop(
      image: TitleScreen.artOf(registry),
      child: Builder(
        builder: (context) {
          final scheme = context.scheme;
          return SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    // 1.3배 글꼴에서도 잘리지 않게 세로로 모자라면 스크롤한다(§4.2).
                    child: SingleChildScrollView(
                      padding: AppInsets.screen,
                      child: _rise(
                        _wordmark,
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              keepAll(TitleScreen.genre),
                              textAlign: TextAlign.center,
                              style: context.text.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpace.sm),
                            Text(
                              TitleScreen.title,
                              textAlign: TextAlign.center,
                              style: context.text.displaySmall,
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
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenX,
                    0,
                    AppSpace.screenX,
                    AppSpace.xxl,
                  ),
                  child: _rise(
                    _entry,
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('title-start'),
                        onPressed: widget.onStart,
                        child: const Text(TitleScreen.startLabel),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
