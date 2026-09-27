import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../ui/design_system.dart';
import '../ui/widgets.dart';
import 'minigame.dart';
import '../ui/keep_all.dart';

/// 4. 표정 읽기 퀴즈 — 눈치
class ReadEmotionGame extends StatefulWidget {
  final MinigameContext ctx;
  final void Function(MinigameResult) done;
  const ReadEmotionGame({super.key, required this.ctx, required this.done});

  @override
  State<ReadEmotionGame> createState() => _ReadEmotionGameState();
}

class _ReadEmotionGameState extends State<ReadEmotionGame> {
  /// (한 말, 표정, 보기, 정답 index). 판마다 이 중 [_perRound] 개만 쓴다 —
  /// 열두 문제를 매번 네 개씩 돌려 쓰면 두 번째 판이 첫 판과 겹치지 않는다.
  static const _pool = [
    ('괜찮아 ㅎㅎ 신경 쓰지 마', '🙂', ['서운함', '진짜 괜찮음', '화남', '피곤함'], 0),
    ('아 그렇구나', '…', ['관심 있음', '대화 끊고 싶음', '기분 좋음', '졸림'], 1),
    ('너 마음대로 해', '🙃', ['허락', '삐짐', '무관심', '신남'], 1),
    ('오늘 좀 피곤하다', '😮‍💨', ['위로 원함', '약속 취소 원함', '자랑', '화남'], 0),
    ('ㅇㅇ', '😐', ['동의', '대화 끊고 싶음', '바쁨', '삐짐'], 1),
    ('아니 뭐 별건 아닌데', '🫤', ['진짜 별거 아님', '꺼내고 싶은 말이 있음', '변명', '자랑'], 1),
    ('넌 참 좋은 사람이야', '🙂', ['호감', '선 긋기', '고마움', '놀림'], 1),
    ('나 내일 시간 비어', '👀', ['일정 공유', '만나자는 뜻', '자랑', '거절'], 1),
    ('ㅋ', '🫥', ['재밌음', '기분 상함', '바쁨', '수줍음'], 1),
    ('그 얘기는 나중에 하자', '😶', ['미루기', '지금 불편함', '까먹음', '관심 없음'], 1),
    ('사진 잘 나왔네', '🙂', ['칭찬', '떠보기', '무성의', '질투'], 0),
    ('먼저 자', '🌙', ['잘 자라는 뜻', '더 붙잡히고 싶음', '화남', '귀찮음'], 1),
  ];

  /// 한 판에 푸는 문제 수. 성공 기준(3개)이 여기에 묶여 있다.
  static const _perRound = 4;

  /// 이 판에 나올 문제. 등장 순번마다 다른 네 개가 잘려 나온다.
  late final List<(String, String, List<String>, int)> _rounds =
      widget.ctx.vary.some('read_emotion', _pool, _perRound);

  /// 보기 순서도 판마다 섞는다. 정답이 늘 같은 자리에 있으면 두 번째부터는
  /// 문장이 아니라 위치를 외우게 된다.
  late final List<List<int>> _optionOrder = [
    for (var i = 0; i < _rounds.length; i++)
      widget.ctx.vary.shuffled(
        'read_emotion_opt$i',
        List<int>.generate(_rounds[i].$3.length, (k) => k),
      ),
  ];

  /// 눈치가 높을수록 시간이 늘고, 날이 갈수록 조금 짧아진다.
  late final int _limit =
      (widget.ctx.vary.byPhase(const [5600, 5000, 4600]) +
              widget.ctx.stat(Stat.sense) * 30)
          .round();
  int _round = 0;
  int _correct = 0;
  int? _picked;
  final _sw = Stopwatch()..start();
  Timer? _tick;
  MinigameResult? _result;

  /// 화면에 보이는 i 번째 보기의 원래 index.
  int _slot(int i) => _optionOrder[_round][i];

