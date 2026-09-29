import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../ui/design_system.dart';
import '../ui/widgets.dart';
import 'minigame.dart';
import '../ui/keep_all.dart';

/// 9. 선 지키기 — 드립 한 번 더
/// 분위기가 좋을 때 드립을 몇 번까지 치고 멈출지 고르는 게임.
/// 멈추는 것 자체가 성공이고, 선을 넘어 드립이 흑역사가 되는 것만 실패다.
/// 한 번 더 칠수록 다음 드립이 선을 넘을 확률이 오른다(최대 5번).
/// id `drink_limit` 와 클래스 이름은 세이브·이벤트 데이터 호환 때문에 그대로 둔다.
class DrinkLimitGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const DrinkLimitGame({super.key, required this.ctx, required this.done});

  @override
  State<DrinkLimitGame> createState() => _DrinkLimitGameState();
}

class _DrinkLimitGameState extends State<DrinkLimitGame> {
  /// (판이 벌어진 자리, 지금 멈추면 남는 말). 판마다 다른 자리에서 벌어진다 —
  /// 규칙은 같아도 무대가 같으면 두 번째부터는 버튼만 누르는 화면이 된다.
  static const _scenes = [
    ('동아리 뒤풀이. 드립 세 개가 연달아 터졌다.', '지금 멈추면 분위기를 맞춘 것으로 끝난다'),
    ('단톡방이 오랜만에 살아났다. 내 드립에 ㅋㅋ 가 붙는다.', '지금 멈추면 재밌는 사람으로 남는다'),
    ('회식 2차. 부장님이 내 말에 처음 웃었다.', '지금 멈추면 눈치 있는 사람으로 남는다'),
    ('통화가 40분째다. 상대가 계속 웃고 있다.', '지금 끊으면 오늘 통화는 성공이다'),
    ('첫 만남 카페. 어색함이 방금 깨졌다.', '지금 멈추면 첫인상은 여기서 굳는다'),
  ];

  late final (String, String) _scene =
      widget.ctx.vary.one('drink_limit', _scenes);

  /// 지금까지 친 드립 수.
  int _jokes = 0;
  MinigameResult? _result;
  late final Random _rng = widget.ctx.vary.rng('drink_limit_roll');

  /// 자존감이 높을수록 어디까지가 선인지 잘 안다.
  int get _bustPercent {
    final tolerance = widget.ctx.stat(Stat.esteem) ~/ 12;
    return (_jokes * _jokes * 5 - tolerance).clamp(0, 95);
  }

  void _joke() {
    if (_result != null) return;
    if (_rng.nextInt(100) < _bustPercent) {
      // 결과 큐는 스캐폴드가 낸다(실패 = choiceFail + heavy).
      setState(() {
        _result = const MinigameResult.miss('선을 넘었다. 방금 그 드립은 흑역사가 됐다.');
      });
      return;
    }
    // 한 발 더 갔고 아직 살아 있다. 이 게임은 "한 번 더" 를 누르는 사이의
    // 정적이 전부라 그 정적에 한 박자가 필요하다.
    MinigameSfx.step();
    setState(() => _jokes++);
    if (_jokes >= 5) _stop();
  }

