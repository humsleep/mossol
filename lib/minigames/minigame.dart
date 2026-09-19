import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../ui/design_system.dart';
import '../ui/widgets.dart';
import '../ui/keep_all.dart';

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

/// 미니게임이 받는 입력. 스탯과 상대 캐릭터에 따라 난이도가 달라진다.
class MinigameContext {
  final GameState state;
  final CharacterDef? partner;

  const MinigameContext({required this.state, this.partner});

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
  final result = await Navigator.of(context).push<MinigameResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _MinigameHost(builder: builder, ctx: ctx),
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

  /// 남은 시간 표시 (0.0 ~ 1.0). null 이면 숨김.
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
  static const _dwell = Duration(milliseconds: 1100);

  @override
  void didUpdateWidget(MinigameScaffold old) {
    super.didUpdateWidget(old);
    if (old.result == null && widget.result != null) {
      Future.delayed(_dwell, () {
        if (mounted) widget.onFinished?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final r = widget.result;
    final time = widget.timeLeft;

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
        child: Column(
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
                child: ResultBadge(
                  tone: tone,
                  label: r.critical ? '크리티컬!' : (r.success ? '성공' : '실패'),
                  detail: r.message,
                  large: true,
                ),
              ),
          ],
        ),
      ),
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
          onTap: dimmed ? null : onTap,
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
