import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sfx_service.dart';
import '../engine/models.dart';
import '../ui/design_system.dart';
import '../ui/widgets.dart';
import '../ui/keep_all.dart';
import 'variation.dart';

/// 미니게임 한 판의 결과.
/// [success] 는 선택지의 효과를 적용할지, [critical] 은 호감 상승을 2배로 할지 결정한다.
class MinigameResult {
  final bool success;
  final bool critical;

  /// 0.0 ~ 1.0. 결과 문구를 고르는 데만 쓴다.
  final double score;

  /// 결과 화면에 띄울 한 줄.
  final String message;

  const MinigameResult({
    required this.success,
    this.critical = false,
    this.score = 0,
    this.message = '',
  });

  const MinigameResult.miss(this.message)
    : success = false,
      critical = false,
      score = 0;
}

/// 미니게임의 손맛. 12종이 **같은 낱말 여섯 개**로만 말한다.
///
/// 새 큐는 만들지 않는다 — `Sfx` enum 은 `lib/audio/sfx_service.dart` 소유라
/// 여기서 못 늘린다. 그래서 있는 큐 중 뜻이 가장 가까운 것을 골라 쓰고, 모자란
/// 자리는 진동만으로 대답한다. 모자란 큐 목록은 docs/review/12_audio_handoff.md
/// 에 요청으로 남겼다.
///
/// 규칙 셋.
/// 1. **토글은 서비스가 본다.** 여기서 `sfxOn`·`hapticOn` 을 다시 보지 않는다
///    (`SfxService.play`·`haptic` 이 이미 걸러 준다).
/// 2. **타이머는 큐를 내지 않는다.** 남은 시간이 매 틱(50~100ms) 울리면 소리가
///    아니라 잡음이다. 시간 경고는 [MinigameScaffold] 가 30% 경계를 **한 번만**
///    넘을 때 낸다.
/// 3. **입력과 결과가 같은 프레임이면 결과만 낸다.** 멈추기 게임처럼 탭이 곧
///    판정인 자리에서 둘을 다 내면 소리가 두 번 겹친다.
class MinigameSfx {
  MinigameSfx._();

  static SfxService get _s => SfxService.instance;

  /// 크리티컬의 둘째 박자. 성공과 **손으로** 구별되게 한 번 더 친다
  /// (엔딩이 heavy → 120ms → light 로 두 박자를 쓰는 것과 같은 방식).
  static const critBeat = Duration(milliseconds: 90);

  /// 놀이판을 건드렸다. 카드·선택지·스와이프·길게 누르기 시작.
  /// `msgOut`(P2 · selection) — "내가 방금 뭘 했다" 에 가장 가까운 큐다.
  static void tap() => _s.cue(Sfx.msgOut);

  /// 한 칸 나아갔다. 맞는 카드, 맞춘 박자, 매칭된 프로필.
  /// `waitRead`(P2 · light) — 짧고 밝은 확인음.
  static void step() => _s.cue(Sfx.waitRead);

  /// 헛디뎠다. **판은 아직 살아 있다** — 그래서 실패음(`choiceFail`)을 쓰지 않는다.
  /// 결과 실패와 섞이면 "졌다" 와 "틀렸다" 가 같은 소리가 된다. 전용 큐가 없어
  /// 지금은 진동만으로 말한다(요청: `tap_bad`).
  static void nudge() => _s.haptic(HapticKind.heavy);

  /// 무르기·취소. 되돌렸다는 것만 알리면 된다(요청: `undo`).
  static void undo() {
    _s.play(Sfx.waitRead);
    _s.haptic(HapticKind.medium);
  }

  /// 남은 시간이 30% 아래로 떨어졌다. 판당 한 번뿐이다(규칙 2).
  /// `callEnd`(P1 · medium) — "이제 끝난다" 쪽 소리라 재촉으로 읽힌다(요청: `timer_low`).
  static void timeLow() => _s.cue(Sfx.callEnd);

