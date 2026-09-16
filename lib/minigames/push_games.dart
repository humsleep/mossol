import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../ui/design_system.dart';
import '../ui/widgets.dart';
import 'minigame.dart';

/// 9. 선 지키기 — 술자리
/// 분위기는 맞추되 내 주량을 넘기지 않는 게임.
/// 멈추는 것 자체가 성공이고, 한도를 넘겨 필름이 끊기는 것만 실패다.
/// 잔 수가 많다고 더 큰 보상을 주지 않는다(음주 미화 방지).
class DrinkLimitGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const DrinkLimitGame({super.key, required this.ctx, required this.done});

  @override
  State<DrinkLimitGame> createState() => _DrinkLimitGameState();
}

class _DrinkLimitGameState extends State<DrinkLimitGame> {
  int _glasses = 0;
  MinigameResult? _result;
  late final Random _rng = Random(
    widget.ctx.state.seed ^ widget.ctx.state.day ^ 7,
  );

  /// 자존감이 높을수록 자기 한도를 잘 안다.
  int get _bustPercent {
    final tolerance = widget.ctx.stat(Stat.esteem) ~/ 12;
    return (_glasses * _glasses * 5 - tolerance).clamp(0, 95);
  }

  void _drink() {
    if (_result != null) return;
    if (_rng.nextInt(100) < _bustPercent) {
      setState(() {
        _result = const MinigameResult.miss('선을 넘었다. 여기부터 기억이 없다.');
      });
      return;
    }
    setState(() => _glasses++);
    if (_glasses >= 5) _stop();
  }

