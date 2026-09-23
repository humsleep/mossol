import 'package:flutter/material.dart';

import '../audio/sfx_service.dart';
import '../engine/retention.dart' show TomorrowPeek;
import '../game_controller.dart';
import '../minigames/minigame.dart' show CenteredScrollColumn;
import 'call_view.dart' show CallBackdrop;
import 'design_system.dart';
import 'keep_all.dart';
import 'retention_widgets.dart';

/// 날짜 전환 카드. `Phase.dayStart` 동안 뜨고, 박자가 끝나거나 탭하면
/// [GameController.beginMorning] 으로 행동 화면(룰렛)으로 넘어간다.
///
/// 규격: docs/overhaul/02_game_loop.md §2(내용·시간), 03_chat_ui_spec.md §4.1(시각),
/// DESIGN_SYSTEM §2.13. 전화·알림과 같은 "밤의 사건" 톤([CallBackdrop])으로 하루가 넘어간다.
///
/// 시간은 **`AnimationController` 하나**로 돈다(체류 = 컨트롤러 길이). `Timer` 를 쓰면
/// 위젯 테스트의 `pumpAndSettle` 이 카드를 넘기지 못한다(02 §2.3). 체류는 모션이 아니라
/// 게임의 박자라 동작 줄이기에서도 줄이지 않는다 — 진입·퇴장 연출만 즉시가 된다.
class DayTransitionScreen extends StatefulWidget {
  final GameController c;
  const DayTransitionScreen({super.key, required this.c});

  /// 체류(진입·퇴장 포함). `next` 1.4초, `first` 2.2초, `resume` 1.0초.
  static const beatNext = Duration(milliseconds: 1400);
  static const beatFirst = Duration(milliseconds: 2200);
  static const beatResume = Duration(milliseconds: 1000);

  /// 첫 350ms 는 탭을 무시한다 — '다음 날로' 를 누른 손가락의 두 번째 탭 방지.
  static const tapGuard = Duration(milliseconds: 350);

  /// 고정 문구(§4.1).
  static const skipHint = '탭해서 넘기기';

  static Duration beatFor(DayCardVariant v) => switch (v) {
    DayCardVariant.next => beatNext,
    DayCardVariant.first => beatFirst,
    DayCardVariant.resume => beatResume,
  };

  @override
  State<DayTransitionScreen> createState() => _DayTransitionScreenState();
}