  /// 판이 끝났다. 세 결과가 **글자를 읽지 않고도** 갈리는 유일한 자리다.
  /// 크리티컬 = choiceOk + medium + 90ms 뒤 heavy(두 박자),
  /// 성공 = choiceOk + medium(한 박자), 실패 = choiceFail + heavy(무거운 한 박자).
  ///
  /// 돌려주는 [Timer] 는 크리티컬의 둘째 박자다. 위젯이 사라질 때 취소해야 한다.
  static Timer? result(MinigameResult r) {
    _s.cue(r.success ? Sfx.choiceOk : Sfx.choiceFail);
    if (!r.critical) return null;
    return Timer(critBeat, () => _s.haptic(HapticKind.heavy));
  }
}

/// 미니게임의 **제한 시계**. 프레임으로 돈다 — `Stopwatch` 도 `Timer.periodic` 도
/// 아니다(규격서 §2.13 이 날짜 카드에 대해 이미 같은 이유로 `Timer` 를 금지한다).
///
/// 왜 바꿨나. 예전 시계는 `Stopwatch` + `Timer.periodic(100ms)` 였다. `Timer` 는
/// 위젯 테스트에서 **가짜 시계**를 타는데 `Stopwatch` 는 **진짜 시계**를 탄다.
/// 그래서 테스트가 프레임을 도는 동안(특히 `pumpAndSettle`) 실제 시간이 흘러
/// **판이 스스로 시간 초과로 끝났다.** 증상은 시계와 아무 상관없어 보이는
/// "크리티컬! 을 못 찾겠다" 였고, 원인을 가리키는 단서가 메시지에 하나도 없었다
/// (12_ui_handoff §2-1 의 `test/widget/flow_test.dart`). 점수에 경과 시간을 쓰는
/// 게임(단톡방의 6초, 5초 삭제의 절반 기준)은 **판정까지** 실행 기계 속도에
/// 좌우됐다. 프레임으로 돌면 흐른 시간이 곧 `pump` 한 시간이라 씨앗이 같으면
/// 결과도 같다.
///
/// [AnimationBehavior.preserve] 는 장식이 아니다. 기본값(`normal`)은 기기에서
/// **동작 줄이기**가 켜져 있으면 길이를 0.05배로 줄인다 — 연출이면 맞는 처리지만
/// 이건 제한 시간이라, 접근성 설정을 켠 플레이어의 판이 0.3초 만에 끝나 버린다.
class MinigameClock extends ChangeNotifier {
  final AnimationController _c;

  /// 시간이 다 됐다. 판을 끝내는 것은 게임의 몫이다.
  final VoidCallback onExpire;

  MinigameClock({
    required TickerProvider vsync,
    required Duration limit,
    required this.onExpire,
  }) : _c = AnimationController(
         vsync: vsync,
         duration: limit,
         animationBehavior: AnimationBehavior.preserve,
       ) {
    _c
      ..addListener(notifyListeners)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) onExpire();
      })
      ..forward();
  }

  /// 남은 시간 0.0~1.0. [MinigameScaffold.timeLeft] 에 그대로 넣는다.
  double get left => (1 - _c.value).clamp(0.0, 1.0);

  /// 시작(또는 마지막 [restart])부터 흐른 밀리초. 점수를 매기는 자리가 쓴다.
  int get elapsedMs => (_c.value * _c.duration!.inMilliseconds).round();

  /// 시계를 되감아 다시 돌린다. 표정 읽기는 문제마다 되감는다.
  void restart() => _c.forward(from: 0);

  /// 시계를 세운다. 판이 끝났거나 정답을 공개하는 동안.
  /// 멈춘 시계는 프레임을 더 잡아먹지 않는다.
  void stop() => _c.stop();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
}

/// 미니게임이 받는 입력. 스탯과 상대 캐릭터에 따라 난이도가 달라진다.
class MinigameContext {
  final GameState state;
  final CharacterDef? partner;

  /// 이 미니게임이 이 회차에서 몇 번째로 등장했는지. [playMinigame] 이 채워 준다.
  /// 직접 만든 컨텍스트(디버그 갤러리·테스트)는 0 이 기본이다.
  final int round;

  const MinigameContext({
    required this.state,
    this.partner,
    this.round = 0,
  });

  /// 등장 순번만 갈아 낀 사본. [playMinigame] 이 쓴다.
  MinigameContext atRound(int r) =>
      MinigameContext(state: state, partner: partner, round: r);