  /// 멈추면 언제든 성공. 보상은 잔 수와 무관하게 고정이고,
  /// 자리 분위기를 읽고 일찍 멈춘 판단만 크리티컬로 쳐준다.
  void _stop() {
    if (_result != null) return;
    setState(() {
      _result = MinigameResult(
        success: true,
        critical: _glasses <= 2,
        score: 1,
        message: _glasses == 0
            ? '한 잔도 안 마시고 대화를 이끌었다.'
            : _glasses <= 2
            ? '$_glasses잔에서 멈췄다. 끝까지 내 말투였다.'
            : '적당히 마시고 자리를 마무리했다.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final bust = _bustPercent;
    // 위험 구간은 경고 상태색으로만 알린다. 노랑 계열을 브랜드로 쓰지 않는다.
    final risky = bust >= 40;

    return MinigameScaffold(
      title: '선 지키기',
      badge: '${Stat.label(Stat.esteem)} ${widget.ctx.stat(Stat.esteem)}',
      instruction: '분위기는 맞추되 내 주량을 넘기지 않는다. '
          '언제 멈춰도 성공이고, 확률은 화면에 그대로 보인다.',
      result: _result,
      onFinished: () => widget.done(_result!),
      // 두 버튼은 이 게임의 전부다. 스크롤과 무관하게 항상 같은 자리에 둔다.
      footer: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _result == null ? _stop : null,
              child: const Text('여기까지'),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: OutlinedButton(
              onPressed: _result == null ? _drink : null,
              child: const Text('한 잔 더'),
            ),
          ),
        ],
      ),
      child: CenteredScrollColumn(
        padding: AppInsets.screenX,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 잔은 다섯 개가 한 묶음이다. 아이콘 반복을 스크린리더가 다섯 번
          // 읽지 않도록 묶어서 한 줄로 요약한다.
          Semantics(
            container: true,
            label: '$_glasses잔',
            child: ExcludeSemantics(
              child: Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < 5; i++)
                    Icon(
                      i < _glasses ? Icons.local_bar : Icons.local_bar_outlined,
                      size: AppSpace.xxxl,
                      color: i < _glasses ? scheme.primary : t.gaugeTrack,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          Text(
            '$_glasses잔',
            textAlign: TextAlign.center,
            style: t.numericLarge,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            '지금 멈추면 분위기를 맞춘 것으로 끝난다',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          // 다음 잔의 위험. 숫자 + 막대 + (위험하면) 아이콘으로 함께 말한다.
          AppCard(
            tone: risky ? AppTone.warning : AppTone.neutral,
            padding: AppInsets.cardTight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      risky
                          ? Icons.warning_amber_rounded
                          : Icons.local_bar_outlined,
                      size: AppSpace.xl,
                      color: risky ? t.warning : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        '다음 잔 흑역사 확률 $bust%',
                        style: t.numericSmall.copyWith(
                          fontSize: 15,
                          color: risky
                              ? t.onWarningContainer
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                AppProgressBar(
                  value: bust / 100,
                  semanticLabel: '다음 잔 흑역사 확률',
                  fill: risky ? t.warning : scheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. 대화 카드 순서 맞추기 — 화술
class WordOrderGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const WordOrderGame({super.key, required this.ctx, required this.done});

  @override
  State<WordOrderGame> createState() => _WordOrderGameState();
}

class _WordOrderGameState extends State<WordOrderGame> {
  /// (3장 문장, 4장 문장). 화술 50 이상이면 4장으로 더 좋은 문장을 만들 수 있다.
  static const _sets = [
    (['오늘', '고마웠어', '진짜'], ['오늘', '진짜', '고마웠어', '덕분에']),
    (['다음에', '또', '보자'], ['다음에는', '내가', '먼저', '연락할게']),
    (['그때', '말한', '거기'], ['그때', '네가', '말한', '거기']),
  ];

  late final bool _long = widget.ctx.stat(Stat.talk) >= 50;
  late final List<String> _answer = () {
    final s = _sets[widget.ctx.state.day % _sets.length];
    return _long ? s.$2 : s.$1;
  }();
  late final List<String> _pool = List.of(_answer)
    ..shuffle(Random(widget.ctx.state.seed ^ widget.ctx.state.day));

  final _built = <String>[];
  int _mistakes = 0;
  MinigameResult? _result;

  /// 방금 잘못 누른 카드. 표시용이며 판정(`_mistakes`)과 별개다.
  /// 틀렸다는 사실이 화면 아래 배지에만 있으면 어느 카드가 틀렸는지 모른다.
  String? _wrong;
  Timer? _wrongTimer;

  /// 틀린 카드를 물들여 두는 시간. 깜빡임이 아니라 잠깐 머무는 상태라
  /// 동작 줄이기 설정과 무관하게 유지한다.
  static final _wrongHold = AppMotion.dSlow * 2;

  @override
  void dispose() {
    _wrongTimer?.cancel();
    super.dispose();
  }

  void _tap(String w) {
    if (_result != null || _built.contains(w)) return;
    final expected = _answer[_built.length];
    if (w != expected) {
      setState(() {
        _mistakes++;
        _wrong = w;
      });
      _wrongTimer?.cancel();
      _wrongTimer = Timer(_wrongHold, () {
        if (mounted) setState(() => _wrong = null);
      });
      return;
    }
    setState(() {
      _built.add(w);
      _wrong = null;
    });
    if (_built.length == _answer.length) _finish();
  }

  void _finish() {
    setState(() {
      _result = MinigameResult(
        success: true,
        critical: _mistakes == 0 && _long,
        score: _mistakes == 0 ? 1 : 0.5,
        message: _mistakes == 0
            ? (_long
                  ? '"${_answer.join(" ")}" 한 번에 완성. 문장이 길수록 잘 먹힌다.'
                  : '"${_answer.join(" ")}" 깔끔했다.')
            : '$_mistakes번 헤맸지만 결국 보냈다.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;

    return MinigameScaffold(
      title: '문장 만들기',
      badge: '${Stat.label(Stat.talk)} ${widget.ctx.stat(Stat.talk)}',
      instruction: _long
          ? '화술 50 이상이라 카드가 4장이다. 순서대로 눌러 문장을 만든다.'
          : '카드를 순서대로 눌러 문장을 만든다. 화술 50이 넘으면 카드가 늘어난다.',
      result: _result,
      onFinished: () => widget.done(_result!),
      child: CenteredScrollColumn(
        padding: AppInsets.screenX,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 만들고 있는 문장이 주인공이다. 좌측 띠로 화술 게임임을 표시한다.
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpace.huge + AppSpace.xl,
            ),
            child: AppCard(
              accentStripe: t.statColor(Stat.talk),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  _built.isEmpty ? '…' : _built.join(' '),
                  style: context.text.bodyLarge?.copyWith(
                    color: _built.isEmpty
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          // 카드는 흩어 놓고 고르는 물건이라 줄 목록이 아니라 묶음으로 둔다.
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            alignment: WrapAlignment.center,
            children: [
              for (final w in _pool)
                _WordCard(
                  word: w,
                  used: _built.contains(w),
                  wrong: _wrong == w,
                  onTap: () => _tap(w),
                ),
            ],
          ),
          if (_mistakes > 0) ...[
            const SizedBox(height: AppSpace.xxl),
            Align(
              alignment: Alignment.center,
              child: ResultBadge(
                tone: AppTone.danger,
                label: '$_mistakes번 잘못 골랐다',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 문장 카드 한 장. 쓴 카드는 흐려지는 대신 2차 글자색 + 체크로 물러나고,
/// 방금 잘못 누른 카드는 위험색 배경 + 굵은 테두리 + × 세 가지로 말한다.
class _WordCard extends StatelessWidget {
  final String word;
  final bool used;
  final bool wrong;
  final VoidCallback onTap;
  const _WordCard({
    required this.word,
    required this.used,
    required this.wrong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;

    final bg = wrong
        ? t.dangerContainer
        : used
        ? scheme.surfaceContainer
        : scheme.surfaceContainerLowest;
    final fg = wrong
        ? t.onDangerContainer
        : used
        ? t.lockedForeground
        : scheme.onSurface;
    final line = wrong ? t.danger : scheme.outlineVariant;
    final mark = wrong ? Icons.close : (used ? Icons.check : null);

    return Material(
      color: bg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.rMd,
        side: BorderSide(
          color: line,
          width: wrong ? AppBorderWidth.emphasis : AppBorderWidth.hairline,
        ),
      ),
      child: InkWell(
        onTap: used ? null : onTap,
        child: ConstrainedBox(
          // 탭 대상 최소 44. 고정 높이가 아니라 최소 높이다.
          constraints: const BoxConstraints(minHeight: AppSpace.minTouch),
          child: Padding(
            padding: AppInsets.chip,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mark != null) ...[
                  Icon(mark, size: 16, color: wrong ? t.danger : fg),
                  const SizedBox(width: AppSpace.xs),
                ],
                Text(
                  word,
                  style: context.text.labelLarge?.copyWith(
                    fontSize: 16,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