  /// 멈추면 언제든 성공. 보상은 드립 수와 무관하게 고정이고,
  /// 분위기를 읽고 일찍 멈춘 판단만 크리티컬로 쳐준다.
  void _stop() {
    if (_result != null) return;
    setState(() {
      _result = MinigameResult(
        success: true,
        critical: _jokes <= 2,
        score: 1,
        message: _jokes == 0
            ? '드립 없이도 대화를 이끌었다.'
            : _jokes <= 2
            ? '$_jokes번에서 멈췄다. 딱 좋았다.'
            : '$_jokes번에서 멈췄다. 아슬아슬했지만 선은 지켰다.',
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
    // 표시용. 실패 결과는 선을 넘긴 경우 하나뿐이다.
    final busted = _result != null && !_result!.success;

    return MinigameScaffold(
      title: '선 지키기',
      badge: '${Stat.label(Stat.esteem)} ${widget.ctx.stat(Stat.esteem)}',
      instruction: '${_scene.$1} 몇 번까지 칠지 고른다. '
          '언제 멈춰도 성공이고, 선을 넘으면 흑역사다. 확률은 화면에 그대로 보인다.',
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
              onPressed: _result == null ? _joke : null,
              child: const Text('한 번 더'),
            ),
          ),
        ],
      ),
      child: CenteredScrollColumn(
        padding: AppInsets.screenX,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 말풍선은 다섯 개가 한 묶음이다. 아이콘 반복을 스크린리더가 다섯 번
          // 읽지 않도록 묶어서 한 줄로 요약한다.
          Semantics(
            container: true,
            label: '드립 $_jokes번',
            child: ExcludeSemantics(
              child: Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < 5; i++)
                    // 선을 넘은 드립은 모양(금지 말풍선)과 위험색이 함께 바뀐다.
                    i == _jokes && busted
                        ? Icon(
                            Icons.comments_disabled_outlined,
                            size: AppSpace.xxxl,
                            color: t.danger,
                          )
                        : Icon(
                            i < _jokes
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            size: AppSpace.xxxl,
                            color: i < _jokes ? scheme.primary : t.gaugeTrack,
                          ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          Text(
            '$_jokes번',
            textAlign: TextAlign.center,
            style: t.numericLarge,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(keepAll(_scene.$2),
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          // 다음 드립의 위험. 숫자 + 막대 + (위험하면) 아이콘으로 함께 말한다.
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
                          : Icons.chat_bubble_outline,
                      size: AppSpace.xl,
                      color: risky ? t.warning : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(keepAll('다음 드립 흑역사 확률 $bust%'),
                        style: t.numericMedium.copyWith(
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
                  semanticLabel: '다음 드립 흑역사 확률',
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
  ///
  /// **한 가지 순서로만 말이 되는 문장만 쓴다.** 예전 3장 세트
  /// `오늘 / 고마웠어 / 진짜` 는 "오늘 고마웠어 진짜" 도 "오늘 진짜 고마웠어" 도
  /// 자연스러운데 한쪽만 정답으로 쳐서, 맞게 말한 플레이어가 틀렸다는 표시를
  /// 받았다(09 §1). 조사·어미로 자리가 고정되는 문장으로 갈았다.
  static const _sets = [
    (['내가', '먼저', '연락할게'], ['다음에는', '내가', '먼저', '연락할게']),
    (['그때', '말한', '거기'], ['그때', '네가', '말한', '거기']),
    (['나', '지금', '나갈게'], ['나', '지금', '바로', '나갈게']),
    (['오늘', '잘', '들어갔어?'], ['오늘', '집에', '잘', '들어갔어?']),
    (['너랑', '있으면', '편해'], ['너랑', '있으면', '이상하게', '편해']),
    (['생각보다', '많이', '웃었어'], ['오늘', '생각보다', '많이', '웃었어']),
    (['내일', '시간', '괜찮아?'], ['내일', '저녁', '시간', '괜찮아?']),
    (['답장', '늦어서', '미안'], ['답장', '이렇게', '늦어서', '미안']),
  ];

  /// 틀린 뒤 몇 번째부터 다음 카드를 짚어 줄지. 두 번 헤매면 길을 알려 준다.
  static const _hintAfter = 2;

  late final bool _long = widget.ctx.stat(Stat.talk) >= 50;
  late final List<String> _answer = () {
    final s = widget.ctx.vary.one('word_order', _sets);
    return _long ? s.$2 : s.$1;
  }();
  late final List<String> _pool =
      widget.ctx.vary.shuffled('word_order_pool', _answer);

  /// 허용하는 실수 횟수. **여기를 넘기면 진다.**
  ///
  /// 예전에는 실패가 없었다(`success: true` 고정). 19번 등장하는 게임이 질 수
  /// 없으면 그건 게임이 아니라 "탭 앞에 붙은 지연" 이다(11 §1-3위).
  /// 카드 수 + 1 로 잡는다: 두 번 틀리면 다음 카드를 브랜드색 테두리 + 화살표로
  /// 짚어 주므로([_hintAfter]), 이 한도에 닿으려면 **짚어 준 카드를 두 번 이상
  /// 무시해야** 한다. 헤매다 지는 게 아니라 안 보고 눌러야 지는 값이다.
  late final int _mistakeLimit = _answer.length + 1;

  final _built = <String>[];
  int _mistakes = 0;
  MinigameResult? _result;

  /// 지금 눌러야 할 카드. 힌트 조건을 넘겼을 때만 값이 있다.
  String? get _hint => _mistakes >= _hintAfter && _built.length < _answer.length
      ? _answer[_built.length]
      : null;

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
      if (_mistakes >= _mistakeLimit) return _fail();
      // 틀렸지만 판은 살아 있다. 실패음이 아니라 진동 한 번으로만 말한다.
      MinigameSfx.nudge();
      _wrongTimer?.cancel();
      _wrongTimer = Timer(_wrongHold, () {
        if (mounted) setState(() => _wrong = null);
      });
      return;
    }
    // 맞는 카드. 한 장씩 밝은 확인음이 붙어야 문장이 쌓이는 게 손에 남는다.
    MinigameSfx.step();
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

  /// 실수 한도를 넘겼다. 보낼 문장이 끝까지 안 만들어진 채로 끝난다.
  void _fail() {
    _wrongTimer?.cancel();
    setState(() {
      _result = MinigameResult(
        success: false,
        score: _built.length / _answer.length,
        message: '$_mistakes번 엉켰다. 쓰다 만 문장을 결국 지웠다.',
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
          ? '화술 50 이상이라 카드가 4장이다. 순서대로 눌러 문장을 만든다. '
                '$_mistakeLimit번 틀리면 문장을 못 보낸다.'
          : '카드를 순서대로 눌러 문장을 만든다. $_mistakeLimit번 틀리면 실패다. '
                '화술 50이 넘으면 카드가 늘어난다.',
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
                  hinted: _hint == w,
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
                // 남은 기회를 숫자로 보여 준다. 실패가 있는 게임이 되었으므로
                // 몇 번 남았는지가 화면에 없으면 지는 이유를 모른다.
                label: _hint == null
                    ? '잘못 고름 $_mistakes / $_mistakeLimit'
                    : '잘못 고름 $_mistakes / $_mistakeLimit · 다음은 테두리 친 카드',
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
/// [hinted] 는 두 번 헤맨 뒤 짚어 주는 다음 카드다(브랜드색 테두리 + 화살표).
class _WordCard extends StatelessWidget {
  final String word;
  final bool used;
  final bool wrong;
  final bool hinted;
  final VoidCallback onTap;
  const _WordCard({
    required this.word,
    required this.used,
    required this.wrong,
    required this.onTap,
    this.hinted = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;

    final bg = wrong
        ? t.dangerContainer
        : used
        ? scheme.surfaceContainer
        : hinted
        ? scheme.primaryContainer
        : scheme.surfaceContainerLowest;
    final fg = wrong
        ? t.onDangerContainer
        : used
        ? t.lockedForeground
        : hinted
        ? scheme.onPrimaryContainer
        : scheme.onSurface;
    final line = wrong
        ? t.danger
        : hinted
        ? scheme.primary
        : scheme.outlineVariant;
    final mark = wrong
        ? Icons.close
        : used
        ? Icons.check
        : hinted
        ? Icons.arrow_forward
        : null;

    return Material(
      color: bg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.rMd,
        side: BorderSide(
          color: line,
          width: wrong || hinted
              ? AppBorderWidth.emphasis
              : AppBorderWidth.hairline,
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
                  Icon(mark, size: 16, color: wrong || hinted ? line : fg),
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