  /// 판을 짜는 데 쓰는 변주기. 같은 씨앗·같은 순번이면 언제나 같은 판이 나온다.
  MinigameVariation get vary =>
      MinigameVariation(seed: state.seed, round: round, day: state.day);

  int stat(String key) => state.stat(key);

  /// 상대의 선호 답장 구간. 상대가 없으면 가운데.
  List<double> get replyZone => partner?.replyZone ?? const [0.35, 0.6];
  String get humor => partner?.humor ?? 'warm';
  List<String> get tags => partner?.tags ?? const ['조용한', '산책'];
  int get budget => partner?.budget ?? 40;
  String get partnerName => partner?.name ?? '상대';
}

typedef MinigameBuilder = Widget Function(
  MinigameContext ctx,
  void Function(MinigameResult) done,
);

/// id → 화면. 이벤트 JSON 의 `"minigame": "<id>"` 가 여기를 가리킨다.
final Map<String, MinigameBuilder> minigameRegistry = {};

/// 등록된 미니게임 id 목록. 데이터 검증에 쓴다.
Set<String> get minigameIds => minigameRegistry.keys.toSet();

/// 미니게임을 전체 화면으로 띄우고 결과를 기다린다.
/// 등록되지 않은 id 면 성공으로 처리해 스토리 흐름을 막지 않는다.
Future<MinigameResult> playMinigame(
  BuildContext context,
  String id,
  MinigameContext ctx,
) async {
  final builder = minigameRegistry[id];
  if (builder == null) {
    debugPrint('등록되지 않은 미니게임: $id');
    return const MinigameResult(success: true);
  }
  // 같은 미니게임의 몇 번째 판인지 여기서 센다. 이 값 하나로 문제·배치·난이도가
  // 판마다 갈린다(variation.dart).
  // 순번은 **기기에 남는다**. 앱을 껐다 켜도 이어 세므로 세션마다 기준 판으로
  // 되돌아가지 않는다(하트 경제 탓에 거의 모든 세션이 콜드 스타트다).
  // 씨앗·회차까지 키에 넣는다. 새 게임은 키가 바뀌므로 순번이 0 부터 다시 시작해
  // 기준 판을 다시 만난다 — 같은 프로세스에서 두 번째 새 게임을 시작해도 그렇다.
  // 세기는 동기다. 여기에 `await` 를 하나 끼우면 "버튼을 누른 그 프레임에
  // 미니게임 라우트가 덮는다" 는 성질이 깨진다. 저장된 값은 앱이 뜰 때
  // [registerMinigames] 가 미리 읽어 둔다([MinigameRotation.ready]).
  final round = MinigameRotation.next(
    '${ctx.state.seed}:${ctx.state.run}:$id',
  );
  final result = await Navigator.of(context).push<MinigameResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _MinigameHost(builder: builder, ctx: ctx.atRound(round)),
    ),
  );
  return result ?? const MinigameResult.miss('중단했다');
}

class _MinigameHost extends StatefulWidget {
  final MinigameBuilder builder;
  final MinigameContext ctx;
  const _MinigameHost({required this.builder, required this.ctx});

  @override
  State<_MinigameHost> createState() => _MinigameHostState();
}

class _MinigameHostState extends State<_MinigameHost> {
  bool _closing = false;

  void _done(MinigameResult r) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) =>
      PopScope(canPop: false, child: widget.builder(widget.ctx, _done));
}

/// 모든 미니게임이 쓰는 껍데기. 제목, 설명, 남은 시간, 본문, 결과를 맡는다.
///
/// 위계: 놀이판([child])이 주인공이고 제목·설명은 물러난다. 결과가 정해지면
/// 본문을 0.5 로 내리고 화면 배경과 결과 배지를 tone 에 맞춰 함께 바꾼다
/// (크리티컬 = brand / 성공 = success / 실패 = danger). 문구
/// `크리티컬!` / `성공` / `실패` 는 고정이다.
class MinigameScaffold extends StatefulWidget {
  final String title;
  final String instruction;
  final Widget child;

  /// 결과가 정해지면 이 값이 채워지고, 잠깐 연출 후 [onFinished] 가 불린다.
  final MinigameResult? result;
  final VoidCallback? onFinished;

