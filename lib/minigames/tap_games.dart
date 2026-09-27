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

  /// 단톡방 세 채. 판마다 한 채만 쓴다. `priority` 가 낮을수록 먼저 답해야 하고,
  /// 그 이유(`why`)는 **고르기 전에 화면에 적혀 있다** — 예전에는 순서의 근거가
  /// 어디에도 없어서, 맞히면 운이고 틀리면 게임 탓이었다(09 §1).
  static const _rooms = [
    [
      ('@partner', '내일 시간 돼?', 0, '지금 안 잡으면 다른 약속이 들어간다'),
      ('엄마', '밥은 먹었니', 1, '어제 전화도 못 받았다'),
      ('준호', '야 나 돈 좀', 2, '급하다지만 늘 급하다'),
      ('동아리', '공지: 이번 주 모임 취소', 3, '공지. 한 마디만 남기면 된다'),
      ('태현', '짤 봤냐 ㅋㅋㅋ', 4, '언제 답해도 똑같다'),
    ],
    [
      ('@partner', '나 지금 너희 집 앞인데', 0, '밖에 서서 기다리는 중이다'),
      ('부장님', '내일 자료 됐나?', 1, '내일 아침까지다'),
      ('누나', '택배 왔어?', 2, '오늘 안에만 답하면 된다'),
      ('과대', '설문 링크 참여 부탁', 3, '마감이 다음 주다'),
      ('준호', 'ㅋㅋㅋㅋㅋㅋ', 4, '답할 게 없다'),
    ],
    [
      ('@partner', '아까 내가 한 말 기분 나빴어?', 0, '오해는 빨리 풀수록 싸다'),
      ('태현', '야 나 지금 응급실', 1, '진짜면 큰일이다'),
      ('동아리', '오늘 회비 입금자 명단', 2, '내 이름이 빠져 있다'),
      ('엄마', '사진 보냄~', 3, '급하지 않다'),
      ('모르는 번호', '(광고) 대출 안내', 4, '답할 필요가 없다'),
    ],
  ];

  late final List<_Msg> _msgs = () {
    final v = widget.ctx.vary;
    final room = v.one('group_chat', _rooms);
    final p = widget.ctx.partnerName;
    final msgs = [
      for (final m in room)
        _Msg(m.$1 == '@partner' ? p : m.$1, m.$2, m.$3, m.$4),
    ];
    // 자리 배치도 씨앗에서 나온다. 예전에는 `Random()` 이라 같은 판을 다시 볼 수
    // 없었고 시뮬레이션·테스트가 재현되지 않았다.
    return v.shuffled('group_chat_slot', msgs);
  }();

  final _order = <int>[];
  final _sw = Stopwatch()..start();
  Timer? _tick;
  MinigameResult? _result;

  @override
  void initState() {
    super.initState();
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

  /// 마지막 선택 하나를 무른다. 손가락이 미끄러진 것까지 실패로 세면
  /// 플레이어는 자기가 진 이유를 자기 실수로 받아들이지 못한다.
  void _undo() {
    if (_result != null || _order.isEmpty) return;
    setState(_order.removeLast);
  }

  /// 실제로 답한 순서. 시간이 다 돼 못 누른 메시지는 뒤로 밀린다.
  List<int> get _ranking => [
    ..._order,
    for (var i = 0; i < _msgs.length; i++)
      if (!_order.contains(i)) i,
  ];

  /// 뒤집힌 쌍의 수. 0 이면 완벽한 순서다.
  ///
  /// 예전 판정은 "n번째로 누른 사람의 우선순위가 정확히 n" 인 칸만 셌다.
  /// 한 칸만 밀려도 뒤가 전부 오답이 돼서, 거의 맞힌 판과 찍은 판의 점수가
  /// 같았다. 쌍 단위로 세면 "한 번 순서를 놓쳤다" 가 한 번으로만 센다.
  int get _inversions {
    final r = _ranking;
    var bad = 0;
    for (var a = 0; a < r.length; a++) {
      for (var b = a + 1; b < r.length; b++) {
        if (_msgs[r[a]].priority > _msgs[r[b]].priority) bad++;
      }
    }
    return bad;
  }

  /// 이 메시지가 어떤 쌍에서도 순서를 어기지 않았는지.
  bool _clean(int i) {
    final r = _ranking;
    final at = r.indexOf(i);
    for (var k = 0; k < r.length; k++) {
      if (k == at) continue;
      final earlier = k < at;
      final higher = _msgs[r[k]].priority < _msgs[i].priority;
      if (earlier != higher) return false;
    }
    return true;
  }

  void _finish() {
    _tick?.cancel();
    final bad = _inversions;
    final secs = _sw.elapsedMilliseconds / 1000;
    final ok = bad <= 2;
    final perfect = bad == 0;
    setState(() {
      _result = MinigameResult(
        success: ok,
        critical: perfect && secs <= 6,
        // 10쌍 기준. 다 뒤집혀도 0 아래로 내려가지 않는다.
        score: (1 - bad / 10).clamp(0.0, 1.0),
        message: perfect && secs <= 6
            ? '6초 안에 전부 순서대로. 단톡방의 지배자.'
            : perfect
            ? '순서를 하나도 안 틀렸다.'
            : ok
            ? '$bad번 순서가 엇갈렸지만 급한 사람은 챙겼다.'
            : '$bad번 엇갈렸다. ${widget.ctx.partnerName}이(가) 제일 늦게 답을 받았다.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final partnerName = widget.ctx.partnerName;
    final done = _result != null;
    return MinigameScaffold(
      title: '단톡방 대응',
      instruction: '10초 안에 답할 순서대로 누른다. 답이 늦으면 손해 보는 사람부터.',
      timeLeft: done ? null : (1 - _sw.elapsedMilliseconds / _limit).clamp(0.0, 1.0),
      result: _result,
      onFinished: () => widget.done(_result!),
      // 무르기는 놀이판의 일부다. 목록과 함께 스크롤되면 손이 닿지 않는다.
      footer: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: done || _order.isEmpty ? null : _undo,
          icon: const Icon(Icons.undo, size: 18),
          label: const Text('마지막 하나 무르기'),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.screenX,
          vertical: AppSpace.sm,
        ),
        children: [
          for (var i = 0; i < _msgs.length; i++)
            MinigameOption(
              label: '${_msgs[i].who}  ·  ${_msgs[i].text}',
              // 고르기 전에는 "왜 급한지", 고른 뒤에는 "몇 번째로 답했는지".
              sub: _order.contains(i)
                  ? '${_order.indexOf(i) + 1}번째로 답함'
                  : _msgs[i].why,
              // 끝나면 제 자리에 답했어야 할 순서를 밝힌다.
              trailingLabel: done ? '정답 ${_msgs[i].priority + 1}' : null,
              selected: _order.contains(i),
              dimmed: _order.contains(i) && !done,
              // 끝나면 칸마다 순서가 맞았는지 공개한다(색 + 테두리 + 아이콘).
              tone: !done
                  ? MinigameOptionTone.neutral
                  : _clean(i)
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

  /// 왜 이 사람이 급한지. 고르기 전에 칸에 적힌다.
  final String why;
  const _Msg(this.who, this.text, this.priority, this.why);
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
  /// 통화 대본 네 벌. (상대가 하는 말, 내가 칠 맞장구).
  /// 같은 여섯 마디를 28번 듣게 둘 수는 없다.
  static const _scripts = [
    [
      ('그래서 내가 뭐랬냐면', '응'),
      ('걔가 갑자기 화를 내는 거야', '진짜?'),
      ('내가 잘못한 것도 아닌데', '그러게'),
      ('결국 내가 사과했어', '왜 네가'),
      ('웃기지 않냐 진짜', 'ㅋㅋㅋ'),
      ('아 맞다 너는 오늘 어땠어', '나는…'),
    ],
    [
      ('오늘 회사에서 진짜', '어'),
      ('팀장이 내 자료를 자기가 만든 척', '헐'),
      ('회의에서 그대로 읽더라', '미친'),
      ('나는 옆에서 웃고만 있었어', '속 터졌겠다'),
      ('집 와서 라면 두 개 끓임', '두 개?'),
      ('야 근데 나 너무 내 얘기만 했지', '아니야'),
    ],
    [
      ('나 어릴 때 살던 동네 갔다 왔는데', '오'),
      ('문방구가 아직 있더라', '진짜?'),
      ('아저씨가 나를 알아봤어', '대박'),
      ('이름까지 기억하시더라고', '헐'),
      ('괜히 눈물 날 뻔했잖아', '그럴 만하지'),
      ('너는 그런 데 있어?', '음…'),
    ],
    [
      ('아까 말한 그 영화 봤어', '어땠어'),
      ('앞에 30분은 진짜 졸렸는데', 'ㅋㅋㅋ'),
      ('뒤에 가서 갑자기 울었잖아 내가', '왜'),
      ('주인공이 편지 읽는 데서', '아…'),
      ('혼자 봤는데도 창피하더라', '그럴 수 있지'),
      ('너랑 다시 보고 싶다', '보자'),
    ],
  ];

  late final List<(String, String)> _beats =
      widget.ctx.vary.one('call_rhythm', _scripts);

  /// 말이 끝나고 맞장구 창이 열리기까지. 판마다 조금씩 다르면 몸으로 외운
  /// 박자가 통하지 않는다.
  late final int _leadMs =
      widget.ctx.vary.one('call_lead', const [700, 600, 850, 1000]);

  /// 너무 빨리 눌렀을 때의 잠금 시간. 이게 없으면 손가락을 계속 두드리는 쪽이
  /// 언제나 이긴다 — 리듬 게임이 아니라 연타 게임이 된다.
  static const _earlyLock = Duration(milliseconds: 450);

  int _index = 0;
  int _hits = 0;
  int _combo = 0;
  int _maxCombo = 0;
  bool _open = false;

  /// 창이 열리기 전에 눌러서 잠긴 상태. 표시와 잠금 두 몫을 한다.
  bool _early = false;
  Timer? _timer, _earlyTimer;
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
    _earlyTimer?.cancel();
    super.dispose();
  }

  void _next() {
    if (_index >= _beats.length) return _finish();
    setState(() => _open = false);
    _timer = Timer(Duration(milliseconds: _leadMs), () {
      if (!mounted) return;
      setState(() => _open = true);
      // 화술이 높을수록 창이 넓다. 날이 갈수록 조금 좁아진다.
      final window =
          ((700 + widget.ctx.stat(Stat.talk) * 6) *
                  widget.ctx.vary.byPhase(const [1.1, 1.0, 0.9]))
              .round();
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
    if (_result != null) return;
    if (!_open) {
      // 창이 열리기 전 탭. 아무 반응도 없던 자리라 "먹혔나?" 싶었다.
      // 이제 화면이 대답하고, 잠깐 잠긴다.
      _earlyTimer?.cancel();
      setState(() => _early = true);
      _earlyTimer = Timer(_earlyLock, () {
        if (mounted) setState(() => _early = false);
      });
      return;
    }
    if (_early) return;
    _timer?.cancel();
    setState(() {
      _hits++;
      _combo++;
      _maxCombo = max(_maxCombo, _combo);
      _open = false;
      _early = false;
      _marks.add(true);
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
    final t = context.tokens;
    final scheme = context.scheme;
    final line = _index < _beats.length ? _beats[_index] : _beats.last;
    final done = _index.clamp(0, _beats.length);
    // 조작 대상은 가운데 원 하나. 열렸을 때만 색·크기·테두리가 동시에 바뀐다.
    const dial = AppSpace.huge * 4; // 160

    // (배경, 테두리, 글자, 안에 적을 말).
    final (Color dialBg, Color dialLine, Color dialFg, String dialText) = _open
        ? (scheme.primary, scheme.primary, scheme.onPrimary, line.$2)
        : _early
        ? (t.warningContainer, t.warning, t.onWarningContainer, '아직')
        : (
            scheme.surfaceContainer,
            scheme.outlineVariant,
            scheme.onSurfaceVariant,
            '…',
          );

    return MinigameScaffold(
      title: '맞장구',
      badge: '${Stat.label(Stat.talk)} ${widget.ctx.stat(Stat.talk)}',
      instruction: '말풍선이 켜지면 바로 누른다. 미리 누르면 잠깐 잠긴다. '
          '화술이 높을수록 창이 넓다.',
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
                  color: dialBg,
                  border: Border.all(
                    color: dialLine,
                    width: _open || _early
                        ? AppBorderWidth.emphasis
                        : AppBorderWidth.hairline,
                  ),
                ),
                alignment: Alignment.center,
                padding: AppInsets.card,
                child: Text(
                  dialText,
                  textAlign: TextAlign.center,
                  style: context.text.headlineSmall?.copyWith(color: dialFg),
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
  static const _all = [
    ('러닝하는 사람', '주 3회 한강. 대화는 짧게.', 0.5, Icons.directions_run),
    ('책 읽는 사람', '조용한 카페를 좋아합니다.', 0.6, Icons.menu_book_outlined),
    ('여행 사진만 12장', '다음 달 유럽 갑니다.', 0.25, Icons.flight_takeoff),
    ('고양이 두 마리', '집사 구함 (농담)', 0.7, Icons.pets),
    ('프로필 사진 없음', '만나서 얘기해요.', 0.15, Icons.person_off_outlined),
    ('맛집 리스트 보유', '먹는 거 좋아하는 분.', 0.65, Icons.restaurant_outlined),
    ('헬스장 거울샷', '3대 400.', 0.3, Icons.fitness_center),
    ('그림 그리는 사람', '주말엔 전시 보러 다녀요.', 0.55, Icons.brush_outlined),
    ('기타 치는 사람', '합주할 사람 구해요.', 0.5, Icons.music_note_outlined),
    ('베이킹 계정', '주말마다 뭔가 굽습니다.', 0.68, Icons.cake_outlined),
    ('등산 사진 20장', '주말은 산에 있습니다.', 0.35, Icons.terrain_outlined),
    ('영화 리뷰 계정', '올해 본 영화 87편.', 0.6, Icons.local_movies_outlined),
    ('프로필이 명언', '"진심은 통한다"', 0.2, Icons.format_quote_outlined),
    ('강아지 산책 사진', '아침마다 공원 갑니다.', 0.72, Icons.directions_walk),
    ('자기소개 한 줄 없음', '', 0.18, Icons.help_outline),
    ('사진이 전부 단체샷', '어느 쪽인지는 비밀.', 0.28, Icons.groups_outlined),
  ];

  /// 한 판에 넘기는 장 수.
  static const _shown = 8;

  late final List<(String, String, double, IconData)> _profiles =
      widget.ctx.vary.some('profile_swipe', _all, _shown);

  int _index = 0;
  int _matches = 0;

  /// 벽 높은 프로필을 넘긴 횟수. 아무나 오른쪽으로 미는 사람과
  /// 읽고 고르는 사람을 가르는 값이다.
  int _passedWalls = 0;
  final _log = <String>[];

  /// 마지막 결과가 매칭이었는지. 배지 색을 고르는 표시용이며 판정과 무관하다.
  bool? _lastHit;
  MinigameResult? _result;
  late final Random _rng = widget.ctx.vary.rng('profile_swipe_roll');

  /// 이 프로필의 실제 호응 확률. 매력이 높을수록 오른다.
  double _chanceOf(int i) => (_profiles[i].$3 *
          (0.55 + widget.ctx.stat(Stat.charm) / 130))
      .clamp(0.05, 0.95)
      .toDouble();

  /// 화면에 보여 주는 신호. 확률을 숫자로 까면 계산기가 되고, 아무것도 안 주면
  /// 동전 던지기가 된다. 세 단계짜리 말로만 알려 준다.
  (String, IconData, AppTone) _signalOf(int i) {
    final c = _chanceOf(i);
    if (c >= 0.45) return ('말 걸어도 될 것 같다', Icons.sentiment_satisfied, AppTone.success);
    if (c >= 0.25) return ('반반이다', Icons.sentiment_neutral, AppTone.neutral);
    return ('벽이 높아 보인다', Icons.sentiment_dissatisfied, AppTone.warning);
  }

  void _swipe(bool right) {
    if (_result != null) return;
    final p = _profiles[_index];
    if (right) {
      final hit = _rng.nextDouble() < _chanceOf(_index);
      if (hit) _matches++;
      _log.add('${p.$1} · ${hit ? '매칭' : '무응답'}');
      _lastHit = hit;
    } else {
      // 벽 높은 프로필을 넘긴 것은 판단이다. 낮은 확률에 시간을 안 쓴 값을 쳐준다.
      if (_chanceOf(_index) < 0.25) _passedWalls++;
      _log.add('${p.$1} · 넘김');
      _lastHit = null;
    }
    setState(() {
      _index++;
      if (_index >= _profiles.length) _finish();
    });
  }

  void _finish() {
    // 판단 점수 = 매칭 + 잘 거른 수. 크리티컬은 둘 다 해야 나온다.
    final judgment = _matches + _passedWalls;
    _result = MinigameResult(
      success: _matches >= 2,
      critical: _matches >= 3 && judgment >= 5,
      score: (judgment / 6).clamp(0.0, 1.0),
      message: _matches >= 3 && judgment >= 5
          ? '$_matches명과 매칭. 넘길 건 넘겼고 알림은 멈추지 않는다.'
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
    final at = done ? _profiles.length - 1 : _index;
    final p = _profiles[at];
    final signal = _signalOf(at);
    final seen = _index.clamp(0, _profiles.length);

    return MinigameScaffold(
      title: '프로필 고르기',
      badge: '${Stat.label(Stat.charm)} ${widget.ctx.stat(Stat.charm)}',
      instruction: '오늘 볼 수 있는 프로필 ${_profiles.length}장. '
          '카드 아래 한 줄이 호응 가능성이다. 매력이 높을수록 그 줄이 올라간다.',
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
                    if (p.$2.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        keepAll(p.$2),
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.md),
                    // 넘길지 말지 고를 근거. 색 + 아이콘 + 낱말 세 신호.
                    ResultBadge(
                      tone: signal.$3,
                      label: signal.$1,
                      icon: signal.$2,
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
