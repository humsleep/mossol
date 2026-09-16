/// 화면들이 공유하는 부품.
///
/// 규격은 docs/DESIGN_SYSTEM.md §3. 색·간격·모서리·시간은 전부
/// design_system.dart 에서 꺼내 쓴다. 이 파일에 `Colors.*` 나 `Color(0x...)`,
/// 체계 밖의 숫자는 쓰지 않는다.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/ad_manager.dart';
import '../engine/models.dart';
import 'design_system.dart';

// ---------------------------------------------------------------------------
// 0. 의미 톤
// ---------------------------------------------------------------------------

/// 의미 톤. 색 + 아이콘 + 낱말을 한 벌로 묶는다.
///
/// 색만으로 뜻을 전하지 않기 위해 톤마다 기본 아이콘을 함께 들고 있다.
enum AppTone { neutral, success, warning, danger, info, brand }

/// 톤 한 벌이 풀린 결과. 배경·글자·테두리·아이콘이 항상 같이 움직인다.
@immutable
class _Tone {
  final Color bg;
  final Color fg;
  final Color line;
  final IconData icon;
  const _Tone(this.bg, this.fg, this.line, this.icon);
}

_Tone _toneOf(BuildContext context, AppTone tone) {
  final t = context.tokens;
  final scheme = context.scheme;
  switch (tone) {
    case AppTone.neutral:
      return _Tone(
        scheme.surfaceContainerLow,
        scheme.onSurface,
        scheme.outlineVariant,
        Icons.remove,
      );
    case AppTone.success:
      return _Tone(
        t.successContainer,
        t.onSuccessContainer,
        t.success,
        Icons.check_circle_outline,
      );
    case AppTone.warning:
      return _Tone(
        t.warningContainer,
        t.onWarningContainer,
        t.warning,
        Icons.warning_amber_rounded,
      );
    case AppTone.danger:
      return _Tone(
        t.dangerContainer,
        t.onDangerContainer,
        t.danger,
        Icons.error_outline,
      );
    case AppTone.info:
      return _Tone(
        t.infoContainer,
        t.onInfoContainer,
        t.info,
        Icons.lightbulb_outline,
      );
    case AppTone.brand:
      return _Tone(
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        scheme.primary,
        Icons.auto_awesome,
      );
  }
}

/// 스탯별 아이콘. 색만으로 스탯을 구분하지 않기 위해 라벨과 함께 쓴다.
IconData _statIcon(String key) {
  switch (key) {
    case Stat.charm:
      return Icons.auto_awesome;
    case Stat.talk:
      return Icons.chat_bubble_outline;
    case Stat.esteem:
      return Icons.self_improvement;
    case Stat.sense:
      return Icons.visibility_outlined;
    case Stat.money:
      return Icons.payments_outlined;
    case Stat.stress:
      return Icons.bolt;
    default:
      return Icons.circle_outlined;
  }
}

// ---------------------------------------------------------------------------
// 1. 진행 막대
// ---------------------------------------------------------------------------

/// 모든 진행 막대. `LinearProgressIndicator` 를 직접 쓰지 않는다.
///
/// [semanticLabel] 은 필수다. 막대는 색과 길이로만 말하므로 스크린리더에게
/// 줄 문장이 없으면 정보가 사라진다.
///
/// 채움 방향은 `Directionality` 를 따른다. 값이 오르면 나쁜 스탯
/// (스트레스)은 rtl 로 감싸 오른쪽에서 자라게 해 형태로 구분한다.
class AppProgressBar extends StatelessWidget {
  final double value;
  final String semanticLabel;
  final double height;
  final Color? fill;
  final Color? track;