  /// 이 문제의 정답이 화면에서 몇 번째 자리인지.
  int get _answerSlot => _optionOrder[_round].indexOf(_rounds[_round].$4);

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
    final answer = _answerSlot;
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
      timeLeft: _picked == null
          ? (1 - _sw.elapsedMilliseconds / _limit).clamp(0.0, 1.0)
          : null,
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
              label: r.$3[_slot(i)],
              selected: _picked == i,
              sub: _picked != null && i == _answerSlot ? '정답' : null,
              tone: _toneFor(i, _answerSlot),
              dimmed:
                  _picked != null &&
                  _toneFor(i, _answerSlot) == MinigameOptionTone.neutral,
              onTap: () => _pick(i),
            ),
          const SizedBox(height: AppSpace.md),
          Text(keepAll('${_round + 1} / ${_rounds.length}'),
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
  /// (취향 키, 이름, 설명, 카드 기호, 카드 색). 짤 그림은 없다 — 있는 척하는 회색
  /// 이미지 아이콘은 "로딩 실패" 로 읽혔다(01 P1-2). 그래서 그림 대신 후보마다 다른
  /// 기호·색의 **자막 카드** 로 보여 준다. 색은 캐릭터 강조색 팔레트를 빌려 후보를
  /// 구분만 하고 뜻은 없다.
  static const _memes = [
    (
      'dry',
      '정색하는 고양이',
      '무표정으로 쳐다보는 고양이',
      Icons.sentiment_neutral,
      'doyun',
    ),
    (
      'loud',
      '박수치며 웃는 사람',
      '대문짝만한 ㅋㅋㅋ 자막',
      Icons.sentiment_very_satisfied,
      'jiwoo',
    ),
    ('witty', '안경 고쳐 쓰는 짤', '"흥미롭군요" 자막', Icons.menu_book_outlined, 'minjae'),
    (
      'meme',
      '픽셀 강아지',
      '알 사람만 아는 옛날 짤',
      Icons.videogame_asset_outlined,
      'haneul',
    ),
    ('warm', '하트 뿅뿅 곰', '따뜻한 파스텔톤', Icons.favorite_outline, 'yeeun'),
    ('dry', '무표정 정장 아저씨', '아무 말 없이 엄지만 세운 짤', Icons.thumb_up_outlined, 'doyun'),
    ('loud', '테이블 치는 짤', '"ㅋㅋㅋㅋㅋㅋㅋ" 가 화면을 덮는다', Icons.celebration_outlined, 'jiwoo'),
    ('witty', '한 줄 자막 밈', '"그건 좀…" 한 줄이 전부', Icons.format_quote_outlined, 'minjae'),
    ('meme', '저화질 개구리', '2012년 짤방 특유의 깨진 화질', Icons.blur_on_outlined, 'haneul'),
    ('warm', '이불 덮은 강아지', '"푹 자" 자막', Icons.bedtime_outlined, 'yeeun'),
  ];

  /// 답해야 할 상대의 말. 판마다 다르다. 같은 말에 같은 짤을 고르는 게 아니라
  /// 무슨 상황인지 읽고 고르게 하려는 것이다.
  static const _prompts = [
    '방금 진짜 웃긴 일 있었는데 ㅋㅋㅋ',
    '아 오늘 진짜 최악이었다…',
    '나 방금 지하철에서 넘어짐',
    '야 이거 봐봐 (사진)',
    '나 시험 망함 ㅋㅋㅋ 인생 끝',
  ];

  static const _candidates = 4;

  int? _picked;
  MinigameResult? _result;

  late final String _prompt = widget.ctx.vary.one('pick_meme_msg', _prompts);

  /// 후보 네 장. **상대 취향에 맞는 짤은 반드시 한 장 들어간다** —
  /// 취향 짤이 빠진 판은 화술 45 미만이면 어떻게 눌러도 실패라, 플레이어가
  /// 자기 잘못이 아닌 실패를 먹었다(감사 N4·09 §1).
  late final List<int> _order = () {
    final v = widget.ctx.vary;
    final all = List<int>.generate(_memes.length, (i) => i);
    final match = all.where((i) => _memes[i].$1 == widget.ctx.humor).toList();
    if (match.isEmpty) return v.some('pick_meme', all, _candidates);
    // 취향 짤 하나를 먼저 잡고, 나머지 자리는 다른 취향에서 채운다.
    final answer = match[v.round % match.length];
    final rest = all.where((i) => _memes[i].$1 != widget.ctx.humor).toList();
    final picked = [
      answer,
      ...v.some('pick_meme', rest, _candidates - 1),
    ];
    return v.shuffled('pick_meme_slot', picked);
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
                child: Text(keepAll('"$_prompt"'),
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
              leading: _MemeCard(
                icon: _memes[_order[i]].$4,
                accent: t.accentFor(_memes[_order[i]].$5),
              ),
              onTap: () => _pick(i),
            ),
        ],
      ),
    );
  }
}

