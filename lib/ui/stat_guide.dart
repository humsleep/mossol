/// 스탯 설명 시트. 행동 화면의 `내 스탯` 머리줄 `스탯 설명` 버튼(또는 막대 탭)으로 연다.
///
/// 문구는 실제 규칙과 맞춘다. 숫자가 바뀌면 여기도 고친다:
/// - 크리티컬 5% + 눈치 20당 1%p, 물올랐을 때 두 배: `EventEngine.critChance`
/// - 위기 이벤트 임계값: assets/story/events_special.json (`c_*`·`h_doyun_intro`)
/// - 밤마다 스트레스 -3: `EventEngine.endDay`
/// - 읽씹 끝까지 기다리기 자존감 -1: `GameController.applyWaitPenalty`
/// - 미니게임 스탯 사용: lib/minigames/*
///
/// "어떻게 오르나" 의 아침 행동 줄은 손으로 쓰지 않고 config.json `actions` 에서 뽑는다
/// ([StatGuideSheet.actionLine]) — 행동 수치가 바뀌어도 시트가 거짓말하지 않는다.
library;

import 'package:flutter/material.dart';

import '../engine/models.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'widgets.dart';

/// 스탯 한 가지의 설명: 무엇인지, (아침 행동 말고) 또 어디서 오르내리는지, 어디에 쓰이는지.
class StatInfo {
  final String key;
  final String what;

  /// 아침 행동 밖에서 오르내리는 길. 없으면 null.
  final String? more;
  final List<String> uses;

  const StatInfo(this.key, this.what, this.more, this.uses);
}

const statGuide = [
  StatInfo(
    Stat.charm,
    '첫인상과 외모 자신감. 처음 보는 사람이 나를 어떻게 기억하는지.',
    '룰렛 “거울이 좋다” · 대화 선택지',
    [
      '프로필 고르기 미니게임에서 상대가 호응할 확률',
      '“매력 N↑” 로 잠긴 선택지가 풀린다',
      '두 번째 회차부터, 60 이상이면 헬스장에서 새로운 얼굴을 만날지도',
    ],
  ),
  StatInfo(
    Stat.talk,
    '말을 고르는 힘. 같은 마음도 어떻게 말하느냐로 결과가 달라진다.',
    '룰렛 “말이 잘 통한다” · 대화 선택지',
    [
      '“화술 N↑” 로 잠긴 선택지가 풀린다',
      '맞장구 미니게임의 박자 창이 넓어진다',
      '짤 고르기: 취향 짤이 없어도 45부터 말로 살린다, 55부터 크리티컬',
      '문장 만들기: 50부터 한 단어 더 긴 문장에 도전한다',
    ],
  ),
  StatInfo(
    Stat.esteem,
    '나를 믿는 힘. 고백, 거절, 당당한 한마디는 자존감에서 나온다.',
    '읽씹을 끝까지 기다리면 -1 · 룰렛 “자신감”',
    [
      '가장 많은 선택지를 여는 열쇠(고백·솔직한 대답)',
      '결심의 순간 미니게임의 안전 구간이 넓어진다',
      '선 지키기: 드립을 어디서 멈출지 버티는 여유',
      '8 이하로 떨어지면 “바닥” 위기 이벤트가 찾아온다',
    ],
  ),
  StatInfo(
    Stat.sense,
    '분위기와 표정을 읽는 힘. 말하지 않은 속마음을 알아챈다.',
    '룰렛 “눈치가 밝다” · 대화 선택지',
    [
      '크리티컬(호감 2배) 확률: 기본 5% + 눈치 20마다 1%p, 물올랐을 땐 두 배',
      '표정 읽기·5초 삭제의 제한 시간이 넉넉해진다',
      '답장 타이밍: 30부터 좋은 구간이, 40부터 크리티컬 구간이 보인다',
      '29 이하인데 가까운 사람이 있으면 그 사람이 잠수를 탈 수도',
      '“눈치 N↑” 로 잠긴 선택지가 풀린다',
    ],
  ),
  StatInfo(
    Stat.stress,
    '유일하게 낮을수록 좋은 수치. 막대가 오른쪽에서 자란다.',
    '밤마다 저절로 -3 · 룰렛 “컨디션 최고” -20',
    ['70부터 막차·몸살 같은 사고가 일어나기 시작한다', '90부터 번아웃. 몸이 먼저 멈춘다'],
  ),
  StatInfo(Stat.money, '잔고. 데이트도 선물도 결국 돈이 든다.', '룰렛 “돈이 생겼다” +4만원 · 데이트 선택지', [
    '코스 짜기 미니게임의 예산(잔고보다 많이 쓸 수 없다)',
    '5천원 이하로 바닥나면 “잔고 바닥” 위기 이벤트',
    '3만원 이하인데 가까운 사람이 있으면 “돈 문제” 가 터질 수도',
  ]),
  // 소문(01_design §5.1). 평판과 다른 축 — 좋게 보는 정도가 아니라 화제로 삼는 정도.
  // 소문이 1 이상인 회차에서만 시트에 나온다([StatGuideSheet.showHeat]).
  StatInfo(
    Stat.heat,
    '내가 동네 화제인 정도. 평판과는 다르다. 좋게 보든 나쁘게 보든 다들 내 얘기를 한다.',
    '밤마다 저절로 -1 · 자극적인 선택·공개 선언으로 오르고, 사과나 해명으로 내린다',
    [
      '홈과 정산의 5칸 게이지: 조용 · 수군수군 · 화제 · 박제 위기 · 대참사',
      '20부터 예상 못 한 사건이 끼어들기 시작한다',
      '60을 넘기면 소문이 걷잡을 수 없이 퍼질 수도',
      '잠수(집에서 휴식)로 조금씩 식는다',
    ],
  ),
];