  /// 남은 시간 표시 (0.0 ~ 1.0).
  ///
  /// **한 번이라도 값을 준 판에서는 null 이 "숨김" 이 아니라 "시계가 멈췄다" 다.**
  /// 막대 자리는 그대로 두고 마지막 값에서 멈춘 막대를 그린다. 예전에는
  /// null 이 오면 자리가 통째로 사라져서, 표정 읽기처럼 정답을 공개할 때마다
  /// 시계를 내리는 게임은 **한 판에 네 번 놀이판 전체가 위아래로 들썩였다**
  /// (12_ui_handoff §2-2). 시계가 아예 없는 게임(9종)은 한 번도 값을 주지 않으므로
  /// 빈 자리가 생기지 않는다 — 자리는 "예약" 이 아니라 "쓰기 시작하면 안 없어짐" 이다.
  final double? timeLeft;

  /// 본문 아래에 고정되는 조작부. 스크롤과 함께 밀려서는 안 되는 버튼을 둔다.
  final Widget? footer;

  /// 제목 우측 pill. 난이도에 영향을 주는 스탯을 알려 줄 때. 예: '눈치 22'.
  final String? badge;

  const MinigameScaffold({
    super.key,
    required this.title,
    required this.instruction,
    required this.child,
    this.result,
    this.onFinished,
    this.timeLeft,
    this.footer,
    this.badge,
  });

  @override
  State<MinigameScaffold> createState() => _MinigameScaffoldState();
}

class _MinigameScaffoldState extends State<MinigameScaffold> {
  /// 결과를 읽을 시간. 애니메이션이 아니라 체류 시간이므로 동작 줄이기
  /// 설정과 무관하게 유지한다(이벤트 흐름과 위젯 테스트가 이 길이를 기다린다).
  /// **탭하면 이 시간을 건너뛴다**([_skipFloor] 이후).
  static const _dwell = Duration(milliseconds: 1100);

  /// 건너뛰기를 열어 주기까지의 최소 체류. 회차당 150판을 1.1초씩 쳐다보는 건
  /// 약 3분이라 넘길 수 있어야 하지만, 0 으로 두면 **판정을 만든 그 탭**의
  /// 손가락이 결과 화면까지 그대로 밀고 들어가 결과를 못 본다. 350ms 는
  /// 배지가 뜨고 색이 바뀌는 것(`AppMotion.base` 급)이 끝나는 길이다.
  static const _skipFloor = Duration(milliseconds: 350);

  /// 시간 경고를 낼 준비가 됐는지. 30% 위로 올라가면 다시 장전된다
  /// (표정 읽기는 문제마다 시계를 되감는다). 매 틱 울리지 않게 하는 장치다.
  bool _lowArmed = true;

  /// 마지막으로 받은 남은 시간. [MinigameScaffold.timeLeft] 가 null 이 돼도
  /// 막대 자리를 비우지 않으려고 들고 있는다.
  double? _lastTime;

  bool _finished = false;
  bool _skippable = false;
  Timer? _dwellTimer, _skipTimer, _critTimer;

  @override
  void initState() {
    super.initState();
    _lastTime = widget.timeLeft;
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _skipTimer?.cancel();
    _critTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MinigameScaffold old) {
    super.didUpdateWidget(old);
    final time = widget.timeLeft;
    if (time != null) _lastTime = time;
    if (time != null && widget.result == null) {
      // 막대가 위험색으로 바뀌는 그 경계(0.3)에서 한 번만 재촉한다.
      if (_lowArmed && time < 0.3) {
        _lowArmed = false;
        MinigameSfx.timeLow();
      } else if (time >= 0.3) {
        _lowArmed = true;
      }
    }
    if (old.result == null && widget.result != null) {
      _lowArmed = false;
      _critTimer = MinigameSfx.result(widget.result!);
      _dwellTimer = Timer(_dwell, _finish);
      _skipTimer = Timer(_skipFloor, () {
        if (mounted) setState(() => _skippable = true);
      });
    }
  }