/// 짤 한 장 자리. 그림이 아니라 기호 + 색으로 후보를 구별하는 작은 카드다.
/// 말풍선에 붙여 보낸 짤처럼 보이게 모서리와 테두리를 준다.
class _MemeCard extends StatelessWidget {
  final IconData icon;
  final CharacterAccent accent;
  const _MemeCard({required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
    width: AppSpace.huge,
    height: AppSpace.huge,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: accent.container,
      borderRadius: AppRadius.rSm,
      border: Border.all(
        color: accent.base,
        width: AppBorderWidth.hairline,
      ),
    ),
    child: Icon(icon, size: AppSpace.xl, color: accent.onContainer),
  );
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
  /// 옷장 전체. 판마다 칸당 [_perSlot] 벌만 걸려 있다 — 매번 같은 열두 벌이면
  /// 두 번째 판부터는 고르는 게 아니라 외운 걸 다시 누르는 일이 된다.
  static const _closet = [
    [
      ('검정 니트', ['조용한', '전시']),
      ('후드티', ['가성비', '실내', '게임']),
      ('셔츠', ['브런치', '전시']),
      ('맨투맨', ['산책', '추억']),
      ('카디건', ['조용한', '브런치']),
      ('체크 셔츠', ['추억', '길거리']),
      ('반팔 티', ['운동', '가성비', '실내']),
      ('블루종', ['야경', '길거리']),
    ],
    [
      ('슬랙스', ['전시', '브런치']),
      ('청바지', ['가성비', '산책', '길거리']),
      ('트레이닝 팬츠', ['실내', '게임', '운동']),
      ('면바지', ['추억', '산책']),
      ('반바지', ['운동', '가성비']),
      ('코듀로이 팬츠', ['조용한', '전시']),
      ('블랙진', ['야경', '야시장', '길거리']),
      ('린넨 팬츠', ['브런치', '산책']),
    ],
    [
      ('구두', ['브런치', '전시']),
      ('운동화', ['산책', '가성비', '운동']),
      ('슬리퍼', ['실내', '게임']),
      ('부츠', ['야경', '야시장']),
      ('로퍼', ['조용한', '브런치']),
      ('컨버스', ['추억', '길거리', '가성비']),
      ('러닝화', ['운동', '산책']),
      ('샌들', ['야시장', '실내']),
    ],
  ];

  /// 칸마다 걸리는 벌 수.
  static const _perSlot = 4;

  /// 칸마다 **취향에 맞는 벌이 최소 한 벌은 걸려 있게** 뽑는다. 세 칸 중 두 칸을
  /// 맞춰야 성공인데 맞는 벌이 아예 없는 칸이 나오면 실패가 플레이어 탓이 아니게 된다.
  late final List<List<(String, List<String>)>> _items = [
    for (var s = 0; s < _closet.length; s++) _slotItems(s),
  ];