/// 스탯 설명 시트.
class StatGuideSheet extends StatelessWidget {
  /// 아침 행동 목록(config.json `actions`). "어떻게 오르나" 줄을 여기서 뽑는다.
  final List<DayAction> actions;

  /// 소문 칸을 보여 줄지. 소문이 0 인 회차(클래식)에서는 숨긴다 — 게이지가 없는 회차에
  /// 게이지 설명이 뜨면 헷갈린다.
  final bool showHeat;

  const StatGuideSheet({
    super.key,
    this.actions = const [],
    this.showHeat = false,
  });

  static Future<void> show(
    BuildContext context, {
    List<DayAction> actions = const [],
    bool showHeat = false,
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => StatGuideSheet(actions: actions, showHeat: showHeat),
  );

  static const title = '스탯은 이렇게 쓰여요';

  /// [key] 스탯을 바꾸는 아침 행동을 `헬스장 +1 · 스타일링 +2` 로. 돈은 `+1.5만원`.
  /// 오르는 행동을 먼저, 내리는 행동을 뒤에 둔다. 스트레스는 내리는 쪽이 좋은 쪽이라 반대.
  static String? actionLine(String key, List<DayAction> actions) {
    final hits = [
      for (final a in actions)
        if (a.effects.stats[key] case final d? when d != 0) (a.name, d),
    ];
    if (hits.isEmpty) return null;
    bool good(int d) => Stat.isGood(key, d);
    hits.sort((a, b) {
      final ga = good(a.$2) ? 0 : 1;
      final gb = good(b.$2) ? 0 : 1;
      return ga.compareTo(gb);
    });
    String amount(int d) => key == Stat.money ? Stat.wonDelta(d) : signed(d);
    return hits.map((h) => '${h.$1} ${amount(h.$2)}').join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final soft = context.scheme.onSurfaceVariant;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        // ListView 가 아니다: 행동 화면 테스트가 화면의 유일한 ListView 를 끈다.
        child: SingleChildScrollView(
          key: const Key('stat-guide-scroll'),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screenX,
            0,
            AppSpace.screenX,
            AppSpace.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: text.titleLarge),
              const SizedBox(height: AppSpace.xs),
              Text(
                keepAll(
                  '아침에 고른 행동으로 스탯이 오르내리고, 스탯이 그날 밤 '
                  '고를 수 있는 말과 미니게임의 난이도를 바꾼다.',
                ),
                style: text.bodyMedium?.copyWith(color: soft),
              ),
              for (final g in statGuide)
                if (showHeat || g.key != Stat.heat) ...[
                  const SizedBox(height: AppSpace.md),
                  _StatCard(info: g, morning: actionLine(g.key, actions)),
                ],
              const SizedBox(height: AppSpace.lg),
              Text(
                keepAll(
                  '화면에 없는 수치도 있다. 진심을 담은 선택은 조용히 쌓여 '
                  '어떤 엔딩을 만날지를 가른다.',
                ),
                style: text.bodySmall?.copyWith(color: soft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 스탯 한 장. 머리(아이콘 원 + 이름) → 한 줄 풀이 → `오르내림` · `쓰이는 곳` 두 묶음.
class _StatCard extends StatelessWidget {
  final StatInfo info;
  final String? morning;

  const _StatCard({required this.info, required this.morning});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = context.text;
    final scheme = context.scheme;
    final color = t.statColor(info.key);
    final inverted = Stat.lowerIsBetter.contains(info.key);
    final how = [?morning, ?info.more];
    return AppCard(
      accentStripe: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSpace.xxxl,
                height: AppSpace.xxxl,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(statIcon(info.key), size: 18, color: color),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(Stat.label(info.key), style: text.titleMedium),
              ),
              if (inverted)
                Text(
                  '낮을수록 좋다',
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(keepAll(info.what), style: text.bodyMedium),
          if (how.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            _Group(
              label: inverted ? '오르내림' : '키우는 법',
              icon: inverted ? Icons.swap_vert : Icons.trending_up,
              lines: how,
            ),
          ],
          const SizedBox(height: AppSpace.sm),
          _Group(
            label: inverted ? '높으면' : '쓰이는 곳',
            icon: inverted
                ? Icons.warning_amber_outlined
                : Icons.subdirectory_arrow_right,
            lines: info.uses,
          ),
        ],
      ),
    );
  }
}

/// 소제목 한 줄 + 들여 쓴 문장들.
class _Group extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> lines;

  const _Group({required this.label, required this.icon, required this.lines});

  @override
  Widget build(BuildContext context) {
    final soft = context.scheme.onSurfaceVariant;
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: soft),
            const SizedBox(width: AppSpace.xs),
            Text(label, style: text.labelMedium?.copyWith(color: soft)),
          ],
        ),
        for (final s in lines)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpace.lg + AppSpace.xxs,
              top: AppSpace.xxs,
            ),
            child: Text(
              keepAll(s),
              style: text.bodySmall?.copyWith(color: context.scheme.onSurface),
            ),
          ),
      ],
    );
  }
}