  /// 결과 화면을 닫는다. 자동(dwell)이든 탭이든 한 번만 통과한다.
  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _dwellTimer?.cancel();
    widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final r = widget.result;
    // null 은 "시계가 멈췄다" 다. 마지막 값으로 막대를 세워 둔다(자리가 안 사라진다).
    final time = widget.timeLeft ?? _lastTime;

    final tone = r == null
        ? AppTone.neutral
        : r.critical
        ? AppTone.brand
        : r.success
        ? AppTone.success
        : AppTone.danger;
    final bg = r == null
        ? scheme.surface
        : r.critical
        ? scheme.primaryContainer
        : r.success
        ? scheme.surfaceContainerHigh
        : scheme.errorContainer;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          // 본문이 예전(SafeArea 의 유일한 자식)과 **같은 제약**을 받게 한다.
          // 기본 loose 로 두면 세로·가로 최소 제약이 0 이 되어 레이아웃이 미묘하게
          // 달라진다 — 덮개를 얹으려고 Stack 을 끼운 것이지 배치를 바꾸려는 게 아니다.
          fit: StackFit.expand,
          children: [
            _body(context, r, time, tone),
            // 결과가 뜬 뒤에는 화면 아무 데나 눌러 넘긴다. 버튼 위까지 덮으려고
            // 본문 위에 깔아 둔다 — 결과 뒤의 버튼은 전부 비활성이라 가릴 것이 없다.
            if (r != null && _skippable)
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: '결과 넘기기',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _finish,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 결과 배지까지 포함한 화면 본문. [build] 가 이 위에 건너뛰기 덮개를 얹는다.
  Widget _body(
    BuildContext context,
    MinigameResult? r,
    double? time,
    AppTone tone,
  ) {
    final t = context.tokens;
    final scheme = context.scheme;
    return Column(
          children: [
            // 제목 블록. 제목 한 줄 + 난이도 배지, 그 아래 설명.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screenX,
                AppSpace.lg,
                AppSpace.screenX,
                AppSpace.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          keepAll(widget.title),
                          style: context.text.titleLarge,
                        ),
                      ),
                      if (widget.badge != null) ...[
                        const SizedBox(width: AppSpace.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.sm,
                            vertical: AppSpace.xs,
                          ),
                          decoration: BoxDecoration(
                            color: t.infoContainer,
                            borderRadius: AppRadius.rPill,
                          ),
                          child: Text(
                            widget.badge!,
                            style: t.numericSmall.copyWith(
                              color: t.onInfoContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    keepAll(widget.instruction),
                    style: context.text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // 남은 시간. 30% 아래면 위험색으로 바뀐다(색 + 길이 두 신호).
            if (time != null)
              Padding(
                // 아래 놀이판과 붙어 보이지 않게 섹션 사이 간격을 둔다.
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenX,
                  AppSpace.xs,
                  AppSpace.screenX,
                  AppSpace.md,
                ),
                child: AppProgressBar(
                  value: time,
                  semanticLabel: '남은 시간',
                  height: AppSpace.xs + 2,
                  fill: time < 0.3 ? t.danger : scheme.primary,
                ),
              ),
            Expanded(
              child: AnimatedOpacity(
                // 0.25 면 정답 공개(체크·정답 문구)가 읽히지 않는다. 물러나되 알아볼 수는 있게.
                opacity: r == null ? 1 : 0.5,
                duration: AppMotion.base(context),
                curve: AppMotion.curve(context),
                child: IgnorePointer(ignoring: r != null, child: widget.child),
              ),
            ),
            if (widget.footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenX,
                  AppSpace.sm,
                  AppSpace.screenX,
                  AppSpace.sm,
                ),
                child: widget.footer!,
              ),
            if (r != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenX,
                  AppSpace.sm,
                  AppSpace.screenX,
                  AppSpace.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ResultBadge(
                      tone: tone,
                      label: r.critical ? '크리티컬!' : (r.success ? '성공' : '실패'),
                      detail: r.message,
                      large: true,
                    ),
                    // 넘길 수 있게 된 뒤에만 알린다. 처음부터 적어 두면 아직
                    // 안 먹히는 안내를 읽히게 된다.
                    if (_skippable) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        keepAll('아무 데나 눌러서 넘기기'),
                        textAlign: TextAlign.center,
                        style: context.text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
    );
  }
}

/// 세로 가운데 정렬하되, 작은 화면이나 큰 글꼴로 공간이 모자라면 스크롤된다.
/// `Column(mainAxisAlignment: center)` 를 그대로 쓰면 RenderFlex overflow 가 난다.
class CenteredScrollColumn extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final CrossAxisAlignment crossAxisAlignment;

  const CenteredScrollColumn({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      padding: padding,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (box.maxHeight - padding.vertical).clamp(
            0,
            double.infinity,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        ),
      ),
    ),
  );
}

