import 'package:flutter/material.dart';

import '../engine/models.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'widgets.dart';

/// 스탯 한 가지의 설명: 무엇인지, 어떻게 오르내리는지, 어디에 쓰이는지.
///
/// 문구는 실제 규칙과 맞춘다. 숫자가 바뀌면 여기도 고친다:
/// - 크리티컬 5% + 눈치 20당 1%p: `EventEngine.critChance`
/// - 위기 이벤트 임계값: assets/story/events_special.json (`c_*`)
/// - 아침 행동 효과: assets/story/config.json `actions`
class StatInfo {
  final String key;
  final String what;
  final String raise;
  final List<String> uses;

  const StatInfo(this.key, this.what, this.raise, this.uses);
}

const statGuide = [
  StatInfo(Stat.charm, '첫인상과 외모 자신감. 처음 보는 사람이 나를 어떻게 기억하는지.', '헬스장 · 스타일링', [
    '프로필 스와이프 같은 첫인상 미니게임의 성공률',
    '"먼저 다가가기" 류 선택지가 열린다',
    '60을 넘기면 헬스장에서 새로운 얼굴을 만날지도',
  ]),
  StatInfo(Stat.talk, '말을 고르는 힘. 같은 마음도 어떻게 말하느냐로 결과가 달라진다.', '독서·영상', [
    '"화술 N 필요" 로 잠긴 선택지가 풀린다',
    '맞장구·문장 만들기·짤 고르기 미니게임의 여유가 늘어난다',
  ]),
  StatInfo(
    Stat.esteem,
    '나를 믿는 힘. 고백, 거절, 당당한 한마디는 자존감에서 나온다.',
    '집에서 휴식 · 친구 만나기 (읽씹을 끝까지 기다리면 -1)',
    [
      '가장 많은 선택지를 여는 열쇠(고백·솔직한 대답)',
      '드립을 어디서 멈출지 버티는 여유',
      '바닥까지 떨어지면 위기 이벤트가 찾아온다',
    ],
  ),
  StatInfo(Stat.sense, '분위기와 표정을 읽는 힘. 말하지 않은 속마음을 알아챈다.', '독서·영상', [
    '크리티컬(호감 2배) 확률: 기본 5% + 눈치 20마다 1%',
    '표정 읽기 제한 시간, 답장 타이밍 판정이 넉넉해진다',
    '"눈치 N 필요" 선택지가 풀린다',
  ]),
  StatInfo(
    Stat.stress,
    '유일하게 낮을수록 좋은 수치. 막대가 오른쪽에서 자란다.',
    '줄이기: 집에서 휴식(-12) · 쌓이는 곳: 헬스장, 알바',
    ['70을 넘으면 막차·몸살 같은 사고가 일어나기 시작한다', '90을 넘으면 번아웃 — 하루가 통째로 무너진다'],
  ),
  StatInfo(
    Stat.money,
    '잔고. 데이트도 선물도 결국 돈이 든다.',
    '벌기: 알바(+15) · 쓰기: 스타일링, 친구 만나기, 데이트 선택지',
    ['옷장 코디·데이트 코스 짜기 미니게임의 예산', '바닥나면 "잔고 바닥" 위기 이벤트'],
  ),
];

/// 스탯 설명 시트. 행동 화면의 "스탯 설명" 에서 연다.
class StatGuideSheet extends StatelessWidget {
  const StatGuideSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const StatGuideSheet(),
  );

  static const title = '스탯은 이렇게 쓰여요';

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final t = context.tokens;
    final soft = context.scheme.onSurfaceVariant;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screenX,
            0,
            AppSpace.screenX,
            AppSpace.xxl,
          ),
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
            for (final g in statGuide) ...[
              const SizedBox(height: AppSpace.lg),
              AppCard(
                accentStripe: t.statColor(g.key),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          statIcon(g.key),
                          size: 20,
                          color: t.statColor(g.key),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text(Stat.label(g.key), style: text.titleMedium),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(keepAll(g.what), style: text.bodyMedium),
                    const SizedBox(height: AppSpace.sm),
                    _line(context, Icons.trending_up, g.raise),
                    for (final u in g.uses)
                      _line(context, Icons.subdirectory_arrow_right, u),
                  ],
                ),
              ),
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
    );
  }

  Widget _line(BuildContext context, IconData icon, String s) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.xxs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(child: Text(keepAll(s), style: context.text.bodySmall)),
      ],
    ),
  );
}