  const AppProgressBar({
    super.key,
    required this.value,
    required this.semanticLabel,
    this.height = AppSpace.sm,
    this.fill,
    this.track,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: AppRadius.rXs,
            child: ColoredBox(
              color: track ?? context.tokens.gaugeTrack,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: v,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill ?? context.scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. 스탯
// ---------------------------------------------------------------------------

/// 스탯 막대. 라벨 · 막대 · 값(+변화량)을 한 줄에 정렬한다.
///
/// - 값이 바뀌면 막대가 부드럽게 따라간다(`AppMotion.gauge`).
/// - 스트레스는 오르면 나쁜 유일한 스탯이라 **오른쪽에서 자라는 막대**와
///   위험색, 번개 아이콘 세 가지로 다른 스탯과 구분한다.
/// - 변화량은 색 + 부호 + 화살표 아이콘 3중으로 표시한다.
class StatBars extends StatelessWidget {
  final GameState state;
  final Map<String, int>? delta;
  final bool compact;
  final List<String>? keys;

  const StatBars({
    super.key,
    required this.state,
    this.delta,
    this.compact = false,
    this.keys,
  });

  /// 값이 오르면 좋은 스탯인지. 스트레스만 반대다.
  static bool _isGood(String key, int d) => key == Stat.stress ? d < 0 : d > 0;

  /// '42' 또는 '42 (+3)'. 괄호 형식은 정산 테스트가 고정한 표기다.
  String _valueLabel(String k) {
    final v = state.stat(k).toString();
    final d = delta?[k];
    if (d == null || d == 0) return v;
    return '$v (${d > 0 ? '+' : ''}$d)';
  }

  @override
  Widget build(BuildContext context) {
    final show = keys ?? Stat.visible;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final k in show) _row(context, k)],
    );
  }

  Widget _row(BuildContext context, String k) {
    final t = context.tokens;
    final scheme = context.scheme;
    final scaler = MediaQuery.textScalerOf(context);

    // 고정 폭은 1.3배 글꼴에서 잘린다. 배율을 곱해 두고 상한만 건다.
    final labelW = scaler.scale(compact ? 52.0 : 58.0).clamp(48.0, 132.0);
    final valueW = scaler.scale(compact ? 58.0 : 66.0).clamp(52.0, 148.0);

    final value = state.stat(k);
    final max = Stat.maxOf(k);
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble();
    final inverted = k == Stat.stress;
    final d = delta?[k];
    final hasDelta = d != null && d != 0;
    final good = hasDelta && _isGood(k, d);
    final label = Stat.label(k);

    return Semantics(
      container: true,
      label: inverted
          ? '$label $value / $max, 낮을수록 좋다'
          : '$label $value / $max',
      value: hasDelta ? '${d > 0 ? '+' : ''}$d' : null,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? AppSpace.xxs : AppSpace.xs,
          ),
          child: Row(
            children: [
              SizedBox(
                width: labelW,
                child: Row(
                  children: [
                    Icon(
                      _statIcon(k),
                      size: compact ? 14 : 16,
                      color: t.statColor(k),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (compact
                                ? context.text.labelSmall
                                : context.text.labelMedium)
                            ?.copyWith(color: scheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: ratio, end: ratio),
                  duration: AppMotion.base(context),
                  curve: AppMotion.curve(context, AppMotion.gauge),
                  builder: (context, v, _) {
                    final animated = AppProgressBar(
                      value: v,
                      semanticLabel: label,
                      height: compact ? AppSpace.xs + 2 : AppSpace.sm,
                      fill: t.statColor(k),
                    );
                    // 스트레스만 오른쪽에서 자란다.
                    return inverted
                        ? Directionality(
                            textDirection: TextDirection.rtl,
                            child: animated,
                          )
                        : animated;
                  },
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              SizedBox(
                width: valueW,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (hasDelta) ...[
                      Icon(
                        good ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 13,
                        color: t.deltaColor(good: good),
                      ),
                      const SizedBox(width: AppSpace.xxs),
                    ],
                    Flexible(
                      child: Text(
                        _valueLabel(k),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: hasDelta
                            ? t.numericSmall.copyWith(
                                color: t.deltaColor(good: good),
                              )
                            : t.numericSmall.copyWith(
                                color: scheme.onSurface,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 라벨 · 값 · 변화량 한 줄. 정산·결과 화면에서 문장 나열을 대체한다.
///
/// [label] 은 넘어온 문자열을 그대로 하나의 Text 로 렌더한다. 정산 화면처럼
/// `'서연 호감 +4'` 한 덩어리가 고정된 자리에서는 그 문장을 [label] 로 넘기고
/// [good] 과 [icon] 으로 방향을 함께 표시한다.
class StatTile extends StatelessWidget {
  final String label;
  final String? value;
  final String? delta;
  final bool? good;
  final IconData? icon;
  final Color? accent;

  const StatTile({
    super.key,
    required this.label,
    this.value,
    this.delta,
    this.good,
    this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final dir = good == null ? null : t.deltaColor(good: good!);
    final arrow = good == null
        ? Icons.remove
        : good!
        ? Icons.arrow_upward
        : Icons.arrow_downward;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpace.minTouch),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Row(
          children: [
            if (accent != null) ...[
              Container(
                width: AppSpace.sm,
                height: AppSpace.sm,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: AppRadius.rPill,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
            ],
            if (icon != null) ...[
              Icon(icon, size: 18, color: accent ?? scheme.onSurfaceVariant),
              const SizedBox(width: AppSpace.sm),
            ],
            Expanded(
              child: Text(label, style: context.text.bodyMedium),
            ),
            if (value != null) ...[
              const SizedBox(width: AppSpace.sm),
              Text(
                value!,
                style: t.numericMedium.copyWith(color: scheme.onSurface),
              ),
            ],
            if (delta != null) ...[
              const SizedBox(width: AppSpace.sm),
              Icon(arrow, size: 14, color: dir ?? scheme.onSurfaceVariant),
              const SizedBox(width: AppSpace.xxs),
              Text(
                delta!,
                style: t.numericSmall.copyWith(
                  color: dir ?? scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. 하트 · 콤보
// ---------------------------------------------------------------------------

/// 하트 게이지와 다음 회복까지 남은 시간.
///
/// 빈 하트는 `Icons.favorite_border` 로 최대 개수만큼 항상 그린다.
/// 남은 개수를 색 차이만으로 알리지 않기 위해 채움/테두리 두 모양을 쓴다.
class HeartsRow extends StatelessWidget {
  final int hearts;
  final int max;
  final Duration nextIn;
  final bool showTimer;

  const HeartsRow({
    super.key,
    required this.hearts,
    required this.max,
    required this.nextIn,
    this.showTimer = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final mm = nextIn.inMinutes;
    final ss = nextIn.inSeconds % 60;
    final timer = showTimer && hearts < max;

    return Semantics(
      label: '하트 $hearts개 / $max개',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadius.rPill,
          border: Border.all(
            color: scheme.outlineVariant,
            width: AppBorderWidth.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < max; i++)
              ExcludeSemantics(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == max - 1 ? 0 : AppSpace.xxs,
                  ),
                  child: Icon(
                    i < hearts ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: i < hearts ? t.heart : t.heartEmpty,
                  ),
                ),
              ),
            if (timer) ...[
              const SizedBox(width: AppSpace.sm),
              Flexible(
                child: Text(
                  '다음 하트 ${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.numericSmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 물오름(콤보) 배지. 3연속부터 색과 아이콘이 함께 바뀐다.
class ComboBadge extends StatelessWidget {
  final int combo;
  final bool onFire;
  final bool dense;

  const ComboBadge({
    super.key,
    required this.combo,
    required this.onFire,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = onFire ? t.comboFire : t.comboIdle;
    final fg = onFire ? t.onComboFire : t.onComboIdle;

    return AnimatedContainer(
      duration: AppMotion.base(context),
      curve: AppMotion.curve(context, AppMotion.emphasized),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpace.sm : AppSpace.md,
        vertical: dense ? AppSpace.xs : AppSpace.sm - 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.rPill,
        border: Border.all(
          color: onFire ? t.comboFire : context.scheme.outlineVariant,
          width: AppBorderWidth.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            onFire ? Icons.local_fire_department : Icons.trending_up,
            size: dense ? 14 : 16,
            color: fg,
          ),
          const SizedBox(width: AppSpace.xs),
          Text(
            onFire ? '물올랐다 $combo' : '$combo연속',
            style: t.badgeText.copyWith(
              color: fg,
              fontSize: dense ? 11.5 : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. 배너 광고 자리
// ---------------------------------------------------------------------------

/// 배너 슬롯. 광고를 지원하지 않는 환경에서는 빈 공간도 차지하지 않는다.
///
/// 로드 로직과 재시도 백오프는 손대지 않는다. 시각만: 광고가 콘텐츠로 보이지
/// 않도록 위쪽에 경계선을 두고, 위 콘텐츠(버튼)와 8 이상 떨어뜨린다.
class BannerSlot extends StatefulWidget {
  /// false 면 SafeArea 를 감싸지 않는다(이미 SafeArea 안일 때).
  final bool safeArea;

  const BannerSlot({super.key, this.safeArea = true});

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  static const _maxAttempts = 5;

  BannerAd? _ad;
  bool _loaded = false;
  int _attempts = 0;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// SDK 초기화 전에 요청하면 조용히 실패한다. 동의 절차가 끝날 때까지 기다렸다 붙인다.
  void _load() {
    if (!mounted || !AdManager.instance.supported) return;
    if (!AdManager.instance.sdkInitialized) return _scheduleRetry();

    final template = AdManager.instance.createBanner();
    _ad = BannerAd(
      adUnitId: template.adUnitId,
      size: template.size,
      request: template.request,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _ad = null;
          debugPrint('배너 로드 실패: ${err.message}');
          _scheduleRetry();
        },
      ),
    )..load();
  }

  /// 무한 재요청은 무효 트래픽으로 잡힌다. 횟수를 제한하고 간격을 늘린다.
  void _scheduleRetry() {
    if (!mounted || _attempts >= _maxAttempts) return;
    _attempts++;
    _retry?.cancel();
    final seconds = (1 << _attempts).clamp(2, 60);
    _retry = Timer(Duration(seconds: seconds), _load);
  }

  @override
  void dispose() {
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    // 광고가 없으면 높이 0. 여백도 경계선도 만들지 않는다.
    if (ad == null || !_loaded) return const SizedBox.shrink();

    final scheme = context.scheme;
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
    if (widget.safeArea) content = SafeArea(top: false, child: content);

    return Container(
      // 위 콘텐츠(버튼)와의 간격. 경계선 위로 8, 아래로 8.
      margin: const EdgeInsets.only(top: AppSpace.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant,
            width: AppBorderWidth.hairline,
          ),
        ),
      ),
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// 5. 채팅 말풍선
// ---------------------------------------------------------------------------

/// 채팅 한 줄. `who` 에 따라 네 가지 위계로 갈린다.
///
/// - `them` — 흰 종이 카드. 1px 테두리, 왼쪽 정렬, 묶음 첫 줄에만 이름표.
/// - `me` — 로즈 단색. 테두리 없음, 오른쪽 정렬.
/// - `narr` — 말풍선이 아니다. 좌측 세로 선 + 이탤릭 조판으로 물러난다.
/// - `sys` — 가운데 중립 pill.
///
/// 꼬리는 삼각형을 그리지 않고 묶음 **마지막 줄의 모서리 하나만** 깎는다
/// (트레이드드레스 회피). 등장은 6포인트 상승 + 페이드 한 번, 220ms.
class ChatBubble extends StatelessWidget {
  final Line line;
  final String partnerName;

  /// 상대 이름·점에 쓸 캐릭터 강조색. null 이면 tokens.neutralAccent.
  final CharacterAccent? accent;

  /// 같은 사람이 연속으로 말하는 묶음의 첫 줄인지. 이름 표시 여부.
  final bool isFirstOfGroup;

  /// 묶음의 마지막 줄인지. 꼬리(각진 모서리) 여부.
  final bool isLastOfGroup;

  const ChatBubble({
    super.key,
    required this.line,
    required this.partnerName,
    this.accent,
    this.isFirstOfGroup = true,
    this.isLastOfGroup = true,
  });

  @override
  Widget build(BuildContext context) {
    switch (line.who) {
      case 'narr':
        return _narration(context);
      case 'sys':
        return _system(context);
      default:
        return _bubble(context);
    }
  }

  /// 지문. 말풍선이 아니라 왼쪽 선 + 이탤릭으로 조판한다.
  Widget _narration(BuildContext context) {
    final t = context.tokens;
    return _Entrance(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xl,
          vertical: AppSpace.sm,
        ),
        // 세로선을 Row + stretch 로 만들면 리스트 안에서 높이가 무한이 되어 터진다.
        // 왼쪽 테두리로 그리면 글 높이에 저절로 맞는다.
        child: Container(
          padding: const EdgeInsets.only(left: AppSpace.md),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: context.scheme.outlineVariant,
                width: AppBorderWidth.emphasis,
              ),
            ),
          ),
          child: Text(
            line.text,
            style: context.text.bodyMedium?.copyWith(
              color: t.narration,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  /// 시스템 줄. 특정 메신저를 닮지 않은 중립 pill.
  Widget _system(BuildContext context) {
    final t = context.tokens;
    return _Entrance(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.xs + 2,
            ),
            decoration: BoxDecoration(
              color: context.scheme.surfaceContainerHigh,
              borderRadius: AppRadius.rPill,
            ),
            child: Text(
              line.text.isEmpty ? '— 읽음 —' : line.text,
              textAlign: TextAlign.center,
              style: context.text.labelSmall?.copyWith(color: t.systemLine),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context) {
    final t = context.tokens;
    final me = line.who == 'me';
    final name = line.name ?? partnerName;
    final a = accent ?? t.neutralAccent;
    final showName = !me && isFirstOfGroup && name.isNotEmpty;

    return _Entrance(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.md,
          right: AppSpace.md,
          // 사람이 바뀌면 md, 같은 사람이 이어 말하면 xs.
          top: isFirstOfGroup ? AppSpace.md : AppSpace.xs,
        ),
        child: Column(
          crossAxisAlignment: me
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (showName)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpace.xs,
                  bottom: AppSpace.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: AppSpace.xs + 2,
                      height: AppSpace.xs + 2,
                      decoration: BoxDecoration(
                        color: a.base,
                        borderRadius: AppRadius.rPill,
                      ),
                      margin: const EdgeInsets.only(right: AppSpace.xs),
                    ),
                    Text(
                      name,
                      style: context.text.labelSmall?.copyWith(color: a.base),
                    ),
                  ],
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              child: Container(
                padding: AppInsets.bubble,
                decoration: BoxDecoration(
                  color: me ? t.bubbleMine : t.bubbleTheirs,
                  borderRadius: AppRadius.bubble(
                    mine: me,
                    tail: isLastOfGroup,
                  ),
                  // 상대 말풍선은 종이 카드처럼 실선 테두리를 둔다.
                  border: me
                      ? null
                      : Border.all(
                          color: t.bubbleBorder,
                          width: AppBorderWidth.hairline,
                        ),
                ),
                child: Text(
                  line.text,
                  style: t.bubbleText.copyWith(
                    color: me ? t.onBubbleMine : t.onBubbleTheirs,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 한 번만 재생되는 등장 연출. 읽는 흐름을 끊지 않도록 6포인트 상승 + 페이드만.
/// 동작 줄이기가 켜져 있으면 즉시 최종 상태로 둔다.
class _Entrance extends StatefulWidget {
  final Widget child;
  const _Entrance({required this.child});

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.dBase,
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: AppMotion.standard,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (context, child) => Opacity(
      opacity: _a.value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - _a.value) * (AppSpace.xs + 2)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

// ---------------------------------------------------------------------------
// 6. 뼈대 · 목록 · 패널
// ---------------------------------------------------------------------------

/// 섹션 제목. 묶음의 시작을 알린다.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailingText;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailingText,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.md),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: context.text.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null)
          trailing!
        else if (trailingText != null)
          Padding(
            padding: const EdgeInsets.only(left: AppSpace.sm),
            child: Text(trailingText!, style: context.tokens.numericSmall),
          ),
      ],
    ),
  );
}

/// 집안 카드. 기본 `Card` 대신 이걸 쓴다.
///
/// 깊이는 그림자보다 표면 단계와 테두리로 만든다. 다크 모드에서는 [raised]
/// 가 아니면 그림자를 아예 쓰지 않는다.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final AppTone tone;
  final Color? accentStripe;
  final VoidCallback? onTap;
  final bool raised;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.tone = AppTone.neutral,
    this.accentStripe,
    this.onTap,
    this.raised = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tn = _toneOf(context, tone);
    final pad = padding ?? AppInsets.card;

    Widget body = Padding(
      padding: accentStripe == null
          ? pad
          : pad.add(
              const EdgeInsetsDirectional.only(start: AppSpace.xs),
            ),
      child: child,
    );

    if (onTap != null) {
      body = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.rLg,
          child: body,
        ),
      );
    }

    if (accentStripe != null) {
      body = Stack(
        children: [
          body,
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: accentStripe),
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tn.bg,
        borderRadius: AppRadius.rLg,
        border: Border.all(
          color: tone == AppTone.neutral ? context.scheme.outlineVariant : tn.line,
          width: AppBorderWidth.hairline,
        ),
        boxShadow: raised
            ? t.shadowRaised
            : context.isDark
            ? null
            : t.shadowCard,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: AppRadius.rLg,
        clipBehavior: Clip.antiAlias,
        child: body,
      ),
    );
  }
}

/// 목록 한 줄. `Card` + `ListTile` 조합을 대체한다.
///
/// 높이를 고정하지 않는다. 1.3배 글꼴에서 제목이 세 줄이 되어도 늘어난다.
class AppListRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  /// 잠긴 항목. 글자색을 내리고 자물쇠를 함께 보여 주며 onTap 을 무시한다.
  final bool locked;

  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final fg = locked ? t.lockedForeground : scheme.onSurface;

    Widget? tail = trailing;
    if (tail == null && locked) {
      tail = Icon(Icons.lock_outline, size: 18, color: t.lockedForeground);
    } else if (tail == null && showChevron) {
      tail = Icon(
        Icons.chevron_right,
        size: 20,
        color: scheme.onSurfaceVariant,
      );
    }

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.rMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: locked ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            borderRadius: AppRadius.rMd,
            border: Border.all(
              color: scheme.outlineVariant,
              width: AppBorderWidth.hairline,
            ),
          ),
          padding: AppInsets.cardTight,
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpace.md),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.titleSmall?.copyWith(
                        fontSize: 15,
                        color: fg,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xxs),
                        child: Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: locked
                                ? t.lockedForeground
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (tail != null) ...[
                const SizedBox(width: AppSpace.sm),
                tail,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 하단 고정 패널. 이벤트 화면의 선택지·결과 패널 껍데기.
///
/// 최대 높이 55% 와 내부 스크롤은 큰 글꼴 대응 요건이라 유지한다.
class BottomPanel extends StatelessWidget {
  final Widget child;
  final AppTone tone;
  final double maxHeightFactor;

  const BottomPanel({
    super.key,
    required this.child,
    this.tone = AppTone.neutral,
    this.maxHeightFactor = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tn = _toneOf(context, tone);
    final bg = tone == AppTone.neutral
        ? context.scheme.surfaceContainerLow
        : tn.bg;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        boxShadow: t.shadowSheet,
        border: Border(
          top: BorderSide(
            color: tone == AppTone.neutral
                ? context.scheme.outlineVariant
                : tn.line,
            width: AppBorderWidth.hairline,
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: AppInsets.panel,
            child: child,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. 배지 · 칩 · 빈 상태 · 선택지
// ---------------------------------------------------------------------------

/// 결과 배지. 색과 아이콘과 낱말로 동시에 알린다.
class ResultBadge extends StatelessWidget {
  final AppTone tone;
  final String label;
  final String? detail;
  final IconData? icon;
  final bool large;

  const ResultBadge({
    super.key,
    required this.tone,
    required this.label,
    this.detail,
    this.icon,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final tn = _toneOf(context, tone);
    final labelStyle = large
        ? context.text.headlineSmall?.copyWith(color: tn.fg)
        : context.tokens.badgeText.copyWith(color: tn.fg);

    final head = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon ?? tn.icon, size: large ? 24 : 16, color: tn.fg),
        SizedBox(width: large ? AppSpace.sm : AppSpace.xs),
        Flexible(
          child: Text(
            label,
            textAlign: large ? TextAlign.center : TextAlign.start,
            style: labelStyle,
          ),
        ),
      ],
    );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: large
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        head,
        if (detail != null && detail!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xs),
            child: Text(
              detail!,
              textAlign: large ? TextAlign.center : TextAlign.start,
              style: context.text.bodyMedium?.copyWith(color: tn.fg),
            ),
          ),
      ],
    );

    return Container(
      padding: large
          ? AppInsets.card
          : const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.sm,
            ),
      decoration: BoxDecoration(
        color: tn.bg,
        borderRadius: large ? AppRadius.rLg : AppRadius.rSm,
        border: Border.all(
          color: tn.line,
          width: AppBorderWidth.hairline,
        ),
      ),
      child: large ? Center(child: body) : body,
    );
  }
}

/// 캐릭터 칩.
///
/// 본문은 반드시 하나의 Text 로 `'$name ♥$affection ✓$trust'` 형태를 유지한다.
class CharacterChip extends StatelessWidget {
  final String name;
  final int affection;
  final int trust;
  final CharacterAccent? accent;
  final bool dimmed;
  final VoidCallback? onTap;

  const CharacterChip({
    super.key,
    required this.name,
    required this.affection,
    required this.trust,
    this.accent,
    this.dimmed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = accent ?? t.neutralAccent;
    final fg = dimmed ? t.lockedForeground : a.onContainer;
    final bg = dimmed ? context.scheme.surfaceContainer : a.container;
    final line = dimmed ? context.scheme.outlineVariant : a.base;

    final body = Container(
      constraints: const BoxConstraints(minHeight: AppSpace.minTouch),
      padding: AppInsets.chip,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.rPill,
        border: Border.all(color: line, width: AppBorderWidth.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSpace.sm,
            height: AppSpace.sm,
            margin: const EdgeInsets.only(right: AppSpace.sm),
            decoration: BoxDecoration(
              color: line,
              borderRadius: AppRadius.rPill,
            ),
          ),
          // 한 덩어리 Text 를 유지한다(테스트 고정).
          Text(
            '$name ♥$affection ✓$trust',
            style: context.text.labelMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      type: MaterialType.transparency,
      borderRadius: AppRadius.rPill,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rPill,
        child: body,
      ),
    );
  }
}

/// 빈 상태. 아이콘 + 제목 + 설명 + (선택) 행동.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: AppRadius.rPill,
              ),
              child: Icon(icon, size: 32, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpace.xxl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 이벤트 선택지 버튼.
///
/// 내부는 반드시 `OutlinedButton` 하나여야 하고 [text] 가 그 자손 Text 여야
/// 한다. 선택지 영역에 다른 OutlinedButton 을 넣지 마라(테스트 고정).
class ChoiceButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final String? lockedReason;
  final String? trailingLabel;
  final IconData? leadingIcon;
  final bool recommended;
  final AppTone trailingTone;

  const ChoiceButton({
    super.key,
    required this.text,
    this.onPressed,
    this.lockedReason,
    this.trailingLabel,
    this.leadingIcon,
    this.recommended = false,
    this.trailingTone = AppTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final locked = onPressed == null;
    final fg = locked ? t.lockedForeground : scheme.onSurface;
    final tn = _toneOf(context, trailingTone);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        // 컴포넌트 안에서만 테마 기본값을 손본다. 추천 선택지는 테두리를 굵게.
        style: OutlinedButton.styleFrom(
          alignment: AlignmentDirectional.centerStart,
          padding: AppInsets.cardTight,
          side: BorderSide(
            color: recommended ? scheme.primary : scheme.outlineVariant,
            width: recommended
                ? AppBorderWidth.emphasis
                : AppBorderWidth.hairline,
          ),
        ),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                size: 18,
                color: locked ? t.lockedForeground : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpace.sm),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: context.text.labelLarge?.copyWith(
                      color: fg,
                      height: 1.35,
                    ),
                  ),
                  if (lockedReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.xxs),
                      child: Text(
                        lockedReason!,
                        style: context.text.bodySmall?.copyWith(
                          color: t.lockedForeground,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailingLabel != null) ...[
              const SizedBox(width: AppSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: AppSpace.xxs,
                ),
                decoration: BoxDecoration(
                  color: trailingTone == AppTone.neutral
                      ? scheme.surfaceContainerHigh
                      : tn.bg,
                  borderRadius: AppRadius.rSm,
                ),
                child: Text(
                  trailingLabel!,
                  style: t.numericSmall.copyWith(
                    color: trailingTone == AppTone.neutral
                        ? scheme.onSurfaceVariant
                        : tn.fg,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
