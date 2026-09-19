import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../ui/design_system.dart';
import '../ui/widgets.dart';
import 'minigame.dart';
import '../ui/keep_all.dart';

/// 보낸 사람 자리. 사진 대신 강조색 이니셜 원형을 쓴다(규격서 §4.3).
class _Initial extends StatelessWidget {
  final String name;
  final CharacterAccent accent;
  const _Initial({required this.name, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
    width: AppSpace.xxxl,
    height: AppSpace.xxxl,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: accent.container, shape: BoxShape.circle),
    child: Text(
      name.isEmpty ? '' : name.substring(0, 1),
      style: context.text.labelMedium?.copyWith(color: accent.onContainer),
    ),
  );
}

/// 8. 단톡방 대응 — 눈치
/// 쏟아지는 메시지 중 답할 사람을 중요도 순서대로 눌러야 한다.
class GroupChatGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const GroupChatGame({super.key, required this.ctx, required this.done});

  @override
  State<GroupChatGame> createState() => _GroupChatGameState();
}

class _GroupChatGameState extends State<GroupChatGame> {
  static const _limit = 10000;
  late final List<_Msg> _msgs;
  final _order = <int>[];
  final _sw = Stopwatch()..start();
  Timer? _tick;
  MinigameResult? _result;

  @override
  void initState() {
    super.initState();
    final p = widget.ctx.partnerName;
    // priority 가 낮을수록 먼저 답해야 한다.
    _msgs = [
      _Msg(p, '내일 시간 돼?', 0),
      _Msg('준호', '야 나 돈 좀', 2),
      _Msg('태현', '짤 봤냐 ㅋㅋㅋ', 4),
      _Msg('엄마', '밥은 먹었니', 1),
      _Msg('동아리', '공지: 이번 주 모임 취소', 3),
    ]..shuffle(Random());
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _result != null) return;
      if (_sw.elapsedMilliseconds >= _limit) {
        _finish();
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

  void _tap(int i) {
    if (_order.contains(i) || _result != null) return;
    setState(() => _order.add(i));
    if (_order.length == _msgs.length) _finish();
  }

  void _finish() {
    _tick?.cancel();
    final picked = _order.map((i) => _msgs[i].priority).toList();
    var correct = 0;
    for (var i = 0; i < picked.length; i++) {
      if (picked[i] == i) correct++;
    }
    final secs = _sw.elapsedMilliseconds / 1000;
    final ok = correct >= 3;
    setState(() {
      _result = MinigameResult(
        success: ok,
        critical: correct == 5 && secs <= 5,
        score: correct / 5,
        message: correct == 5 && secs <= 5
            ? '5초 안에 전부 순서대로. 단톡방의 지배자.'
            : ok
            ? '$correct명은 순서를 맞췄다.'
            : '$correct명뿐이다. ${widget.ctx.partnerName}이(가) 제일 늦게 답을 받았다.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final partnerName = widget.ctx.partnerName;
    return MinigameScaffold(
      title: '단톡방 대응',
      instruction: '10초 안에 답할 순서대로 누른다. 급한 사람이 먼저.',
      timeLeft: 1 - _sw.elapsedMilliseconds / _limit,
      result: _result,
      onFinished: () => widget.done(_result!),
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.screenX,
          vertical: AppSpace.sm,
        ),
        children: [
          for (var i = 0; i < _msgs.length; i++)
            MinigameOption(
              label: '${_msgs[i].who}  ·  ${_msgs[i].text}',
              sub: _order.contains(i) ? '${_order.indexOf(i) + 1}번째로 답함' : null,
              selected: _order.contains(i),
              dimmed: _order.contains(i) && _result == null,
              // 끝나면 누른 칸마다 순서가 맞았는지 공개한다(색 + 테두리 + 아이콘).
              tone: _result == null || !_order.contains(i)
                  ? MinigameOptionTone.neutral
                  : _msgs[i].priority == _order.indexOf(i)
                  ? MinigameOptionTone.correct
                  : MinigameOptionTone.wrong,
              // 상대만 캐릭터 강조색을 받는다. 나머지는 중립.
              leading: _Initial(
                name: _msgs[i].who,
                accent: _msgs[i].who == partnerName
                    ? t.accentFor(widget.ctx.partner?.id)
                    : t.neutralAccent,
              ),
              onTap: () => _tap(i),
            ),
          const SizedBox(height: AppSpace.md),
          Text(keepAll('누른 순서가 곧 답장 순서다.'), style: context.text.bodySmall),
        ],
      ),
    );
  }
}

class _Msg {
  final String who, text;
  final int priority;
  const _Msg(this.who, this.text, this.priority);
}

/// 12. 통화 맞장구 리듬 — 화술
class CallRhythmGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const CallRhythmGame({super.key, required this.ctx, required this.done});

  @override
  State<CallRhythmGame> createState() => _CallRhythmGameState();
}

class _CallRhythmGameState extends State<CallRhythmGame> {
  static const _beats = [
    ('그래서 내가 뭐랬냐면', '응'),
    ('걔가 갑자기 화를 내는 거야', '진짜?'),
    ('내가 잘못한 것도 아닌데', '그러게'),
    ('결국 내가 사과했어', '왜 네가'),
    ('웃기지 않냐 진짜', 'ㅋㅋㅋ'),
    ('아 맞다 너는 오늘 어땠어', '나는…'),
  ];

