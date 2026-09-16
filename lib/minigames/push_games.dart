import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/models.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final bust = _bustPercent;
    return MinigameScaffold(
      title: '선 지키기',
      instruction: '분위기는 맞추되 내 주량을 넘기지 않는다. '
          '언제 멈춰도 성공이고, 확률은 화면에 그대로 보인다.',
      result: _result,
      onFinished: () => widget.done(_result!),
      child: CenteredScrollColumn(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  i < _glasses ? Icons.local_bar : Icons.local_bar_outlined,
                  size: 34,
                  color: i < _glasses ? scheme.primary : scheme.outlineVariant,
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            '$_glasses잔',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '지금 멈추면 분위기를 맞춘 것으로 끝난다',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: bust >= 40
                  ? scheme.errorContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '다음 잔 흑역사 확률 $bust%',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: bust >= 40 ? scheme.onErrorContainer : scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _result == null ? _stop : null,
                  child: const Text('여기까지'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _result == null ? _drink : null,
                  child: const Text('한 잔 더'),
                ),
              ),
            ],
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

  void _tap(String w) {
    if (_result != null || _built.contains(w)) return;
    final expected = _answer[_built.length];
    if (w != expected) {
      setState(() => _mistakes++);
      return;
    }
    setState(() => _built.add(w));
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
    final scheme = Theme.of(context).colorScheme;
    return MinigameScaffold(
      title: '문장 만들기',
      instruction: _long
          ? '화술 50 이상이라 카드가 4장이다. 순서대로 눌러 문장을 만든다.'
          : '카드를 순서대로 눌러 문장을 만든다. 화술 50이 넘으면 카드가 늘어난다.',
      result: _result,
      onFinished: () => widget.done(_result!),
      child: CenteredScrollColumn(
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _built.isEmpty ? '…' : _built.join(' '),
              style: const TextStyle(fontSize: 17, height: 1.4),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final w in _pool)
                ActionChip(
                  label: Text(w, style: const TextStyle(fontSize: 16)),
                  onPressed: _built.contains(w) ? null : () => _tap(w),
                  backgroundColor: _built.contains(w)
                      ? scheme.surfaceContainerLow
                      : null,
                  labelStyle: TextStyle(
                    color: _built.contains(w)
                        ? scheme.outline
                        : scheme.onSurface,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (_mistakes > 0)
            Text(
              '$_mistakes번 잘못 골랐다',
              style: TextStyle(fontSize: 12, color: scheme.error),
            ),
        ],
      ),
    );
  }
}
