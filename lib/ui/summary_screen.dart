import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../engine/models.dart';
import '../game_controller.dart';
import 'design_system.dart';
import 'widgets.dart';

/// 하루 정산. "다음 날" 을 누르면 정책에 맞을 때만 전면 광고가 나온다.
///
/// 규격: docs/DESIGN_SYSTEM.md §2.4.
/// 주인공은 오늘 바뀐 수치다. 절대값은 막대에 남기고 변화량을 색 + 부호 +
/// 화살표 3중으로 앞세운다. 마지막은 클리프행어 — 내일을 궁금하게 만드는 줄.
class SummaryScreen extends StatelessWidget {
  final GameController c;
  const SummaryScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final d = c.dayDelta;
    final hasRelation = d.affection.isNotEmpty || d.trust.isNotEmpty;
    final cliffhanger = c.cliffhanger;

    // 관계 변화 줄. 표시 문자열('서연 호감 +4')은 고정이다.
    final relations = <_RelationDelta>[
      for (final e in d.affection.entries)
        _RelationDelta(
          label: '${c.characterName(e.key)} 호감 ${_signed(e.value)}',
          up: e.value > 0,
        ),
      for (final e in d.trust.entries)
        _RelationDelta(
          label: '${c.characterName(e.key)} 신뢰 ${_signed(e.value)}',
          up: e.value > 0,
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
          // 1. 오늘 바뀐 수치. 막대가 오늘 값으로 흘러가고 오른쪽에 '42 (+3)'.
          StatBars(state: s, delta: d.stats),

          // 2. 관계 변화. 한 줄씩 차례로 쌓인다.
          if (hasRelation) ...[
            const SizedBox(height: AppSpace.sectionGap),
            const SectionHeader(title: '관계 변화'),
            for (var i = 0; i < relations.length; i++)
              _Reveal(
                index: i,
                child: StatTile(
                  label: relations[i].label,
                  // 색(상승/하락) + 부호(라벨 안) + 화살표 3중 표시.
                  accent: context.tokens.deltaColor(good: relations[i].up),
                  icon: relations[i].up
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                ),
              ),
          ],

          // 3. 클리프행어. 하루의 마지막 줄이자 내일의 첫 줄.
          if (cliffhanger != null) ...[
            const SizedBox(height: AppSpace.sectionGap),
            _Reveal(
              index: relations.length,
              child: _CliffhangerCard(text: cliffhanger),
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
            '스트레스 ${s.stat(Stat.stress)} · 흑역사 ${s.album.length}개',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: const BannerSlot(),
    );
  }

  static String _signed(int v) => v > 0 ? '+$v' : '$v';
}

/// 관계 변화 한 줄분.
class _RelationDelta {
  final String label;
  final bool up;
  const _RelationDelta({required this.label, required this.up});
}

/// 내일의 예고. 좌측 청록 띠로 "아직 안 끝난 줄" 임을 표시한다.
class _CliffhangerCard extends StatelessWidget {
  final String text;
  const _CliffhangerCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return AppCard(
      accentStripe: scheme.tertiary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.more_horiz, size: 20, color: scheme.tertiary),
          const SizedBox(width: AppSpace.md),
          // 컨트롤러가 준 문장을 그대로 한 덩어리로 둔다(테스트 고정).
          Expanded(child: Text(text, style: context.text.bodyLarge)),
        ],
      ),
    );
  }
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