class _DayTransitionScreenState extends State<DayTransitionScreen>
    with SingleTickerProviderStateMixin {
  late final DayCard _card =
      widget.c.dayCard ??
      // 카드 없이 이 화면에 오면(디버그·이상 경로) 상태만으로 만든다.
      DayCard(
        variant: DayCardVariant.resume,
        day: widget.c.state?.day ?? 1,
        run: widget.c.state?.run ?? 1,
        chapter: widget.c.state?.chapter(widget.c.config) ?? 1,
        weekday: DayCard.weekdayFor(widget.c.state?.day ?? 1),
        weather: '맑음',
      );

  late final Duration _beat = DayTransitionScreen.beatFor(_card.variant);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _beat,
    // 체류는 게임의 박자다. 동작 줄이기가 켜져도(기본은 5% 로 줄어든다) 그대로 둔다.
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void initState() {
    super.initState();
    // 아침 소리 + light 진동(05 §1 #11). 룰렛 소리와 겹치지 않게 카드가 끝난 뒤 룰렛이 뜬다.
    SfxService.instance.cue(Sfx.dayStart);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.c.beginMorning();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 탭: 첫 350ms 는 무시, 그 뒤엔 곧바로 끝으로(멱등 — beginMorning 이 두 번 넘어가지 않는다).
  void _skip() {
    if (_c.value * _beat.inMilliseconds <
        DayTransitionScreen.tapGuard.inMilliseconds) {
      return;
    }
    if (_c.status == AnimationStatus.completed) return;
    _c.value = _c.upperBound;
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final reduced = AppMotion.reduced(context);
    // 진입 dSlow · 퇴장 dBase 를 컨트롤러 구간으로 환산. 축소 모션이면 둘 다 즉시.
    final entry = reduced
        ? 0.0
        : AppMotion.dSlow.inMilliseconds / _beat.inMilliseconds;
    final exit = reduced
        ? 0.0
        : AppMotion.dBase.inMilliseconds / _beat.inMilliseconds;
    final fadeIn = CurvedAnimation(
      parent: _c,
      curve: Interval(
        0,
        entry <= 0 ? 0.0001 : entry,
        curve: AppMotion.standard,
      ),
    );
    final fadeOut = CurvedAnimation(
      parent: _c,
      curve: Interval(
        (1 - exit).clamp(0.0, 0.9999),
        1,
        curve: AppMotion.standard,
      ),
    );

    return CallBackdrop(
      child: Builder(
        builder: (context) {
          final scheme = context.scheme;
          final muted = scheme.onSurfaceVariant;
          final isFirst = card.variant == DayCardVariant.first;
          final isNext = card.variant == DayCardVariant.next;
          final pill = card.chapterTitle == null
              ? '${card.chapter}장'
              : '${card.chapter}장 · ${card.chapterTitle}';
          final subtitle = isFirst
              ? '${card.run}회차 · 첫날 · ${card.weekday} · ${card.weather}'
              : '${card.day}일째 아침 · ${card.weekday} · ${card.weather}';
          final hintName = card.hintName;
          final hintId = card.hintCharacterId;
          final semanticsLabel = isFirst
              ? '${card.run}회차 첫날, ${card.weekday}, ${card.weather}'
              : '${card.day}일째 아침, ${card.weekday}, ${card.weather}';

          return GestureDetector(
            key: const Key('day-card'),
            behavior: HitTestBehavior.opaque,
            onTap: _skip,
            child: Semantics(
              container: true,
              liveRegion: true,
              button: true,
              label: semanticsLabel,
              hint: DayTransitionScreen.skipHint,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, child) => Opacity(
                  opacity: (fadeIn.value * (1 - fadeOut.value)).clamp(0.0, 1.0),
                  child: child,
                ),
                child: CenteredScrollColumn(
                  padding: AppInsets.screenX,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        padding: AppInsets.chip,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: AppRadius.rPill,
                        ),
                        child: Text(
                          keepAll(pill),
                          style: context.text.labelMedium?.copyWith(
                            color: muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    // 이 화면의 강조는 D+N 하나. displayLarge 의 첫 사용처.
                    ExcludeSemantics(
                      child: AnimatedBuilder(
                        animation: fadeIn,
                        builder: (context, child) => Transform.scale(
                          scale: 0.92 + 0.08 * fadeIn.value,
                          child: child,
                        ),
                        child: Text(
                          'D+${card.day}',
                          style: AppTypography.tabular(
                            (context.text.displayLarge ?? const TextStyle())
                                .copyWith(color: scheme.onSurface),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    ExcludeSemantics(
                      child: Text(
                        keepAll(subtitle),
                        textAlign: TextAlign.center,
                        style: context.text.titleMedium?.copyWith(color: muted),
                      ),
                    ),
                    // 예고: 정산에서 본 "내일" 이 "오늘" 이 된다. 없으면 줄 자체가 없다.
                    if (isNext && hintName != null && hintId != null) ...[
                      const SizedBox(height: AppSpace.xl),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: TomorrowLine(
                          characterId: hintId,
                          line: TomorrowPeek.todayLineFor(hintName),
                          preview: card.hintPreview,
                        ),
                      ),
                    ],
                    // 밤사이 멀어진 사람 한 줄.
                    if (isNext && card.overnight != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        keepAll(card.overnight!),
                        key: const Key('day-card-overnight'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                    // 새 회차 첫날: 지난 판이 어떻게 끝났는지.
                    if (isFirst && card.previousRunLine != null) ...[
                      const SizedBox(height: AppSpace.xl),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: PreviousRunNote(text: card.previousRunLine!),
                      ),
                    ],
                    const SizedBox(height: AppSpace.xxxl),
                    ExcludeSemantics(
                      child: Text(
                        DayTransitionScreen.skipHint,
                        style: context.text.labelMedium?.copyWith(color: muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
