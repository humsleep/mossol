import 'package:flutter/material.dart';

import '../engine/models.dart';

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

/// 모든 미니게임이 쓰는 껍데기. 제목, 설명, 본문, 결과 연출을 맡는다.
class MinigameScaffold extends StatefulWidget {
  final String title;
  final String instruction;
  final Widget child;

  /// 결과가 정해지면 이 값이 채워지고, 잠깐 연출 후 [onFinished] 가 불린다.
  final MinigameResult? result;
  final VoidCallback? onFinished;

  /// 남은 시간 표시 (0.0 ~ 1.0). null 이면 숨김.
  final double? timeLeft;

  const MinigameScaffold({
    super.key,
    required this.title,
    required this.instruction,
    required this.child,
    this.result,
    this.onFinished,
    this.timeLeft,
  });

  @override
  State<MinigameScaffold> createState() => _MinigameScaffoldState();
}

class _MinigameScaffoldState extends State<MinigameScaffold> {
  @override
  void didUpdateWidget(MinigameScaffold old) {
    super.didUpdateWidget(old);
    if (old.result == null && widget.result != null) {
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) widget.onFinished?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = widget.result;
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.instruction,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.timeLeft != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: widget.timeLeft!.clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: widget.timeLeft! < 0.3
                        ? scheme.error
                        : scheme.primary,
                  ),
                ),
              ),
            Expanded(
              child: AnimatedOpacity(
                opacity: r == null ? 1 : 0.25,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(ignoring: r != null, child: widget.child),
              ),
            ),
            if (r != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      r.critical ? '크리티컬!' : (r.success ? '성공' : '실패'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: r.critical
                                ? scheme.primary
                                : r.success
                                ? scheme.onSurface
                                : scheme.error,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(r.message, textAlign: TextAlign.center),
                  ],
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

/// 미니게임 안에서 반복해 쓰는 선택 버튼.
class MinigameOption extends StatelessWidget {
  final String label;
  final String? sub;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  const MinigameOption({
    super.key,
    required this.label,
    this.sub,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: dimmed ? null : onTap,
          child: Opacity(
            opacity: dimmed ? 0.4 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(fontSize: 15, height: 1.35),
                        ),
                        if (sub != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              sub!,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check, size: 18, color: scheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