  List<(String, List<String>)> _slotItems(int s) {
    final v = widget.ctx.vary;
    final rack = _closet[s];
    final fits = rack.where((e) => e.$2.any(widget.ctx.tags.contains)).toList();
    if (fits.isEmpty) return v.some('outfit$s', rack, _perSlot);
    final keep = fits[v.round % fits.length];
    final rest = rack.where((e) => e != keep).toList();
    return v.shuffled('outfit${s}_slot', [
      keep,
      ...v.some('outfit$s', rest, _perSlot - 1),
    ]);
  }

  /// 결과가 나온 뒤 고른 벌이 취향에 맞았는지 알려 준다. 고르지 않은 벌은 중립.
  MinigameOptionTone _toneFor(int slot, int i) {
    if (_result == null || _picked[slot] != i) return MinigameOptionTone.neutral;
    return _items[slot][i].$2.any(widget.ctx.tags.contains)
        ? MinigameOptionTone.correct
        : MinigameOptionTone.wrong;
  }

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
                tone: _toneFor(s, i),
                // 결과가 나오면 고른 벌만 남기고 물러난다.
                dimmed: _result != null && _picked[s] != i,
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
  /// 갈 수 있는 곳 전부. 값은 돈 스탯 단위다(1 = 1,000원, [Stat.won]).
  /// 판마다 이 중 [_shown] 곳만 목록에 오른다.
  static const _allPlaces = [
    ('한강 산책', 0, ['산책', '가성비', '야경']),
    ('동네 전시회', 12, ['전시', '조용한']),
    ('분식집', 8, ['분식', '가성비', '추억']),
    ('브런치 카페', 25, ['브런치', '조용한']),
    ('야시장', 15, ['야시장', '길거리', '사진']),
    ('오마카세', 90, ['조용한']),
    ('보드게임 카페', 18, ['실내', '게임']),
    ('옛날 학교 앞', 5, ['추억', '사진', '산책']),
    ('독립 서점', 10, ['조용한', '전시']),
    ('포장마차', 14, ['야시장', '길거리', '추억']),
    ('영화관 조조', 11, ['실내', '가성비']),
    ('남산 전망대', 7, ['야경', '산책', '사진']),
    ('실내 클라이밍', 22, ['운동', '실내', '게임']),
    ('동네 목욕탕 앞 커피', 3, ['추억', '가성비']),
    ('루프탑 바', 45, ['야경', '조용한']),
    ('벼룩시장', 6, ['길거리', '사진', '가성비']),
  ];

  /// 한 판에 보이는 후보 수.
  static const _shown = 8;

  /// 이 판의 후보. 취향에 맞는 곳이 최소 세 군데는 들어가야 크리티컬(취향 3개)이
  /// 가능하다 — 애초에 불가능한 판을 내주면 안 된다.
  late final List<(String, int, List<String>)> _places = () {
    final v = widget.ctx.vary;
    final fits = _allPlaces
        .where((p) => p.$3.any(widget.ctx.tags.contains))
        .toList();
    final keep = v.some('date_fit', fits, min(3, fits.length));
    final rest = _allPlaces.where((p) => !keep.contains(p)).toList();
    return v.shuffled('date_slot', [
      ...keep,
      ...v.some('date_course', rest, _shown - keep.length),
    ]);
  }();

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
            ? '예산 ${Stat.won(budget)}을 ${Stat.won(_cost - budget)} 초과했다. 계산대에서 얼어붙었다.'
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
          '3곳을 고른다. 예산 ${Stat.won(budget)} · '
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
                child: Text(keepAll(
                  '합계 ${Stat.won(_cost)} / ${Stat.won(budget)}'
                  '${over ? "  (예산 초과)" : ""}',
                ),
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
              trailingLabel: _places[i].$2 == 0
                  ? '무료'
                  : Stat.won(_places[i].$2),
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