/// 미니게임 선택 버튼의 상태. [correct] / [wrong] 은 정답 공개 연출이다.
enum MinigameOptionTone { neutral, correct, wrong }

/// 미니게임 안에서 반복해 쓰는 선택 버튼.
///
/// 상태는 언제나 색 + 테두리 굵기 + 아이콘 세 가지로 동시에 말한다.
/// [dimmed] 는 불투명도를 내리지 않는다 — 대비가 4.5:1 아래로 떨어지기
/// 때문에, 흐리게 보이는 대신 2차 글자색으로 물러나고 탭만 막는다.
class MinigameOption extends StatelessWidget {
  final String label;
  final String? sub;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  /// [dimmed] 라서 못 누르는 칸을 눌렀을 때. 없으면 예전처럼 탭이 조용히 먹힌다.
  /// "3곳이 다 찼다" 처럼 **막혀 있다는 것 자체가 알려야 할 정보**인 자리에 쓴다.
  final VoidCallback? onDimmedTap;

  /// 좌측 아이콘·번호 등. 없으면 좌측 여백 없음.
  final Widget? leading;

  /// 우측 짧은 수치(가격, 순서 등). numericSmall 로 렌더한다.
  final String? trailingLabel;

  /// 정답 공개 연출.
  final MinigameOptionTone tone;

  const MinigameOption({
    super.key,
    required this.label,
    this.sub,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
    this.onDimmedTap,
    this.leading,
    this.trailingLabel,
    this.tone = MinigameOptionTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;

    // (배경, 선, 글자, 선 굵기, 상태 아이콘)
    final (Color bg, Color line, Color fg, double w, IconData? mark) =
        switch (tone) {
          MinigameOptionTone.correct => (
            t.successContainer,
            t.success,
            t.onSuccessContainer,
            AppBorderWidth.emphasis,
            Icons.check_circle,
          ),
          MinigameOptionTone.wrong => (
            t.dangerContainer,
            t.danger,
            t.onDangerContainer,
            AppBorderWidth.emphasis,
            Icons.close,
          ),
          MinigameOptionTone.neutral when selected => (
            scheme.primaryContainer,
            scheme.primary,
            scheme.onPrimaryContainer,
            AppBorderWidth.emphasis,
            Icons.check,
          ),
          MinigameOptionTone.neutral => (
            scheme.surfaceContainer,
            scheme.outlineVariant,
            scheme.onSurface,
            AppBorderWidth.hairline,
            null,
          ),
        };
    final labelColor = dimmed ? scheme.onSurfaceVariant : fg;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Material(
        color: bg,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rMd,
          side: BorderSide(color: line, width: w),
        ),
        child: InkWell(
          onTap: dimmed ? onDimmedTap : onTap,
          child: ConstrainedBox(
            // 탭 대상 최소 48. 고정 높이가 아니라 최소 높이라 큰 글꼴에서 늘어난다.
            constraints: const BoxConstraints(
              minHeight: AppSpace.minTouch + AppSpace.xs,
            ),
            child: Padding(
              padding: AppInsets.cardTight,
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpace.md),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          keepAll(label),
                          style: context.text.bodyMedium?.copyWith(
                            fontSize: 15,
                            color: labelColor,
                          ),
                        ),
                        if (sub != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.xxs),
                            child: Text(
                              keepAll(sub!),
                              style: context.text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailingLabel != null) ...[
                    const SizedBox(width: AppSpace.sm),
                    Text(
                      trailingLabel!,
                      style: t.numericSmall.copyWith(color: labelColor),
                    ),
                  ],
                  if (mark != null) ...[
                    const SizedBox(width: AppSpace.sm),
                    Icon(mark, size: 18, color: line),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