  int _index = 0;
  int _hits = 0;
  int _combo = 0;
  int _maxCombo = 0;
  bool _open = false;
  Timer? _timer;
  MinigameResult? _result;

  /// 박자마다 맞췄는지(true) 놓쳤는지(false)의 기록. 판정은 [_hits] 로 하고
  /// 이 목록은 화면 표시에만 쓴다 — 놓친 순간이 눈에 남아야 다음 박자를 노린다.
  final _marks = <bool>[];

  @override
  void initState() {
    super.initState();
    _next();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _next() {
    if (_index >= _beats.length) return _finish();
    setState(() => _open = false);
    _timer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _open = true);
      // 화술이 높을수록 창이 넓다.
      final window = 700 + widget.ctx.stat(Stat.talk) * 6;
      _timer = Timer(Duration(milliseconds: window), () {
        if (!mounted || !_open) return;
        setState(() {
          _open = false;
          _combo = 0;
          _index++;
          _marks.add(false);
        });
        _next();
      });
    });
  }

  void _tap() {
    if (!_open || _result != null) return;
    _timer?.cancel();
    setState(() {
      _hits++;
      _combo++;
      _maxCombo = max(_maxCombo, _combo);
      _open = false;
      _index++;
      _marks.add(true);
    });
    _next();
  }

  void _finish() {
    final full = _hits == _beats.length;
    setState(() {
      _result = MinigameResult(
        success: _hits >= 4,
        critical: full,
        score: _hits / _beats.length,
        message: full
            ? '풀 콤보. 통화가 30분 더 이어졌다.'
            : _hits >= 4
            ? '$_hits번 맞췄다. 듣고 있다는 게 전해졌다.'
            : '$_hits번. "너 듣고 있어?" 소리를 들었다.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final line = _index < _beats.length ? _beats[_index] : _beats.last;
    final done = _index.clamp(0, _beats.length);
    // 조작 대상은 가운데 원 하나. 열렸을 때만 색·크기·테두리가 동시에 바뀐다.
    const dial = AppSpace.huge * 4; // 160

    return MinigameScaffold(
      title: '맞장구',
      badge: '${Stat.label(Stat.talk)} ${widget.ctx.stat(Stat.talk)}',
      instruction: '말풍선이 켜지면 바로 누른다. 화술이 높을수록 창이 넓다.',
      result: _result,
      onFinished: () => widget.done(_result!),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: CenteredScrollColumn(
          padding: AppInsets.screenX,
          children: [
            // 상대가 하는 말. 이벤트 화면의 상대 말풍선과 같은 토큰.
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
                    keepAll(line.$1),
                    style: t.bubbleText.copyWith(color: t.onBubbleTheirs),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xxxl),
            AnimatedScale(
              scale: _open ? 1 : 0.94,
              duration: AppMotion.fast(context),
              curve: AppMotion.curve(context),
              child: AnimatedContainer(
                duration: AppMotion.fast(context),
                curve: AppMotion.curve(context),
                width: dial,
                height: dial,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _open ? scheme.primary : scheme.surfaceContainer,
                  border: Border.all(
                    color: _open ? scheme.primary : scheme.outlineVariant,
                    width: _open
                        ? AppBorderWidth.emphasis
                        : AppBorderWidth.hairline,
                  ),
                ),
                alignment: Alignment.center,
                padding: AppInsets.card,
                child: Text(
                  _open ? line.$2 : '…',
                  textAlign: TextAlign.center,
                  style: context.text.headlineSmall?.copyWith(
                    color: _open ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xxl),
            // 진행도는 막대보다 박자 하나하나로 읽는 게 낫다. 남은 박자는 빈 원,
            // 맞춘 박자는 채운 체크, 놓친 박자는 뚫린 원 — 색 + 모양 두 신호다.
            Semantics(
              container: true,
              label: '맞장구 $done / ${_beats.length}',
              child: ExcludeSemantics(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpace.xs,
                  runSpacing: AppSpace.xs,
                  children: [
                    for (var i = 0; i < _beats.length; i++)
                      Icon(
                        i >= _marks.length
                            ? Icons.circle_outlined
                            : _marks[i]
                            ? Icons.check_circle
                            : Icons.remove_circle_outline,
                        size: AppSpace.xl,
                        color: i >= _marks.length
                            ? t.gaugeTrack
                            : _marks[i]
                            ? t.success
                            : t.danger,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text(keepAll('$done / ${_beats.length}   콤보 $_combo'), style: t.numericSmall),
          ],
        ),
      ),
    );
  }
}

/// 11. 프로필 스와이프 — 첫 만남
class ProfileSwipeGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const ProfileSwipeGame({super.key, required this.ctx, required this.done});

  @override
  State<ProfileSwipeGame> createState() => _ProfileSwipeGameState();
}

class _ProfileSwipeGameState extends State<ProfileSwipeGame> {
  /// (제목, 한 줄, 호응 확률, 아이콘). 확률은 판정용이고 아이콘은 표시용이다.
  /// 여덟 장이 전부 같은 사람 실루엣이면 카드가 넘어간 것도 눈에 안 띈다.
  static const _profiles = [
    ('러닝하는 사람', '주 3회 한강. 대화는 짧게.', 0.5, Icons.directions_run),
    ('책 읽는 사람', '조용한 카페를 좋아합니다.', 0.6, Icons.menu_book_outlined),
    ('여행 사진만 12장', '다음 달 유럽 갑니다.', 0.25, Icons.flight_takeoff),
    ('고양이 두 마리', '집사 구함 (농담)', 0.7, Icons.pets),
    ('프로필 사진 없음', '만나서 얘기해요.', 0.15, Icons.person_off_outlined),
    ('맛집 리스트 보유', '먹는 거 좋아하는 분.', 0.65, Icons.restaurant_outlined),
    ('헬스장 거울샷', '3대 400.', 0.3, Icons.fitness_center),
    ('그림 그리는 사람', '주말엔 전시 보러 다녀요.', 0.55, Icons.brush_outlined),
  ];

  int _index = 0;
  int _matches = 0;
  final _log = <String>[];

  /// 마지막 결과가 매칭이었는지. 배지 색을 고르는 표시용이며 판정과 무관하다.
  bool? _lastHit;
  MinigameResult? _result;
  late final Random _rng = Random(widget.ctx.state.seed ^ widget.ctx.state.day);

  void _swipe(bool right) {
    if (_result != null) return;
    final p = _profiles[_index];
    if (right) {
      // 매력이 높을수록 매칭 확률이 오른다.
      final chance = (p.$3 * (0.55 + widget.ctx.stat(Stat.charm) / 130)).clamp(
        0.05,
        0.95,
      );
      final hit = _rng.nextDouble() < chance;
      if (hit) _matches++;
      _log.add('${p.$1} · ${hit ? '매칭' : '무응답'}');
      _lastHit = hit;
    }
    setState(() {
      _index++;
      if (_index >= _profiles.length) _finish();
    });
  }

  void _finish() {
    _result = MinigameResult(
      success: _matches >= 2,
      critical: _matches >= 4,
      score: _matches / 4,
      message: _matches >= 4
          ? '$_matches명과 매칭. 알림이 멈추지 않는다.'
          : _matches >= 2
          ? '$_matches명과 매칭됐다.'
          : _matches == 1
          ? '한 명. 그래도 0은 아니다.'
          : '매칭 0. 프로필부터 다시 써야 한다.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final done = _index >= _profiles.length;
    final p = done ? _profiles.last : _profiles[_index];
    final seen = _index.clamp(0, _profiles.length);

    return MinigameScaffold(
      title: '프로필 고르기',
      badge: '${Stat.label(Stat.charm)} ${widget.ctx.stat(Stat.charm)}',
      instruction: '오늘 볼 수 있는 프로필 8장. 매력이 높을수록 호응 확률이 오른다.',
      result: _result,
      onFinished: () => widget.done(_result!),
      child: CenteredScrollColumn(
        padding: AppInsets.screenX,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 카드 한 장이 주인공. 높이를 고정하지 않고 최소 높이만 줘서
          // 카드가 바뀌어도 아래 버튼이 덜 흔들린다.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.huge * 4),
            // 카드가 넘어갔다는 사실 자체가 피드백이다. 글자만 바뀌면 탭이
            // 먹혔는지 알 수 없어서, 다음 장은 짧은 페이드로 갈아든다
            // (동작 줄이기에서는 AppMotion 이 0ms 를 주므로 즉시 교체).
            child: AnimatedSwitcher(
              duration: AppMotion.base(context),
              switchInCurve: AppMotion.curve(context),
              switchOutCurve: AppMotion.curve(context),
              child: AppCard(
                key: ValueKey(_index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: AppSpace.huge + AppSpace.xxl, // 64
                      height: AppSpace.huge + AppSpace.xxl,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        p.$4,
                        size: AppSpace.xxxl,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      keepAll(p.$1),
                      textAlign: TextAlign.center,
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      keepAll(p.$2),
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          // 넘기기와 관심은 무게가 다르다. 하나만 채운 원으로 위계를 준다.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundBtn(
                icon: Icons.close,
                semanticLabel: '넘기기',
                filled: false,
                onTap: done ? null : () => _swipe(false),
              ),
              _RoundBtn(
                icon: Icons.favorite,
                semanticLabel: '관심 있음',
                filled: true,
                onTap: done ? null : () => _swipe(true),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          AppProgressBar(
            value: seen / _profiles.length,
            semanticLabel: '프로필 고르기',
          ),
          const SizedBox(height: AppSpace.sm),
          Center(
            child: Text(keepAll('$seen / ${_profiles.length}   매칭 $_matches'),
              style: t.numericSmall,
            ),
          ),
          if (_log.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            // 직전 결과. 색 + 아이콘 + 낱말이 함께 움직인다.
            Align(
              alignment: Alignment.center,
              child: ResultBadge(
                tone: _lastHit == true ? AppTone.success : AppTone.neutral,
                label: _log.last,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 원형 조작 버튼. 지름 최소 64(규격서 §2.8).
class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final bool filled;
  final VoidCallback? onTap;
  const _RoundBtn({
    required this.icon,
    required this.semanticLabel,
    required this.filled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final bg = filled ? scheme.primary : scheme.surfaceContainerHigh;
    final fg = filled ? scheme.onPrimary : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: bg,
        shape: CircleBorder(
          side: filled
              ? BorderSide.none
              : BorderSide(
                  color: scheme.outlineVariant,
                  width: AppBorderWidth.hairline,
                ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSpace.huge + AppSpace.xxl, // 64
              minHeight: AppSpace.huge + AppSpace.xxl,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Icon(icon, color: fg, size: AppSpace.xxl + AppSpace.xs),
            ),
          ),
        ),
      ),
    );
  }
}
