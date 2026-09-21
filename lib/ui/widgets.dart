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
import '../engine/mbti.dart';
import '../engine/models.dart';
import 'design_system.dart';

import 'photo_card.dart';
import 'portraits.dart';
import 'keep_all.dart';

export 'photo_card.dart';

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

/// 부호 붙인 정수. '+3' / '-2' / '0'.
String signed(int v) => v > 0 ? '+$v' : '$v';

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

  TextStyle? _labelStyle(BuildContext context) =>
      (compact ? context.text.labelSmall : context.text.labelMedium)?.copyWith(
        color: context.scheme.onSurface,
      );

  /// 가장 긴 라벨('스트레스')이 잘리지 않는 폭. 글자 배율까지 반영해 실제로 잰다.
  double _labelWidth(BuildContext context, List<String> show) {
    final scaler = MediaQuery.textScalerOf(context);
    final style = _labelStyle(context);
    var widest = 0.0;
    for (final k in show) {
      final tp = TextPainter(
        text: TextSpan(text: Stat.label(k), style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (tp.width > widest) widest = tp.width;
      tp.dispose();
    }
    final icon = compact ? 14.0 : 16.0;
    // 아이콘 + 간격 + 글자 + 반올림 여유. 화면 폭을 다 먹지 않도록 상한을 둔다.
    return (icon + AppSpace.xs + widest + AppSpace.xxs).ceilToDouble().clamp(
      48.0,
      140.0,
    );
  }

  /// 기본 순서. 돈은 잔고라 막대 다섯 줄 아래로 내린다(HOME_REDESIGN §4.2).
  /// `Stat.visible` 은 엔진 소속이라 그대로 두고 여기서만 순서를 바꾼다.
  static const _defaultOrder = [
    Stat.charm,
    Stat.talk,
    Stat.esteem,
    Stat.sense,
    Stat.stress,
    Stat.money,
  ];

  @override
  Widget build(BuildContext context) {
    final show = keys ?? _defaultOrder;
    final labelW = _labelWidth(context, show);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < show.length; i++) ...[
          // 막대 다섯 줄과 "잔고 한 줄" 은 다른 종류다. 돈 위에만 구분선.
          if (show[i] == Stat.money && i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpace.xs),
              child: Divider(),
            ),
          _row(context, show[i], labelW),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, String k, double labelW) {
    final t = context.tokens;
    final scheme = context.scheme;
    final scaler = MediaQuery.textScalerOf(context);

    // 값('42')과 변화량('+3')이 나란히 들어갈 폭. 1.3배 글꼴까지 배율을 곱한다.
    final valueW = scaler.scale(compact ? 40.0 : 88.0).clamp(36.0, 160.0);

    if (k == Stat.money) return _moneyRow(context, labelW, valueW);

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
                        style: _labelStyle(context),
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
                    // 변화량이 주인공이다. 화살표는 실제 증감 방향, 색은 좋고 나쁨.
                    if (hasDelta) ...[
                      Icon(
                        d > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 13,
                        color: t.deltaColor(good: good),
                      ),
                      const SizedBox(width: AppSpace.xxs),
                      Flexible(
                        child: Text(
                          signed(d),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.numericMedium.copyWith(
                            color: t.deltaColor(good: good),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                    ],
                    Text(
                      '$value',
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: t.numericSmall.copyWith(
                        color: hasDelta
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
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

/// 돈은 막대를 그리지 않는다. 능력치가 아니라 잔고라 상한(9999)이 목표가 아니고,
/// 막대는 초반엔 빈 채, 후반엔 의미 없는 길이로 보인다. 숫자 하나가 정확하다(§4.1).
extension _MoneyRow on StatBars {
  Widget _moneyRow(BuildContext context, double labelW, double valueW) {
    final t = context.tokens;
    final scheme = context.scheme;
    final value = state.stat(Stat.money);
    final d = delta?[Stat.money];
    final hasDelta = d != null && d != 0;
    final good = hasDelta && d > 0;
    final label = Stat.label(Stat.money);

    return Semantics(
      container: true,
      label: '$label $value',
      value: hasDelta ? signed(d) : null,
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
                      _statIcon(Stat.money),
                      size: compact ? 14 : 16,
                      color: t.statColor(Stat.money),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _labelStyle(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              // 막대 자리는 비운다. 트랙도 그리지 않는다.
              const Expanded(child: SizedBox()),
              const SizedBox(width: AppSpace.sm),
              SizedBox(
                width: valueW,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (hasDelta) ...[
                      Icon(
                        d > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 13,
                        color: t.deltaColor(good: good),
                      ),
                      const SizedBox(width: AppSpace.xxs),
                      Flexible(
                        child: Text(
                          signed(d),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.numericMedium.copyWith(
                            color: t.deltaColor(good: good),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                    ],
                    // 막대가 없는 만큼 숫자가 정보의 전부라 한 단 크게(numericMedium).
                    Text(
                      '$value',
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: t.numericMedium.copyWith(
                        color: hasDelta
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
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
    // 화살표는 실제 증감 방향을 따른다. 색([good])과 따로 논다(스트레스 +4 는 ↑ + 위험색).
    final arrow = delta == null
        ? Icons.remove
        : delta!.startsWith('-')
        ? Icons.arrow_downward
        : Icons.arrow_upward;

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
            Expanded(child: Text(label, style: context.text.bodyLarge)),
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
                style: t.numericMedium.copyWith(
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

    return BannerFrame(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      safeArea: widget.safeArea,
      child: AdWidget(ad: ad),
    );
  }
}

/// 배너 한 장의 틀. 광고 SDK 와 분리해 두어 위젯 테스트로 배치를 검증한다.
///
/// `Scaffold.bottomNavigationBar` 는 세로로 느슨한 제약(0 ~ 화면 높이)을 준다.
/// 여기서 세로로 늘어나는 위젯을 쓰면 본문이 0 높이로 밀려난다.
class BannerFrame extends StatelessWidget {
  final double width;
  final double height;
  final bool safeArea;
  final Widget child;

  const BannerFrame({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Center(
        heightFactor: 1,
        child: SizedBox(width: width, height: height, child: child),
      ),
    );
    if (safeArea) content = SafeArea(top: false, child: content);

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
    // 사진 줄은 누가 보냈든 말풍선 자리에 사진 카드로 그린다(me 면 오른쪽).
    if (line.photo != null) return _bubble(context);
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
            keepAll(line.text),
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
              line.text.isEmpty ? '읽음' : keepAll(line.text),
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
            if (line.photo case final photo?) ...[
              PhotoBubble(photo: photo, accent: a),
              if (line.text.isNotEmpty) const SizedBox(height: AppSpace.xs),
            ],
            if (line.photo == null || line.text.isNotEmpty)
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
                    keepAll(line.text),
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

// 사진 메시지 카드(PhotoBubble · photoIcons · photoIconFor)는 photo_card.dart.

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
            keepAll(title),
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
          : pad.add(const EdgeInsetsDirectional.only(start: AppSpace.xs)),
      child: child,
    );

    if (onTap != null) {
      body = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: InkWell(onTap: onTap, borderRadius: AppRadius.rLg, child: body),
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
          color: tone == AppTone.neutral
              ? context.scheme.outlineVariant
              : tn.line,
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

  /// danger 면 제목·leading 아이콘 색을 tokens.danger 로. 배경은 바꾸지 않는다.
  /// neutral | danger 만 지원, 나머지는 neutral 로 취급. [locked] 가 우선.
  final AppTone tone;

  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.locked = false,
    this.tone = AppTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final danger = !locked && tone == AppTone.danger;
    final fg = locked
        ? t.lockedForeground
        : danger
        ? t.danger
        : scheme.onSurface;

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
                // leading 아이콘은 제목과 같은 색을 따른다(danger 면 위험색).
                IconTheme.merge(
                  data: IconThemeData(
                    color: locked
                        ? t.lockedForeground
                        : danger
                        ? t.danger
                        : scheme.onSurfaceVariant,
                  ),
                  child: leading!,
                ),
                const SizedBox(width: AppSpace.md),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      keepAll(title),
                      style: context.text.titleSmall?.copyWith(
                        fontSize: 15,
                        color: fg,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xxs),
                        child: Text(
                          keepAll(subtitle!),
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
              if (tail != null) ...[const SizedBox(width: AppSpace.sm), tail],
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
          child: SingleChildScrollView(padding: AppInsets.panel, child: child),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. 배지 · 칩 · 빈 상태 · 선택지
// ---------------------------------------------------------------------------

/// 어제와 오늘을 잇는 한 줄(클리프행어). 행동 화면과 정산 화면이 같은 껍데기를 쓴다.
///
/// 청록(tertiary) 좌측 띠 + 밤 아이콘으로 "아직 안 끝난 줄" 임을 알린다.
/// [text] 는 가공하지 않고 한 덩어리 Text 로 렌더한다(테스트 고정).
class CliffhangerCard extends StatelessWidget {
  final String text;

  /// 정산 화면처럼 이 줄이 화면의 마지막 여운일 때 한 단 크게.
  final bool emphasized;

  const CliffhangerCard({
    super.key,
    required this.text,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return AppCard(
      accentStripe: scheme.tertiary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xxs),
            child: Icon(
              Icons.bedtime_outlined,
              size: 18,
              color: scheme.tertiary,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              keepAll(text),
              style: emphasized
                  ? context.text.bodyLarge
                  : context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

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
            keepAll(label),
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
              keepAll(detail!),
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
        border: Border.all(color: tn.line, width: AppBorderWidth.hairline),
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
            keepAll('$name ♥$affection ✓$trust'),
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
      child: InkWell(onTap: onTap, borderRadius: AppRadius.rPill, child: body),
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
              keepAll(title),
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              keepAll(body),
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
                    keepAll(text),
                    style: context.text.labelLarge?.copyWith(
                      color: fg,
                      height: 1.35,
                    ),
                  ),
                  if (lockedReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.xxs),
                      child: Text(
                        keepAll(lockedReason!),
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

// ---------------------------------------------------------------------------
// 8. 다이얼로그 헬퍼
// ---------------------------------------------------------------------------

/// 홈·행동·설정의 `showDialog` 를 대신한다. 스크림 불투명도를 시트와 맞춘다(§3.4).
/// `barrierDismissible` 등 다른 인자가 필요해지면 그때 추가한다.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showDialog<T>(
  context: context,
  barrierColor: context.scrimColor,
  builder: builder,
);

// ---------------------------------------------------------------------------
// 9. 홈 부품 — 아바타 · 사람들 · 이어하기 · 출석 · 엔딩 점
// ---------------------------------------------------------------------------

/// 캐릭터 원형 아바타. 초상화가 있으면 원형으로 자른 그림, 없으면 강조색 + 이름 첫 글자(§4.3).
///
/// 초상화는 규칙 기반이다: [characterId] 의 `assets/portraits/<id>.png` 가 번들에 있으면 쓴다
/// ([PortraitRegistry]). 그림을 읽는 중이거나 실패하면 이니셜을 그린다. 어느 쪽이든 크기·테두리는
/// 같아서 레이아웃이 달라지지 않는다. [characterId] 를 안 주면 [accent] 로 캐릭터를 거꾸로 찾는다
/// (`accentFor` 가 돌려준 강조색이면 찾힌다. 예전 호출부 호환).
///
/// [mystery] 는 히든 미해금. 그림이 있어도 글자 대신 사람 실루엣, 배경은 중립 표면(스포일러 방지).
class CharacterAvatar extends StatelessWidget {
  final String name;
  final CharacterAccent? accent;

  /// 초상화를 찾을 캐릭터 id. null 이면 [accent] 로 찾는다.
  final String? characterId;

  /// 32 · 40 · 56 · 72 를 쓴다(72 는 캐스트 소개 카드).
  final double size;
  final bool mystery;

  const CharacterAvatar({
    super.key,
    required this.name,
    this.accent,
    this.characterId,
    this.size = 40,
    this.mystery = false,
  });

  /// 강조색으로 캐릭터 id 를 거꾸로 찾는다. 중립색이거나 모르는 색이면 null.
  static String? idForAccent(AppTokens t, CharacterAccent? accent) {
    if (accent == null) return null;
    for (final e in t.characterAccents.entries) {
      if (identical(e.value, accent) || e.value == accent) return e.key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final a = accent ?? t.neutralAccent;
    final initial = name.isEmpty ? '' : name.characters.first;
    final style =
        (size <= 32
                ? context.text.labelMedium
                : size >= 56
                ? context.text.titleLarge
                : context.text.labelLarge)
            ?.copyWith(fontWeight: FontWeight.w700, color: a.onContainer);

    Widget initialCircle(BuildContext context) => Center(
      child: mystery
          ? Icon(
              Icons.person_outline,
              size: size * 0.5,
              color: t.lockedForeground,
            )
          : Text(initial, style: style),
    );

    final border = Border.all(
      color: mystery ? scheme.outlineVariant : a.base,
      width: AppBorderWidth.hairline,
    );

    return Semantics(
      label: mystery ? '아직 만나지 않은 사람' : name,
      child: ExcludeSemantics(
        child: ValueListenableBuilder<PortraitRegistry>(
          valueListenable: PortraitRegistry.listenable,
          builder: (context, portraits, _) {
            final path = mystery
                ? null
                : portraits.pathFor(characterId ?? idForAccent(t, accent));
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: mystery ? scheme.surfaceContainerHigh : a.container,
                shape: BoxShape.circle,
              ),
              // 테두리는 그림 위에 얹는다. 그림 가장자리가 강조색 선을 덮지 않게.
              foregroundDecoration: BoxDecoration(
                shape: BoxShape.circle,
                border: border,
              ),
              child: path == null
                  ? initialCircle(context)
                  : PortraitImage(
                      path: path,
                      size: size,
                      bundle: portraits.bundle,
                      semanticLabel: name,
                      fallback: initialCircle,
                    ),
            );
          },
        ),
      ),
    );
  }
}

/// [CastStrip] 한 칸의 데이터.
class CastEntry {
  final String id;
  final String name;

  /// null 이면 ♥ 줄을 그리지 않는다(세이브 없음).
  final int? affection;
  final bool mystery;

  const CastEntry({
    required this.id,
    required this.name,
    this.affection,
    this.mystery = false,
  });
}

/// 캐릭터 가로 한 줄(홈). 정렬은 호출부가 끝내서 넘긴다. 항목 폭 56, 사이 md.
///
/// 6개뿐이라 `ListView.builder` 대신 가로 `SingleChildScrollView` + `Row`.
/// 고정 높이가 필요 없어 글자를 키워도 줄이 늘어난다.
class CastStrip extends StatelessWidget {
  final List<CastEntry> entries;

  const CastStrip({super.key, required this.entries});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.md),
          _CastItem(entry: entries[i]),
        ],
      ],
    ),
  );
}

class _CastItem extends StatelessWidget {
  final CastEntry entry;
  const _CastItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final e = entry;
    // '???' 는 4.5:1 을 지키려 onSurfaceVariant. 잠김은 실루엣 아바타가 먼저 말한다.
    final nameColor = e.mystery ? scheme.onSurfaceVariant : scheme.onSurface;

    return Semantics(
      label: e.mystery
          ? '아직 만나지 않은 사람'
          : e.affection == null
          ? e.name
          : '${e.name} 호감 ${e.affection}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CharacterAvatar(
                name: e.name,
                characterId: e.id,
                accent: e.mystery ? null : t.accentFor(e.id),
                mystery: e.mystery,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                e.mystery ? '???' : e.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.text.labelSmall?.copyWith(color: nameColor),
              ),
              if (!e.mystery && e.affection != null) ...[
                const SizedBox(height: AppSpace.xxs),
                // 이름과 별개 Text(테스트 고정).
                Text(
                  keepAll('♥${e.affection}'),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: t.numericSmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 홈 이어하기 카드. 회차·진행·어젯밤 예고·가장 가까운 사람(HOME_REDESIGN §1.3 B-2).
///
/// 예고는 `'어젯밤: …'` 단일 Text, 최고 호감은 `'서연 ♥42'` 단일 Text 로 유지한다(테스트 고정).
/// [topSignal] 이 있으면 마지막 줄의 주인공은 숫자가 아니라 서사 신호 한 줄이고,
/// `'서연 ♥42'` 는 그 아래 작은 보조 줄로 내려간다(DESIGN_SYSTEM §3.2 서사 신호).
class ContinueCard extends StatelessWidget {
  final int run;
  final int chapter;
  final int day;
  final int totalDays;

  /// null 이면 '아직 아무 일도 없었다. 오늘부터다.' 라벨 '어젯밤:' 은 항상 붙는다.
  final String? cliffhanger;

  /// null 이면 '아직 아무와도 가까워지지 않았다'.
  final String? topName;
  final int topAffection;
  final CharacterAccent? topAccent;

  /// 최애의 id(초상화용). null 이면 [topAccent] 로 찾는다.
  final String? topCharacterId;

  /// 최애의 서사 신호 한 줄. null 이면 예전처럼 `'서연 ♥42'` + '가장 가까운 사람'.
  final String? topSignal;

  /// 이 회차의 선호 표기(`'여성 캐릭터'`). 회차 줄 뒤에 `' · 여성 캐릭터'` 로 작게 붙는다.
  /// null 이면(선호가 없던 예전 세이브) 붙이지 않는다. `'1회차 · 2장'` 은 단일 Text 그대로다.
  final String? preferenceLabel;

  /// 요약을 아직 못 읽은 첫 프레임인지.
  final bool _placeholder;

  const ContinueCard({
    super.key,
    required this.run,
    required this.chapter,
    required this.day,
    required this.totalDays,
    this.cliffhanger,
    this.topName,
    this.topAffection = 0,
    this.topAccent,
    this.topCharacterId,
    this.topSignal,
    this.preferenceLabel,
  }) : _placeholder = false;

  /// 세이브 요약을 아직 못 읽은 첫 프레임용.
  const ContinueCard.placeholder({super.key})
    : run = 0,
      chapter = 0,
      day = 0,
      totalDays = 100,
      cliffhanger = null,
      topName = null,
      topAffection = 0,
      topAccent = null,
      topCharacterId = null,
      topSignal = null,
      preferenceLabel = null,
      _placeholder = true;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final ratio = totalDays <= 0
        ? 0.0
        : (day / totalDays).clamp(0.0, 1.0).toDouble();
    final preview = _placeholder
        ? '어젯밤: 불러오는 중…'
        : '어젯밤: ${cliffhanger ?? '아직 아무 일도 없었다. 오늘부터다.'}';
    // 좁은 화면 + 큰 글꼴에서 신호 줄(2줄)이 붙으면 예고를 1줄로 줄여 높이 예산을 지킨다.
    final tight =
        topSignal != null &&
        MediaQuery.sizeOf(context).width < 360 &&
        MediaQuery.textScalerOf(context).scale(10) > 11.5;

    return AppCard(
      accentStripe: scheme.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _placeholder ? '저장된 회차' : '$run회차 · $chapter장',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelMedium,
                      ),
                    ),
                    // 선호는 회차 줄 꼬리. 좁으면 이쪽이 먼저 말줄임된다.
                    if (!_placeholder && preferenceLabel != null)
                      Flexible(
                        child: Text(
                          ' · $preferenceLabel',
                          key: const Key('continue-preference'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall,
                        ),
                      ),
                  ],
                ),
              ),
              if (!_placeholder) ...[
                const SizedBox(width: AppSpace.sm),
                Text(keepAll('D+$day / $totalDays'), style: t.numericMedium),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          AppProgressBar(
            value: ratio,
            height: AppSpace.xs + 2,
            semanticLabel: '진행도 $day일 / $totalDays일',
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xxs),
                child: Icon(
                  Icons.bedtime_outlined,
                  size: 18,
                  color: scheme.tertiary,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  keepAll(preview),
                  maxLines: tight ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium,
                ),
              ),
            ],
          ),
          if (!_placeholder) ...[
            const SizedBox(height: AppSpace.md),
            if (topName == null)
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      keepAll('아직 아무와도 가까워지지 않았다'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              )
            else if (topSignal != null)
              _SignalLine(
                name: topName!,
                affection: topAffection,
                accent: topAccent,
                characterId: topCharacterId,
                signal: topSignal!,
              )
            else
              Row(
                children: [
                  CharacterAvatar(
                    name: topName!,
                    characterId: topCharacterId,
                    accent: topAccent,
                    size: 32,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      keepAll('$topName ♥$topAffection'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text('가장 가까운 사람', style: context.text.labelSmall),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// 선호 선택 카드 한 장(`lib/ui/preference_screen.dart`). DESIGN_SYSTEM §3.2.
///
/// 제목(`titleMedium`) + 우측 화살표 → 그 쪽 캐릭터 이니셜 아바타 줄(40, 강조색, 히든은
/// 실루엣) → 한 줄 소개(`bodySmall`, 최대 2줄). 카드 전체가 한 탭 대상(최소 56)이고
/// 스크린리더에는 제목·소개·인원을 한 문장으로 읽힌다. [onTap] 이 null 이면 그 쪽 데이터가
/// 아직 없는 것 — 화살표 대신 [unavailableNote] 를 보이고 탭되지 않는다.
class PreferenceCard extends StatelessWidget {
  /// `'여성 캐릭터'` / `'남성 캐릭터'`. 단일 Text.
  final String title;

  /// 한 줄 소개. 예: `'선배 · 소개팅 상대 · 초등 동창'`.
  final String intro;

  /// 아바타 줄. 순서는 호출부가 정한다. [CastEntry.mystery] 면 실루엣.
  final List<CastEntry> cast;

  final VoidCallback? onTap;

  /// 탭할 수 없을 때 화살표 자리에 둘 짧은 말.
  final String unavailableNote;

  const PreferenceCard({
    super.key,
    required this.title,
    required this.intro,
    required this.cast,
    this.onTap,
    this.unavailableNote = '준비 중',
  });

  /// 아바타 [n]개가 폭 [width] 한 줄에 들어가는 가장 큰 크기(40, 안 되면 32).
  static double avatarSizeFor(int n, double width) {
    double row(double s) => n * s + (n - 1) * AppSpace.sm;
    return n <= 0 || row(40) <= width ? 40 : 32;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final enabled = onTap != null;
    final names = [
      for (final e in cast)
        if (!e.mystery) e.name,
    ];
    final hidden = cast.where((e) => e.mystery).length;
    final who = [...names, if (hidden > 0) '숨은 인물 $hidden명'].join(', ');

    return Semantics(
      button: true,
      enabled: enabled,
      label: [
        title,
        if (who.isNotEmpty) who,
        if (intro.isNotEmpty) intro,
        if (!enabled) unavailableNote,
      ].join('. '),
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium?.copyWith(
                      color: enabled
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                if (enabled)
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  )
                else
                  Text(unavailableNote, style: context.text.labelSmall),
              ],
            ),
            if (cast.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              // 한 줄에 다 들어가면 40, 아니면 32. 캐스트가 6명씩이라 320pt 에서는 32 로
              // 한 줄이 된다(두 줄로 접히면 선택 화면 높이 예산을 넘는다). 그래도 모자라면 접힌다.
              LayoutBuilder(
                builder: (context, box) {
                  final size = avatarSizeFor(cast.length, box.maxWidth);
                  return Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      for (final e in cast)
                        CharacterAvatar(
                          name: e.name,
                          characterId: e.id,
                          accent: e.mystery ? null : t.accentFor(e.id),
                          mystery: e.mystery,
                          size: size,
                        ),
                    ],
                  );
                },
              ),
            ],
            if (intro.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                keepAll(intro),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 온보딩 1단계(`lib/ui/onboarding_gender_screen.dart`)의 큰 선택 버튼 한 장. DESIGN_SYSTEM §3.2.
///
/// `AppCard(onTap)` 안에 [아이콘 24(onSurfaceVariant) → md → 라벨 `titleMedium` + 보조 `bodySmall`
/// → 우측 chevron 20]. 세 장이 같은 무게라 강조색·로즈를 쓰지 않는다. 카드 전체가 한 탭 대상
/// (최소 높이 64)이고 스크린리더에는 "라벨. 보조" 한 덩어리 버튼으로 읽힌다.
class GenderOptionCard extends StatelessWidget {
  final IconData icon;

  /// `'남자'` / `'여자'` / `'선택 안 할래요'`. 단일 Text.
  final String label;

  /// 이 답이 무엇을 바꾸는지 한 줄. 예: `'여성 캐릭터를 먼저 소개해요'`.
  final String hint;

  final VoidCallback onTap;

  const GenderOptionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  static const minHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Semantics(
      button: true,
      label: '$label. $hint',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        padding: AppInsets.cardTight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: minHeight - AppSpace.md * 2,
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.text.titleMedium),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      keepAll(hint),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [CastIntroCard] 한 장의 데이터. 화면이 `StoryBundle` 에서 만들어 넘긴다.
class CastIntro {
  final String id;
  final String name;

  /// 역할 호칭(`title`). 예: `'동아리 선배'`.
  final String title;

  /// 한 줄 매력(characters.json `tagline`). 비어 있으면 줄을 그리지 않는다.
  final String tagline;

  /// 첫 메시지 미리보기. null 이면 말풍선을 그리지 않는다.
  final String? firstLine;

  /// 히든. 이름·역할·문구를 전부 숨기고 `???` 실루엣 한 칸으로 그린다(스포일러).
  final bool mystery;

  /// 캐릭터 MBTI 칩 글자(`INTJ`, 히든은 [hiddenMbti]). null 이면 칩을 그리지 않는다.
  final String? mbti;

  /// 플레이어와의 궁합 점수(0~4). null 이면(플레이어 MBTI 모름) 궁합 줄을 그리지 않는다.
  final int? compat;

  /// 히든 캐릭터의 MBTI 칩 글자.
  static const hiddenMbti = '????';

  const CastIntro({
    required this.id,
    required this.name,
    this.title = '',
    this.tagline = '',
    this.firstLine,
    this.mystery = false,
    this.mbti,
    this.compat,
  });
}

/// 캐스트 소개 카드의 MBTI 칩. 작은 pill(`surfaceContainerHigh` + `outlineVariant` 1px),
/// 글자 `labelSmall` onSurfaceVariant. 스크린리더에는 "MBTI INTJ".
class MbtiChip extends StatelessWidget {
  final String mbti;
  const MbtiChip({super.key, required this.mbti});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Semantics(
      label: 'MBTI $mbti',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xxs,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: AppRadius.rPill,
          border: Border.all(
            color: scheme.outlineVariant,
            width: AppBorderWidth.hairline,
          ),
        ),
        child: Text(
          mbti,
          style: context.text.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// 궁합 줄: 하트 5칸 중 `score + 1` 칸 + 라벨(`천생연분` … `정반대`). docs/MBTI_SPEC.md §1.5.
/// 하트는 장식(스크린리더 제외), 라벨이 뜻을 전한다. 스크린리더에는 "궁합 천생연분, 5칸 중 5칸".
class CompatRow extends StatelessWidget {
  final int score;
  const CompatRow({super.key, required this.score});

  static const cells = 5;

  /// 채운 하트 수.
  static int filledFor(int score) => (score + 1).clamp(1, cells);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final filled = filledFor(score);
    final label = Mbti.compatLabel(score);
    return Semantics(
      label: '궁합 $label, $cells칸 중 $filled칸',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < cells; i++)
            Icon(
              i < filled ? Icons.favorite : Icons.favorite_border,
              size: 14,
              color: i < filled ? t.heart : t.heartEmpty,
            ),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Text(
              '궁합 $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 새 게임 2단계(캐스트 소개)의 캐릭터 한 장. DESIGN_SYSTEM §3.2.
///
/// `AppCard`(neutral, 누르지 않음) 안에 [아바타 72·좁으면 56(accentFor, 초상화) → md → 본문]. 본문은
/// 이름 `titleMedium` + 역할 `labelMedium`(onSurfaceVariant) 한 줄(좁으면 접힘) → xxs → 한 줄 매력
/// `bodyMedium` w600 → sm → 첫 메시지 말풍선(상대 말풍선과 같은 `bubbleTheirs` + 1px
/// `bubbleBorder` + `AppRadius.bubble(mine: false)`, `bubbleText`, 최대 3줄).
/// [CastIntro.mystery] 면 실루엣 아바타 + `'???'` + 안내 한 줄만.
/// 스크린리더에는 한 덩어리로 읽힌다(말풍선 앞에 "첫 메시지").
class CastIntroCard extends StatelessWidget {
  final CastIntro intro;

  const CastIntroCard({super.key, required this.intro});

  static const mysteryNote = '어떤 조건을 채우면 나타나는 사람';

  /// 카드 안쪽 폭 [width] 에 맞는 아바타 크기. 초상화 얼굴이 보이게 넉넉하면 72,
  /// 좁은 화면(320pt 폰, 안쪽 폭 약 248)은 본문 폭을 지키려 56. 그림 유무와 무관하다.
  static double avatarSizeFor(double width) => width >= 280 ? 72 : 56;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final e = intro;
    final accent = e.mystery ? null : t.accentFor(e.id);

    final List<Widget> body;
    if (e.mystery) {
      body = [
        Wrap(
          spacing: AppSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '???',
              style: context.text.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (e.mbti != null) MbtiChip(mbti: e.mbti!),
          ],
        ),
        const SizedBox(height: AppSpace.xxs),
        Text(
          keepAll(mysteryNote),
          style: context.text.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ];
    } else {
      final line = e.firstLine;
      body = [
        Wrap(
          spacing: AppSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(e.name, style: context.text.titleMedium),
            if (e.mbti != null) MbtiChip(mbti: e.mbti!),
            if (e.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.xxs),
                child: Text(
                  keepAll(e.title),
                  style: context.text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        if (e.compat != null) ...[
          const SizedBox(height: AppSpace.xxs),
          CompatRow(key: Key('compat-${e.id}'), score: e.compat!),
        ],
        if (e.tagline.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xxs),
          Text(
            keepAll(e.tagline),
            style: context.text.bodyMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (line != null) ...[
          const SizedBox(height: AppSpace.sm),
          Semantics(
            label: '첫 메시지',
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
                keepAll(line),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: t.bubbleText.copyWith(color: t.onBubbleTheirs),
              ),
            ),
          ),
        ],
      ];
    }

    return MergeSemantics(
      child: AppCard(
        child: LayoutBuilder(
          builder: (context, box) {
            final size = avatarSizeFor(box.maxWidth);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CharacterAvatar(
                  name: e.name,
                  characterId: e.id,
                  accent: accent,
                  mystery: e.mystery,
                  size: size,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: body,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 이어하기 카드의 마지막 줄: 최애의 서사 신호가 주인공, 하트 숫자는 작은 보조.
///
/// 아바타(32) 옆에 한 덩어리 `Text.rich`: 신호 문장 `bodyMedium`(onSurface) 뒤에
/// `'서연 ♥42'` 를 `labelSmall`(onSurfaceVariant) 꼬리로 붙이고 최대 2줄. 꼬리를 별도 줄로
/// 두지 않는 건 320pt · 1.3배 · 배너 높이 예산(HOME_REDESIGN §1.5) 때문이다.
class _SignalLine extends StatelessWidget {
  final String name;
  final int affection;
  final CharacterAccent? accent;
  final String? characterId;
  final String signal;

  const _SignalLine({
    required this.name,
    required this.affection,
    required this.accent,
    required this.signal,
    this.characterId,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CharacterAvatar(
          name: name,
          characterId: characterId,
          accent: accent,
          size: 32,
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: keepAll(signal),
                  style: context.text.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const TextSpan(text: '  '),
                // 이름과 호감은 한 덩어리(테스트 고정: '서연 ♥42'). 한글은 글자 사이에서도
                // 줄이 바뀌므로 TextSpan 으로 두면 '하 / 늘 ♥3' 처럼 이름이 쪼개진다.
                // WidgetSpan 은 통째로 다음 줄로 넘어간다.
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: Text(
                    keepAll('$name ♥$affection'),
                    style: context.text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 하루 정산의 "관계 변화" 카드. 오늘 호감 구간을 넘은 캐릭터 한 명.
///
/// 상승([up]): 캐릭터 강조색 좌측 띠 + 아바타 + 이름 + `'가까워졌다'` 배지(강조색 container
/// 면, 하트 아이콘) + 서사 신호 `bodyLarge`. 정산의 도파민 순간이라 화면 맨 위에 둔다.
/// 하강: 띠 없음, 배지는 중립 면 `'조금 멀어졌다'`(아래 화살표), 문장은 `bodyMedium`
/// onSurfaceVariant. 조용한 톤으로만 알린다. 색만으로 방향을 전하지 않도록 배지 낱말과
/// 아이콘이 항상 함께 간다.
class RelationShiftCard extends StatelessWidget {
  final String name;
  final String text;
  final bool up;
  final CharacterAccent? accent;

  /// 초상화용 id. null 이면 [accent] 로 찾는다.
  final String? characterId;

  const RelationShiftCard({
    super.key,
    required this.name,
    required this.text,
    required this.up,
    this.accent,
    this.characterId,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final a = accent ?? t.neutralAccent;
    final badgeBg = up ? a.container : scheme.surfaceContainerHigh;
    final badgeFg = up ? a.onContainer : scheme.onSurfaceVariant;
    final label = up ? '가까워졌다' : '조금 멀어졌다';

    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: AppRadius.rPill,
        border: Border.all(
          color: up ? a.base : scheme.outlineVariant,
          width: AppBorderWidth.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.favorite : Icons.south_east,
            size: 14,
            color: badgeFg,
          ),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.badgeText.copyWith(color: badgeFg),
            ),
          ),
        ],
      ),
    );

    return MergeSemantics(
      child: AppCard(
        // 하강 카드도 띠를 둔다(중립 색). 띠가 없으면 내용이 4pt 왼쪽으로 밀려
        // 상승 카드와 나란히 놓였을 때 아바타·이름 줄이 어긋난다.
        accentStripe: up ? a.base : scheme.outlineVariant,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CharacterAvatar(
              name: name,
              characterId: characterId,
              accent: a,
              size: 40,
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(name, style: context.text.titleSmall),
                      badge,
                    ],
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    keepAll(text),
                    style: up
                        ? context.text.bodyLarge?.copyWith(
                            color: scheme.onSurface,
                          )
                        : context.text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 출석 보상 줄의 상태.
enum RewardStripState { unclaimed, unclaimedBonus, claimed }

/// 홈 출석 보상 줄. 미수령이면 primaryContainer + '받기', 수령이면 중립 + 체크.
///
/// 탭 대상은 `받기` 버튼뿐이다. 줄 전체를 누르게 하면 "뭘 눌렀는지" 가 불분명해진다.
class RewardStrip extends StatelessWidget {
  final RewardStripState state;
  final int streakDays;

  /// unclaimedBonus 에서 부제에 붙는 보너스 문구. 예: '룰렛 재도전권 +1'.
  final String? bonusLabel;

  /// 세이브 없이 받아 둔 하트. 0 보다 크면 수령 상태 부제가 바뀐다.
  final int pendingHearts;

  /// unclaimed / unclaimedBonus 에서 필수.
  final Future<void> Function()? onClaim;

  const RewardStrip({
    super.key,
    required this.state,
    required this.streakDays,
    this.bonusLabel,
    this.pendingHearts = 0,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final claimed = state == RewardStripState.claimed;
    final bonus = state == RewardStripState.unclaimedBonus;

    final String title;
    final String subtitle;
    final IconData icon;
    if (claimed) {
      icon = Icons.check_circle;
      title = '오늘 출석 완료';
      subtitle = pendingHearts > 0
          ? '하트 +$pendingHearts 은 새 게임을 시작하면 들어온다'
          : '연속 $streakDays일째 · 내일 또 +1';
    } else if (bonus) {
      icon = Icons.redeem;
      title = '연속 $streakDays일 보너스';
      subtitle = bonusLabel == null ? '하트 +1' : '하트 +1 · $bonusLabel';
    } else {
      icon = Icons.card_giftcard;
      title = '출석 보상 하트 +1';
      subtitle = streakDays <= 0 ? '오늘부터 출석' : '연속 $streakDays일째';
    }

    final fg = claimed ? scheme.onSurface : scheme.onPrimaryContainer;
    final sub = claimed ? scheme.onSurfaceVariant : scheme.onPrimaryContainer;

    return AnimatedContainer(
      duration: AppMotion.base(context),
      curve: AppMotion.curve(context),
      constraints: const BoxConstraints(minHeight: 56),
      padding: AppInsets.cardTight,
      decoration: BoxDecoration(
        color: claimed ? scheme.surfaceContainerLow : scheme.primaryContainer,
        borderRadius: AppRadius.rMd,
        border: Border.all(
          color: claimed ? scheme.outlineVariant : scheme.primary,
          width: AppBorderWidth.hairline,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: claimed ? t.success : fg),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  keepAll(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(color: fg),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  keepAll(subtitle),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: sub),
                ),
              ],
            ),
          ),
          if (!claimed) ...[
            const SizedBox(width: AppSpace.md),
            FilledButton(
              onPressed: onClaim == null ? null : () => onClaim!(),
              // DS §5.7 예외 ①: 카드 안 보조 버튼이라 최소 높이 44.
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, AppSpace.minTouch),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: AppSpace.sm,
                ),
              ),
              child: const Text('받기'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 엔딩 등급별 획득 점. 순서 happy → good → solo → bad → hidden 고정.
///
/// 점은 색만으로 말하지 않는다 — 우측에 `n/m` 숫자를 항상 함께 둔다.
class EndingTierDots extends StatelessWidget {
  /// tier → (획득, 전체).
  final Map<String, (int, int)> counts;

  const EndingTierDots({super.key, required this.counts});

  static const _order = ['happy', 'good', 'solo', 'bad', 'hidden'];

  /// 앨범 `_tier` 와 같은 낱말.
  static String labelOf(String tier) => switch (tier) {
    'happy' => '해피',
    'good' => '굿',
    'solo' => '솔로',
    'bad' => '배드',
    'hidden' => '히든',
    _ => tier,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final rows = [
      for (final tier in _order)
        if (counts.containsKey(tier)) (tier, counts[tier]!),
    ];
    final summary = rows
        .map((r) => '${labelOf(r.$1)} 엔딩 ${r.$2.$2}개 중 ${r.$2.$1}개')
        .join(', ');

    return Semantics(
      label: summary,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      labelOf(rows[i].$1),
                      maxLines: 1,
                      style: context.text.labelSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Wrap(
                      spacing: AppSpace.xs,
                      runSpacing: AppSpace.xs,
                      children: [
                        for (var d = 0; d < rows[i].$2.$2; d++)
                          Container(
                            width: AppSpace.sm,
                            height: AppSpace.sm,
                            decoration: BoxDecoration(
                              color: d < rows[i].$2.$1
                                  ? scheme.primary
                                  : t.gaugeTrack,
                              shape: BoxShape.circle,
                              border: d < rows[i].$2.$1
                                  ? null
                                  : Border.all(
                                      color: scheme.outlineVariant,
                                      width: AppBorderWidth.hairline,
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    keepAll('${rows[i].$2.$1}/${rows[i].$2.$2}'),
                    style: t.numericSmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
