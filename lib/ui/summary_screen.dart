import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../game_controller.dart';
import 'design_system.dart';
import 'widgets.dart';
import 'keep_all.dart';

/// 하루 정산. "다음 날" 을 누르면 정책에 맞을 때만 전면 광고가 나온다.
///
/// 규격: docs/DESIGN_SYSTEM.md §2.4.
/// 주인공은 오늘 바뀐 수치다. 절대값은 막대에 남기고 변화량을 색 + 부호 +
/// 화살표 3중으로 앞세운다. 마지막은 클리프행어 — 내일을 궁금하게 만드는 줄.
///
/// 단, 오늘 누군가와 호감 구간을 넘었으면 그 "관계 변화" 카드(서사 신호)가 맨 위에
/// 먼저 뜬다. 숫자보다 이야기로 가까워진 걸 먼저 느끼게 하는 자리다(최대 2장).
class SummaryScreen extends StatelessWidget {
  final GameController c;
  const SummaryScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final d = c.dayDelta;
    final hasRelation = d.affection.isNotEmpty || d.trust.isNotEmpty;
    final cliffhanger = c.sayOrNull(c.cliffhanger);
    final shifts = c.todayShifts.take(GameController.maxShiftCards).toList();

    // 관계 변화 줄. 라벨('서연 호감')과 변화량('+4')을 나눠 변화량을 앞세운다.
    final relations = <_RelationDelta>[
      for (final e in d.affection.entries)
        _RelationDelta(
          id: e.key,
          label: '${c.characterName(e.key)} 호감',
          value: e.value,
        ),
      for (final e in d.trust.entries)
        _RelationDelta(
          id: e.key,
          label: '${c.characterName(e.key)} 신뢰',
          value: e.value,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('D+${s.day} 정산'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screenX,
          AppSpace.screenY,
          AppSpace.screenX,
          AppSpace.xxl,
        ),
        children: [
          // 0. 관계 변화 카드. 오늘 구간을 넘은 사람(오른 쪽 먼저). 없으면 자리도 없다.
          for (var i = 0; i < shifts.length; i++) ...[
            _Reveal(
              index: i,
              child: RelationShiftCard(
                name: c.characterName(shifts[i].id),
                text: c.say(shifts[i].text),
                up: shifts[i].up,
                accent: context.tokens.accentFor(shifts[i].id),
                characterId: shifts[i].id,
              ),
            ),
            const SizedBox(height: AppSpace.listGap),
          ],
          if (shifts.isNotEmpty)
            const SizedBox(height: AppSpace.sectionGap - AppSpace.listGap),

          // 1. 오늘 바뀐 수치. 막대가 오늘 값으로 흘러가고 오른쪽에 '+3  42'.
          const SectionHeader(title: '오늘의 변화'),
          AppCard(
            padding: AppInsets.cardTight,
            child: StatBars(state: s, delta: d.stats),
          ),

          // 2. 관계 변화. 한 줄씩 차례로 쌓인다.
          if (hasRelation) ...[
            const SizedBox(height: AppSpace.sectionGap),
            const SectionHeader(title: '관계 변화'),
            for (var i = 0; i < relations.length; i++)
              _Reveal(
                index: i,
                child: StatTile(
                  label: relations[i].label,
                  // 점은 누구인지(캐릭터색), 변화량은 색 + 부호 + 화살표 3중.
                  accent: context.tokens.accentFor(relations[i].id).base,
                  delta: signed(relations[i].value),
                  good: relations[i].value > 0,
                ),
              ),
          ],

          // 3. 클리프행어. 하루의 마지막 줄이자 내일의 첫 줄.
          if (cliffhanger != null) ...[
            const SizedBox(height: AppSpace.sectionGap),
            _Reveal(
              index: relations.length,
              child: CliffhangerCard(text: cliffhanger, emphasized: true),
            ),
          ],

          // 4. 하루를 닫는 버튼.
          const SizedBox(height: AppSpace.xxl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                await AdManager.instance.showInterstitial(day: s.day);
                await c.endDay();
              },
              child: Text(s.day >= c.config.totalDays ? '엔딩 보기' : '다음 날로'),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            keepAll('흑역사 ${s.album.length}개'),
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: const BannerSlot(),
    );
  }
}

/// 관계 변화 한 줄분.
class _RelationDelta {
  final String id;
  final String label;
  final int value;
  const _RelationDelta({
    required this.id,
    required this.label,
    required this.value,
  });
}

/// 하루치 변화가 위에서부터 차례로 쌓이는 느낌만 준다.
/// 화면당 하나의 연출이고, 동작 줄이기가 켜지면 즉시 최종 상태로 둔다.
class _Reveal extends StatelessWidget {
  final int index;
  final Widget child;
  const _Reveal({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.slow(context);
    if (duration == Duration.zero) return child;
    // 줄마다 조금씩 늦게 시작한다. 마지막 줄도 한 번의 dSlow 안에서 끝난다.
    final begin = (index * 0.12).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Interval(begin, 1, curve: AppMotion.standard),
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - v) * AppSpace.sm),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
