import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/models.dart';
import 'minigame.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return MinigameScaffold(
      title: '단톡방 대응',
      instruction: '10초 안에 답할 순서대로 누른다. 급한 사람이 먼저.',
      timeLeft: 1 - _sw.elapsedMilliseconds / _limit,
      result: _result,
      onFinished: () => widget.done(_result!),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          for (var i = 0; i < _msgs.length; i++)
            MinigameOption(
              label: '${_msgs[i].who}  ·  ${_msgs[i].text}',
              sub: _order.contains(i) ? '${_order.indexOf(i) + 1}번째로 답함' : null,
              selected: _order.contains(i),
              dimmed: _order.contains(i),
              onTap: () => _tap(i),
            ),
          const SizedBox(height: 12),
          Text(
            '누른 순서가 곧 답장 순서다.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
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
    final scheme = Theme.of(context).colorScheme;
    final line = _index < _beats.length ? _beats[_index] : _beats.last;
    return MinigameScaffold(
      title: '맞장구',
      instruction: '말풍선이 켜지면 바로 누른다. 화술이 높을수록 창이 넓다.',
      result: _result,
      onFinished: () => widget.done(_result!),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: CenteredScrollColumn(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(line.$1),
              ),
            ),
            const SizedBox(height: 32),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _open ? scheme.primary : scheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Text(
                _open ? line.$2 : '…',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _open ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${_index.clamp(0, _beats.length)} / ${_beats.length}   콤보 $_combo',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
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
  static const _profiles = [
    ('러닝하는 사람', '주 3회 한강. 대화는 짧게.', 0.5),
    ('책 읽는 사람', '조용한 카페를 좋아합니다.', 0.6),
    ('여행 사진만 12장', '다음 달 유럽 갑니다.', 0.25),
    ('고양이 두 마리', '집사 구함 (농담)', 0.7),
    ('프로필 사진 없음', '만나서 얘기해요.', 0.15),
    ('맛집 리스트 보유', '먹는 거 좋아하는 분.', 0.65),
    ('헬스장 거울샷', '3대 400.', 0.3),
    ('그림 그리는 사람', '주말엔 전시 보러 다녀요.', 0.55),
  ];

  int _index = 0;
  int _matches = 0;
  final _log = <String>[];
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
    final scheme = Theme.of(context).colorScheme;
    final done = _index >= _profiles.length;
    final p = done ? _profiles.last : _profiles[_index];
    return MinigameScaffold(
      title: '프로필 고르기',
      instruction: '오늘 볼 수 있는 프로필 8장. 매력이 높을수록 호응 확률이 오른다.',
      result: _result,
      onFinished: () => widget.done(_result!),
      child: CenteredScrollColumn(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 64,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  p.$1,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundBtn(
                icon: Icons.close,
                color: scheme.outline,
                onTap: done ? null : () => _swipe(false),
              ),
              _RoundBtn(
                icon: Icons.favorite,
                color: scheme.primary,
                onTap: done ? null : () => _swipe(true),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${_index.clamp(0, _profiles.length)} / ${_profiles.length}   매칭 $_matches',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (_log.isNotEmpty)
            Text(
              _log.last,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _RoundBtn({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.surface,
          size: 28,
        ),
      ),
    ),
  );
}
