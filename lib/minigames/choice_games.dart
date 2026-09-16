import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../ui/design_system.dart';
import '../ui/widgets.dart';
import 'minigame.dart';

/// 4. 표정 읽기 퀴즈 — 눈치
class ReadEmotionGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const ReadEmotionGame({super.key, required this.ctx, required this.done});

  @override
  State<ReadEmotionGame> createState() => _ReadEmotionGameState();
}

class _ReadEmotionGameState extends State<ReadEmotionGame> {
  static const _rounds = [
    ('괜찮아 ㅎㅎ 신경 쓰지 마', '🙂', ['서운함', '진짜 괜찮음', '화남', '피곤함'], 0),
    ('아 그렇구나', '…', ['관심 있음', '대화 끊고 싶음', '기분 좋음', '졸림'], 1),
    ('너 마음대로 해', '🙃', ['허락', '삐짐', '무관심', '신남'], 1),
    ('오늘 좀 피곤하다', '😮‍💨', ['위로 원함', '약속 취소 원함', '자랑', '화남'], 0),
  ];

  late final int _limit = 5000 + widget.ctx.stat(Stat.sense) * 30;
  int _round = 0;
  int _correct = 0;
  int? _picked;
  final _sw = Stopwatch()..start();
  Timer? _tick;
  MinigameResult? _result;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _result != null) return;
      if (_sw.elapsedMilliseconds >= _limit) {
        _pick(-1);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _pick(int i) {
    if (_picked != null || _result != null) return;
    final answer = _rounds[_round].$4;
    if (i == answer) _correct++;
    setState(() => _picked = i);
    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      if (_round + 1 >= _rounds.length) return _finish();
      setState(() {
        _round++;
        _picked = null;
        _sw
          ..reset()
          ..start();
      });
    });
  }

  void _finish() {
    _tick?.cancel();
    setState(() {
      _result = MinigameResult(
        success: _correct >= 3,
        critical: _correct == _rounds.length,
        score: _correct / _rounds.length,
        message: _correct == _rounds.length
            ? '전부 맞췄다. 속마음이 한 번 공짜로 보인다.'
            : _correct >= 3
            ? '$_correct개 맞췄다. 눈치가 늘었다.'
            : '$_correct개. 아직 표정을 못 읽는다.',
      );
    });
  }

  /// 고른 뒤의 정답 공개. 색 + 테두리 + 아이콘이 함께 바뀐다.
  MinigameOptionTone _toneFor(int i, int answer) {
    if (_picked == null) return MinigameOptionTone.neutral;
    if (i == answer) return MinigameOptionTone.correct;
    if (i == _picked) return MinigameOptionTone.wrong;
    return MinigameOptionTone.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = _rounds[_round];

    return MinigameScaffold(
      title: '진짜 감정은?',
      badge: '${Stat.label(Stat.sense)} ${widget.ctx.stat(Stat.sense)}',
      instruction:
          '${(_limit / 1000).toStringAsFixed(1)}초 안에 고른다. '
          '눈치가 높을수록 시간이 늘어난다.',
      timeLeft: _picked == null ? 1 - _sw.elapsedMilliseconds / _limit : null,
      result: _result,
      onFinished: () => widget.done(_result!),
      child: ListView(
        padding: AppInsets.screenX,
        children: [
          // 읽어야 할 대상. 표정과 말이 한 덩어리로 보여야 한다.
          AppCard(
            child: Column(
              children: [
                Text(r.$2, style: context.text.displayLarge),
                const SizedBox(height: AppSpace.sm),
                Text(
                  '"${r.$1}"',
                  textAlign: TextAlign.center,
                  style: context.text.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          for (var i = 0; i < r.$3.length; i++)
            MinigameOption(
              label: r.$3[i],
              selected: _picked == i,
              sub: _picked != null && i == r.$4 ? '정답' : null,
              tone: _toneFor(i, r.$4),
              dimmed:
                  _picked != null &&
                  _toneFor(i, r.$4) == MinigameOptionTone.neutral,
              onTap: () => _pick(i),
            ),
          const SizedBox(height: AppSpace.md),
          Text(
            '${_round + 1} / ${_rounds.length}',
            textAlign: TextAlign.center,
            style: t.numericSmall,
          ),
        ],
      ),
    );
  }
}

/// 5. 짤 고르기 — 화술
class PickMemeGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const PickMemeGame({super.key, required this.ctx, required this.done});

  @override
  State<PickMemeGame> createState() => _PickMemeGameState();
}

class _PickMemeGameState extends State<PickMemeGame> {
  static const _memes = [
    ('dry', '정색하는 고양이', '무표정으로 쳐다보는 고양이'),
    ('loud', '박수치며 웃는 사람', '대문짝만한 ㅋㅋㅋ 자막'),
    ('witty', '안경 고쳐 쓰는 짤', '"흥미롭군요" 자막'),
    ('meme', '픽셀 강아지', '알 사람만 아는 옛날 짤'),
    ('warm', '하트 뿅뿅 곰', '따뜻한 파스텔톤'),
  ];

  int? _picked;
  MinigameResult? _result;
  late final List<int> _order = () {
    final idx = List.generate(_memes.length, (i) => i);
    idx.shuffle(Random(widget.ctx.state.seed ^ widget.ctx.state.day));
    return idx.take(4).toList()..shuffle(Random(widget.ctx.state.day));
  }();

  bool get _hasAnswer => _order.any((i) => _memes[i].$1 == widget.ctx.humor);

  void _pick(int slot) {
    if (_picked != null) return;
    final meme = _memes[_order[slot]];
    final match = meme.$1 == widget.ctx.humor;
    // 상대 취향이 후보에 없으면 화술로 커버한다.
    final ok = match || (!_hasAnswer && widget.ctx.stat(Stat.talk) >= 45);
    setState(() {
      _picked = slot;
      _result = MinigameResult(
        success: ok,
        critical: match && widget.ctx.stat(Stat.talk) >= 55,
        score: ok ? 1 : 0,
        message: match
            ? '${widget.ctx.partnerName}이(가) 같은 시리즈 짤로 답했다.'
            : ok
            ? '취향은 아니었지만 말로 살렸다.'
            : '읽씹. 짤은 취향을 탄다.',
      );
    });
  }

  /// 고른 칸만 결과 색을 입는다. 고르지 않은 칸의 정답 여부는 밝히지 않는다
  /// (다음 판의 난이도를 건드리지 않기 위해서다).
  MinigameOptionTone _toneFor(int slot) {
    if (_picked != slot || _result == null) return MinigameOptionTone.neutral;
    return _result!.success
        ? MinigameOptionTone.correct
        : MinigameOptionTone.wrong;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return MinigameScaffold(
      title: '짤 고르기',
      badge: '${Stat.label(Stat.talk)} ${widget.ctx.stat(Stat.talk)}',
      instruction: '${widget.ctx.partnerName}의 유머 코드에 맞는 짤을 고른다.',
      result: _result,
      onFinished: () => widget.done(_result!),
      child: ListView(
        padding: AppInsets.screenX,
        children: [
          // 답해야 할 말. 이벤트 화면의 상대 말풍선과 같은 옷을 입는다.
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              child: Container(
                padding: AppInsets.bubble,
                decoration: BoxDecoration(
                  color: t.bubbleTheirs,
                  borderRadius: AppRadius.bubble(mine: false),
                  border: Border.all(
                    color: t.bubbleBorder,
                    width: AppBorderWidth.hairline,
                  ),
                ),
                child: Text(
                  '"방금 진짜 웃긴 일 있었는데 ㅋㅋㅋ"',
                  style: t.bubbleText.copyWith(color: t.onBubbleTheirs),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          for (var i = 0; i < _order.length; i++)
            MinigameOption(
              label: _memes[_order[i]].$2,
              sub: _memes[_order[i]].$3,
              selected: _picked == i,
              dimmed: _picked != null && _picked != i,
              tone: _toneFor(i),
              leading: Icon(
                Icons.image_outlined,
                size: AppSpace.xl,
                color: context.scheme.onSurfaceVariant,
              ),
              onTap: () => _pick(i),
            ),
        ],
      ),
    );
  }
}

/// 10. 옷장 코디 — 매력
class OutfitGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const OutfitGame({super.key, required this.ctx, required this.done});

  @override
  State<OutfitGame> createState() => _OutfitGameState();
}

class _OutfitGameState extends State<OutfitGame> {
  static const _slots = ['상의', '하의', '신발'];
  static const _slotIcons = [
    Icons.checkroom,
    Icons.dry_cleaning,
    Icons.hiking,
  ];
  static const _items = [
    [
      ('검정 니트', ['조용한', '전시']),
      ('후드티', ['가성비', '실내', '게임']),
      ('셔츠', ['브런치', '전시']),
      ('맨투맨', ['산책', '추억']),
    ],
    [
      ('슬랙스', ['전시', '브런치']),
      ('청바지', ['가성비', '산책', '길거리']),
      ('트레이닝 팬츠', ['실내', '게임', '운동']),
      ('면바지', ['추억', '산책']),
    ],
    [
      ('구두', ['브런치', '전시']),
      ('운동화', ['산책', '가성비', '운동']),
      ('슬리퍼', ['실내', '게임']),
      ('부츠', ['야경', '야시장']),
    ],
  ];

  final _picked = <int, int>{};
  MinigameResult? _result;

  int get _matches {
    var n = 0;
    for (final e in _picked.entries) {
      final tags = _items[e.key][e.value].$2;
      if (tags.any(widget.ctx.tags.contains)) n++;
    }
    return n;
  }

  void _finish() {
    final m = _matches;
    setState(() {
      _result = MinigameResult(
        success: m >= 2,
        critical: m == 3,
        score: m / 3,
        message: m == 3
            ? '${widget.ctx.partnerName}이(가) 오늘 옷 좋다고 먼저 말했다.'
            : m >= 2
            ? '나쁘지 않은 조합이었다.'
            : '거울을 다시 봤어야 했다.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return MinigameScaffold(
      title: '옷장',
      instruction:
          '${widget.ctx.partnerName}의 취향: ${widget.ctx.tags.join(", ")}',
      result: _result,
      onFinished: () => widget.done(_result!),
      // 세 칸을 다 채워야 나갈 수 있다. 버튼이 스크롤과 함께 사라지면
      // 무엇이 남았는지 알기 어려우므로 아래에 고정한다.
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _picked.length == 3 && _result == null ? _finish : null,
          child: const Text('이걸로 나간다'),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.screenX,
          vertical: AppSpace.sm,
        ),
        children: [
          for (var s = 0; s < _slots.length; s++) ...[
            if (s > 0) const SizedBox(height: AppSpace.sectionGap),
            SectionHeader(title: _slots[s]),
            for (var i = 0; i < _items[s].length; i++)
              MinigameOption(
                label: _items[s][i].$1,
                selected: _picked[s] == i,
                leading: Icon(
                  _slotIcons[s],
                  size: AppSpace.xl,
                  color: _picked[s] == i
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                onTap: _result != null
                    ? null
                    : () => setState(() => _picked[s] = i),
              ),
          ],
        ],
      ),
    );
  }
}

/// 3. 데이트 코스 짜기 — 돈
class DateCourseGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const DateCourseGame({super.key, required this.ctx, required this.done});

  @override
  State<DateCourseGame> createState() => _DateCourseGameState();
}

class _DateCourseGameState extends State<DateCourseGame> {
  static const _places = [
    ('한강 산책', 0, ['산책', '가성비', '야경']),
    ('동네 전시회', 12, ['전시', '조용한']),
    ('분식집', 8, ['분식', '가성비', '추억']),
    ('브런치 카페', 25, ['브런치', '조용한']),
    ('야시장', 15, ['야시장', '길거리', '사진']),
    ('오마카세', 90, ['조용한']),
    ('보드게임 카페', 18, ['실내', '게임']),
    ('옛날 학교 앞', 5, ['추억', '사진', '산책']),
  ];

  final _picked = <int>[];
  MinigameResult? _result;

  int get _cost => _picked.fold(0, (a, i) => a + _places[i].$2);
  int get _matches {
    final tags = <String>{};
    for (final i in _picked) {
      tags.addAll(_places[i].$3.where(widget.ctx.tags.contains));
    }
    return tags.length;
  }

  void _toggle(int i) {
    if (_result != null) return;
    setState(() {
      if (_picked.contains(i)) {
        _picked.remove(i);
      } else if (_picked.length < 3) {
        _picked.add(i);
      }
    });
  }

  void _finish() {
    final budget = min(widget.ctx.budget, widget.ctx.stat(Stat.money));
    final over = _cost > budget;
    final m = _matches;
    setState(() {
      _result = MinigameResult(
        success: !over && m >= 2,
        critical: !over && m >= 3,
        score: over ? 0 : m / 3,
        message: over
            ? '예산 $budget을 ${_cost - budget} 초과했다. 계산대에서 얼어붙었다.'
            : m >= 3
            ? '취향 $m개 적중. 다음 약속을 상대가 먼저 잡았다.'
            : m >= 2
            ? '무난한 코스였다.'
            : '가긴 갔는데 기억에 남는 게 없다.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final budget = min(widget.ctx.budget, widget.ctx.stat(Stat.money));
    final over = _cost > budget;
    final spent = budget <= 0 ? (_cost > 0 ? 1.0 : 0.0) : _cost / budget;

    return MinigameScaffold(
      title: '코스 짜기',
      instruction:
          '3곳을 고른다. 예산 $budget · '
          '${widget.ctx.partnerName}의 취향: ${widget.ctx.tags.join(", ")}',
      result: _result,
      onFinished: () => widget.done(_result!),
      // 예산은 고르는 내내 보여야 하는 정보다. 목록과 함께 스크롤되면
      // 초과를 모른 채 고르게 되므로 아래에 고정한다.
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppProgressBar(
            value: spent,
            semanticLabel: '예산',
            fill: over ? t.danger : scheme.primary,
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (over) ...[
                Icon(Icons.warning_amber_rounded, size: 16, color: t.danger),
                const SizedBox(width: AppSpace.xs),
              ],
              Flexible(
                child: Text(
                  '합계 $_cost / $budget${over ? "  (예산 초과)" : ""}',
                  textAlign: TextAlign.center,
                  style: t.numericMedium.copyWith(
                    color: over ? t.danger : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _picked.length == 3 && _result == null ? _finish : null,
              child: const Text('이 코스로 간다'),
            ),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.screenX,
          vertical: AppSpace.sm,
        ),
        children: [
          for (var i = 0; i < _places.length; i++)
            MinigameOption(
              label: _places[i].$1,
              // 값은 오른쪽에 tabular 로 세워 줄마다 자리수가 흔들리지 않는다.
              trailingLabel: _places[i].$2 == 0 ? '무료' : '${_places[i].$2}',
              selected: _picked.contains(i),
              dimmed: !_picked.contains(i) && _picked.length >= 3,
              leading: Icon(
                Icons.place_outlined,
                size: AppSpace.xl,
                color: _picked.contains(i)
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
              onTap: () => _toggle(i),
            ),
        ],
      ),
    );
  }
}
